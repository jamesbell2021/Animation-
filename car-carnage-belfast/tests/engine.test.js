// Headless engine test: bots fight on every map, checking the simulation never throws,
// keeps cars inside the arena and finishes. Run with `npm test`.
import { createMatch, resolveTurn, phaseMoves, controlTable, ramDice, predictPath, computeStats, obbCorners, polyOverlap, circleOverlapPoly, shapePoly } from '../web/shared/engine.js';
import { botOrders } from '../web/shared/ai.js';
import { MAPS } from '../web/shared/maps.js';
import { STOCK, PLAYER_COLORS, DEFAULT_OPTIONS } from '../web/shared/data.js';

let failures = 0;
const check = (cond, msg) => { if (!cond) { failures++; console.log('  FAIL', msg); } };

// the movement chart
check(JSON.stringify(phaseMoves(30).slice(1)) === JSON.stringify([1, 0, 1, 0, 1]), '30 mph moves 1" in phases 1,3,5: ' + phaseMoves(30).slice(1));
check(JSON.stringify(phaseMoves(80).slice(1)) === JSON.stringify([2, 1, 2, 1, 2]), '80 mph moves 2,1,2,1,2: ' + phaseMoves(80).slice(1));
check(JSON.stringify(phaseMoves(15).slice(1)) === JSON.stringify([1, 0, 0.5, 0, 0]), '15 mph: ' + phaseMoves(15).slice(1));
check(phaseMoves(100).slice(1).reduce((a, b) => a + b, 0) === 10, '100 mph is 10 inches per turn');
check(controlTable(10, 3) === 'safe' && controlTable(100, -6) === 'XX' && typeof controlTable(60, -3) === 'number', 'control table shape');
check(ramDice(40) === '3d' && ramDice(100) === '15d' && ramDice(20) === '1d', 'ram dice');

// stock vehicle stats roughly match the rulebook
for (const s of STOCK) {
  const st = computeStats(s);
  const wErr = Math.abs(st.weight - s.weight) / s.weight;
  if (wErr > 0.25) console.log('  note: ' + s.name + ' computed weight ' + st.weight + ' vs book ' + s.weight);
  check(st.top >= s.top - 15, s.name + ' top speed ' + st.top + ' vs ' + s.top);
}

// spawns must not sit inside walls
for (const map of MAPS) {
  for (const [i, sp] of map.spawns.entries()) {
    const poly = obbCorners(sp.x, sp.y, sp.heading, 1, 0.5);
    for (const w of map.walls) {
      const hit = w.kind === 'circle' ? circleOverlapPoly(w.x, w.y, w.r, poly) : polyOverlap(poly, shapePoly(w));
      check(!hit, map.id + ' spawn ' + i + ' overlaps ' + (w.name || w.style));
    }
    check(sp.x > 0.6 && sp.y > 0.6 && sp.x < map.width - 0.6 && sp.y < map.height - 0.6, map.id + ' spawn ' + i + ' inside arena');
  }
}

// full matches with 8 bots on every map
let totalEvents = {};
const t0 = Date.now();
for (const map of MAPS) {
  const players = STOCK.slice(0, 8).map((s, i) => ({ id: 'b' + i, name: 'Bot ' + i, color: PLAYER_COLORS[i], bot: true, def: { ...s, color: PLAYER_COLORS[i] } }));
  const state = createMatch(map, players, { ...DEFAULT_OPTIONS, maxTurns: 40 }, 12345 + map.id.length);
  let turns = 0, frames = 0;
  while (!state.over && turns < 45) {
    const orders = {};
    for (const v of state.vehicles) if (v.status === 'alive') orders[v.owner.id] = botOrders(state, map, v, 99 + turns);
    let tl;
    try { tl = resolveTurn(state, orders, map); } catch (e) { failures++; console.log('  FAIL', map.id, 'turn', turns, e.stack); break; }
    frames += tl.frames.length;
    for (const e of tl.events) totalEvents[e.type] = (totalEvents[e.type] || 0) + 1;
    for (const v of state.vehicles) {
      check(Number.isFinite(v.x) && Number.isFinite(v.y) && Number.isFinite(v.heading), map.id + ' vehicle ' + v.name + ' has finite position');
      check(v.x > -1 && v.y > -1 && v.x < map.width + 1 && v.y < map.height + 1, map.id + ' ' + v.name + ' inside arena (' + v.x.toFixed(1) + ',' + v.y.toFixed(1) + ')');
      check(Number.isFinite(v.speed) && v.speed % 5 === 0, v.name + ' speed is a multiple of 5: ' + v.speed);
      check(v.handling >= -6 && v.handling <= 8, v.name + ' handling in range ' + v.handling);
    }
    for (const f of tl.frames) check(f.length === state.vehicles.length, 'frame has every vehicle');
    turns++;
  }
  const alive = state.vehicles.filter((v) => v.status === 'alive').length;
  console.log(`${map.name.padEnd(20)} ${turns} turns, ${frames} frames, ${alive} alive, winner: ${state.standings ? state.standings[0].name : '-'} (${state.standings ? state.standings[0].kills : 0} kills)`);
  // prediction matches a straight line run
  const v = state.vehicles[0];
  const pr = predictPath(v, { speed: 0, steer: [null, null, null, null, null] }, map);
  check(pr.points.length === 6, 'prediction has 6 points');
}
console.log('events:', JSON.stringify(totalEvents));
console.log('time', Date.now() - t0, 'ms');
if (failures) { console.log(failures + ' failures'); process.exit(1); } else console.log('all engine checks passed');
