#!/usr/bin/env python3
"""The game's music, composed and synthesised here and written to audio/music_*.ogg.

    python3 art/source/music/build_music.py [out_dir]        (default: audio/)

North Sea folk in the modes, played by a small band made in numpy: a tin whistle, a
clarsach (small harp), a fiddle, a reed drone like a harmonium's or the pipes', a soft
string pad, a frame drum (bodhran), a low bowed string and glassy harmonics, all in a
stone room's reverb. Six pieces:

    title       "The Light on the Skerry": a slow air in D aeolian, 3/4. Loops.
    day         "Mending Nets": gentle, brighter (D mixolydian), harp-led, 6/8. Loops.
    night       "The Water is Moving": tense drones, a heartbeat drum, b2 swells. Loops.
    finale      "Hold the Light": a driving reel in D minor for the last night. Loops.
    chapter_end "The Mary Ann": the title's air turned to the major, for going home.
    game_over   "Dark": a falling phrase and the drone dying away.

Loops are rendered with their reverb tail wrapped round onto the start, so they loop
without a seam. Needs numpy and ffmpeg (libvorbis).
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

SR = 44100
RNG = np.random.default_rng(1798)


def hz(m):
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


def env_adsr(n, a, d, s, r, sr=SR):
    """Attack, decay, sustain level, release (seconds); n samples long including release."""
    e = np.ones(n) * s
    na, nd, nr = int(a * sr), int(d * sr), int(r * sr)
    na = max(1, min(na, n))
    e[:na] = np.linspace(0.0, 1.0, na)
    nd = max(0, min(nd, n - na))
    if nd:
        e[na:na + nd] = np.linspace(1.0, s, nd)
    nr = max(1, min(nr, n))
    e[n - nr:] *= np.linspace(1.0, 0.0, nr)
    return e


# ---- the band ----

def whistle(m, dur, vel=1.0):
    """A tin whistle: nearly pure, a breathy edge, a scoop up into the note, vibrato that
    blooms on long notes."""
    n = int((dur + 0.12) * SR)
    t = np.arange(n) / SR
    f = hz(m) * (1.0 - 0.012 * np.exp(-t / 0.035))
    vib = 0.006 * np.sin(2 * np.pi * 5.6 * t) * np.clip((t - 0.3) / 0.4, 0, 1)
    ph = 2 * np.pi * np.cumsum(f * (1 + vib)) / SR
    tone = np.sin(ph) + 0.18 * np.sin(2 * ph) + 0.05 * np.sin(3 * ph)
    # A little breath, only round the note's own pitch (the noise ring-modulated by it),
    # so it's air in the tone, not hiss across everything.
    breath = RNG.standard_normal(n)
    breath = np.convolve(breath, np.ones(30) / 30, mode="same")
    sig = tone + 0.25 * breath * np.sin(ph) * np.exp(-t / 0.4)
    return sig * env_adsr(n, 0.03, 0.15, 0.85, 0.12) * 0.32 * vel


def fiddle(m, dur, vel=1.0):
    """A fiddle: a bright bowed tone (a band-limited saw, the top rolled off), a quick
    bite at the start of each bow, a little vibrato."""
    n = int((dur + 0.06) * SR)
    t = np.arange(n) / SR
    f = hz(m)
    vib = 0.004 * np.sin(2 * np.pi * 6.2 * t) * np.clip((t - 0.12) / 0.2, 0, 1)
    ph = 2 * np.pi * np.cumsum(f * (1 + vib)) / SR
    sig = np.zeros(n)
    for k in range(1, 14):
        if f * k > SR * 0.45:
            break
        sig += np.sin(k * ph) / (k ** 1.15) * (0.9 if k % 2 else 1.0)
    bite = 1.0 + 0.6 * np.exp(-t / 0.03)
    return sig * bite * env_adsr(n, 0.015, 0.08, 0.8, 0.05) * 0.12 * vel


def harp(m, dur, vel=1.0):
    """A clarsach string: plucked, bright then mellowing, each partial dying at its own rate."""
    n = int((dur + 2.5) * SR)
    t = np.arange(n) / SR
    f = hz(m)
    sig = np.zeros(n)
    for k in range(1, 10):
        fk = f * k * (1 + 0.0004 * k * k)
        if fk > SR * 0.45:
            break
        sig += np.sin(2 * np.pi * fk * t) * (1.0 / k ** 1.25) * np.exp(-t * (1.1 + 0.9 * k))
    sig *= np.clip(t / 0.003, 0, 1)
    return sig * 0.22 * vel


def pad(ms, dur, vel=1.0, bright=1.6):
    """A soft string pad on these notes: three detuned voices each, slow in, slow out."""
    n = int((dur + 1.5) * SR)
    t = np.arange(n) / SR
    sig = np.zeros(n)
    for m in ms:
        for det in (-0.004, 0.0, 0.0045):
            f = hz(m) * (1 + det)
            ph0 = RNG.uniform(0, 2 * np.pi)
            for k in range(1, 9):
                if f * k > 6000:
                    break
                sig += np.sin(2 * np.pi * f * k * t + ph0 * k) / (k ** bright)
    sig /= max(1, len(ms)) * 3
    return sig * env_adsr(n, min(1.2, dur * 0.4), 0.4, 0.8, 1.5) * 0.16 * vel


def drone(ms, dur, vel=1.0, steady=False):
    """A reed drone: odd-heavy, nasal, steady, slowly beating. `steady`: no swell in or
    out (for a loop; see loop_drone)."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    sig = np.zeros(n)
    for m in ms:
        f = hz(m) * (1 + 0.0015 * np.sin(2 * np.pi * 0.11 * t))
        ph = 2 * np.pi * np.cumsum(f) / SR
        for k in range(1, 12):
            sig += np.sin(k * ph) * (1.0 / k) * (1.0 if k % 2 else 0.45)
    sig /= len(ms)
    if steady:
        return sig * 0.06 * vel
    return sig * env_adsr(n, 2.0, 0.5, 1.0, 2.0) * 0.06 * vel


