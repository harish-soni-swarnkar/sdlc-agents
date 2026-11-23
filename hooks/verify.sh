#!/usr/bin/env bash
# Stack-aware verify hook (used by the Stop hook).
# Checks every stack present at the repo ROOT *and* in each depth-1 subdirectory, so a
# polyglot / mid-migration tree (e.g. legacy-java/ + new-node/) is fully checked, not
# silently skipped. Node test runners get CI=true so Vitest/Jest run once, never watch-hang.
# Exit non-zero if any detected stack fails; fail-open for tools that aren't installed.
set -uo pipefail
root="${CLAUDE_PROJECT_DIR:-$(pwd)}"
fail=0
run() { echo "[verify] ($(pwd)) $*" >&2; "$@" || fail=1; }

check_dir() {
  local d="$1"; [ -d "$d" ] || return 0
  pushd "$d" >/dev/null 2>&1 || return 0

  # Node / TypeScript — CI=true so vitest/jest run once instead of entering watch mode.
  if [ -f package.json ]; then
    export CI=true
    local pm=npm; [ -f yarn.lock ] && pm=yarn; [ -f pnpm-lock.yaml ] && pm=pnpm
    if command -v "$pm" >/dev/null 2>&1; then
      grep -q '"typecheck"' package.json && run "$pm" -s typecheck
      grep -q '"test"' package.json && run "$pm" -s test
    fi
  fi

  # Python
  if [ -f pyproject.toml ] || [ -f setup.cfg ] || [ -f requirements.txt ]; then
    command -v ruff   >/dev/null 2>&1 && run ruff check .
    command -v mypy   >/dev/null 2>&1 && run mypy .
    command -v pytest >/dev/null 2>&1 && run pytest -q
  fi

  # Java (Maven / Gradle)
  [ -f pom.xml ] && command -v mvn >/dev/null 2>&1 && run mvn -q test
  { [ -f build.gradle ] || [ -f build.gradle.kts ]; } && [ -x ./gradlew ] && run ./gradlew -q test

  # Go
  if [ -f go.mod ] && command -v go >/dev/null 2>&1; then
    out=$(gofmt -l . 2>/dev/null); [ -n "$out" ] && { echo "[verify] gofmt needed: $out" >&2; fail=1; }
    run go test ./...
  fi

  # Rust
  [ -f Cargo.toml ] && command -v cargo >/dev/null 2>&1 && run cargo test -q

  popd >/dev/null 2>&1 || true
}

cd "$root" 2>/dev/null || exit 0
check_dir "$root"
for d in "$root"/*/; do
  case "$(basename "$d")" in
    node_modules|.git|dist|build|target|vendor|.venv|venv|.next|coverage) continue ;;
  esac
  check_dir "$d"
done
exit $fail
