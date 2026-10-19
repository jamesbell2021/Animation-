# itch.io page: Tripod Attack!

Everything for the itch.io project page, field by field. Files are in `launch/out/` (made by
`tools/make_itch_art.py`, `tools/make_reel.py` and the `--shots` demo at 1920x1080) and the
builds come from the **Tripod Attack builds** GitHub Actions run (also in `build/dist/` locally).

## Basic info

| Field | Value |
|---|---|
| Title | Tripod Attack! |
| Project URL | `gamesdevnisite.itch.io/tripod-attack` (the CI workflow pushes to this name; change `ITCH_PROJECT` in `.github/workflows/tripod-attack-builds.yml` if you pick another) |
| Short description / tagline | Shoot the legs. Duck the Heat-Ray. Take Europe back. A Vectrex-style arcade game after H. G. Wells, with full-physics collapsing tripods. |
| Classification | Game |
| Kind of project | Downloadable |
| Release status | Released |
| Pricing | Your call. The other 3BL_Indie arcade games are $4.99 with the bundle at $5.99; this one is a single-player arcade game of similar size. "$0 or donate" is the other sensible option for a launch. |
| Genre | Action (Shooter) |
| Tags (itch allows 10) | arcade, retro, vectrex, war-of-the-worlds, physics, godot, 2d, singleplayer, sci-fi, destruction |
| Custom noun | game |
| Made with | Godot |
| Average session | A few minutes |
| Languages | English |
| Inputs | Keyboard, Mouse, Touchscreen, Gamepad (any) |
| Accessibility | Subtitles (every sound cue also has an on-screen cue: the siren shows "ULLA...", hits show text) |
| Links | gamesdevni.site; source and builds: the GitHub repository |
| Multiplayer | No |
| AI generation disclosure | The code was written with an AI coding assistant (Claude). The graphics are drawn procedurally by that code as vector lines and the sound is synthesised by it; no image, audio or text generation model output is shipped. Tick "Code" (and the others only if you prefer to be conservative). The quotations are H. G. Wells, 1898, public domain. |
| Community | Comments (or a discussion board if you want bug reports kept separate) |
| Visibility | Public when ready |

## Uploads

| File (from `build/dist/`) | Size | "This file will be played on" | Notes |
|---|---|---|---|
| `tripod-attack-windows.zip` | 30 MB | Windows (64-bit) | Contains `TripodAttack.exe` (everything embedded) and the README. Mark as "Executable". Works with the itch app. |
| `tripod-attack-linux.zip` | 24 MB | Linux (64-bit) | Contains `TripodAttack.x86_64` and the README. Mark as "Executable". |
| `tripod-attack.apk` | 45 MB | Android | arm64 and armv7, landscape. Current file is a debug build with a throwaway key: fine to play, but a later release-signed build will not install over it. Add the `ANDROID_RELEASE_KEYSTORE_*` secrets and re-run the workflow before you want updates to install cleanly. |

Later releases: tag `ta-v1.0.1` (or run the workflow by hand with "Push the builds to itch.io"
ticked) and butler uploads all three channels, once the project exists and `BUTLER_API_KEY` is
set in the repository secrets.

## Images

| Slot | File | Notes |
|---|---|---|
| Cover image (630x500) | `launch/out/cover_630x500.png` | Title, the machine, the Heat-Ray, the three taglines, the 3BL_Indie logo |
| Screenshots (in this order) | `launch/out/screenshots/01-heat-ray.jpg` … `09-game-over.jpg` | Nine 1920x1080 frames from the engine: the Heat-Ray over the ducked artilleryman, a leg blown off, the wreck, a machine walking in, the cry, the campaign map, the sector briefing, the title, game over. Use at least the first six. |
| Trailer (YouTube or Vimeo link) | `launch/out/tripod-attack-gameplay-1080p.mp4` | 34 s of the scripted take, 1920x1080, with the game audio. Upload it to YouTube as the trailer; the vertical reel (`tripod-attack-reel.mp4`) can go up as a Short. |
| Icon (for the bundle/collection page) | `launch/out/icon_512.png` | |

## Description (paste into the page body)

**The Martians have landed. Belfast is the last free city. You have a rocket launcher.**

TRIPOD ATTACK! is a Vectrex-style vector arcade game after H. G. Wells's *The War of the Worlds*.
Green lines on a black phosphor tube, showers of sparks, and an 80s arcade soundtrack synthesised
in code. Play it with a mouse, a touchscreen, a keyboard or a gamepad.

**Shoot the legs.** The fighting-machines' hoods are armour; rockets glance off. Each leg takes a
few hits. Drag back and release to fire, like a slingshot.

**Watch them fall.** The machines are real physics. Break a leg and the hood, the remaining legs
and the broken one come down under gravity, differently every time, crushing anything beneath.

**Duck the Heat-Ray.** Before a machine fires it stops, its lens glows red and it cries *Ulla*.
That is your warning. The beam sweeps the whole field; get behind the sandbags or lose a life.

**Protect the people.** Small figures run from the ruins towards the shelter. Each one you get
there is points; the beam, a falling wreck or your own stray rocket will take them.

**Take Europe back.** Ten sectors from Belfast to Athens, each with its own vector skyline: the
Harland and Wolff cranes, the Castle rock, the Liver Birds, Big Ben, the Eiffel Tower, windmills,
the Brandenburg Gate, the Riesenrad, the Colosseum, the Parthenon. Lose all your lives and the
Martians retake the last sector you freed. Clear Athens to win, and unlock an endless high-score
mode set in Belfast.

Three difficulties, each with its own high score tables. On VETERAN and MASSACRE the machines
are faster, better armoured and fire more often, you start with fewer lives and reload slower,
and the Heat-Ray sweeps out and back sooner. On every setting a damaged leg reseals if you leave
it alone, and the gap between the cry and the beam is never the same twice.

Every line of text in the game is Wells's own, from the 1898 novel.

**Controls**

* Mouse or touch: drag back and release to fire. Hold the left side of the screen (or the right
  mouse button) to duck.
* Keyboard: arrows or WASD aim and set power, Enter fires, Space ducks, P pauses, M mutes.
* Gamepad: left stick aims, A fires, B ducks.

Windows, Linux and Android. Made with Godot 4 by 3BL_Indie. No music or sound files: it is all
synthesised when the game starts.

## Devlog post: "Tripod Attack! is out"

**Tripod Attack! is out now for Windows, Linux and Android.**

A vector arcade game after The War of the Worlds. You are the artilleryman behind the sandbags;
the fighting-machines stride in from the right. Shoot their legs out and real physics brings them
down in a shower of sparks. When one cries *Ulla*, duck: the Heat-Ray is coming. Get the people
to the shelter, then push the Martians back across ten European cities, each with its own
skyline, from Belfast to Athens. Clear Europe and an endless mode opens in Belfast.

All graphics are stroked lines on a phosphor tube and all sound is synthesised in code, 80s
arcade style. Tell us your best endless wave in the comments.

## Short post

TRIPOD ATTACK! is out. Shoot the legs, duck the Heat-Ray, take Europe back. A Vectrex-style
arcade game after H. G. Wells with full-physics collapsing tripods. Windows · Linux · Android.
GAME_URL
