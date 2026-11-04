"""End-to-end run against the Firebase emulators, driving the app as an owner would.

    firebase emulators:start --project demo-benj --only auth,firestore
    flutter build web --no-web-resources-cdn --pwa-strategy=none --dart-define=USE_EMULATOR=true
    python scripts/serve.py 8766
    python scripts/e2e.py OUT_DIR

Past days of history are written straight into the throwaway emulator, so the screens
can be checked with weeks of logs. None of this exists in the app or in production.
"""
import json
import random
import sys
import time
import urllib.request
from datetime import datetime, timedelta, timezone

from playwright.sync_api import sync_playwright

OUT = sys.argv[1]
URL = "http://localhost:8766/"
W, H = 412, 860
EMAIL = f"owner{int(time.time())}@test.benj"
errors, checks = [], []
FS = "http://localhost:8087/v1/projects/demo-benj/databases/(default)/documents"


def check(name, ok):
    checks.append((name, bool(ok)))
    print(("  PASS " if ok else "  FAIL ") + name)


def api(url, data=None, method=None):
    req = urllib.request.Request(url, data=json.dumps(data).encode() if data is not None else None, method=method, headers={"Authorization": "Bearer owner", "Content-Type": "application/json"})
    return json.loads(urllib.request.urlopen(req).read() or b"{}")


def uid_for(email):
    return api("http://localhost:9099/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=demo", {"email": email, "password": "secret123", "returnSecureToken": True}, "POST")["localId"]


def shot(pg, name):
    pg.screenshot(path=f"{OUT}/e2e_{name}.png")
    print("  shot", name)


def semantics(pg):
    # Flutter draws to canvas; its accessibility tree gives us real buttons and inputs.
    pg.evaluate("""() => { const b = document.querySelector('flt-semantics-placeholder'); if (b) b.click(); }""")
    pg.wait_for_timeout(500)


def click_el(pg, el):
    try:
        el.scroll_into_view_if_needed(timeout=1500)
    except Exception:
        pass  # Floating things never hold still; the box below is good enough.
    box = el.bounding_box()
    pg.mouse.click(box["x"] + box["width"] / 2, box["y"] + box["height"] / 2)
    pg.wait_for_timeout(350)


def tap(pg, name, exact=False, timeout=15000):
    deadline = time.time() + timeout / 1000
    while True:
        for role in ("button", "tab", "radio", "checkbox"):
            el = pg.get_by_role(role, name=name, exact=exact)
            if el.count():
                return click_el(pg, el.first)
        el = pg.locator(f'flt-semantics:text-is("{name}")')
        if el.count():
            return click_el(pg, el.first)
        if time.time() > deadline:
            pg.screenshot(path=f"{OUT}/e2e_FAIL.png")
            print("  visible:", page_text(pg)[:1500])
            raise RuntimeError(f"nothing to tap called {name!r}")
        pg.wait_for_timeout(300)


def fill(pg, label, text):
    el = pg.get_by_label(label).first
    el.wait_for(state="attached", timeout=15000)
    click_el(pg, el)
    pg.keyboard.press("Control+A")
    pg.keyboard.type(text, delay=8)
    pg.wait_for_timeout(250)


def page_text(pg):
    return pg.evaluate("[...document.querySelectorAll('flt-semantics')].map(e => (e.getAttribute('aria-label')||'') + ' ' + (e.textContent||'')).join(' | ')")


def seed_history(uid):
    """28 days of sales for the products the owner just added."""
    docs = api(f"{FS}/shops/{uid}/products")["documents"]
    ids = {}
    for d in docs:
        f = d["fields"]
        ids[f["name"]["stringValue"] + " " + f.get("size", {}).get("stringValue", "")] = d["name"].split("/")[-1]
    now = datetime.now(timezone.utc).replace(hour=17, minute=0, second=0, microsecond=0)
    rng = random.Random(4)
    rates = {"Rice 1 kg": 4.0, "Rice 4.5 kg": 1.2, "Noodles ": 2.6, "Milo ": 0.5}
    start_stock = {"Rice 1 kg": 118, "Rice 4.5 kg": 35, "Noodles ": 90, "Milo ": 26}
    writes = []
    def doc(pid, at, typ, q, method="tap", secs=None):
        fields = {"product": {"stringValue": pid}, "at": {"timestampValue": at.strftime("%Y-%m-%dT%H:%M:%SZ")}, "type": {"stringValue": typ}, "quantity": {"doubleValue": q}, "method": {"stringValue": method}}
        if secs is not None:
            fields["secondsTaken"] = {"integerValue": str(secs)}
        writes.append({"update": {"name": f"projects/demo-benj/databases/(default)/documents/shops/{uid}/stockLogs/seed{len(writes)}", "fields": fields}})
    for name, pid in ids.items():
        base = name if name in rates else name
        doc(pid, now - timedelta(days=29), "restock", start_stock.get(base, 40))
        for d in range(28, 0, -1):
            at = now - timedelta(days=d)
            q = max(0, round(rng.gauss(rates.get(base, 1) * (0.55 if at.weekday() == 6 else 1), rates.get(base, 1) * 0.3)))
            if q:
                doc(pid, at, "sale", q, rng.choice(["tap", "tap", "voice", "photo"]), rng.randint(9, 48))
    for i in range(0, len(writes), 200):
        api("http://localhost:8087/v1/projects/demo-benj/databases/(default)/documents:commit", {"writes": writes[i:i + 200]}, "POST")
    print("  seeded", len(writes), "logs")


