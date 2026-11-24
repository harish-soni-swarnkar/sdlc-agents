#!/usr/bin/env python3
"""Check every portable skill against the Agent Skills spec (agentskills.io/specification)
and against what this edition promises: no Claude Code-only constructs, and every skill a
skill refers to actually exists in the set. Exit 1 on any failure.

    python3 portable/validate.py
"""
import json
import re
import sys
from pathlib import Path

SKILLS = Path(__file__).resolve().parent / "skills"
ALLOWED_KEYS = {"name", "description", "license", "compatibility", "metadata", "allowed-tools"}
NAME_RE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")  # lowercase alnum + single hyphens
CLAUDE_ONLY = [
    "agent tool", "task tool", "subagent", "sub-agent", "$arguments", "disable-model-invocation",
    "argument-hint", "claude_plugin_root", "claude_project_dir", "claude_code_",
    "claude --worktree", "nesting", "main thread", "sdlc-agents:", "isolated context",
    "worktree session",
]
errors = []


def err(skill, msg):
    errors.append(f"{skill}: {msg}")


def frontmatter(text):
    m = re.match(r"\A---\n(.*?)\n---\n", text, re.S)
    if not m:
        return None, text
    data, current = {}, None
    for line in m.group(1).splitlines():
        if line.startswith("  ") and current == "metadata":
            k, _, v = line.strip().partition(": ")
            data["metadata"][k] = json.loads(v) if v.startswith('"') else v
            continue
        k, _, v = line.partition(":")
        v = v.strip()
        current = k
        if k == "metadata" and v == "":
            data["metadata"] = {}
        else:
            data[k] = json.loads(v) if v.startswith('"') else v
    return data, text[m.end():]


names = sorted(p.name for p in SKILLS.iterdir() if p.is_dir())
for name in names:
    path = SKILLS / name / "SKILL.md"
    if not path.exists():
        err(name, "missing SKILL.md")
        continue
    text = path.read_text(encoding="utf-8")
    fm, body = frontmatter(text)
    if fm is None:
        err(name, "no frontmatter")
        continue
    extra = set(fm) - ALLOWED_KEYS
    if extra:
        err(name, f"non-standard frontmatter keys: {sorted(extra)}")
    n = fm.get("name", "")
    if not (1 <= len(n) <= 64 and NAME_RE.match(n)):
        err(name, f"invalid name {n!r} (1-64 chars, lowercase a-z/0-9, single hyphens)")
    if n != name:
        err(name, f"name {n!r} must match its folder name")
    d = fm.get("description", "")
    if not (1 <= len(d) <= 1024):
        err(name, f"description must be 1-1024 chars (is {len(d)})")
    if len(fm.get("compatibility", "")) > 500:
        err(name, "compatibility over 500 chars")
    md = fm.get("metadata", {})
    if not isinstance(md, dict) or not all(isinstance(v, str) for v in md.values()):
        err(name, "metadata must be a string-to-string map")
    lines = text.count("\n") + 1
    if lines >= 500:
        err(name, f"SKILL.md is {lines} lines (spec recommends under 500)")
    low = text.lower()
    for token in CLAUDE_ONLY:
        if token in low:
            err(name, f"contains Claude Code-only construct {token!r}")
    for ref in set(re.findall(r"`([a-z0-9-]+)` skill", body)):
        if ref not in names:
            err(name, f"refers to a `{ref}` skill that isn't in the set")

route = (SKILLS / "route" / "SKILL.md").read_text(encoding="utf-8")
for n in names:
    if n not in ("route", "engineering-rules") and f"`{n}`" not in route:
        err("route", f"routing map doesn't name `{n}`")
if not (SKILLS.parent / "AGENTS.md").exists():
    errors.append("AGENTS.md: missing")

if errors:
    print(f"portable validation FAILED ({len(errors)}):")
    for e in errors:
        print("  " + e)
    sys.exit(1)
print(f"portable validation passed: {len(names)} skills, spec-compliant, no Claude-only constructs")
