#!/usr/bin/env python3
"""End-to-end test of templates/harness/replay_golden.py against two local HTTP servers.

A "source" and a deliberately different "target" run in-process on 127.0.0.1 (random
ports, no network). The test records from the source, replays against the target and
against the source itself, and checks every outcome and exit code. Exit 1 on failure.
"""
import json
import subprocess
import sys
import tempfile
import threading
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HARNESS = ROOT / "templates" / "harness" / "replay_golden.py"


def make_handler(variant):
    class H(BaseHTTPRequestHandler):
        def log_message(self, *a):  # keep test output clean
            pass

        def reply(self, status, body, ctype="application/json"):
            data = (json.dumps(body) if ctype.endswith("json") else body).encode()
            self.send_response(status)
            self.send_header("content-type", ctype)
            self.send_header("x-request-id", str(uuid.uuid4()))
            self.end_headers()
            self.wfile.write(data)

        def do_GET(self):
            p = self.path
            if p == "/users":  # volatile id + timestamp differ on every call (ignored)
                self.reply(200, {"items": [{"id": str(uuid.uuid4()), "name": "ada"}], "createdAt": str(uuid.uuid4())})
            elif p == "/price":
                self.reply(200, {"amount": 10 if variant == "source" else 11})
            elif p == "/text":
                self.reply(200, "hello", "text/plain")
            elif p == "/missing":
                body = {"error": "nope"} if variant == "source" else {"type": "about:blank", "title": "Not Found"}
                self.reply(404, body)
            elif p == "/ctype":
                self.reply(200, {"ok": True}, "application/json" if variant == "source" else "text/json")
            else:
                self.reply(404, {"error": "no route"})

        def do_POST(self):
            n = int(self.headers.get("content-length", 0))
            payload = json.loads(self.rfile.read(n) or b"{}")
            if variant == "source":
                self.reply(201, {"echo": payload})
            else:
                self.reply(500, {"error": "boom"})
    return H


def serve(variant):
    srv = ThreadingHTTPServer(("127.0.0.1", 0), make_handler(variant))
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    return srv, f"http://127.0.0.1:{srv.server_address[1]}"


def run(*args):
    r = subprocess.run([sys.executable, str(HARNESS), *args], capture_output=True, text=True)
    return r.returncode, r.stdout + r.stderr


def labels(output):
    out = {}
    for line in output.splitlines():
        parts = line.split()
        if parts and parts[0] in ("PASS", "FAIL", "INTENDED"):
            out[line[line.index("(") + 1:line.rindex(")")]] = parts[0]
    return out


failures = []


def check(cond, msg):
    if not cond:
        failures.append(msg)


src, src_url = serve("source")
tgt, tgt_url = serve("target")
with tempfile.TemporaryDirectory() as tmp:
    cases = Path(tmp) / "cases.json"
    golden = Path(tmp) / "golden.json"
    cases.write_text(json.dumps({
        "ignore": {"headers": ["x-request-id"], "json_paths": ["createdAt", "items[*].id"]},
        "compare_headers": ["content-type"],
        "cases": [
            {"name": "users", "method": "GET", "path": "/users"},
            {"name": "price", "method": "GET", "path": "/price"},
            {"name": "text", "method": "GET", "path": "/text"},
            {"name": "missing", "method": "GET", "path": "/missing",
             "intended_difference": "error body moves to problem+json"},
            {"name": "ctype", "method": "GET", "path": "/ctype"},
            {"name": "echo", "method": "POST", "path": "/echo",
             "headers": {"content-type": "application/json"}, "body": {"x": 1}},
        ]}))

    code, out = run("record", "--base-url", src_url, "--cases", str(cases), "--out", str(golden))
    check(code == 0, f"record exit {code}\n{out}")
    check(json.loads(golden.read_text())["cases"][3]["expected"]["status"] == 404,
          "record must keep error responses (404)")

    code, out = run("replay", "--base-url", tgt_url, "--golden", str(golden))
    got = labels(out)
    check(code == 1, f"replay vs a divergent target must exit 1, got {code}")
    expected = {"users": "PASS", "text": "PASS", "price": "FAIL", "echo": "FAIL",
                "ctype": "FAIL", "missing": "INTENDED"}
    check(got == expected, f"replay vs target outcomes:\n  expected {expected}\n  got      {got}\n{out}")
    check("status 201 → 500" in out, "status divergence must be reported")
    check("header content-type" in out, "header divergence must be reported")

    code, out = run("replay", "--base-url", src_url, "--golden", str(golden))
    check(code == 0, f"replay vs the source itself must exit 0 (volatile fields ignored), got {code}\n{out}")
    check(set(labels(out).values()) == {"PASS"}, f"replay vs source must be all PASS:\n{out}")

    code, out = run("replay", "--base-url", "http://127.0.0.1:9", "--golden", str(golden))
    check(code == 2, f"unreachable system must exit 2, got {code}")

src.shutdown()
tgt.shutdown()
if failures:
    print("harness tests FAILED:")
    for f in failures:
        print("  - " + f)
    sys.exit(1)
print("harness tests: record, replay (pass/fail/intended), self-replay, unreachable — all passed")
