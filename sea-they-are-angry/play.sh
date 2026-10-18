#!/usr/bin/env bash
# Launch Sea They Are Angry. Runs Godot's import first whenever it is needed (fresh clone,
# or files changed since the last import), which builds the class list the scripts rely on.
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
# Re-import when the class list is missing or any script, shader or model is newer than it
# (a git pull that adds a class_name script otherwise fails with "Identifier not declared").
cache="$here/.godot/global_script_class_cache.cfg"
if [ ! -f "$cache" ] || [ -n "$(find "$here" -path "$here/.godot" -prune -o \( -name '*.gd' -o -name '*.gdshader' -o -name '*.glb' \) -newer "$cache" -print -quit)" ]; then
	echo "Importing the project (a few seconds)..."
	"$godot" --headless --editor --quit --path "$here" >/dev/null 2>&1 || true
	touch "$cache"
fi
exec "$godot" --path "$here"
