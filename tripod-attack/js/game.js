// Tripod Attack! -- a Vectrex-style vector arcade game. Everything is stroked lines on a
// black screen, composited with phosphor persistence and glow. See README.md.
(() => {
'use strict';
const W = 1024, H = 576, GROUND = 468;
const PLAYER_X = 150, SANDBAG_L = 92, SANDBAG_R = 268, SANDBAG_TOP = GROUND - 45, SHELTER_X = 44, STOP_X = 350, PS = 1.5;
const GRAV = 520;
const GREEN = '#3cff5a', DIM = '#1d8a33', DIMMER = '#135a22', RED = '#ff3b3b', WHITE = '#eaffea', AMBER = '#ffd24a';
const WAVES_PER_SECTOR = 3;

// ---------------------------------------------------------------- canvases
const canvas = document.getElementById('screen');
const dctx = canvas.getContext('2d');
const mk = (w, h) => { const c = document.createElement('canvas'); c.width = w; c.height = h; return c; };
const scene = mk(W, H), ctx = scene.getContext('2d');
const phos = mk(W, H), pctx = phos.getContext('2d');
const glowC = mk(W / 4, H / 4), gctx = glowC.getContext('2d');
const overlay = mk(W, H);
(() => {
  const o = overlay.getContext('2d');
  o.fillStyle = 'rgba(0,0,0,0.22)';
  for (let y = 0; y < H; y += 3) o.fillRect(0, y, W, 1);
  const g = o.createRadialGradient(W / 2, H / 2, H * 0.45, W / 2, H / 2, H * 0.95);
  g.addColorStop(0, 'rgba(0,0,0,0)'); g.addColorStop(1, 'rgba(0,0,0,0.75)');
  o.fillStyle = g; o.fillRect(0, 0, W, H);
})();
let view = { scale: 1, ox: 0, oy: 0 };
function resize() {
  const dpr = Math.min(2, window.devicePixelRatio || 1);
  const cw = window.innerWidth, ch = window.innerHeight;
  canvas.width = cw * dpr; canvas.height = ch * dpr;
  const s = Math.min(cw / W, ch / H);
  view = { scale: s * dpr, ox: (cw - W * s) / 2 * dpr, oy: (ch - H * s) / 2 * dpr, cssScale: s, cssOx: (cw - W * s) / 2, cssOy: (ch - H * s) / 2 };
}
window.addEventListener('resize', resize); resize();

// ---------------------------------------------------------------- utils
const rnd = (a = 1, b) => b === undefined ? Math.random() * a : a + Math.random() * (b - a);
const clamp = (v, a, b) => v < a ? a : v > b ? b : v;
const lerp = (a, b, t) => a + (b - a) * t;
const easeInOut = t => t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2;
const pad = (n, w) => String(Math.floor(n)).padStart(w, '0');
function segDist(px, py, ax, ay, bx, by) {
  const dx = bx - ax, dy = by - ay, l2 = dx * dx + dy * dy || 1e-6;
  const t = clamp(((px - ax) * dx + (py - ay) * dy) / l2, 0, 1);
  return Math.hypot(px - (ax + dx * t), py - (ay + dy * t));
}
function overlaps(a0, a1, b0, b1) { return Math.min(a0, a1) <= b1 && Math.max(a0, a1) >= b0; }

// ---------------------------------------------------------------- vector drawing
const V = {
  poly(pts, color = GREEN, lw = 2, closed = false) {
    if (pts.length < 2) return;
    ctx.strokeStyle = color; ctx.lineWidth = lw; ctx.beginPath();
    ctx.moveTo(pts[0][0], pts[0][1]);
    for (let i = 1; i < pts.length; i++) ctx.lineTo(pts[i][0], pts[i][1]);
    if (closed) ctx.closePath();
    ctx.stroke();
  },
  line(x1, y1, x2, y2, color = GREEN, lw = 2) { ctx.strokeStyle = color; ctx.lineWidth = lw; ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke(); },
  circle(x, y, r, color = GREEN, lw = 2) { ctx.strokeStyle = color; ctx.lineWidth = lw; ctx.beginPath(); ctx.arc(x, y, Math.max(0.5, r), 0, Math.PI * 2); ctx.stroke(); },
  dot(x, y, r, color = GREEN) { ctx.fillStyle = color; ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.fill(); },
  text(str, x, y, size, align = 'left', color = GREEN, lw = 0) { VecFont.draw(ctx, str, x, y, size, align, color, lw); },
  // Many polylines in local coords (y up) placed at (ox, oy) on screen.
  lines(lines, ox, oy, color = DIM, lw = 1.5, sx = 1, sy = 1) {
    ctx.strokeStyle = color; ctx.lineWidth = lw; ctx.beginPath();
    for (const L of lines) {
      for (let i = 0; i < L.length; i++) { const x = ox + L[i][0] * sx, y = oy - L[i][1] * sy; if (i) ctx.lineTo(x, y); else ctx.moveTo(x, y); }
    }
    ctx.stroke();
  }
};

// ---------------------------------------------------------------- game state
const G = {
  state: 'title', t: 0, shake: 0, flash: 0, flashColor: WHITE, slow: 0,
  score: 0, lives: 4, sectorIdx: 0, wave: 0, endless: false,
  tripods: [], rockets: [], civs: [], parts: [], debris: [], texts: [],
  skyline: [], covers: [], stars: [],
  banner: null, menuIdx: 0, paused: false, touch: false, typed: 0,
  waveInfo: { toSpawn: 0, timer: 0, total: 0, killed: 0, clearT: 0 },
  stats: { saved: 0, lost: 0, destroyed: 0, dodged: 0 },
  attract: false, attractT: 0, battleQuote: null, battleQuoteT: 0,
  save: null, gameOverT: 0, mapAnim: 0, lostSector: null
};
function loadSave() {
  try { const s = JSON.parse(localStorage.getItem('tripodAttack.save') || 'null'); if (s && s.cleared) return s; } catch (e) { /* fine */ }
  return { cleared: new Array(10).fill(false), campaignDone: false, highCampaign: 0, highEndless: 0 };
}
function persist() { try { localStorage.setItem('tripodAttack.save', JSON.stringify(G.save)); } catch (e) { /* fine */ } }
G.save = loadSave();
for (let i = 0; i < 70; i++) G.stars.push([rnd(W), rnd(GROUND - 120), rnd() < 0.1 ? 1.6 : 1]);

// ---------------------------------------------------------------- effects
function sparks(x, y, n, o = {}) {
  const { speed = 260, spread = Math.PI * 2, dir = -Math.PI / 2, color = GREEN, life = 0.7, grav = 1, size = 1, white = 0.3 } = o;
  for (let i = 0; i < n; i++) {
    const a = dir + (rnd() - 0.5) * spread, v = speed * (0.3 + rnd() * 0.9);
    G.parts.push({ x, y, vx: Math.cos(a) * v, vy: Math.sin(a) * v, life: life * (0.5 + rnd() * 0.8), max: life, color: rnd() < white ? WHITE : color, grav, size, kind: 'spark' });
  }
}
function smoke(x, y, n, color = DIM) {
  for (let i = 0; i < n; i++) G.parts.push({ x: x + rnd(-6, 6), y, vx: rnd(-25, 25), vy: rnd(-70, -20), life: rnd(0.8, 1.8), max: 1.8, color, grav: -0.15, size: rnd(3, 9), kind: 'smoke' });
}
function debris(x, y, n, o = {}) {
  const { speed = 300, color = GREEN, len = 14 } = o;
  for (let i = 0; i < n; i++) {
    const a = -Math.PI / 2 + (rnd() - 0.5) * 2.4, v = speed * (0.3 + rnd());
    G.debris.push({ x, y, vx: Math.cos(a) * v, vy: Math.sin(a) * v, ang: rnd(Math.PI * 2), av: rnd(-14, 14), len: len * (0.4 + rnd()), life: rnd(1.5, 3.5), color, bounces: 0 });
  }
}
function floatText(x, y, text, color = GREEN, size = 12, life = 1.2) { G.texts.push({ x, y, text, color, size, life, max: life, vy: -28 }); }
function shake(v) { G.shake = Math.min(28, G.shake + v); }
function flash(a, color = WHITE) { G.flash = Math.max(G.flash, a); G.flashColor = color; }
function explosion(x, y, big = 1, color = GREEN) {
  sparks(x, y, 28 * big, { speed: 320 * big, color, life: 0.9, white: 0.5 });
  sparks(x, y, 10 * big, { speed: 120 * big, color: AMBER, life: 0.5, grav: 0.2 });
  smoke(x, y, 4 * big);
  // the shock ring
  G.parts.push({ x, y, vx: 0, vy: 0, life: 0.35, max: 0.35, color: WHITE, grav: 0, size: 40 * big, kind: 'ring' });
  shake(5 * big); flash(0.12 * big); Sfx.explosion(big);
  for (const c of G.civs) if (c.alive && Math.abs(c.x - x) < 34 * big && y > GROUND - 60) killCiv(c, 'blast');
}
function updateEffects(dt) {
  for (const p of G.parts) {
    p.life -= dt;
    if (p.kind === 'ring') { p.size += 320 * dt; continue; }
    p.vy += GRAV * p.grav * dt; p.x += p.vx * dt; p.y += p.vy * dt;
    if (p.kind === 'spark' && p.y > GROUND) { p.y = GROUND; p.vy *= -0.45; p.vx *= 0.7; if (Math.abs(p.vy) < 20) p.life = Math.min(p.life, 0.15); }
  }
  G.parts = G.parts.filter(p => p.life > 0);
  for (const d of G.debris) {
    d.life -= dt; d.vy += GRAV * dt; d.x += d.vx * dt; d.y += d.vy * dt; d.ang += d.av * dt;
    if (d.y > GROUND) { d.y = GROUND; d.vy *= -0.4; d.vx *= 0.6; d.av *= 0.5; d.bounces++; if (Math.abs(d.vy) > 60) { sparks(d.x, GROUND, 3, { speed: 90, life: 0.3 }); if (rnd() < 0.3) Sfx.spark(); } }
  }
  G.debris = G.debris.filter(d => d.life > 0);
  for (const t of G.texts) { t.life -= dt; t.y += t.vy * dt; }
  G.texts = G.texts.filter(t => t.life > 0);
  G.shake = Math.max(0, G.shake - dt * 40);
  G.flash = Math.max(0, G.flash - dt * 2.5);
}
function drawEffects() {
  for (const p of G.parts) {
    const a = clamp(p.life / p.max, 0, 1);
    if (p.kind === 'ring') { ctx.globalAlpha = a; V.circle(p.x, p.y, p.size, p.color, 2); ctx.globalAlpha = 1; continue; }
    if (p.kind === 'smoke') { ctx.globalAlpha = a * 0.5; V.circle(p.x, p.y, p.size * (1.5 - a * 0.5), p.color, 1); ctx.globalAlpha = 1; continue; }
    ctx.globalAlpha = Math.min(1, a * 1.5);
    const k = 0.035 * p.size;
    V.line(p.x, p.y, p.x - p.vx * k, p.y - p.vy * k, p.color, 1.6 * p.size);
  }
  ctx.globalAlpha = 1;
  for (const d of G.debris) {
    const c = Math.cos(d.ang) * d.len / 2, s = Math.sin(d.ang) * d.len / 2;
    ctx.globalAlpha = clamp(d.life, 0, 1);
    V.line(d.x - c, d.y - s, d.x + c, d.y + s, d.color, 2);
  }
  ctx.globalAlpha = 1;
  for (const t of G.texts) { ctx.globalAlpha = clamp(t.life / t.max * 1.5, 0, 1); V.text(t.text, t.x, t.y, t.size, 'center', t.color); }
  ctx.globalAlpha = 1;
}

// ---------------------------------------------------------------- player (the artilleryman)
const P = { x: PLAYER_X, duck: false, angle: -0.55, power: 680, reload: 0, reloadTime: 1.05, inv: 0, recoil: 0, drag: null, duckPointer: null, keys: {}, fireFlash: 0, burnT: 0 };
function shoulder() { return [P.x + 4 * PS, P.duck ? GROUND - 22 * PS : GROUND - 48 * PS]; }
function muzzle() {
  const [px, py] = shoulder();
  return [px + Math.cos(P.angle) * 42 * PS, py + Math.sin(P.angle) * 42 * PS, px, py];
}
function fireRocket() {
  if (P.reload > 0 || P.duck || P.burnT > 0) return false;
  const [mx, my, px, py] = muzzle();
  const v = P.power;
  G.rockets.push({ x: mx, y: my, vx: Math.cos(P.angle) * v, vy: Math.sin(P.angle) * v, t: 0, alive: true });
  P.reload = P.reloadTime; P.recoil = 1; P.fireFlash = 0.08;
  sparks(mx, my, 10, { speed: 220, dir: P.angle, spread: 0.7, color: AMBER, life: 0.3, white: 0.6 });
  sparks(px - Math.cos(P.angle) * 30, py - Math.sin(P.angle) * 30, 14, { speed: 260, dir: P.angle + Math.PI, spread: 0.9, color: DIM, life: 0.35 }); // back-blast
  floatText(mx + 26, my - 30, 'FIRE', GREEN, 10, 0.45);
  shake(2); Sfx.launch();
  return true;
}
function updatePlayer(dt) {
  P.reload = Math.max(0, P.reload - dt); P.inv = Math.max(0, P.inv - dt); P.recoil = Math.max(0, P.recoil - dt * 4);
  P.fireFlash = Math.max(0, P.fireFlash - dt); P.burnT = Math.max(0, P.burnT - dt);
  const k = P.keys;
  if (k.aimUp) P.angle -= 1.3 * dt; if (k.aimDown) P.angle += 1.3 * dt;
  if (k.powUp) P.power += 420 * dt; if (k.powDown) P.power -= 420 * dt;
  P.angle = clamp(P.angle, -1.45, 0.12); P.power = clamp(P.power, 380, 1000);
  P.duck = !!(k.duck || P.duckPointer !== null) && P.burnT <= 0;
  if (P.drag) {
    const dx = P.drag.sx - P.drag.x, dy = P.drag.sy - P.drag.y, len = Math.hypot(dx, dy);
    if (len > 12) { P.angle = clamp(Math.atan2(dy, dx), -1.45, 0.12); P.power = clamp(380 + len * 3.6, 380, 1000); }
  }
}
function playerHit(why) {
  if (P.inv > 0 || G.attract || G.state !== 'play') return;
  G.lives--; P.inv = 2.6; P.burnT = 0.9; P.duck = false;
  const [, , px, py] = muzzle();
  sparks(P.x, GROUND - 40, 60, { speed: 300, color: WHITE, life: 1, white: 1 });
  sparks(P.x, GROUND - 40, 30, { speed: 200, color: RED, life: 0.8 });
  flash(0.6, RED); shake(14); Sfx.hurt();
  floatText(P.x, GROUND - 110, why === 'beam' ? 'TURNED TO FIRE' : why === 'crush' ? 'CRUSHED' : 'OVERRUN', RED, 13, 1.6);
  if (G.lives <= 0) { G.lives = 0; beginGameOver(); }
}
function drawPlayer() {
  if (G.attract) return;
  const S = PS, x = P.x, duck = P.duck;
  const hipY = GROUND - 8 * S, [shX, shY] = shoulder(), headY = shY - 11 * S;
  const rec = P.recoil * 5 * S;
  const visible = !(P.inv > 0 && Math.floor(G.t * 18) % 2 === 0 && P.burnT <= 0); // invulnerability flicker
  const col = P.burnT > 0 ? (Math.floor(G.t * 30) % 2 ? WHITE : RED) : GREEN;
  if (visible) {
    // kneeling legs
    V.poly([[x - 2 * S, hipY], [x - 16 * S, hipY + 4 * S], [x - 10 * S, GROUND]], col, 2);
    V.poly([[x - 2 * S, hipY], [x + 12 * S, hipY - 8 * S], [x + 14 * S, GROUND]], col, 2);
    V.line(x + 8 * S, GROUND, x + 20 * S, GROUND, col, 2);
    // torso and pack
    V.line(x - 2 * S, hipY, shX - 4 * S - rec, shY + 2 * S, col, 2.5);
    V.poly([[shX - 16 * S - rec, shY + 4 * S], [shX - 16 * S - rec, hipY - 4 * S], [x - 4 * S, hipY - 2 * S]], col, 1.6);
    V.poly([[shX - 15 * S - rec, shY + 8 * S], [shX - 11 * S - rec, shY + 8 * S], [shX - 11 * S - rec, hipY - 6 * S], [shX - 15 * S - rec, hipY - 6 * S]], col, 1.2, true);
    // head with helmet
    V.circle(shX - 1 * S - rec, headY, 6 * S, col, 2);
    V.poly([[shX - 9 * S - rec, headY - 1 * S], [shX - 7 * S - rec, headY - 8 * S], [shX + 5 * S - rec, headY - 8 * S], [shX + 7 * S - rec, headY - 1 * S]], col, 1.8);
    // the launcher tube on the shoulder
    const a = P.angle, px = shX - rec, py = shY, c = Math.cos(a), sn = Math.sin(a), nx = -sn, ny = c;
    const L0 = -22 * S, L1 = 42 * S, r = 4 * S;
    V.poly([[px + c * L0 + nx * r, py + sn * L0 + ny * r], [px + c * L1 + nx * r, py + sn * L1 + ny * r], [px + c * L1 - nx * r, py + sn * L1 - ny * r], [px + c * L0 - nx * r, py + sn * L0 - ny * r]], col, 2, true);
    V.circle(px + c * L1, py + sn * L1, 5.5 * S, col, 1.6);
    V.line(px + c * 10 * S, py + sn * 10 * S, px + c * 10 * S + nx * 12 * S, py + sn * 10 * S + ny * 12 * S, col, 1.6);
    // arms
    V.line(shX - 4 * S - rec, shY + 2 * S, px + c * 14 * S + nx * 6 * S, py + sn * 14 * S + ny * 6 * S, col, 2);
    V.line(shX - 4 * S - rec, shY + 2 * S, px + c * -6 * S + nx * 6 * S, py + sn * -6 * S + ny * 6 * S, col, 2);
    if (P.fireFlash > 0) { const mx = px + c * L1, my = py + sn * L1; for (let i = 0; i < 6; i++) { const aa = a + (rnd() - 0.5) * 1.2; V.line(mx, my, mx + Math.cos(aa) * rnd(14, 40), my + Math.sin(aa) * rnd(14, 40), WHITE, 1.5); } }
    if (P.reload > 0 && !duck) { const w = 40, f = 1 - P.reload / P.reloadTime; V.line(x - w / 2, headY - 26, x - w / 2 + w * f, headY - 26, DIM, 2); }
  }
  // sandbags, drawn over the man
  const rows = [[SANDBAG_L, SANDBAG_R, GROUND - 15], [SANDBAG_L + 10, SANDBAG_R - 8, GROUND - 30], [SANDBAG_L + 22, SANDBAG_R - 20, GROUND - 45]];
  for (const [x0, x1, y] of rows) {
    for (let x = x0; x < x1 - 6; x += 30) { const w = Math.min(30, x1 - x); V.poly([[x, y + 15], [x + 3, y], [x + w - 3, y], [x + w, y + 15]], GREEN, 1.6); }
    V.line(x0, y + 15, x1, y + 15, GREEN, 1.6);
  }
  // aim preview: dotted ballistic arc
  if (!duck && G.state === 'play' && (P.drag || P.reload <= 0)) {
    const [mx, my] = muzzle(), a = P.angle;
    let sx = mx, sy = my, vx = Math.cos(a) * P.power, vy = Math.sin(a) * P.power;
    const step = 0.05, n = P.drag ? 22 : 9;
    ctx.globalAlpha = P.drag ? 0.9 : 0.35;
    for (let i = 0; i < n; i++) {
      const spd = Math.hypot(vx, vy), th = i * step < 0.7 ? 260 : 0;
      vx += vx / spd * th * step; vy += vy / spd * th * step;
      vy += GRAV * step; sx += vx * step; sy += vy * step;
      if (sy > GROUND) break;
      V.dot(sx, sy, 1.6, i % 2 ? DIM : GREEN);
    }
    ctx.globalAlpha = 1;
  }
  if (P.drag) {
    const d = P.drag; V.line(d.sx, d.sy, d.x, d.y, DIM, 1); V.circle(d.sx, d.sy, 6, DIM, 1); V.circle(d.x, d.y, 10, GREEN, 1.4);
  }
}

// ---------------------------------------------------------------- civilians
class Civ {
  constructor(x) {
    this.x = x; this.y = GROUND; this.speed = rnd(55, 95); this.t = rnd(10); this.h = rnd(15, 21); this.alive = true;
    this.state = 'run'; this.cover = null; this.panic = 0; this.child = rnd() < 0.2; this.screamT = rnd(1, 4); this.done = false;
  }
  update(dt) {
    this.t += dt; this.screamT -= dt;
    const danger = G.tripods.some(tp => tp.alive && (tp.state === 'siren' || tp.state === 'fire'));
    if (danger) this.panic = Math.min(1, this.panic + dt * 2); else this.panic = Math.max(0, this.panic - dt);
    if (this.screamT < 0 && this.panic > 0.5) { this.screamT = rnd(1.5, 4); Sfx.scream(); }
    if (this.state === 'run') {
      this.x -= this.speed * (1 + this.panic * 0.6) * dt;
      if (danger && !this.cover) {
        const c = G.covers.find(cv => Math.abs(cv.x - this.x) < 110 && cv.x <= this.x + 20);
        if (c && rnd() < 0.9) { this.cover = c; this.state = 'tocover'; }
      }
      if (this.x < SHELTER_X) this.saved();
    } else if (this.state === 'tocover') {
      const dir = Math.sign(this.cover.x - 6 - this.x);
      this.x += dir * this.speed * 1.5 * dt;
      if (Math.abs(this.cover.x - 6 - this.x) < 4) { this.state = 'hide'; this.hideT = 0; }
    } else if (this.state === 'hide') {
      this.hideT += dt;
      if (!danger && this.hideT > 1.2) { this.state = 'run'; this.cover = null; }
    }
  }
  saved() {
    this.alive = false; this.done = true; G.stats.saved++;
    const pts = this.child ? 400 : 200; G.score += pts; floatText(SHELTER_X + 30, GROUND - 60, '+' + pts, GREEN, 11); Sfx.saved();
    sparks(SHELTER_X, GROUND - 30, 6, { speed: 60, color: GREEN, life: 0.4 });
  }
  draw() {
    const x = this.x, h = this.h, col = GREEN;
    if (this.state === 'hide') {
      // crouched behind the rubble
      V.circle(x, GROUND - h * 0.45, h * 0.17, col, 1.4);
      V.poly([[x, GROUND - h * 0.3], [x + 4, GROUND - h * 0.1], [x + 2, GROUND]], col, 1.4);
      return;
    }
    const run = Math.sin(this.t * 22 * (1 + this.panic * 0.3)), bob = Math.abs(Math.cos(this.t * 22)) * 2;
    const hy = GROUND - h * 0.45 - bob, hdy = GROUND - h - bob;
    V.circle(x, hdy, h * 0.17, col, 1.4);
    V.line(x, hdy + h * 0.17, x, hy, col, 1.6);
    V.poly([[x, hy], [x - 4 - run * 4, hy + h * 0.25], [x - 6 - run * 6, GROUND - (run > 0 ? 0 : 3)]], col, 1.4);
    V.poly([[x, hy], [x + 4 + run * 4, hy + h * 0.25], [x + 6 + run * 6, GROUND - (run < 0 ? 0 : 3)]], col, 1.4);
    const ay = hdy + h * 0.3;
    V.poly([[x, ay], [x - 4 + run * 5, ay + 4], [x - 6 + run * 5, ay + 1]], col, 1.3);
    V.poly([[x, ay], [x + 4 - run * 5, ay + 4], [x + 6 - run * 5, ay + 1]], col, 1.3);
    if (this.child) { V.circle(x + 6, hdy + h * 0.5, 2.5, col, 1.2); V.line(x + 6, hdy + h * 0.5 + 2.5, x + 6, hy + 2, col, 1.2); }
  }
}
function killCiv(c, how) {
  if (!c.alive) return;
  c.alive = false; G.stats.lost++;
  if (how === 'beam') { sparks(c.x, GROUND - c.h * 0.6, 26, { speed: 160, color: WHITE, life: 0.6, white: 1 }); sparks(c.x, GROUND - c.h * 0.6, 10, { speed: 90, color: RED, life: 0.5 }); Sfx.burn(); }
  else { sparks(c.x, GROUND - 10, 14, { speed: 160, color: GREEN, life: 0.5 }); Sfx.crunch(); }
  floatText(c.x, GROUND - 50, how === 'beam' ? 'TURNED TO FIRE' : 'LOST', RED, 9, 1.2);
}

// ---------------------------------------------------------------- the fighting-machines
let tripodId = 0;
class Tripod {
  constructor(o) {
    const s = this.s = o.scale || 1;
    this.id = ++tripodId;
    this.x = o.x; this.speed = o.speed; this.legHp = o.legHp; this.cooldown = o.cooldown; this.sirenDur = o.sirenDur; this.fireDur = o.fireDur || 1.15;
    this.r = 44 * s; this.baseY = GROUND - 238 * s; this.y = this.baseY;
    this.L1 = 100 * s; this.L2 = 142 * s;
    this.hipOff = [[-24 * s, 28 * s], [2 * s, 34 * s], [26 * s, 28 * s]];
    this.rest = [-72 * s, 6 * s, 76 * s];
    this.legs = this.rest.map((rx, i) => ({ hp: o.legHp, max: o.legHp, footX: this.x + rx, footY: GROUND, swing: false, fromX: 0, phase: i / 3, kneeSide: i === 1 ? 1 : Math.sign(rx), broken: false, flash: 0, kx: 0, ky: 0 }));
    this.stride = 64 * s; this.period = this.stride / this.speed; this.gaitT = rnd(this.period);
    this.state = 'walk'; this.t = 0; this.cool = o.firstCool != null ? o.firstCool : rnd(2.5, 5);
    this.alive = true; this.dynamic = false; this.world = null; this.wreckT = 0; this.settled = false; this.gone = false;
    this.hoodGlow = 0; this.beam = null; this.hitFlash = 0; this.tent = rnd(10); this.big = !!o.big; this.knock = 0;
    this.crushed = false; this.impactSoundT = 0; this.score = this.big ? 2500 : 1000;
  }
  hip(i) { return [this.x + this.hipOff[i][0], this.y + this.hipOff[i][1]]; }
  emitter() { return [this.x - this.r * 0.62, this.y - this.r * 0.1]; }
  knee(i) {
    const leg = this.legs[i], [hx, hy] = this.hip(i), fx = leg.footX, fy = leg.footY;
    const L1 = this.L1, L2 = this.L2;
    let dx = fx - hx, dy = fy - hy, d = clamp(Math.hypot(dx, dy), Math.abs(L1 - L2) + 1, L1 + L2 - 1);
    const ang = Math.atan2(dy, dx), a = Math.acos(clamp((L1 * L1 + d * d - L2 * L2) / (2 * L1 * d), -1, 1));
    const k1 = [hx + Math.cos(ang + a) * L1, hy + Math.sin(ang + a) * L1], k2 = [hx + Math.cos(ang - a) * L1, hy + Math.sin(ang - a) * L1];
    // the knee bends outward, away from the body, like the Martian machines
    const want = leg.kneeSide;
    return (k1[0] - this.x) * want > (k2[0] - this.x) * want ? k1 : k2;
  }
  update(dt) {
    this.hitFlash = Math.max(0, this.hitFlash - dt);
    for (const l of this.legs) l.flash = Math.max(0, l.flash - dt);
    if (this.dynamic) return this.updateDynamic(dt);
    this.t += dt; this.tent += dt;
    if (this.state === 'walk') {
      if (this.x > STOP_X) { this.x -= this.speed * dt; this.gaitT += dt; this.updateGait(dt); }
      else this.overrun();
      this.y = this.baseY + Math.sin(this.gaitT / this.period * Math.PI * 6) * 2.5 * this.s;
      this.cool -= dt;
      if (this.cool <= 0 && this.x < 880) {
        this.state = 'siren'; this.t = 0; Sfx.siren(this.sirenDur, this.big ? 0.8 : 1);
        floatText(this.x, this.y - this.r - 40, 'ULLA...', RED, 14, this.sirenDur);
      }
    } else if (this.state === 'siren') {
      this.settleFeet(dt);
      this.hoodGlow = 0.5 + 0.5 * Math.sin(this.t * 28);
      if (this.t > this.sirenDur) {
        this.state = 'fire'; this.t = 0; Sfx.heatRay(this.fireDur);
        const [ex, ey] = this.emitter();
        this.beam = { gx: this.x - 70 * this.s, prev: this.x - 70 * this.s, ex, ey, touched: new Set() };
        shake(3); flash(0.1, RED);
      }
    } else if (this.state === 'fire') {
      this.settleFeet(dt);
      this.hoodGlow = 1;
      const u = clamp(this.t / this.fireDur, 0, 1);
      this.beam.prev = this.beam.gx;
      this.beam.gx = lerp(this.x - 70 * this.s, 20, easeInOut(u));
      [this.beam.ex, this.beam.ey] = this.emitter();
      if (this.t > this.fireDur) { this.state = 'walk'; this.beam = null; this.hoodGlow = 0; this.cool = this.cooldown * rnd(0.8, 1.25); }
    } else if (this.state === 'knock') {
      this.knock -= dt; this.x += 170 * dt; this.gaitT += dt * 2; this.updateGait(dt, true);
      if (this.knock <= 0) { this.state = 'walk'; this.cool = 2.5; }
    }
  }
  allFeetDown() { return this.legs.every(l => !l.swing); }
  settleFeet(dt) { for (const l of this.legs) if (l.swing || l.footY < GROUND) { l.footY = Math.min(GROUND, l.footY + 260 * this.s * dt); if (l.footY >= GROUND) l.swing = false; } }
  updateGait(dt, backwards = false) {
    const ph = (this.gaitT / this.period) % 1, swingLen = 0.3, dir = backwards ? -1 : 1;
    for (let i = 0; i < 3; i++) {
      const leg = this.legs[i], lp = (ph - leg.phase + 1) % 1;
      if (lp < swingLen) {
        if (!leg.swing) { leg.swing = true; leg.fromX = leg.footX; }
        const k = lp / swingLen;
        const target = this.x + this.rest[i] - dir * this.stride * ((1 - swingLen) / 2 + swingLen * (1 - k));
        leg.footX = lerp(leg.fromX, target, 1 - Math.pow(1 - k, 2));
        leg.footY = GROUND - Math.sin(k * Math.PI) * 30 * this.s;
      } else if (leg.swing) {
        leg.swing = false; leg.footY = GROUND;
        { Sfx.footstep(this.s); shake(1.5 * this.s); sparks(leg.footX, GROUND, 5, { speed: 70 * this.s, color: DIM, life: 0.4, spread: 1.6 }); smoke(leg.footX, GROUND, 1, DIMMER); }
      }
    }
  }
  overrun() {
    // The machine has reached the sandbags: it stamps the position flat and is driven back.
    if (this.state !== 'walk') return;
    this.state = 'knock'; this.knock = 1.6;
    Sfx.stomp(); shake(22); flash(0.3, RED);
    sparks(PLAYER_X + 60, GROUND, 40, { speed: 300, color: GREEN, life: 0.8 }); debris(SANDBAG_R, GROUND - 20, 8, { len: 10 });
    playerHit('overrun');
  }
  // A rocket strikes. Returns true if it hit anything.
  hitTest(rk) {
    if (this.dynamic) {
      for (const p of this.world.particles) if (Math.hypot(p.x - rk.x, p.y - rk.y) < 16 * this.s) {
        p.setVelocity((p.x - p.px) / this.world.dt + rk.vx * 0.5, (p.y - p.py) / this.world.dt + rk.vy * 0.5, this.world.dt);
        sparks(rk.x, rk.y, 20, { speed: 240, life: 0.6, white: 0.5 }); Sfx.legHit(); G.score += 50; floatText(rk.x, rk.y - 20, '+50', GREEN, 10);
        return true;
      }
      return false;
    }
    // hood: armoured, the rocket glances off
    if (Math.hypot(rk.x - this.x, rk.y - this.y) < this.r * 1.1) {
      sparks(rk.x, rk.y, 22, { speed: 260, dir: Math.atan2(rk.y - this.y, rk.x - this.x), spread: 1.6, life: 0.5, white: 0.6 });
      Sfx.ricochet(); this.hitFlash = 0.2; G.score += 25; floatText(rk.x, rk.y - 30, 'ARMOUR', DIM, 9, 0.8);
      return true;
    }
    for (let i = 0; i < 3; i++) {
      const leg = this.legs[i]; if (leg.broken) continue;
      const [hx, hy] = this.hip(i), [kx, ky] = this.knee(i);
      const thick = 7 * this.s + 4;
      if (segDist(rk.x, rk.y, hx, hy, kx, ky) < thick || segDist(rk.x, rk.y, kx, ky, leg.footX, leg.footY) < thick) {
        this.damageLeg(i, rk);
        return true;
      }
    }
    return false;
  }
  damageLeg(i, rk) {
    const leg = this.legs[i];
    leg.hp -= 1; leg.flash = 0.25; this.hitFlash = 0.1;
    sparks(rk.x, rk.y, 34, { speed: 320, life: 0.7, white: 0.5 }); sparks(rk.x, rk.y, 12, { speed: 150, color: AMBER, life: 0.5 });
    debris(rk.x, rk.y, 4, { len: 8 }); shake(5); Sfx.legHit(); Sfx.explosion(0.5);
    G.score += 100; floatText(rk.x, rk.y - 24, '+100', GREEN, 11);
    if (leg.hp <= 0) {
      leg.broken = true; Sfx.legBreak();
      sparks(rk.x, rk.y, 70, { speed: 420, life: 1.1, white: 0.6 }); debris(rk.x, rk.y, 12, { len: 16 }); flash(0.25); shake(12);
      floatText(this.x, this.y - this.r - 30, 'LEG DOWN!', WHITE, 14, 1.5);
      this.collapse(rk.vx * 0.35, rk.vy * 0.2, rk);
    }
  }
  collapse(ivx, ivy) {
    this.dynamic = true; this.alive = false; this.wreckT = 0;
    G.stats.destroyed++; G.waveInfo.killed++;
    G.score += this.score; floatText(this.x, this.y - this.r - 60, '+' + this.score, AMBER, 16, 2);
    const w = this.world = new VerletWorld(GROUND);
    const r = this.r, dt = w.dt;
    const c = w.add(this.x, this.y), top = w.add(this.x, this.y - r), l = w.add(this.x - r, this.y + r * 0.3), rr = w.add(this.x + r, this.y + r * 0.3);
    w.rigid([c, top, l, rr]);
    this.pts = { c, top, l, rr };
    this.legPts = [];
    for (let i = 0; i < 3; i++) {
      const leg = this.legs[i], [hx, hy] = this.hip(i), [kx, ky] = this.knee(i);
      const hip = w.add(hx, hy); w.attach(hip, [c, l, rr]);
      const knee = w.add(kx, ky), foot = w.add(leg.footX, leg.footY);
      if (leg.broken) { w.stick(knee, foot); knee.setVelocity(rnd(-80, 80), -rnd(60, 160), dt); }
      else { w.stick(hip, knee); w.stick(knee, foot); w.stick(hip, foot, null, (this.L1 + this.L2) * 0.4, (this.L1 + this.L2) * 0.985); }
      this.legPts.push({ hip, knee, foot });
    }
    const vx = -this.speed + ivx + rnd(-30, 30), vy = ivy;
    for (const p of [c, top, l, rr]) p.setVelocity(vx, vy, dt);
    // a shove on the hood so it topples convincingly
    top.setVelocity(vx + (ivx >= 0 ? 60 : -60), vy - 20, dt);
    if (G.tripods.filter(t => t.alive).length === 0) G.slow = 0.9;   // last machine of the wave: slow motion
  }
  updateDynamic(dt) {
    this.wreckT += dt; this.impactSoundT -= dt;
    if (this.settled) return;
    const w = this.world;
    w.step(dt);
    for (const p of w.impacts) {
      const big = p === this.pts.c || p === this.pts.top || p === this.pts.l || p === this.pts.rr;
      const n = Math.min(60, p.impact / (big ? 6 : 12));
      sparks(p.x, GROUND, n, { speed: Math.min(420, p.impact * 0.8), life: 0.8, white: 0.5, spread: 2.4 });
      if (big && p.impact > 180) {
        debris(p.x, GROUND, 6, { len: 14, speed: Math.min(400, p.impact * 0.6) }); smoke(p.x, GROUND, 6);
        shake(Math.min(20, p.impact / 30)); flash(0.15);
        if (!this.crushed) { this.crushed = true; Sfx.collapse(); explosion(p.x, GROUND - 10, this.big ? 1.6 : 1.1); G.parts.push({ x: p.x, y: GROUND - 10, vx: 0, vy: 0, life: 0.6, max: 0.6, color: GREEN, grav: 0, size: 20, kind: 'ring' }); floatText(p.x, GROUND - 120, 'COLLAPSED', WHITE, 18, 1.6); }
        else if (this.impactSoundT <= 0) { this.impactSoundT = 0.15; Sfx.crunch(); }
        for (const c of G.civs) if (c.alive && Math.abs(c.x - p.x) < 44 * this.s) killCiv(c, 'crush');
        if (!G.attract && Math.abs(PLAYER_X - p.x) < 50 * this.s) playerHit('crush');
      } else if (p.impact > 120 && this.impactSoundT <= 0) { this.impactSoundT = 0.12; Sfx.spark(); }
    }
    // smouldering wreck
    if (this.crushed && rnd() < dt * 12) { const c = this.pts.c; sparks(c.x + rnd(-this.r, this.r), c.y, 2, { speed: 60, color: AMBER, life: 0.6, grav: -0.1 }); smoke(c.x, c.y, 1, DIMMER); }
    if (this.wreckT > 2.5 && w.energy() < 12) this.settled = true;
    if (this.wreckT > 14) this.gone = true;
  }
  draw() {
    const s = this.s;
    if (this.dynamic) return this.drawDynamic();
    const col = this.hitFlash > 0 ? WHITE : GREEN;
    // legs: rear first so the front leg draws over the hood edge
    for (const i of [2, 1, 0]) {
      const leg = this.legs[i], [hx, hy] = this.hip(i), [kx, ky] = this.knee(i);
      const lc = leg.flash > 0 ? WHITE : leg.hp < leg.max ? (Math.floor(G.t * 20) % 3 ? col : AMBER) : col;
      const lw = (i === 1 ? 2.2 : 3) * s;
      V.poly([[hx, hy], [kx, ky], [leg.footX, leg.footY]], lc, lw);
      V.circle(kx, ky, 4 * s, lc, 1.5);
      V.line(leg.footX - 9 * s, leg.footY, leg.footX + 9 * s, leg.footY, lc, 2 * s);
      if (leg.hp < leg.max && rnd() < 0.3) sparks(lerp(hx, kx, rnd()), lerp(hy, ky, rnd()), 1, { speed: 50, color: AMBER, life: 0.3 });
    }
    this.drawHood(this.x, this.y, 0, col);
  }
  hoodShape(r) {
    const pts = [];
    for (let i = 0; i <= 14; i++) { const a = Math.PI + Math.PI * i / 14; pts.push([Math.cos(a) * r, Math.sin(a) * r * 0.9]); }
    pts.push([r * 1.15, r * 0.2], [r * 1.15, r * 0.38], [-r * 1.15, r * 0.38], [-r * 1.15, r * 0.2], [-r, 0]);
    return pts;
  }
  drawHood(x, y, ang, col, dim = 1) {
    const r = this.r, s = this.s, c = Math.cos(ang), sn = Math.sin(ang);
    const T = (lx, ly) => [x + lx * c - ly * sn, y + lx * sn + ly * c];
    const shape = this.hoodShape(r).map(p => T(p[0], p[1]));
    ctx.globalAlpha = dim;
    V.poly(shape, col, 2.5 * s, true);
    V.poly([T(-r * 1.1, r * 0.1), T(r * 1.1, r * 0.1)], col, 1.5 * s);
    V.poly([T(-r * 0.3, -r * 0.9), T(-r * 0.2, -r * 1.15), T(r * 0.2, -r * 1.15), T(r * 0.3, -r * 0.9)], col, 1.5 * s);  // cowl
    V.poly([T(-r * 0.2, -r * 0.5), T(r * 0.5, -r * 0.5)], col, 1.2 * s);
    V.poly([T(-r * 0.15, -r * 0.3), T(r * 0.55, -r * 0.3)], col, 1.2 * s);
    // the lens of the Heat-Ray
    const [ex, ey] = T(-r * 0.62, -r * 0.1);
    if (this.hoodGlow > 0) {
      ctx.globalAlpha = dim * (0.5 + 0.5 * this.hoodGlow);
      V.circle(ex, ey, r * 0.22 + this.hoodGlow * 3, RED, 3 * s); V.poly(shape, RED, 1.2 * s, true);
      ctx.globalAlpha = dim;
      V.dot(ex, ey, r * 0.1, WHITE);
    } else { V.circle(ex, ey, r * 0.18, col, 1.6 * s); V.dot(ex, ey, r * 0.05, col); }
    // dangling tentacles
    if (!this.dynamic) {
      for (let k = 0; k < 3; k++) {
        const bx = -r * 0.6 + k * r * 0.6, pts = [];
        for (let j = 0; j <= 6; j++) { const u = j / 6; pts.push(T(bx + Math.sin(this.tent * 2.2 + k * 1.7 + u * 3) * 7 * u * s, r * 0.38 + u * 60 * s)); }
        V.poly(pts, col, 1.3 * s);
      }
    }
    ctx.globalAlpha = 1;
  }
  drawDynamic() {
    const { c, top } = this.pts, s = this.s;
    const dim = this.settled ? Math.max(0.25, 1 - (this.wreckT - 2.5) / 6) : 1;
    const col = this.crushed ? (this.settled ? DIM : (Math.floor(G.t * 30) % 2 ? WHITE : GREEN)) : GREEN;
    const ang = Math.atan2(top.y - c.y, top.x - c.x) + Math.PI / 2;
    for (let i = 0; i < 3; i++) {
      const lp = this.legPts[i], leg = this.legs[i];
      ctx.globalAlpha = dim;
      if (leg.broken) { V.line(lp.knee.x, lp.knee.y, lp.foot.x, lp.foot.y, col, 3 * s); if (!this.settled && rnd() < 0.4) sparks(lp.hip.x, lp.hip.y, 1, { speed: 120, color: AMBER, life: 0.4 }); V.line(lp.hip.x, lp.hip.y, lp.hip.x + rnd(-6, 6), lp.hip.y + rnd(0, 10), AMBER, 1.5); }
      else { V.poly([[lp.hip.x, lp.hip.y], [lp.knee.x, lp.knee.y], [lp.foot.x, lp.foot.y]], col, 3 * s); V.circle(lp.knee.x, lp.knee.y, 4 * s, col, 1.5); }
    }
    this.hoodGlow = 0;
    this.drawHood(c.x, c.y, ang, col, dim);
    ctx.globalAlpha = 1;
  }
}

// ---------------------------------------------------------------- the Heat-Ray
function applyBeam(tp) {
  const b = tp.beam, gx = b.gx, prev = b.prev;
  sparks(gx, GROUND, 3, { speed: 220, color: RED, life: 0.5, spread: 1.3, white: 0.4 });
  if (rnd() < 0.4) smoke(gx, GROUND, 1, '#5a1a1a');
  for (const e of G.skyline) if (!e.ruined && e.heat <= 0 && !b.touched.has(e) && overlaps(prev, gx, e.x - e.w * 0.3, e.x + e.w * 0.3)) { b.touched.add(e); if (rnd() < 0.35) igniteBuilding(e); }
  if (G.attract) return;
  if (overlaps(prev, gx, P.x - 26, P.x + 30)) {
    if (!P.duck) playerHit('beam');
    else if (!b.dodged) { b.dodged = true; sparks(P.x + 40, SANDBAG_TOP, 30, { speed: 240, color: RED, life: 0.6, dir: -Math.PI / 2, spread: 2 }); G.score += 50; G.stats.dodged++; floatText(P.x, GROUND - 95, 'DUCKED +50', GREEN, 11); }
  }
  for (const c of G.civs) if (c.alive && c.state !== 'hide' && overlaps(prev, gx, c.x - 6, c.x + 6)) killCiv(c, 'beam');
  for (const cv of G.covers) if (overlaps(prev, gx, cv.x - 22, cv.x + 22)) sparks(cv.x, GROUND - 16, 8, { speed: 160, color: RED, life: 0.4 });
}
function drawBeam(tp) {
  const b = tp.beam, ex = b.ex, ey = b.ey, gx = b.gx, gy = GROUND;
  ctx.globalAlpha = 0.3; V.line(ex, ey, gx, gy, RED, 12 * tp.s);
  ctx.globalAlpha = 0.85; V.line(ex, ey, gx, gy, RED, 4);
  ctx.globalAlpha = 1; V.line(ex, ey, gx, gy, WHITE, 1.5);
  for (let i = 0; i < 6; i++) { const a = -Math.PI / 2 + (rnd() - 0.5) * 2.4, l = rnd(10, 46); V.line(gx, gy, gx + Math.cos(a) * l, gy + Math.sin(a) * l, rnd() < 0.5 ? RED : WHITE, 1.5); }
  V.circle(gx, gy, 6 + rnd(8), WHITE, 1.5);
  V.circle(ex, ey, tp.r * 0.3 + rnd(5), RED, 2);
}
function igniteBuilding(e) { if (e.heat > 0) return; e.heat = 1; e.burnT = 0; Sfx.burn(); }
function clipLines(lines, limit) {
  const out = [];
  for (const L of lines) {
    let cur = [];
    for (let i = 0; i < L.length; i++) {
      const p = L[i], inside = p[1] <= limit;
      if (i > 0) {
        const q = L[i - 1], qin = q[1] <= limit;
        if (inside !== qin) { const t = (limit - q[1]) / (p[1] - q[1]); const ix = [q[0] + (p[0] - q[0]) * t, limit]; if (qin) { cur.push(ix); out.push(cur); cur = []; } else cur.push(ix); }
      }
      if (inside) cur.push(p);
    }
    if (cur.length > 1) out.push(cur);
  }
  return out;
}
function updateSkyline(dt) {
  for (const e of G.skyline) {
    if (e.heat <= 0 || e.ruined) continue;
    e.burnT += dt;
    let maxH = 0; for (const L of e.lines) for (const p of L) maxH = Math.max(maxH, p[1]);
    if (rnd() < 0.7) sparks(e.x + rnd(-e.w / 2, e.w / 2), GROUND - rnd(maxH), 2, { speed: 90, color: rnd() < 0.5 ? RED : AMBER, life: 0.5, grav: 0.3 });
    if (e.burnT > 1.1) {
      e.ruined = true; e.heat = 0;
      const keep = maxH * rnd(0.25, 0.45);
      const ruin = clipLines(e.lines, keep);
      const jag = [[-e.w / 2, keep]];
      for (let x = -e.w / 2; x < e.w / 2; x += 6 + rnd(8)) jag.push([x, keep - rnd(2, 10)]);
      jag.push([e.w / 2, keep]); ruin.push(jag);
      e.lines = ruin; e.anim = null;
      debris(e.x, GROUND - keep, 10, { color: DIM, len: 12 }); smoke(e.x, GROUND - keep, 8); shake(3); Sfx.crunch();
      if (e.name) floatText(e.x, GROUND - keep - 30, e.name + ' FALLS', DIM, 9, 1.6);
    }
  }
}
function drawSkyline() {
  for (const st of G.stars) { ctx.globalAlpha = 0.35 + 0.3 * Math.sin(G.t * 2 + st[0]); V.dot(st[0], st[1], st[2], DIM); }
  ctx.globalAlpha = 0.8; V.circle(W - 150, 70, 6, RED, 1.5); V.dot(W - 150, 70, 3, RED); ctx.globalAlpha = 1;
  for (const e of G.skyline) {
    let col = DIM;
    if (e.heat > 0) col = Math.floor(G.t * 30) % 2 ? RED : WHITE;
    ctx.globalAlpha = e.ruined ? 0.6 : 0.85;
    V.lines(e.lines, e.x, GROUND, col, 1.4);
    if (e.anim) V.lines(e.anim(G.t), e.x, GROUND, col, 1.2);
  }
  ctx.globalAlpha = 1;
}
function drawGround() {
  V.line(0, GROUND, W, GROUND, GREEN, 2);
  for (let x = 20; x < W; x += 48) V.line(x, GROUND + 8, x - 10, GROUND + 18, DIMMER, 1.2);
  // the shelter doorway on the left
  V.poly([[14, GROUND], [14, GROUND - 46], [SHELTER_X + 4, GROUND - 46], [SHELTER_X + 4, GROUND]], GREEN, 2);
  V.poly([[20, GROUND], [20, GROUND - 38], [SHELTER_X - 2, GROUND - 38], [SHELTER_X - 2, GROUND]], DIM, 1.2);
  if (Math.floor(G.t * 2) % 2 === 0 || G.state !== 'play') V.text('SHELTER', 30, GROUND - 62, 8, 'center', GREEN);
  V.poly([[60, GROUND - 56], [48, GROUND - 56], [52, GROUND - 60]], GREEN, 1.2); V.line(48, GROUND - 56, 52, GROUND - 52, GREEN, 1.2);
  for (const cv of G.covers) V.poly(cv.pts, GREEN, 1.6);
}
function makeCovers() {
  G.covers = [430, 650, 870].map(x => {
    const pts = [[x - 30, GROUND]];
    for (let i = 1; i < 6; i++) pts.push([x - 30 + i * 10, GROUND - rnd(8, 18) * (i === 1 || i === 5 ? 0.5 : 1)]);
    pts.push([x + 30, GROUND]);
    return { x, pts };
  });
}

// ---------------------------------------------------------------- rockets
function updateRockets(dt) {
  for (const rk of G.rockets) {
    rk.t += dt;
    const spd = Math.hypot(rk.vx, rk.vy) || 1;
    if (rk.t < 0.7) { rk.vx += rk.vx / spd * 260 * dt; rk.vy += rk.vy / spd * 260 * dt; }
    rk.vy += GRAV * dt; rk.x += rk.vx * dt; rk.y += rk.vy * dt;
    G.parts.push({ x: rk.x, y: rk.y, vx: -rk.vx * 0.1 + rnd(-20, 20), vy: -rk.vy * 0.1 + rnd(-20, 20), life: 0.3, max: 0.3, color: rk.t < 0.7 ? AMBER : DIM, grav: 0, size: 1, kind: 'spark' });
    let hit = false;
    for (const tp of G.tripods) if (!tp.gone && tp.hitTest(rk)) { hit = true; break; }
    if (!hit && rk.y >= GROUND) { explosion(rk.x, GROUND, 0.8); hit = true; }
    if (!hit && (rk.x > W + 60 || rk.x < -60 || rk.y < -300)) hit = true;
    if (hit) rk.alive = false;
  }
  G.rockets = G.rockets.filter(r => r.alive);
}
function drawRockets() {
  for (const rk of G.rockets) {
    const s = Math.hypot(rk.vx, rk.vy) || 1, ux = rk.vx / s, uy = rk.vy / s;
    V.line(rk.x - ux * 10, rk.y - uy * 10, rk.x + ux * 4, rk.y + uy * 4, WHITE, 3);
    V.line(rk.x - ux * 10 - uy * 4, rk.y - uy * 10 + ux * 4, rk.x - ux * 10 + uy * 4, rk.y - uy * 10 - ux * 4, GREEN, 2);
    if (rk.t < 0.7) V.line(rk.x - ux * 10, rk.y - uy * 10, rk.x - ux * (18 + rnd(10)), rk.y - uy * (18 + rnd(10)), AMBER, 2);
  }
}

// ---------------------------------------------------------------- waves and sectors
function waveConfig() {
  if (G.endless) {
    const n = G.wave;
    return { count: 2 + Math.floor(n / 2), speed: 20 + n * 1.5, legHp: 2 + Math.floor(n / 3), cooldown: Math.max(2.4, 6.5 - n * 0.3), siren: Math.max(0.7, 1.4 - n * 0.05), big: n >= 2 && n % 2 === 0, gap: Math.max(2.5, 6 - n * 0.3), civRate: 1 + n * 0.08 };
  }
  const si = G.sectorIdx, wi = G.wave - 1;
  return { count: 2 + wi + Math.floor(si / 4), speed: 15 + si * 1.6 + wi * 2, legHp: 2 + Math.floor(si / 2), cooldown: Math.max(3, 8 - si * 0.5), siren: Math.max(0.8, 1.6 - si * 0.08), big: si >= 2 && wi === WAVES_PER_SECTOR - 1, gap: Math.max(3, 7 - si * 0.4), civRate: 1 };
}
function spawnTripod(cfg, big) {
  const s = big ? 1.3 : rnd(0.92, 1.08);
  G.tripods.push(new Tripod({ x: W + 130 + rnd(100), scale: s, speed: cfg.speed * rnd(0.9, 1.1) * (big ? 0.8 : 1), legHp: cfg.legHp + (big ? 2 : 0), cooldown: cfg.cooldown * (big ? 0.85 : 1), sirenDur: cfg.siren, big }));
}
function resetField() {
  G.tripods = []; G.rockets = []; G.civs = []; G.parts = []; G.debris = []; G.texts = []; G.slow = 0; G.dying = false;
  P.drag = null; P.duckPointer = null; P.reload = 0; P.inv = 0; P.burnT = 0;
}
function startSector(idx) {
  G.sectorIdx = idx;
  const sec = EuroMap.SECTORS[idx];
  G.skyline = Landmarks.build(sec.key, W, idx + 1); makeCovers(); resetField();
  G.wave = 0; G.stats = { saved: 0, lost: 0, destroyed: 0, dodged: 0 }; G.lostSector = null;
  G.state = 'intro'; G.typed = 0; G.t = 0; G.attract = false; Sfx.play('menu');
}
function startWave() {
  G.wave++;
  const cfg = waveConfig();
  G.waveInfo = { toSpawn: cfg.count, timer: 0, total: cfg.count, killed: 0, clearT: 0, cfg, bigLeft: cfg.big ? 1 : 0 };
  G.nextWaveT = 0; G.civTimer = 2;
  G.banner = { text: 'WAVE ' + G.wave, sub: G.endless ? 'ENDLESS - BELFAST' : EuroMap.SECTORS[G.sectorIdx].name + ' - WAVE ' + G.wave + ' OF ' + WAVES_PER_SECTOR, t: 0, dur: 2.4 };
  G.state = 'play'; G.attract = false; Sfx.alarm(); Sfx.play('battle');
  G.battleQuoteT = 12;
}
function onWaveCleared() {
  if (!G.endless && G.wave >= WAVES_PER_SECTOR) { sectorCleared(); return; }
  G.banner = { text: 'WAVE CLEARED', sub: G.endless ? 'SCORE ' + G.score : null, t: 0, dur: 2.4 };
  G.nextWaveT = 2.8; Sfx.fanfare();
  if (G.endless && G.wave % 3 === 0 && G.lives < 6) { G.lives++; floatText(W / 2, 260, 'EXTRA LIFE', AMBER, 14, 2); }
}
function sectorCleared() {
  const bonus = G.stats.saved * 100 + G.lives * 250 + G.stats.dodged * 50;
  G.score += bonus; G.clearBonus = bonus;
  G.save.cleared[G.sectorIdx] = true;
  if (G.save.cleared.every(Boolean)) G.save.campaignDone = true;
  if (G.score > G.save.highCampaign) G.save.highCampaign = G.score;
  persist();
  G.lives = Math.min(6, G.lives + 1);
  G.state = 'cleared'; G.typed = 0; G.stateT = 0; Sfx.cleared(); Sfx.play('map');
}
function beginGameOver() { G.dying = true; G.gameOverT = 2.4; Sfx.stopMusic(); }
function finishGameOver() {
  G.state = 'gameover'; G.stateT = 0; Sfx.gameOver();
  for (const tp of G.tripods) { if (tp.state === 'siren' || tp.state === 'fire') { tp.state = 'walk'; tp.beam = null; tp.hoodGlow = 0; } tp.cool = 1e9; }
  if (G.endless) { if (G.score > G.save.highEndless) G.save.highEndless = G.score; }
  else {
    if (G.score > G.save.highCampaign) G.save.highCampaign = G.score;
    // The Martians retake the last liberated sector.
    let last = -1; for (let i = 0; i < 10; i++) if (G.save.cleared[i]) last = i;
    if (last >= 0 && G.sectorIdx > 0) { G.save.cleared[last] = false; G.lostSector = last; } else G.lostSector = null;
  }
  persist();
}
function startCampaign(fresh) {
  if (fresh) { G.save.cleared = new Array(10).fill(false); persist(); }
  G.endless = false; G.score = 0; G.lives = 4; G.state = 'map'; G.mapAnim = 0; G.lostSector = null; G.attract = false; Sfx.play('map');
}
function nextSectorIdx() { for (let i = 0; i < 10; i++) if (!G.save.cleared[i]) return i; return 9; }
function startEndless() { G.endless = true; G.score = 0; G.lives = 4; startSector(0); }
function enterTitle() {
  G.state = 'title'; G.menuIdx = 0; G.typed = 0; G.attract = true; G.attractT = 0; resetField();
  G.skyline = Landmarks.build('belfast', W, 1); makeCovers(); Sfx.play('menu');
  for (const x of [700, 980]) G.tripods.push(new Tripod({ x, scale: rnd(0.9, 1.15), speed: 26, legHp: 3, cooldown: 6, sirenDur: 1.5, firstCool: rnd(3, 6) }));
}

function updatePlay(dt) {
  const wi = G.waveInfo, cfg = wi.cfg;
  updatePlayer(dt);
  if (!G.dying) {
    wi.timer -= dt;
    if (wi.toSpawn > 0 && wi.timer <= 0) {
      const big = wi.bigLeft > 0 && wi.toSpawn === 1;
      spawnTripod(cfg, big); if (big) wi.bigLeft--;
      wi.toSpawn--; wi.timer = cfg.gap * rnd(0.8, 1.2);
    }
    G.civTimer -= dt * cfg.civRate;
    if (G.civTimer <= 0 && G.civs.filter(c => c.alive).length < 6) {
      G.civTimer = rnd(2.5, 6);
      G.civs.push(new Civ(rnd() < 0.6 ? W + 20 : rnd(380, 900)));
    }
  }
  for (const tp of G.tripods) { tp.update(dt); if (tp.beam) applyBeam(tp); }
  G.tripods = G.tripods.filter(tp => !tp.gone);
  updateRockets(dt);
  for (const c of G.civs) if (c.alive) c.update(dt);
  G.civs = G.civs.filter(c => c.alive);
  updateSkyline(dt); updateEffects(dt);
  if (G.banner) { G.banner.t += dt; if (G.banner.t > G.banner.dur) G.banner = null; }
  if (G.dying) { G.gameOverT -= dt; if (G.gameOverT <= 0) finishGameOver(); return; }
  if (G.nextWaveT > 0) { G.nextWaveT -= dt; if (G.nextWaveT <= 0) startWave(); return; }
  if (wi.toSpawn === 0 && G.tripods.every(tp => !tp.alive)) { wi.clearT += dt; if (wi.clearT > 2.6) { wi.clearT = -1e9; onWaveCleared(); } }
  G.battleQuoteT -= dt;
  if (G.battleQuoteT <= 0) { G.battleQuote = { text: Wells.battle(), t: 7 }; G.battleQuoteT = rnd(22, 35); }
  if (G.battleQuote) { G.battleQuote.t -= dt; if (G.battleQuote.t <= 0) G.battleQuote = null; }
  Sfx.setIntensity(Math.min(1, G.tripods.filter(t => t.alive).length / 3));
}
function updateAttract(dt) {
  G.attractT += dt;
  const alive = G.tripods.filter(tp => tp.alive);
  if (alive.length < 2 && rnd() < dt * 0.5) G.tripods.push(new Tripod({ x: W + 100 + rnd(200), scale: rnd(0.9, 1.2), speed: 24, legHp: 3, cooldown: 6, sirenDur: 1.5 }));
  for (const tp of G.tripods) {
    if (tp.alive && tp.x < 430 && tp.state === 'walk') tp.x = W + 160;
    tp.update(dt); if (tp.beam) applyBeam(tp);
  }
  if (G.attractT > 8 && alive.length >= 2) {
    G.attractT = 0;
    const tp = alive[Math.floor(rnd(alive.length))], i = Math.floor(rnd(3)), [kx, ky] = tp.knee(i);
    tp.legs[i].hp = 1; tp.damageLeg(i, { x: kx, y: ky, vx: 400, vy: -100 });
  }
  G.tripods = G.tripods.filter(tp => !tp.gone);
  for (const e of G.skyline) if (e.ruined) { /* let the title skyline stay ruined: Belfast is burning */ }
  updateSkyline(dt); updateEffects(dt);
}

// ---------------------------------------------------------------- screens
function typewriter(text, x, y, size, maxW, color = GREEN, speed = 38) {
  const n = Math.min(text.length, Math.floor(G.typed * speed));
  const lines = VecFont.wrap(text, size, maxW);
  let left = n, yy = y;
  for (const L of lines) {
    const take = Math.max(0, Math.min(L.length, left));
    V.text(L.slice(0, take) + (take < L.length && left >= 0 && Math.floor(G.t * 8) % 2 ? '_' : ''), x, yy, size, 'center', color);
    left -= L.length + 1; yy += size * 1.7;
    if (left <= 0) break;
  }
  return n >= text.length;
}
function drawTitle() {
  const fl = 0.85 + 0.15 * Math.sin(G.t * 9) * Math.random();
  ctx.globalAlpha = fl;
  V.text('TRIPOD ATTACK!', W / 2 + 2, 42, 46, 'center', DIM, 7);
  V.text('TRIPOD ATTACK!', W / 2, 40, 46, 'center', GREEN, 3.5);
  ctx.globalAlpha = 1;
  V.text('A VECTOR ARCADE GAME AFTER H. G. WELLS', W / 2, 98, 10, 'center', DIM);
  const items = menuItems();
  const y0 = 140;
  items.forEach((it, i) => {
    const sel = i === G.menuIdx, col = it.locked ? DIMMER : sel ? WHITE : GREEN;
    if (sel && Math.floor(G.t * 6) % 2 === 0) { V.poly([[W / 2 - 170, y0 + i * 36 + 2], [W / 2 - 156, y0 + i * 36 + 8], [W / 2 - 170, y0 + i * 36 + 14]], WHITE, 2, true); }
    V.text(it.label, W / 2, y0 + i * 36, 16, 'center', col);
  });
  const hy = y0 + items.length * 36 + 14;
  V.text('HIGH SCORES   CAMPAIGN ' + pad(G.save.highCampaign, 6) + '   ENDLESS ' + pad(G.save.highEndless, 6), W / 2, hy, 9, 'center', DIM);
  const held = G.save.cleared.filter(Boolean).length;
  V.text(G.save.campaignDone ? 'EUROPE IS FREE' : 'SECTORS LIBERATED ' + held + ' / 10', W / 2, hy + 18, 9, 'center', DIM);
  typewriter(Wells.opening, W / 2, hy + 48, 10, 720, GREEN, 30);
  V.text('DRAG BACK AND RELEASE TO FIRE   ARROWS AIM   ENTER FIRE   SPACE DUCK   M MUTE', W / 2, H - 28, 8, 'center', DIM);
}
function menuItems() {
  const has = G.save.cleared.some(Boolean) && !G.save.campaignDone;
  const items = [];
  if (has) { items.push({ label: 'CONTINUE CAMPAIGN', act: () => startCampaign(false) }); items.push({ label: 'NEW CAMPAIGN', act: () => startCampaign(true) }); }
  else items.push({ label: G.save.campaignDone ? 'REPLAY CAMPAIGN' : 'CAMPAIGN', act: () => startCampaign(true) });
  items.push({ label: G.save.campaignDone ? 'ENDLESS: BELFAST' : 'ENDLESS: BELFAST (LOCKED - CLEAR EUROPE)', act: () => startEndless(), locked: !G.save.campaignDone });
  return items;
}
function drawTripodIcon(x, y, s, col) {
  const pts = []; for (let i = 0; i <= 8; i++) { const a = Math.PI + Math.PI * i / 8; pts.push([x + Math.cos(a) * 5 * s, y - 8 * s + Math.sin(a) * 4 * s]); }
  V.poly(pts, col, 1.3, true);
  V.poly([[x - 4 * s, y - 7 * s], [x - 8 * s, y - 2 * s], [x - 7 * s, y]], col, 1.2);
  V.poly([[x, y - 7 * s], [x + 1 * s, y - 2 * s], [x, y]], col, 1.2);
  V.poly([[x + 4 * s, y - 7 * s], [x + 8 * s, y - 2 * s], [x + 7 * s, y]], col, 1.2);
}
function drawMap() {
  const proj = EuroMap.projector(30, 40, 590, 500, [-11, 27, 35, 61]);
  V.text('THE TRIPOD ADVANCE', 325, 16, 14, 'center', GREEN);
  for (const C of EuroMap.COAST) V.poly(C.map(([lo, la]) => proj(lo, la)), DIM, 1.3);
  const S = EuroMap.SECTORS, next = nextSectorIdx();
  for (let i = 0; i < S.length - 1; i++) {
    const a = proj(S[i].lon, S[i].lat), b = proj(S[i + 1].lon, S[i + 1].lat);
    const held = !G.save.cleared[i + 1];
    ctx.setLineDash([4, 6]); V.line(a[0], a[1], b[0], b[1], held ? RED : GREEN, 1.2); ctx.setLineDash([]);
    if (held) for (let k = 0; k < 2; k++) { const u = ((G.mapAnim * 0.05 + k / 2 + i * 0.17) % 1); const x = lerp(b[0], a[0], u), y = lerp(b[1], a[1], u); drawTripodIcon(x, y, 0.75, RED); }
  }
  S.forEach((s, i) => {
    const [x, y] = proj(s.lon, s.lat), cleared = G.save.cleared[i];
    if (cleared) { V.circle(x, y, 7, GREEN, 1.6); V.poly([[x - 3, y], [x - 1, y + 3], [x + 4, y - 3]], GREEN, 1.6); }
    else if (i === next) { const b = Math.floor(G.t * 4) % 2 === 0; V.circle(x, y, 9 + (G.t * 20) % 8, b ? AMBER : WHITE, 1.4); V.line(x - 14, y, x - 6, y, AMBER, 1.2); V.line(x + 6, y, x + 14, y, AMBER, 1.2); V.line(x, y - 14, x, y - 6, AMBER, 1.2); V.line(x, y + 6, x, y + 14, AMBER, 1.2); drawTripodIcon(x, y + 6, 1.1, RED); }
    else drawTripodIcon(x, y + 6, 1.3, RED);
    const right = 'RLRLLRRRLR'[i] === 'R', lx = right ? x + 14 : x - 14, al = right ? 'left' : 'right';
    V.text(s.name, lx, y - 5, 8, al, cleared ? GREEN : i === next ? AMBER : RED);
    if (G.lostSector === i && Math.floor(G.t * 5) % 2 === 0) V.text('RETAKEN', lx, y + 6, 7, al, RED);
  });
  // panel
  const px = 660, py = 50;
  V.poly([[px - 14, py - 14], [W - 24, py - 14], [W - 24, H - 40], [px - 14, H - 40]], DIM, 1.2, true);
  const sec = S[next], held = 10 - G.save.cleared.filter(Boolean).length;
  V.text('SECTOR ' + (next + 1) + ' OF 10', px, py, 12, 'left', DIM);
  V.text(sec.name, px, py + 24, 24, 'left', WHITE);
  VecFont.wrap(sec.blurb, 9, 320).forEach((L, i) => V.text(L, px, py + 62 + i * 15, 9, 'left', GREEN));
  V.text('EUROPE HELD BY MARTIANS: ' + held * 10 + '%', px, py + 110, 9, 'left', RED);
  V.text('TRIPODS SIGHTED: ' + (6 + next * 2 + (next >= 2 ? 1 : 0)), px, py + 126, 9, 'left', RED);
  V.text('SCORE ' + pad(G.score, 6), px, py + 160, 11, 'left', GREEN);
  V.text('LIFE ' + 'I'.repeat(G.lives), px, py + 178, 11, 'left', G.lives <= 1 ? RED : GREEN);
  if (G.lostSector != null) VecFont.wrap('THE MARTIANS HAVE RETAKEN ' + S[G.lostSector].name + '. THE LINE FALLS BACK.', 9, 320).forEach((L, i) => V.text(L, px, py + 210 + i * 15, 9, 'left', Math.floor(G.t * 5) % 2 ? RED : WHITE));
  VecFont.wrap(Wells.sectorIntro(next), 8, 320).forEach((L, i) => V.text(L, px, py + 260 + i * 13, 8, 'left', DIM));
  if (Math.floor(G.t * 2.5) % 2 === 0) V.text('PRESS FIRE TO ADVANCE', px + 160, H - 70, 12, 'center', WHITE);
}
function drawIntro() {
  const sec = EuroMap.SECTORS[G.sectorIdx];
  drawSkyline(); drawGround();
  V.text(G.endless ? 'ENDLESS MODE' : 'SECTOR ' + (G.sectorIdx + 1) + ' OF 10', W / 2, 70, 14, 'center', DIM);
  V.text(sec.name, W / 2, 100, 40, 'center', WHITE, 3);
  V.text(G.endless ? 'HOLD BELFAST FOR AS LONG AS YOU CAN. THEY NEVER STOP.' : sec.blurb, W / 2, 160, 10, 'center', GREEN);
  const done = typewriter(Wells.sectorIntro(G.sectorIdx), W / 2, 220, 12, 820, GREEN, 36);
  V.text('SHOOT THE LEGS.  DUCK THE HEAT-RAY WHEN YOU HEAR THE CRY.  GET THE PEOPLE TO SHELTER.', W / 2, 330, 8, 'center', DIM);
  if (done && Math.floor(G.t * 2.5) % 2 === 0) V.text('PRESS FIRE', W / 2, 380, 14, 'center', WHITE);
}
function drawCleared() {
  const sec = EuroMap.SECTORS[G.sectorIdx];
  V.text('SECTOR CLEARED', W / 2, 60, 34, 'center', WHITE, 3);
  V.text(sec.name + ' IS FREE', W / 2, 110, 14, 'center', GREEN);
  const rows = [['TRIPODS DESTROYED', G.stats.destroyed], ['PEOPLE SAVED', G.stats.saved], ['PEOPLE LOST', G.stats.lost], ['HEAT-RAYS DUCKED', G.stats.dodged], ['SECTOR BONUS', G.clearBonus], ['SCORE', G.score]];
  rows.forEach(([k, v], i) => { V.text(k, W / 2 - 20, 150 + i * 22, 11, 'right', i === 2 ? RED : GREEN); V.text(String(v), W / 2 + 20, 150 + i * 22, 11, 'left', WHITE); });
  typewriter(Wells.sectorCleared(G.sectorIdx), W / 2, 300, 11, 820, DIM, 36);
  if (Math.floor(G.t * 2.5) % 2 === 0) V.text('PRESS FIRE', W / 2, 380, 14, 'center', WHITE);
}
function drawGameOver() {
  V.text('GAME OVER', W / 2, 70, 44, 'center', RED, 3.5);
  typewriter(Wells.gameOver, W / 2, 140, 12, 820, GREEN, 36);
  V.text('SCORE ' + pad(G.score, 6), W / 2, 200, 16, 'center', WHITE);
  const hi = G.endless ? G.save.highEndless : G.save.highCampaign;
  V.text((G.score >= hi && G.score > 0 ? 'NEW HIGH SCORE  ' : 'HIGH SCORE  ') + pad(hi, 6), W / 2, 228, 11, 'center', G.score >= hi && G.score > 0 ? AMBER : DIM);
  if (G.endless) V.text('WAVES SURVIVED ' + (G.wave - 1), W / 2, 250, 11, 'center', GREEN);
  else if (G.lostSector != null) V.text('THE MARTIANS RETAKE ' + EuroMap.SECTORS[G.lostSector].name, W / 2, 250, 11, 'center', RED);
  if (Math.floor(G.t * 2.5) % 2 === 0) V.text('PRESS FIRE', W / 2, 380, 14, 'center', WHITE);
}
function drawVictory() {
  V.text('EUROPE IS FREE', W / 2, 50, 40, 'center', WHITE, 3.5);
  V.text(Wells.victory2, W / 2, 104, 14, 'center', GREEN);
  typewriter(Wells.victory, W / 2, 140, 11, 820, GREEN, 36);
  V.text('SCORE ' + pad(G.score, 6), W / 2, 220, 16, 'center', AMBER);
  V.text('ENDLESS MODE UNLOCKED: BELFAST', W / 2, 260, 12, 'center', Math.floor(G.t * 3) % 2 ? WHITE : GREEN);
  if (Math.floor(G.t * 2.5) % 2 === 0) V.text('PRESS FIRE', W / 2, 380, 14, 'center', WHITE);
}
function drawHUD() {
  V.text('SCORE: ' + pad(G.score, 6), 40, 22, 14, 'left', GREEN);
  V.text('TRIPOD ATTACK!', W / 2, 18, 15, 'center', GREEN);
  V.text(G.endless ? 'WAVE: ' + G.wave : 'WAVE: ' + G.wave + '/' + WAVES_PER_SECTOR, W - 40, 22, 14, 'right', GREEN);
  V.text((G.endless ? 'ENDLESS - ' : 'SECTOR ' + (G.sectorIdx + 1) + ': ') + EuroMap.SECTORS[G.sectorIdx].name, 40, 44, 8, 'left', DIM);
  V.text('SAVED: ' + G.stats.saved + '   LOST: ' + G.stats.lost, W - 40, 44, 8, 'right', DIM);
  const remaining = G.waveInfo.toSpawn + G.tripods.filter(t => t.alive).length;
  const ready = P.reload <= 0 && !P.duck;
  V.text('CANNON: ' + (P.duck ? 'DUCKED' : ready ? 'READY' : 'LOADING'), 60, H - 40, 14, 'left', P.duck ? AMBER : ready ? GREEN : DIM);
  V.text('TRIPODS: ' + remaining, W / 2, H - 40, 14, 'center', GREEN);
  V.text('LIFE: ' + 'I'.repeat(Math.max(0, G.lives)), W - 60, H - 40, 14, 'right', G.lives <= 1 ? (Math.floor(G.t * 4) % 2 ? RED : WHITE) : GREEN);
  if (G.touch) { ctx.setLineDash([6, 6]); V.poly([[12, 250], [226, 250], [226, GROUND + 14], [12, GROUND + 14]], P.duck ? AMBER : DIMMER, 1.2, true); ctx.setLineDash([]); V.text('HOLD TO DUCK', 118, 258, 8, 'center', P.duck ? AMBER : DIMMER); }
  if (G.battleQuote) { ctx.globalAlpha = clamp(Math.min(G.battleQuote.t, 7 - G.battleQuote.t), 0, 1); VecFont.wrap(G.battleQuote.text, 8, 700).forEach((L, i) => V.text(L, W / 2, 62 + i * 13, 8, 'center', DIM)); ctx.globalAlpha = 1; }
  if (G.banner) {
    const b = G.banner, a = clamp(Math.min(b.t * 3, (b.dur - b.t) * 2), 0, 1);
    ctx.globalAlpha = a * (0.8 + 0.2 * Math.sin(G.t * 20));
    V.text(b.text, W / 2, 190, 38, 'center', WHITE, 3);
    if (b.sub) V.text(b.sub, W / 2, 240, 11, 'center', GREEN);
    ctx.globalAlpha = 1;
  }
  if (G.paused) { V.text('PAUSED', W / 2, 200, 34, 'center', WHITE, 3); V.text('P TO RESUME   M TO MUTE', W / 2, 250, 10, 'center', DIM); }
}
function drawBattlefield() {
  drawSkyline(); drawGround();
  const sorted = G.tripods.slice().sort((a, b) => (a.alive ? 1 : 0) - (b.alive ? 1 : 0));
  for (const tp of sorted) tp.draw();
  for (const c of G.civs) c.draw();
  drawPlayer(); drawRockets();
  for (const tp of G.tripods) if (tp.beam) drawBeam(tp);
  drawEffects();
}

// ---------------------------------------------------------------- compositing (the phosphor tube)
function composite() {
  dctx.setTransform(1, 0, 0, 1, 0, 0);
  dctx.globalCompositeOperation = 'source-over'; dctx.globalAlpha = 1; dctx.filter = 'none';
  dctx.fillStyle = '#000'; dctx.fillRect(0, 0, canvas.width, canvas.height);
  pctx.globalCompositeOperation = 'source-over'; pctx.fillStyle = 'rgba(0,0,0,0.38)'; pctx.fillRect(0, 0, W, H);
  pctx.globalCompositeOperation = 'lighter'; pctx.drawImage(scene, 0, 0);
  gctx.clearRect(0, 0, glowC.width, glowC.height); gctx.drawImage(scene, 0, 0, glowC.width, glowC.height);
  dctx.setTransform(view.scale, 0, 0, view.scale, view.ox, view.oy);
  dctx.globalCompositeOperation = 'lighter';
  dctx.globalAlpha = 0.5; dctx.drawImage(phos, 0, 0);
  dctx.globalAlpha = 0.75; dctx.filter = 'blur(3px)'; dctx.drawImage(glowC, 0, 0, W, H); dctx.filter = 'none';
  dctx.globalAlpha = 1; dctx.drawImage(scene, 0, 0);
  dctx.globalCompositeOperation = 'source-over';
  dctx.drawImage(overlay, 0, 0);
  if (G.flash > 0) { dctx.globalAlpha = Math.min(0.8, G.flash); dctx.fillStyle = G.flashColor; dctx.fillRect(0, 0, W, H); dctx.globalAlpha = 1; }
}
function dimScene() { ctx.fillStyle = 'rgba(0,0,0,0.62)'; ctx.fillRect(-40, -40, W + 80, H + 80); }
function draw() {
  ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.globalCompositeOperation = 'source-over'; ctx.globalAlpha = 1;
  ctx.fillStyle = '#000'; ctx.fillRect(0, 0, W, H);
  ctx.lineCap = 'round'; ctx.lineJoin = 'round';
  ctx.save();
  if (G.shake > 0) ctx.translate(rnd(-G.shake, G.shake), rnd(-G.shake, G.shake) * 0.6);
  switch (G.state) {
    case 'title': drawSkyline(); drawGround(); for (const tp of G.tripods) tp.draw(); for (const tp of G.tripods) if (tp.beam) drawBeam(tp); drawEffects(); ctx.fillStyle = 'rgba(0,0,0,0.5)'; ctx.fillRect(-40, -40, W + 80, GROUND - 60); drawTitle(); break;
    case 'map': drawMap(); break;
    case 'intro': drawIntro(); break;
    case 'play': drawBattlefield(); drawHUD(); break;
    case 'cleared': drawBattlefield(); dimScene(); drawCleared(); break;
    case 'gameover': drawBattlefield(); dimScene(); drawGameOver(); break;
    case 'victory': drawBattlefield(); dimScene(); drawVictory(); break;
  }
  ctx.restore();
  composite();
}

// ---------------------------------------------------------------- input
function toLogical(e) {
  const r = canvas.getBoundingClientRect();
  return [(e.clientX - r.left - view.cssOx) / view.cssScale, (e.clientY - r.top - view.cssOy) / view.cssScale];
}
function inDuckZone(x, y) { return x < 226 && y > 250 && y < GROUND + 14; }
function press() {
  Sfx.resume();
  switch (G.state) {
    case 'title': { const it = menuItems()[G.menuIdx]; if (it.locked) { Sfx.blip(); floatText(W / 2, 300, 'CLEAR THE CAMPAIGN FIRST', RED, 10, 1.5); return; } Sfx.select(); it.act(); break; }
    case 'map': Sfx.select(); startSector(nextSectorIdx()); break;
    case 'intro': if (G.typed * 36 < 20) return; Sfx.select(); startWave(); break;
    case 'cleared': if (G.stateT < 0.8) return; Sfx.select(); if (G.save.campaignDone && G.save.cleared.every(Boolean)) { G.state = 'victory'; G.stateT = 0; G.typed = 0; Sfx.victory(); } else { G.state = 'map'; G.mapAnim = 0; } break;
    case 'gameover': if (G.stateT < 1) return; Sfx.select(); enterTitle(); break;
    case 'victory': if (G.stateT < 1) return; Sfx.select(); enterTitle(); break;
  }
}
function menuMove(d) { if (G.state !== 'title') return; const n = menuItems().length; G.menuIdx = (G.menuIdx + d + n) % n; Sfx.blip(); }
canvas.addEventListener('pointerdown', e => {
  Sfx.resume(); e.preventDefault();
  if (e.pointerType === 'touch') G.touch = true;
  const [x, y] = toLogical(e);
  if (G.state === 'title') {
    const items = menuItems(); const i = Math.floor((y - 140 + 10) / 36);
    if (i >= 0 && i < items.length && Math.abs(x - W / 2) < 300) { G.menuIdx = i; press(); } else press();
    return;
  }
  if (G.state !== 'play') { press(); return; }
  if (G.paused) { G.paused = false; return; }
  if (e.button === 2 || inDuckZone(x, y)) { P.duckPointer = e.pointerId; return; }
  if (e.button === 0) P.drag = { sx: x, sy: y, x, y, id: e.pointerId };
});
canvas.addEventListener('pointermove', e => { if (P.drag && P.drag.id === e.pointerId) { const [x, y] = toLogical(e); P.drag.x = x; P.drag.y = y; } });
function pointerEnd(e) {
  if (P.duckPointer === e.pointerId) P.duckPointer = null;
  if (P.drag && P.drag.id === e.pointerId) {
    const d = P.drag; const dx = d.sx - d.x, dy = d.sy - d.y, len = Math.hypot(dx, dy);
    if (len > 12) { P.angle = clamp(Math.atan2(dy, dx), -1.45, 0.12); P.power = clamp(380 + len * 3.6, 380, 1000); }
    P.drag = null;
    if (G.state === 'play' && !G.paused) fireRocket();
  }
}
canvas.addEventListener('pointerup', pointerEnd); canvas.addEventListener('pointercancel', pointerEnd);
canvas.addEventListener('contextmenu', e => e.preventDefault());
const KEYS = { ArrowUp: 'aimUp', KeyW: 'aimUp', ArrowDown: 'aimDown', KeyS: 'aimDown', ArrowLeft: 'powDown', KeyA: 'powDown', ArrowRight: 'powUp', KeyD: 'powUp', Space: 'duck', ShiftLeft: 'duck', ShiftRight: 'duck', KeyX: 'duck', ControlLeft: 'duck' };
window.addEventListener('keydown', e => {
  Sfx.resume();
  if (['Space', 'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'].includes(e.code)) e.preventDefault();
  if (e.repeat) return;
  if (e.code === 'KeyM') { const m = Sfx.toggleMute(); floatText(W / 2, 100, m ? 'SOUND OFF' : 'SOUND ON', DIM, 10); return; }
  if (e.code === 'KeyP' || e.code === 'Escape') { if (G.state === 'play') { G.paused = !G.paused; Sfx.blip(); } return; }
  if (G.state === 'title') {
    if (e.code === 'ArrowUp' || e.code === 'KeyW') menuMove(-1);
    else if (e.code === 'ArrowDown' || e.code === 'KeyS') menuMove(1);
    else if (['Enter', 'NumpadEnter', 'Space', 'KeyZ', 'KeyF'].includes(e.code)) press();
    return;
  }
  if (G.state !== 'play') { if (['Enter', 'NumpadEnter', 'Space', 'KeyZ', 'KeyF'].includes(e.code)) press(); return; }
  if (['Enter', 'NumpadEnter', 'KeyZ', 'KeyF'].includes(e.code)) { if (G.paused) G.paused = false; else fireRocket(); return; }
  const k = KEYS[e.code]; if (k) P.keys[k] = true;
});
window.addEventListener('keyup', e => { const k = KEYS[e.code]; if (k) P.keys[k] = false; });
window.addEventListener('blur', () => { P.keys = {}; P.drag = null; P.duckPointer = null; });

// ---------------------------------------------------------------- main loop
let last = performance.now();
function update(dt) {
  G.t += dt; G.typed += dt; G.stateT = (G.stateT || 0) + dt;
  if (G.typed * 36 < 400 && Math.floor(G.typed * 36) % 2 === 0 && (G.state === 'title' || G.state === 'intro' || G.state === 'cleared' || G.state === 'gameover' || G.state === 'victory')) Sfx.type();
  switch (G.state) {
    case 'title': updateAttract(dt); break;
    case 'map': G.mapAnim += dt; break;
    case 'intro': break;
    case 'play': if (!G.paused) updatePlay(dt); break;
    default: for (const tp of G.tripods) tp.update(dt); updateEffects(dt); updateSkyline(dt); break;
  }
}
function frame(now) {
  let dt = Math.min(0.05, (now - last) / 1000); last = now;
  if (G.slow > 0) { G.slow -= dt; dt *= 0.35; }
  update(dt); draw();
  requestAnimationFrame(frame);
}
enterTitle();
requestAnimationFrame(frame);

// Hooks for automated tests and tinkering from the console.
window.TA = { G, P, Tripod, startCampaign, startSector, startWave, startEndless, fireRocket, press, spawnTripod, waveConfig, update, draw, enterTitle, Sfx, V, VecFont };
})();
