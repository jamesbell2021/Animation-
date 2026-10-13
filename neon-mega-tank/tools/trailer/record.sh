#!/usr/bin/env bash
# Films every trailer shot inside the game with Godot's Movie Maker, and exports the music and
# announcer lines the edit uses. Then run assemble.py. Needs Godot 4.3 on PATH (or GODOT=...)
# and a display: on a headless Linux box use  xvfb-run -a -s "-screen 0 1920x1080x24" ./record.sh
#   ./record.sh                 film every shot
#   ./record.sh boss finale     film only these
set -euo pipefail
cd "$(dirname "$0")/../.."
GODOT=${GODOT:-godot}
TAKES=tools/trailer/takes
mkdir -p "$TAKES"
printf '[editor]\n\nmovie_writer/mjpeg_quality=0.95\n' > override.cfg
trap 'rm -f override.cfg' EXIT

"$GODOT" --headless --path . -s tools/trailer/export_audio.gd -- "$TAKES"

SHOTS=${*:-reveal crew collapse shootdown combat shouts drones phones boss finale}
for shot in $SHOTS; do
	extra=""
	[ "$shot" = phones ] && extra="--touch"
	echo "== filming $shot"
	"$GODOT" --path . --resolution 1920x1080 --write-movie "$TAKES/$shot.avi" --fixed-fps 30 --quit-after 600 \
		-s tools/trailer/director.gd -- "$shot" $extra
done
