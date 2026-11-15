#!/usr/bin/env python3
"""Turns the movie-maker take of the reel choreography into a 1080x1920 TikTok cut.

    python3 tools/make_tiktok.py take.avi take.log launch/out/tripod-attack-tiktok.mp4

Different from make_reel.py (the Instagram reel) in the ways TikTok wants: no opening card, the
game is running and the hook is on screen in the first second; the game sits in TikTok's safe
zone (clear of the top bar and the bottom 400 px the caption and buttons cover); the captions are
short, large and timed to the EVENT lines the reel script printed; it ends on one card that says
where to get it, with the handle. The game's own synthesised audio is kept, normalised, so the
take works with sound on; James can swap it for a TikTok sound when posting. Needs Pillow and
ffmpeg. The font is DotGothic16 (OFL) from the Neon Mega Tank folder; the lockup is tools/brand.py.
"""
import os
import re
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from brand import draw_lockup  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
FONT = os.path.normpath(os.path.join(HERE, "..", "..", "neon-mega-tank", "fonts", "DotGothic16-Regular.ttf"))
W, H = 1080, 1920
GAME_Y, GAME_H = 560, 608          # the game band, centred in the safe zone
GREEN = (60, 255, 90)
DIM = (29, 138, 51)
RED = (255, 59, 59)
WHITE = (234, 255, 234)
AMBER = (255, 210, 74)

# The cut: the take's seconds to keep, then the end card.
TAKE_END = 27.4
CARD_SECONDS = 3.6

# Captions keyed to the reel script's EVENT names, so a new take re-times them itself.
# (event that starts it, event that ends it or None for "the next one", line 1, line 2, colour)
# The first is the hook and starts at 0 whatever the events say.
CAPTIONS = [
    ("start", "siren", "THE MARTIANS", "ARE IN BELFAST", GREEN),
    ("siren", "beam_over", "HEAR THE CRY?", "DUCK.", RED),
    ("beam_over", "collapse_a", "SHOOT THE LEGS", "", GREEN),
    ("collapse_a", "siren:1", "WATCH IT FALL", "REAL PHYSICS, EVERY TIME", AMBER),
    ("siren:1", "beam_over:1", "ULLA... ULLA...", "DUCK!", RED),
    ("beam_over:1", "collapse_b", "BIGGER ONES COME", "", GREEN),
    ("collapse_b", "map", "TAKE EUROPE BACK", "SECTOR BY SECTOR", GREEN),
]
# If the take's log has no EVENT lines, these seconds stand in (the reel's own timings).
FALLBACK = [0.0, 2.25, 5.45, 9.4, 14.4, 17.3, 25.05, TAKE_END]


def font(size):
    return ImageFont.truetype(FONT, size)


def neon_text(img, text, xy, size, colour, anchor="mm", glow=14):
    f = font(size)
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.text(xy, text, font=f, fill=colour + (255,), anchor=anchor)
    g = layer.filter(ImageFilter.GaussianBlur(glow))
    a = g.split()[3].point(lambda v: min(255, int(v * 1.8)))
    g.putalpha(a)
    img.alpha_composite(g)
    img.alpha_composite(layer)


def scanlines(img, shade=18):
    d = ImageDraw.Draw(img)
    for y in range(0, img.height, 4):
        d.line([(0, y), (img.width, y)], fill=(shade, shade, shade, 255), width=1)


