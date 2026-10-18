# Sea They Are Angry

A lighthouse keeper on a tiny North Sea rock, late 1980s. By day you gather driftwood, scrap and bioluminescent matter from the shoreline, mend the fences and refuel the lamp. At dusk the fog rolls in. At night things walk up out of the water toward the light. The lamp's beam slows them; your boathook does the rest. If the lamp goes dark, the run is over. There is no winning, only how many nights you last.

This folder holds the **grey-box vertical slice**: every object is a primitive mesh built in code, with no art or audio yet.

## How to run

1. Install [Godot 4.3](https://godotengine.org/download/archive/4.3-stable/) (standard build, not .NET).
2. Open Godot, choose **Import**, and pick `sea-they-are-angry/project.godot`.
3. Press **F5**.

Headless load check (no window):

```
godot --headless --quit --path sea-they-are-angry
```

On Windows use the console binary, for example `Godot_v4.3-stable_win64_console.exe --headless --quit --path sea-they-are-angry`.

## Controls

| Key | Action |
|---|---|
| W A S D | Move (W is up the screen) |
| Mouse | Aim; the keeper faces the cursor |
| Left mouse | Boathook swing (20 damage, 2.5 m, 60° either side of aim) |
| E | Interact: gather, repair, refuel |
| R | Operate the lamp (stand within 3.8 m of the lighthouse); R again to leave |
| Q | While operating, switch the beam between wide and focused |
| Space | Sprint (3 s, then 2 s cooldown) |
| Enter | Skip the rest of the day or dawn |

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
