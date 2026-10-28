#!/usr/bin/env python3
"""Cuts the Neon Mega Tank trailer from the takes that record.sh films.

Shots come from tools/trailer/takes/<shot>.avi (each starts with director.gd's WARMUP frames,
trimmed here). Title cards are drawn with the game's DotGothic16 pixel font and a neon glow.
Music: the lobby theme under the opening, the battle theme from "ONE TANK. FOUR CREW." on,
with the game's own sound effects and announcer lines mixed on top.

    python3 tools/trailer/assemble.py          ->  tools/trailer/out/neon_mega_tank_trailer.mp4
                                                   tools/trailer/out/neon_mega_tank_poster.jpg
    python3 tools/trailer/assemble.py update   ->  the update 1.1 trailer (shield, repair gauge,
                                                   snap-aim cannon, new enemies, collapsing
                                                   buildings) ending on the free demo:
                                                   tools/trailer/out/neon_mega_tank_update_trailer.mp4
                                                   tools/trailer/out/neon_mega_tank_update_poster.jpg
Needs ffmpeg. Film the update shots first with "record.sh update".
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
FONT = os.path.join(PROJECT, "fonts", "DotGothic16-Regular.ttf")
W, H, FPS = 1920, 1080, 30
WARMUP = 45 / FPS
RATE = 48000

PINK, CYAN, YELLOW, GREEN, WHITE = "0xff4fd8", "0x33d6ff", "0xffe03a", "0x40ff70", "0xe8f4ff"

# (kind, ...): ("card", lines, seconds, voice) / ("shot", take, start, seconds[, caption]) /
# ("end", take, start, seconds). A card line is (text, size, colour); a caption is a list of
# lines drawn in the lower third of the shot.
EDIT = [
    ("card", [("3BL PRESENTS", 60, CYAN)], 1.6, None),
    ("shot", "reveal", 0.0, 5.6),
    ("card", [("ONE TANK.", 120, CYAN), ("FOUR CREW.", 120, PINK)], 2.0, None),
    ("shot", "crew", 0.0, 4.6),
    ("card", [("FLATTEN THE CITY", 104, YELLOW)], 1.3, None),
    ("shot", "collapse", 0.2, 4.6),
    ("card", [("SHOOT ROCKETS", 104, PINK), ("OUT OF THE SKY", 104, PINK)], 1.5, None),
    ("shot", "shootdown", 0.3, 4.6),
    ("shot", "combat", 0.2, 5.0),
    ("card", [("EVERY ENEMY HAS", 96, CYAN), ("LAST WORDS", 96, CYAN), ("やられた！", 72, PINK)], 1.7, None),
    ("shot", "shouts", 0.3, 4.6),
    ("shot", "drones", 0.0, 4.3),
    ("card", [("PLAY TOGETHER", 104, GREEN), ("ON YOUR OWN PHONES", 104, GREEN),
              ("over Wi-Fi  ·  1-4 players  ·  AI crew fills empty seats", 40, WHITE)], 2.6, None),
    ("shot", "phones", 0.0, 4.8),
    ("card", [("ボス出現！", 140, PINK), ("BOSS INCOMING", 64, WHITE)], 1.9, "voice_boss"),
    ("shot", "boss", 0.0, 6.8),
    ("card", [("HOW LONG", 120, YELLOW), ("CAN YOU SURVIVE?", 120, YELLOW)], 1.9, None),
    ("shot", "finale", 0.0, 4.6),
    ("end", "finale", 4.6, 4.4),
]
# The battle theme comes in on the first card after the reveal.
MUSIC_SWITCH_INDEX = 2
END_LINES = [("NEON MEGA TANK", 150, PINK), ("ネオン・メガ・タンク", 70, CYAN), (" ", 20, WHITE),
             ("OUT NOW ON ITCH.IO", 64, YELLOW), ("ANDROID  ·  WINDOWS  ·  LINUX  ·  日本語対応", 38, WHITE),
             ("gamesdevni.site", 40, WHITE)]

# Update 1.1: what's new, then the free demo.
UPDATE_EDIT = [
    ("card", [("NEON MEGA TANK", 120, PINK), ("UPDATE 1.1", 96, YELLOW)], 1.8, None),
    ("shot", "reveal", 1.6, 3.2),
    ("card", [("NEW!", 72, YELLOW), ("ENERGY SHIELD", 120, CYAN), ("hold ACTION on the repair station", 40, WHITE)], 1.8, None),
    ("shot", "shield", 0.4, 4.4),
    ("card", [("TIMED REPAIRS", 120, GREEN), ("PERFECT!  COMBO!", 80, YELLOW)], 1.5, None),
    ("shot", "gauge", 0.3, 4.6),
    ("card", [("SNAP-AIM CANNON", 116, PINK), ("LOCK ON.  FIRE.", 80, WHITE)], 1.5, None),
    ("shot", "lockon", 0.0, 5.6),
    ("card", [("4 NEW ENEMIES", 130, YELLOW)], 1.3, "voice_wave"),
    ("shot", "hornets", 0.2, 3.3, [("HORNET SWARMS", 64, YELLOW)]),
    ("shot", "mortars", 0.3, 3.4, [("MORTAR TEAMS", 64, YELLOW), ("get out of the red ring!", 36, WHITE)]),
    ("shot", "barrier", 0.2, 4.6, [("結界車  BARRIER TRUCKS", 64, YELLOW), ("break the dome", 36, WHITE)]),
    ("shot", "gunship", 0.6, 3.8, [("GUNSHIPS", 64, YELLOW)]),
    ("card", [("BRING THE", 110, CYAN), ("HOUSE DOWN", 120, PINK)], 1.4, None),
    ("shot", "collapse", 0.2, 4.6),
    ("shot", "storm", 0.0, 4.6, [("THEMED WAVES", 56, YELLOW)]),
    ("card", [("FREE DEMO", 170, YELLOW), ("OUT NOW", 110, PINK),
              ("10 minutes of battle  ·  Android  ·  Windows  ·  Linux", 40, WHITE)], 2.4, None),
    ("shot", "demomenu", 0.4, 3.0),
    ("end", "finale", 1.0, 5.2),
]
UPDATE_END_LINES = [("NEON MEGA TANK", 150, PINK), ("UPDATE 1.1  +  FREE DEMO", 64, YELLOW), (" ", 16, WHITE),
                    ("PLAY THE DEMO FREE ON ITCH.IO", 58, CYAN),
                    ("gamesdevnisite.itch.io/neon-mega-tank", 40, WHITE),
                    ("ANDROID  ·  WINDOWS  ·  LINUX  ·  日本語対応", 36, WHITE)]


def run(cmd):
    subprocess.run(cmd, check=True)


def ff(*args):
    run(["ffmpeg", "-loglevel", "error", "-y", *args])


def text_file(text, idx):
    path = os.path.join(WORK, f"text_{idx}.txt")
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)
    return path


def drawtexts(lines, key, start_alpha_at=0.0):
    """drawtext filters for centred lines; returns a filter string."""
    total = sum(size * 1.25 for _, size, _ in lines)
    y = (H - total) / 2
    parts = []
    for i, (text, size, colour) in enumerate(lines):
        tf = text_file(text, f"{key}_{i}")
        alpha = f":alpha='min(1,max(0,(t-{start_alpha_at})*3))'" if start_alpha_at else ""
        parts.append(
            f"drawtext=fontfile='{FONT}':textfile='{tf}':fontsize={size}:fontcolor={colour}"
            f":x=(w-text_w)/2:y={y:.0f}{alpha}")
        y += size * 1.25
    return ",".join(parts)


def glow(chain):
    """Adds a neon bloom to whatever the chain draws."""
    return f"{chain},split[a][b];[b]gblur=sigma=16[g];[a][g]blend=all_mode=screen"


def video_card(i, lines, dur):
    vf = glow(f"color=c=0x030510:s={W}x{H}:r={FPS}:d={dur},format=gbrp,{drawtexts(lines, i)}")
    vf += f",fade=in:st=0:d=0.18,fade=out:st={dur - 0.18:.2f}:d=0.18,format=yuv420p"
    out = os.path.join(WORK, f"seg_{i:02d}.mp4")
    ff("-f", "lavfi", "-i", f"anullsrc=r={RATE}:cl=stereo", "-filter_complex", vf, "-t", f"{dur}",
       "-an", "-c:v", "libx264", "-crf", "16", "-preset", "fast", "-r", str(FPS), out)
    return out


def caption(lines, key):
    """Lower-third caption over a shot: a dark band with neon lines sliding in."""
    total = sum(size * 1.2 for _, size, _ in lines)
    y = H - 110 - total
    parts = [f"drawbox=x=0:y={y - 24:.0f}:w=iw:h={total + 48:.0f}:color=black@0.55:t=fill"]
    for i, (text, size, colour) in enumerate(lines):
        tf = text_file(text, f"cap{key}_{i}")
        parts.append(
            f"drawtext=fontfile='{FONT}':textfile='{tf}':fontsize={size}:fontcolor={colour}"
            f":borderw=3:bordercolor=black@0.8:shadowx=0:shadowy=0"
            f":x='90-max(0,(0.25-t))*1600':y={y:.0f}:alpha='min(1,t*5)'")
        y += size * 1.2
    return ",".join(parts)


def video_shot(i, take, start, dur, end_card=False, cap=None, end_lines=None):
    src = os.path.join(TAKES, take + ".avi")
    vf = f"scale={W}:{H},fps={FPS},fade=in:st=0:d=0.12,fade=out:st={dur - 0.12:.2f}:d=0.12"
    if cap:
        vf = f"scale={W}:{H},fps={FPS},{caption(cap, i)},fade=in:st=0:d=0.12,fade=out:st={dur - 0.12:.2f}:d=0.12"
    if end_card:
        # Darken the footage and bring the title up over it.
        lines = end_lines or END_LINES
        vf = (f"scale={W}:{H},fps={FPS},eq=brightness=-0.3:saturation=0.75,"
              f"drawbox=x=0:y=ih*0.27:w=iw:h=ih*0.46:color=black@0.62:t=fill,format=gbrp,"
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
               f"aresample={RATE},pan=stereo|c0=c0|c1=c0,adelay=150|150,apad,atrim=0:{dur},volume=1.6",
               "-ar", str(RATE), "-ac", "2", out)
        else:
            ff("-f", "lavfi", "-i", f"anullsrc=r={RATE}:cl=stereo", "-t", f"{dur}", out)
    else:
        take, start, dur = item[1], item[2], item[3]
        af = f"aresample={RATE},afade=in:st=0:d=0.08,afade=out:st={dur - 0.15:.2f}:d=0.15,apad,atrim=0:{dur}"
        if kind == "end":
            # The announcer calls 出撃！ (sortie!) over the title.
            ff("-ss", f"{WARMUP + start:.3f}", "-t", f"{dur}", "-i", os.path.join(TAKES, take + ".avi"),
               "-i", os.path.join(TAKES, "voice_deploy.wav"), "-filter_complex",
               f"[0:a]{af},volume=0.6[g];[1:a]aresample={RATE},pan=stereo|c0=c0|c1=c0,adelay=700|700,volume=1.6[v];"
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


def music(total, switch_at):
    """Lobby theme until the switch, then the battle theme (looped after its intro)."""
    out = os.path.join(WORK, "music.wav")
    battle_len = total - switch_at + 1.0
    ff("-i", os.path.join(TAKES, "music_lobby.wav"), "-i", os.path.join(TAKES, "music_battle.wav"),
       "-filter_complex",
       f"[0:a]aresample={RATE},atrim=0:{switch_at + 0.4},afade=out:st={switch_at - 0.2}:d=0.6,"
       f"pan=stereo|c0=c0|c1=c0[l];"
       f"[1:a]aresample={RATE},asplit[b1][b2];[b2]atrim=start=3.0,asetpts=PTS-STARTPTS[body];"
       f"[b1][body]concat=n=2:v=0:a=1,atrim=0:{battle_len},afade=out:st={battle_len - 3.2}:d=3,"
       f"pan=stereo|c0=c0|c1=c0,adelay={int(switch_at * 1000)}|{int(switch_at * 1000)}[b];"
       f"[l][b]amix=inputs=2:normalize=0:duration=longest,atrim=0:{total}",
       "-ar", str(RATE), "-ac", "2", out)
    return out


def main():
    if not shutil.which("ffmpeg"):
        sys.exit("ffmpeg is needed")
    update = len(sys.argv) > 1 and sys.argv[1] == "update"
    edit = UPDATE_EDIT if update else EDIT
    name = "neon_mega_tank_update" if update else "neon_mega_tank"
    end_lines = UPDATE_END_LINES if update else END_LINES
    switch_index = 1 if update else MUSIC_SWITCH_INDEX
    if os.path.isdir(WORK):
        shutil.rmtree(WORK)
    os.makedirs(WORK, exist_ok=True)
    videos, audios = [], []
    t = 0.0
    switch_at = 0.0
    for i, item in enumerate(edit):
        kind = item[0]
        if i == switch_index:
            switch_at = t
        print(f"[{t:6.2f}s] {kind:5} {item[1] if kind != 'card' else item[1][0][0]}")
        if kind == "card":
            videos.append(video_card(i, item[1], item[2]))
            t += item[2]
        else:
            videos.append(video_shot(i, item[1], item[2], item[3], end_card=kind == "end",
                                     cap=item[4] if len(item) > 4 else None, end_lines=end_lines))
            t += item[3]
        audios.append(audio_segment(i, kind, item))
    total = t
    video = os.path.join(WORK, "video.mp4")
    concat(videos, video)
    game = os.path.join(WORK, "game.wav")
    concat(audios, game, copy=False)
    mus = music(total, switch_at)
    final = os.path.join(OUT, name + "_trailer.mp4")
    ff("-i", video, "-i", game, "-i", mus, "-filter_complex",
       "[2:a]volume=0.62[m];[1:a]volume=1.0[g];[m][g]amix=inputs=2:normalize=0:duration=first,"
       "alimiter=limit=0.95,loudnorm=I=-15:TP=-1.5:LRA=11[a]",
       "-map", "0:v", "-map", "[a]", "-c:v", "libx264", "-preset", "slow", "-crf", "22",
       "-maxrate", "3000k", "-bufsize", "6000k", "-pix_fmt", "yuv420p", "-profile:v", "high",
       "-c:a", "aac", "-b:a", "160k", "-ar", str(RATE), "-movflags", "+faststart", "-t", f"{total}", final)
    poster = os.path.join(OUT, name + "_poster.jpg")
    poster_take, poster_at = ("shield", 2.6) if update else ("boss", 3.2)
    ff("-ss", f"{WARMUP + poster_at:.2f}", "-i", os.path.join(TAKES, poster_take + ".avi"), "-frames:v", "1",
       "-vf", f"scale={W}:{H}", "-q:v", "3", poster)
    print(f"trailer: {final} ({total:.1f}s)\nposter:  {poster}")


if __name__ == "__main__":
    main()
