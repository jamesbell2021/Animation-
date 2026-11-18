#!/usr/bin/env bash
# Regenerates every image and Godot resource in the kit from code.
# Usage: tools/build_all.sh /path/to/Godot_v4.3-stable   (Python 3 with Pillow + numpy needed)
set -euo pipefail
GODOT="${1:-godot}"
cd "$(dirname "$0")/.."
python3 tools/terrain.py
python3 tools/props.py
python3 tools/level_layout.py > /dev/null
python3 tools/make_guides.py
"$GODOT" --headless --editor --quit --path . > /dev/null 2>&1 || true   # import the PNGs
"$GODOT" --headless --path . --script res://tools/build_godot.gd
"$GODOT" --headless --path . --script res://tools/test_mechanics.gd
