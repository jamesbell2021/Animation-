#!/usr/bin/env python3
"""Makes the itch.io art from the trailer takes (run tools/trailer/record.sh first).

    python3 launch/make_art.py

Writes  launch/out/cover_630x500.png      itch.io cover (Yamata-no-Orochi rising in the rain)
        launch/out/banner_960x360.png     page header (kaiju wading in under the blood moon)
        launch/out/screenshots/*.jpg      twelve 1920x1080 stills, in page order
        launch/out/gif_eye_out.gif        shooting out an Onigami's eye
        launch/out/gif_airstrike.gif      the airstrike
Needs ffmpeg and Pillow.
"""
import os
import subprocess

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.normpath(os.path.join(HERE, ".."))
TAKES = os.path.join(PROJECT, "tools", "trailer", "takes")
OUT = os.path.join(HERE, "out")
BIG = os.path.join(PROJECT, "fonts", "DelaGothicOne-Regular.ttf")
SMALL = os.path.join(PROJECT, "fonts", "DotGothic16-Regular.ttf")
WARMUP = 1.5   # director.gd's WARMUP frames, in seconds

SHU = (255, 59, 48)
CYAN = (54, 215, 255)
GOLD = (255, 196, 77)
PAPER = (240, 232, 216)

# (file name, take, seconds into the shot)
STILLS = [
    ("01_reveal", "reveal", 4.2), ("02_wade", "wade", 2.2), ("03_build", "build", 3.4),
    ("04_eye_out", "gunner", 2.6), ("05_rockets", "rockets", 2.4), ("06_airship", "airship", 2.0),
    ("07_airstrike", "airstrike", 2.4), ("08_storm", "storm", 1.2), ("09_flood", "flood", 1.6),
    ("10_rampage", "rampage", 3.2), ("11_orochi", "orochi", 5.2), ("12_finale", "finale", 6.0),
]


def ff(*args):
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", *args], check=True)


def frame(take, t, path):
    ff("-ss", f"{WARMUP + t:.2f}", "-i", os.path.join(TAKES, take + ".avi"), "-frames:v", "1", "-q:v", "2", path)
    return path


def neon_text(img, xy, text, font, colour, anchor="la", blur=14, stroke=0):
    """Draws text with a soft coloured glow under a crisp copy."""
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.text(xy, text, font=font, fill=colour + (255,), anchor=anchor, stroke_width=stroke, stroke_fill=(0, 0, 0, 255))
    glow = layer.filter(ImageFilter.GaussianBlur(blur))
    img.alpha_composite(glow)
    img.alpha_composite(glow)
    img.alpha_composite(layer)


def shade(img, top, bottom):
    """Darkens the image towards the top and/or bottom so the lettering reads."""
    w, h = img.size
    grad = Image.new("L", (1, h))
    for y in range(h):
        f = y / (h - 1)
        a = max(top * (1 - f / 0.45) if f < 0.45 else 0, bottom * ((f - 0.6) / 0.4) if f > 0.6 else 0)
        grad.putpixel((0, y), int(255 * min(1, a)))
    mask = grad.resize((w, h))
    black = Image.new("RGBA", (w, h), (4, 3, 10, 255))
    img.paste(black, (0, 0), mask)


def fit(src, w, h, focus_x=0.5, focus_y=0.5):
    """Scales to cover w x h and crops around the focus point."""
    im = Image.open(src).convert("RGBA")
    s = max(w / im.width, h / im.height)
    im = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
    x = int(min(max(0, im.width * focus_x - w / 2), im.width - w))
    y = int(min(max(0, im.height * focus_y - h / 2), im.height - h))
    return im.crop((x, y, x + w, y + h))


def cover():
    src = frame("orochi", 2.4, os.path.join(OUT, "_cover_src.png"))
    img = fit(src, 630, 500, 0.47, 0.5)
    shade(img, 0.0, 0.95)
    neon_text(img, (315, 318), "怪獣海岸", ImageFont.truetype(BIG, 88), SHU, "ma", 16, 2)
    neon_text(img, (315, 420), "KAIJU COAST", ImageFont.truetype(BIG, 44), PAPER, "ma", 10, 2)
    neon_text(img, (315, 488), "TOWER DEFENCE · FIRST PERSON · GIANT MONSTERS", ImageFont.truetype(SMALL, 17), GOLD, "ms", 6)
    img.convert("RGB").save(os.path.join(OUT, "cover_630x500.png"), optimize=True)
    os.remove(src)


def banner():
    src = frame("reveal", 4.2, os.path.join(OUT, "_banner_src.png"))
    img = fit(src, 960, 360, 0.55, 0.45)
    side = Image.new("L", (960, 1))
    for x in range(960):
        side.putpixel((x, 0), int(235 * max(0.0, 1 - x / 520)))
    img.paste(Image.new("RGBA", (960, 360), (4, 3, 10, 255)), (0, 0), side.resize((960, 360)))
    neon_text(img, (40, 70), "怪獣海岸", ImageFont.truetype(BIG, 96), SHU, "la", 16, 2)
    neon_text(img, (44, 196), "KAIJU COAST", ImageFont.truetype(BIG, 46), PAPER, "la", 10, 2)
    neon_text(img, (46, 270), "Hold the bay. Man the guns. Fly the airship.", ImageFont.truetype(SMALL, 22), CYAN, "la", 6)
    img.convert("RGB").save(os.path.join(OUT, "banner_960x360.png"), optimize=True)
    os.remove(src)


def stills():
    d = os.path.join(OUT, "screenshots")
    os.makedirs(d, exist_ok=True)
    for name, take, t in STILLS:
        png = frame(take, t, os.path.join(d, name + ".png"))
        Image.open(png).convert("RGB").save(os.path.join(d, name + ".jpg"), quality=90, optimize=True)
        os.remove(png)


def gif(name, take, start, dur, width=540, fps=15):
    out = os.path.join(OUT, name + ".gif")
    vf = f"fps={fps},scale={width}:-1:flags=lanczos"
    ff("-ss", f"{WARMUP + start:.2f}", "-t", f"{dur}", "-i", os.path.join(TAKES, take + ".avi"),
       "-filter_complex", f"[0:v]{vf},split[a][b];[a]palettegen=max_colors=128:stats_mode=diff[p];"
       f"[b][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle", out)


def main():
    os.makedirs(OUT, exist_ok=True)
    cover()
    banner()
    stills()
    gif("gif_eye_out", "gunner", 1.4, 3.2)
    gif("gif_airstrike", "airstrike", 0.6, 3.0)
    for f in sorted(os.listdir(OUT)):
        print(os.path.join(OUT, f))


if __name__ == "__main__":
    main()