def cello(m, dur, vel=1.0):
    """A low bowed string, dark."""
    n = int((dur + 0.3) * SR)
    t = np.arange(n) / SR
    f = hz(m)
    vib = 0.003 * np.sin(2 * np.pi * 5.0 * t)
    ph = 2 * np.pi * np.cumsum(f * (1 + vib)) / SR
    sig = np.zeros(n)
    for k in range(1, 10):
        sig += np.sin(k * ph) / (k ** 1.7)
    return sig * env_adsr(n, 0.25, 0.3, 0.85, 0.3) * 0.2 * vel


def bodhran(vel=1.0, low=True):
    """A frame-drum hit: a falling low thump and a skin slap."""
    n = int(0.5 * SR)
    t = np.arange(n) / SR
    f = (62 if low else 95) * (1 + 0.6 * np.exp(-t / 0.03))
    thump = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / (0.16 if low else 0.08))
    slap = RNG.standard_normal(n)
    slap = np.convolve(slap, np.ones(12) / 12, mode="same") * np.exp(-t / 0.02)
    return (thump * 0.55 + slap * 0.25) * vel


def glass(m, dur, vel=1.0):
    """Glassy harmonics, trembling: the sea's eerie shimmer."""
    n = int((dur + 1.0) * SR)
    t = np.arange(n) / SR
    sig = np.sin(2 * np.pi * hz(m) * t) + 0.3 * np.sin(2 * np.pi * hz(m) * 2.01 * t)
    trem = 0.6 + 0.4 * np.sin(2 * np.pi * 3.3 * t)
    return sig * trem * env_adsr(n, 0.8, 0.2, 0.9, 1.0) * 0.04 * vel


# ---- putting it down ----

