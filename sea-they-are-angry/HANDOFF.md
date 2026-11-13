# Handoff: Sea They Are Angry

**v1.3.3 (the seven walk forwards; the flamer's nozzle and a proper shotgun; solid boats and furniture; hits that land, keepers' knacks, the rock's days and nights, the seven's requests, a kraken in three stages, stars and unlocks) is the current build** (`docs/RELEASE_NOTES_v1.3.3.md`; earlier notes are v1.3.2, v1.3.1, v1.3.0, v1.2.1, v1.2.0, v1.1.2, v1.1.1, v1.1.0, v1.0.0, v0.1.4 and v0.1.0). The cloud session can't push tags: make `sea-v1.3.3`, or a release, on GitHub's Releases page. Read this first, then `docs/STORY.md` (the story, which everything written for players must agree with), `docs/DESIGN.md` (the rock), `docs/KIRKHAVEN.md` (the town), `docs/DECISIONS.md` (why, newest last) and `git log`. Brought up to date 2026-11-10.

## Where things stand

Both chapters are built and tested by script; neither has been played through by a person since Chapter Two and the fog went in. What the plans (`docs/prompts/`) asked for, and where each stands:

| Plan | State |
|---|---|
| 1. Vertical slice (`01_vertical_slice.md`) | Done |
| 2. First release, phases A to G (`02_first_release_phases_A-G.md`) | Done, with differences listed in `docs/DESIGN.md` and `docs/ARCHITECTURE.md`. Built: the creatures (plus a fifth), garden, cottage, traps, upgrades, flares, co-op (with joining a game under way), pause and options, fog, sound, the F10 overlay, `Balance` (`autoload/balance.gd`), `tests/smoke.gd`, the asset list, the Windows export. Not built as planned: `Loot` (drops go through `Enemy.salvage()`), `Targeting`, `Assets` (the models load directly), and the plan's appendix numbers (the code's are newer). |
| 3. Phases H to L (`03_phases_H-L.md`) | Done: the design docs (`docs/DESIGN.md`, `ENEMIES.md`, `ARCHITECTURE.md`, `BALANCING.md`), game feel (shake, hit-stop, hit flash, damage numbers, the morning card), accessibility (shake levels, steady lights, a second keeper palette, interface size; rebinding is keeper one only), the strings table (the menus only), the local play log, F12, the playtest script, the export scripts, `LICENSE`, `CREDITS.md`, `docs/ITCH_PAGE.md`. |
| 4. Roadmap (`04_after_v0.2_roadmap.md`) | **Not started, on purpose.** It says to do these after playtests: the daily rock, unlockable keepers, run modifiers, special nights, dawn wrecks, lamp mastery. Build none of them until a person has played v0.1.4 and the six checks (`docs/BALANCING.md`) say what's wrong. |

**The story was turned round on 2026-11-10** at the owner's direction (`docs/STORY.md`):

