# Art direction

The chosen look is the one in `docs/concept/keepers_reference_sheet.png`: stylised low-poly, faceted clothing folds, hand-painted colour, chunky boots and heavy coats, lit by a cold blue night with a warm lighthouse beam. The project owner picked this over the earlier blockout style ("this style is way better").

![Keeper reference sheet](concept/keepers_reference_sheet.png)

## Target: a Valheim-style island

| Grey box | Day | Night, wide beam |
|---|---|---|
| ![grey box](screenshots/greybox_day.png) | ![day](screenshots/day.png) | ![night](screenshots/night.png) |

| Night, focused beam | Callum and a Bloated up close |
|---|---|
| ![focused](screenshots/night_focused.png) | ![close-up](screenshots/keeper_closeup.png) |

| Title screen | Three keepers by day |
|---|---|
| ![title](screenshots/title.png) | ![co-op day](screenshots/coop_day.png) |

| Three keepers at night with lanterns | Burst, splash and palisade up close |
|---|---|
| ![co-op night](screenshots/coop_night_lanterns.png) | ![effects](screenshots/effects_closeup.png) |

| Night: fog walls round the rock | Dusk: the fog rolling in |
|---|---|
| ![night fog](screenshots/night_fog.png) | ![dusk fog](screenshots/dusk_fog.png) |

| The homestead by day | The homestead at night |
|---|---|
| ![homestead](screenshots/homestead_day.png) | ![homestead at night](screenshots/homestead_night.png) |

The crag and its ledge path (Bad North layout; the shots above are of the earlier, smaller island):

| The island by day | Night: the focused beam on the east beach |
|---|---|
| ![crag day](screenshots/crag_day.png) | ![crag night](screenshots/crag_night.png) |

| A Bloated climbing the ledge; the keepers' ladder on the right |
|---|
| ![ledge](screenshots/crag_ledge.png) |

The creatures and the hammer:

| The Eel coiled round the tower, its head in the focused beam | The Eel's surge up the east beach |
|---|---|
| ![eel](screenshots/creature_eel.png) | ![eel surge](screenshots/creature_eel_surge.png) |

| The Crab winding up at the cottage | A Squid on the crag's edge | Mending a fence |
|---|---|---|
| ![crab](screenshots/creature_crab.png) | ![squid](screenshots/creature_squid.png) | ![hammer](screenshots/keeper_hammer.png) |

| Smotherers: one climbing, one wrapped over the lantern |
|---|
| ![smotherer](screenshots/creature_smotherer.png) |

| Night storm: rain, breakers, glowing eyes | A lightning flash shows the watchers in the surf |
|---|---|
| ![storm](screenshots/storm_night.png) | ![flash](screenshots/storm_flash.png) |

| The four keepers, built in Blender | Their faces |
|---|---|
| ![keepers](screenshots/characters_keepers.png) | ![heads](screenshots/characters_heads.png) |

| The Bloated, the Smotherer and the Eel's head | The Crab and the Squid |
|---|---|
| ![drowned](screenshots/characters_drowned.png) | ![crab and squid](screenshots/characters_crab_squid.png) |

| The keepers in the game | The creatures at the homestead on a clear night | The Eel coiled on the tower |
|---|---|---|
| ![in game](screenshots/characters_keepers_ingame.png) | ![creatures](screenshots/characters_creatures_night.png) | ![eel](screenshots/characters_eel_coil.png) |

| Knocked flat and back up: walk, swing, knocked, down, getting up, up |
|---|
| ![ragdoll](screenshots/ragdoll_keeper.png) |

| Walk, run and sprint (one row each), played by the game's rig: feet planted, heel to toe |
|---|
| ![gaits](screenshots/anim_walk_run_sprint.png) |

| The Bloated's shamble, the Smotherer's creep, the Crab's tripod walk, the Squid's crawl |
|---|
| ![creature gaits](screenshots/anim_creatures.png) |

| Getting up for real: from the ragdoll into the clip, onto the elbows, sit, rock forward, stand |
|---|
| ![get up](screenshots/anim_getup.png) |

| Clear, squalls and storm: each night's weather is rolled at dusk |
|---|
| ![weather](screenshots/weather_nights.png) |

| The homestead: potato beds, campfire, a trap on the ledge | The lighthouse at upgrade level 3 |
|---|---|
| ![homestead](screenshots/eco_homestead.png) | ![upgraded](screenshots/eco_lighthouse.png) |

