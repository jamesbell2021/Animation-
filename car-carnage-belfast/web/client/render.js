// Car Carnage: Belfast Edition - the renderer. Plays timelines back in real time, fires effects and
// sounds off the events, and draws the planning overlays.

import { drawCar, renderGround, drawTerrainLive, drawWalls, drawOverhead, drawCounter, OUTLINE } from './art.js';
import { WEAPONS } from '../shared/data.js';
import { TICKS_PER_PHASE, PHASES, normAngle, obbCorners, arcOf } from '../shared/engine.js';

const TAU = Math.PI * 2;
const GROUND_PX = 40;
const lerp = (a, b, t) => a + (b - a) * t;
const lerpAngle = (a, b, t) => a + normAngle(b - a) * t;

export class Renderer {
  constructor(canvas, fx, audio) {
    this.canvas = canvas; this.ctx = canvas.getContext('2d'); this.fx = fx; this.audio = audio;
    this.scene = document.createElement('canvas'); this.sctx = this.scene.getContext('2d');
    this.map = null; this.ground = null; this.marks = null; this.mctx = null;
    this.vehicles = []; this.counters = []; this.breached = new Set(); this.wallDp = {};
    this.cam = { x: 20, y: 15, zoom: 1 }; this.camTarget = { x: 20, y: 15, zoom: 1 }; this.camMode = 'overview'; this.followId = null; this.focus = null; this.userMoved = 0;
    this.playback = null; this.ghost = null; this.ghostOwner = null; this.targetId = null; this.myId = null; this.myVehicleId = null;
    this.time = 0; this.dpr = Math.min(2, window.devicePixelRatio || 1); this.heavy = true;
    this.ash = []; this.onClick = null; this.onCar = null; this.hover = null; this.rangeRing = 0; this.showLabels = true;
    this.lastEngineUpdate = 0; this.cinematic = false; this.tint = true;
    this.resize(); window.addEventListener('resize', () => this.resize());
    this.bindInput();
  }
  resize() {
    const w = this.canvas.clientWidth || window.innerWidth, h = this.canvas.clientHeight || window.innerHeight;
    this.canvas.width = Math.round(w * this.dpr); this.canvas.height = Math.round(h * this.dpr);
    this.scene.width = this.canvas.width; this.scene.height = this.canvas.height;
    this.W = w; this.H = h;
    if (this.map && this.camMode === 'overview') this.fitMap(true);
  }
  setMap(map) {
    this.map = map; this.ground = renderGround(map, GROUND_PX);
    this.marks = document.createElement('canvas'); this.marks.width = this.ground.width; this.marks.height = this.ground.height; this.mctx = this.marks.getContext('2d'); this.mctx.scale(GROUND_PX, GROUND_PX);
    this.breached = new Set(); this.wallDp = {}; this.walls = map.walls.map((w, i) => ({ ...w, id: i, dp: w.dp ?? 9999, maxDp: w.dp ?? 9999 }));
    this.fx.clear(); this.counters = []; this.playback = null; this.camMode = 'overview'; this.fitMap(true);
  }
  setWalls(list) { for (const w of list || []) { if (w.breached) this.breached.add(w.id); const ww = this.walls[w.id]; if (ww) ww.dp = w.dp; } }
  setState(vehicles, counters, walls) {
    this.vehicles = vehicles.map((v) => ({ ...v })); this.counters = (counters || []).slice();
    if (walls) this.setWalls(walls);
    if (this.myId != null) { const mine = this.vehicles.find((v) => v.owner.id === this.myId); this.myVehicleId = mine ? mine.id : null; }
  }
  fitMap(instant) {
    if (!this.map) return;
    const z = Math.min(this.W / (this.map.width + 1), this.H / (this.map.height + 1)) / GROUND_PX * GROUND_PX;
    this.camTarget = { x: this.map.width / 2, y: this.map.height / 2, zoom: z };
    if (instant) this.cam = { ...this.camTarget };
  }
  // pixels per inch at the current zoom
  get px() { return this.cam.zoom; }
  worldToScreen(x, y) { return [(x - this.cam.x) * this.cam.zoom + this.W / 2, (y - this.cam.y) * this.cam.zoom + this.H / 2]; }
  screenToWorld(sx, sy) { return [(sx - this.W / 2) / this.cam.zoom + this.cam.x, (sy - this.H / 2) / this.cam.zoom + this.cam.y]; }
  setCamMode(mode) { this.camMode = mode; this.userMoved = 0; if (mode === 'overview') this.fitMap(false); }
  bindInput() {
    const c = this.canvas; let drag = null, pinch = null;
    const down = (x, y, id) => { drag = { x, y, sx: x, sy: y, moved: false, id }; };
    const move = (x, y) => { if (!drag) return; const dx = x - drag.x, dy = y - drag.y; if (Math.hypot(x - drag.sx, y - drag.sy) > 6) drag.moved = true; if (drag.moved) { this.camMode = 'free'; this.camTarget.x -= dx / this.cam.zoom; this.camTarget.y -= dy / this.cam.zoom; this.cam.x = this.camTarget.x; this.cam.y = this.camTarget.y; this.userMoved = this.time; } drag.x = x; drag.y = y; };
    const up = (x, y) => { if (!drag) return; if (!drag.moved) this.click(x, y); drag = null; };
    c.addEventListener('mousedown', (e) => down(e.clientX, e.clientY));
    window.addEventListener('mousemove', (e) => { move(e.clientX, e.clientY); this.hover = this.screenToWorld(e.clientX, e.clientY); });
    window.addEventListener('mouseup', (e) => up(e.clientX, e.clientY));
    c.addEventListener('wheel', (e) => { e.preventDefault(); this.zoomAt(e.clientX, e.clientY, Math.exp(-e.deltaY * 0.0012)); }, { passive: false });
    c.addEventListener('touchstart', (e) => { if (e.touches.length === 1) down(e.touches[0].clientX, e.touches[0].clientY); else if (e.touches.length === 2) { drag = null; pinch = { d: dist2(e.touches), cx: (e.touches[0].clientX + e.touches[1].clientX) / 2, cy: (e.touches[0].clientY + e.touches[1].clientY) / 2 }; } }, { passive: true });
    c.addEventListener('touchmove', (e) => { e.preventDefault(); if (e.touches.length === 1 && drag) move(e.touches[0].clientX, e.touches[0].clientY); else if (e.touches.length === 2 && pinch) { const d = dist2(e.touches); this.zoomAt(pinch.cx, pinch.cy, d / pinch.d); pinch.d = d; } }, { passive: false });
    c.addEventListener('touchend', (e) => { if (e.touches.length === 0) { if (drag) up(drag.x, drag.y); pinch = null; } }, { passive: true });
    function dist2(t) { return Math.hypot(t[0].clientX - t[1].clientX, t[0].clientY - t[1].clientY); }
  }
  zoomAt(sx, sy, f) {
    const [wx, wy] = this.screenToWorld(sx, sy);
    const z = Math.max(this.minZoom(), Math.min(140, this.cam.zoom * f));
    this.cam.zoom = z; this.camTarget.zoom = z; this.camMode = 'free'; this.userMoved = this.time;
    const [nx, ny] = this.screenToWorld(sx, sy);
    this.cam.x += wx - nx; this.cam.y += wy - ny; this.camTarget.x = this.cam.x; this.camTarget.y = this.cam.y;
  }
  minZoom() { return this.map ? Math.min(this.W / (this.map.width + 2), this.H / (this.map.height + 2)) * 0.8 : 5; }
  click(sx, sy) {
    const [wx, wy] = this.screenToWorld(sx, sy);
    let best = null, bd = 0.9;
    for (const v of this.currentVehicles()) { const d = Math.hypot(v.x - wx, v.y - wy); if (d < bd) { bd = d; best = v; } }
    if (best && this.onCar) this.onCar(best); else if (this.onClick) this.onClick(wx, wy);
  }

