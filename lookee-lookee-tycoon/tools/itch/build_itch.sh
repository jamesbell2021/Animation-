#!/usr/bin/env bash
# Builds the itch.io uploads into build/itch/:
#   LookeeLookeeTycoon-web.zip      (the browser version: index.html at the top of the zip)
#   LookeeLookeeTycoon-windows.zip, LookeeLookeeTycoon-linux.zip
#   LookeeLookeeTycoon-android.apk  (only when a release keystore is given)
# Needs Godot 4.3 and its export templates (Godot: Editor > Manage Export Templates >
# Download and Install), plus zip. For Android also set the Android SDK and JDK in Godot's
# Editor Settings (Export > Android) and:
#   ANDROID_KEYSTORE=/path/to/lookee-release.keystore
#   ANDROID_KEYSTORE_USER=lookee          (the key alias)
#   ANDROID_KEYSTORE_PASSWORD=...
# Always sign with the same keystore, or phones won't install the update.
#   tools/itch/build_itch.sh [path-to-godot]   (or set GODOT=/path/to/godot)
set -euo pipefail
cd "$(dirname "$0")/../.."
GODOT="${1:-${GODOT:-godot}}"
OUT=build/itch
rm -rf build/web build/windows build/linux build/android "$OUT"
mkdir -p build/web build/windows build/linux build/android "$OUT"

"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
echo "Running the smoke test first (your save is backed up and restored)..."
"$GODOT" --headless --path . res://tests/smoke_test.tscn | tail -3
"$GODOT" --headless --path . --export-release Web build/web/index.html
"$GODOT" --headless --path . --export-release Windows build/windows/LookeeLookeeTycoon.exe
"$GODOT" --headless --path . --export-release Linux build/linux/LookeeLookeeTycoon.x86_64
if [ -n "${ANDROID_KEYSTORE:-}" ]; then
	GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$ANDROID_KEYSTORE" \
	GODOT_ANDROID_KEYSTORE_RELEASE_USER="${ANDROID_KEYSTORE_USER:-lookee}" \
	GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="${ANDROID_KEYSTORE_PASSWORD:?set ANDROID_KEYSTORE_PASSWORD}" \
		"$GODOT" --headless --path . --export-release Android build/android/LookeeLookeeTycoon.apk
	cp build/android/LookeeLookeeTycoon.apk "$OUT/LookeeLookeeTycoon-android.apk"
else
	echo "No ANDROID_KEYSTORE set: skipping the Android build."
fi

cp tools/itch/HOW_TO_PLAY.txt build/windows/
cp tools/itch/HOW_TO_PLAY.txt build/linux/
chmod +x build/linux/LookeeLookeeTycoon.x86_64
(cd build/web && zip -qr "../itch/LookeeLookeeTycoon-web.zip" .)
(cd build/windows && zip -qr "../itch/LookeeLookeeTycoon-windows.zip" .)
(cd build/linux && zip -qr "../itch/LookeeLookeeTycoon-linux.zip" .)
ls -lh "$OUT"