class Track:
    def __init__(self, seconds, bpm):
        self.n = int(seconds * SR)
        self.buf = np.zeros((self.n + 6 * SR, 2))
        self.beat = 60.0 / bpm

    def put(self, sig, at_beats, pan=0.0, gain=1.0):
        i = int(at_beats * self.beat * SR)
        if i >= len(self.buf):
            return
        sig = sig[: len(self.buf) - i] * gain
        left = np.cos((pan + 1) * np.pi / 4)
        right = np.sin((pan + 1) * np.pi / 4)
        self.buf[i:i + len(sig), 0] += sig * left
        self.buf[i:i + len(sig), 1] += sig * right

    def loop_drone(self, ms, vel=1.0):
        """A drone the whole length of a loop, its end crossfaded into its start so it
        never dips or clicks at the join."""
        f = int(2.0 * SR)
        sig = drone(ms, (self.n + f + 2) / SR, vel, steady=True)
        out = sig[: self.n].copy()
        r = np.linspace(0.0, 1.0, f)
        out[:f] = sig[:f] * np.sqrt(r) + sig[self.n:self.n + f] * np.sqrt(1.0 - r)
        self.buf[: self.n, 0] += out * np.cos(np.pi / 4)
        self.buf[: self.n, 1] += out * np.sin(np.pi / 4)

    def line(self, voice, notes, start, pan=0.0, gain=1.0, legato=1.0):
        """notes: (midi or None, beats) in order from `start` beats."""
        at = start
        for m, d in notes:
            if m is not None:
                self.put(voice(m, d * self.beat * legato), at, pan, gain)
            at += d
        return at


def reverb(buf, seconds=2.6, mix=0.32, damp=0.0008):
    """A stone room: convolution with decaying, darkening noise, a little different each side."""
    n = int(seconds * SR)
    t = np.arange(n) / SR
    out = np.zeros_like(buf)
    for ch in range(2):
        ir = RNG.standard_normal(n) * np.exp(-t / (seconds / 6.0))
        # Darker as it decays: smooth more toward the end.
        ir = np.convolve(ir, np.ones(4) / 4, mode="same") * (1 - t / seconds) + np.convolve(ir, np.ones(24) / 24, mode="same") * (t / seconds)
        ir[: int(0.018 * SR)] = 0.0
        ir /= np.sqrt(np.sum(ir ** 2))
        size = 1
        while size < len(buf) + n:
            size *= 2
        wet = np.fft.irfft(np.fft.rfft(buf[:, ch], size) * np.fft.rfft(ir, size), size)[: len(buf)]
        out[:, ch] = buf[:, ch] * (1 - mix) + wet * mix * 1.8
    return out


def finish(track, loop):
    buf = reverb(track.buf)
    if loop:
        # Wrap the tail round onto the start so the end flows back into the beginning.
        tail = buf[track.n:]
        head = buf[: track.n].copy()
        k = min(len(tail), len(head))
        head[:k] += tail[:k]
        buf = head
    else:
        last = np.nonzero(np.max(np.abs(buf), axis=1) > 1e-4)[0]
        buf = buf[: (last[-1] + 1 if len(last) else len(buf))]
        f = int(0.5 * SR)
        buf[-f:] *= np.linspace(1, 0, f)[:, None]
    buf = np.tanh(buf * 1.2) / np.tanh(1.2)
    return buf / max(1e-6, np.max(np.abs(buf))) * 0.89


# ---- the pieces ----

# The air (D aeolian), bars of 3/4: (midi, beats).
AIR = [
    [(69, 1), (74, 2)], [(76, 1), (77, 1), (76, 1)], [(74, 2), (72, 1)], [(69, 3)],
    [(67, 1), (69, 2)], [(72, 1), (74, 1), (76, 1)], [(77, 2), (76, 1)], [(74, 3)],
    [(77, 1), (79, 2)], [(81, 2), (79, 1)], [(77, 1), (76, 1), (74, 1)], [(72, 3)],
    [(74, 1), (76, 1), (77, 1)], [(76, 2), (72, 1)], [(74, 3)], [(74, 3)],
]
# Its chords, a bar each: root, then the triad's notes.
AIR_CHORDS = [
    (50, [62, 65, 69]), (48, [60, 64, 67]), (50, [62, 65, 69]), (45, [57, 60, 64]),
    (43, [55, 58, 62]), (48, [60, 64, 67]), (41, [53, 57, 60]), (50, [62, 65, 69]),
    (41, [53, 57, 60]), (48, [60, 64, 67]), (50, [62, 65, 69]), (45, [57, 60, 64]),
    (46, [58, 62, 65]), (48, [60, 64, 67]), (50, [62, 65, 69]), (50, [62, 65, 69]),
]


def flat(bars):
    out = []
    for b in bars:
        out += b
    return out


