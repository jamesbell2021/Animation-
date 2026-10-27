#!/usr/bin/env python3
"""Cuts the Kaiju Coast trailer from the takes that record.sh films.

Shots come from tools/trailer/takes/<shot>.avi (each starts with director.gd's WARMUP frames,
trimmed here). Title cards use the game's fonts (Dela Gothic One for the big lines, DotGothic16
for the small ones) with a neon glow. Music: the title theme under the opening, the battle theme
from "BUILD YOUR DEFENCES" on and the boss theme from the Orochi card, with the game's own sound
effects and radio call-outs mixed on top.

    python3 tools/trailer/assemble.py      ->  tools/trailer/out/kaiju_coast_trailer.mp4
                                               tools/trailer/out/kaiju_coast_poster.jpg
Needs ffmpeg.
"""
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.normpath(os.path.join(HERE, "..", ".."))
TAKES = os.path.join(HERE, "takes")
OUT = os.path.join(HERE, "out")
WORK = os.path.join(OUT, "work")
BIG = os.path.join(PROJECT, "fonts", "DelaGothicOne-Regular.ttf")
SMALL = os.path.join(PROJECT, "fonts", "DotGothic16-Regular.ttf")
W, H, FPS = 1920, 1080, 30
WARMUP = 45 / FPS
RATE = 48000

SHU, CYAN, GOLD, SAKURA, WHITE = "0xff3b30", "0x36d7ff", "0xffc44d", "0xff5fa3", "0xf0e8d8"

# (kind, ...): ("card", lines, seconds, voice) / ("shot", take, start, seconds) /
# ("end", take, start, seconds). A card line is (text, size, colour); sizes under 64 use the
# small pixel font.
EDIT = [
    ("card", [("3BL PRESENTS", 56, CYAN)], 1.6, None),
    ("shot", "reveal", 0.0, 6.0),
    ("card", [("THE SEA IS WALKING", 112, CYAN), ("海が歩き出した", 80, SHU)], 1.9, "voice_wave"),
    ("shot", "wade", 0.2, 4.0),
    ("card", [("BUILD YOUR DEFENCES", 104, GOLD), ("大砲 · 火箭 · 雷神 · 刀 · 花火", 56, WHITE)], 1.8, None),
    ("shot", "build", 0.0, 4.2),
    ("card", [("THEN MAN THE GUNS", 108, SHU), ("YOURSELF", 108, SHU), ("shoot out their eyes · 目潰し", 48, WHITE)], 1.9, None),
    ("shot", "gunner", 0.4, 4.9),
    ("shot", "rockets", 0.2, 4.0),
    ("card", [("FLY THE AIRSHIP", 112, CYAN), ("雷神丸 RAIJIN-MARU", 64, WHITE)], 1.6, None),
    ("shot", "airship", 0.2, 4.4),
    ("card", [("CALL IN THE STORM", 112, GOLD), ("空爆 · 雷雨 · 放流", 64, WHITE)], 1.6, "voice_storm"),
    ("shot", "airstrike", 0.0, 3.6),
    ("shot", "storm", 0.0, 4.2),
    ("shot", "flood", 0.2, 3.6),
    ("card", [("DON'T LET THEM", 112, SHU), ("REACH THE CITY", 112, SHU)], 1.7, "voice_city_low"),
    ("shot", "rampage", 0.0, 4.8),
    ("card", [("八岐大蛇", 170, SAKURA), ("YAMATA-NO-OROCHI", 60, WHITE)], 2.0, "voice_orochi"),
    ("shot", "orochi", 0.0, 6.8),
    ("card", [("HOLD THE COAST", 120, GOLD), ("海岸を守れ", 80, SHU)], 1.7, None),
    ("shot", "finale", 0.0, 4.6),
    ("end", "finale", 4.6, 4.8),
]
# Where the music changes: the battle theme on "BUILD YOUR DEFENCES", the boss theme on the Orochi card.
BATTLE_AT = 4
BOSS_AT = 17


def run(cmd):
    subprocess.run(cmd, check=True)


def ff(*args):
    run(["ffmpeg", "-loglevel", "error", "-y", *args])


def text_file(text, key):
    path = os.path.join(WORK, f"text_{key}.txt")
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)
    return path


