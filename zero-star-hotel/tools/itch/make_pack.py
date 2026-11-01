#!/usr/bin/env python3
"""Builds an itch.io upload pack for this game:

    <Game>-itch-pack/
      web/<Game>-web.zip         upload as the HTML5 file ("This file will be played in the browser")
      android/<Game>.apk         upload as the Android download
      page/                      store page text, how-to-play, cover image
      media/                     screenshots, trailer and poster
      UPLOAD_GUIDE.txt           the itch.io settings to pick, step by step
    <Game>-itch-pack.zip         the same folder, zipped

The web zip uses tools/itch/loader.html (a tap-to-play loader that unlocks sound on phones)
instead of Godot's default page. Run from the game folder:

    python3 tools/itch/make_pack.py --godot /path/to/godot --apk build/apk/Game.apk \\
        --screens /path/to/screenshots --trailer tools/trailer/out/game_trailer.mp4 --out /tmp/packs
"""
import argparse
import glob
import os
import re
import shutil
import subprocess
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.abspath(os.path.join(HERE, "..", ".."))

PROFILES = {
    "lookee-lookee-tycoon": {
        "title": "Lookee Lookee Tycoon", "file": "LookeeLookeeTycoon", "mascot": "vendor.png",
        "page": "itch/PAGE.md", "howto": "tools/itch/HOW_TO_PLAY.txt", "cover": "itch/cover.png",
        "tagline": "Hello chicken nugget! Sell plastic junk to tourists on the Costa and dodge the police.",
        "genre": "Simulation", "tags": "tycoon, management, comedy, beach, funny, casual, mobile, character-customization",
    },
    "zero-star-hotel": {
        "title": "Zero Star Hotel", "file": "ZeroStarHotel", "mascot": "manager.png",
        "page": "store/PAGE.md", "howto": "store/HOW_TO_PLAY.txt", "cover": "store/cover.png",
        "tagline": "Run the worst hotel on the Costa: drunken lads, cockroaches, lounger wars. Reach three stars.",
        "genre": "Simulation", "tags": "tycoon, management, comedy, hotel, funny, casual, mobile, time-management",
    },
}

GUIDE = """{title} - itch.io upload guide
{rule}

Do this on itch.io (Dashboard > Create new project). Everything you need is in this pack.

1. DETAILS
   Title:            {title}
   Project URL:      {slug}
   Short description / tagline:
                     {tagline}
   Classification:   Games
   Kind of project:  HTML   (so it plays in the browser; the APK goes in as a download too)
   Release status:   Released
   Pricing:          your choice (e.g. "No payments" or "$0 or donate")

2. UPLOADS
   a) Upload  web/{file}-web.zip
      Tick "This file will be played in the browser".
   b) Upload  android/{file}.apk
      Tick the Android platform icon next to it.

3. EMBED OPTIONS (shown once the web zip is uploaded)
   Viewport dimensions:  1280 x 720
   [x] Mobile friendly        Orientation: Landscape
   [ ] Automatically start on page load: leave OFF (the game has its own PLAY button)
   [x] Fullscreen button
   [ ] SharedArrayBuffer support: leave OFF (not needed)
   Frame options: "Click to launch in fullscreen" is optional; "Embed in page" is the usual.

4. DETAILS (lower down the page)
   Description:   paste page/PAGE.md (itch.io's editor accepts the text; tidy headings if you like)
   Genre:         {genre}
   Tags:          {tags}
   Cover image:   page/cover.png (630 x 500)
   Screenshots:   everything in media/screenshots/
   Gameplay video or trailer: itch.io only takes a YouTube or Vimeo link.
                  Upload media/{file}-trailer.mp4 to YouTube, then paste the link.
   Visibility:    Draft while you check it, then Public when you're happy.

5. CHECK BEFORE GOING PUBLIC
   - Open the page, press PLAY, and tap "Test sound" on the loading screen.
   - On a phone, turn it sideways.
   - Install the APK on an Android phone.

ABOUT THE APK
   This APK is a debug build signed with a throwaway key. It installs and plays fine, but
   each new version needs the old one uninstalled first (players lose their save), and the
   Google Play Store won't accept it. For a proper release, make one permanent signing key,
   keep it safe, and sign every future build with it.

SCHEDULING
   itch.io has no "publish at a set time" button. To go live at a particular time, finish
   everything as a Draft, then switch Visibility to Public at that time.
"""


