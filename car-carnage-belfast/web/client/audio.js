// Car Carnage: Belfast Edition - music and sound, all synthesised with the Web Audio API.
// Nothing is loaded from disk: the soundtrack is sequenced live and changes intensity with the game.

const BPM = 142;
const STEP = 60 / BPM / 4; // a sixteenth

// E minor: scale degrees in semitones from the root
const SCALE = [0, 2, 3, 5, 7, 8, 10];
const noteHz = (semi, base = 41.2) => base * Math.pow(2, semi / 12); // E1 = 41.2 Hz

export class AudioEngine {
  constructor() {
    this.ctx = null; this.musicOn = true; this.sfxOn = true; this.mode = 'off'; this.engines = new Map();
    this.pendingMode = 'menu';
  }
  init() {
    if (this.ctx) { if (this.ctx.state === 'suspended') this.ctx.resume(); return; }
    const ctx = this.ctx = new (window.AudioContext || window.webkitAudioContext)();
    this.master = ctx.createGain(); this.master.gain.value = 0.9;
    this.comp = ctx.createDynamicsCompressor(); this.comp.threshold.value = -14; this.comp.ratio.value = 4; this.comp.attack.value = 0.004; this.comp.release.value = 0.2;
    this.master.connect(this.comp); this.comp.connect(ctx.destination);
    this.musicBus = ctx.createGain(); this.musicBus.gain.value = 0.55; this.musicBus.connect(this.master);
    this.sfxBus = ctx.createGain(); this.sfxBus.gain.value = 0.9; this.sfxBus.connect(this.master);
    this.duck = ctx.createGain(); this.duck.gain.value = 1; this.duck.connect(this.musicBus); // sidechain for bass, pad and lead
    this.delay = ctx.createDelay(1); this.delay.delayTime.value = STEP * 3; const fb = ctx.createGain(); fb.gain.value = 0.32; const dfilt = ctx.createBiquadFilter(); dfilt.type = 'highpass'; dfilt.frequency.value = 900;
    this.delay.connect(dfilt); dfilt.connect(fb); fb.connect(this.delay); const dOut = ctx.createGain(); dOut.gain.value = 0.35; dfilt.connect(dOut); dOut.connect(this.duck);
    this.noise = this.makeNoise();
    // pad voices run constantly; their gain is 0 until the pad is needed
    this.pad = this.makePad();
    this.nextStep = 0; this.step = 0; this.stepTime = ctx.currentTime + 0.1;
    this.fillStep = -1;
    this.timer = setInterval(() => this.schedule(), 30);
    this.setMode(this.pendingMode);
  }
  makeNoise() {
    const len = this.ctx.sampleRate * 2, buf = this.ctx.createBuffer(1, len, this.ctx.sampleRate), d = buf.getChannelData(0);
    for (let i = 0; i < len; i++) d[i] = Math.random() * 2 - 1;
    return buf;
  }
  makePad() {
    const ctx = this.ctx;
    const gain = ctx.createGain(); gain.gain.value = 0;
    const filt = ctx.createBiquadFilter(); filt.type = 'lowpass'; filt.frequency.value = 600; filt.Q.value = 2;
    filt.connect(gain); gain.connect(this.duck);
    const lfo = ctx.createOscillator(); lfo.frequency.value = 0.08; const lfoG = ctx.createGain(); lfoG.gain.value = 350; lfo.connect(lfoG); lfoG.connect(filt.frequency); lfo.start();
    const oscs = [];
    for (let i = 0; i < 3; i++) {
      const o1 = ctx.createOscillator(), o2 = ctx.createOscillator(); o1.type = 'sawtooth'; o2.type = 'sawtooth'; o2.detune.value = 9 + i * 3; o1.detune.value = -7;
      const g = ctx.createGain(); g.gain.value = 0.08; o1.connect(g); o2.connect(g); g.connect(filt); o1.start(); o2.start(); oscs.push([o1, o2]);
    }
    return { gain, oscs, filt, chord: null };
  }
  setPadChord(semis, t) {
    for (let i = 0; i < 3; i++) for (const o of this.pad.oscs[i]) o.frequency.setTargetAtTime(noteHz(semis[i], 82.4), t, 0.05);
  }
  setMode(mode) {
    this.pendingMode = mode;
    if (!this.ctx) return;
    this.mode = mode;
    const t = this.ctx.currentTime;
    const padLevel = mode === 'menu' || mode === 'over' ? 1 : mode === 'plan' ? 0.7 : mode === 'off' ? 0 : 0.35;
    this.pad.gain.gain.setTargetAtTime(padLevel * (this.musicOn ? 1 : 0), t, 0.6);
  }
  setMusic(on) { this.musicOn = on; if (this.ctx) { this.musicBus.gain.setTargetAtTime(on ? 0.55 : 0, this.ctx.currentTime, 0.2); } }
  setSfx(on) { this.sfxOn = on; if (this.ctx) this.sfxBus.gain.setTargetAtTime(on ? 0.9 : 0, this.ctx.currentTime, 0.05); }

