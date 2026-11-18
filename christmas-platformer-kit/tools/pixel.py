"""Shared pixel-art helpers for the Christmas platformer kit generators.

Everything is drawn with hard edges (no anti-aliasing) from one fixed palette,
so every sheet in the kit sits together visually. Change a colour here and
re-run the generators to re-skin the whole kit.
"""
from __future__ import annotations

import math
import random

import numpy as np
from PIL import Image, ImageDraw

TILE = 64

# One shared palette. Names, not raw hex, are used everywhere else.
PAL = {
    "clear": (0, 0, 0, 0),
    "ink": (26, 28, 44, 255),          # universal outline
    "ink_soft": (51, 60, 87, 255),     # inner lines
    # snow
    "snow_hi": (255, 255, 255, 255),
    "snow": (228, 240, 251, 255),
    "snow_mid": (184, 212, 236, 255),
    "snow_lo": (138, 174, 214, 255),
    # ice
    "ice_hi": (215, 246, 255, 255),
    "ice": (158, 228, 245, 255),
    "ice_mid": (95, 195, 228, 255),
    "ice_lo": (58, 143, 192, 255),
    "ice_deep": (39, 95, 143, 255),
    # frozen earth
    "earth_hi": (138, 98, 72, 255),
    "earth": (107, 74, 58, 255),
    "earth_lo": (77, 51, 40, 255),
    "earth_deep": (51, 34, 28, 255),
    "stone_hi": (164, 176, 188, 255),
    "stone": (125, 138, 150, 255),
    "stone_lo": (90, 100, 112, 255),
    # gingerbread
    "ginger_hi": (224, 160, 96, 255),
    "ginger": (200, 128, 62, 255),
    "ginger_lo": (163, 95, 43, 255),
    "ginger_deep": (122, 67, 32, 255),
    # brick
    "brick_hi": (196, 92, 76, 255),
    "brick": (160, 64, 58, 255),
    "brick_lo": (118, 44, 48, 255),
    "mortar": (196, 184, 172, 255),
    "mortar_lo": (150, 138, 132, 255),
    # festive colours
    "red_hi": (255, 122, 107, 255),
    "red": (232, 59, 59, 255),
    "red_lo": (176, 43, 56, 255),
    "red_deep": (110, 28, 44, 255),
    "green_hi": (127, 212, 106, 255),
    "green": (63, 163, 77, 255),
    "green_lo": (36, 115, 74, 255),
    "green_deep": (22, 74, 58, 255),
    "gold_hi": (255, 244, 184, 255),
    "gold": (255, 215, 94, 255),
    "gold_mid": (242, 169, 59, 255),
    "gold_lo": (194, 112, 40, 255),
    "blue_hi": (140, 190, 255, 255),
    "blue": (74, 120, 220, 255),
    "blue_lo": (46, 72, 160, 255),
    "purple": (150, 90, 200, 255),
    "purple_lo": (100, 56, 150, 255),
    "pink": (255, 158, 200, 255),
    "wood_hi": (192, 138, 85, 255),
    "wood": (156, 107, 64, 255),
    "wood_lo": (115, 73, 44, 255),
    "wood_deep": (78, 48, 32, 255),
    "skin": (245, 196, 156, 255),
    "skin_lo": (217, 154, 116, 255),
    "coal": (40, 40, 52, 255),
    "carrot": (245, 130, 40, 255),
    "warm_light": (255, 236, 160, 255),
    "glow": (255, 200, 90, 255),
    # night sky
    "sky0": (15, 21, 48, 255),
    "sky1": (28, 37, 82, 255),
    "sky2": (46, 58, 120, 255),
    "sky3": (74, 90, 168, 255),
    "sky4": (110, 128, 196, 255),
    "star": (255, 251, 230, 255),
}


def C(name) -> tuple:
    """Palette lookup by name; an RGBA tuple passes straight through."""
    return name if isinstance(name, tuple) else PAL[name]


def new(w: int = TILE, h: int = TILE) -> Image.Image:
    return Image.new("RGBA", (w, h), PAL["clear"])


