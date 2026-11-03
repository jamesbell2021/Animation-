#!/usr/bin/env bash
# Runs every test headless and fails if any check fails or Godot printed a script error.
# Usage: tests/run_tests.sh [path-to-godot-4.3]   (or set GODOT=...)
set -uo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
godot="${1:-${GODOT:-godot}}"
"$godot" --headless --editor --quit --path "$here" >/dev/null 2>&1 || true
status=0
for t in test_rules test_smoke; do
	echo "== $t"
	out="$("$godot" --headless --path "$here" --script "res://tests/$t.gd" 2>&1)"
	code=$?
	echo "$out" | grep -E "FAIL|passed|OK:|FAILED" || true
	if [ $code -ne 0 ]; then
		echo "$t exited with $code"
		status=1
	fi
	# The headless dummy renderer reports every mesh as missing; that one line isn't ours.
	errors="$(echo "$out" | grep -E -A1 "SCRIPT ERROR|ERROR: " | grep -v -E 'Parameter "m" is null|dummy/storage/mesh_storage|^--$')"
	if echo "$errors" | grep -qE "SCRIPT ERROR|ERROR: "; then
		echo "$errors" | head -40
		status=1
	fi
done
[ $status -eq 0 ] && echo "All tests passed." || echo "Tests FAILED."
exit $status