def frame_layer():
    """What stays on screen the whole take: the game's name small above the band, a frame round
    the band, the handle small below it."""
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, GAME_Y - 6, W, GAME_Y + GAME_H + 6], outline=DIM + (255,), width=3)
    neon_text(img, "TRIPOD ATTACK!", (W // 2, GAME_Y - 60), 52, DIM, glow=8)
    neon_text(img, "@3BL_Indie", (W // 2, GAME_Y + GAME_H + 62), 40, DIM, glow=6)
    return img


def caption(line1, line2, colour, hook=False):
    """Above the game band: the hook is bigger than the rest."""
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    size1 = 112 if hook else (96 if len(line1) < 15 else 76)
    y = 300 if line2 else 345
    neon_text(img, line1, (W // 2, y), size1, colour, glow=18)
    if line2:
        neon_text(img, line2, (W // 2, y + (118 if hook else 100)), 72 if hook else 56, WHITE, glow=10)
    return img


def end_card():
    img = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    scanlines(img)
    neon_text(img, "TRIPOD ATTACK!", (W // 2, 640), 118, GREEN, glow=18)
    neon_text(img, "PLAY IT NOW", (W // 2, 790), 96, WHITE, glow=14)
    neon_text(img, "FREE IN THE BROWSER", (W // 2, 900), 52, AMBER, glow=10)
    neon_text(img, "WINDOWS  ·  LINUX  ·  ANDROID", (W // 2, 970), 44, AMBER, glow=8)
    neon_text(img, "LINK IN BIO", (W // 2, 1110), 72, GREEN, glow=14)
    draw_lockup(img, W // 2, 1300, 9)
    neon_text(img, "@3BL_Indie", (W // 2, 1420), 44, DIM, glow=6)
    return img


def events(log_path):
    """EVENT <seconds> <name> lines from the take's log, as {name: seconds} for the first time
    each name is printed and {name:k: seconds} for its k-th repeat (the reel's second siren is
    "siren:1")."""
    out = {"start": 0.0}
    seen = {}
    if log_path and os.path.exists(log_path):
        for line in open(log_path, encoding="utf-8", errors="ignore"):
            m = re.match(r"EVENT\s+([0-9.]+)\s+(\S+)", line.strip())
            if m:
                name, t = m.group(2), float(m.group(1))
                k = seen.get(name, 0)
                seen[name] = k + 1
                out[name if k == 0 else f"{name}:{k}"] = t
    out.setdefault("map", TAKE_END)
    out["end"] = TAKE_END
    return out


def timings(ev):
    """(start, end) for each caption; falls back to the reel's seconds for any event missing."""
    out = []
    for i, (a, b, *_rest) in enumerate(CAPTIONS):
        start = 0.0 if i == 0 else ev.get(a, FALLBACK[i])
        end = ev.get(b, FALLBACK[i + 1]) if b else (ev.get(CAPTIONS[i + 1][0], FALLBACK[i + 1]) if i + 1 < len(CAPTIONS) else TAKE_END)
        end = min(end, TAKE_END)
        if end - start < 1.2:
            end = min(start + 1.2, TAKE_END)
        out.append((start, end - 0.05))
    return out


def main():
    take, log, out = sys.argv[1], sys.argv[2], sys.argv[3]
    ev = events(log)
    times = timings(ev)
    print("captions:", [(round(a, 2), round(b, 2), c[2]) for (a, b), c in zip(times, CAPTIONS)])
    total = TAKE_END + CARD_SECONDS
    work = tempfile.mkdtemp(prefix="tiktok-")
    frame_layer().save(os.path.join(work, "frame.png"))
    end_card().save(os.path.join(work, "end.png"))
    for i, (a, b, l1, l2, col) in enumerate(CAPTIONS):
        caption(l1, l2, col, hook=(i == 0)).save(os.path.join(work, f"cap{i}.png"))
    inputs = ["-t", str(TAKE_END), "-i", take, "-loop", "1", "-i", os.path.join(work, "frame.png"), "-loop", "1", "-i", os.path.join(work, "end.png")]
    for i in range(len(CAPTIONS)):
        inputs += ["-loop", "1", "-i", os.path.join(work, f"cap{i}.png")]
    f = []
    # The take, held on its last frame through the end card so the timeline runs to `total`.
    f.append(f"[0:v]fps=30,tpad=stop_mode=clone:stop_duration={CARD_SECONDS + 0.5},split[g][gb]")
    f.append(f"[gb]scale={W // 4}:{H // 4}:force_original_aspect_ratio=increase,crop={W // 4}:{H // 4},gblur=sigma=7,eq=brightness=-0.30:saturation=1.3,scale={W}:{H}[bg]")
    f.append(f"[g]scale={W}:{GAME_H}[game]")
    f.append(f"[bg][game]overlay=0:{GAME_Y}[v0]")
    f.append("[v0][1:v]overlay=0:0[v1]")
    last = "v1"
    for i, (a, b) in enumerate(times):
        f.append(f"[{last}][{3 + i}:v]overlay=0:0:enable='between(t,{a:.2f},{b:.2f})'[c{i}]")
        last = f"c{i}"
    f.append(f"[2:v]format=rgba,fade=t=in:st={TAKE_END:.2f}:d=0.5:alpha=1[card]")
    f.append(f"[{last}][card]overlay=0:0:enable='gte(t,{TAKE_END:.2f})',fade=t=out:st={total - 0.4:.2f}:d=0.4,format=yuv420p[vout]")
    f.append(f"[0:a]apad=pad_dur={CARD_SECONDS + 0.5},alimiter=limit=0.9,loudnorm=I=-14:TP=-1.5:LRA=11,afade=t=out:st={total - 1.2:.2f}:d=1.2,aresample=48000[aout]")
    cmd = ["ffmpeg", "-y", "-hide_banner", "-loglevel", "error"] + inputs + ["-filter_complex", ";".join(f), "-map", "[vout]", "-map", "[aout]",
           "-t", f"{total:.2f}", "-c:v", "libx264", "-preset", "medium", "-crf", "19", "-profile:v", "high", "-r", "30", "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", out]
    subprocess.run(cmd, check=True)
    cover_at = ev.get("collapse_a", 9.9) + 0.6
    subprocess.run(["ffmpeg", "-y", "-hide_banner", "-loglevel", "error", "-ss", f"{cover_at:.2f}", "-i", out, "-frames:v", "1", "-q:v", "3", os.path.splitext(out)[0] + "-cover.jpg"], check=True)
    print("wrote", out, f"({total:.1f} s)")


if __name__ == "__main__":
    main()
