#!/usr/bin/env bash
# Install the per-project deterministic layer into an existing project.
#   ./setup-project.sh [--standalone] [/path/to/project]      (default path: current dir)
#
# Default — plugin companion: for projects where the sdlc-agents plugin is enabled. The
# plugin already registers the guard / format / SessionStart / PreCompact hooks, so the
# project settings carry only what a plugin can't ship: the permissions deny-list and the
# opt-in Stop test gate. Wiring the same hooks here too would make each one fire twice.
#
# --standalone: for projects NOT using the plugin (manual install.sh). Installs the full
# hook set into the project settings instead.
#
# Never clobbers an existing settings.json, .mcp.json, rules file, or .worktreeinclude.
# Hook scripts are always refreshed and made executable.
set -euo pipefail
shopt -s nullglob

mode=companion; DEST=""
for arg in "$@"; do
  case "$arg" in
    --standalone) mode=standalone ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    -*) echo "error: unknown option '$arg' (see --help)" >&2; exit 1 ;;
    *) DEST="$arg" ;;
  esac
done
DEST="${DEST:-$(pwd)}"
[ -d "$DEST" ] || { echo "error: destination '$DEST' does not exist" >&2; exit 1; }

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # the templates/ dir
HOOKS="$SRC/../hooks"                                  # single source: the plugin's hooks/
settings_src="$SRC/settings.json"
[ "$mode" = standalone ] && settings_src="$SRC/settings.standalone.json"
echo "mode: $mode → $DEST"

mkdir -p "$DEST/.claude/hooks" "$DEST/.claude/rules"

# Hook scripts: our code — always (re)install and mark executable.
for s in "$HOOKS"/*.sh; do
  cp "$s" "$DEST/.claude/hooks/"
  chmod +x "$DEST/.claude/hooks/$(basename "$s")"
  echo "installed .claude/hooks/$(basename "$s") (+x)"
done

# Config files: the project's own — never clobber.
if [ -f "$DEST/.claude/settings.json" ]; then
  echo "note: .claude/settings.json exists — left it; merge from $settings_src if wanted."
else
  cp "$settings_src" "$DEST/.claude/settings.json"; echo "installed .claude/settings.json ($mode)"
fi
if [ -f "$DEST/.mcp.json" ]; then
  echo "note: .mcp.json exists — left it; merge from $SRC/.mcp.json if wanted."
else
  cp "$SRC/.mcp.json" "$DEST/.mcp.json"; echo "installed .mcp.json"
fi

# Path-scoped rules (load only when matching files are read/edited) — never clobber.
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
echo "Done ($mode) into $DEST"
if [ "$mode" = companion ]; then
  echo "Guard/format/SessionStart/PreCompact hooks come from the sdlc-agents plugin."
  echo "Not using the plugin? Re-run with --standalone (on a project without a settings.json)."
fi
echo "Next: set the verify.sh/format.sh commands for this stack and review the hooks before relying on them. Requires jq."
