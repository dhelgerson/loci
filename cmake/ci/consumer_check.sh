#!/usr/bin/env bash
# consumer_check.sh -- build and run the heat tutorial application against
# two Loci install trees (legacy and CMake) using its UNMODIFIED Makefile,
# exactly as an external Loci application would, and require identical
# numerical behavior from both.
#
# Usage: consumer_check.sh <legacy-prefix> <cmake-prefix>
set -u -o pipefail

if [ $# -ne 2 ]; then
  echo "usage: $0 <legacy-prefix> <cmake-prefix>" >&2
  exit 2
fi
TREES=("$(cd "$1" 2>/dev/null && pwd)" "$(cd "$2" 2>/dev/null && pwd)")
if [ -z "${TREES[0]}" ] || [ -z "${TREES[1]}" ]; then
  echo "usage: $0 <legacy-prefix> <cmake-prefix>   (both must exist)" >&2
  exit 2
fi
MPIRUN="${MPIRUN:-mpirun}"
NP="${NP:-3}"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
FAIL=0

for prefix in "${TREES[@]}"; do
  name=$(basename "$prefix")
  app="$WORK/heat-$name"
  echo "== building heat consumer against $prefix"
  cp -r "$prefix/docs/heat" "$app"
  ( cd "$app" && make LOCI_BASE="$prefix" -j"$(nproc)" ) > "$app/build.log" 2>&1
  rc=$?
  if [ $rc -ne 0 ] || [ ! -x "$app/heat" ]; then
    echo "FAIL: heat did not build against $prefix"
    tail -30 "$app/build.log" | sed 's/^/      /'
    FAIL=1
    continue
  fi
  echo "== running heat ($NP ranks) from $prefix"
  ( cd "$app" && "$MPIRUN" -np "$NP" --bind-to none ./heat test ) \
    > "$app/run.log" 2>&1
  rc=$?
  grep '^R[0-9]' "$app/run.log" > "$app/residuals.txt"
  if [ $rc -ne 0 ] || ! grep -q 'Schedule execution complete' "$app/run.log"; then
    echo "FAIL: heat run failed against $prefix"
    tail -20 "$app/run.log" | sed 's/^/      /'
    FAIL=1
  fi
done

if [ $FAIL -eq 0 ]; then
  a="$WORK/heat-$(basename "${TREES[0]}")/residuals.txt"
  b="$WORK/heat-$(basename "${TREES[1]}")/residuals.txt"
  out=$(diff "$a" "$b"); rc=$?
  if [ $rc -eq 0 ]; then
    echo "PASS: heat residuals identical between both install trees:"
    sed 's/^/      /' "$a"
  else
    echo "FAIL: heat residuals differ between install trees"
    printf '%s\n' "$out" | sed 's/^/      /'
    FAIL=1
  fi
fi

if [ $FAIL -eq 0 ]; then
  echo "CONSUMER CHECK: PASS"
else
  echo "CONSUMER CHECK: FAILED"
fi
exit "$FAIL"
