// A small Verlet particle system: particles, distance sticks (optionally with a min/max range)
// and a flat ground with bounce and friction. Used for collapsing fighting-machines and debris.
class VParticle {
  constructor(x, y) { this.x = x; this.y = y; this.px = x; this.py = y; this.r = 2; this.pinned = false; this.impact = 0; this.rest = 0; }
  setVelocity(vx, vy, dt) { this.px = this.x - vx * dt; this.py = this.y - vy * dt; }
}
class VStick {
  constructor(a, b, len, min, max) {
    this.a = a; this.b = b;
    const d = Math.hypot(b.x - a.x, b.y - a.y);
    this.len = len == null ? d : len;
    this.min = min; this.max = max; // when set, the stick only pushes/pulls outside [min, max]
    this.alive = true;
  }
}
class VerletWorld {
  constructor(groundY) {
    this.groundY = groundY; this.particles = []; this.sticks = []; this.gravity = 1100;
    this.damping = 0.995; this.bounce = 0.25; this.friction = 0.55; this.impacts = []; this.dt = 1 / 120; this.acc = 0;
  }
  add(x, y) { const p = new VParticle(x, y); this.particles.push(p); return p; }
  stick(a, b, len, min, max) { const s = new VStick(a, b, len, min, max); this.sticks.push(s); return s; }
  rigid(pts) { for (let i = 0; i < pts.length; i++) for (let j = i + 1; j < pts.length; j++) this.stick(pts[i], pts[j]); }
  attach(p, anchors) { for (const a of anchors) this.stick(p, a); }
  removeStick(s) { s.alive = false; }
  // Advances by `elapsed` seconds in fixed sub-steps. Impacts are collected in this.impacts.
  step(elapsed) {
    this.impacts.length = 0;
    this.acc += Math.min(elapsed, 0.1);
    while (this.acc >= this.dt) { this.integrate(this.dt); this.acc -= this.dt; }
  }
  integrate(dt) {
    const g = this.gravity * dt * dt, gy = this.groundY;
    for (const p of this.particles) {
      if (p.pinned) continue;
      const vx = (p.x - p.px) * this.damping, vy = (p.y - p.py) * this.damping;
      p.px = p.x; p.py = p.y;
      p.x += vx; p.y += vy + g;
      if (p.y > gy) {
        const speed = vy / dt;
        if (speed > 60) { p.impact = speed; this.impacts.push(p); }
        p.y = gy;
        p.py = gy + vy * this.bounce;             // bounce
        p.px = p.x - vx * (1 - this.friction);    // friction
      }
    }
    for (let it = 0; it < 7; it++) {
      for (const s of this.sticks) {
        if (!s.alive) continue;
        const a = s.a, b = s.b;
        let dx = b.x - a.x, dy = b.y - a.y, d = Math.hypot(dx, dy) || 0.0001;
        let target = s.len;
        if (s.min != null) { if (d < s.min) target = s.min; else if (d > s.max) target = s.max; else continue; }
        const diff = (d - target) / d * 0.5;
        const ox = dx * diff, oy = dy * diff;
        if (!a.pinned) { a.x += ox; a.y += oy; }
        if (!b.pinned) { b.x -= ox; b.y -= oy; }
      }
      for (const p of this.particles) if (p.y > gy) p.y = gy;
    }
    this.sticks = this.sticks.filter(s => s.alive);
  }
  // Average speed of all particles, used to decide when a wreck has come to rest.
  energy() {
    let e = 0; for (const p of this.particles) e += Math.hypot(p.x - p.px, p.y - p.py); return this.particles.length ? e / this.particles.length / this.dt : 0;
  }
}
