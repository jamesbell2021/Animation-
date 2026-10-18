# Decisions

Judgement calls made where the spec was open, contradictory, or would not work as written. Newest phases append below.

## Vertical slice

### Geometry and camera
- **Camera framing.** From (0, 22, 18) a 45° vertical field of view cannot hold the whole 14 m island: the front rim needs about 45.2°. The camera keeps its position but uses FOV 47 and looks at (0, 0, 3.8) instead of the origin. Measured at 1600×900, every point of the rim and the lighthouse top are inside the frustum.
- **Fence ring.** Eight sections of 4 m on a 9 m ring leave 2.9 m holes, which contradicts "fences form a closed ring". Each section now spans its chord of the ring minus a 1.0 m gap (about 5.9 m long). The narrowest gap between fence ends measures 0.92 m: a keeper (0.70 m wide) can squeeze through, a Bloated (1.0 m) cannot. This keeps the ring closed to enemies without trapping the player inside it.
- **Fence orientation.** Positions use (sin a, 0, cos a) so `rotation.y = a` makes local +X the ring tangent. A test checks the tangent is perpendicular to the radius.
- **Lighthouse lamp housing.** The red band and dark cap surround the spot light at y 8.6, so both have shadow casting turned off. Otherwise the shadow-casting spot light would be blocked by its own housing.
- **Enemy collision height.** The Bloated collision cylinder sits at y 0.9 instead of 0.85, so its bottom is 5 cm above the body origin and never catches the rim of the island when it walks up out of the sea.
- **Keeper stays on the rock.** The keeper is clamped to a 13.5 m radius so nobody walks off the island and falls forever. This rule was otherwise planned for Phase D.

### Interaction
- **Interact distance uses the structure surface.** Structures expose `surface_distance(point)`. The lighthouse subtracts its 1.6 m radius; fences measure to the nearest point of the segment. This replaces "subtract 1.5 for Fence", which fails on a 5.9 m fence. The Bloated burst uses the same measure. Without it a Bloated that stops 3.5 m from the lighthouse centre would never be within its 3 m burst radius.
- **Lighthouse E action when damaged and the lamp needs fuel.** Strictly following the spec, a damaged lighthouse only offers repair, so a guttering lamp could not be refuelled without driftwood and scrap. Now E repairs when the repair is affordable or refuelling is impossible; otherwise it refuels. The prompt always ends with "[R] Operate lamp".
- **Repairing the lighthouse re-lights a guttering lamp** when it has fuel, by calling the lamp's recover check. Without this a destroyed-then-repaired lighthouse would stay guttering.
- **Dusk with a destroyed lighthouse or an empty tank** starts the lamp in GUTTERING rather than BURNING.
- **Attacking is disabled while operating the lamp**, since operating locks the keeper in place.

### Enemies and spawning
- **Light slow timing.** The lamp runs before the enemies in the tree. Each enemy uses `speed_mult` and only then resets it to 1.0, so the lamp's per-frame `in_light()` call always lands. Resetting at the start of the frame, as written in the spec, would erase the slow every frame.
- **Knockback** is stored as its own vector, added to velocity after the state sets it, and decays at 8 m/s². The states overwrite velocity each frame, so a one-off `velocity +=` would vanish immediately.
- **Retreat ignores collisions** (mask 0) so creatures inside the fence ring can walk back out at dawn. Past the shoreline they sink as they go and are freed beyond 20 m.
- **Spawn stagger without `await`.** The 0.3 s gaps between individuals are counted down in the spawner's `_process`. An `await` on a timer would resume on a freed spawner if New Run reloads the scene mid-group, which prints an error.
- **Spawn points** sit at 30°, 90°, 150° and so on around the 17 m ring, so none spawns exactly in front of the camera.
- **Integer divisions** in the night table use `floori(x / 2.0)` to avoid integer-division warnings.

