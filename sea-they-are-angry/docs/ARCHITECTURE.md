# Architecture

Written from the code (v0.1.3, with v0.1.4's additions noted, Godot 4.3, GDScript, Forward Plus). Everything in the world, the HUD and the menus is built in code; the only scene file is `scenes/main.tscn`, which holds a node with `scenes/main.gd`. Where this file and `docs/DECISIONS.md` disagree, the code is right. Plan files in `docs/prompts/` describe things that were never built (see "Where the plans and the code differ" at the end).

## Autoloads

Order is as in `project.godot` `[autoload]`. `Settings._ready` reads the default key bindings `InputSetup` has already made, and `Players._ready` adds the `pause` action, so keep that order.

| Autoload | File | Job |
|---|---|---|
| StudioSplash | `studio/splash.gd` | CanvasLayer (layer 128). The 3BL_Indie splash: fade in 0.7 s, hold 2.0 s, fade out 0.7 s, any key or button skips. Frees itself at once when headless or run with `--no-splash`. Credits screen is `studio/credits.gd`. |
| Events | `autoload/events.gd` | Signal bus only: `structure_damaged(s)`, `structure_destroyed(s)`, `enemy_killed(e)`, `lamp_state_changed(state)`, `message(text)`, `lore(text)`, `run_ended(reason, night)`, `did(what, keeper)`. `did` ticks the first-days jobs (ids `gather repair eat generator sow lamp eggs`). |
| Run | `autoload/run.gd` | The run's data, all of it saved: `night`, `endless`, `difficulty`/`next_difficulty`, `lamp_fuel`, `camp_fuel`, `camp_crops[4]`, `crops[5]`, `hunger[3]`, `warmth[3]`, `research`, `researching`, `notes_found`, `upgrades`, `max_hp_bonus[3]`, `flares[3]`, `arms[3]`, `flamer_rigged`, `flamer_fuel`, `barrels`, `weather_seed/for/kind`, `jobs`, `quick_start`. Functions: `start_new()`, `start_loaded(dict)`, `advance_night(structures_damaged)` (anger decay, `night += 1`, autosave), `end_run(reason)` (saves best night, deletes the run save, emits `Events.run_ended`). |
| Cycle | `autoload/cycle.gd` | Phase clock. `Phase {DAY, DUSK, NIGHT, DAWN}`; signals `phase_changed(phase)`, `night_progress(t)` (0..1, night only). `start(p)`, `stop()`, `skip()` (DAY to DUSK, DAWN to DAY only), `duration_for(p)`, `progress()`, `phase_name()`. |
| Stock | `autoload/stock.gd` | The shared store. `KINDS` = driftwood, scrap, seaweed, bio, food, oil, dirty_fuel, diesel, seeds, notes, arrows, shells, bombs, poison, eggs. Signal `changed`. `get_amount`, `set_amount`, `add`, `can_afford(cost)`, `spend(cost)`, `all`, `set_all`, `reset`; static `word(k)` ("seaweed" reads "kelp") and `cost_str`. |
| Anger | `autoload/anger.gd` | The hidden "sea anger", 0 to `MAX` 10. Signal `changed`. `add(n)` is clamped to -1..+2 net per night; `on_dawn(structures_damaged)` takes 1 off (fewer than 3 structures damaged) or 2 off (3 or more) and resets the per-night counter. |
| SaveSys | `autoload/save_sys.gd` | `user://run.json` (the run, written at each dawn by `Run.advance_night`; a LAN client never writes) and `user://profile.json` (`best_night`, `chapters`). `save_run`, `snapshot()` (also what the LAN host sends), `load_run`, `clear_run`, `load_profile`, `save_best`, `load_best`, `finish_chapter(n)`, `chapter_done(n)`. |
| InputSetup | `autoload/input_setup.gd` | Keeper one's default actions (keyboard, mouse, optional pad) and the free-camera helpers: `set_pad(on)`, `pad_active`, `pad_stick()`, `wheel_zooming()`, static `on_ground(v)` (screen direction to ground direction, rotated by `CameraDirector.yaw`). |
| Audio | `autoload/audio.gd` | All sound. 58 effects and loops are synthesised in code at 16 kHz mono (functions `_s_*`, table `SOUNDS`) and cached as PCM in `user://audio_cache_v5/`; a file `res://audio/<key>.ogg` would override one (none exists). Pools of 14 3D and 6 2D players on bus `SFX`. `sfx(key, at, db, jitter)`, `ambient_sfx` (not sent over LAN), `loop(key, on, db, fade)`, `loop_volume`, `horn(pattern, db)`, `start_ambience()`, `music(key, fade)`, `music_now()`. Music is `audio/music_{title,day,night,finale,chapter_end,game_over}.ogg`, crossfaded on two players on bus `Music`. It reacts to `Cycle.phase_changed` (dusk: horn and day music fades; night: sting, `night` or `finale` on the last night; dawn/day: `day`), lamp state and `run_ended`. |
| Players | `autoload/players.gd` | Local keepers. `MAX = 3`, `wanted`, `helpers` (fill empty places with computer keepers), `devices`, `nodes`. `configure(n)` picks P2/P3 devices (a free pad, else the arrow keys), `bind_device(idx, device)`, static `action(idx, name)` ("p1_attack"), `count()`, `humans()` (people, at least 1: what creature counts scale with), `alive_count()`, `all_down()`, `device_label(idx)`. Names `Callum, Hamish, Mairi, Ewan`; only the first three can be in a run. |
| Net | `autoload/net.gd` | LAN host/client (see "LAN"). |
| Settings | `autoload/settings.gd` | `user://settings.cfg`: volumes (Master, Music, SFX), fullscreen, window size, graphics quality (Low/Medium/High), render scale, camera shake, keeper one's rebinds. Signal `changed`. `use_world(env, sun)` receives main's Environment, `key_name(action)` and `keys_in(text, idx)` rewrite "[E]" hints to the keys in use or the pad's buttons, `rebind`, `reset_controls`, `apply_*`. |
| Telemetry | `autoload/telemetry.gd` | The optional local play log (`user://telemetry.jsonl`: run start, each night at dawn, upgrades, dirty fuel, run end; off unless `Settings.telemetry` or `--telemetry`) and the F12 snapshot to `user://feedback.txt`. Format in `docs/TELEMETRY.md`. |
| Feel | `autoload/feel.gd` | Camera trauma shake (decay 1.7/s, offset is trauma squared, max 0.55 m lens shift), a kick toward a blow (`kick(dir, amount)`, up to 0.22 m, springs back at 16/s; follows the shake setting) and hit-stop (`Engine.time_scale` 0.04 for 0.055 to 0.11 real seconds, timed in real time; never stacks, 0.12 s between stops, skipped whenever the clock is not at 1.0). `shake(amount, at)` fades with distance to the nearest person's keeper (6 m full, 26 m none); `hitstop(s)`; `blow(killed, heavy, dir, amount)` (a person's blows only; under 15 damage no stop). All off headless unless `force_live` (tests stay frame-exact) and hit-stop is off on a LAN. |

