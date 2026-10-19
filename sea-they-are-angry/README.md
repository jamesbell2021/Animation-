# Sea They Are Angry

A lighthouse keeper on a tiny North Sea rock, late 1980s. By day you gather driftwood, scrap and bioluminescent matter from the shoreline, mend the fences and refuel the lamp. At dusk the fog rolls in. At night things walk up out of the water toward the light. The lamp's beam slows them; your boathook does the rest. If the lamp goes dark, the run is over. There is no winning, only how many nights you last.

This folder holds the **grey-box vertical slice**: every object is a primitive mesh built in code, with no art or audio yet.

## How to run

1. Install [Godot 4.3](https://godotengine.org/download/archive/4.3-stable/) (standard build, not .NET).
2. Either open Godot, choose **Import**, pick `sea-they-are-angry/project.godot` and press **F5**,
3. or run the launcher: `./play.sh ~/Godot_v4.3-stable_linux.x86_64` on Linux, `play.bat C:\path\to\Godot_v4.3-stable_win64.exe` on Windows.

On a fresh clone, launching with `godot --path` alone fails with "Could not find type Lighthouse" and similar errors. Godot builds its list of script classes in the git-ignored `.godot/` folder the first time the editor opens the project. The same error appears after a `git pull` that adds new scripts, because the list is then out of date. The launchers re-import automatically whenever anything changed; by hand it is `godot --headless --editor --quit --path sea-they-are-angry`.

Balance playtest: a bot plays several nights and prints what happened, with `--` then the number of nights, `bot` or `idle`, and 1 to 3 keepers. Your own save and best night are backed up and put back.

```
godot --headless --path sea-they-are-angry --script res://tools/playtest.gd -- 6 bot 1
```

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
| Work the lamp / leave it | R (within 3.8 m of the lighthouse) | / | Y |
| Switch beam: wide slows, focused burns | Q | . | B |
| Sprint | Space | , | Right shoulder |
| Skip the rest of the day or dawn | Enter | | |
| Pause | Esc | | Start |

Keepers face the way they walk and turn to their aim to swing. Each carries a paraffin lantern that lights at dusk. A keeper who falls goes down; a teammate holds Use beside them for 3 seconds to revive them, and everyone gets up at dawn. The run ends when the lamp goes dark or every keeper is down. Only one keeper can work the lamp at a time.

## What is in the slice

- The island, after Bad North: a meadow ringed by cliffs, three beaches where the sea comes ashore, and the lighthouse on a crag in the middle. The only way up is a ledge path that winds round the crag. Fixed camera, day/dusk/night/dawn lighting with fog.
- Keeper movement, mouse aim, boathook attack. A blow aimed outward on the ledge knocks a creature over the edge. Keepers have their own ladders down the crag.
- The lamp: fuel, wide and focused beams (the focused one reaches the beaches), auto-sweep when nobody operates it, Burning to Guttering to Dark.
- Six scavenge points on the beaches that refill at dawn, five fences at the chokepoints (beach heads and the ledge), repair, refuel.
- One enemy, the Bloated Dead: lands on a beach, walks the long way up to the light, batters fences, swells and bursts.
- Foghorn warnings name where they land, the water churns before they surface, and a keeper's log at dawn sums up the night.
- A spawner driven by a per-night table and the hidden Sea Anger value.
- HUD, dawn autosave and resume, game-over screen with New Run.
- 3BL_Indie studio splash at launch and a Credits screen on the title menu (`studio/`, shared with the other 3BL_Indie games; see [CREDITS.md](CREDITS.md)).

Design choices the spec left open are recorded in [docs/DECISIONS.md](docs/DECISIONS.md).

## Next milestone

Specified in [docs/NEXT_MILESTONE.md](docs/NEXT_MILESTONE.md): the Wall-Crawling Squid, the Armoured Crab, the Giant Constrictor Eel, then the garden, traps, upgrades, dirty fuel, flare gun, downed and revive, 2 to 4 player local co-op, fog volumes and audio.

## For the next session

Start with [HANDOFF.md](HANDOFF.md). The phase plans are in [docs/prompts/](docs/prompts/), the first real models are in [art/](art/README.md), and the chosen visual style is in [docs/ART_DIRECTION.md](docs/ART_DIRECTION.md).
