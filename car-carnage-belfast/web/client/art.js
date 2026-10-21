// Car Carnage: Belfast Edition - vector art. Cars, landmarks, ground and counters, all drawn with
// canvas paths in world units (inches). Thick black outlines, flat colour, long dusk shadows.

const TAU = Math.PI * 2;
export const OUTLINE = '#0a0a0c';
const SHADOW = 'rgba(0,0,0,0.42)';
const LIGHT = [0.28, 0.38]; // shadow offset per inch of height

function rrect(ctx, x, y, w, h, r) {
  r = Math.min(r, w / 2, h / 2);
  ctx.beginPath(); ctx.moveTo(x + r, y); ctx.lineTo(x + w - r, y); ctx.quadraticCurveTo(x + w, y, x + w, y + r); ctx.lineTo(x + w, y + h - r); ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h); ctx.lineTo(x + r, y + h); ctx.quadraticCurveTo(x, y + h, x, y + h - r); ctx.lineTo(x, y + r); ctx.quadraticCurveTo(x, y, x + r, y); ctx.closePath();
}
function poly(ctx, pts) { ctx.beginPath(); pts.forEach(([x, y], i) => (i ? ctx.lineTo(x, y) : ctx.moveTo(x, y))); ctx.closePath(); }
export function shade(hex, f) {
  const m = /^#?([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/i.exec(hex); if (!m) return hex;
  const c = [1, 2, 3].map((i) => Math.max(0, Math.min(255, Math.round(parseInt(m[i], 16) * f))));
  return `rgb(${c[0]},${c[1]},${c[2]})`;
}
function seeded(seed) { let a = seed >>> 0; return () => { a = (a + 0x6d2b79f5) >>> 0; let t = a; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }; }

