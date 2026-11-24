#!/usr/bin/env python3
"""Build the cross-tool edition (Agent Skills open standard) from the Claude Code agents.

agents/*.md is the single source of truth. Each agent becomes a standard-only skill at
portable/skills/<name>/SKILL.md: frontmatter limited to the spec's fields (name,
description, license, compatibility, metadata), and every Claude Code-only passage
(subagent delegation, nesting depth, `claude --worktree`) rewritten into instructions any
agent can follow. global/CLAUDE.md becomes portable/AGENTS.md.

Every rewrite asserts that the text it replaces occurs exactly once. If an agent is edited
so a rewrite no longer matches, the build stops with an error instead of shipping a stale
or half-converted skill — update the rewrite below to match the new text.

    python3 portable/build.py           # regenerate portable/skills and portable/AGENTS.md
    python3 portable/build.py --check   # exit 1 if the committed output is out of date
"""
import json
import re
import shutil
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
AGENTS = ROOT / "agents"
OUT = ROOT / "portable"

# Claude Code edition: these coordinate other agents.
ORCHESTRATORS = {"route", "pr-ready", "review-gate", "design-gate", "hardening-gate",
                 "production-gate", "ship-it", "takehome-runner", "fix-loop",
                 "migrate-stack", "upgrade-runtime"}
# Claude Code edition: these have no edit tools. Portably that can only be an instruction.
REVIEW_ONLY = {"pr-ready", "review-gate", "design-gate", "hardening-gate",
               "production-gate", "parity-gate", "senior-auditor", "security-reviewer"}

ORCH_NOTE = ("> **Portable edition.** This skill coordinates other skills from the same set: "
             "apply each named skill yourself, one after another, as a distinct pass, and keep "
             "each pass's findings separate until you merge them.")
RO_NOTE = ("> **Review-only.** Don't create, edit, or delete files while applying this skill — "
           "report findings; fixes go through the `fix-loop` skill.")

COMPATIBILITY = ("Agent Skills open standard (agentskills.io). Part of the sdlc-agents portable "
                 "set: install the whole set, since skills refer to each other by name. Uses "
                 "git and the project's own build/test tooling.")

