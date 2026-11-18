# Christmas Platformer Kit

64×64 pixel-art tiles for a Christmas-themed 2D platformer, plus a ready-made Godot 4.3 TileSet and a small playable demo level that shows every tile in use.

![Demo level](docs/screenshots/demo_start.png)

## What's in the kit

| File | What it is | Tiles |
|---|---|---|
| `tiles/terrain_snow_ground.png` | Frozen earth with a snow cap | 47 + 1 variant |
| `tiles/terrain_ice.png` | Ice blocks (slippery) | 47 + 1 variant |
| `tiles/terrain_gingerbread.png` | Gingerbread with icing and sprinkles | 47 + 1 variant |
| `tiles/terrain_snow_brick.png` | Red brick with snow (houses, towers, chimneys) | 47 + 1 variant |
| `tiles/platforms_hazards.png` | One-way planks, candy-cane and ice platforms, crate, gift block, ice blocks, spikes, icicles, spring, ladder, animated freezing water | 8×4 sheet |
| `tiles/decorations.png` | Christmas tree, snowy pine, log cabin, North Pole sign, snowman, lamp post, presents, candy cane, wreath, stocking, holly, bell, bush, gingerbread man, rock, snow pile, icicles, fence, twinkling string lights | 8×6 sheet, some objects 2×3 or 3×3 tiles |
| `tiles/pickups.png` | Animated collectables, 6 frames each: star, present, candy cane, bauble, cookie, bell, heart, snowflake, and a sparkle "collected" effect | 6×9 sheet |
| `tiles/player_elf.png` | A simple elf test character: idle, run, jump, fall, climb | 10 frames |
| `backgrounds/` | Three 1280×720 parallax layers (sky with aurora, mountains, hills) that repeat sideways, plus a snowflake particle | |

Every tile is **64×64 pixels** on a 64-pixel grid with no padding, and every sheet uses the same palette and the same 2-pixel dark outline, so they all look like one set.

Labelled reference sheets are in [`docs/`](docs): `ref_terrains.png`, `ref_platforms_hazards.png`, `ref_decorations.png`, `ref_pickups.png`, and `guide_blob_47.png`, which shows the neighbour pattern each terrain tile expects.

## Run the demo (Godot 4.3)

