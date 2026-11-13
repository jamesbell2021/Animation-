#!/usr/bin/env python3
"""Cuts the itch.io page's small animated GIFs from the trailer's takes.

    python3 tools/trailer/make_gifs.py <work_dir> [out_dir] [name ...]

<work_dir> holds the takes (<shot>.avi, <shot>.log) that
tools/trailer/trailer_director.gd recorded; out_dir defaults to itch/gifs. Names (the
GIFS keys) make only those. itch.io refuses images over 3 MB, so each GIF is made
smaller (fewer colours, then narrower, then fewer frames a second) until it is under
LIMIT. A two-pass palette (palettegen stats_mode=diff, paletteuse bayer dither); if
gifsicle is installed it is run over the result as well. Needs ffmpeg.
"""
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LIMIT = 2.3e6   # bytes: itch's limit is 3 MB; the page loads quicker under this
# name: take, start (s after its REC mark), seconds, width, frames a second, loop.
# loop "pingpong" plays it forward then back (a seamless loop from any footage);
# "cut" just repeats (for a blow or a blast, which would look wrong backwards).
GIFS = {
    "01_kirkhaven_fog": ("fog", 1.5, 3.0, 520, 12, "cut"),
    "02_shotgun": ("shotgun", 0.5, 2.6, 520, 15, "cut"),
    "03_fire": ("fire", 1.2, 3.0, 520, 12, "cut"),
    "04_the_escape": ("boat", 0.4, 2.0, 520, 12, "pingpong"),
    "05_the_beam": ("beam", 1.0, 3.0, 520, 12, "cut"),
    "06_the_kraken": ("rear", 0.8, 3.2, 520, 12, "cut"),
}
# Tried in order until the file fits: (colours, width scale, fps scale, bayer scale).
LADDER = [(128, 1.0, 1.0, 3), (96, 1.0, 1.0, 3), (64, 1.0, 1.0, 3), (64, 0.92, 1.0, 3), (64, 0.92, 0.84, 4), (48, 0.92, 0.84, 4),
          (48, 0.85, 0.84, 4), (40, 0.8, 0.84, 5), (32, 0.8, 0.84, 5)]


def rec_mark(work: Path, take: str) -> float:
    m = re.search(r"^REC ([0-9.]+)", (work / f"{take}.log").read_text(errors="replace"), re.M)
    if not m:
        sys.exit(f"{take}.log has no REC mark: record the take again")
    return float(m.group(1))


def make(work: Path, out: Path, name: str) -> None:
    take, start, length, width, fps, loop = GIFS[name]
    src = work / f"{take}.avi"
    at = rec_mark(work, take) + start
    target = out / f"{name}.gif"
    for colours, wk, fk, bayer in LADDER:
        w = int(round(width * wk / 2.0)) * 2
        f = max(8, int(round(fps * fk)))
        chain = f"fps={f},scale={w}:-2:flags=lanczos"
        if loop == "pingpong":
            # Forward, then back without repeating the two end frames.
            chain += ",split[fw][bw];[bw]reverse,trim=start_frame=1,setpts=PTS-STARTPTS[rv];[fw][rv]concat=n=2:v=1,trim=end_frame=%d" % (2 * int(length * f) - 2)
        graph = (f"[0:v]{chain},split[a][b];[a]palettegen=stats_mode=diff:max_colors={colours}[p];"
                 f"[b][p]paletteuse=dither=bayer:bayer_scale={bayer}:diff_mode=rectangle[o]")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-ss", f"{at:.3f}", "-t", f"{length:.3f}", "-i", str(src),
                        "-filter_complex", graph, "-map", "[o]", "-loop", "0", str(target)], check=True)
        if shutil.which("gifsicle"):
            subprocess.run(["gifsicle", "-O3", "--lossy=40", "-b", str(target)], check=True)
        size = target.stat().st_size
        if size <= LIMIT:
            break
    print(f"{target}: {size / 1e6:.2f} MB, {w} px wide, {f} fps, {colours} colours, {loop}")
    if size > LIMIT:
        print("  STILL OVER THE LIMIT: shorten it in GIFS")


def main() -> None:
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    work = Path(sys.argv[1]).resolve()
    out = ROOT / "itch/gifs"
    names = []
    for a in sys.argv[2:]:
        if a in GIFS:
            names.append(a)
        else:
            out = Path(a).resolve()
    out.mkdir(parents=True, exist_ok=True)
    for name in names or GIFS:
        make(work, out, name)


if __name__ == "__main__":
    main()
