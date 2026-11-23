#!/usr/bin/env bash
# Install the per-project deterministic layer into a project.
# Run from the project root, or pass its path:  ./setup-project.sh [/path/to/project]
# Copies settings.json, .mcp.json, the path-scoped rules, and .worktreeinclude (never
# clobbering existing ones) and the hook scripts (always refreshed, made executable).
set -euo pipefail
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # the templates/ dir
HOOKS="$SRC/../hooks"                                  # single source: the plugin's hooks/
DEST="${1:-$(pwd)}"

mkdir -p "$DEST/.claude/hooks"

# Hook scripts: our code — always (re)install and mark executable.
for s in "$HOOKS"/*.sh; do
  cp "$s" "$DEST/.claude/hooks/"
  chmod +x "$DEST/.claude/hooks/$(basename "$s")"
  echo "installed .claude/hooks/$(basename "$s") (+x)"
done

# Config files: the project's own — never clobber.
if [ -f "$DEST/.claude/settings.json" ]; then
  echo "note: .claude/settings.json exists — left it; merge from $SRC/settings.json if wanted."
else
  cp "$SRC/settings.json" "$DEST/.claude/settings.json"; echo "installed .claude/settings.json"
fi
if [ -f "$DEST/.mcp.json" ]; then
  echo "note: .mcp.json exists — left it; merge from $SRC/.mcp.json if wanted."
else
  cp "$SRC/.mcp.json" "$DEST/.mcp.json"; echo "installed .mcp.json"
fi

# Path-scoped rules (load only when matching files are read/edited) — never clobber.
mkdir -p "$DEST/.claude/rules"
for r in "$SRC"/rules/*.md; do
  b=$(basename "$r")
  if [ -f "$DEST/.claude/rules/$b" ]; then
    echo "note: .claude/rules/$b exists — left it."
  else
    cp "$r" "$DEST/.claude/rules/$b"; echo "installed .claude/rules/$b"
  fi
done

# Files copied into new git worktrees (.env etc.) — never clobber.
if [ -f "$DEST/.worktreeinclude" ]; then
  echo "note: .worktreeinclude exists — left it; merge from $SRC/.worktreeinclude if wanted."
else
  cp "$SRC/.worktreeinclude" "$DEST/.worktreeinclude"; echo "installed .worktreeinclude"
fi

echo ""
echo "Done into $DEST"
echo "Next: set the verify.sh/format.sh commands for this stack, and review the hooks before relying on them (they run shell automatically). Requires jq."
