# Sea They Are Angry

A lighthouse keeper on a tiny North Sea rock, late 1980s. By day you gather driftwood, scrap and bioluminescent matter from the shoreline, mend the fences and refuel the lamp. At dusk the fog rolls in. At night things walk up out of the water toward the light. The lamp's beam slows them; your boathook does the rest. If the lamp goes dark, the run is over. There is no winning, only how many nights you last.

This folder holds the **grey-box vertical slice**: every object is a primitive mesh built in code, with no art or audio yet.

## How to run

1. Install [Godot 4.3](https://godotengine.org/download/archive/4.3-stable/) (standard build, not .NET).
2. Either open Godot, choose **Import**, pick `sea-they-are-angry/project.godot` and press **F5**,
3. or run the launcher: `./play.sh ~/Godot_v4.3-stable_linux.x86_64` on Linux, `play.bat C:\path\to\Godot_v4.3-stable_win64.exe` on Windows.

On a fresh clone, launching with `godot --path` alone fails with "Could not find type Lighthouse" and similar errors. Godot builds its list of script classes in the git-ignored `.godot/` folder the first time the editor opens the project. The same error appears after a `git pull` that adds new scripts, because the list is then out of date. The launchers re-import automatically whenever anything changed; by hand it is `godot --headless --editor --quit --path sea-they-are-angry`.

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
| Use: gather, repair, refuel, revive (hold) | E | Shift | A |
| Work the lamp / leave it | R (within 3.8 m of the lighthouse) | / | Y |
| Switch beam: wide slows, focused burns | Q | . | B |
| Sprint | Space | , | Right shoulder |
| Skip the rest of the day or dawn | Enter | | |
| Pause | Esc | | Start |

Keepers face the way they walk and turn to their aim to swing. Each carries a paraffin lantern that lights at dusk. A keeper who falls goes down; a teammate holds Use beside them for 3 seconds to revive them, and everyone gets up at dawn. The run ends when the lamp goes dark or every keeper is down. Only one keeper can work the lamp at a time.

## What is in the slice

- Island, fixed camera, day/dusk/night/dawn lighting with fog.
- Keeper movement, mouse aim, boathook attack.
- The lamp: fuel, wide and focused beams, auto-sweep when nobody operates it, Burning to Guttering to Dark.
- Six scavenge points that refill at dawn, a ring of eight fences, repair, refuel.
- One enemy, the Bloated Dead: walks at the lighthouse, batters fences, swells and bursts.
- A spawner driven by a per-night table and the hidden Sea Anger value.
- HUD, dawn autosave and resume, game-over screen with New Run.

Design choices the spec left open are recorded in [docs/DECISIONS.md](docs/DECISIONS.md).

## Next milestone

Specified in [docs/NEXT_MILESTONE.md](docs/NEXT_MILESTONE.md): the Wall-Crawling Squid, the Armoured Crab, the Giant Constrictor Eel, then the garden, traps, upgrades, dirty fuel, flare gun, downed and revive, 2 to 4 player local co-op, fog volumes and audio.

## For the next session

Start with [HANDOFF.md](HANDOFF.md). The phase plans are in [docs/prompts/](docs/prompts/), the first real models are in [art/](art/README.md), and the chosen visual style is in [docs/ART_DIRECTION.md](docs/ART_DIRECTION.md).
