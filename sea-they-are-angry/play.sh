#!/usr/bin/env bash
# Launch Sea They Are Angry. On a fresh clone, first runs Godot's one-time import,
# which builds the class list in .godot/ that the scripts need.
# Usage: ./play.sh [path-to-godot-4.3]   (or set GODOT=/path/to/godot)
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
godot="${1:-${GODOT:-}}"
if [ -z "$godot" ]; then
	for c in godot4 godot "$HOME/Godot_v4.3-stable_linux.x86_64" "$here/../Godot_v4.3-stable_linux.x86_64"; do
		if command -v "$c" >/dev/null 2>&1 || [ -x "$c" ]; then
			godot="$c"
			break
		fi
	done
fi
if [ -z "$godot" ]; then
	echo "Godot 4.3 not found. Pass its path: ./play.sh ~/Godot_v4.3-stable_linux.x86_64" >&2
	exit 1
fi
if [ ! -f "$here/.godot/global_script_class_cache.cfg" ]; then
	echo "First run: importing the project (a few seconds)..."
	"$godot" --headless --editor --quit --path "$here" >/dev/null 2>&1 || true
fi
exec "$godot" --path "$here"
