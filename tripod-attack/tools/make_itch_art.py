#!/usr/bin/env python3
"""Draws the itch.io cover (630x500), the store icon (512x512), an Instagram square and an X card
in the game's vector style.

    python3 tools/make_itch_art.py

Writes launch/out/cover_630x500.png and launch/out/icon_512.png. Needs Pillow; reuses the
drawing helpers from make_reel.py (DotGothic16 font from the Neon Mega Tank folder).
"""
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_reel import AMBER, DIM, GREEN, RED, WHITE, neon_text, tripod_icon  # noqa: E402
from brand import draw_lockup  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "launch", "out"))


def scanlines(img, shade=16):
    d = ImageDraw.Draw(img)
    for y in range(0, img.height, 3):
        d.line([(0, y), (img.width, y)], fill=(shade, shade, shade, 255), width=1)


def ground_and_skyline(img, y):
    d = ImageDraw.Draw(img)
    w = img.width
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    ld.line([(0, y), (w, y)], fill=GREEN, width=2)
    # ruined skyline
    import random
    random.seed(7)
    x = 10
    while x < w:
        bw = random.randint(18, 46)
        bh = random.randint(14, 60)
        pts = [(x, y), (x, y - bh)]
        n = random.randint(2, 4)
        for i in range(1, n + 1):
            px = x + bw * i / n
            pts.append((px, y - bh + (0 if random.random() < 0.5 else random.random() * bh * 0.5)))
        pts.append((x + bw, y))
        ld.line(pts, fill=DIM, width=1)
        x += bw + random.randint(14, 40)
    for x in range(0, w, 36):
        ld.line([(x, y + 6), (x - 7, y + 13)], fill=(19, 90, 34), width=1)
    img.alpha_composite(layer)


def cover():
    W, H = 630, 500
    img = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    scanlines(img)
    ground_and_skyline(img, 440)
    # the machine on the right, legs down to the ground
    tripod_icon(img, 470, 250, 1.05, GREEN, 4)
    # red beam from the lens to the ground on the left
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.line([(470 - 27 * 1.05, 250 - 4 * 1.05), (120, 440)], fill=RED + (90,), width=14)
    d.line([(470 - 27 * 1.05, 250 - 4 * 1.05), (120, 440)], fill=RED + (230,), width=4)
    d.line([(470 - 27 * 1.05, 250 - 4 * 1.05), (120, 440)], fill=WHITE + (255,), width=1)
    img.alpha_composite(layer)
    neon_text(img, "TRIPOD", (40, 70), 92, GREEN, anchor="lm", glow=14)
    neon_text(img, "ATTACK!", (40, 160), 92, GREEN, anchor="lm", glow=14)
    neon_text(img, "A VECTOR ARCADE GAME", (40, 225), 24, DIM, anchor="lm", glow=5)
    neon_text(img, "AFTER H. G. WELLS", (40, 252), 24, DIM, anchor="lm", glow=5)
    neon_text(img, "SHOOT THE LEGS.", (40, 310), 28, WHITE, anchor="lm", glow=6)
    neon_text(img, "DUCK THE HEAT-RAY.", (40, 345), 28, RED, anchor="lm", glow=6)
    neon_text(img, "TAKE EUROPE BACK.", (40, 380), 28, AMBER, anchor="lm", glow=6)
    neon_text(img, "WINDOWS · LINUX · ANDROID", (W / 2 - 60, 470), 20, DIM, glow=4)
    draw_lockup(img, W - 70, 462, 2)
    return img


def icon():
    S = 512
    img = Image.new("RGBA", (S, S), (0, 0, 0, 255))
    scanlines(img, 12)
    tripod_icon(img, S / 2, 120, 1.45, GREEN, 6)
    neon_text(img, "TRIPOD", (S / 2, 420), 66, GREEN, glow=10)
    neon_text(img, "ATTACK!", (S / 2, 476), 50, GREEN, glow=8)
    return img


def social_square():
    """1080x1080 for the Instagram feed post."""
    S = 1080
    img = Image.new("RGBA", (S, S), (0, 0, 0, 255))
    scanlines(img, 14)
    ground_and_skyline(img, 820)
    tripod_icon(img, 790, 500, 1.9, GREEN, 6)
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    e = (790 - 27 * 1.9, 500 - 4 * 1.9)
    d.line([e, (140, 820)], fill=RED + (90,), width=22)
    d.line([e, (140, 820)], fill=RED + (230,), width=6)
    d.line([e, (140, 820)], fill=WHITE + (255,), width=2)
    img.alpha_composite(layer)
    neon_text(img, "TRIPOD", (60, 150), 150, GREEN, anchor="lm", glow=18)
    neon_text(img, "ATTACK!", (60, 290), 150, GREEN, anchor="lm", glow=18)
    neon_text(img, "A VECTOR ARCADE GAME AFTER H. G. WELLS", (60, 390), 36, DIM, anchor="lm", glow=6)
    neon_text(img, "SHOOT THE LEGS.", (60, 560), 52, WHITE, anchor="lm", glow=8)
    neon_text(img, "DUCK THE HEAT-RAY.", (60, 625), 52, RED, anchor="lm", glow=8)
    neon_text(img, "TAKE EUROPE BACK.", (60, 690), 52, AMBER, anchor="lm", glow=8)
    neon_text(img, "OUT NOW  ·  WINDOWS  ·  LINUX  ·  ANDROID", (S / 2, 930), 40, GREEN, glow=8)
    draw_lockup(img, S / 2, 1010, 4)
    return img


def x_card():
    """1200x675 (16:9) for the X post."""
    W, H = 1200, 675
    img = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    scanlines(img, 14)
    ground_and_skyline(img, 590)
    tripod_icon(img, 930, 330, 1.35, GREEN, 5)
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    e = (930 - 27 * 1.35, 330 - 4 * 1.35)
    d.line([e, (330, 590)], fill=RED + (90,), width=16)
    d.line([e, (330, 590)], fill=RED + (230,), width=5)
    d.line([e, (330, 590)], fill=WHITE + (255,), width=1)
    img.alpha_composite(layer)
    neon_text(img, "TRIPOD", (60, 110), 120, GREEN, anchor="lm", glow=16)
    neon_text(img, "ATTACK!", (60, 225), 120, GREEN, anchor="lm", glow=16)
    neon_text(img, "A VECTOR ARCADE GAME AFTER H. G. WELLS", (60, 305), 28, DIM, anchor="lm", glow=5)
    neon_text(img, "SHOOT THE LEGS.", (60, 390), 40, WHITE, anchor="lm", glow=7)
    neon_text(img, "DUCK THE HEAT-RAY.", (60, 440), 40, RED, anchor="lm", glow=7)
    neon_text(img, "TAKE EUROPE BACK.", (60, 490), 40, AMBER, anchor="lm", glow=7)
    neon_text(img, "OUT NOW  ·  WINDOWS  ·  LINUX  ·  ANDROID", (420, 632), 26, GREEN, glow=5)
    draw_lockup(img, 1060, 625, 3)
    return img


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    cover().save(os.path.join(OUT, "cover_630x500.png"))
    icon().save(os.path.join(OUT, "icon_512.png"))
    social_square().convert("RGB").save(os.path.join(OUT, "instagram_1080x1080.jpg"), quality=92)
    x_card().convert("RGB").save(os.path.join(OUT, "x_card_1200x675.jpg"), quality=92)
    print("wrote", OUT)
