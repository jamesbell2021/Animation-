# Sea They Are Angry

A lighthouse keeper on a tiny North Sea rock, late 1980s. By day you gather driftwood, scrap, kelp and bioluminescent matter from the shoreline, mend the fences, plant the garden, set traps and refuel the lamp. At dusk the fog and the storm roll in. At night things walk up out of the water toward the light. The lamp's beam slows them; your boathook does the rest. If the lamp goes dark, the run is over. There is no winning, only how many nights you last.

The island, buildings and effects are built in code. The characters are rigged models built by a Blender script. Sound is synthesised at start-up.

## How to run

1. Install [Godot 4.3](https://godotengine.org/download/archive/4.3-stable/) (standard build, not .NET).
2. Either open Godot, choose **Import**, pick `sea-they-are-angry/project.godot` and press **F5**,
3. or run the launcher: `./play.sh ~/Godot_v4.3-stable_linux.x86_64` on Linux, `play.bat C:\path\to\Godot_v4.3-stable_win64.exe` on Windows.

On a fresh clone, launching with `godot --path` alone fails with "Could not find type Lighthouse" and similar errors. Godot builds its list of script classes in the git-ignored `.godot/` folder the first time the editor opens the project. The same error appears after a `git pull` that adds new scripts, because the list is then out of date. The launchers re-import automatically whenever anything changed; by hand it is `godot --headless --editor --quit --path sea-they-are-angry`.

Balance playtest: a bot plays several nights and prints what happened, with `--` then the number of nights, `bot`, `eco` (the bot also plants, eats, buys upgrades and sets traps) or `idle`, and 1 to 3 keepers. Your own save and best night are backed up and put back.

```
godot --headless --path sea-they-are-angry --script res://tools/playtest.gd -- 6 bot 1
```

Gameplay reel: `tools/reel/make_reel.sh` records 16 captioned shots of the main gameplay with Godot's Movie Maker and joins them into one MP4 (needs ffmpeg, and `xvfb-run` with no display; set `GODOT=` to the binary). It takes about an hour, since every frame is fully rendered.

Headless load check (no window):

```
godot --headless --quit --path sea-they-are-angry
```

On Windows use the console binary, for example `Godot_v4.3-stable_win64_console.exe --headless --quit --path sea-they-are-angry`.

## Controls

Choose 1 to 3 keepers on the title screen, then New Run (or Continue).

| Action | P1: keyboard + mouse | P2: arrow keys (if no free gamepad) | Gamepad (P2, P3) |
|---|---|---|---|
| Move | W A S D | Arrow keys | Left stick |
| Aim | Mouse | Facing direction | Right stick |
| Boathook swing | Left mouse | Ctrl | X or right trigger |
| Use: gather, repair, refuel, climb a ladder, revive (hold) | E | Shift | A |
| Work the lamp (walk in at the door) / leave it | R (within 3.8 m of the lighthouse) | / | Y |
| Switch beam: wide slows, focused burns | Q | . | B |
| Fire a flare (lobbed to the cursor) | Right mouse | ; | Left trigger |
| Pour dirty fuel (at the lighthouse) | F | ' | Left shoulder |
| Sprint | Space | , | Right shoulder |
| Skip the rest of the day or dawn | Enter | | |
| Pause | Esc | | Start |

Keepers face the way they walk and turn to their aim to swing. Each carries a paraffin lantern that lights at dusk. A keeper who falls goes down; a teammate holds Use beside them for 3 seconds to revive them, and everyone gets up at dawn. The run ends when the lamp goes dark or every keeper is down. Only one keeper can work the lamp at a time.

## What is in the slice

- The island, after Bad North: a meadow ringed by cliffs, three beaches where the sea comes ashore, and the lighthouse on a crag in the middle. The only way up is a ledge path that winds round the crag. Fixed camera, day/dusk/night/dawn lighting with fog.
- Characters modelled, rigged, textured and animated in Blender by scripts (`art/source/characters/build_characters.py`, `animate.py`): IK-solved walks, runs and sprints with planted feet, tool work, ladder climbs and creature gaits. Hard hits knock keepers and creatures down as ragdolls, and they get back up with real get-up animations from where they fall.
- Keeper movement, mouse aim, boathook attack. A blow aimed outward on the ledge knocks a creature over the edge. Keepers have their own ladders down the crag.
- The lamp: fuel, wide and focused beams (the focused one reaches the beaches), auto-sweep when nobody operates it, Burning to Guttering to Dark.
- Seven scavenge points on the beaches that refill at dawn (an eighth with three keepers), five fences at the chokepoints (beach heads and the ledge), repair, refuel.
- The keepers' economy:
  - **Garden:** dig kelp into the potato beds by day; they are ready at dawn.
  - **Cottage:** go in to eat (full heal and more max health), load flares, mix oil into dirty fuel, and buy upgrades for the lighthouse, the defences and the garden.
  - **Traps:** spike boards, kelp nets and chain plates on cairns up the beaches and the ledge.
  - **Oil:** a drum washes up every third night.
  - **Flare gun:** two shots that burn red where they land.
  - **Campfire:** warms a keeper back up by the cottage.
- Random weather each night: a clear moonlit night, rain squalls, or a storm that builds through dusk to a gale. The angrier the sea, the likelier a storm. In a storm: driving rain, thrashing grass, breakers crashing on the beaches, lightning and thunder, and pale shapes standing in the surf that only the flashes show. Every creature's eyes glow in the dark.
- Five creatures:
  - **The Bloated Dead** land on a beach and walk the long way up to the light, batter fences, swell and burst. Some groups raid the homestead instead.
  - **The Wall-Crawling Squid** climbs straight up cliffs and the crag at the keepers, lunges, and hides the others in ink.
  - **The Armoured Crab** comes to wreck the cottage, shed or garden; its shell turns blows from the front.
  - **The Giant Constrictor Eel** surges up and coils round the lighthouse until the focused beam burns its head.
  - **The Smotherer** climbs the lighthouse and wraps itself over the lantern, smothering the beam. The light can't burn it: throw your boathook up at it from the crag top to knock it off, then go and pick the hook up.
- Work the lamp from inside the lighthouse: the keeper walks in at the door and out again. Repairs are done with a hammer; refuelling with an oil can. The cottage, shed and garden take damage and need mending too.
- Foghorn warnings name where they land, the water churns before they surface, and a keeper's log at dawn sums up the night.
- A spawner driven by a per-night table and the hidden Sea Anger value.
- HUD, dawn autosave and resume, game-over screen with New Run.
- 3BL_Indie studio splash at launch and a Credits screen on the title menu (`studio/`, shared with the other 3BL_Indie games; see [CREDITS.md](CREDITS.md)).

Design choices the spec left open are recorded in [docs/DECISIONS.md](docs/DECISIONS.md).

## Next milestone

Plan 2 ([docs/prompts/02_first_release_phases_A-G.md](docs/prompts/02_first_release_phases_A-G.md)). Its Phase B creatures and Phase C economy are already in; Phase A (the `Balance` and `Loot` plumbing) is next, see [HANDOFF.md](HANDOFF.md).

## For the next session

Start with [HANDOFF.md](HANDOFF.md). The phase plans are in [docs/prompts/](docs/prompts/), the first real models are in [art/](art/README.md), and the chosen visual style is in [docs/ART_DIRECTION.md](docs/ART_DIRECTION.md).