// ---------------------------------------------------------------- cars
// Body outlines in local space: x forward, y to the right. Length L, width W.
function bodyPath(ctx, style, L, W) {
  const hl = L / 2, hw = W / 2;
  switch (style) {
    case 'coupe': poly(ctx, [[hl, -hw * 0.55], [hl - 0.06, -hw], [-hl + 0.1, -hw], [-hl, -hw * 0.7], [-hl, hw * 0.7], [-hl + 0.1, hw], [hl - 0.06, hw], [hl, hw * 0.55]]); break;
    case 'hatch': poly(ctx, [[hl, -hw * 0.6], [hl - 0.12, -hw], [-hl + 0.05, -hw], [-hl, -hw * 0.75], [-hl, hw * 0.75], [-hl + 0.05, hw], [hl - 0.12, hw], [hl, hw * 0.6]]); break;
    case 'limo': rrect(ctx, -hl, -hw, L, W, 0.07); break;
    case 'wagon': poly(ctx, [[hl, -hw * 0.7], [hl - 0.15, -hw], [-hl, -hw], [-hl, hw], [hl - 0.15, hw], [hl, hw * 0.7]]); break;
    case 'pickup': poly(ctx, [[hl, -hw * 0.7], [hl - 0.12, -hw], [-hl, -hw], [-hl, hw], [hl - 0.12, hw], [hl, hw * 0.7]]); break;
    case 'van': rrect(ctx, -hl, -hw, L, W, 0.05); break;
    case 'trike': poly(ctx, [[hl, -hw * 0.25], [hl - 0.3, -hw * 0.8], [-hl + 0.15, -hw], [-hl, -hw * 0.8], [-hl, hw * 0.8], [-hl + 0.15, hw], [hl - 0.3, hw * 0.8], [hl, hw * 0.25]]); break;
    case 'cycle': poly(ctx, [[hl, -hw * 0.3], [hl * 0.5, -hw], [-hl * 0.6, -hw], [-hl, -hw * 0.4], [-hl, hw * 0.4], [-hl * 0.6, hw], [hl * 0.5, hw], [hl, hw * 0.3]]); break;
    default: poly(ctx, [[hl, -hw * 0.65], [hl - 0.1, -hw], [-hl + 0.08, -hw], [-hl, -hw * 0.8], [-hl, hw * 0.8], [-hl + 0.08, hw], [hl - 0.1, hw], [hl, hw * 0.65]]); break; // saloon
  }
}
export function drawCar(ctx, v, o = {}) {
  const L = v.len, W = v.wid, hl = L / 2, hw = W / 2;
  const wreck = v.status !== 'alive';
  const color = wreck ? '#2a2a2c' : v.color;
  const z = v.z || 0;
  const roll = v.rollAngle || 0;
  const flip = Math.cos(roll) < 0;
  ctx.save();
  // shadow on the ground
  ctx.save();
  ctx.translate(LIGHT[0] * (0.25 + z * 2.5), LIGHT[1] * (0.25 + z * 2.5));
  ctx.fillStyle = SHADOW; ctx.globalAlpha = Math.max(0.2, 1 - z * 0.8);
  bodyPath(ctx, v.style, L * (1 + z * 0.2), W * (1 + z * 0.2)); ctx.fill();
  ctx.restore();
  // airborne cars look bigger, rolling cars squash sideways
  const scale = 1 + z * 0.35;
  ctx.scale(scale, scale * Math.max(0.35, Math.abs(Math.cos(roll))));
  ctx.lineJoin = 'round'; ctx.lineWidth = 0.035; ctx.strokeStyle = OUTLINE;
  // wheels
  const wheelL = L * 0.2, wheelW = W * 0.14;
  const tyres = v.tires || [];
  const posOf = (p) => ({ FL: [hl * 0.62, -hw], FR: [hl * 0.62, hw], BL: [-hl * 0.62, -hw], BR: [-hl * 0.62, hw], ML: [0, -hw], MR: [0, hw], F: [hl * 0.7, 0], B: [-hl * 0.7, 0] }[p]);
  for (const t of tyres) {
    const p = posOf(t.pos); if (!p) continue;
    const gone = t.dp <= 0;
    ctx.fillStyle = gone ? '#777' : '#111';
    if (v.kind === 'cycle') { ctx.beginPath(); ctx.ellipse(p[0], p[1], wheelL * 0.8, wheelW * 1.3, 0, 0, TAU); ctx.fill(); ctx.stroke(); }
    else { rrect(ctx, p[0] - wheelL / 2, p[1] - wheelW * 1.1, wheelL, wheelW * 2.2, 0.03); ctx.fill(); if (gone) { ctx.strokeStyle = '#333'; ctx.stroke(); ctx.strokeStyle = OUTLINE; } }
  }
  // body
  ctx.fillStyle = flip ? '#3a3a3a' : color;
  bodyPath(ctx, v.style, L, W); ctx.fill(); ctx.stroke();
  if (flip) { // underbody: a dark plate with the exhaust and axles
    ctx.strokeStyle = '#111'; ctx.lineWidth = 0.05; ctx.beginPath(); ctx.moveTo(-hl * 0.6, -hw * 0.9); ctx.lineTo(-hl * 0.6, hw * 0.9); ctx.moveTo(hl * 0.6, -hw * 0.9); ctx.lineTo(hl * 0.6, hw * 0.9); ctx.moveTo(-hl * 0.9, 0); ctx.lineTo(hl * 0.3, 0); ctx.stroke(); ctx.strokeStyle = OUTLINE; ctx.lineWidth = 0.035;
    ctx.restore(); return;
  }
  // body highlight stripe
  ctx.globalAlpha = 0.28; ctx.fillStyle = '#fff'; ctx.fillRect(-hl + 0.1, -hw * 0.82, L - 0.2, W * 0.14); ctx.globalAlpha = 1;
  // glass and roof per style
  const glass = wreck ? '#1a1a1a' : '#17202b';
  ctx.fillStyle = glass;
  switch (v.style) {
    case 'cycle': { ctx.fillStyle = wreck ? '#222' : shade(color, 0.6); ctx.beginPath(); ctx.arc(-hl * 0.1, 0, hw * 0.55, 0, TAU); ctx.fill(); ctx.stroke(); ctx.fillStyle = '#222'; ctx.beginPath(); ctx.arc(-hl * 0.1, 0, hw * 0.3, 0, TAU); ctx.fill(); break; }
    case 'trike': { poly(ctx, [[hl * 0.35, -hw * 0.35], [hl * 0.05, -hw * 0.55], [-hl * 0.35, -hw * 0.55], [-hl * 0.35, hw * 0.55], [hl * 0.05, hw * 0.55], [hl * 0.35, hw * 0.35]]); ctx.fill(); ctx.stroke(); ctx.fillStyle = '#222'; ctx.beginPath(); ctx.arc(-hl * 0.1, 0, hw * 0.28, 0, TAU); ctx.fill(); break; }
    case 'pickup': { rrect(ctx, hl * 0.05, -hw * 0.8, hl * 0.5, W * 0.8, 0.04); ctx.fill(); ctx.stroke(); ctx.fillStyle = shade(color, 0.55); rrect(ctx, -hl * 0.95, -hw * 0.82, hl * 0.85, W * 0.82, 0.03); ctx.fill(); ctx.stroke(); break; }
    case 'van': { rrect(ctx, hl * 0.45, -hw * 0.8, hl * 0.4, W * 0.8, 0.03); ctx.fill(); ctx.stroke(); ctx.fillStyle = shade(color, 0.8); rrect(ctx, -hl * 0.9, -hw * 0.75, hl * 1.2, W * 0.75, 0.03); ctx.fill(); ctx.stroke(); break; }
    case 'wagon': { rrect(ctx, -hl * 0.75, -hw * 0.78, hl * 1.35, W * 0.78, 0.05); ctx.fill(); ctx.stroke(); ctx.fillStyle = shade(color, 0.8); rrect(ctx, -hl * 0.6, -hw * 0.6, hl * 1.0, W * 0.6, 0.03); ctx.fill(); break; }
    case 'limo': { rrect(ctx, -hl * 0.55, -hw * 0.78, hl * 1.05, W * 0.78, 0.05); ctx.fill(); ctx.stroke(); ctx.fillStyle = shade(color, 0.8); rrect(ctx, -hl * 0.4, -hw * 0.6, hl * 0.7, W * 0.6, 0.03); ctx.fill(); break; }
    case 'coupe': { rrect(ctx, -hl * 0.45, -hw * 0.72, hl * 0.85, W * 0.72, 0.06); ctx.fill(); ctx.stroke(); ctx.fillStyle = shade(color, 0.8); rrect(ctx, -hl * 0.3, -hw * 0.5, hl * 0.45, W * 0.5, 0.03); ctx.fill(); break; }
    default: { rrect(ctx, -hl * 0.5, -hw * 0.78, hl * 0.9, W * 0.78, 0.05); ctx.fill(); ctx.stroke(); ctx.fillStyle = shade(color, 0.8); rrect(ctx, -hl * 0.35, -hw * 0.6, hl * 0.55, W * 0.6, 0.03); ctx.fill(); break; }
  }
  // lights
  if (!wreck) {
    ctx.fillStyle = '#fff3b0'; ctx.fillRect(hl - 0.07, -hw * 0.85, 0.06, hw * 0.35); ctx.fillRect(hl - 0.07, hw * 0.5, 0.06, hw * 0.35);
    ctx.fillStyle = '#ff2a2a'; ctx.fillRect(-hl + 0.01, -hw * 0.85, 0.05, hw * 0.3); ctx.fillRect(-hl + 0.01, hw * 0.55, 0.05, hw * 0.3);
  }
  // weapons as barrels and nozzles on their sides
  const bySide = {};
  for (const w of v.weapons || []) (bySide[w.side] = bySide[w.side] || []).push(w);
  for (const side of ['F', 'B', 'L', 'R']) {
    const list = bySide[side] || [];
    list.forEach((w, i) => {
      const n = list.length, off = (i - (n - 1) / 2) * (side === 'F' || side === 'B' ? W * 0.35 : L * 0.3);
      ctx.save();
      if (side === 'F') ctx.translate(hl, off); else if (side === 'B') { ctx.translate(-hl, off); ctx.rotate(Math.PI); } else if (side === 'R') { ctx.translate(off, hw); ctx.rotate(Math.PI / 2); } else { ctx.translate(off, -hw); ctx.rotate(-Math.PI / 2); }
      drawWeaponNub(ctx, w);
      ctx.restore();
    });
  }
  if (v.turret || bySide.T) {
    ctx.fillStyle = wreck ? '#333' : shade(color, 0.7); ctx.beginPath(); ctx.arc(-hl * 0.05, 0, hw * 0.45, 0, TAU); ctx.fill(); ctx.stroke();
    ctx.save(); ctx.translate(-hl * 0.05, 0); ctx.rotate(v.turretAngle || 0); ctx.fillStyle = '#444'; ctx.fillRect(0, -0.03, hw * 0.9, 0.06); ctx.strokeRect(0, -0.03, hw * 0.9, 0.06); ctx.restore();
  }
  // damage: scorch marks grow as armour goes
  if (v.armor && v.armorMax) {
    const rng = seeded(v.id * 977 + 13);
    for (const side of ['F', 'B', 'L', 'R', 'T']) {
      const max = v.armorMax[side] || 0, cur = v.armor[side] || 0;
      const frac = max ? 1 - cur / max : 0;
      if (frac <= 0.05) continue;
      const n = Math.ceil(frac * 5);
      ctx.fillStyle = 'rgba(20,16,12,0.75)';
      for (let i = 0; i < n; i++) {
        let x, y;
        if (side === 'F') { x = hl - 0.05 - rng() * 0.2; y = (rng() - 0.5) * W; } else if (side === 'B') { x = -hl + 0.05 + rng() * 0.2; y = (rng() - 0.5) * W; } else if (side === 'L') { x = (rng() - 0.5) * L; y = -hw + rng() * 0.1; } else if (side === 'R') { x = (rng() - 0.5) * L; y = hw - rng() * 0.1; } else { x = (rng() - 0.5) * L * 0.6; y = (rng() - 0.5) * W * 0.6; }
        ctx.beginPath(); ctx.ellipse(x, y, 0.05 + rng() * 0.07, 0.03 + rng() * 0.05, rng() * TAU, 0, TAU); ctx.fill();
      }
    }
  }
  if (wreck) { ctx.strokeStyle = '#555'; ctx.lineWidth = 0.02; ctx.beginPath(); ctx.moveTo(-hl * 0.6, -hw * 0.5); ctx.lineTo(hl * 0.3, hw * 0.4); ctx.moveTo(-hl * 0.2, hw * 0.7); ctx.lineTo(hl * 0.5, -hw * 0.6); ctx.stroke(); }
  if (v.paintTurns > 0) { ctx.fillStyle = 'rgba(255,0,180,0.55)'; rrect(ctx, -hl * 0.5, -hw * 0.78, hl * 0.9, W * 0.78, 0.05); ctx.fill(); }
  ctx.restore();
}
function drawWeaponNub(ctx, w) {
  // drawn pointing along +x from the edge of the body
  const dead = w.dp <= 0;
  ctx.fillStyle = dead ? '#553' : '#3b3f46'; ctx.strokeStyle = OUTLINE; ctx.lineWidth = 0.03;
  switch (w.type) {
    case 'laser': ctx.fillStyle = dead ? '#553' : '#2fe6e6'; rrect(ctx, -0.02, -0.035, 0.14, 0.07, 0.02); ctx.fill(); ctx.stroke(); break;
    case 'flame': rrect(ctx, -0.02, -0.05, 0.1, 0.1, 0.02); ctx.fill(); ctx.stroke(); ctx.fillStyle = '#ff7a1f'; ctx.beginPath(); ctx.arc(0.1, 0, 0.03, 0, TAU); ctx.fill(); break;
    case 'rocket': ctx.fillStyle = dead ? '#553' : '#5a3a2a'; rrect(ctx, -0.03, -0.06, 0.1, 0.12, 0.02); ctx.fill(); ctx.stroke(); ctx.fillStyle = '#ddd'; ctx.fillRect(0.02, -0.04, 0.05, 0.03); ctx.fillRect(0.02, 0.01, 0.05, 0.03); break;
    case 'dropLiquid': case 'dropGas': case 'dropSolid': ctx.fillStyle = dead ? '#553' : '#555'; ctx.beginPath(); ctx.arc(0.0, 0, 0.035, 0, TAU); ctx.fill(); ctx.stroke(); break;
    default: { const big = ['AC', 'ATG', 'RR'].includes(w.w); ctx.fillRect(-0.02, -0.035, big ? 0.22 : 0.14, 0.07); ctx.strokeRect(-0.02, -0.035, big ? 0.22 : 0.14, 0.07); if (w.w === 'VMG') { ctx.fillRect(0.05, -0.06, 0.1, 0.12); } break; }
  }
}

