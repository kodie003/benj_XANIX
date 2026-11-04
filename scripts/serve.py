"""Run the built app locally the way Vercel serves it.

    flutter build web
    python scripts/serve.py [port]      # http://localhost:8000

Static files come from build/web; /api/forecast goes to the same Python handler.
"""

import functools
import os
import sys
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "api"))

from forecast import handler as Engine  # noqa: E402


class Dev(SimpleHTTPRequestHandler):
    _send = Engine._send

    def log_message(self, *args):
        pass

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def do_GET(self):
        return Engine.do_GET(self) if self.path.startswith("/api/forecast") else super().do_GET()

    def do_POST(self):
        return Engine.do_POST(self)

    def do_OPTIONS(self):
        return Engine.do_OPTIONS(self)


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
    print(f"benj at http://localhost:{port}")
    ThreadingHTTPServer(("", port), functools.partial(Dev, directory=os.path.join(ROOT, "build", "web"))).serve_forever()
