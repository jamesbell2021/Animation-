#!/usr/bin/env bash
# Records the gameplay reel shot by shot with Godot's Movie Maker and joins them
# into one 1280x720 MP4 with the game's own sound. Needs Godot (GODOT=/path),
# ffmpeg and, with no display, xvfb-run. Slow: every frame is rendered in full.
#   tools/reel/make_reel.sh [output.mp4]
# SHOTS="day beam" re-records just those; SKIP_RECORD=1 only re-joins.
set -euo pipefail
cd "$(dirname "$0")/../.."
GODOT="${GODOT:-godot}"
OUT="${1:-reel.mp4}"
WORK="${WORK:-build/reel}"
mkdir -p "$WORK"
RUN=()
if [ -z "${DISPLAY:-}" ] && command -v xvfb-run >/dev/null; then
	RUN=(xvfb-run -a -s "-screen 0 1280x720x24")
fi
ALL=(title day moves dusk beam ledge squid crab eel smotherer storm garden cottage trap flare dawn end)
read -r -a TODO <<< "${SHOTS:-${ALL[*]}}"
"$GODOT" --headless --editor --quit --path . >/dev/null 2>&1 || true
if [ "${SKIP_RECORD:-0}" != "1" ]; then
	for shot in "${TODO[@]}"; do
		echo "Recording $shot..."
		"${RUN[@]}" "$GODOT" --path . --resolution 1280x720 --write-movie "$WORK/$shot.avi" --fixed-fps 30 \
			-s res://tools/reel/reel_director.gd -- "shot=$shot" > "$WORK/$shot.log" 2>&1
	done
fi
python3 tools/reel/assemble.py "$WORK" "$OUT" "${ALL[@]}"
