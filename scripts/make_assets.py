"""Renders the app icons, the mascot stills and the mascot's .glb from the code-built model.

    python scripts/make_assets.py
"""
import base64
import functools
import os
import shutil
import threading
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

from playwright.sync_api import sync_playwright

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WEB = os.path.join(ROOT, "web")


class Quiet(SimpleHTTPRequestHandler):
    def log_message(self, *a):
        pass


LOGO_PAGE = """<!doctype html><meta charset=utf-8><style>html,body{margin:0;background:#080B18}</style>
<canvas id=c></canvas><script type=module>
import {drawLogo} from './fx/glsl.js';
window.draw=(S,pad,round)=>{const c=document.getElementById('c');c.width=c.height=S;const g=c.getContext('2d');
g.clearRect(0,0,S,S);g.fillStyle='#080B18';if(round){g.beginPath();g.roundRect(0,0,S,S,S*.22);g.fill();}else g.fillRect(0,0,S,S);
const i=S*(1-pad*2);g.save();g.translate(S*pad,S*pad);const gr=g.createLinearGradient(0,0,0,i);gr.addColorStop(0,'#FFD36B');gr.addColorStop(1,'#FFB627');g.fillStyle=gr;g.strokeStyle=gr;drawLogo(g,i);g.restore();return c.toDataURL('image/png')};
window.ready=true;
</script>"""

shutil.copy(os.path.join(ROOT, "scripts", "fx_lab.html"), os.path.join(WEB, "_lab.html"))
with open(os.path.join(WEB, "_logo.html"), "w") as f:
    f.write(LOGO_PAGE)
shutil.copy(os.path.join(ROOT, "scripts", "GLTFExporter.mjs"), os.path.join(WEB, "fx", "_exporter.js"))
srv = ThreadingHTTPServer(("127.0.0.1", 0), functools.partial(Quiet, directory=WEB))
threading.Thread(target=srv.serve_forever, daemon=True).start()
port = srv.server_address[1]


def save(data_url, path):
    with open(path, "wb") as f:
        f.write(base64.b64decode(data_url.split(",", 1)[1]))
    print("wrote", os.path.relpath(path, ROOT))


try:
    with sync_playwright() as p:
        b = p.chromium.launch(channel="msedge", headless=True, args=["--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"])
        pg = b.new_page(viewport={"width": 700, "height": 700})
        pg.on("pageerror", lambda e: print("pageerror", e))
        pg.goto(f"http://127.0.0.1:{port}/_logo.html")
        pg.wait_for_function("window.ready===true")
        save(pg.evaluate("draw(32,.08,true)"), os.path.join(WEB, "favicon.png"))
        for name, size, pad, rnd in [("Icon-192", 192, 0.1, False), ("Icon-512", 512, 0.1, False), ("Icon-maskable-192", 192, 0.2, False), ("Icon-maskable-512", 512, 0.2, False)]:
            save(pg.evaluate(f"draw({size},{pad},{str(rnd).lower()})"), os.path.join(WEB, "icons", f"{name}.png"))
        # Android launcher icons, same mark.
        for folder, size in [("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)]:
            save(pg.evaluate(f"draw({size},.12,false)"), os.path.join(ROOT, "android", "app", "src", "main", "res", f"mipmap-{folder}", "ic_launcher.png"))

        # Stills for phones without WebGL, transparent background.
        os.makedirs(os.path.join(ROOT, "assets"), exist_ok=True)
        for framing, state in [("full", "wave"), ("bust", "idle")]:
            pg.goto(f'http://127.0.0.1:{port}/_lab.html?kind=mascot&cfg={{"framing":"{framing}","maxDpr":1}}')
            pg.wait_for_function("window.ready===true", timeout=60000)
            url = pg.evaluate(f"(() => {{ h.settle('{state}'); return h.renderer.domElement.toDataURL('image/png'); }})()")
            save(url, os.path.join(ROOT, "assets", f"mascot_{framing}.png"))

        # The same model as a standard 3D file: Blender, flutter_scene, three.js, Rive's importer.
        pg.goto(f'http://127.0.0.1:{port}/_lab.html?kind=mascot&cfg={{"framing":"full"}}')
        pg.wait_for_function("window.ready===true", timeout=60000)
        glb = pg.evaluate("""async () => {
            const { GLTFExporter } = await import('./fx/_exporter.js');
            h.settle('idle');
            const buf = await new GLTFExporter().parseAsync(h.root, { binary: true });
            let s = ''; const u = new Uint8Array(buf); for (let i = 0; i < u.length; i += 8192) s += String.fromCharCode(...u.subarray(i, i + 8192));
            return btoa(s);
        }""")
        with open(os.path.join(WEB, "fx", "benj.glb"), "wb") as f:
            f.write(base64.b64decode(glb))
        print("wrote web/fx/benj.glb", os.path.getsize(os.path.join(WEB, "fx", "benj.glb")))
        b.close()
finally:
    for f in [os.path.join(WEB, "_lab.html"), os.path.join(WEB, "_logo.html"), os.path.join(WEB, "fx", "_exporter.js")]:
        if os.path.exists(f):
            os.remove(f)
