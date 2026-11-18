"""Generates the four 47-tile 'blob' terrain sheets (snowy ground, ice,
gingerbread, snowy brick) used by Godot's 'Match Corners and Sides' terrain mode.

How it works (worth showing students):
  * Every tile is defined by which of its 8 neighbours are also solid.
  * A diagonal neighbour only matters when both sides next to it are solid, so
    the 256 combinations collapse to 47 unique tiles.
  * For each tile we build a 3x3-tile 'context' of solid pixels, then colour each
    pixel from its distance to the nearest empty pixel. Outlines, snow caps and
    inner corners all fall out of that one distance field, so they always join up.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

import numpy as np
from PIL import Image

from pixel import PAL, TILE, C, draw, new, periodic, rng

N, NE, E, SE, S, SW, W, NW = 1, 2, 4, 8, 16, 32, 64, 128
BIT_OFFSETS = {N: (0, -1), NE: (1, -1), E: (1, 0), SE: (1, 1), S: (0, 1), SW: (-1, 1), W: (-1, 0), NW: (-1, -1)}
CORNER_RADIUS = 9


def reduce_mask(m: int) -> int:
    """Drop diagonal bits whose two adjacent side bits are not both set."""
    if not (m & N and m & E): m &= ~NE
    if not (m & S and m & E): m &= ~SE
    if not (m & S and m & W): m &= ~SW
    if not (m & N and m & W): m &= ~NW
    return m


def blob_masks() -> list[int]:
    masks = sorted({reduce_mask(m) for m in range(256)})
    # Order so the sheet reads sensibly: fewer neighbours first, full tile last.
    masks.sort(key=lambda m: (bin(m).count("1"), m))
    assert len(masks) == 47
    return masks


# ---------------------------------------------------------------- context mask
def context_solid(mask: int) -> np.ndarray:
    """192x192 boolean image of the tile and its 8 neighbours."""
    cells = {(0, 0)}
    for bit, (dx, dy) in BIT_OFFSETS.items():
        if mask & bit:
            cells.add((dx, dy))
    big = np.zeros((TILE * 3, TILE * 3), dtype=bool)
    yy, xx = np.mgrid[0:TILE, 0:TILE]
    for (cx, cy) in cells:
        cell = np.ones((TILE, TILE), dtype=bool)

        def solid(dx, dy):
            nx, ny = cx + dx, cy + dy
            if abs(nx) > 1 or abs(ny) > 1:
                return True  # outside the context: assume solid so we do not invent edges
            return (nx, ny) in cells

        r = CORNER_RADIUS
        for (sx, sy, px, py) in ((-1, -1, r, r), (1, -1, TILE - 1 - r, r), (-1, 1, r, TILE - 1 - r), (1, 1, TILE - 1 - r, TILE - 1 - r)):
            if not solid(sx, 0) and not solid(0, sy):
                in_corner = ((xx - px) * sx > 0) & ((yy - py) * sy > 0)
                outside = (xx - px) ** 2 + (yy - py) ** 2 > (r + 0.35) ** 2
                cell &= ~(in_corner & outside)
        ox, oy = (cx + 1) * TILE, (cy + 1) * TILE
        big[oy:oy + TILE, ox:ox + TILE] |= cell
    return big


def distance_to_empty(big: np.ndarray, radius: int = 12) -> np.ndarray:
    """Euclidean distance (capped) from each pixel of the centre tile to empty space."""
    pad = radius
    empty = np.pad(~big, pad, constant_values=False)
    d = np.full((TILE, TILE), float(radius + 1))
    y0 = x0 = TILE + pad
    for dy in range(-radius, radius + 1):
        for dx in range(-radius, radius + 1):
            dist = math.hypot(dx, dy)
            if dist > radius:
                continue
            win = empty[y0 + dy:y0 + dy + TILE, x0 + dx:x0 + dx + TILE]
            d = np.where(win & (dist < d), dist, d)
    return d


def run_length(big: np.ndarray, direction: str) -> np.ndarray:
    """How many solid pixels lie between each centre pixel and empty space in one direction."""
    arr = big
    if direction == "up":
        pass
    elif direction == "down":
        arr = arr[::-1, :]
    elif direction == "left":
        arr = arr.T
    elif direction == "right":
        arr = arr.T[::-1, :]
    out = np.zeros(arr.shape, dtype=np.int32)
    run = np.zeros(arr.shape[1], dtype=np.int32)
    for y in range(arr.shape[0]):
        run = np.where(arr[y], run + 1, 0)
        out[y] = run
    if direction == "down":
        out = out[::-1, :]
    elif direction == "left":
        out = out.T
    elif direction == "right":
        out = out[::-1, :].T
    return out[TILE:2 * TILE, TILE:2 * TILE]


# ---------------------------------------------------------------- textures
def wrap_draw(fn, seed: int) -> Image.Image:
    """Draw onto a 3x3 canvas and fold it back to 64x64 so shapes that cross an
    edge reappear on the opposite edge: the texture tiles seamlessly."""
    big = new(TILE * 3, TILE * 3)
    fn(big, rng(seed))
    out = new()
    for oy in range(3):
        for ox in range(3):
            out.alpha_composite(big.crop((ox * TILE, oy * TILE, ox * TILE + TILE, oy * TILE + TILE)))
    return out


def tex_earth(base: Image.Image, r) -> None:
    d = draw(base)
    o = TILE  # draw in the middle cell; pieces past its edge get folded back
    for _ in range(70):
        x, y = r.randrange(TILE), r.randrange(TILE)
        d.rectangle([o + x, o + y, o + x + r.choice([0, 1]), o + y], fill=C(r.choice(["earth_lo", "earth_lo", "earth_hi"])))
    for _ in range(9):  # lighter clumps of soil
        x, y = r.randrange(TILE), r.randrange(TILE)
        d.ellipse([o + x, o + y, o + x + r.randint(6, 12), o + y + r.randint(3, 6)], fill=C("earth_hi"))
        d.line([(o + x + 2, o + y + 5), (o + x + 8, o + y + 5)], fill=C("earth_lo"))
    for _ in range(5):  # pebbles of mixed size
        x, y = r.randrange(TILE), r.randrange(TILE)
        w = r.choice([4, 6, 8, 11]); h = max(3, w * 2 // 3)
        d.ellipse([o + x - 1, o + y - 1, o + x + w + 1, o + y + h + 1], fill=C("earth_deep"))
        d.ellipse([o + x, o + y, o + x + w, o + y + h], fill=C("stone"))
        d.ellipse([o + x + 1, o + y + h // 2, o + x + w, o + y + h], fill=C("stone_lo"))
        d.rectangle([o + x + 2, o + y + 1, o + x + 3, o + y + 1], fill=C("stone_hi"))
    for _ in range(4):  # tiny roots
        x, y = r.randrange(TILE), r.randrange(TILE)
        pts = [(o + x, o + y)]
        for _ in range(4):
            x += r.choice([2, 3]); y += r.choice([-1, 0, 1])
            pts.append((o + x, o + y))
        d.line(pts, fill=C("earth_deep"), width=1)


def tex_ice(base: Image.Image, r) -> None:
    d = draw(base)
    o = TILE
    for _ in range(10):
        x, y = r.randrange(TILE), r.randrange(TILE)
        d.ellipse([o + x, o + y, o + x + r.randint(8, 16), o + y + r.randint(6, 10)], fill=C("ice_mid"))
    for k in range(3):  # diagonal glints, spaced so they wrap cleanly
        x = k * 21 + r.randint(0, 6)
        d.line([(o + x, o + 48), (o + x + 16, o + 32)], fill=C("ice_hi"), width=3)
        d.line([(o + x + 6, o + 20), (o + x + 12, o + 14)], fill=C("ice_hi"), width=2)
    for _ in range(4):  # hairline cracks
        x, y = r.randrange(TILE), r.randrange(TILE)
        pts = [(o + x, o + y)]
        for _ in range(3):
            x += r.randint(2, 5); y += r.choice([-3, -2, 2, 3])
            pts.append((o + x, o + y))
        d.line(pts, fill=C("ice_lo"), width=1)
    for _ in range(8):  # air bubbles
        x, y = r.randrange(TILE), r.randrange(TILE)
        d.rectangle([o + x, o + y, o + x + 1, o + y + 1], fill=C("ice_hi"))


def tex_ginger(base: Image.Image, r) -> None:
    d = draw(base)
    o = TILE
    for _ in range(8):
        x, y = r.randrange(TILE), r.randrange(TILE)
        d.ellipse([o + x, o + y, o + x + r.randint(8, 14), o + y + r.randint(5, 9)], fill=C("ginger_hi"))
    for _ in range(26):  # baked pores
        x, y = r.randrange(TILE), r.randrange(TILE)
        d.rectangle([o + x, o + y, o + x + 1, o + y + 1], fill=C("ginger_lo"))
        d.point((o + x, o + y - 1), fill=C("ginger_hi"))
    for _ in range(3):  # cracks in the bake
        x, y = r.randrange(TILE), r.randrange(TILE)
        d.line([(o + x, o + y), (o + x + 3, o + y + 2), (o + x + 6, o + y + 1)], fill=C("ginger_deep"), width=1)


def tex_brick(base: Image.Image, r) -> None:
    d = draw(base)
    o = TILE
    bw, bh = 32, 16
    for row in range(TILE // bh):
        shift = 0 if row % 2 == 0 else bw // 2
        for col in range(-1, TILE // bw + 1):
            x0 = o + col * bw + shift
            y0 = o + row * bh
            body = C(r.choice(["brick", "brick", "brick_hi", "brick_lo"]))
            d.rectangle([x0, y0, x0 + bw - 1, y0 + bh - 1], fill=C("mortar"))
            d.rectangle([x0 + 2, y0 + 2, x0 + bw - 1, y0 + bh - 1], fill=body)
            d.line([(x0 + 2, y0 + 2), (x0 + bw - 1, y0 + 2)], fill=C("brick_hi") if body != C("brick_hi") else C("red_hi"))
            d.line([(x0 + 2, y0 + bh - 1), (x0 + bw - 1, y0 + bh - 1)], fill=C("brick_lo") if body != C("brick_lo") else C("red_deep"))
            d.line([(x0, y0 + bh - 1), (x0 + 1, y0 + bh - 1)], fill=C("mortar_lo"))
            for _ in range(2):
                px, py = x0 + r.randint(4, bw - 4), y0 + r.randint(5, bh - 4)
                d.point((px, py), fill=C("brick_lo"))


# ---------------------------------------------------------------- variants (full tile only)
def var_earth(img: Image.Image) -> None:
    d = draw(img)  # a lost bauble frozen in the ground
    d.ellipse([22, 24, 40, 42], fill=C("ink"))
    d.ellipse([24, 26, 38, 40], fill=C("red"))
    d.ellipse([30, 32, 38, 40], fill=C("red_lo"))
    d.rectangle([27, 28, 29, 30], fill=C("red_hi"))
    d.rectangle([28, 20, 34, 25], fill=C("ink"))
    d.rectangle([29, 21, 33, 24], fill=C("gold"))


def var_ice(img: Image.Image) -> None:
    d = draw(img)  # a snowflake trapped in the ice
    cx, cy = 32, 32
    for a in range(6):
        ang = a * math.pi / 3
        x2, y2 = cx + 11 * math.cos(ang), cy + 11 * math.sin(ang)
        d.line([(cx, cy), (x2, y2)], fill=C("ice_hi"), width=2)
        mx, my = cx + 6 * math.cos(ang), cy + 6 * math.sin(ang)
        for s in (-1, 1):
            b = ang + s * math.pi / 4
            d.line([(mx, my), (mx + 4 * math.cos(b), my + 4 * math.sin(b))], fill=C("ice_hi"), width=1)
    d.rectangle([cx - 1, cy - 1, cx + 1, cy + 1], fill=C("snow_hi"))


def var_ginger(img: Image.Image) -> None:
    d = draw(img)  # a gumdrop button
    d.ellipse([22, 24, 42, 42], fill=C("ink"))
    d.ellipse([24, 26, 40, 40], fill=C("green"))
    d.ellipse([30, 32, 40, 40], fill=C("green_lo"))
    d.rectangle([27, 29, 29, 30], fill=C("green_hi"))
    for (x, y) in ((27, 35), (33, 29), (35, 36)):
        d.point((x, y), fill=C("snow_hi"))


def var_brick(img: Image.Image) -> None:
    before = img.copy()
    d = draw(img)  # a little wreath hung on the wall
    d.ellipse([18, 18, 46, 46], fill=C("ink"))
    d.ellipse([20, 20, 44, 44], fill=C("green_lo"))
    d.ellipse([28, 28, 36, 36], fill=C("ink"))
    hole = new()
    draw(hole).ellipse([29, 29, 35, 35], fill=C("ink"))
    img.paste(before, (0, 0), hole)  # the hole shows the brick behind
    r_ = rng(7)
    for _ in range(24):
        a = r_.random() * 2 * math.pi
        rr = r_.uniform(7, 10)
        x, y = 32 + rr * math.cos(a), 32 + rr * math.sin(a)
        d.rectangle([x, y, x + 1, y + 1], fill=C(r_.choice(["green", "green_hi"])))
    for a in (0.6, 2.2, 3.8, 5.1):
        x, y = 32 + 9 * math.cos(a), 32 + 9 * math.sin(a)
        d.rectangle([x - 1, y - 1, x + 1, y + 1], fill=C("red"))
    d.polygon([(28, 40), (32, 38), (36, 40), (37, 46), (32, 42), (27, 46)], fill=C("red"))


MATERIALS = {
    "snow_ground": dict(tex=tex_earth, seed=11, cap=15, cap_kind="snow", body=("earth_hi", "earth", "earth_lo", "earth_deep"), variant=var_earth, slippery=False),
    "ice": dict(tex=tex_ice, seed=23, cap=10, cap_kind="snow", body=("ice_hi", "ice", "ice_lo", "ice_deep"), variant=var_ice, slippery=True),
    "gingerbread": dict(tex=tex_ginger, seed=37, cap=13, cap_kind="icing", body=("ginger_hi", "ginger", "ginger_lo", "ginger_deep"), variant=var_ginger, slippery=False),
    "snow_brick": dict(tex=tex_brick, seed=41, cap=12, cap_kind="snow", body=("brick_hi", "brick", "brick_lo", "mortar_lo"), variant=var_brick, slippery=False),
}


def base_texture(mat: dict) -> Image.Image:
    # Details are drawn on a transparent layer, folded to 64x64, then laid on the flat fill.
    out = new()
    draw(out).rectangle([0, 0, TILE, TILE], fill=C(mat["body"][1]))
    out.alpha_composite(wrap_draw(mat["tex"], mat["seed"]))
    return out


def cap_profile(mat: dict) -> np.ndarray:
    """Thickness of the snow/icing cap per column. Periodic, so neighbours line up."""
    x = np.arange(TILE)
    prof = mat["cap"] + periodic(x, [(1, 1.4, 0.7), (2, 1.2, 2.1), (5, 0.6, 0.3)])
    drips = [(9, 4, 6), (30, 6, 9), (52, 4, 5)] if mat["cap_kind"] == "icing" else [(10, 4, 5), (27, 3, 3), (45, 5, 7), (59, 2, 3)]
    for (cx, width, depth) in drips:
        t = np.clip(1 - ((x - cx) / width) ** 2, 0, 1)
        prof = prof + depth * np.sqrt(t)
    return np.round(prof).astype(int)


def render_tile(mat: dict, mask: int, tex: np.ndarray, cap: np.ndarray, sprinkle_seed: int) -> Image.Image:
    big = context_solid(mask)
    solid = big[TILE:2 * TILE, TILE:2 * TILE]
    dist = distance_to_empty(big)
    du, dd = run_length(big, "up"), run_length(big, "down")
    dl, dr = run_length(big, "left"), run_length(big, "right")
    hi, mid, lo, deep = (PAL[n] for n in mat["body"])

    out = tex.copy()
    # Form shading on exposed faces: light from the top-left.
    out[(dl >= 3) & (dl <= 5)] = hi
    out[(dr >= 3) & (dr <= 6)] = lo
    out[(dd >= 3) & (dd <= 8)] = lo
    out[(dd >= 3) & (dd <= 4)] = deep

    # Snow / icing cap: thicker where it spills over an exposed side.
    capx = cap[np.newaxis, :].repeat(TILE, 0)
    side = np.minimum(dl, dr)
    spill = np.clip(12 - 2 * side, 0, 12)
    capped = du <= capx + spill
    shadow = (du > capx + spill) & (du <= capx + spill + 2) & (du < 40)
    out[shadow] = deep
    out[capped] = PAL["snow"]
    out[capped & (du >= capx + spill - 1)] = PAL["snow_mid"]
    out[capped & (du <= 5)] = PAL["snow_hi"]
    out[capped & (dr <= 6) & (du > 5)] = PAL["snow_mid"]
    out[capped & (dl <= 5) & (du > 5)] = PAL["snow_hi"]

    if mat["cap_kind"] == "icing":  # sprinkles on the icing, kept clear of edges
        r = rng(sprinkle_seed)
        for _ in range(7):
            x, y = r.randrange(4, TILE - 5), r.randrange(4, 14)
            if capped[y, x] and capped[y, x + 1] and dist[y, x] > 4:
                out[y, x:x + 2] = PAL[r.choice(["red", "green", "pink", "gold"])]
    else:  # sparkles on snow
        r = rng(sprinkle_seed)
        for _ in range(3):
            x, y = r.randrange(4, TILE - 4), r.randrange(5, 10)
            if capped[y, x] and dist[y, x] > 4:
                out[y, x] = PAL["snow_lo"]
                out[y - 1, x] = PAL["snow_hi"]

    out[dist <= 2.0] = PAL["ink"]
    out[~solid] = PAL["clear"]
    return Image.fromarray(out)


def build(out_dir: Path) -> dict:
    masks = blob_masks()
    meta = {}
    cols, rows = 8, 6
    for name, mat in MATERIALS.items():
        tex_img = base_texture(mat)
        tex = np.array(tex_img)
        cap = cap_profile(mat)
        sheet = new(cols * TILE, rows * TILE)
        tiles = []
        for i, m in enumerate(masks):
            img = render_tile(mat, m, tex, cap, mat["seed"] * 100 + i)
            c, r = i % cols, i // cols
            sheet.alpha_composite(img, (c * TILE, r * TILE))
            tiles.append({"col": c, "row": r, "mask": m})
        # Slot 48: variant of the full tile, picked at random by Godot (probability).
        full = render_tile(mat, 255, tex, cap, 1)
        mat["variant"](full)
        sheet.alpha_composite(full, (7 * TILE, 5 * TILE))
        tiles.append({"col": 7, "row": 5, "mask": 255, "probability": 0.05})
        sheet.save(out_dir / f"terrain_{name}.png")
        meta[name] = {"tiles": tiles, "slippery": mat["slippery"]}
    return meta


if __name__ == "__main__":
    root = Path(__file__).resolve().parent.parent
    meta = build(root / "tiles")
    (root / "tools" / "terrain_meta.json").write_text(json.dumps(meta, indent=1))
    print("terrain sheets written")
