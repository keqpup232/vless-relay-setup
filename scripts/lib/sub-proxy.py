#!/usr/bin/env python3
"""Subscription proxy: fetches from 3X-UI and appends CDN VLESS link.

Browser requests (Accept: text/html) are passed through as-is so the
3X-UI subscription page with QR codes works normally.

App requests (no Accept: text/html) get the CDN link appended to the
base64-encoded subscription response.
"""

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
        accept = self.headers.get("Accept", "")
        is_browser = "text/html" in accept

        try:
            headers = {
                "Host": self.headers.get("Host", "localhost"),
                "User-Agent": self.headers.get("User-Agent", ""),
                "Accept": accept,
            }
            req = urllib.request.Request(
                f"{UPSTREAM}{self.path}",
                headers=headers,
            )
            with urllib.request.urlopen(req, timeout=5) as resp:
                body = resp.read()
                ct = resp.headers.get("Content-Type", "text/plain")
        except Exception:
            self.send_error(502, "Upstream unavailable")
            return

        # Browser → pass through HTML as-is (3X-UI subscription page with QR codes)
        if is_browser or b"<!DOCTYPE" in body[:100] or b"<html" in body[:100]:
            self.send_response(200)
            self.send_header("Content-Type", ct)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return

        # App → append CDN link to base64 subscription
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
