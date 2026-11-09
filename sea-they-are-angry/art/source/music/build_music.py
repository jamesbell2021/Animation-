#!/usr/bin/env python3
"""The game's music, composed and synthesised here and written to audio/music_*.ogg.

    python3 art/source/music/build_music.py [out_dir]        (default: audio/)

Two bands, both made in numpy. The days are North Sea folk in the modes: a tin whistle,
a clarsach (small harp), a fiddle, a reed drone like a harmonium's or the pipes', a soft
string pad, a frame drum (bodhran), a low bowed string and glassy harmonics, all in a
stone room's reverb.

    day         "Mending Nets": gentle, brighter (D mixolydian), harp-led, 6/8. Loops.
    chapter_end "The Mary Ann": a slow air in D major, for going home.

The nights are a coastal horror film of about 1980: a cold, small analogue synth score.
A saw bass pulsing in eighths, a felt piano's sparse figure, slow detuned saw pads, a
thin high lead, a soft kick like a heartbeat, a long reverb, all a little worn by tape.
One figure of a few notes (FIGURE) runs through every one of them.

    title         "Nobody on the Quay": the figure alone on the piano, slowly, over a low
                  drone; a foghorn now and then. D minor. Loops.
    night         "Something in the Water": the bass pulse, the figure coming in after
                  some bars, pads swelling. D minor, 92 to the minute. Loops.
    harbour_night "The Bell at Low Tide": the same a tone lower and darker, a bell
                  tolling across the bars. C minor. Loops.
    finale        "Hold the Light": the last night; the bass jumping octaves, a racing
                  arpeggio, the figure insisting. D minor, 126. Loops.
    harbour_day   "Shutters": the deserted harbour by day; a thin pad, a few piano notes
                  and a lot of room. Loops.
    game_over     "Dark": the figure falling apart as the tape runs down.
    ending        "First Light": the figure in the major, warm, and the whistle from
                  "Mending Nets" somewhere far off. Ends on a held chord.

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


# ---- the synthesisers (the nights) ----

def lowpass_gain(f, cutoff, res=0.0):
    """How much of frequency f a four-pole low-pass at `cutoff` lets through (both Hz,
    broadcast together), with a lift of `res` just at the cutoff."""
    x = f / cutoff
    g = 1.0 / np.sqrt(1.0 + x ** 8)
    if res:
        g = g * (1.0 + res * np.exp(-np.log2(x) ** 2 / 0.08))
    return g


def osc(f, n, cutoff, shape="saw", pw=0.5, res=0.0, phase=0.0):
    """An analogue oscillator through its filter: a saw or a pulse (`pw` its width) at f
    Hz, low-passed at `cutoff` Hz; either may be one number or one a sample. Built from
    its harmonics, each at the level the filter would leave it, so nothing is made above
    the filter to alias or to be harsh."""
    i = np.arange(n)
    moving = np.ndim(f) > 0
    ph = (2 * np.pi * np.cumsum(f) / SR if moving else 2 * np.pi * f * i / SR) + phase
    # The filter's gain on each harmonic is worked out every 32 samples and joined up.
    at = np.unique(np.append(np.arange(0, n, 32), n - 1))
    fc = np.asarray(f)[at] if moving else f
    cc = np.asarray(cutoff)[at] if np.ndim(cutoff) > 0 else cutoff
    still = not moving and np.ndim(cutoff) == 0
    top = min(SR * 0.45, 3.0 * np.max(cutoff))
    sig = np.zeros(n)
    for k in range(1, max(1, int(top / np.min(f))) + 1):
        if k * np.max(f) > SR * 0.45:
            break
        if shape == "saw":
            a, wave_k = 2.0 / (np.pi * k), np.sin(k * ph)
        else:
            a, wave_k = 4.0 / (np.pi * k) * np.sin(np.pi * k * pw), np.cos(k * ph)
        if abs(a) < 1e-4:
            continue
        g = lowpass_gain(k * fc, cc, res)
        sig += a * (g if still else np.interp(i, at, g)) * wave_k
    return sig


_MADE = {}  # The pulse bass and the arpeggio play the same few notes hundreds of times.


def synth_bass(m, dur, vel=1.0, openness=0.5):
    """The pulse bass: a saw and a pulse a hair apart, the filter snapping shut behind
    the start of each note. `openness` (0 to 1): how far the filter is let open."""
    key = ("bass", m, round(dur, 4), round(vel, 2), round(openness, 2))
    if key not in _MADE:
        n = int((dur + 0.07) * SR)
        t = np.arange(n) / SR
        cut = 150.0 + 500.0 * openness + (250.0 + 1300.0 * openness) * vel * np.exp(-t / 0.085)
        sig = osc(hz(m), n, cut, "saw", res=0.3) + 0.6 * osc(hz(m) * 1.004, n, cut, "pulse", pw=0.38, res=0.3)
        _MADE[key] = sig * env_adsr(n, 0.004, 0.12, 0.65, 0.07) * 0.2 * (0.55 + 0.45 * vel)
    return _MADE[key]


def synth_pluck(m, dur, vel=1.0, openness=0.5):
    """The arpeggio's voice: a narrow pulse, plucked, the filter closing fast."""
    key = ("pluck", m, round(dur, 4), round(vel, 2), round(openness, 2))
    if key not in _MADE:
        n = int((dur + 0.12) * SR)
        t = np.arange(n) / SR
        cut = 350.0 + 700.0 * openness + (500.0 + 2200.0 * openness) * vel * np.exp(-t / 0.06)
        sig = osc(hz(m), n, cut, "pulse", pw=0.3, res=0.35)
        _MADE[key] = sig * env_adsr(n, 0.003, 0.09, 0.45, 0.12) * 0.11 * (0.5 + 0.5 * vel)
    return _MADE[key]


