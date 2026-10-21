// Car Carnage: Belfast Edition - bot drivers.
// A bot tries a handful of candidate order sets, predicts each with the engine's ghost path,
// and keeps the one that brings its guns to bear without wrapping the car round a lamp post.

import { predictPath, obbCorners, polyOverlap, circleOverlapPoly, shapePoly, pointInShape, dist, normAngle, arcOf, defaultOrders, canFire, phaseMoves } from './engine.js';
import { WEAPONS } from './data.js';

const PERSONALITIES = ['brawler', 'sniper', 'rammer', 'nervous'];

export function botOrders(state, map, v, rngSeed) {
  const rnd = mulberry(rngSeed ^ (v.id * 7777 + state.turn * 131));
  const persona = PERSONALITIES[v.id % PERSONALITIES.length];
  const enemies = state.vehicles.filter((e) => e.id !== v.id && e.status === 'alive');
  const o = defaultOrders();
  o.maxRange = persona === 'sniper' ? 20 : 14;
  if (!enemies.length) return o;
  // the target: nearest, with a preference for anyone already damaged
  let target = null, best = Infinity;
  for (const e of enemies) {
    let d = dist(v.x, v.y, e.x, e.y);
    if (e.damageTaken > 10) d *= 0.8;
    if (e.id === v.lastHitBy) d *= 0.7;
    if (d < best) { best = d; target = e; }
  }
  o.target = target.owner.id;
  o.aimTires = persona === 'sniper' && best < 6 && rnd() < 0.3;
  // drop things on anyone close behind
  const dropWeapons = v.weapons.filter((w) => w.type.startsWith('drop') && w.dp > 0 && w.shots > 0);
  if (dropWeapons.length) {
    const behind = enemies.some((e) => { const a = arcOf(v, e.x, e.y); return (a === 'B' || a === 'L' || a === 'R') && dist(v.x, v.y, e.x, e.y) < 4; });
    if (behind || rnd() < 0.15) {
      const seen = new Set();
      for (const w of dropWeapons) { if (w.link && seen.has(w.link)) continue; if (w.link) seen.add(w.link); o.drops.push({ weaponId: w.id, phase: 1 + Math.floor(rnd() * 2) }); }
    }
  }
  // the weapon we most want to point at them
  const guns = v.weapons.filter((w) => !w.type.startsWith('drop') && w.dp > 0 && w.shots > 0);
  const gunSides = new Set(guns.map((w) => w.side));
  const wantSide = gunSides.has('F') ? 'F' : gunSides.has('T') ? 'any' : gunSides.has('L') || gunSides.has('R') ? 'side' : gunSides.has('B') ? 'B' : 'F';

  const speed = Math.abs(v.speed);
  const cruise = persona === 'rammer' ? 70 : persona === 'nervous' ? 40 : persona === 'sniper' ? 35 : 55;
  const speedOptions = [0];
  if (v.plant.dp > 0 && speed < Math.min(cruise, v.top)) speedOptions.push(v.accel);
  if (speed > 0) speedOptions.push(-5, -10);
  if (speed > cruise + 10) speedOptions.push(-15, -20);
  if (speed > 30) speedOptions.push(-Math.min(45, speed)); // an emergency stop is always on the table
  if (v.speed <= 10 && v.speed >= 0 && v.plant.dp > 0) speedOptions.push(-(v.speed + 5), -(v.speed + 10)); // reverse out of trouble
  if (v.speed < 0) speedOptions.push(-v.speed + 5, -v.speed);
  if (speed === 0 && v.plant.dp <= 0 && guns.length) return o; // sit and shoot
  const candidates = [];
  const toTarget = Math.atan2(target.y - v.y, target.x - v.x);
  const rel = normAngle(toTarget - v.heading);
  // desired heading change depending on which side the guns are on
  let want = rel;
  if (wantSide === 'side') want = normAngle(rel - Math.sign(rel || 1) * Math.PI / 2);
  else if (wantSide === 'B') want = normAngle(rel + Math.PI);
  else if (wantSide === 'any') want = rel * 0.3;
  const wantDeg = Math.round(want * 180 / Math.PI / 15) * 15;
  if (speed >= 20 && speed <= 35 && Math.abs(rel) > 2.4 && wantSide === 'F' && rnd() < 0.5) candidates.push({ ...o, speed: 0, special: { kind: 'bootlegger', phase: 1, dir: rnd() < 0.5 ? -1 : 1 }, steer: [null, null, null, null, null] });
  for (const sp of speedOptions) {
    const newSpeed = Math.max(-v.top / 5, Math.min(v.top, v.speed + sp));
    const moves = phaseMoves(newSpeed);
    const movingPhases = [1, 2, 3, 4, 5].filter((p) => moves[p] >= 1 || (Math.abs(newSpeed) <= 5 && moves[p] > 0));
    const plans = [[null, null, null, null, null]];
    const seq = (deg, perPhase, from = 0) => {
      const st = [null, null, null, null, null];
      let left = deg;
      for (const p of movingPhases.slice(from)) { if (Math.abs(left) < 15) break; const step = Math.sign(left) * Math.min(perPhase, Math.abs(left)); st[p - 1] = { type: 'bend', deg: Math.round(step / 15) * 15 }; left -= step; }
      return st;
    };
    if (Math.abs(wantDeg) >= 15) for (const per of [15, 30, 45]) { plans.push(seq(wantDeg, per)); plans.push(seq(wantDeg, per, 1)); }
    if (Math.abs(wantDeg) >= 30) plans.push(seq(wantDeg / 2, 30));
    for (const d of [-15, 15, -30, 30, -45, 45, -60, 60]) { if (movingPhases.length) { const st = [null, null, null, null, null]; st[movingPhases[0] - 1] = { type: 'bend', deg: d }; plans.push(st); } if (movingPhases.length > 1) { const st = [null, null, null, null, null]; st[movingPhases[1] - 1] = { type: 'bend', deg: d }; plans.push(st); } }
    if (movingPhases.length) { for (const dir of [-1, 1]) { const st = [null, null, null, null, null]; st[movingPhases[0] - 1] = { type: 'drift', dir }; plans.push(st); } }
    for (const st of plans) candidates.push({ ...o, speed: sp, steer: st });
  }
  let bestScore = -Infinity, bestOrders = candidates[0];
  for (const c of candidates) {
    const score = scorePlan(state, map, v, c, target, persona, wantSide, rnd);
    if (score > bestScore) { bestScore = score; bestOrders = c; }
  }
  return bestOrders;
}

