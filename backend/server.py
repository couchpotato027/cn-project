#!/usr/bin/env python3
"""
CN Project - Task C: a deliberately tiny HTTP/REST backend.

The same file runs as Backend A and Backend B; only --name and --port differ:
    python3 backend/server.py --name A --port 3001
    python3 backend/server.py --name B --port 3002

Endpoints
    GET /            JSON "service is running" page            (Cache-Control: no-store)
    GET /api/status  {"backend": "A", "status": "ok", ...}     (Cache-Control: no-store)
    GET /api/data    static catalogue used for the caching demo (Task F)
                     Cache-Control: public, max-age=60 + ETag; answers
                     If-None-Match with 304 Not Modified.
    HEAD on any of the above (curl -I sends HEAD).

Every response, including 304 and 404, carries "X-Backend: A|B" so the
load-balancing demo can show which backend served the request.

Only the Python standard library is used - nothing to install.
"""
import argparse
import hashlib
import json
import socket
import sys
import time
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

# Static payload for the caching demo. It is IDENTICAL on Backend A and B, so
# its ETag is identical too - a 304 works no matter which backend the load
# balancer picks for the revalidation request.
CATALOGUE = {
    "resource": "course-catalogue",
    "version": 1,
    "items": [
        {"id": 1, "topic": "DNS", "layer": "Application"},
        {"id": 2, "topic": "TLS", "layer": "Session/Presentation (between TCP and HTTP)"},
        {"id": 3, "topic": "TCP", "layer": "Transport"},
        {"id": 4, "topic": "IP", "layer": "Network"},
        {"id": 5, "topic": "Ethernet / Wi-Fi", "layer": "Link"},
    ],
}
CATALOGUE_BODY = json.dumps(CATALOGUE, indent=2).encode() + b"\n"
CATALOGUE_ETAG = '"' + hashlib.sha256(CATALOGUE_BODY).hexdigest()[:16] + '"'
CATALOGUE_MAX_AGE = 60


def make_handler(name: str, port: int):
    started = time.time()
    hostname = socket.gethostname()

    class Handler(BaseHTTPRequestHandler):
        server_version = f"cn-backend-{name}"
        sys_version = ""

        # ---------- helpers ----------
        def _send(self, status, body=b"", content_type="application/json",
                  extra_headers=None, head_only=False):
            self.send_response(status)
            self.send_header("X-Backend", name)
            self.send_header("Content-Type", content_type)
            for key, value in (extra_headers or {}).items():
                self.send_header(key, value)
            if status != 304:
                self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            if body and not head_only and status != 304:
                self.wfile.write(body)

        def _json(self, status, obj, head_only, extra_headers=None):
            headers = {"Cache-Control": "no-store"}
            headers.update(extra_headers or {})
            body = json.dumps(obj, indent=2).encode() + b"\n"
            self._send(status, body, extra_headers=headers, head_only=head_only)

        # ---------- routing ----------
        def _route(self, head_only=False):
            path = self.path.split("?", 1)[0]

            if path == "/":
                self._json(200, {
                    "service": "CN Project private service",
                    "message": f"Backend {name} is running",
                    "backend": name,
                    "try": ["/api/status", "/api/data"],
                }, head_only)

            elif path == "/api/status":
                self._json(200, {
                    "backend": name,
                    "status": "ok",
                    "port": port,
                    "host": hostname,
                    "uptime_seconds": round(time.time() - started, 1),
                    "time": datetime.now(timezone.utc).isoformat(timespec="seconds"),
                    # What the backend sees as its client. Behind nginx this is
                    # the EDGE's address, not the real client - the real client
                    # only arrives in the X-Forwarded-For header.
                    "seen_peer": f"{self.client_address[0]}:{self.client_address[1]}",
                    "x_forwarded_for": self.headers.get("X-Forwarded-For"),
                }, head_only)

            elif path == "/api/data":
                cache_headers = {
                    "Cache-Control": f"public, max-age={CATALOGUE_MAX_AGE}",
                    "ETag": CATALOGUE_ETAG,
                }
                inm = self.headers.get("If-None-Match", "")
                tags = [t.strip() for t in inm.split(",") if t.strip()]
                if CATALOGUE_ETAG in tags or "*" in tags:
                    # Conditional request and nothing changed: headers only.
                    self._send(304, extra_headers=cache_headers)
                else:
                    self._send(200, CATALOGUE_BODY, extra_headers=cache_headers,
                               head_only=head_only)

            else:
                self._json(404, {"error": "not found", "path": path,
                                 "backend": name}, head_only)

        def do_GET(self):
            self._route()

        def do_HEAD(self):
            self._route(head_only=True)

        def log_message(self, fmt, *args):
            # One line per request: who connected (TCP peer) and who the
            # original client was (X-Forwarded-For set by nginx).
            xff = self.headers.get("X-Forwarded-For", "-") if hasattr(self, "headers") else "-"
            sys.stderr.write(
                f"[{datetime.now().strftime('%H:%M:%S')}] backend={name} "
                f"peer={self.client_address[0]}:{self.client_address[1]} "
                f"xff={xff} {fmt % args}\n"
            )

    return Handler


def main():
    parser = argparse.ArgumentParser(description="CN Project backend")
    parser.add_argument("--name", required=True, help="Backend identifier, e.g. A or B")
    parser.add_argument("--port", type=int, required=True)
    # 0.0.0.0 = every interface, including the LAN one. Binding to 127.0.0.1
    # would make the backend unreachable from other machines (Task C rule).
    parser.add_argument("--host", default="0.0.0.0")
    args = parser.parse_args()

    server = ThreadingHTTPServer((args.host, args.port), make_handler(args.name, args.port))
    print(f"Backend {args.name} listening on {args.host}:{args.port}  (Ctrl+C to stop)",
          flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print(f"\nBackend {args.name} stopped.")


if __name__ == "__main__":
    main()
