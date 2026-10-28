#!/usr/bin/env bash
# Benchmarks minimal_mvn before and after the fixes, and writes RESULTS.md
#
#   LAYOUTS=3 ROUNDS=4 benchmark/tool/run.sh [before-ref]
#
# "before" is before-ref (default: upstream/main, or main), checked out in a
# temporary git worktree; "after" is the current checkout.
#
# * Correctness: test/correctness_test.dart replays the bug scenarios
# * Performance: the app in lib/ is built in release mode (AOT), LAYOUTS times
#   per version, each build with a different amount of padding code, since
#   nanosecond benchmarks depend on code alignment. Each benchmark then runs
#   in its own process, alternating versions, ROUNDS times per build
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
LAYOUTS="${LAYOUTS:-3}"
ROUNDS="${ROUNDS:-4}"

TMP="$(mktemp -d)"
BEFORE_DIR="$TMP/before"
git -C "$ROOT" worktree add --detach -q "$BEFORE_DIR" "$BEFORE_REF"
PADDING="$BENCH_DIR/lib/padding.dart"
cp "$PADDING" "$TMP/padding.dart"
cleanup() {
  git -C "$ROOT" worktree remove --force "$BEFORE_DIR"
  cp "$TMP/padding.dart" "$PADDING"
  rm -f "$BENCH_DIR/pubspec_overrides.yaml"
  rm -rf "$TMP"
}
trap cleanup EXIT

RESULTS="$BENCH_DIR/results"
rm -rf "$RESULTS"
mkdir -p "$RESULTS"

# layout: writes padding.dart with a layout-dependent amount of dead code
pad() {
  {
    sed -n '1,3p' "$TMP/padding.dart"
    echo 'final padding = <int Function(int)>['
    for i in $(seq 1 $(($1 * 7))); do
      echo "  (x) => (x * $((i * 31 + 7)) + $i) ^ (x >> $((i % 5 + 1))),"
    done
    echo '];'
  } >"$PADDING"
}

# label, package directory, git ref
prepare() {
  printf 'dependency_overrides:\n  minimal_mvn:\n    path: %s\n' "$2" \
    >"$BENCH_DIR/pubspec_overrides.yaml"
  cd "$BENCH_DIR"
  flutter pub get >/dev/null
  echo "$1 ($3): correctness"
  BENCH_LABEL="$1" BENCH_REF="$3" BENCH_OUT="$RESULTS/$1_correctness.json" \
    flutter test test/correctness_test.dart >/dev/null
  for layout in $(seq 1 "$LAYOUTS"); do
    echo "$1 ($3): release build, layout $layout/$LAYOUTS"
    pad "$layout"
    flutter build macos --release >/dev/null
    cp -R build/macos/Build/Products/Release/minimal_benchmark.app "$TMP/$1_$layout.app"
  done
}

prepare before "$BEFORE_DIR" \
  "$BEFORE_REF@$(git -C "$ROOT" rev-parse --short "$BEFORE_REF")"
prepare after "$ROOT" \
  "$(git -C "$ROOT" branch --show-current)@$(git -C "$ROOT" rev-parse --short HEAD)"

# label, layout, benchmark id
run() {
  BENCH_ONLY="$3" "$TMP/$1_$2.app/Contents/MacOS/minimal_benchmark" 2>/dev/null |
    grep '^{' | sed "s/^{/{\"layout\":$2,/" >>"$RESULTS/$1_performance.jsonl"
}

IDS="$("$TMP/after_1.app/Contents/MacOS/minimal_benchmark" 2>/dev/null | grep '^\[' | tr -d '[]"' | tr ',' ' ')"
for round in $(seq 1 "$ROUNDS"); do
  echo "Performance round $round/$ROUNDS"
  for layout in $(seq 1 "$LAYOUTS"); do
    for id in $IDS; do
      # alternate which version goes first
      if (((round + layout) % 2)); then
        run before "$layout" "$id"
        run after "$layout" "$id"
      else
        run after "$layout" "$id"
        run before "$layout" "$id"
      fi
    done
  done
done

cd "$BENCH_DIR"
dart run tool/report.dart "$RESULTS" >RESULTS.md
echo "Wrote $BENCH_DIR/RESULTS.md"
