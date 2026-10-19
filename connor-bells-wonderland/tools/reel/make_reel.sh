#!/usr/bin/env bash
# Records the promo reel and joins it into a vertical 1080x1920 MP4 for
# Instagram Reels / phones. Needs Godot (GODOT=/path/to/godot), ffmpeg and,
# on a machine with no display, xvfb-run. Takes a while: each shot renders
# frame by frame with Godot's Movie Maker.
#   tools/reel/make_reel.sh [output.mp4]
set -euo pipefail
cd "$(dirname "$0")/../.."
GODOT="${GODOT:-godot}"
OUT="${1:-reel.mp4}"
WORK="${WORK:-build/reel}"
mkdir -p "$WORK"
RUN=()
if [ -z "${DISPLAY:-}" ] && command -v xvfb-run >/dev/null; then
	RUN=(xvfb-run -a -s "-screen 0 1080x1920x24")
fi

"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . -s res://tools/reel/export_music.gd -- "out=$PWD/$WORK/music.wav"

SHOTS=(title race paintball finale end)
if [ "${SKIP_RECORD:-0}" != "1" ]; then
	for shot in "${SHOTS[@]}"; do
		echo "Recording $shot..."
		"${RUN[@]}" "$GODOT" --path . --resolution 1080x1920 --write-movie "$WORK/$shot.avi" --fixed-fps 30 \
			-s res://tools/reel/reel_director.gd -- --no-splash "shot=$shot" > "$WORK/$shot.log" 2>&1
	done
fi
python3 tools/reel/assemble.py "$WORK" "$OUT"
