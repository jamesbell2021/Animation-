#!/usr/bin/env python3
"""Joins the recorded reel shots into one MP4 with short crossfades.

Each shot's log says where its usable footage starts ("REC <seconds>").

    python3 tools/reel/assemble.py <work_dir> <output.mp4> <shot> [<shot> ...]
"""
import json
import re
import subprocess
import sys
from pathlib import Path

T = 0.4  # crossfade (s)


def duration(path: Path) -> float:
    out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "json", str(path)],
                         check=True, capture_output=True, text=True).stdout
    return float(json.loads(out)["format"]["duration"])


def main() -> None:
    work, output, shots = Path(sys.argv[1]), sys.argv[2], sys.argv[3:]
    shots = [s for s in shots if (work / f"{s}.avi").exists()]
    starts, lengths = [], []
    for shot in shots:
        log = (work / f"{shot}.log").read_text(errors="replace")
        match = re.search(r"^REC ([0-9.]+)", log, re.M)
        start = float(match.group(1)) if match else 2.0
        starts.append(start)
        lengths.append(duration(work / f"{shot}.avi") - start - 0.05)
    cmd = ["ffmpeg", "-y", "-loglevel", "error"]
    for shot, start, length in zip(shots, starts, lengths):
        cmd += ["-ss", f"{start:.3f}", "-t", f"{length:.3f}", "-i", str(work / f"{shot}.avi")]
    parts = []
    for i in range(len(shots)):
        parts.append(f"[{i}:v]fps=30,format=yuv420p,setsar=1,settb=AVTB,setpts=PTS-STARTPTS[v{i}]")
        parts.append(f"[{i}:a]aformat=sample_fmts=fltp:sample_rates=48000:channel_layouts=stereo,asetpts=PTS-STARTPTS[a{i}]")
    video, audio, offset = "v0", "a0", 0.0
    for i in range(1, len(shots)):
        offset += lengths[i - 1] - T
        parts.append(f"[{video}][v{i}]xfade=transition=fade:duration={T}:offset={offset:.3f}[xv{i}]")
        parts.append(f"[{audio}][a{i}]acrossfade=d={T}[xa{i}]")
        video, audio = f"xv{i}", f"xa{i}"
    total = sum(lengths) - T * (len(shots) - 1)
    parts.append(f"[{video}]fade=t=in:d=0.5,fade=t=out:st={total - 0.8:.3f}:d=0.8[vout]")
    parts.append(f"[{audio}]afade=t=out:st={total - 1.0:.3f}:d=1.0,alimiter=limit=0.95[aout]")
    cmd += ["-filter_complex", ";".join(parts), "-map", "[vout]", "-map", "[aout]",
            "-c:v", "libx264", "-preset", "medium", "-crf", "20", "-pix_fmt", "yuv420p", "-r", "30",
            "-c:a", "aac", "-b:a", "160k", "-movflags", "+faststart", output]
    subprocess.run(cmd, check=True)
    print(f"{output}: {len(shots)} shots, {total:.1f} s")


if __name__ == "__main__":
    main()
