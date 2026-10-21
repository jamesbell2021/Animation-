// Car Carnage: Belfast Edition - rules data.
// Numbers follow the Car Wars classic rulebook (bodies, plants, tires, weapons, stock cars).
// Inches are rulebook inches: 1" = 15 feet. Speeds are mph. Weights are pounds.

export const BODIES = {
  subcompact: { name: 'Subcompact', price: 300, weight: 1000, maxLoad: 2300, spaces: 7, armorCost: 11, armorWt: 5, len: 1, wid: 0.5, kind: 'car', style: 'hatch' },
  compact: { name: 'Compact', price: 400, weight: 1300, maxLoad: 3700, spaces: 10, armorCost: 13, armorWt: 6, len: 1, wid: 0.5, kind: 'car', style: 'coupe' },
  midsize: { name: 'Mid-sized', price: 600, weight: 1600, maxLoad: 4800, spaces: 13, armorCost: 16, armorWt: 8, len: 1, wid: 0.5, kind: 'car', style: 'saloon' },
  sedan: { name: 'Sedan', price: 700, weight: 1700, maxLoad: 5100, spaces: 16, armorCost: 18, armorWt: 9, len: 1, wid: 0.5, kind: 'car', style: 'saloon' },
  luxury: { name: 'Luxury', price: 800, weight: 1800, maxLoad: 5500, spaces: 19, armorCost: 20, armorWt: 10, len: 1, wid: 0.5, kind: 'car', style: 'limo' },
  wagon: { name: 'Station Wagon', price: 800, weight: 1800, maxLoad: 5500, spaces: 21, armorCost: 20, armorWt: 11, len: 1, wid: 0.5, kind: 'car', style: 'wagon' },
  pickup: { name: 'Pickup', price: 900, weight: 2100, maxLoad: 6500, spaces: 24, armorCost: 30, armorWt: 14, len: 1, wid: 0.5, kind: 'car', style: 'pickup', sixWheels: true },
  camper: { name: 'Camper', price: 1400, weight: 2300, maxLoad: 6500, spaces: 24, armorCost: 30, armorWt: 14, len: 1, wid: 0.5, kind: 'car', style: 'van', sixWheels: true },
  van: { name: 'Van', price: 1000, weight: 2000, maxLoad: 6000, spaces: 30, armorCost: 30, armorWt: 14, len: 1, wid: 0.5, kind: 'car', style: 'van', sixWheels: true },
  lightcycle: { name: 'Light Cycle', price: 200, weight: 250, maxLoad: 800, spaces: 4, armorCost: 5, armorWt: 5, len: 0.5, wid: 0.25, kind: 'cycle', style: 'cycle' },
  medcycle: { name: 'Medium Cycle', price: 300, weight: 300, maxLoad: 1100, spaces: 5, armorCost: 11, armorWt: 5, len: 0.5, wid: 0.25, kind: 'cycle', style: 'cycle' },
  hvycycle: { name: 'Heavy Cycle', price: 400, weight: 350, maxLoad: 1300, spaces: 7, armorCost: 12, armorWt: 6, len: 0.5, wid: 0.25, kind: 'cycle', style: 'cycle' },
  lighttrike: { name: 'Light Trike', price: 250, weight: 300, maxLoad: 1600, spaces: 8, armorCost: 11, armorWt: 5, len: 1, wid: 0.5, kind: 'trike', style: 'trike' },
  medtrike: { name: 'Medium Trike', price: 300, weight: 500, maxLoad: 2100, spaces: 10, armorCost: 13, armorWt: 6, len: 1, wid: 0.5, kind: 'trike', style: 'trike' },
  hvytrike: { name: 'Heavy Trike', price: 400, weight: 700, maxLoad: 2800, spaces: 12, armorCost: 14, armorWt: 7, len: 1, wid: 0.5, kind: 'trike', style: 'trike' },
  xhvytrike: { name: 'X-Heavy Trike', price: 550, weight: 950, maxLoad: 3500, spaces: 14, armorCost: 16, armorWt: 8, len: 1, wid: 0.5, kind: 'trike', style: 'trike' },
};

