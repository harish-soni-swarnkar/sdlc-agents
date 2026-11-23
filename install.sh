#!/usr/bin/env bash
# Manual / global install of the agent crew into ~/.claude/agents.
# NOTE: this bundle is ALSO a native Claude Code plugin (see .claude-plugin/plugin.json);
# installing it as a plugin is the alternative to this script. This script is the manual
# path — it copies agents/*.md into ~/.claude/agents (flat, un-namespaced) and the global
# rules into ~/.claude/CLAUDE.md. Safe to re-run.
set -euo pipefail

# Resolve this script's own directory, so it works no matter where it's run from.
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="$HOME/.claude/agents"

mkdir -p "$DEST"

count=0
for f in "$SRC"/agents/*.md; do
  [ -e "$f" ] || continue
  base="$(basename "$f")"
  cp "$f" "$DEST/$base"
  echo "  installed $base"
  count=$((count + 1))
done

echo ""
echo "Done — $count agent(s) installed to $DEST"

# Ship the crew README alongside the agents, so docs live at a stable path
# (~/.claude/agents/README.md) with no dependency on where this bundle folder sits.
# It has no agent frontmatter, so Claude Code does not register it as an agent.
[ -f "$SRC/README.md" ] && cp "$SRC/README.md" "$DEST/README.md" && echo "installed README.md -> $DEST"

# Global rules: install only if the user doesn't already have one.
if [ -f "$SRC/global/CLAUDE.md" ]; then
  if [ -f "$HOME/.claude/CLAUDE.md" ]; then
    echo "Note: ~/.claude/CLAUDE.md already exists — left it untouched."
    echo "      Compare with $SRC/global/CLAUDE.md and merge by hand if you want the global rules."
  else
    cp "$SRC/global/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
    echo "Installed global engineering rules to ~/.claude/CLAUDE.md"
  fi
fi

echo "Use one in any Claude Code chat:  Use the <agent-name> agent. <target + context>"