// ---------------------------------------------------------------- the ground
const THEMES = {
  dock: { base: '#4a4d4f', speck: '#5a5d5f', crack: '#2d2f31', road: '#3c3e40', line: '#9c9a7a' },
  city: { base: '#3b3d41', speck: '#46484c', crack: '#26282b', road: '#333538', line: '#a8a48a' },
  river: { base: '#3f4246', speck: '#4a4d51', crack: '#2a2c2f', road: '#353739', line: '#a4a287' },
  terraces: { base: '#403c38', speck: '#4c4742', crack: '#2b2825', road: '#36332f', line: '#a8a48a' },
  hill: { base: '#4f4a35', speck: '#5a5540', crack: '#3a3524', road: '#5c5442', line: '#7f7760' },
  avenue: { base: '#3c3e41', speck: '#47494c', crack: '#27292c', road: '#313336', line: '#b0ac90' },
  gaol: { base: '#45474a', speck: '#505255', crack: '#2d2f31', road: '#3a3c3e', line: '#9c9a7a' },
};
export function renderGround(map, px) {
  const c = document.createElement('canvas');
  c.width = Math.ceil(map.width * px); c.height = Math.ceil(map.height * px);
  const ctx = c.getContext('2d');
  ctx.scale(px, px);
  const th = THEMES[map.theme] || THEMES.city;
  const rng = seeded(map.id.length * 1337 + map.width);
  ctx.fillStyle = th.base; ctx.fillRect(0, 0, map.width, map.height);
  // cracks and speckles
  ctx.fillStyle = th.speck;
  for (let i = 0; i < map.width * map.height * 1.5; i++) { ctx.globalAlpha = 0.3 + rng() * 0.5; ctx.fillRect(rng() * map.width, rng() * map.height, 0.05 + rng() * 0.12, 0.05 + rng() * 0.12); }
  ctx.globalAlpha = 1; ctx.strokeStyle = th.crack; ctx.lineWidth = 0.03; ctx.lineCap = 'round';
  for (let i = 0; i < map.width * 0.9; i++) {
    let x = rng() * map.width, y = rng() * map.height; ctx.beginPath(); ctx.moveTo(x, y);
    for (let k = 0; k < 4 + rng() * 6; k++) { x += (rng() - 0.5) * 1.2; y += (rng() - 0.5) * 1.2; ctx.lineTo(x, y); }
    ctx.stroke();
  }
  // lawns, yards and ground art first, roads over them
  for (const d of map.deco || []) drawDecoGround(ctx, d, th, rng, map);
  for (const d of map.deco || []) if (d.type === 'road') drawRoad(ctx, d, th);
  for (const d of map.deco || []) if (d.type === 'text') drawRoadText(ctx, d);
  for (const t of map.terrain || []) drawTerrainStatic(ctx, t, rng);
  // wall shadows live on the ground so they sit under everything
  for (const w of map.walls) drawWallShadow(ctx, w);
  // scorched edges: a vignette of fallout grime
  const g = ctx.createRadialGradient(map.width / 2, map.height / 2, Math.min(map.width, map.height) * 0.35, map.width / 2, map.height / 2, Math.max(map.width, map.height) * 0.75);
  g.addColorStop(0, 'rgba(0,0,0,0)'); g.addColorStop(1, 'rgba(10,6,2,0.55)'); ctx.fillStyle = g; ctx.fillRect(0, 0, map.width, map.height);
  return c;
}
function drawRoad(ctx, d, th) {
  ctx.save(); ctx.lineCap = 'butt'; ctx.lineJoin = 'round';
  ctx.strokeStyle = d.dirt ? '#5e5541' : th.road; ctx.lineWidth = d.w; ctx.beginPath(); d.pts.forEach(([x, y], i) => (i ? ctx.lineTo(x, y) : ctx.moveTo(x, y))); ctx.stroke();
  if (!d.dirt) { ctx.strokeStyle = th.line; ctx.globalAlpha = 0.35; ctx.lineWidth = 0.04; ctx.setLineDash([0.4, 0.4]); ctx.beginPath(); d.pts.forEach(([x, y], i) => (i ? ctx.lineTo(x, y) : ctx.moveTo(x, y))); ctx.stroke(); ctx.setLineDash([]);
    ctx.globalAlpha = 0.25; ctx.lineWidth = 0.03; ctx.beginPath(); // kerbs
    const [[x1, y1], [x2, y2]] = [d.pts[0], d.pts[d.pts.length - 1]]; const a = Math.atan2(y2 - y1, x2 - x1), nx = -Math.sin(a) * d.w / 2, ny = Math.cos(a) * d.w / 2;
    ctx.moveTo(x1 + nx, y1 + ny); ctx.lineTo(x2 + nx, y2 + ny); ctx.moveTo(x1 - nx, y1 - ny); ctx.lineTo(x2 - nx, y2 - ny); ctx.stroke(); }
  ctx.restore();
}
function drawRoadText(ctx, d) {
  ctx.save(); ctx.globalAlpha = d.river ? 0.25 : 0.4; ctx.fillStyle = d.river ? '#9ff' : '#d8d2b8'; ctx.font = `bold ${d.size || 0.6}px Impact, "Arial Narrow Bold", sans-serif`; ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; ctx.fillText(d.text, d.x, d.y); ctx.restore();
}
function drawDecoGround(ctx, d, th, rng, map) {
  switch (d.type) {
    case 'lawn': case 'avenue': { ctx.fillStyle = d.type === 'lawn' ? '#5b5a35' : th.road; ctx.fillRect(d.x, d.y, d.w, d.h); if (d.type === 'lawn') { ctx.fillStyle = '#6a6a3c'; for (let i = 0; i < d.w * d.h * 2; i++) ctx.fillRect(d.x + rng() * d.w, d.y + rng() * d.h, 0.1, 0.05); } else { ctx.strokeStyle = th.line; ctx.globalAlpha = 0.35; ctx.lineWidth = 0.05; ctx.setLineDash([0.6, 0.5]); for (const yy of [d.y + d.h * 0.33, d.y + d.h * 0.66]) { ctx.beginPath(); ctx.moveTo(d.x, yy); ctx.lineTo(d.x + d.w, yy); ctx.stroke(); } ctx.setLineDash([]); ctx.globalAlpha = 1; } break; }
    case 'wasteground': { ctx.fillStyle = '#4a4032'; ctx.fillRect(d.x, d.y, d.w, d.h); ctx.fillStyle = '#5a5042'; for (let i = 0; i < d.w * d.h; i++) { ctx.beginPath(); ctx.arc(d.x + rng() * d.w, d.y + rng() * d.h, 0.05 + rng() * 0.15, 0, TAU); ctx.fill(); } break; }
    case 'yard': case 'slipway': { ctx.fillStyle = d.type === 'yard' ? '#4e5054' : '#55585a'; ctx.fillRect(d.x, d.y, d.w, d.h); ctx.strokeStyle = 'rgba(0,0,0,0.25)'; ctx.lineWidth = 0.03; for (let x = d.x; x <= d.x + d.w; x += d.type === 'yard' ? 2 : 1) { ctx.beginPath(); ctx.moveTo(x, d.y); ctx.lineTo(x, d.y + d.h); ctx.stroke(); } if (d.type === 'slipway') { ctx.strokeStyle = '#6d5a3a'; ctx.lineWidth = 0.06; for (const yy of [d.y + d.h * 0.3, d.y + d.h * 0.7]) { ctx.beginPath(); ctx.moveTo(d.x, yy); ctx.lineTo(d.x + d.w, yy); ctx.stroke(); } } break; }
    case 'river': { ctx.fillStyle = '#17323a'; ctx.fillRect(d.x, d.y, d.w, d.h); ctx.strokeStyle = 'rgba(80,255,120,0.18)'; ctx.lineWidth = 0.12; for (let i = 0; i < 18; i++) { const yy = d.y + rng() * d.h; ctx.beginPath(); ctx.moveTo(d.x, yy); for (let x = d.x; x <= d.x + d.w; x += 2) ctx.lineTo(x, yy + Math.sin(x * 0.7 + i) * 0.3); ctx.stroke(); } ctx.fillStyle = '#2b2b2b'; for (let i = 0; i < 10; i++) { ctx.beginPath(); ctx.ellipse(d.x + rng() * d.w, d.y + rng() * d.h, 0.3, 0.12, rng() * 3, 0, TAU); ctx.fill(); } break; } // junk in the water
    case 'bridge': { ctx.fillStyle = '#5a5c5e'; ctx.fillRect(d.x, d.y, d.w, d.h); ctx.strokeStyle = 'rgba(0,0,0,0.35)'; ctx.lineWidth = 0.03; const vert = d.h > d.w; for (let i = 0; i < 6; i++) { ctx.beginPath(); if (vert) { const yy = d.y + d.h * i / 5; ctx.moveTo(d.x, yy); ctx.lineTo(d.x + d.w, yy); } else { const xx = d.x + d.w * i / 5; ctx.moveTo(xx, d.y); ctx.lineTo(xx, d.y + d.h); } ctx.stroke(); } break; }
    case 'weir': { ctx.strokeStyle = 'rgba(220,240,255,0.5)'; ctx.lineWidth = 0.08; for (let i = 0; i < 5; i++) { ctx.beginPath(); ctx.moveTo(d.x - 0.3 + i * 0.15, d.y); ctx.lineTo(d.x - 0.3 + i * 0.15, d.y + d.h); ctx.stroke(); } ctx.fillStyle = '#3a3a3a'; for (let i = 0; i < 4; i++) ctx.fillRect(d.x - 0.2, d.y + d.h * (i + 0.5) / 4 - 0.15, 0.5, 0.3); break; }
    case 'crater': { const g = ctx.createRadialGradient(d.x, d.y, 0, d.x, d.y, d.r); g.addColorStop(0, '#15120f'); g.addColorStop(0.7, '#2a2520'); g.addColorStop(0.92, '#5a5248'); g.addColorStop(1, 'rgba(90,82,72,0)'); ctx.fillStyle = g; ctx.beginPath(); ctx.arc(d.x, d.y, d.r, 0, TAU); ctx.fill(); ctx.strokeStyle = '#1a1612'; ctx.lineWidth = 0.04; for (let i = 0; i < 12; i++) { const a = rng() * TAU; ctx.beginPath(); ctx.moveTo(d.x + Math.cos(a) * d.r * 0.6, d.y + Math.sin(a) * d.r * 0.6); ctx.lineTo(d.x + Math.cos(a + 0.2) * d.r * (1.1 + rng() * 0.5), d.y + Math.sin(a + 0.2) * d.r * (1.1 + rng() * 0.5)); ctx.stroke(); } break; }
    case 'dome': { ctx.fillStyle = '#6b7a6e'; ctx.beginPath(); ctx.arc(d.x, d.y, d.r, Math.PI * 0.5, Math.PI * 1.5); ctx.fill(); ctx.strokeStyle = OUTLINE; ctx.lineWidth = 0.05; ctx.stroke(); ctx.fillStyle = '#3a3f3a'; for (let i = 0; i < 20; i++) { ctx.beginPath(); ctx.arc(d.x + rng() * d.r * 1.4, d.y + (rng() - 0.5) * d.r * 2, 0.08 + rng() * 0.15, 0, TAU); ctx.fill(); } break; }
    case 'mural': { const cols = ['#d33', '#fc3', '#39c', '#3a3', '#fff', '#f80']; for (let i = 0; i < 8; i++) { ctx.fillStyle = cols[i % cols.length]; ctx.globalAlpha = 0.6; ctx.fillRect(d.x + d.w * i / 8, d.y + d.h, d.w / 8, 0.25); } ctx.globalAlpha = 1; break; }
    case 'gorse': { for (let i = 0; i < 14; i++) { ctx.fillStyle = i % 3 ? '#4d5a2a' : '#c9b63a'; ctx.beginPath(); ctx.arc(d.x + (rng() - 0.5) * d.r * 2, d.y + (rng() - 0.5) * d.r * 2, 0.15 + rng() * 0.25, 0, TAU); ctx.fill(); } break; }
    case 'tunnel': { ctx.fillStyle = '#111'; ctx.beginPath(); ctx.arc(d.x, d.y, 0.8, Math.PI, TAU); ctx.fill(); ctx.strokeStyle = '#777'; ctx.lineWidth = 0.08; ctx.stroke(); break; }
    case 'shipwreck': { ctx.save(); ctx.translate(d.x, d.y); ctx.rotate(-0.3); ctx.fillStyle = '#5a2e22'; poly(ctx, [[-4, -0.6], [3.5, -0.8], [5, 0], [3.5, 0.8], [-4, 0.6]]); ctx.fill(); ctx.strokeStyle = OUTLINE; ctx.lineWidth = 0.05; ctx.stroke(); ctx.fillStyle = '#333'; ctx.fillRect(-1, -0.3, 2.5, 0.6); ctx.restore(); break; }
    case 'crane': { // the gantry's shadow goes on the ground
      ctx.fillStyle = 'rgba(0,0,0,0.35)'; ctx.fillRect(d.x - d.w / 2 + 1.2, d.y - 0.6 + 1.6, d.w, 1.2); ctx.fillRect(d.x - 0.5 + 1.2, d.y - d.h / 2 + 1.6, 1, d.h); break; }
    default: break;
  }
}
function drawTerrainStatic(ctx, t, rng) {
  ctx.save();
  switch (t.type) {
    case 'offroad': { shapeFill(ctx, t, 'rgba(90,70,45,0.45)'); ctx.fillStyle = 'rgba(60,45,30,0.5)'; const b = bounds(t); for (let i = 0; i < b.w * b.h * 0.8; i++) ctx.fillRect(b.x + rng() * b.w, b.y + rng() * b.h, 0.08 + rng() * 0.2, 0.06); break; }
    case 'rubble': { shapeFill(ctx, t, 'rgba(70,68,64,0.9)'); const b = bounds(t); for (let i = 0; i < b.w * b.h * 3; i++) { ctx.fillStyle = i % 2 ? '#5c5a56' : '#3f3d39'; const x = b.x + rng() * b.w, y = b.y + rng() * b.h; if (t.kind === 'circle' && Math.hypot(x - t.x, y - t.y) > t.r) continue; ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(x + 0.2 + rng() * 0.2, y + rng() * 0.1); ctx.lineTo(x + rng() * 0.2, y + 0.15 + rng() * 0.15); ctx.closePath(); ctx.fill(); } break; }
    case 'water': { shapeFill(ctx, t, (t.depth || 1) <= 1.5 ? '#2a4a52' : '#17323a'); ctx.strokeStyle = 'rgba(120,255,160,0.25)'; ctx.lineWidth = 0.08; const b = bounds(t); for (let i = 0; i < 4; i++) { const yy = b.y + b.h * (i + 0.5) / 4; ctx.beginPath(); ctx.moveTo(b.x, yy); for (let x = b.x; x <= b.x + b.w; x += 1) ctx.lineTo(x, yy + Math.sin(x * 1.3 + i) * 0.15); ctx.stroke(); } break; }
    case 'rad': { shapeFill(ctx, t, '#1f3a14'); break; }
    case 'ramp': { ctx.fillStyle = '#6b6450'; ctx.fillRect(t.x, t.y, t.w, t.h); ctx.save(); ctx.translate(t.x + t.w / 2, t.y + t.h / 2); ctx.rotate(t.angle); const L = Math.cos(t.angle) ? t.w : t.h, Wd = Math.cos(t.angle) ? t.h : t.w; ctx.fillStyle = '#ffd02f'; for (let i = -2; i <= 2; i++) { const x = i * 0.3; ctx.beginPath(); ctx.moveTo(x - 0.15, -Wd / 2); ctx.lineTo(x, 0); ctx.lineTo(x - 0.15, Wd / 2); ctx.lineTo(x - 0.3, Wd / 2); ctx.lineTo(x - 0.15, 0); ctx.lineTo(x - 0.3, -Wd / 2); ctx.closePath(); ctx.fill(); } ctx.fillStyle = '#111'; ctx.beginPath(); ctx.moveTo(L / 2 - 0.05, -Wd * 0.3); ctx.lineTo(L / 2 + 0.25, 0); ctx.lineTo(L / 2 - 0.05, Wd * 0.3); ctx.closePath(); ctx.fill(); ctx.restore(); ctx.strokeStyle = OUTLINE; ctx.lineWidth = 0.04; ctx.strokeRect(t.x, t.y, t.w, t.h); break; }
    case 'debris': { const b = bounds(t); for (let i = 0; i < 12; i++) { ctx.fillStyle = ['#3a3a3a', '#6a4a2a', '#555'][i % 3]; ctx.save(); ctx.translate(b.x + rng() * b.w, b.y + rng() * b.h); ctx.rotate(rng() * TAU); ctx.fillRect(-0.12, -0.05, 0.24, 0.1); ctx.restore(); } break; }
    default: break;
  }
  ctx.restore();
}
function bounds(t) { if (t.kind === 'circle') return { x: t.x - t.r, y: t.y - t.r, w: t.r * 2, h: t.r * 2 }; if (t.kind === 'poly') { const xs = t.pts.map((p) => p[0]), ys = t.pts.map((p) => p[1]); return { x: Math.min(...xs), y: Math.min(...ys), w: Math.max(...xs) - Math.min(...xs), h: Math.max(...ys) - Math.min(...ys) }; } return t; }
function shapePath(ctx, s) { if (s.kind === 'circle') { ctx.beginPath(); ctx.arc(s.x, s.y, s.r, 0, TAU); } else if (s.kind === 'poly') poly(ctx, s.pts); else { ctx.beginPath(); ctx.rect(s.x, s.y, s.w, s.h); } }
function shapeFill(ctx, s, color) { ctx.fillStyle = color; shapePath(ctx, s); ctx.fill(); }