def title():
    tr = Track(16 * 3 * 2 * 60 / 72, 72)
    tr.loop_drone([38, 45])
    for rep in range(2):
        start = rep * 48
        for i, (root, tri) in enumerate(AIR_CHORDS):
            b = start + i * 3
            tr.put(pad(tri, 3 * tr.beat), b, -0.2, 0.9)
            for k, m in enumerate([root + 12] + tri):
                if k < 3 or rep == 1:
                    tr.put(harp(m, tr.beat), b + k * 0.75, 0.35, 0.8)
        if rep == 0:
            tr.line(whistle, flat(AIR), start, -0.1, 1.0)
        else:
            # The second time round, an octave down on the fiddle, softer.
            tr.line(lambda m, d: fiddle(m - 12, d, 0.8), flat(AIR), start, 0.15, 0.9)
    return finish(tr, True)


def day():
    beats = 16 * 2 * 3
    tr = Track(beats * 60 / 132, 132)
    tr.loop_drone([38], 0.6)
    tune = [
        [(74, 1), (76, 1), (78, 1), (81, 3)], [(79, 1), (78, 1), (76, 1), (72, 3)],
        [(74, 2), (76, 1), (78, 2), (76, 1)], [(74, 6)],
        [(71, 1), (74, 1), (79, 1), (78, 3)], [(76, 1), (74, 1), (72, 1), (74, 3)],
        [(72, 2), (71, 1), (69, 2), (72, 1)], [(74, 6)],
    ]
    chords = [(50, [62, 66, 69]), (48, [60, 64, 67]), (50, [62, 66, 69]), (50, [62, 66, 69]),
              (43, [55, 59, 62]), (50, [62, 66, 69]), (48, [60, 64, 67]), (50, [62, 66, 69])]
    for rep in range(4):
        start = rep * 8 * 6
        for i, (root, tri) in enumerate(chords):
            b = start + i * 6
            if rep % 2 == 1:
                tr.put(pad(tri, 6 * tr.beat, 0.6), b, 0.0, 0.8)
            # Harp: a lilting broken chord across the bar.
            for k, m in enumerate([root + 12, tri[0], tri[1], tri[2], tri[1] + 12, tri[0]]):
                tr.put(harp(m, tr.beat, 0.8 if k else 1.0), b + k, 0.3 if k % 2 else -0.3, 0.75)
        if rep in (1, 3):
            tr.line(whistle, flat(tune), start, -0.15, 0.85)
    return finish(tr, True)


def night():
    beats = 64
    tr = Track(beats * 60 / 60, 60)
    tr.loop_drone([26, 38, 45], 1.2)
    # Swells: the sea's minor second against the drone.
    swells = [([62, 65], 0), ([63, 67], 8), ([62, 65, 69], 16), ([63, 66], 24), ([62, 65], 32), ([61, 64, 70], 40), ([63, 67], 48), ([62, 65], 56)]
    for notes, at in swells:
        tr.put(pad(notes, 7.5, 0.9, bright=2.2), at, -0.3, 1.0)
    # The low string: a slow, uneasy ground.
    ground = [(38, 4), (39, 4), (38, 4), (36, 4)] * 4
    tr.line(cello, ground, 0, 0.1, 1.0)
    # A heartbeat on the drum.
    for b in range(0, beats, 2):
        tr.put(bodhran(0.7), b, 0.0, 0.8)
        tr.put(bodhran(0.4), b + 0.35, 0.0, 0.8)
    # Glass, high and far.
    for at, m in [(6, 93), (19, 94), (31, 92), (45, 94), (58, 91)]:
        tr.put(glass(m, 5.0), at, 0.6 if at % 2 else -0.6, 1.0)
    # The whistle, distant, never finishing its phrase.
    tr.line(lambda m, d: whistle(m, d, 0.55), [(69, 2), (70, 1), (69, 3)], 12, 0.5, 0.7)
    tr.line(lambda m, d: whistle(m, d, 0.5), [(74, 1.5), (72, 1.5), (70, 2), (69, 3)], 36, -0.5, 0.7)
    return finish(tr, True)


