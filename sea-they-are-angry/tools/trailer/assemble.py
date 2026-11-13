#!/usr/bin/env python3
"""Cuts the itch.io trailer from the takes tools/trailer/trailer_director.gd recorded.

    python3 tools/trailer/assemble.py <work_dir> [output.mp4]

<work_dir> holds <shot>.avi and <shot>.log for every shot in EDL (the log says where
the usable footage starts: "REC <seconds>"). The output defaults to
itch/trailer/SeaTheyAreAngry-trailer.mp4; a poster frame is written beside it.
Intermediates go in <work_dir>/edit. Needs ffmpeg, ffprobe and Pillow.

The edit is the EDL table below: text cards (made here, in the game's own fonts) and
shots (which take, where in it to start, how long). The second half is cut to the beat
of the game's finale music (126 beats a minute), so its lengths are given in bars.
The sound is the game's own: two of its music pieces, the takes' recorded audio, a
bell and the foghorn. It is brought to -14 LUFS with peaks under -1 dBTP.
"""
import json
import re
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
FPS = 30
W, H = 1280, 720
NIGHT = (11, 16, 24)        # #0b1018
GOLD = (240, 196, 110)      # #f0c46e
PAPER = (232, 226, 210)     # #e8e2d2
TITLE_FONT = ROOT / "fonts/IMFellEnglishSC.ttf"
TEXT_FONT = ROOT / "fonts/SpecialElite.ttf"
AUDIO = ROOT / "audio"

BAR = 4 * 60.0 / 126.0      # one bar of music_finale.ogg (s)
FINALE_FROM_BAR = 8         # where in the finale the action starts (its third phrase)

# ---- the edit ----
# ("card", lines, seconds)            lines: [(text, "title" | "text", size), ...]
# ("shot", take, start, seconds, {...})  start: seconds after the take's REC mark.
#   options: "over": [(text, kind, size)] a line of text over the footage (lower left),
#            "gain": dB on the take's own sound, "tail": seconds its sound runs on under
#            what follows, "eq": an ffmpeg eq= string to lift a dark take,
#            "fade_in"/"fade_out": seconds from/to black.
# A length given as "2b" is in bars of the finale; the first shot with one starts it.
EDL = [
    ("shot", "dusk", 0.3, 3.0, {"over": [("Kirkhaven, October 1987.", "text", 34)], "fade_in": 0.6, "gain": 4.0}),
    ("card", [("The Board put the harbour light on a clock.", "text", 36)], 1.9),
    ("shot", "fog", 0.9, 2.6, {"gain": 4.0}),
    ("card", [("The clock stuck.", "title", 76)], 1.3),
    ("shot", "hook", 0.35, "1b", {}),
    ("shot", "shotgun", 0.55, "1b", {}),
    ("shot", "fire", 0.6, "1b", {}),
    ("shot", "pier", 0.2, "1b", {}),
    ("shot", "boat", 0.5, "1b", {}),
    ("shot", "arm", 0.9, "1.5b", {}),
    ("shot", "beam", 0.5, "1.5b", {}),
    ("card", [("It cannot abide the light.", "title", 64)], "1b"),
    ("shot", "rise", 1.5, "1.5b", {}),
    ("shot", "camp", 0.6, "1b", {}),
    ("shot", "blind", 0.7, "1b", {}),
    ("shot", "rear", 0.3, "1.5b", {"tail": 2.5}),
    ("title", None, "2b+1.0"),
]
# The poster: this take, this many seconds after its REC mark, under the title.
POSTER = ("rear", 2.0)


def run(cmd, **kw):
    return subprocess.run([str(c) for c in cmd], check=True, **kw)


def font(kind: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(TITLE_FONT if kind == "title" else TEXT_FONT), size)


def draw_lines(img: Image.Image, lines, centre_y: float, gap: float = 1.35, anchor_x=None) -> None:
    """Lines of text centred on centre_y (or left-aligned at anchor_x)."""
    d = ImageDraw.Draw(img)
    heights = [size * gap for _, _, size in lines]
    y = centre_y - sum(heights) / 2.0
    for (text, kind, size), h in zip(lines, heights):
        f = font(kind, size)
        colour = GOLD if kind == "title" else PAPER
        box = d.textbbox((0, 0), text, font=f)
        x = (W - (box[2] - box[0])) / 2.0 - box[0] if anchor_x is None else anchor_x
        d.text((x, y + (h - size) / 2.0), text, font=f, fill=colour)
        y += h


