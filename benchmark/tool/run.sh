#!/usr/bin/env bash
# Benchmarks minimal_mvn before and after the fixes, and writes RESULTS.md
#
#   ROUNDS=8 benchmark/tool/run.sh [before-ref]
#
# "before" is before-ref (default: upstream/main, or main), checked out in a
# temporary git worktree; "after" is the current checkout.
#
# * Correctness: test/correctness_test.dart replays the bug scenarios
# * Performance: the app in lib/ is built in release mode (AOT) once per
#   version; then each benchmark runs in its own process, alternating
#   versions, ROUNDS times
set -euo pipefail

BENCH_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(git -C "$BENCH_DIR" rev-parse --show-toplevel)"
if [[ $# -gt 0 ]]; then
  BEFORE_REF="$1"
elif git -C "$ROOT" rev-parse --verify -q upstream/main >/dev/null; then
  BEFORE_REF=upstream/main
else
  BEFORE_REF=main
fi
ROUNDS="${ROUNDS:-8}"

TMP="$(mktemp -d)"
BEFORE_DIR="$TMP/before"
git -C "$ROOT" worktree add --detach -q "$BEFORE_DIR" "$BEFORE_REF"
cleanup() {
  git -C "$ROOT" worktree remove --force "$BEFORE_DIR"
  rm -f "$BENCH_DIR/pubspec_overrides.yaml"
  rm -rf "$TMP"
}
trap cleanup EXIT

RESULTS="$BENCH_DIR/results"
rm -rf "$RESULTS"
mkdir -p "$RESULTS"

# label, package directory, git ref
prepare() {
  printf 'dependency_overrides:\n  minimal_mvn:\n    path: %s\n' "$2" \
    >"$BENCH_DIR/pubspec_overrides.yaml"
  cd "$BENCH_DIR"
  flutter pub get >/dev/null
  echo "$1 ($3): correctness"
  BENCH_LABEL="$1" BENCH_REF="$3" BENCH_OUT="$RESULTS/$1_correctness.json" \
    flutter test test/correctness_test.dart >/dev/null
  echo "$1 ($3): release build"
  flutter build macos --release >/dev/null
  cp -R build/macos/Build/Products/Release/minimal_benchmark.app "$TMP/$1.app"
}

prepare before "$BEFORE_DIR" \
  "$BEFORE_REF@$(git -C "$ROOT" rev-parse --short "$BEFORE_REF")"
prepare after "$ROOT" \
  "$(git -C "$ROOT" branch --show-current)@$(git -C "$ROOT" rev-parse --short HEAD)"

# label, benchmark id
run() {
  BENCH_ONLY="$2" "$TMP/$1.app/Contents/MacOS/minimal_benchmark" 2>/dev/null |
    grep '^{' >>"$RESULTS/$1_performance.jsonl"
}

IDS="$("$TMP/after.app/Contents/MacOS/minimal_benchmark" 2>/dev/null | grep '^\[' | tr -d '[]"' | tr ',' ' ')"
for round in $(seq 1 "$ROUNDS"); do
  echo "Performance round $round/$ROUNDS"
  for id in $IDS; do
    # alternate which version goes first
    if ((round % 2)); then
      run before "$id"
      run after "$id"
    else
      run after "$id"
      run before "$id"
    fi
  done
done

cd "$BENCH_DIR"
dart run tool/report.dart "$RESULTS" >RESULTS.md
echo "Wrote $BENCH_DIR/RESULTS.md"