def drawtexts(lines, key, start_alpha_at=0.0):
    """drawtext filters for centred lines; returns a filter string."""
    total = sum(size * 1.3 for _, size, _ in lines)
    y = (H - total) / 2
    parts = []
    for i, (text, size, colour) in enumerate(lines):
        tf = text_file(text, f"{key}_{i}")
        font = BIG if size >= 64 else SMALL
        alpha = f":alpha='min(1,max(0,(t-{start_alpha_at})*3))'" if start_alpha_at else ""
        parts.append(
            f"drawtext=fontfile='{font}':textfile='{tf}':fontsize={size}:fontcolor={colour}"
            f":borderw=3:bordercolor=0x000000@0.6:x=(w-text_w)/2:y={y:.0f}{alpha}")
        y += size * 1.3
    return ",".join(parts)


def glow(chain):
    """Adds a neon bloom to whatever the chain draws."""
    return f"{chain},split[a][b];[b]gblur=sigma=18[g];[a][g]blend=all_mode=screen"


def video_card(i, lines, dur):
    # A dark card with faint scanlines, like the game's CRT pass.
    vf = (f"color=c=0x07060d:s={W}x{H}:r={FPS}:d={dur},format=gbrp,"
          + glow(drawtexts(lines, i))
          + ",geq=r='r(X,Y)*(0.86+0.14*mod(Y,3))':g='g(X,Y)*(0.86+0.14*mod(Y,3))':b='b(X,Y)*(0.86+0.14*mod(Y,3))'"
          + f",fade=in:st=0:d=0.18,fade=out:st={dur - 0.18:.2f}:d=0.18,format=yuv420p")
    out = os.path.join(WORK, f"seg_{i:02d}.mp4")
    ff("-f", "lavfi", "-i", f"anullsrc=r={RATE}:cl=stereo", "-filter_complex", vf, "-t", f"{dur}",
       "-an", "-c:v", "libx264", "-crf", "16", "-preset", "fast", "-r", str(FPS), out)
    return out


def video_shot(i, take, start, dur, end_card=False):
    src = os.path.join(TAKES, take + ".avi")
    vf = f"scale={W}:{H},fps={FPS},fade=in:st=0:d=0.12,fade=out:st={dur - 0.12:.2f}:d=0.12"
    if end_card:
        # Darken the footage and bring the title up over it.
        lines = [("怪獣海岸", 170, SHU), ("KAIJU COAST", 96, WHITE), (" ", 16, WHITE),
                 ("PLAY IT ON ITCH.IO", 64, GOLD), ("WINDOWS · ANDROID · LINUX", 40, WHITE),
                 ("gamesdevnisite.itch.io/kaiju-coast", 40, CYAN)]
        vf = (f"scale={W}:{H},fps={FPS},eq=brightness=-0.3:saturation=0.75,"
              f"drawbox=x=0:y=ih*0.2:w=iw:h=ih*0.6:color=black@0.62:t=fill,format=gbrp,"
              + glow(drawtexts(lines, i, start_alpha_at=0.3))
              + f",fade=in:st=0:d=0.12,fade=out:st={dur - 0.6:.2f}:d=0.6")
    vf += ",format=yuv420p"
    out = os.path.join(WORK, f"seg_{i:02d}.mp4")
    ff("-ss", f"{WARMUP + start:.3f}", "-t", f"{dur}", "-i", src, "-filter_complex", vf,
       "-an", "-c:v", "libx264", "-crf", "16", "-preset", "fast", "-r", str(FPS), out)
    return out


def audio_segment(i, kind, item):
    out = os.path.join(WORK, f"aud_{i:02d}.wav")
    if kind == "card":
        dur, voice = item[2], item[3]
        if voice:
            ff("-i", os.path.join(TAKES, voice + ".wav"), "-af",
               f"aresample={RATE},pan=stereo|c0=c0|c1=c0,adelay=150|150,apad,atrim=0:{dur},volume=1.7",
               "-ar", str(RATE), "-ac", "2", out)
        else:
            ff("-f", "lavfi", "-i", f"anullsrc=r={RATE}:cl=stereo", "-t", f"{dur}", out)
    else:
        take, start, dur = item[1], item[2], item[3]
        af = f"aresample={RATE},afade=in:st=0:d=0.08,afade=out:st={dur - 0.15:.2f}:d=0.15,apad,atrim=0:{dur}"
        if kind == "end":
            # The radio calls 出撃！ (sortie!) over the title.
            ff("-ss", f"{WARMUP + start:.3f}", "-t", f"{dur}", "-i", os.path.join(TAKES, take + ".avi"),
               "-i", os.path.join(TAKES, "voice_deploy.wav"), "-filter_complex",
               f"[0:a]{af},volume=0.6[g];[1:a]aresample={RATE},pan=stereo|c0=c0|c1=c0,adelay=700|700,volume=1.7[v];"
               f"[g][v]amix=inputs=2:normalize=0:duration=first", "-ac", "2", "-ar", str(RATE), out)
        else:
            ff("-ss", f"{WARMUP + start:.3f}", "-t", f"{dur}", "-i", os.path.join(TAKES, take + ".avi"),
               "-af", af, "-ac", "2", "-ar", str(RATE), out)
    return out