def card_png(lines, path: Path) -> None:
    img = Image.new("RGB", (W, H), NIGHT)
    draw_lines(img, lines, H / 2.0)
    img.save(path)


def title_png(path: Path, alpha: bool = False) -> None:
    """The title card. With alpha: only the lettering (for the poster), on a soft shade."""
    lines_top = [("SEA THEY ARE ANGRY", "title", 104)]
    lines_low = [("Keep the light burning.", "text", 34), ("", "text", 14), ("1 to 3 keepers · Windows and Linux", "text", 24)]
    if not alpha:
        img = Image.new("RGB", (W, H), NIGHT)
        draw_lines(img, lines_top, H * 0.42)
        d = ImageDraw.Draw(img)
        d.line([(W / 2 - 150, H * 0.545), (W / 2 + 150, H * 0.545)], fill=(120, 98, 55), width=2)
        draw_lines(img, lines_low, H * 0.68)
        img.save(path)
        return
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    shade = Image.new("L", (W, H), 0)
    ImageDraw.Draw(shade).rectangle([0, H * 0.62, W, H], fill=150)
    shade = shade.filter(ImageFilter.GaussianBlur(60))
    img.paste(Image.new("RGBA", (W, H), NIGHT + (255,)), (0, 0), shade)
    draw_lines(img, [("SEA THEY ARE ANGRY", "title", 96)], H * 0.83)
    img.save(path)


def over_png(lines, path: Path) -> None:
    """A line over footage, lower left, with a soft dark edge so it reads on anything."""
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    y = H - 96
    for dx, dy in [(0, 0), (2, 2), (-2, 2), (2, -2), (-2, -2)]:
        tmp = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        dd = ImageDraw.Draw(tmp)
        for text, kind, size in lines:
            dd.text((64 + dx, y + dy), text, font=font(kind, size), fill=(0, 0, 0, 200))
        shadow = Image.alpha_composite(shadow, tmp)
    shadow = shadow.filter(ImageFilter.GaussianBlur(3))
    img = Image.alpha_composite(img, shadow)
    d = ImageDraw.Draw(img)
    for text, kind, size in lines:
        d.text((64, y), text, font=font(kind, size), fill=(GOLD if kind == "title" else PAPER) + (255,))
    img.save(path)


def rec_mark(work: Path, take: str) -> float:
    log = (work / f"{take}.log").read_text(errors="replace")
    m = re.search(r"^REC ([0-9.]+)", log, re.M)
    if not m:
        sys.exit(f"{take}.log has no REC mark: record the take again")
    return float(m.group(1))


def seconds(spec, t_now: float, grid0):
    """A segment's end time. Bars are counted on the finale's grid so cuts never drift."""
    if isinstance(spec, (int, float)):
        return t_now + float(spec), grid0
    m = re.fullmatch(r"([0-9.]+)b(?:\+([0-9.]+))?", spec)
    if grid0 is None:
        grid0 = t_now
    bars_done = round((t_now - grid0) / BAR * 4) / 4.0
    end = grid0 + (bars_done + float(m.group(1))) * BAR + float(m.group(2) or 0.0)
    return end, grid0


def loudness(path: Path) -> dict:
    out = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", str(path), "-af", "ebur128=peak=true", "-f", "null", "-"],
                         capture_output=True, text=True).stderr
    tail = out[out.rfind("Summary:"):]
    return {"I": float(re.search(r"I:\s+(-?[0-9.]+) LUFS", tail).group(1)),
            "LRA": float(re.search(r"LRA:\s+(-?[0-9.]+) LU", tail).group(1)),
            "TP": float(re.search(r"Peak:\s+(-?[0-9.]+) dBFS", tail).group(1))}


