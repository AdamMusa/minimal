#!/usr/bin/env bash
# Benchmarks minimal_mvn before and after the fixes, and writes RESULTS.md
#
#   benchmark/tool/run.sh [before-ref]
#
# "before" is before-ref (default: upstream/main, or main), checked out in a
# temporary git worktree; "after" is the current checkout
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

BEFORE_DIR="$(mktemp -d)/before"
git -C "$ROOT" worktree add --detach -q "$BEFORE_DIR" "$BEFORE_REF"
cleanup() {
  git -C "$ROOT" worktree remove --force "$BEFORE_DIR"
  rm -f "$BENCH_DIR/pubspec_overrides.yaml"
}
trap cleanup EXIT

# label, package directory, git ref
bench() {
  printf 'dependency_overrides:\n  minimal_mvn:\n    path: %s\n' "$2" \
    >"$BENCH_DIR/pubspec_overrides.yaml"
  echo "Benchmarking $1 ($3)..."
  (
    cd "$BENCH_DIR"
    flutter pub get >/dev/null
    BENCH_LABEL="$1" BENCH_REF="$3" BENCH_OUT="$BENCH_DIR/results/$1.json" \
      flutter test test/benchmark_test.dart >/dev/null
  )
}

mkdir -p "$BENCH_DIR/results"
bench before "$BEFORE_DIR" "$BEFORE_REF@$(git -C "$ROOT" rev-parse --short "$BEFORE_REF")"
bench after "$ROOT" "$(git -C "$ROOT" branch --show-current)@$(git -C "$ROOT" rev-parse --short HEAD)"

cd "$BENCH_DIR"
dart run tool/report.dart results/before.json results/after.json >RESULTS.md
echo "Wrote $BENCH_DIR/RESULTS.md"