def draw(img: Image.Image) -> ImageDraw.ImageDraw:
    # ImageDraw on RGBA with solid fills never anti-aliases: ideal for pixel art.
    return ImageDraw.Draw(img)


def alpha(img: Image.Image) -> np.ndarray:
    return np.array(img)[:, :, 3] > 0


def outline(img: Image.Image, color: str = "ink", width: int = 2, corners: bool = False) -> Image.Image:
    """Add an outline *outside* the opaque shape. Corners=False gives the softer
    'pixel' outline (no diagonal neighbours), which reads better at small sizes."""
    arr = np.array(img)
    solid = arr[:, :, 3] > 0
    grown = solid.copy()
    for _ in range(width):
        g = grown.copy()
        g[1:, :] |= grown[:-1, :]
        g[:-1, :] |= grown[1:, :]
        g[:, 1:] |= grown[:, :-1]
        g[:, :-1] |= grown[:, 1:]
        if corners:
            g[1:, 1:] |= grown[:-1, :-1]
            g[:-1, :-1] |= grown[1:, 1:]
            g[1:, :-1] |= grown[:-1, 1:]
            g[:-1, 1:] |= grown[1:, :-1]
        grown = g
    ring = grown & ~solid
    arr[ring] = PAL[color]
    return Image.fromarray(arr)


def inner_outline(img: Image.Image, color: str = "ink", width: int = 2) -> Image.Image:
    """Recolour the outermost `width` pixels of the shape (keeps the footprint)."""
    arr = np.array(img)
    solid = arr[:, :, 3] > 0
    core = solid.copy()
    for _ in range(width):
        c = core.copy()
        c[1:, :] &= core[:-1, :]
        c[:-1, :] &= core[1:, :]
        c[:, 1:] &= core[:, :-1]
        c[:, :-1] &= core[:, 1:]
        c[0, :] = c[-1, :] = False
        c[:, 0] = c[:, -1] = False
        core = c
    arr[solid & ~core] = PAL[color]
    return Image.fromarray(arr)


def paste(dst: Image.Image, src: Image.Image, x: int, y: int) -> None:
    dst.alpha_composite(src, (x, y))


def recolor_mask(img: Image.Image, mask: np.ndarray, color: str) -> Image.Image:
    arr = np.array(img)
    arr[mask & (arr[:, :, 3] > 0)] = PAL[color]
    return Image.fromarray(arr)


def shade_side(img: Image.Image, light: str, dark: str, band: int = 3) -> Image.Image:
    """Cheap form shading for a flat silhouette: a light band on the top-left
    inner edge and a dark band on the bottom-right, ignoring the outline colour."""
    arr = np.array(img)
    solid = (arr[:, :, 3] > 0) & ~np.all(arr == PAL["ink"], axis=2)
    h, w = solid.shape
    lit = np.zeros_like(solid)
    shd = np.zeros_like(solid)
    for k in range(1, band + 1):
        up = np.zeros_like(solid); up[k:, :] = solid[:-k, :]
        left = np.zeros_like(solid); left[:, k:] = solid[:, :-k]
        down = np.zeros_like(solid); down[:-k, :] = solid[k:, :]
        right = np.zeros_like(solid); right[:, :-k] = solid[:, k:]
        lit |= solid & (~up | ~left)
        shd |= solid & (~down | ~right)
    arr[shd & ~lit] = PAL[dark]
    arr[lit & ~shd] = PAL[light]
    return Image.fromarray(arr)


def rng(seed: int) -> random.Random:
    return random.Random(seed)


def periodic(x: np.ndarray | float, terms: list[tuple[int, float, float]], period: int = TILE):
    """Sum of sines with integer frequencies: guaranteed to wrap at `period`, so
    edges drawn with it line up across neighbouring tiles."""
    total = 0.0
    for freq, amp, phase in terms:
        total = total + amp * np.sin(2 * math.pi * freq * np.asarray(x) / period + phase)
    return total


def sheet(cols: int, rows: int, tile: int = TILE) -> Image.Image:
    return new(cols * tile, rows * tile)
