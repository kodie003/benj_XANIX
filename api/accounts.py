"""benj account lookup: sign in with a business name, phone or email, and reset by email.

Firebase signs a person in with one email-style login. Owners can type any of their
business name, phone or email, so benj keeps a private index:

    logins/{sha256(kind:value)} -> {uid, login, kind, hasEmail}

The index is never readable from the app (firestore.rules). Only this service reads
it, signed in as a dedicated service account, and it only reveals the login after the
password is checked by Firebase itself.

POST /api/accounts with JSON {"action": ...}:
  available  {business, phone?}            -> {business: free?, phone: free?}
  register   {idToken, business?, phone?, email?}  (records this account's names)
  resolve    {identifier, password}        -> {login} when the password is right
  reset      {identifier}                  -> sends Firebase's reset email if the account has one
  unregister {idToken}                     (removes this account from the index)
"""

import hashlib
import json
import os
import re
import time
import traceback
import unicodedata
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler

PROJECT = os.environ.get("BENJ_PROJECT", "benj-27c66")
API_KEY = os.environ.get("BENJ_API_KEY", "AIzaSyB-JRfxfNRUWOiDPx6iiDcBv9xpy-h6He8")  # public web key
SVC_EMAIL = os.environ.get("BENJ_SVC_EMAIL", "svc-logins@benj.invalid")
SVC_PASSWORD = os.environ.get("BENJ_SVC_PASSWORD", "")
AUTH_EMU = os.environ.get("FIREBASE_AUTH_EMULATOR_HOST")
FS_EMU = os.environ.get("FIRESTORE_EMULATOR_HOST")
IDT = (f"http://{AUTH_EMU}/" if AUTH_EMU else "https://") + "identitytoolkit.googleapis.com/v1"
FS = (f"http://{FS_EMU}" if FS_EMU else "https://firestore.googleapis.com") + f"/v1/projects/{PROJECT}/databases/(default)/documents"
REFERER = "https://benj-xanix.vercel.app/"


# ---------------------------------------------------------------- normalising

def norm_business(s):
    """'  Ama  Provisions!' and 'ama provisions' are the same shop name."""
    s = unicodedata.normalize("NFKD", s or "").encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", " ", s.lower()).strip()


def norm_phone(s):
    """+233241234567 from '0241234567', '024 123 4567', '+233 24 123 4567' or '233241234567'."""
    s = (s or "").strip()
    digits = re.sub(r"\D", "", s)
    if not digits:
        return None
    if s.startswith("+"):
        return "+" + digits
    if s.startswith("00"):
        return "+" + digits[2:]
    if len(digits) == 10 and digits.startswith("0"):  # Ghana, typed locally
        return "+233" + digits[1:]
    if len(digits) == 12 and digits.startswith("233"):
        return "+" + digits
    return None


def norm_email(s):
    s = (s or "").strip().lower()
    return s if re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", s) else None


def key(kind, value):
    return hashlib.sha256(f"{kind}:{value}".encode()).hexdigest()


def identifier_keys(identifier):
    """Every index key an identifier could match, most specific first."""
    out = []
    email = norm_email(identifier)
    if email:
        out.append(("email", email))
    phone = norm_phone(identifier)
    if phone:
        out.append(("phone", phone))
    business = norm_business(identifier)
    if business:
        out.append(("business", business))
    return out


# ---------------------------------------------------------------- HTTP helpers

class ApiError(Exception):
    def __init__(self, status, body):
        super().__init__(body)
        self.status, self.body = status, body


def call(url, body=None, token=None, method=None):
    headers = {"Content-Type": "application/json", "Referer": REFERER}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=10) as r:
            return r.status, json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        try:
            return e.code, json.loads(e.read() or b"{}")
        except ValueError:
            return e.code, {}


def password_ok(login, password):
    status, body = call(f"{IDT}/accounts:signInWithPassword?key={API_KEY}", {"email": login, "password": password, "returnSecureToken": False})
    if status == 200:
        return True
    msg = (body.get("error") or {}).get("message", "")
    if "TOO_MANY_ATTEMPTS" in msg:
        raise ApiError(429, {"error": "too-many-requests"})
    return False


# The service account's token, reused while it is fresh.
_svc = {"token": None, "until": 0}


def svc_token():
    if _svc["token"] and time.time() < _svc["until"]:
        return _svc["token"]
    if not SVC_PASSWORD:
        raise ApiError(500, {"error": "service-not-configured"})
    body = {"email": SVC_EMAIL, "password": SVC_PASSWORD, "returnSecureToken": True}
    status, res = call(f"{IDT}/accounts:signInWithPassword?key={API_KEY}", body)
    if status != 200 and AUTH_EMU:  # Local emulators start empty.
        status, res = call(f"{IDT}/accounts:signUp?key={API_KEY}", body)
    if status != 200:
        raise ApiError(500, {"error": "service-sign-in-failed"})
    _svc.update(token=res["idToken"], until=time.time() + int(res.get("expiresIn", "3600")) - 300)
    return _svc["token"]