// pulsing fallout pools and water shimmer, drawn every frame over the ground
export function drawTerrainLive(ctx, map, time) {
  for (const t of map.terrain || []) {
    if (t.type === 'rad') {
      const pulse = 0.5 + 0.5 * Math.sin(time * 2.2 + (t.id || 0));
      const b = bounds(t), r = (t.r || Math.max(b.w, b.h) / 2);
      const g = ctx.createRadialGradient(t.x ?? b.x + b.w / 2, t.y ?? b.y + b.h / 2, 0, t.x ?? b.x + b.w / 2, t.y ?? b.y + b.h / 2, r * 1.3);
      g.addColorStop(0, `rgba(125,255,58,${0.35 + pulse * 0.3})`); g.addColorStop(0.6, `rgba(90,220,40,${0.15 + pulse * 0.15})`); g.addColorStop(1, 'rgba(60,180,30,0)');
      ctx.fillStyle = g; ctx.beginPath(); ctx.arc(t.x ?? b.x + b.w / 2, t.y ?? b.y + b.h / 2, r * 1.3, 0, TAU); ctx.fill();
    } else if (t.type === 'water') {
      const b = bounds(t);
      ctx.strokeStyle = 'rgba(160,255,200,0.14)'; ctx.lineWidth = 0.05;
      for (let i = 0; i < 3; i++) { const yy = b.y + ((time * 0.3 + i * 0.33) % 1) * b.h; ctx.beginPath(); ctx.moveTo(b.x, yy); for (let x = b.x; x <= b.x + b.w; x += 0.5) ctx.lineTo(x, yy + Math.sin(x * 2 + time * 2) * 0.08); ctx.stroke(); }
    }
  }
}