function scorePlan(state, map, v, orders, target, persona, wantSide, rnd) {
  const pred = predictPath(v, orders, map);
  let score = 0;
  // risk of losing control
  const riskPenalty = { 0: 0, 2: 2, 3: 6, 4: 14, 5: 25, 6: 40, 7: 80 };
  score -= (riskPenalty[pred.risk] ?? 50) * (persona === 'nervous' ? 2 : persona === 'rammer' ? 0.5 : 1);
  // walls and the arena edge along the path
  const pts = pred.points;
  for (let i = 1; i < pts.length; i++) {
    const p = pts[i];
    const margin = 0.6;
    if (p.x < margin || p.y < margin || p.x > map.width - margin || p.y > map.height - margin) score -= 60 * i;
    const poly = obbCorners(p.x, p.y, p.h, v.len + 0.3, v.wid + 0.2);
    for (const w of state.walls) {
      if (w.breached) continue;
      const hit = w.kind === 'circle' ? circleOverlapPoly(w.x, w.y, w.r, poly) : polyOverlap(poly, shapePoly(w));
      if (hit) score -= (w.dp < 100 && persona === 'rammer' ? 10 : 50) * (6 - i);
    }
    for (const t of map.terrain || []) {
      if (!pointInShape(p.x, p.y, t)) continue;
      if (t.type === 'water' && !v.offroadOk) score -= 300;
      else if (t.type === 'rad') score -= 25;
      else if (t.type === 'offroad' && !v.offroadOk) score -= 6;
      else if (t.type === 'ramp' && Math.abs(pred.speed) >= 20) score += persona === 'nervous' ? -10 : 8;
      else if (t.type === 'debris') score -= 8;
    }
    for (const c of state.counters) {
      if (c.ttl === 0 || c.owner === v.id) continue;
      if (Math.abs(p.x - c.x) < c.w / 2 + 0.3 && Math.abs(p.y - c.y) < c.h / 2 + 0.3) score -= c.type === 'mines' || c.type === 'spearmines' ? 40 : c.type === 'smoke' ? 2 : 15;
    }
    // other cars (predicted to stay roughly put)
    for (const e of state.vehicles) {
      if (e.id === v.id || e.status === 'gone') continue;
      const ex = e.x + Math.cos(e.heading) * (Math.abs(e.speed) / 10) * (i / 5), ey = e.y + Math.sin(e.heading) * (Math.abs(e.speed) / 10) * (i / 5);
      const d = dist(p.x, p.y, ex, ey);
      if (d < 1.2) score -= persona === 'rammer' && e.id === target.id && v.weight > e.weight ? -30 : 35;
    }
  }
  const end = pts[pts.length - 1];
  // the run-out: where a straight line at this speed goes next turn
  const sgn = pred.speed < 0 ? -1 : 1;
  for (const ahead of [1, 2, 3]) {
    if (Math.abs(pred.speed) / 10 < ahead - 0.5) break;
    const px = end.x + Math.cos(end.h) * ahead * sgn, py = end.y + Math.sin(end.h) * ahead * sgn;
    const pen = ahead === 1 ? 30 : ahead === 2 ? 14 : 6;
    if (px < 0.6 || py < 0.6 || px > map.width - 0.6 || py > map.height - 0.6) score -= pen;
    const poly = obbCorners(px, py, end.h, v.len + 0.2, v.wid + 0.1);
    for (const w of state.walls) {
      if (w.breached) continue;
      const hit = w.kind === 'circle' ? circleOverlapPoly(w.x, w.y, w.r, poly) : polyOverlap(poly, shapePoly(w));
      if (hit) { score -= pen; break; }
    }
    for (const t of map.terrain || []) if (t.type === 'water' && !v.offroadOk && pointInShape(px, py, t)) score -= pen * 3;
  }
  const fake = { x: end.x, y: end.y, heading: end.h, len: v.len, wid: v.wid };
  const d = dist(end.x, end.y, target.x, target.y);
  const arc = arcOf(fake, target.x, target.y);
  const inArc = wantSide === 'any' || (wantSide === 'side' ? (arc === 'L' || arc === 'R') : arc === wantSide);
  if (inArc) score += 40;
  const ideal = persona === 'sniper' ? 7 : persona === 'rammer' ? 1 : 4;
  score -= Math.abs(d - ideal) * 4;
  // do not sit in their front arc if we can help it
  const theirArc = arcOf(target, end.x, end.y);
  if (theirArc === 'F' && persona !== 'rammer') score -= 10;
  // speed preferences
  const cruise = persona === 'rammer' ? 70 : persona === 'nervous' ? 40 : persona === 'sniper' ? 35 : 55;
  score -= Math.abs(Math.abs(pred.speed) - Math.min(cruise, v.top)) * 0.4;
  if (Math.abs(pred.speed) < 15) score -= 10;
  if (pred.speed < 0) score -= 6;
  score += rnd() * 3;
  return score;
}

function mulberry(seed) {
  let a = seed >>> 0;
  return () => { a = (a + 0x6d2b79f5) >>> 0; let t = a; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
}
export const BOT_NAMES = ['Big Sadie', 'Wee Davy', 'Mad Dog McCann', 'The Doc', 'Sammy Sparks', 'Rab the Rocket', 'Sharon Shrapnel', 'Dessie Diesel', 'Nuala Napalm', 'Pablo from Poleglass'];
