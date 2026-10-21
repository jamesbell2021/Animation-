// Car Carnage: Belfast Edition - particles, beams, projectiles, screen shake, flashes, slow-mo.
// Everything lives in world units (inches). The renderer applies the camera before drawing.

const TAU = Math.PI * 2;
const rnd = (a, b) => a + Math.random() * (b - a);

export class FX {
  constructor() {
    this.p = []; this.texts = []; this.beams = []; this.rockets = []; this.rings = []; this.flames = [];
    this.shake = 0; this.flashA = 0; this.flashColor = '#fff'; this.chroma = 0; this.slow = 0; this.slowUntil = 0; this.zoomPunch = 0;
    this.heavy = true; this.time = 0;
  }
  clear() { this.p.length = 0; this.texts.length = 0; this.beams.length = 0; this.rockets.length = 0; this.rings.length = 0; this.flames.length = 0; this.shake = 0; this.flashA = 0; this.chroma = 0; }
  add(o) { if (this.p.length < (this.heavy ? 2600 : 900)) this.p.push(o); }

  sparks(x, y, n = 10, color = '#ffd27a', speed = 4) {
    for (let i = 0; i < n; i++) { const a = rnd(0, TAU), s = rnd(0.3, 1) * speed; this.add({ t: 'spark', x, y, vx: Math.cos(a) * s, vy: Math.sin(a) * s, life: rnd(0.15, 0.5), max: 0.5, size: rnd(0.02, 0.05), color, drag: 3 }); }
  }
  smoke(x, y, n = 6, color = 'rgba(70,70,75,0.5)', size = 0.25, vx = 0, vy = 0) {
    for (let i = 0; i < n; i++) { const a = rnd(0, TAU), s = rnd(0.1, 0.5); this.add({ t: 'smoke', x: x + rnd(-0.1, 0.1), y: y + rnd(-0.1, 0.1), vx: Math.cos(a) * s + vx, vy: Math.sin(a) * s + vy - 0.2, life: rnd(0.8, 1.8), max: 1.8, size: size * rnd(0.6, 1.3), color, drag: 1.2, grow: 0.35 }); }
  }
  fire(x, y, n = 4, size = 0.18) {
    for (let i = 0; i < n; i++) { this.add({ t: 'fire', x: x + rnd(-0.12, 0.12), y: y + rnd(-0.12, 0.12), vx: rnd(-0.2, 0.2), vy: rnd(-0.9, -0.3), life: rnd(0.25, 0.6), max: 0.6, size: size * rnd(0.6, 1.4), drag: 1, shrink: true }); }
  }
  debris(x, y, n = 8, color = '#333', speed = 3) {
    for (let i = 0; i < n; i++) { const a = rnd(0, TAU), s = rnd(0.5, 1) * speed; this.add({ t: 'debris', x, y, vx: Math.cos(a) * s, vy: Math.sin(a) * s, vz: rnd(1, 4), z: 0, life: rnd(0.6, 1.4), max: 1.4, size: rnd(0.04, 0.13), color, rot: rnd(0, TAU), vr: rnd(-12, 12), drag: 1.5, grav: 9 }); }
  }
  glow(x, y, size, color, life = 0.3) { this.add({ t: 'glow', x, y, vx: 0, vy: 0, life, max: life, size, color, drag: 0 }); }
  ring(x, y, maxR = 2.5, color = 'rgba(255,220,150,0.9)', width = 0.12, life = 0.5) { this.rings.push({ x, y, r: 0.1, maxR, color, width, life, max: life }); }
  text(x, y, text, color = '#fff', size = 0.5, life = 1.2) {
    // stack texts that land on the same spot so they stay readable
    for (let guard = 0; guard < 6; guard++) { const clash = this.texts.find((t) => Math.abs(t.x - x) < 1.2 && Math.abs(t.y - y) < 0.45 && t.life > t.max * 0.4); if (!clash) break; y = clash.y - 0.5; }
    this.texts.push({ x, y, vy: -0.7, text, color, size, life, max: life });
  }
  beam(x1, y1, x2, y2, color = '#ff3b3b', width = 0.08, life = 0.25, glow = true) { this.beams.push({ x1, y1, x2, y2, color, width, life, max: life, glow }); }
  tracer(x1, y1, x2, y2, color = '#ffe08a', life = 0.12) { this.beams.push({ x1, y1, x2, y2, color, width: 0.04, life, max: life, glow: false, tracer: true }); }
  rocket(x1, y1, x2, y2, speed = 28, onHit) {
    const d = Math.hypot(x2 - x1, y2 - y1); this.rockets.push({ x: x1, y: y1, x1, y1, x2, y2, t: 0, dur: Math.max(0.12, d / speed), onHit, a: Math.atan2(y2 - y1, x2 - x1) });
  }
  muzzle(x, y, angle, big = false) {
    this.glow(x, y, big ? 0.6 : 0.35, big ? 'rgba(255,170,60,0.9)' : 'rgba(255,220,120,0.9)', big ? 0.18 : 0.08);
    this.sparks(x, y, big ? 14 : 5, '#ffd27a', big ? 5 : 3);
    this.smoke(x + Math.cos(angle) * 0.3, y + Math.sin(angle) * 0.3, big ? 5 : 2, 'rgba(120,120,120,0.5)', 0.2, Math.cos(angle) * 0.8, Math.sin(angle) * 0.8);
  }
  explosion(x, y, size = 1, heavy = true) {
    this.glow(x, y, 1.6 * size, 'rgba(255,240,200,1)', 0.12);
    this.glow(x, y, 2.4 * size, 'rgba(255,120,30,0.8)', 0.35);
    this.ring(x, y, 3.2 * size, 'rgba(255,200,120,0.9)', 0.18 * size, 0.55);
    this.ring(x, y, 1.8 * size, 'rgba(255,255,255,0.8)', 0.08, 0.3);
    this.fire(x, y, 22 * size, 0.45 * size);
    this.sparks(x, y, 30 * size, '#ffb347', 7 * size);
    this.debris(x, y, 16 * size, '#2b2b2b', 5 * size);
    this.debris(x, y, 6 * size, '#ff7a1f', 4 * size);
    this.smoke(x, y, 16 * size, 'rgba(30,30,32,0.7)', 0.6 * size);
    this.shakeBy(0.9 * size); this.flash('rgba(255,200,120,1)', 0.5 * Math.min(1, size)); this.chroma = Math.max(this.chroma, 1.0 * size);
    if (heavy) this.slowmo(0.35, 0.8 * size); this.zoomPunch = Math.max(this.zoomPunch, 0.5 * size);
  }
  impact(x, y, dmg = 3, color = '#ffd27a') {
    this.sparks(x, y, 6 + dmg * 2, color, 3 + dmg * 0.4); this.glow(x, y, 0.3 + dmg * 0.05, 'rgba(255,230,170,0.9)', 0.1);
    this.debris(x, y, Math.min(14, dmg), '#444', 2.5); this.shakeBy(0.08 + dmg * 0.02);
  }
  shakeBy(v) { this.shake = Math.min(2.5, this.shake + v); }
  flash(color, a) { this.flashColor = color; this.flashA = Math.max(this.flashA, a); }
  slowmo(factor, seconds) { this.slow = factor; this.slowUntil = this.time + seconds; }
  burning(x, y, heading, size = 1) { this.flames.push({ x, y, heading, size }); }

