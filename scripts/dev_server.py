"""Run the app locally exactly as Vercel serves it.

    flutter build web
    python scripts/dev_server.py        # then open http://localhost:8000

Static files come from build/web; /api/forecast and /api/accounts go to the same
Python handlers Vercel runs, so what works here works on the deployment.
"""

import functools
import os
import sys
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "api"))

import accounts  # noqa: E402
import forecast  # noqa: E402


class DevHandler(SimpleHTTPRequestHandler):
    def _api(self):
        if self.path.startswith("/api/accounts"):
            return accounts.handler
        if self.path.startswith("/api/forecast"):
            return forecast.handler
        return None

    def do_GET(self):
        api = self._api()
        return api.do_GET(self) if api else super().do_GET()

    def do_POST(self):
        api = self._api()
        if not api:
            self.send_error(404)
            return
        self._send = api._send.__get__(self)
        return api.do_POST(self)

    def do_OPTIONS(self):
        api = self._api()
        return api.do_OPTIONS(self) if api else super().do_OPTIONS()

    def _send(self, status, body):  # replaced per request by the matching API's _send
        return forecast.handler._send(self, status, body)


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
    serve = functools.partial(DevHandler, directory=os.path.join(ROOT, "build", "web"))
    print(f"benj running at http://localhost:{port}")
    ThreadingHTTPServer(("", port), serve).serve_forever()
