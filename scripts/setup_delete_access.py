"""Lets benj delete an account instantly: stores a Google service key in Vercel.

1. Open https://console.firebase.google.com/project/benj-27c66/settings/serviceaccounts/adminsdk
2. Click "Generate new private key" and save the file.
3. Run:  python scripts/setup_delete_access.py "<path to the downloaded .json file>"

The key is sent to Vercel and never printed. The downloaded file is deleted afterwards,
because it is a password to the whole Firebase project. Never put it in this public repo.
"""
import json, os, subprocess, sys

if len(sys.argv) != 2:
    raise SystemExit(__doc__)
path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    sa = json.load(f)
if sa.get("project_id") != "benj-27c66" or sa.get("type") != "service_account" or "private_key" not in sa:
    raise SystemExit("That isn't a service key for benj-27c66. Nothing was changed.")

key = json.dumps(sa, separators=(",", ":"))
repo = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
res = subprocess.run("vercel env add BENJ_ADMIN_KEY production --sensitive", input=key, text=True, capture_output=True, shell=True, cwd=repo)
print((res.stdout + res.stderr).replace(key, "***")[-400:])
if res.returncode != 0:
    raise SystemExit("Vercel didn't save it, so the file was kept. Fix the message above and run this again.")
os.remove(path)
print("Saved in Vercel and deleted the downloaded file. Tell Claude it's done, so the site can be redeployed.")
