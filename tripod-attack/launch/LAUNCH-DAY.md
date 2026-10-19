# Tripod Attack! launch day: everything to upload and post

All files are in `launch/out/` (images, videos) and the builds are the three files from the
latest green **Tripod Attack builds** run on GitHub (also sent to you in chat):
`tripod-attack.apk`, `tripod-attack-windows.zip`, `tripod-attack-linux.zip`. The APK is signed
with the release key from the repository secrets, so later updates install over it.

## 1. itch.io: create the project (about 15 minutes)

1. Sign in at itch.io as the **gamesdevnisite** account, open **Dashboard → Create new project**.
2. **Title**: `Tripod Attack!`
   **Project URL**: `tripod-attack` (so the page is `gamesdevnisite.itch.io/tripod-attack`; the
   CI workflow pushes future builds there automatically once `BUTLER_API_KEY` is in the repository
   secrets).
   **Short description or tagline**:
   `Shoot the legs. Duck the Heat-Ray. Take Europe back. A Vectrex-style arcade game after H. G. Wells, with full-physics collapsing tripods.`
3. **Classification**: Game. **Kind of project**: Downloadable. **Release status**: Released.
4. **Pricing**: your call. Suggested: `$0 or donate` for the launch, or `$2.99` to sit under the
   other 3BL_Indie arcade games at $4.99.
5. **Uploads** (press *Upload files*, then set the platform box under each file):

   | File | Tick | Also |
   |---|---|---|
   | `tripod-attack-windows.zip` | Windows | Tick *This file will be played in the browser*? **No.** Leave as download. Mark **Executable**. |
   | `tripod-attack-linux.zip` | Linux | Mark **Executable**. |
   | `tripod-attack.apk` | Android | Nothing else. |

   Every zip contains the executable plus a README; players unzip and run.
6. **Description**: paste the block from "Page description" below (itch's editor keeps the bold
   lines and bullets if you paste as rich text; if it comes in plain, re-bold the five lead-ins).
7. **Genre**: Action. **Tags** (ten max): `arcade`, `retro`, `vectrex`, `war-of-the-worlds`,
   `physics`, `godot`, `2d`, `singleplayer`, `sci-fi`, `destruction`.
8. **AI generation disclosure** (itch asks this on the edit page): tick **Yes**, and in the
   categories tick **Code** only. Wording if a note is wanted: *"The code was written with an AI
   coding assistant. The graphics are drawn by that code as vector lines and the sound is
   synthesised by it; no image, audio or text generation model output is shipped. The quotations
   are H. G. Wells, 1898, public domain."*
9. **Cover image**: `cover_630x500.png`.
   **Screenshots**: upload `screenshots/01-heat-ray.jpg` through `09-game-over.jpg` in that
   order (drag to reorder if itch shuffles them). At least the first six.
   **Trailer**: itch wants a YouTube or Vimeo link. Upload `tripod-attack-gameplay-1080p.mp4` to
   YouTube first (title *Tripod Attack! gameplay*, unlisted is fine), then paste the link.
10. **Details** further down the form: *Made with*: Godot. *Average session*: A few minutes.
    *Languages*: English. *Inputs*: Keyboard, Mouse, Touchscreen, Gamepad (any).
    *Accessibility*: Subtitles. *Links*: `https://gamesdevni.site`.
11. **Community**: Comments. **Visibility & access**: Public. Save, then open the page and
    download each file once to check the three downloads work.

## 2. Page description (paste into the itch editor)

**The Martians have landed. Belfast is the last free city. You have a rocket launcher.**

TRIPOD ATTACK! is a Vectrex-style vector arcade game after H. G. Wells's *The War of the Worlds*.
Green lines on a black phosphor tube, showers of sparks, and an 80s arcade soundtrack synthesised
in code. Play it with a mouse, a touchscreen, a keyboard or a gamepad.

**Shoot the legs.** The fighting-machines' hoods are armour; rockets glance off. Each leg takes a
few hits, and a leg left alone reseals, so commit to one. Drag back and release to fire, like a
slingshot.

**Watch them fall.** The machines are real physics. Break a leg and the hood, the remaining legs
and the broken one come down under gravity, differently every time, crushing anything beneath.

**Duck the Heat-Ray.** Before a machine fires it stops, its lens glows red and it cries *Ulla*.
That is your warning, but the beam comes after a gap that is never the same twice, and from the
fourth sector it sweeps out and back. Get behind the sandbags or lose a life.

**Protect the people.** Small figures run from the ruins towards the shelter. Each one you get
there is points; the beam, a falling wreck or your own stray rocket will take them.

**Take Europe back.** Ten sectors from Belfast to Athens, each with its own vector skyline: the
Harland and Wolff cranes, the Castle rock, the Liver Birds, Big Ben, the Eiffel Tower, windmills,
the Brandenburg Gate, the Riesenrad, the Colosseum, the Parthenon. Lose all your lives and the
Martians retake the last sector you freed. Clear Athens to win, and unlock an endless high-score
mode set in Belfast.

Three difficulties, NORMAL, VETERAN and MASSACRE, each with its own high score tables.

Every line of text in the game is Wells's own, from the 1898 novel.

**Controls**

* Mouse or touch: drag back and release to fire. Hold the left side of the screen (or the right
  mouse button) to duck.
