# Plan 2: first release, phases A to G

Status: **not started.** The vertical slice it builds on is done (see `docs/DECISIONS.md`). Paste the block below into Claude Code from inside `sea-they-are-angry/`, or tell Claude to "follow docs/prompts/02_first_release_phases_A-G.md".

Original text, unchanged:

```text
TASK
The current directory contains a working Godot 4.3 grey-box vertical slice of Sea They Are Angry (island, day/night cycle, lamp with fuel, one enemy, fences, scavenging, repair, HUD, save). Your job is to take it to a feature-complete first release as defined below, in seven phases. Each phase ends with a headless load check, a self-verification list, and a git commit. Do not skip phases or reorder them.
Before writing anything: read every file in autoload/, scenes/ and docs/. The conventions, signal names, interact pattern, collision layers and Geo helper are established there — extend them, don't replace them. If a phase requires changing an existing file, change it minimally and keep the old behaviour working for solo.
CONSTRAINTS (unchanged from the slice)
Godot 4.3, GDScript only, Forward+. No .tscn files beyond scenes/main.tscn. No editor work required.
All geometry is primitives via Geo, until Phase F, which adds a loader that swaps in real assets when files exist.
GDScript style: one statement per line; no ; chains; super.method(args); set_deferred for collision toggles inside physics callbacks; typed signals; never name a method get/set.
Collision layers: 1 ground · 2 players · 4 structures · 8 enemies · 16 traps.
All balancing numbers live in one file: autoload/balance.gd (new, Phase A). No magic numbers in gameplay scripts after Phase A.
After each phase: godot --headless --quit --path . must be clean of errors. Fix before committing.
Record every judgement call in docs/DECISIONS.md.
THE GAME (reminder)
Keep the lighthouse burning. Up to four keepers on a tiny North Sea rock. Day: gather, repair, plant, build traps, refuel, upgrade. Night: creatures come from the water; the lamp reveals, slows and (focused) damages them. The lamp going Dark or all players down ends the run. Hidden Sea Anger (0–10) escalates difficulty based on dirty fuel, destroyed structures and failures. No win state; survive as many nights as possible.
PHASE A — FOUNDATIONS FOR MULTI-ENEMY, MULTI-PLAYER
A1. autoload/balance.gd (new, register as Balance after InputSetup)
Constants only, grouped by system. Move every number currently hard-coded in the slice into here and reference Balance.X instead. Include everything in the APPENDIX — NUMBERS at the end of this prompt. Add a static func enemy_count_scale(players: int) -> float returning 1.0 + 0.5 * (players - 1) and static func enemy_hp_scale(players: int) -> float returning 1.0 + 0.2 * (players - 1).
A2. Targeting
Enemies currently target the lighthouse by reference. Replace with a Targeting helper in scenes/systems/targeting.gd (class_name Targeting, static funcs):
nearest_in_group(from: Vector3, group: String, filter: Callable = Callable()) -> Node3D
nearest_player(from: Vector3, include_downed := false) -> Node3D
nearest_structure(from: Vector3, ids: Array[String]) -> Structure (skips destroyed)
nearest_trap(from: Vector3) -> Node3D
Enemies implement pick_target() using these. Enemy.lighthouse stays as a convenience reference.
A3. autoload/players.gd (new, register as Players after Balance)
const MAX := 4. var devices: Array[int] (index = player idx; value = device id; -1 = keyboard+mouse). var nodes: Array[Node] (Player instances).
signal player_joined(idx: int), signal player_left(idx: int).
_input: if fewer than MAX joined — any key press joins device -1 (once); any InputEventJoypadButton press on an unjoined device joins it.
count() -> int (minimum 1), alive_count(), all_down() -> bool.
Per-player actions. InputSetup now creates actions named p<idx>_<action> for idx 0–3 (p0_move_left … p3_attack). Idx 0 keyboard+mouse bindings as now. Idx 1–3: joypad bindings with the event's device set when the player joins (InputEventJoypadMotion for sticks, InputEventJoypadButton for buttons: attack = JOY_BUTTON_X, interact = JOY_BUTTON_A, operate = JOY_BUTTON_Y, beam_mode = JOY_BUTTON_B, sprint = JOY_BUTTON_RIGHT_SHOULDER, pause = JOY_BUTTON_START). Idx 0 may also be a gamepad if a gamepad joins first; then keyboard becomes idx 1. Implement Players.bind_device(idx, device) that (re)creates that idx's actions for that device.
Player gets @export var idx: int and reads "p%d_%s" % [idx, action]. Mouse aim only when its device is -1; otherwise right-stick aim, falling back to left-stick movement direction when the right stick is idle.
Main spawns Player 0 at start and listens to player_joined to spawn others at the cottage.
A4. Enemy base extensions
var scales_hp := false. On _ready, max_hp = roundi(base_hp * (Balance.enemy_hp_scale(Players.count()) if scales_hp else 1.0)).
var drops: Array of {kind: String, chance: float, n: int}; _die() spawns Loot for each successful roll.
Generic stagger(duration: float) state usable by any enemy: velocity zero, visual wobble, returns to previous state.
func is_vulnerable() -> bool (default true; Eel overrides).
A5. scenes/systems/loot.gd — class_name Loot extends Node3D
Small coloured sphere (colour by kind, same palette as ScavengePoint) that bobs. Group "interactable". Auto-collects when any player walks within 1.0 m (no key press). Despawns at DUSK. Dawn salvage from kills lives here.
A6. Verify + commit
Solo still plays exactly as before.
Pressing a gamepad button spawns a second keeper at the cottage who moves with the left stick.
grep -r "[0-9]\.[0-9]" scenes/ finds no gameplay-tuning literals outside Balance (visual sizes/colours are fine).
Commit: Phase A: Balance, Targeting, Players, per-player input, Loot.
PHASE B — REMAINING ENEMIES
All three extend Enemy. Each must have a distinct silhouette built from primitives, a distinct movement pattern, a visible attack tell, and a specific response to each beam mode. Register all four in spawner.gd's kind table.
B1. Wall-Crawling Squid — scenes/enemies/squid.gd
Stats from Balance: hp 35, dash speed 4.5, dash 1.0 s / pause 0.6 s, mass 0.8, lunge range 1.5, lunge dmg 10, retreat 3 m, ink every 8 s (radius 4, duration 5), climb 2.0 s, light slow ×0.4, focused dmg 15/s. scales_hp = false. Drop: bio 50%.
Silhouette: low flattened sphere body (r 0.5, squashed to 0.5 height), 6 thin box tentacles splayed outward, cyan (0.3,0.9,0.9) dots (tiny unshaded spheres) along each. Overall darker body (0.25,0.3,0.4).
pick_target(): Targeting.nearest_player, else lighthouse.
States: Emerge → Stalk (alternate Dash/Pause; re-pick target every pause) → Climb (when blocked by a non-destroyed Fence: 2 s, body rises over 1.4 m and drops on the far side; collision_mask temporarily excludes layer 4) → Lunge (when within 1.5 m: 0.2 s tell — dots flash twice — then hit for 10, then Retreat3) → Retreat3 (move 3 m away from target at dash speed, then Stalk).
Parallel timer: every 8 s spawn an InkCloud at its position: Node3D with a translucent cyan sphere r 4, duration 5 s. Effect: any enemy whose flat distance to a cloud centre < 4 has its visible set to false unless the lamp is currently sweeping it (track with var lit_this_frame; lamp sets it in in_light, enemy clears it each physics frame). Players always visible.
in_light(mode, delta): speed_mult = 0.4, lit_this_frame = true; if FOCUSED, take_damage(15 * delta) (accumulate fractional damage in a float and apply integer part) and emit a short high "squeal" message flag the HUD can show as ! above it (text label via Label3D with billboard).
At DAWN: Retreat.
B2. Armoured Crab — scenes/enemies/crab.gd
Stats: hp 150, speed 1.2, mass 5.0, slam structure dmg 50 / player dmg 25, knockback 4 m, wind-up 1.5 s, recovery 1.0 s, front arc 120° takes ×0.5, recovery window ×2, stagger 1.0 s with 4 s cooldown. scales_hp = true. Drop: scrap ×2, 100%.
Silhouette: wide flat box body (1.6×0.5×1.2) (0.5,0.3,0.25) with 3 small grey boxes (embedded scrap) on top, 6 leg boxes, one oversized claw box (0.7×0.4×0.5) on the right that raises during wind-up.
pick_target(): Targeting.nearest_trap → Targeting.nearest_structure(["fence"]) → lighthouse. If hit 3 times by the same player within 5 s, target that player for 8 s.
Movement: straight-line approach (no navmesh); sidestep 90° for 0.8 s if blocked by anything that isn't the target (avoids wedging on rocks).
States: Approach → WindUp (1.5 s; claw rotates up; tint claw brighter; Events.message not used — this is a visual tell) → Slam (0.15 s; damage everything in a 2.0 m × 120° arc in front: structures 50, players 25 + knockback, traps destroyed outright) → Recover (1.0 s; vulnerable_window = true) → Approach.
take_damage(amount, from_dir, source): compute the angle between the crab's facing and -from_dir; if within 60° → ×0.5. If in Recover → ×2. Then super.
in_light(mode, delta): WIDE no effect. FOCUSED: if in WindUp and stagger cooldown ready → stagger(1.0), start 4 s cooldown.
B3. Giant Constrictor Eel — scenes/enemies/eel.gd
Not a normal enemy: it is a scripted encounter with four phases. Still extends Enemy so the lamp sweep reaches it.
Stats: beam_hp 90, coil 20 s (solo 25), lighthouse dps 5, announce 8 s, surge 3 s, prone 1.5 s, melee effectiveness 0.25. scales_hp = true (applies to beam_hp). Drop on Release at lighthouse base: bio ×3, scrap ×2.
Silhouette: a chain of 14 cylinders (r 0.6 → 0.3 tapering) forming the body, plus a wedge head (box 1.2×0.8×1.6) with two unshaded yellow eye spheres. During Coil the body segments are positioned on a helix around the lighthouse (radius 2.2, three turns, rising to y 6) and the head circles at y 2.0, angular speed 0.5 rad/s.
Phases:
Announce (8 s): pick a random spawn point P. Body hidden except a churn: 6 translucent spheres bobbing at P. Events.message.emit("The water is moving."). Spawner reduces other spawns to 25% rate until the Eel leaves (expose Spawner.spawn_rate_mult).
Surge (3 s): body segments move along the straight line P → lighthouse, trailing. Any player within 1.2 m of the line is set prone 1.5 s (Player gets a prone state: can't move/act, body tilted). Any Fence intersecting the line is destroyed outright.
Coil (20 s): segments snap to helix positions. Each physics frame lighthouse.take_damage accumulates 5/s (apply integer part). Head circles. is_vulnerable() = true only during Coil.
Release: body unwinds along the path back to P over 2 s, drops loot at lighthouse base, queue_free. Spawner rate restored.
Damage: take_damage ignored unless Coil. Melee ×0.25. Flare gun ×1.0. in_light(mode, delta): FOCUSED only; if the head position is within the cone (lamp calls in_light using the enemy's global_position; so the Eel overrides a light_probe_position() method that the Lamp sweep uses if present → returns head position) → beam_damage += 15 * delta… no: beam damage is binary "beam on head" — apply take_damage(roundi(12 * delta)) accumulated as float; with ×1.0 so ~90 in ~7.5 s of steady focus.
When hp <= 0 during Coil → Release early, Anger.add(-1). If Coil runs its full duration → Anger.add(2) then Release.
Spawner schedules it (see Appendix): first on night 5 (solo 6), then every 3 nights, never twice in one night; if Anger.value >= 6 schedule one night earlier.
B4. Lamp sweep update
In lamp._sweep, probe position = e.light_probe_position() if the enemy has that method, else e.global_position.
B5. Verify + commit
Night 2 spawns Squid pairs opposite the Bloated group; they climb fences; ink hides a Bloated inside the cloud unless the beam is on it; focused beam kills a Squid in ~2.5 s.
Night 3 Crab walks to the nearest fence, raises its claw for 1.5 s, slams; hitting it from behind does full damage; focused beam during wind-up staggers it.
Force an Eel via a debug key (F9, only when OS.is_debug_build()): Announce → Surge knocks a player prone and breaks a fence → Coil damages the lighthouse → focused beam on the head for ~8 s releases it early.
Commit: Phase B: Squid, Crab, Eel.
PHASE C — ECONOMY: GARDEN, TRAPS, UPGRADES, FUEL, FLARE, COTTAGE
C1. Cottage — scenes/structures/cottage.gd (class_name Cottage extends Structure)
Position (−6, 0, 5). Box 4×2.5×3 (0.6,0.55,0.5) with a dark roof wedge (box rotated). id "cottage", hp 150, repair 1 driftwood. Cannot be targeted by enemies in this release (decorative hp only).
Interact (when not damaged): opens the Cottage Menu (Phase E builds the UI; for now a minimal panel): Eat food (full heal + max hp), Refill flare (1 scrap per shot), Make dirty fuel (1 oil + 2 driftwood → 1 dirty fuel), Upgrade (three paths, see C4).
C2. Garden — scenes/structures/garden.gd (class_name Garden extends Structure)
Position (5, 0, −5). id "garden", hp 100, repair 1 driftwood + 1 seaweed. Low fence box border (0.4,0.3,0.2) and plots (3 at level 1, 4 at 2, 5 at 3) as flat dirt boxes 1×0.2×1.
Each plot: empty → planted → mature. Interact on an empty plot with ≥1 seaweed → planted (small green cylinder). On DAWN every planted plot becomes mature (taller green cylinder). Interact on a mature plot → Stock.add("food", 1), plot empty. Add "food", "oil", "dirty_fuel" to Stock.KINDS.
Bloated Dead now target: Garden → Lighthouse (not player). Burst within 3 m of a planted/mature plot resets it to empty (crop lost); garden structure damage as normal.
Eating food (cottage): player.heal(player.max_hp); player.max_hp += 10 up to 100 + Balance.GARDEN_MAXHP_CAP[level] (10/20/30). Persist max_hp_bonus per player index in save.
Revive time (Phase D) = Balance.REVIVE_TIME[garden.level] (3.0 / 2.5 / 2.0).
C3. Traps — scenes/systems/trap_slot.gd and scenes/systems/trap.gd
TrapSlot (Node3D, group "interactable"): 5 fixed positions just outside the fence ring at radius 10.5, angles 0°, 72°, 144°, 216°, 288°. Flat translucent square marker. Slots 4 and 5 unlock at Defences level 2 and 3. Interact cycles a small 3-option chooser (reuse the cottage menu panel): Spike (2 driftwood), Net (1 driftwood + 1 seaweed), Chain-plate (1 driftwood + 2 scrap).
Trap (StaticBody3D layer 16, group "traps"): kind, uses.
Spike: 3 uses. Any enemy entering (flat dist < 1.0) takes 25 × Balance.TRAP_DMG_MULT[def_level] (1/1.5/2) and the Bloated's Bloat is triggered immediately. Squid ignores.
Net: 2 uses. Squid or Bloated entering → stagger(3.0). Crab ignores.
Chain-plate: 2 uses. Crab entering → stagger(3.0) and ×2 damage from players for its duration. Others ignore.
Each use decrements; at 0 the trap frees and the slot is empty. Crab slam destroys traps outright.
Enemies detect traps via an Area3D on the trap (monitoring enemies layer 8) using body_entered.
C4. Upgrades
Run holds upgrades := {"lighthouse": 1, "defences": 1, "garden": 1} (saved). Costs in Balance (Appendix). Max level 3. Purchased at the cottage. Immediate visible effect:
Lighthouse: max_hp 200/400/600 (keep hp ratio), lamp range +0/+3/+6 to both modes, focused damage ×1/1.5/2 (multiplies Squid/Eel beam damage), fuel burn ×1/0.85/0.7. Visual: red band becomes two then three bands.
Defences: every Fence max_hp 100/200/300 (keep ratio), trap slots 3/4/5, trap damage ×1/1.5/2. Visual: fence rails become thicker/darker.
Garden: plots 3/4/5, max-hp cap 10/20/30, revive time 3/2.5/2. Visual: extra plots appear.
Lamp reads Run.upgrades.lighthouse for range/damage/burn multipliers through Balance tables.
C5. Dirty fuel and oil
Oil washes up as a special ScavengePoint kind "oil" (black box) on nights whose number is in Balance.OIL_NIGHTS (2, 5, 8, 11, …) — appears at dawn of that night, one only. Stock caps oil at 1.
Cottage: make dirty fuel. Lighthouse interact: if dirty_fuel > 0 and fuel not full, offer F to use dirty fuel (lamp.refuel_dirty(30)), E for clean. Add "use_dirty" action (key F / JOY_BUTTON_LEFT_SHOULDER).
refuel_dirty already applies boost + Anger.add(1).
C6. Flare gun
Each player has flares := 2 (max 2). Action "flare" (right mouse button / JOY_BUTTON_RIGHT_TRIGGER via JOY_AXIS_TRIGGER_RIGHT > 0.5). Fires a Flare projectile along aim: speed 25 m/s, range 12, hits first enemy within 0.6 m → 40 dmg; Bloated → immediate Bloat; Eel → full damage if in Coil. On hit or at max range it drops to the ground and creates a FlareLight: OmniLight3D orange, range 3, 4 s, which calls in_light(Lamp.Mode.WIDE, delta) on enemies within 3 m each frame (so Squids are slowed/revealed).
Refill at cottage: 1 scrap per shot.
C7. Scavenge rebalance and seaweed
Six points: driftwood ×2 at three points, scrap ×1 at one, seaweed ×2 at one, bio ×1 at one. Plus the oil point on oil nights. Co-op: add one extra driftwood point per player beyond 2.
Campfire — scenes/structures/campfire.gd: small ring of stones with an unshaded orange flame cylinder at (−2, 0, 7). Interact: heal 30 for 1 seaweed. Group "interactable". Not a Structure (no hp).
C8. Verify + commit
Plant seaweed; next dawn it's mature; harvest; eat at cottage → hp full and max 110.
Place a spike trap; a Bloated walking over it bloats at the fence line instead of at the garden.
Buy Lighthouse 2 (4 scrap + 2 bio): band doubles, cone visibly longer, fuel bar drains slower.
Make dirty fuel on an oil night; F at the lighthouse; cone brighter for 30 s; Anger +1 (debug overlay F10 shows Anger, fuel burn rate, spawn queue).
RMB fires a flare; a Squid in its glow slows.
Commit: Phase C: garden, traps, upgrades, dirty fuel, flare gun, cottage, campfire.
PHASE D — DOWNED, REVIVE, FULL CO-OP
D1. Downed state (Player)
At hp 0: downed = true, body tilts 80°, collision with enemies off, bleed := 30.0 counting down. Enemies ignore downed players (Targeting default excludes them).
A living teammate within 1.5 m holding interact fills a revive bar over Balance.REVIVE_TIME[garden.level]; on completion: hp = 40% max, standing.
Solo: if Players.count() == 1, holding interact self-revives over 10 s, once per night (reset at DAWN). Second down in the same night → run over.
Bleed-out reaches 0 → dead = true (stays down until DAWN, then returns at the cottage with 50% hp; Anger +1 for each player who was dead at dawn).
If Players.all_down() → Run.end_run("Every keeper is down.").
D2. Co-op scaling
Spawner multiplies each wave count by Balance.enemy_count_scale(Players.count()), rounded up.
Enemy.scales_hp applies Balance.enemy_hp_scale (Crab, Eel only).
Eel: coil duration from Balance by player count (solo 25, else 20).
D3. Shared screen and camera
Camera stays fixed; the island fits. Each player has a coloured ring under their feet (idx colours: amber, cyan, magenta, green) and a Label3D "P1".."P4" above the head. Keep players inside the ground radius (clamp position at r 13.5 so no one walks into the sea).
D4. Lamp operator rules
Only one operator; Lamp.set_operator rejects if already operated by someone else (message "Someone is already on the lamp").
If the operator is downed, operator becomes null automatically.
D5. Join/leave
Joining mid-run is allowed during DAY and DAWN only; spawn at cottage with full hp. No mid-run leave (a disconnected controller simply leaves the keeper idle).
D6. Verify + commit
Solo: get downed, hold E for 10 s, stand up; get downed again same night → game over.
Two players: one downed, the other revives in 3 s; garden level 3 reduces it to 2 s.
Two players: night 1 spawn count is ~1.5× solo.
Commit: Phase D: downed/revive, co-op scaling, operator rules.
PHASE E — PRESENTATION: MENUS, FOG, WATER, HUD
E1. Scene flow
main.gd becomes a thin root with a state: TITLE → GAME → GAME_OVER. Title screen (scenes/ui/title.gd): game name, Continue (only if SaveSys.load_run() is non-empty), New Run (confirm if a save exists; clears it), Controls, Options, Quit, and Best night: N. Keyboard/gamepad navigable (ui_up/ui_down/ui_accept).
E2. Pause (scenes/ui/pause.gd)
Action "pause" (Escape / Start). get_tree().paused = true; menus use process_mode = PROCESS_MODE_ALWAYS. Options: Resume, Controls, Options, Quit to title (with the text "Quitting now returns you to the start of this day."). Any player can pause.
E3. Options (scenes/ui/options.gd)
Master / Music / SFX volume sliders (AudioServer buses Master, Music, SFX — create the buses in code at startup if missing), Fullscreen toggle, VSync toggle, Fog quality (Off / Low / High — Low = distance fog only, High = FogVolume). Persist to user://settings.json via SaveSys.
E4. Fog and lighting
Environment.volumetric_fog_enabled = true on High with volumetric_fog_density driven by phase and Anger: NIGHT base 0.03 × Balance.FOG_ANGER_MULT[anger_band] (1.0 / 1.3 / 1.6 / 2.0 for bands 0–2, 3–5, 6–8, 9–10). Low: use fog_density the same way, no volumetrics.
A FogVolume ring (shape box, large, thin) around the island at the shoreline at DUSK/NIGHT so the sea is foggier than the rock.
Lamp cone: on High, raise SpotLight3D.light_volumetric_fog_energy to 4 so the beam visibly cuts the fog; keep the translucent cone mesh as the Low fallback (hide it on High).
E5. Water
shaders/sea.gdshader: two layered scrolling sine displacements on a subdivided PlaneMesh (120×120, 64 subdivisions), dark grey-green (0.1,0.18,0.22) with a lighter foam band near the island (distance from origin 13.5–15) and a subtle fresnel. Phase darkens it. Keep it cheap: no reflections.
E6. HUD polish
Per-player hp bars in a row at the bottom (colour-coded), downed/bleed timers, flare count.
Shared top-left: night, phase/time, resources (now including seaweed, food, oil, dirty fuel), lighthouse hp, fuel bar with burn-rate hint, lamp state.
Atmospheric warning line under the night number, chosen by Anger band: 0–2 "The sea is quiet." · 3–5 "The sea is restless." · 6–8 "The sea is angry." · 9–10 "The sea wants the light."
Danger flash: when lamp is GUTTERING or lighthouse hp < 30%, pulse a red vignette (ColorRect with radial gradient shader) at 1 Hz.
Eel phases show a centred warning for Announce and Coil.
E7. Verify + commit
Launch → title → New Run → play → Esc pauses → Quit to title → Continue resumes at the day start.
Options persist across launches. Fog High shows a visible beam in fog at night; Fog Off still plays fine.
Commit: Phase E: title, pause, options, fog, water, HUD.
PHASE F — ASSET PIPELINE AND AUDIO HOOKS
The user will supply real models and sounds later. Build the plumbing now so dropping files in requires no code changes.
F1. autoload/assets.gd (register as Assets)
func model(key: String) -> Node3D: looks up Balance.ASSET_PATHS[key] (e.g. "res://art/creatures/bloated.glb"); if ResourceLoader.exists(path), instantiate the PackedScene and return it; else return null.
Every entity's _build() becomes: var m := Assets.model(key); if m → add it, find its AnimationPlayer (if any) and store it; else build the primitive grey-box as now. Scale/orientation contract: models are authored with +Z forward... no — Godot forward is −Z: models face −Z, origin at the feet, 1 unit = 1 metre.
func play_anim(name: String) on Enemy and Player: plays the clip if the player exists and has it; otherwise no-op. Call it at state transitions with the contract names: idle, walk, attack, hit, die, plus enemy-specific: Bloated bloat, burst; Squid dash, climb, lunge, ink; Crab windup, slam, recover, stagger; Eel surge, coil, release; Player swing, downed, revive, operate.
Structures: lighthouse, cottage, fence, garden_plot, trap_spike, trap_net, trap_plate, campfire, rock_a/b/c, driftwood, scrap, seaweed, bio, oil, loot_*.
F2. autoload/audio.gd (register as Audio)
func sfx(key: String, at: Vector3 = Vector3.INF): looks up Balance.AUDIO_PATHS[key]; if the file exists, play on an AudioStreamPlayer3D (if a position is given) or AudioStreamPlayer from a pool; otherwise no-op. Bus SFX.
func loop(key: String, on: bool) for ambient loops: wind, waves, lamp_hum, fog_drone. Bus Music for drones, SFX for wind/waves.
func music(key: String) crossfades tracks: title, day, night, eel, game_over.
Dusk muffling: on DUSK add a low-pass AudioEffectLowPassFilter to SFX (cutoff 2 kHz) and remove at DAWN.
Wire calls everywhere the spec names a sound: lamp state changes (lamp_ignite, lamp_gutter, lamp_dark), each enemy's tells and hits, player swing/hit/down/revive, gather, repair, upgrade, trap trigger, flare, Eel phases.
F3. docs/ASSET_LIST.md
Generate from Balance.ASSET_PATHS and AUDIO_PATHS: a table per category with path, description, size/poly budget (creatures ≤ 3k tris, structures ≤ 2k, props ≤ 300), required animation clip names, and for audio the intended length/loop status. Include the orientation/scale contract.
F4. Verify + commit
With no files in art/ or audio/, the game runs identically.
Drop any .glb at res://art/structures/lighthouse.glb (a cube is fine) → it appears in place of the primitive lighthouse.
Drop any .ogg at the gather path → it plays on gather.
Commit: Phase F: asset loader, animation contract, audio hooks, asset list.
PHASE G — BALANCE PASS, DEBUG TOOLS, RELEASE
G1. Debug overlay (F10, debug builds only)
Anger, per-night delta, fuel/burn, spawn queue, enemy count, player count, phase timer. Hotkeys: F5 skip phase, F6 +10 fuel, F7 +5 of every resource, F8 damage lighthouse 50, F9 force Eel, F11 +1 Anger.
G2. Spawn schedule
Implement the full table from the Appendix in Spawner.night_table, including Anger modifiers and Eel scheduling. Night 9+ formula as specified.
G3. Automated smoke test
tests/smoke.gd runnable with godot --headless --script tests/smoke.gd: boots the game scene with Engine.time_scale = 20, runs 3 full cycles with the player standing still, asserts: no script errors, the lamp enters GUTTERING at some point (solo, no refuel), the run ends by night 3 or earlier with reason "The lamp went dark.", and the save file is created at the first dawn. Print PASS/FAIL.
G4. Export preset
Create export_presets.cfg for Windows Desktop, export/sea-they-are-angry.exe, embed PCK. Document the export command in README.
G5. README
Pitch, controls (keyboard + gamepad), how to play (one paragraph each for Day and Night), co-op join, run/save behaviour, asset drop-in instructions pointing to docs/ASSET_LIST.md, debug keys, known limitations.
G6. Final verify + commit + tag
Smoke test passes.
Play nights 1–5 solo with the debug hotkeys where needed; Eel appears night 6 solo.
Commit: Phase G: schedule, debug overlay, smoke test, export preset, README. Tag v0.1.0.
APPENDIX — NUMBERS (put all of these in autoload/balance.gd)
Cycle
Day 120 s · Dusk 30 s · Night min(150 + 10(n−1), 240) · Dawn 60 s. Skip allowed in Day and Dawn.
Lamp
Tank 100 · wide 0.5/s · focused 1.5/s · unmanned ×0.8 · clean 1 bio = 25 · dirty = 30 + ×1.3 energy 30 s + Anger +1 · Guttering 25 s · wide angle 35°, range 20 · focused angle 10°, range 18 · range bonus by level +0/+3/+6 · focused dmg mult 1/1.5/2 · burn mult 1/0.85/0.7 · lighthouse hp 200/400/600, repair 25 for 1 driftwood + 1 scrap · hp 0 → Guttering regardless of fuel.
Player
hp 100 · speed 4.5 · sprint 6.5 (3 s, 2 s cd) · boathook 20 dmg, 2.5 m, 0.6 s, 60° half-arc · flare 40 dmg, 12 m, 2 shots, 1 scrap refill · downed bleed 30 s · revive 3/2.5/2 s by garden level · solo self-revive 10 s once/night · revive hp 40% · dead returns at dawn 50% hp.
Enemies
hp	speed	mass	key numbers
Bloated	60	1.6	2.0	burst 30 player / 40 structure / 3 m · bloat 1.2 s · fence 10 per 1 s · light slow ×0.6 · drop seaweed 30%
Squid	35	4.5 dash 1 s / pause 0.6 s	0.8	lunge 1.5 m 10 dmg · retreat 3 m · ink 8 s cd, 4 m, 5 s · climb 2 s · light slow ×0.4 · focused 15/s · drop bio 50%
Crab	150 (scales)	1.2	5.0	windup 1.5 s · slam 50/25 · knockback 4 · recover 1 s ×2 · front 120° ×0.5 · stagger 1 s, 4 s cd · drop 2 scrap
Eel	beam 90 (scales)	—	—	announce 8 · surge 3 · coil 20 (solo 25) · 5 dps lighthouse · melee ×0.25 · beam 12/s on head · early −1 Anger / full +2 · drop 3 bio + 2 scrap
Scavenge (per day)
3 pts driftwood ×2 · 1 pt scrap ×1 · 1 pt seaweed ×2 · 1 pt bio ×1 · oil ×1 on nights 2, 5, 8, 11… · +1 driftwood pt per player beyond 2. Start: 4 driftwood, 1 bio.
Costs
Action	driftwood	scrap	seaweed	bio	other
Repair fence 25	1				
Repair lighthouse 25	1	1			
Repair garden 25	1		1		
Repair cottage 25	1				
Spike trap	2				3 uses
Net trap	1		1		2 uses
Chain-plate trap	1	2			2 uses
Plant plot			1		
Flare refill (1)		1			
Campfire heal 30			1		
Dirty fuel	2				1 oil
Lighthouse L2 / L3		4 / 8		2 / 4	
Defences L2 / L3	6 / 8	2 / 5			
Garden L2 / L3	4 / 6		3 / 6		
Upgrade effects
Lighthouse: hp 200/400/600, range +0/+3/+6, focused ×1/1.5/2, burn ×1/0.85/0.7.
Defences: fence hp 100/200/300, slots 3/4/5, trap dmg ×1/1.5/2.
Garden: plots 3/4/5, max-hp cap +10/+20/+30, revive 3/2.5/2.
Anger
Dirty fuel +1 · structure destroyed +1 · Eel full coil +2 · player dead at dawn +1 · Eel repelled early −1 · survived night (<3 damaged) −1 · survived (≥3 damaged) −2 · per-night clamp −1..+2 (dawn decay bypasses the clamp).
Bands: 0–2 none · 3–5 +1 per group, fog ×1.3 · 6–8 +2 per group, fog ×1.6, Eel one night early, Crab pairs from night 4 · 9–10 +3 per group, fog ×2.0, Squid groups from two points simultaneously.
Spawn schedule (solo, Anger 0; t = fraction of night; B/S/C/E; opp = point opposite the night's first group)
1: .10 B2 · .45 B2 · .75 B3
2: .10 B2 · .30 S2 opp · .60 B3 · .80 S2 opp
3: .10 B3 · .25 C1 · .50 S2 opp · .70 B3 · .85 S2 opp
4: .05 S2 · .15 B3 · .35 C1 · .55 B4 · .70 S3 opp · .85 C1
5: .10 B3 · .25 C1 · .40 S3 opp · .55 E · .80 B4
6: .05 B4 · .20 S3 opp · .35 C2 · .55 B4 · .70 S3 opp · .85 C1
7: .05 S3 · .15 B4 · .30 C2 · .50 B5 · .65 S4 opp · .85 C2
8: .05 B4 · .20 C2 · .35 S4 opp · .50 E · .75 B5 · .90 S3 opp
9+: night 7 pattern; +1 to every group every 2 nights; Eel every 3 nights from 8 (8, 11, 14…). Solo: first Eel night 6 instead of 5, then 9, 12…
Co-op scaling
Count ×(1 + 0.5(p−1)) · Crab/Eel hp ×(1 + 0.2(p−1)) · Eel coil 20 s (solo 25) · scavenge +1 driftwood point per player beyond 2.
Asset keys (for Balance.ASSET_PATHS / AUDIO_PATHS)
Models: player, bloated, squid, crab, eel_head, eel_segment, lighthouse, cottage, fence, garden_plot, campfire, trap_spike, trap_net, trap_plate, rock_a, rock_b, rock_c, scav_driftwood, scav_scrap, scav_seaweed, scav_bio, scav_oil, loot_driftwood, loot_scrap, loot_seaweed, loot_bio, flare. Paths under res://art/<category>/<key>.glb.
Audio: wind, waves, lamp_hum, fog_drone, lamp_ignite, lamp_gutter, lamp_dark, gather, repair, upgrade, plant, harvest, eat, swing, swing_hit, player_hit, player_down, revive, flare_fire, flare_land, trap_spike, trap_net, trap_plate, bloated_loop, bloated_bloat, bloated_burst, squid_click, squid_ink, squid_squeal, squid_lunge, crab_scuttle, crab_windup, crab_slam, crab_stagger, eel_announce, eel_surge, eel_coil, eel_release, ui_move, ui_accept, warning_dusk, warning_night, music_title, music_day, music_night, music_eel, music_game_over. Paths under res://audio/<key>.ogg.
```

How to resume if a session stops partway: start a new session and say "Continue from Phase X in docs/prompts/02_first_release_phases_A-G.md; read docs/DECISIONS.md and git log first."
