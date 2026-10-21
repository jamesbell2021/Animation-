#!/usr/bin/env sh
# Starts the Car Carnage: Belfast Edition game server (needs Node 18 or newer: https://nodejs.org).
cd "$(dirname "$0")"
command -v node >/dev/null 2>&1 || { echo "Node.js is not installed. Get it from https://nodejs.org and run this again."; exit 1; }
node server.js "${1:-8080}"
