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

## Typography (owner's request)

- **Two typefaces instead of Godot's default sans.** IM FELL English (SC for titles, Roman for the tagline) for the title, menus, warnings, game-over heading and name tags: an old-print serif that suits a haunted lighthouse. Special Elite, a typewriter face, is the project-wide default (`gui/theme/custom_font`), so the HUD reads like the keeper's logbook. Licences and credits are in `fonts/`.
- **IM Fell's old-style "1" looks like a capital I**, so numbers stay in the typewriter face (the night counter) or are spelled out (the keeper count on the title).

## Studio splash and credits (owner's request)

- **3BL_Indie splash on every game.** `studio/splash.gd` is the first autoload in Sea They Are Angry, Neon Mega Tank and Connor Bell's Wonderland. It covers the screen from the first frame, so the island being built underneath is hidden, then fades the logo in and out over about three seconds. Any key, click, tap or button skips it. Its timeline waits for the game to settle and steps at most 0.1 s per frame, so a long first frame can't skip it. Headless runs (the tests) and `--no-splash` leave it out. The capture tools free it.
- **Credits screen.** `studio/credits.gd` opens from the title menu's Credits button. It names the studio and the team (James, Aaron, Connor, Bonnie), the font licences, and Godot. Each game passes its own title, extra lines and font. Both files are identical in every game; change them everywhere together.

## The crag, the ledge and the beaches (owner's request: "look at Bad North")

- **The owner's notes:** the lighthouse should sit higher on a rock, the island should be a bit bigger, and creatures got past the light too quickly. They should be slow and have to come up a path.
- **Layout (`scenes/util/terrain.gd`):** a meadow about 15 m in radius, ringed by sheer cliffs about 66° steep. Three shingle beaches (east, north, west) are the only ways ashore. In the middle is a crag 4.6 m above the meadow with the lighthouse on top. The only way up for creatures is a ledge path, 2.6 m wide, that winds 300° round the crag from its foot in the north. The homestead sits on the south meadow, toward the camera, where creatures don't walk.
- **Creatures follow a waypoint graph (`scenes/util/nav.gd`):** up their beach, round the worn track at the crag's foot, then up the ledge. They still don't collide with the ground, so the graph is what keeps them off the cliffs. From the north beach the way up is 56 m, about a minute's walk. At dawn they walk back down the way they came and out by the nearest beach.
- **The Bloated is slower:** 1.15 m/s, down from 1.6.
- **Keepers stay on walkable ground.** `Terrain.walkable` refuses moves into the sea or onto ground steeper than about 48°. A keeper slides along a cliff edge rather than walking off it. The boathook and Use only reach things within 1.5 m of the keeper's own height, so nothing is struck or repaired through the crag's walls.
- **The lamp reaches the beaches.** The light sits 4.6 m higher, so the beam is tipped down 38° (was 30°). Ranges are now 26 m wide and 29 m focused (were 20 and 18). The focused beam lands on the beaches and the water just off them. The wide beam covers the meadow and the ledge. Creatures near the top are below the beam, so close in it's the boathook.
- **Fences close the chokepoints:** one across the head of each beach gully, and two across the ledge (at its foot and halfway up). That makes five fences, down from eight. Each leaves a 0.9 m gap on one side: a keeper fits through it, a Bloated doesn't.
- **Shove them off the ledge.** A boathook blow aimed outward on the ledge throws a creature over the edge. It falls, takes 14 damage per metre fallen past the first 1.2 m, and has to walk all the way round again. The higher up the ledge, the harder it lands.
- **Keepers' ladders (`scenes/structures/ladder.gd`)** go down the east-south-east face, top to ledge and ledge to meadow, so the lamp keeper can get down to fight fast. They aren't in the creatures' graph, so creatures never use them. They're placed clear of the lighthouse door, so Refuel and Operate win there.
- **Landings are telegraphed.** The water churns at a landing for 4 s before anything surfaces, so the keeper at the lamp has time to swing the beam round. From night 2, groups of three or more split between two beaches ("north and east"), so one beam can't cover everything.
- **Balance, from `tools/playtest.gd` runs:**
  - With the longer approach, the focused beam is on far more, so the old fuel rates emptied the lamp on night 1. Fuel burn is now 0.35/s wide and 1.0/s focused (was 0.5 and 1.5), and a bio refuel gives 40 (was 25).
  - Waves come earlier in the night so the last one still reaches the fences.
  - One driftwood now mends 50 hp of fence, because at 25 every fence was down from night 3 and never came back.
  - A bot that never leaves the lamp now holds about seven nights.
- **Feedback:**
  - The HUD says when the focused beam is on ("burns oil fast") and when the lamp is sweeping unmanned.
  - At dawn a keeper's log reports what came ashore, how each one was stopped (burned, over the edge, boathook), what it cost, and one tip for the next night.
- **Camera and mood:** the camera sits further back (0, 41, 27) to frame the bigger island. Fog densities are scaled down to match the longer view, and night ambient and moonlight are raised a little so the island still reads in the dark.
- **Mouse aim from the crag top hits what's under the cursor.** Aiming used a flat plane at the keeper's height. From 6.4 m up, a cursor over a beach turned the beam about 18° off, which is more than the focused beam's 10° half-width. While a keeper works the lamp, the cursor ray is now traced down to the ground or the sea, and the lamp turns from its own centre toward that point. Gamepads still aim by stick direction.
- **The big centred warnings were drawn off-screen.** `set_anchors_preset` only moves anchors, so "They are coming." and the foghorn landing warnings sat above the top edge. They now use `set_anchors_and_offsets_preset`.
- **First day briefing:** a new run opens with four lines on what to do: gather on the beaches, the ladders, mending and the lamp, burning, and the ledge shove.

## The other creatures, the lamp-room door, homestead raids and the hammer (owner's requests)