// ---------------------------------------------------------------- walls and landmarks
function wallHeight(w) { return w.low ? 0.25 : ({ building: 0.9, ruin: 0.5, shop: 0.6, peacewall: 0.7, craneleg: 1.2, titanic: 1.3, cityhall: 1.0, statue: 0.8, clock: 1.4, waterfront: 0.9, tree: 0.5, boulder: 0.3, cliff: 1.0, castle: 1.0, parliament: 1.2, hub: 0.9, tower: 1.1, bonfire: 0.4 }[w.style] || 0.6); }
function drawWallShadow(ctx, w) {
  if (w.breached) return;
  const h = wallHeight(w);
  ctx.save(); ctx.translate(LIGHT[0] * h, LIGHT[1] * h); ctx.fillStyle = SHADOW; ctx.globalAlpha = 0.6; shapePath(ctx, w); ctx.fill(); ctx.restore();
}
export function drawWalls(ctx, walls, time, breachedIds) {
  for (const w of walls) {
    if (breachedIds && breachedIds.has(w.id)) { drawRubble(ctx, w); continue; }
    drawWall(ctx, w, time);
  }
}
function drawRubble(ctx, w) {
  const rng = seeded(w.id * 31 + 7); const b = bounds(w);
  for (let i = 0; i < Math.max(8, b.w * b.h * 4); i++) { ctx.fillStyle = i % 2 ? '#5c5a56' : '#3f3d39'; const x = b.x + rng() * b.w, y = b.y + rng() * b.h; ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(x + 0.2 + rng() * 0.25, y + rng() * 0.1); ctx.lineTo(x + rng() * 0.2, y + 0.15 + rng() * 0.2); ctx.closePath(); ctx.fill(); }
}
function drawWall(ctx, w, time) {
  ctx.save(); ctx.lineJoin = 'round'; ctx.strokeStyle = OUTLINE; ctx.lineWidth = 0.05;
  const dmg = w.maxDp && w.maxDp < 9999 ? 1 - w.dp / w.maxDp : 0;
  switch (w.style) {
    case 'building': { ctx.fillStyle = '#4e5560'; shapePath(ctx, w); ctx.fill(); ctx.stroke(); ctx.fillStyle = '#5b636f'; if (w.kind === 'rect') { ctx.fillRect(w.x + 0.15, w.y + 0.15, w.w - 0.3, w.h - 0.3); ctx.fillStyle = '#3a4049'; for (let i = 0; i < Math.floor(w.w * w.h / 3); i++) ctx.fillRect(w.x + 0.3 + (i * 1.7) % Math.max(0.5, w.w - 0.6), w.y + 0.3 + ((i * 1.1) % Math.max(0.5, w.h - 0.6)), 0.25, 0.25); } break; }
    case 'ruin': { ctx.fillStyle = '#4a4540'; shapePath(ctx, w); ctx.fill(); ctx.stroke(); const rng = seeded(w.id * 13 + 1); const b = bounds(w); ctx.fillStyle = '#2d2a26'; for (let i = 0; i < b.w * b.h * 1.5; i++) { ctx.beginPath(); ctx.arc(b.x + rng() * b.w, b.y + rng() * b.h, 0.1 + rng() * 0.2, 0, TAU); ctx.fill(); } ctx.strokeStyle = '#6a645c'; ctx.lineWidth = 0.04; ctx.strokeRect(b.x + 0.12, b.y + 0.12, b.w - 0.24, b.h - 0.24); break; }
    case 'shop': { ctx.fillStyle = dmg > 0.5 ? '#5a4a3a' : '#6a5a48'; shapePath(ctx, w); ctx.fill(); ctx.stroke(); const b = bounds(w); ctx.fillStyle = '#7d6c58'; ctx.fillRect(b.x + 0.1, b.y + 0.1, b.w - 0.2, b.h - 0.2); ctx.strokeStyle = '#3a3028'; ctx.lineWidth = 0.03; for (let x = b.x + 0.4; x < b.x + b.w; x += 0.6) { ctx.beginPath(); ctx.moveTo(x, b.y + 0.1); ctx.lineTo(x, b.y + b.h - 0.1); ctx.stroke(); } if (dmg > 0) { ctx.fillStyle = 'rgba(20,15,10,0.6)'; ctx.fillRect(b.x, b.y, b.w * dmg, b.h); } break; }
    case 'lowwall': { ctx.fillStyle = '#7a7a72'; shapePath(ctx, w); ctx.fill(); ctx.stroke(); break; }
    case 'barrier': { ctx.fillStyle = '#9a9a92'; shapePath(ctx, w); ctx.fill(); ctx.stroke(); const b = bounds(w); ctx.fillStyle = '#d33'; for (let i = 0; i < 3; i++) ctx.fillRect(b.x, b.y + b.h * (i * 2 + 0.5) / 6, b.w, b.h / 6); break; }
    case 'lamp': { ctx.fillStyle = '#333'; ctx.beginPath(); ctx.arc(w.x, w.y, w.r, 0, TAU); ctx.fill(); ctx.stroke(); ctx.strokeStyle = 'rgba(0,0,0,0.4)'; ctx.lineWidth = 0.06; ctx.beginPath(); ctx.moveTo(w.x, w.y); ctx.lineTo(w.x + 0.5, w.y + 0.7); ctx.stroke(); break; }
    case 'tree': { ctx.fillStyle = '#4a3a2a'; ctx.beginPath(); ctx.arc(w.x, w.y, w.r, 0, TAU); ctx.fill(); ctx.stroke(); ctx.strokeStyle = '#2a1f14'; ctx.lineWidth = 0.05; for (let i = 0; i < 5; i++) { const a = i * 1.26 + w.x; ctx.beginPath(); ctx.moveTo(w.x, w.y); ctx.lineTo(w.x + Math.cos(a) * w.r * 1.3, w.y + Math.sin(a) * w.r * 1.3); ctx.stroke(); } break; }
    case 'peacewall': { ctx.fillStyle = '#5a5e66'; shapePath(ctx, w); ctx.fill(); ctx.stroke(); const b = bounds(w); ctx.strokeStyle = '#3a3e46'; ctx.lineWidth = 0.03; const vert = b.h > b.w; for (let k = 0.15; k < (vert ? b.h : b.w); k += 0.3) { ctx.beginPath(); if (vert) { ctx.moveTo(b.x, b.y + k); ctx.lineTo(b.x + b.w, b.y + k); } else { ctx.moveTo(b.x + k, b.y); ctx.lineTo(b.x + k, b.y + b.h); } ctx.stroke(); } break; }
    case 'wreck': { ctx.save(); ctx.translate(w.x + w.w / 2, w.y + w.h / 2); ctx.fillStyle = '#2a2a2a'; rrect(ctx, -w.w / 2, -w.h / 2, w.w, w.h, 0.08); ctx.fill(); ctx.stroke(); ctx.fillStyle = '#111'; rrect(ctx, -w.w * 0.25, -w.h * 0.35, w.w * 0.4, w.h * 0.7, 0.04); ctx.fill(); ctx.restore(); break; }
    case 'craneleg': { ctx.fillStyle = '#f5c400'; ctx.fillRect(w.x - w.r, w.y - w.r, w.r * 2, w.r * 2); ctx.strokeRect(w.x - w.r, w.y - w.r, w.r * 2, w.r * 2); ctx.strokeStyle = '#8a6d00'; ctx.lineWidth = 0.04; ctx.beginPath(); ctx.moveTo(w.x - w.r, w.y - w.r); ctx.lineTo(w.x + w.r, w.y + w.r); ctx.moveTo(w.x + w.r, w.y - w.r); ctx.lineTo(w.x - w.r, w.y + w.r); ctx.stroke(); break; }
    case 'titanic': { // four hull prows as a star of shards
      ctx.save(); ctx.translate(w.x, w.y); ctx.fillStyle = '#9aa7b5'; for (let i = 0; i < 4; i++) { ctx.save(); ctx.rotate(i * Math.PI / 2 + Math.PI / 4); poly(ctx, [[0, 0], [w.r * 0.45, -w.r * 0.95], [w.r * 1.05, 0], [w.r * 0.45, w.r * 0.95]]); ctx.fill(); ctx.stroke(); ctx.fillStyle = '#c7d2dd'; poly(ctx, [[w.r * 0.2, -w.r * 0.1], [w.r * 0.5, -w.r * 0.7], [w.r * 0.9, 0]]); ctx.fill(); ctx.fillStyle = '#9aa7b5'; ctx.restore(); } ctx.fillStyle = '#2b3340'; ctx.beginPath(); ctx.arc(0, 0, w.r * 0.35, 0, TAU); ctx.fill(); ctx.stroke(); ctx.restore(); break; }
    case 'cityhall': { ctx.fillStyle = '#8f9a8a'; shapePath(ctx, w); ctx.fill(); ctx.stroke(); ctx.fillStyle = '#a9b5a4'; ctx.fillRect(w.x + 0.2, w.y + 0.2, w.w - 0.4, w.h - 0.4); ctx.fillStyle = '#5f7a66'; for (const [cx, cy] of [[w.x + 0.5, w.y + 0.5], [w.x + w.w - 0.5, w.y + 0.5], [w.x + 0.5, w.y + w.h - 0.5], [w.x + w.w - 0.5, w.y + w.h - 0.5]]) { ctx.beginPath(); ctx.arc(cx, cy, 0.35, 0, TAU); ctx.fill(); ctx.stroke(); } break; }
    case 'statue': { ctx.fillStyle = '#6d6a60'; ctx.beginPath(); ctx.arc(w.x, w.y, w.r, 0, TAU); ctx.fill(); ctx.stroke(); ctx.fillStyle = '#3f5a4a'; ctx.beginPath(); ctx.arc(w.x, w.y, w.r * 0.45, 0, TAU); ctx.fill(); break; }
    case 'clock': { ctx.save(); ctx.translate(w.x, w.y); ctx.rotate(0.15); ctx.fillStyle = '#8a7a5a'; ctx.fillRect(-w.r, -w.r, w.r * 2, w.r * 2); ctx.strokeRect(-w.r, -w.r, w.r * 2, w.r * 2); ctx.fillStyle = '#eee'; ctx.beginPath(); ctx.arc(0, 0, w.r * 0.55, 0, TAU); ctx.fill(); ctx.stroke(); ctx.strokeStyle = '#000'; ctx.lineWidth = 0.04; ctx.beginPath(); ctx.moveTo(0, 0); ctx.lineTo(0, -w.r * 0.4); ctx.moveTo(0, 0); ctx.lineTo(w.r * 0.3, w.r * 0.2); ctx.stroke(); ctx.restore(); break; }
    case 'waterfront': { ctx.fillStyle = '#5c6b7a'; ctx.beginPath(); ctx.arc(w.x, w.y, w.r, 0, TAU); ctx.fill(); ctx.stroke(); ctx.fillStyle = '#7d8c9a'; ctx.beginPath(); ctx.arc(w.x, w.y, w.r * 0.7, 0, TAU); ctx.fill(); ctx.stroke(); ctx.fillStyle = '#3b4a58'; ctx.beginPath(); ctx.arc(w.x, w.y, w.r * 0.3, 0, TAU); ctx.fill(); break; }
    case 'bigfish': { ctx.save(); ctx.translate(w.x + w.w / 2, w.y + w.h / 2); ctx.fillStyle = '#3b7cc9'; poly(ctx, [[-w.w / 2, 0], [-w.w * 0.3, -w.h / 2], [w.w * 0.25, -w.h * 0.45], [w.w * 0.4, 0], [w.w * 0.25, w.h * 0.45], [-w.w * 0.3, w.h / 2]]); ctx.fill(); ctx.stroke(); ctx.fillStyle = '#2a5a9a'; poly(ctx, [[w.w * 0.3, 0], [w.w / 2, -w.h / 2], [w.w / 2, w.h / 2]]); ctx.fill(); ctx.stroke(); ctx.fillStyle = '#9fd0ff'; for (let i = 0; i < 12; i++) ctx.fillRect(-w.w * 0.45 + (i % 6) * w.w * 0.12, -w.h * 0.3 + Math.floor(i / 6) * w.h * 0.4, 0.08, 0.08); ctx.fillStyle = '#fff'; ctx.beginPath(); ctx.arc(-w.w * 0.3, -w.h * 0.1, 0.06, 0, TAU); ctx.fill(); ctx.restore(); break; }
    case 'bonfire': { ctx.fillStyle = '#6a4a2a'; for (let i = 0; i < 6; i++) { ctx.save(); ctx.translate(w.x, w.y); ctx.rotate(i * 1.05); ctx.fillRect(-w.r * 0.8, -0.08, w.r * 1.6, 0.16); ctx.strokeRect(-w.r * 0.8, -0.08, w.r * 1.6, 0.16); ctx.restore(); } if (dmg < 1) { const p = 0.6 + 0.4 * Math.sin(time * 9 + w.x); const g = ctx.createRadialGradient(w.x, w.y, 0, w.x, w.y, w.r * 1.3 * p); g.addColorStop(0, 'rgba(255,220,120,0.9)'); g.addColorStop(0.4, 'rgba(255,120,30,0.6)'); g.addColorStop(1, 'rgba(255,60,0,0)'); ctx.fillStyle = g; ctx.beginPath(); ctx.arc(w.x, w.y, w.r * 1.3 * p, 0, TAU); ctx.fill(); } break; }
    case 'boulder': { const rng = seeded(w.x * 100 + w.y); ctx.fillStyle = '#6e6a62'; ctx.beginPath(); for (let i = 0; i < 9; i++) { const a = i / 9 * TAU, r = w.r * (0.8 + rng() * 0.3); i ? ctx.lineTo(w.x + Math.cos(a) * r, w.y + Math.sin(a) * r) : ctx.moveTo(w.x + Math.cos(a) * r, w.y + Math.sin(a) * r); } ctx.closePath(); ctx.fill(); ctx.stroke(); ctx.fillStyle = '#8a857c'; ctx.beginPath(); ctx.arc(w.x - w.r * 0.25, w.y - w.r * 0.25, w.r * 0.35, 0, TAU); ctx.fill(); break; }
    case 'cliff': { ctx.fillStyle = '#3d3a33'; shapePath(ctx, w); ctx.fill(); ctx.stroke(); ctx.strokeStyle = '#2a2822'; ctx.lineWidth = 0.05; const b = bounds(w); for (let i = 0; i < 20; i++) { const x = b.x + (i / 20) * b.w; ctx.beginPath(); ctx.moveTo(x, b.y); ctx.lineTo(x + 0.4, b.y + b.h * 0.7); ctx.stroke(); } ctx.fillStyle = '#5a5648'; ctx.fillRect(b.x + 0.2, b.y, b.w - 0.4, 0.5); break; }
    case 'castle': { ctx.fillStyle = '#7a6f5a'; shapePath(ctx, w); ctx.fill(); ctx.stroke(); ctx.fillStyle = '#5a5040'; for (let x = w.x; x < w.x + w.w; x += 0.5) { ctx.fillRect(x, w.y, 0.25, 0.25); ctx.fillRect(x, w.y + w.h - 0.25, 0.25, 0.25); } ctx.fillStyle = '#8a7f6a'; ctx.fillRect(w.x + 0.4, w.y + 0.4, w.w - 0.8, w.h - 0.8); break; }
    case 'parliament': { ctx.fillStyle = '#d8d2c4'; shapePath(ctx, w); ctx.fill(); ctx.stroke(); ctx.fillStyle = '#b9b2a2'; ctx.fillRect(w.x + 0.3, w.y + 0.3, w.w - 0.6, w.h - 0.6); ctx.fillStyle = '#efe9da'; for (let y = w.y + 0.5; y < w.y + w.h - 0.3; y += 0.7) { ctx.beginPath(); ctx.arc(w.x + 0.15, y, 0.12, 0, TAU); ctx.fill(); ctx.stroke(); } ctx.fillStyle = '#6b655a'; ctx.fillRect(w.x + w.w / 2 - 0.6, w.y + w.h / 2 - 0.6, 1.2, 1.2); ctx.strokeRect(w.x + w.w / 2 - 0.6, w.y + w.h / 2 - 0.6, 1.2, 1.2); break; }
    case 'hub': { ctx.fillStyle = '#6a5f4f'; ctx.beginPath(); ctx.arc(w.x, w.y, w.r, 0, TAU); ctx.fill(); ctx.stroke(); ctx.fillStyle = '#4a4238'; ctx.beginPath(); ctx.arc(w.x, w.y, w.r * 0.5, 0, TAU); ctx.fill(); ctx.stroke(); break; }
    case 'tower': { ctx.fillStyle = '#5a5e66'; ctx.beginPath(); ctx.arc(w.x, w.y, w.r, 0, TAU); ctx.fill(); ctx.stroke(); ctx.fillStyle = '#2a2e36'; ctx.beginPath(); ctx.arc(w.x, w.y, w.r * 0.5, 0, TAU); ctx.fill(); break; }
    default: { ctx.fillStyle = '#555'; shapePath(ctx, w); ctx.fill(); ctx.stroke(); break; }
  }
  ctx.restore();
}
// things that are above the cars: the gantry cranes
export function drawOverhead(ctx, map, time) {
  for (const d of map.deco || []) {
    if (d.type !== 'crane') continue;
    ctx.save(); ctx.strokeStyle = OUTLINE; ctx.lineWidth = 0.06; ctx.lineJoin = 'round';
    ctx.fillStyle = '#f5c400';
    ctx.fillRect(d.x - d.w / 2, d.y - 0.6, d.w, 1.2); ctx.strokeRect(d.x - d.w / 2, d.y - 0.6, d.w, 1.2);
    ctx.fillRect(d.x - 0.5, d.y - d.h / 2, 1, d.h); ctx.strokeRect(d.x - 0.5, d.y - d.h / 2, 1, d.h);
    ctx.strokeStyle = '#8a6d00'; ctx.lineWidth = 0.04;
    for (let x = d.x - d.w / 2 + 0.3; x < d.x + d.w / 2; x += 0.6) { ctx.beginPath(); ctx.moveTo(x, d.y - 0.6); ctx.lineTo(x + 0.3, d.y + 0.6); ctx.stroke(); }
    for (let y = d.y - d.h / 2 + 0.3; y < d.y + d.h / 2; y += 0.6) { ctx.beginPath(); ctx.moveTo(d.x - 0.5, y); ctx.lineTo(d.x + 0.5, y + 0.3); ctx.stroke(); }
    ctx.fillStyle = '#111'; ctx.font = 'bold 0.9px Impact, "Arial Narrow Bold", sans-serif'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
    ctx.fillText('H&W', d.x - d.w / 2 + 1.6, d.y); ctx.fillText('H&W', d.x + d.w / 2 - 1.6, d.y);
    ctx.save(); ctx.translate(d.x, d.y + d.h / 2 - 1.2); ctx.rotate(-Math.PI / 2); ctx.font = 'bold 0.7px Impact, "Arial Narrow Bold", sans-serif'; ctx.fillText(d.label, 0, 0); ctx.restore();
    // a warning light on top
    ctx.fillStyle = `rgba(255,40,40,${0.4 + 0.6 * Math.max(0, Math.sin(time * 3))})`; ctx.beginPath(); ctx.arc(d.x, d.y, 0.18, 0, TAU); ctx.fill();
    ctx.restore();
  }
}

