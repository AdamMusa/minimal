#!/usr/bin/env bash
# Benchmarks minimal_mvn before and after the fixes, and writes RESULTS.md
#
#   ROUNDS=5 benchmark/tool/run.sh [before-ref]
#
# "before" is before-ref (default: upstream/main, or main), checked out in a
# temporary git worktree; "after" is the current checkout. Both are run
# alternately for ROUNDS rounds, so that machine load affects them alike
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

ROUNDS="${ROUNDS:-5}"
BEFORE_LABEL="$BEFORE_REF@$(git -C "$ROOT" rev-parse --short "$BEFORE_REF")"
AFTER_LABEL="$(git -C "$ROOT" branch --show-current)@$(git -C "$ROOT" rev-parse --short HEAD)"

# label, package directory, git ref, round
bench() {
  printf 'dependency_overrides:\n  minimal_mvn:\n    path: %s\n' "$2" \
    >"$BENCH_DIR/pubspec_overrides.yaml"
  echo "Round $4/$ROUNDS: $1 ($3)"
  (
    cd "$BENCH_DIR"
    flutter pub get >/dev/null
    BENCH_LABEL="$1" BENCH_REF="$3" BENCH_OUT="$BENCH_DIR/results/$1_$4.json" \
      flutter test test/benchmark_test.dart >/dev/null
  )
}

rm -rf "$BENCH_DIR/results"
mkdir -p "$BENCH_DIR/results"
for round in $(seq 1 "$ROUNDS"); do
  bench before "$BEFORE_DIR" "$BEFORE_LABEL" "$round"
  bench after "$ROOT" "$AFTER_LABEL" "$round"
done

cd "$BENCH_DIR"
dart run tool/report.dart results/*.json >RESULTS.md
echo "Wrote $BENCH_DIR/RESULTS.md"
