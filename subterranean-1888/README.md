# Subterranean: 1888

**Version 0.1.0: a playable vertical slice of the *Subterranean: 1888* game design document.**

Victorian turn-based tactics in the Earth's mantle. Her Majesty's Royal Subterranean Expedition, four specialists, goes down the shaft after a survey party that never came back. Recover their journal and bring the survivors back to the lift, or wipe out the insectoid swarm and its hive. Time Units, a 90° vision cone, light as a resource, reaction fire, and a swarm that hunts by pheromone.

The GDD targets Unity; this prototype is built in **Godot 4.3**, like the rest of this repository. Everything visible (cavern, models, effects) is built in code from primitives, and the sound is synthesised at start-up, so there are no art or audio files apart from the fonts.

![First contact: the Naturalist's lamp catches a worker's glow; the Engineer's strike is out of reach](docs/screenshot.png)

## How to run

1. Install [Godot 4.3](https://godotengine.org/download/archive/4.3-stable/) (standard build, not .NET).
2. Either open Godot, choose **Import**, pick `subterranean-1888/project.godot` and press **F5**,
3. or run the launcher: `./play.sh ~/Godot_v4.3-stable_linux.x86_64` on Linux, `play.bat C:\path\to\Godot_v4.3-stable_win64.exe` on Windows.

On a fresh clone, launching with `godot --path` alone fails with "Could not find type Battle" and similar errors, because Godot builds its list of script classes the first time the editor opens the project. The launchers import first; by hand it is `godot --headless --editor --quit --path subterranean-1888`.

The game uses the Forward+ renderer (volumetric fog, SSAO, glow). On machines without Vulkan, add `--rendering-driver opengl3` to run it with the Compatibility renderer; the rules and the look are the same apart from the fog.

## How to play

| | |
|---|---|
| **Select** a specialist | Left-click them, the squad cards at the top, or **Tab** |
| **Move** | Left-click a tile. Blue tiles keep enough TU for Overwatch; amber ones spend it |
| **Face** | Right-click (1 TU each 45°) |
| **Shoot** | **1** snap, **2** aimed, **3** burst, then click a spotted creature. Hover for the hit chance and every modifier |
| **Reload / crouch / flare** | **R** / **C** / **F** |
| **Engineer** | **M** mortar flare (12 tiles, no line of sight needed), **B** drill soft rock or boulders, **H** patch up a neighbour |
| **Naturalist** | **G** pheromone lure: a false trail the swarm will follow |
| **Grenadier** | **T** dynamite |
| **Doors, valves, the journal** | **X**, then click it |
| **Field repair** | **V**: boiler pressure back to 100, clears a jam |
| **Lamp** | **L** shutters or lights the Davy lamp |
| **End turn** | **Enter** |
| **Camera** | WASD / arrows / middle-drag, **Q** / **E** to turn, wheel to zoom, **Space** to centre |
| **Overlays** | **O** the light map (pitch / dim / bright), **P** swarm sense (where the pheromone is) |
| **Menu** | **Esc** |

The in-game How to Play (title screen or pause menu) explains the rules in the players' words.

## How it's built

```
rules/      the simulation: plain GDScript, no nodes, no rendering, no input
  rules.gd        every number and formula (TU costs, light bands, hit chance, reactions)
  tac_grid.gd     terrain, doors, steam, light, occupancy; Dijkstra reach; line of sight
  battle.gd       the battle: commands in, events out
  swarm_ai.gd     the insectoids, through the same commands the player uses
  unit.gd / unit_def.gd / weapon_def.gd / level_loader.gd / catalog.gd
data/       unit classes and weapons as .tres resources (edit the numbers in the Inspector)
levels/     the cavern as an ASCII map (legend in rules/level_loader.gd)
view/       the 3D board, models, effects, HUD, camera, title and sound
tests/      headless tests (run_tests.sh)
tools/      autoplay balance runs, the squad bot, screenshots
```

**Commands in, events out.** The view never changes the game. A click becomes a command dictionary such as `{"t": "shoot", "u": 2, "target": 9, "mode": "aimed"}`. `Battle.exec()` validates it with `can()`, applies it, and returns a list of events (`move`, `aim`, `shot`, `hurt`, `reaction`, `death`...). The view plays those events back as animation. This structure gives you several things:

- The swarm AI calls the same `can()` / `_run()` path, so it can't cheat.
- The HUD's previews (path cost, the red TU ghost, hit chance and its breakdown) call the same functions the resolution does.
- The rules are testable without a window.
- Commands are plain dictionaries, ready to send over a network. That is Milestone 3's co-op, with the server running `Battle` and clients sending commands.

## Tests and balance

```
tests/run_tests.sh ~/Godot_v4.3-stable_linux.x86_64
```

- `test_rules.gd` has 95 checks: TU maths, light bands, paths, line of sight through doors and steam, cover, bursts, reactions, flanking, pheromone decay and lures, and twelve full idle turns on the real map.
- `test_smoke.gd` plays the real scene for about a dozen turns through the view, building every hover preview and opening every menu.

The runner fails if any check fails or Godot prints a script error.

Balance runs: the squad bot plays whole expeditions and prints the outcomes.

```
godot --headless --path subterranean-1888 --script res://tools/autoplay.gd -- 30 40
```

The bot is deliberately naive. It never crouches, uses cover, shuts the valve, closes doors, shutters lamps or lays lures. It wins about 30% of expeditions, which is meant as a floor for a player who uses the systems.

Screenshots: `xvfb-run godot --path subterranean-1888 --script res://tools/screenshot.gd -- /some/folder --no-splash`.

## What's in the slice, and what isn't

In: the four GDD specialists with their gear, TU and the load formula, all three fire modes, Overwatch, the light map and the 90° cone, steam and valves, doors, soft rock, cover, boiler pressure and jams, poison, flares, lures, dynamite, the drill, the seismograph, the swarm (pheromone, horde aggro, flanking crawlers, the hive), and one hand-built cavern.

Not yet: multiplayer (the command/event structure is ready for it), more levels, a campaign, inventory management, and enemy ranged attacks. See [docs/DESIGN_NOTES.md](docs/DESIGN_NOTES.md) for every rule the GDD left open and how this prototype settled it.