def finale():
    bars = 32
    tr = Track(bars * 6 * 60 / 330, 330)
    tr.loop_drone([38, 45], 1.1)
    # The reel's figure, in eighths (6 to a bar of 6/8).
    a = [74, 77, 81, 77, 74, 77, 72, 76, 79, 76, 72, 76, 70, 74, 77, 74, 70, 74, 69, 72, 76, 74, 72, 69]
    b = [81, 79, 77, 76, 74, 76, 77, 76, 74, 72, 70, 72, 74, 72, 70, 69, 67, 69, 70, 72, 74, 74, 74, 74]
    chords = [(38, [62, 65, 69]), (36, [60, 64, 67]), (34, [58, 62, 65]), (33, [57, 61, 64])]
    for rep in range(bars // 4):
        start = rep * 24
        for i, (root, tri) in enumerate(chords):
            tr.put(pad(tri, 6 * tr.beat, 1.0, bright=1.3), start + i * 6, -0.25, 0.9)
            tr.put(cello(root, 3 * tr.beat), start + i * 6, 0.0, 1.0)
            tr.put(cello(root, 3 * tr.beat), start + i * 6 + 3, 0.0, 0.8)
        fig = a if rep % 2 == 0 else b
        if rep >= 1:
            tr.line(fiddle, [(m, 1) for m in fig], start, 0.2, 1.0, legato=0.92)
        if rep >= 4:
            tr.line(lambda m, d: whistle(m + 12, d, 0.6), [(m, 2) for m in fig[::2]], start, -0.3, 0.7)
        # The bodhran: driving, the accent on one and four.
        for e in range(24):
            accent = e % 3 == 0
            tr.put(bodhran(1.0 if accent else 0.45, low=accent), start + e, 0.0, 0.9)
    return finish(tr, True)


def chapter_end():
    tr = Track(16 * 3 * 60 / 70 + 4.0, 70)
    major_air = []
    for bar in AIR:
        major_air.append([(m + 1 if m % 12 in (5, 0) else m, d) for m, d in bar])
    chords = [(50, [62, 66, 69]), (45, [57, 61, 64]), (50, [62, 66, 69]), (45, [57, 61, 64]),
              (43, [55, 59, 62]), (45, [57, 61, 64]), (47, [59, 62, 66]), (50, [62, 66, 69]),
              (43, [55, 59, 62]), (45, [57, 61, 64]), (50, [62, 66, 69]), (47, [59, 62, 66]),
              (43, [55, 59, 62]), (45, [57, 61, 64]), (50, [62, 66, 69]), (50, [62, 66, 69, 74])]
    tr.put(drone([38, 45], tr.n / SR), 0, 0.0, 0.8)
    for i, (root, tri) in enumerate(chords):
        b = i * 3
        tr.put(pad(tri, (3 if i < 15 else 8) * tr.beat, 1.1), b, -0.2, 0.9)
        for k, m in enumerate([root + 12] + tri):
            tr.put(harp(m, tr.beat), b + k * 0.75, 0.3, 0.8)
    tr.line(whistle, flat(major_air[:15]) + [(74, 6)], 0, 0.0, 1.0)
    return finish(tr, False)


def game_over():
    tr = Track(14.0, 60)
    tr.put(drone([38, 45], 12.0), 0, 0.0, 1.0)
    tr.put(pad([62, 65, 69], 8.0, 0.9, bright=2.0), 0, -0.2, 1.0)
    tr.line(whistle, [(69, 1), (67, 1), (65, 1), (64, 1.5), (62, 4)], 0.5, 0.0, 0.9)
    tr.put(cello(38, 8.0), 0, 0.0, 0.9)
    return finish(tr, False)


PIECES = {"title": title, "day": day, "night": night, "finale": finale, "chapter_end": chapter_end, "game_over": game_over}


def write_ogg(buf, path):
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "m.wav")
        pcm = (np.clip(buf, -1, 1) * 32767).astype("<i2")
        with wave.open(wav, "wb") as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "4", path], check=True)


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "..", "..", "audio")
    os.makedirs(out, exist_ok=True)
    only = sys.argv[2:] or list(PIECES)
    for name in only:
        buf = PIECES[name]()
        path = os.path.join(out, "music_%s.ogg" % name)
        write_ogg(buf, path)
        print("%-12s %5.1f s  %s" % (name, len(buf) / SR, os.path.normpath(path)))


if __name__ == "__main__":
    main()
