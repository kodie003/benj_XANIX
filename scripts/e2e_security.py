"""Checks the SMS sign-in flow and the Firestore security rules against the emulators.

    python scripts/e2e_security.py OUT_DIR     (emulators and scripts/serve.py running)
"""
import json
import sys
import time
import urllib.error
import urllib.request

from playwright.sync_api import sync_playwright

OUT = sys.argv[1]
AUTH = "http://localhost:9099"
FS = "http://localhost:8087/v1/projects/demo-benj/databases/(default)/documents"
results = []


def check(name, ok, extra=""):
    results.append(bool(ok))
    print(("PASS " if ok else "FAIL ") + name, extra)


def call(url, data=None, token=None, method=None):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(url, data=json.dumps(data).encode() if data is not None else None, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req) as r:
            return r.status, json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        return e.code, {}


def user(tag):
    _, u = call(f"{AUTH}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo", {"email": f"{tag}{int(time.time() * 1000)}@test.benj", "password": "secret123", "returnSecureToken": True})
    return u["localId"], u["idToken"]


def val(**k):
    out = {}
    for name, v in k.items():
        if isinstance(v, bool):
            out[name] = {"booleanValue": v}
        elif isinstance(v, str) and v.startswith("TS:"):
            out[name] = {"timestampValue": v[3:]}
        elif isinstance(v, str):
            out[name] = {"stringValue": v}
        elif isinstance(v, int):
            out[name] = {"integerValue": str(v)}
        else:
            out[name] = {"doubleValue": v}
    return {"fields": out}


def rules():
    print("--- security rules")
    a, ta = user("a")
    b, tb = user("b")
    ts = "TS:2026-11-04T10:00:00Z"
    shop = val(name="A's shop", consentAt=ts)
    s, _ = call(f"{FS}/shops/{a}", shop, ta, "PATCH")
    check("owner can create their shop", s == 200, s)
    s, _ = call(f"{FS}/shops/{a}/products/p1", val(name="Rice", unit="bag"), ta, "PATCH")
    check("owner can add a product", s == 200, s)
    log = val(product="p1", at=ts, type="sale", quantity=2, method="tap")
    s, _ = call(f"{FS}/shops/{a}/stockLogs/l1", log, ta, "PATCH")
    check("owner can log a sale", s == 200, s)
    s, _ = call(f"{FS}/shops/{a}", token=tb)
    check("another user cannot read the shop", s == 403, s)
    s, _ = call(f"{FS}/shops/{a}/stockLogs", token=tb)
    check("another user cannot list the logs", s == 403, s)
    s, _ = call(f"{FS}/shops/{a}/stockLogs/l2", log, tb, "PATCH")
    check("another user cannot write logs", s == 403, s)
    s, _ = call(f"{FS}/shops/{a}")
    check("nobody signed out can read", s == 403, s)
    s, _ = call(f"{FS}/shops", token=ta)
    check("cannot list everyone's shops", s == 403, s)
    s, _ = call(f"{FS}/shops/{a}/stockLogs/l3", val(product="p1", at=ts, type="sale", quantity=-5), ta, "PATCH")
    check("negative quantity rejected", s == 403, s)
    s, _ = call(f"{FS}/shops/{a}/stockLogs/l4", val(product="p1", at=ts, type="stolen", quantity=1), ta, "PATCH")
    check("unknown log type rejected", s == 403, s)
    s, _ = call(f"{FS}/shops/{a}/products/p2", val(name="Rice", unit="bag", admin=True), ta, "PATCH")
    check("unexpected fields rejected", s == 403, s)
    s, _ = call(f"{FS}/secrets/x", val(a="b"), ta, "PATCH")
    check("other collections are closed", s == 403, s)


def phone():
    print("--- SMS sign-in")
    number = f"+23324{int(time.time()) % 10000000:07d}"
    local = "0" + number[4:]
    with sync_playwright() as p:
        b = p.chromium.launch(channel="msedge", headless=True, args=["--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"])
        pg = b.new_context(viewport={"width": 412, "height": 860}, device_scale_factor=1.5).new_page()
        pg.goto("http://localhost:8766/")
        pg.add_style_tag(content=".firebase-emulator-warning{display:none!important}")
        pg.wait_for_function("!document.getElementById('boot')", timeout=120000)
        pg.wait_for_timeout(4000)
        pg.evaluate("() => { const b = document.querySelector('flt-semantics-placeholder'); if (b) b.click(); }")
        pg.wait_for_timeout(800)

        def click(el):
            box = el.bounding_box()
            pg.mouse.click(box["x"] + box["width"] / 2, box["y"] + box["height"] / 2)
            pg.wait_for_timeout(300)

        click(pg.get_by_label("Phone number").first)
        pg.keyboard.type(local, delay=10)
        click(pg.get_by_role("button", name="Text me a code").first)
        pg.wait_for_timeout(4000)
        pg.screenshot(path=f"{OUT}/sms_1_code_screen.png")
        text = pg.evaluate("[...document.querySelectorAll('flt-semantics')].map(e => (e.getAttribute('aria-label')||'') + ' ' + (e.textContent||'')).join(' ')")
        check("a local number became international and a code was sent", number in text, number)
        _, codes = call(f"{AUTH}/emulator/v1/projects/demo-benj/verificationCodes")
        code = next((c["code"] for c in reversed(codes.get("verificationCodes", [])) if c["phoneNumber"] == number), None)
        check("Firebase issued a code for this number", bool(code))

        inputs = pg.locator("input")
        click(inputs.first)
        pg.keyboard.type("000000", delay=20)
        pg.wait_for_timeout(2500)
        text = pg.evaluate("[...document.querySelectorAll('flt-semantics')].map(e => (e.getAttribute('aria-label')||'') + ' ' + (e.textContent||'')).join(' ')")
        check("a wrong code is explained in plain English", "isn't right" in text)

        pg.keyboard.press("Control+A")
        pg.keyboard.type(code, delay=20)
        pg.wait_for_timeout(5000)
        pg.screenshot(path=f"{OUT}/sms_2_signed_in.png")
        text = pg.evaluate("[...document.querySelectorAll('flt-semantics')].map(e => (e.getAttribute('aria-label')||'') + ' ' + (e.textContent||'')).join(' ')")
        check("the right code signs in, and lands on setup", "Tell me about your shop" in text)
        b.close()


rules()
phone()
print(f"\n{sum(results)}/{len(results)} passed")
