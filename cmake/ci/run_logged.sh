#!/usr/bin/env bash
# run_logged.sh -- run a command with its output teed to a log file; on
# failure, surface the log tail as a ::error annotation (visible through the
# public check-run annotations API even when job-log download is restricted)
# and exit with the original status.
#
# Usage: run_logged.sh NAME cmd [args...]
set -u -o pipefail
if [ $# -lt 2 ]; then
  echo "usage: $0 NAME cmd [args...]" >&2
  exit 2
fi
name=$1
shift
log="/tmp/ci-${name}.log"
"$@" 2>&1 | tee "$log"
rc=${PIPESTATUS[0]}
if [ "$rc" -ne 0 ]; then
  tail -c 1800 "$log" | tr '\r\n' '~~' | sed 's/^/::error::/'
fi
exit "$rc"