// ---------------------------------------------------------------- dropped counters
export function drawCounter(ctx, c, time) {
  ctx.save(); ctx.translate(c.x, c.y); ctx.rotate(c.angle || 0);
  const w = c.w, h = c.h;
  switch (c.type) {
    case 'oil': { ctx.fillStyle = 'rgba(20,18,30,0.85)'; ctx.beginPath(); ctx.ellipse(0, 0, w / 2, h / 2, 0, 0, TAU); ctx.fill(); ctx.strokeStyle = `rgba(${120 + 60 * Math.sin(time * 2)},80,200,0.5)`; ctx.lineWidth = 0.04; ctx.beginPath(); ctx.ellipse(0, 0, w / 2.6, h / 2.8, 0, 0, TAU); ctx.stroke(); break; }
    case 'flamingoil': { ctx.fillStyle = 'rgba(40,20,10,0.9)'; ctx.beginPath(); ctx.ellipse(0, 0, w / 2, h / 2, 0, 0, TAU); ctx.fill(); const p = 0.7 + 0.3 * Math.sin(time * 11 + c.id); const g = ctx.createRadialGradient(0, 0, 0, 0, 0, w / 2 * p); g.addColorStop(0, 'rgba(255,230,120,0.9)'); g.addColorStop(0.5, 'rgba(255,110,20,0.7)'); g.addColorStop(1, 'rgba(255,40,0,0)'); ctx.fillStyle = g; ctx.beginPath(); ctx.ellipse(0, 0, w / 2 * p, h / 2 * p * 1.3, 0, 0, TAU); ctx.fill(); break; }
    case 'smoke': { const f = c.ttl < 0 ? 1 : Math.min(1, c.ttl / 3); for (let i = 0; i < 5; i++) { ctx.fillStyle = `rgba(150,150,155,${0.35 * f})`; ctx.beginPath(); ctx.arc((i - 2) * w / 5 + Math.sin(time + i) * 0.05, Math.cos(time * 0.7 + i) * 0.06, h * 0.55, 0, TAU); ctx.fill(); } break; }
    case 'paint': { for (let i = 0; i < 5; i++) { ctx.fillStyle = 'rgba(255,0,180,0.4)'; ctx.beginPath(); ctx.arc((i - 2) * w / 5, 0, h * 0.5, 0, TAU); ctx.fill(); } break; }
    case 'mines': case 'spearmines': { ctx.fillStyle = 'rgba(0,0,0,0.3)'; ctx.beginPath(); ctx.ellipse(0, 0, w / 2, h / 2, 0, 0, TAU); ctx.fill(); ctx.fillStyle = c.type === 'mines' ? '#4a4a50' : '#6a3a3a'; for (let i = 0; i < 3; i++) { const a = i * 2.1, r = w * 0.25; ctx.beginPath(); ctx.arc(Math.cos(a) * r, Math.sin(a) * r, 0.07, 0, TAU); ctx.fill(); ctx.strokeStyle = OUTLINE; ctx.lineWidth = 0.02; ctx.stroke(); ctx.fillStyle = `rgba(255,40,40,${0.3 + 0.7 * Math.max(0, Math.sin(time * 4 + i))})`; ctx.beginPath(); ctx.arc(Math.cos(a) * r, Math.sin(a) * r, 0.025, 0, TAU); ctx.fill(); ctx.fillStyle = c.type === 'mines' ? '#4a4a50' : '#6a3a3a'; } break; }
    case 'spikes': { ctx.fillStyle = '#999'; ctx.strokeStyle = OUTLINE; ctx.lineWidth = 0.015; for (let i = 0; i < 8; i++) { const x = (i % 4 - 1.5) * w / 4, y = (Math.floor(i / 4) - 0.5) * h / 2; poly(ctx, [[x - 0.05, y + 0.05], [x + 0.05, y + 0.05], [x, y - 0.06]]); ctx.fill(); ctx.stroke(); } break; }
    case 'debris': { ctx.fillStyle = '#4a4744'; for (let i = 0; i < 7; i++) { ctx.save(); ctx.translate((i % 4 - 1.5) * w / 4, (Math.floor(i / 4) - 0.5) * h / 2); ctx.rotate(i * 0.9); ctx.fillRect(-0.1, -0.04, 0.2, 0.08); ctx.restore(); } break; }
    default: break;
  }
  ctx.restore();
}

