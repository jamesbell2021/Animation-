#!/usr/bin/env python3
"""Cuts the Lookee Lookee Tycoon trailer from the takes that record.sh films.

Each take starts with the director's scene setup, which is trimmed here. The title cards are
filmed in-engine too, so the whole trailer uses the game's own art and font. The beach music is
laid under the full edit as one continuous track (the takes are filmed with music muted), with
the game's own sound effects and "Hello chicken nugget!" voice mixed on top.

    python3 tools/trailer/assemble.py   ->  tools/trailer/out/lookee_lookee_tycoon_trailer.mp4
                                            tools/trailer/out/lookee_lookee_tycoon_poster.jpg
Needs ffmpeg.
"""
import json
import os
import shutil
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
TAKES = os.path.join(HERE, "takes")
OUT = os.path.join(HERE, "out")
WORK = os.path.join(OUT, "work")
W, H, FPS, RATE = 1920, 1080, 30, 48000

# (take, start, seconds). start skips the setup at the head of each take; seconds=None runs to
# the end of the take.
EDIT = [
    ("card_hello", 1.25, None),
    ("sell", 4.1, 5.6),
    ("card_anyone", 1.25, None),
    ("creator", 1.3, 3.9),
    ("card_police", 1.25, None),
    ("police", 1.3, 5.6),
    ("card_legit", 1.25, None),
    ("chase", 1.3, 4.7),
    ("card_empire", 1.25, None),
    ("empire", 1.3, 4.9),
    ("events", 1.3, 4.5),
    ("end", 1.25, None),
]
MUSIC_VOLUME = 1.3


def ff(*args):
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", *args], check=True)


def duration(path):
    out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "json", path],
                         check=True, capture_output=True, text=True).stdout
    return float(json.loads(out)["format"]["duration"])


def segment(i, take, start, secs):
    src = os.path.join(TAKES, take + ".avi")
    if secs is None:
        secs = duration(src) - start - 0.05
    dst = os.path.join(WORK, f"{i:02d}_{take}.mp4")
    fade = []
    if i == 0:
        fade.append("fade=t=in:st=0:d=0.4")
    if i == len(EDIT) - 1:
        fade.append(f"fade=t=out:st={secs - 0.6:.2f}:d=0.6")
    vf = ",".join([f"scale={W}:{H}:flags=lanczos", f"fps={FPS}", "format=yuv420p"] + fade)
    ff("-ss", f"{start:.3f}", "-t", f"{secs:.3f}", "-i", src,
       "-vf", vf, "-af", f"aresample={RATE},aformat=channel_layouts=stereo",
       "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-c:a", "pcm_s16le", "-ar", str(RATE), dst)
    return dst, secs


def main():
    shutil.rmtree(WORK, ignore_errors=True)
    os.makedirs(WORK)
    parts = []
    t = 0.0
    for i, (take, start, secs) in enumerate(EDIT):
        path, length = segment(i, take, start, secs)
        print(f"[{t:6.2f}s] {take:12} {length:4.1f}s")
        parts.append(path)
        t += length
    total = t
    # Join the picture and the in-game sound.
    lst = os.path.join(WORK, "list.txt")
    with open(lst, "w") as f:
        for p in parts:
            f.write(f"file '{p}'\n")
    joined = os.path.join(WORK, "joined.mkv")
    ff("-f", "concat", "-safe", "0", "-i", lst, "-c", "copy", joined)
    # Music under everything, looped as needed, fading out with the end card.
    music = os.path.join(TAKES, "music.wav")
    os.makedirs(OUT, exist_ok=True)
    final = os.path.join(OUT, "lookee_lookee_tycoon_trailer.mp4")
    ff("-i", joined, "-stream_loop", "-1", "-i", music,
       "-filter_complex",
       f"[1:a]aresample={RATE},aformat=channel_layouts=stereo,atrim=0:{total:.3f},"
       f"volume={MUSIC_VOLUME},afade=t=in:st=0:d=0.5,afade=t=out:st={total - 1.6:.3f}:d=1.6[m];"
       f"[0:a]volume=1.0[g];[g][m]amix=inputs=2:duration=first:normalize=0,alimiter=limit=0.95[a]",
       "-map", "0:v", "-map", "[a]", "-c:v", "copy", "-c:a", "aac", "-b:a", "192k",
       "-movflags", "+faststart", final)
    poster = os.path.join(OUT, "lookee_lookee_tycoon_poster.jpg")
    ff("-ss", f"{total - 2.0:.2f}", "-i", final, "-frames:v", "1", "-q:v", "2", poster)
    print(f"\n{total:.1f}s trailer -> {final}\nposter -> {poster}")


if __name__ == "__main__":
    main()
