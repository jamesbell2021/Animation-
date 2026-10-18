# Art drop-ins (not wired into the game yet)

These are the first real models. The vertical slice still draws everything from primitives in code. Wiring these in is Phase F of `docs/prompts/02_first_release_phases_A-G.md`.

| File | What it is | Triangles | Size (metres) |
|---|---|---|---|
| characters/callum_keeper.glb | Callum MacLeod, lamp keeper | 1,748 | 1.0 wide, 2.06 tall |
| characters/hamish_keeper.glb | Hamish Fraser, engineer | 1,660 | 1.0 wide, 2.04 tall |
| characters/mairi_keeper.glb | Mairi Campbell, gardener and runner | 2,004 | 1.0 wide, 2.02 tall |
| characters/ewan_keeper.glb | Ewan Reid, frontline | 1,648 | 1.1 wide, 2.05 tall |
| characters/all_four_keepers.glb | All four in a lineup, for reference renders | 7,060 | 5.4 wide |
| props/boat_hook.glb | Boathook | 96 | 1.21 long |
| environment/island_environment.glb | Whole island blockout: cliffs, lighthouse, three buildings, garden, dock, rowboat, props | 12,192 | 31 × 22, lighthouse 9.2 tall |

## Facts to know before importing

- **Z is up.** All files were exported by trimesh with height along +Z, not glTF's +Y. In Godot they will lie on their backs. Rotate the imported root −90° about X, either in the import settings or in code when instancing.
- **Origin.** Keepers stand with their feet at the origin. The island origin is near its centre at sea level.
- **Colour.** Keepers and the boathook have no materials, only vertex colours (`COLOR_0`). Give them a `StandardMaterial3D` with `vertex_color_use_as_albedo = true`. The island has 15 simple PBR base-colour materials.
- **No normals.** Godot will generate flat normals, which suits the faceted low-poly look.
- **No rig, no animation.** The animation contract in Phase F (idle, walk, swing, downed and so on) will no-op until rigged versions arrive.
- **Budgets.** Every keeper is under the 3k-triangle creature budget. The island is one assembled scene, so the gameplay rock (14 m radius, fences on a 9 m ring) and this model (31 × 22 m with its own lighthouse, buildings and garden) need reconciling before it replaces the primitive island.

## Source files

- `source/setup_blender_scene.py` builds a Blender lineup scene from the keeper GLBs (see `source/BLENDER_README.txt`).
- `source/stylized_character_material.py` is the two-tone painted shader the art direction is built on.
- `source/ISLAND_README.txt` is the original note that came with the island.
