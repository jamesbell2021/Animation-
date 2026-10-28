#!/usr/bin/env bash
# Runs the headless scenarios in tools/tests/scenarios.gd and prints a summary.
#   tools/tests/run_tests.sh                 everything (takes a few minutes: "battle" plays a
#                                            whole game with four AI crew)
#   tools/tests/run_tests.sh cannon repair   just these
#   tools/tests/run_tests.sh lan             a host and a phone client talking over the LAN
# Needs Godot 4.3 on PATH (or GODOT=/path/to/godot).
set -uo pipefail
cd "$(dirname "$0")/../.."
GODOT=${GODOT:-godot}
# A throwaway save folder, so tests never touch (or depend on) your real records and settings.
export XDG_DATA_HOME=$(mktemp -d)
trap 'rm -rf "$XDG_DATA_HOME"' EXIT
SCENARIOS=${*:-waves cannon repair shield collapse enemies demo lan battle}
NOISE='mesh_get_surface_count|Parameter "m" is null'
failed=0

show() {
	grep -E "^(PASS|FAIL|RESULT|      )|SCRIPT ERROR" <<<"$1" | grep -Ev "$NOISE"
}

for s in $SCENARIOS; do
	if [ "$s" = lan ]; then
		host_log=$(mktemp)
		timeout 120 "$GODOT" --headless --path . -s tools/tests/game_test.gd -- lan_host >"$host_log" 2>&1 &
		host_pid=$!
		sleep 3
		client=$(timeout 120 "$GODOT" --headless --path . -s tools/tests/game_test.gd -- lan_client 2>&1)
		wait $host_pid
		host=$(cat "$host_log")
		rm -f "$host_log"
		show "$host"
		show "$client"
		grep -q "^RESULT \[lan_host\] [0-9]* passed, 0 failed" <<<"$host" || failed=1
		grep -q "^RESULT \[lan_client\] [0-9]* passed, 0 failed" <<<"$client" || failed=1
		continue
	fi
	out=$("$GODOT" --headless --path . --fixed-fps 60 --quit-after 60000 -s tools/tests/game_test.gd -- "$s" 2>&1)
	show "$out"
	grep -q "^RESULT \[$s\] [0-9]* passed, 0 failed" <<<"$out" || failed=1
	grep -q "SCRIPT ERROR" <<<"$out" && failed=1
done
[ $failed = 0 ] && echo "ALL PASSED" || echo "SOME CHECKS FAILED"
exit $failed
