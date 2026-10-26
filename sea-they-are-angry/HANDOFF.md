# Handoff: Sea They Are Angry

Read this first, then `docs/DECISIONS.md` and `git log`. Written 2026-10-19 at the end of a cloud session.

## Where things stand

| Plan | File | State |
|---|---|---|
| 1. Vertical slice | `docs/prompts/01_vertical_slice.md` | Done, tested, pushed |
| 2. First release, phases A to G | `docs/prompts/02_first_release_phases_A-G.md` | **Next: start at Phase A** |
| 3. Phases H to L | `docs/prompts/03_phases_H-L.md` | After v0.1.0 |
| 4. Roadmap after v0.2.0 | `docs/prompts/04_after_v0.2_roadmap.md` | Ideas for after playtests |

The work lives on branch `claude/windows-build-omarchy-d2b94k` of `jamesbell2021/Animation-`, in the `sea-they-are-angry/` folder. The repo also holds other projects (`neon-mega-tank/`, `animation-principles/`); leave them alone.

To start the next session, open Claude Code in `sea-they-are-angry/` and say:

> Follow docs/prompts/02_first_release_phases_A-G.md from Phase A. Read HANDOFF.md, docs/DECISIONS.md and git log first.

## How to verify

On a fresh clone, run `./play.sh` (or `play.bat`) or open the project in the editor once first. Launching with `godot --path` before any import fails with "Could not find type Lighthouse", because the class list lives in the git-ignored `.godot/` folder. The same applies after any pull that adds a `class_name` script: the cached list goes stale. `play.sh` re-imports whenever a script, shader or model is newer than the cache; before headless tests, run `godot --headless --editor --quit --path sea-they-are-angry` yourself.

```
godot --headless --quit --path sea-they-are-angry
godot --headless --path sea-they-are-angry --script res://tests/slice_behaviour.gd
godot --headless --path sea-they-are-angry --script res://tests/slice_night.gd
godot --headless --path sea-they-are-angry --script res://tests/slice_retreat.gd
godot --headless --path sea-they-are-angry --script res://tests/slice_coop.gd
godot --headless --path sea-they-are-angry --script res://tests/slice_ledge.gd
godot --headless --path sea-they-are-angry --script res://tests/slice_creatures.gd
godot --headless --path sea-they-are-angry --script res://tests/slice_economy.gd
godot --headless --path sea-they-are-angry --script res://tests/slice_holm.gd
godot --headless --path sea-they-are-angry --script res://tests/slice_survival.gd
godot --headless --path sea-they-are-angry --script res://tests/slice_research.gd
godot --headless --path sea-they-are-angry --script res://tests/slice_camp_raid.gd
```

On Windows use `Godot_v4.3-stable_win64_console.exe` in place of `godot`. All eleven tests ended in PASS on Godot 4.3 stable. The holm, survival, research and camp-raid tests reach the camp's classes only through the scene, never by name: `--script` compiles whatever a test names before the autoloads exist, and that left a camp script unusable. The older seven turn the helper keepers off (`Players.helpers = false`) because they script every keeper themselves; `slice_holm.gd` covers the holm, the bridge, the split screen and the helpers. Run them one at a time: they share `user://run.json`. For balance, `tools/playtest.gd` plays several nights with a bot and prints a line per night (see README). `slice_behaviour.gd` covers every item of the slice's verify list, from W moving up-screen to New Run restarting at night 1.

Two kinds of console noise are expected and harmless:

- `Parameter "m" is null` from `mesh_get_surface_count`: Godot 4.3's headless dummy renderer prints it once per primitive mesh with a material override. It does not appear with a real renderer.
- Compile errors before the first PASS line when running a test with `--script`: the test loads class scripts before the autoloads exist, then the real run compiles cleanly.

`slice_night.gd` overwrites `user://run.json`, so do not run it on a machine with a save you care about.

## Things Phase A must reconcile

