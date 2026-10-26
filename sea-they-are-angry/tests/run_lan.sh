#!/bin/sh
# The LAN test: a host and a client, two Godot processes on this machine.
#   GODOT=/path/to/godot tests/run_lan.sh
GODOT=${GODOT:-godot}
cd "$(dirname "$0")/.."
$GODOT --headless --path . --script res://tests/lan_host.gd > /tmp/sea_lan_host.log 2>&1 &
HOST=$!
sleep 3
$GODOT --headless --path . --script res://tests/lan_client.gd > /tmp/sea_lan_client.log 2>&1
CLIENT=$?
wait $HOST
HOSTRC=$?
grep -E "^(PASS|FAIL)|ALL PASS|FAILED" /tmp/sea_lan_host.log /tmp/sea_lan_client.log
[ $CLIENT -eq 0 ] && [ $HOSTRC -eq 0 ] && echo "LAN: ALL PASS" || echo "LAN: FAILED"
