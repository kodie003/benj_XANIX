"""Run the app locally exactly as Vercel serves it.

    flutter build web
    python scripts/dev_server.py        # then open http://localhost:8000

Static files come from build/web; /api/insights goes to the same Python
handler Vercel runs, so what works here works on the deployment.
"""

import functools
import os
import sys
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "api"))

from insights import handler as InsightsHandler  # noqa: E402


class DevHandler(SimpleHTTPRequestHandler):
    def _api(self):
        return self.path.startswith("/api/insights")

    def do_GET(self):
        if self._api():
            return InsightsHandler.do_GET(self)
        return super().do_GET()

    def do_POST(self):
        return InsightsHandler.do_POST(self)

    def do_OPTIONS(self):
        return InsightsHandler.do_OPTIONS(self)

    _send = InsightsHandler._send


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
    serve = functools.partial(DevHandler, directory=os.path.join(ROOT, "build", "web"))
    print(f"SeeYou running at http://localhost:{port}")
    ThreadingHTTPServer(("", port), serve).serve_forever()
