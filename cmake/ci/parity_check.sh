#!/usr/bin/env bash
# parity_check.sh -- rigorous legacy-vs-CMake parity gate for Loci CI.
#
# Compares the artifacts of a legacy configure/make build (OBJ tree + install
# prefix) against the CMake build (binary dir + install prefix) that was built
# from the SAME checkout on the SAME machine with the SAME dependency
# detection modes.  Any difference in the installed file sets, header
# contents, generated conf files, or quickTest results fails the check, so a
# change that regresses CMake away from the original build system is caught
# immediately.
#
# Usage:
#   parity_check.sh --legacy-obj DIR --cmake-build DIR \
#                   --legacy-prefix DIR --cmake-prefix DIR
#
# Exit status: 0 = full parity, 1 = mismatch (details printed), 2 = bad args.

set -u -o pipefail

LEG_OBJ="" CMB_BUILD="" LEG_PREFIX="" CMB_PREFIX=""
while [ $# -gt 0 ]; do
  case "$1" in
    --legacy-obj)    LEG_OBJ="$2"; shift 2 ;;
    --cmake-build)   CMB_BUILD="$2"; shift 2 ;;
    --legacy-prefix) LEG_PREFIX="$2"; shift 2 ;;
    --cmake-prefix)  CMB_PREFIX="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
for v in LEG_OBJ CMB_BUILD LEG_PREFIX CMB_PREFIX; do
  if [ -z "${!v}" ] || [ ! -d "${!v}" ]; then
    echo "ERROR: $v missing or not a directory" >&2
    exit 2
  fi
done
# Normalize all tree arguments to absolute paths: quickTest result files may
# embed either relative or absolute test paths, and the content normalization
# below must substitute whole directory paths (a bare relative name would
# otherwise be replaced inside unrelated absolute path components).
LEG_OBJ=$(cd "$LEG_OBJ" && pwd)
CMB_BUILD=$(cd "$CMB_BUILD" && pwd)
LEG_PREFIX=$(cd "$LEG_PREFIX" && pwd)
CMB_PREFIX=$(cd "$CMB_PREFIX" && pwd)

FAIL=0
report() {  # report NAME RC [DETAIL]
  local name="$1" rc="$2" out="${3:-}"
  if [ "$rc" -eq 0 ]; then
    echo "PASS: $name"
  else
    echo "FAIL: $name"
    [ -n "$out" ] && printf '%s\n' "$out" | sed 's/^/      /'
    FAIL=1
  fi
}

# Path normalization for content checks: the two trees live at different
# absolute paths; those must not count as differences.
norm() { # norm FILE
  sed -e "s|${LEG_OBJ}|TREE|g" \
      -e "s|${CMB_BUILD}|TREE|g" \
      -e "s|${LEG_PREFIX}|PREFIX|g" \
      -e "s|${CMB_PREFIX}|PREFIX|g" "$1"
}

check_listing() { # name dirA dirB [find args...]
  local name="$1" a="$2" b="$3"; shift 3
  local out rc
  out=$(diff <( cd "$a" && find "$@" | LC_ALL=C sort ) \
             <( cd "$b" && find "$@" | LC_ALL=C sort )); rc=$?
  report "$name" "$rc" "$out"
}

check_conf() { # name fileA fileB [extra sed expr...]
  local name="$1" a="$2" b="$3"; shift 3
  local out rc e
  local -a extra=()
  for e in "$@"; do extra+=(-e "$e"); done
  if [ "${#extra[@]}" -gt 0 ]; then
    out=$(diff <(norm "$a" | sed "${extra[@]}") \
               <(norm "$b" | sed "${extra[@]}")); rc=$?
  else
    out=$(diff <(norm "$a") <(norm "$b")); rc=$?
  fi
  report "$name" "$rc" "$out"
}

echo "===== 1. install tree file sets ====="
check_listing "bin/ contents" \
  "$LEG_PREFIX/bin" "$CMB_PREFIX/bin" -maxdepth 1 -type f
check_listing "lib/ contents" \
  "$LEG_PREFIX/lib" "$CMB_PREFIX/lib" -maxdepth 1
check_listing "top-level contents" \
  "$LEG_PREFIX" "$CMB_PREFIX" -maxdepth 1
check_listing "docs/ tree" \
  "$LEG_PREFIX/docs" "$CMB_PREFIX/docs" -type f
check_listing "include/ tree" \
  "$LEG_PREFIX/include" "$CMB_PREFIX/include" -mindepth 1

echo "===== 2. installed trees must contain no symlinks ====="
nsym=$(find "$LEG_PREFIX" "$CMB_PREFIX" -type l | wc -l)
if [ "$nsym" -eq 0 ]; then report "no symlinks installed" 0
else report "no symlinks installed" 1 "symlink count: $nsym"; fi

