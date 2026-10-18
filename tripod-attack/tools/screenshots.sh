#!/usr/bin/env bash
# Runs the scripted demo under a virtual display and saves a screenshot of every screen.
# Usage: tools/screenshots.sh [path-to-godot] [out-dir]     (needs xvfb-run and Mesa)
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
godot="${1:-${GODOT:-godot}}"
out="${2:-/tmp/tripod-attack-shots}"
mkdir -p "$out"
"$godot" --headless --path "$here" --import >/dev/null 2>&1 || true
xvfb-run -a -s "-screen 0 1280x720x24" "$godot" --path "$here" --rendering-driver opengl3 --resolution 1024x576 -- "--shots=$out"
ls -la "$out"