  // ------------------------------------------------------------ sequencer
  schedule() {
    if (!this.ctx) return;
    const ctx = this.ctx;
    while (this.stepTime < ctx.currentTime + 0.14) {
      if (this.musicOn && this.mode !== 'off') this.playStep(this.step, this.stepTime);
      this.step++; this.stepTime += STEP;
    }
  }
  playStep(step, t) {
    const bar = Math.floor(step / 16), s = step % 16, mode = this.mode;
    const prog = (Math.floor(bar / 8) % 2 === 0) ? [0, 0, 8, 10] : [0, 3, 8, 10];
    const root = prog[Math.floor(bar / 2) % 4];
    const chordSemis = [root, root + (root === 0 ? 3 : 4), root + 7];
    if (s === 0) this.setPadChord(chordSemis.map((x) => x + 12), t);
    const full = mode === 'action' || mode === 'replay';
    const beat = mode !== 'over';
    // kick
    const kickSteps = mode === 'menu' ? [0, 8] : mode === 'over' ? [0] : [0, 4, 8, 12];
    const extraKick = full && (bar % 2 === 1) && s === 14;
    if (beat && (kickSteps.includes(s) || extraKick)) { this.kick(t, full ? 1 : 0.8); this.sidechain(t); }
    if (mode === 'over') return;
    // snare / clap
    if (mode !== 'menu' && (s === 4 || s === 12)) this.snare(t, full ? 1 : 0.7);
    if (full && bar % 4 === 3 && s >= 12 && s % 1 === 0) this.snare(t, 0.5 + (s - 12) * 0.12, true);
    // hats
    if (s % 2 === 0) this.hat(t, 0.35, false); else if (mode !== 'menu' && (full || s % 4 === 1)) this.hat(t, s % 4 === 2 ? 0.5 : 0.25, s % 4 === 2 && full);
    if (full && s % 4 === 2) this.hat(t, 0.45, true);
    if (full && s === 0 && bar % 8 === 0) this.crash(t);
    // acid bass
    const pattern = mode === 'menu' ? [1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0] : [1, 0, 1, 0, 1, 1, 0, 1, 0, 0, 1, 0, 1, 0, 1, 0];
    if (pattern[s]) {
      const acc = s === 0 || s === 10 || (full && s === 5);
      let n = root;
      if (s === 5 || s === 13) n = root + 12;
      else if (s === 7) n = root + 10;
      else if (s === 10) n = root + 7;
      else if (s === 14 && bar % 2) n = root + 3;
      this.bass(t, n, acc, full ? 1 : 0.8, mode === 'menu' ? 0.5 : 1);
    }
    // lead arps in the action
    if (full) {
      const arp = [0, 7, 12, 10, 7, 12, 15, 12, 0, 7, 12, 19, 15, 12, 10, 7];
      const fired = bar % 4 !== 3 ? (s % 2 === 0) : true;
      if (fired) this.lead(t, root + 24 + arp[s] + (bar % 2 ? 0 : 0), s % 4 === 0 ? 0.5 : 0.3);
    } else if (mode === 'plan' && bar % 2 === 1 && (s === 6 || s === 14)) this.lead(t, root + 36 + (s === 6 ? 0 : 3), 0.25, true);
  }
  sidechain(t) {
    const g = this.duck.gain; g.cancelScheduledValues(t); g.setValueAtTime(0.3, t); g.linearRampToValueAtTime(1, t + 0.22);
  }
  kick(t, vel = 1) {
    const ctx = this.ctx, o = ctx.createOscillator(), g = ctx.createGain();
    o.frequency.setValueAtTime(160, t); o.frequency.exponentialRampToValueAtTime(42, t + 0.11);
    g.gain.setValueAtTime(1.1 * vel, t); g.gain.exponentialRampToValueAtTime(0.001, t + 0.42);
    o.connect(g); g.connect(this.musicBus); o.start(t); o.stop(t + 0.45);
    const c = this.noiseBurst(t, 0.02, 0.5 * vel, 'highpass', 3000, this.musicBus);
    // a little distortion body
    const o2 = ctx.createOscillator(), g2 = ctx.createGain(); o2.type = 'square'; o2.frequency.setValueAtTime(90, t); o2.frequency.exponentialRampToValueAtTime(40, t + 0.06); g2.gain.setValueAtTime(0.25 * vel, t); g2.gain.exponentialRampToValueAtTime(0.001, t + 0.08); o2.connect(g2); g2.connect(this.musicBus); o2.start(t); o2.stop(t + 0.1);
    return c;
  }
  snare(t, vel = 1, soft = false) {
    this.noiseBurst(t, soft ? 0.08 : 0.16, 0.6 * vel, 'bandpass', 1900, this.musicBus, 1.2);
    const ctx = this.ctx, o = ctx.createOscillator(), g = ctx.createGain();
    o.frequency.setValueAtTime(230, t); o.frequency.exponentialRampToValueAtTime(140, t + 0.08);
    g.gain.setValueAtTime(0.5 * vel, t); g.gain.exponentialRampToValueAtTime(0.001, t + 0.12);
    o.connect(g); g.connect(this.musicBus); o.start(t); o.stop(t + 0.14);
  }
  hat(t, vel = 0.4, open = false) { this.noiseBurst(t, open ? 0.18 : 0.035, vel * 0.35, 'highpass', 8000, this.musicBus); }
  crash(t) { this.noiseBurst(t, 1.2, 0.35, 'highpass', 5000, this.musicBus); }
  bass(t, semi, accent, vel = 1, len = 1) {
    const ctx = this.ctx, o = ctx.createOscillator(), f = ctx.createBiquadFilter(), g = ctx.createGain();
    o.type = 'sawtooth'; o.frequency.value = noteHz(semi);
    f.type = 'lowpass'; f.Q.value = accent ? 14 : 8;
    const cut = accent ? 2400 : 900;
    f.frequency.setValueAtTime(cut, t); f.frequency.exponentialRampToValueAtTime(140, t + (accent ? 0.28 : 0.16) * len);
    g.gain.setValueAtTime(0.55 * vel * (accent ? 1.2 : 1), t); g.gain.exponentialRampToValueAtTime(0.001, t + STEP * 1.6 * len);
    o.connect(f); f.connect(g); g.connect(this.duck); o.start(t); o.stop(t + STEP * 1.8 * len);
    // sub for weight
    const s = ctx.createOscillator(), sg = ctx.createGain(); s.frequency.value = noteHz(semi) / 2; sg.gain.setValueAtTime(0.35 * vel, t); sg.gain.exponentialRampToValueAtTime(0.001, t + STEP * 1.4 * len); s.connect(sg); sg.connect(this.duck); s.start(t); s.stop(t + STEP * 1.6 * len);
  }
  lead(t, semi, vel = 0.4, soft = false) {
    const ctx = this.ctx, o = ctx.createOscillator(), o2 = ctx.createOscillator(), f = ctx.createBiquadFilter(), g = ctx.createGain();
    o.type = soft ? 'triangle' : 'square'; o2.type = 'sawtooth'; o.frequency.value = noteHz(semi); o2.frequency.value = noteHz(semi); o2.detune.value = 8;
    f.type = 'lowpass'; f.frequency.setValueAtTime(soft ? 1800 : 4200, t); f.frequency.exponentialRampToValueAtTime(700, t + 0.2); f.Q.value = 3;
    g.gain.setValueAtTime(0.16 * vel, t); g.gain.exponentialRampToValueAtTime(0.001, t + (soft ? 0.5 : 0.18));
    o.connect(f); o2.connect(f); f.connect(g); g.connect(this.duck); g.connect(this.delay); o.start(t); o2.start(t); o.stop(t + 0.55); o2.stop(t + 0.55);
  }
  noiseBurst(t, dur, vel, type, freq, dest, q = 1) {
    const ctx = this.ctx, src = ctx.createBufferSource(), f = ctx.createBiquadFilter(), g = ctx.createGain();
    src.buffer = this.noise; src.loop = true; src.playbackRate.value = 1;
    f.type = type; f.frequency.value = freq; f.Q.value = q;
    g.gain.setValueAtTime(vel, t); g.gain.exponentialRampToValueAtTime(0.001, t + dur);
    src.connect(f); f.connect(g); g.connect(dest || this.sfxBus); src.start(t); src.stop(t + dur + 0.05);
    return { src, f, g };
  }

