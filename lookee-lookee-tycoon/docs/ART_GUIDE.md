# Art guide: placeholder art and the modular character

Everything you see in Lookee Lookee Tycoon is drawn in code, so the game is complete and
playable with no art files at all. When you want hand-made art, you can replace it **one piece
at a time** by dropping PNGs into `art/`. No code changes and no scene editing are needed. This
guide explains how the character is built, what to draw, and where each piece goes.

## Style rules

* **Chunky cartoon.** Flat colours, one highlight, a thick dark outline (`#2b1d16`), and no
  gradients on characters.
* **Big heads.** The head is about 40% of the character's height, so faces, sunglasses and hats
  read on a phone.
* **Mediterranean palette.** Sea `#1e9bd7`, sand `#f7d89b`, terracotta `#e2673f`, lemon
  `#ffd23f`, lime `#7cc242`, white `#fffaf0`. The full palettes are in
  `scripts/character/appearance_options.gd` and `scripts/art/ui_theme.gd`.
* **Clear silhouettes.** Every accessory should be recognisable as a black shape: the arm of
  watches, the sombrero, the bum bag.

## How the character is built

`scripts/character/vendor_avatar.gd` is a **cut-out rig**. Each body part is its own node.
Animation (walking, running, waving, shouting, lying on a towel, swimming, blinking, talking)
just moves, rotates or swaps those parts. So you never draw animation frames: **one image per
part per style** is enough, and every combination of parts animates automatically.

The player's vendor, the tourists, the police and the workers all use this same rig.

### Coordinates

Units are **1x game pixels**. The origin is between the feet on the ground, and +y points down.
An average character is about 125 px tall.

```
            (0,-109)  top of head
        ┌─────────┐
        │  skull  │   skull centre (0,-84), radius 25  → head is 50 px wide
        │ (0,-84) │
        └────┬────┘
   arm ──────┼────── arm   shoulders at y = -57, x = ±(shoulder width - 2), arms 28 long
       ┌─────┴─────┐
       │   torso   │      torso from the hips (y=-26) up to the shoulders (y=-62)
       └──┬─────┬──┘
          │legs │         legs pivot at the hips, ±(waist × 0.45), 26 long
          ┴     ┴
        (0,0) feet on the ground
```

Body types change the widths:

| Body type | Shoulder half-width | Waist half-width | Belly | Arm width | Leg width |
|---|---|---|---|---|---|
| Slim | 14 | 12 | 0 | 5 | 6 |
| Average | 18 | 16 | 2 | 6 | 7 |
| Large | 22 | 23 | 9 | 7.5 | 8.5 |
| Muscular | 24 | 15 | 0 | 8.5 | 8 |

### Draw order (back to front)

1. shadow
2. back arm (slightly darker)
3. back leg, then front leg (each draws: skin, bottoms, shoes)
4. torso (skin, shirt, waistband/belt, chain, bag)
5. head: hair back, then skull (neck, ears, face, earrings), eyes, brows, nose, beard, mouth,
   moustache, hair front, glasses, hat
6. front arm (sleeve, hand, watches, held item)

## Replacing parts with PNGs

Put a PNG at `art/characters/<layer>/<style>.png` and it replaces that part for every character
wearing that style.

* **Draw at 4x.** Files are drawn at a quarter of their pixel size, so a 200 px wide head
  appears 50 px wide. They stay sharp in the creator preview (about 3x zoom) and on big tablets.
* **Centre the anchor.** The middle of your image is placed on the layer's anchor point (table
  below). Leave transparent space so the anchor lands in the centre.
* **Paint tintable parts in greyscale.** The image is multiplied by the player's chosen colour.
  White becomes the exact colour, mid greys become shading, and black outlines stay black. That
  is how one hair PNG works for every hair colour, and one head works for every skin tone. Parts
  that aren't tinted (eyes, mouths, glasses) are painted in full colour.

File names are the option names in lower case, with `&` becoming `and` and spaces becoming
`_`: "Buzz Cut" → `buzz_cut.png`, "Socks & Sandals" → `socks_and_sandals.png`.