export const CHASSIS = {
  light: { name: 'Light', load: -0.10, price: -0.20 },
  standard: { name: 'Standard', load: 0, price: 0 },
  heavy: { name: 'Heavy', load: 0.10, price: 0.50 },
  xheavy: { name: 'Extra Heavy', load: 0.20, price: 1.00 },
};

// Handling class by suspension: cars, vans/pickups/campers (van), subcompacts (sub), cycles, trikes.
export const SUSPENSIONS = {
  light: { name: 'Light', price: 0, hc: { car: 1, van: 0, sub: 2, cycle: 0, trike: 0 } },
  improved: { name: 'Improved', price: 1.0, hc: { car: 2, van: 1, sub: 3, cycle: 1, trike: 1 } },
  heavy: { name: 'Heavy', price: 1.5, hc: { car: 3, van: 2, sub: 4, cycle: 2, trike: 2 } },
  offroad: { name: 'Off-Road', price: 5.0, hc: { car: 2, van: 1, sub: 3, cycle: 2, trike: 2 }, offroad: true },
};

export const PLANTS = {
  small: { name: 'Small', cost: 500, weight: 500, spaces: 3, dp: 5, pf: 800, kind: 'car' },
  medium: { name: 'Medium', cost: 1000, weight: 700, spaces: 4, dp: 8, pf: 1400, kind: 'car' },
  large: { name: 'Large', cost: 2000, weight: 900, spaces: 5, dp: 10, pf: 2000, kind: 'car' },
  super: { name: 'Super', cost: 3000, weight: 1100, spaces: 6, dp: 12, pf: 2600, kind: 'car' },
  sport: { name: 'Sport', cost: 6000, weight: 1000, spaces: 6, dp: 12, pf: 3000, kind: 'car' },
  thundercat: { name: 'Thundercat', cost: 12000, weight: 2000, spaces: 8, dp: 15, pf: 6700, kind: 'car' },
  smallcycle: { name: 'Small Cycle', cost: 500, weight: 100, spaces: 1, dp: 2, pf: 400, kind: 'cycle' },
  medcycle: { name: 'Medium Cycle', cost: 1000, weight: 150, spaces: 1, dp: 3, pf: 600, kind: 'cycle' },
  largecycle: { name: 'Large Cycle', cost: 1500, weight: 175, spaces: 2, dp: 4, pf: 800, kind: 'cycle' },
  supercycle: { name: 'Super Cycle', cost: 2000, weight: 200, spaces: 2, dp: 5, pf: 1000, kind: 'cycle' },
  supertrike: { name: 'Super Trike', cost: 3000, weight: 250, spaces: 3, dp: 6, pf: 1200, kind: 'cycle' },
};

export const TIRES = {
  standard: { name: 'Standard', price: 50, weight: 30, dp: 4 },
  hd: { name: 'Heavy-Duty', price: 100, weight: 40, dp: 6 },
  pr: { name: 'Puncture-Resistant', price: 200, weight: 50, dp: 9 },
  solid: { name: 'Solid', price: 500, weight: 75, dp: 12 },
};
export const TIRE_MODS = {
  steelbelted: { name: 'Steelbelted', price: 0.5, wtMult: 0.5, dpMult: 1.25 },
  radial: { name: 'Radial', price: 1.0, wtMult: 0.2, dp: -1, hc: 1 },
  offroad: { name: 'Off-Road', price: 0.2, wtAdd: 5, offroad: true },
};