  // ------------------------------------------------------------ playback
  // tl: {frames, events, ticks}; opts: {duration, onDone, onPhase, director, cinematic}
  play(tl, baseVehicles, opts = {}) {
    const events = tl.events.slice().sort((a, b) => a.t - b.t);
    this.playback = { tl, events, ei: 0, pos: 0, speed: (tl.ticks || tl.frames.length - 1) / (opts.duration || 4), base: baseVehicles.map((v) => ({ ...v })), opts, phase: 0, done: false, fast: 1 };
    this.liveCounters = this.counters.slice();
    this.fx.slow = 0;
    this.audio.setMode(opts.cinematic ? 'replay' : 'action');
  }
  stopPlayback() { this.playback = null; this.audio.enginesOff(); }
  fastForward() { if (this.playback) this.playback.fast = 4; }
  currentVehicles() {
    const p = this.playback;
    if (!p) return this.vehicles;
    const frames = p.tl.frames, i = Math.min(frames.length - 1, Math.floor(p.pos)), j = Math.min(frames.length - 1, i + 1), t = p.pos - i;
    return p.base.map((v, k) => {
      const a = frames[i][k], b = frames[j][k];
      if (!a) return v;
      const flags = (t < 0.5 ? a : b)[6];
      return { ...v, x: lerp(a[0], b[0], t), y: lerp(a[1], b[1], t), heading: lerpAngle(a[2], b[2], t), speed: a[3], z: lerp(a[4], b[4], t), rollAngle: lerp(a[5], b[5], t), turretAngle: lerpAngle(a[7] || 0, b[7] || 0, t), flags, status: (flags & 64) ? 'gone' : (flags & 2) ? 'wreck' : 'alive', fire: { burning: !!(flags & 1) }, air: (flags & 8) ? {} : null };
    });
  }
  update(dt) {
    this.time += dt;
    const p = this.playback;
    if (p && !p.done) {
      const factor = (this.fx.slow || 1) * p.fast;
      const prev = p.pos;
      p.pos = Math.min(p.tl.frames.length - 1, p.pos + p.speed * dt * factor);
      while (p.ei < p.events.length && p.events[p.ei].t <= p.pos) { this.handleEvent(p.events[p.ei], p); p.ei++; }
      const phase = Math.min(PHASES, Math.floor((p.pos - 0.001) / TICKS_PER_PHASE) + 1);
      if (phase !== p.phase && p.pos > 0) { p.phase = phase; if (p.opts.onPhase) p.opts.onPhase(phase); }
      this.layMarks(prev, p.pos);
      if (this.time - this.lastEngineUpdate > 0.1) { this.lastEngineUpdate = this.time; for (const v of this.currentVehicles()) this.audio.engine(v.id, v.speed, (v.x - this.cam.x) / 20, v.status === 'alive'); }
      if (p.pos >= p.tl.frames.length - 1) { p.done = true; this.audio.enginesOff(); if (p.opts.onDone) p.opts.onDone(); }
    }
    this.fx.update(dt);
    // the camera
    const z = this.cam.zoom;
    if (this.camMode !== 'free' || (this.time - this.userMoved > 6 && !this.cinematic)) {
      if (this.focus && this.time < this.focus.until) { this.camTarget.x = this.focus.x; this.camTarget.y = this.focus.y; this.camTarget.zoom = this.focus.zoom; }
      else if (this.camMode === 'follow' && this.followId != null) { const v = this.currentVehicles().find((x) => x.id === this.followId); if (v) { this.camTarget.x = v.x + Math.cos(v.heading) * 1.5; this.camTarget.y = v.y + Math.sin(v.heading) * 1.5; this.camTarget.zoom = Math.max(this.minZoom(), Math.min(this.W, this.H) / 14); } }
      else if (this.camMode === 'overview' || (this.camMode === 'free' && !this.cinematic)) { this.fitMap(false); if (this.camMode === 'free') this.camMode = 'overview'; }
    }
    const k = 1 - Math.exp(-dt * (this.focus && this.time < this.focus.until ? 5 : 2.5));
    this.cam.x = lerp(this.cam.x, this.camTarget.x, k); this.cam.y = lerp(this.cam.y, this.camTarget.y, k); this.cam.zoom = lerp(this.cam.zoom, this.camTarget.zoom * (1 + this.fx.zoomPunch * 0.12), k);
    // ash falling over the city
    if (this.heavy && this.ash.length < 90) this.ash.push({ x: Math.random() * this.W, y: -10, vy: 12 + Math.random() * 20, vx: 5 + Math.random() * 8, s: 1 + Math.random() * 2, a: 0.2 + Math.random() * 0.3 });
    for (let i = this.ash.length - 1; i >= 0; i--) { const a = this.ash[i]; a.y += a.vy * dt; a.x += (a.vx + Math.sin(this.time + a.y * 0.02) * 10) * dt; if (a.y > this.H + 10) this.ash.splice(i, 1); }
  }
  focusOn(x, y, zoom, seconds) { if (this.cinematic) return; this.focus = { x, y, zoom: Math.max(this.minZoom(), zoom), until: this.time + seconds }; }
  layMarks(from, to) {
    const p = this.playback; if (!p || !this.mctx) return;
    const i = Math.floor(from), j = Math.min(p.tl.frames.length - 1, Math.floor(to));
    if (j <= i) return;
    for (let k = i; k < j; k++) {
      const fa = p.tl.frames[k], fb = p.tl.frames[k + 1];
      for (let n = 0; n < fa.length; n++) {
        const a = fa[n], b = fb[n], v = p.base[n];
        if (!a || !b || (b[6] & 64)) continue;
        const skidding = (b[6] & (4 | 16 | 32)) !== 0;
        const braking = Math.abs(a[3] - b[3]) >= 15;
        const turning = Math.abs(normAngle(b[2] - a[2])) > 0.05 && Math.abs(b[3]) >= 40;
        if (!skidding && !braking && !turning) continue;
        const ctx = this.mctx; ctx.strokeStyle = 'rgba(15,12,10,0.55)'; ctx.lineWidth = v.wid * 0.14; ctx.lineCap = 'round';
        for (const s of [-1, 1]) {
          const ax = a[0] - Math.cos(a[2]) * v.len * 0.3 + Math.cos(a[2] + Math.PI / 2) * s * v.wid * 0.42, ay = a[1] - Math.sin(a[2]) * v.len * 0.3 + Math.sin(a[2] + Math.PI / 2) * s * v.wid * 0.42;
          const bx = b[0] - Math.cos(b[2]) * v.len * 0.3 + Math.cos(b[2] + Math.PI / 2) * s * v.wid * 0.42, by = b[1] - Math.sin(b[2]) * v.len * 0.3 + Math.sin(b[2] + Math.PI / 2) * s * v.wid * 0.42;
          ctx.beginPath(); ctx.moveTo(ax, ay); ctx.lineTo(bx, by); ctx.stroke();
        }
      }
    }
  }
  scorch(x, y, r) { if (!this.mctx) return; const g = this.mctx.createRadialGradient(x, y, 0, x, y, r); g.addColorStop(0, 'rgba(10,8,6,0.85)'); g.addColorStop(1, 'rgba(10,8,6,0)'); this.mctx.fillStyle = g; this.mctx.beginPath(); this.mctx.arc(x, y, r, 0, TAU); this.mctx.fill(); }