echo "===== 3. executability of bin/ artifacts ====="
nonexec=0
for f in "$LEG_PREFIX"/bin/* "$CMB_PREFIX"/bin/*; do
  if [ -f "$f" ] && [ ! -x "$f" ]; then
    echo "not executable: $f"; nonexec=$((nonexec + 1))
  fi
done
report "all bin/ files executable" "$nonexec"

echo "===== 4. header contents (recursive diff) ====="
out=$(diff -r --exclude=version_info.h \
          "$LEG_PREFIX/include" "$CMB_PREFIX/include"); rc=$?
report "include/ contents byte-identical" "$rc" "$out"
# Config/version_info.h is the single documented deviation.  On a checkout
# with no reachable git tag, legacy Makefile sed-extraction leaves the raw
# hash in the macro (e.g. '#define LOCI_VERSION_MAJOR c4129f' -- inert but
# unusable), while CMake writes numeric 0/0.  Whenever legacy produced a
# numeric value (tagged checkout) the files must be byte-identical, which is
# enforced here; the untagged form is accepted only if CMake wrote exactly
# its documented 0/0 fallback.
leg_vih="$LEG_PREFIX/include/Config/version_info.h"
cmb_vih="$CMB_PREFIX/include/Config/version_info.h"
if diff -q "$leg_vih" "$cmb_vih" >/dev/null 2>&1; then
  report "Config/version_info.h byte-identical" 0
elif grep -Eq '#define LOCI_VERSION_MAJOR [0-9]' "$leg_vih" 2>/dev/null; then
  report "Config/version_info.h byte-identical" 1 \
    "$(diff "$leg_vih" "$cmb_vih" 2>&1)"
elif grep -q '#define LOCI_VERSION_MAJOR 0' "$cmb_vih" 2>/dev/null &&
     grep -q '#define LOCI_VERSION_MINOR 0' "$cmb_vih" 2>/dev/null; then
  echo "NOTE: untagged checkout: legacy emits non-numeric version macros,"
  report "Config/version_info.h (documented untagged deviation)" 0
else
  report "Config/version_info.h (untagged checkout, unexpected content)" 1 \
    "$(diff "$leg_vih" "$cmb_vih" 2>&1)"
fi

echo "===== 5. generated conf files ====="
check_conf "Loci.conf"    "$LEG_PREFIX/Loci.conf"    "$CMB_PREFIX/Loci.conf"
check_conf "comp.conf"    "$LEG_PREFIX/comp.conf"    "$CMB_PREFIX/comp.conf"
check_conf "version.conf" "$LEG_PREFIX/version.conf" "$CMB_PREFIX/version.conf"
# sys.conf lives in the build trees; byte-identical modulo install prefixes
check_conf "sys.conf (paths normalized)" \
  "$LEG_OBJ/sys.conf" "$CMB_BUILD/sys.conf" \
  "s|^INSTALL_DIR=.*|INSTALL_DIR=PREFIX|"

echo "===== 6. quickTest results ====="
SUITES="Containers Tools FVMModUnitTests FVM SystemTests FVMAdaptTest"
legacy_results=$(mktemp)  cmake_results=$(mktemp)
trap 'rm -f "$legacy_results" "$cmake_results"' EXIT
for s in $SUITES; do
  f="$LEG_OBJ/quickTest/$s/TestResults"
  if [ -f "$f" ]; then norm "$f" >> "$legacy_results"
  else echo "missing results: $f" >&2; FAIL=1; fi
  f="$CMB_BUILD/quickTest/$s/TestResults"
  if [ -f "$f" ]; then norm "$f" >> "$cmake_results"
  else echo "missing results: $f" >&2; FAIL=1; fi
done
out=$(diff <(LC_ALL=C sort "$legacy_results") <(LC_ALL=C sort "$cmake_results"))
rc=$?
report "quickTest TestResults identical (sorted, paths normalized)" "$rc" "$out"
if grep -q "FAIL" "$legacy_results"; then
  report "legacy quickTest itself fully passing" 1 \
    "$(grep FAIL "$legacy_results")"
fi
n_l=$(grep -c PASS "$legacy_results" || true)
n_c=$(grep -c PASS "$cmake_results" || true)
if [ "$n_l" -eq "$n_c" ]; then report "same PASS count (both $n_l)" 0
else report "same PASS count (legacy=$n_l cmake=$n_c)" 1; fi

echo "======================================="
if [ "$FAIL" -eq 0 ]; then
  echo "PARITY CHECK: PASS (CMake build matches legacy build)"
else
  echo "PARITY CHECK: FAILED"
fi
exit "$FAIL"
