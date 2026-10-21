# Launch checklist: Car Carnage: Belfast Edition on itch.io

Everything here is prepared; the steps marked **you** need your itch.io or GitHub login.

## 1. Build - automatic, or one command

Every push that touches `car-carnage-belfast/` runs **Actions → Car Carnage Belfast**, which
runs the engine test and leaves two artifacts: `car-carnage-belfast-html5` (the browser game,
`index.html` at the root of the zip, as itch.io requires) and `car-carnage-belfast-server`
(the online game server with start scripts).

By hand, from the game's folder: `tools/pack.sh` writes the same two zips to `dist/`.

The version comes from `package.json`. Bump it before each release.

## 2. Art - done

`launch/out/` holds the cover (`cover_630x500.png`), a banner (`banner_1920x480.png`) and a
screenshot of every arena (`shot_<arena>.png`), all rendered from the game itself by
`node launch/make_art.mjs` (needs the `playwright` package and its Chromium). Re-run it after
any change to the art.

## 3. itch.io project page - you

itch.io → **Dashboard → Create new project**, fill it from `itch-page.md`: title, tagline,
description, **Kind of project: HTML**, the embed settings, tags, cover, screenshots. Upload
`car-carnage-belfast-html5.zip` and tick **This file will be played in the browser**. Upload
`car-carnage-belfast-server.zip` as a plain download with the "Download text" from
`itch-page.md`. Save as **Draft**, open the page, and check:

* the title screen loads with cars driving about behind the menu and the music starts on the
  first click;
* **PLAY ON THIS DEVICE** runs a full turn;
* **PLAY ONLINE** opens the **Game server** box with the note about entering an address (the
  itch.io page has no server of its own);
* the fullscreen button works and a phone shows the panel under the map.

Then set it to **Public**.

## 4. Publishing with butler - optional, you

Add the repository secret `BUTLER_API_KEY` (itch.io → **Settings → API keys**) on GitHub
(**Settings → Secrets and variables → Actions**). After that, pushing a tag such as
`git tag ccb-v1.0.0 && git push origin ccb-v1.0.0`, or running the workflow by hand with
**Push the builds to itch.io** ticked, uploads the html5 zip to the `html5` channel and the
server zip to the `server` channel of `gamesdevnisite/car-carnage-belfast`. The first push
creates the channels; on the page, tick "played in the browser" on the html5 one once.

## 5. Online games for players - how it works

The itch.io page plays the game from itch's own https servers, which can only talk to an https
game server. Three ways to run online games:

1. **Same Wi-Fi, no itch.io:** run the server zip, everyone opens the address it prints. The
   game is served by the server itself, so nothing else is needed. This is the easy one.
2. **Over the internet:** run the server, then `cloudflared tunnel --url http://localhost:8080`
   (free, from cloudflare.com) prints an https link. Share that link: people open it and play.
3. **From the itch.io page:** as 2, but players paste the https link under **Game server** on
   the PLAY ONLINE screen instead of opening it.

If you want a permanent public server, any small host that runs Node (a $5 VPS, Fly.io,
Railway, Render) can run `node server.js` with `PORT` set; put its https address in the
description so players can paste it.