def user_of(id_token):
    status, res = call(f"{IDT}/accounts:lookup?key={API_KEY}", {"idToken": id_token})
    if status != 200 or not res.get("users"):
        raise ApiError(401, {"error": "not-signed-in"})
    u = res["users"][0]
    return u["localId"], (u.get("email") or "").lower()


def fs_get(k):
    status, doc = call(f"{FS}/logins/{k}", token=svc_token())
    if status == 404:
        return None
    if status != 200:
        raise ApiError(502, {"error": "index-unavailable"})
    f = doc.get("fields", {})
    return {name: list(v.values())[0] for name, v in f.items()}


def fs_set(k, uid, login, kind):
    has_email = not login.endswith(".invalid")
    fields = {"uid": {"stringValue": uid}, "login": {"stringValue": login}, "kind": {"stringValue": kind}, "hasEmail": {"booleanValue": has_email}}
    status, _ = call(f"{FS}/logins/{k}", {"fields": fields}, token=svc_token(), method="PATCH")
    if status != 200:
        raise ApiError(502, {"error": "index-unavailable"})


def fs_docs_of(uid):
    query = {"structuredQuery": {"from": [{"collectionId": "logins"}], "where": {"fieldFilter": {"field": {"fieldPath": "uid"}, "op": "EQUAL", "value": {"stringValue": uid}}}}}
    status, rows = call(f"{FS}:runQuery", query, token=svc_token())
    if status != 200:
        raise ApiError(502, {"error": "index-unavailable"})
    out = []
    for row in rows if isinstance(rows, list) else []:
        d = row.get("document")
        if d:
            out.append((d["name"].split("/")[-1], d["fields"].get("kind", {}).get("stringValue", "")))
    return out


def fs_delete(k):
    call(f"{FS}/logins/{k}", token=svc_token(), method="DELETE")


# ---------------------------------------------------------------- actions

def act_available(body):
    out = {}
    b = norm_business(body.get("business", ""))
    if b:
        out["business"] = fs_get(key("business", b)) is None
    p = norm_phone(body.get("phone", ""))
    if p:
        out["phone"] = fs_get(key("phone", p)) is None
    return out


def act_register(body):
    uid, login = user_of(body.get("idToken", ""))
    wanted = []
    b = norm_business(body.get("business", ""))
    if b:
        wanted.append(("business", b))
    p = norm_phone(body.get("phone", ""))
    if p:
        wanted.append(("phone", p))
    e = norm_email(body.get("email", ""))
    if e:
        wanted.append(("email", e))
    # Nobody else may already hold any of these names.
    for kind, value in wanted:
        existing = fs_get(key(kind, value))
        if existing and existing.get("uid") != uid:
            raise ApiError(409, {"error": "taken", "kind": kind})
    # Replace this account's old entries of the same kinds (e.g. a renamed shop).
    kinds = {k for k, _ in wanted}
    keep = {key(k, v) for k, v in wanted}
    for doc_id, kind in fs_docs_of(uid):
        if kind in kinds and doc_id not in keep:
            fs_delete(doc_id)
    for kind, value in wanted:
        fs_set(key(kind, value), uid, login, kind)
    return {"ok": True}


def act_resolve(body):
    identifier, password = body.get("identifier", ""), body.get("password", "")
    if not identifier or not password:
        raise ApiError(400, {"error": "missing"})
    tried = set()
    for kind, value in identifier_keys(identifier):
        entry = fs_get(key(kind, value))
        if not entry or entry["login"] in tried:
            continue
        tried.add(entry["login"])
        if password_ok(entry["login"], password):
            return {"login": entry["login"]}
    raise ApiError(401, {"error": "wrong"})


def act_reset(body):
    for kind, value in identifier_keys(body.get("identifier", "")):
        entry = fs_get(key(kind, value))
        if entry and entry.get("hasEmail"):
            call(f"{IDT}/accounts:sendOobCode?key={API_KEY}", {"requestType": "PASSWORD_RESET", "email": entry["login"]})
            break
    # Same answer either way, so nobody can find out which accounts exist.
    return {"ok": True}


def act_unregister(body):
    uid, _ = user_of(body.get("idToken", ""))
    for doc_id, _ in fs_docs_of(uid):
        fs_delete(doc_id)
    return {"ok": True}


ACTIONS = {"available": act_available, "register": act_register, "resolve": act_resolve, "reset": act_reset, "unregister": act_unregister}


class handler(BaseHTTPRequestHandler):
    def _send(self, status, body):
        data = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header("Allow", "POST")
        self.end_headers()

    def do_GET(self):
        self._send(200, {"service": "benj accounts", "usage": "POST {action: ...}"})

    def do_POST(self):
        try:
            length = int(self.headers.get("Content-Length", 0))
            body = json.loads(self.rfile.read(length) or b"{}")
            action = ACTIONS.get(body.get("action"))
            if not action:
                return self._send(400, {"error": "unknown-action"})
            return self._send(200, action(body))
        except ApiError as e:
            return self._send(e.status, e.body)
        except ValueError:
            return self._send(400, {"error": "bad-json"})
        except Exception:  # A slow or failed call upstream: answer cleanly, never drop the connection.
            traceback.print_exc()
            return self._send(502, {"error": "service"})
