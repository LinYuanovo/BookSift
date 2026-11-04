#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
flutter_bin="${FLUTTER_BIN:-flutter}"
timeout_seconds="${TEST_TIMEOUT_SECONDS:-600}"
log_directory="$repository_root/app/build/test_logs"
mkdir -p "$log_directory"
log_file="$log_directory/test-$(date +%Y%m%d-%H%M%S)-$$.log"
cd "$repository_root/app"
printf '[watchdog] timeout=%ss log=%s\n' "$timeout_seconds" "$log_file"
set +e
timeout --signal=TERM --kill-after=15s "${timeout_seconds}s" "$flutter_bin" test --reporter expanded "$@" > "$log_file" 2>&1
result=$?
set -e
tail -n 70 "$log_file"
if [[ "$result" -eq 124 || "$result" -eq 137 ]]; then
  printf '[watchdog] TIMEOUT\n' >&2
fi
exit "$result"