## Scene and class map

Most classes have a `class_name`; `main.gd` and the UI screens other than `ChoiceMenu`, `ThreatMarkers` and `WeaponBar` do not and are preloaded by path. Main wires everything together in `_ready`.

**`scenes/main.gd`**: builds the whole world in code, then waits at the title (`_show_title`) or, headless or `Run.quick_start`, calls `begin_run`. Owns `lighthouse`, `camp`, `bridge`, `players`, `director`, `spawner`, `hud`, `atmosphere`, `rowing_boat`, `gulls`, `jobs`, `boat`. Also the dawn report, oil and cartridge washing up, the rescue sequence.

**`scenes/world/`**: `Terrain` (static heights, islands, beaches, ledge, bridge, camp, islet geometry and queries such as `island_of`), `Camp` (the holm's wartime camp: wire, towers, huts, plots, string lights), `Weather` (storm level, rain, lightning, `tonight()`), `Atmosphere` (fog, mist, vignette, buoy bell), `CameraDirector`, `RowingBoat`, `ReliefBoat`, `GullFlocks`, `Gull`, `GullNest`.

**`scenes/structures/`**: `Structure` (base: hp, `take_damage`, `repair`, group `structures`), `Lighthouse`, `Cottage`, `Shed`, `Garden` + `GardenPlot`, `Fence`, `Campfire`, `TrapSlot`, `SandbagWall`, `RopeBridge`, `Ladder` + `LadderEnd`, `Interior` (walk-in cutaway rooms), `Generator`, `CampBuilding` (quarters, mess, greenhouse bodies), `CampWire`, `CampPlot`, `HutStove`, `MessTable`, `ResearchDesk`, `WindTurbine`.

**`scenes/systems/`**: `Lamp` (beam, fuel, states), `Searchlight`, `Spawner`, `Difficulty`, `Rescue`, `Research`, `Upgrades`, `Jobs`, `Lore`, `Salvage` (drops), `ScavengePoint`, `Flare`, `Harpoon`, `Arrow`, `PetrolBomb`, `FirePool`. `Difficulty`, `Rescue`, `Research`, `Upgrades` and `Lore` are static tables with no node.

**`scenes/enemies/`**: `Enemy` (base state machine), `Bloated`, `Squid`, `Crab`, `Eel`, `Smotherer`, `InkCloud`. See `docs/ENEMIES.md`.

**`scenes/player/`**: `Player` (one keeper: move, swing, needs, ladders, doors, boat, `net_snap/net_apply`), `Arsenal` (the five weapons), `KeeperAI` (helper keepers, roles "light" and "camp").

**`scenes/ui/`**: `hud.gd` (+ `ThreatMarkers`, `WeaponBar`), `title.gd`, `pause.gd`, `settings_menu.gd`, `how_to_play.gd`, `ChoiceMenu` (cottage, shed and trap menus), `lan_lobby.gd`, `chapter_end.gd`, `debug_overlay.gd` (debug builds only).

**`scenes/util/` and `scenes/fx/`**: `Geo` (box/cylinder/shape helpers), `Look` (materials, textured surfaces), `Props`, `Fonts`, `CharacterRig` (loads a GLB, plays baked clips through an AnimationTree, layers code poses, ragdoll and get-up), `Nav` (creatures' waypoint graph, main island and holm kept separate), `KeeperNav` (the same plus ladders and the bridge), `Pendulum`, `FX` (code-built particles), `PixelFire` (the fire: soft, glowing flame sprites, the flamer's jet and its billows, drawn by `shaders/fire.gdshader`; named for the pixel fire it replaced).

Shaders: `shaders/` has `sea`, `terrain`, `grass`, `beam`, `mist_sheet`, `keeper_outline`, `fire`, `split_screen`. The global shader parameter `storm` (project.godot) is driven by `Weather`.

Groups the code relies on: `player`, `enemies`, `structures`, `interactable`, `trap_slots`, `salvage`, `searchlights`, `smotherers`, `eel`, `camp_root`, `camp_wire`, `barricades`, `heat`, `harpoons`, `gull_nests`, `relief_boat`, `rowing_boat`.

## How a run starts

1. `Main._ready` calls `KeeperNav.reset()`, builds environment, ground, sea, lighthouse, homestead, holm (and `Camp`), islet and rowing boat, fences, ladders, scavenge points, trap slots, campfire, camera, enemy root, `Spawner`, `Atmosphere`, `Hud`, `Pause`, and in debug builds `DebugOverlay`. It connects `Cycle.phase_changed`, `Events.run_ended`, `enemy_killed`, `structure_destroyed`, `lore`, then `Audio.start_ambience()`.
2. Headless, or `Run.quick_start` (New Run from game over, or "stay on the rock"): `begin_run(true, Players.wanted)`. Otherwise `_show_title()` (orbiting camera, lamp showcase, `Title`), whose `start_requested(continue, n)` calls `begin_run`. A LAN game starts through `Net.start_game` and `begin_lan(cfg)`.
3. `begin_run(continue_save, n)`: frees the title; `Players.configure(n)` (offline) or one keeper per machine (LAN); creates `Players.MAX` `Player` nodes when `Players.helpers` is on (`ai = i >= wanted`; the last helper's role is "camp" and it starts on the holm, others are "light"), adding a `KeeperAI` child to each helper; creates the `CameraDirector`; loads `run.json` into `Run.start_loaded` or calls `Run.start_new`; sets each keeper's hp, hunger, warmth from the run; `Upgrades.apply`; adds the third keeper's extra scavenge point; places two note tins; on a new run shows the first-day report; applies day lighting; `Cycle.start(DAY)`; adds `Jobs`; on LAN calls `Net.game_started`.
4. `Main._on_phase_changed` does the rest each phase: lighting tween (2 s), the last-night warning at dusk, and at dawn (host/offline only) oil and cartridges wash up, `Research.finish()`, a new note tin, the dawn report, store `Run.lamp_fuel` and needs, `Run.advance_night(damaged)`, and `_begin_rescue()` if the boat is due.

## Day, dusk, night, dawn

`Cycle.duration_for`: DAY 60 s, DUSK 15 s, NIGHT `min(120 + 10(n-1), 210)` s, DAWN 30 s (night 1 is 225 s all told; the 10th night is 210 s of night). Enter and Back (pad) skip the rest of DAY or DAWN (`Main._process`, not on a LAN client).
- Dusk: `Lamp` lights (fuel above zero), foghorn, weather applies, `Atmosphere` fog, salvage on the ground vanishes, `Generator` starts, keepers' lanterns light, music fades.
- Night: `Spawner` loads `night_table(Run.night)`, and releases rows as `Cycle.night_progress(t)` passes each row's `t`.
- Dawn: every `Enemy.on_dawn()` sets state `Retreat` (walk to the nearest beach at twice speed and sink); downed keepers get up at 50% hp; lamp goes `OFF`; scavenge points and gull nests refill; crops ripen; the night is scored and saved.

## LAN (autoloads/net.gd)

Host-authoritative, up to 3 machines, one keeper each. ENet on UDP 24686; discovery by UDP broadcast on 24687 each second (`MAGIC = "SEA_THEY_ARE_ANGRY_LAN_1"`); lobby by `_hello`/`_lobby` RPCs. Nobody can join after `start_game`. The host runs creatures, spawner, store, buildings, night and the helpers; offline play is the same code with `Net.mode == OFFLINE`.
- **Input (client to host)**: every physics frame `_send_input` sends `_in` (unreliable ordered): move vector turned to the ground, aim, the mouse's ground point, held actions, and counted presses for `Net.ACTIONS` (so a dropped packet loses no press). The host turns counts into "just pressed" in `input_frame(slot)`; `Player` reads `Net.just/held` for a `remote` keeper.
- **Snapshots (host to clients)**: `_snap` at 30 Hz, unreliable ordered: phase and time left, every keeper's `net_snap()`, every creature's `net_snap()` (id, script path, position, yaw, velocity, state, hp, flags, last animation shot), the lamp, searchlights, the rowing boat.
- **State**: `_state` at 4 Hz, reliable: `SaveSys.snapshot()` (the whole run, applied with `Run.start_loaded`), structure hp, trap slots, scavenge points, generator, stove, gull eggs, salvage on the ground, current research.
- **Events**: `_fx_batch` (unreliable: sounds, particles via `fx_gate`/`sfx_gate`) and `_event` (reliable: messages, warnings, the dawn report, `ended`, creature `corpse`, `shot` for flares, harpoons, ink, `rescue` for the boat). Menus run on the host and are mirrored (`_menu`, `_menu_pick`).
- **Clients**: every `Player` there is a puppet (`puppet = true`) lerped toward the host at `FOLLOW = 16` per second, including the client's own keeper (no prediction); creatures are puppets made from the script path in the snapshot; `Cycle.running = false`, the clock follows the snapshot; nothing on a client can hurt anything and `Spawner`/`Salvage.drop` return early.
- **Drops**: a client that leaves hands its keeper to the computer (`Main.keeper_left`); if the host leaves, everyone goes back to the title with the reason in `Net.last_error`. Time-scale hit-stop is skipped when online.

## Camera director and split screen (`scenes/world/camera_director.gd`)

One 45-degree camera framing a whole island from the south (offset 38 up, 26 back). Each island has its focus (`MAIN_FOCUS`, `HOLM_FOCUS`, `ISLET_FOCUS` with zoom 0.62); the bridge blends from one to the other and a keeper in the rowing boat slides to Gull Rock. People (not helpers) are grouped by which island they are on. When two groups are 9 m or more apart the screen splits along a line square to the line between them (rejoin under 4 m, 0.7 s to open or close); up to three views. View 1 is the main camera (mouse aiming goes through it); views 2 and 3 are `SubViewport`s sharing the world, laid over by `shaders/split_screen.gdshader` on a CanvasLayer at layer -1. Helpers get no view. Alone, or one person per machine on a LAN, the camera is free (`CameraDirector.free_on`): middle-mouse drag or Z/C turn it, wheel or `-`/`=` zoom (0.36 to 1.3), X resets, and movement keys follow `CameraDirector.yaw`. `Feel` shakes the cameras the director registers with `use_cameras`.

## The story: Kirkhaven, the survivors, the kraken

`Run.story` marks a run as the story (docs/STORY.md): Act One in the town, Act Two on the rock, the kraken at the end. Without it the rock is played alone and ends with the relief boat (LAN, most older tests). `Run.chapter` is still 2 in the town and 1 on the rock (the ids date from when the town came second).

**Act One** is the rock's code on a different map. `scenes/harbour.tscn` runs `harbour/harbour.gd`, which **extends `scenes/main.gd`** and builds its own world in `_ready`. `Terrain.chapter` (2 there, back to 1 in `main.gd`) makes `Terrain`, `Nav` and `KeeperNav` hand over to `HarbourMap`: height, walkable ground, paint, landings, and paths on an `AStarGrid2D`. See `docs/KIRKHAVEN.md` for the rules and the hooks in shared systems. When the *Mary Ann* sails, `Run.carry` takes the living, the store and the keepers' weapons across, and `main.gd` begins Act Two from it.

| File | What |
|---|---|
| `harbour/harbour_map.gd` | `HarbourMap`: the plan (buildings, lamps, landings), height and paint, the pathfinding grids |
| `harbour/harbour.gd` | the scene: world building, the run, landings, the seven by day and night, the kirk breach, the last night's flight to the boat, the sailing |
| `harbour/street_lamp.gd` | `StreetLamp` (a `Structure`): switched in, lit by the generator, a fog hole, lamplight on creatures |
| `harbour/kirk.gd`, `kirk_keep.gd` | the kirk's model (`Kirk`) and its play (`KirkKeep`): knock, the doors, the bell |
| `harbour/town_house.gd`, `harbour_props.gd` | the town's buildings and furniture, built in code |
| `harbour/paving.gd` | `Paving`: the town's setts, flags, kerbs, pier blocks, wear, puddles, drains, rings, steps and weeds, laid over the terrain. Looks only: no collisions, and `HarbourMap` still decides heights and paths |
| `people/villagers.gd` | `Villagers`: the roster of the seven, what each brings, who lives (`Run.villagers`, `Run.lost`) |
| `people/villager.gd` | `Villager`: one of them on their feet; in the group "prey" when out of doors in the dark (`Enemy.nearest_prey`) |
| `people/outfits.gd` | `Outfits`: dresses a villager's borrowed keeper model as their own (the texture repainted by part, parts cut away, a skirt and props hung on the bones). `LOOKS` by villager id; the keepers' materials are not touched |
| `systems/story_rock.gd` | `StoryRock`: Act Two's story. Survivors in the camp, dawn gifts, the diary, raising the kraken, its death, the clear sky, the last pages |
| `systems/rock_days.gd` | `RockDays`: the story's rock days and nights: each day's event (stores, markers), the special night (`night_kind`, shaping `Spawner.special_rows`), the seven's requests and rewards (`Villagers.REQUESTS`, `Run.favours`) |
| `ui/day_note.gd` | the small note at the top of the screen by day: today's event, and who has asked what |
| `systems/night_rating.gd` | `NightRating`: the dawn report's rated line and the run's total (every rock run) |
| `enemies/kraken.gd` | `Kraken`: the fight's rules in three stages (the camp: fire and searchlights drive arms back; the crossing: cut arms slow it; the light: blinding that shortens, the tower grip, the rear-up), slams, hurt, death |
| `enemies/kraken_bar.gd` | The kraken's bar across the top: its strength under the three stage names (a `CanvasLayer` the kraken makes) |
| `enemies/kraken_body.gd` | `KrakenBody`: the creature (head, eyes, eight arms as tubes rebuilt each frame, like the Eel) |
| `enemies/kraken_part.gd` | `KrakenPart` (an `Enemy`): the places on it that weapons find, which pass hits on to `Kraken.struck` |
| `ui/story_pages.gd`, `ui/story_text.gd` | the keeper's log: the page player, and the pages' words |
| `ui/story_end.gd` | the end card |
| `tools/make_story_stills.gd`, `shaders/sketch.gdshader` | renders the log's drawings from the game's scenes into `art/story/` |

**Between the acts, the Escape** (`scenes/escape.tscn`, `scenes/escape/`, `docs/ESCAPE.md`): the Mary Ann's crossing from Kirkhaven to the rock, played. Its script also extends `scenes/main.gd`; `Terrain.chapter` and `Run.chapter` are 3, and `Terrain`, `KeeperNav` and `CameraDirector` hand over to `EscapeMap`. The boat stays at the origin and the world goes past her. Kirkhaven's `_after_town` sends `Run.carry` there; it hands it on to the rock, less whoever was lost and whatever was spent.

| File | What |
|---|---|
| `escape/escape.gd` | the scene: the boat, the scrolled sea and fog, the rock and its beam, steering, rocks and arms, waves and surges of boarders, the hull, the light, founder and arrival, the save; the autopilot for Dod and a helper; what helper keepers ask |
| `escape/escape_map.gd` | `EscapeMap`: the deck (height, walkable, routes round the wheelhouse), the climbing places, the hull's outline, the camera's framing |
| `escape/escape_helm.gd` | `EscapeHelm`: the wheel (interactable; a keeper at it is held with `in_menu`), Dod Wiseman |
| `escape/boarder.gd` | `Boarder` (an `Enemy`): the drowned and the bloated, swimming up, climbing her side (any hit knocks it off), loose on deck (grab, strike, bloat and burst) |
| `escape/sea_arm.gd` | `SeaArm` (an `Enemy`): an arm that lurks, rears and comes down on a marked ring |
| `escape/escape_hud.gd` | the Escape's card (miles to the rock, hull, the wheel, the seven); the HUD itself is unchanged |
| `shaders/escape_sea.gdshader` | the open sea, its pattern scrolled; her wake and wash |
| `tools/playtest_escape.gd` | the balance bot: the computer's keepers sail it, per sea |

The fog on both maps is `scenes/world/fog_bank.gd` (`FogBank`, owned by `Atmosphere`); the night's small events are `scenes/world/night_events.gd`.

## Tests

`tests/slice_*.gd` (23 scripts, one per system) are `extends SceneTree` scripts, run one at a time:

```
godot --headless --editor --quit --path sea-they-are-angry          # once, after any new class_name script
godot --headless --path sea-they-are-angry --script res://tests/slice_night.gd
```

Each prints `PASS`/`FAIL` lines and a `RESULT` line. Most `quit(1)` on failure; `slice_night`, `slice_retreat`, `slice_coop`, `slice_creatures`, `slice_economy`, `slice_ledge`, `slice_camera`, `slice_interior` always exit 0, so read their output. They set `Players.helpers = false`, jump the clock with `Cycle._enter`, raise `Engine.time_scale`, and several overwrite `user://run.json` (your Continue save). Compile errors printed before the first `PASS` come from `--script` loading class scripts before the autoloads exist; the second pass runs. `slice_behaviour` and `slice_night` cover the core loop, `slice_creatures`/`slice_camp_raid` the creatures, `slice_arms` the weapons, `slice_rescue` the ending, `slice_holm`/`slice_camera` the camp and split screen. There is no aggregate runner; `HANDOFF.md` lists the commands (it omits `slice_camera` and `slice_interior`).

`tests/run_lan.sh` starts `tests/lan_host.gd` in the background, waits 3 s, runs `tests/lan_client.gd`, and greps both logs for `PASS`/`FAIL` (logs in `/tmp/sea_lan_*.log`). The two sides step through stages by the host changing the rat-poison count in the store and the client answering by holding the `sprint` control. Use `GODOT=/path/to/godot tests/run_lan.sh`. Both processes use the real ports on this machine.

## Tools

- `tools/playtest.gd`: balance bot. `-- [nights] [bot|idle] [keepers] [helpers] [calm|angry|raging]` (the README also names an `eco` mode that plants, eats, buys upgrades and sets traps). Backs up and restores your save and best night; stops when the boat comes.
- `tools/playtest_harbour.gd`: the same for Act One. `-- [calm|angry|raging] [speed]`: three computer keepers hold Kirkhaven with nobody playing, each dawn prints what came, what was lost and who is left, and on the last night they bring the seven to the boat.
- `tools/playtest_escape.gd`: the Escape. `-- [calm|angry|raging] [helpers|dod|careless] [speed] [runs]`: the computer's keepers sail the Mary Ann to the rock (one at the wheel, or Dod; or nobody steering or fighting), and each run prints her hull, who was lost, what came over the side and how often she was struck.
- `tools/playtest_kraken.gd`: the last night. `-- [calm|angry|raging] [survivors] [speed]`: the computer's keepers against the kraken, with a line every few seconds and the result.
- `tools/tour.gd`: renders a run played entirely by computer keepers, saving a frame every few seconds of game time (`xvfb-run`, `--fixed-fps 20`).
- `tools/screenshot.gd`: one PNG of a chosen phase, beam mode, or close or homestead view.
- `tools/reel/`: `make_reel.sh` records 16 captioned shots from `reel_director.gd` with Movie Maker and `assemble.py` joins them with crossfades (needs ffmpeg; about an hour).
- `play.sh` / `play.bat`: re-import when any `.gd`, `.gdshader` or `.glb` is newer than `.godot/global_script_class_cache.cfg`, then launch. A fresh clone needs the import (`Could not find type Lighthouse` otherwise).
- Export: presets "Linux" and "Windows" in `export_presets.cfg` write to `build/linux/` and `build/windows/`. F5 to F11 debug keys exist only in debug builds (`DebugOverlay`).

## Art and audio pipeline

- **Characters** (`art/characters/*.glb`, `*.json`, `*.anims.json`): never edited by hand. `art/source/characters/build_characters.py` (Blender 4.2, headless) builds the four keepers, Bloated, Smotherer, Crab, Squid and the Eel's head: skin-modifier bodies, sculpted heads, regional clothing, automatic weights, procedural materials baked with AO into one 1024 texture each. `art/source/characters/animate.py` authors every clip with IK-solved, fully keyed poses and bakes them into the GLBs. Run: `blender -b -P art/source/characters/build_characters.py -- art/characters [names] [--preview]`, then re-import in Godot. `CharacterRig` plays the clips; if a model is missing each creature falls back to primitives built in its own script.
- **Textures**: `art/source/textures/build_textures.py` (numpy and Pillow) writes seamless colour and normal maps to `art/textures/`.
- **World**: terrain, buildings, boats, props and effects are code (`Terrain`, `Look`, `Geo`, `Props`, `FX`); `art/environment/island_environment.glb` and the two files in `art/source/` (`setup_blender_scene.py`, `stylized_character_material.py`, `BLENDER_README.txt`, `ISLAND_README.txt`) are early blockout and starter material that the game no longer uses.
- **Music**: `python3 art/source/music/build_music.py [out_dir]` (numpy, ffmpeg with libvorbis) writes the six `audio/music_*.ogg`: whistle, harp, fiddle, drone, drum in a stone room's reverb; loops are rendered with the reverb tail wrapped on to the start.
- **Sound effects**: synthesised at start-up by `autoload/audio.gd` (no file; first run builds `user://audio_cache_v5`). There is no `Tools/audio` folder in this project.
- **Fonts**: `fonts/` has IM Fell English (titles) and Special Elite (default UI font, set in project.godot); `scenes/util/fonts.gd` picks them.

## Where the plans and the code differ

- `docs/prompts/02_first_release_phases_A-G.md` asks for `Balance`, `Loot`, `Targeting`, `Strings`, `Accessibility` autoloads and classes. As of v0.1.4: `Balance` (`autoload/balance.gd`, a class the scripts' constants read, with the numbers a designer tunes; see `docs/BALANCING.md`) and `Strings` (`scenes/util/strings.gd`, the menus' text) exist; accessibility is in `Settings`. `Loot` and `Targeting` do not: creatures drop through `Enemy.salvage()` and `Salvage`, and each creature picks its own target.
- The plan's appendix numbers are older than the code: it has Day 120, Dusk 30, Dawn 60 s (code 60, 15, 30), lamp burn 0.5 and 1.5 per second (code 0.35 and 1.0), ranges 20 and 18 m (code 26 and 29), a clean refuel of 25 (code 40 per bio), a first wave at t = 0.10 (code 0.06), a bleed-out timer and a solo self-revive (neither exists), and Anger bands with fog and Squid-from-two-points effects (code uses Anger only for extra creatures, the storm chance, the Eel a night early, and the HUD's mood line).
- `docs/prompts/03_phases_H-L.md`: Phase H is this documentation. As of v0.1.4 phases I to L are built except the dawn dissolve of survivors and per-player rebinding (keeper one's keys can be changed; local co-op's keys and the pads' layout are fixed).
- `docs/NEXT_MILESTONE.md` numbers for the creatures are compared in `docs/ENEMIES.md`.
- (Fixed in v0.1.4: the README's control table now says Sprint is Shift and Jump is Space, and Settings names the arrow-key player's Use key as M.)
