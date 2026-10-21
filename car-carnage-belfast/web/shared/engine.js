// Car Carnage: Belfast Edition - the rules engine.
// A Car Wars turn is one second in five phases. Every vehicle's orders for the turn are known
// before resolution starts, then all vehicles move at once, tick by tick, and the result is a
// timeline of frames and events that the client plays back in real time.
//
// Units: inches (1" = 15 ft), mph, radians (0 = east, clockwise positive since y points down).

import { BODIES, CHASSIS, SUSPENSIONS, PLANTS, TIRES, TIRE_MODS, WEAPONS, ACCESSORIES, SIDES, damageModifier } from './data.js';

export const TICKS_PER_PHASE = 10;
export const PHASES = 5;
export const TAU = Math.PI * 2;
export const HANDLING_MIN = -6;

// ---------------------------------------------------------------- random numbers
export function makeRng(seed) {
  let a = (seed >>> 0) || 0x9e3779b9;
  const next = () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
  const d = (n = 1) => { let s = 0; for (let i = 0; i < n; i++) s += 1 + Math.floor(next() * 6); return s; };
  return {
    next, d,
    int: (lo, hi) => lo + Math.floor(next() * (hi - lo + 1)),
    pick: (arr) => arr[Math.floor(next() * arr.length)],
    roll: (dice) => rollDice(dice, d),
  };
}

export function parseDice(s) {
  // '2d', '1d-2', '2d+3', '1/2d', '3 hits', '0'
  if (!s || s === '0') return { n: 0, mod: 0, half: false };
  const m = /^(1\/2)?(\d*)d([+-]\d+)?$/.exec(s.trim());
  if (!m) { const h = /^(\d+) hits?$/.exec(s); return h ? { n: 0, mod: +h[1], half: false } : { n: 0, mod: 0, half: false }; }
  return { n: m[2] === '' ? 1 : +m[2], mod: m[3] ? +m[3] : 0, half: !!m[1] };
}
export function rollDice(s, d) {
  const p = parseDice(s);
  let v = p.n ? d(p.n) : 0;
  if (p.half) v = Math.ceil(v / 2);
  return Math.max(0, v + p.mod);
}
export function diceAverage(s) {
  const p = parseDice(s);
  return Math.max(0, (p.half ? 1.75 : 3.5) * p.n + p.mod);
}

// ---------------------------------------------------------------- geometry
export const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
export const lerp = (a, b, t) => a + (b - a) * t;
export function normAngle(a) { a = a % TAU; if (a > Math.PI) a -= TAU; if (a < -Math.PI) a += TAU; return a; }
export const dist = (ax, ay, bx, by) => Math.hypot(bx - ax, by - ay);

export function obbCorners(x, y, h, len, wid) {
  const c = Math.cos(h), s = Math.sin(h), hl = len / 2, hw = wid / 2;
  return [
    [x + c * hl - s * hw, y + s * hl + c * hw],
    [x + c * hl + s * hw, y + s * hl - c * hw],
    [x - c * hl + s * hw, y - s * hl - c * hw],
    [x - c * hl - s * hw, y - s * hl + c * hw],
  ];
}
export function rectCorners(r) { return [[r.x, r.y], [r.x + r.w, r.y], [r.x + r.w, r.y + r.h], [r.x, r.y + r.h]]; }

