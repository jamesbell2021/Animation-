#!/usr/bin/env bash
# Films every trailer shot inside the game with Godot's Movie Maker and renders the music.
# Then run assemble.py. Needs Godot 4.3 (GODOT=/path/to/godot) and a display; on a headless
# Linux box:  xvfb-run -a -s "-screen 0 1920x1080x24" tools/trailer/record.sh
#   tools/trailer/record.sh               film every shot
#   tools/trailer/record.sh sell chase    film only these
set -euo pipefail
cd "$(dirname "$0")/../.."
GODOT=${GODOT:-godot}
TAKES=tools/trailer/takes
mkdir -p "$TAKES"
printf '[editor]\n\nmovie_writer/mjpeg_quality=0.95\n' > override.cfg
trap 'rm -f override.cfg' EXIT

"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . -s res://tools/trailer/export_music.gd -- "$PWD/$TAKES/music.wav"

SHOTS=${*:-card_hello sell card_anyone creator card_police police card_legit chase card_empire empire events end}
for shot in $SHOTS; do
	echo "== filming $shot"
	"$GODOT" --path . --no-splash --resolution 1920x1080 --write-movie "$TAKES/$shot.avi" --fixed-fps 30 \
		res://tools/trailer/director.tscn -- "$shot" 2>&1 | grep -E "SCRIPT ERROR|^ERROR" | grep -v "status < 0" || true
done
ls -la "$TAKES"