### Presentation
- **Focused beam burns the Bloated (design change, owner's call).** The original spec said the focused beam does nothing extra to a Bloated. After playtesting, the owner chose: the wide beam slows (×0.6), the focused beam burns for 10 hp per second and does not slow. A full focus kills a Bloated in 6 s, and the kill still ends in a burst where it stands. A burning Bloated glows orange. Phase A should move `BEAM_DPS` into `Balance`, and the lighthouse upgrade's focused-damage multiplier (×1 / 1.5 / 2) should apply to it.
- **The beam hits what it visibly lights (owner's call).** The spec's sweep was a flat 2D test, so the focused beam burned creatures right beside the lighthouse where no light could be seen. The lamp now tests its real 3D cone against three points on each creature (feet, waist and head at 0.3, 1.0 and 1.8 m), and the lamp tilts 30° down instead of 22°. The wide beam reaches creatures from 3.2 m to 18.8 m out; the focused beam from 8.2 m to 16.6 m. Intended play: burn them in the shallows and along the fence line, finish them with the boathook near the lighthouse. A Bloated walking in through the focused band takes about 48 damage before it reaches a fence. Creatures can override `light_probe_points()`; Phase B's Eel should return just its head, which covers plan item B4.
- **Lit Bloated reaction.** Playtest feedback: "the light doesn't seem to do anything to the enemy". The 40% slow worked but had no visible cue. A Bloated in the wide beam now eases to a pale yellow and squats (scale 1.12 × 0.84 × 1.12) while lit, fading back over about a sixth of a second. No balance numbers changed.
- Bio scavenge boxes use an unshaded material so they read as glowing at night.
- The Bloated flashes pale for 0.1 s when hit. During Bloat it also gains emission as it brightens.
- The keeper has a dark knit-cap disc on top of the head, a nod to the concept art.

### Verification notes
- `godot --headless --quit` reports no script errors. The headless dummy renderer prints `Parameter "m" is null` from `mesh_get_surface_count` once per primitive mesh that has a `material_override`. Every `Geo` helper creates one. A five-line script with one `BoxMesh` and a material override reproduces it, so it is an engine quirk of the dummy renderer and does not appear with a real renderer. `Geo` is spec-verbatim, so it was left alone.
- With nobody defending, night 1 ends with the lighthouse at 0 hp: seven Bloated bursts at 40 each exceed its 200 hp. That matches the intent that the keeper must fight, but it is worth watching in playtests.

## Visual pass: Valheim-style look (owner's request)

- **Primitives rule relaxed early.** Plan 2 says all geometry stays primitives until Phase F. The owner asked for the game to "look decent" now, with a Valheim look, so this pass adds generated meshes (terrain, rocks, grass tufts) and three shaders, and loads Callum's model and the boathook from `art/`. Each model falls back to the old primitives if its file is missing or not imported. Phase F's loader should absorb `Player.load_art()`.
- **Terrain.** `Terrain.height_at(x, z)` is the single source for the island's shape: a gently bumped plateau, a flat 2.8 m gravel yard around the lighthouse, and a shingle beach that runs from 11.6 m out down under the sea. Ground collision is a trimesh of the same mesh.
- **Creatures follow the terrain height instead of colliding with the ground.** Their collision mask drops the ground layer (now 2 | 4). Without that, a creature walking up the beach slope would snag on the trimesh. They rise out of the water, walk up the beach and sink as they retreat.
- **The keeper's walking limit moved from 13.5 m to 12.9 m**, so the keeper stays above the waterline at 13.2 m.
- **Lighting.** Every phase now sets ambient colour, sun colour and volumetric fog as well as the old values. Night ambient and moonlight were raised (0.34 and 0.5) so the island stays readable away from the beam.
- **The lamp beam** combines spot-light scattering in the volumetric fog (energy 0.45) with a soft additive cone mesh (intensity 0.09) and an omni glow at the lantern. Stronger settings washed half the island out in haze.
- **The lighthouse** is now a striped Scottish light: stone plinth, door, tapered tower with two red bands, gallery and railing, glazed lantern room that glows with the lamp, red dome. Collision is unchanged.
- **The keeper model** is `art/characters/callum_keeper.glb`, rotated from Z-up, scaled to about 1.75 m, and given a vertex-colour material. The boathook GLB replaces the primitive hook.
- **Vertex colours are sRGB.** Both the GLB keepers and the colours written in code are sRGB values, so `Look.vertex_mat()` sets `vertex_color_is_srgb` and the grass shader converts with a 2.2 power. Without it Callum's navy coat rendered pale blue and the whole island looked bleached.
- **The Bloated has wet skin** (roughness 0.32) and a darker drowned grey-green, so it reads against the grass and catches the beam.

## Raised rocky island, cottage, shed and garden (owner's request)

- **The island is a rock now, not a disc.** The plateau sits 1.8 m above the old ground level, with the lighthouse on a 0.5 m gravel knoll. Rocky, mossy slopes fall from a wandering cliff line about 9.8 m out to a shelf under the sea. Slope colour comes from each facet's steepness, so steep faces read as rock. Crags of loose rock are scattered round the cliffs.
- **The slopes stay climbable**, peaking around 40°. The keeper's `floor_max_angle` is 60° so the keeper can scramble down to the scavenge points, which moved out to 12.3 m near the waterline. Creatures follow the height function, so they climb out of the sea on any side.
- **Camera.** The lighthouse top is now 12.5 m up, so the camera moved to (0, 26, 19), aimed at (0, 2, 4), keeping FOV 47. A search over positions found this the closest view that still holds the whole shoreline and the lantern on screen.
- **Beam reach barely changes.** The lamp sits on the knoll 0.5 m above the plateau, so the focused band starts at about 8.7 m from the lighthouse on the plateau, still inside the fence line.
- **Homestead positions differ from plan 2's.** Plan 2 puts the cottage at (−6, 0, 5) and the garden at (5, 0, −5), but at those spots their footprints cross the fence ring. They sit on flattened pads inside the ring instead: the cottage at (−4.8, 2.9), the garden at (5.0, −2.9), and a store shed at (−5.4, −2.8). Each faces the lighthouse, and gravel paths join them. The pads live in `Terrain.PADS`, so the ground, grass and buildings agree.
- **The cottage** (`scenes/structures/cottage.gd`) is a whitewashed stone croft with a slate roof, a chimney and windows that light up from dusk to dawn. It has 150 hp and repairs for 1 driftwood. Its menu is still Phase C.
- **The garden** (`scenes/structures/garden.gd`) is a drystone wall round three tilled plots, with a water butt at the gate. It has 100 hp and repairs for 1 driftwood and 1 seaweed. It has no collision, so keepers and creatures walk over it. Planting is still Phase C, and `plots` is exposed for it.
- **Creatures only attack fences.** A creature blocked by any other static body (cottage, shed) side-steps along the wall for 0.8 s and then heads for its target again. This keeps the plan's rule that the cottage cannot be targeted, and gives Phase B's Crab its "sidestep 90° for 0.8 s" behaviour for free.

## Co-op, animation, sound, menus, effects (owner's requests)

- **Three-player local co-op was pulled forward from Phase D.** `autoload/players.gd` assigns devices: P1 keyboard and mouse with the original action names; P2 the first gamepad, or the arrow-key side of the keyboard (Ctrl, Shift, /, ., ,) if none is free; P3 the next gamepad. P2 and P3 get their own `p1_*` and `p2_*` actions. Phase A's `Players` autoload should extend this one; its 4-player join-by-button-press is not built yet.
- **Downed and revive, simplified from Phase D.** A keeper at 0 hp goes down (tilted, no collision) when others are still up. A teammate holding Use within 1.5 m revives them over 3 s at 40% hp; dawn revives everyone at 50%. Solo keeps the old rule (falling ends the run), so Phase D's solo self-revive and bleed-out are still to do.
- **Co-op scaling** multiplies each spawn group by 1 + 0.5 per extra keeper, rounded up. **One lamp operator** at a time.
- **Keeper models per player:** Callum, Hamish, Mairi (Ewan for a fourth later). Each gets a coloured ring and a name tag only in co-op.
- **Animation is procedural.** The GLBs have no rig, so `Player._rig()` re-parents each limb's parts under a pivot at the hip or shoulder and swings them. The walk cycle follows ground speed, the right arm chops with the boathook, and the body bobs and breathes. Real rigged models with the Phase F clip names can replace this later.
- **Facing:** keepers face their walking direction, turning to their aim for 0.45 s when they swing, and while they work the lamp. The mouse still aims the beam and the swing.
- **Paraffin lanterns:** each keeper carries a lantern in the left hand (it swings with the arm) with a warm 6.5 m light, lit from dusk to dawn.
- **Sound is synthesised** in `autoload/audio.gd` and cached as raw PCM in `user://audio_cache_v2`. A real file at `res://audio/<key>.ogg` replaces any sound. Cold synthesis takes under a second. Buses `Music` and `SFX` are created if missing.
- **Title and pause menus were pulled forward from Phase E.** The title sits over the island at dusk with an orbiting camera and the lamp sweeping for show (`Lamp.showcase`: no fuel use, no effect on creatures). Headless runs and New Run from the game-over screen (`Run.quick_start`) skip the title, so tests start straight into a run.
- **Particle effects** live in `scenes/fx/fx.gd`: chunky low-poly droplets, puffs and splinters with GPU particles, freed when done.
- **Fences** are now sharpened driftwood palisades with lashed rails and cross-braces. Damage shows in stages: the braces snap below 66%, the top rail goes below 40%, and the stakes lean further as hp falls. A destroyed section leaves stumps.
- **Creatures only take hit spray from boathook hits**, not from the beam's burn ticks, which have their own steam.
- **Set dressing:** a procedural sky that follows the phase, screen-space reflections on the sea, a rippled water surface, flower clumps, a jetty and rowboat at the landing, lobster pots, crates, barrels, a washing line, and gulls by day.
- **Tests wait for the scene** to exist instead of a fixed five physics steps. After a slow first frame, Godot can run several physics steps before the scene swap. `tests/slice_coop.gd` covers co-op.

## Fog, dread and foghorn warnings (owner's requests)

- **`scenes/world/atmosphere.gd` owns the mood.** Twelve ellipsoid fog banks circle the island over the sea and drift slowly round it. A low mist volume and drifting mist puffs cover the rock at night. All of it rolls in over 15 s at dusk and thins over 8 s at dawn. The fog has a faint grey-blue emission, so it reads as pale walls of mist by moonlight instead of only darkening the scene.
- **The grade drains at night:** saturation falls to 0.68 and contrast rises to 1.16. A vignette with faint film grain (CanvasLayer 5, under the HUD) closes in from 0.18 by day to 0.6 at night.
- **Night sounds:** a bell buoy out at sea (with a red light) tolls every 7 to 14 s, and creaks, whispers and distant moans come from random directions out in the dark every 9 to 20 s. Distant lightning flashes every 25 to 50 s, with thunder 1 to 2.5 s later. The flash is a separate directional light, so it never fights the phase lighting tween.
- **Bioluminescence:** at night the sea shows small, sparse, slowly pulsing cyan specks. The first version was too large and bright and read as confetti.
- **The foghorn is the alarm system.** Two long blasts at dusk, and one short blast for each spawn group, with a centred warning naming the compass direction (north is up-screen). Three short blasts every 7 s while the lamp is guttering, and a short-long blast once a night when the lighthouse drops below 30%. `Spawner.wave_incoming(point, count)` drives the wave warnings.
- **The title screen opens in the night fog,** with the dusk lighting.