# Exact rewrites of Claude Code-only passages, per agent: (old, new). Applied before the
# generic rewrites below, against the agent's original text.
REWRITES = {
    "design-gate": [(
        "2. Dispatch both lenses (Agent tool: senior-architect, security-reviewer) on the\n"
        "   same design + requirements. Fallback: run both inline in sequence, say so.",
        "2. Apply both lenses yourself, one after another, on the same design + requirements:\n"
        "   the `senior-architect` skill, then the `security-reviewer` skill.")],
    "hardening-gate": [(
        "2. Dispatch both lenses (Agent tool: security-reviewer, sre-reliability) on the same\n"
        "   target. Fallback: run both inline in sequence, say so.",
        "2. Apply both lenses yourself, one after another, on the same target: the\n"
        "   `security-reviewer` skill, then the `sre-reliability` skill.")],
    "pr-ready": [(
        "2. Dispatch both lenses (Agent tool: senior-auditor, qa-test-engineer) scoped to the\n"
        "   diff, asking for a FAST focused pass — top issues only, not exhaustive. Fallback:\n"
        "   run both inline, say so.",
        "2. Apply both lenses yourself, scoped to the diff, as FAST focused passes — top issues\n"
        "   only, not exhaustive: the `senior-auditor` skill, then the `qa-test-engineer` skill.")],
    "review-gate": [
        ("2. Dispatch the three lenses on the SAME target and contract. Use the Agent tool:\n"
         "   subagent_type \"senior-auditor\", then \"security-reviewer\", then \"qa-test-engineer\"\n"
         "   (run them one after another by default; they're independent, so you may run them\n"
         "   concurrently for speed if the user is waiting). Pass each the same target +\n"
         "   contract so results are comparable.\n"
         "   - Fallback: if delegating to sub-agents isn't available in this environment,\n"
         "     perform all three reviews yourself, in sequence, applying each agent's own\n"
         "     method and rules (quality lens, security lens, QA lens) as distinct passes —\n"
         "     and say you ran them inline rather than via sub-agents.",
         "2. Apply the three lenses yourself on the SAME target and contract, one after another,\n"
         "   as distinct passes: the `senior-auditor` skill (quality), then the\n"
         "   `security-reviewer` skill (security), then the `qa-test-engineer` skill\n"
         "   (adversarial QA). Keep each lens's findings separate so they stay comparable."),
        ("The three sub-agents remain individually runnable.",
         "The three lens skills remain individually usable."),
    ],
    "production-gate": [(
        "2. Dispatch the five lenses via the Agent tool on the same target + context. Run them\n"
        "   one after another by default; may run concurrently if the user is waiting.\n"
        "   Fallback: run each lens inline in sequence and say so.",
        "2. Apply the five lenses yourself, one after another, on the same target + context —\n"
        "   each lens's skill as a distinct pass.")],
    "fix-loop": [(
        "- Dispatch via the Agent tool: review-gate for the gate, senior-builder for the\n"
        "  fixes. Fallback: run the gate's three lenses and the fixes inline in sequence, and\n"
        "  say so.",
        "- Apply the `review-gate` skill for the gate and the `senior-builder` skill for the\n"
        "  fixes, yourself, in sequence.")],
    "ship-it": [(
        "- Dispatch each phase via the Agent tool (subagent_type = the phase's agent),\n"
        "  passing forward the previous phase's output plus the original brief/rubric.\n"
        "- Fallback: if sub-agent nesting isn't available, perform each phase inline in\n"
        "  sequence applying that agent's method, and say you ran it inline.",
        "- Run each phase yourself by applying that phase's skill, in order, passing forward\n"
        "  the previous phase's output plus the original brief/rubric.")],
    "takehome-runner": [(
        "- Dispatch each phase via the Agent tool; fallback to inline sequential passes if\n"
        "  nesting isn't available, and say so.",
        "- Run each phase yourself by applying that phase's skill, in order.")],
    "migrate-stack": [
        ("- Delegate via the Agent tool: qa-test-engineer (golden tests), senior-architect (target\n"
         "  design), senior-builder (port), data-engineer (data migration), refactorer (strangler\n"
         "  mechanics), parity-gate (prove behavioral parity), review-gate/production-gate (verify\n"
         "  quality). Fallback: perform the phases inline in\n"
         "  sequence and say so.",
         "- Apply the phase skills yourself, in order: `qa-test-engineer` (golden tests),\n"
         "  `senior-architect` (target design), `senior-builder` (port), `data-engineer` (data\n"
         "  migration), `refactorer` (strangler mechanics), `parity-gate` (prove behavioral\n"
         "  parity), `review-gate` / `production-gate` (verify quality)."),
        ("so downstream\n  gates running in isolated contexts find what upstream did.",
         "so downstream\n  gates and later sessions find what upstream did."),
        ("Prefer running the port in a worktree session (`claude --worktree <name>`):\n"
         "  the main conversation and every subagent then work on one known branch\n"
         "  (`worktree-<name>`) that is merged normally.",
         "Prefer running the port in an isolated git worktree (e.g. `git worktree add\n"
         "  ../<repo>-port -b port/<name>`, copying in gitignored files such as `.env` that the\n"
         "  app needs), so the whole port lives on one known branch that is merged normally."),
        (" — e.g. the /migrate skill already ran it", ""),
    ],
    "upgrade-runtime": [
        ("running the whole upgrade in a worktree session (`claude --worktree <name>`) — everything lands on branch\n"
         "`worktree-<name>`, which is merged normally, and `.worktreeinclude` brings over `.env` and\n"
         "similar files — so a broken dependency never dirties the main tree.",
         "running the whole upgrade in an isolated git worktree (e.g. `git worktree add\n"
         "../<repo>-upgrade -b upgrade/<version>`, copying in gitignored files such as `.env` that the\n"
         "app needs) — so a broken dependency never dirties the main tree."),
        ("- Prefer a worktree session (`claude --worktree <name>`) for the upgrade;",
         "- Prefer an isolated git worktree for the upgrade;"),
        ("downstream gates in isolated contexts resume with",
         "downstream gates and later sessions resume with"),
    ],
    "parity-gate": [(
        "delegate its creation to qa-test-engineer first",
        "create it first with the `qa-test-engineer` skill")],
    "route": [
        ("5. Offer to run it: \"Say go and the main session will run this sequence; or take any step\n"
         "   yourself.\" On yes, prefer running the steps from the MAIN thread — each agent invoked in\n"
         "   order, stopping at the gates' verdicts. Subagent nesting works but is bounded (~3 layers\n"
         "   deep by default, via CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH), and a deep pipeline (an\n"
         "   orchestrator → a gate → its lenses) can exhaust that depth — so hand multi-step chains to\n"
         "   the main thread rather than nesting them from inside this router. You may run a single\n"
         "   specialist step inline; a delegated step that can't spawn its own children at this depth\n"
         "   falls back to running that phase inline. On no, leave them the plan.",
         "5. Offer to run it: \"Say go and I'll run this sequence; or take any step yourself.\" On\n"
         "   yes, apply each skill in order yourself, stopping at the gates' verdicts. On no, leave\n"
         "   them the plan."),
        ("- Mind the nesting depth — subagents can spawn subagents, but only ~3 layers deep by\n"
         "  default (configurable); a deep pipeline can hit that limit, so prefer main-thread\n"
         "  execution for multi-step chains and let deep steps fall back to inline. Nesting is\n"
         "  limited, not impossible.\n",
         ""),
    ],
}