  // ------------------------------------------------------------ sound effects
  now() { return this.ctx ? this.ctx.currentTime : 0; }
  ok() { return this.ctx && this.sfxOn; }
  pan(x) { const p = this.ctx.createStereoPanner(); p.pan.value = Math.max(-1, Math.min(1, x)); p.connect(this.sfxBus); return p; }
  ui() { if (!this.ok()) return; const t = this.now(), o = this.ctx.createOscillator(), g = this.ctx.createGain(); o.frequency.value = 900; g.gain.setValueAtTime(0.12, t); g.gain.exponentialRampToValueAtTime(0.001, t + 0.05); o.connect(g); g.connect(this.sfxBus); o.start(t); o.stop(t + 0.06); }
  lockIn() { if (!this.ok()) return; const t = this.now(); for (const [i, f] of [660, 990].entries()) { const o = this.ctx.createOscillator(), g = this.ctx.createGain(); o.type = 'square'; o.frequency.value = f; g.gain.setValueAtTime(0.08, t + i * 0.08); g.gain.exponentialRampToValueAtTime(0.001, t + i * 0.08 + 0.12); o.connect(g); g.connect(this.sfxBus); o.start(t + i * 0.08); o.stop(t + i * 0.08 + 0.14); } }
  actionStart() {
    if (!this.ok()) return; const t = this.now(), ctx = this.ctx;
    // air-raid style riser then a hit
    const o = ctx.createOscillator(), g = ctx.createGain(); o.type = 'sawtooth'; o.frequency.setValueAtTime(220, t); o.frequency.exponentialRampToValueAtTime(880, t + 0.7); g.gain.setValueAtTime(0.001, t); g.gain.exponentialRampToValueAtTime(0.25, t + 0.65); g.gain.exponentialRampToValueAtTime(0.001, t + 0.8);
    const f = ctx.createBiquadFilter(); f.type = 'lowpass'; f.frequency.setValueAtTime(400, t); f.frequency.exponentialRampToValueAtTime(5000, t + 0.7); o.connect(f); f.connect(g); g.connect(this.sfxBus); o.start(t); o.stop(t + 0.85);
    const n = this.noiseBurst(t, 0.75, 0.001, 'bandpass', 800, this.sfxBus, 2); n.g.gain.exponentialRampToValueAtTime(0.5, t + 0.7); n.f.frequency.exponentialRampToValueAtTime(6000, t + 0.7);
    this.explosion(t + 0.72, 0.6, 0);
  }
  gun(type, x = 0) {
    if (!this.ok()) return; const t = this.now(), p = this.pan(x);
    const shots = type === 'VMG' ? 9 : type === 'MG' ? 5 : 1;
    const gap = type === 'VMG' ? 0.035 : 0.055;
    for (let i = 0; i < shots; i++) {
      const tt = t + i * gap;
      if (shots > 1) { this.noiseBurst(tt, 0.045, 0.5, 'bandpass', 2200 + Math.random() * 600, p, 0.8); const o = this.ctx.createOscillator(), g = this.ctx.createGain(); o.frequency.setValueAtTime(300, tt); o.frequency.exponentialRampToValueAtTime(80, tt + 0.04); g.gain.setValueAtTime(0.3, tt); g.gain.exponentialRampToValueAtTime(0.001, tt + 0.05); o.connect(g); g.connect(p); o.start(tt); o.stop(tt + 0.06); }
      else { this.noiseBurst(tt, 0.25, 0.9, 'lowpass', 1200, p); const o = this.ctx.createOscillator(), g = this.ctx.createGain(); o.frequency.setValueAtTime(140, tt); o.frequency.exponentialRampToValueAtTime(35, tt + 0.2); g.gain.setValueAtTime(0.9, tt); g.gain.exponentialRampToValueAtTime(0.001, tt + 0.3); o.connect(g); g.connect(p); o.start(tt); o.stop(tt + 0.32); }
    }
  }
  laser(x = 0) {
    if (!this.ok()) return; const t = this.now(), p = this.pan(x), o = this.ctx.createOscillator(), g = this.ctx.createGain();
    o.type = 'sawtooth'; o.frequency.setValueAtTime(1800, t); o.frequency.exponentialRampToValueAtTime(220, t + 0.28);
    g.gain.setValueAtTime(0.35, t); g.gain.exponentialRampToValueAtTime(0.001, t + 0.3); o.connect(g); g.connect(p); o.start(t); o.stop(t + 0.32);
    this.noiseBurst(t, 0.2, 0.15, 'highpass', 6000, p);
  }
  rocket(x = 0) {
    if (!this.ok()) return; const t = this.now(), p = this.pan(x);
    const n = this.noiseBurst(t, 0.45, 0.6, 'bandpass', 500, p, 1.5); n.f.frequency.exponentialRampToValueAtTime(2500, t + 0.4);
  }
  flame(x = 0) {
    if (!this.ok()) return; const t = this.now(), p = this.pan(x);
    const n = this.noiseBurst(t, 0.7, 0.55, 'lowpass', 600, p); const lfo = this.ctx.createOscillator(); lfo.frequency.value = 23; const lg = this.ctx.createGain(); lg.gain.value = 300; lfo.connect(lg); lg.connect(n.f.frequency); lfo.start(t); lfo.stop(t + 0.75);
  }
  explosion(at, size = 1, x = 0) {
    if (!this.ok()) return; const t = at || this.now(), p = this.pan(x), ctx = this.ctx;
    const n = this.noiseBurst(t, 0.9 * size + 0.3, 1.0, 'lowpass', 3000, p); n.f.frequency.exponentialRampToValueAtTime(120, t + 0.8 * size + 0.2);
    const o = ctx.createOscillator(), g = ctx.createGain(); o.frequency.setValueAtTime(70, t); o.frequency.exponentialRampToValueAtTime(22, t + 0.9); g.gain.setValueAtTime(1.0, t); g.gain.exponentialRampToValueAtTime(0.001, t + 1.1 * size); o.connect(g); g.connect(p); o.start(t); o.stop(t + 1.2 * size);
    for (let i = 0; i < 6 * size; i++) this.noiseBurst(t + 0.1 + Math.random() * 0.6 * size, 0.03, 0.2, 'bandpass', 1500 + Math.random() * 3000, p, 3);
  }
  crashHit(speed = 30, x = 0) {
    if (!this.ok()) return; const t = this.now(), p = this.pan(x), ctx = this.ctx, v = Math.min(1, 0.3 + speed / 80);
    this.noiseBurst(t, 0.12, 0.8 * v, 'bandpass', 3200, p, 0.7);
    this.noiseBurst(t, 0.35, 0.7 * v, 'lowpass', 500, p);
    for (const f of [311, 418, 672, 1130]) { const o = ctx.createOscillator(), g = ctx.createGain(); o.type = 'square'; o.frequency.value = f * (0.9 + Math.random() * 0.2); g.gain.setValueAtTime(0.08 * v, t); g.gain.exponentialRampToValueAtTime(0.001, t + 0.35 + Math.random() * 0.3); o.connect(g); g.connect(p); o.start(t); o.stop(t + 0.7); }
    const o = ctx.createOscillator(), g = ctx.createGain(); o.frequency.setValueAtTime(90, t); o.frequency.exponentialRampToValueAtTime(30, t + 0.25); g.gain.setValueAtTime(0.8 * v, t); g.gain.exponentialRampToValueAtTime(0.001, t + 0.3); o.connect(g); g.connect(p); o.start(t); o.stop(t + 0.32);
  }
  skid(x = 0, len = 0.5) {
    if (!this.ok()) return; const t = this.now(), p = this.pan(x);
    const n = this.noiseBurst(t, len, 0.35, 'bandpass', 1100, p, 4); n.f.frequency.setValueAtTime(900, t); n.f.frequency.linearRampToValueAtTime(1400, t + len);
  }
  whoosh(x = 0) { if (!this.ok()) return; const t = this.now(), p = this.pan(x); const n = this.noiseBurst(t, 0.5, 0.4, 'bandpass', 300, p, 2); n.f.frequency.exponentialRampToValueAtTime(3000, t + 0.45); }
  thud(x = 0) { if (!this.ok()) return; const t = this.now(), p = this.pan(x); this.noiseBurst(t, 0.2, 0.6, 'lowpass', 400, p); const o = this.ctx.createOscillator(), g = this.ctx.createGain(); o.frequency.setValueAtTime(100, t); o.frequency.exponentialRampToValueAtTime(30, t + 0.2); g.gain.setValueAtTime(0.7, t); g.gain.exponentialRampToValueAtTime(0.001, t + 0.25); o.connect(g); g.connect(p); o.start(t); o.stop(t + 0.3); }
  drop(x = 0) { if (!this.ok()) return; const t = this.now(), p = this.pan(x); const o = this.ctx.createOscillator(), g = this.ctx.createGain(); o.frequency.setValueAtTime(320, t); o.frequency.exponentialRampToValueAtTime(70, t + 0.12); g.gain.setValueAtTime(0.3, t); g.gain.exponentialRampToValueAtTime(0.001, t + 0.15); o.connect(g); g.connect(p); o.start(t); o.stop(t + 0.16); this.noiseBurst(t, 0.3, 0.15, 'highpass', 4000, p); }
  geiger(x = 0) { if (!this.ok()) return; const t = this.now(), p = this.pan(x); for (let i = 0; i < 12; i++) this.noiseBurst(t + Math.random() * 0.8, 0.006, 0.4, 'highpass', 5000, p); }
  fireCrackle(x = 0) { if (!this.ok()) return; const t = this.now(), p = this.pan(x); for (let i = 0; i < 5; i++) this.noiseBurst(t + Math.random() * 0.4, 0.02, 0.18, 'bandpass', 2500 + Math.random() * 3000, p, 2); }
  mine(x = 0) { this.explosion(this.now(), 0.7, x); }
  sting(kind) {
    if (!this.ok()) return; const t = this.now(), ctx = this.ctx;
    const notes = kind === 'win' ? [0, 7, 12, 19, 24] : kind === 'death' ? [12, 8, 3, 0] : [0, 3, 7];
    notes.forEach((n, i) => { const o = ctx.createOscillator(), g = ctx.createGain(); o.type = 'square'; o.frequency.value = noteHz(n + 24); g.gain.setValueAtTime(0.0001, t + i * 0.12); g.gain.exponentialRampToValueAtTime(0.18, t + i * 0.12 + 0.02); g.gain.exponentialRampToValueAtTime(0.001, t + i * 0.12 + 0.5); o.connect(g); g.connect(this.sfxBus); o.start(t + i * 0.12); o.stop(t + i * 0.12 + 0.55); });
  }
  // engines: one voice per car while the action plays
  engine(id, speed, x, alive) {
    if (!this.ctx) return;
    let e = this.engines.get(id);
    if (!e) {
      const ctx = this.ctx, o = ctx.createOscillator(), o2 = ctx.createOscillator(), f = ctx.createBiquadFilter(), g = ctx.createGain(), p = ctx.createStereoPanner();
      o.type = 'sawtooth'; o2.type = 'square'; o2.detune.value = -1200; f.type = 'lowpass'; f.frequency.value = 400; f.Q.value = 2; g.gain.value = 0;
      o.connect(f); o2.connect(f); f.connect(g); g.connect(p); p.connect(this.sfxBus); o.start(); o2.start();
      e = { o, o2, f, g, p }; this.engines.set(id, e);
    }
    const t = this.ctx.currentTime;
    const sp = Math.abs(speed);
    const target = alive && this.sfxOn ? Math.min(0.09, 0.015 + sp / 900) : 0;
    e.g.gain.setTargetAtTime(target, t, 0.08);
    e.o.frequency.setTargetAtTime(38 + sp * 1.1, t, 0.1); e.o2.frequency.setTargetAtTime(38 + sp * 1.1, t, 0.1);
    e.f.frequency.setTargetAtTime(250 + sp * 9, t, 0.1);
    e.p.pan.setTargetAtTime(Math.max(-1, Math.min(1, x)), t, 0.1);
  }
  enginesOff() { if (!this.ctx) return; const t = this.ctx.currentTime; for (const e of this.engines.values()) e.g.gain.setTargetAtTime(0, t, 0.15); }
}

export const audio = new AudioEngine();
