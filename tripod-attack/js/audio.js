// All sound is synthesised with the Web Audio API: square/saw/noise voices through a cabinet
// echo and a compressor, in the manner of an early-80s arcade board. No audio files.
const Sfx = (() => {
  let ac = null, master, sfxBus, musicBus, comp, noiseBuf;
  let muted = false;

  let timeOffset = 0;
  function ensure(override) {
    if (ac) return true;
    try { ac = override || new (window.AudioContext || window.webkitAudioContext)(); } catch (e) { return false; }
    master = ac.createGain(); master.gain.value = muted ? 0 : 0.9;
    comp = ac.createDynamicsCompressor();
    comp.threshold.value = -16; comp.knee.value = 18; comp.ratio.value = 5;
    comp.attack.value = 0.003; comp.release.value = 0.18;
    sfxBus = ac.createGain(); sfxBus.gain.value = 0.85;
    musicBus = ac.createGain(); musicBus.gain.value = 0.3;
    // Cabinet echo: short feedback delay, low-passed so it sits behind the dry sound.
    const delay = ac.createDelay(1.0); delay.delayTime.value = 0.23;
    const fb = ac.createGain(); fb.gain.value = 0.25;
    const lp = ac.createBiquadFilter(); lp.type = 'lowpass'; lp.frequency.value = 2400;
    const send = ac.createGain(); send.gain.value = 0.3;
    sfxBus.connect(send); send.connect(delay); delay.connect(lp); lp.connect(fb); fb.connect(delay); lp.connect(comp);
    sfxBus.connect(comp); musicBus.connect(comp); comp.connect(master); master.connect(ac.destination);
    noiseBuf = ac.createBuffer(1, ac.sampleRate * 2, ac.sampleRate);
    const d = noiseBuf.getChannelData(0);
    for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
    return true;
  }
  function resume() {
    if (!ensure()) return;
    if (ac.state === 'suspended' && !ac.startRendering) ac.resume();
    if (music.song) { if (!music.next) music.next = ac.currentTime + 0.05; startTimer(); }
  }
  function ready() { return !!ac && ac.state === 'running'; }
  function setMuted(m) { muted = m; if (master) master.gain.setTargetAtTime(m ? 0 : 0.9, ac.currentTime, 0.02); }
  function toggleMute() { setMuted(!muted); return muted; }
  const now = () => ac.currentTime + timeOffset;

  function env(g, t0, peak, a, d, s, r, dur) {
    const p = g.gain;
    p.cancelScheduledValues(t0);
    p.setValueAtTime(0.0001, t0);
    p.linearRampToValueAtTime(peak, t0 + a);
    p.exponentialRampToValueAtTime(Math.max(0.0001, peak * s), t0 + a + d);
    p.setValueAtTime(Math.max(0.0001, peak * s), t0 + Math.max(a + d, dur));
    p.exponentialRampToValueAtTime(0.0001, t0 + Math.max(a + d, dur) + r);
  }
  function distCurve(k) {
    const n = 1024, c = new Float32Array(n);
    for (let i = 0; i < n; i++) { const x = i * 2 / n - 1; c[i] = (1 + k) * x / (1 + k * Math.abs(x)); }
    return c;
  }

  function tone(o) {
    if (!ac) return;
    const { type = 'square', f0 = 440, f1 = null, dur = 0.2, vol = 0.3, a = 0.004, d = 0.05, s = 0.6, r = 0.06,
      dest = null, t0 = null, detune = 0, filter = null, lin = false } = o;
    const st = t0 == null ? now() : t0;
    const osc = ac.createOscillator(); osc.type = type;
    osc.frequency.setValueAtTime(Math.max(1, f0), st);
    if (f1 != null) {
      if (lin) osc.frequency.linearRampToValueAtTime(Math.max(1, f1), st + dur);
      else osc.frequency.exponentialRampToValueAtTime(Math.max(1, f1), st + dur);
    }
    if (detune) osc.detune.value = detune;
    const g = ac.createGain(); env(g, st, vol, a, d, s, r, dur);
    let node = osc;
    if (filter) {
      const bq = ac.createBiquadFilter(); bq.type = filter.type || 'lowpass';
      bq.frequency.setValueAtTime(filter.f0 || 1000, st);
      if (filter.f1) bq.frequency.exponentialRampToValueAtTime(filter.f1, st + dur);
      bq.Q.value = filter.q || 1; osc.connect(bq); node = bq;
    }
    node.connect(g); g.connect(dest || sfxBus);
    osc.start(st); osc.stop(st + dur + r + 0.05);
    return osc;
  }
  function noise(o) {
    if (!ac) return;
    const { dur = 0.3, vol = 0.3, a = 0.002, d = 0.05, s = 0.5, r = 0.1, filter = 'lowpass', f0 = 1200, f1 = 200, q = 1,
      dest = null, t0 = null, rate = 1 } = o;
    const st = t0 == null ? now() : t0;
    const src = ac.createBufferSource(); src.buffer = noiseBuf; src.loop = true; src.playbackRate.value = rate;
    src.loopStart = Math.random() * 1.5;
    const bq = ac.createBiquadFilter(); bq.type = filter;
    bq.frequency.setValueAtTime(f0, st); bq.frequency.exponentialRampToValueAtTime(Math.max(20, f1), st + dur); bq.Q.value = q;
    const g = ac.createGain(); env(g, st, vol, a, d, s, r, dur);
    src.connect(bq); bq.connect(g); g.connect(dest || sfxBus);
    src.start(st, src.loopStart); src.stop(st + dur + r + 0.05);
  }

  const S = { ensure, resume, ready, toggleMute, setMuted, isMuted: () => muted };
  const guard = f => (...args) => { if (!ac) return; try { f(...args); } catch (e) { if (S.strict) throw e; /* audio is never fatal */ } };

  S.blip = guard(() => tone({ type: 'square', f0: 900, f1: 1400, dur: 0.05, vol: 0.12, s: 0.3, r: 0.03 }));
  S.select = guard(() => { tone({ type: 'square', f0: 660, dur: 0.06, vol: 0.14, s: 0.5 }); tone({ type: 'square', f0: 1320, dur: 0.12, vol: 0.14, s: 0.5, t0: now() + 0.06 }); });
  S.type = guard(() => tone({ type: 'square', f0: 1500 + Math.random() * 600, dur: 0.02, vol: 0.05, s: 0.2, r: 0.015 }));
  S.launch = guard(() => {
    noise({ dur: 0.55, vol: 0.55, f0: 3500, f1: 250, filter: 'bandpass', q: 0.6, r: 0.25 });
    tone({ type: 'sawtooth', f0: 380, f1: 70, dur: 0.5, vol: 0.28, s: 0.4, r: 0.2, filter: { type: 'lowpass', f0: 2200, f1: 250 } });
    tone({ type: 'square', f0: 120, f1: 50, dur: 0.12, vol: 0.3, s: 0.3 });
  });
  S.explosion = guard((size = 1) => {
    noise({ dur: 0.45 * size, vol: 0.75, f0: 1800, f1: 50, r: 0.35 * size, s: 0.5 });
    tone({ type: 'sine', f0: 140, f1: 28, dur: 0.4 * size, vol: 0.7, s: 0.5, r: 0.25 });
    noise({ dur: 0.12, vol: 0.4, f0: 7000, f1: 2500, filter: 'highpass', r: 0.08 });
  });
  S.legHit = guard(() => {
    const base = 600 + Math.random() * 400;
    [1, 1.47, 2.09, 3.3].forEach((m, i) => tone({ type: 'square', f0: base * m, f1: base * m * 0.96, dur: 0.1, vol: 0.14 / (i + 1), a: 0.001, d: 0.04, s: 0.35, r: 0.22 }));
    noise({ dur: 0.07, vol: 0.35, f0: 6000, f1: 1200, filter: 'bandpass', q: 1.5, r: 0.05 });
    tone({ type: 'sine', f0: 110, f1: 60, dur: 0.15, vol: 0.4, s: 0.3 });
  });
  S.ricochet = guard(() => {
    tone({ type: 'square', f0: 2200, f1: 350, dur: 0.22, vol: 0.14, s: 0.35, r: 0.12 });
    noise({ dur: 0.05, vol: 0.25, f0: 8000, f1: 3000, filter: 'highpass', r: 0.04 });
  });
  S.legBreak = guard(() => {
    noise({ dur: 0.6, vol: 0.7, f0: 2500, f1: 120, r: 0.4 });
    for (let i = 0; i < 5; i++) { const f = 300 + Math.random() * 1200; tone({ type: 'square', f0: f, f1: f * 0.7, dur: 0.12, vol: 0.14, t0: now() + i * 0.05, s: 0.4, r: 0.2 }); }
    tone({ type: 'sawtooth', f0: 900, f1: 90, dur: 0.6, vol: 0.25, s: 0.5, r: 0.3, filter: { type: 'lowpass', f0: 3000, f1: 300 } });
  });
  S.footstep = guard((scale = 1) => {
    tone({ type: 'sine', f0: 75 / scale, f1: 32, dur: 0.28, vol: 0.6, a: 0.002, d: 0.12, s: 0.35, r: 0.18 });
    noise({ dur: 0.14, vol: 0.28, f0: 500, f1: 80, r: 0.12 });
    tone({ type: 'square', f0: 260 / scale, f1: 240 / scale, dur: 0.05, vol: 0.09, s: 0.2, r: 0.1 });
  });
  // The fighting-machine's cry before it fires: "Ulla, ulla". Detuned saws through a sweeping
  // band-pass and a wave-shaper, vibrato on the pitch, a sub-tone underneath: a siren with a throat.
  S.siren = guard((dur = 1.5, pitch = 1) => {
    const st = now();
    const g = ac.createGain(); g.connect(sfxBus); env(g, st, 0.55, 0.12, 0.25, 0.85, 0.35, dur);
    const shaper = ac.createWaveShaper(); shaper.curve = distCurve(28); shaper.oversample = '2x';
    const bp = ac.createBiquadFilter(); bp.type = 'bandpass'; bp.Q.value = 2.2;
    bp.frequency.setValueAtTime(320, st);
    bp.frequency.exponentialRampToValueAtTime(1500, st + dur * 0.42);
    bp.frequency.exponentialRampToValueAtTime(450, st + dur);
    shaper.connect(bp); bp.connect(g);
    const lfo = ac.createOscillator(); lfo.frequency.value = 5.2;
    const lfoG = ac.createGain(); lfoG.gain.value = 22; lfo.connect(lfoG);
    [['sawtooth', 1, 0], ['sawtooth', 1.006, 6], ['square', 0.5, 0], ['sawtooth', 1.498, -8]].forEach(([type, mul, det]) => {
      const o = ac.createOscillator(); o.type = type;
      const f = 105 * mul * pitch;
      o.frequency.setValueAtTime(f, st);
      o.frequency.exponentialRampToValueAtTime(f * 3.1, st + dur * 0.4);
      o.frequency.exponentialRampToValueAtTime(f * 1.3, st + dur);
      o.detune.value = det; lfoG.connect(o.detune);
      o.connect(shaper); o.start(st); o.stop(st + dur + 0.45);
    });
    lfo.start(st); lfo.stop(st + dur + 0.45);
    tone({ type: 'sine', f0: 52 * pitch, f1: 38 * pitch, dur, vol: 0.35, a: 0.05, s: 0.8, r: 0.3 });
    noise({ dur, vol: 0.08, f0: 900, f1: 2500, filter: 'bandpass', q: 3, s: 0.8, r: 0.3 });
  });
  S.heatRay = guard((dur = 1.1) => {
    noise({ dur, vol: 0.4, f0: 2200, f1: 4500, filter: 'highpass', s: 0.85, r: 0.15 });
    tone({ type: 'sawtooth', f0: 1600, f1: 2900, dur, vol: 0.13, s: 0.85, r: 0.15, filter: { type: 'bandpass', f0: 2000, f1: 3200, q: 5 } });
    tone({ type: 'square', f0: 85, f1: 65, dur, vol: 0.22, s: 0.9, r: 0.2 });
    tone({ type: 'sine', f0: 3200, f1: 5200, dur, vol: 0.05, s: 0.8, r: 0.1 });
  });
  S.burn = guard(() => {
    noise({ dur: 0.35, vol: 0.5, f0: 4500, f1: 500, filter: 'bandpass', q: 0.8, r: 0.3 });
    tone({ type: 'sawtooth', f0: 1000, f1: 110, dur: 0.3, vol: 0.2, s: 0.5, r: 0.1 });
  });
  S.scream = guard(() => {
    const f = 650 + Math.random() * 450;
    tone({ type: 'sawtooth', f0: f, f1: f * 1.7, dur: 0.1, vol: 0.07, s: 0.9, r: 0.02, filter: { type: 'bandpass', f0: 1900, q: 2 } });
    tone({ type: 'sawtooth', f0: f * 1.7, f1: f * 0.6, dur: 0.28, vol: 0.07, s: 0.7, r: 0.08, t0: now() + 0.1, filter: { type: 'bandpass', f0: 1700, q: 2 } });
  });
  S.saved = guard(() => [880, 1175, 1760].forEach((f, i) => tone({ type: 'square', f0: f, dur: 0.06, vol: 0.09, t0: now() + i * 0.06, s: 0.5, r: 0.08 })));
  S.collapse = guard(() => {
    noise({ dur: 1.3, vol: 0.85, f0: 900, f1: 35, r: 0.7, s: 0.5 });
    for (let i = 0; i < 7; i++) {
      const f = 180 + Math.random() * 1000;
      tone({ type: 'square', f0: f, f1: f * 0.75, dur: 0.14, vol: 0.16, t0: now() + 0.04 + i * 0.09 + Math.random() * 0.06, s: 0.4, r: 0.25 });
    }
    tone({ type: 'sine', f0: 65, f1: 22, dur: 0.9, vol: 0.8, s: 0.6, r: 0.5 });
    noise({ dur: 0.2, vol: 0.5, f0: 8000, f1: 2000, filter: 'highpass', r: 0.3 });
  });
  S.crunch = guard(() => { noise({ dur: 0.18, vol: 0.5, f0: 1400, f1: 120, r: 0.15 }); tone({ type: 'sine', f0: 90, f1: 35, dur: 0.2, vol: 0.5, s: 0.4 }); });
  S.spark = guard(() => noise({ dur: 0.035, vol: 0.1, f0: 8000, f1: 3500, filter: 'highpass', r: 0.03 }));
  S.hurt = guard(() => {
    tone({ type: 'sawtooth', f0: 420, f1: 55, dur: 0.5, vol: 0.45, s: 0.5, r: 0.2 });
    noise({ dur: 0.45, vol: 0.55, f0: 3200, f1: 180, r: 0.3 });
    tone({ type: 'square', f0: 1200, f1: 200, dur: 0.3, vol: 0.15, s: 0.4 });
  });
  S.stomp = guard(() => {
    tone({ type: 'sine', f0: 60, f1: 25, dur: 0.5, vol: 0.9, s: 0.5, r: 0.3 });
    noise({ dur: 0.4, vol: 0.6, f0: 900, f1: 60, r: 0.3 });
  });
  S.alarm = guard(() => {
    for (let i = 0; i < 3; i++) tone({ type: 'square', f0: 660, f1: 440, dur: 0.22, vol: 0.14, t0: now() + i * 0.3, s: 0.7, r: 0.05, lin: true });
  });
  S.fanfare = guard(() => {
    [440, 554, 659, 880].forEach((f, i) => tone({ type: 'square', f0: f, dur: 0.11, vol: 0.14, t0: now() + i * 0.1, s: 0.6, r: 0.05 }));
    tone({ type: 'square', f0: 1108, dur: 0.45, vol: 0.14, t0: now() + 0.42, s: 0.6, r: 0.3 });
    tone({ type: 'sawtooth', f0: 277, dur: 0.9, vol: 0.1, t0: now() + 0.42, s: 0.6, r: 0.3, filter: { type: 'lowpass', f0: 1200 } });
  });
  S.cleared = guard(() => {
    const m = [[440, .12], [523, .12], [659, .12], [880, .25], [659, .12], [880, .5]];
    let t = now();
    for (const [f, d] of m) { tone({ type: 'square', f0: f, dur: d, vol: 0.14, t0: t, s: 0.6, r: 0.08 }); tone({ type: 'square', f0: f / 2, dur: d, vol: 0.1, t0: t, s: 0.6, r: 0.08, detune: 6 }); t += d; }
  });
  S.victory = guard(() => {
    const m = [[523, .15], [659, .15], [784, .15], [1047, .3], [784, .15], [1047, .3], [1319, .6]];
    let t = now();
    for (const [f, d] of m) { tone({ type: 'square', f0: f, dur: d, vol: 0.15, t0: t, s: 0.6, r: 0.1 }); tone({ type: 'sawtooth', f0: f / 2, dur: d, vol: 0.1, t0: t, s: 0.6, r: 0.1, filter: { type: 'lowpass', f0: 1500 } }); t += d; }
  });
  S.gameOver = guard(() => {
    [330, 311, 294, 220].forEach((f, i) => {
      tone({ type: 'sawtooth', f0: f, f1: f * 0.96, dur: 0.38, vol: 0.2, t0: now() + i * 0.38, s: 0.7, r: 0.25, filter: { type: 'lowpass', f0: 1400, q: 1 } });
      tone({ type: 'square', f0: f / 2, dur: 0.38, vol: 0.12, t0: now() + i * 0.38, s: 0.7, r: 0.25 });
    });
  });

  // ---- Music: a small 16-step sequencer with a look-ahead scheduler.
  const NOTE = (semi, base = 55) => base * Math.pow(2, semi / 12);
  const SONGS = {
    battle: {
      bpm: 132,
      roots: [0, 0, -4, -2, 0, 0, -4, 3],           // A A F G A A F C  (semitones from A)
      bass: [0, 0, 12, 0, 0, 0, 10, 0, 0, 0, 12, 0, 7, 7, 8, 10],
      lead: [12, null, 15, null, 19, null, 15, null, 12, null, 15, null, 19, null, 22, 24],
      kick: [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0],
      snare: [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0],
      hat: [0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 1],
      leadEvery: 1
    },
    menu: {
      bpm: 84,
      roots: [0, 0, -4, -2],
      bass: [0, null, null, null, null, null, null, null, 0, null, null, null, null, null, 12, null],
      lead: [null, null, 12, null, null, null, 15, null, null, null, 19, null, null, null, 15, null],
      kick: [1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0],
      snare: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      hat: [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0],
      leadEvery: 1
    },
    map: {
      bpm: 112,
      roots: [0, -4, -2, -5],
      bass: [0, null, 0, null, 12, null, 0, null, 0, null, 0, null, 12, null, 10, null],
      lead: [12, 15, 19, 24, 19, 15, 12, 15, 19, 24, 27, 24, 19, 15, 12, null],
      kick: [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0],
      snare: [0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0],
      hat: [1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0],
      leadEvery: 1
    }
  };
  const music = { song: null, step: 0, bar: 0, next: 0, timer: null, intensity: 0 };
  function startTimer() { if (!music.timer) music.timer = setInterval(tick, 40); }
  function scheduleStep(song, t) {
    const sp = 60 / song.bpm / 4;
    const root = song.roots[music.bar % song.roots.length];
    const b = song.bass[music.step];
    if (b != null) tone({ type: 'square', f0: NOTE(root + b, 55), dur: sp * 0.9, vol: 0.22, s: 0.7, r: 0.03, t0: t, dest: musicBus, filter: { type: 'lowpass', f0: 900 + music.intensity * 600, q: 2 } });
    const l = song.lead[music.step];
    if (l != null && (music.bar % song.leadEvery === 0)) {
      tone({ type: 'square', f0: NOTE(root + l, 110), dur: sp * 1.6, vol: 0.09, s: 0.5, r: 0.12, t0: t, dest: musicBus, detune: 4 });
      tone({ type: 'sawtooth', f0: NOTE(root + l, 110), dur: sp * 1.6, vol: 0.05, s: 0.5, r: 0.12, t0: t, dest: musicBus, detune: -5, filter: { type: 'lowpass', f0: 2500 } });
    }
    if (song.kick[music.step]) tone({ type: 'sine', f0: 150, f1: 40, dur: 0.12, vol: 0.5, s: 0.3, r: 0.05, t0: t, dest: musicBus });
    if (song.snare[music.step]) noise({ dur: 0.12, vol: 0.25, f0: 2500, f1: 800, filter: 'bandpass', q: 0.8, r: 0.08, t0: t, dest: musicBus });
    if (song.hat[music.step]) noise({ dur: 0.03, vol: 0.09, f0: 9000, f1: 7000, filter: 'highpass', r: 0.02, t0: t, dest: musicBus });
    music.step = (music.step + 1) % 16;
    if (music.step === 0) music.bar++;
    music.next = t + sp;
  }
  function tick() {
    if (!music.song || !ac) return;
    const song = SONGS[music.song];
    while (music.next < ac.currentTime + 0.12) scheduleStep(song, Math.max(music.next, ac.currentTime));
  }
  // Remembers the song before the first user gesture; resume() starts it once a context exists.
  S.play = function (name) {
    if (music.song === name) return;
    music.song = name; music.step = 0; music.bar = 0; music.next = 0;
    if (!ac) return;
    music.next = ac.currentTime + 0.05; startTimer();
  };
  S.stopMusic = function () { music.song = null; };
  S.setIntensity = v => { music.intensity = v; };
  S.current = () => music.song;
  // For offline rendering: shift every effect by `t` seconds, and lay down `steps` of a song from `t0`.
  S.at = t => { timeOffset = t; };
  S.renderSong = (name, t0, steps) => { const song = SONGS[name]; music.step = 0; music.bar = 0; music.intensity = 0.6; let t = t0; for (let i = 0; i < steps; i++) { scheduleStep(song, t); t = music.next; } return t; };
  return S;
})();
