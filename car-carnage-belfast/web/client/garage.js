// Car Carnage: Belfast Edition - the garage. Build a car to the Car Wars design rules:
// body, chassis, suspension, power plant, tyres, armour per side, weapons by side, accessories.
import { BODIES, CHASSIS, SUSPENSIONS, PLANTS, TIRES, TIRE_MODS, WEAPONS, ACCESSORIES, SIDES, SIDE_NAMES } from '../shared/data.js';
import { computeStats } from '../shared/engine.js';
import { drawCarPreview } from './art.js';

const KEY = 'ccb-garage';
export function loadBuilds() { try { return JSON.parse(localStorage.getItem(KEY) || '[]'); } catch { return []; } }
export function saveBuilds(list) { try { localStorage.setItem(KEY, JSON.stringify(list)); } catch { /* ignore */ } }

export function mountGarage(container, { onChange } = {}) {
  let def = { name: 'My Motor', body: 'midsize', chassis: 'standard', susp: 'heavy', plant: 'large', tires: 'hd', tireMods: [], armor: { F: 20, B: 15, L: 15, R: 15, T: 5, U: 5 }, weapons: [{ w: 'MG', side: 'F' }], acc: [], fireproof: false, laserReflective: false, color: '#ff3b3b' };
  let builds = loadBuilds();
  const el = (tag, attrs = {}, ...kids) => { const e = document.createElement(tag); for (const [k, v] of Object.entries(attrs)) { if (k === 'class') e.className = v; else if (k.startsWith('on')) e.addEventListener(k.slice(2), v); else if (k === 'html') e.innerHTML = v; else e.setAttribute(k, v); } for (const k of kids) e.append(k); return e; };
  const sel = (opts, value, on) => { const s = el('select'); for (const [k, label] of opts) { const o = el('option', { value: k }, label); if (k === value) o.selected = true; s.append(o); } s.addEventListener('change', () => on(s.value)); return s; };
  container.innerHTML = '';
  const grid = el('div', { class: 'garage-grid' });
  const left = el('div'), mid = el('div'), right = el('div');
  grid.append(left, mid, right);
  const preview = el('canvas', { width: 360, height: 180 }); preview.style.width = '100%'; preview.style.borderRadius = '8px';
  const stats = el('div', { class: 'stats' });
  const savedList = el('div', { class: 'saved' });
  container.append(grid);

  function render() {
    left.innerHTML = ''; mid.innerHTML = ''; right.innerHTML = '';
    left.append(el('h3', {}, 'CHASSIS'));
    const name = el('input', { value: def.name, maxlength: '18' }); name.addEventListener('input', () => { def.name = name.value; });
    left.append(el('label', {}, 'Name ', name));
    const kindOf = (b) => BODIES[b].kind;
    left.append(el('label', {}, 'Body ', sel(Object.entries(BODIES).map(([k, b]) => [k, `${b.name} ($${b.price}, ${b.spaces} sp)`]), def.body, (v) => { const wasKind = kindOf(def.body); def.body = v; if (kindOf(v) !== wasKind) { def.plant = kindOf(v) === 'car' ? 'medium' : 'medcycle'; } update(); })));
    left.append(el('label', {}, 'Chassis ', sel(Object.entries(CHASSIS).map(([k, c]) => [k, `${c.name} (load ${c.load >= 0 ? '+' : ''}${c.load * 100}%)`]), def.chassis, (v) => { def.chassis = v; update(); })));
    left.append(el('label', {}, 'Suspension ', sel(Object.entries(SUSPENSIONS).map(([k, s]) => [k, s.name]), def.susp, (v) => { def.susp = v; update(); })));
    const plants = Object.entries(PLANTS).filter(([, p]) => p.kind === (kindOf(def.body) === 'car' ? 'car' : 'cycle'));
    left.append(el('label', {}, 'Power plant ', sel(plants.map(([k, p]) => [k, `${p.name} (${p.pf} PF, ${p.dp} DP)`]), def.plant, (v) => { def.plant = v; update(); })));
    left.append(el('label', {}, 'Tyres ', sel(Object.entries(TIRES).map(([k, t]) => [k, `${t.name} (${t.dp} DP)`]), def.tires, (v) => { def.tires = v; update(); })));
    for (const [k, m] of Object.entries(TIRE_MODS)) { const cb = el('input', { type: 'checkbox' }); cb.checked = def.tireMods.includes(k); cb.addEventListener('change', () => { def.tireMods = cb.checked ? [...def.tireMods, k] : def.tireMods.filter((x) => x !== k); update(); }); left.append(el('label', {}, m.name, cb)); }
    const fp = el('input', { type: 'checkbox' }); fp.checked = def.fireproof; fp.addEventListener('change', () => { def.fireproof = fp.checked; update(); }); left.append(el('label', {}, 'Fireproof armour (2× cost)', fp));
    const lr = el('input', { type: 'checkbox' }); lr.checked = def.laserReflective; lr.addEventListener('change', () => { def.laserReflective = lr.checked; update(); }); left.append(el('label', {}, 'Laser-reflective armour', lr));
    left.append(el('h3', {}, 'ARMOUR (points per side)'));
    const ag = el('div', { class: 'armor-grid' });
    for (const s of SIDES) { const inp = el('input', { type: 'number', min: '0', max: '80', value: String(def.armor[s] || 0) }); inp.addEventListener('input', () => { def.armor[s] = Math.max(0, Math.min(99, +inp.value || 0)); update(); }); ag.append(el('label', {}, SIDE_NAMES[s], inp)); }
    left.append(ag);

    mid.append(el('h3', {}, 'WEAPONS'));
    const wl = el('div', { class: 'wlist' });
    def.weapons.forEach((w, i) => {
      const row = el('div', { class: 'w' });
      row.append(el('span', {}, `${WEAPONS[w.w].name} (${WEAPONS[w.w].spaces} sp, $${WEAPONS[w.w].cost})`));
      row.append(sel([['F', 'Front'], ['B', 'Back'], ['L', 'Left'], ['R', 'Right'], ['T', 'Turret']], w.side, (v) => { w.side = v; update(); }));
      const link = el('input', { type: 'number', min: '0', max: '5', value: String(w.link || 0), title: 'link group (0 = none)', style: 'width:52px' }); link.addEventListener('input', () => { w.link = +link.value || 0; update(); });
      row.append(link);
      row.append(el('button', { class: 'small', onclick: () => { def.weapons.splice(i, 1); update(); } }, '×'));
      wl.append(row);
    });
    mid.append(wl);
    const addSel = sel(Object.entries(WEAPONS).map(([k, w]) => [k, `${w.name} · to-hit ${w.toHit || '-'} · ${w.dmg} · ${w.spaces} sp · $${w.cost}`]), 'MG', () => {});
    mid.append(el('div', { class: 'row' }, addSel, el('button', { class: 'small', onclick: () => { if (def.weapons.length < 10) { def.weapons.push({ w: addSel.value, side: 'F' }); update(); } } }, '+ ADD')));
    mid.append(el('div', { class: 'small muted' }, 'Linked weapons (same group number) fire together. Turret weapons need a turret accessory and fire in any direction.'));
    mid.append(el('h3', {}, 'ACCESSORIES'));
    for (const [k, a] of Object.entries(ACCESSORIES)) { const cb = el('input', { type: 'checkbox' }); cb.checked = def.acc.includes(k); cb.addEventListener('change', () => { def.acc = cb.checked ? [...def.acc, k] : def.acc.filter((x) => x !== k); update(); }); mid.append(el('label', {}, `${a.name} ($${a.cost}${a.spaces ? ', ' + a.spaces + ' sp' : ''})`, cb)); }

    right.append(el('h3', {}, 'THE CAR'), preview, stats);
    const colors = el('div', { class: 'swatches' });
    for (const c of ['#ff3b3b', '#2f8cff', '#3ddc5a', '#ffd02f', '#ff7a1f', '#c25cff', '#2fe6e6', '#ff4fd1', '#ffffff', '#222222']) { const sw = el('div', { class: 'swatch' + (def.color === c ? ' sel' : '') }); sw.style.background = c; sw.addEventListener('click', () => { def.color = c; update(); }); colors.append(sw); }
    right.append(el('div', { class: 'field' }, 'Paint', colors));
    right.append(el('div', { class: 'row' }, el('button', { class: 'big', onclick: save }, 'SAVE BUILD'), el('button', { onclick: () => { def = JSON.parse(JSON.stringify(def)); def.name = def.name + ' II'; update(); } }, 'DUPLICATE')));
    right.append(el('h3', {}, 'SAVED BUILDS'), savedList);
    renderSaved();
    update(false);
  }
  function renderSaved() {
    savedList.innerHTML = '';
    if (!builds.length) savedList.append(el('span', { class: 'small muted' }, 'Nothing saved yet.'));
    builds.forEach((b, i) => {
      const chip = el('div', { class: 'row' }, el('button', { class: 'small', onclick: () => { def = JSON.parse(JSON.stringify(b)); render(); } }, b.name), el('button', { class: 'small danger', onclick: () => { builds.splice(i, 1); saveBuilds(builds); renderSaved(); if (onChange) onChange(builds); } }, '×'));
      savedList.append(chip);
    });
  }
  function save() {
    const st = computeStats(def);
    const problems = validate(def, st);
    if (problems.length) { alert('Fix these first:\n' + problems.join('\n')); return; }
    const idx = builds.findIndex((b) => b.name === def.name);
    const copy = JSON.parse(JSON.stringify(def));
    if (idx >= 0) builds[idx] = copy; else builds.push(copy);
    saveBuilds(builds); renderSaved(); if (onChange) onChange(builds);
  }
  function update(rerender = true) {
    const st = computeStats(def);
    const problems = validate(def, st);
    stats.innerHTML = '';
    const line = (k, v, cls = '') => { stats.append(el('span', { class: 'muted' }, k), el('span', { class: cls }, String(v))); };
    line('Cost', '$' + st.cost.toLocaleString());
    line('Weight', `${st.weight.toLocaleString()} / ${st.maxLoad.toLocaleString()} lbs`, st.weight > st.maxLoad ? 'bad' : '');
    line('Spaces', `${+st.spaces.toFixed(2)} / ${st.maxSpaces}`, st.spaces > st.maxSpaces ? 'bad' : '');
    line('Handling class', st.hc, st.hc >= 3 ? 'good' : '');
    line('Acceleration', st.accel + ' mph', st.accel === 0 ? 'bad' : '');
    line('Top speed', st.top + ' mph');
    line('Tyre DP', st.tireDp);
    for (const p of problems) stats.append(el('span', { class: 'bad' }, '!'), el('span', { class: 'bad' }, p));
    const body = BODIES[def.body];
    drawCarPreview(preview, { ...def, kind: body.kind, style: body.style, tires: Array.from({ length: st.nTires }, (_, i) => ({ pos: body.kind === 'cycle' ? ['F', 'B'][i] : body.kind === 'trike' ? ['FL', 'FR', 'B'][i] : ['FL', 'FR', 'BL', 'BR', 'ML', 'MR'][i], dp: 1 })), weapons: def.weapons.map((w) => ({ ...w, type: WEAPONS[w.w].type })) }, def.color);
    if (rerender) render();
  }
  render();
  return { getDef: () => def, getBuilds: () => builds };
}
export function validate(def, st) {
  const problems = [];
  const body = BODIES[def.body];
  if (st.weight > st.maxLoad) problems.push('Too heavy for the chassis.');
  if (st.spaces > st.maxSpaces) problems.push('Not enough space in the body.');
  if (st.accel === 0) problems.push('Power plant too small to move this weight.');
  const perSide = {};
  for (const w of def.weapons) perSide[w.side] = (perSide[w.side] || 0) + WEAPONS[w.w].spaces;
  for (const [s, n] of Object.entries(perSide)) if (s !== 'T' && n > body.spaces / 3 + 0.01) problems.push(`Too many weapon spaces facing ${SIDE_NAMES[s]} (max ${(body.spaces / 3).toFixed(1)}).`);
  if (perSide.T && !def.acc.some((a) => ACCESSORIES[a].turret)) problems.push('Turret weapons need a turret.');
  if (perSide.T) { const t = def.acc.map((a) => ACCESSORIES[a].turret || 0).reduce((a, b) => Math.max(a, b), 0); if (perSide.T > t) problems.push('Turret is too small for those weapons.'); }
  if (body.kind === 'cycle' && def.weapons.some((w) => w.side === 'L' || w.side === 'R' || w.side === 'T')) problems.push('Cycles carry weapons front or back only.');
  if (!def.name.trim()) problems.push('Give it a name.');
  return problems;
}