function projectPoly(pts, nx, ny) {
  let lo = Infinity, hi = -Infinity;
  for (const [x, y] of pts) { const p = x * nx + y * ny; if (p < lo) lo = p; if (p > hi) hi = p; }
  return [lo, hi];
}
// Separating axis test for two convex polygons. Returns the minimum translation to push B out of A
// as {depth, nx, ny} (normal points from A toward B), or null when they do not overlap.
export function polyOverlap(a, b) {
  let best = null;
  for (const poly of [a, b]) {
    for (let i = 0; i < poly.length; i++) {
      const [x1, y1] = poly[i], [x2, y2] = poly[(i + 1) % poly.length];
      let nx = -(y2 - y1), ny = x2 - x1;
      const l = Math.hypot(nx, ny); if (l < 1e-9) continue;
      nx /= l; ny /= l;
      const [a0, a1] = projectPoly(a, nx, ny), [b0, b1] = projectPoly(b, nx, ny);
      const d1 = a1 - b0, d2 = b1 - a0;
      if (d1 <= 0 || d2 <= 0) return null;
      if (d1 < d2) { if (!best || d1 < best.depth) best = { depth: d1, nx, ny }; }
      else { if (!best || d2 < best.depth) best = { depth: d2, nx: -nx, ny: -ny }; }
    }
  }
  return best;
}
export function circleOverlapPoly(cx, cy, r, poly) {
  // closest point on polygon to circle centre (polygon convex)
  let inside = true, bestD = Infinity, bx = 0, by = 0;
  for (let i = 0; i < poly.length; i++) {
    const [x1, y1] = poly[i], [x2, y2] = poly[(i + 1) % poly.length];
    const ex = x2 - x1, ey = y2 - y1, l2 = ex * ex + ey * ey;
    const t = clamp(((cx - x1) * ex + (cy - y1) * ey) / (l2 || 1), 0, 1);
    const px = x1 + ex * t, py = y1 + ey * t;
    const d = Math.hypot(cx - px, cy - py);
    if (d < bestD) { bestD = d; bx = px; by = py; }
    if ((ex * (cy - y1) - ey * (cx - x1)) < 0) inside = false;
  }
  if (inside) return { depth: r + bestD, nx: (bx - cx) / (bestD || 1), ny: (by - cy) / (bestD || 1) };
  if (bestD >= r) return null;
  return { depth: r - bestD, nx: (bx - cx) / (bestD || 1), ny: (by - cy) / (bestD || 1) };
}
export function pointInRect(x, y, r) { return x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h; }
export function pointInShape(x, y, s) {
  if (s.kind === 'circle') return Math.hypot(x - s.x, y - s.y) <= s.r;
  if (s.kind === 'poly') return pointInPoly(x, y, s.pts);
  return pointInRect(x, y, s);
}
export function pointInPoly(x, y, pts) {
  let inside = false;
  for (let i = 0, j = pts.length - 1; i < pts.length; j = i++) {
    const [xi, yi] = pts[i], [xj, yj] = pts[j];
    if (((yi > y) !== (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi)) inside = !inside;
  }
  return inside;
}
// Length of segment inside an axis aligned rect (Liang-Barsky).
export function segmentInRect(x1, y1, x2, y2, r) {
  const dx = x2 - x1, dy = y2 - y1;
  let t0 = 0, t1 = 1;
  const p = [-dx, dx, -dy, dy], q = [x1 - r.x, r.x + r.w - x1, y1 - r.y, r.y + r.h - y1];
  for (let i = 0; i < 4; i++) {
    if (p[i] === 0) { if (q[i] < 0) return 0; continue; }
    const t = q[i] / p[i];
    if (p[i] < 0) { if (t > t1) return 0; if (t > t0) t0 = t; }
    else { if (t < t0) return 0; if (t < t1) t1 = t; }
  }
  return Math.max(0, t1 - t0) * Math.hypot(dx, dy);
}
export function segmentHitsCircle(x1, y1, x2, y2, cx, cy, r) {
  const dx = x2 - x1, dy = y2 - y1, l2 = dx * dx + dy * dy || 1;
  const t = clamp(((cx - x1) * dx + (cy - y1) * dy) / l2, 0, 1);
  return Math.hypot(x1 + dx * t - cx, y1 + dy * t - cy) <= r;
}
export function segmentHitsPoly(x1, y1, x2, y2, poly) {
  if (pointInPoly(x1, y1, poly) || pointInPoly(x2, y2, poly)) return true;
  for (let i = 0; i < poly.length; i++) {
    const [ax, ay] = poly[i], [bx, by] = poly[(i + 1) % poly.length];
    if (segmentsCross(x1, y1, x2, y2, ax, ay, bx, by)) return true;
  }
  return false;
}
function segmentsCross(ax, ay, bx, by, cx, cy, dx, dy) {
  const d = (bx - ax) * (dy - cy) - (by - ay) * (dx - cx);
  if (Math.abs(d) < 1e-12) return false;
  const t = ((cx - ax) * (dy - cy) - (cy - ay) * (dx - cx)) / d;
  const u = ((cx - ax) * (by - ay) - (cy - ay) * (bx - ax)) / d;
  return t >= 0 && t <= 1 && u >= 0 && u <= 1;
}
export function shapePoly(s) {
  if (s.kind === 'circle') { const pts = []; for (let i = 0; i < 12; i++) pts.push([s.x + Math.cos(i / 12 * TAU) * s.r, s.y + Math.sin(i / 12 * TAU) * s.r]); return pts; }
  if (s.kind === 'poly') return s.pts;
  return rectCorners(s);
}

// Which side of a vehicle a world point lies in: F, B, L or R (Car Wars arcs of fire,
// drawn out at 45 degrees from each corner of the counter).
export function arcOf(v, px, py) {
  const c = Math.cos(v.heading), s = Math.sin(v.heading);
  const dx = px - v.x, dy = py - v.y;
  const lx = dx * c + dy * s, ly = -dx * s + dy * c;
  const beyondX = Math.abs(lx) - v.len / 2, beyondY = Math.abs(ly) - v.wid / 2;
  if (beyondX >= beyondY) return lx >= 0 ? 'F' : 'B';
  return ly >= 0 ? 'R' : 'L';
}
export function localPoint(v, px, py) {
  const c = Math.cos(v.heading), s = Math.sin(v.heading);
  const dx = px - v.x, dy = py - v.y;
  return [dx * c + dy * s, -dx * s + dy * c];
}
export function sidePoint(v, side) {
  const c = Math.cos(v.heading), s = Math.sin(v.heading), hl = v.len / 2, hw = v.wid / 2;
  switch (side) {
    case 'F': return [v.x + c * hl, v.y + s * hl];
    case 'B': return [v.x - c * hl, v.y - s * hl];
    case 'L': return [v.x + s * hw, v.y - c * hw];
    case 'R': return [v.x - s * hw, v.y + c * hw];
    default: return [v.x, v.y];
  }
}

// ---------------------------------------------------------------- the movement chart
export function phaseMoves(speed) {
  const s = Math.round(Math.abs(speed) / 5) * 5;
  const inches = s / 10;
  const full = Math.floor(inches), half = s % 10 === 5;
  const base = Math.floor(full / 5), extra = full % 5;
  const pattern = [[], [1], [1, 3], [1, 3, 5], [1, 2, 3, 4]][extra];
  const moves = [0, 0, 0, 0, 0, 0];
  for (let p = 1; p <= 5; p++) moves[p] = base + (pattern.includes(p) ? 1 : 0);
  if (half) { const order = [3, 1, 5, 2, 4]; const p = order.find((q) => !pattern.includes(q)) || 3; moves[p] += 0.5; }
  return moves;
}
export function ramDice(speed) {
  const s = Math.round(Math.abs(speed) / 5) * 5;
  if (s <= 0) return '0';
  if (s === 5) return '1d-4';
  if (s === 10) return '1d-2';
  if (s === 15) return '1d-1';
  if (s <= 30) return '1d';
  return `${s / 5 - 5}d`;
}

// The Control Table. Returns 'safe', a number to roll on 1 die, or 'XX'.
const CONTROL_FIRST = [-5, -4, -3, -2, -1, -1, 0, 0, 0, 0, 1, 1, 1, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 5, 5, 5, 6, 6, 6, 6];
const CRASH_MOD = [-3, -2, -1, 0, 1, 1, 1, 2, 2, 2, 3, 3, 4, 4, 5, 5, 5, 6, 6, 6, 7, 7, 7, 8, 8, 8, 8, 9, 9, 9];
export function speedBand(speed) { return clamp(Math.ceil(Math.abs(speed) / 10) - 1, 0, 29); }
export function controlTable(speed, status) {
  if (Math.abs(speed) < 5) return 'safe';
  const b = speedBand(speed);
  const first = CONTROL_FIRST[b];
  if (status > first) return 'safe';
  const j = first - status;
  const seq = b < 6 ? [2, 3, 4, 5, 6] : b < 12 ? [2, 4, 5, 6] : b < 20 ? [2, 4, 6] : [2, 3, 4, 6];
  return j < seq.length ? seq[j] : 'XX';
}
export function crashModifier(speed) { return Math.abs(speed) < 5 ? -3 : CRASH_MOD[speedBand(speed)]; }

export function decelDifficulty(d) {
  if (d <= 10) return { D: 0, tire: '0' };
  if (d <= 15) return { D: 1, tire: '0' };
  if (d <= 20) return { D: 2, tire: '0' };
  if (d <= 25) return { D: 3, tire: '0' };
  if (d <= 30) return { D: 5, tire: '0' };
  if (d <= 35) return { D: 7, tire: '1' };
  if (d <= 40) return { D: 9, tire: '1d' };
  return { D: 11, tire: '1d+3' };
}
export function bendDifficulty(deg) { return Math.max(1, Math.ceil(Math.abs(deg) / 15)); }

// Temporary speed table, as the fraction of speed kept after a collision.
export function tempSpeedFraction(myDM, otherDM) {
  const r = myDM / (otherDM || 0.01);
  if (r >= 4.5) return 1;
  if (r >= 2) return 0.75;
  if (r >= 1) return 0.5;
  if (r >= 0.4) return 0.25;
  return 0;
}
export const round5 = (s) => Math.round(s / 5) * 5;

// ---------------------------------------------------------------- vehicle construction
export function computeStats(def) {
  // Derives weight, cost, HC, acceleration and top speed from a vehicle definition (garage).
  const body = BODIES[def.body], chassis = CHASSIS[def.chassis || 'standard'], susp = SUSPENSIONS[def.susp || 'light'];
  const plant = PLANTS[def.plant], tire = TIRES[def.tires || 'standard'];
  const kind = body.kind;
  const nTires = kind === 'cycle' ? 2 : kind === 'trike' ? 3 : body.sixWheels ? 6 : 4;
  let weight = body.weight + plant.weight + 150; // driver
  let cost = body.price * (1 + chassis.price) + body.price * susp.price + plant.cost;
  let spaces = plant.spaces + 2; // driver takes two spaces
  let tireDp = tire.dp, tireCost = tire.price, tireWt = tire.weight, hcMod = 0, offroadTires = false;
  for (const m of def.tireMods || []) {
    const tm = TIRE_MODS[m];
    if (tm.dpMult) tireDp = Math.floor(tireDp * tm.dpMult);
    tireCost += tire.price * tm.price; tireWt += tire.weight * (tm.wtMult || 0) + (tm.wtAdd || 0);
    if (tm.dp) tireDp += tm.dp;
    if (tm.hc) hcMod += tm.hc;
    if (tm.offroad) offroadTires = true;
  }
  weight += nTires * (kind === 'cycle' ? tireWt / 2 : tireWt);
  cost += nTires * tireCost;
  let armorMult = 1;
  if (def.fireproof && def.laserReflective) armorMult = 2.5; else if (def.fireproof) armorMult = 2; else if (def.laserReflective) armorMult = 1.1;
  let armorPts = 0;
  for (const s of SIDES) armorPts += def.armor[s] || 0;
  weight += armorPts * body.armorWt * (def.laserReflective ? 1.1 : 1);
  cost += armorPts * body.armorCost * armorMult;
  let turretSpaces = 0;
  for (const a of def.acc || []) {
    const ac = ACCESSORIES[a]; if (!ac) continue;
    if (ac.ramplate) { cost += (def.armor.F || 0) * body.armorCost * 1.5; weight += (def.armor.F || 0) * body.armorWt * 0.5; continue; }
    if (ac.bumperSpikes) { cost += 5 * body.armorCost; weight += 5 * body.armorWt; continue; }
    if (ac.aero) { cost += 25 * body.armorCost; weight += 10 * body.armorWt; continue; }
    if (ac.rollcage) { cost += 150; weight += armorPts ? Math.max(1, Math.round(armorPts / 6)) * 5 : 0; spaces += 1; continue; }
    cost += ac.cost; weight += ac.weight; spaces += ac.spaces;
    if (ac.turret) turretSpaces = ac.turret;
  }
  for (const w of def.weapons) {
    const wd = WEAPONS[w.w];
    cost += wd.cost + wd.cps * wd.shots; weight += wd.weight + (wd.cps ? wd.shots * (wd.type === 'proj' ? 2.5 : 5) : 0);
    if (w.side !== 'T') spaces += wd.spaces;
    if (w.link) cost += 0;
  }
  const links = new Set((def.weapons || []).filter((w) => w.link).map((w) => w.link));
  cost += links.size * 50;
  const hcKey = kind === 'cycle' ? 'cycle' : kind === 'trike' ? 'trike' : body.sixWheels ? 'van' : def.body === 'subcompact' ? 'sub' : 'car';
  let hc = susp.hc[hcKey] + hcMod;
  for (const a of def.acc || []) if (ACCESSORIES[a]?.hc) hc += ACCESSORIES[a].hc;
  const pf = plant.pf;
  const accel = pf >= weight ? 15 : pf >= weight / 2 ? 10 : pf >= weight / 3 ? 5 : 0;
  const top = Math.floor((360 * pf / (pf + weight)) / 2.5) * 2.5;
  const maxLoad = Math.floor(body.maxLoad * (1 + chassis.load));
  return { weight: Math.round(weight), cost: Math.round(cost), hc, accel, top, spaces, maxSpaces: body.spaces, maxLoad, tireDp, nTires, offroad: !!susp.offroad, offroadTires, turretSpaces };
}

export function buildVehicle(def, owner, spawn, idx) {
  const body = BODIES[def.body];
  const stats = computeStats(def);
  const weight = def.weight || stats.weight;
  const tireDp = stats.tireDp;
  const kind = body.kind;
  const tires = [];
  if (kind === 'cycle') tires.push({ pos: 'F', dp: tireDp, max: tireDp }, { pos: 'B', dp: tireDp, max: tireDp });
  else if (kind === 'trike') tires.push({ pos: 'FL', dp: tireDp, max: tireDp }, { pos: 'FR', dp: tireDp, max: tireDp }, { pos: 'B', dp: tireDp, max: tireDp });
  else {
    tires.push({ pos: 'FL', dp: tireDp, max: tireDp }, { pos: 'FR', dp: tireDp, max: tireDp }, { pos: 'BL', dp: tireDp, max: tireDp }, { pos: 'BR', dp: tireDp, max: tireDp });
    if (body.sixWheels) tires.push({ pos: 'ML', dp: tireDp, max: tireDp }, { pos: 'MR', dp: tireDp, max: tireDp });
  }
  const weapons = def.weapons.map((w, i) => {
    const wd = WEAPONS[w.w];
    return { id: i, w: w.w, name: wd.name, side: w.side, link: w.link || 0, dp: wd.dp, max: wd.dp, shots: wd.shots || Infinity, maxShots: wd.shots || Infinity, type: wd.type };
  });
  const acc = {};
  for (const a of def.acc || []) Object.assign(acc, ACCESSORIES[a] || {});
  const hc = def.hc ?? stats.hc;
  const plant = PLANTS[def.plant];
  return {
    id: idx, owner, name: def.name, defId: def.id, color: def.color, body: def.body, kind, style: body.style,
    len: body.len, wid: body.wid,
    x: spawn.x, y: spawn.y, heading: spawn.heading, speed: 0, z: 0, rollAngle: 0,
    armor: { ...def.armor }, armorMax: { ...def.armor }, fireproof: !!def.fireproof, laserReflective: !!def.laserReflective,
    tires, plant: { dp: plant.dp, max: plant.dp }, driver: { dp: 3, max: 3, skill: owner.skill || 0, reflex: 0 },
    weapons, acc, turret: stats.turretSpaces > 0 || def.weapons.some((w) => w.side === 'T'), turretAngle: 0,
    hc, hcBase: hc, hcOffroad: def.hcOffroad ?? (stats.offroad ? hc : Math.max(0, hc - 3)), handling: hc,
    accel: def.accel ?? stats.accel, top: def.top ?? stats.top, weight, dm: damageModifier(weight),
    offroadOk: stats.offroad, abs: !!acc.abs, wheelguards: acc.wheelguards || 0, ramplate: !!acc.ramplate, bumperSpikes: !!acc.bumperSpikes,
    extinguisher: acc.extinguish || 0, toHitBonus: acc.toHit || 0, rollcage: !!acc.rollcage, safetyseat: !!acc.safetyseat, aero: 0,
    control: { kind: 'ok' }, pendingCrash: null, moves: phaseMoves(0),
    fire: { burning: false, pending: [], turnsBurning: 0 },
    air: null, onCounters: {}, touchedCounters: {}, firedThisTurn: {}, sustained: {},
    status: 'alive', deathReason: null, killedBy: null, kills: 0, damageDealt: 0, damageTaken: 0, lastHitBy: null,
    accelerated: false, paintTurns: 0, moveDir: spawn.heading, phaseStartHeading: spawn.heading, skid: null, wasOffroad: false,
  };
}

export function vehicleAlive(v) { return v.status === 'alive'; }
export function workingTires(v) { return v.tires.filter((t) => t.dp > 0).length; }
export function hasWeapons(v) { return v.weapons.some((w) => w.dp > 0 && w.shots > 0); }
export function currentHC(v) {
  let hc = v.wasOffroad ? v.hcOffroad : v.hcBase;
  const lostWheels = v.tires.filter((t) => t.dp <= 0).length;
  if (lostWheels) hc -= 2 * lostWheels;
  hc += v.driver.reflex;
  if (v.aeroAt60 && Math.abs(v.speed) >= 60) hc += 1;
  return clamp(hc, -3, 6);
}

// ---------------------------------------------------------------- orders
export function defaultOrders() {
  return { speed: 0, steer: [null, null, null, null, null], special: null, target: null, aimTires: false, weapons: null, drops: [], maxRange: 16 };
}
// steer entries: {type:'bend', deg: +/-15..90} | {type:'drift', dir: -1|1} | {type:'swerve', deg} | null

export function steerDifficulty(st, v, onOil) {
  if (!st) return 0;
  let D = 0;
  if (st.type === 'bend') D = bendDifficulty(st.deg);
  else if (st.type === 'drift') D = st.steep ? 3 : 1;
  else if (st.type === 'swerve') D = bendDifficulty(st.deg) + 1;
  if (v && v.wasOffroad) D += 1;
  if (onOil) D += 2;
  if (v && v.speed < 0) D += 1;
  return D;
}

// ---------------------------------------------------------------- match state
export function createMatch(map, players, options, seed) {
  const vehicles = players.map((p, i) => {
    const spawn = map.spawns[i % map.spawns.length];
    const v = buildVehicle(p.def, { id: p.id, name: p.name, color: p.color, bot: !!p.bot, skill: p.skill || 0 }, spawn, i);
    v.speed = options.startSpeed || 0;
    v.moves = phaseMoves(v.speed);
    v.moveDir = v.heading;
    v.aeroAt60 = (p.def.acc || []).includes('spoiler') && (p.def.acc || []).includes('airdam');
    return v;
  });
  const rng = makeRng(seed);
  for (const v of vehicles) { const r = rng.d(); v.driver.reflex = r === 5 ? 1 : r === 6 ? 2 : 0; v.handling = currentHC(v); }
  const walls = map.walls.map((w, i) => ({ ...w, id: i, dp: w.dp ?? 9999, maxDp: w.dp ?? 9999, dm: w.dm ?? 20, breached: false }));
  return { turn: 1, mapId: map.id, width: map.width, height: map.height, options: { ...options }, seed, vehicles, walls, counters: [], nextCounter: 1, over: false, winner: null, standings: null };
}

// ---------------------------------------------------------------- turn resolution
export function resolveTurn(state, ordersById, map) {
  const rng = makeRng((state.seed * 7919 + state.turn * 104729) >>> 0);
  const tl = { turn: state.turn, frames: [], events: [] };
  const V = state.vehicles;
  let tick = 0;
  const ev = (type, data) => tl.events.push({ t: tick, type, ...data });
  const orders = {};
  for (const v of V) orders[v.id] = normalizeOrders(ordersById[v.owner.id] || ordersById[v.id] || defaultOrders());

  const frame = () => {
    tl.frames.push(V.map((v) => [+v.x.toFixed(3), +v.y.toFixed(3), +v.heading.toFixed(4), v.speed, +v.z.toFixed(3), +v.rollAngle.toFixed(3), flagsOf(v), +v.turretAngle.toFixed(3)]));
  };

  // --- turn start: speed changes, spin recovery
  for (const v of V) {
    v.firedThisTurn = {};
    v.touchedCountersTurn = {};
    v.maneuveredPhase = 0;
    if (v.status !== 'alive') continue;
    if (v.control.kind === 'spin') {
      // try to regain control at HC -6
      if (rng.d() >= 5) { v.control = { kind: 'ok' }; v.moveDir = v.heading; ev('text', { id: v.id, text: 'Regains control!' }); }
    }
    if (!controllable(v)) continue;
    const o = orders[v.id];
    applySpeedOrder(v, o, rng, ev);
  }
  frame();

  for (let phase = 1; phase <= PHASES; phase++) {
    // announce maneuvers and apply pending crash results
    for (const v of V) {
      if (v.status === 'wreck' || v.status === 'gone') continue;
      v.phaseStartHeading = v.heading;
      v.steer = null; v.special = null;
      if (v.pendingCrash) { beginCrash(v, v.pendingCrash, rng, ev); v.pendingCrash = null; }
      if (!controllable(v) || v.air) continue;
      const o = orders[v.id];
      const move = v.moves[phase];
      if (move < 1 && !(Math.abs(v.speed) <= 5 && move > 0)) continue; // no maneuver on a half move
      if (v.skid) continue; // skidding: must go straight
      let st = o.steer[phase - 1];
      const special = o.special && o.special.phase === phase ? o.special : null;
      if (special) st = null;
      if (st && st.type === 'bend' && Math.abs(v.speed) <= 5) { v.steer = { type: 'pivot', deg: st.deg }; continue; }
      let D = steerDifficulty(st, v, isOnCounter(v, 'oil') || isOnCounter(v, 'flamingoil'));
      if (special) {
        if (special.kind === 'bootlegger' && Math.abs(v.speed) >= 20 && Math.abs(v.speed) <= 35) { D = 7; v.special = { kind: 'bootlegger', dir: special.dir || 1 }; }
        else if (special.kind === 'tstop' && Math.abs(v.speed) >= 20 && Math.abs(v.speed) <= 35) { D = Math.ceil(Math.abs(v.speed) / 10); v.special = { kind: 'tstop', dir: special.dir || 1 }; }
        else continue;
      }
      if (!st && !special) continue;
      v.steer = st;
      if (D > 0) {
        v.maneuveredPhase = phase; v.maneuverD = D;
        v.handling = Math.max(HANDLING_MIN, v.handling - D);
        ev('maneuver', { id: v.id, phase, D, text: describeSteer(v.special || st) });
        controlCheck(v, D, 'maneuver', rng, ev);
      }
      if (v.special?.kind === 'bootlegger') { for (const t of v.tires) tireDamage(v, t, 1, ev); }
    }
    // dropped weapons for this phase
    for (const v of V) {
      if (!controllable(v) || v.air) continue;
      const o = orders[v.id];
      for (const d of o.drops) if (d.phase === phase) dropWeapon(state, v, d.weaponId, rng, ev);
    }
    // movement ticks
    for (let k = 0; k < TICKS_PER_PHASE; k++) {
      tick++;
      for (const v of V) moveTick(state, map, v, phase, k, rng, ev);
      for (const v of V) terrainCheck(state, map, v, phase, rng, ev);
      resolveCollisions(state, map, phase, rng, ev);
      frame();
    }
    // end of phase: land jumps that finished this phase handled in moveTick; combat
    for (const v of V) if (v.air === null && v.landedThisPhase) { v.landedThisPhase = false; }
    combatPhase(state, map, phase, orders, rng, ev);
    for (const v of V) checkDeath(state, v, rng, ev);
  }

  // --- end of turn
  for (const v of V) {
    if (v.status === 'gone') continue;
    endOfTurn(state, map, v, rng, ev);
    checkDeath(state, v, rng, ev);
  }
  for (const c of state.counters) if (c.ttl > 0) c.ttl--;
  state.counters = state.counters.filter((c) => c.ttl !== 0);
  frame();
  tl.ticks = tick;
  state.turn++;
  checkMatchEnd(state, ev);
  return tl;
}

function flagsOf(v) {
  let f = 0;
  if (v.fire.burning) f |= 1;
  if (v.status !== 'alive') f |= 2;
  if (v.skid) f |= 4;
  if (v.air) f |= 8;
  if (v.control.kind === 'spin') f |= 16;
  if (v.control.kind === 'roll') f |= 32;
  if (v.status === 'gone') f |= 64;
  if (v.paintTurns > 0) f |= 128;
  return f;
}

export function normalizeOrders(o) {
  const d = defaultOrders();
  const n = { ...d, ...(o || {}) };
  n.steer = Array.from({ length: 5 }, (_, i) => (n.steer && n.steer[i]) || null);
  n.drops = Array.isArray(n.drops) ? n.drops : [];
  return n;
}
export function controllable(v) {
  return v.status === 'alive' && v.driver.dp >= 2 && v.control.kind === 'ok';
}
function describeSteer(st) {
  if (!st) return 'straight';
  if (st.kind === 'bootlegger') return 'Bootlegger reverse!';
  if (st.kind === 'tstop') return 'T-stop!';
  if (st.type === 'bend') return `${Math.abs(st.deg)}° bend ${st.deg < 0 ? 'left' : 'right'}`;
  if (st.type === 'drift') return `${st.steep ? 'steep ' : ''}drift ${st.dir < 0 ? 'left' : 'right'}`;
  if (st.type === 'swerve') return `swerve ${st.deg < 0 ? 'left' : 'right'}`;
  return 'maneuver';
}

function applySpeedOrder(v, o, rng, ev) {
  let delta = o.speed || 0;
  if (v.plant.dp <= 0 && delta > 0) delta = 0;
  const maxRev = -Math.floor(v.top / 5 / 5) * 5;
  const target = clamp(v.speed + delta, maxRev, v.top);
  delta = target - v.speed;
  if (delta > 0) { delta = Math.min(delta, v.accel); if (v.speed < 0 && target > 0) delta = -v.speed; }
  if ((v.speed > 0 && v.speed + delta < 0) || (v.speed < 0 && v.speed + delta > 0)) delta = -v.speed;
  if (delta < 0) {
    let d = -delta;
    if (d > 45) { d = 45; delta = -45; }
    let { D, tire } = decelDifficulty(d);
    if (v.abs) { D = Math.max(0, D - 1); tire = '0'; }
    if (D > 0) {
      v.handling = Math.max(HANDLING_MIN, v.handling - D);
      ev('maneuver', { id: v.id, phase: 1, D, text: `Hard braking ${d} mph` });
      controlCheck(v, D, 'maneuver', rng, ev);
      if (tire !== '0') for (const t of v.tires) tireDamage(v, t, rng.roll(tire), ev);
    }
  }
  if (v.plant.dp <= 0 && delta >= 0) delta = Math.max(-5, -Math.abs(v.speed)); // dead plant coasts down
  v.speed = round5(v.speed + delta);
  v.moves = phaseMoves(v.speed);
  if (delta !== 0) ev('speed', { id: v.id, speed: v.speed, delta });
}

// A control roll after a maneuver or hazard. Returns true if control is kept.
export function controlCheck(v, D, kind, rng, ev) {
  if (v.status !== 'alive') return true;
  v.handling = Math.max(HANDLING_MIN, v.handling);
  const res = controlTable(v.speed, v.handling);
  if (res === 'safe') return true;
  let keep = false, roll = 0;
  if (res !== 'XX') { roll = rng.d() + v.driver.skill; keep = roll >= res; }
  ev('control', { id: v.id, need: res, roll, keep, handling: v.handling });
  if (keep) return true;
  const crash = kind === 'maneuver' ? crashTable1(v, D, rng) : crashTable2(v, D, rng);
  v.pendingCrash = crash;
  ev('crash', { id: v.id, kind: crash.kind, text: crash.text, table: kind === 'maneuver' ? 1 : 2 });
  return false;
}

export function crashTable1(v, D, rng) {
  const roll = rng.d(2) + (D - 3) + crashModifier(v.speed) - v.driver.skill;
  const dir = rng.d() <= 3 ? -1 : 1;
  if (roll <= 2) return { kind: 'skid', dist: 0.25, loss: 0, tire: 0, text: 'Trivial skid', fire: -3 };
  if (roll <= 4) return { kind: 'skid', dist: 0.5, loss: 5, tire: 0, text: 'Minor skid', fire: -6 };
  if (roll <= 6) return { kind: 'skid', dist: 0.75, loss: 10, tire: 1, text: 'Moderate skid', fire: -6 };
  if (roll <= 8) return { kind: 'skid', dist: 1, loss: 20, tire: 2, text: 'Severe skid', fire: 'none' };
  if (roll <= 10) return { kind: 'spin', dir, text: 'SPINOUT!' };
  if (roll <= 12) return { kind: 'roll', dir, text: 'ROLLS!' };
  if (roll <= 14) return { kind: 'roll', dir, burn: true, text: 'ROLLS AND BURNS!' };
  return { kind: 'vault', dir, dist: rng.d(), text: 'VAULTS INTO THE AIR!' };
}
export function crashTable2(v, D, rng) {
  const roll = rng.d(2) + (D - 3) + crashModifier(v.speed) - v.driver.skill;
  const dir = rng.d() <= 3 ? -1 : 1;
  if (roll <= 4) return { kind: 'fishtail', deg: 15 * dir, text: 'Minor fishtail' };
  if (roll <= 8) return { kind: 'fishtail', deg: 30 * dir, text: 'Major fishtail' };
  if (roll <= 10) return { kind: 'fishtail', deg: 15 * dir, then: crashTable1(v, D, rng), text: 'Minor fishtail and skid' };
  if (roll <= 14) return { kind: 'fishtail', deg: 30 * dir, then: crashTable1(v, D, rng), text: 'Major fishtail and skid' };
  return { kind: 'fishtail', deg: 45 * dir, then: crashTable1(v, D, rng), text: 'Wild fishtail!' };
}

function beginCrash(v, crash, rng, ev) {
  if (v.status !== 'alive') return;
  if (crash.kind === 'fishtail') {
    v.heading = normAngle(v.heading + crash.deg * Math.PI / 180);
    v.moveDir = v.heading;
    ev('fishtail', { id: v.id, deg: crash.deg, text: crash.text });
    if (crash.then) beginCrash(v, crash.then, rng, ev);
    return;
  }
  if (crash.kind === 'skid') {
    v.skid = { dir: v.moveDir, remaining: crash.dist };
    v.speed = round5(Math.max(0, Math.abs(v.speed) - crash.loss) * Math.sign(v.speed || 1)); v.moves = phaseMoves(v.speed);
    if (crash.tire) for (const t of v.tires) tireDamage(v, t, crash.tire, ev);
    ev('skid', { id: v.id, text: crash.text, dist: crash.dist });
    return;
  }
  if (crash.kind === 'spin') {
    v.control = { kind: 'spin', dir: crash.dir, phaseRot: 0 };
    v.moveDir = v.moveDir ?? v.heading;
    for (const t of v.tires) tireDamage(v, t, rng.d(), ev);
    ev('spin', { id: v.id, text: crash.text });
    return;
  }
  if (crash.kind === 'roll' || crash.kind === 'vault') {
    v.control = { kind: 'roll', dir: crash.dir, quarter: 0, phases: 0 };
    v.moveDir = v.moveDir ?? v.heading;
    v.driver.dp -= 1;
    if (crash.burn) startFire(v, ev, 'rolled and caught fire');
    if (crash.kind === 'vault') {
      v.air = { total: crash.dist, remaining: crash.dist, height: 1, vault: true };
      v.vaultDamage = true;
      ev('vault', { id: v.id, text: crash.text, dist: crash.dist });
    } else ev('roll', { id: v.id, text: crash.text });
    return;
  }
}

// ---------------------------------------------------------------- movement
function moveTick(state, map, v, phase, k, rng, ev) {
  if (v.status === 'gone') return;
  const move = v.moves[phase];
  const d = move / TICKS_PER_PHASE;
  if (v.status === 'wreck') {
    if (d > 0) { v.x += Math.cos(v.moveDir) * d; v.y += Math.sin(v.moveDir) * d; if (v.control.kind === 'roll') v.rollAngle += 0.1; }
    return;
  }
  const T = TICKS_PER_PHASE;
  const sgn = v.speed < 0 ? -1 : 1;
  if (v.air) {
    // flying: straight, at speed, with a height arc
    const step = v.air.total > 0 ? Math.max(d, 0.02) : d;
    v.x += Math.cos(v.moveDir) * step * sgn; v.y += Math.sin(v.moveDir) * step * sgn;
    v.air.remaining -= step;
    const f = 1 - Math.max(0, v.air.remaining) / (v.air.total || 1);
    v.z = Math.sin(f * Math.PI) * (v.air.height || 0.8);
    if (v.air.vault) v.rollAngle += 0.35 * v.control.dir;
    if (v.air.remaining <= 0) land(state, map, v, rng, ev);
    return;
  }
  if (d <= 0) return;
  if (v.control.kind === 'spin') {
    v.heading = normAngle(v.heading + (Math.PI / 2 / T) * v.control.dir);
    v.x += Math.cos(v.moveDir) * d; v.y += Math.sin(v.moveDir) * d;
    if (k === T - 1) { v.control.phaseRot++; }
    return;
  }
  if (v.control.kind === 'roll') {
    const step = Math.max(d, 1 / T);
    v.x += Math.cos(v.moveDir) * step; v.y += Math.sin(v.moveDir) * step;
    v.rollAngle += (Math.PI / 2 / T) * v.control.dir;
    if (k === T - 1) {
      v.control.quarter++; v.control.phases++;
      const sides = v.control.dir > 0 ? ['R', 'T', 'L', 'U'] : ['L', 'T', 'R', 'U'];
      const side = sides[(v.control.quarter - 1) % 4];
      applyDamage(state, v, side, rng.d(), null, rng, ev, 'rolling');
      if (side === 'U') for (const t of v.tires) tireDamage(v, t, rng.d(), ev);
      ev('rollhit', { id: v.id, side });
    }
    return;
  }
  // skids: slide in the old direction first
  if (v.skid && v.skid.remaining > 0) {
    const s = Math.min(d, v.skid.remaining);
    v.x += Math.cos(v.skid.dir) * s; v.y += Math.sin(v.skid.dir) * s;
    v.skid.remaining -= s;
    const rest = d - s;
    if (rest > 0) { v.x += Math.cos(v.heading) * rest * sgn; v.y += Math.sin(v.heading) * rest * sgn; }
    if (v.skid.remaining <= 0.0001) v.skid = null;
    v.moveDir = v.heading;
    return;
  }
  const st = v.steer, sp = v.special;
  if (sp && sp.kind === 'bootlegger') {
    // slide 1" in the original direction while the car swings round 180 degrees; ends stopped
    v.heading = normAngle(v.heading + (Math.PI / T) * sp.dir);
    v.x += Math.cos(v.moveDir) * d; v.y += Math.sin(v.moveDir) * d;
    if (k === T - 1) { v.speed = 0; v.moves = phaseMoves(0); v.moveDir = v.heading; ev('text', { id: v.id, text: 'Bootlegger!' }); }
    return;
  }
  if (sp && sp.kind === 'tstop') {
    v.heading = normAngle(v.heading + (Math.PI / 2 / T) * sp.dir);
    v.x += Math.cos(v.moveDir) * d; v.y += Math.sin(v.moveDir) * d;
    if (k === T - 1) { v.speed = round5(Math.max(0, v.speed - 20)); v.moves = phaseMoves(v.speed); for (const t of v.tires) tireDamage(v, t, 1, ev); if (v.speed === 0) v.moveDir = v.heading; }
    return;
  }
  if (st) {
    if (st.type === 'bend' || st.type === 'pivot' || st.type === 'swerve') {
      const deg = st.type === 'swerve' ? -st.deg : st.deg;
      v.heading = normAngle(v.heading + (deg * Math.PI / 180) / T);
    }
    if (st.type === 'drift' || st.type === 'swerve') {
      const dir = st.type === 'swerve' ? Math.sign(st.deg) : st.dir;
      const lat = (st.steep ? 0.5 : 0.25) / T * dir;
      v.x += -Math.sin(v.heading) * lat; v.y += Math.cos(v.heading) * lat;
    }
  }
  v.x += Math.cos(v.heading) * d * sgn; v.y += Math.sin(v.heading) * d * sgn;
  v.moveDir = v.speed < 0 ? normAngle(v.heading + Math.PI) : v.heading;
}

function land(state, map, v, rng, ev) {
  const total = v.air.total; const vault = v.air.vault;
  v.air = null; v.z = 0;
  if (vault) {
    applyDamage(state, v, rng.d() <= 3 ? 'L' : 'R', rng.d(3), null, rng, ev, 'vault landing');
    ev('land', { id: v.id, text: 'CRASHES DOWN' });
    return;
  }
  // landing hazard: D1 + D1 per full 2" of flight
  const D = 1 + Math.floor(total / 2);
  ev('land', { id: v.id, text: `Lands (D${D})` });
  v.handling = Math.max(HANDLING_MIN, v.handling - D);
  controlCheck(v, D, 'hazard', rng, ev);
  // landing in water or on a building
  for (const t of map.terrain || []) if (t.type === 'water' && pointInShape(v.x, v.y, t) && !v.offroadOk) { kill(state, v, 'drowned in the Lagan', null, ev); }
}

function terrainCheck(state, map, v, phase, rng, ev) {
  if (v.status !== 'alive' || v.air) return;
  let offroad = false, road = false, water = false;
  for (const t of map.terrain || []) {
    if (!pointInShape(v.x, v.y, t)) continue;
    if (t.type === 'offroad' || t.type === 'rubble') offroad = true;
    else if (t.type === 'road') road = true;
    else if (t.type === 'water') {
      if (v.offroadOk && (t.depth || 1) <= 1.5) { water = true; if (!v.inWater) { v.speed = round5(Math.max(0, Math.abs(v.speed) - 10)) * (v.speed < 0 ? -1 : 1); v.moves = phaseMoves(v.speed); ev('hazard', { id: v.id, kind: 'water', text: 'Splash!' }); } }
      else { kill(state, v, 'drowned', null, ev); return; }
    } else if (t.type === 'rad') {
      if (!v.touchedCountersTurn['rad' + (t.id || 0)]) {
        v.touchedCountersTurn['rad' + (t.id || 0)] = true;
        ev('hazard', { id: v.id, kind: 'rad', text: 'Fallout pool!' });
        for (const tr of v.tires) tireDamage(v, tr, 1, ev);
        hazard(v, 2, rng, ev);
      }
    } else if (t.type === 'ramp') {
      // take off when leaving the ramp through its lip while moving along it
      const key = 'ramp' + (t.id || 0);
      if (!v.touchedCountersTurn[key]) {
        const along = Math.cos(v.moveDir - t.angle);
        if (along > 0.6 && Math.abs(v.speed) >= 20 && v.control.kind === 'ok') {
          v.touchedCountersTurn[key] = true;
          const distIn = (Math.abs(v.speed) - 20) / 10 + 0.5;
          v.air = { total: distIn, remaining: distIn, height: 0.4 + distIn * 0.15 };
          v.heading = t.angle; v.moveDir = t.angle; v.steer = null;
          ev('jump', { id: v.id, dist: distIn, text: 'JUMP!' });
        }
      }
    } else if (t.type === 'debris') {
      const key = 'deb' + (t.id || 0);
      if (!v.touchedCounters[key]) { v.touchedCounters[key] = true; ev('hazard', { id: v.id, kind: 'debris', text: 'Debris!' }); for (const tr of v.tires) tireDamage(v, tr, Math.max(0, rng.d() - 3), ev); hazard(v, 1, rng, ev); }
    }
  }
  v.inWater = water;
  if (road) offroad = false;
  if (offroad !== v.wasOffroad) {
    v.wasOffroad = offroad;
    if (offroad && !v.offroadOk) ev('hazard', { id: v.id, kind: 'offroad', text: 'Off the road' });
  }
  // dropped counters
  for (const c of state.counters) {
    if (c.ttl === 0) continue;
    const inside = counterContains(c, v.x, v.y);
    if (!inside) { v.onCounters[c.id] = false; continue; }
    if (v.onCounters[c.id]) continue;
    v.onCounters[c.id] = true;
    if (v.touchedCounters[c.id]) continue;
    v.touchedCounters[c.id] = true;
    if (c.owner === v.id && c.turn === state.turn) continue; // you just dropped it
    counterEffect(state, v, c, rng, ev);
  }
}
function counterContains(c, x, y) {
  const cs = Math.cos(-c.angle), sn = Math.sin(-c.angle);
  const dx = x - c.x, dy = y - c.y;
  const lx = dx * cs - dy * sn, ly = dx * sn + dy * cs;
  return Math.abs(lx) <= c.w / 2 && Math.abs(ly) <= c.h / 2;
}
function isOnCounter(v, type) { return (v.onCountersType && v.onCountersType[type]) || false; }
function counterEffect(state, v, c, rng, ev) {
  switch (c.type) {
    case 'oil':
      ev('hazard', { id: v.id, kind: 'oil', text: 'Oil slick!' });
      v.onCountersType = { ...(v.onCountersType || {}), oil: true };
      hazard(v, 1, rng, ev);
      break;
    case 'flamingoil':
      ev('hazard', { id: v.id, kind: 'flamingoil', text: 'Flaming oil!' });
      hazard(v, 1, rng, ev);
      for (const t of v.tires) tireDamage(v, t, Math.max(0, rng.d() - 2), ev);
      applyDamage(state, v, 'U', Math.max(0, rng.d() - 2), c.owner, rng, ev, 'flaming oil');
      v.fire.pending.push({ mod: 3, turns: 2 });
      break;
    case 'mines': case 'spearmines': {
      if (rng.d() <= 4) {
        const dmg = c.type === 'mines' ? rng.d(2) : rng.d(2) + 3;
        ev('mine', { id: v.id, x: c.x, y: c.y, text: 'MINE!' });
        applyDamage(state, v, 'U', dmg, c.owner, rng, ev, 'mine');
        for (const t of v.tires) tireDamage(v, t, c.type === 'mines' ? rng.d() : Math.max(0, rng.d() - 3), ev);
        hazard(v, 3, rng, ev);
        c.ttl = 0;
      }
      break;
    }
    case 'spikes':
      ev('hazard', { id: v.id, kind: 'spikes', text: 'Spikes!' });
      for (const t of v.tires) if (rng.d() <= 4) tireDamage(v, t, rng.d(), ev);
      hazard(v, 1, rng, ev);
      break;
    case 'paint':
      v.paintTurns = 2; ev('hazard', { id: v.id, kind: 'paint', text: 'Painted!' });
      break;
    case 'smoke': default: break;
  }
}
// A hazard: handling drops by D and a control roll on Crash Table 2 may follow.
export function hazard(v, D, rng, ev) {
  if (v.status !== 'alive' || D <= 0) return;
  v.handling = Math.max(HANDLING_MIN, v.handling - D);
  controlCheck(v, 0, 'hazard', rng, ev);
}

// ---------------------------------------------------------------- collisions
function resolveCollisions(state, map, phase, rng, ev) {
  const V = state.vehicles;
  for (let i = 0; i < V.length; i++) {
    const a = V[i];
    if (a.status === 'gone') continue;
    const pa = obbCorners(a.x, a.y, a.heading, a.len, a.wid);
    for (let j = i + 1; j < V.length; j++) {
      const b = V[j];
      if (b.status === 'gone') continue;
      if ((a.air && !b.air) || (b.air && !a.air)) continue;
      const pb = obbCorners(b.x, b.y, b.heading, b.len, b.wid);
      const mtv = polyOverlap(pa, pb);
      if (!mtv) continue;
      const key = a.id + ':' + b.id;
      state._collided = state._collided || {};
      const tag = state.turn + ':' + phase;
      if (state._collided[key] !== tag) { state._collided[key] = tag; vehicleCollision(state, a, b, mtv, rng, ev); }
      // separate
      const push = mtv.depth / 2 + 0.005;
      const wa = a.status === 'alive' ? 1 : 0, wb = b.status === 'alive' ? 1 : 0;
      const tot = wa + wb || 1;
      a.x -= mtv.nx * push * 2 * (wa / tot); a.y -= mtv.ny * push * 2 * (wa / tot);
      b.x += mtv.nx * push * 2 * (wb / tot); b.y += mtv.ny * push * 2 * (wb / tot);
      pa.splice(0, 4, ...obbCorners(a.x, a.y, a.heading, a.len, a.wid));
    }
    // walls and the arena edge
    if (a.status === 'gone') continue;
    wallCollisions(state, map, a, phase, rng, ev);
  }
}

function vehicleCollision(state, a, b, mtv, rng, ev) {
  const sideA = arcOf(a, b.x, b.y), sideB = arcOf(b, a.x, a.y);
  const sa = Math.abs(a.speed), sb = Math.abs(b.speed);
  const dh = Math.abs(normAngle(a.heading - b.heading));
  let kind, v1 = a, v2 = b, s1 = sideA, s2 = sideB;
  const isSide = (s) => s === 'L' || s === 'R';
  if (sideA === 'F' && sideB === 'F') kind = 'head-on';
  else if ((sideA === 'F' && sideB === 'B') || (sideA === 'B' && sideB === 'F')) { kind = 'rear-end'; if (sideA === 'B') { v1 = b; v2 = a; s1 = sideB; s2 = sideA; } }
  else if (isSide(sideA) && isSide(sideB)) kind = dh < Math.PI / 2 ? 'sideswipe' : 'sideswipe-opposite';
  else if (isSide(sideB)) { kind = 'T-bone'; }
  else { kind = 'T-bone'; v1 = b; v2 = a; s1 = sideB; s2 = sideA; }
  const sp1 = Math.abs(v1.speed), sp2 = Math.abs(v2.speed);
  const cx = (a.x + b.x) / 2, cy = (a.y + b.y) / 2;
  let collSpeed, dmgTo2, dmgTo1, new1 = sp1, new2 = sp2;
  const ram = (speed, from, to, ramplate) => {
    let dmg = Math.floor(rollDice(ramDice(speed), rng.d) * from.dm);
    if (from.bumperSpikes && speed > 0) dmg += rng.d();
    if (ramplate) dmg *= 2;
    return dmg;
  };
  const f1 = tempSpeedFraction(v1.dm, v2.dm), f2 = tempSpeedFraction(v2.dm, v1.dm);
  if (kind === 'head-on') {
    collSpeed = sp1 + sp2;
    dmgTo2 = ram(collSpeed, v1, v2, v1.ramplate && s1 === 'F'); dmgTo1 = ram(collSpeed, v2, v1, v2.ramplate && s2 === 'F');
    if (v1.ramplate) dmgTo1 = Math.floor(dmgTo1 / 2); if (v2.ramplate) dmgTo2 = Math.floor(dmgTo2 / 2);
    const t1 = sp1 * f1, t2 = sp2 * f2;
    if (t1 >= t2) { new1 = round5(t1 - t2); new2 = 0; } else { new2 = round5(t2 - t1); new1 = 0; }
  } else if (kind === 'rear-end') {
    collSpeed = Math.max(0, sp1 - sp2);
    dmgTo2 = ram(collSpeed, v1, v2, v1.ramplate && s1 === 'F'); dmgTo1 = ram(collSpeed, v2, v1, false);
    if (v1.ramplate) dmgTo1 = Math.floor(dmgTo1 / 2);
    const t = round5(sp1 * f1 + sp2 * f2);
    new1 = t; new2 = t;
  } else if (kind === 'T-bone') {
    collSpeed = sp1;
    dmgTo2 = ram(collSpeed, v1, v2, v1.ramplate && s1 === 'F'); dmgTo1 = ram(collSpeed, v2, v1, false);
    if (v1.ramplate) dmgTo1 = Math.floor(dmgTo1 / 2);
    new1 = round5(sp1 * f1); new2 = sp2;
  } else {
    const net = kind === 'sideswipe' ? Math.abs(sp1 - sp2) : sp1 + sp2;
    collSpeed = Math.ceil(net / 4 / 5) * 5;
    dmgTo2 = ram(collSpeed, v1, v2, false); dmgTo1 = ram(collSpeed, v2, v1, false);
  }
  ev('collision', { a: v1.id, b: v2.id, kind, speed: collSpeed, x: cx, y: cy, dmgA: dmgTo1, dmgB: dmgTo2, sideA: s1, sideB: s2 });
  if (dmgTo2 > 0) applyDamage(state, v2, s2, dmgTo2, v1.id, rng, ev, 'rammed by ' + v1.name);
  if (dmgTo1 > 0) applyDamage(state, v1, s1, dmgTo1, v2.id, rng, ev, 'rammed by ' + v2.name);
  const applySpeed = (v, ns) => {
    const change = Math.abs(Math.abs(v.speed) - ns);
    v.speed = ns * (v.speed < 0 ? -1 : 1); v.moves = phaseMoves(v.speed);
    if (v.status === 'alive' && kind !== 'sideswipe' && kind !== 'sideswipe-opposite') {
      const D = Math.max(1, Math.round(change / 10));
      v.handling = Math.max(HANDLING_MIN, v.handling - D);
      controlCheck(v, 0, 'hazard', rng, ev);
    }
  };
  if (kind.startsWith('sideswipe')) {
    const D = Math.max(0, Math.round(collSpeed / 10));
    for (const v of [v1, v2]) if (v.status === 'alive' && D > 0) { v.handling = Math.max(HANDLING_MIN, v.handling - D); controlCheck(v, 0, 'hazard', rng, ev); }
  } else { applySpeed(v1, new1); applySpeed(v2, new2); }
  if (v1.status === 'alive') v1.lastHitBy = v2.id; if (v2.status === 'alive') v2.lastHitBy = v1.id;
}

function wallCollisions(state, map, v, phase, rng, ev) {
  if (v.status === 'gone') return;
  const poly = obbCorners(v.x, v.y, v.heading, v.len, v.wid);
  const edges = [
    { kind: 'rect', x: -5, y: -5, w: map.width + 10, h: 5, dp: 9999, dm: 20, edge: true },
    { kind: 'rect', x: -5, y: map.height, w: map.width + 10, h: 5, dp: 9999, dm: 20, edge: true },
    { kind: 'rect', x: -5, y: 0, w: 5, h: map.height, dp: 9999, dm: 20, edge: true },
    { kind: 'rect', x: map.width, y: 0, w: 5, h: map.height, dp: 9999, dm: 20, edge: true },
  ];
  const all = state.walls.concat(edges);
  for (const w of all) {
    if (w.breached) continue;
    if (v.air && w.low) continue;
    const mtv = w.kind === 'circle' ? circleOverlapPoly(w.x, w.y, w.r, poly) : polyOverlap(poly, shapePoly(w));
    if (!mtv) continue;
    // push the vehicle out
    v.x -= mtv.nx * (mtv.depth + 0.003); v.y -= mtv.ny * (mtv.depth + 0.003);
    const key = 'w' + (w.id ?? 'e' + w.x + ',' + w.y);
    state._collided = state._collided || {};
    const tag = state.turn + ':' + phase + ':' + v.id;
    if (state._collided[key] === tag) continue;
    state._collided[key] = tag;
    if (v.status !== 'alive' && v.speed === 0) continue;
    // which side of the car hit?
    const [lx, ly] = [mtv.nx * Math.cos(v.heading) + mtv.ny * Math.sin(v.heading), -mtv.nx * Math.sin(v.heading) + mtv.ny * Math.cos(v.heading)];
    const side = Math.abs(lx) * v.wid >= Math.abs(ly) * v.len ? (lx > 0 ? 'F' : 'B') : (ly > 0 ? 'R' : 'L');
    const speed = Math.abs(v.speed);
    const glancing = (side === 'L' || side === 'R') && Math.abs(lx) < 0.5;
    if (v.air && !glancing) { v.air = null; v.z = 0; }
    if (glancing) {
      const swipe = Math.ceil(speed / 4 / 5) * 5;
      const dmg = Math.floor(rollDice(ramDice(swipe), rng.d) * (w.dm || 1));
      ev('wall', { id: v.id, x: v.x + mtv.nx * v.wid / 2, y: v.y + mtv.ny * v.wid / 2, dmg, side, kind: 'scrape', wallId: w.id });
      if (dmg > 0) applyDamage(state, v, side, Math.min(dmg, w.dp), null, rng, ev, 'scraped a wall');
      if (!w.edge && w.dp < 9999) { w.dp -= Math.floor(rollDice(ramDice(swipe), rng.d) * v.dm); if (w.dp <= 0) breach(state, w, ev); }
      v.speed = round5(Math.max(0, speed - 5)) * (v.speed < 0 ? -1 : 1); v.moves = phaseMoves(v.speed);
      if (v.status === 'alive') { const D = Math.max(1, Math.round(swipe / 10)); v.handling = Math.max(HANDLING_MIN, v.handling - D); controlCheck(v, 0, 'hazard', rng, ev); }
      continue;
    }
    // a ram into a fixed object
    let dealt = Math.floor(rollDice(ramDice(speed), rng.d) * v.dm);
    if (v.ramplate && side === 'F') dealt *= 2;
    const taken = Math.min(dealt, w.dp);
    let breached = false;
    if (!w.edge && w.dp < 9999) { w.dp -= dealt; if (w.dp <= 0) { breach(state, w, ev); breached = true; } }
    ev('wall', { id: v.id, x: v.x + mtv.nx * v.len / 2, y: v.y + mtv.ny * v.len / 2, dmg: taken, side, kind: breached ? 'breach' : 'ram', wallId: w.id, speed });
    const tk = v.ramplate && side === 'F' ? Math.floor(taken / 2) : taken;
    if (tk > 0) applyDamage(state, v, side, tk, null, rng, ev, w.name ? 'hit ' + w.name : 'hit a wall');
    const oldSpeed = speed;
    if (breached) v.speed = round5(speed * tempSpeedFraction(v.dm, w.dm || 1)) * (v.speed < 0 ? -1 : 1);
    else v.speed = 0;
    v.moves = phaseMoves(v.speed);
    if (v.control.kind === 'spin' || v.control.kind === 'roll') { if (!breached) { v.control = { kind: v.control.kind === 'roll' ? 'roll' : 'ok' }; } }
    if (v.control.kind === 'roll' && !breached) { v.control.stopped = true; }
    if (v.status === 'alive') {
      const change = oldSpeed - Math.abs(v.speed);
      const D = Math.max(1, Math.round(change / 10));
      v.handling = Math.max(HANDLING_MIN, v.handling - D);
      controlCheck(v, 0, 'hazard', rng, ev);
    }
    v.skid = null;
  }
}
function breach(state, w, ev) {
  w.breached = true;
  ev('breach', { wallId: w.id, x: w.x + (w.w || 0) / 2, y: w.y + (w.h || 0) / 2, name: w.name || 'wall' });
  // rubble spills out as debris
  state.counters.push({ id: state.nextCounter++, type: 'debris', x: w.x + (w.w || 0) / 2, y: w.y + (w.h || 0) / 2, w: Math.min(2, (w.w || 1) + 0.5), h: Math.min(2, (w.h || 1) + 0.5), angle: 0, ttl: -1, owner: -1, turn: state.turn });
}

// ---------------------------------------------------------------- weapons fire
function combatPhase(state, map, phase, orders, rng, ev) {
  const V = state.vehicles;
  const shots = [];
  for (const v of V) {
    if (!controllable(v) || v.air) continue;
    const o = orders[v.id];
    let target = null;
    if (o.target != null) target = V.find((t) => t.owner.id === o.target || t.id === o.target);
    if (target && (target.status === 'gone' || target.id === v.id)) target = null;
    const auto = o.target === 'auto' || o.target == null;
    const groups = {};
    for (const w of v.weapons) {
      if (w.dp <= 0 || w.shots <= 0) continue;
      if (w.type.startsWith('drop')) continue;
      if (o.weapons && o.weapons[w.id] === false) continue;
      if (v.firedThisTurn[w.id]) continue;
      if (w.link) { (groups[w.link] = groups[w.link] || []).push(w); } else groups['s' + w.id] = [w];
    }
    for (const key of Object.keys(groups)) {
      const g = groups[key];
      let tgt = target;
      if (!tgt && auto) tgt = pickTarget(state, map, v, g[0], o.maxRange);
      if (!tgt) continue;
      const w0 = g[0];
      if (!canFire(state, map, v, w0, tgt, o.maxRange).ok) {
        // try the other side's linked weapons? fallback: skip
        continue;
      }
      for (const w of g) shots.push({ v, w, tgt, aimTires: o.aimTires });
    }
  }
  // all fire is simultaneous: resolve from a snapshot of positions
  for (const s of shots) resolveShot(state, map, s.v, s.w, s.tgt, s.aimTires, phase, rng, ev);
}

function pickTarget(state, map, v, w, maxRange) {
  let best = null, bestD = Infinity;
  for (const t of state.vehicles) {
    if (t.id === v.id || t.status !== 'alive') continue;
    const d = dist(v.x, v.y, t.x, t.y);
    if (d > maxRange || d >= bestD) continue;
    if (!canFire(state, map, v, w, t, maxRange).ok) continue;
    best = t; bestD = d;
  }
  return best;
}

export function canFire(state, map, v, w, t, maxRange = 16) {
  const [fx, fy] = w.side === 'T' ? [v.x, v.y] : sidePoint(v, w.side);
  const d = dist(fx, fy, t.x, t.y);
  if (d > (maxRange || 16)) return { ok: false, why: 'range' };
  const wd = WEAPONS[w.w];
  if (wd.range && d > wd.range) return { ok: false, why: 'range' };
  if (w.side !== 'T') { const arc = arcOf(v, t.x, t.y); if (arc !== w.side) return { ok: false, why: 'arc' }; }
  const lof = lineOfFire(state, map, v, t, fx, fy);
  if (!lof.clear) return { ok: false, why: 'blocked' };
  return { ok: true, d, smoke: lof.smoke, fx, fy };
}
export function lineOfFire(state, map, v, t, fx, fy) {
  let smoke = 0;
  for (const w of state.walls) {
    if (w.breached || w.low) continue;
    if (w.kind === 'circle' ? segmentHitsCircle(fx, fy, t.x, t.y, w.x, w.y, w.r) : segmentHitsPoly(fx, fy, t.x, t.y, shapePoly(w))) return { clear: false };
  }
  for (const o of state.vehicles) {
    if (o.id === v.id || o.id === t.id || o.status === 'gone' || o.air) continue;
    if (segmentHitsPoly(fx, fy, t.x, t.y, obbCorners(o.x, o.y, o.heading, o.len, o.wid))) return { clear: false };
  }
  for (const c of state.counters) {
    if ((c.type !== 'smoke' && c.type !== 'paint' && c.type !== 'flamingoil') || c.ttl === 0) continue;
    const r = { x: c.x - c.w / 2, y: c.y - c.h / 2, w: c.w, h: c.h };
    smoke += segmentInRect(fx, fy, t.x, t.y, r);
  }
  return { clear: true, smoke };
}

export function toHitModifiers(state, map, v, w, t, aimTires, phase) {
  const mods = [];
  const [fx, fy] = w.side === 'T' ? [v.x, v.y] : sidePoint(v, w.side);
  const d = dist(fx, fy, t.x, t.y);
  if (d < 1) mods.push(['Point blank', 4]);
  else if (d >= 4) mods.push(['Range ' + d.toFixed(1) + '"', -Math.floor(d / 4)]);
  if (v.speed === 0) mods.push(['Firer stationary', 1]);
  if (t.speed === 0) mods.push(['Target stationary', 1]);
  const ts = Math.abs(t.speed);
  const arcT = arcOf(t, fx, fy), arcF = arcOf(v, t.x, t.y);
  let eff = ts;
  if ((arcF === 'F' || arcF === 'B') && (arcT === 'F' || arcT === 'B')) eff = Math.max(0, Math.abs(ts - Math.abs(v.speed)) / 2 + (arcF === 'F' && arcT === 'F' ? ts / 2 : 0));
  else if ((arcF === 'L' || arcF === 'R') && (arcT === 'L' || arcT === 'R')) eff = Math.abs(ts - Math.abs(v.speed));
  const speedPen = eff >= 80 ? -6 : eff >= 70 ? -5 : eff >= 60 ? -4 : eff >= 50 ? -3 : eff >= 40 ? -2 : eff >= 30 ? -1 : 0;
  if (speedPen) mods.push(['Target speed', speedPen]);
  if (t.kind === 'cycle') mods.push(['Cycle', (arcT === 'L' || arcT === 'R') ? -2 : -3]);
  else if (t.kind === 'trike') mods.push(['Trike', (arcT === 'L' || arcT === 'R') ? -1 : -2]);
  else if (t.body === 'subcompact') mods.push(['Subcompact', -1]);
  else if (t.body === 'compact' && (arcT === 'F' || arcT === 'B')) mods.push(['Compact', -1]);
  if (aimTires) mods.push(['Aiming at tyres', -3]);
  if (v.toHitBonus) mods.push(['Targeting computer', v.toHitBonus]);
  if (v.driver.skill) mods.push(['Gunner skill', v.driver.skill]);
  if (v.maneuveredPhase === phase) mods.push(['Maneuvering', -v.maneuverD]);
  if (v.paintTurns > 0) mods.push(['Paint on the windows', -2]);
  if (state.options.fallout && d >= 6) mods.push(['Fallout haze', -1]);
  const sus = v.sustained[w.id];
  if (sus && sus.target === t.id && sus.count >= 1) mods.push(['Sustained fire', Math.min(2, sus.count)]);
  const lof = lineOfFire(state, map, v, t, fx, fy);
  if (lof.smoke > 0) mods.push(['Smoke', -Math.ceil(lof.smoke / 0.5)]);
  if (v.wasOffroad) mods.push(['Bad road', -1]);
  return mods;
}

function resolveShot(state, map, v, w, t, aimTires, phase, rng, ev) {
  const wd = WEAPONS[w.w];
  v.firedThisTurn[w.id] = true;
  if (w.shots !== Infinity) w.shots--;
  const sus = v.sustained[w.id];
  if (sus && sus.target === t.id) sus.count++; else v.sustained[w.id] = { target: t.id, count: 0 };
  v.sustained[w.id].turn = state.turn;
  const [fx, fy] = w.side === 'T' ? [v.x, v.y] : sidePoint(v, w.side);
  if (w.side === 'T') v.turretAngle = normAngle(Math.atan2(t.y - fy, t.x - fx) - v.heading);
  const salvo = wd.salvo || 1;
  const mods = toHitModifiers(state, map, v, w, t, aimTires, phase);
  const need = wd.toHit - mods.reduce((s, m) => s + m[1], 0);
  for (let n = 0; n < salvo; n++) {
    const roll = rng.d(2);
    const hit = roll !== 2 && (roll === 12 || roll >= need);
    const side = arcOf(t, fx, fy);
    const base = { from: v.id, to: t.id, wid: w.id, w: w.w, x1: fx, y1: fy, x2: t.x, y2: t.y, roll, need, hit, side, mods, salvo: n };
    if (!hit) {
      // a miss flies on past the target
      const ang = Math.atan2(t.y - fy, t.x - fx) + (rng.next() - 0.5) * 0.25;
      const far = dist(fx, fy, t.x, t.y) + 4 + rng.next() * 6;
      ev('shot', { ...base, x2: fx + Math.cos(ang) * far, y2: fy + Math.sin(ang) * far });
      continue;
    }
    let dmg = rollDice(wd.dmg, rng.d);
    if (wd.type === 'laser' && t.laserReflective) dmg = Math.floor(dmg / 2);
    const res = { destroyed: [] };
    if (aimTires || wd.tiresOnly) {
      const cands = t.tires.filter((tr) => tr.dp > 0 && (side === 'F' ? tr.pos.startsWith('F') || tr.pos === 'F' : side === 'B' ? tr.pos.startsWith('B') || tr.pos === 'B' : tr.pos.endsWith(side)));
      const tire = cands.length ? rng.pick(cands) : t.tires.find((tr) => tr.dp > 0);
      if (tire) { tireDamage(t, tire, dmg, ev, res); }
      ev('shot', { ...base, dmg, tire: tire ? tire.pos : null, destroyed: res.destroyed });
    } else {
      applyDamage(state, t, side, dmg, v.id, rng, ev, wd.name + ' from ' + v.name, res);
      ev('shot', { ...base, dmg, destroyed: res.destroyed, penetrated: res.penetrated });
    }
    v.damageDealt += dmg;
    if (wd.fireMod != null && (wd.type === 'flame' || wd.type === 'laser')) {
      if (!t.fireproof || res.penetrated) t.fire.pending.push({ mod: wd.fireMod, turns: wd.burn || 0 });
    }
    if (dmg >= 1 && t.status === 'alive') hazard(t, dmg >= 10 ? 3 : dmg >= 6 ? 2 : 1, rng, ev);
  }
  if (wd.smoke) {
    // a flamethrower leaves a smoke cloud along the line of fire
    const ang = Math.atan2(t.y - fy, t.x - fx);
    const cx = fx + Math.cos(ang) * 1, cy = fy + Math.sin(ang) * 1;
    state.counters.push({ id: state.nextCounter++, type: 'smoke', x: cx, y: cy, w: 1, h: 0.5, angle: ang, ttl: 2, owner: v.id, turn: state.turn });
  }
}

// Damage to a side: armor, then the components behind it.
export function applyDamage(state, t, side, dmg, byId, rng, ev, cause, res = {}) {
  if (dmg <= 0 || t.status === 'gone') return;
  res.destroyed = res.destroyed || [];
  t.damageTaken += dmg;
  if (byId != null) t.lastHitBy = byId;
  const armor = t.armor;
  const absorbed = Math.min(armor[side] || 0, dmg);
  armor[side] = Math.max(0, (armor[side] || 0) - absorbed);
  let rest = dmg - absorbed;
  if (absorbed > 0) ev('armor', { id: t.id, side, dmg: absorbed, left: armor[side] });
  if (rest <= 0) return;
  res.penetrated = true;
  // components on that side take it first (weapons), then internals
  const order = [];
  if (side === 'T') { for (const w of t.weapons) if (w.side === 'T' && w.dp > 0) order.push({ kind: 'weapon', w }); order.push({ kind: 'internal' }); }
  else {
    for (const w of t.weapons) if (w.side === side && w.dp > 0) order.push({ kind: 'weapon', w });
    order.push({ kind: 'internal' });
    const opp = { F: 'B', B: 'F', L: 'R', R: 'L', U: 'T' }[side];
    for (const w of t.weapons) if (w.side === opp && w.dp > 0) order.push({ kind: 'weapon', w });
    if (opp) order.push({ kind: 'armor', side: opp });
  }
  for (const o of order) {
    if (rest <= 0) break;
    if (o.kind === 'weapon') {
      const take = Math.min(o.w.dp, rest); o.w.dp -= take; rest -= take;
      if (o.w.dp <= 0) { res.destroyed.push(o.w.name); ev('destroyed', { id: t.id, what: o.w.name }); }
    } else if (o.kind === 'internal') {
      // driver, power plant: a random internal location, overflow moves on
      let guard = 6;
      while (rest > 0 && guard-- > 0) {
        const cands = [];
        if (t.driver.dp > 0) cands.push('driver');
        if (t.plant.dp > 0) cands.push('plant');
        if (!cands.length) break;
        const pickI = rng.pick(cands);
        if (pickI === 'driver') {
          const take = Math.min(t.driver.dp, t.safetyseat ? Math.ceil(rest / 2) : rest);
          t.driver.dp -= take; rest -= t.safetyseat ? Math.min(rest, take * 2) : take;
          ev('driver', { id: t.id, dp: t.driver.dp, text: t.driver.dp <= 0 ? 'DRIVER KILLED' : t.driver.dp === 1 ? 'Driver knocked out' : 'Driver wounded' });
          if (t.driver.dp === 2) hazard(t, 2, rng, ev);
          if (t.driver.dp <= 1) { t.killedBy = byId; t.deathReason = cause; }
        } else {
          const take = Math.min(t.plant.dp, rest); t.plant.dp -= take; rest -= take;
          if (t.plant.dp <= 0) { res.destroyed.push('Power plant'); ev('destroyed', { id: t.id, what: 'Power plant' }); }
        }
        if (t.plant.dp <= 0 && t.driver.dp <= 0) break;
      }
      // anything left exits the far side (handled by the following entries)
    } else if (o.kind === 'armor') {
      const take = Math.min(armor[o.side] || 0, rest); armor[o.side] = Math.max(0, (armor[o.side] || 0) - take); rest -= take;
      if (take > 0) ev('armor', { id: t.id, side: o.side, dmg: take, left: armor[o.side] });
    }
  }
  if (t.driver.dp <= 1 && t.status === 'alive') { t.killedBy = t.killedBy ?? byId; t.deathReason = t.deathReason || cause; }
}

export function tireDamage(v, tire, dmg, ev, res = {}) {
  if (dmg <= 0 || tire.dp <= 0) return;
  if (v.wheelguards > 0 && dmg > 0) { const take = Math.min(v.wheelguards, dmg); v.wheelguards -= take; dmg -= take; if (dmg <= 0) return; }
  tire.dp -= dmg;
  if (tire.dp <= 0) {
    tire.dp = 0;
    ev('tire', { id: v.id, tire: tire.pos, text: 'Tyre blown!' });
    res.destroyed = res.destroyed || []; res.destroyed.push('Tyre ' + tire.pos);
    v.handling = Math.max(HANDLING_MIN, v.handling - 2);
    v.lostTire = true;
  } else ev('tiredmg', { id: v.id, tire: tire.pos, dmg });
}

function dropWeapon(state, v, weaponId, rng, ev) {
  const w = v.weapons.find((x) => x.id === weaponId);
  if (!w || w.dp <= 0 || w.shots <= 0 || v.firedThisTurn[w.id]) return;
  const wd = WEAPONS[w.w];
  if (!wd.counter && !wd.cloud) return;
  const fire = (ww) => {
    ww.shots--; v.firedThisTurn[ww.id] = true;
    const wdd = WEAPONS[ww.w];
    const type = wdd.counter || wdd.cloud;
    const side = ww.side;
    let cx, cy, ang = v.heading;
    const back = { x: v.x - Math.cos(v.heading) * (v.len / 2 + 0.5), y: v.y - Math.sin(v.heading) * (v.len / 2 + 0.5) };
    if (side === 'F') { cx = v.x + Math.cos(v.heading) * (v.len / 2 + 0.5); cy = v.y + Math.sin(v.heading) * (v.len / 2 + 0.5); }
    else if (side === 'L') { cx = v.x + Math.sin(v.heading) * (v.wid / 2 + 0.3) - Math.cos(v.heading) * 0.2; cy = v.y - Math.cos(v.heading) * (v.wid / 2 + 0.3) - Math.sin(v.heading) * 0.2; }
    else if (side === 'R') { cx = v.x - Math.sin(v.heading) * (v.wid / 2 + 0.3) - Math.cos(v.heading) * 0.2; cy = v.y + Math.cos(v.heading) * (v.wid / 2 + 0.3) - Math.sin(v.heading) * 0.2; }
    else { cx = back.x; cy = back.y; }
    const size = type === 'mines' || type === 'spearmines' || type === 'spikes' ? [0.5, 0.5] : [1, 0.5];
    const ttl = type === 'smoke' ? 6 : type === 'paint' ? 2 : type === 'flamingoil' ? 5 : -1;
    state.counters.push({ id: state.nextCounter++, type, x: cx, y: cy, w: size[0], h: size[1], angle: ang, ttl, owner: v.id, turn: state.turn });
    ev('drop', { id: v.id, type, x: cx, y: cy, angle: ang, w: size[0], h: size[1] });
  };
  if (w.link) { for (const ww of v.weapons) if (ww.link === w.link && ww.dp > 0 && ww.shots > 0 && !v.firedThisTurn[ww.id]) fire(ww); }
  else fire(w);
}

// ---------------------------------------------------------------- deaths and the end of the turn
function startFire(v, ev, why) {
  if (v.fire.burning) return;
  v.fire.burning = true; v.fire.turnsBurning = 0;
  ev('fire', { id: v.id, text: 'ON FIRE' + (why ? ' (' + why + ')' : '') });
}
function kill(state, v, reason, byId, ev) {
  if (v.status !== 'alive') return;
  v.status = 'wreck'; v.deathReason = reason; v.killedBy = byId ?? v.lastHitBy ?? null;
  if (!/driver|knocked|wrecked|burned/.test(reason)) { v.speed = 0; v.moves = phaseMoves(0); }
  v.air = null; v.z = 0; v.skid = null;
  ev('death', { id: v.id, by: v.killedBy, reason });
  const killer = state.vehicles.find((k) => k.id === v.killedBy);
  if (killer && killer.id !== v.id) killer.kills++;
}
function explode(state, v, rng, ev) {
  if (v.status === 'gone') return;
  ev('explode', { id: v.id, x: v.x, y: v.y });
  if (v.status === 'alive') kill(state, v, 'exploded', v.lastHitBy, ev);
  v.status = 'gone';
  for (const o of state.vehicles) {
    if (o.id === v.id || o.status === 'gone') continue;
    const d = dist(v.x, v.y, o.x, o.y);
    if (d > 2.5) continue;
    const side = arcOf(o, v.x, v.y);
    applyDamage(state, o, side, rng.d(3), v.lastHitBy ?? v.id, rng, ev, v.name + ' exploding');
    if (o.status === 'alive') hazard(o, 2, rng, ev);
  }
  for (let i = 0; i < 4; i++) {
    const a = rng.next() * TAU, r = 0.5 + rng.next() * 1.5;
    state.counters.push({ id: state.nextCounter++, type: 'debris', x: v.x + Math.cos(a) * r, y: v.y + Math.sin(a) * r, w: 0.5, h: 0.25, angle: a, ttl: -1, owner: -1, turn: state.turn });
  }
}
function checkDeath(state, v, rng, ev) {
  if (v.status !== 'alive') return;
  if (v.driver.dp <= 1) { kill(state, v, v.driver.dp <= 0 ? 'driver killed' : 'driver knocked out', v.killedBy ?? v.lastHitBy, ev); return; }
  if (v.control.kind === 'roll' && v.control.stopped) {
    const quarter = v.control.quarter;
    if (quarter % 4 === 0 && workingTires(v) >= v.tires.length - 1) { v.control = { kind: 'ok' }; v.rollAngle = 0; v.moveDir = v.heading; ev('text', { id: v.id, text: 'Back on its wheels!' }); }
    else { v.control = { kind: 'wrecked' }; kill(state, v, 'rolled over', v.lastHitBy, ev); return; }
  }
  if (v.plant.dp <= 0 && v.speed === 0 && !hasWeapons(v)) { kill(state, v, 'wrecked', v.lastHitBy, ev); return; }
  const working = workingTires(v);
  if (v.kind === 'cycle' && working < 2 && Math.abs(v.speed) > 0) { v.control = { kind: 'roll', dir: 1, quarter: 0, phases: 0, stopped: false }; }
  if (working <= Math.ceil(v.tires.length / 2) - (v.kind === 'cycle' ? 1 : 0) && working < v.tires.length && v.speed === 0 && !hasWeapons(v)) kill(state, v, 'immobilised', v.lastHitBy, ev);
}

function endOfTurn(state, map, v, rng, ev) {
  if (v.status === 'gone') return;
  // spin and roll slow down
  if (v.control.kind === 'spin' || v.control.kind === 'roll') {
    v.speed = round5(Math.max(0, Math.abs(v.speed) - 20)); v.moves = phaseMoves(v.speed);
    if (v.speed === 0) {
      if (v.control.kind === 'spin') { v.control = { kind: 'ok' }; v.moveDir = v.heading; ev('text', { id: v.id, text: 'Spin stops' }); }
      else v.control.stopped = true;
    }
  }
  if (v.status !== 'alive') { v.speed = round5(Math.max(0, Math.abs(v.speed) - 10)); v.moves = phaseMoves(v.speed); return; }
  // uncontrolled car (driver out) coasts
  if (v.driver.dp < 2) { v.speed = round5(Math.max(0, Math.abs(v.speed) - 5)); v.moves = phaseMoves(v.speed); }
  if (v.plant.dp <= 0 && v.speed > 0) { /* handled at speed order time */ }
  // off-road wear
  if (v.wasOffroad && !v.offroadOk && Math.abs(v.speed) > 10) {
    const n = Math.abs(v.speed) > 50 ? 3 : Math.abs(v.speed) > 30 ? 2 : 1;
    for (let i = 0; i < n; i++) {
      const r = rng.d(2);
      if (r <= 3) applyDamage(state, v, 'U', 1, null, rng, ev, 'rough ground');
      else if (r <= 5) { const t = rng.pick(v.tires.filter((x) => x.dp > 0) || v.tires); if (t) tireDamage(v, t, 1, ev); }
    }
  }
  // fire
  if (!v.fire.burning && v.fire.pending.length) {
    const total = v.fire.pending.reduce((s, p) => s + p.mod, 0);
    const r = rng.d(2);
    ev('firecheck', { id: v.id, need: total, roll: r });
    if (r <= total) startFire(v, ev, '');
  }
  v.fire.pending = v.fire.pending.map((p) => ({ mod: p.mod, turns: p.turns - 1 })).filter((p) => p.turns > 0);
  if (v.fire.burning) {
    if (v.extinguisher > 0 && rng.d() <= v.extinguisher) { v.fire.burning = false; v.extinguisher = 0; ev('fireout', { id: v.id, text: 'Fire out!' }); }
    else {
      v.fire.turnsBurning++;
      for (const s of SIDES) if (v.armor[s] > 0) v.armor[s]--;
      for (const w of v.weapons) if (w.dp > 0) { w.dp--; if (w.dp <= 0) ev('destroyed', { id: v.id, what: w.name }); }
      for (const t of v.tires) if (t.dp > 0) tireDamage(v, t, 1, ev);
      if (v.plant.dp > 0) { v.plant.dp--; if (v.plant.dp <= 0) ev('destroyed', { id: v.id, what: 'Power plant' }); }
      v.driver.dp--; ev('driver', { id: v.id, dp: v.driver.dp, text: 'Burning!' });
      if (v.driver.dp <= 1) { v.deathReason = 'burned'; }
      const volatile = v.weapons.some((w) => (w.type === 'flame' || w.type === 'rocket' || w.w === 'FOJ') && w.shots > 0);
      if (volatile && rng.d() === 1) { explode(state, v, rng, ev); return; }
      ev('burn', { id: v.id });
    }
  }
  if (v.paintTurns > 0) v.paintTurns--;
  // sustained fire bookkeeping
  for (const k of Object.keys(v.sustained)) if (v.sustained[k].turn !== state.turn) delete v.sustained[k];
  v.onCountersType = {};
  // handling recovers
  const hc = currentHC(v);
  v.hc = hc;
  v.handling = Math.min(hc, v.handling + Math.max(1, hc));
}

function checkMatchEnd(state, ev) {
  const alive = state.vehicles.filter((v) => v.status === 'alive');
  const limit = state.options.maxTurns || 30;
  if (alive.length <= 1 || state.turn > limit) {
    state.over = true;
    state.standings = standings(state);
    state.winner = state.standings[0]?.id ?? null;
    ev('gameover', { winner: state.winner });
  }
}
export function standings(state) {
  const score = (v) => (v.status === 'alive' ? 1000 : 0) + v.kills * 100 + v.damageDealt;
  return state.vehicles.slice().sort((a, b) => score(b) - score(a)).map((v) => ({ id: v.id, owner: v.owner, name: v.name, alive: v.status === 'alive', kills: v.kills, damage: v.damageDealt, taken: v.damageTaken, reason: v.deathReason, score: score(v) }));
}

// ---------------------------------------------------------------- prediction (no dice, no collisions) for the planning ghost
export function predictPath(vIn, orders, map) {
  const v = { x: vIn.x, y: vIn.y, heading: vIn.heading, speed: vIn.speed, top: vIn.top, accel: vIn.accel, len: vIn.len, wid: vIn.wid, wasOffroad: vIn.wasOffroad, plant: vIn.plant };
  const o = normalizeOrders(orders);
  let delta = o.speed || 0;
  if (v.plant.dp <= 0 && delta > 0) delta = 0;
  const maxRev = -Math.floor(v.top / 5 / 5) * 5;
  let target = clamp(v.speed + delta, maxRev, v.top);
  delta = target - v.speed;
  if (delta > 0) delta = Math.min(delta, v.accel);
  if (delta < -45) delta = -45;
  v.speed = round5(v.speed + delta);
  const moves = phaseMoves(v.speed);
  const pts = [{ x: v.x, y: v.y, h: v.heading, phase: 0 }];
  const T = TICKS_PER_PHASE;
  const sgn = v.speed < 0 ? -1 : 1;
  let risk = 0, handling = vIn.handling;
  const notes = [];
  for (let phase = 1; phase <= 5; phase++) {
    const move = moves[phase];
    let st = o.steer[phase - 1];
    const special = o.special && o.special.phase === phase ? o.special : null;
    const can = move >= 1 || (Math.abs(v.speed) <= 5 && move > 0);
    if (!can) { if (st || special) notes.push({ phase, text: 'no manoeuvre on a half move' }); st = null; }
    if (st && st.type === 'bend' && Math.abs(v.speed) <= 5) st = { type: 'pivot', deg: st.deg };
    let D = can ? steerDifficulty(st, v) : 0;
    let sp = null;
    if (special && can) {
      if (special.kind === 'bootlegger' && Math.abs(v.speed) >= 20 && Math.abs(v.speed) <= 35) { D = 7; sp = { kind: 'bootlegger', dir: special.dir || 1 }; st = null; }
      else if (special.kind === 'tstop' && Math.abs(v.speed) >= 20 && Math.abs(v.speed) <= 35) { D = Math.ceil(Math.abs(v.speed) / 10); sp = { kind: 'tstop', dir: special.dir || 1 }; st = null; }
      else notes.push({ phase, text: special.kind + ' needs 20-35 mph' });
    }
    if (D > 0) { handling -= D; const ct = controlTable(v.speed, handling); notes.push({ phase, text: describeSteer(sp || st) + ' D' + D + ': ' + (ct === 'safe' ? 'safe' : ct === 'XX' ? 'LOSES CONTROL' : 'roll ' + ct + '+'), ct }); if (ct !== 'safe') risk = Math.max(risk, ct === 'XX' ? 7 : ct); }
    const moveDir = v.heading;
    for (let k = 0; k < T; k++) {
      const d = move / T;
      if (sp && sp.kind === 'bootlegger') { v.heading = normAngle(v.heading + (Math.PI / T) * sp.dir); v.x += Math.cos(moveDir) * d; v.y += Math.sin(moveDir) * d; if (k === T - 1) { v.speed = 0; moves.fill(0); } continue; }
      if (sp && sp.kind === 'tstop') { v.heading = normAngle(v.heading + (Math.PI / 2 / T) * sp.dir); v.x += Math.cos(moveDir) * d; v.y += Math.sin(moveDir) * d; if (k === T - 1) { v.speed = round5(Math.max(0, v.speed - 20)); const m2 = phaseMoves(v.speed); for (let p = phase + 1; p <= 5; p++) moves[p] = m2[p]; } continue; }
      if (st) {
        if (st.type === 'bend' || st.type === 'pivot' || st.type === 'swerve') v.heading = normAngle(v.heading + ((st.type === 'swerve' ? -st.deg : st.deg) * Math.PI / 180) / T);
        if (st.type === 'drift' || st.type === 'swerve') { const dir = st.type === 'swerve' ? Math.sign(st.deg) : st.dir; const lat = (st.steep ? 0.5 : 0.25) / T * dir; v.x += -Math.sin(v.heading) * lat; v.y += Math.cos(v.heading) * lat; }
      }
      v.x += Math.cos(v.heading) * d * sgn; v.y += Math.sin(v.heading) * d * sgn;
    }
    pts.push({ x: v.x, y: v.y, h: v.heading, phase, move });
  }
  return { points: pts, speed: v.speed, risk, notes, handling };
}

export function vehicleSummary(v) {
  return {
    id: v.id, owner: v.owner, name: v.name, defId: v.defId, color: v.color, body: v.body, kind: v.kind, style: v.style, len: v.len, wid: v.wid,
    x: v.x, y: v.y, heading: v.heading, speed: v.speed, armor: v.armor, armorMax: v.armorMax, tires: v.tires, plant: v.plant, driver: v.driver,
    weapons: v.weapons, turret: v.turret, hc: v.hc, handling: v.handling, accel: v.accel, top: v.top, weight: v.weight,
    control: v.control, fire: { burning: v.fire.burning }, status: v.status, deathReason: v.deathReason, kills: v.kills, damageDealt: v.damageDealt,
    wasOffroad: v.wasOffroad, offroadOk: v.offroadOk, paintTurns: v.paintTurns, extinguisher: v.extinguisher, toHitBonus: v.toHitBonus, z: v.z, rollAngle: v.rollAngle,
    killedBy: v.killedBy, wheelguards: v.wheelguards, air: v.air,
  };
}