| Layer folder | Files | Anchor (from the feet, 1x) | Tinted by | Suggested 4x canvas |
|---|---|---|---|---|
| `skull/` | `head.png` (face shape and ears; the neck stays procedural) | (0, -84) skull centre | skin | 256 × 256 |
| `hair_back/` | one per hair style, drawn **behind** the head (long hair, afro volume, ponytail, braids) | (0, -84) | hair colour | 320 × 320 |
| `hair_front/` | one per hair style, drawn **over** the face (fringe, top) | (0, -84) | hair colour | 320 × 320 |
| `eyes/` | one per eye style + `closed.png` (blink/sleep) | (3, -85) between the eyes | none (`closed` uses skin) | 160 × 64 |
| `brows/` | one per brow style | (3, -94) | hair colour, darkened | 160 × 48 |
| `nose/` | one per nose style | (4.5, -78) | skin | 64 × 64 |
| `mouth/` | one per mouth style + `open.png` (talking/shouting) | (3, -70) | none | 96 × 80 |
| `facial_hair/` | one per style except `none` (include the moustache; it replaces both beard and moustache) | (3, -76) | hair colour | 224 × 192 |
| `glasses/` | one per style except `none` | (3, -85) | none | 192 × 96 |
| `hats/` | one per hat except `none`, + `police.png` | (0, -96), raised 2-9 px by big hair | hat colour (police: navy) | 384 × 256 |
| `shirts/` | one per shirt, + `police.png`; optional `<shirt>_<body>.png` (e.g. `hawaiian_large.png`) | (0, -44) torso centre | shirt colour | 224 × 192 |
| `bottoms/` | one per leg style, drawn on **each** leg; optional `<style>_<body>.png` | 10.4 px below the hip joint | bottoms colour | 64 × 128 |
| `shoes/` | one per shoe style, drawn on **each** foot | 2 px forward, 25 px below the hip joint | shoe colour | 96 × 48 |

Notes:

* Sleeves, hands, watches, chains, bags and earrings stay procedural for now, because they ride
  on animated arms or depend on the body type. The painters are small functions in
  `vendor_avatar.gd` (`_paint_arm`, `_paint_chain`, `_paint_bag`) if you want to add more
  override points the same way.
* The character faces right. The rig mirrors the whole body when walking left, so draw facing
  right with the face features nudged slightly right (3/4 view, as the code does).
* Mixing is fine: replace just the hats, or just one hair style, and the rest stays procedural.

### Import settings

Godot imports PNGs automatically. Select a file in the FileSystem dock, open the Import tab, set
the following and click **Reimport**:

* **Compress > Mode: VRAM Compressed.** The project imports ETC2/ASTC for Android and S3TC/BPTC
  for desktop browsers, which keeps memory low on phones.
* **Mipmaps > Generate: On.** Character parts are drawn with mipmapped filtering, because 4x art
  is shown smaller most of the time.

For crisp UI art, use **Lossless** instead.

## Item icons

`art/items/<item_id>.png` replaces that item's icon everywhere: on stalls, in tourists' hands
and in the Wholesaler. Use square images (128 × 128 is plenty) in full colour with the same dark
outline. The ids are the keys in `data/items.gd`: `magnet`, `sunglasses`, `bracelet`,
`umbrella`, `bunny_ears`, `selfie_stick`, `sun_hat`, `flamingo`, `fan`, `watch`, `speaker`,
`henna`, `unicorn`, `gold_chain`, `drone`, `handbag`, `light_shoes` and `yacht_model`.

## Quick placeholder workflow

1. Start from a real screenshot. `godot --path . res://tools/screenshots.tscn -- /tmp/screens`
   renders every screen; scale the creator preview up 4x and trace over it to get proportions
   right.
2. In Krita, Aseprite or Inkscape, make one layer per part on a 4x canvas from the table, and
   put a guide at the canvas centre (the anchor).
3. Hair, skin, clothes and hats: paint them white or light grey with a dark outline. Eyes,
   mouths and glasses: paint them in colour.
4. Export each layer as PNG into the matching `art/characters/<layer>/` folder, open the
   project, and press Play. The Character Creator shows your art immediately, with every colour.

## If you'd rather use sprite sheets

The cut-out rig is the recommended approach because it keeps every customisation combination
animated for free. If you want hand-drawn frame animation for some characters (for example
special NPCs), give them an `AnimatedSprite2D` with a `SpriteFrames` resource (idle, walk, run,
shout) instead of a `VendorAvatar`. To keep that customisable, stack one `AnimatedSprite2D` per
layer (body, shirt, hair, hat) using identical frame layouts, play the same animation on all of
them, and set each layer's `modulate` to the chosen colour, painting the layers in greyscale as
above. `Walker` only talks to its avatar through `set_pose()`, `set_facing()`, `talk()` and
`shout()`, so a small wrapper with those four methods is all that needs to change.

## Other art in the game

| What | Where | Notes |
|---|---|---|
| Beach, sea, sky, promenade | `scripts/beach/beach_backdrop.gd` | Colours per resort in `data/beaches.gd` |
| Palms, lamps, umbrellas, towels, lifeguard tower, signs | `scripts/beach/props.gd` | Origin = where it touches the ground (y-sorted) |
| Stalls (6 tiers) | `scripts/beach/stall.gd` | Origin = front edge on the sand |
| Coins, puffs, floating text | `scripts/beach/fx_layer.gd` | One node draws every particle |
| HUD icons, round SHOUT button | `scripts/ui/widgets.gd` | |
| Buttons, panels, sliders | `scripts/art/ui_theme.gd` | Theme built in code |
| App icons, itch cover | `tools/make_icons.gd` | Rendered from the rig |