def concat(files, out, copy=True):
    lst = os.path.join(WORK, os.path.basename(out) + ".txt")
    with open(lst, "w") as f:
        for p in files:
            f.write(f"file '{p}'\n")
    ff("-f", "concat", "-safe", "0", "-i", lst, *(["-c", "copy"] if copy else []), out)


def music(total, battle_at, boss_at):
    """Title theme, then the battle theme, then the boss theme to the end, each looped."""
    out = os.path.join(WORK, "music.wav")
    parts = [("music_title", 0.0, battle_at), ("music_battle", battle_at, boss_at), ("music_boss", boss_at, total)]
    inputs, chains, labels = [], [], []
    for n, (name, a, b) in enumerate(parts):
        inputs += ["-stream_loop", "-1", "-i", os.path.join(TAKES, name + ".wav")]
        length = b - a + 0.5
        fade_in = "" if n == 0 else "afade=in:st=0:d=0.25,"
        fade_out = f"afade=out:st={length - 0.6:.2f}:d=0.6" if n < 2 else f"afade=out:st={length - 3.5:.2f}:d=3.2"
        chains.append(f"[{n}:a]aresample={RATE},atrim=0:{length:.2f},{fade_in}{fade_out},"
                      f"pan=stereo|c0=c0|c1=c0,adelay={int(a * 1000)}|{int(a * 1000)}[m{n}]")
        labels.append(f"[m{n}]")
    fc = ";".join(chains) + ";" + "".join(labels) + f"amix=inputs=3:normalize=0:duration=longest,atrim=0:{total:.2f}"
    ff(*inputs, "-filter_complex", fc, "-ar", str(RATE), "-ac", "2", out)
    return out


def main():
    if not shutil.which("ffmpeg"):
        sys.exit("ffmpeg is needed")
    os.makedirs(WORK, exist_ok=True)
    videos, audios = [], []
    t = 0.0
    battle_at = boss_at = 0.0
    for i, item in enumerate(EDIT):
        kind = item[0]
        if i == BATTLE_AT:
            battle_at = t
        if i == BOSS_AT:
            boss_at = t
        print(f"[{t:6.2f}s] {kind:5} {item[1] if kind != 'card' else item[1][0][0]}")
        if kind == "card":
            videos.append(video_card(i, item[1], item[2]))
            t += item[2]
        else:
            videos.append(video_shot(i, item[1], item[2], item[3], end_card=kind == "end"))
            t += item[3]
        audios.append(audio_segment(i, kind, item))
    total = t
    video = os.path.join(WORK, "video.mp4")
    concat(videos, video)
    game = os.path.join(WORK, "game.wav")
    concat(audios, game, copy=False)
    mus = music(total, battle_at, boss_at)
    final = os.path.join(OUT, "kaiju_coast_trailer.mp4")
    ff("-i", video, "-i", game, "-i", mus, "-filter_complex",
       "[2:a]volume=0.6[m];[1:a]volume=1.0[g];[m][g]amix=inputs=2:normalize=0:duration=first,"
       "alimiter=limit=0.95,loudnorm=I=-15:TP=-1.5:LRA=11[a]",
       "-map", "0:v", "-map", "[a]", "-c:v", "libx264", "-preset", "slow", "-crf", "21",
       "-maxrate", "4500k", "-bufsize", "9000k", "-pix_fmt", "yuv420p", "-profile:v", "high",
       "-c:a", "aac", "-b:a", "160k", "-ar", str(RATE), "-movflags", "+faststart", "-t", f"{total}", final)
    poster = os.path.join(OUT, "kaiju_coast_poster.jpg")
    ff("-ss", f"{WARMUP + 5.0:.2f}", "-i", os.path.join(TAKES, "orochi.avi"), "-frames:v", "1",
       "-vf", f"scale={W}:{H}", "-q:v", "3", poster)
    print(f"trailer: {final} ({total:.1f}s)\nposter:  {poster}")


if __name__ == "__main__":
    main()