def saw_pad(ms, dur, vel=1.0, cutoff=900.0, swell=600.0, attack=None, release=3.0, shape="saw", pw=0.5):
    """Slow detuned saws, a string machine: three voices to a note, each wandering a
    little on its own, the filter opening as the chord swells and closing as it goes."""
    n = int((dur + release) * SR)
    t = np.arange(n) / SR
    e = env_adsr(n, min(3.0, dur * 0.45) if attack is None else attack, 0.0, 1.0, release)
    e = e * e * (3.0 - 2.0 * e)
    cut = cutoff + swell * e
    sig = np.zeros(n)
    for m in ms:
        for det in (-0.0035, 0.0, 0.004):
            wander = 0.0012 * np.sin(2 * np.pi * RNG.uniform(0.2, 0.6) * t + RNG.uniform(0, 2 * np.pi))
            sig += osc(hz(m) * (1 + det) * (1 + wander), n, cut, shape, pw, phase=RNG.uniform(0, 2 * np.pi))
    return sig / np.sqrt(3 * len(ms)) * e * 0.09 * vel


def synth_drone(ms, dur, vel=1.0, cutoff=240.0, loop=False, sag=0.0):
    """Low saws, the filter nearly shut and slowly breathing: the bed under a piece.
    `loop`: for a loop `dur` long; every pitch and the breathing are nudged to fit it a
    whole number of times, so the drone meets itself exactly, with no swell in or out.
    `sag`: semitones the pitch sinks by the end, like a tape running down."""
    n = int(round(dur * SR))
    t = np.arange(n) / SR
    fit = (lambda f: round(f * dur) / dur) if loop else (lambda f: f)
    cut = cutoff * (1.0 + 0.3 * np.sin(2 * np.pi * fit(0.045) * t))
    if sag:
        cut = cut * (1.0 - 0.75 * t / dur)
    sig = np.zeros(n)
    for m in ms:
        for det in (-0.0025, 0.003):
            f = fit(hz(m) * (1 + det))
            if sag:
                f = f * 2.0 ** (-(sag / 12.0) * (t / dur) ** 2)
            sig += osc(f, n, cut, "saw", res=0.1, phase=RNG.uniform(0, 2 * np.pi))
    sig *= 0.1 * vel / np.sqrt(2 * len(ms))
    if loop:
        return sig
    return sig * env_adsr(n, min(1.5, dur * 0.2), 0.5, 1.0, min(6.0, dur * 0.6))


