#!/usr/bin/env bash
# Build a distributable zip of the kit — only after the checks pass.
#  1. tests/test-hooks.sh must pass (guard block/allow cases).
#  2. `claude plugin validate . --strict` must pass when the claude CLI is available;
#     if it isn't on PATH, say so loudly instead of pretending the plugin was validated.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

echo "== hook tests =="
./tests/test-hooks.sh

echo "== plugin validation =="
if command -v claude >/dev/null 2>&1; then
  claude plugin validate . --strict
else
  echo "WARNING: claude CLI not on PATH — plugin manifest/frontmatter NOT validated." >&2
  echo "         Run 'claude plugin validate . --strict' before publishing." >&2
fi

echo "== package =="
rm -f Claude-Agents.zip
zip -qr Claude-Agents.zip . -x "*.DS_Store" -x ".git/*" -x "Claude-Agents.zip"
echo "Wrote $(pwd)/Claude-Agents.zip"