- **Phase B's three creatures are in**, adapted to the crag island rather than built to plan 2 word for word:
  - **Squid** (`scenes/enemies/squid.gd`): 35 hp. Dashes for 1 s at 4.5 m/s, then pauses for 0.6 s. It ignores the paths and crawls straight over everything (beaches, cliffs, the crag's walls) toward the nearest keeper outside the lighthouse, leaning into slopes as it climbs. It goes up and over fences and buildings, and with no keeper outside it goes for the lighthouse door. Its lunge has a 0.35 s tell (the dots flash), deals 10, then it backs off 3 m. Every 8 s it leaves an ink cloud (radius 4, 5 s) that hides any creature inside it unless the beam is on that creature. The wide beam slows it ×0.4; the focused beam burns 15/s, about 2.5 s to kill, with a "!" while it squeals. The plan's 0.2 s tell is too short to react to from the game camera, so it is 0.35 s.
  - **Crab** (`scenes/enemies/crab.gd`): 150 hp (+20% per extra keeper), 1.2 m/s, too heavy to shove off the ledge. It walks the paths to the nearest homestead building and slams fences on the way. Each slam has a 1.5 s wind-up (the claw rises and glows) and hits a 2.2 m, 120° arc: 30 to buildings, 25 to keepers with a hard shove. Blows from the front do half damage, with sparks and a clang; during the 1 s recovery they do double. Three hits from one keeper within 5 s make it go for that keeper for 8 s. The beam can't hurt it, but a focused beam in its eyes during the wind-up staggers it (4 s cooldown). Killing it with the boathook drops 2 scrap.
  - **Crab balance:** playtests showed one unopposed crab flattening the whole homestead in a night. So it now tears at the wreckage for 2.5 s between slams on a building, and once it has wrecked one building it drags itself back to the sea. Each crab costs at most one building unless a keeper stops it. Only once the whole homestead is down does it go for the lighthouse.
  - **Eel** (`scenes/enemies/eel.gd`): a scripted encounter.
    - **Announce, 8 s:** dark humps churn off a beach, with a long foghorn blast and "The water is moving."
    - **Surge, 3 s:** it rushes up over the beach, cliff and crag toward the lighthouse. Fences in its line are smashed and keepers in it are knocked flat for 1.5 s.
    - **Coil, 25 s solo or 20 s co-op:** it wraps the tower and crushes it at 5/s. Its head rears out over the ledge, 6.6 m from the tower and 3.6 m above the top, circling slowly. That spot is inside the focused beam's reach. The plan put the head at the tower's foot, where the tipped beam can't reach.
    - **Release:** the focused beam on the head does 12/s against 90 hp (+20% per extra keeper). Driving it off early gives Anger −1 and +3 bio, +2 scrap. Outlasting the coil gives Anger +2.
    - **Damage:** boathook blows on the coils do a quarter.
    - **Body:** one tapering tube rebuilt each frame through its control points, not a chain of spheres, which read as loose balls.
- **Schedule (`spawner.gd`):** plan 2's appendix table, with t compressed by about 0.8 for the long walk up. Rows are [t, kind, count, "opp"], and "opp" lands on a different beach from the night's first group. Night 9+ repeats night 7 with +1 per group every two nights. The Eel comes on nights 6, 9, 12… solo and 5, 8, 11… in co-op, a night earlier at Anger 6+. While it's about, other groups shrink to a quarter. Warnings name the kind ("Something skitters in the shallows", "Something heavy drags itself ashore"). F9 brings the Eel in debug builds.
- **Homestead raids:** from night 2, every second Bloated group of a night makes for the nearest of the cottage, shed and garden ("They're making for the cottage!"). It walks the paths to a stop beside the building (new nodes in `Nav`) and bursts on it.
- **Homestead buildings:** the shed is now a `Shed` structure (120 hp). Damage shows: the cottage's roof sags and slips, the shed's roof skews and its door hangs, the garden's rows are trampled. A cottage or shed below 45% smoulders. Mending any of them gives 50 per driftwood (the garden also takes kelp), like fences. A seaweed pile on the west beach supplies the kelp.
- **Repairs take a hammer.** Using a damaged building swaps the boathook for a claw hammer: three blows over about a second, each with a synthesised hammer knock and splinters. The stock is spent and the repair applied when the hammering is done. With nothing to pay with, there is no hammering, just "Need …". Refuelling at the lighthouse is a pour from an oil can instead. Keepers can't move meanwhile.
- **The lamp-room door.** R near the lighthouse takes the lamp at once, then the keeper walks up to the door and goes in. Inside they are out of sight and nothing can hurt them. R again lets go, and they step out a few paces clear of the door. Pressing R on the way in turns them round. At dawn they come out by themselves.
- **Keepers can be knocked about:** `knock_prone(t)` (the Eel's surge) and `shove(v)` (the Crab's slam).
- **Shared enemy plumbing (`enemy.gd`):**
  - `replan()` and `at_target()`: buildings are measured to their walls.
  - `stagger(t)`, `is_vulnerable()`.
  - `inked` and `lit_this_frame`: the lamp sets the flag before calling `in_light`.
  - Shove only below mass 3.
  - `Enemy.nearest_home()`.
- **Playtest bot, lamp keeper only, perfect aim:** survives eight nights.
  - Each Crab costs about a building a night.
  - The Eel is driven off on its first visit.
  - From night 6, lighthouse damage comes from Bloated that reach the top.
  - Human mouse aim will do worse than the bot on Squids.

## The Smotherer, a fifth creature (owner's request, from the roadmap's idea)

- **Why:** the roadmap's idea was a creature that threatens the lamp keeper: it climbs the lighthouse and must be knocked off by another keeper. Solo, it forces you off the lamp for a while.
- **`scenes/enemies/smotherer.gd`:** a gaunt, pale drowned thing. 50 hp, 1.4 m/s, mass 1.2, so it can be shoved off the ledge.
  - **Getting there:** it comes up a beach and the ledge like the Bloated.
  - **Climbing:** at the tower it climbs hand over hand at 1.3 m/s.
  - **Smothering:** at the top it wraps itself over the lantern. While any Smotherer is there (counted), the beam's energy is ×0.12 and its range ×0.3, so it can't reach anything worth slowing or burning. The lantern glass also cracks at 2 hp/s.
  - **Alarm:** four foghorn blasts and "The light is smothered!"
  - **HUD:** "Lamp: SMOTHERED", and the keeper in the lamp room is told to go out.
- **Beam can't burn it:** it only slows ×0.6 in either beam. A first version could be burned like the Bloated, and the playtest bot burned every one on the beaches, so it never threatened the lamp at all. It is boathook work: on the ledge, where an outward blow knocks it over the edge, or at the tower.
- **Harpooning it down** (replaced shaking the tower, which looked janky): on the tower it can't be struck, but from anywhere on the crag top within 10 m of the tower an attack throws the boathook up at it like a harpoon. The throw is a clip with the hook leaving the hand at 0.32 s, and the hook homes a little because the creature keeps climbing. A hit makes it let go of the stone and drop from where it clung as a ragdoll, and wounds it (15). Fall damage is the usual 14/m past 1.2 m, so from the lantern it dies; from low down it gets up and tries again.
  - **Then the hook has to be fetched:** it bounces off the stone and comes to rest on walkable ground just out from the tower's foot, glinting. With it gone the keeper has nothing to swing, and walking over it takes it back. At dawn it comes back on its own, so it can't be lost for good.
  - **Prompts:** in reach, "[LMB] Throw the boathook up at it!"; while it's out, "Your boathook lies by the tower: walk over it to take it back".
- **Schedule:** one on nights 4, 5 and 6, two on night 7 (and so on from 9), two together on night 8. Warning: "Something pale crawls from the sea".
- **Playtest bot:**
  - Solo: the lamp is smothered for 4–41 s a night from night 4, and each time the keeper has to go out and harpoon it down.
  - Co-op: the keeper holding the ledge kills every Smotherer on the way up, so the lamp is never smothered. That gives the second keeper a clear job.


## Storm weather and glowing eyes (owner's request: "really creepy")

- **One storm value drives everything.** `scenes/world/weather.gd` (`Weather`, created by `Atmosphere`) eases a global shader uniform `storm` (declared in `project.godot` under `[shader_globals]`) toward a level per phase: day 0.12, dusk 0.6, night 1.0, dawn 0.3, over 12 s. The grass, sea and beam shaders read it, so nothing has to be wired per material.
- **Rain:** 5,000 stretched GPU particles over the whole island, thinning out below storm 0.35. The vignette shader gets slanting streaks, and the lamp's beam shows rain falling through it, which is the cheapest way to make the beam feel wet.
- **Wind:** the grass sways harder and faster as the storm rises, with a gust band sweeping across the meadow and a lean downwind. Gust sounds come at random.
- **Sea:** storm rollers, a swell up to 6× higher offshore, darker water and wider foam. The water inside about 16 m stays calmer so the beaches still read. Breakers burst on the three beaches (`FX.breaker`), from every 1.6 s in calm weather to every 0.32 s at full storm, each with a synthesised crash.
- **Lightning:** above storm 0.45, a strike comes every 5–12 s (more often in heavier weather). A jagged bolt with a fork drops into the sea, the sky and the whole island flash white, and thunder follows after a delay. One strike in six hits the lighthouse's rod instead.
- **The watchers:** 70 pale drowned figures standing in the surf 18–30 m out, all facing the light, with pinprick eyes. They are only ever visible for half a second during a flash (40% of flashes), so they read as a glimpse rather than something to fight. They are not creatures and nothing touches them.
- **Glowing eyes:** every creature's eyes use `Look.eye_mat` (unshaded, high energy) plus `Look.glint`, a camera-facing additive halo. The halo matters: the eyes are a few pixels across from the game camera, so the glow alone vanished at distance. Colours: Bloated sickly yellow-green, Squid cyan, Crab red, Eel yellow, Smotherer pale pinpoints in black sockets.
- **Random weather each night (owner's request, after the reel showed nights too dark to read):** at dusk each night rolls one of three kinds of weather (`Weather.tonight()`):
  - **Clear:** calm and moonlit, almost no rain or wind; ambient ×1.2, moon ×1.45, half the fog, a lighter vignette.
  - **Squalls:** storm level 0.6 at night, with rain, gusts and the odd lightning strike.
  - **Storm:** the full gale, eased to 0.9 from 1.0, with ambient ×1.1 and less fog than before.

  The base night is brighter too: ambient energy 0.95 (was 0.72), moon 1.05 (was 0.85), and less fog. Night 1 is always clear. After that a storm comes 20% of the time, plus 4% per point of Anger up to 60%; squalls come 35% of the time; and the rest are clear. The roll is seeded per run (`Run.weather_seed`, saved), so a reloaded night has the same weather. The HUD names tonight's weather, and the dusk warning says what is coming. The title screen is always a storm.
- **Tuning from renders:** the first breakers were white cotton balls, so they are now a burst of spray with a few faint puffs. The whitecaps blew out to white in a lightning flash, so they are toned down at full storm. The watchers were too small to notice, so they are 1.5–2.2× scale and closer in.

## Phase C: garden, cottage, upgrades, traps, oil, flares, campfire (owner's request)

Built to plan 2's Phase C, with these departures:

- **Garden (`garden.gd`, `garden_plot.gd`):** five narrow potato beds inside the existing drystone wall; upgrades show 3, 4 or 5. Planting digs in 1 kelp (seaweed was a real island fertiliser); planted beds show kelp and shoots, and at dawn they are ready, with bushy flowering haulms. Lifting a bed gives 1 food. Any damage to the garden ruins one bed with a crop in it, and wrecking it loses them all. That covers the plan's "a burst near a plot ruins it", and the Crab too. Bed states live in `Run.crops` and are saved. A second kelp heap on the east beach (1) joins the west beach's (2), since kelp now goes on planting, mending the garden and nets.
- **Cottage menu:** a generic `ChoiceMenu` (`scenes/ui/choice_menu.gd`). The keeper who opened it stands still; the night carries on. Mouse, number keys, arrows or d-pad pick; Esc or B leaves. One menu at a time across keepers. Rows:
  - Eat (1 food): full heal and +10 max health, up to the garden level's cap (10/20/30). The bonus is per keeper in `Run.max_hp_bonus` and saved.
  - Load a flare (1 scrap).
  - Mix dirty fuel: **1 oil + 1 driftwood makes 2 cans** (plan: 1 oil + 2 driftwood makes 1). Oil comes only every third night, so one can per drum felt like too little to bother with.
  - The three upgrades, with cost and what the next level gives.
  A damaged cottage asks for the hammer first when the keeper can pay for it.
- **Upgrades (`scenes/systems/upgrades.gd`):** the plan's tables and costs as written. `Upgrades.apply()` runs at the start of a run and after each purchase, keeping health ratios. The lighthouse gains brass hoops and a brass gallery rail at level 2, then a copper dome and iron storm shutters at level 3. Plan 2 said more red bands; brass reads better against the white tower at night. Fences go tarred black with thicker rails at 2, and get iron straps at 3. `Lamp.focus_mult` and `Lamp.dps_mult` carry the focused-damage multiplier into the Bloated's, Squid's and Eel's beam burn.
- **Traps (`scenes/structures/trap_slot.gd`):** one class handles both slot and trap (no separate StaticBody or Area3D). It checks creatures within 1.1 m each physics frame and skips any it has already caught. The slots sit where the creatures actually walk on this island, not on a ring at radius 10.5 as plan 2 had it:
  - three up the middle of the beaches (t 0.6, short enough of the fence that a Bloated bursting there can't reach it);
  - one on the ledge (defences 2);
  - one at the ledge's foot (defences 3).
  Each slot is a cairn with a red rag. The trap kinds:
  - **Spike:** 3 uses, 25 × the trap multiplier; a Bloated bursts where it stands; Squid skitter over.
  - **Net:** 2 uses, a 3 s tangle for the Bloated, Squid and Smotherer; Crabs ignore it.
  - **Chain plate:** 2 uses; flips a Crab for 3 s, then 5 s of double boathook damage; others reel for 1 s.
  A Crab's slam smashes any trap in front of it. Kills count as "in traps" in the dawn log.
- **Dirty fuel:** at the lighthouse, F (or LB) pours a can with the oil-can job: +30 fuel, 30 s burning hot (light ×1.3, beam burn ×1.5), Anger +1. The HUD says "BURNING HOT on dirty fuel".
- **Oil:** a rusted drum on its side with a black slick washes up at dawn after nights 2, 5, 8…, once only, and the dawn log says on which beach. There is no cap of 1 on oil in stock.
- **Flare gun:** RMB (LT on a pad) lobs a flare in an arc to the ground under the cursor, up to 14 m, or 10 m along the aim on a pad. The plan's straight shot along the aim, at 12 m, was hard to place from this camera with the crag in the way. The first creature within 1 m of where it lands takes 40, and a Bloated bursts. It then burns red for 8 s (plan: 4 s), lighting 3.5 m around it like the wide beam: slows, cows, and shows creatures hidden by ink. Two shots per keeper, saved in `Run.flares`.
- **Campfire (`campfire.gd`):** a stone fire pit in front of the cottage, towards the shed. It burns low by day and up at dusk, and smokes. Throw on 1 driftwood for +30 health; the plan said 1 seaweed, but kelp already has three jobs.
- **Scrap:** the scrap heap gives 2 a day, not 1. In a 10-night bot playtest, 1 scrap a day bought only two upgrades in ten nights, because flares, chain plates and every upgrade but the garden all want scrap.
- **Co-op:** a third keeper adds a driftwood point on the south beach.
- **Revive time** follows the garden level (3/2.5/2 s).
- **Tests:** `tests/slice_economy.gd` covers all of the above (37 checks).

## Characters remade in Blender, with ragdolls (owner's request: "Valheim level", "ragdoll and get back up")

- **One script builds every character:** `art/source/characters/build_characters.py`, run headless in Blender 4.2 (see `art/README.md`). Nothing is hand-edited, so a character can be changed and rebuilt in minutes. The four keepers, the Bloated, the Smotherer, the Crab, the Squid and the Eel's head all come from it. The old primitives remain as a fallback in each script if a model is missing.
- **What gets it toward the Valheim look:**
  - Heads sculpted with real structure: brow ridge, deep-set heavy-lidded eyes, cheekbones, a jaw and chin, a fleshy nose.
  - Chunky beards made from a mass plus hanging clumps.
  - Proper clothes: a cable gansey, a boiler suit, a waxed jacket, an oilskin coat and sou'wester, sea boots with soles, belts, buckles and pockets.
  - Painterly baked textures: noise, cloth patterns, curvature shading and ambient occlusion.
  - Stocky proportions: big hands, broad shoulders, shorter legs.

  It is still procedural modelling, not hand sculpting: up close the forms are simpler than Valheim's. The script is where to push further (more head detail, cloth folds, a second texture pass).
- **Animation was first posed in code** (sine cycles through `CharacterRig.pose()`); it is now clips, below. Tools sit in the keeper's right hand and the lantern hangs from the left, on bone attachments.
- **Ragdolls (`CharacterRig.ragdoll()`):** on demand, the rig builds a `PhysicalBoneSimulator3D` with a capsule per bone and cone joints with swing and twist limits.
  - **Collisions:** the bodies sit on their own collision layer (32) and collide only with the ground and buildings.
  - **Speed cap:** speeds are capped at 7 m/s (and spin at 14 rad/s). Without the cap, a body that starts against the crag wall was flung 10 m into the air.
  - **Getting up:** the owner moves to where the ragdoll lies, found with a ray down because the island has several levels, and gets up with a get-up clip (see the next section). With no clip it blends back into the animated pose over 0.55 s. If the ragdoll is lying somewhere it can't stand (the sea), it snaps up on the last safe ground instead of stretching across the gap.
  - **Lifetime:** the physics bodies are freed after getting up, so idle characters cost nothing.
- **When keepers go down** (since the hit reactions, below, only big blows floor them):
  - A hit of 25 or more (a Crab's slam, a Bloated's burst) knocks them flat for about a second.
  - The Eel's surge knocks them flat for its prone time.
  - Downed keepers lie as ragdolls until revived. The revive test now keeps the reviver beside the body, since it can slide.
- **When creatures go down:**
  - A boathook hit staggers a Bloated, Smotherer or Squid; the second within 3 s floors it (the third for a Bloated). See the hit reactions, below. A blow aimed out over the ledge throws it off for real, and the fall damage (the usual 14/m) applies when it lands. Knocked into the sea, it's gone.
  - The Crab is too heavy to knock down, but a chain plate now throws it on its back as a ragdoll, wide open.
  - A harpooned Smotherer falls from the tower as a dead weight and, from the lantern, dies of the fall.
  - The dead lie as ragdolls for five seconds, then sink away. The Bloated still bursts, and the Eel is a scripted giant with no ragdoll.
- **The Eel** keeps its tube body (it has to wrap the tower) but gains a mottled texture, a pale belly, a ragged dorsal fin and a moray head modelled in Blender.
- **Eyes** are placed from points the build script writes alongside each model (`*.json`), so the glows sit in the sockets.
- **Character models go through Git LFS** (path rule for `sea-they-are-angry/art/**/*.glb`). The textures Godot extracts from them are git-ignored.

## Animation clips (owner's request: "make sure the animations are more realistic"; "take any you need from Forged in Formation")

- **What came from Forged in Formation:** the method, not files. Its own Blender scripts (`Art/Characters/build_human_anims.py` and `crouch_solver.py` in the Formnation repo) solve poses rather than ease between them by eye. Every frame is worked out in full and keyed, the legs by two-bone IK on the true hip, knee and ankle joints with an explicit knee pole, so a planted foot stays put. `art/source/characters/animate.py` ports that solver to Sea's rig.
  - Its Unreal Mannequin clips can't be reused: they are Epic's content, licensed for Unreal Engine only, and on a different skeleton.
- **The clips are baked into each character's GLB** by the same build, solved on that character's own skeleton. The squat Bloated and the long-legged Smotherer get steps that fit their legs, because distances are in leg lengths. `<name>.anims.json` beside each GLB gives each clip's length and loop, the locomotion cycles' real period and speed, how high a climb cycle rises, and where the hips lie at the start of each get-up.
- **What each character has:**
  - Keepers: idle, walk, run, sprint, swing, hammer, pour, climb, flare, hit, revive, get up from the back, get up from the front.
  - Bloated: idle, a shambling walk dragging the right leg, swelling to burst, a two-handed strike, hit, both get-ups (slower and heavier).
  - Smotherer: idle, a hunched stalking creep, the tower climb, smothering the lamp, strike, hit, both get-ups.
  - Crab: idle, a tripod walk with each leg tip planted by IK, rummaging in wreckage.
  - Squid: idle, a crawl that drags the body after alternating sets of arms, the lunge.
- **Walking that isn't skating:** walk, run and sprint are one-second cycles in step: left heel strike at 0, right at 0.5. The game blends them by speed and plays them at the rate that matches how fast the character really moves, so a foot on the ground stays put.
  - The cycles carry the detail of a real gait: heel strike and toe-off rolling over the heel and ball of the foot, the hips rising over the standing leg and swaying toward it, the pelvis turning and dropping on the swing side, the shoulders turning against it, and the head held steady.
  - Measured on Callum's walk: the knee is about 15° at heel strike, 4° at mid-stance, 38° at toe-off and 57° in the swing. The run is about 45° at mid-stance and 110° in the swing, with a flight phase.
- **How the game plays them (`CharacterRig`):**
  - **The blend:** one AnimationTree per character, advanced by hand each physics frame: idle into walk/run/sprint by `locomote(speed)`, then a held `activity()` (hammering, pouring, the ladder, kneeling to revive, a creature climbing or swelling), then an upper-body `shot()` that the legs walk under (the swing, the flare, a flinch, a creature's strike), then a full-body `shot()` (the get-ups, the Squid's lunge).
  - **Code on top:** `layer()` adds code turns over the clips: the Crab's claw cocked for a slam, the Bloated and Smotherer hunching from the beam.
  - **Timing:** the hammer clip is one blow in `STRIKE_TIME`, landing when the game plays the sound. A creature's strike is fired so it lands as the fence takes the damage, and the Squid's arms snap shut as its lunge strikes.
- **Getting up for real:** when a ragdoll gets up, `getup_plan()` works out whether it is lying face up or face down (from which way its chest faces), which way to face, and where to stand the owner so that the clip's first frame lies where the body does. The limp body blends into that first frame over 0.3 s and the clip takes it up:
  - off the back: up on the elbows, sit up with the knees drawn in, rock forward over a hand onto the feet, hands to the knees, stand;
  - off the front: a push-up, a knee under, a foot planted, stand.
  Keepers take about 1.4 s, the heavy Bloated nearer 2.3 s.
- **Checked:** every clip was rendered as frame strips in Blender and through the game's own rig in Godot, and in the reel's new "moves" shot (a swing that floors a Bloated, which gets up; a keeper floored and getting up). All seven test suites still pass.
- **Limits:** the clips are authored in code, not motion-captured or keyed by an animator. There are no hand or finger poses and no facial animation. Turning on the spot doesn't step, it slides. Climbing a ladder still moves the keeper in straight lines, with the clip on top.

## Hit reactions before ragdolls (owner's request: "people ragdoll too easy, need to show they are being hit, react and then ragdoll")

- **Keepers take a blow by its size:**
  - Under 12 damage: a flinch, an upper-body clip they keep walking under.
  - 12 to 24 (a Squid's lunge): a stagger. The body snaps away from the blow, a foot steps to catch the weight, the arms fly out, and they slide half a metre with no control for 0.45 s. The clip's planted foot is keyed against exactly that slide, so it doesn't skate. Hit from behind, they stumble forward instead.
  - 25 and up (a Crab's slam, a Bloated's burst, the Eel's surge): the stagger plays for 0.16 s and then the body goes limp, carrying the blow's momentum.
- **Creatures have poise:**
  - A boathook hit staggers a light creature back (Bloated, Smotherer, Squid). It turns to the blow, reels back in its stagger clip, and stops what it was doing for 0.55 s.
  - The blow that wears its poise down floors it: the second within 3 s, the third for a Bloated. That blow shows for 0.14 s before the ragdoll.
  - A blow aimed out over the ledge still throws it straight off.
  - The Crab only flinches in its shell: no turn, no slide.
  - Death blows react before going limp too.
- **Livelier between the clips:** `CharacterRig` adds a little on its own.
  - Bodies lean forward when they speed up, back when they pull up, and into turns.
  - Heads turn to look: a keeper at the nearest creature within 7 m (or where they aim); a creature at the nearest keeper within 8 m.
- **Runs that fit the game's speeds:** the keepers' run and sprint were re-solved to their real speeds, 4.5 and 6.5 m/s: longer strides, shorter ground contact, and a proper flight phase. Before, the game played the sprint sped up for an ordinary run.

## Textured ground and buildings (owner's request: "smooth the polys on the ground, add textures to the ground, walls and buildings, a slate roof, normal or bump maps")

- **The ground is smooth now:** one shared vertex per grid point on a finer grid (0.45 m). Normals come from the height function itself, so the meadow rolls instead of showing facets. The cliffs keep their shape but no longer read as flat-shaded polygons.
- **Ground textures:** grass, dirt, shingle and rock, each with a normal map, all generated and tileable (`art/source/textures/build_textures.py`).
  - **Blending:** the terrain shader blends them by weights the mesh carries per vertex. Rock goes where it's steep or past the cliff line, shingle on the beaches and the lighthouse yard, dirt on the tracks, the ledge path, the building pads and bare patches.
  - **Colour:** it still comes from the island's painted vertex colours. Each texture is divided by its mean colour, so it adds detail without changing the palette.
  - **Rock:** projected from all three sides, so the cliff faces aren't stretched.
  - **By the sea:** the ground is darker and glossier, as if wet.
- **The cottage:**
  - **Slate roof:** courses of slates along the eaves, lips facing down each slope, a little moss, and a slate ridge.
  - **Walls:** whitewashed roughcast ("harl"). Its tint still darkens as the cottage is damaged.
  - **Stonework and door:** a rubble footing and chimney, and a boarded door.
- **Everything else:**
  - The lighthouse is painted render over a rubble plinth.
  - The shed is rubble-built with a slate roof.
  - Timber is boards: fences, the jetty and its piles, the boat, crates, barrels and doors.
  - Loose rocks and sea stacks get rock detail over their painted colours.
- **How it works:** these materials project the texture from three sides in each object's own space (StandardMaterial3D triplanar), so the boxes and cylinders the buildings are made of need no UVs, and a tilted roof slab still has its slates running along the eaves. The normal maps give the relief: slates' lips, rubble faces, pebbles, the bedding in the cliffs.

## Slower out of the sea; the Eel's coils hug the tower (owner's requests)

- **Wading ashore:** creatures coming up a beach, below the meadow, move at half speed: slowed by the surf and the shingle, which gives the beam time to find them and burn them. It applies while they approach, not while they retreat. Rising out of the water takes 1.6 s instead of 0.8. The Eel isn't affected.
- **The Eel's coils:** they used a fixed 2.1 m radius round a tower that tapers from 1.6 m to 1.15 m on a 2.15 m plinth, so the thick lower coils sank into the stone and the thin upper ones stood off it. Each coil now follows the tower's radius at its height plus the body's thickness there (pressed in a little), and the lowest starts above the plinth.

## The cottage's fire, chimney smoke in the wind, and the Eel's coils seen through (owner's requests)

- **A fire in the cottage after dark:** from dusk the four-pane windows (glazing bars and stone sills now) glow with firelight that flickers like an open fire and an oil lamp: the glow's brightness wavers on a few beating rhythms with a little randomness, and its colour shifts between lamp-yellow and ember-orange. The light thrown out in front of the cottage flickers with it.
- **Smoke that follows the wind:** `Weather.wind_now` is the wind over the island (a breeze, up to a gale in a storm, plus gusts), the same wind the rain slants in. The chimney smoke takes its push from it every frame. On a still night it climbs a few metres in a soft, drifting plume. As the wind rises it rises less and leans further, and in a storm it's torn off flat and carried away downwind. It's thin by day and thicker once the fire's built up at night.
- **Soft smoke:** smoke is drawn with soft, ragged, camera-facing puffs now (`FX.smoke`), not shaded spheres, so it reads as a plume, not a string of beads. A badly damaged building's smoke uses them too.
- **The Eel's coils were see-through:** the body tube's triangles were wound the wrong way for Godot (counter-clockwise from outside), so the outside was culled and only the inside of the far half drew: the lighthouse showed through each coil. Rewound, with both faces of the back fin drawn.

## Burning in the beam (owner's request: "really satisfying sizzling and popping and a reaction ... they should stop moving and react ... then a nice hiss and pop")

- **They stop and writhe:** while the focused beam burns a Bloated or a Squid it can't take a step (the beam holds it still; the wide beam still only slows). It plays a burn clip: the Bloated throws its arms up over its face, wrenches its head away from the light, buckles at the knees and shudders and twists; the Squid rears up off the ground with every arm thrashing and curling. When the beam moves off, it carries on.
- **It sounds like frying:** each frame the beam burns it (`Enemy.burn_tick`):
  - a sizzle: a bright frying hiss dense with tiny spits, overlapped into one long sound;
  - a fat crackle every 0.07–0.3 s, many spitting a few glowing embers;
  - its cry: the Bloated's groan, the Squid's shriek, the Eel's hiss.
  Steam boils off it in soft puffs.
- **A hiss and a pop to finish:** burnt to death, a Bloated vents a long rising hiss of steam as it swells, then bursts with a wet pop (a crack, a bubble falling in pitch, a thump and a splatter) in a billow of steam and embers. A Squid hisses and pops the same way. All of it is synthesised in `Audio` (`sizzle`, `crackle`, `burn_hiss`, `pop`).

## Animation polish: turning on the spot, easier blends, a swinging lantern, hands that grip, wind-ups (owner's request: "animation could be better")

- **Turning on the spot:** a standing keeper, Bloated or Smotherer that turns now steps round instead of spinning on planted feet. Each has a pair of turning clips (`turn_l`, `turn_r`). In them the feet step round under the body, the inside foot first, the hips leading and the head looking into the turn. `CharacterRig` measures how fast the body turns, blends the clip in above about 30°/s, and plays it at the rate that keeps a planted foot still on the ground. The Crab and the Squid shuffle round on their walk. Creatures used to snap to a new heading in one frame; now they come round at a rate set for each: the Crab slowest, the Squid quickest. A blow that spins one round, and getting up, still turn it at once.
- **Easier in and out:** every blend between clips follows an ease-in-out curve instead of a straight line:
  - standing to walking, and into and out of activities (hammering, climbing, burning);
  - crossfades between activities;
  - one-off actions coming in over the body and fading back out.
  Fades are a little longer. Full-body actions (a stagger, a lunge) now ease in from what the body was doing; a get-up still starts at once from where the ragdoll lies.
- **The lantern on its bail:** it hangs from the keeper's left fist on a pendulum (`Pendulum`). It always hangs plumb. It swings back when the keeper sets off, forward when they stop dead, and out on a turn, and the swings die away. Its light swings with it.
- **Hands:** the humanoid skeletons have finger and thumb bones now, so hands close round what they hold. In each clip:
  - a keeper grips the boathook and the lantern's bail; the hand opens as the hook is thrown;
  - a keeper's hands are flat to push up off the ground, half open steadying the work while hammering, and tight on a ladder's rails;
  - the drowned's hands hang half-curled; they clench to club a fence and spread as a Bloated swells;
  - a Smotherer's are hooked like claws, digging into the stone and spreading wide as they reach up the tower.
- **Wind-ups:**
  - **Clubbing strike (Bloated and Smotherer):** each strike now has a readable wind-up. The arms go up, the body rears back and sinks, holds there trembling, then crashes down. The game deals the blow when the clip's arms land (the `hit` time written by `animate.py`), not half way through.
  - **Crab:** rears up at the front, settles back on braced legs and shakes harder through its 1.5 s wind-up, then slams the front of its shell down with the claw and heaves itself level.
  - **Squid:** coils before it lunges. The mantle sinks back and the front arms curl back like springs and tremble, then it throws itself forward and snaps them shut. Its tell is 0.65 s instead of 0.35, so there's time to see it coming and step back.

## The holm, the rope bridge, the split screen and the helpers (owner's request: "more than just enemy attacks ... maintaining your base and survivalism")

The owner asked for more depth: jobs on the island, research, crops and more interesting defences, and a second island beside the lighthouse with an old WW2 internment camp on it. The camp is fully fenced, with a guard tower at each corner and lights and spots that can be angled to burn the enemy. In the middle are living quarters, vegetable fields and a greenhouse. They decided:
- Keepers cross on a rope bridge like Carrick-a-Rede's, and it moves when you walk on it.
- There are always three keepers, with helpers run by the computer if fewer people play.
- Losing the lighthouse ends the run; losing the camp makes the game much harder.
- The screen splits when players go apart, Baldur's Gate style.

This is step 1 of five: the place, the crossing, the camera and the helpers. Next come the camp's searchlights and power, food, warmth and fuel, research and new defences, and creatures that go for the camp.

- **The holm:** a second island 18 m east of the main one (`Terrain.HOLM_*`). It is low (1.4 m) and flat, a rounded box about 30 by 25 m, with ragged low cliffs and two shingle beaches (east and north) for landings later.
  - **Terrain:** one height function still drives everything. `height_at` is the higher of the main island and the holm, both falling to the same sea floor.
  - **Ground mesh:** the holm's mesh is a second grid beside the first. Its border vertices aren't jittered, so the two meet exactly.
  - **Sea:** the shader's shallows and shore foam follow the holm's shoreline as well as the main island's ring.
- **The camp (grey box, `scenes/world/camp.gd`):** a 22 by 17 m compound on the flattened middle of the holm, as an abandoned 1940s camp would stand in the late 1980s:
  - barbed wire on posts with cranked tops, and a gate on the west side facing the bridge;
  - a timber guard tower at each corner, with a braced platform, a hipped tin roof, a ladder and a searchlight on a yoke (dark for now);
  - two corrugated-iron Nissen huts with brick ends: the quarters, and the mess, where research will be done;
  - a brick generator house, three vegetable beds and a glasshouse.

  Keepers can't pass the wire, the huts or the towers' legs.
- **The rope bridge (`scenes/structures/rope_bridge.gd`):** 18 m from clifftop to clifftop, sagging 0.6 m in the middle. Its parts:
  - slats on two deck ropes;
  - a handrope each side, on cords;
  - posts at each end.

  It moves:
  - every footfall kicks its bounce (two up-and-down modes) and, unevenly, its sway, so a keeper crossing sets it swinging;
  - a keeper's weight sinks it where they stand;
  - the wind across the gully leans on it;
  - the deck tips as it swings.

  Its collision is one surface, rebuilt every physics step from where the deck is: the walking surface from a ramp on one clifftop to a ramp on the other, and the rope sides as walls. One surface has no seams for a keeper's flat-bottomed cylinder to catch on (it caught on a row of separate boxes). Keepers on it are carried sideways as it swings. The bridge's ends sit just back from where each clifftop actually falls away, found by walking out along the line between the islands.
- **The camera (`scenes/world/camera_director.gd`):** each island has its own framing, the main island's exactly as before (tested).
  - **Following:** a keeper is framed by the island they're on; crossing the bridge, the view pans from one framing to the other.
  - **Splitting:** when the people playing have views more than 9 m apart, the screen splits. It is a Voronoi split, so up to three ways. The line is square to the way from one group to the other, and each side shows its own island, pulled back a little. As they separate the views slide apart from one shared view, so the split opens without a jump. Together again (under 4 m), they close back into one.
  - **Rendering:** the first view is the main camera, so P1's mouse aims through it as before. The others render into SubViewports sharing the world, laid over it by `shaders/split_screen.gdshader` with a thin dark seam. While the screen is whole nothing extra is drawn. Split, the extra views cost a full scene render each.
  - **Helpers:** helper keepers don't get a view.
- **Helper keepers (`scenes/player/keeper_ai.gd`):** with fewer than three people, the rest are run by the computer, so there are always three keepers. P1, P2 and P3 are people; helpers come after them.
  - **Labels:** helpers are named without a player number, on their tags and in the HUD.
  - **Lighthouse helper:**
    - By day it mends whatever on the main island is broken and can be paid for, refuels the lamp when it's below 70% and gathers from the beaches.
    - At dusk it climbs up and works the lamp if nobody else is on it, aiming like a person would: a new target about once a second, a few degrees off, focusing only once on target.
    - If someone else has the lamp it holds the ledge. It comes out of the lamp room when something is on the tower.
  - **Camp warden:** the last helper starts in the camp. By day it does the rounds of the beds, the greenhouse, the huts and the generator. At night it walks the wire from tower to tower; it gets real work in steps 2 and 3.
  - **Both:**
    - fight anything that comes within 7 m on their own level, backing out of a swelling Bloated's blast;
    - revive a downed keeper (holding Use beside them);
    - fetch their thrown boathook.
  - **Steering:** they move the keeper through the same movement code as a person (`Player.ai_move`, `ai_held`), not by teleporting. They walk `KeeperNav`: the creatures' graph plus the yard round the tower, its door, the two ladders (climbed as a player climbs them), the bridge and the camp.
  - **Getting stuck:** a keeper that stops getting closer to its next waypoint sidesteps, and as a last resort hops onto the waypoint.
  - **Difficulty:** creatures scale with the number of people (`Players.humans()`), not keepers, so solo plays as before, with help. With helpers about, a person who goes down solo no longer ends the run: a helper comes to revive them. Losing every keeper still ends it.
  - **Tests:** the older tests script every keeper themselves, so they turn helpers off.

## The camp's power: the generator, diesel, the searchlights, climbing the towers (step 2)

- **The generator (`scenes/structures/generator.gd`):** a Structure in the brick house, so creatures can damage it later and keepers mend it with scrap and driftwood.
  - **Running:** from dusk to dawn while it has diesel, with its own chugging engine sound (synthesised: a slow single cylinder firing about seven times a second) and exhaust smoke. It burns 0.03 fuel a second idling, plus whatever it powers:
    - each searchlight 0.1 a second wide, 0.2 focused;
    - the huts' lights 0.015 each.

    All four lights sweeping and the huts lit burn about 0.46 a second, so a full tank (100) lasts about 220 s, roughly one night.
  - **Low and dry:** below 15% the lights it powers flicker and dim and a warning comes up. Run dry, the whole camp goes dark.
  - **Saving:** its fuel is saved with the run (`Run.camp_fuel`, 60 to start).
- **Diesel:** a new resource. A jerrycan washes up on each of the holm's two beaches every dawn (with a little driftwood and scrap). One can fills the generator by 35, worked with the oil can like refuelling the lamp. Two cans a day keep about two lights burning all night, not four. Which lights to keep running, and whether to fetch the diesel or do something else, is the camp's daily trade-off.
- **The searchlights (`scenes/systems/searchlight.gd`):** an arc lamp in a drum on each tower's platform.
  - **Unmanned:** it sweeps 120° of the ground outside its corner of the wire, 13 m out, in a wide beam.
  - **Manned:** a keeper who takes it aims it where they like (the mouse's point on the ground, or along the stick) and switches it to a 6° focused beam with Q.
  - **Effect:** it uses the lighthouse lamp's 3D cone test and the creatures' own light reactions, so the wide beam slows what it catches and the focused one burns it.
  - **Feedback:** each light strikes with a buzzing clunk as the generator brings it on. Its glass glows and its beam shows in the fog.
- **Climbing a tower:** each tower has a keepers' ladder up its inward side (the crag ladders' code). The platform has a floor and rails, with a hatch where the ladder comes up.
  - **At the top:** the searchlight is the nearer thing to hand, so E takes it. E or R lets go; Q switches the beam.
  - **Climbing down:** step to the hatch and E climbs down.
  - **Knocked:** a keeper who is knocked about lets go of the light.
- **The huts:** their windows light warm yellow and throw light out of each end while the generator runs, flickering with it when it runs low.
- **The HUD:** shows the camp's generator: its fuel, whether it's running and how many lights, and diesel in store.
- **The camp warden:**
  - **By day:** keeps the generator filled. It fetches the diesel from the holm's beaches, walking a new path round the outside of the wire, and works the can at the generator. It also mends the camp, then does its rounds.
  - **From dusk:** it climbs the tower facing whatever is on the holm or the bridge (or the one over the east beach), takes its light and sweeps. When something comes within range it swings the beam onto it and focuses once it's on target. It moves to a better tower if the danger is elsewhere, and comes down at dawn. If the camp is dark with diesel in store, it gets the generator going first.
- **The holm grew** to 33 by 27 m so there's a 5 m margin round the wire: the towers stand turned to the diagonal and their legs reach 1.5 m out along it, and the path round the outside needs to clear them. A check walks every link of the keepers' map on the holm against the ground and the buildings (all clear), and no link may cross the wire.

## Hunger, warmth and the camp's crops (step 3)

- **Hunger and warmth:** every keeper, people's and helpers alike, has both, from 100 (fed, warm) down to 0. Both show beside each keeper's health on the HUD and are saved with the run.
  - **Hunger** drains 0.18 a second (half as fast again sprinting), about two days and nights from full to empty.
  - **Warmth** drains outdoors at night: 0.12 a second on a clear night, 1.6 times that in squalls, 2.2 times in a storm. It comes back by day (0.25 a second), quickly by a fire (3 a second by a lit campfire or stove, 2 by the cottage door), and slowly up in the lamp room.
  - **Below 25** a keeper is hungry (15% slower) or cold (10% slower, and swings take a quarter longer). A warning comes up for a person's keeper.
  - **At 0** they starve or freeze, losing a point of health every 2.5 s. That can down them; the needs never kill outright.
- **Eating:** a cottage meal now feeds as well as healing and building strength. It's on the menu whenever a keeper is hungry, even at full health. The camp's mess hut has a trestle table where a meal from the store feeds a keeper and heals 30, without the cottage's strength gain, so the lighthouse stays worth coming back to.
- **The quarters' stove:** a driftwood lights it for about four minutes, smoke coming out of the hut's stovepipe, and anyone standing by the hut warms through. It is the camp's way in from the cold, as the cottage's fire and the campfire are the main island's.
- **The camp's crops (`scenes/structures/camp_plot.gd`):** four plots, each saved with the run (`Run.camp_crops`). Each sown plot comes up overnight and is ready at dawn.
  - **Outdoor beds (three):** kale and cabbages, 2 food and a seed back. A storm night flattens a planted bed half the time.
  - **The greenhouse's staging:** tomatoes and beans, 3 food and a seed back, safe from the weather. It is worked from its doorway, the side facing the parade ground.
  - **Seed:** a new resource. Three packets are left in the huts at the start; every harvest gives one back.

  With the cottage's potato beds, a tended homestead and camp grow well over what three keepers eat. The pressure is finding the time to tend both islands and stay fed and warm through a long or stormy night, not a shortage.
- **Helpers look after themselves:**
  - When hungry they go and eat, in the mess on the holm or at the cottage on the main island.
  - When cold they go and warm up, the warden at the stove (lighting it if need be), the lighthouse helper at the campfire. They stay until warm through.
  - Up in the lamp room they stay warm, so the light isn't left for the cold. On a tower they're out in the weather.
  - The warden sows and lifts the camp's plots between filling the generator and fetching diesel. The lighthouse helper lifts the cottage's potatoes and digs kelp in, keeping a little back for mending.
- **The balance bot:** `tools/playtest.gd` feeds and warms its keepers by day, as a player would, so it keeps measuring the nights. In "eco" mode it pays for the meals.

## Research, the internees' notes and the new defences (step 4)

- **The internees' notes:** the camp was a 1940s internment camp, and its internees and guards left papers behind. Two tins of them lie about the camp at the start and another turns up each dawn while fewer than two are lying about (eight spots about the camp, `NOTE_SPOTS`).
  - **Reading:** picking one up gives a page of notes for the research desk and reads out the next page of the diary on screen for 12 s (`scenes/systems/lore.gd`). The eight pages tell what the camp saw, from the internees' arrival in September 1940 to their release in May 1945. Each one also hints at a project.
  - **After the diary:** later finds are loose pages of sums.
  - **Saving:** the count read is saved (`Run.notes_found`), so a continued run carries on the diary where it left off.
- **The research desk (`scenes/structures/research_desk.gd`):** a desk in front of the mess hut, papers spread on it. E opens the list of projects (`scenes/systems/research.gd`).
  - **Cost:** each project costs a page of notes and some of the store.
  - **Timing:** one is worked out at a time and is done by dawn. The dawn report says what was finished.
  - **Saving:** what's done and what's under way are saved.
  - **Why the notes gate it:** the desk is a reason to go and look round the camp by day, and research can't all be bought in the first afternoon.
- **The projects:**
  - **Clockwork tracking:** a searchlight nobody is on finds the nearest creature in its sector within 24 m, follows it and narrows to the focused beam, so it burns it. Without it an unmanned light only sweeps in the wide beam. Even so, a keeper on the light still matters: tracking takes the nearest creature, not the most dangerous one.
  - **Silvered reflectors:** the searchlights reach 5 m further and burn 1.6 times harder.
  - **Generator governor:** the generator burns a third less diesel (×0.67).
  - **Cold frames:** the camp's outdoor beds come through storms, and the greenhouse gives 5 instead of 3.
  - **Tinning:** every harvest, at the camp and the cottage, gives a food more.
  - **Barbed wire, tripwire flares and sandbag walls:** each opens a new defence at the cairns (below).
  - **Alarm bell:** in the list now and does nothing yet. Step 5 makes it ring when anything comes ashore on the holm.
- **New defences, set at the cairns like the traps:**
  - **Barbed wire** (a scrap and a driftwood): anything within 1.4 m crawls at 35% speed and loses 5 health a second. The wire wears only while something is in it and is torn away after 40 s of that. Eels are not caught, as with the other traps.
  - **Tripwire flare** (a scrap and a bio): the first creature to trip it gets a flare fired into it from the stake, aimed where it's going. The flare does its usual 40 damage and burns red.
  - **Sandbag wall** (two driftwood and a seaweed): a wall 2.6 m long and 0.9 m high goes up across the path, with 160 health.
    - **Blocking:** creatures that walk into it stop and batter it, as they do a fence (enemies treat the group `barricades` like fences).
    - **Wear:** it slumps a course at a time, and can be patched with driftwood (60 a time).
    - **When it's down:** the cairn is clear for another defence.
    - **Crabs:** a Crab's slam batters a wall like a building, rather than smashing it at a stroke as it does a trap.
- **Where walls can go:** only across a beach path, at the main island's three beach cairns and the holm's two beach posts.
  - **Elsewhere:** the ledge cairns, the gate post and the bridge-end post are on the keepers' own way, and a wall there would shut them out. A cairn knows the way along its path (`path_dir`); one with none takes no wall.
- **The holm's defence posts:** four cairns of their own, open from the start rather than with the defences upgrade:
  - **One up each of its two beaches.**
  - **One on the track outside the gate.**
  - **One where the bridge comes onto the holm.**

  These are where step 5's raids will come.
- **Tests:** `tests/slice_research.gd` (39 checks):
  - **Notes:** the notes and the diary, and the desk and its costs.
  - **Effects:** what each project does.
  - **Defences:** the posts, a creature crawling and bleeding in the wire, a tripwire's flare, and a creature stopping to batter a wall.
  - **Saving.**

  `slice_economy`'s count of the trap slots the defences upgrade opens leaves out the holm's posts.

## Creatures raid the camp (step 5)

- **Two fronts:** from night 2, every third group of Bloated, Squid or Crabs in the night's table lands on one of the holm's two beaches instead and makes for the camp. From night 5 it's every other group.
  - **Where they come from:** these groups come out of the table, so the main island sees that many fewer and the night is no bigger. Nights 2 and 3 send one group to the holm, night 4 sends two, and nights 5 to 8 send two or three.
  - **What never goes:** Smotherers and the Eel stay with the light.
  - **Co-op:** the same scaling as on the main island.
  - **Once the camp has fallen:** nothing more is sent; it all comes for the light again. Losing the camp never makes the nights easier.
- **The holm's own creature map (`Nav._build_holm`):** up each beach and straight at the nearest stretch of wire (kept clear of the corner towers), then inside to the parade ground and a stop before each building and the generator.
  - **Separate from the main island's:** raiders stay on the holm (`Enemy.camp_raid`). They never try to walk to the light across the sea, and the main island's creatures never wander onto the holm.
  - **The gate:** it's on the map, but going through the wire is shorter from both beaches, so they tear through it.
  - **Dawn:** they go back down to the holm's own beaches.
- **What they make for:** the nearest of the generator, the quarters, the mess hut and the greenhouse still standing (`Camp.targets()`). Crabs and Squid only go after keepers on their own island: a Squid on the holm won't chase a keeper across the water.
- **The wire (`scenes/structures/camp_wire.gd`):** each of the five runs of wire (three whole sides and the two either side of the gate) is a barricade with 120 health. Creatures that walk into it stop and tear at it, under the searchlights.
  - **Torn:** the strands part one by one.
  - **Down:** the gap stands open.
  - **Mending:** a scrap mends 60.
- **The buildings (`scenes/structures/camp_building.gd`):**
  - **Health:** the quarters and the mess have 220 each and the greenhouse 150. The generator keeps its 120 and is now measured to its walls, so creatures can reach it and keepers can mend it from outside.
  - **Mending:** two driftwood mend 60. Scrap is scarce and the wire wants it.
  - **Battered:** they lean and smoke.
  - **Wrecked:** a building sinks to a ruin, and what's in it stops working until it's mended:
    - **The quarters:** the stove goes out and can't be lit.
    - **The mess:** no meals, and the research desk can't be used. A project under way waits, and isn't finished at dawn.
    - **The greenhouse:** its glass goes, what's growing in it is lost at dawn, and nothing can be sown.
    - **The generator:** no power: no searchlights, no hut lights.
  - **A wrecked hut stays dark.**
- **The camp has fallen** when the generator and all three buildings are wrecked. The HUD says so in red, the dawn report says so, and the tip says what to mend.
  - **The run goes on.** As the owner asked, only the lighthouse's destruction ends it.
  - **Why it's hard:** losing the camp loses its searchlights, its warmth, the mess and the research, and its crops. All the while, the nights stay the same size.
- **Alarm bell (research):**
  - **With it:** when a group lands on the holm, the camp's bell rings (made in code, `_s_camp_bell`: four clangs of an iron bell) and a warning says which beach.
  - **Without it:** the lighthouse's foghorn doesn't sound for the holm, and the landing is only noticed if a person's keeper is on the holm. Otherwise the first sign is the searchlights swinging, the HUD's camp line going red, or "The camp's wire is down!".
- **The HUD's camp line:** names anything wrecked, anything under half health, and how many runs of wire are down, in red, so a raid reads from the main island.
- **The warden mends the camp by day:** wire from just inside it, buildings from in front of them, after seeing to the generator. The lighthouse's helper mends only the main island's.
- **The balance bot** (`tools/playtest.gd`) now prints the camp's state each dawn.
  - **Its day:** it fetches the holm's two cans of diesel into the generator and mends the camp with what it has.
  - **By default** its keepers don't go to the holm, so the camp has only its own searchlights.
  - **A fourth argument, `helpers`,** brings in the computer's keepers, the camp's warden among them.
- **Balance, first pass:** with nobody on the holm, the camp at first fell on night 3 to two raids of three Bloated. The bursts by the huts caught both huts at once, and the bot had no scrap to mend them. So the buildings were made tougher (220 / 150) and are mended with driftwood rather than scrap. See the playtest numbers below.
- **Tests:** `tests/slice_camp_raid.gd`:
  - **Setup:** the camp's targets and wire, the holm's map (through the wire, back to sea off the holm), and which groups go for the camp.
  - **A raid:** a Bloated tearing at the wire and then bursting on the generator. A Squid and a Crab on the holm going for the camp, not a keeper over the water.
  - **Wrecking:** what stops working, and the camp falling without ending the run.
  - **Mending:** mending by hand, and the warden mending.
  - **The bell.**
- **Playtest numbers** (`playtest.gd -- 6 bot 1`, after the change):
  - **Nobody on the holm:** the camp takes its first raid on night 2 (quarters and mess at 45%, a run of wire down). It loses the generator and the greenhouse on night 3 and falls on night 6.
  - **With the warden** (`helpers`): the camp comes through nights 2 and 3 untouched. It loses the generator on night 4 and the mess on night 5, but never falls in six nights.
  - **Why it stays battered:** the bot spends its scrap before the generator's turn, so the wreck waits.
  - **The light:** neither run lost the lighthouse.

  So the camp needs someone on it, as asked. Left alone it is lost about a week in, and a warden keeps it alive but not whole.

## The shed's weapons (owner's request: "a flamer from a weed burner ... a poison trap from rat poison ... a homemade longbow from driftwood ... petrol bombs from bio fuel ... a double-barrel shotgun with limited ammo")

- **Where they come from:** the garden shed has a workbench now. E opens it, unless the shed is damaged and can be mended, when the hammer comes first, as at the cottage.
  - **One of each:** the shotgun and the weed burner are single objects. Whoever carries one has it, and anyone else sees "Callum has it". Hung back up, they're in the shed for anyone. Each keeper makes their own longbow.
  - **Where they're kept:** what each keeper carries is saved (`Run.arms`), along with the flamer's tank and the shotgun's loaded barrels.
- **What's in hand (`scenes/player/arsenal.gd`):** the boathook, longbow, shotgun, flamer or petrol bombs, changed with Tab, the mouse wheel or 1 to 5 (P1), [ and ] (P2 on the arrow keys), or the d-pad.
  - **Attack:** works whatever's in hand.
  - **The boathook:** still thrown at a climber on the tower, but only with the hook in hand.
  - **The HUD:** says what each person's keeper holds and its ammunition.
  - **Helpers:** keep to the boathook.
- **The longbow:** 3 driftwood and a kelp cord, and 5 arrows for a driftwood and a scrap.
  - **Using it:** hold attack to draw (0.8 s, walking at half speed), let go to loose. An arrow does 12 damage at a quarter draw and 40 at a full one, and flies 26 m almost flat.
  - **Aiming:** it's aimed at the body of whatever's on the ground under the aim, so it works from the crag top down onto a beach.
  - **Arrows aren't recovered,** to keep it simple.
- **The double-barrelled shotgun:** 9 pellets in a 24° cone out to 11 m, 7 damage each and 1.6 times that inside 3.5 m.
  - **Damage:** each pellet hits the first creature in its line. Two barrels at 3 m kill a Bloated outright.
  - **Reloading:** after both barrels, the keeper breaks it open and loads two from the store (1.6 s). A loud crack and boom, a muzzle flash, smoke, and a shove back.
  - **Limited ammunition, as asked:** there is no way to make cartridges.
    - **The box in the shed:** 10 at the start.
    - **Wash-ups:** a tin of 3 washes up every third dawn from the third, and the dawn report says where.
  - **Crabs** still shrug off pellets from the front, like any blow.
- **The flamer:** rigging the weed burner costs 2 scrap and comes with half a tank. Hold attack for a roaring 5.5 m stream, 17° either side.
  - **Its effect:** whatever's in it stops and writhes (the beam's burn), takes 34 damage a second, and burns on for 2.5 s after (8 a second).
  - **Fuel:** a tank lasts about six seconds. When it runs dry, the keeper pours a bio from the store into it (1.5 s), so it competes with the lamp for bio.
  - **Moving:** the keeper walks at 60% while it's going.
  - **Visible:** the gas bottle shows on the back of whoever carries it.
- **Petrol bombs:** 2 for a bio and a kelp rag. They're thrown to the mouse's point, up to 12 m. On a pad, with no cursor, they go to the nearest creature within 25° of the aim, otherwise 10 m ahead.
  - **The smash:** 20 damage and alight for 4 s within 2.2 m, then a pool of fire 2.3 m across for 7 s. Anything in the pool takes 16 a second and is alight.
  - **Into the sea:** only steam.
- **Rat poison:** 4 tins in the shed, and no more. Bait at a trap cairn costs a tin and a kelp, and does no damage on the spot. It does work on the first three creatures that eat it:
  - **Poisoned:** 14 s of poison, 3.5 a second and 30% slower, about 49 in all.
  - **Squid** skitter over it.
- **Fire and poison over time:** both live on the creatures (`Enemy.on_fire`, `Enemy.poisoned`), so any source can use them. The sea puts fire out.
- **Who gets the kill:** a keeper's blow is now tallied by what it was (`Player.hit_kind`: "shot", "arrow", "flame", "bomb", "poison"), and the dawn report lists each.
- **The Eel:** takes half damage from these weapons (the boathook does a quarter). The beam is still what brings it down.
- **Friendly fire:** none. The flamer, fire pools and shot don't hurt keepers, so co-op and the helpers aren't punished for standing near them.
- **Sounds,** all made in code: the shotgun, the bow's thrum, an arrow striking, the flamer's roaring loop, and glass smashing.
- **Tests:** `tests/slice_arms.gd` (40 checks): the workbench, switching, each weapon doing what it says, the cartridges running out, the poison, the wash-up and the save.

## Difficulty (owner's request: "difficulty modes; in easy mode there's infinite ammo")

- **Three seas,** chosen on the title screen under the keepers (◀ ▶ or click to change). A new run takes the choice; a continued run keeps its own, saved with it (`Run.difficulty`). The HUD's top line names it when it isn't the normal one.

  | | Calm sea (easy) | Angry sea (normal) | Raging sea (hard) |
  |---|---|---|---|
  | Creatures per landing | ×0.7 | as balanced | ×1.35 |
  | Damage to keepers | ×0.6 | ×1 | ×1.3 |
  | Hunger and cold | ×0.6 | ×1 | ×1.25 |
  | Ammunition | never runs out | as it is | 6 cartridges and 2 tins of rat poison to start, not 10 and 4 |

- **Infinite ammunition on a calm sea** covers everything a keeper shoots, throws or burns:
  - the shotgun's barrels never empty, so it never reloads;
  - arrows and petrol bombs are never used up, and bombs are in hand even with none made;
  - the flamer's tank never drops;
  - flares never run out.

  The weapons themselves still have to be made or taken at the shed, so the workbench still matters. Traps and the lamp's fuel are not ammunition and cost as usual.
- **Group sizes are rounded to nearest** (at least 1), not up, so the calm sea's ×0.7 actually removes a creature from small groups. This changes nothing on the normal sea: the co-op ×1.5 only ever leaves halves, which round up either way (`Spawner.group_size`).
- **The tests run on the normal sea.** `slice_arms.gd` checks the three seas' group sizes, the free ammunition, the damage, the hard sea's smaller shed and the save.

## LAN play (owner's request: "local network play so on LAN you don't need split screen")

- **One keeper to each machine, each on a screen of its own.** Up to three machines; the computer's helpers make up three keepers as ever. Title screen → Play on the LAN → Host a game, or Join a game (hosts on the LAN show up by themselves; or type the host's address). The host sees who's in the lobby and starts a new run or continues its save. The host's sea (difficulty) is the game's. Nobody can join a game under way.
- **The host runs the game (`autoload/net.gd`).** Godot's ENet, port 24686 (UDP), with a broadcast on 24687 each second while a lobby is open, so clients can find it. A client:
  - **sends** its keeper's controls 60 times a second: movement, aim, the mouse's point on the ground, and the buttons held. Presses are counted, not flagged, so a lost packet loses no press;
  - **gets snapshots** 30 times a second (unreliable, ordered): every keeper, every creature, the lamp, the searchlights, and the day's clock;
  - **gets the state** 4 times a second (reliable): the run as the save keeps it, so the store, research, crops, flares and what's carried; plus the buildings' health, the trap cairns, what's washed up, the generator and the stove;
  - **gets events** as they happen:
    - sounds and effects (unreliable, batched once a frame);
    - messages, warnings and reports;
    - flares, arrows and petrol bombs in flight;
    - creatures dying (as a corpse there too);
    - the end of the run and a new run.
- **Puppets.** On a client every keeper and creature is a puppet: it eases toward the host's position (it snaps when more than 4 to 5 m out), turns as the host has it, and plays the host's one-off clips and ragdolls (`CharacterRig.shot_seq`).
  - **Puppets can't be hurt and don't act.** The client's spawner, creatures' minds, traps, generator, alarms, saves and dawn are all off.
  - **Some look is still worked out on the client:** its lamp and searchlights light what they fall on, so creatures flinch and smoke there too, but the damage is the host's.
  - **Sound and effects:** the host's sounds and effects are sent over and played there, and the client's own copies are held back so nothing plays twice. The sea, the weather and the interface make their own on each machine.
- **Menus across machines.** A client's keeper at the cottage, the shed, a cairn or the research desk opens a menu run on the host and shown on the client. A pick goes back to the host, and the rows come back refreshed.
  - **Shared menus:** a menu open on another machine doesn't stop the host using a menu of its own.
  - **The keeper stands still** while it's open, as on one screen.
- **Leaving:**
  - **A client leaves:** its keeper carries on, run by the computer: the camp's warden if nobody keeps the camp, otherwise a lighthouse helper.
  - **The host leaves:** everyone else is put back on the title screen, which says why.
  - **Game over:** only the host can start the next run, and everyone's game reloads into it together.
- **On the LAN:**
  - **Pause:** it shows the menu but stops nothing, since the night goes on for everyone else.
  - **Skipping the day:** only the host can.
- **Ink and the thrown boathook** are sent as shots: the client draws the Squid's cloud, and a boathook that flies at the climber, drops at the tower's foot and lies there until the host says its keeper has it back. Neither does anything on the client; which creatures the ink hides already comes over with each creature.
- **Tests:** `tests/run_lan.sh` runs a host and a client as two Godot processes on this machine (`GODOT=... tests/run_lan.sh`). They step along together:
  - **Joining:** the lobby, and the keeper slots.
  - **Moving:** the client's keeper walking on both machines.
  - **What the client sees:** the host's creature, the battered fence, the store, dusk and the lamp, the message, and effects and sounds arriving.
  - **The shed's menu:** opened on the client, run on the host; the shotgun taken.
  - **Firing:** the client's shot hitting the host's Bloated.
  - **Ink and the boathook:** a Squid's cloud and the host's thrown boathook showing on the client, and the boathook going when it's picked up.
  - **The run's end:** on both machines.
  - **Afterwards:** a New Run for everyone, and the client leaving with its keeper handed to the computer.

## The holm reshaped (owner's request: "take time and care to shape the new island to be more realistic")

- **A real islet's outline, not a rounded box.** `Terrain.holm_edge_dist` warps the box with two scales of noise so the shore wanders, cuts a cove at each of the two beaches, and blends (`_smin`) round the camp so there is never sea within 5 m of the wire (`HOLM_DRY`).
- **Its height** (`Terrain._holm_height`): turf knolls on the open ground, bare sandstone outcrops, a stepped cliff, and a wave-cut shelf just above the sea at the cliff's foot. The colours follow: sandstone and its darker beds on the cliffs, lichen, wrack on the shelf, heather on the knolls; `is_grassy` keeps grass off the rock.
- **The sea knows the new shore.** The foam band used to follow a rounded box; now `Terrain.holm_shore_texture()` bakes the real waterline into a distance texture (half-metre cells) that `sea.gdshader` reads, so surf breaks where the rock actually is.
- **Rocks in the water** (`main._build_holm_rocks`): skerries off the points, a sea stack to the south-west, boulders on the shelf; never on a landing, where creatures come ashore.

## The camp textured and dressed (owner's request: "texture the camp well to match the theme")

- **A Second World War internment camp left to the North Sea weather.** New tiling textures, generated like the rest by `art/source/textures/build_textures.py` (`camp` builds just these): corrugated iron, concrete, brick, roofing felt, rust, weathered timber and hessian. `Look.camp()` makes the material.
- **The buildings:** Nissen huts in corrugated iron (laid in world space, so the ribs line up across a hut) on concrete bases with steps and porches; felted tower roofs on timber posts; the generator in a brick and concrete house with a corrugated roof, a rusted door, a vent and an exhaust.
- **The dressing** (`Camp._dress`): paths and duckboards between the huts, a flagpole whose flag flies with the wind (`Weather.wind_now`), the "No. 7 CAMP / AUTHORISED PERSONS ONLY" sign, a water tank, oil drums, sandbags, a coal bunker and a washing line.
- **The dressing doesn't get in the way of a fight:** its collision is on layer 1 only, so keepers walk round it and creatures don't snag on it.

## Survive until rescued: the end of Chapter One (owner's request: "a survive until rescued mechanic, then they head off in a boat and it's set up for the next chapter")

- **How long:** the boat comes at the dawn after night 8 on a calm sea, 10 on an angry one and 12 on a raging one (`Rescue.NIGHTS`). Long enough for the camp, research and raids to come into it, short enough to finish in a few evenings. The HUD's phase line counts down ("boat in 3 nights"), the dawn report says so, and dusk on the last night warns that the sea will throw everything.
- **The last night** sends 30% more in each landing (`LAST_NIGHT_SURGE`).
- **A reason to mend the wireless:** a research project ("The camp's wireless": 3 scrap, a bio, a page of notes) calls the boat two nights sooner.
- **The boat** is the *Mary Ann*, a Kirkhaven fishing boat: built in code with a hull, bulwarks, rubbing strakes, tyre fenders, a wheelhouse, funnel, mast lights and fish boxes. She steams in over 14 seconds and lies off a beach with a plank to the shore. The day doesn't advance while she waits.
- **Going aboard:** each person's keeper walks down and presses E at her plank (the prompt wins over anything else nearby); helpers drop everything and make their own way. When everyone's aboard she sails, with the camera following her out. She waits for every person; a helper that hasn't found its way down in 150 seconds is taken aboard anyway, so a stuck helper can't hold everyone up.
- **The chapter's end:** a card, "Chapter One: The Light Held", with the nights held, the sea and the creatures killed, and a few lines setting up Chapter Two, The Harbour (Kirkhaven's lights have gone out). Then **back to the title**, or **stay on the rock**: an endless run with no boat (`Run.endless`), kept with the save. The profile remembers the chapter was finished, and on which sea, and the title says so.
- **On the LAN** the boat, boarding and the card happen on every machine; only the host chooses what happens next.
- **Tests:** `slice_rescue.gd`.

## The first days' jobs (owner's request: "a first-day tutorial job list", from the list of what the game still needed)

- **A checklist, not a tutorial that stops play.** Down the right of the screen for the first three days: gather, mend, eat, cross the bridge, fill the generator, take a weapon from the shed, sow a bed, work the lamp at dusk. Each ticks off when a person's keeper does it (a helper doing it doesn't count), and the list goes once they're all done or after night 3.
- **How it knows:** the game says what a keeper did through `Events.did(what, keeper)` from the scavenge points, repairs, meals, the generator, the beds and the lamp; crossing the bridge and having a weapon are checked as they happen. The ticks are kept with the save (`Run.jobs`).
- **Keys in the list follow the settings:** the jobs name keys as `[E]`, which the HUD swaps for the key actually set, or the pad's button.
- **Tests:** `slice_jobs.gd`.

## Settings, and a pad for keeper one (from the list of what the game still needed)

- **One settings screen** from the title and the pause menu (`scenes/ui/settings_menu.gd`, kept by `autoload/settings.gd` in `user://settings.cfg`):
  - **Sound:** the master volume, the music and the sounds (the audio buses), 0 to 100%.
  - **Display:** full screen or a window, the window's size (1280×720 to 2560×1440), the graphics and the render scale.
  - **Graphics:** Low turns off ambient occlusion and water reflections, halves the sun's shadow map and makes the fog cheaper; Medium keeps the ambient occlusion; High is everything. The fog stays on at every level, since the beam in the fog is the game's look. The render scale (50% to 100%) draws the world smaller and sharpens it back up with FSR, for slow machines.
  - **Keys:** each of keeper one's controls can go on any key or mouse button. Putting one on a key another uses swaps them, so nothing is ever left without a key. The number keys (the weapons) and Esc stay as they are. The wheel stays on the weapons alongside whatever key is chosen.
- **The interface scales with the window** (`canvas_items` stretch from the 1600×900 it was laid out for), so the menus fit at 1280×720 and aren't tiny at 1440p. The title's menu was tightened to fit with every line showing.
- **The game's text names the real keys.** Prompts, messages, reports and the jobs are written with the default keys in brackets (`[E] Repair`); `Settings.keys_in` swaps in the key keeper one has set, the arrow-key layout's, or a pad's button.
- **A pad for keeper one** when only one person plays on the machine: alone, or on the LAN (where every machine has one person). The same layout as keepers two and three, on any pad. The right stick aims while it's being used; moving the mouse goes back to the mouse. In local co-op the pads stay with keepers two and three.
- **Tests:** `slice_settings.gd`.

## The helpers use the shed's weapons (from the list of what the game still needed)

- **The lighthouse's helper takes the shotgun** off the wall by day when nobody has it and there are more than 2 cartridges in the box. It fires at whatever comes within 6 m. A person who wants it takes it back at the workbench ("Take the shotgun back from Hamish"), and the helper won't take it from a person.
- **Longbows for helpers** are made at the workbench for the usual 3 driftwood and a kelp, once the person has their own. A helper shoots what's past the boathook's reach (out to its 7 m fighting range), drawing to about 80% before it looses.
- **Not the flamer or the petrol bombs:** they set fire to what's near the target, the helpers' fights are close to the keepers, and the flamer drinks the bio everyone needs. They stay the people's.
- **Ammunition is the store's,** the same as anyone's: a helper with the shotgun spends the cartridges.
- **Tests:** `slice_helpers.gd`.

## A Windows build

- **An export preset for Windows** next to Linux (`export_presets.cfg`): `--export-release "Windows" build/windows/SeaTheyAreAngry.exe`, the program and its `.pck` side by side. It needs Godot 4.3's `windows_release_x86_64.exe` template installed. The program's icon and version details are left as Godot's (that needs `rcedit`).


## Gull Rock, the rowing boat, the eggs and the gulls (owner's request: "a third small island you can take a rowing boat out to, and collect gull eggs, and flocks of seagulls; they aren't there at night or during storms")

- **Gull Rock** (`Terrain.ISLET_*`, `_islet_height`): a small stack of grey whinstone about 14 by 9 m, 45 m north-east of the lighthouse, in the open sea past the channel between the main island and the holm. It sits at the top edge of the main view, so it's seen before it's visited. Its ledged cliffs stand straight out of the sea on the far side, and it has a turf knoll at its north-west end. Its colours are those of a real gull colony: rich green turf, thrift in pink cushions, orange Xanthoria lichen on the rock tops, and white guano streaking down from the ledges. A slip of flat rock runs down into the water on the side facing the lighthouse; that's the landing. Its ground is a mesh of its own beside the main island's square, and the sea's foam follows its baked shoreline as it does the holm's.
- **Out of the creatures' way:** nothing lands there, and nothing on the other islands goes for a keeper out there (`Enemy.same_island` now tells the three islands apart). Helpers never go: they don't row, and a keeper downed out there gets up at dawn like everyone else.
- **The rowing boat** (`scenes/world/rowing_boat.gd`): a clinker-built, double-ended yoal of the Northern Isles kind, made in code: lapped strakes, a teal sheer strake, a red rubbing strake, three thwarts, thole pins and two oars. It lies alongside the jetty on the east beach, where a boat used to sit as decoration.
  - **[E] at the jetty's foot** puts that keeper at the oars, facing the stern. For a moment anyone else can press [E] to climb in too, up to three. It rows itself along the channel, under the keepers' camera, the oars sweeping through a real stroke (blades buried on the drive, lifted and feathered on the recovery) and the rower leaning in and pulling back. It lands everyone at the foot of the slip, about 12 seconds later.
  - **Only by day, and not in a storm**, does it row out. Rowing back is always allowed, so nobody can be stranded. The game warns at dusk if a keeper is still out there.
  - **It runs on a line**, made fast to the jetty's end post and to an iron ring on the rock, so from either end a keeper can haul the empty boat across to them.
  - **Dry inside:** the sea is one sheet and the boat sits down in it, so the sea shader leaves out its own surface inside the hull's outline at the waterline (`boat_at`, `boat_half`). The keeper's boathook and weapons are put away while seated.
  - **Keepers in the boat** are seated by code layers on the rig (no new clips), can't be hurt, and the camera slides from the main island's framing to Gull Rock's as it crosses. Gull Rock's framing comes in closer, since it's small.
- **The eggs** (`scenes/world/gull_nest.gd`): six nests on the top, scrapes lined with dry grass. Each has 0 to 3 olive-brown, blotched eggs, laid fresh each dawn: about 8 a day. [E] takes them into the store (Gull eggs on the HUD), and the cottage boils 3 into a meal (+1 food). It's a day's errand for food that doesn't need the garden. Taking them sends the colony up to mob the keeper: wheeling, swooping and screaming. It's only a fright; they do no harm.
- **The gulls** (`scenes/world/gull.gd`, `gull_flocks.gd`): 37 herring gulls with white heads and bodies, pale grey backs, black wingtips with white mirrors, yellow bills with the red spot, and pink legs.
  - **Who they are:** a colony of 14 on Gull Rock's ledges and nests, 5 loafers on the beaches, and three flocks of 6 wheeling over the main island, the holm and the channel.
  - **Flying:** they soar with their wings in the gull's shallow M, flap when they climb or slow, and bank into their turns.
  - **Standing:** they face into the wind with their black primaries crossed over their tails, turning about, giving the long call, and stretching their wings.
  - **Keepers put them up:** a keeper who comes close sends them up calling, to circle and land again somewhere quieter.
  - **When they're about:** at dusk they fly off out to sea, and they don't come back until dawn, and only once the storm level is below the boat's limit too (`Weather.storm_now`). A stormy dawn keeps them away.
  - **Calls:** made in code, as the other sounds are: the mew, the laughing long call, the alarm. Played on three voices of their own so they never crowd out the game's sounds.
  - **On the LAN** they're cosmetic, each machine's own like the weather. The boat (in the snapshots) and the eggs (in the state) are the host's, and a client's colony mobs when the host says a nest was robbed.
- **Tests:** `slice_islet.gd`.

## The wind turbine and the lights round the camp (owner's request: "a 1980s style wind generator on the other island with the huts; lights strung around the compound; if the wind turbine gets attacked they go out")

- **The machine** (`scenes/structures/wind_turbine.gd`): an early-1980s Danish-style turbine, put up on the holm long after the camp's war.
  - **What it looks like:** three blades upwind of a 9 m galvanised lattice tower, with a cream glass-fibre nacelle that turns to face the wind. The rotor speeds up with the wind, from a slow turn in a breeze to fast in a gale.
  - **Where it stands:** on the north-west knoll outside the wire, clear of the keepers' path round the outside, and in sight of the north beach where creatures come ashore. Inside the wire there wasn't room among the huts, beds and walkways, and outside is where such a machine would stand. Its cable runs on two poles to the north fence.
- **The lights:** strings of warm bulbs sagging from post to post round the inside of the wire, about 56 bulbs, with a real light at every fifth. They're on from dusk to dawn while the turbine stands; there are batteries in the cabinet, so it doesn't matter how hard the wind blows.
- **"If it gets attacked they go out":**
  - **Every blow** makes the whole string blink out for a moment.
  - **Below half health** the turbine smokes, its rotor wobbles, and the lights stutter and dip.
  - **Wrecked**, they're out. The rotor runs down and stops, one blade gone and another hanging, and the keepers are warned.
  - **Mending:** keepers mend it at the cabinet with scrap (2 a time), and the lights come back with it.
- **Why the lights matter:** creatures inside the lit wire move 15% slower (they hate the light, as everywhere in the game). That's one more reason to keep the turbine standing.
- **For raiders it's a target** like the generator and the buildings (`Camp.targets()`). Losing it doesn't count toward the camp falling, though: it only lights the wire (`Camp.fallen()` checks the generator and buildings).
- **On the LAN:** its health is the host's like any building's. Each machine works out the lights and the rotor from that, so a blow blinks the lights everywhere.
- **Tests:** `slice_turbine.gd`.
