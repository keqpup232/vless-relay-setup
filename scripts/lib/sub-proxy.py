#!/usr/bin/env python3
"""Subscription proxy: fetches from 3X-UI and appends CDN VLESS link."""

import http.server
import urllib.request
import base64
import os
import sys

UPSTREAM = os.environ.get("SUB_UPSTREAM", "http://127.0.0.1:8443")
CDN_LINK = os.environ.get("CDN_VLESS_LINK", "")
LISTEN_PORT = int(os.environ.get("SUB_PROXY_PORT", "18443"))


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        try:
            req = urllib.request.Request(
                f"{UPSTREAM}{self.path}",
                headers={"Host": self.headers.get("Host", "localhost")},
            )
            with urllib.request.urlopen(req, timeout=5) as resp:
                body = resp.read()
        except Exception:
            self.send_error(502, "Upstream unavailable")
            return

        if CDN_LINK:
            try:
                decoded = base64.b64decode(body).decode("utf-8", errors="replace")
                combined = decoded.rstrip("\n") + "\n" + CDN_LINK + "\n"
                body = base64.b64encode(combined.encode()).rstrip(b"=")
            except Exception:
                pass  # non-base64 response, return as-is

        self.send_response(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body if isinstance(body, bytes) else body.encode())

    def log_message(self, fmt, *args):
        pass  # silent


if __name__ == "__main__":
    server = http.server.HTTPServer(("127.0.0.1", LISTEN_PORT), Handler)
    print(f"sub-proxy listening on 127.0.0.1:{LISTEN_PORT} -> {UPSTREAM}")
    sys.stdout.flush()
    server.serve_forever()
