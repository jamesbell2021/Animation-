#!/usr/bin/env python3
"""Turns the movie-maker take of the reel choreography into a 1080x1920 Instagram reel.

    python3 tools/make_reel.py take.avi launch/out/tripod-attack-reel.mp4

The gameplay (1024x576) sits in the middle third, sharp, over a blurred and darkened copy of
itself. A title band with the 3BL_Indie lockup and the game's name sits above; captions timed to the
EVENT lines the reel script prints run below; a "3BL_Indie presents" card opens and an "out now" card
closes. Needs Pillow and ffmpeg. The font is DotGothic16 (OFL) from the Neon Mega Tank folder.
"""
import os
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from brand import draw_lockup  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
FONT = os.path.normpath(os.path.join(HERE, "..", "..", "neon-mega-tank", "fonts", "DotGothic16-Regular.ttf"))
W, H = 1080, 1920
GAME_Y, GAME_H = 600, 608
GREEN = (60, 255, 90)
DIM = (29, 138, 51)
RED = (255, 59, 59)
WHITE = (234, 255, 234)
AMBER = (255, 210, 74)

# (start, end, line1, line2, colour)
CAPTIONS = [
    (0.0, 2.2, "BELFAST. WAVE ONE.", "THE MARTIANS ARE HERE.", GREEN),
    (2.25, 5.4, "HEAR THE CRY...", "DUCK THE HEAT-RAY", RED),
    (5.45, 9.3, "SHOOT THE LEGS", "", GREEN),
    (9.4, 14.3, "WATCH THEM FALL", "REAL PHYSICS. EVERY TIME.", AMBER),
    (14.4, 17.2, "ULLA... ULLA...", "DUCK!", RED),
    (17.3, 25.0, "BIGGER ONES COME", "", GREEN),
    (25.05, 27.4, "SHOWERS OF SPARKS", "", AMBER),
    (27.5, 30.4, "TAKE EUROPE BACK", "SECTOR BY SECTOR", GREEN),
]
INTRO_END = 1.6
OUTRO_START = 30.5


def font(size):
    return ImageFont.truetype(FONT, size)


def neon_text(img, text, xy, size, colour, anchor="mm", glow=14, width_limit=None):
    """Draws glowing text onto an RGBA image."""
    f = font(size)
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.text(xy, text, font=f, fill=colour + (255,), anchor=anchor)
    g = layer.filter(ImageFilter.GaussianBlur(glow))
    a = g.split()[3].point(lambda v: min(255, int(v * 1.8)))
    g.putalpha(a)
    img.alpha_composite(g)
    img.alpha_composite(layer)