// Weapon types. dmg is dice notation. type: proj, laser, flame, rocket, dropLiquid, dropGas, dropSolid.
// burst: burst effect (also damages peds/components nearby). area: area effect.
// fireMod / burn: Vehicular Fire Table. range: max inches (0 = unlimited).
export const WEAPONS = {
  MG: { name: 'Machine Gun', toHit: 7, dmg: '1d', dp: 3, cost: 1000, weight: 150, spaces: 1, shots: 20, cps: 25, type: 'proj', area: true },
  AC: { name: 'Autocannon', toHit: 6, dmg: '3d', dp: 4, cost: 6500, weight: 500, spaces: 3, shots: 10, cps: 75, type: 'proj', burst: true },
  RR: { name: 'Recoilless Rifle', toHit: 6, dmg: '2d', dp: 4, cost: 1500, weight: 300, spaces: 2, shots: 10, cps: 35, type: 'proj', burst: true },
  VMG: { name: 'Vulcan Machine Gun', toHit: 6, dmg: '2d', dp: 3, cost: 2000, weight: 350, spaces: 2, shots: 10, cps: 35, type: 'proj', area: true },
  ATG: { name: 'Anti-Tank Gun', toHit: 8, dmg: '3d', dp: 5, cost: 2000, weight: 600, spaces: 3, shots: 10, cps: 35, type: 'proj', burst: true },
  GL: { name: 'Grenade Launcher', toHit: 7, dmg: '1d', dp: 2, cost: 1000, weight: 200, spaces: 2, shots: 10, cps: 50, type: 'proj', burst: true },
  SG: { name: 'Spike Gun', toHit: 7, dmg: '1d', dp: 2, cost: 1500, weight: 250, spaces: 2, shots: 10, cps: 40, type: 'proj', tiresOnly: true },
  HR: { name: 'Heavy Rocket', toHit: 9, dmg: '3d', dp: 2, cost: 200, weight: 100, spaces: 1, shots: 1, cps: 0, type: 'rocket', burst: true },
  LtR: { name: 'Light Rocket', toHit: 9, dmg: '1d', dp: 1, cost: 75, weight: 25, spaces: 0.5, shots: 1, cps: 0, type: 'rocket', burst: true },
  MR: { name: 'Medium Rocket', toHit: 9, dmg: '2d', dp: 2, cost: 140, weight: 50, spaces: 1, shots: 1, cps: 0, type: 'rocket', burst: true },
  MML: { name: 'Micromissile Launcher', toHit: 8, dmg: '1d', dp: 2, cost: 750, weight: 100, spaces: 1, shots: 10, cps: 20, type: 'rocket', burst: true },
  MNR: { name: 'Mini Rocket', toHit: 9, dmg: '1d-1', dp: 1, cost: 50, weight: 20, spaces: 0.34, shots: 1, cps: 0, type: 'rocket', burst: true },
  MFR: { name: 'Multi-Fire Rocket Pod', toHit: 9, dmg: '1d', dp: 3, cost: 450, weight: 150, spaces: 2, shots: 1, cps: 0, type: 'rocket', burst: true, salvo: 6 },
  RL: { name: 'Rocket Launcher', toHit: 8, dmg: '2d', dp: 2, cost: 1000, weight: 200, spaces: 2, shots: 10, cps: 35, type: 'rocket', burst: true },
  HL: { name: 'Heavy Laser', toHit: 6, dmg: '4d', dp: 2, cost: 12000, weight: 1000, spaces: 3, shots: 0, cps: 0, type: 'laser', area: true, pu: 3, fireMod: 2 },
  L: { name: 'Laser', toHit: 6, dmg: '3d', dp: 2, cost: 8000, weight: 500, spaces: 2, shots: 0, cps: 0, type: 'laser', area: true, pu: 2, fireMod: 1 },
  ML: { name: 'Medium Laser', toHit: 6, dmg: '2d', dp: 2, cost: 5500, weight: 350, spaces: 2, shots: 0, cps: 0, type: 'laser', area: true, pu: 2, fireMod: 1 },
  LL: { name: 'Light Laser', toHit: 6, dmg: '1d', dp: 2, cost: 3000, weight: 200, spaces: 1, shots: 0, cps: 0, type: 'laser', area: true, pu: 1, fireMod: 0 },
  FT: { name: 'Flamethrower', toHit: 6, dmg: '2d', dp: 2, cost: 500, weight: 450, spaces: 3, shots: 10, cps: 25, type: 'flame', area: true, range: 10, fireMod: 4, burn: 3, smoke: true },
  PS: { name: 'Paint Spray', toHit: 0, dmg: '0', dp: 2, cost: 400, weight: 25, spaces: 1, shots: 25, cps: 10, type: 'dropGas', cloud: 'paint' },
  SS: { name: 'Smokescreen', toHit: 0, dmg: '0', dp: 4, cost: 250, weight: 25, spaces: 1, shots: 10, cps: 10, type: 'dropGas', cloud: 'smoke' },
  FOJ: { name: 'Flaming Oil Jet', toHit: 0, dmg: '1d-2', dp: 3, cost: 300, weight: 30, spaces: 2, shots: 25, cps: 15, type: 'dropLiquid', counter: 'flamingoil', fireMod: 3, burn: 2 },
  OJ: { name: 'Oil Jet', toHit: 0, dmg: '0', dp: 3, cost: 250, weight: 25, spaces: 2, shots: 25, cps: 10, type: 'dropLiquid', counter: 'oil' },
  MD: { name: 'Minedropper', toHit: 0, dmg: '2d', dp: 2, cost: 500, weight: 150, spaces: 2, shots: 10, cps: 50, type: 'dropSolid', counter: 'mines' },
  SMD: { name: 'Spear 1000 Minedropper', toHit: 0, dmg: '2d+3', dp: 2, cost: 750, weight: 150, spaces: 2, shots: 5, cps: 100, type: 'dropSolid', counter: 'spearmines' },
  SD: { name: 'Spikedropper', toHit: 0, dmg: '1d', dp: 4, cost: 100, weight: 25, spaces: 1, shots: 10, cps: 20, type: 'dropSolid', counter: 'spikes' },
};

