#!/usr/bin/env bash
# Builds the itch.io uploads into build/itch/:
#   ConnorsCarnivalChaos-windows.zip, ConnorsCarnivalChaos-linux.zip,
#   ConnorsCarnivalChaos-web.zip (the browser version: index.html at the top)
#   and, when a release keystore is given, ConnorsCarnivalChaos-android.apk.
# Needs Godot 4.3 and its export templates (Godot: Editor > Manage Export
# Templates > Download and Install), plus zip. For Android also set the Android
# SDK in Godot's Editor Settings (Export > Android) and:
#   ANDROID_KEYSTORE=/path/to/connors-carnival-chaos-release.keystore
#   ANDROID_KEYSTORE_PASSWORD=...   (the alias is connorscarnivalchaos)
# Always sign with that same keystore, or phones won't install the update.
#   tools/itch/build_itch.sh [path-to-godot]   (or set GODOT=/path/to/godot)
set -euo pipefail
cd "$(dirname "$0")/../.."
GODOT="${1:-${GODOT:-godot}}"
OUT=build/itch
rm -rf build/windows build/linux build/web build/android "$OUT"
mkdir -p build/windows build/linux build/web build/android "$OUT"

"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-release Windows build/windows/ConnorsCarnivalChaos.exe
"$GODOT" --headless --path . --export-release Linux build/linux/ConnorsCarnivalChaos.x86_64
"$GODOT" --headless --path . --export-release Web build/web/index.html
if [ -n "${ANDROID_KEYSTORE:-}" ]; then
	GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$ANDROID_KEYSTORE" \
	GODOT_ANDROID_KEYSTORE_RELEASE_USER=connorscarnivalchaos \
	GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="${ANDROID_KEYSTORE_PASSWORD:?set ANDROID_KEYSTORE_PASSWORD}" \
		"$GODOT" --headless --path . --export-release Android build/android/ConnorsCarnivalChaos.apk
	cp build/android/ConnorsCarnivalChaos.apk "$OUT/ConnorsCarnivalChaos-android.apk"
else
	echo "No ANDROID_KEYSTORE set: skipping the Android build."
fi

cp tools/itch/HOW_TO_PLAY.txt build/windows/
cp tools/itch/HOW_TO_PLAY.txt build/linux/
chmod +x build/linux/ConnorsCarnivalChaos.x86_64
(cd build/windows && zip -qr "../itch/ConnorsCarnivalChaos-windows.zip" .)
(cd build/linux && zip -qr "../itch/ConnorsCarnivalChaos-linux.zip" .)
(cd build/web && zip -qr "../itch/ConnorsCarnivalChaos-web.zip" .)
ls -lh "$OUT"