  vehicleAt(id) { return this.currentVehicles().find((v) => v.id === id); }
  nameOf(id) { const v = this.playback ? this.playback.base.find((x) => x.id === id) : this.vehicles.find((x) => x.id === id); return v ? v.owner.name : '?'; }
  colorOf(id) { const v = this.playback ? this.playback.base.find((x) => x.id === id) : this.vehicles.find((x) => x.id === id); return v ? v.color : '#fff'; }
  handleEvent(e, p) {
    const fx = this.fx, au = this.audio, heavy = this.heavy;
    const log = (text, cls) => { if (p.opts.onLog) p.opts.onLog(text, cls, e); };
    const panOf = (x) => (x - this.cam.x) / 20;
    const big = (x, y, zoom = 2.2, secs = 1.3) => { if (this.camMode !== 'free' && p.opts.director !== false) this.focusOn(x, y, Math.min(this.W, this.H) / zoom / 6, secs); };
    switch (e.type) {
      case 'shot': {
        const w = WEAPONS[e.w]; const from = this.vehicleAt(e.from), to = this.vehicleAt(e.to);
        const x1 = e.x1, y1 = e.y1, x2 = to && e.hit ? to.x : e.x2, y2 = to && e.hit ? to.y : e.y2;
        const ang = Math.atan2(y2 - y1, x2 - x1);
        const onHit = () => {
          if (!e.hit) { if (e.salvo === 0) fx.text(x2, y2, 'MISS', '#aaa', 0.35, 0.7); return; }
          const t = this.vehicleAt(e.to) || { x: x2, y: y2 };
          fx.impact(t.x, t.y, e.dmg || 1, w.type === 'laser' ? '#9ff' : '#ffd27a');
          if (w.type === 'rocket' || w.w === 'AC' || w.w === 'ATG') { fx.explosion(t.x, t.y, 0.45, false); au.explosion(au.now(), 0.4, panOf(t.x)); }
          fx.text(t.x, t.y - 0.4, '-' + e.dmg, e.penetrated ? '#ff5c5c' : '#ffe08a', e.penetrated ? 0.6 : 0.45, 1.1);
          if (e.tire) fx.text(t.x, t.y + 0.3, 'TYRE', '#ffb347', 0.35, 0.9);
          for (const d of e.destroyed || []) { fx.text(t.x, t.y + 0.5, d.toUpperCase() + ' GONE', '#ff7a1f', 0.4, 1.4); log(`${this.nameOf(e.to)}'s ${d} destroyed`, 'bad'); }
          if (e.dmg >= 6) fx.shakeBy(0.25);
        };
        if (w.type === 'laser') { fx.beam(x1, y1, x2, y2, w.w === 'HL' ? '#ff4d4d' : '#2fe6e6', 0.07, 0.3); au.laser(panOf(x1)); onHit(); }
        else if (w.type === 'rocket') { fx.muzzle(x1, y1, ang, true); au.rocket(panOf(x1)); fx.rocket(x1, y1, x2, y2, 30, onHit); }
        else if (w.type === 'flame') { au.flame(panOf(x1)); const d = Math.hypot(x2 - x1, y2 - y1); for (let i = 0; i < 26; i++) { const f = Math.random(); fx.add({ t: 'fire', x: x1 + Math.cos(ang) * d * f + (Math.random() - 0.5) * 0.3 * f, y: y1 + Math.sin(ang) * d * f + (Math.random() - 0.5) * 0.3 * f, vx: Math.cos(ang) * 2, vy: Math.sin(ang) * 2, life: 0.3 + Math.random() * 0.5, max: 0.8, size: 0.2 + f * 0.35, drag: 1.5, shrink: true }); } fx.smoke(x2, y2, 8, 'rgba(60,60,60,0.5)', 0.4); onHit(); }
        else { fx.muzzle(x1, y1, ang, ['AC', 'ATG', 'RR'].includes(e.w)); au.gun(e.w, panOf(x1)); fx.tracer(x1, y1, x2, y2, '#ffe08a', 0.13); if (['AC', 'ATG', 'RR'].includes(e.w)) fx.shakeBy(0.12); setTimeout(() => onHit(), 60); }
        if (e.hit && e.salvo === 0) log(`${this.nameOf(e.from)} hits ${this.nameOf(e.to)} with ${w.name} for ${e.dmg}` + (e.tire ? ' (tyre)' : ''), e.to === this.myVehicleId ? 'bad' : e.from === this.myVehicleId ? 'good' : '');
        break;
      }
      case 'collision': {
        fx.sparks(e.x, e.y, 20 + e.speed, '#ffd27a', 5); fx.debris(e.x, e.y, 10 + e.speed / 4, '#333', 4); fx.glow(e.x, e.y, 0.6, 'rgba(255,220,150,0.8)', 0.15);
        au.crashHit(e.speed, panOf(e.x)); fx.shakeBy(0.2 + e.speed / 60);
        if (e.speed >= 40) { fx.ring(e.x, e.y, 2, 'rgba(255,255,255,0.7)', 0.1, 0.4); if (heavy) fx.slowmo(0.35, 0.7); fx.chroma = Math.max(fx.chroma, 0.6); big(e.x, e.y, 2.4, 1.2); }
        fx.text(e.x, e.y - 0.6, e.kind.toUpperCase().replace('-OPPOSITE', ''), '#fff', 0.45, 1);
        log(`${this.nameOf(e.a)} and ${this.nameOf(e.b)}: ${e.kind} at ${e.speed} mph (${e.dmgA}/${e.dmgB})`, e.a === this.myVehicleId || e.b === this.myVehicleId ? 'bad' : '');
        break;
      }
      case 'wall': {
        fx.sparks(e.x, e.y, 8 + e.dmg * 2, '#ffd27a', 3.5); fx.debris(e.x, e.y, 4 + e.dmg, '#5a5a5a', 3);
        if (e.kind !== 'scrape') { au.crashHit(e.speed || 20, panOf(e.x)); fx.shakeBy(0.15 + (e.dmg || 0) * 0.02); }
        else au.skid(panOf(e.x), 0.3);
        if (e.kind === 'breach') { fx.explosion(e.x, e.y, 0.8, false); fx.text(e.x, e.y - 0.5, 'BREACH!', '#ffd02f', 0.6, 1.2); big(e.x, e.y, 2.2, 1.2); }
        if (e.dmg > 0) fx.text(e.x, e.y - 0.3, '-' + e.dmg, '#ffe08a', 0.4, 0.9);
        break;
      }
      case 'breach': { this.breached.add(e.wallId); fx.debris(e.x, e.y, 20, '#6a645c', 4); fx.smoke(e.x, e.y, 10, 'rgba(120,110,100,0.6)', 0.5); log(`${this.nameOf(e.id ?? -1) === '?' ? 'Someone' : this.nameOf(e.id)} smashed through the ${e.name}`); break; }
      case 'explode': {
        fx.explosion(e.x, e.y, 1.7, heavy); au.explosion(au.now(), 1.4, panOf(e.x)); this.scorch(e.x, e.y, 2);
        fx.text(e.x, e.y - 1, 'BOOM', '#ff7a1f', 1.0, 1.5); big(e.x, e.y, 2.8, 1.8); if (p.opts.onBig) p.opts.onBig('explode', e);
        log(`${this.nameOf(e.id)} EXPLODES`, 'bad');
        break;
      }
      case 'mine': { fx.explosion(e.x, e.y, 0.9, heavy); au.mine(panOf(e.x)); this.scorch(e.x, e.y, 0.8); fx.text(e.x, e.y - 0.6, 'MINE!', '#ff7a1f', 0.6, 1.2); big(e.x, e.y, 2.4, 1); break; }
      case 'death': {
        const v = this.vehicleAt(e.id); if (v) { fx.smoke(v.x, v.y, 20, 'rgba(30,30,30,0.7)', 0.5); fx.text(v.x, v.y - 0.8, this.nameOf(e.id).toUpperCase() + ' IS OUT', '#ff3b3b', 0.6, 2); big(v.x, v.y, 2.6, 1.6); }
        au.sting('death'); if (p.opts.onBig) p.opts.onBig('death', e);
        log(`${this.nameOf(e.id)} is out: ${e.reason}` + (e.by != null && e.by !== e.id ? ` (${this.nameOf(e.by)})` : ''), 'bad');
        break;
      }
      case 'fire': { const v = this.vehicleAt(e.id); if (v) { fx.fire(v.x, v.y, 12, 0.3); fx.text(v.x, v.y - 0.6, 'ON FIRE', '#ff7a1f', 0.5, 1.3); } au.fireCrackle(); log(`${this.nameOf(e.id)} is on fire`, e.id === this.myVehicleId ? 'bad' : ''); break; }
      case 'fireout': { const v = this.vehicleAt(e.id); if (v) { fx.smoke(v.x, v.y, 10, 'rgba(200,200,200,0.6)', 0.3); fx.text(v.x, v.y - 0.6, 'FIRE OUT', '#9f9', 0.4, 1); } break; }
      case 'skid': case 'spin': case 'roll': case 'vault': case 'fishtail': {
        const v = this.vehicleAt(e.id); if (!v) break;
        const colors = { skid: '#fff', spin: '#ffd02f', roll: '#ff7a1f', vault: '#ff3b3b', fishtail: '#ddd' };
        fx.text(v.x, v.y - 0.6, (e.text || e.type).toUpperCase(), colors[e.type], e.type === 'vault' || e.type === 'roll' ? 0.7 : 0.4, 1.3);
        fx.smoke(v.x, v.y, 6, 'rgba(200,200,200,0.5)', 0.3); au.skid(panOf(v.x), e.type === 'skid' ? 0.4 : 0.8);
        if (e.type === 'roll' || e.type === 'vault') { if (heavy) fx.slowmo(0.4, 1.4); fx.chroma = Math.max(fx.chroma, 0.8); big(v.x, v.y, 2.4, 1.6); fx.shakeBy(0.4); if (p.opts.onBig) p.opts.onBig(e.type, e); }
        if (e.type === 'spin') big(v.x, v.y, 2.6, 1.2);
        log(`${this.nameOf(e.id)}: ${e.text}`, e.id === this.myVehicleId ? 'bad' : '');
        break;
      }
      case 'rollhit': { const v = this.vehicleAt(e.id); if (v) { fx.sparks(v.x, v.y, 12, '#ffd27a', 4); fx.debris(v.x, v.y, 6, '#333', 3); au.crashHit(25, panOf(v.x)); fx.shakeBy(0.2); } break; }
      case 'jump': { const v = this.vehicleAt(e.id); if (v) { fx.text(v.x, v.y - 0.6, 'JUMP!', '#2fe6e6', 0.6, 1.2); fx.smoke(v.x, v.y, 8, 'rgba(160,150,130,0.6)', 0.3); } au.whoosh(panOf(v ? v.x : 0)); if (heavy) fx.slowmo(0.5, 0.9); big(v ? v.x : 0, v ? v.y : 0, 2.4, 1.2); break; }
      case 'land': { const v = this.vehicleAt(e.id); if (v) { fx.smoke(v.x, v.y, 10, 'rgba(160,150,130,0.6)', 0.35); fx.sparks(v.x, v.y, 8, '#ffd27a', 3); fx.text(v.x, v.y - 0.5, e.text.toUpperCase(), '#ddd', 0.4, 1); } au.thud(panOf(v ? v.x : 0)); fx.shakeBy(0.3); break; }
      case 'drop': { this.liveCounters.push({ id: 'live' + Math.random(), type: e.type, x: e.x, y: e.y, w: e.w, h: e.h, angle: e.angle, ttl: -1 }); au.drop(panOf(e.x)); if (e.type === 'smoke') fx.smoke(e.x, e.y, 12, 'rgba(170,170,175,0.7)', 0.35); else if (e.type === 'paint') fx.smoke(e.x, e.y, 10, 'rgba(255,0,180,0.5)', 0.3); else if (e.type === 'flamingoil') fx.fire(e.x, e.y, 10, 0.3); else fx.sparks(e.x, e.y, 4, '#ccc', 1.5); log(`${this.nameOf(e.id)} drops ${e.type}`); break; }
      case 'hazard': { const v = this.vehicleAt(e.id); if (v && e.kind !== 'offroad') fx.text(v.x, v.y - 0.5, (e.text || e.kind).toUpperCase(), '#ddd', 0.35, 0.9); if (e.kind === 'rad') au.geiger(panOf(v ? v.x : 0)); if (e.kind === 'flamingoil' && v) fx.fire(v.x, v.y, 8, 0.25); break; }
      case 'control': { if (!e.keep) { const v = this.vehicleAt(e.id); if (v) fx.text(v.x, v.y - 0.7, 'LOSES CONTROL', '#ff3b3b', 0.45, 1.2); log(`${this.nameOf(e.id)} loses control (needed ${e.need}, rolled ${e.roll})`, e.id === this.myVehicleId ? 'bad' : ''); } break; }
      case 'driver': { const v = this.vehicleAt(e.id); if (v && e.text) fx.text(v.x, v.y + 0.5, e.text.toUpperCase(), e.dp <= 1 ? '#ff3b3b' : '#ff9f5c', 0.4, 1.4); log(`${this.nameOf(e.id)}: ${e.text}`, e.id === this.myVehicleId ? 'bad' : ''); break; }
      case 'tire': { const v = this.vehicleAt(e.id); if (v) { fx.sparks(v.x, v.y, 10, '#ccc', 3); fx.debris(v.x, v.y, 5, '#111', 3); fx.text(v.x, v.y + 0.4, 'TYRE BLOWN', '#ffb347', 0.4, 1.2); } au.gun('MG', 0); break; }
      case 'tiredmg': { const v = this.vehicleAt(e.id); if (v) fx.sparks(v.x, v.y, 3, '#ccc', 2); break; }
      case 'text': { const v = this.vehicleAt(e.id); if (v) fx.text(v.x, v.y - 0.6, e.text.toUpperCase(), '#fff', 0.4, 1.2); log(`${this.nameOf(e.id)}: ${e.text}`); break; }
      case 'burn': { const v = this.vehicleAt(e.id); if (v) fx.fire(v.x, v.y, 10, 0.3); break; }
      case 'armor': case 'destroyed': case 'firecheck': case 'speed': case 'maneuver': case 'crash': case 'gameover': default: break;
    }
  }