export const ACCESSORIES = {
  tc: { name: 'Targeting Computer', cost: 1000, weight: 0, spaces: 0, toHit: 1 },
  hrtc: { name: 'Hi-Res Targeting Computer', cost: 4000, weight: 0, spaces: 0, toHit: 2 },
  fe: { name: 'Fire Extinguisher', cost: 300, weight: 150, spaces: 1, extinguish: 3 },
  ife: { name: 'Improved Fire Extinguisher', cost: 500, weight: 200, spaces: 1, extinguish: 4 },
  turret1: { name: '1-space Turret', cost: 1000, weight: 150, spaces: 1, turret: 1 },
  turret2: { name: '2-space Turret', cost: 1500, weight: 200, spaces: 2, turret: 2 },
  turret3: { name: '3-space Turret', cost: 2500, weight: 300, spaces: 2, turret: 3 },
  ramplate: { name: 'Ramplate', cost: 0, weight: 0, spaces: 0, ramplate: true },
  spikes: { name: 'Bumper Spikes', cost: 0, weight: 0, spaces: 0, bumperSpikes: true },
  spoiler: { name: 'Spoiler', cost: 0, weight: 0, spaces: 0, aero: 1 },
  airdam: { name: 'Airdam', cost: 0, weight: 0, spaces: 0, aero: 1 },
  abs: { name: 'Antilock Brakes', cost: 1000, weight: 50, spaces: 0, abs: true },
  rollcage: { name: 'Roll Cage', cost: 150, weight: 0, spaces: 1, rollcage: true },
  safetyseat: { name: 'Safety Seat', cost: 500, weight: 25, spaces: 0, safetyseat: true },
  activesusp: { name: 'Active Suspension', cost: 4000, weight: 100, spaces: 0, hc: 1 },
  wheelguards: { name: 'Wheelguards (10 pt)', cost: 400, weight: 160, spaces: 0, wheelguards: 10 },
  cyberlink: { name: 'Cyberlink', cost: 16000, weight: 100, spaces: 1, toHit: 3 },
};

export const SIDES = ['F', 'B', 'L', 'R', 'T', 'U'];
export const SIDE_NAMES = { F: 'Front', B: 'Back', L: 'Left', R: 'Right', T: 'Top', U: 'Underbody' };

