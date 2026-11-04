"""Create benj's account-service login on benj-27c66 and store its password in Vercel.
The password is generated here and never printed."""
import json, secrets, subprocess, urllib.request, urllib.error

KEY = "AIzaSyB-JRfxfNRUWOiDPx6iiDcBv9xpy-h6He8"
EMAIL = "svc-logins@benj.invalid"
password = secrets.token_urlsafe(32)

req = urllib.request.Request(
    f"https://identitytoolkit.googleapis.com/v1/accounts:signUp?key={KEY}",
    json.dumps({"email": EMAIL, "password": password, "returnSecureToken": True}).encode(),
    {"Content-Type": "application/json", "Referer": "https://benj-xanix.vercel.app/"},
)
try:
    with urllib.request.urlopen(req) as r:
        print("service login created:", r.status)
except urllib.error.HTTPError as e:
    print("service login NOT created:", e.code, json.loads(e.read()).get("error", {}).get("message"))
    raise SystemExit(1)

res = subprocess.run("vercel env add BENJ_SVC_PASSWORD production", input=password, text=True, capture_output=True, shell=True,
                     cwd=r"C:\Users\josep\Desktop\projects\XANIX")
print("vercel env add exit:", res.returncode)
print((res.stdout + res.stderr).replace(password, "***")[-400:])