def tripod_icon(img, cx, cy, s, colour=GREEN, w=5):
    import math
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    pts = [(cx + math.cos(math.pi + math.pi * i / 14) * 44 * s, cy + math.sin(math.pi + math.pi * i / 14) * 40 * s) for i in range(15)]
    pts += [(cx + 50 * s, cy + 9 * s), (cx + 50 * s, cy + 17 * s), (cx - 50 * s, cy + 17 * s), (cx - 50 * s, cy + 9 * s), (cx - 44 * s, cy)]
    d.line(pts + [pts[0]], fill=colour, width=w, joint="curve")
    d.line([(cx - 48 * s, cy + 4 * s), (cx + 48 * s, cy + 4 * s)], fill=colour, width=max(1, w // 2))
    r = 8 * s
    ex, ey = cx - 27 * s, cy - 4 * s
    d.ellipse([ex - r, ey - r, ex + r, ey + r], outline=RED, width=w)
    d.ellipse([ex - r * 0.4, ey - r * 0.4, ex + r * 0.4, ey + r * 0.4], fill=RED)
    for hip, knee, foot in [((-24, 28), (-70, 60), (-72, 180)), ((2, 34), (10, 70), (6, 180)), ((26, 28), (76, 56), (76, 180))]:
        p = [(cx + hip[0] * s, cy + hip[1] * s), (cx + knee[0] * s, cy + knee[1] * s), (cx + foot[0] * s, cy + foot[1] * s)]
        d.line(p, fill=colour, width=w, joint="curve")
        k = p[1]
        d.ellipse([k[0] - 3 * s, k[1] - 3 * s, k[0] + 3 * s, k[1] + 3 * s], outline=colour, width=max(1, w // 2))
        fx, fy = p[2]
        d.line([(fx - 9 * s, fy), (fx + 9 * s, fy)], fill=colour, width=w)
    g = layer.filter(ImageFilter.GaussianBlur(10))
    img.alpha_composite(g)
    img.alpha_composite(layer)


def scanlines(img, shade=18):
    """Dark stripes on an opaque card (drawn opaque: ImageDraw replaces pixels, it does not blend)."""
    d = ImageDraw.Draw(img)
    for y in range(0, img.height, 4):
        d.line([(0, y), (img.width, y)], fill=(shade, shade, shade, 255), width=1)


def mark_3bl(img, cx, cy, size=64, sub=True):
    """The 3BL_Indie lockup; `size` is roughly its height in pixels."""
    px = max(2, int(size / 20))
    draw_lockup(img, cx, cy, px)
    if sub:
        neon_text(img, "gamesdevni.site", (cx, cy + px * 10 + size * 0.45), int(size * 0.42), DIM, glow=6)


def top_band():
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    tripod_icon(img, W // 2, 150, 0.95, GREEN, 5)
    neon_text(img, "TRIPOD ATTACK!", (W // 2, 420), 118, GREEN, glow=18)
    neon_text(img, "A VECTOR ARCADE GAME AFTER H. G. WELLS", (W // 2, 510), 34, DIM, glow=6)
    # frame around the screen
    d = ImageDraw.Draw(img)
    d.rectangle([0, GAME_Y - 6, W, GAME_Y + GAME_H + 6], outline=DIM + (255,), width=3)
    mark_3bl(img, W // 2, 1790, 60)
    return img


def caption(line1, line2, colour):
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    y = 1380 if line2 else 1420
    neon_text(img, line1, (W // 2, y), 86 if len(line1) < 16 else 70, colour, glow=16)
    if line2:
        neon_text(img, line2, (W // 2, y + 110), 54, WHITE, glow=10)
    return img


def intro_card():
    img = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    scanlines(img)
    draw_lockup(img, W // 2, 860, 14)
    neon_text(img, "PRESENTS", (W // 2, 1090), 64, GREEN, glow=12)
    return img


def outro_card():
    img = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    scanlines(img)
    tripod_icon(img, W // 2, 420, 1.3, GREEN, 6)
    neon_text(img, "TRIPOD ATTACK!", (W // 2, 820), 118, GREEN, glow=18)
    neon_text(img, "OUT NOW", (W // 2, 960), 90, WHITE, glow=14)
    neon_text(img, "WINDOWS  ·  LINUX  ·  ANDROID", (W // 2, 1070), 48, AMBER, glow=10)
    neon_text(img, "SHOOT THE LEGS. DUCK THE HEAT-RAY.", (W // 2, 1200), 40, DIM, glow=6)
    neon_text(img, "PROTECT THE PEOPLE. TAKE EUROPE BACK.", (W // 2, 1255), 40, DIM, glow=6)
    mark_3bl(img, W // 2, 1560, 180)
    return img


def main():
    take = sys.argv[1]
    out = sys.argv[2]
    probe = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", take], capture_output=True, text=True, check=True)
    duration = float(probe.stdout.strip())
    work = tempfile.mkdtemp(prefix="reel-")
    top_band().save(os.path.join(work, "top.png"))
    intro_card().save(os.path.join(work, "intro.png"))
    outro_card().save(os.path.join(work, "outro.png"))
    for i, (a, b, l1, l2, col) in enumerate(CAPTIONS):
        caption(l1, l2, col).save(os.path.join(work, f"cap{i}.png"))
    inputs = ["-i", take, "-loop", "1", "-i", os.path.join(work, "top.png"), "-loop", "1", "-i", os.path.join(work, "intro.png"),
              "-loop", "1", "-i", os.path.join(work, "outro.png")]
    for i in range(len(CAPTIONS)):
        inputs += ["-loop", "1", "-i", os.path.join(work, f"cap{i}.png")]
    f = []
    f.append(f"[0:v]fps=30,split[g][gb]")
    f.append(f"[gb]scale={W // 4}:{H // 4}:force_original_aspect_ratio=increase,crop={W // 4}:{H // 4},gblur=sigma=7,eq=brightness=-0.28:saturation=1.3,scale={W}:{H}[bg]")
    f.append(f"[g]scale={W}:{GAME_H}[game]")
    f.append(f"[bg][game]overlay=0:{GAME_Y}[v0]")
    f.append("[v0][1:v]overlay=0:0[v1]")
    last = "v1"
    for i, (a, b, *_rest) in enumerate(CAPTIONS):
        f.append(f"[{last}][{4 + i}:v]overlay=0:0:enable='between(t,{a},{b})'[c{i}]")
        last = f"c{i}"
    f.append(f"[2:v]format=rgba,fade=t=out:st={INTRO_END - 0.5}:d=0.5:alpha=1[intro]")
    f.append(f"[{last}][intro]overlay=0:0:enable='lte(t,{INTRO_END})'[vi]")
    f.append(f"[3:v]format=rgba,fade=t=in:st={OUTRO_START}:d=0.6:alpha=1[outro]")
    f.append(f"[vi][outro]overlay=0:0:enable='gte(t,{OUTRO_START})',format=yuv420p[vout]")
    f.append("[0:a]alimiter=limit=0.9,loudnorm=I=-14:TP=-1.5:LRA=11,aresample=48000[aout]")
    cmd = ["ffmpeg", "-y", "-hide_banner", "-loglevel", "error"] + inputs + ["-filter_complex", ";".join(f), "-map", "[vout]", "-map", "[aout]",
           "-t", str(duration), "-c:v", "libx264", "-preset", "medium", "-crf", "19", "-profile:v", "high", "-r", "30", "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", out]
    subprocess.run(cmd, check=True)
    # a cover frame for the post
    subprocess.run(["ffmpeg", "-y", "-hide_banner", "-loglevel", "error", "-ss", "9.9", "-i", out, "-frames:v", "1", "-q:v", "3", os.path.splitext(out)[0] + "-cover.jpg"], check=True)
    print("wrote", out)


if __name__ == "__main__":
    main()