| The cottage menu | A flare burning on the north beach |
|---|---|
| ![menu](screenshots/eco_menu.png) | ![flare](screenshots/eco_flare.png) |

Regenerate with `tools/screenshot.gd`.

The owner's brief is "a Valheim look". In practice that means simple, faceted low-poly shapes with flat colour, carried by modern, moody lighting. It is the lighting and atmosphere that make Valheim read as beautiful, not texture detail. The checklist the game now follows:

| Valheim trait | How this game does it |
|---|---|
| Chunky faceted terrain | `scenes/util/terrain.gd`: a meadow on sheer cliffs, shingle beaches, the lighthouse on a crag with a ledge path winding up it; a jittered grid, flat-shaded, one painted colour per triangle |
| A lived-in homestead | Whitewashed cottage with slate roof and glowing windows, a stone store shed, a drystone-walled garden, gravel paths |
| Dense grass swaying in the wind | `shaders/grass.gdshader`: 4,200 vertex-coloured tufts in a MultiMesh, gusting wind, up-facing normals so the field shades softly |
| Living water | `shaders/sea.gdshader`: layered swells, shallow-to-deep colour, a breathing foam line at the shore, sparse whitecaps |
| Volumetric fog and god rays | Forward+ volumetric fog per phase; the lamp's spot light scatters in it, plus a soft additive beam mesh (`shaders/beam.gdshader`) |
| Warm light against cold dark | Night is moonlit blue; the lantern glazing, the beam and the bio clusters are the warm and cyan accents |
| Filmic grade | ACES tonemapping, screen-blend bloom, SSAO, slight contrast lift |
| Rugged props | Faceted rocks with moss on top (`Look.rock`), sea stacks, bleached driftwood, rusty scrap, weathered leaning fence posts |

Weather and real character models are in (see DECISIONS). Still to do for the full look: foliage variety (heather, thrift, kelp on the shingle), a sky that shows at the horizon, and pushing the character script further (cloth folds, more facial detail).

## The four keepers

| Keeper | Role | Read at a glance | Signature prop |
|---|---|---|---|
| Callum MacLeod | Lamp keeper | Navy peacoat, grey beard, knit cap | Brass key |
| Hamish Fraser | Engineer | Olive wax jacket, red beard, steel-toe boots | Hammer |
| Mairi Campbell | Gardener and runner | Green jumper, auburn braid, canvas satchel, green wellingtons | Satchel |
| Ewan Reid | Frontline | Navy smock, orange life-jacket straps, fisherman's jumper | Boathook |

In-game scale is about 2.0 m. The four map naturally onto player slots P1 to P4, and their roles echo the systems they lean on: the lamp, repairs, the garden, and the boathook. The design rules out classes, so these stay cosmetic unless that decision changes.

Tagline from the sheet: **Four souls. One island. No escape.**

## Rendering the look in Godot

The Blender material in `art/source/stylized_character_material.py` is a hard two-step ramp: a cool shadow tint (0.2, 0.2, 0.25) below 0.35 and a pale light tint (0.9, 0.9, 0.95) above 0.65, output as emission. A Godot equivalent is a small spatial shader whose `light()` function quantises `dot(NORMAL, LIGHT)` into two or three bands, tinted cool in shadow, multiplied by vertex colour. Keep the warm lamp light as a separate, unquantised term so the beam still reads as the brightest thing on screen.

## Prompt template for more concept sheets

> A concept art character reference sheet featuring a full-body turnaround (front, side, back views) of a rugged [Profession/Role, e.g., Mountain Ranger / Lighthouse Keeper] in a stylized low-poly video game aesthetic. Faceted geometric clothing folds, hand-painted painterly textures, chunky boots, and heavy outerwear. Detailed close-ups of equipment props like [Prop 1] and [Prop 2]. Cinematic dramatic lighting, concept art style for an Unreal Engine adventure game, blue-grey atmospheric background with scale grid.

Use the same template for the creatures (Bloated Dead, Wall-Crawling Squid, Armoured Crab, Giant Constrictor Eel) so they sit in the same world as the keepers.

| Textured and smooth-shaded: the island by day |
|---|
| ![island](screenshots/textures_island.png) |

| Close up: the cottage, its slate roof and rubble chimney, a cliff, the shingle, the lighthouse plinth, the shed |
|---|
| ![close](screenshots/textures_close.png) |