* Keyboard: arrows or WASD aim and set power, Enter fires, Space ducks, P pauses, M mutes.
* Gamepad: left stick aims, A fires, B ducks.

Windows, Linux and Android. Made with Godot 4 by 3BL_Indie, County Down. No music or sound
files: it is all synthesised when the game starts.

## 3. X (Twitter)

Attach `x_card_1200x675.jpg` or the 1080p gameplay video (X takes MP4 up to 2 min 20 s).

**Launch tweet** (248 characters):

> TRIPOD ATTACK! is out now 🛸 Shoot the legs. Duck the Heat-Ray. Take Europe back. A Vectrex-style arcade game after The War of the Worlds, with full-physics collapsing tripods. Windows · Linux · Android → GAME_URL #indiegame #godot #retrogaming

**Follow-up replies** (post as a thread under it, one at a time through the day):

> The machines are real physics. Every leg is a rigid body; break one and the whole thing comes down differently every time. Here's one going over. (attach `tripod-attack-reel.mp4` or a clip)

> Ten sectors, ten skylines: Belfast's cranes, Edinburgh's castle, Big Ben, the Eiffel Tower, the Brandenburg Gate, the Colosseum, the Parthenon. Lose your lives and the Martians take a city back.

> Every sound is synthesised in code, 80s arcade style: the siren cry, the Heat-Ray, the collapse. No audio files in the build at all. Every line of text in the game is Wells's own, 1898.

> Made in Godot 4 in County Down by a small studio. If you try it, tell us your best endless wave. GAME_URL

**Short version** (for a quote-post or Bluesky/Threads, 180 characters):

> Tripod Attack! is out: a vector arcade War of the Worlds. Shoot the legs, duck the Heat-Ray, take Europe back. Windows · Linux · Android. GAME_URL

## 4. Instagram

**Reel**: upload `tripod-attack-reel.mp4` (1080x1920, 34 s, with its own audio; use
`tripod-attack-reel-cover.jpg` as the cover frame). Caption:

> TRIPOD ATTACK! is out now 🛸
>
> Shoot the legs. Duck the Heat-Ray. Protect the people. Take Europe back.
>
> A Vectrex-style vector arcade game after H. G. Wells's The War of the Worlds. The fighting-machines are real physics: break a leg and the whole thing comes down differently every time, in a shower of sparks. Ten sectors from Belfast to Athens, each with its own skyline, then an endless mode in Belfast for the high score. Three difficulties. Every sound synthesised in code, 1980s arcade style.
>
> Windows · Linux · Android. Link in bio.
>
> #indiegame #indiedev #godot #godotengine #retrogaming #arcade #vectrex #vectorgraphics #waroftheworlds #hgwells #gamedev #indiegames #androidgames #pcgaming #belfast #northernireland #madeinni #scifi #80s #newrelease

**Feed post**: `instagram_1080x1080.jpg` as the first image, then `screenshots/01-heat-ray.jpg`,
`02-leg-down.jpg`, `03-wreck.jpg`, `06-campaign-map.jpg` as a carousel (Instagram crops 16:9
shots to 4:5 unless you choose "original" when adding them; choose original). Caption:

> Belfast is the last free city and the Martians are walking in. TRIPOD ATTACK! is out today for Windows, Linux and Android.
>
> Shoot the legs. Duck the Heat-Ray. Take Europe back, one city at a time.
>
> Link in bio. #indiegame #retrogaming #godot #waroftheworlds #belfast #madeinni #arcade #vectrex #newrelease #indiedev

**Story** (three slides, 15 s each): the reel's opening 15 s, then `instagram_1080x1080.jpg`
with a link sticker to the itch page, then `screenshots/02-leg-down.jpg` with a poll sticker
"Could you duck it?".

**Bio line**: `Tripod Attack! out now · Windows · Linux · Android` with the itch link.

## 5. Before you post

* Put the itch link in place of GAME_URL and in the Instagram bio.
* Upload the gameplay video to YouTube first so the itch trailer slot and the tweet have it.
* Play one wave on each file you downloaded from the itch page. If the Android install refuses,
  it is because an older APK with the throwaway key is still on the phone: uninstall it first.

## 6. itch.io page theme (Edit theme, top right of the project page)

The page should look like the game: green phosphor on black, with the studio orange on the one
thing people click.

| Setting | Value |
|---|---|
| Background color | `#000000` |
| Background image | none (the scanline look comes from the banner and screenshots) |
| Text color | `#EAFFEA` |
| Link color | `#3CFF5A` |
| Button color | `#FF8C2B` (3BL_Indie orange) |
| Button text color | `#000000` |
| Font | Monospace (closest itch offers to the game's stroke lettering; "Default" is fine if you prefer readable body text) |
| Banner image | `itch_banner_960x260.png` (replaces the title text; keep *Title* unticked) |
| Header text color (if title text is shown instead) | `#3CFF5A` |
| Header background color | `#000000` |
| Screenshots | Right of the description, "default" size |
| Layout | Default width, single column |
| Download button text | `Download`; the Android button itch labels on its own |
| Project theme colour for your profile and collection cards | `#3CFF5A` |

Hex reference, in case a field wants a different one: game green `#3CFF5A`, dim green `#1D8A33`,
Heat-Ray red `#FF3B3B`, amber `#FFD24A`, white `#EAFFEA`, studio orange `#FF8C2B`, studio cyan
`#1FC8DA`.
