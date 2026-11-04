"""Dev helper: screenshot FX effects in headless Edge (real WebGL through SwiftShader).

python scripts/shot.py OUT_DIR kind[:state] ... [--size 480x640] [--cfg JSON] [--front]
"""
import functools, json, os, shutil, sys, threading
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from playwright.sync_api import sync_playwright

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WEB = os.path.join(ROOT, "web")
args = sys.argv[1:]
out = args.pop(0)
size = (480, 640); cfg = {}; wait = 2500
while "--size" in args:
    i = args.index("--size"); size = tuple(map(int, args[i + 1].split("x"))); del args[i:i + 2]
while "--cfg" in args:
    i = args.index("--cfg"); cfg = json.loads(args[i + 1]); del args[i:i + 2]
while "--wait" in args:
    i = args.index("--wait"); wait = int(args[i + 1]); del args[i:i + 2]
shutil.copy(os.path.join(ROOT, "scripts", "fx_lab.html"), os.path.join(WEB, "_lab.html"))


class Quiet(SimpleHTTPRequestHandler):
    def log_message(self, *a):
        pass


srv = ThreadingHTTPServer(("127.0.0.1", 0), functools.partial(Quiet, directory=WEB))
threading.Thread(target=srv.serve_forever, daemon=True).start()
port = srv.server_address[1]
try:
    with sync_playwright() as p:
        b = p.chromium.launch(channel="msedge", headless=True, args=["--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"])
        pg = b.new_page(viewport={"width": size[0], "height": size[1]})
        pg.on("console", lambda m: print("console:", m.text) if m.type in ("error", "warning") and "GPU stall" not in m.text and "swiftshader" not in m.text.lower() else None)
        pg.on("pageerror", lambda e: print("pageerror:", e))
        for spec in args:
            kind, _, state = spec.partition(":")
            c = dict(cfg)
            pg.goto(f"http://127.0.0.1:{port}/_lab.html?kind={kind}&cfg=" + json.dumps(c))
            pg.wait_for_function("window.ready===true", timeout=60000)
            if state:
                pg.evaluate(f"h.settle ? h.settle('{state}') : h.send({{state:'{state}'}})")
            pg.wait_for_timeout(wait)
            name = spec.replace(":", "_")
            pg.screenshot(path=os.path.join(out, f"fx_{name}.png"))
            print("ok", name)
        b.close()
finally:
    os.remove(os.path.join(WEB, "_lab.html"))