1. Install [Godot 4.3](https://godotengine.org/download/archive/4.3-stable/) (standard build).
2. In Godot choose **Import**, pick `christmas-platformer-kit/project.godot`, then press **F5**.
3. Controls: **A/D** or arrow keys to move, **Space** to jump (hold it for a higher jump), **W/S** to climb ladders. A gamepad also works.

The level demonstrates: slippery ice, a spring, one-way platforms, a ladder up a brick tower, crumbling ice over freezing water, a gift block that gives a star when you hit it from below, spikes and icicles, collectables, and the North Pole sign as the finish line.

## Using the tiles in your own Godot project

1. Copy `tiles/`, `tilesets/` and (if you want them) `backgrounds/` into your project, keeping the folder names. The TileSet looks for the images at `res://tiles/...`.
2. **Project Settings → Rendering → Textures → Default Texture Filter → Nearest.** Without this, pixel art looks blurry.
3. Add a **TileMapLayer** node and set its *Tile Set* to `tilesets/christmas_tileset.tres`.
4. Use three layers, in this order in the scene tree:
   - `BackDecor`: trees, cabin, snowmen (drawn behind the player)
   - `Ground`: terrain, platforms and hazards (the only layer the player collides with)
   - `FrontDecor`: wreaths and lights hung on walls, drawn in front of the terrain

### Painting terrain (the quick way)

Open the **TileMap** panel, then the **Terrains** tab:

- **Terrain set 0** (Match Corners and Sides): *Snowy Ground, Ice, Gingerbread, Snowy Brick.* Pick one and paint. Godot picks the right edge, corner and inner-corner tile for you from the 47.
- **Terrain set 1** (Match Sides): *Wood Plank, Candy Cane, Ice Slab.* Paint a row and the end pieces are added automatically.

Each terrain also has a variant of the full tile (a buried bauble, a frozen snowflake, a gumdrop, a tiny wreath). Godot uses it at random about 1 time in 20 to break up repetition.

### Big decorations

Multi-tile objects such as the tree (2×3) and the cabin (3×3) are a single tile. **Click the cell where the object's bottom-left should stand.** They are anchored so their base sits on that cell.

### What the tiles know (custom data and physics)

| Custom data layer | Type | Set on | Use it for |
|---|---|---|---|
| `hazard` | bool | spikes, icicles, water | marks dangerous tiles |
| `slippery` | bool | every ice terrain tile, ice slab, ice block | lower acceleration and friction |
| `bounce` | float | spring (1.8) | multiply the jump velocity |
| `climbable` | bool | ladder | switch to climbing |
| `crumble` | bool | cracked ice | remove the tile after standing on it |
| `hit_block` | bool | gift block | swap to the used block and spawn a reward |
| `goal` | bool | North Pole sign | finish the level |

| Physics layer | Collision layer | Contains |
|---|---|---|
| 0 "world" | 1 | terrain, crates and blocks (full squares), the spring, one-way platforms (top 16 px, one-way) |
| 1 "hazard" | 2 | only the dangerous part of each spike, icicle and water tile |

Reading tile data from a script:

```gdscript
var cell := ground.local_to_map(ground.to_local(global_position + Vector2(0, 33)))
var data := ground.get_cell_tile_data(cell)
if data and data.get_custom_data("slippery"):
	accel = ice_accel
```

`scripts/player.gd` uses every one of these layers, and is commented as a worked example.

## Using the tiles in other engines

All sheets are plain PNGs on a 64×64 grid with no spacing or margin.

- **Unreal Engine (Paper2D):** import the PNGs, right-click → *Sprite Actions → Apply Paper2D Texture Settings* (this sets Nearest filtering and no mipmaps), then *Create Tile Set* with Tile Size 64×64. Build levels with a *Paper Tile Map*. Set collision per tile in the Tile Set editor using the tables above. For the pickups and elf, use *Extract Sprites* (grid 64×64) and make a *Flipbook* per row.
- **Unity:** Texture Type *Sprite (2D and UI)*, Sprite Mode *Multiple*, Filter *Point*, Compression *None*, Pixels Per Unit *64*. Slice in the Sprite Editor with *Grid By Cell Size* 64×64. Rule Tiles (2D Tilemap Extras) can rebuild the 47-tile terrains: `guide_blob_47.png` shows each tile's neighbour rule.
- **GameMaker:** create a Tile Set from each sheet with tile width/height 64 and no offsets or separation. For Auto Tiles, choose the 47-tile set and assign each slot using `guide_blob_47.png`, because the kit's tile order differs from GameMaker's template.

## Editing or regenerating the art

Students can paint over any PNG in Aseprite, LibreSprite, Piskel or Krita. Keep the 64-pixel grid and the outline colour (`#1a1c2c`) so edits match the rest of the kit.

Everything in the kit is generated by the scripts in `tools/`. Running them **overwrites** the PNGs, so back up hand edits first:

- `tools/pixel.py`: the shared palette. Change a colour and rebuild to re-skin the whole kit.
- `tools/terrain.py`: the 47-tile terrain generator (distance-field outlines, snow caps, inner corners).
- `tools/props.py`: platforms, decorations, pickups, elf and backgrounds.
- `tools/level_layout.py`: the demo level as an ASCII map.
- `tools/build_godot.gd`: builds the TileSet, SpriteFrames and scenes.
- `tools/test_mechanics.gd`: a headless check that each tile mechanic works.

Rebuild everything with `tools/build_all.sh /path/to/godot` (needs Python 3 with Pillow and numpy).
