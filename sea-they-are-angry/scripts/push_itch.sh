#!/usr/bin/env bash
# Pushes the Windows build to itch.io with butler, as the "windows" channel, tagged with
# the version in project.godot. Not run by anything: you run it, once you have a page.
#
#   BUTLER_TARGET=youruser/sea-they-are-angry scripts/push_itch.sh
#
# Install butler from https://itch.io/docs/butler/ (it must be on the PATH), and log in
# once with `butler login`. Run scripts/export_windows.sh first.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${BUTLER_TARGET:?set BUTLER_TARGET to <itch user>/<game page>, e.g. youruser/sea-they-are-angry}"
VERSION="$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)"
[ -d build/windows ] || { echo "no build/windows: run scripts/export_windows.sh first" >&2; exit 1; }
butler push build/windows "${BUTLER_TARGET}:windows" --userversion "$VERSION"