- **Parts of later phases already exist:** 3-player co-op and a simplified downed/revive (Phase D), the title and pause menus (Phase E), synthesised sound with `.ogg` overrides (Phase F), particle effects (Phase I) and the cottage, shed and garden buildings (Phase C). Extend these rather than rebuilding them; DECISIONS lists exactly what each covers and what is missing.
- **Phase B's creatures already exist** (owner's request): Squid, Crab and Eel, adapted to the crag island, plus a fifth, the Smotherer, from the roadmap's "something that climbs the lighthouse" idea (see DECISIONS). So do the hammer and oil-can repairs, homestead raids and damage, the `Shed` structure, and the lamp-room door. See DECISIONS, "The other creatures…", for every number and where it departs from plan 2. Phase B now means moving their numbers into `Balance`, adding drops through Phase A's `Loot` (they currently add straight to `Stock`), and reconciling the Eel's head position and the Squid's tell.
- **Phase C is already built** (owner's request): the garden beds, cottage menu, upgrades, traps, oil and dirty fuel, the flare gun and the campfire. See DECISIONS, "Phase C…", for where it departs from plan 2. The main departures are trap slots placed on the creature paths rather than a ring, the flare lobbed to the cursor, a generic `ChoiceMenu` standing in for Phase E's cottage UI, and scrap at 2 a day. Phase C now means moving its numbers (`Upgrades`, `TrapSlot.TRAPS`, `Cottage`, `Flare`, `Campfire`) into `Balance`.
- **Characters are rigged GLBs** built by `art/source/characters/build_characters.py` in Blender 4.2 and driven by `scenes/util/character_rig.gd`: clips baked in by `art/source/characters/animate.py` (IK-solved, played through an AnimationTree), code layers on top, ragdolls on demand. Phase F's art pipeline should extend those scripts rather than import models by hand. See DECISIONS, "Characters remade in Blender" and "Animation clips".
- **Storm weather** runs off one global shader value, `storm`, set by `scenes/world/weather.gd`. Plan 2's fog volumes (Phase E) should sit alongside it rather than replace it.
- **The island was rebuilt Bad North style** (owner's request, see DECISIONS "The crag, the ledge and the beaches"). Creatures land only on three beaches and walk a waypoint graph (`scenes/util/nav.gd`) up the ledge that winds round the crag. New enemies should follow `Enemy.route` too. Phase B's Wall-Crawling Squid is the obvious exception: let it climb straight up the crag walls. That shortcut is its threat. Traps (Phase C) belong at the chokepoints: the beach heads, the track and the ledge.
- **The lamp tests a real 3D cone** against `Enemy.light_probe_points()` and is tilted 38°, so it cannot reach near its own base. Plan item B4 asks for `light_probe_position()`; use the existing `light_probe_points()` instead and have the Eel return its head. See DECISIONS.
- **The focused beam now burns the Bloated** at 10 hp per second instead of slowing it, by the owner's decision after playtesting. The appendix still lists only "light slow ×0.6" for the Bloated, so add the burn to `Balance` alongside it. See DECISIONS.
- **The appendix changes slice numbers.** Plan 2 says "solo still plays exactly as before", but its appendix sets Day 120 s, Dusk 30 s, Night min(150 + 10(n−1), 240) and Dawn 60 s. The slice uses 60, 15, min(120 + 10(n−1), 210) and 30. The appendix is the newer design, so move to it when building `Balance` and record that in DECISIONS.
- **`autoload/cycle.gd` and the other autoloads were written verbatim from plan 1.** Moving their numbers into `Balance` is expected; keep their signals and method names.
- **Camera.** FOV 45 from (0, 41, 27), looking at (0, 3, 1), still frames the whole main island and every landing (tested). Phase D3's "every player on screen" is replaced by the owner's split screen: `CameraDirector` frames each island the same way, follows the keepers between them, and splits the screen when the people playing are on different islands. See DECISIONS "The holm, the rope bridge, the split screen and the helpers".
- **Fences** are five sections across the chokepoints (beach heads and the ledge), each leaving a 0.9 m gap that a keeper fits through and a Bloated does not. Phase B's Squid climbs fences, and Phase B's Eel surge breaks any fence on its line. Neither needs the gaps changed.
- **Balance numbers changed with the new island:** lamp burn 0.35 / 1.0 per second, refuel 40 per bio, fence mend 50 per driftwood, Bloated 1.15 m/s, and earlier night tables in `spawner.gd`. Move them into `Balance` with the rest.
- **Structures have `surface_distance(point)`.** Use it for anything measured to a structure: interact range, burst splash, the Crab's slam arc, trap placement checks.
- **Light slow.** Enemies reset `speed_mult` after moving, not before, because the lamp processes first in the tree. Keep that order when adding the Squid's `lit_this_frame`: set it in `in_light`, read it in the tick, clear it after `move_and_slide`.
- **Spawner stagger** is counted down in `_process` rather than with `await`, so a scene reload cannot resume a coroutine on a freed node. Phase D's count scaling and Phase B's spawn-rate multiplier both slot into `_queue_group`.

## The visual pass (done early, at the owner's request)

The game already has its Valheim-style look: a raised rocky island, grass, sea, fog, a modelled lighthouse on its knoll, the cottage, shed and garden, and Callum's model as the keeper. Phase C should build on the existing `Cottage` and `Garden` classes (`scenes/structures/`) rather than create new ones; their positions differ from plan 2, see DECISIONS. See `docs/ART_DIRECTION.md` for screenshots and the checklist of what each Valheim trait maps to, and DECISIONS for the details. Keep the look intact while doing phases A to G. `tools/screenshot.gd` renders real frames so changes can be checked by eye; in a headless container it needs `mesa-vulkan-drivers` and `xvfb-run`.

## Art that is waiting for Phase F

`art/README.md` has the details. In short:

- Four keeper models, a lineup, a boathook and a whole-island blockout are in `art/`. Callum and the boathook are already loaded by `Player.load_art()`; the other keepers wait for co-op in Phase A/D.
- **They are Z-up.** Rotate the root −90° about X on import or they lie on their backs.
- Keepers are about 2.05 m tall with feet at the origin, use vertex colours only and have no rig or animations.
- A natural mapping for Phase F's `Balance.ASSET_PATHS`: player slot 0 to `art/characters/callum_keeper.glb`, 1 to Hamish, 2 to Mairi, 3 to Ewan, and the boathook prop on every keeper. Plan 2 has a single `player` key, so add per-slot keys and record the choice.
- The island model is 31 × 22 m with its own lighthouse, buildings and garden. The gameplay rock is a 14 m radius. Treat the model as a backdrop to fit around the gameplay layout, not a drop-in replacement, until the two are reconciled.

The chosen visual style is the painted low-poly look on the reference sheet. `docs/ART_DIRECTION.md` describes it, includes the Blender two-tone material script, and sketches a Godot shader equivalent. Use it when Phase E and Phase F touch materials.