def felt_piano(m, dur, vel=1.0, cents=0.0):
    """A felted upright, close and soft: stiff strings (the partials a shade sharp), two
    to a note, the second quieter and not quite in tune, each partial dying at its own rate, the hammer's
    thump. `dur`: how long the key is held; `cents`: out of tune by that much."""
    n = int((dur + 0.4) * SR)
    t = np.arange(n) / SR
    f = hz(m + cents / 100.0)
    ring = float(np.clip(3.2 * (261.6 / f) ** 0.55, 0.9, 7.0))
    soft = 2.0 - 0.5 * vel
    sig = np.zeros(n)
    for k in range(1, 17):
        fk = f * k * np.sqrt(1 + 0.0005 * k * k)
        if fk > 5500:
            break
        a = abs(np.sin(np.pi * k / 8.3)) / k ** soft
        die = np.exp(-t * (1 + 0.28 * (k - 1)) / ring)
        sig += a * die * (np.sin(2 * np.pi * fk * 0.9998 * t) + 0.45 * np.sin(2 * np.pi * fk * 1.0004 * t + 0.3 * k))
    thump = np.convolve(RNG.standard_normal(n), np.ones(60) / 60, mode="same") * np.exp(-t / 0.012)
    sig = (sig + 0.5 * thump) * np.clip(t / 0.004, 0, 1)
    nr = int(0.4 * SR)
    sig[n - nr:] *= np.linspace(1.0, 0.0, nr) ** 2
    return sig * 0.25 * vel ** 1.3


def epiano(m, dur, vel=1.0):
    """An electric piano: a tine's tick over a round body that barks a little when it's
    hit hard (two FM pairs), a slow tremolo."""
    n = int((dur + 0.4) * SR)
    t = np.arange(n) / SR
    w = 2 * np.pi * hz(m) * t
    body = np.sin(w + 1.1 * vel * np.exp(-t / 0.5) * np.sin(w))
    tine = np.sin(w + 0.35 * vel * np.exp(-t / 0.07) * np.sin(7 * w))
    sig = (body + 0.3 * tine) * np.exp(-t / 2.2) * (1.0 + 0.1 * np.sin(2 * np.pi * 4.6 * t))
    return sig * env_adsr(n, 0.004, 0.1, 0.9, 0.4) * 0.17 * vel


def fm_bell(m, dur=8.0, vel=1.0):
    """A bell tolling, a synthesiser's: two FM pairs whose modulators sit at 3.5 and 1.41
    times the note (no harmonic of it), a few cents apart so the tone slowly beats, and a
    hum an octave under. Bright where it's struck, mellowing as it rings."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    w = 2 * np.pi * hz(m) * t
    a = np.sin(w + (1.7 * np.exp(-t / 1.1) + 0.3) * np.sin(3.5 * w))
    b = np.sin(1.004 * w + (1.0 * np.exp(-t / 2.0) + 0.2) * np.sin(1.41 * w))
    hum = np.sin(0.5 * 0.997 * w)
    sig = (a + 0.6 * b) * np.exp(-t * 5.0 / dur) + 0.45 * hum * np.exp(-t * 3.5 / dur)
    nr = int(0.5 * SR)
    sig[n - nr:] *= np.linspace(1.0, 0.0, nr)
    return sig * np.clip(t / 0.006, 0, 1) * 0.16 * vel


def soft_kick(vel=1.0):
    """A soft kick, half of a heartbeat: a low thump falling in pitch, no click on it."""
    n = int(0.5 * SR)
    t = np.arange(n) / SR
    f = 58.0 + 65.0 * np.exp(-t / 0.04)
    sig = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.1) * np.clip(t / 0.005, 0, 1) * np.clip((0.5 - t) / 0.1, 0, 1)
    return sig * 0.32 * vel


def tick(vel=1.0):
    """A clock's tick, small and dry."""
    n = int(0.06 * SR)
    t = np.arange(n) / SR
    sig = np.sin(2 * np.pi * 2300 * t) + 0.5 * np.sin(2 * np.pi * 3650 * t)
    return sig * np.exp(-t / 0.006) * np.clip(t / 0.0006, 0, 1) * 0.05 * vel


def thin_lead(m, dur, vel=1.0):
    """The high thin lead: one narrow pulse, the filter half shut, sliding up into the
    note, the vibrato coming late."""
    n = int((dur + 0.7) * SR)
    t = np.arange(n) / SR
    vib = 0.005 * np.sin(2 * np.pi * 5.1 * t) * np.clip((t - 0.7) / 0.9, 0, 1)
    f = hz(m) * (1.0 - 0.03 * np.exp(-t / 0.07)) * (1 + vib)
    e = env_adsr(n, 0.3, 0.3, 0.8, 0.7)
    return osc(f, n, 1300.0 + 1100.0 * e, "pulse", pw=0.22, res=0.2) * e * 0.06 * vel


