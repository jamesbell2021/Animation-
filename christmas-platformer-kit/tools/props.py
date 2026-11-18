"""Generates the non-terrain sheets: platforms & hazards, decorations,
animated pickups, and the parallax background layers.

Each object is drawn as flat shapes from the shared palette, then given the
kit's 2px ink outline, so it matches the terrain.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

import numpy as np
from PIL import Image

from pixel import PAL, TILE, C, draw, new, outline, periodic, rng

ROOT = Path(__file__).resolve().parent.parent


def finish(img: Image.Image, width: int = 2) -> Image.Image:
    return outline(img, "ink", width)


def snow_lip(d, x0: int, x1: int, y: int, seed: int, depth: int = 6) -> None:
    """A lumpy strip of snow sitting on a surface from x0..x1 with its base at y."""
    r = rng(seed)
    d.rounded_rectangle([x0, y - depth, x1, y + 2], radius=3, fill=C("snow"))
    for x in range(x0 + 3, x1 - 2, 7):
        h = r.randint(2, 4)
        d.ellipse([x - 3, y - depth - h, x + 4, y - depth + 3], fill=C("snow"))
        if r.random() < 0.5:
            d.rectangle([x, y + 2, x + 1, y + 2 + r.randint(1, 3)], fill=C("snow_mid"))
    d.line([(x0 + 2, y - depth + 1), (x1 - 3, y - depth + 1)], fill=C("snow_hi"))
    d.line([(x0 + 1, y + 1), (x1 - 1, y + 1)], fill=C("snow_mid"))


# =================================================================== PLATFORMS
def plank(kind: str, seed: int) -> Image.Image:
    """One-way wooden plank. kind is L, M, R or single; the platform's walkable
    top is the tile's top edge, so the one-way collider sits at y 0..16."""
    img = new()
    d = draw(img)
    x0 = 4 if kind in ("L", "single") else 0
    x1 = 59 if kind in ("R", "single") else 63
    d.rectangle([x0, 8, x1, 26], fill=C("wood"))
    d.line([(x0, 9), (x1, 9)], fill=C("wood_hi"))
    d.line([(x0, 25), (x1, 25)], fill=C("wood_lo"))
    d.line([(x0, 17), (x1, 17)], fill=C("wood_lo"))  # two boards
    r = rng(seed)
    for _ in range(3):  # grain
        gx = r.randint(x0 + 3, x1 - 12)
        gy = r.choice([12, 14, 20, 22])
        d.line([(gx, gy), (gx + r.randint(5, 10), gy)], fill=C("wood_lo"))
    for nx in ([x0 + 5] if kind in ("L", "single") else []) + ([x1 - 6] if kind in ("R", "single") else []) + ([31] if kind == "M" else []):
        for ny in (12, 21):
            d.rectangle([nx, ny, nx + 1, ny + 1], fill=C("ink_soft"))
    if kind in ("L", "single", "R"):  # support bracket under the end
        bx = x0 + 6 if kind != "R" else x1 - 12
        if kind == "single":
            for bx_ in (x0 + 6, x1 - 12):
                d.polygon([(bx_, 26), (bx_ + 6, 26), (bx_ + 3, 36)], fill=C("wood_lo"))
        else:
            d.polygon([(bx, 26), (bx + 6, 26), (bx + 3, 36)], fill=C("wood_lo"))
    snow_lip(d, x0, x1, 8, seed + 1, depth=5)
    return finish(img)


def candy_platform(kind: str, seed: int) -> Image.Image:
    img = new()
    d = draw(img)
    x0 = 4 if kind in ("L", "single") else 0
    x1 = 59 if kind in ("R", "single") else 63
    top, bot = 8, 26
    d.rectangle([x0, top, x1, bot], fill=C("snow_hi"))
    for sx in range(-40, 80, 16):  # diagonal stripes; period 16 divides 64 so they join
        d.polygon([(sx, bot), (sx + 8, bot), (sx + 8 + (bot - top), top), (sx + (bot - top), top)], fill=C("red"))
    mask = new(); draw(mask).rectangle([x0, top, x1, bot], fill=C("ink"))
    if kind in ("L", "single"):
        draw(mask).rectangle([x0, top, x0 + 8, bot], fill=(0, 0, 0, 0))
        draw(mask).ellipse([x0, top, x0 + 18, bot], fill=C("ink"))
    if kind in ("R", "single"):
        draw(mask).rectangle([x1 - 8, top, x1, bot], fill=(0, 0, 0, 0))
        draw(mask).ellipse([x1 - 18, top, x1, bot], fill=C("ink"))
    arr = np.array(img); m = np.array(mask)[:, :, 3] > 0
    arr[~m] = PAL["clear"]
    img = Image.fromarray(arr)
    d = draw(img)
    # tube shading
    a = np.array(img)
    for y, (light, dark) in ((top + 2, ("snow_hi", "red_hi")), (bot - 2, ("snow_mid", "red_lo")), (bot - 1, ("snow_mid", "red_lo"))):
        row = a[y]
        for x in range(64):
            if row[x, 3]:
                row[x] = PAL[dark] if tuple(row[x]) in (PAL["red"], PAL["red_hi"], PAL["red_lo"]) else PAL[light]
    img = Image.fromarray(a)
    d = draw(img)
    d.line([(x0 + 6, top + 3), (x1 - 6, top + 3)], fill=C("snow_hi"))
    snow_lip(d, x0 + 3, x1 - 3, top + 1, seed, depth=3)
    return finish(img)