  update(dt) {
    this.time += dt;
    this.shake *= Math.pow(0.03, dt); if (this.shake < 0.003) this.shake = 0;
    this.flashA = Math.max(0, this.flashA - dt * 2.6);
    this.chroma = Math.max(0, this.chroma - dt * 2.2);
    this.zoomPunch = Math.max(0, this.zoomPunch - dt * 1.8);
    if (this.time > this.slowUntil) this.slow = 0;
    for (let i = this.p.length - 1; i >= 0; i--) {
      const q = this.p[i];
      q.life -= dt;
      if (q.life <= 0) { this.p[i] = this.p[this.p.length - 1]; this.p.pop(); continue; }
      const dr = q.drag ? Math.exp(-q.drag * dt) : 1;
      q.vx *= dr; q.vy *= dr;
      q.x += q.vx * dt; q.y += q.vy * dt;
      if (q.grav) { q.vz -= q.grav * dt; q.z += q.vz * dt; if (q.z < 0) { q.z = 0; q.vz = -q.vz * 0.4; q.vx *= 0.6; q.vy *= 0.6; } }
      if (q.vr) q.rot += q.vr * dt;
      if (q.grow) q.size += q.grow * dt;
      if (q.t === 'ash') { q.x += Math.sin(this.time * 1.3 + q.y) * 0.05 * dt; }
    }
    for (let i = this.texts.length - 1; i >= 0; i--) { const t = this.texts[i]; t.life -= dt; t.y += t.vy * dt; if (t.life <= 0) this.texts.splice(i, 1); }
    for (let i = this.beams.length - 1; i >= 0; i--) { const b = this.beams[i]; b.life -= dt; if (b.life <= 0) this.beams.splice(i, 1); }
    for (let i = this.rings.length - 1; i >= 0; i--) { const r = this.rings[i]; r.life -= dt; r.r = r.maxR * (1 - r.life / r.max); if (r.life <= 0) this.rings.splice(i, 1); }
    for (let i = this.rockets.length - 1; i >= 0; i--) {
      const r = this.rockets[i]; r.t += dt; const f = Math.min(1, r.t / r.dur);
      r.x = r.x1 + (r.x2 - r.x1) * f; r.y = r.y1 + (r.y2 - r.y1) * f;
      this.smoke(r.x, r.y, 1, 'rgba(200,200,200,0.5)', 0.12); this.glow(r.x, r.y, 0.18, 'rgba(255,200,100,0.9)', 0.05);
      if (f >= 1) { this.rockets.splice(i, 1); if (r.onHit) r.onHit(r); }
    }
    this.flames.length = 0;
  }

