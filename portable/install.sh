#!/usr/bin/env bash
# Install the portable skills into an AI coding tool — no Node needed. (With Node, the
# cross-agent installer is simpler: npx skills add harish-soni-swarnkar/sdlc-agents/portable)
#
#   ./install.sh [--target agents|github|claude|all] [--global] [--git-hooks] [project-dir]
#
# Targets (folders verified against each tool's docs):
#   agents  .agents/skills  — Codex, Cursor, GitHub Copilot CLI & coding agent, Gemini CLI,
#                             Antigravity, VS Code (local sessions)          [default]
#   github  .github/skills  — GitHub Copilot in VS Code
#   claude  .claude/skills  — Claude Code (prefer the sdlc-agents plugin there instead)
#   all     all three
# --global installs per-user instead of per-project:
#   agents → ~/.agents/skills, github → ~/.copilot/skills, claude → ~/.claude/skills
#
# Project installs also copy AGENTS.md (the always-on rules) to the project root, unless
# one already exists, and the commit/push safety hooks to .githooks/. --git-hooks turns
# those on (sets core.hooksPath, only if the project doesn't already use one). Skills previously installed from this set are refreshed; a
# same-named skill from anywhere else is left untouched.
set -euo pipefail
shopt -s nullglob

target=agents; global=0; githooks=0; DEST=""
for arg in "$@"; do
  case "$arg" in
    --target=*) target="${arg#--target=}" ;;
    --target) target="__next__" ;;
    --global) global=1 ;;
    --git-hooks) githooks=1 ;;
    -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
    -*) echo "error: unknown option '$arg' (see --help)" >&2; exit 1 ;;
    *) if [ "$target" = "__next__" ]; then target="$arg"; else DEST="$arg"; fi ;;
  esac
done
case "$target" in agents|github|claude|all) ;; *) echo "error: --target must be agents, github, claude, or all" >&2; exit 1 ;; esac

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ "$global" -eq 0 ]; then
  DEST="${DEST:-$(pwd)}"
  [ -d "$DEST" ] || { echo "error: destination '$DEST' does not exist" >&2; exit 1; }
fi

dir_for() { # $1=target → skills folder
  if [ "$global" -eq 1 ]; then
    case "$1" in agents) echo "$HOME/.agents/skills" ;; github) echo "$HOME/.copilot/skills" ;; claude) echo "$HOME/.claude/skills" ;; esac
  else
    case "$1" in agents) echo "$DEST/.agents/skills" ;; github) echo "$DEST/.github/skills" ;; claude) echo "$DEST/.claude/skills" ;; esac
  fi
}

targets="$target"; [ "$target" = all ] && targets="agents github claude"
for t in $targets; do
  out=$(dir_for "$t"); mkdir -p "$out"
  installed=0; skipped=0
  for s in "$SRC"/skills/*/; do
    name=$(basename "$s")
    if [ -e "$out/$name" ] && ! grep -q '^  edition: "portable"' "$out/$name/SKILL.md" 2>/dev/null; then
      echo "note: $out/$name exists and isn't from this set — left it."
      skipped=$((skipped + 1)); continue
    fi
    mkdir -p "$out/$name" && cp -R "$s". "$out/$name/"   # whole folder: SKILL.md + scripts/ assets/
    installed=$((installed + 1))
  done
  echo "installed $installed skills → $out$( [ $skipped -gt 0 ] && echo " ($skipped skipped)")"
done

if [ "$global" -eq 0 ]; then
  if [ -f "$DEST/AGENTS.md" ]; then
    echo "note: AGENTS.md exists — left it; merge from $SRC/AGENTS.md if wanted."
  else
    cp "$SRC/AGENTS.md" "$DEST/AGENTS.md"; echo "installed AGENTS.md → $DEST"
  fi
  mkdir -p "$DEST/.githooks"
  for h in "$SRC"/githooks/*; do
    hb=$(basename "$h")
    if [ -e "$DEST/.githooks/$hb" ] && ! grep -q '^# sdlc-agents git hook' "$DEST/.githooks/$hb"; then
      echo "note: .githooks/$hb exists and isn't from this kit — left it."
    else
      cp "$h" "$DEST/.githooks/" && chmod +x "$DEST/.githooks/$hb" && echo "installed .githooks/$hb"
    fi
  done
  if [ "$githooks" -eq 1 ]; then
    if ! git -C "$DEST" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      echo "note: $DEST isn't a git repo — git hooks copied but not enabled."
    elif current=$(git -C "$DEST" config core.hooksPath) && [ -n "$current" ]; then
      echo "note: core.hooksPath is already '$current' — left it; call the .githooks/ scripts from your hook setup."
    else
      git -C "$DEST" config core.hooksPath .githooks && echo "enabled git hooks (core.hooksPath=.githooks)"
    fi
  else
    echo "git hooks not enabled — re-run with --git-hooks to turn them on."
  fi
  echo ""
  echo "Gemini CLI reads GEMINI.md by default; to make it read AGENTS.md, add to .gemini/settings.json:"
  echo '  { "context": { "fileName": ["AGENTS.md", "GEMINI.md"] } }'
fi
echo "Start with the route skill if you're unsure which skill fits a task."