SKILL_REWRITES = {
    "engineering-rules": [(
        "(In non-plugin installs these same\nrules live always-on in `~/.claude/CLAUDE.md`; here they ship as a skill.)",
        "(The same rules ship as\n`AGENTS.md` for tools that load it always-on; this skill is the on-demand copy.)")],
}


def parse(path):
    """Split a frontmatter file; values are plain or JSON-style double-quoted strings."""
    text = path.read_text(encoding="utf-8")
    m = re.match(r"\A---\n(.*?)\n---\n", text, re.S)
    if not m:
        sys.exit(f"build: {path} has no frontmatter")
    fm = {}
    for line in m.group(1).splitlines():
        k, _, v = line.partition(": ")
        fm[k.strip()] = json.loads(v) if v.startswith('"') else v.strip()
    return fm, text[m.end():]


def apply_exact(text, pairs, where):
    for old, new in pairs:
        n = text.count(old)
        if n != 1:
            sys.exit(f"build: rewrite for {where} matched {n} times (expected 1):\n  {old[:90]!r}\n"
                     f"The source changed — update REWRITES in portable/build.py.")
        text = text.replace(old, new)
    return text


def generic(text, names, name):
    # "(delegate to X" -> "(apply the `X` skill"; the source wraps some of these across lines.
    text = re.sub(r"\(delegate to\s+([a-z][a-z-]*)", r"(apply the `\1` skill", text)
    # "the senior-builder agent" -> "the `senior-builder` skill"
    for n in names:
        text = re.sub(rf"`?\b{re.escape(n)}\b`? agent\b", f"`{n}` skill", text)
    if name == "route":
        text = re.sub(r"\bagent\(s\)", "skill(s)", text)
        text = re.sub(r"\bagents\b", "skills", text)
        text = re.sub(r"\bagent\b", "skill", text)
    return text


def skill_file(name, description, body, source):
    fm = ["---", f"name: {name}", f"description: {json.dumps(description, ensure_ascii=False)}",
          "license: MIT", f"compatibility: {json.dumps(COMPATIBILITY)}", "metadata:",
          f"  source: {json.dumps(source)}", '  edition: "portable"', "---", ""]
    notes = []
    if name in ORCHESTRATORS:
        notes.append(ORCH_NOTE)
    if name in REVIEW_ONLY:
        notes.append(RO_NOTE)
    head = ("\n\n".join(notes) + "\n\n") if notes else ""
    return "\n".join(fm) + head + body.lstrip("\n")


