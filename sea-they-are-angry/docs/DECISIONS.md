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