  // draw in world space (ctx already carries the camera transform; px = pixels per inch for line widths)
  draw(ctx, px, time) {
    ctx.save();
    // rings
    for (const r of this.rings) { ctx.globalAlpha = Math.max(0, r.life / r.max); ctx.strokeStyle = r.color; ctx.lineWidth = r.width; ctx.beginPath(); ctx.arc(r.x, r.y, r.r, 0, TAU); ctx.stroke(); }
    ctx.globalAlpha = 1;
    // particles
    for (const q of this.p) {
      const f = q.life / q.max;
      switch (q.t) {
        case 'spark': ctx.globalAlpha = Math.min(1, f * 1.5); ctx.strokeStyle = q.color; ctx.lineWidth = q.size; ctx.beginPath(); ctx.moveTo(q.x, q.y); ctx.lineTo(q.x - q.vx * 0.04, q.y - q.vy * 0.04); ctx.stroke(); break;
        case 'smoke': ctx.globalAlpha = f * 0.8; ctx.fillStyle = q.color; ctx.beginPath(); ctx.arc(q.x, q.y, q.size, 0, TAU); ctx.fill(); break;
        case 'fire': { ctx.globalAlpha = Math.min(1, f * 1.2); const s = q.shrink ? q.size * (0.3 + f) : q.size; const g = ctx.createRadialGradient(q.x, q.y, 0, q.x, q.y, s); g.addColorStop(0, 'rgba(255,245,200,1)'); g.addColorStop(0.35, f > 0.5 ? 'rgba(255,170,40,0.95)' : 'rgba(255,90,20,0.8)'); g.addColorStop(1, 'rgba(120,20,0,0)'); ctx.fillStyle = g; ctx.beginPath(); ctx.arc(q.x, q.y, s, 0, TAU); ctx.fill(); break; }
        case 'debris': ctx.globalAlpha = Math.min(1, f * 2); ctx.fillStyle = q.color; ctx.save(); ctx.translate(q.x, q.y - (q.z || 0) * 0.3); ctx.rotate(q.rot); ctx.fillRect(-q.size, -q.size * 0.5, q.size * 2, q.size); ctx.restore(); break;
        case 'glow': { ctx.globalAlpha = f; const g = ctx.createRadialGradient(q.x, q.y, 0, q.x, q.y, q.size); g.addColorStop(0, q.color); g.addColorStop(1, 'rgba(255,200,100,0)'); ctx.fillStyle = g; ctx.beginPath(); ctx.arc(q.x, q.y, q.size, 0, TAU); ctx.fill(); break; }
        case 'ash': ctx.globalAlpha = 0.35 * Math.min(1, f * 3); ctx.fillStyle = '#cfc9bd'; ctx.fillRect(q.x, q.y, q.size, q.size); break;
        default: break;
      }
    }
    ctx.globalAlpha = 1;
    // beams and tracers
    ctx.lineCap = 'round';
    for (const b of this.beams) {
      const f = b.life / b.max;
      if (b.tracer) { ctx.globalAlpha = f; ctx.strokeStyle = b.color; ctx.lineWidth = b.width; ctx.beginPath(); ctx.moveTo(b.x1, b.y1); ctx.lineTo(b.x2, b.y2); ctx.stroke(); continue; }
      if (b.glow) { ctx.globalAlpha = f * 0.45; ctx.strokeStyle = b.color; ctx.lineWidth = b.width * 4; ctx.beginPath(); ctx.moveTo(b.x1, b.y1); ctx.lineTo(b.x2, b.y2); ctx.stroke(); }
      ctx.globalAlpha = f; ctx.strokeStyle = b.color; ctx.lineWidth = b.width; ctx.beginPath(); ctx.moveTo(b.x1, b.y1); ctx.lineTo(b.x2, b.y2); ctx.stroke();
      ctx.globalAlpha = f; ctx.strokeStyle = '#fff'; ctx.lineWidth = b.width * 0.35; ctx.beginPath(); ctx.moveTo(b.x1, b.y1); ctx.lineTo(b.x2, b.y2); ctx.stroke();
    }
    ctx.globalAlpha = 1;
    // rockets
    for (const r of this.rockets) { ctx.save(); ctx.translate(r.x, r.y); ctx.rotate(r.a); ctx.fillStyle = '#ddd'; ctx.fillRect(-0.12, -0.04, 0.24, 0.08); ctx.fillStyle = '#ff5c1a'; ctx.fillRect(-0.2, -0.03, 0.08, 0.06); ctx.restore(); }
    // floating text
    for (const t of this.texts) {
      const f = t.life / t.max; ctx.globalAlpha = Math.min(1, f * 2);
      ctx.font = `bold ${t.size}px Impact, "Arial Narrow Bold", sans-serif`; ctx.textAlign = 'center'; ctx.lineWidth = t.size * 0.12; ctx.strokeStyle = '#000'; ctx.fillStyle = t.color;
      ctx.strokeText(t.text, t.x, t.y); ctx.fillText(t.text, t.x, t.y);
    }
    ctx.restore();
  }
}
