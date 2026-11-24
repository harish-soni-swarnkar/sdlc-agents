#!/usr/bin/env bash
# Build a distributable zip of the kit — only from a clean, committed, checked tree.
#   ./release.sh                  hook tests + `claude plugin validate . --strict`, then package
#   ./release.sh --skip-validate  allow packaging when neither claude nor npx is available (says so)
#
# The zip is built with `git archive` from HEAD, so only tracked, committed files ship —
# never local files like CLAUDE.local.md, .claude/settings.local.json, or stray artifacts.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

skip_validate=0
for arg in "$@"; do
  case "$arg" in
    --skip-validate) skip_validate=1 ;;
    -h|--help) sed -n '2,7p' "$0"; exit 0 ;;
    *) echo "error: unknown option '$arg' (see --help)" >&2; exit 1 ;;
  esac
done

if [ -n "$(git status --porcelain)" ]; then
  echo "error: working tree has uncommitted changes — commit them first, so the zip matches a commit." >&2
  git status --short >&2
  exit 1
fi

echo "== hook tests =="
./tests/test-hooks.sh

echo "== frontmatter (strict YAML) =="
./tests/test-frontmatter.sh

echo "== git hooks + golden-replay harness =="
./tests/test-githooks.sh
python3 tests/test-harness.py

echo "== portable edition =="
python3 portable/build.py --check
python3 portable/validate.py

echo "== plugin validation =="
if command -v claude >/dev/null 2>&1; then
  claude plugin validate . --strict
elif command -v npx >/dev/null 2>&1; then
  npx --yes @anthropic-ai/claude-code plugin validate . --strict
elif [ "$skip_validate" -eq 1 ]; then
  echo "WARNING: no claude CLI or npx — packaging WITHOUT plugin validation (--skip-validate)." >&2
else
  echo "error: neither the claude CLI nor npx is available, so the plugin can't be validated." >&2
  echo "       Install one, or re-run with --skip-validate to package anyway." >&2
  exit 1
fi

echo "== package =="
git archive --format=zip --output=Claude-Agents.zip HEAD
echo "Wrote $(pwd)/Claude-Agents.zip from $(git rev-parse --short HEAD)"