def ice_slab(kind: str, seed: int) -> Image.Image:
    img = new()
    d = draw(img)
    x0 = 4 if kind in ("L", "single") else 0
    x1 = 59 if kind in ("R", "single") else 63
    d.rectangle([x0, 6, x1, 20], fill=C("ice"))
    d.line([(x0, 7), (x1, 7)], fill=C("ice_hi"))
    d.line([(x0, 8), (x1, 8)], fill=C("ice_hi"))
    d.line([(x0, 19), (x1, 19)], fill=C("ice_lo"))
    for gx in range(x0 + 6, x1 - 6, 18):
        d.line([(gx, 16), (gx + 6, 10)], fill=C("ice_hi"), width=2)
    r = rng(seed)
    xs = list(range(x0 + 4, x1 - 3, 9))
    for ix in xs:  # icicles hanging under the slab (decoration only)
        length = r.randint(6, 18)
        d.polygon([(ix - 3, 20), (ix + 3, 20), (ix, 20 + length)], fill=C("ice_mid"))
        d.line([(ix - 1, 21), (ix - 1, 20 + length * 2 // 3)], fill=C("ice_hi"))
    if kind in ("L", "single"):
        d.rectangle([x0, 6, x0 + 1, 7], fill=(0, 0, 0, 0))
    if kind in ("R", "single"):
        d.rectangle([x1 - 1, 6, x1, 7], fill=(0, 0, 0, 0))
    return finish(img)


def crate() -> Image.Image:
    img = new(); d = draw(img)
    d.rectangle([2, 2, 61, 61], fill=C("wood"))
    d.rectangle([2, 2, 61, 9], fill=C("wood_lo")); d.rectangle([2, 54, 61, 61], fill=C("wood_lo"))
    d.rectangle([2, 2, 9, 61], fill=C("wood_lo")); d.rectangle([54, 2, 61, 61], fill=C("wood_lo"))
    d.line([(10, 52), (52, 10)], fill=C("wood_lo"), width=6)
    d.line([(10, 50), (50, 10)], fill=C("wood_hi"), width=1)
    for y in (24, 38):
        d.line([(10, y), (53, y)], fill=C("wood_deep"))
    for (x, y) in ((5, 5), (57, 5), (5, 57), (57, 57)):
        d.rectangle([x, y, x + 1, y + 1], fill=C("stone_hi"))
    d.line([(10, 10), (53, 10)], fill=C("wood_hi"))
    snow_lip(d, 2, 61, 6, 5, depth=4)
    return inner(img)


def inner(img: Image.Image) -> Image.Image:
    """Solid full blocks keep their 64x64 footprint: outline drawn inside."""
    from pixel import inner_outline
    return inner_outline(img, "ink", 2)


def gift_block(used: bool = False) -> Image.Image:
    img = new(); d = draw(img)
    if used:
        d.rectangle([0, 0, 63, 63], fill=C("wood_lo"))
        d.rectangle([4, 4, 59, 59], fill=C("wood"))
        d.rectangle([4, 4, 59, 8], fill=C("wood_hi"))
        d.rectangle([4, 55, 59, 59], fill=C("wood_deep"))
        for (x, y) in ((8, 12), (52, 12), (8, 50), (52, 50)):
            d.rectangle([x, y, x + 2, y + 2], fill=C("ink_soft"))
        return inner(img)
    d.rectangle([0, 0, 63, 63], fill=C("red"))
    d.rectangle([0, 0, 63, 5], fill=C("red_hi"))
    d.rectangle([0, 56, 63, 63], fill=C("red_lo"))
    d.rectangle([27, 0, 36, 63], fill=C("gold"))  # ribbon
    d.rectangle([0, 27, 63, 36], fill=C("gold"))
    d.line([(27, 0), (27, 63)], fill=C("gold_hi")); d.line([(0, 27), (63, 27)], fill=C("gold_hi"))
    d.line([(36, 0), (36, 63)], fill=C("gold_lo")); d.line([(0, 36), (63, 36)], fill=C("gold_lo"))
    # bow
    d.ellipse([16, 20, 31, 32], fill=C("gold_mid")); d.ellipse([33, 20, 48, 32], fill=C("gold_mid"))
    d.ellipse([20, 23, 28, 29], fill=C("gold_lo")); d.ellipse([36, 23, 44, 29], fill=C("gold_lo"))
    d.rectangle([28, 24, 35, 34], fill=C("gold"))
    # star mark: 'hit me'
    for (x, y) in ((10, 10), (50, 48), (48, 10), (10, 48)):
        d.rectangle([x, y, x + 3, y + 3], fill=C("snow_hi"))
    return inner(img)


def ice_block(cracked: bool = False) -> Image.Image:
    img = new(); d = draw(img)
    d.rectangle([0, 0, 63, 63], fill=C("ice"))
    d.rectangle([0, 0, 63, 5], fill=C("ice_hi"))
    d.rectangle([0, 56, 63, 63], fill=C("ice_lo"))
    d.rectangle([58, 0, 63, 63], fill=C("ice_mid"))
    d.line([(10, 40), (30, 12)], fill=C("ice_hi"), width=4)
    d.line([(22, 50), (36, 30)], fill=C("ice_hi"), width=2)
    if cracked:
        d.line([(8, 20), (22, 28), (30, 22), (44, 34), (56, 30)], fill=C("ice_deep"), width=2)
        d.line([(30, 22), (32, 8)], fill=C("ice_deep"), width=2)
        d.line([(44, 34), (40, 52), (46, 60)], fill=C("ice_deep"), width=2)
        d.line([(22, 28), (16, 46)], fill=C("ice_deep"), width=1)
    snow_lip(d, 2, 61, 5, 9, depth=3)
    return inner(img)


def floor_spikes() -> Image.Image:
    img = new(); d = draw(img)
    r = rng(3)
    xs = [4, 14, 24, 34, 44, 54]
    for i, x in enumerate(xs):
        h = 22 + (6 if i % 2 else 0) + r.randint(0, 4)
        d.polygon([(x - 5, 62), (x + 5, 62), (x, 62 - h)], fill=C("ice_mid"))
        d.polygon([(x - 5, 62), (x, 62), (x, 62 - h)], fill=C("ice_hi"))
        d.line([(x + 2, 60), (x + 1, 62 - h + 6)], fill=C("ice_lo"))
    d.rectangle([0, 58, 63, 63], fill=C("snow"))
    d.line([(0, 58), (63, 58)], fill=C("snow_hi"))
    return finish(img)


def ceiling_icicles() -> Image.Image:
    img = new(); d = draw(img)
    r = rng(8)
    for i, x in enumerate(range(5, 62, 9)):
        h = 18 + r.randint(0, 16)
        d.polygon([(x - 4, 1), (x + 4, 1), (x, 1 + h)], fill=C("ice"))
        d.line([(x - 2, 2), (x - 1, h - 2)], fill=C("ice_hi"))
        d.line([(x + 2, 2), (x + 1, h - 4)], fill=C("ice_lo"))
    d.rectangle([0, 0, 63, 4], fill=C("ice_lo"))
    return finish(img)


def wall_spikes(facing_right: bool) -> Image.Image:
    img = floor_spikes().rotate(-90 if facing_right else 90)
    return img


def spring() -> Image.Image:
    img = new(); d = draw(img)
    d.rectangle([8, 54, 55, 61], fill=C("stone_lo"))
    d.line([(8, 54), (55, 54)], fill=C("stone_hi"))
    for i, y in enumerate(range(50, 34, -5)):  # coil
        d.line([(16, y + 4), (47, y)], fill=C("stone_hi") if i % 2 == 0 else C("stone"), width=3)
    d.rounded_rectangle([6, 24, 57, 34], radius=4, fill=C("red"))
    d.line([(9, 26), (54, 26)], fill=C("red_hi"))
    d.line([(9, 33), (54, 33)], fill=C("red_lo"))
    for x in (14, 28, 42):
        d.rectangle([x, 28, x + 5, 30], fill=C("snow_hi"))
    return finish(img)


def ladder(top: bool) -> Image.Image:
    img = new(); d = draw(img)
    y0 = 10 if top else 0
    for x in (12, 46):
        d.rectangle([x, y0, x + 5, 63], fill=C("wood"))
        d.line([(x, y0), (x, 63)], fill=C("wood_hi"))
        d.line([(x + 5, y0), (x + 5, 63)], fill=C("wood_lo"))
    for y in range(y0 + 6, 64, 16):
        d.rectangle([17, y, 46, y + 4], fill=C("wood"))
        d.line([(17, y), (46, y)], fill=C("wood_hi"))
        d.line([(17, y + 4), (46, y + 4)], fill=C("wood_lo"))
    if top:
        d.ellipse([9, 4, 21, 13], fill=C("snow")); d.ellipse([43, 4, 55, 13], fill=C("snow"))
    return finish(img)


def water(surface: bool, frame: int) -> Image.Image:
    img = new(); d = draw(img)
    x = np.arange(TILE)
    ph = frame * math.pi / 2
    if surface:
        wave = 14 + np.round(periodic(x, [(2, 2.2, ph), (3, 1.0, -ph * 1.5)])).astype(int)
        for i in range(TILE):
            d.line([(i, wave[i]), (i, 63)], fill=C("ice_lo"))
            d.line([(i, wave[i]), (i, wave[i] + 2)], fill=C("ice_hi"))
            d.point((i, wave[i] + 3), fill=C("ice_mid"))
    else:
        d.rectangle([0, 0, 63, 63], fill=C("ice_lo"))
    r = rng(50)
    for k in range(6):  # drifting glints, positions wrap with the frame so the loop is seamless
        gx = (r.randrange(TILE) + frame * 4) % TILE
        gy = r.randrange(24 if surface else 4, 60)
        d.line([(gx, gy), (min(63, gx + 4), gy)], fill=C("ice_mid"))
    for k in range(3):
        bx = r.randrange(4, 60)
        by = (r.randrange(64) - frame * 16) % 64
        if not surface or by > 26:
            d.rectangle([bx, by, bx + 1, by + 1], fill=C("ice"))
    d.line([(0, 63), (63, 63)], fill=C("ice_deep")) if not surface else None
    return img


def build_platforms():
    cols, rows = 8, 4
    sh = new(cols * TILE, rows * TILE)
    tiles = {}

    def put(c, r, img, name, **data):
        sh.alpha_composite(img, (c * TILE, r * TILE))
        tiles[name] = dict(col=c, row=r, **data)

    for i, k in enumerate(("L", "M", "R", "single")):
        put(i, 0, plank(k, 20 + i), f"plank_{k}", collide="oneway")
        put(4 + i, 0, candy_platform(k, 30 + i), f"candy_{k}", collide="oneway")
        put(i, 1, ice_slab(k, 40 + i), f"ice_slab_{k}", collide="oneway", slippery=True)
    put(4, 1, crate(), "crate", collide="full")
    put(5, 1, gift_block(), "gift_block", collide="full", hit_block=True)
    put(6, 1, ice_block(), "ice_block", collide="full", slippery=True)
    put(7, 1, ice_block(cracked=True), "cracked_ice", collide="full", crumble=True)
    put(0, 2, floor_spikes(), "spikes_up", hazard=True)
    put(1, 2, ceiling_icicles(), "icicles_down", hazard=True)
    put(2, 2, spring(), "spring", collide="spring", bounce=1.8)
    put(3, 2, ladder(True), "ladder_top", climbable=True)
    put(4, 2, ladder(False), "ladder_mid", climbable=True)
    put(5, 2, wall_spikes(False), "spikes_left", hazard=True)
    put(6, 2, wall_spikes(True), "spikes_right", hazard=True)
    put(7, 2, gift_block(used=True), "used_block", collide="full")
    for f in range(4):
        sh.alpha_composite(water(True, f), (f * TILE, 3 * TILE))
        sh.alpha_composite(water(False, f), ((4 + f) * TILE, 3 * TILE))
    tiles["water_top"] = dict(col=0, row=3, hazard=True, frames=4, fps=6)
    tiles["water_deep"] = dict(col=4, row=3, hazard=True, frames=4, fps=6)
    sh.save(ROOT / "tiles/platforms_hazards.png")
    return tiles


# =================================================================== DECORATIONS
def star_points(cx, cy, r_out, r_in, n=5, rot=-math.pi / 2, sx=1.0):
    pts = []
    for i in range(n * 2):
        a = rot + i * math.pi / n
        rr = r_out if i % 2 == 0 else r_in
        pts.append((cx + rr * math.cos(a) * sx, cy + rr * math.sin(a)))
    return pts


def xmas_tree() -> Image.Image:
    w, h = 128, 192
    img = new(w, h); d = draw(img)
    d.rectangle([54, 160, 73, 188], fill=C("wood"))
    d.line([(55, 160), (55, 188)], fill=C("wood_hi")); d.line([(72, 160), (72, 188)], fill=C("wood_lo"))
    tiers = [(30, 70, 46), (60, 112, 56), (95, 160, 62)]  # (top y, bottom y, half width)
    for (ty, by, hw) in tiers:
        d.polygon([(64, ty - 18), (64 + hw, by), (64 - hw, by)], fill=C("green"))
        d.polygon([(64, ty - 18), (64, by), (64 - hw, by)], fill=C("green_hi"))
        d.polygon([(64 + 6, ty), (64 + hw, by), (64 + 8, by)], fill=C("green_lo"))
        # snowy, scalloped bottom edge
        for x in range(64 - hw + 4, 64 + hw - 3, 10):
            d.ellipse([x - 5, by - 5, x + 5, by + 3], fill=C("green_lo"))
        d.line([(64 - hw + 6, by - 2), (64 + hw - 6, by - 2)], fill=C("green_deep"))
    # garland
    for (ty, by, hw), col in zip(tiers, ("gold", "gold_mid", "gold")):
        y0 = (ty + by) // 2
        d.line([(64 - hw * 0.55, y0 - 6), (64 + hw * 0.55, y0 + 6)], fill=C(col), width=2)
    r = rng(12)
    for (ty, by, hw) in tiers:  # baubles
        for _ in range(5):
            y = r.randint(ty + 6, by - 6)
            span = hw * (y - (ty - 18)) / (by - (ty - 18)) - 7
            x = 64 + r.uniform(-span, span)
            col = r.choice(["red", "blue", "gold", "purple", "red"])
            d.ellipse([x - 4, y - 4, x + 4, y + 4], fill=C(col))
            d.point((x - 1, y - 2), fill=C("snow_hi"))
    d.polygon(star_points(64, 14, 13, 6), fill=C("gold"))
    d.polygon(star_points(64, 14, 7, 3), fill=C("gold_hi"))
    return finish(img)


def pine_tree() -> Image.Image:
    w, h = 128, 192
    img = new(w, h); d = draw(img)
    d.rectangle([56, 164, 71, 190], fill=C("wood_lo"))
    d.line([(57, 164), (57, 190)], fill=C("wood"))
    tiers = [(16, 64, 34), (46, 104, 48), (80, 146, 58), (112, 172, 62)]
    for (ty, by, hw) in tiers:
        d.polygon([(64, ty), (64 + hw, by), (64 - hw, by)], fill=C("green_lo"))
        d.polygon([(64, ty), (64, by), (64 - hw, by)], fill=C("green"))
        d.polygon([(64, ty), (64 + hw, by), (64 + hw - 10, by)], fill=C("green_deep"))
    img = finish(img)
    d = draw(img)
    for (ty, by, hw) in tiers:  # heavy snow on each tier
        d.polygon([(64, ty + 1), (64 + hw * 0.55, ty + (by - ty) * 0.55), (64 + hw * 0.25, ty + (by - ty) * 0.5),
                   (64, ty + (by - ty) * 0.6), (64 - hw * 0.3, ty + (by - ty) * 0.5), (64 - hw * 0.6, ty + (by - ty) * 0.58)], fill=C("snow"))
        d.polygon([(64, ty + 1), (64 - hw * 0.6, ty + (by - ty) * 0.58), (64 - hw * 0.3, ty + (by - ty) * 0.5), (64, ty + 4)], fill=C("snow_hi"))
        d.line([(64 - hw + 4, by - 1), (64 + hw - 4, by - 1)], fill=C("snow_mid"), width=2)
    return img


def cabin() -> Image.Image:
    w, h = 192, 192
    img = new(w, h); d = draw(img)
    # walls (log cabin)
    d.rectangle([20, 84, 171, 189], fill=C("wood"))
    for y in range(84, 190, 10):
        d.line([(20, y), (171, y)], fill=C("wood_lo"))
        d.line([(20, y + 1), (171, y + 1)], fill=C("wood_hi"))
        d.ellipse([16, y, 25, y + 9], fill=C("wood_hi")); d.ellipse([166, y, 175, y + 9], fill=C("wood_lo"))
    # chimney
    d.rectangle([128, 20, 151, 70], fill=C("brick"))
    for y in range(22, 70, 8):
        d.line([(128, y), (151, y)], fill=C("mortar"))
    # roof
    d.polygon([(4, 92), (96, 22), (188, 92)], fill=C("red_lo"))
    d.polygon([(4, 92), (96, 22), (96, 92)], fill=C("red"))
    for y in range(36, 92, 9):
        half = (y - 22) * 92 / 70
        d.line([(96 - half, y), (96 + half, y)], fill=C("red_deep"))
    # door
    d.rectangle([80, 132, 111, 189], fill=C("green_lo"))
    d.rectangle([84, 136, 107, 189], fill=C("green"))
    d.rectangle([102, 160, 105, 163], fill=C("gold"))
    d.ellipse([86, 142, 105, 157], fill=C("green_deep")); d.ellipse([90, 146, 101, 153], fill=C("green_lo"))  # wreath
    d.rectangle([93, 154, 98, 158], fill=C("red"))
    # windows, lit from inside
    for wx in (36, 128):
        d.rectangle([wx, 120, wx + 27, 147], fill=C("wood_deep"))
        d.rectangle([wx + 3, 123, wx + 24, 144], fill=C("warm_light"))
        d.rectangle([wx + 3, 136, wx + 24, 144], fill=C("glow"))
        d.line([(wx + 13, 123), (wx + 13, 144)], fill=C("wood_deep"), width=2)
        d.line([(wx + 3, 133), (wx + 24, 133)], fill=C("wood_deep"), width=2)
        d.rectangle([wx - 2, 147, wx + 29, 151], fill=C("snow"))
    img = finish(img)
    d = draw(img)
    # snow on roof & chimney
    d.polygon([(2, 92), (96, 20), (190, 92), (180, 98), (150, 80), (130, 90), (96, 64), (60, 90), (30, 82), (12, 98)], fill=C("snow"))
    d.polygon([(2, 92), (96, 20), (96, 64), (60, 90), (30, 82), (12, 98)], fill=C("snow_hi"))
    d.line([(96, 64), (130, 90), (150, 80), (180, 98)], fill=C("snow_mid"), width=2)
    d.rounded_rectangle([124, 12, 155, 24], radius=4, fill=C("snow"))
    d.line([(126, 13), (153, 13)], fill=C("snow_hi"))
    # string lights along the eaves
    for i, x in enumerate(range(16, 180, 10)):
        y = 98 + int(3 * math.sin(i * 1.3))
        d.rectangle([x, y, x + 2, y + 3], fill=C(("red", "gold", "green", "blue")[i % 4]))
    return outline(img, "ink", 1)


def north_pole() -> Image.Image:
    img = new(64, 192); d = draw(img)
    d.rectangle([26, 30, 37, 186], fill=C("snow_hi"))
    for y in range(20, 190, 16):  # red helix stripes
        d.polygon([(26, y + 10), (37, y), (37, y + 7), (26, y + 17)], fill=C("red"))
    d.line([(36, 30), (36, 186)], fill=C("snow_mid"))
    d.ellipse([20, 6, 43, 29], fill=C("gold")); d.ellipse([24, 9, 33, 18], fill=C("gold_hi"))
    # sign
    d.rectangle([4, 62, 59, 84], fill=C("wood"))
    d.line([(4, 63), (59, 63)], fill=C("wood_hi")); d.line([(4, 84), (59, 84)], fill=C("wood_lo"))
    for i, ch in enumerate("NORTH"):  # tiny pixel letters
        _glyph(d, 8 + i * 10, 67, ch, C("snow_hi"))
    d.rectangle([22, 182, 41, 190], fill=C("snow"))
    return finish(img)


GLYPHS = {
    "N": ["X..X", "XX.X", "X.XX", "X..X", "X..X"], "O": [".XX.", "X..X", "X..X", "X..X", ".XX."],
    "R": ["XXX.", "X..X", "XXX.", "X.X.", "X..X"], "T": ["XXXX", ".XX.", ".XX.", ".XX.", ".XX."],
    "H": ["X..X", "X..X", "XXXX", "X..X", "X..X"], "E": ["XXXX", "X...", "XXX.", "X...", "XXXX"],
    "I": ["XXX", ".X.", ".X.", ".X.", "XXX"], "X": ["X..X", "X..X", ".XX.", "X..X", "X..X"],
}


def _glyph(d, x, y, ch, col):
    for gy, row in enumerate(GLYPHS[ch]):
        for gx, c in enumerate(row):
            if c == "X":
                d.rectangle([x + gx * 2, y + gy * 2, x + gx * 2 + 1, y + gy * 2 + 1], fill=col)


def snowman() -> Image.Image:
    img = new(64, 128); d = draw(img)
    d.ellipse([8, 72, 55, 125], fill=C("snow"))
    d.ellipse([14, 38, 49, 76], fill=C("snow"))
    d.ellipse([19, 12, 44, 40], fill=C("snow"))
    for (x0, y0, x1, y1) in ((8, 72, 55, 125), (14, 38, 49, 76), (19, 12, 44, 40)):
        d.chord([x0, y0, x1, y1], 330, 150, fill=C("snow_mid"))
        d.ellipse([x0 + 4, y0 + 3, x0 + (x1 - x0) // 2, y0 + (y1 - y0) // 3], fill=C("snow_hi"))
    d.rectangle([20, 34, 45, 40], fill=C("red"))  # scarf
    d.rectangle([36, 40, 42, 54], fill=C("red_lo"))
    d.line([(20, 35), (45, 35)], fill=C("red_hi"))
    d.rectangle([22, 0, 41, 14], fill=C("coal")); d.rectangle([16, 12, 47, 16], fill=C("coal"))  # hat
    d.rectangle([22, 9, 41, 11], fill=C("red"))
    d.rectangle([26, 22, 28, 24], fill=C("coal")); d.rectangle([35, 22, 37, 24], fill=C("coal"))
    d.polygon([(31, 26), (31, 30), (42, 29)], fill=C("carrot"))
    for y in (50, 60, 86, 98):
        d.rectangle([30, y, 33, y + 3], fill=C("coal"))
    d.line([(14, 52), (2, 40), (0, 42)], fill=C("wood_lo"), width=2)  # stick arms
    d.line([(49, 52), (61, 42)], fill=C("wood_lo"), width=2)
    return finish(img)


def lamp_post() -> Image.Image:
    img = new(64, 128); d = draw(img)
    d.rectangle([28, 34, 35, 122], fill=C("ink_soft"))
    d.line([(29, 34), (29, 122)], fill=C("stone"))
    d.rectangle([22, 116, 41, 126], fill=C("ink_soft"))
    d.polygon([(20, 14), (43, 14), (39, 34), (24, 34)], fill=C("warm_light"))
    d.polygon([(32, 14), (43, 14), (39, 34), (32, 34)], fill=C("glow"))
    d.rectangle([18, 10, 45, 14], fill=C("ink_soft"))
    d.polygon([(22, 10), (41, 10), (32, 2)], fill=C("ink_soft"))
    d.rectangle([20, 34, 43, 37], fill=C("ink_soft"))
    # holly ribbon
    d.rectangle([26, 60, 37, 66], fill=C("red"))
    d.ellipse([23, 55, 30, 62], fill=C("green")); d.ellipse([33, 55, 40, 62], fill=C("green"))
    img = finish(img)
    d = draw(img)
    d.ellipse([18, 0, 45, 8], fill=C("snow"))
    return img


def present(body: str, ribbon: str, w: int = 40, h: int = 30, ox: int = 12, oy: int = 32) -> Image.Image:
    img = new(); d = draw(img)
    pal = {"red": ("red_hi", "red", "red_lo"), "green": ("green_hi", "green", "green_lo"),
           "blue": ("blue_hi", "blue", "blue_lo"), "purple": ("pink", "purple", "purple_lo")}[body]
    d.rectangle([ox, oy, ox + w, oy + h], fill=C(pal[1]))
    d.rectangle([ox, oy, ox + w, oy + 7], fill=C(pal[0]))  # lid
    d.rectangle([ox + w - 6, oy + 8, ox + w, oy + h], fill=C(pal[2]))
    cx = ox + w // 2
    d.rectangle([cx - 3, oy, cx + 3, oy + h], fill=C(ribbon))
    d.rectangle([ox, oy + 3, ox + w, oy + 5], fill=C(ribbon))
    d.ellipse([cx - 13, oy - 9, cx - 1, oy + 1], fill=C(ribbon))
    d.ellipse([cx + 1, oy - 9, cx + 13, oy + 1], fill=C(ribbon))
    d.ellipse([cx - 9, oy - 6, cx - 4, oy - 2], fill=C(pal[2])); d.ellipse([cx + 4, oy - 6, cx + 9, oy - 2], fill=C(pal[2]))
    return img


def present_stack() -> Image.Image:
    img = present("green", C("gold"), 46, 26, 9, 36)
    img.alpha_composite(present("purple", C("snow_hi"), 28, 18, 18, 12).crop((0, 0, 64, 34)), (0, 0))
    return finish(img)


def candy_cane_deco() -> Image.Image:
    img = new(); d = draw(img)
    d.arc([18, 4, 44, 30], 180, 360, fill=C("snow_hi"), width=8)
    d.rectangle([37, 16, 44, 62], fill=C("snow_hi"))
    for y in range(18, 62, 10):
        d.polygon([(37, y + 6), (44, y), (44, y + 4), (37, y + 10)], fill=C("red"))
    for a in (200, 250, 300):
        x = 31 + 11 * math.cos(math.radians(a)); y = 17 + 11 * math.sin(math.radians(a))
        d.ellipse([x - 3, y - 3, x + 3, y + 3], fill=C("red"))
    d.ellipse([12, 56, 52, 64], fill=C("snow"))
    return finish(img)


def signpost() -> Image.Image:
    img = new(); d = draw(img)
    d.rectangle([28, 22, 35, 62], fill=C("wood_lo"))
    d.polygon([(6, 12), (48, 12), (58, 22), (48, 32), (6, 32)], fill=C("wood"))
    d.line([(6, 13), (48, 13)], fill=C("wood_hi"))
    d.polygon([(20, 18), (32, 18), (32, 14), (40, 22), (32, 30), (32, 26), (20, 26)], fill=C("snow_hi"))
    img = finish(img); d = draw(img)
    d.rounded_rectangle([4, 7, 50, 13], radius=3, fill=C("snow"))
    d.ellipse([18, 56, 46, 64], fill=C("snow"))
    return img


def wreath() -> Image.Image:
    img = new(); d = draw(img)
    d.ellipse([6, 6, 57, 57], fill=C("green_lo"))
    r = rng(5)
    for _ in range(90):
        a = r.random() * 2 * math.pi; rr = r.uniform(15, 24)
        x, y = 32 + rr * math.cos(a), 32 + rr * math.sin(a)
        d.rectangle([x - 1, y - 1, x + 1, y], fill=C(r.choice(["green", "green_hi", "green_deep"])))
    d.ellipse([19, 19, 44, 44], fill=(0, 0, 0, 0))
    for a in (0.3, 1.4, 2.6, 3.5, 4.4, 5.6):
        x, y = 32 + 20 * math.cos(a), 32 + 20 * math.sin(a)
        d.ellipse([x - 3, y - 3, x + 3, y + 3], fill=C("red")); d.point((x - 1, y - 1), fill=C("red_hi"))
    d.polygon([(22, 50), (32, 46), (42, 50), (44, 62), (32, 52), (20, 62)], fill=C("red"))
    d.ellipse([28, 45, 36, 53], fill=C("red_lo"))
    return finish(img)


def stocking() -> Image.Image:
    img = new(); d = draw(img)
    d.polygon([(20, 14), (40, 14), (40, 44), (46, 50), (44, 58), (24, 58), (16, 50), (20, 40)], fill=C("red"))
    d.polygon([(32, 14), (40, 14), (40, 44), (46, 50), (44, 58), (36, 58)], fill=C("red_lo"))
    d.rectangle([16, 6, 44, 16], fill=C("snow"))
    d.line([(16, 7), (44, 7)], fill=C("snow_hi"))
    d.ellipse([14, 48, 26, 58], fill=C("snow"))
    d.polygon(star_points(30, 32, 6, 3), fill=C("gold"))
    d.rectangle([28, 0, 31, 6], fill=C("gold_lo"))
    return finish(img)


def holly() -> Image.Image:
    img = new(); d = draw(img)
    for (pts, col) in (([(10, 40), (20, 30), (30, 36), (26, 46), (16, 50)], "green"),
                       ([(54, 40), (44, 30), (34, 36), (38, 46), (48, 50)], "green_lo"),
                       ([(24, 20), (32, 10), (40, 20), (38, 32), (26, 32)], "green_hi")):
        d.polygon(pts, fill=C(col))
    for (x, y) in ((28, 34), (36, 34), (32, 40)):
        d.ellipse([x - 5, y - 5, x + 5, y + 5], fill=C("red")); d.point((x - 2, y - 2), fill=C("red_hi"))
    return finish(img)


def bell_shape(d, cx, cy, ang=0.0, s=1.0):
    def rot(px, py):
        ca, sa = math.cos(ang), math.sin(ang)
        return (cx + (px * ca - py * sa) * s, cy + (px * sa + py * ca) * s)
    body = [rot(*p) for p in ((-4, -14), (4, -14), (9, -6), (11, 6), (16, 12), (-16, 12), (-11, 6), (-9, -6))]
    d.polygon(body, fill=C("gold"))
    d.polygon([rot(*p) for p in ((4, -14), (9, -6), (11, 6), (16, 12), (6, 12), (5, -12))], fill=C("gold_lo"))
    d.polygon([rot(*p) for p in ((-3, -12), (-2, -12), (-6, 6), (-8, 6))], fill=C("gold_hi"))
    cl = rot(0, 15); d.ellipse([cl[0] - 3, cl[1] - 3, cl[0] + 3, cl[1] + 3], fill=C("gold_mid"))
    tp = rot(0, -16); d.ellipse([tp[0] - 3, tp[1] - 3, tp[0] + 3, tp[1] + 3], fill=C("gold_lo"))


def bell_deco() -> Image.Image:
    img = new(); d = draw(img)
    bell_shape(d, 32, 34, 0, 1.2)
    d.polygon([(22, 12), (32, 16), (42, 12), (40, 22), (32, 18), (24, 22)], fill=C("red"))
    return finish(img)


def snowy_bush() -> Image.Image:
    img = new(); d = draw(img)
    for (x0, y0, x1, y1) in ((4, 30, 30, 62), (20, 22, 48, 62), (36, 32, 60, 62)):
        d.ellipse([x0, y0, x1, y1], fill=C("green_lo"))
        d.ellipse([x0 + 3, y0 + 3, x1 - 8, y1 - 10], fill=C("green"))
    for (x, y) in ((14, 44), (40, 40), (28, 50)):
        d.ellipse([x - 2, y - 2, x + 2, y + 2], fill=C("red"))
    img = finish(img); d = draw(img)
    d.ellipse([8, 26, 28, 36], fill=C("snow")); d.ellipse([22, 18, 46, 30], fill=C("snow_hi")); d.ellipse([38, 28, 58, 38], fill=C("snow"))
    return img


def gingerbread_man() -> Image.Image:
    img = new(); d = draw(img)
    d.ellipse([22, 4, 42, 24], fill=C("ginger"))
    d.rounded_rectangle([20, 22, 44, 46], radius=6, fill=C("ginger"))
    d.line([(22, 28), (8, 36)], fill=C("ginger"), width=8); d.line([(42, 28), (56, 36)], fill=C("ginger"), width=8)
    d.line([(26, 44), (18, 60)], fill=C("ginger"), width=9); d.line([(38, 44), (46, 60)], fill=C("ginger"), width=9)
    for (x, y) in ((27, 12), (35, 12)):
        d.rectangle([x, y, x + 2, y + 2], fill=C("ink"))
    d.arc([26, 12, 38, 20], 20, 160, fill=C("snow_hi"), width=1)
    for y in (28, 35):
        d.ellipse([30, y, 34, y + 4], fill=C("red" if y == 28 else "green"))
    d.line([(8, 36), (12, 32)], fill=C("snow_hi")); d.line([(52, 32), (56, 36)], fill=C("snow_hi"))
    d.line([(16, 58), (22, 58)], fill=C("snow_hi")); d.line([(42, 58), (48, 58)], fill=C("snow_hi"))
    return finish(img)


def snowy_rock() -> Image.Image:
    img = new(); d = draw(img)
    d.polygon([(6, 62), (10, 40), (24, 28), (44, 30), (58, 44), (60, 62)], fill=C("stone"))
    d.polygon([(34, 30), (44, 30), (58, 44), (60, 62), (40, 62)], fill=C("stone_lo"))
    d.line([(20, 46), (28, 40)], fill=C("stone_hi"), width=2)
    img = finish(img); d = draw(img)
    d.polygon([(10, 40), (24, 26), (44, 28), (52, 38), (40, 36), (30, 40), (18, 42)], fill=C("snow"))
    return img


def snow_pile() -> Image.Image:
    img = new(); d = draw(img)
    d.ellipse([2, 40, 40, 70], fill=C("snow")); d.ellipse([22, 34, 62, 70], fill=C("snow"))
    d.ellipse([8, 44, 24, 52], fill=C("snow_hi")); d.ellipse([30, 38, 46, 46], fill=C("snow_hi"))
    d.rectangle([0, 60, 63, 63], fill=C("snow_mid"))
    return finish(img)


def icicles_deco() -> Image.Image:
    img = new(); d = draw(img)
    r = rng(14)
    for x in range(4, 62, 7):
        h = r.randint(8, 30)
        d.polygon([(x - 3, 0), (x + 3, 0), (x, h)], fill=C("ice_hi"))
        d.line([(x + 1, 1), (x + 1, h * 2 // 3)], fill=C("ice_mid"))
    return outline(img, "ink", 1)


def fence(kind: str) -> Image.Image:
    img = new(); d = draw(img)
    posts = {"L": [8, 40], "M": [8, 40], "R": [8, 40]}[kind]
    x0 = 6 if kind == "L" else 0
    x1 = 58 if kind == "R" else 63
    d.rectangle([x0, 34, x1, 39], fill=C("wood")); d.rectangle([x0, 50, x1, 55], fill=C("wood"))
    d.line([(x0, 34), (x1, 34)], fill=C("wood_hi")); d.line([(x0, 50), (x1, 50)], fill=C("wood_hi"))
    for px in posts:
        d.polygon([(px, 24), (px + 6, 18), (px + 12, 24), (px + 12, 62), (px, 62)], fill=C("wood"))
        d.line([(px + 11, 24), (px + 11, 62)], fill=C("wood_lo"))
    img = finish(img); d = draw(img)
    for px in posts:
        d.polygon([(px - 1, 22), (px + 6, 15), (px + 13, 22)], fill=C("snow"))
    d.line([(x0, 33), (x1, 33)], fill=C("snow"), width=2)
    return img


def string_lights(frame: int) -> Image.Image:
    img = new(); d = draw(img)
    x = np.arange(TILE)
    sag = 10 + np.round(6 * np.sin(np.pi * x / TILE)).astype(int)  # 0 at both edges: joins seamlessly
    for i in range(TILE - 1):
        d.line([(i, sag[i]), (i + 1, sag[i + 1])], fill=C("ink_soft"))
    cols = ["red", "gold", "green", "blue"]
    for k, bx in enumerate((8, 24, 40, 56)):
        by = sag[bx] + 2
        on = (k + frame) % 2 == 0
        col = cols[k]
        if on:
            d.ellipse([bx - 6, by - 2, bx + 6, by + 10], fill=PAL[col][:3] + (90,))
        d.rectangle([bx - 1, by - 1, bx + 1, by], fill=C("ink_soft"))
        d.ellipse([bx - 3, by, bx + 3, by + 7], fill=C(col if on else col + "_lo" if col + "_lo" in PAL else "gold_lo"))
        if on:
            d.point((bx - 1, by + 2), fill=C("snow_hi"))
    return img


def build_decorations():
    cols, rows = 8, 6
    sh = new(cols * TILE, rows * TILE)
    tiles = {}

    def put(c, r, img, name, w=1, h=1, **data):
        sh.alpha_composite(img, (c * TILE, r * TILE))
        tiles[name] = dict(col=c, row=r, w=w, h=h, **data)

    put(0, 0, xmas_tree(), "christmas_tree", 2, 3)
    put(2, 0, pine_tree(), "pine_tree", 2, 3)
    put(4, 0, cabin(), "cabin", 3, 3)
    put(7, 0, north_pole(), "north_pole_sign", 1, 3, goal=True)
    put(0, 3, snowman(), "snowman", 1, 2)
    put(1, 3, lamp_post(), "lamp_post", 1, 2)
    put(2, 3, finish(present("red", C("gold"))), "present_red")
    put(3, 3, finish(present("green", C("red"))), "present_green")
    put(4, 3, finish(present("blue", C("snow_hi"))), "present_blue")
    put(5, 3, present_stack(), "present_stack")
    put(6, 3, candy_cane_deco(), "candy_cane")
    put(7, 3, signpost(), "signpost")
    put(2, 4, wreath(), "wreath")
    put(3, 4, stocking(), "stocking")
    put(4, 4, holly(), "holly")
    put(5, 4, bell_deco(), "bell")
    put(6, 4, snowy_bush(), "snowy_bush")
    put(7, 4, gingerbread_man(), "gingerbread_man")
    put(0, 5, snowy_rock(), "snowy_rock")
    put(1, 5, snow_pile(), "snow_pile")
    put(2, 5, icicles_deco(), "icicles_hanging")
    put(3, 5, fence("L"), "fence_L")
    put(4, 5, fence("M"), "fence_M")
    put(5, 5, fence("R"), "fence_R")
    put(6, 5, string_lights(0), "string_lights", frames=2, fps=2)
    sh.alpha_composite(string_lights(1), (7 * TILE, 5 * TILE))
    sh.save(ROOT / "tiles/decorations.png")
    return tiles


# =================================================================== PICKUPS (animated)
FRAMES = 6


def item_star(f):
    img = new(); d = draw(img)
    sx = math.cos(f / FRAMES * math.pi)  # spins: full width -> edge-on -> back
    sx = max(0.18, abs(sx))
    d.polygon(star_points(32, 33, 20, 9, sx=sx), fill=C("gold"))
    d.polygon(star_points(32 - 2 * sx, 31, 10, 4, sx=sx), fill=C("gold_hi"))
    d.polygon([(32, 33)] + star_points(32, 33, 20, 9, sx=sx)[3:6], fill=C("gold_mid"))
    return finish(img)


def item_present(f):
    bob = round(3 * math.sin(f / FRAMES * 2 * math.pi))
    img = new()
    img.alpha_composite(present("red", C("gold"), 32, 24, 16, 28 + bob))
    img = finish(img)
    if f in (1, 2):  # glint
        d = draw(img); x, y = 22 + f * 6, 30 + bob
        d.line([(x, y - 3), (x, y + 3)], fill=C("snow_hi")); d.line([(x - 3, y), (x + 3, y)], fill=C("snow_hi"))
    return img


def item_candy(f):
    bob = round(3 * math.sin(f / FRAMES * 2 * math.pi))
    img = new(); d = draw(img)
    d.arc([18, 8 + bob, 38, 28 + bob], 180, 360, fill=C("snow_hi"), width=6)
    d.rectangle([33, 17 + bob, 38, 56 + bob], fill=C("snow_hi"))
    for y in range(18, 56, 8):
        d.polygon([(33, y + 5 + bob), (38, y + bob), (38, y + 3 + bob), (33, y + 8 + bob)], fill=C("red"))
    d.ellipse([18, 14 + bob, 24, 20 + bob], fill=C("red"))
    return finish(img)


def item_bauble(f):
    img = new(); d = draw(img)
    d.ellipse([14, 18, 50, 54], fill=C("blue"))
    d.chord([14, 18, 50, 54], 20, 160, fill=C("blue_lo"))
    d.rectangle([26, 10, 37, 18], fill=C("gold")); d.line([(26, 11), (37, 11)], fill=C("gold_hi"))
    d.arc([28, 4, 35, 12], 180, 360, fill=C("gold_lo"), width=2)
    d.line([(16, 36), (48, 36)], fill=C("snow_hi"), width=2)
    sweep = 18 + f * 5  # highlight sweeps across
    d.ellipse([sweep, 24, sweep + 6, 32], fill=C("blue_hi"))
    d.rectangle([sweep + 1, 25, sweep + 2, 27], fill=C("snow_hi"))
    return finish(img)


def item_cookie(f):
    bob = round(3 * math.sin(f / FRAMES * 2 * math.pi))
    img = gingerbread_man().resize((48, 48), Image.NEAREST)
    out = new(); out.alpha_composite(img, (8, 8 + bob))
    return out


def item_bell(f):
    ang = math.radians(25) * math.sin(f / FRAMES * 2 * math.pi)
    img = new(); d = draw(img)
    bell_shape(d, 32, 32, ang, 1.15)
    return finish(img)


def item_heart(f):
    s = 1.0 + 0.12 * math.sin(f / FRAMES * 2 * math.pi)
    img = new(); d = draw(img)
    pts = []
    for i in range(48):
        t = i / 48 * 2 * math.pi
        x = 16 * math.sin(t) ** 3
        y = -(13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))
        pts.append((32 + x * s, 32 + y * s))
    d.polygon(pts, fill=C("red"))
    d.ellipse([20, 22, 28, 30], fill=C("red_hi")); d.rectangle([21, 23, 23, 25], fill=C("snow_hi"))
    return finish(img)


def item_snowflake(f):
    img = new(); d = draw(img)
    base = f / FRAMES * (math.pi / 3)
    for a in range(6):
        ang = base + a * math.pi / 3
        x2, y2 = 32 + 20 * math.cos(ang), 32 + 20 * math.sin(ang)
        d.line([(32, 32), (x2, y2)], fill=C("ice_hi"), width=3)
        for k in (9, 15):
            mx, my = 32 + k * math.cos(ang), 32 + k * math.sin(ang)
            for s in (-1, 1):
                b = ang + s * math.pi / 3.5
                d.line([(mx, my), (mx + 5 * math.cos(b), my + 5 * math.sin(b))], fill=C("ice_hi"), width=2)
    d.ellipse([28, 28, 36, 36], fill=C("snow_hi"))
    return outline(img, "ice_lo", 1)


def item_sparkle(f):
    """Collect effect: a ring of stars bursting outwards (play once, then free)."""
    img = new(); d = draw(img)
    t = (f + 1) / FRAMES
    rad = 6 + 22 * t
    size = max(1, round(5 * (1 - t)) + 1)
    for k in range(8):
        a = k * math.pi / 4
        x, y = 32 + rad * math.cos(a), 32 + rad * math.sin(a)
        col = C("gold_hi") if k % 2 == 0 else C("snow_hi")
        d.polygon(star_points(x, y, size + 2, max(1, size // 2), n=4, rot=0), fill=col)
    if f < 2:
        d.ellipse([32 - 8 + f * 3, 32 - 8 + f * 3, 32 + 8 - f * 3, 32 + 8 - f * 3], fill=C("snow_hi"))
    return img


ITEMS = [("star", item_star, 10, True), ("present", item_present, 8, True), ("candy_cane", item_candy, 8, True),
         ("bauble", item_bauble, 8, True), ("cookie", item_cookie, 8, True), ("bell", item_bell, 8, True),
         ("heart", item_heart, 8, True), ("snowflake", item_snowflake, 8, True), ("sparkle", item_sparkle, 14, False)]


def build_items():
    sh = new(FRAMES * TILE, len(ITEMS) * TILE)
    meta = []
    for row, (name, fn, fps, loop) in enumerate(ITEMS):
        for f in range(FRAMES):
            sh.alpha_composite(fn(f), (f * TILE, row * TILE))
        meta.append(dict(name=name, row=row, frames=FRAMES, fps=fps, loop=loop))
    sh.save(ROOT / "tiles/pickups.png")
    return meta


# =================================================================== TEST PLAYER (elf)
def elf(leg_a: float, leg_b: float, bob: int = 0, arms: float = 0.0, squash: int = 0) -> Image.Image:
    """A small elf drawn from shapes. leg_a/leg_b: foot x offsets (run cycle), arms: swing."""
    img = new(); d = draw(img)
    hip_y = 44 + bob
    for off, col in ((leg_b, "green_lo"), (leg_a, "green")):  # back leg darker
        fx = 32 + off
        d.line([(32, hip_y), (fx, 58)], fill=C(col), width=6)
        d.rounded_rectangle([fx - 4, 56, fx + 6, 61], radius=2, fill=C("red_lo"))
    d.rounded_rectangle([22, 26 + bob + squash, 42, 47 + bob], radius=5, fill=C("green"))  # tunic
    d.rectangle([22, 40 + bob, 42, 43 + bob], fill=C("ink_soft"))  # belt
    d.rectangle([30, 40 + bob, 34, 43 + bob], fill=C("gold"))
    d.line([(23, 28 + bob), (23, 44 + bob)], fill=C("green_hi"))
    ax = round(6 * arms)
    d.line([(26, 30 + bob), (20 - ax, 40 + bob)], fill=C("green_lo"), width=5)
    d.line([(38, 30 + bob), (44 + ax, 40 + bob)], fill=C("green_lo"), width=5)
    d.ellipse([17 - ax, 38 + bob, 23 - ax, 44 + bob], fill=C("skin")); d.ellipse([41 + ax, 38 + bob, 47 + ax, 44 + bob], fill=C("skin"))
    hy = 12 + bob + squash
    d.ellipse([22, hy, 42, hy + 18], fill=C("skin"))  # head
    d.polygon([(40, hy + 6), (49, hy + 2), (42, hy + 11)], fill=C("skin"))  # pointy ear (facing right)
    d.rectangle([36, hy + 7, 38, hy + 10], fill=C("ink"))  # eye
    d.rectangle([39, hy + 12, 41, hy + 13], fill=C("red_hi"))  # rosy cheek
    d.polygon([(20, hy + 5), (44, hy + 5), (34, hy - 10), (14, hy - 4)], fill=C("red"))  # hat
    d.rectangle([20, hy + 3, 44, hy + 7], fill=C("snow_hi"))
    d.ellipse([9, hy - 9, 17, hy - 1], fill=C("snow_hi"))  # bobble
    return finish(img)


def build_player():
    frames = [
        ("idle", [elf(-3, 3), elf(-3, 3, bob=1, squash=1)], 3, True),
        ("run", [elf(8, -8, 0, 1), elf(2, -2, -2, 0.3), elf(-8, 8, 0, -1), elf(-2, 2, -2, -0.3)], 10, True),
        ("jump", [elf(6, -4, -1, 1.4)], 1, False),
        ("fall", [elf(-4, 5, 0, -1.4)], 1, False),
        ("climb", [elf(-3, 3, 0, 1.2), elf(3, -3, 0, -1.2)], 6, True),
    ]
    total = sum(len(f) for _, f, _, _ in frames)
    sh = new(total * TILE, TILE)
    meta, i = [], 0
    for name, imgs, fps, loop in frames:
        meta.append(dict(name=name, start=i, frames=len(imgs), fps=fps, loop=loop))
        for im in imgs:
            sh.alpha_composite(im, (i * TILE, 0)); i += 1
    sh.save(ROOT / "tiles/player_elf.png")
    return meta


# =================================================================== BACKGROUNDS
BW, BH = 1280, 720


def bg_sky():
    img = Image.new("RGBA", (BW, BH), C("sky0"))
    a = np.array(img)
    bands = ["sky0", "sky1", "sky2", "sky3", "sky4"]
    yy, xx = np.mgrid[0:BH, 0:BW]
    t = yy / BH * (len(bands) - 1)
    bayer = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0
    thr = bayer[yy % 4, xx % 4]
    idx = np.floor(t + (thr - 0.5) * 0.9 + 0.5).clip(0, len(bands) - 1).astype(int)  # ordered dither between bands
    for i, b in enumerate(bands):
        a[idx == i] = PAL[b]
    img = Image.fromarray(a); d = draw(img)
    r = rng(99)
    for _ in range(260):
        x, y = r.randrange(BW), r.randrange(int(BH * 0.7))
        if r.random() < 0.12:
            d.line([(x - 2, y), (x + 2, y)], fill=C("star")); d.line([(x, y - 2), (x, y + 2)], fill=C("star"))
        else:
            d.point((x, y), fill=C(r.choice(["star", "sky4", "snow_mid"])))
    # moon
    sky_before = img.copy()
    d.ellipse([980, 70, 1080, 170], fill=C("gold_hi"))
    d.ellipse([990, 80, 1030, 120], fill=C("gold"))
    bite = Image.new("L", (BW, BH), 0)
    draw(bite).ellipse([1004, 60, 1104, 160], fill=255)
    img.paste(sky_before, (0, 0), bite)  # the bite shows the real (dithered) sky behind
    d = draw(img)
    # a gentle aurora ribbon
    for x in range(0, BW, 2):
        y = 210 + 40 * math.sin(x / 170) + 18 * math.sin(x / 61)
        h = 30 + 16 * math.sin(x / 90)
        for k in range(int(h)):
            if (x // 2 + k) % 3 == 0:
                img.putpixel((x, int(y + k)), C("green_lo") if k > h * 0.4 else C("green"))
    return img


def ridge(period_terms, base, amp_scale=1.0):
    x = np.arange(BW)
    return base + amp_scale * periodic(x, period_terms, period=BW)


def bg_mountains():
    img = new(BW, BH); d = draw(img)
    x = np.arange(BW)
    # |sin| makes sharp cusps; with y pointing down those cusps are the peaks.
    top = (300 + 150 * np.abs(np.sin(np.pi * 4 * x / BW + 0.3)) + 60 * np.abs(np.sin(np.pi * 7 * x / BW + 1.1))
           + periodic(x, [(23, 4, 0.5), (41, 2, 1.0)], period=BW))
    snowline = 400 + periodic(x, [(9, 12, 0.2), (31, 5, 2.0)], period=BW)
    for xi in range(BW):
        y = int(top[xi])
        lit = top[(xi + 1) % BW] < top[xi]  # slope rising to the right faces the moon
        d.line([(xi, y), (xi, BH)], fill=C("sky3") if lit else C("sky2"))
        if y < snowline[xi]:
            d.line([(xi, y), (xi, int(snowline[xi]))], fill=C("snow_mid") if lit else C("snow_lo"))
    return img


def bg_hills():
    img = new(BW, BH); d = draw(img)
    top = ridge([(2, 30, 1.0), (7, 14, 0.3), (13, 6, 1.7)], 520)
    for x in range(BW):
        y = int(top[x])
        d.line([(x, y), (x, BH)], fill=C("sky1"))
        d.line([(x, y), (x, y + 3)], fill=C("snow_lo"))
    r = rng(4)
    for i in range(46):  # pine silhouettes (spaced on a wrap-safe grid)
        x = i * (BW // 46) + r.randint(0, 12)
        base = int(top[x % BW]) + 6
        h = r.randint(44, 90)
        w = h // 3
        d.polygon([(x, base - h), (x + w, base), (x - w, base)], fill=C("sky0"))
        d.polygon([(x, base - h), (x + w // 2, base - h // 2), (x - w // 2, base - h // 2)], fill=C("sky2"))
    for hx in (250, 760, 1110):  # far-off cottages with lit windows
        base = int(top[hx]) + 4
        d.rectangle([hx - 16, base - 18, hx + 16, base], fill=C("sky0"))
        d.polygon([(hx - 20, base - 18), (hx, base - 34), (hx + 20, base - 18)], fill=C("sky0"))
        d.rectangle([hx - 8, base - 12, hx - 3, base - 7], fill=C("glow"))
        d.rectangle([hx + 4, base - 12, hx + 9, base - 7], fill=C("glow"))
    return img


def build_backgrounds():
    flake = new(8, 8); d = draw(flake)  # falling-snow particle
    d.rectangle([2, 1, 5, 6], fill=C("snow_hi")); d.rectangle([1, 2, 6, 5], fill=C("snow_hi"))
    d.rectangle([3, 3, 4, 4], fill=C("snow"))
    flake.save(ROOT / "backgrounds/snow_particle.png")
    bg_sky().convert("RGB").save(ROOT / "backgrounds/bg_sky.png")
    bg_mountains().save(ROOT / "backgrounds/bg_mountains.png")
    bg_hills().save(ROOT / "backgrounds/bg_hills.png")


if __name__ == "__main__":
    meta = {"platforms": build_platforms(), "decorations": build_decorations(), "pickups": build_items(), "player": build_player()}
    build_backgrounds()
    (ROOT / "tools/props_meta.json").write_text(json.dumps(meta, indent=1))
    print("props written")