def foghorn(m, dur=3.0, vel=1.0):
    """A foghorn a long way off: a low note swelling in, held, and dropping away in
    pitch as it stops."""
    n = int((dur + 0.9) * SR)
    t = np.arange(n) / SR
    f = hz(m) * 2.0 ** (-(7.0 / 12.0) * np.clip((t - dur + 0.1) / 0.6, 0, 1))
    e = env_adsr(n, 0.4, 0.2, 0.9, 0.9)
    sig = osc(f, n, 300.0 + 220.0 * e, "saw", res=0.2) + 0.5 * osc(f * 1.003, n, 300.0 + 220.0 * e, "pulse", pw=0.4)
    return sig * e * 0.1 * vel


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


class SynthTrack(Track):
    """A Track for the synth pieces: a second, drier bus for the bass and the kick (a
    long reverb on those is only mud), and more room after the end for long tails."""

    def __init__(self, seconds, bpm, tail=12.0):
        Track.__init__(self, seconds, bpm)
        self.buf = np.zeros((self.n + int(tail * SR), 2))
        self.dry = np.zeros_like(self.buf)

    def put_dry(self, sig, at_beats, pan=0.0, gain=1.0):
        wet, self.buf = self.buf, self.dry
        self.put(sig, at_beats, pan, gain)
        self.buf = wet

    def bed(self, ms, vel=1.0, cutoff=240.0):
        """A synth drone the whole length of a loop, fitted to it (see synth_drone)."""
        self.put(synth_drone(ms, self.n / SR, vel, cutoff, loop=True), 0)

    def wide(self, sig_of, at_beats, gain=1.0, width=0.6):
        """The same thing made twice, one each side: sig_of() is called for each."""
        self.put(sig_of(), at_beats, -width, gain * 0.71)
        self.put(sig_of(), at_beats, width, gain * 0.71)


def tape(buf, loop):
    """What a reel of tape does: the top rolled off, a little weight round 100 Hz,
    nothing under 35 Hz, and the pitch wandering very slightly (wow). For a loop both
    run round its join, so it stays a loop."""
    n = len(buf)
    size = n if loop else n + SR
    f = np.fft.rfftfreq(size, 1.0 / SR)
    shape = 1.0 / np.sqrt(1.0 + (f / 8500.0) ** 4)
    shape *= (f / 35.0) ** 2 / np.sqrt(1.0 + (f / 35.0) ** 4)
    shape *= 1.0 + 0.15 * np.exp(-np.log2(np.maximum(f, 1.0) / 100.0) ** 2 / 1.5)
    out = np.empty_like(buf)
    secs = n / SR
    i = np.arange(n)
    # Wow: 0.1% of pitch at about 0.55 Hz and a slower 0.06%, a whole number to the loop.
    at = i.astype(float)
    for dev, rate in ((0.001, 0.55), (0.0006, 0.13)):
        rate = max(1.0, round(rate * secs)) / secs
        at += dev * SR / (2 * np.pi * rate) * np.sin(2 * np.pi * rate * i / SR)
    i0 = np.floor(at).astype(int)
    fr = at - i0
    for ch in range(2):
        x = np.fft.irfft(np.fft.rfft(buf[:, ch], size) * shape, size)[:n]
        if loop:
            y0, y1, y2, y3 = (x[(i0 + d) % n] for d in (-1, 0, 1, 2))
        else:
            y0, y1, y2, y3 = (x[np.clip(i0 + d, 0, n - 1)] for d in (-1, 0, 1, 2))
        c1 = 0.5 * (y2 - y0)
        c2 = y0 - 2.5 * y1 + 2.0 * y2 - 0.5 * y3
        c3 = 0.5 * (y3 - y0) + 1.5 * (y1 - y2)
        out[:, ch] = ((c3 * fr + c2) * fr + c1) * fr + y1
    return out


def soft_limit(buf, ceiling):
    """Tape again: left alone below 0.6 of the ceiling, rounded off into it above."""
    knee = 0.6 * ceiling
    over = np.maximum(np.abs(buf) - knee, 0.0)
    return np.where(over > 0, np.sign(buf) * (knee + (ceiling - knee) * np.tanh(over / (ceiling - knee))), buf)


