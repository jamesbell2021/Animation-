#!/usr/bin/env bash
# Exports the Windows build and zips it with the version from project.godot:
#   build/SeaTheyAreAngry-v<version>-windows-x86_64.zip
# Needs Godot 4.3 with its export templates installed (GODOT=/path/to/godot, default "godot").
# Run from anywhere:  scripts/export_windows.sh
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
VERSION="$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)"
[ -n "$VERSION" ] || { echo "no application/config/version in project.godot" >&2; exit 1; }
OUT="build/windows"
ZIP="build/SeaTheyAreAngry-v${VERSION}-windows-x86_64.zip"
mkdir -p "$OUT"
# Refresh the class list the exporter needs, then export (the preset is in export_presets.cfg).
"$GODOT" --headless --editor --quit --path . >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-release "Windows" "$OUT/SeaTheyAreAngry.exe"
rm -f "$ZIP"
(cd "$OUT" && zip -q -r "../$(basename "$ZIP")" .)
echo "wrote $ZIP"