  // ------------------------------------------------------------ drawing
  draw() {
    const ctx = this.sctx, W = this.W, H = this.H, dpr = this.dpr;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.fillStyle = '#0b0d10'; ctx.fillRect(0, 0, W, H);
    if (!this.map) { this.present(); return; }
    const shake = this.fx.shake * (this.heavy ? 1 : 0.4);
    const sx = (Math.random() - 0.5) * shake * 18, sy = (Math.random() - 0.5) * shake * 18;
    ctx.save();
    ctx.translate(W / 2 + sx, H / 2 + sy); ctx.scale(this.cam.zoom, this.cam.zoom); ctx.translate(-this.cam.x, -this.cam.y);
    const px = this.cam.zoom;
    // ground, marks
    ctx.drawImage(this.ground, 0, 0, this.map.width, this.map.height);
    ctx.drawImage(this.marks, 0, 0, this.map.width, this.map.height);
    drawTerrainLive(ctx, this.map, this.time);
    // counters
    const counters = this.playback ? this.liveCounters : this.counters;
    for (const c of counters) if (c.ttl !== 0) drawCounter(ctx, c, this.time);
    // walls
    drawWalls(ctx, this.walls, this.time, this.breached);
    // bonfires burn
    if (this.heavy) for (const w of this.walls) if (w.style === 'bonfire' && !this.breached.has(w.id) && Math.random() < 0.5) this.fx.fire(w.x + (Math.random() - 0.5) * 0.6, w.y + (Math.random() - 0.5) * 0.6, 1, 0.25);
    // planning overlays
    if (!this.playback) this.drawPlanning(ctx);
    // cars: wrecks, then alive, then airborne
    const vehicles = this.currentVehicles();
    const order = vehicles.filter((v) => v.status !== 'gone').sort((a, b) => (a.status === 'alive') - (b.status === 'alive') || (a.z || 0) - (b.z || 0));
    for (const v of order) {
      ctx.save(); ctx.translate(v.x, v.y); ctx.rotate(v.heading);
      if (v.id === this.myVehicleId && !this.cinematic) { ctx.strokeStyle = 'rgba(255,255,255,0.6)'; ctx.lineWidth = 0.06; ctx.setLineDash([0.12, 0.08]); ctx.strokeRect(-v.len / 2 - 0.1, -v.wid / 2 - 0.1, v.len + 0.2, v.wid + 0.2); ctx.setLineDash([]); }
      if (v.id === this.targetId && !this.cinematic) { ctx.strokeStyle = '#ff3b3b'; ctx.lineWidth = 0.06; ctx.beginPath(); ctx.arc(0, 0, v.len * 0.75, 0, TAU); ctx.stroke(); ctx.beginPath(); for (let i = 0; i < 4; i++) { const a = i * Math.PI / 2 + this.time * 2; ctx.moveTo(Math.cos(a) * v.len * 0.6, Math.sin(a) * v.len * 0.6); ctx.lineTo(Math.cos(a) * v.len * 0.95, Math.sin(a) * v.len * 0.95); } ctx.stroke(); }
      drawCar(ctx, v, {});
      ctx.restore();
      if (v.fire && v.fire.burning && this.playback) { if (Math.random() < (this.heavy ? 0.9 : 0.4)) this.fx.fire(v.x + (Math.random() - 0.5) * v.len * 0.6, v.y + (Math.random() - 0.5) * v.wid, 2, 0.22); if (Math.random() < 0.3) this.fx.smoke(v.x, v.y, 1, 'rgba(40,40,40,0.6)', 0.3); }
      else if (v.fire && v.fire.burning) { if (Math.random() < 0.5) this.fx.fire(v.x + (Math.random() - 0.5) * v.len * 0.6, v.y + (Math.random() - 0.5) * v.wid, 1, 0.2); }
      if (v.plant && v.plant.dp <= v.plant.max / 2 && v.status === 'alive' && Math.random() < 0.25) this.fx.smoke(v.x - Math.cos(v.heading) * v.len * 0.4, v.y - Math.sin(v.heading) * v.len * 0.4, 1, 'rgba(50,50,55,0.5)', 0.15);
      if (this.playback && Math.abs(v.speed) >= 60 && v.status === 'alive' && this.heavy && Math.random() < 0.5) this.fx.smoke(v.x - Math.cos(v.heading) * v.len * 0.5, v.y - Math.sin(v.heading) * v.len * 0.5, 1, 'rgba(120,110,100,0.25)', 0.12);
    }
    this.fx.draw(ctx, px, this.time);
    drawOverhead(ctx, this.map, this.time);
    if (this.showLabels) this.drawLabels(ctx, vehicles);
    ctx.restore();
    this.present();
  }
  drawPlanning(ctx) {
    const g = this.ghost;
    const me = this.vehicles.find((v) => v.id === this.myVehicleId);
    if (me && this.rangeRing > 0 && me.status === 'alive') { ctx.strokeStyle = 'rgba(255,255,255,0.12)'; ctx.lineWidth = 0.04; ctx.setLineDash([0.3, 0.3]); ctx.beginPath(); ctx.arc(me.x, me.y, this.rangeRing, 0, TAU); ctx.stroke(); ctx.setLineDash([]); }
    if (me && me.status === 'alive' && me.weapons) {
      // faint arcs of fire for the sides that carry guns
      const sides = new Set(me.weapons.filter((w) => w.dp > 0 && w.shots > 0 && !w.type.startsWith('drop')).map((w) => w.side));
      ctx.save(); ctx.translate(me.x, me.y); ctx.rotate(me.heading); ctx.fillStyle = 'rgba(255,208,47,0.07)';
      const R = 6, hl = me.len / 2, hw = me.wid / 2;
      if (sides.has('F')) { ctx.beginPath(); ctx.moveTo(hl, -hw); ctx.lineTo(hl + R, -hw - R); ctx.lineTo(hl + R, hw + R); ctx.lineTo(hl, hw); ctx.fill(); }
      if (sides.has('B')) { ctx.beginPath(); ctx.moveTo(-hl, -hw); ctx.lineTo(-hl - R, -hw - R); ctx.lineTo(-hl - R, hw + R); ctx.lineTo(-hl, hw); ctx.fill(); }
      if (sides.has('L')) { ctx.beginPath(); ctx.moveTo(-hl, -hw); ctx.lineTo(-hl - R, -hw - R); ctx.lineTo(hl + R, -hw - R); ctx.lineTo(hl, -hw); ctx.fill(); }
      if (sides.has('R')) { ctx.beginPath(); ctx.moveTo(-hl, hw); ctx.lineTo(-hl - R, hw + R); ctx.lineTo(hl + R, hw + R); ctx.lineTo(hl, hw); ctx.fill(); }
      if (sides.has('T')) { ctx.beginPath(); ctx.arc(0, 0, R * 0.8, 0, TAU); ctx.fill(); }
      ctx.restore();
    }
    if (!g || !me) return;
    const col = g.risk >= 7 ? '#ff3b3b' : g.risk >= 4 ? '#ff7a1f' : g.risk > 0 ? '#ffd02f' : '#7dff3a';
    ctx.save(); ctx.strokeStyle = col; ctx.lineWidth = 0.07; ctx.setLineDash([0.18, 0.12]); ctx.lineJoin = 'round';
    ctx.beginPath(); g.points.forEach((p, i) => (i ? ctx.lineTo(p.x, p.y) : ctx.moveTo(p.x, p.y))); ctx.stroke(); ctx.setLineDash([]);
    for (const p of g.points.slice(1)) { ctx.fillStyle = col; ctx.beginPath(); ctx.arc(p.x, p.y, 0.09, 0, TAU); ctx.fill(); ctx.fillStyle = '#000'; ctx.font = 'bold 0.22px sans-serif'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; ctx.fillText(String(p.phase), p.x, p.y); }
    const end = g.points[g.points.length - 1];
    ctx.translate(end.x, end.y); ctx.rotate(end.h); ctx.globalAlpha = 0.45; ctx.strokeStyle = col; ctx.lineWidth = 0.05; ctx.strokeRect(-me.len / 2, -me.wid / 2, me.len, me.wid); ctx.beginPath(); ctx.moveTo(me.len / 2, 0); ctx.lineTo(me.len / 2 + 0.25, 0); ctx.stroke();
    ctx.restore();
  }
  drawLabels(ctx, vehicles) {
    const s = 1 / this.cam.zoom; // keep labels at a constant pixel size
    for (const v of vehicles) {
      if (v.status === 'gone') continue;
      const fontPx = 12;
      ctx.save(); ctx.translate(v.x, v.y - v.wid - 0.35); ctx.scale(s, s);
      ctx.font = `bold ${fontPx}px Impact, "Arial Narrow Bold", sans-serif`; ctx.textAlign = 'center'; ctx.textBaseline = 'bottom';
      const name = v.owner.name;
      const w = ctx.measureText(name).width + 10;
      ctx.globalAlpha = v.status === 'alive' ? 0.9 : 0.4;
      ctx.fillStyle = 'rgba(0,0,0,0.6)'; ctx.fillRect(-w / 2, -fontPx - 9, w, fontPx + 4);
      ctx.fillStyle = v.color; ctx.fillText(name, 0, -7);
      if (v.status === 'alive' && v.armor && v.armorMax) {
        const tot = Object.values(v.armor).reduce((a, b) => a + b, 0), max = Object.values(v.armorMax).reduce((a, b) => a + b, 0) || 1;
        ctx.fillStyle = '#000'; ctx.fillRect(-w / 2, -5, w, 4); ctx.fillStyle = tot / max > 0.5 ? '#7dff3a' : tot / max > 0.25 ? '#ffd02f' : '#ff3b3b'; ctx.fillRect(-w / 2 + 1, -4, (w - 2) * Math.max(0, tot / max), 2);
        for (let i = 0; i < 3; i++) { ctx.fillStyle = i < (v.driver ? v.driver.dp : 3) ? '#fff' : '#555'; ctx.fillRect(-w / 2 + 2 + i * 5, 1, 3, 3); }
        if (v.fire && v.fire.burning) { ctx.fillStyle = '#ff7a1f'; ctx.font = 'bold 9px sans-serif'; ctx.fillText('FIRE', 0, 12); }
      } else if (v.status !== 'alive') { ctx.fillStyle = '#ff3b3b'; ctx.font = 'bold 9px sans-serif'; ctx.fillText('OUT', 0, 4); }
      ctx.restore();
    }
  }
  present() {
    const ctx = this.ctx, W = this.canvas.width, H = this.canvas.height;
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.globalCompositeOperation = 'source-over'; ctx.globalAlpha = 1;
    ctx.drawImage(this.scene, 0, 0);
    const ch = this.fx.chroma;
    if (ch > 0.03 && this.heavy) { const d = ch * 6 * this.dpr; ctx.globalCompositeOperation = 'lighter'; ctx.globalAlpha = 0.22 * ch; ctx.drawImage(this.scene, -d, 0); ctx.drawImage(this.scene, d, 0); ctx.globalCompositeOperation = 'source-over'; ctx.globalAlpha = 1; }
    if (this.tint && this.map) { const g = ctx.createLinearGradient(0, 0, 0, H); g.addColorStop(0, 'rgba(255,140,60,0.10)'); g.addColorStop(0.6, 'rgba(120,140,110,0.06)'); g.addColorStop(1, 'rgba(20,40,20,0.14)'); ctx.fillStyle = g; ctx.fillRect(0, 0, W, H); }
    // vignette
    const vg = ctx.createRadialGradient(W / 2, H / 2, Math.min(W, H) * 0.45, W / 2, H / 2, Math.max(W, H) * 0.75); vg.addColorStop(0, 'rgba(0,0,0,0)'); vg.addColorStop(1, 'rgba(0,0,0,0.55)'); ctx.fillStyle = vg; ctx.fillRect(0, 0, W, H);
    // ash
    ctx.fillStyle = '#d8d2c4';
    for (const a of this.ash) { ctx.globalAlpha = a.a; ctx.fillRect(a.x * this.dpr, a.y * this.dpr, a.s * this.dpr, a.s * this.dpr); }
    ctx.globalAlpha = 1;
    if (this.fx.flashA > 0) { ctx.globalAlpha = Math.min(1, this.fx.flashA); ctx.fillStyle = this.fx.flashColor; ctx.fillRect(0, 0, W, H); ctx.globalAlpha = 1; }
    // film grain, cheap
    if (this.heavy) { ctx.globalAlpha = 0.035; for (let i = 0; i < 40; i++) { ctx.fillStyle = i % 2 ? '#fff' : '#000'; ctx.fillRect(Math.random() * W, Math.random() * H, 2 * this.dpr, 2 * this.dpr); } ctx.globalAlpha = 1; }
  }
}
export { arcOf, obbCorners };