def finish_synth(track, loop, rms_db=-14.0, room=4.5, wet=0.34, fade=3.0, ceiling=0.8):
    """finish() for a SynthTrack: a long reverb on the main bus and a short one on the
    dry bus, the tail wrapped round (a loop) or the end faded over `fade` seconds (not a
    loop), then tape. The level is set by loudness, to sit with the folk pieces (their
    RMS is -12 to -14 dBFS), and the peaks rounded off under `ceiling`."""
    buf = reverb(track.buf, room, wet) + reverb(track.dry, 1.6, 0.12)
    head = buf[: track.n].copy()
    if loop:
        tail = buf[track.n:]
        k = min(len(tail), len(head))
        head[:k] += tail[:k]
    else:
        f = int(fade * SR)
        head[-f:] *= (0.5 + 0.5 * np.cos(np.linspace(0, np.pi, f)))[:, None]
    buf = tape(head, loop)
    if not loop:
        buf[: SR // 100] *= np.linspace(0.0, 1.0, SR // 100)[:, None]
    buf *= 10.0 ** (rms_db / 20.0) / max(1e-9, np.sqrt(np.mean(buf ** 2)))
    return soft_limit(buf, ceiling)


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


# The night's figure: four bars of 4/4, each note (which eighth of the bar, semitones
# above the tonic). A falling fifth with the minor sixth leaning on it. The title plays it
# alone and slowly, the nights and the finale turn it round and round, the game over
# drops it, and the ending raises its thirds.
FIGURE = [
    [(0, 12), (3, 15), (6, 14)],
    [(0, 7), (3, 8), (6, 7)],
    [(0, 12), (3, 15), (6, 17)],
    [(0, 14), (6, 7)],
]


def figure(tr, voice, tonic, bar, which=(0, 1, 2, 3), major=False, flat2=False, pan=0.0, gain=1.0, hold=3.0, vel=1.0):
    """Play those bars of the figure on `voice`, starting at bar `bar`. `major`: its
    thirds raised; `flat2`: its second lowered, for the bars over the flat second."""
    for i, w in enumerate(which):
        for e, s in FIGURE[w]:
            if major and s in (15, 8):
                s += 1
            if flat2 and s == 14:
                s -= 1
            v = vel * (1.0 if e == 0 else 0.82)
            tr.put(voice(tonic + s, hold * tr.beat, v), (bar + i) * 4 + e * 0.5, pan, gain)


def title():
    bpm, bars = 60, 20
    tr = SynthTrack(bars * 4 * 60 / bpm, bpm)
    tr.bed([38, 45, 50], 0.75, 300.0)
    # The distant pad: a chord to each four bars, over the drone's D.
    pads = [[62, 69, 76], [58, 65, 69, 74], [55, 58, 62, 69], [63, 67, 70], [57, 62, 64, 69]]
    for p, notes in enumerate(pads):
        tr.wide(lambda: saw_pad(notes, 11 * tr.beat, 1.0, 700.0, 500.0), p * 16 + 3, 0.7)
    # The figure alone; again with a low note under it; half of it lower down; then with
    # its second flattened; then only its middle bar, and room for the foghorn.
    figure(tr, felt_piano, 62, 0, hold=4.0, vel=0.9)
    figure(tr, felt_piano, 62, 4, hold=4.0, vel=0.85)
    figure(tr, felt_piano, 50, 8, which=(0, 1), hold=5.0, vel=0.85)
    figure(tr, felt_piano, 62, 12, flat2=True, hold=4.0, vel=0.75)
    figure(tr, felt_piano, 62, 17, which=(1,), hold=5.0, vel=0.7)
    # Low notes under it, kept a third or more clear of the drone's D and A.
    for bar, m in [(4, 50), (6, 53), (8, 55), (12, 55), (14, 55), (16, 45), (16.5, 52)]:
        tr.put(felt_piano(m, 6.0, 0.7), bar * 4, -0.1, 1.0)
    for at in (26, 42, 74):
        tr.put(foghorn(45, 3.2), at, 0.4, 0.6)
    return finish_synth(tr, True, -14.0, room=5.0, wet=0.4)


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


def nights(tonic, bpm, dark=False):
    """Both night pieces. `tonic`: the key note above middle C (D for the night, C for
    the harbour's). `dark`: the filters further shut, the figure on an electric piano and
    less often, no lead, a bell tolling instead."""
    bars = 28
    tr = SynthTrack(bars * 4 * 60 / bpm, bpm)
    low = tonic - 24
    # Four bars each: i, i, VI, iv, i, the flat second, V.
    roots = [0, 0, -4, 5, 0, 1, -5]
    opened = [0.15, 0.45, 0.5, 0.55, 0.4, 0.6, 0.5, 0.15]
    for bar in range(bars):
        p = bar // 4
        # The pulse: eighths on the root, the filter opening and closing over the phrases.
        o = np.interp(bar / 4.0, range(8), opened) - (0.1 if dark else 0.0)
        o = round(o * 20) / 20.0
        for e in range(8):
            v = 1.0 if e == 0 else (0.85 if e == 4 else 0.7)
            tr.put_dry(synth_bass(low + roots[p], 0.4 * tr.beat, v, o), bar * 4 + e * 0.5)
        # The heartbeat: twice a bar, once a bar where the piece draws breath.
        for b in ((0,) if p in (0, 4) else (0, 2)):
            tr.put_dry(soft_kick(0.8), bar * 4 + b)
            tr.put_dry(soft_kick(0.5), bar * 4 + b + 0.5)
    # Pads, a swell to a phrase: bare fifths, the chords, a major seventh over the
    # minor where the piano is silent, the flat ninth to turn it round.
    pads = [(0, 12, [-12, -5, 0, 7]), (4, 12, [-5, 0, 3, 7]), (8, 12, [-4, 0, 3, 7]), (12, 12, [-7, -4, 0, 7]),
            (16, 7, [0, 3, 7]), (18, 7, [-1, 2, 7]), (20, 12, [-4, 0, 5, 7]), (24, 12, [-5, -1, 2, 8])]
    for bar, beats, notes in pads:
        chord = [tonic + s for s in notes]
        tr.wide(lambda: saw_pad(chord, beats * tr.beat, 1.0, 600.0 if dark else 800.0, 350.0 if dark else 600.0), bar * 4 + 2, 1.25)
    # The piano's figure: in after the first phrase, out for the fifth, half of it to end.
    keys = epiano if dark else felt_piano
    for p in ((1, 3, 5) if dark else (1, 2, 3, 5)):
        figure(tr, keys, tonic, p * 4, flat2=p == 5, pan=-0.15, gain=0.6 if dark else 1.0, vel=0.8)
    figure(tr, keys, tonic, 24, which=(0, 1), pan=-0.15, gain=0.6 if dark else 1.0, vel=0.7)
    if dark:
        # The bell: the fifth, every fourteen beats, so it never tolls in the same place.
        for k in range(8):
            tr.put(fm_bell(tonic - 5, 9.0, 1.0 if k % 2 == 0 else 0.8), 2 + 14 * k, 0.3 if k % 2 else -0.3, 0.8)
    else:
        # The lead: the figure's middle bar, very slowly, and one long note later.
        tr.line(thin_lead, [(tonic + 19, 6), (tonic + 20, 2), (tonic + 19, 5)], 50, 0.35, 0.8)
        tr.put(thin_lead(tonic + 24, 7 * tr.beat, 0.7), 84, -0.35)
    return finish_synth(tr, True, -14.5)


def night():
    return nights(62, 92)


def harbour_night():
    return nights(60, 88, dark=True)


def finale():
    bpm, bars = 126, 24
    tr = SynthTrack(bars * 4 * 60 / bpm, bpm)
    tonic, low = 62, 38
    roots = [0, 0, -4, 5, 1, -5]
    jump = [0, 0, 12, 0, 0, 12, 0, 12]
    # The arpeggio's notes for each phrase, low to high.
    arps = [[62, 65, 69, 74, 77], [62, 65, 69, 74, 77], [58, 62, 65, 70, 74], [58, 62, 67, 69, 74],
            [58, 63, 67, 69, 75], [57, 61, 64, 67, 70]]
    order = [0, 1, 2, 3, 4, 3, 2, 1] * 2
    for bar in range(bars):
        p = bar // 4
        # The bass: eighths again, now leaping the octave, three and three and two.
        o = round(np.interp(bar, [0, 4, 8, 12, 16, 20, 23], [0.4, 0.55, 0.6, 0.65, 0.7, 0.8, 0.5]) * 20) / 20.0
        for e in range(8):
            tr.put_dry(synth_bass(low + roots[p] + jump[e], 0.38 * tr.beat, 1.0 if e == 0 else 0.8, o), bar * 4 + e * 0.5, 0.0, 0.9)
        for b in range(4):
            tr.put_dry(soft_kick(0.65 if b % 2 == 0 else 0.45), bar * 4 + b)
            if p >= 1:
                tr.put(tick(1.0), bar * 4 + b + 0.5, 0.4, 2.0)
        # The arpeggio: sixteenths, its filter opening all the way through.
        o = round(np.interp(bar, [0, 8, 16, 22, 23], [0.15, 0.4, 0.6, 0.9, 0.7]) * 20) / 20.0
        for s in range(16):
            m = arps[p][order[s]]
            tr.put(synth_pluck(m, 0.2 * tr.beat, 1.0 if s % 4 == 0 else 0.7, o), bar * 4 + s * 0.25, 0.35 if s % 2 else -0.35)
    pads = [[50, 57, 62], [57, 62, 65, 69], [58, 62, 65, 69], [55, 58, 62, 69], [58, 62, 67, 69], [57, 61, 64, 70]]
    for p, notes in enumerate(pads):
        tr.wide(lambda: saw_pad(notes, 15 * tr.beat, 1.0, 1000.0, 800.0, attack=2.0, release=2.5), p * 16)
    # The figure, from the second phrase; an octave under it as well from the fourth.
    for p in range(1, 6):
        figure(tr, felt_piano, tonic, p * 4, flat2=p == 4, pan=-0.15, gain=0.8, vel=0.85)
        if p >= 3:
            figure(tr, felt_piano, tonic - 12, p * 4, flat2=p == 4, pan=0.15, gain=0.5, vel=0.8)
    # The lead climbs a semitone a phrase and falls to the leading note for the turn.
    for at, m, beats in [(48, 86, 14), (64, 87, 14), (80, 88, 8), (88, 85, 7)]:
        tr.put(thin_lead(m, beats * tr.beat), at, 0.3)
    return finish_synth(tr, True, -13.0, room=3.5, wet=0.28)


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
    tr = SynthTrack(14.0, 92)
    sec = lambda s: s / tr.beat
    # The tape runs down: the drone sinking, the pulse and the heart slowing to nothing.
    tr.put(synth_drone([26, 38, 45], 13.5, 1.0, 420.0, sag=5.0), 0)
    tr.wide(lambda: saw_pad([62, 65, 69, 73], 5.0, 1.0, 500.0, 400.0, attack=0.6, release=4.0), 0)
    for i, s in enumerate([0.0, 0.33, 0.70, 1.15, 1.75, 2.60, 3.90]):
        tr.put_dry(synth_bass(38, 0.26, 0.9 - 0.1 * i, 0.5 - 0.07 * i), sec(s), 0.0, 0.8)
    for s, v in [(0.0, 0.8), (1.75, 0.6), (3.9, 0.4)]:
        tr.put_dry(soft_kick(v), sec(s))
        tr.put_dry(soft_kick(v * 0.6), sec(s + 0.33 + s * 0.05))
    # The figure, coming apart: later each time, flatter, the wrong note, then the floor.
    notes = [(0.30, 74, 0.9, 0), (1.28, 77, 0.85, 0), (2.26, 76, 0.85, -4), (3.55, 69, 0.75, -10),
             (5.05, 70, 0.65, -20), (6.90, 68, 0.55, -32), (8.90, 62, 0.5, -45), (10.6, 39, 0.5, -60)]
    for s, m, v, cents in notes:
        tr.put(felt_piano(m, 5.0, v, cents), sec(s), -0.1)
    return finish_synth(tr, False, -14.5, fade=4.0)


def harbour_day():
    bpm, bars = 72, 16
    tr = SynthTrack(bars * 4 * 60 / bpm, bpm)
    tr.bed([38, 50], 0.5, 260.0)
    # The pad: thin (a narrow pulse, high up), chords with no thirds that settle nowhere.
    pads = [[62, 69, 76], [58, 65, 69, 76], [55, 62, 69, 74], [57, 62, 64, 71]]
    for p, notes in enumerate(pads):
        tr.wide(lambda: saw_pad(notes, 13 * tr.beat, 1.0, 1100.0, 700.0, attack=3.5, release=3.5, shape="pulse", pw=0.18), p * 16 + 1, 0.8)
    # A few notes of the figure, a bar of it at a time and never all of it.
    figure(tr, felt_piano, 62, 1, which=(0,), gain=1.5, hold=5.0, vel=0.75)
    figure(tr, felt_piano, 62, 5, which=(1,), gain=1.5, hold=5.0, vel=0.7)
    figure(tr, felt_piano, 62, 9, which=(2,), gain=1.5, hold=5.0, vel=0.75)
    for at, m in [(13, 69), (30, 76), (44, 76), (52, 62), (53.5, 69), (59, 69)]:
        tr.put(felt_piano(m, 6.0, 0.65), at, 0.15, 1.5)
    # Glass, high and far, from the old night; a foghorn, once.
    tr.put(glass(88, 6.0), 22, 0.6)
    tr.put(glass(83, 6.0), 54, -0.6)
    tr.put(foghorn(45, 3.0), 29, -0.4, 0.4)
    return finish_synth(tr, True, -15.0, room=5.0, wet=0.4)


def ending():
    bpm = 72
    tr = SynthTrack(66.0, bpm)
    # Bars, a bass note and a chord: D, G, B minor, G, A, D over F sharp, G, E minor, A.
    chords = [(0, 2, 38, [57, 62, 66, 69]), (2, 2, 43, [55, 59, 62, 67]), (4, 2, 47, [54, 59, 62, 66]),
              (6, 1, 43, [55, 59, 62, 67]), (7, 1, 45, [57, 61, 64, 69]), (8, 2, 42, [57, 62, 66, 69]),
              (10, 2, 43, [55, 59, 62, 67, 71]), (12, 1, 40, [55, 59, 62, 64]), (13, 1, 45, [57, 62, 64, 67]),
              (14, 2, 45, [57, 61, 64, 69])]
    for bar, n, root, notes in chords:
        d = n * 4 * tr.beat
        tr.wide(lambda: saw_pad(notes, d, 1.0, 1000.0, 700.0, attack=min(2.0, d * 0.4), release=2.5), bar * 4)
        tr.put_dry(saw_pad([root], d, 1.6, 240.0, 160.0, attack=0.3, release=1.2), bar * 4)
    # The night's pulse, still there for four bars, going.
    for e in range(32):
        tr.put_dry(synth_bass(38, 0.4 * tr.beat, 0.7 - 0.02 * e, 0.3), e * 0.5, 0.0, 1.0 - e / 32.0)
    # The figure with its thirds raised, twice; then the whistle from "Mending Nets", far
    # off, while the piano only keeps time; then the figure's end, and home.
    figure(tr, felt_piano, 62, 0, major=True, hold=4.0, vel=0.85)
    figure(tr, felt_piano, 62, 4, major=True, hold=4.0, vel=0.9)
    for at, m in [(0, 50), (8, 55), (16, 47), (24, 55), (28, 57), (32, 54), (34, 62), (36, 69), (40, 55), (42, 62), (44, 71)]:
        tr.put(felt_piano(m, 5.0, 0.65), at, -0.15)
    far = lambda m, d: whistle(m, d, 0.5)
    tr.line(far, [(74, 0.5), (76, 0.5), (78, 0.5), (81, 2.5)], 33, 0.35, 0.4)
    tr.line(far, [(74, 1), (76, 0.5), (78, 1), (76, 0.5), (74, 3)], 41, 0.35, 0.4)
    figure(tr, felt_piano, 62, 12, which=(2, 3, 1), major=True, hold=4.0, vel=0.85)
    for at, m in [(48, 52), (52, 57), (56, 57), (60, 76), (62, 73)]:
        tr.put(felt_piano(m, 5.0, 0.7), at, -0.15)
    # The last chord, held: the piano spreads it, the whistle takes the third.
    tr.wide(lambda: saw_pad([50, 57, 62, 66, 69, 74], 9.0, 1.0, 1000.0, 800.0, attack=1.5, release=5.0), 64)
    tr.put_dry(saw_pad([38], 9.0, 1.6, 240.0, 160.0, attack=0.3, release=4.0), 64)
    for k, m in enumerate([38, 50, 57, 62, 66, 74]):
        tr.put(felt_piano(m, 10.0, 0.55), 64 + k * 0.14, -0.15)
    tr.put(felt_piano(86, 8.0, 0.5), 67, 0.1)
    tr.put(whistle(78, 5 * tr.beat, 0.45), 65, 0.35, 0.4)
    return finish_synth(tr, False, -13.5, fade=6.0)


PIECES = {"title": title, "day": day, "night": night, "finale": finale, "chapter_end": chapter_end, "game_over": game_over,
          "harbour_day": harbour_day, "harbour_night": harbour_night, "ending": ending}


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
