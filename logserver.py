#!/usr/bin/env python3
"""Goalline log receiver. The game POSTs batches of events and screenshots here over Wi-Fi.
   Logs: ~/goalline-logs/<session>.jsonl and .log (human readable), shots/<session>_<n>.jpg
"""
import json, os, time, re
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROOT = os.path.expanduser("~/goalline-logs")
os.makedirs(os.path.join(ROOT, "shots"), exist_ok=True)
MAX = 6 * 1024 * 1024
SAFE = re.compile(r"[^A-Za-z0-9_.-]")

def sid_clean(s):
    return SAFE.sub("_", s)[:64] or "unknown"

class H(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def _ok(self, body=b"ok", code=200):
        self.send_response(code)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path.startswith("/ping"):
            return self._ok(b"goalline-log")
        self._ok(b"not found", 404)

    def do_POST(self):
        n = int(self.headers.get("Content-Length", "0"))
        if n <= 0 or n > MAX:
            return self._ok(b"bad size", 413)
        body = self.rfile.read(n)
        if self.path.startswith("/log"):
            try:
                j = json.loads(body)
            except Exception:
                return self._ok(b"bad json", 400)
            sid = sid_clean(str(j.get("sid", "unknown")))
            dev = j.get("device")
            with open(os.path.join(ROOT, sid + ".jsonl"), "a") as f:
                for e in j.get("events", []):
                    f.write(json.dumps(e) + "\n")
            with open(os.path.join(ROOT, sid + ".log"), "a") as f:
                if dev:
                    f.write("DEVICE " + json.dumps(dev) + "\n")
                for e in j.get("events", []):
                    f.write("[%8.1fs] %-14s %s\n" % (e.get("t", 0) / 1000.0, e.get("k", "?"), json.dumps(e.get("d", {}))))
            latest = os.path.join(ROOT, "latest.log")
            try:
                if os.path.islink(latest) or os.path.exists(latest):
                    os.remove(latest)
                os.symlink(os.path.join(ROOT, sid + ".log"), latest)
            except Exception:
                pass
            return self._ok()
        if self.path.startswith("/shot"):
            m = re.search(r"sid=([^&]+)&n=(\d+)", self.path)
            sid = sid_clean(m.group(1)) if m else "unknown"
            k = m.group(2) if m else str(int(time.time()))
            p = os.path.join(ROOT, "shots", "%s_%s.jpg" % (sid, k.zfill(4)))
            with open(p, "wb") as f:
                f.write(body)
            lp = os.path.join(ROOT, "shots", "latest.jpg")
            try:
                if os.path.islink(lp) or os.path.exists(lp):
                    os.remove(lp)
                os.symlink(p, lp)
            except Exception:
                pass
            return self._ok()
        self._ok(b"not found", 404)

if __name__ == "__main__":
    srv = ThreadingHTTPServer(("0.0.0.0", 8799), H)
    print("goalline log server on :8799, writing to", ROOT, flush=True)
    srv.serve_forever()
