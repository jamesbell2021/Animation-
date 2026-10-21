#!/usr/bin/env sh
# Packs Car Carnage: Belfast Edition for itch.io.
#   tools/pack.sh            -> dist/car-carnage-belfast-html5.zip   (upload as "This file will be played in the browser")
#                               dist/car-carnage-belfast-server.zip  (the online game server, a downloadable file)
# The HTML5 zip has index.html at its root, as itch.io requires. It plays on one device with
# no server; online play needs the server zip (node server.js) and the address typed in.
set -e
cd "$(dirname "$0")/.."
version=$(node -p "require('./package.json').version")
rm -rf dist && mkdir -p dist/html5 dist/server
cp -r web/. dist/html5/
printf '%s' "$version" > dist/html5/version.txt
cp -r web server.js ws.js package.json README.md tools/start.sh tools/start.bat dist/server/
(cd dist/html5 && zip -qr ../car-carnage-belfast-html5.zip .)
(cd dist && mv server car-carnage-belfast-server && zip -qr car-carnage-belfast-server.zip car-carnage-belfast-server && rm -r car-carnage-belfast-server html5)
ls -la dist
echo "version $version"
