// Car Carnage: Belfast Edition - the arenas. Post-nuclear Belfast, one inch = 15 feet.
// walls: solid things cars crash into (dp = damage points before it breaches; dm = how hard it hits back).
// terrain: ground that changes the driving (offroad, water, rad pools, ramps, rubble, debris).
// deco: landmarks and ground art drawn by the client.

const R = (x, y, w, h, extra = {}) => ({ kind: 'rect', x, y, w, h, ...extra });
const C = (x, y, r, extra = {}) => ({ kind: 'circle', x, y, r, ...extra });
const P = (pts, extra = {}) => ({ kind: 'poly', pts, ...extra });
const S = (x, y, deg) => ({ x, y, heading: deg * Math.PI / 180 });

const BUILDING = { dp: 9999, dm: 20, style: 'building' };
const RUIN = { dp: 40, dm: 4, style: 'ruin' };
const SHOP = { dp: 30, dm: 3, style: 'shop' };
const LOW = { dp: 20, dm: 2, style: 'lowwall', low: true };
const BARRIER = { dp: 25, dm: 3, style: 'barrier', low: true };
const LAMP = { dp: 8, dm: 0.34, style: 'lamp', low: true };
const TREE = { dp: 20, dm: 1, style: 'tree' };
const PEACEWALL = { dp: 80, dm: 8, style: 'peacewall' };
const WRECK = { dp: 35, dm: 2, style: 'wreck', low: true };

function ring(x, y, r, n, extra) { const out = []; for (let i = 0; i < n; i++) { const a = i / n * Math.PI * 2; out.push(C(x + Math.cos(a) * r, y + Math.sin(a) * r, 0.3, extra)); } return out; }
function row(x, y, w, h, n, gap, extra, vertical = false) { const out = []; for (let i = 0; i < n; i++) out.push(vertical ? R(x, y + i * (h + gap), w, h, extra) : R(x + i * (w + gap), y, w, h, extra)); return out; }
function lamps(x1, y1, x2, y2, n) { const out = []; for (let i = 0; i < n; i++) { const t = n === 1 ? 0 : i / (n - 1); out.push(C(x1 + (x2 - x1) * t, y1 + (y2 - y1) * t, 0.12, { ...LAMP, name: 'lamp post' })); } return out; }