// Damage modifier by vehicle weight (Collision Damage Table).
export function damageModifier(weight) {
  if (weight <= 2000) return 1 / 3;
  if (weight <= 4000) return 2 / 3;
  if (weight <= 8000) return 1;
  if (weight <= 12000) return 2;
  if (weight <= 16000) return 3;
  if (weight <= 20000) return 4;
  return 5 + Math.floor((weight - 20001) / 4000);
}

// Stock vehicles from the rulebook's Sample Vehicles chapter, with Belfast names.
// weapons: w = weapon key, side = F/B/L/R/T (T = turret), link = group id for linked fire.
export const STOCK = [
  {
    id: 'bap', name: 'Belfast Bap', orig: 'Killer Kart', body: 'subcompact', chassis: 'standard', susp: 'heavy', plant: 'medium', tires: 'hd',
    weapons: [{ w: 'MG', side: 'F' }], armor: { F: 5, R: 3, L: 3, B: 3, T: 2, U: 2 }, acc: [],
    accel: 10, top: 135, hc: 4, weight: 2300, cost: 3848, color: '#f5b400',
    blurb: 'A wee kart with one gun and no fear. The Amateur Night special: cheap, nippy and made of tinfoil.'
  },
  {
    id: 'stinger', name: 'Shankill Stinger', orig: 'Stinger', body: 'subcompact', chassis: 'heavy', susp: 'heavy', plant: 'small', tires: 'hd',
    weapons: [{ w: 'MG', side: 'F', link: 1 }, { w: 'MG', side: 'F', link: 1 }], armor: { F: 10, R: 5, L: 5, B: 8, T: 5, U: 5 }, acc: [],
    accel: 5, top: 90, hc: 4, weight: 2400, cost: 5268, color: '#ff5c1a',
    blurb: 'Twin linked machine guns up front and a heavy chassis. Slow off the mark but it bites.'
  },
  {
    id: 'dart', name: 'Dunmurry Dart', orig: 'Yellow Jacket', body: 'subcompact', chassis: 'heavy', susp: 'heavy', plant: 'small', tires: 'hd',
    weapons: [{ w: 'L', side: 'F' }], armor: { F: 5, R: 4, L: 4, B: 5, T: 0, U: 0 }, acc: [],
    accel: 5, top: 90, hc: 4, weight: 2400, cost: 9998, color: '#ffe600',
    blurb: 'All the money went on the laser. None of it went on armour. Hit first or do not get hit.'
  },
  {
    id: 'crusher', name: 'Crumlin Crusher', orig: 'Mini-Sherman', body: 'compact', chassis: 'standard', susp: 'heavy', plant: 'large', tires: 'hd',
    weapons: [{ w: 'MG', side: 'F', link: 1 }, { w: 'MG', side: 'F', link: 1 }, { w: 'SS', side: 'B' }], armor: { F: 35, R: 20, L: 20, B: 23, T: 10, U: 10 }, acc: [],
    accel: 10, top: 125, hc: 3, weight: 3693, cost: 8334, color: '#5c7a3a',
    blurb: 'A compact tank. Thick front plate, twin guns, a smokescreen for the getaway.'
  },
  {
    id: 'samson', name: 'Samson', orig: 'Capricorn', body: 'compact', chassis: 'xheavy', susp: 'heavy', plant: 'large', tires: 'pr', tireMods: ['radial'],
    weapons: [{ w: 'RL', side: 'F' }, { w: 'SS', side: 'B' }], armor: { F: 45, R: 35, L: 35, B: 40, T: 37, U: 35 }, acc: ['tc', 'wheelguards'],
    accel: 5, top: 110, hc: 3, weight: 4437, cost: 11451, color: '#e8c21a',
    blurb: 'Named after the big yellow crane. Rockets, a targeting computer and armour everywhere.'
  },
  {
    id: 'spitfire', name: 'Shorts Spitfire', orig: 'Spitfire', body: 'compact', chassis: 'xheavy', susp: 'heavy', plant: 'medium', tires: 'pr', fireproof: true,
    weapons: [{ w: 'VMG', side: 'F' }, { w: 'FT', side: 'B' }], armor: { F: 35, R: 25, L: 25, B: 35, T: 15, U: 15 }, acc: ['hrtc'],
    accel: 5, top: 90, hc: 3, weight: 4200, cost: 14550, color: '#6b7f99',
    blurb: 'Built in the old aircraft works. Vulcan gun forward, flamethrower aft, fireproof plate, hi-res targeting.'
  },
  {
    id: 'sandyrow', name: 'Sandy Row Special', orig: 'Joseph Special', body: 'midsize', chassis: 'standard', susp: 'improved', plant: 'large', tires: 'hd',
    weapons: [{ w: 'ATG', side: 'F' }, { w: 'RL', side: 'B' }, { w: 'PS', side: 'R' }], armor: { F: 30, R: 15, L: 15, B: 25, T: 15, U: 15 }, acc: [],
    accel: 5, top: 105, hc: 2, weight: 4795, cost: 10340, color: '#9b2d2d',
    blurb: 'An anti-tank gun on a family saloon. Rockets out the back, paint spray on the right.'
  },
  {
    id: 'goliath', name: 'Goliath', orig: 'Mauler', body: 'midsize', chassis: 'xheavy', susp: 'heavy', plant: 'large', tires: 'solid', tireMods: ['radial'],
    weapons: [{ w: 'AC', side: 'F' }, { w: 'FOJ', side: 'B' }], armor: { F: 50, R: 40, L: 40, B: 40, T: 15, U: 15 }, acc: ['spoiler', 'airdam', 'wheelguards'],
    accel: 5, top: 92.5, hc: 3, weight: 5760, cost: 22250, color: '#c9a227',
    blurb: 'The other crane. Autocannon, flaming oil, solid tyres and fifty points of front armour.'
  },
  {
    id: 'titanic', name: 'Titanic', orig: 'Hotshot', body: 'luxury', chassis: 'xheavy', susp: 'heavy', plant: 'large', tires: 'pr',
    weapons: [{ w: 'MG', side: 'F', link: 1 }, { w: 'MG', side: 'F', link: 1 }, { w: 'FT', side: 'B', link: 2 }, { w: 'FT', side: 'B', link: 2 }, { w: 'FT', side: 'R' }, { w: 'FT', side: 'L' }],
    armor: { F: 20, R: 10, L: 10, B: 20, T: 10, U: 10 }, acc: ['fe'],
    accel: 5, top: 100, hc: 3, weight: 6600, cost: 14600, color: '#1b2a4a',
    blurb: 'She was fine when she left here. Four flamethrowers, two machine guns and a fire extinguisher, wisely.'
  },
  {
    id: 'peacewall', name: 'Peace Wall', orig: 'Bodyguard', body: 'luxury', chassis: 'heavy', susp: 'heavy', plant: 'large', tires: 'solid',
    weapons: [{ w: 'MD', side: 'L', link: 1 }, { w: 'MD', side: 'R', link: 1 }, { w: 'OJ', side: 'L', link: 2 }, { w: 'OJ', side: 'R', link: 2 }, { w: 'OJ', side: 'B', link: 2 }, { w: 'PS', side: 'L', link: 3 }, { w: 'PS', side: 'R', link: 3 }],
    armor: { F: 20, R: 45, L: 45, B: 50, T: 20, U: 20 }, acc: [],
    accel: 5, top: 90, hc: 3, weight: 5925, cost: 15400, color: '#8a8f99',
    blurb: 'No guns at all. Mines, oil and paint out of every side, and armour like a wall. Let them come to you.'
  },
  {
    id: 'statesman', name: 'Stormont Statesman', orig: 'Intimidator', body: 'wagon', chassis: 'standard', susp: 'improved', plant: 'super', tires: 'pr',
    weapons: [{ w: 'L', side: 'T' }], armor: { F: 25, R: 15, L: 15, B: 25, T: 30, U: 15 }, acc: ['turret2'],
    accel: 5, top: 120, hc: 2, weight: 5200, cost: 17400, color: '#d8d2c4',
    blurb: 'A long estate car with a laser in a turret. Fires in any direction, drives like a bus.'
  },
  {
    id: 'hammer', name: 'Harland Hammer', orig: 'Ventura', body: 'pickup', chassis: 'xheavy', susp: 'heavy', plant: 'super', tires: 'solid', laserReflective: true, fireproof: true,
    weapons: [{ w: 'AC', side: 'F' }, { w: 'VMG', side: 'T' }], armor: { F: 40, R: 30, L: 30, B: 33, T: 25, U: 20 }, acc: ['turret2', 'spoiler'],
    accel: 5, top: 90, hc: 2, weight: 7314, cost: 31740, color: '#b8431f',
    blurb: 'Shipyard pickup. Autocannon forward, Vulcan in the turret, six solid tyres, reflective fireproof plate.'
  },
  {
    id: 'lightning', name: 'Lisburn Road Lightning', orig: 'Shogun 100', body: 'lightcycle', chassis: 'standard', susp: 'heavy', plant: 'smallcycle', tires: 'pr',
    weapons: [{ w: 'MG', side: 'F' }], armor: { F: 6, R: 0, L: 0, B: 6, T: 0, U: 0 }, acc: [],
    accel: 10, top: 120, hc: 3, weight: 798, cost: 3120, color: '#2fd4ff',
    blurb: 'A motorbike with a machine gun. Tiny, fast, hard to hit, and one good burst ends it.'
  },
  {
    id: 'ravenhill', name: 'Ravenhill Rocket', orig: 'Shogun 200', body: 'medcycle', chassis: 'standard', susp: 'heavy', plant: 'supercycle', tires: 'pr',
    weapons: [{ w: 'MG', side: 'F' }], armor: { F: 10, R: 0, L: 0, B: 10, T: 0, U: 0 }, acc: [],
    accel: 15, top: 180, hc: 3, weight: 1000, cost: 5020, color: '#ff2fa8',
    blurb: 'The fastest thing in the arena. 180 on the straight if you dare. Do not touch anything.'
  },
  {
    id: 'cavecrab', name: 'Cave Hill Crab', orig: 'Sandcrab', body: 'medtrike', chassis: 'standard', susp: 'offroad', plant: 'largecycle', tires: 'solid', tireMods: ['offroad'],
    weapons: [{ w: 'VMG', side: 'F' }, { w: 'RL', side: 'B' }], armor: { F: 12, R: 12, L: 12, B: 15, T: 9, U: 15 }, acc: [],
    accel: 5, top: 97.5, hc: 2, hcOffroad: 3, weight: 2095, cost: 9450, color: '#7a5c3a',
    blurb: 'Off-road trike. Goes over rubble and up the hill without shaking itself apart.'
  },
  {
    id: 'blitz', name: 'Blitz Trike', orig: 'Blastmaster', body: 'xhvytrike', chassis: 'standard', susp: 'heavy', plant: 'supertrike', tires: 'solid',
    weapons: [{ w: 'RL', side: 'R', link: 1 }, { w: 'RL', side: 'R', link: 1 }, { w: 'RL', side: 'L', link: 1 }, { w: 'RL', side: 'L', link: 1 }],
    armor: { F: 20, R: 20, L: 20, B: 20, T: 15, U: 6 }, acc: ['fe', 'tc'],
    accel: 5, top: 92.5, hc: 3, weight: 2794, cost: 17430, color: '#3a3f4a',
    blurb: 'Four rocket launchers on one link. Press the button and everything in front of a side goes away.'
  },
];

export const PLAYER_COLORS = ['#ff3b3b', '#2f8cff', '#3ddc5a', '#ffd02f', '#ff7a1f', '#c25cff', '#2fe6e6', '#ff4fd1'];

export const DEFAULT_OPTIONS = {
  startSpeed: 20,      // mph, everyone starts at this speed
  turnTimer: 0,        // seconds, 0 = no timer
  maxTurns: 30,
  playbackSeconds: 4,  // real seconds per game turn in the action phase
  fallout: true,       // ash haze: -1 to hit at range
};