def build(dest):
    skills = dest / "skills"
    skills.mkdir(parents=True)
    names = sorted(p.stem for p in AGENTS.glob("*.md"))
    for name in names:
        fm, body = parse(AGENTS / f"{name}.md")
        if fm.get("name") != name:
            sys.exit(f"build: agents/{name}.md frontmatter name is {fm.get('name')!r}")
        desc = fm["description"]
        if name in REWRITES:
            joined = apply_exact(desc + "\n\x00\n" + body, REWRITES[name], name)
            desc, body = joined.split("\n\x00\n", 1)
        desc, body = generic(desc, names, name), generic(body, names, name)
        (skills / name).mkdir()
        (skills / name / "SKILL.md").write_text(
            skill_file(name, desc, body, f"agents/{name}.md"), encoding="utf-8")

    # engineering-rules: the one Claude skill that is already pure instructions.
    fm, body = parse(ROOT / "skills" / "engineering-rules" / "SKILL.md")
    body = apply_exact(body, SKILL_REWRITES["engineering-rules"], "engineering-rules")
    (skills / "engineering-rules").mkdir()
    (skills / "engineering-rules" / "SKILL.md").write_text(
        skill_file("engineering-rules", fm["description"], body,
                   "skills/engineering-rules/SKILL.md"), encoding="utf-8")

    # AGENTS.md: the always-on rules for tools that read it.
    rules = (ROOT / "global" / "CLAUDE.md").read_text(encoding="utf-8")
    rules = apply_exact(rules, [(
        "These are enforced by the SDLC agent crew in `~/.claude/agents/` (writers apply them,\n"
        "the auditor checks them). See `~/.claude/agents/README.md`.",
        "These rules come from the sdlc-agents portable edition. Its skills apply them (start\n"
        "with the `route` skill if you're unsure which skill fits a task).")], "AGENTS.md")
    (dest / "AGENTS.md").write_text(
        rules.rstrip("\n") + "\n\n" + SAFETY, encoding="utf-8")


SAFETY = """## Safety rules (always)
Other tools can't enforce these with hooks the way the Claude Code edition does, so follow
them as rules:
- Never read, print, search, or copy the contents of secret files (`.env`, `.env.*` other
  than `.env.example`, `*.pem`, `*.key`, `id_rsa`, `~/.ssh/`, `~/.aws/credentials`,
  `secrets/`). Refer to a key by name, never by value.
- Never force-push (`git push --force` / `-f`); use `--force-with-lease` only when asked.
- Never run a recursive delete on a root, home, or wildcard target, and never run
  destructive SQL (DROP / TRUNCATE) or database resets — write a reviewed migration with a
  rollback instead.
- Never edit an existing (committed) migration — create a new one. Never hand-edit a
  lockfile — regenerate it with the package manager.
"""


def main():
    check = "--check" in sys.argv[1:]
    with tempfile.TemporaryDirectory() as tmp:
        fresh = Path(tmp) / "out"
        build(fresh)
        if check:
            stale = []
            for f in sorted(fresh.rglob("*")):
                if f.is_file():
                    rel = f.relative_to(fresh)
                    cur = OUT / rel
                    if not cur.exists() or cur.read_bytes() != f.read_bytes():
                        stale.append(str(rel))
            for d in sorted((OUT / "skills").glob("*")) if (OUT / "skills").exists() else []:
                if not (fresh / "skills" / d.name).exists():
                    stale.append(f"skills/{d.name} (no longer has a source)")
            if stale:
                print("portable edition is out of date — run: python3 portable/build.py")
                for s in stale:
                    print("  " + s)
                sys.exit(1)
            print("portable edition is up to date")
            return
        if (OUT / "skills").exists():
            shutil.rmtree(OUT / "skills")
        shutil.copytree(fresh / "skills", OUT / "skills")
        shutil.copy2(fresh / "AGENTS.md", OUT / "AGENTS.md")
        print(f"built {len(list((OUT / 'skills').iterdir()))} skills + AGENTS.md into portable/")


if __name__ == "__main__":
    main()
