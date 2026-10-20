# Art

## Characters (rigged, in the game)

Every character is built by one Blender script, `source/characters/build_characters.py`, and loaded by `scenes/util/character_rig.gd`:

```
blender -b -P art/source/characters/build_characters.py -- art/characters            # all of them
blender -b -P art/source/characters/build_characters.py -- art/characters crab squid # just these
blender -b -P art/source/characters/build_characters.py -- /tmp/out callum_keeper --preview  # with renders
```

Blender 4.2 LTS. A full rebuild takes about two minutes on a CPU. After rebuilding, re-import in Godot (`godot --headless --editor --quit --path sea-they-are-angry`).

| File | What it is | Rig |
|---|---|---|
| characters/callum_keeper.glb | Callum MacLeod, principal keeper: navy cable gansey, red watch cap, grey beard | humanoid |
| characters/hamish_keeper.glb | Hamish Fraser, engineer: boiler suit, rolled sleeves, flat cap | humanoid |
| characters/mairi_keeper.glb | Mairi Campbell, gardener and runner: waxed jacket, auburn braid, cords, wellies | humanoid |
| characters/ewan_keeper.glb | Ewan Reid, frontline: yellow oilskin coat and sou'wester | humanoid |
| characters/bloated.glb | The Bloated Dead | humanoid |
| characters/smotherer.glb | The Smotherer | humanoid |
| characters/crab.glb | The Armoured Crab | body, 6 two-part legs, 2 claws |
| characters/squid.glb | The Wall-Crawling Squid | mantle, 6 three-part arms |
| characters/eel_head.glb | The Constrictor Eel's head (the body is a tube drawn in code) | none |
| characters/*.json | Points the game needs (eyes, mouth), in the game's model space | |
| characters/*.anims.json | The clips in each GLB: length, loop, and for walks the real period and speed; where a get-up starts | |

How the script works:

- **Bodies** come from a joint graph through Blender's skin modifier, with a radius per joint and subdivision. The same joints place the armature's bones, so the skeleton always fits.
- **Heads** are sculpted in code from a dense sphere: the jaw narrows to a chin, with a brow ridge, sunken eye sockets, cheekbones, and (for the drowned) hollow cheeks. Noses, eyelids, ears, brows, beards (a mass plus hanging clumps), hair and hats are added on top.
- **Clothing** is painted by body region (jumper, trousers, boots, skin), with extra geometry for hems, cuffs, collars, belts, pockets, coat skirts that follow the thighs, boots and soles.
- **Weights:** bodies get automatic weights; rigid parts are bound to one bone.
- **Materials** are procedural: two-colour noise with a knit, cable, weave, rib or stripe pattern. Curvature lightens raised edges and darkens creases, the way a hand-painted texture does, and a vertical grade lightens toward the head. Each character is baked with ambient occlusion into one 1024² texture, so it draws with a single material.
- **Coordinates:** Z up, facing -Y, left is +X (bones named `.L`). Godot sees +Y up, facing +Z; `CharacterRig` turns the model round to face -Z.

## Animation

`source/characters/animate.py` authors every clip in code and the build bakes them into the GLBs, solved on each character's own skeleton. It is a port of Forged in Formation's crouch solver: every frame is solved and keyed, and feet and planted hands are placed by two-bone IK, so contacts don't slide.

- Distances are in leg lengths, so steps fit each body.
- Walk, run and sprint are one-second cycles in step; their real period and speed go in the `.anims.json`.
- `CharacterRig` plays the clips through an AnimationTree:
  - `locomote(speed)` picks and paces the walk, run or sprint.
  - `activity(name)` holds a looped or one-time action.
  - `shot(name)` plays a one-off: upper body for swings and flinches, the whole body for get-ups and lunges.
  - `layer(bone, euler)` adds code on top.
  - A ragdoll gets up with `getup_plan()` and `get_up(time, clip)`.
- The build prints any clip where a limb can't reach its target ("overreaches"). A few centimetres is fine.

To change a clip, edit its pose function in `animate.py` and rebuild the character.

## Surface textures

`source/textures/build_textures.py` (plain Python with numpy and Pillow) generates every tiling surface texture into `textures/`: a colour map and a normal map each, all seamless.

```
python3 art/source/textures/build_textures.py art/textures
```

| Texture | What it is | Metres per tile |
|---|---|---|
| grass | meadow turf, clumps and blades | 2 |
| dirt | worn earth with pebbles | 2 |
| shingle | rounded beach pebbles in sand | 1.5 |
| rock | cliff rock: bedding, cracks, lichen | 4 |
| slate | roof slates in courses, lips down the slope | 1 (5 courses) |
| harl | whitewashed roughcast render | 1.2 |
| rubble | rubble stonework in lime mortar | 1.3 to 1.5 |
| planks | weathered boards | 0.6 to 0.9 |

How they're made:
- Heights come from periodic noise (filtered white noise) and wrapped Voronoi cells.
- The normal maps are taken from those heights (OpenGL style, as Godot expects).
- The colour maps are painted from the same cells, so the paint and the relief agree.
- `textures/terrain.json` records the ground layers' mean colours, which the terrain shader divides by.

How the game uses them:
- **The ground:** `shaders/terrain.gdshader` blends grass, dirt, shingle and rock by weights stored in the terrain mesh (`Terrain.layers_at`). The colour comes from the painted vertex colours, and the detail and relief from the textures. Rock is projected from three sides so the cliffs don't smear.
- **Buildings and props:** `Look.textured(kind, tint, tile)` projects a texture from three sides in the object's own space, so boxes and cylinders built in code need no UVs. `Look.wood()` and `Look.stone()` wrap it for a painted colour.

## Older drop-ins

- `characters/all_four_keepers.glb`: the original four keepers in a lineup, from before the Blender rebuild. Not used by the game.
- `props/boat_hook.glb`: the boathook, Z-up, vertex-coloured; `Player.load_art()` stands it up.
- `environment/island_environment.glb`: a whole-island blockout (31 × 22 m) from early on, not used; the game's island is built in code by `scenes/util/terrain.gd`.
- `source/setup_blender_scene.py`, `source/stylized_character_material.py`, `source/ISLAND_README.txt`: notes and scripts from the first art drop.