def main() -> None:
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    work = Path(sys.argv[1]).resolve()
    out = Path(sys.argv[2]).resolve() if len(sys.argv) > 2 else ROOT / "itch/trailer/SeaTheyAreAngry-trailer.mp4"
    edit = work / "edit"
    edit.mkdir(parents=True, exist_ok=True)
    out.parent.mkdir(parents=True, exist_ok=True)

    # ---- timings (whole frames) ----
    segs = []
    t, grid0 = 0.0, None
    for row in EDL:
        kind, what = row[0], row[1]
        length = row[3] if kind == "shot" else row[2]
        opts = row[4] if kind == "shot" else {}
        end, grid0 = seconds(length, t, grid0)
        f0, f1 = round(t * FPS), round(end * FPS)
        segs.append({"kind": kind, "what": what, "start": f0 / FPS, "frames": f1 - f0, "opts": opts,
                     "in": float(row[2]) if kind == "shot" else 0.0})
        t = end
    total_frames = round(t * FPS)
    total = total_frames / FPS
    finale_at = grid0

    # ---- pictures ----
    listing = []
    for i, s in enumerate(segs):
        seg = edit / f"seg_{i:02d}.mp4"
        n, dur = s["frames"], s["frames"] / FPS
        enc = ["-frames:v", n, "-r", FPS, "-c:v", "libx264", "-preset", "fast", "-crf", "12", "-pix_fmt", "yuv420p", "-an", seg]
        if s["kind"] in ("card", "title"):
            png = edit / f"card_{i:02d}.png"
            if s["kind"] == "title":
                title_png(png)
                fades = f"fade=t=in:d=0.5,fade=t=out:st={dur - 0.9:.3f}:d=0.9"
            else:
                card_png(s["what"], png)
                fades = f"fade=t=in:d=0.2,fade=t=out:st={dur - 0.2:.3f}:d=0.2"
            run(["ffmpeg", "-y", "-loglevel", "error", "-loop", "1", "-framerate", FPS, "-i", png,
                 "-vf", f"{fades},format=yuv420p"] + enc)
        else:
            o = s["opts"]
            start = rec_mark(work, s["what"]) + s["in"]
            vf = ["fps=30", f"scale={W}:{H}:flags=lanczos", "setsar=1"]
            if "eq" in o:
                vf.append("eq=" + o["eq"])
            if "fade_in" in o:
                vf.append(f"fade=t=in:d={o['fade_in']}")
            if "fade_out" in o:
                vf.append(f"fade=t=out:st={dur - o['fade_out']:.3f}:d={o['fade_out']}")
            cmd = ["ffmpeg", "-y", "-loglevel", "error", "-ss", f"{start:.3f}", "-i", work / f"{s['what']}.avi"]
            if "over" in o:
                png = edit / f"over_{i:02d}.png"
                over_png(o["over"], png)
                cmd += ["-loop", "1", "-framerate", FPS, "-i", png, "-filter_complex",
                        f"[0:v]{','.join(vf)}[v];[1:v]fade=t=in:st=0.5:d=0.5:alpha=1,fade=t=out:st={dur - 0.5:.3f}:d=0.4:alpha=1[t];[v][t]overlay=format=auto,format=yuv420p[o]",
                        "-map", "[o]"]
            else:
                cmd += ["-vf", ",".join(vf) + ",format=yuv420p"]
            run(cmd + enc)
        listing.append(f"file '{seg}'")
    (edit / "list.txt").write_text("\n".join(listing) + "\n")
    silent = edit / "picture.mp4"
    run(["ffmpeg", "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", edit / "list.txt", "-c", "copy", silent])

    # ---- sound ----
    # The bed: the town's night music under the opening, out on the bell; the finale,
    # hard in, from the first action cut to the title, where it falls away.
    title_at = next(s["start"] for s in segs if s["kind"] == "title")
    stuck_at = next(s["start"] for s in segs if s["kind"] == "card" and s["what"][0][0] == "The clock stuck.")
    inputs, chains, mix = [], [], []

    def add(path, chain: str, at: float) -> None:
        n = len(inputs)
        inputs.extend(["-i", str(path)])
        ms = max(0, round(at * 1000))
        chains.append(f"[{n}:a]{chain},aformat=sample_fmts=fltp:sample_rates=48000:channel_layouts=stereo,adelay={ms}:all=1[a{n}]")
        mix.append(f"[a{n}]")

    open_len = stuck_at + 0.25
    add(AUDIO / "music_harbour_night.ogg",
        f"atrim=start=12.0:duration={open_len:.3f},asetpts=PTS-STARTPTS,volume=-3dB,afade=t=in:d=1.2,afade=t=out:st={open_len - 0.5:.3f}:d=0.5", 0.0)
    add(AUDIO / "bell.ogg", "volume=-1dB,afade=t=out:st=1.6:d=1.2", stuck_at + 0.1)
    fin_len = total - finale_at
    fin_out = title_at - finale_at + 1.2
    add(AUDIO / "music_finale.ogg",
        f"atrim=start={FINALE_FROM_BAR * BAR:.4f}:duration={fin_len:.3f},asetpts=PTS-STARTPTS,volume=-1.5dB,afade=t=in:d=0.02,afade=t=out:st={fin_out:.3f}:d=2.4", finale_at)
    add(AUDIO / "foghorn.ogg", "volume=0dB", title_at + 0.25)
    for i, s in enumerate(segs):
        if s["kind"] != "shot":
            continue
        o = s["opts"]
        start = rec_mark(work, s["what"]) + s["in"]
        dur = s["frames"] / FPS + float(o.get("tail", 0.0))
        fade_out = max(0.05, float(o.get("tail", 0.0)))
        add(work / f"{s['what']}.avi",
            f"atrim=start={start:.3f}:duration={dur:.3f},asetpts=PTS-STARTPTS,volume={float(o.get('gain', 0.0)):.1f}dB,afade=t=in:d=0.04,afade=t=out:st={dur - fade_out:.3f}:d={fade_out:.3f}",
            s["start"])
    raw = edit / "mix_raw.wav"
    graph = ";".join(chains) + ";" + "".join(mix) + f"amix=inputs={len(mix)}:normalize=0:duration=longest,apad,atrim=duration={total:.3f},afade=t=out:st={total - 1.2:.3f}:d=1.2[out]"
    run(["ffmpeg", "-y", "-loglevel", "error"] + inputs + ["-filter_complex", graph, "-map", "[out]", "-ar", "48000", "-c:a", "pcm_s24le", raw])
    # To -14 LUFS: a plain gain, then a limiter holding the peaks under -1 dBTP, twice
    # over (the limiter takes a little loudness off, so the gain is measured again).
    mixed = edit / "mix.wav"
    gain = -14.0 - loudness(raw)["I"]
    for _ in range(3):
        run(["ffmpeg", "-y", "-loglevel", "error", "-i", raw, "-af",
             f"volume={gain:.2f}dB,alimiter=limit=-2.0dB:level=false:attack=3:release=60,aresample=48000", "-c:a", "pcm_s24le", mixed])
        got = loudness(mixed)
        if abs(got["I"] + 14.0) < 0.15:
            break
        gain += -14.0 - got["I"]

    # ---- together ----
    run(["ffmpeg", "-y", "-loglevel", "error", "-i", silent, "-i", mixed, "-map", "0:v", "-map", "1:a",
         "-c:v", "libx264", "-preset", "slow", "-crf", "18", "-pix_fmt", "yuv420p", "-profile:v", "high", "-r", FPS,
         "-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-t", f"{total:.3f}", "-movflags", "+faststart", out])
    final = loudness(out)

    # ---- the poster ----
    poster = out.parent / "poster.png"
    frame = edit / "poster_frame.png"
    letters = edit / "poster_title.png"
    title_png(letters, alpha=True)
    run(["ffmpeg", "-y", "-loglevel", "error", "-ss", f"{rec_mark(work, POSTER[0]) + POSTER[1]:.3f}", "-i", work / f"{POSTER[0]}.avi",
         "-frames:v", "1", "-vf", f"scale={W}:{H}:flags=lanczos", frame])
    base = Image.open(frame).convert("RGBA")
    Image.alpha_composite(base, Image.open(letters)).convert("RGB").save(poster, optimize=True)

    print(f"{out}: {total:.2f} s, {total_frames} frames, {out.stat().st_size / 1e6:.1f} MB")
    print(f"sound: {final['I']:.1f} LUFS integrated, range {final['LRA']:.1f} LU, true peak {final['TP']:.1f} dBTP")
    print("cut list:")
    for s in segs:
        name = s["what"] if s["kind"] == "shot" else ("TITLE" if s["kind"] == "title" else "card: " + " / ".join(l[0] for l in s["what"]))
        print(f"  {s['start']:6.2f}  {s['frames'] / FPS:5.2f} s  {name}")
    print(json.dumps({"finale_from": round(finale_at, 3), "title_at": round(title_at, 3)}))


if __name__ == "__main__":
    main()