- **Act One, Kirkhaven** (`scenes/harbour.tscn`, `scenes/harbour/`, `docs/KIRKHAVEN.md`): New Run starts here. Three nights; seven named villagers (`scenes/people/`) to keep alive; the town falls and they are brought down to the *Mary Ann* on the third night. Local play only.
- **Between the acts, the Escape** (`scenes/escape.tscn`, `scenes/escape/`, `docs/ESCAPE.md`; added 2026-11-11 at the owner's request): the log's first two crossing pages, then the Mary Ann runs up the coast to the rock in the fog, with the arms, rocks and climbers to fight off (a person, a helper or Dod Wiseman at the wheel), then the last two pages. Her hull broken, the run is lost and Continue begins the crossing again. Local play only.
- **Act Two, the rock** (`scenes/main.gd` with `scenes/systems/story_rock.gd` when `Run.story`): the survivors in the camp, the diary, no relief boat. Six, seven or eight nights by the sea (`Rescue.STORY_NIGHTS`, 2026-11-11), with a different event each day, special nights, and one request at a time from the seven (`scenes/systems/rock_days.gd`, `docs/DESIGN.md` "The story's rock"). Every rock run's dawn log ends with a rated line (`night_rating.gd`); finishing the story on an angry or raging sea unlocks the oilskin and Hard Light (`SaveSys.UNLOCKS`, Settings).
- **The kraken** (`scenes/enemies/kraken.gd` the rules, `kraken_body.gd` the creature, `kraken_part.gd` what weapons hit): the last night; its death is the end (`scenes/ui/story_end.gd`).
- **The keeper's log** (`scenes/ui/story_pages.gd`, `story_text.gd`, stills in `art/story/` made by `tools/make_story_stills.gd` with `shaders/sketch.gdshader`): before Act One, on the crossing, at the diary, after the end.
- **A quieter HUD**: H cycles Full / Slim / Off; panels shrink themselves; click a header to fold it when the mouse is free.
- `Run.story` false is the rock alone with the relief boat at the end: LAN games, and what most of the older tests exercise.

**The fog** (v1.0.0): a glowing bank (`scenes/world/fog_bank.gd`, `shaders/fog_bank.gdshader`) on both maps, a synthesiser score (`art/source/music/build_music.py`), and night events (`scenes/world/night_events.gd`).

**What is next:** the owner plays it (`docs/PLAYTEST_CHECKLIST.md`, and `docs/PLAYTEST.md` for watching someone else). The things only a person can judge: the new music and sounds (made and measured, never heard), whether the nights are now too dark, the town's and the kraken's balance (set against `tools/playtest_harbour.gd` and `tools/playtest_kraken.gd`, where the computer's keepers play alone), whether the evacuation and the kraken read on screen, whether the pencil pages pass for hand-drawn, the shake and the hit pause, the jump and the fence climb, when the roof lifts, the free camera, and the Windows build, which has never been run on Windows.

The work lives on branch `claude/windows-build-omarchy-d2b94k` of `jamesbell2021/Animation-`, in the `sea-they-are-angry/` folder. The repo also holds other projects (`neon-mega-tank/`, `animation-principles/`); leave them alone.

`tools/tour.gd` renders a computer-played run frame by frame, with the HUD, for reviewing how it looks; `tools/screenshot.gd` takes a still; `tools/playtest.gd` plays nights with a bot for balance (`tools/playtest_harbour.gd` does Kirkhaven, `tools/playtest_kraken.gd` the last night); `tools/make_asset_list.py` rewrites `docs/ASSET_LIST.md`.

To start the next session, open Claude Code in `sea-they-are-angry/` and say what you want; `docs/DESIGN.md` and this file are the map.

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
godot --headless --path sea-they-are-angry --script res://tests/slice_arms.gd
godot --headless --path sea-they-are-angry --script res://tests/slice_rescue.gd
godot --headless --path sea-they-are-angry --script res://tests/slice_jobs.gd
godot --headless --path sea-they-are-angry --script res://tests/slice_settings.gd
godot --headless --path sea-they-are-angry --script res://tests/slice_helpers.gd
godot --headless --path sea-they-are-angry --script res://tests/slice_islet.gd
godot --headless --path sea-they-are-angry --script res://tests/slice_turbine.gd
godot --headless --path sea-they-are-angry --script res://tests/slice_music.gd
godot --headless --path sea-they-are-angry --script res://tests/slice_hud.gd
godot --headless --path sea-they-are-angry --script res://tests/slice_salvage.gd
godot --headless --path sea-they-are-angry --script res://tests/slice_camera.gd
godot --headless --path sea-they-are-angry --script res://tests/slice_interior.gd
godot --headless --path sea-they-are-angry --script res://tests/slice_join.gd
godot --headless --path sea-they-are-angry --script res://tests/slice_access.gd
godot --headless --path sea-they-are-angry --script res://tests/slice_events.gd
godot --headless --path sea-they-are-angry --script res://tests/slice_harbour.gd
godot --headless --path sea-they-are-angry --script res://tests/slice_kraken.gd
godot --headless --path sea-they-are-angry --script res://tests/slice_story.gd
godot --headless --path sea-they-are-angry --script res://tests/slice_escape.gd
godot --headless --path sea-they-are-angry --script res://tests/smoke.gd    # a whole run at 20x, about half a minute
GODOT=godot sea-they-are-angry/tests/run_lan.sh   # the LAN test: a host and a client, two processes
```

On Windows use `Godot_v4.3-stable_win64_console.exe` in place of `godot`. All twenty-five tests, the smoke test and the LAN test ended in PASS on Godot 4.3 stable (2026-11-09). The holm, survival, research and camp-raid tests reach the camp's classes only through the scene, never by name: `--script` compiles whatever a test names before the autoloads exist, and that left a camp script unusable. The older seven turn the helper keepers off (`Players.helpers = false`) because they script every keeper themselves; `slice_holm.gd` covers the holm, the bridge, the split screen and the helpers. Run them one at a time: they share `user://run.json`. For balance, `tools/playtest.gd` plays several nights with a bot and prints a line per night (see README). `slice_behaviour.gd` covers every item of the slice's verify list, from W moving up-screen to New Run restarting at night 1.

One intermittent failure to know about: in one of seven full runs on 2026-11-01, `slice_holm.gd`'s keeper stalled at the holm end of the rope bridge (x 28.07) instead of walking on to the camp gate. It didn't happen in six re-runs, in eight walks under different winds, or in 24 more walks from different starting offsets and moments of the bridge's sway (2026-11-09). If it happens in play, a keeper may catch on the seam where the bridge's deck meets the holm's clifftop (the deck's collision is a concave surface rebuilt every physics step in `rope_bridge.gd`).

Two kinds of console noise are expected and harmless:

- `Parameter "m" is null` from `mesh_get_surface_count`: Godot 4.3's headless dummy renderer prints it once per primitive mesh with a material override. It does not appear with a real renderer.
- Compile errors before the first PASS line when running a test with `--script`: the test loads class scripts before the autoloads exist, then the real run compiles cleanly.

`slice_night.gd` overwrites `user://run.json`, so do not run it on a machine with a save you care about.

## Notes from reconciling the plans (kept for reference)

These were written to guide plan 2's Phase A and are mostly done; `docs/DESIGN.md` and `docs/ARCHITECTURE.md` are the current word. Where one still bites (the fences' gap, the lamp's cone, enemy order of `speed_mult`), it is worth reading.

## Things Phase A had to reconcile

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
