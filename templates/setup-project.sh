#!/usr/bin/env bash
# Install the per-project deterministic layer into a project.
# Run from the project root, or pass its path:  ./setup-project.sh [/path/to/project]
# Copies settings.json + .mcp.json (without clobbering existing ones) and the hook scripts
# (always refreshed) into <project>/.claude/, and makes the hooks executable.
set -euo pipefail
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # the templates/ dir
DEST="${1:-$(pwd)}"

mkdir -p "$DEST/.claude/hooks"

# Hook scripts: our code — always (re)install and mark executable.
cp "$SRC/hooks/verify.sh" "$DEST/.claude/hooks/verify.sh"
cp "$SRC/hooks/format.sh" "$DEST/.claude/hooks/format.sh"
chmod +x "$DEST/.claude/hooks/verify.sh" "$DEST/.claude/hooks/format.sh"
echo "installed .claude/hooks/{verify,format}.sh (+x)"

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

echo ""
echo "Done into $DEST"
echo "Next: set the verify.sh/format.sh commands for this stack, and review the hooks before relying on them (they run shell automatically). Requires jq."
