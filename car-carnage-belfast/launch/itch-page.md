# itch.io page: Car Carnage: Belfast Edition

Paste the description block into the itch.io project's **Description**. Page settings are at the
end. The two uploads come from `tools/pack.sh` (or the **Car Carnage Belfast** workflow's
artifacts): `car-carnage-belfast-html5.zip` is the browser game, `car-carnage-belfast-server.zip`
is the online game server.

---

## Description

**Eight drivers. One second at a time. Everybody moves at once.**

Car Carnage: Belfast Edition is turn-based car combat in a Belfast that has been through the
bombs. Set your speed, a steering move for each of the five phases of the second, and what to
shoot. Hit **ACTION**. When every driver has, all the cars move at once and the second plays out
in real time: tracers, lasers, rockets, flamethrowers, oil slicks, mines, head-on crashes, rolls,
jumps, fires and explosions, in slow motion where it counts, to a pumping synthesised
soundtrack. When the dust settles, the host decides whether everyone watches the whole match
back as a film, with a camera that hunts for the action, or skips to the standings.

**The rules are the classic ones.** Adapted from the *Car Wars* classic rules: the movement
chart, bends and drifts with their difficulties, the bootlegger reverse, the control table and
both crash tables, to-hit rolls with range, speed, size and smoke modifiers, armour by side with
weapons, power plant and driver behind it, ramming damage by speed and weight. Before you commit
a move the game draws where it takes you and tells you the control roll it needs.

**Belfast, 2041.** Seven arenas drawn in code: the shipyard under Samson and Goliath with a
flooded dry dock to jump, Donegall Square with City Hall's dome in a crater, the glowing Lagan
with its broken bridge and the Big Fish, the Peace Line, Cave Hill, Stormont's mile of straight
road, and the yard of Crumlin Road Gaol. Weak walls can be smashed through. Green pools are
fallout. Striped ramps are jumps.

**Sixteen cars and a garage.** Stock cars from the rulebook with local names, from the Belfast
Bap (one machine gun, tinfoil armour, 135 mph) to the Harland Hammer (autocannon, turreted
Vulcan, six solid tyres), and a garage that builds your own to the design rules.

**Play it three ways.**

* **In the browser, on one device:** pass-and-play. Each driver sets their orders behind a
  hand-over screen, bots take the empty seats. No server, no install. Works on a phone.
* **Online, up to eight:** download the server, run `start` (needs Node.js), share the address
  and the four-letter room code. Bots fill empty seats, there is a turn timer and chat.
* **Against the bots:** they plan with the same rules you do, and they will ram you.

All the art is vector drawing done in code and all the sound is synthesised, so the whole game
is a few plain JavaScript files.

Adapted from *Car Wars* by Steve Jackson Games. A fan project, not affiliated. Made by 3BL.

---

## Page settings

| Field | Value |
|---|---|
| Title | Car Carnage: Belfast Edition |
| Project URL | `gamesdevnisite.itch.io/car-carnage-belfast` (the workflow pushes to this name; change `ITCH_PROJECT` in `.github/workflows/car-carnage-belfast.yml` if you pick another) |
| Short description / tagline | Eight-player turn-based car combat in post-nuclear Belfast. Set your moves, hit ACTION, everybody moves at once. Watch the carnage back as a film. |
| Classification | Game |
| Kind of project | **HTML** (the html5 zip plays in the browser; the server zip is an extra download) |
| Pricing | No payments, or **$2.99 or more** if you want to charge (the browser game is still playable for free on itch unless you tick "Only paid users can play") |
| Embed options | Viewport **1280 × 720**, **Fullscreen button** on, **Mobile friendly** on, **Automatically start on page load** off |
| Genre | Strategy |
| Tags (up to 10) | turn-based, multiplayer, cars, vehicular-combat, car-wars, belfast, post-apocalyptic, html5, local-multiplayer, strategy |
| Made with | None of the above (hand-written JavaScript and the Web Audio API) |
| Average session | About half an hour |
| Languages | English |
| Inputs | Mouse, Touchscreen |
| Multiplayer | Local multiplayer, Server-based networked multiplayer |
| Player count | Singleplayer, Multiplayer |
| Release status | Released |
| Cover image | `launch/out/cover_630x500.png` |
| Screenshots | `launch/out/shot_titanic.png`, `shot_lagan.png`, `shot_cityhall.png`, `shot_peaceline.png`, `shot_stormont.png`, `shot_cavehill.png`, `shot_gaol.png`, then `docs/planning.jpg`, `docs/replay.jpg`, `docs/lobby.jpg` |
| Uploads | `car-carnage-belfast-html5.zip` ticked **This file will be played in the browser**; `car-carnage-belfast-server.zip` as a downloadable file, platforms Windows, macOS, Linux, labelled "Online game server (needs Node.js)" |
| Community | Comments |

## Download text

Shown next to the server zip:

> **Online game server.** Unzip, run `start.bat` (Windows) or `start.sh` (Mac, Linux). It needs
> Node.js from nodejs.org. Everyone on your Wi-Fi opens the address it prints and joins with the
> room code. To play with people elsewhere, or to use the server from this itch.io page, put it
> behind an https tunnel (for example `cloudflared tunnel --url http://localhost:8080`) and give
> players that link, or paste it under **Game server** on the PLAY ONLINE screen.
