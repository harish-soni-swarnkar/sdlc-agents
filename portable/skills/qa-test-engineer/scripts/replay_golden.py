#!/usr/bin/env python3
"""Golden-master record/replay for HTTP APIs — a language-neutral parity oracle.

Record what the OLD system returns, then replay the same requests against the NEW system
and diff. Standard library only, so it runs anywhere Python 3.8+ does, whatever stack the
two systems are written in.

    replay_golden.py record --base-url http://localhost:8080 --cases cases.json --out golden.json
    replay_golden.py replay --base-url http://localhost:8081 --golden golden.json

cases.json (you write it; see cases.example.json):
    {
      "ignore":          {"headers": [...], "json_paths": ["createdAt", "items[*].id"]},
      "compare_headers": ["content-type"],
      "cases": [
        {"name": "list users", "method": "GET", "path": "/users?limit=2"},
        {"name": "create", "method": "POST", "path": "/users",
         "headers": {"content-type": "application/json"}, "body": {"name": "Ada"}},
        {"name": "new error shape", "method": "GET", "path": "/missing",
         "intended_difference": "404 body changed to RFC 7807 — approved in the ledger"}
      ]
    }

Replay compares status, the `compare_headers`, and the body. JSON bodies are compared as
parsed values after removing the `json_paths` to ignore (volatile fields such as timestamps
and generated ids); other bodies are compared as text. A case with `intended_difference`
is reported as INTENDED instead of failing.

Exit codes: 0 = every case matches (or is intended), 1 = at least one divergence,
2 = usage error or a system that couldn't be reached.
"""
import argparse
import copy
import difflib
import json
import re
import sys
import urllib.error
import urllib.request

TIMEOUT = 30


def send(base_url, case):
    """Send one case; return (status, headers, body_text). Error statuses are results too."""
    body = case.get("body")
    data = None
    if body is not None:
        data = (json.dumps(body) if not isinstance(body, str) else body).encode("utf-8")
    req = urllib.request.Request(
        base_url.rstrip("/") + case["path"], data=data,
        method=case.get("method", "GET").upper(), headers=case.get("headers", {}))
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
            return resp.status, dict(resp.headers.items()), resp.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:  # 4xx/5xx — a real response, keep it
        return e.code, dict(e.headers.items()), e.read().decode("utf-8", "replace")


def remove_path(value, parts):
    """Remove a json_path like ['items', '*', 'id'] from a parsed JSON value, in place."""
    if not parts:
        return
    head, rest = parts[0], parts[1:]
    if head == "*" and isinstance(value, list):
        targets = list(range(len(value)))
    elif isinstance(value, list) and head.isdigit():
        targets = [int(head)] if int(head) < len(value) else []
    elif isinstance(value, dict) and head in value:
        targets = [head]
    else:
        return
    for t in targets:
        if rest:
            remove_path(value[t], rest)
        elif isinstance(value, dict):
            del value[t]
        else:
            value[t] = None  # keep list positions stable


def split_path(path):
    path = path[2:] if path.startswith("$.") else path
    return [p for p in re.split(r"\.|\[|\]", path) if p != ""]


def normalize_body(text, ignore_paths):
    try:
        value = json.loads(text)
    except ValueError:
        return ("text", text)
    value = copy.deepcopy(value)
    for p in ignore_paths:
        remove_path(value, split_path(p))
    return ("json", value)


def pick_headers(headers, wanted):
    lower = {k.lower(): v for k, v in headers.items()}
    return {h.lower(): lower.get(h.lower()) for h in wanted}


def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def record(args):
    spec = load(args.cases)
    out = {"ignore": spec.get("ignore", {}), "compare_headers": spec.get("compare_headers", ["content-type"]),
           "recorded_from": args.base_url, "cases": []}
    for case in spec["cases"]:
        status, headers, body = send(args.base_url, case)
        rec = dict(case)
        rec["expected"] = {"status": status, "headers": pick_headers(headers, out["compare_headers"]),
                           "body": body}
        out["cases"].append(rec)
        print(f"recorded  {status}  {case.get('method', 'GET').upper()} {case['path']}  ({case['name']})")
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(out, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print(f"wrote {len(out['cases'])} cases to {args.out}")
    return 0


def describe(kind, value):
    return json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False) if kind == "json" else value


def replay(args):
    golden = load(args.golden)
    ignore_paths = golden.get("ignore", {}).get("json_paths", [])
    ignore_headers = {h.lower() for h in golden.get("ignore", {}).get("headers", [])}
    wanted = [h for h in golden.get("compare_headers", ["content-type"]) if h.lower() not in ignore_headers]
    counts = {"PASS": 0, "FAIL": 0, "INTENDED": 0}
    for case in golden["cases"]:
        exp = case["expected"]
        status, headers, body = send(args.base_url, case)
        problems = []
        if status != exp["status"]:
            problems.append(f"status {exp['status']} → {status}")
        got_h, exp_h = pick_headers(headers, wanted), {h.lower(): exp["headers"].get(h.lower()) for h in wanted}
        for h in wanted:
            if got_h[h.lower()] != exp_h[h.lower()]:
                problems.append(f"header {h}: {exp_h[h.lower()]!r} → {got_h[h.lower()]!r}")
        ek, ev = normalize_body(exp["body"], ignore_paths)
        gk, gv = normalize_body(body, ignore_paths)
        if (ek, ev) != (gk, gv):
            diff = difflib.unified_diff(describe(ek, ev).splitlines(), describe(gk, gv).splitlines(),
                                        "expected (recorded)", "actual (replayed)", lineterm="", n=2)
            problems.append("body differs:\n      " + "\n      ".join(diff))
        label = "PASS" if not problems else ("INTENDED" if case.get("intended_difference") else "FAIL")
        counts[label] += 1
        print(f"{label:8}  {case.get('method', 'GET').upper()} {case['path']}  ({case['name']})")
        if problems and label == "INTENDED":
            print(f"          intended: {case['intended_difference']}")
        for p in problems if label == "FAIL" else []:
            print(f"          {p}")
    print(f"\n{counts['PASS']} pass, {counts['FAIL']} fail, {counts['INTENDED']} intended — "
          f"replayed against {args.base_url}")
    return 1 if counts["FAIL"] else 0


def main():
    ap = argparse.ArgumentParser(description="Golden-master record/replay for HTTP APIs.")
    sub = ap.add_subparsers(dest="cmd", required=True)
    r = sub.add_parser("record", help="send the cases to the OLD system and save its responses")
    r.add_argument("--base-url", required=True)
    r.add_argument("--cases", required=True)
    r.add_argument("--out", required=True)
    p = sub.add_parser("replay", help="send the recorded cases to the NEW system and diff")
    p.add_argument("--base-url", required=True)
    p.add_argument("--golden", required=True)
    args = ap.parse_args()
    try:
        return record(args) if args.cmd == "record" else replay(args)
    except (urllib.error.URLError, OSError) as e:
        print(f"error: couldn't reach {args.base_url}: {e}", file=sys.stderr)
        return 2
    except (KeyError, ValueError) as e:
        print(f"error: bad cases/golden file: {e}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
