#!/usr/bin/env python3
"""Draws the launch art: the app icon set and the itch.io covers.

    python3 launch/make_art.py [path/to/gamesdevni-site/screenshots]

Writes  icons/icon.png, icons/icon_192.png, icons/icon_fg_432.png, icons/icon_bg_432.png
        launch/out/cover_630x500.png            (itch.io cover for Neon Mega Tank)
        launch/out/bundle_cover_630x500.png     (itch.io cover for the five-game bundle)
        launch/out/icon_512.png                 (store listing icon)
Needs Pillow. The site's screenshots folder is only needed for the bundle cover.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.normpath(os.path.join(HERE, ".."))
FONT = os.path.join(PROJECT, "fonts", "DotGothic16-Regular.ttf")
OUT = os.path.join(HERE, "out")
ICONS = os.path.join(PROJECT, "icons")

BG = (5, 8, 26)
CYAN = (51, 214, 255)
PINK = (255, 79, 216)
GOLD = (255, 224, 58)
GREEN = (64, 255, 112)
WHITE = (232, 244, 255)

BUNDLE_TITLE = "NEON ARCADE COLLECTION"
BUNDLE_LINE = "5 GAMES FROM 3BL"
BUNDLE_PRICE = "ALL FIVE  $5.99"


def glow_layer(size, draw_fn, blur, strength=1.0):
    """Runs draw_fn on a transparent layer and returns (blurred glow, crisp)."""
    crisp = Image.new("RGBA", size, (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(crisp))
    glow = crisp.filter(ImageFilter.GaussianBlur(blur))
    if strength != 1.0:
        a = glow.split()[3].point(lambda v: min(255, int(v * strength)))
        glow.putalpha(a)
    return glow, crisp


def neon(base, draw_fn, blur=18, strength=1.6):
    for layer in glow_layer(base.size, draw_fn, blur, strength) + glow_layer(base.size, draw_fn, blur / 3, 1.0)[1:]:
        base.alpha_composite(layer)
    return base


def grid(img, step, colour=(51, 214, 255, 22), angle=True):
    d = ImageDraw.Draw(img)
    w, h = img.size
    if not angle:
        for x in range(0, w, step):
            d.line([(x, 0), (x, h)], fill=colour, width=1)
        for y in range(0, h, step):
            d.line([(0, y), (w, y)], fill=colour, width=1)
        return
    # isometric-looking grid, like the game's ground
    for k in range(-h, w + h, step):
        d.line([(k, 0), (k + h * 0.6, h)], fill=colour, width=1)
        d.line([(k, h), (k + h * 0.6, 0)], fill=colour, width=1)


def tank(d, cx, cy, s, body=CYAN, trim=PINK, width=None):
    """Side view of the mega tank, centred on (cx, cy), s = overall width."""
    lw = width or max(2, int(s * 0.035))
    h = s * 0.52
    x0, y0 = cx - s / 2, cy - h / 2
    # tracks
    track = [x0, y0 + h * 0.66, x0 + s, y0 + h]
    d.rounded_rectangle(track, radius=h * 0.17, outline=trim, width=lw)
    for i in range(1, 6):
        x = x0 + s * i / 6
        d.line([(x, track[1] + lw), (x, track[3] - lw)], fill=trim, width=max(1, lw // 2))
    # hull (wide low trapezoid)
    hull = [(x0 + s * 0.06, y0 + h * 0.66), (x0 + s * 0.16, y0 + h * 0.4),
            (x0 + s * 0.86, y0 + h * 0.4), (x0 + s * 0.98, y0 + h * 0.66)]
    d.polygon(hull, outline=body, width=lw)
    # turret
    tur = [(x0 + s * 0.30, y0 + h * 0.4), (x0 + s * 0.36, y0 + h * 0.12),
           (x0 + s * 0.68, y0 + h * 0.12), (x0 + s * 0.72, y0 + h * 0.4)]
    d.polygon(tur, outline=body, width=lw)
    # twin barrels
    for dy in (-h * 0.03, h * 0.07):
        d.line([(x0 + s * 0.70, y0 + h * 0.23 + dy), (x0 + s * 1.02, y0 + h * 0.17 + dy)], fill=trim, width=lw)
    # crew pips on deck
    for i, col in enumerate((CYAN, GREEN, PINK, GOLD)):
        px = x0 + s * (0.40 + i * 0.08)
        d.rectangle([px, y0 + h * 0.02, px + s * 0.04, y0 + h * 0.11], fill=col)


def icon_set():
    os.makedirs(ICONS, exist_ok=True)
    big = 1024

    def scene(size, with_bg=True, inset=0.0):
        img = Image.new("RGBA", (size, size), BG if with_bg else (0, 0, 0, 0))
        if with_bg:
            grid(img, size // 8)
        s = size * (0.78 - inset)
        neon(img, lambda d: tank(d, size / 2, size / 2 + size * 0.02, s), blur=size * 0.03)
        return img

    full = scene(big)
    full.resize((512, 512), Image.LANCZOS).save(os.path.join(OUT, "icon_512.png"))
    full.resize((256, 256), Image.LANCZOS).save(os.path.join(ICONS, "icon.png"))
    full.resize((192, 192), Image.LANCZOS).save(os.path.join(ICONS, "icon_192.png"))
    # adaptive icon: the launcher masks the outer 1/6 on each side, keep the tank inside
    fg = scene(big, with_bg=False, inset=0.26)
    fg.resize((432, 432), Image.LANCZOS).save(os.path.join(ICONS, "icon_fg_432.png"))
    bg = Image.new("RGBA", (big, big), BG)
    grid(bg, big // 8)
    bg.resize((432, 432), Image.LANCZOS).save(os.path.join(ICONS, "icon_bg_432.png"))


def text_glow(img, xy, text, size, colour, anchor="mm", blur=None):
    font = ImageFont.truetype(FONT, size)
    blur = blur or size * 0.18

    def draw(d):
        d.text(xy, text, font=font, fill=colour, anchor=anchor)
    neon(img, draw, blur=blur, strength=1.4)


def cover_base(shot_path, w=630, h=500):
    shot = Image.open(shot_path).convert("RGB")
    sw, sh = shot.size
    scale = max(w / sw, h / sh)
    shot = shot.resize((int(sw * scale) + 1, int(sh * scale) + 1), Image.LANCZOS)
    x = (shot.width - w) // 2
    y = (shot.height - h) // 2
    return shot.crop((x, y, x + w, y + h)).convert("RGBA")


def shade(img, top, bottom, alpha_top, alpha_bottom):
    """Vertical dark gradient between rows top..bottom."""
    w = img.width
    band = Image.new("RGBA", (w, bottom - top), (0, 0, 0, 0))
    d = ImageDraw.Draw(band)
    for i in range(bottom - top):
        a = int(alpha_top + (alpha_bottom - alpha_top) * i / max(1, bottom - top - 1))
        d.line([(0, i), (w, i)], fill=(2, 4, 12, a))
    img.alpha_composite(band, (0, top))


def game_cover():
    img = cover_base(os.path.join(PROJECT, "docs", "cover_source.jpg"))
    shade(img, 0, 190, 235, 0)
    shade(img, 380, 500, 0, 220)
    text_glow(img, (315, 62), "NEON MEGA TANK", 66, PINK)
    text_glow(img, (315, 122), "ネオン・メガ・タンク", 30, CYAN)
    text_glow(img, (315, 452), "1-4 PLAYERS  ·  CO-OP ON YOUR PHONES", 24, GOLD)
    text_glow(img, (315, 482), "ANDROID  ·  WINDOWS  ·  LINUX  ·  日本語対応", 17, WHITE, blur=3)
    img.convert("RGB").save(os.path.join(OUT, "cover_630x500.png"))


def bundle_cover(site_shots):
    img = Image.new("RGBA", (630, 500), BG)
    grid(img, 42)
    text_glow(img, (315, 48), BUNDLE_TITLE, 44, PINK)
    text_glow(img, (315, 92), BUNDLE_LINE, 20, CYAN)
    tiles = [("cyber_title.jpg", "CYBER VIKINGS"), ("vbn_title.jpg", "VICTORY BY NONE"),
             ("aom_winner.jpg", "ANGRY OLD MEN"), ("pultz_two_player.jpg", "PULTZ"),
             (os.path.join(PROJECT, "docs", "cover_source.jpg"), "NEON MEGA TANK")]
    tw, th, gap = 198, 111, 10
    slots = [(gap + i * (tw + gap), 124) for i in range(3)] + [(gap + i * (tw + gap), 124 + th + 34 + gap) for i in range(2)]
    font = ImageFont.truetype(FONT, 15)
    for (src, label), (x, y) in zip(tiles, slots):
        path = src if os.path.isabs(src) else os.path.join(site_shots, src)
        if os.path.exists(path):
            tile = cover_base(path, tw, th)
        else:
            tile = Image.new("RGBA", (tw, th), (10, 14, 40, 255))
        img.alpha_composite(tile, (x, y))
        d = ImageDraw.Draw(img)
        d.rectangle([x, y, x + tw - 1, y + th - 1], outline=CYAN, width=2)
        d.text((x + tw / 2, y + th + 16), label, font=font, fill=WHITE, anchor="mm")
    # the price box fills the sixth slot
    x, y = slots[2][0], slots[3][1]
    d = ImageDraw.Draw(img)
    d.rectangle([x, y, x + tw - 1, y + th - 1], fill=(20, 16, 4, 255), outline=GOLD, width=3)
    text_glow(img, (x + tw / 2, y + 36), "ALL FIVE", 26, GOLD)
    text_glow(img, (x + tw / 2, y + 78), BUNDLE_PRICE.split()[-1], 40, GOLD)
    text_glow(img, (315, 472), "ARCADE ACTION  ·  CO-OP  ·  RETRO PIXELS  ·  itch.io", 17, WHITE, blur=3)
    img.convert("RGB").save(os.path.join(OUT, "bundle_cover_630x500.png"))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    icon_set()
    game_cover()
    bundle_cover(sys.argv[1] if len(sys.argv) > 1 else os.path.join(PROJECT, "..", "..", "gamesdevni-site", "screenshots"))
    print("wrote", ICONS, "and", OUT)