// ---------------------------------------------------------------- previews for the lobby
export function drawCarPreview(canvas, def, color) {
  const ctx = canvas.getContext('2d');
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  const px = canvas.width / 2.2;
  ctx.save(); ctx.fillStyle = '#1a1f27'; ctx.fillRect(0, 0, canvas.width, canvas.height);
  ctx.translate(canvas.width / 2, canvas.height / 2); ctx.scale(px, px); ctx.rotate(-0.35);
  const body = def.body;
  const fake = { id: 1, len: ['lightcycle', 'medcycle', 'hvycycle'].includes(body) ? 0.5 : 1, wid: ['lightcycle', 'medcycle', 'hvycycle'].includes(body) ? 0.25 : 0.5, kind: def.kind || 'car', style: def.style, color, status: 'alive', armor: def.armor, armorMax: def.armor, weapons: def.weapons.map((w, i) => ({ id: i, w: w.w, side: w.side, dp: 1, type: w.type })), turret: def.weapons.some((w) => w.side === 'T'), turretAngle: 0.4, tires: def.tires, z: 0, rollAngle: 0 };
  drawCar(ctx, fake, {}); ctx.restore();
}
export function drawMapPreview(canvas, map) {
  const ctx = canvas.getContext('2d');
  const px = Math.min(canvas.width / map.width, canvas.height / map.height);
  ctx.fillStyle = '#0e1116'; ctx.fillRect(0, 0, canvas.width, canvas.height);
  const ground = renderGround(map, Math.max(6, px));
  ctx.save(); ctx.translate((canvas.width - map.width * px) / 2, (canvas.height - map.height * px) / 2);
  ctx.drawImage(ground, 0, 0, map.width * px, map.height * px);
  ctx.scale(px, px);
  drawTerrainLive(ctx, map, 1);
  drawWalls(ctx, map.walls.map((w, i) => ({ ...w, id: i, maxDp: w.dp ?? 9999, dp: w.dp ?? 9999 })), 1, null);
  drawOverhead(ctx, map, 1);
  for (const s of map.spawns) { ctx.save(); ctx.translate(s.x, s.y); ctx.rotate(s.heading); ctx.fillStyle = '#ffd02f'; poly(ctx, [[0.5, 0], [-0.3, -0.3], [-0.3, 0.3]]); ctx.fill(); ctx.restore(); }
  ctx.restore();
}
