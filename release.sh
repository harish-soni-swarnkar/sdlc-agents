#!/usr/bin/env bash
# Build a distributable zip of the kit, excluding OS/VCS junk.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
rm -f Claude-Agents.zip
zip -r Claude-Agents.zip . -x "*.DS_Store" -x ".git/*" -x "Claude-Agents.zip"
echo "Wrote $(pwd)/Claude-Agents.zip"