def run(cmd, **kw):
    print("+", " ".join(cmd))
    subprocess.run(cmd, check=True, **kw)


def zip_dir(src, dst):
    with zipfile.ZipFile(dst, "w", zipfile.ZIP_DEFLATED) as z:
        for root, _, files in os.walk(src):
            for f in sorted(files):
                p = os.path.join(root, f)
                z.write(p, os.path.relpath(p, src))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--godot", required=True)
    ap.add_argument("--apk", required=True)
    ap.add_argument("--screens", required=True, help="folder of PNG screenshots")
    ap.add_argument("--trailer", default="")
    ap.add_argument("--poster", default="")
    ap.add_argument("--mascot", default="", help="PNG shown on the loading screen")
    ap.add_argument("--out", required=True)
    ap.add_argument("--skip-export", action="store_true")
    a = ap.parse_args()
    prof = PROFILES[os.path.basename(GAME)]
    name = prof["file"]
    pack = os.path.join(a.out, f"{name}-itch-pack")
    shutil.rmtree(pack, ignore_errors=True)
    for d in ["web", "android", "page", "media/screenshots"]:
        os.makedirs(os.path.join(pack, d))

    # Web: fresh export, then swap in the itch.io loader page.
    web = os.path.join(GAME, "build", "web")
    if not a.skip_export:
        shutil.rmtree(web, ignore_errors=True)
        os.makedirs(web)
        run([a.godot, "--headless", "--path", GAME, "--export-release", "Web", os.path.join(web, "index.html")])
    exported = open(os.path.join(web, "index.html")).read()
    config = re.search(r"const GODOT_CONFIG = (\{.*?\});", exported).group(1)
    loader = open(os.path.join(HERE, "loader.html")).read().replace("__GODOT_CONFIG__", config)
    stage = os.path.join(a.out, f"_{name}_web")
    shutil.rmtree(stage, ignore_errors=True)
    os.makedirs(stage)
    for f in ["index.js", "index.wasm", "index.pck", "index.audio.worklet.js"]:
        shutil.copy(os.path.join(web, f), stage)
    open(os.path.join(stage, "index.html"), "w").write(loader)
    if a.mascot:
        shutil.copy(a.mascot, os.path.join(stage, prof["mascot"]))
    zip_dir(stage, os.path.join(pack, "web", f"{name}-web.zip"))
    shutil.rmtree(stage)

    shutil.copy(a.apk, os.path.join(pack, "android", f"{name}.apk"))
    shutil.copy(os.path.join(GAME, prof["page"]), os.path.join(pack, "page", "PAGE.md"))
    shutil.copy(os.path.join(GAME, prof["howto"]), os.path.join(pack, "page", "HOW_TO_PLAY.txt"))
    shutil.copy(os.path.join(GAME, prof["cover"]), os.path.join(pack, "page", "cover.png"))
    for i, png in enumerate(sorted(glob.glob(os.path.join(a.screens, "*.png")))):
        shutil.copy(png, os.path.join(pack, "media", "screenshots", os.path.basename(png)))
    if a.trailer:
        shutil.copy(a.trailer, os.path.join(pack, "media", f"{name}-trailer.mp4"))
    if a.poster:
        shutil.copy(a.poster, os.path.join(pack, "media", f"{name}-poster.jpg"))
    slug = prof["title"].lower().replace(" ", "-")
    with open(os.path.join(pack, "UPLOAD_GUIDE.txt"), "w") as f:
        f.write(GUIDE.format(rule="=" * (len(prof["title"]) + 24), slug=slug, **prof))
    zip_dir(pack, pack + ".zip")
    print("pack ->", pack + ".zip")


if __name__ == "__main__":
    main()
