#!/usr/bin/env bash
# Launch Connor Bell's Wonderland.
# Godot needs a one-time import that builds the list of named scripts in .godot/.
# This runs it on a fresh clone, and again whenever a script is newer than that
# list (for example after a git pull) or a different Godot version is used.
# Usage: ./play.sh [path-to-godot]   (or set GODOT=/path/to/godot)
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
godot="${1:-${GODOT:-}}"
if [ -z "$godot" ]; then
	for c in godot godot4 "$HOME/Godot_v4.3-stable_linux.x86_64"; do
		if command -v "$c" >/dev/null 2>&1 || [ -x "$c" ]; then
			godot="$c"
			break
		fi
	done
fi
if [ -z "$godot" ]; then
	echo "Godot not found. Install it (sudo pacman -S godot) or pass its path: ./play.sh ~/Godot_v4.3-stable_linux.x86_64" >&2
	exit 1
fi
cache="$here/.godot/global_script_class_cache.cfg"
stamp="$here/.godot/play_sh_godot_version"
version="$("$godot" --version 2>/dev/null | tail -n 1 || true)"
if [ ! -f "$cache" ] || [ "$(cat "$stamp" 2>/dev/null || true)" != "$version" ] \
	|| [ -n "$(find "$here/scripts" -name '*.gd' -newer "$cache" -print -quit)" ]; then
	echo "Importing the project (a few seconds)..."
	"$godot" --headless --path "$here" --import >/dev/null 2>&1 || true
	touch "$cache" 2>/dev/null || true
	printf '%s' "$version" > "$stamp" 2>/dev/null || true
fi
exec "$godot" --path "$here" "${@:2}"
