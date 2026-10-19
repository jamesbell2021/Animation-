#!/usr/bin/env python3
"""Joins the recorded reel shots into one vertical MP4 (Instagram Reels ready).

Each shot's log says where its usable footage starts ("REC <seconds>"). Shots are
trimmed, joined with quick transitions, the game sounds are crossfaded and the
game's dance track is laid over the whole reel.

    python3 tools/reel/assemble.py <work_dir> <output.mp4>
"""
import json
import re
import subprocess
import sys
from pathlib import Path

SHOTS = ["title", "race", "paintball", "finale", "end"]
TRANSITIONS = ["circleopen", "slideleft", "fadewhite", "fade"]
T = 0.35  # transition length (s)
MUSIC_VOLUME = 0.55


def duration(path: Path) -> float:
    out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "json", str(path)],
                         check=True, capture_output=True, text=True).stdout
    return float(json.loads(out)["format"]["duration"])


def main() -> None:
    work, output = Path(sys.argv[1]), sys.argv[2]
    starts, lengths = [], []
    for shot in SHOTS:
        log = (work / f"{shot}.log").read_text(errors="replace")
        match = re.search(r"^REC ([0-9.]+)", log, re.M)
        start = float(match.group(1)) if match else 1.5
        starts.append(start)
        lengths.append(duration(work / f"{shot}.avi") - start - 0.05)
    total = sum(lengths) - T * (len(SHOTS) - 1)

    cmd = ["ffmpeg", "-y", "-loglevel", "error"]
    for shot, start, length in zip(SHOTS, starts, lengths):
        cmd += ["-ss", f"{start:.3f}", "-t", f"{length:.3f}", "-i", str(work / f"{shot}.avi")]
    cmd += ["-stream_loop", "3", "-i", str(work / "music.wav")]

    parts = []
    for i in range(len(SHOTS)):
        parts.append(f"[{i}:v]fps=30,format=yuv420p,setsar=1,settb=AVTB,setpts=PTS-STARTPTS[v{i}]")
        parts.append(f"[{i}:a]aformat=sample_fmts=fltp:sample_rates=48000:channel_layouts=stereo,asetpts=PTS-STARTPTS[a{i}]")
    video, audio, offset = "v0", "a0", 0.0
    for i in range(1, len(SHOTS)):
        offset += lengths[i - 1] - T
        parts.append(f"[{video}][v{i}]xfade=transition={TRANSITIONS[i - 1]}:duration={T}:offset={offset:.3f}[xv{i}]")
        parts.append(f"[{audio}][a{i}]acrossfade=d={T}[xa{i}]")
        video, audio = f"xv{i}", f"xa{i}"
    music = len(SHOTS)
    parts.append(f"[{music}:a]aformat=sample_fmts=fltp:sample_rates=48000:channel_layouts=stereo,"
                 f"atrim=0:{total:.3f},volume={MUSIC_VOLUME},afade=t=in:d=0.4,afade=t=out:st={total - 2.0:.3f}:d=2[m]")
    parts.append(f"[{audio}][m]amix=inputs=2:duration=first:normalize=0,alimiter=limit=0.95[aout]")
    cmd += ["-filter_complex", ";".join(parts), "-map", f"[{video}]", "-map", "[aout]",
            "-c:v", "libx264", "-preset", "slow", "-crf", "18", "-profile:v", "high", "-level", "4.1",
            "-pix_fmt", "yuv420p", "-r", "30", "-maxrate", "12M", "-bufsize", "24M",
            "-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-movflags", "+faststart",
            "-t", f"{total:.3f}", output]
    subprocess.run(cmd, check=True)
    print(f"reel: {output} ({total:.1f} s)")


if __name__ == "__main__":
    main()
