#!/usr/bin/env bash
# Films every trailer shot inside the game with Godot's Movie Maker, and exports the music and
# voice lines the edit uses. Then run assemble.py. Needs Godot 4.3 on PATH (or GODOT=...)
# and a display: on a headless Linux box use  xvfb-run -a -s "-screen 0 1920x1080x24" ./record.sh
#   ./record.sh                 film every shot
#   ./record.sh orochi finale   film only these
set -euo pipefail
cd "$(dirname "$0")/../.."
GODOT=${GODOT:-godot}
TAKES=tools/trailer/takes
mkdir -p "$TAKES"
printf '[editor]\n\nmovie_writer/mjpeg_quality=0.95\n' > override.cfg
trap 'rm -f override.cfg' EXIT

"$GODOT" --headless --path . res://tests/audio_preview.tscn -- --out="$TAKES" 2>&1 | grep -v 'Parameter "m"\|mesh_get_surface' || true

SHOTS=${*:-reveal wade build gunner rockets airship airstrike storm flood rampage orochi finale}
for shot in $SHOTS; do
	echo "== filming $shot"
	"$GODOT" --path . --rendering-driver opengl3 --resolution 1920x1080 --write-movie "$TAKES/$shot.avi" \
		--fixed-fps 30 --quit-after 900 res://tools/trailer/director.tscn -- "$shot" 2>&1 \
		| grep -v 'Parameter "m"\|mesh_get_surface\|^ALSA\|snd_' || true
done