export const MAPS = [
  {
    id: 'titanic', name: 'Titanic Quarter', tagline: 'The shipyard. Samson and Goliath still stand over the slipways. The dry dock is a jump now.',
    width: 44, height: 32, theme: 'dock',
    spawns: [S(4, 4, 0), S(40, 4, 180), S(4, 28, 0), S(40, 28, 180), S(14, 4.5, 0), S(30, 4.5, 180), S(7, 15, 0), S(37, 15, 180)],
    walls: [
      // Samson (west) and Goliath (east): four legs each, the beam overhead is decoration you drive under
      C(9, 10, 0.55, { ...BUILDING, name: 'Samson leg', style: 'craneleg' }), C(9, 20, 0.55, { ...BUILDING, name: 'Samson leg', style: 'craneleg' }),
      C(15, 10, 0.55, { ...BUILDING, name: 'Samson leg', style: 'craneleg' }), C(15, 20, 0.55, { ...BUILDING, name: 'Samson leg', style: 'craneleg' }),
      C(29, 10, 0.55, { ...BUILDING, name: 'Goliath leg', style: 'craneleg' }), C(29, 20, 0.55, { ...BUILDING, name: 'Goliath leg', style: 'craneleg' }),
      C(35, 10, 0.55, { ...BUILDING, name: 'Goliath leg', style: 'craneleg' }), C(35, 20, 0.55, { ...BUILDING, name: 'Goliath leg', style: 'craneleg' }),
      // Titanic Belfast: the shard building
      C(22, 15.5, 2.6, { ...BUILDING, name: 'Titanic Belfast', style: 'titanic' }),
      // shipyard sheds and the pump house
      R(2, 10, 3, 10, { ...RUIN, name: 'paint hall' }), R(39, 10, 3, 10, { ...RUIN, name: 'pump house' }),
      R(17, 1, 10, 1.2, { ...SHOP, name: 'drawing offices' }), R(17, 29.8, 10, 1.2, { ...SHOP, name: 'drawing offices' }),
      // dry dock walls (low) along its long edges
      R(12, 24.5, 20, 0.3, { ...LOW, name: 'dock edge' }), R(12, 27.2, 20, 0.3, { ...LOW, name: 'dock edge' }),
      // crates and containers
      R(6, 5, 1.5, 0.8, { ...WRECK, name: 'container' }), R(36.5, 5, 1.5, 0.8, { ...WRECK, name: 'container' }),
      R(6, 26, 1.5, 0.8, { ...WRECK, name: 'container' }), R(36.5, 26, 1.5, 0.8, { ...WRECK, name: 'container' }),
      ...lamps(4, 8, 40, 8, 7),
    ],
    terrain: [
      R(12, 24.8, 20, 2.4, { type: 'water', id: 1, depth: 3 }),                // the flooded Thompson dry dock
      R(10.5, 24.6, 1.5, 2.8, { type: 'ramp', id: 1, angle: 0 }),              // jump it from the west...
      R(32, 24.6, 1.5, 2.8, { type: 'ramp', id: 2, angle: Math.PI }),          // ...or the east
      C(22, 8, 1.6, { type: 'rad', id: 1 }),                                    // where the reactor ship went up
      R(0, 29.5, 44, 2.5, { type: 'offroad', id: 2 }),                          // the mud flats
      R(20, 11, 4, 1.5, { type: 'rubble', id: 3 }),
    ],
    deco: [
      { type: 'crane', x: 12, y: 15, w: 7.2, h: 11, label: 'SAMSON' }, { type: 'crane', x: 32, y: 15, w: 7.2, h: 11, label: 'GOLIATH' },
      { type: 'slipway', x: 12, y: 2.5, w: 20, h: 6 }, { type: 'road', pts: [[0, 8.5], [44, 8.5]], w: 2.2 }, { type: 'road', pts: [[0, 22.5], [44, 22.5]], w: 2.2 },
      { type: 'road', pts: [[22, 0], [22, 32]], w: 2 }, { type: 'text', x: 22, y: 26, text: 'THOMPSON DRY DOCK', size: 0.6 },
      { type: 'shipwreck', x: 38, y: 30.5 },
    ],
  },
  {
    id: 'cityhall', name: 'City Hall Crater', tagline: 'Donegall Square. Half the dome is gone and the other half is in the crater.',
    width: 40, height: 30, theme: 'city',
    spawns: [S(3, 3, 0), S(37, 3, 180), S(3, 27, 0), S(37, 27, 180), S(20, 2, 90), S(20, 28, 270), S(2, 15, 0), S(38, 15, 180)],
    walls: [
      // City Hall: the surviving east wing, the collapsed west wing
      R(21, 11.5, 6, 7, { ...BUILDING, name: 'City Hall', style: 'cityhall' }), R(14, 11.5, 6, 2, { ...RUIN, name: 'City Hall west wing' }), R(14, 16.5, 6, 2, { ...RUIN, name: 'City Hall west wing' }),
      // the square's surrounding blocks
      R(2, 7, 8, 3, { ...SHOP, name: 'Robinson & Cleaver' }), R(30, 7, 8, 3, { ...SHOP, name: 'Scottish Provident' }),
      R(2, 20, 8, 3, { ...SHOP, name: 'Linen Hall Library' }), R(30, 20, 8, 3, { ...SHOP, name: 'Ten Square' }),
      R(12, 2, 5, 2, { ...BUILDING, name: 'Donegall Place block' }), R(23, 2, 5, 2, { ...BUILDING, name: 'Donegall Place block' }),
      R(12, 26, 5, 2, { ...BUILDING, name: 'Bedford Street block' }), R(23, 26, 5, 2, { ...BUILDING, name: 'Bedford Street block' }),
      // bus shelters and the Titanic memorial
      R(11, 12, 0.4, 2, { ...BARRIER, name: 'bus shelter' }), R(28.6, 16, 0.4, 2, { ...BARRIER, name: 'bus shelter' }),
      C(20, 22.5, 0.4, { ...BUILDING, name: 'Titanic memorial', style: 'statue' }), C(20, 7.5, 0.4, { ...BUILDING, name: 'Queen Victoria', style: 'statue' }),
      R(5, 14.5, 1.2, 0.6, { ...WRECK, name: 'burnt-out black taxi' }), R(33, 14.5, 1.2, 0.6, { ...WRECK, name: 'burnt-out Glider' }),
      ...lamps(11, 5.5, 29, 5.5, 5), ...lamps(11, 24.5, 29, 24.5, 5),
    ],
    terrain: [
      C(17, 15, 2.6, { type: 'rubble', id: 1 }), C(17, 15, 1.2, { type: 'rad', id: 2 }),
      R(12, 11, 2, 8, { type: 'offroad', id: 3 }), R(28, 11, 2, 8, { type: 'offroad', id: 4 }),
      R(4.5, 11, 1.4, 1, { type: 'ramp', id: 5, angle: 0 }), R(34, 18, 1.4, 1, { type: 'ramp', id: 6, angle: Math.PI }),
    ],
    deco: [
      { type: 'road', pts: [[0, 5.5], [40, 5.5]], w: 2.4 }, { type: 'road', pts: [[0, 24.5], [40, 24.5]], w: 2.4 },
      { type: 'road', pts: [[11, 0], [11, 30]], w: 2 }, { type: 'road', pts: [[29, 0], [29, 30]], w: 2 },
      { type: 'road', pts: [[0, 15], [40, 15]], w: 1.6 }, { type: 'road', pts: [[20, 0], [20, 30]], w: 1.6 },
      { type: 'crater', x: 17, y: 15, r: 2.8 }, { type: 'dome', x: 24, y: 15, r: 1.6 }, { type: 'text', x: 20, y: 10.5, text: 'DONEGALL SQUARE', size: 0.5 },
      { type: 'lawn', x: 12, y: 11, w: 2, h: 8 }, { type: 'lawn', x: 28, y: 11, w: 2, h: 8 },
    ],
  },
  {
    id: 'lagan', name: 'Lagan Weir', tagline: 'The river glows now. Two bridges, one of them in bits. Mind the Big Fish.',
    width: 44, height: 30, theme: 'river',
    spawns: [S(3, 3, 0), S(41, 3, 180), S(3, 27, 0), S(41, 27, 180), S(14, 2.5, 90), S(30, 2.5, 90), S(14, 27.5, 270), S(30, 27.5, 270)],
    walls: [
      // Queen's Bridge (west), with low parapets
      R(10, 11, 0.3, 8, { ...LOW, name: 'bridge parapet' }), R(14, 11, 0.3, 8, { ...LOW, name: 'bridge parapet' }),
      // the broken Lagan Weir footbridge (east): two stubs with a gap
      R(30, 11, 0.3, 2.6, { ...LOW, name: 'bridge parapet' }), R(33.5, 11, 0.3, 2.6, { ...LOW, name: 'bridge parapet' }),
      R(30, 16.4, 0.3, 2.6, { ...LOW, name: 'bridge parapet' }), R(33.5, 16.4, 0.3, 2.6, { ...LOW, name: 'bridge parapet' }),
      // the Big Fish and the Albert Clock
      R(19, 8.6, 2.4, 0.6, { dp: 30, dm: 2, style: 'bigfish', name: 'the Big Fish', low: true }),
      C(6, 7.5, 0.55, { ...BUILDING, name: 'Albert Clock', style: 'clock' }),
      // Waterfront Hall, Custom House, the Obel
      C(37, 24, 2.4, { ...BUILDING, name: 'Waterfront Hall', style: 'waterfront' }), R(2, 20, 5, 3, { ...SHOP, name: 'Custom House' }),
      R(37, 2, 3, 3, { ...BUILDING, name: 'the Obel' }), R(16, 21, 6, 2, { ...RUIN, name: 'Lanyon Place' }), R(22, 2, 6, 2, { ...RUIN, name: 'Donegall Quay sheds' }),
      // quay bollards
      ...ring(22, 15, 0, 0, LAMP), ...lamps(1, 9.5, 43, 9.5, 8), ...lamps(1, 20.5, 43, 20.5, 8),
      R(26, 24.5, 1.2, 0.6, { ...WRECK, name: 'burnt-out Glider' }),
    ],
    terrain: [
      R(0, 11, 10, 8, { type: 'water', id: 1, depth: 3 }), R(14.3, 11, 15.7, 8, { type: 'water', id: 2, depth: 3 }), R(33.8, 11, 10.2, 8, { type: 'water', id: 3, depth: 3 }),
      R(30.3, 13.6, 3.2, 2.8, { type: 'water', id: 4, depth: 3 }),
      R(30.3, 11.2, 3.2, 2.4, { type: 'ramp', id: 5, angle: Math.PI / 2 }), R(30.3, 16.4, 3.2, 2.4, { type: 'ramp', id: 6, angle: -Math.PI / 2 }),
      C(22, 11.5, 1.5, { type: 'rad', id: 7 }), C(22, 18.5, 1.5, { type: 'rad', id: 8 }),
      R(16, 9.5, 12, 1.5, { type: 'offroad', id: 9 }),
    ],
    deco: [
      { type: 'river', x: 0, y: 11, w: 44, h: 8 }, { type: 'bridge', x: 10, y: 11, w: 4.3, h: 8 }, { type: 'bridge', x: 30, y: 11, w: 3.8, h: 2.6 }, { type: 'bridge', x: 30, y: 16.4, w: 3.8, h: 2.6 },
      { type: 'weir', x: 22, y: 11, h: 8 }, { type: 'road', pts: [[0, 9.5], [44, 9.5]], w: 2.2 }, { type: 'road', pts: [[0, 20.5], [44, 20.5]], w: 2.2 },
      { type: 'road', pts: [[12, 0], [12, 30]], w: 2.4 }, { type: 'road', pts: [[32, 0], [32, 30]], w: 2 },
      { type: 'text', x: 22, y: 15, text: 'RIVER LAGAN', size: 0.8, river: true },
    ],
  },
  {
    id: 'peaceline', name: 'Peace Line', tagline: 'Terraces, waste ground and a wall with three gates. Drive through the houses if you must.',
    width: 40, height: 30, theme: 'terraces',
    spawns: [S(3, 4, 0), S(37, 4, 180), S(3, 26, 0), S(37, 26, 180), S(3, 17.5, 0), S(37, 17.5, 180), S(12, 2, 0), S(28, 28, 180)],
    walls: [
      // the peace wall across the middle with three gates
      R(19.5, 0, 1, 6, PEACEWALL), R(19.5, 8.5, 1, 8, PEACEWALL), R(19.5, 19, 1, 6, PEACEWALL), R(19.5, 27.5, 1, 2.5, PEACEWALL),
      // gate barriers
      R(18.5, 6.2, 0.3, 1, BARRIER), R(21.2, 7.3, 0.3, 1, BARRIER), R(18.5, 16.8, 0.3, 1, BARRIER), R(21.2, 17.8, 0.3, 1, BARRIER), R(18.5, 25.2, 0.3, 1, BARRIER), R(21.2, 26.3, 0.3, 1, BARRIER),
      // terraces (breachable houses) in rows
      ...row(4, 7, 1.5, 1.2, 7, 0.2, { ...SHOP, name: 'terrace', dp: 25 }), ...row(4, 21, 1.5, 1.2, 7, 0.2, { ...SHOP, name: 'terrace', dp: 25 }),
      ...row(24, 7, 1.5, 1.2, 7, 0.2, { ...SHOP, name: 'terrace', dp: 25 }), ...row(24, 21, 1.5, 1.2, 7, 0.2, { ...SHOP, name: 'terrace', dp: 25 }),
      R(2, 12, 5, 3, { ...RUIN, name: 'the chapel' }), R(33, 12, 5, 3, { ...RUIN, name: 'the mission hall' }),
      R(9, 13.5, 3, 1.2, { ...WRECK, name: 'burnt-out bus' }), R(28, 15.2, 3, 1.2, { ...WRECK, name: 'burnt-out bus' }),
      C(13, 16, 1.0, { dp: 15, dm: 1, style: 'bonfire', name: 'the bonfire', low: true }), C(27, 11, 1.0, { dp: 15, dm: 1, style: 'bonfire', name: 'the bonfire', low: true }),
      ...lamps(2, 10, 18, 10, 4), ...lamps(22, 20, 38, 20, 4),
    ],
    terrain: [
      R(8, 11, 10, 8, { type: 'offroad', id: 1 }), R(22, 11, 10, 8, { type: 'offroad', id: 2 }),
      C(14, 12.5, 0.9, { type: 'rad', id: 3 }), C(26, 17.5, 0.9, { type: 'rad', id: 4 }),
      R(16, 9.9, 1.5, 1, { type: 'debris', id: 5 }), R(22.5, 19.5, 1.5, 1, { type: 'debris', id: 6 }),
    ],
    deco: [
      { type: 'road', pts: [[0, 5], [40, 5]], w: 2.2 }, { type: 'road', pts: [[0, 10], [19, 10]], w: 1.6 }, { type: 'road', pts: [[21, 10], [40, 10]], w: 1.6 },
      { type: 'road', pts: [[0, 20], [19, 20]], w: 1.6 }, { type: 'road', pts: [[21, 20], [40, 20]], w: 1.6 }, { type: 'road', pts: [[0, 25.5], [40, 25.5]], w: 2.2 },
      { type: 'road', pts: [[8, 0], [8, 30]], w: 1.6 }, { type: 'road', pts: [[32, 0], [32, 30]], w: 1.6 },
      { type: 'mural', x: 2, y: 12, w: 5, h: 3 }, { type: 'mural', x: 33, y: 12, w: 5, h: 3 }, { type: 'wasteground', x: 8, y: 11, w: 10, h: 8 }, { type: 'wasteground', x: 22, y: 11, w: 10, h: 8 },
    ],
  },
  {
    id: 'cavehill', name: 'Cave Hill', tagline: 'Up the mountain. Boulders, gorse and the castle. Off-road unless you stick to the track.',
    width: 44, height: 32, theme: 'hill',
    spawns: [S(3, 29, 0), S(41, 29, 180), S(3, 3, 0), S(41, 3, 180), S(22, 30, 270), S(22, 12, 90), S(3, 16, 0), S(41, 16, 180)],
    walls: [
      // Napoleon's Nose: a cliff along the north
      P([[12, 0], [32, 0], [30, 3.5], [24, 5.5], [19, 5], [14, 3]], { ...BUILDING, name: "Napoleon's Nose", style: 'cliff' }),
      // Belfast Castle
      R(5, 8, 5, 4, { ...BUILDING, name: 'Belfast Castle', style: 'castle' }), C(7.5, 13, 0.6, { ...BUILDING, name: 'castle tower', style: 'statue' }),
      // boulders
      C(16, 12, 0.8, { dp: 50, dm: 3, style: 'boulder', name: 'boulder' }), C(28, 10, 1.0, { dp: 60, dm: 4, style: 'boulder', name: 'boulder' }),
      C(34, 18, 0.9, { dp: 55, dm: 3, style: 'boulder', name: 'boulder' }), C(12, 22, 0.7, { dp: 45, dm: 3, style: 'boulder', name: 'boulder' }),
      C(24, 24, 1.1, { dp: 70, dm: 4, style: 'boulder', name: 'boulder' }), C(38, 26, 0.8, { dp: 50, dm: 3, style: 'boulder', name: 'boulder' }),
      // trees
      C(20, 17, 0.5, { ...TREE, name: 'tree' }), C(31, 14, 0.5, { ...TREE, name: 'tree' }), C(9, 19, 0.5, { ...TREE, name: 'tree' }), C(17, 28, 0.5, { ...TREE, name: 'tree' }), C(36, 8, 0.5, { ...TREE, name: 'tree' }),
      R(38, 12, 3, 1.2, { ...WRECK, name: 'crashed helicopter' }),
    ],
    terrain: [
      R(0, 0, 44, 32, { type: 'offroad', id: 1 }),
      R(2, 15, 40, 1.8, { type: 'road', id: 2 }), R(21, 2, 1.8, 28, { type: 'road', id: 3 }), R(2, 29, 40, 1.8, { type: 'road', id: 4 }), R(2, 6, 10, 1.8, { type: 'road', id: 5 }), R(32, 6, 10, 1.8, { type: 'road', id: 6 }),
      R(2, 6, 1.8, 25, { type: 'road', id: 7 }), R(40.2, 6, 1.8, 25, { type: 'road', id: 8 }),
      C(22, 9, 2.2, { type: 'rad', id: 9 }), C(22, 9, 3.2, { type: 'rubble', id: 10 }),
      R(27.5, 20, 1.2, 1.8, { type: 'ramp', id: 11, angle: 0 }), R(14, 7.8, 1.2, 1.8, { type: 'ramp', id: 12, angle: Math.PI }),
      R(5, 22, 3, 3, { type: 'water', id: 13, depth: 1 }), R(32, 23, 4, 2.5, { type: 'water', id: 14, depth: 1 }),
    ],
    deco: [
      { type: 'road', pts: [[2, 15.9], [42, 15.9]], w: 1.8, dirt: true }, { type: 'road', pts: [[21.9, 2], [21.9, 30]], w: 1.8, dirt: true },
      { type: 'road', pts: [[2, 29.9], [42, 29.9]], w: 1.8, dirt: true }, { type: 'road', pts: [[2, 6.9], [12, 6.9]], w: 1.8, dirt: true }, { type: 'road', pts: [[32, 6.9], [42, 6.9]], w: 1.8, dirt: true },
      { type: 'road', pts: [[2.9, 6], [2.9, 31]], w: 1.8, dirt: true }, { type: 'road', pts: [[41.1, 6], [41.1, 31]], w: 1.8, dirt: true },
      { type: 'crater', x: 22, y: 9, r: 3.4 }, { type: 'gorse', x: 10, y: 24, r: 1.2 }, { type: 'gorse', x: 30, y: 27, r: 1.4 }, { type: 'gorse', x: 36, y: 20, r: 1 }, { type: 'gorse', x: 15, y: 18, r: 1 },
      { type: 'text', x: 22, y: 3, text: "NAPOLEON'S NOSE", size: 0.5 },
    ],
  },
  {
    id: 'stormont', name: 'Stormont Avenue', tagline: 'A mile of straight road up to Parliament. Top speed country. Carson is still in the middle.',
    width: 48, height: 28, theme: 'avenue',
    spawns: [S(3, 10, 0), S(3, 18, 0), S(36, 10, 180), S(36, 18, 180), S(14, 3, 0), S(34, 3, 180), S(14, 25, 0), S(24, 25, 180)],
    walls: [
      R(40, 8, 6, 12, { ...BUILDING, name: 'Parliament Buildings', style: 'parliament' }),
      C(24, 14, 0.7, { ...BUILDING, name: 'Carson statue', style: 'statue' }),
      // lime trees either side of the avenue
      ...Array.from({ length: 9 }, (_, i) => C(5 + i * 4.2, 7.6, 0.45, { ...TREE, name: 'lime tree' })),
      ...Array.from({ length: 9 }, (_, i) => C(5 + i * 4.2, 20.4, 0.45, { ...TREE, name: 'lime tree' })),
      R(2, 2, 6, 2.5, { ...RUIN, name: 'Massey Avenue gate lodge' }), R(2, 23.5, 6, 2.5, { ...RUIN, name: 'gate lodge' }),
      R(16, 1.5, 8, 1.5, { ...SHOP, name: 'Stormont Hotel' }), R(28, 25, 8, 1.5, { ...SHOP, name: 'Stormont Estate offices' }),
      R(20, 13.4, 1.2, 0.6, { ...WRECK, name: 'ministerial car' }), R(28, 14.1, 1.2, 0.6, { ...WRECK, name: 'ministerial car' }),
      R(30, 4.5, 0.3, 2, { ...BARRIER, name: 'police barrier' }), R(18, 21.5, 0.3, 2, { ...BARRIER, name: 'police barrier' }),
    ],
    terrain: [
      R(0, 0, 48, 7, { type: 'offroad', id: 1 }), R(0, 21, 48, 7, { type: 'offroad', id: 2 }),
      R(4, 7, 44, 0.4, { type: 'road', id: 3 }), R(4, 20.6, 44, 0.4, { type: 'road', id: 4 }),
      R(10, 2.3, 2, 1.6, { type: 'road', id: 5 }), R(36, 2.3, 2, 1.6, { type: 'road', id: 6 }), R(10, 24.1, 2, 1.6, { type: 'road', id: 7 }), R(36, 24.1, 2, 1.6, { type: 'road', id: 8 }),
      R(0, 2.3, 48, 1.6, { type: 'road', id: 9 }), R(0, 24.1, 48, 1.6, { type: 'road', id: 10 }), R(9, 2, 2, 24, { type: 'road', id: 11 }), R(37, 2, 2, 24, { type: 'road', id: 12 }),
      C(24, 14, 3.5, { type: 'rad', id: 13 }), C(24, 14, 3.5, { type: 'rubble', id: 14 }),
      R(14, 11.8, 1.4, 1.6, { type: 'ramp', id: 15, angle: 0 }), R(32.6, 14.6, 1.4, 1.6, { type: 'ramp', id: 16, angle: Math.PI }),
    ],
    deco: [
      { type: 'avenue', x: 0, y: 7, w: 48, h: 14 }, { type: 'road', pts: [[0, 3.1], [48, 3.1]], w: 1.6 }, { type: 'road', pts: [[0, 24.9], [48, 24.9]], w: 1.6 },
      { type: 'road', pts: [[10, 2], [10, 26]], w: 2 }, { type: 'road', pts: [[38, 2], [38, 26]], w: 2 },
      { type: 'crater', x: 24, y: 14, r: 3.6 }, { type: 'lawn', x: 0, y: 0, w: 48, h: 7 }, { type: 'lawn', x: 0, y: 21, w: 48, h: 7 },
      { type: 'text', x: 24, y: 9.5, text: 'PRINCE OF WALES AVENUE', size: 0.6 },
    ],
  },
  {
    id: 'gaol', name: 'Crumlin Road Gaol', tagline: 'The prison yard. Cell blocks like spokes, a wall around the lot, and no way out but through.',
    width: 40, height: 32, theme: 'gaol',
    spawns: [S(4, 4, 45), S(36, 4, 135), S(4, 28, -45), S(36, 28, -135), S(20, 3, 90), S(20, 29, 270), S(3, 16, 0), S(37, 16, 180)],
    walls: [
      // the circle: central hub, and four wings
      C(20, 16, 1.8, { ...BUILDING, name: 'the Circle', style: 'hub' }),
      R(21.5, 15.2, 9, 1.6, { ...RUIN, name: 'A Wing', dp: 60 }), R(9.5, 15.2, 9, 1.6, { ...RUIN, name: 'C Wing', dp: 60 }),
      R(19.2, 17.5, 1.6, 8, { ...RUIN, name: 'B Wing', dp: 60 }), R(19.2, 6.5, 1.6, 8, { ...RUIN, name: 'D Wing', dp: 60 }),
      // perimeter wall with breaches, watchtowers in the corners
      R(1, 1, 38, 0.6, PEACEWALL), R(1, 30.4, 16, 0.6, PEACEWALL), R(23, 30.4, 16, 0.6, PEACEWALL), R(1, 1, 0.6, 12, PEACEWALL), R(1, 19, 0.6, 12, PEACEWALL), R(38.4, 1, 0.6, 30, PEACEWALL),
      C(1.3, 1.3, 0.6, { ...BUILDING, name: 'watchtower', style: 'tower' }), C(38.7, 1.3, 0.6, { ...BUILDING, name: 'watchtower', style: 'tower' }), C(1.3, 30.7, 0.6, { ...BUILDING, name: 'watchtower', style: 'tower' }), C(38.7, 30.7, 0.6, { ...BUILDING, name: 'watchtower', style: 'tower' }),
      // the gatehouse and the hanging cell
      R(2, 8, 4, 3, { ...RUIN, name: 'gatehouse' }), R(34, 21, 4, 3, { ...RUIN, name: 'the hanging cell' }),
      R(8, 25, 1.2, 0.6, { ...WRECK, name: 'prison van' }), R(30, 6, 1.2, 0.6, { ...WRECK, name: 'prison van' }),
      ...lamps(4, 12.5, 16, 12.5, 3), ...lamps(24, 19.5, 36, 19.5, 3),
    ],
    terrain: [
      R(3, 2, 34, 4, { type: 'offroad', id: 1 }), R(3, 26, 34, 4, { type: 'offroad', id: 2 }),
      C(31, 11, 1.2, { type: 'rad', id: 3 }), C(9, 21, 1.2, { type: 'rad', id: 4 }),
      R(12, 12, 2, 1.4, { type: 'ramp', id: 5, angle: 0 }), R(26, 18.6, 2, 1.4, { type: 'ramp', id: 6, angle: Math.PI }),
      R(5, 15.2, 1.5, 1, { type: 'debris', id: 7 }), R(33.5, 15.8, 1.5, 1, { type: 'debris', id: 8 }),
    ],
    deco: [
      { type: 'yard', x: 3, y: 2, w: 34, h: 4 }, { type: 'yard', x: 3, y: 26, w: 34, h: 4 },
      { type: 'road', pts: [[2, 13.5], [38, 13.5]], w: 2 }, { type: 'road', pts: [[2, 18.5], [38, 18.5]], w: 2 }, { type: 'road', pts: [[10, 2], [10, 30]], w: 2 }, { type: 'road', pts: [[30, 2], [30, 30]], w: 2 },
      { type: 'text', x: 20, y: 4, text: 'HMP CRUMLIN ROAD', size: 0.6 }, { type: 'tunnel', x: 20, y: 30.5 },
    ],
  },
];

export function getMap(id) { return MAPS.find((m) => m.id === id) || MAPS[0]; }