def main():
    with sync_playwright() as p:
        b = p.chromium.launch(channel="msedge", headless=True, args=["--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"])
        ctx = b.new_context(viewport={"width": W, "height": H}, device_scale_factor=1.5)
        pg = ctx.new_page()
        pg.on("pageerror", lambda e: errors.append(f"pageerror: {e}"))
        pg.on("console", lambda m: errors.append(f"console: {m.text}") if m.type == "error" and "404" not in m.text and "favicon" not in m.text and "ERR_INTERNET_DISCONNECTED" not in m.text and "400 (Bad Request)" not in m.text else None)

        print("boot")
        pg.goto(URL)
        pg.add_style_tag(content=".firebase-emulator-warning{display:none!important}")  # Emulator-only banner.
        pg.wait_for_timeout(700)
        shot(pg, "01_boot_logo")
        pg.wait_for_function("!document.getElementById('boot')", timeout=120000)
        pg.wait_for_timeout(1000)
        shot(pg, "02_name_glass")
        pg.wait_for_timeout(3500)
        semantics(pg)
        pg.wait_for_timeout(2500)
        shot(pg, "03_auth")

        print("wrong password is explained")
        tap(pg, "Email", exact=True)
        fill(pg, "Email", EMAIL)
        fill(pg, "Password", "nope123")
        tap(pg, "Sign in", exact=True)
        pg.wait_for_timeout(2500)
        check("failed sign-in shows a plain message", "isn't right" in page_text(pg))

        print("sign up")
        tap(pg, "New here? Create an account")
        fill(pg, "Password", "secret123")
        tap(pg, "Create account")
        pg.wait_for_timeout(5000)
        check("new account lands on shop setup", "Tell me about your shop" in page_text(pg))
        shot(pg, "05_setup")

        print("set up the shop")
        fill(pg, "Shop name", "Test Mini Mart")
        fill(pg, "Your name", "Ama")
        fill(pg, "Where is it?", "Berekuso")
        tap(pg, "Mon", exact=True)
        tap(pg, "Open my shop")
        pg.wait_for_timeout(800)
        check("setup requires consent", "tick the box" in page_text(pg))
        cb = pg.get_by_role("checkbox", name="Keep my stock").first
        click_el(pg, cb)
        tap(pg, "Open my shop")
        pg.wait_for_timeout(4500)
        check("setup opens the home screen", "Test Mini Mart" in page_text(pg))
        shot(pg, "06_home_empty")

        print("add products")
        tap(pg, "Add what you sell")
        pg.wait_for_timeout(2500)
        tap(pg, "Add a product")
        pg.wait_for_timeout(600)
        for name, size, unit, on_hand, cost in [("Rice", "1 kg", "bag", "30", "18"), ("Rice", "4.5 kg", "bag", "12", "75"), ("Noodles", "", "carton", "9", "60"), ("Milo", "", "tin", "6", "32")]:
            fill(pg, "Name", name)
            if size:
                fill(pg, "Size (optional)", size)
            fill(pg, "On the shelf now", on_hand)
            fill(pg, "You pay (optional)", cost)
            tap(pg, unit, exact=True)
            if name == "Rice" and size == "1 kg":
                shot(pg, "07_product_form")
            tap(pg, "Save, add another")
            pg.wait_for_timeout(1500)
        pg.mouse.click(W / 2, 40)  # Close the sheet by tapping outside it.
        pg.wait_for_timeout(1500)
        semantics(pg)
        check("products appear on the Log screen", "Noodles" in page_text(pg) and "Rice 4.5 kg" in page_text(pg))
        shot(pg, "08_log")

        print("log by tapping")
        tap(pg, "One more Noodles")
        tap(pg, "One more Noodles")
        tap(pg, "One more Rice 1 kg")
        shot(pg, "09_log_tapped")
        tap(pg, "Save 2 items")
        pg.wait_for_timeout(700)
        shot(pg, "10_saving_glow")
        pg.wait_for_timeout(1500)
        shot(pg, "11_saved_tick")
        pg.wait_for_timeout(2500)
        semantics(pg)
        check("after saving, back on home", "Days logged this week" in page_text(pg))
        check("sale reduced stock (home shows 1 of 7)", "1 of 7" in page_text(pg))

        print("offline: a log still saves")
        tap(pg, "Log", exact=True)
        pg.wait_for_timeout(1200)
        ctx.set_offline(True)
        pg.wait_for_timeout(500)
        tap(pg, "One more Milo")
        tap(pg, "Save 1 item")
        pg.wait_for_timeout(4500)
        semantics(pg)
        ctx.set_offline(False)
        pg.wait_for_timeout(3000)
        check("offline log saved and returned home", "Days logged this week" in page_text(pg))

        print("voice, typed the same way")
        tap(pg, "Log", exact=True)
        pg.wait_for_timeout(1000)
        tap(pg, "Speak")
        pg.wait_for_timeout(3000)
        shot(pg, "12_voice_orb")
        semantics(pg)
        fill(pg, "Or type it the same way", "sold five small rice and two noodles")
        pg.keyboard.press("Enter")
        pg.wait_for_timeout(1500)
        semantics(pg)
        t = page_text(pg)
        check("voice parser offers both rows", "Rice 1 kg" in t and "Noodles" in t and "Is this right?" in t)
        shot(pg, "13_voice_confirm")
        tap(pg, "Yes, save it")
        pg.wait_for_timeout(4200)
        semantics(pg)

        print("seed four weeks of history in the emulator")
        seed_history(uid_for(EMAIL))
        pg.wait_for_timeout(2500)
        tap(pg, "Home")
        pg.wait_for_timeout(3500)
        semantics(pg)
        t = page_text(pg)
        check("home now gives a buying answer", "THIS WEEK" in t and "Buy " in t)
        shot(pg, "14_home_answer")

        print("buying list")
        tap(pg, "Buy", exact=True)
        pg.wait_for_timeout(1500)
        semantics(pg)
        shot(pg, "15_buying")
        fill(pg, "Cash for restock (optional)", "500")
        pg.wait_for_timeout(600)
        shot(pg, "16_buying_budget")
        check("budget trims the list", "reduced to fit your cash" in page_text(pg))

        print("stock chart and sky")
        tap(pg, "Stock", exact=True)
        pg.wait_for_timeout(1500)
        semantics(pg)
        tap(pg, "Month", exact=True)
        pg.wait_for_timeout(800)
        shot(pg, "17_chart")
        tap(pg, "Sky", exact=True)
        pg.wait_for_timeout(5000)
        shot(pg, "18_sky")
        print("product detail")
        tap(pg, "Chart", exact=True)
        pg.wait_for_timeout(800)
        semantics(pg)
        click_el(pg, pg.locator('flt-semantics[aria-label*="Noodles"]').first)
        pg.wait_for_timeout(1500)
        semantics(pg)
        shot(pg, "19_product")
        check("product shows forecast vs actual", "Was benj right?" in page_text(pg))
        pg.go_back()
        pg.wait_for_timeout(1000)

        print("sparkle")
        semantics(pg)
        tap(pg, "Ask Benj")
        pg.wait_for_timeout(2500)
        semantics(pg)
        tap(pg, "What is running out?")
        pg.wait_for_timeout(1200)
        shot(pg, "20_sparkle")
        pg.mouse.click(W / 2, 40)
        pg.wait_for_timeout(1000)

        print("settings, numbers, team")
        tap(pg, "Home")
        pg.wait_for_timeout(1500)
        semantics(pg)
        tap(pg, "Settings")
        pg.wait_for_timeout(800)
        semantics(pg)
        tap(pg, "My numbers")
        pg.wait_for_timeout(800)
        semantics(pg)
        shot(pg, "21_numbers")
        check("numbers report seconds per log", "Median seconds" in page_text(pg))
        pg.go_back()
        pg.wait_for_timeout(600)
        semantics(pg)
        tap(pg, "Calendar")
        pg.wait_for_timeout(700)
        shot(pg, "22_calendar")
        pg.go_back()
        pg.wait_for_timeout(600)
        semantics(pg)
        tap(pg, "The team behind benj")
        pg.wait_for_timeout(8000)
        shot(pg, "23_team")
        pg.mouse.wheel(0, H)
        pg.wait_for_timeout(7000)
        shot(pg, "24_globe")
        b.close()


if __name__ == "__main__":
    try:
        main()
    finally:
        failed = [n for n, ok in checks if not ok]
        print(f"\nCHECKS: {len(checks) - len(failed)}/{len(checks)} passed", failed)
        print("ERRORS:", json.dumps(errors[:12], indent=1))
