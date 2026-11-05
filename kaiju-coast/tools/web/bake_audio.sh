#!/usr/bin/env bash
# Bakes the game's synthesised audio to Ogg in web_audio/ for the browser build (see
# scripts/audio_bank.gd). Run it again whenever the music, effects or voice lines change.
# Needs Godot 4.3 on PATH (or GODOT=...) and ffmpeg with libvorbis.
set -euo pipefail
cd "$(dirname "$0")/../.."
GODOT=${GODOT:-godot}
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
"$GODOT" --headless --path . res://tools/web/bake_audio.tscn -- --out="$WORK" 2>&1 | grep -v 'Parameter "m"\|mesh_get_surface' || true
test -f "$WORK/manifest.cfg"
rm -rf web_audio
mkdir -p web_audio
for wav in "$WORK"/*.wav; do
	name=$(basename "$wav" .wav)
	# Music gets a higher quality than the short effects and voices.
	q=3
	case "$name" in music_*) q=5 ;; esac
	ffmpeg -loglevel error -y -i "$wav" -c:a libvorbis -q:a $q "web_audio/$name.ogg"
done
cp "$WORK/manifest.cfg" web_audio/manifest.cfg
du -sh web_audio
