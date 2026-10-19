#!/usr/bin/env bash
# Builds the three itch.io uploads into build/itch/:
#   ConnorsCarnivalChaos-windows.zip, ConnorsCarnivalChaos-linux.zip and
#   ConnorsCarnivalChaos-web.zip (the browser version: index.html at the top).
# Needs Godot 4.3 and its export templates (Godot: Editor > Manage Export
# Templates > Download and Install), plus zip.
#   tools/itch/build_itch.sh [path-to-godot]   (or set GODOT=/path/to/godot)
set -euo pipefail
cd "$(dirname "$0")/../.."
GODOT="${1:-${GODOT:-godot}}"
OUT=build/itch
rm -rf build/windows build/linux build/web "$OUT"
mkdir -p build/windows build/linux build/web "$OUT"

"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-release Windows build/windows/ConnorsCarnivalChaos.exe
"$GODOT" --headless --path . --export-release Linux build/linux/ConnorsCarnivalChaos.x86_64
"$GODOT" --headless --path . --export-release Web build/web/index.html

cp tools/itch/HOW_TO_PLAY.txt build/windows/
cp tools/itch/HOW_TO_PLAY.txt build/linux/
chmod +x build/linux/ConnorsCarnivalChaos.x86_64
(cd build/windows && zip -qr "../itch/ConnorsCarnivalChaos-windows.zip" .)
(cd build/linux && zip -qr "../itch/ConnorsCarnivalChaos-linux.zip" .)
(cd build/web && zip -qr "../itch/ConnorsCarnivalChaos-web.zip" .)
ls -lh "$OUT"
