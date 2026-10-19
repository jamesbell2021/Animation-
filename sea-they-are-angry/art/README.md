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

How the script works:

- **Bodies** come from a joint graph through Blender's skin modifier, with a radius per joint and subdivision. The same joints place the armature's bones, so the skeleton always fits.
- **Heads** are sculpted in code from a dense sphere: the jaw narrows to a chin, with a brow ridge, sunken eye sockets, cheekbones, and (for the drowned) hollow cheeks. Noses, eyelids, ears, brows, beards (a mass plus hanging clumps), hair and hats are added on top.
- **Clothing** is painted by body region (jumper, trousers, boots, skin), with extra geometry for hems, cuffs, collars, belts, pockets, coat skirts that follow the thighs, boots and soles.
- **Weights:** bodies get automatic weights; rigid parts are bound to one bone.
- **Materials** are procedural: two-colour noise with a knit, cable, weave, rib or stripe pattern. Curvature lightens raised edges and darkens creases, the way a hand-painted texture does, and a vertical grade lightens toward the head. Each character is baked with ambient occlusion into one 1024² texture, so it draws with a single material.
- **Coordinates:** Z up, facing -Y, left is +X (bones named `.L`). Godot sees +Y up, facing +Z; `CharacterRig` turns the model round to face -Z.

The game animates the bones in code (`CharacterRig.pose()` takes rotations about the model's own axes) and turns them into physics for ragdolls on demand. There are no baked animations.

## Older drop-ins

- `characters/all_four_keepers.glb`: the original four keepers in a lineup, from before the Blender rebuild. Not used by the game.
- `props/boat_hook.glb`: the boathook, Z-up, vertex-coloured; `Player.load_art()` stands it up.
- `environment/island_environment.glb`: a whole-island blockout (31 × 22 m) from early on, not used; the game's island is built in code by `scenes/util/terrain.gd`.
- `source/setup_blender_scene.py`, `source/stylized_character_material.py`, `source/ISLAND_README.txt`: notes and scripts from the first art drop.
