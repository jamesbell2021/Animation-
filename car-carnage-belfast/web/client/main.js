// Car Carnage: Belfast Edition - the app: screens, lobby, orders, playback, results and replay.
import { STOCK, PLAYER_COLORS, WEAPONS } from '../shared/data.js';
import { MAPS, getMap } from '../shared/maps.js';
import { predictPath, controlTable, decelDifficulty, phaseMoves, canFire, toHitModifiers, defaultOrders, arcOf, dist } from '../shared/engine.js';
import { NetLink, LocalLink } from './net.js';
import { Renderer } from './render.js';
import { FX } from './fx.js';
import { audio } from './audio.js';
import { Cinematic } from './replay.js';
import { mountGarage, loadBuilds } from './garage.js';
import { drawCarPreview, drawMapPreview } from './art.js';

const $ = (id) => document.getElementById(id);
const h = (tag, attrs = {}, ...kids) => { const e = document.createElement(tag); for (const [k, v] of Object.entries(attrs)) { if (k === 'class') e.className = v; else if (k.startsWith('on')) e.addEventListener(k.slice(2), v); else if (k === 'html') e.innerHTML = v; else if (k === 'style') e.style.cssText = v; else if (typeof v === 'boolean') { if (v) e.setAttribute(k, ''); } else e.setAttribute(k, v); } for (const k of kids) if (k != null) e.append(k); return e; };
const show = (el, on = true) => el.classList.toggle('hidden', !on);
const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));

const fx = new FX();
const renderer = new Renderer($('game'), fx, audio);
const cinematic = new Cinematic(renderer, fx, audio, { show: (on) => show($('cinematic'), on), title: (t) => { $('cine-title').textContent = t; $('cine-title').classList.toggle('show', !!t); }, caption: (t) => { $('cine-caption').textContent = t; } });

const app = {
  screen: 'title', link: null, mode: null, myId: null, seats: [], lobby: null, game: null, attract: null,
  orders: {}, locked: new Set(), hotseat: null, planningOpen: false, pendingTurns: [], playing: false, name: localStorage.getItem('ccb-name') || '', color: localStorage.getItem('ccb-color') || null, vehicle: localStorage.getItem('ccb-vehicle') || 'bap', custom: null,
  cinematicPending: null,
};

// ------------------------------------------------------------ screens
function go(screen) {
  for (const s of ['title', 'online', 'local', 'lobby', 'garage', 'help']) show($('screen-' + s), s === screen);
  show($('hud'), screen === 'game'); show($('results'), false);
  app.screen = screen;
  if (screen === 'title') { startAttract(); audio.setMode('menu'); }
  else if (screen !== 'game') { stopAttract(); audio.setMode(screen === 'lobby' ? 'menu' : 'menu'); }
  if (screen === 'online') { $('online-name').value = app.name; buildSwatches($('online-colors'), app.color, (c) => { app.color = c; buildSwatches($('online-colors'), c, null); }); refreshOpenRooms(); }
  if (screen === 'garage') mountGarage($('garage-ui'), {});
}
document.querySelectorAll('[data-go]').forEach((b) => b.addEventListener('click', () => { audio.ui(); const t = b.dataset.go; if (t === 'title' && app.link && app.screen === 'lobby') leaveRoom(); go(t); }));
document.addEventListener('pointerdown', () => audio.init(), { once: false });
document.addEventListener('keydown', () => audio.init(), { once: true });
for (const [id, fn] of [['opt-music', (v) => audio.setMusic(v)], ['opt-sfx', (v) => audio.setSfx(v)], ['opt-fx', (v) => { fx.heavy = v; renderer.heavy = v; }]]) {
  const cb = $(id); const saved = localStorage.getItem('ccb-' + id); if (saved != null) { cb.checked = saved === '1'; fn(cb.checked); }
  cb.addEventListener('change', () => { fn(cb.checked); localStorage.setItem('ccb-' + id, cb.checked ? '1' : '0'); const g = $(id.replace('opt-', 'gm-')); if (g) g.checked = cb.checked; });
}
for (const id of ['gm-music', 'gm-sfx', 'gm-fx']) $(id).addEventListener('change', () => { const o = $(id.replace('gm-', 'opt-')); o.checked = $(id).checked; o.dispatchEvent(new Event('change')); });

function toast(text, ms = 2500) { const d = h('div', {}, text); $('toast').append(d); setTimeout(() => d.remove(), ms); }
function buildSwatches(container, selected, onPick, taken = new Set()) {
  container.innerHTML = '';
  for (const c of PLAYER_COLORS) { const s = h('div', { class: 'swatch' + (c === selected ? ' sel' : '') + (taken.has(c) && c !== selected ? ' taken' : '') }); s.style.background = c; if (onPick && !(taken.has(c) && c !== selected)) s.addEventListener('click', () => { audio.ui(); onPick(c); }); container.append(s); }
}

// ------------------------------------------------------------ attract mode on the title screen
function startAttract() {
  if (app.attract || app.link) return;
  const link = new LocalLink();
  app.attract = link;
  link.onMessage((m) => {
    if (app.attract !== link) return;
    if (m.t === 'start') { const map = getMap(m.mapId); renderer.setMap(map); renderer.myId = null; renderer.setState(m.vehicles, m.counters, m.walls); app.attractGame = { vehicles: m.vehicles }; renderer.camMode = 'overview'; renderer.showLabels = false; }
    else if (m.t === 'turn') { if (!app.attractGame) return; const before = app.attractGame.vehicles; app.attractGame.vehicles = m.vehicles; renderer.play(m.timeline, before, { duration: 5, director: true, onDone: () => { renderer.setState(m.vehicles, m.counters, m.walls); if (m.over) setTimeout(() => { if (app.attract === link) { stopAttract(); startAttract(); } }, 1500); } }); audio.setMode('menu'); }
  });
  const map = MAPS[Math.floor(Math.random() * MAPS.length)];
  link.room.mapId = map.id; link.room.options.playbackSeconds = 5;
  for (let i = 0; i < 6; i++) link.room.addBot();
  link.room.start();
}
function stopAttract() { if (app.attract) { app.attract.close(); app.attract = null; app.attractGame = null; renderer.stopPlayback(); renderer.showLabels = true; } }

// ------------------------------------------------------------ online
$('btn-create').addEventListener('click', () => connectOnline('create'));
$('btn-join').addEventListener('click', () => connectOnline('join'));
$('join-code').addEventListener('keydown', (e) => { if (e.key === 'Enter') connectOnline('join'); });
async function refreshOpenRooms() {
  try { const r = await fetch('/api/rooms'); const list = await r.json(); const el = $('open-rooms'); el.innerHTML = ''; if (list.length) { el.append('Open games: '); for (const x of list) el.append(h('button', { class: 'small', onclick: () => { $('join-code').value = x.code; connectOnline('join'); } }, `${x.code} (${x.players})`)); } } catch { /* offline file */ }
}
async function connectOnline(kind) {
  audio.init();
  const name = $('online-name').value.trim() || 'Driver'; app.name = name; localStorage.setItem('ccb-name', name); if (app.color) localStorage.setItem('ccb-color', app.color);
  const code = $('join-code').value.trim().toUpperCase();
  if (kind === 'join' && code.length !== 4) { $('online-status').textContent = 'Enter the 4-letter room code.'; return; }
  $('online-status').textContent = 'Connecting...';
  stopAttract();
  const link = new NetLink();
  try { await link.connect(); } catch (e) { $('online-status').textContent = e.message + ' Is server.js running? For a game on one device use PLAY ON THIS DEVICE.'; startAttract(); return; }
  app.link = link; app.mode = 'online'; app.seats = [];
  link.onMessage(onMessage);
  link.send({ t: kind, code, name, color: app.color, vehicle: app.vehicle === 'custom' ? null : app.vehicle, custom: app.custom });
  $('online-status').textContent = 'Connected.';
}
function leaveRoom() {
  if (app.link) { app.link.send({ t: 'leave' }); app.link.close(); app.link = null; }
  app.mode = null; app.game = null; app.lobby = null; app.myId = null; app.seats = []; app.hotseat = null; renderer.stopPlayback(); cinematic.skip();
}
// ------------------------------------------------------------ local
let localHumans = 1, localBots = 5;
const refreshLocal = () => { $('local-humans').textContent = localHumans; $('local-bots').textContent = localBots; };
$('local-humans-minus').addEventListener('click', () => { localHumans = Math.max(1, localHumans - 1); if (localHumans + localBots > 8) localBots = 8 - localHumans; refreshLocal(); });
$('local-humans-plus').addEventListener('click', () => { localHumans = Math.min(8, localHumans + 1); if (localHumans + localBots > 8) localBots = 8 - localHumans; refreshLocal(); });
$('local-bots-minus').addEventListener('click', () => { localBots = Math.max(0, localBots - 1); refreshLocal(); });
$('local-bots-plus').addEventListener('click', () => { localBots = Math.min(8 - localHumans, localBots + 1); refreshLocal(); });
$('btn-local-start').addEventListener('click', () => {
  audio.init(); stopAttract();
  const link = new LocalLink(); app.link = link; app.mode = 'local'; app.seats = [];
  link.onMessage(onMessage);
  for (let i = 0; i < localHumans; i++) { const pid = link.addSeat({ name: i === 0 && app.name ? app.name : 'Player ' + (i + 1), color: i === 0 ? app.color : null, vehicle: i === 0 && app.vehicle !== 'custom' ? app.vehicle : null }); app.seats.push(pid); }
  for (let i = 0; i < localBots; i++) link.room.addBot();
  app.myId = app.seats[0]; app.editSeat = app.seats[0];
  link.room.broadcastLobby();
});

// ------------------------------------------------------------ messages from the room
function onMessage(m, pid) {
  switch (m.t) {
    case 'welcome': if (app.mode === 'online') app.myId = m.id; break;
    case 'error': toast(m.msg, 4000); $('online-status').textContent = m.msg; break;
    case 'kicked': toast('You were removed from the room.'); leaveRoom(); go('title'); break;
    case 'disconnected': if (app.mode === 'online' && m.was) { toast('Connection lost.', 5000); leaveRoom(); go('title'); } break;
    case 'lobby': app.lobby = m; if (m.phase === 'lobby' && app.screen !== 'lobby') { go('lobby'); } if (app.screen === 'lobby') renderLobby(); if (app.screen === 'game') renderTopPlayers(); break;
    case 'chat': { const d = h('div', {}, h('b', { style: 'color:' + m.color }, m.from + ': '), m.text); $('chat-log').append(d); $('chat-log').scrollTop = 1e6; break; }
    case 'start': onStart(m); break;
    case 'locks': onLocks(m); break;
    case 'turn': app.pendingTurns.push(m); if (!app.playing) playNextTurn(); break;
    case 'replay': if (m.choice === 'watch') startCinematic(); else showResults(true); break;
    default: break;
  }
}

// ------------------------------------------------------------ lobby
function myLobbyPlayer() { return app.lobby && app.lobby.players.find((p) => p.id === (app.mode === 'local' ? app.editSeat : app.myId)); }
function isHost() { return app.lobby && (app.mode === 'local' || app.lobby.hostId === app.myId); }
function renderLobby() {
  const L = app.lobby; if (!L) return;
  document.body.classList.toggle('not-host', !isHost());
  $('lobby-code').textContent = app.mode === 'local' ? 'THIS DEVICE' : L.code;
  $('lobby-share').textContent = app.mode === 'local' ? 'Pass the device round when the game starts.' : `Friends join with the code ${L.code} at ${location.origin}${location.pathname.replace(/\/[A-Z0-9]{4}$/i, '')}`;
  $('lobby-count').textContent = `${L.players.length}/8`;
  const list = $('lobby-list'); list.innerHTML = '';
  for (const p of L.players) {
    const veh = p.vehicle === 'custom' ? (p.custom ? p.custom.name : 'custom') : (STOCK.find((s) => s.id === p.vehicle) || {}).name;
    const row = h('div', { class: 'pl' }, h('span', { class: 'dot', style: 'background:' + p.color }), h('span', { class: 'nm' }, p.name + (p.bot ? ' (bot)' : '') + (!p.connected ? ' (gone)' : '')), h('span', { class: 'veh' }, veh || ''), p.id === L.hostId && app.mode === 'online' ? h('span', { class: 'host' }, 'HOST') : null, h('span', { class: 'rdy' + (p.ready ? '' : ' no') }, p.ready ? 'READY' : '...'));
    if (app.mode === 'local' && !p.bot) { row.append(h('button', { class: 'small', onclick: () => { app.editSeat = p.id; renderLobby(); } }, p.id === app.editSeat ? 'EDITING' : 'EDIT')); }
    if (isHost() && p.id !== (app.mode === 'local' ? app.seats[0] : app.myId) && (p.bot || app.mode === 'online')) row.append(h('button', { class: 'small', onclick: () => app.link.send({ t: 'kick', pid: p.id }, app.seats[0]) }, '×'));
    list.append(row);
  }
  const me = myLobbyPlayer();
  if (me) {
    if (document.activeElement !== $('lobby-name')) $('lobby-name').value = me.name;
    const taken = new Set(L.players.filter((p) => p.id !== me.id).map((p) => p.color));
    buildSwatches($('lobby-colors'), me.color, (c) => app.link.send({ t: 'setup', color: c }, me.id), taken);
    const g = $('lobby-garage'); g.innerHTML = '';
    const takenVeh = new Set(L.players.filter((p) => p.id !== me.id && !p.bot).map((p) => p.vehicle));
    for (const s of STOCK) g.append(h('div', { class: 'car' + (me.vehicle === s.id ? ' sel' : '') + (takenVeh.has(s.id) ? ' taken' : ''), onclick: () => { audio.ui(); app.vehicle = s.id; localStorage.setItem('ccb-vehicle', s.id); app.link.send({ t: 'setup', vehicle: s.id }, me.id); } }, h('b', {}, s.name), h('i', {}, `${s.orig} · HC ${s.hc} · ${s.top} mph`)));
    for (const b of loadBuilds()) g.append(h('div', { class: 'car' + (me.vehicle === 'custom' && me.custom && me.custom.name === b.name ? ' sel' : ''), onclick: () => { audio.ui(); app.custom = b; app.link.send({ t: 'setup', custom: b }, me.id); } }, h('b', {}, b.name), h('i', {}, 'your build')));
    const def = me.vehicle === 'custom' ? (loadBuilds().find((b) => me.custom && b.name === me.custom.name) || null) : STOCK.find((s) => s.id === me.vehicle);
    if (def) {
      $('lobby-blurb').textContent = def.blurb || `${def.name}: your own design.`;
      const body = def.body; const kind = ['lightcycle', 'medcycle', 'hvycycle'].includes(body) ? 'cycle' : /trike/.test(body) ? 'trike' : 'car';
      const style = { subcompact: 'hatch', compact: 'coupe', midsize: 'saloon', sedan: 'saloon', luxury: 'limo', wagon: 'wagon', pickup: 'pickup', camper: 'van', van: 'van' }[body] || (kind === 'cycle' ? 'cycle' : 'trike');
      const nT = kind === 'cycle' ? 2 : kind === 'trike' ? 3 : ['pickup', 'camper', 'van'].includes(body) ? 6 : 4;
      drawCarPreview($('lobby-preview'), { ...def, kind, style, tires: Array.from({ length: nT }, (_, i) => ({ pos: kind === 'cycle' ? ['F', 'B'][i] : kind === 'trike' ? ['FL', 'FR', 'B'][i] : ['FL', 'FR', 'BL', 'BR', 'ML', 'MR'][i], dp: 1 })), weapons: def.weapons.map((w) => ({ ...w, type: WEAPONS[w.w].type })) }, me.color);
    }
    $('btn-ready').textContent = me.ready ? 'READY ✓ (click to unready)' : 'READY';
    $('btn-ready').classList.toggle('on', !!me.ready);
  }
  const maps = $('lobby-maps'); maps.innerHTML = '';
  for (const m of MAPS) maps.append(h('div', { class: 'map' + (L.mapId === m.id ? ' sel' : ''), onclick: () => { if (isHost()) { audio.ui(); app.link.send({ t: 'map', mapId: m.id }, app.seats[0]); } } }, m.name));
  const map = getMap(L.mapId); $('lobby-map-tag').textContent = map.tagline;
  if (app.lastPreviewMap !== map.id) { app.lastPreviewMap = map.id; drawMapPreview($('lobby-mappreview'), map); }
  for (const k of ['startSpeed', 'turnTimer', 'maxTurns', 'playbackSeconds']) { const s = $('opt-' + k); if (document.activeElement !== s) s.value = String(L.options[k]); }
  $('opt-fallout').checked = !!L.options.fallout;
  $('lobby-options-ro').textContent = isHost() ? '' : `Start ${L.options.startSpeed} mph · timer ${L.options.turnTimer || 'off'} · ${L.options.maxTurns} turns · fallout ${L.options.fallout ? 'on' : 'off'}`;
  const humans = L.players.filter((p) => !p.bot && p.connected);
  const notReady = humans.filter((p) => !p.ready);
  $('btn-start').disabled = L.players.length < 2 || (app.mode === 'online' && notReady.length > 0);
  $('lobby-wait').textContent = L.players.length < 2 ? 'Add a bot or wait for a friend.' : notReady.length && app.mode === 'online' ? 'Waiting for: ' + notReady.map((p) => p.name).join(', ') : isHost() ? 'Everyone is ready.' : 'Waiting for the host to start.';
  show($('chat'), app.mode === 'online');
}
$('lobby-name').addEventListener('change', () => { const me = myLobbyPlayer(); if (me) { app.name = $('lobby-name').value; localStorage.setItem('ccb-name', app.name); app.link.send({ t: 'setup', name: $('lobby-name').value }, me.id); } });
$('btn-ready').addEventListener('click', () => { const me = myLobbyPlayer(); if (me) { audio.lockIn(); app.link.send({ t: 'ready', ready: !me.ready }, me.id); } });
$('btn-add-bot').addEventListener('click', () => { audio.ui(); app.link.send({ t: 'addBot' }, app.seats[0]); });
$('btn-start').addEventListener('click', () => { audio.actionStart(); if (app.mode === 'local') { for (const s of app.seats) app.link.send({ t: 'ready', ready: true }, s); } app.link.send({ t: 'start' }, app.seats[0]); });
$('btn-leave').addEventListener('click', () => { audio.ui(); leaveRoom(); go('title'); });
for (const k of ['startSpeed', 'turnTimer', 'maxTurns', 'playbackSeconds']) $('opt-' + k).addEventListener('change', () => app.link && app.link.send({ t: 'options', options: { [k]: +$('opt-' + k).value } }, app.seats[0]));
$('opt-fallout').addEventListener('change', () => app.link && app.link.send({ t: 'options', options: { fallout: $('opt-fallout').checked } }, app.seats[0]));
$('chat-form').addEventListener('submit', (e) => { e.preventDefault(); const t = $('chat-input').value.trim(); if (t && app.link) { app.link.send({ t: 'chat', text: t }); $('chat-input').value = ''; } });

// ------------------------------------------------------------ the game
function onStart(m) {
  const map = getMap(m.mapId);
  app.game = { map, mapId: m.mapId, options: m.options, players: m.players, vehicles: m.vehicles, startVehicles: m.vehicles.map((v) => ({ ...v })), counters: m.counters, walls: m.walls, turn: m.turn, history: m.history || [], over: m.over, standings: m.standings, hostId: m.hostId, locked: new Set(m.locked || []), deadline: m.deadline || 0 };
  app.orders = {}; app.locked = new Set(); app.pendingTurns = []; app.playing = false; app.planningOpen = false; app.hotseat = null;
  renderer.setMap(map); renderer.myId = app.mode === 'local' ? app.seats[0] : app.myId; renderer.setState(m.vehicles, m.counters, m.walls); renderer.ghost = null; renderer.targetId = null; renderer.showLabels = true;
  go('game'); show($('results'), false); show($('side-spectate'), false);
  $('hud-map').textContent = map.name.toUpperCase(); $('hud-turn').textContent = 'TURN ' + m.turn; $('side-log').innerHTML = ''; $('ticker').innerHTML = '';
  renderer.onCar = (v) => onCarClicked(v);
  renderTopPlayers();
  audio.setMode('plan');
  toast(map.name + ': ' + map.tagline, 5000);
  if (m.over) { showResults(false); return; }
  if (m.phase === 'planning') onLocks({ locked: m.locked || [], deadline: m.deadline || 0, turn: m.turn });
}
function renderTopPlayers() {
  const G = app.game; if (!G) return;
  const el = $('top-players'); el.innerHTML = '';
  for (const v of G.vehicles) {
    const mine = app.mode === 'local' ? app.seats.includes(v.owner.id) : v.owner.id === app.myId;
    el.append(h('span', { class: 'chip' + (G.locked.has(v.owner.id) ? ' locked' : '') + (v.status !== 'alive' ? ' dead' : '') + (mine ? ' me' : ''), title: v.name }, h('span', { class: 'dot', style: 'background:' + v.color }), v.owner.name, v.status === 'alive' ? (G.locked.has(v.owner.id) ? ' ✓' : v.owner.bot ? ' ·' : ' …') : ' ✗'));
  }
}
function onLocks(m) {
  const G = app.game; if (!G) return;
  G.locked = new Set(m.locked); G.deadline = m.deadline || 0;
  app.locksTurn = m.turn || 0;
  renderTopPlayers();
  if (!app.playing && !app.planningOpen && !G.over && (!m.turn || m.turn === G.turn)) openPlanning();
  if (app.planningOpen) refreshActionBar();
}
function humanSeatsAlive() {
  const G = app.game;
  const ids = app.mode === 'local' ? app.seats : [app.myId];
  return ids.filter((pid) => G.vehicles.some((v) => v.owner.id === pid && v.status === 'alive'));
}
function openPlanning() {
  const G = app.game; if (!G || G.over) return;
  app.planningOpen = true;
  $('hud-turn').textContent = 'TURN ' + G.turn;
  show($('phasebar'), false);
  audio.setMode('plan');
  const seats = humanSeatsAlive();
  if (app.mode === 'local') {
    app.hotseat = { queue: seats.filter((pid) => !G.locked.has(pid)), current: null };
    nextHotseat();
  } else {
    app.current = app.myId;
    if (!seats.length) { showSpectate(); return; }
    buildPlanningUI(app.myId);
  }
}
function nextHotseat() {
  const hs = app.hotseat; if (!hs) return;
  if (!hs.queue.length) { hs.current = null; showSpectate('Everyone has locked in. The turn is about to play out.', 'LOCKED IN'); return; }
  const pid = hs.queue.shift(); hs.current = pid; app.current = pid;
  const name = app.game.vehicles.find((v) => v.owner.id === pid)?.owner.name || pid;
  if (app.seats.length > 1) { $('pass-name').textContent = name; show($('passover'), true); renderer.ghost = null; show($('side'), false); show($('actionbar'), false); }
  else buildPlanningUI(pid);
}
$('btn-pass-ok').addEventListener('click', () => { audio.ui(); show($('passover'), false); show($('side'), true); show($('actionbar'), true); buildPlanningUI(app.hotseat.current); });
function showSpectate(text, title) {
  show($('side-spectate'), true); $('spectate-text').textContent = text || 'Your car is out of it. Watch the rest of the carnage.'; $('side-spectate').querySelector('h3').textContent = title || "YOU'RE OUT";
  $('status').innerHTML = ''; $('orders').innerHTML = ''; renderer.ghost = null; renderer.targetId = null;
  show($('actionbar'), true); $('btn-action').disabled = true; $('btn-action').textContent = 'WATCHING'; refreshActionBar();
  renderer.myVehicleId = null;
}

// ------------------------------------------------------------ planning UI
function myVehicle(pid) { return app.game.vehicles.find((v) => v.owner.id === pid); }
function getOrders(pid) { if (!app.orders[pid]) { app.orders[pid] = defaultOrders(); app.orders[pid].target = null; } return app.orders[pid]; }
function buildPlanningUI(pid) {
  const G = app.game, v = myVehicle(pid);
  show($('side-spectate'), false); show($('side'), true); show($('actionbar'), true);
  if (!v || v.status !== 'alive') { showSpectate(); return; }
  renderer.myId = pid; renderer.myVehicleId = v.id;
  const o = getOrders(pid);
  if (G.locked.has(pid)) { /* already locked: show status only */ }
  // a sensible default target: the nearest enemy in front
  if (o.target == null) o.target = 'auto';
  renderStatus(v);
  renderOrders(v, o, pid);
  refreshActionBar();
  updateGhost(pid);
  if (renderer.camMode === 'overview' || renderer.camMode === 'follow') { renderer.camMode = 'overview'; renderer.fitMap(false); }
}
function renderStatus(v) {
  const s = $('status'); s.innerHTML = '';
  s.append(h('h3', {}, v.name.toUpperCase()));
  const diag = h('div', { class: 'armor-diagram' });
  const pos = { F: 'left:38px;top:0', B: 'left:38px;top:92px', L: 'left:0;top:46px', R: 'left:80px;top:46px', T: 'left:38px;top:34px', U: 'left:38px;top:60px' };
  diag.append(h('div', { class: 'car', style: 'background:' + v.color }));
  for (const side of ['F', 'B', 'L', 'R', 'T', 'U']) { const a = v.armor[side] || 0, m = v.armorMax[side] || 0; diag.append(h('div', { class: 'a' + (a === 0 && m > 0 ? ' gone' : a < m / 2 ? ' low' : ''), style: pos[side], title: side }, `${side}${a}`)); }
  const right = h('div');
  const pip = (n, max, hurtBelow) => { const p = h('span', { class: 'pips' }); for (let i = 0; i < max; i++) p.append(h('span', { class: 'pip' + (i < n ? (n <= hurtBelow ? ' hurt' : ' on') : '') })); return p; };
  right.append(h('div', { class: 'statline' }, 'Driver ', pip(v.driver.dp, 3, 1)));
  right.append(h('div', { class: 'statline' }, 'Power plant ', h('b', {}, `${v.plant.dp}/${v.plant.max}`)));
  right.append(h('div', { class: 'statline' }, 'Speed ', h('b', {}, v.speed + ' mph')), h('div', { class: 'statline' }, 'Top / accel ', h('b', {}, `${v.top} / +${v.accel}`)));
  right.append(h('div', { class: 'statline' }, 'Handling ', h('b', {}, `${v.handling} (HC ${v.hc})`)));
  const tires = h('div', { class: 'tires' }); for (const t of v.tires) tires.append(h('span', { class: 'tire' + (t.dp <= 0 ? ' gone' : ''), title: 'tyre ' + t.pos }, `${t.pos} ${t.dp}`)); right.append(tires);
  if (v.fire.burning) right.append(h('div', { class: 'burning' }, '🔥 ON FIRE'));
  if (v.wasOffroad) right.append(h('div', { class: 'small muted' }, 'Off-road: HC reduced, +1 difficulty'));
  if (v.paintTurns > 0) right.append(h('div', { class: 'small muted' }, 'Paint on the windows: −2 to hit'));
  s.append(h('div', { class: 'car-status' }, diag, right));
}
function renderOrders(v, o, pid) {
  const el = $('orders'); el.innerHTML = '';
  const G = app.game;
  const locked = G.locked.has(pid);
  const changed = () => { updateGhost(pid); if (app.mode === 'online') throttledDraft(pid); renderOrders(v, o, pid); };
  // speed
  el.append(h('h3', {}, 'SPEED'));
  const row = h('div', { class: 'speed-row' });
  const maxRev = -Math.floor(v.top / 5 / 5) * 5;
  const options = [-45, -40, -35, -30, -25, -20, -15, -10, -5, 0, 5, 10, 15].filter((d) => d <= v.accel && v.speed + d <= v.top && v.speed + d >= maxRev && (d >= 0 || v.speed > 0 || v.speed + d >= maxRev));
  for (const d of options) {
    const ns = v.speed + d; const dd = d < 0 ? decelDifficulty(-d) : { D: 0 };
    const cls = 'small' + (o.speed === d ? ' on' + (dd.D >= 5 ? ' deadly' : dd.D >= 2 ? ' risky' : '') : '');
    row.append(h('button', { class: cls, disabled: locked, title: d < 0 ? `brake ${-d} mph` + (dd.D ? ` (D${dd.D})` : '') : d > 0 ? `accelerate ${d}` : 'hold speed', onclick: () => { audio.ui(); o.speed = d; changed(); } }, (d > 0 ? '+' : '') + d));
  }
  el.append(row);
  const nsp = Math.max(maxRev, Math.min(v.top, v.speed + (o.speed || 0)));
  const moves = phaseMoves(nsp);
  const dd = o.speed < 0 ? decelDifficulty(-o.speed) : { D: 0 };
  el.append(h('div', { class: 'orders-note' }, `${v.speed} → ${nsp} mph${nsp < 0 ? ' (reverse)' : ''}: moves ${[1, 2, 3, 4, 5].map((p) => moves[p] || '·').join(' / ')} inches per phase` + (dd.D ? ` · hard braking D${dd.D}${v.abs ? ' (ABS −1)' : ''}` : '')));
  // steering
  el.append(h('h3', {}, 'STEERING'));
  const steer = h('div', { class: 'steer' });
  const atPivot = Math.abs(nsp) <= 5;
  for (let p = 1; p <= 5; p++) {
    const st = o.steer[p - 1];
    const can = moves[p] >= 1 || (atPivot && moves[p] > 0);
    const special = o.special && o.special.phase === p;
    const r = h('div', { class: 'steer-row' + (can ? '' : ' idle') });
    r.append(h('span', { class: 'ph' }, 'ph ' + p, h('b', {}, moves[p] ? moves[p] + '"' : '—')));
    const opts = [['bend', -45, '↰45'], ['bend', -30, '↰30'], ['bend', -15, '↰15'], ['drift', -1, '⇠'], ['straight', 0, '↑'], ['drift', 1, '⇢'], ['bend', 15, '15↱'], ['bend', 30, '30↱'], ['bend', 45, '45↱']];
    for (const [type, val, label] of opts) {
      const sel = type === 'straight' ? !st && !special : st && st.type === type && (type === 'bend' ? st.deg === val : st.dir === val);
      let risk = '';
      if (sel && st) { const D = type === 'bend' ? Math.ceil(Math.abs(val) / 15) : 1; risk = D >= 4 ? ' deadly' : D >= 2 ? ' risky' : ''; }
      r.append(h('button', { class: 'small' + (sel ? ' on' + risk : ''), disabled: locked || !can, onclick: () => { audio.ui(); if (special) o.special = null; o.steer[p - 1] = type === 'straight' ? null : type === 'bend' ? { type: 'bend', deg: val } : { type: 'drift', dir: val }; changed(); } }, label));
    }
    steer.append(r);
  }
  el.append(steer);
  const notes = app.ghostNotes || [];
  const riskBox = h('div', { class: 'risk ' + (app.ghostRisk >= 7 ? 'xx' : app.ghostRisk > 0 ? 'roll' : 'safe') });
  riskBox.append(notes.length ? notes.map((n) => `ph${n.phase}: ${n.text}`).join(' · ') : 'No manoeuvres: safe.');
  el.append(riskBox);
  // specials
  const canSpecial = Math.abs(nsp) >= 20 && Math.abs(nsp) <= 35;
  const sp = h('div', { class: 'row special-row' });
  for (const [kind, dir, label, tip] of [['bootlegger', -1, 'BOOTLEGGER ↶', 'Spin the car round 180° (D7). Ends at 0 mph.'], ['bootlegger', 1, 'BOOTLEGGER ↷', 'Spin the car round 180° (D7). Ends at 0 mph.'], ['tstop', -1, 'T-STOP ↶', 'Slew 90° and brake hard (D1 per 10 mph).'], ['tstop', 1, 'T-STOP ↷', 'Slew 90° and brake hard (D1 per 10 mph).']]) {
    const on = o.special && o.special.kind === kind && o.special.dir === dir;
    sp.append(h('button', { class: 'small' + (on ? ' on deadly' : ''), disabled: locked || !canSpecial, title: tip, onclick: () => { audio.ui(); o.special = on ? null : { kind, dir, phase: [1, 2, 3, 4, 5].find((p) => moves[p] >= 1) || 1 }; if (o.special) o.steer = [null, null, null, null, null]; changed(); } }, label));
  }
  el.append(h('h3', {}, 'SPECIAL (20–35 mph)'), sp);
  // weapons and target
  const guns = v.weapons.filter((w) => !w.type.startsWith('drop'));
  const drops = v.weapons.filter((w) => w.type.startsWith('drop'));
  if (guns.length) {
    el.append(h('h3', {}, 'TARGET'));
    const tr = h('div', { class: 'target-row' });
    tr.append(h('button', { class: 'small' + (o.target === 'auto' ? ' on' : ''), disabled: locked, onclick: () => { audio.ui(); o.target = 'auto'; renderer.targetId = null; changed(); } }, 'NEAREST'));
    for (const t of G.vehicles) {
      if (t.id === v.id || t.status !== 'alive') continue;
      const d = dist(v.x, v.y, t.x, t.y);
      tr.append(h('button', { class: 'small' + (o.target === t.owner.id ? ' on' : ''), disabled: locked, style: 'border-color:' + t.color, title: `${t.name}, ${d.toFixed(1)}" away, in your ${arcOf(v, t.x, t.y)} arc`, onclick: () => { audio.ui(); o.target = t.owner.id; renderer.targetId = t.id; changed(); } }, `${t.owner.name} ${d.toFixed(0)}"`));
    }
    el.append(tr);
    const tgt = o.target !== 'auto' ? G.vehicles.find((t) => t.owner.id === o.target) : null;
    renderer.targetId = tgt ? tgt.id : null;
    el.append(h('h3', {}, 'WEAPONS'));
    const seenLinks = new Set();
    for (const w of guns) {
      if (w.link && seenLinks.has(w.link)) continue; if (w.link) seenLinks.add(w.link);
      const on = !(o.weapons && o.weapons[w.id] === false);
      const dead = w.dp <= 0 || w.shots <= 0;
      let hint = '';
      if (tgt && !dead) { const cf = canFire(G, G.map, v, w, tgt, o.maxRange); if (cf.ok) { const mods = toHitModifiers(G, G.map, v, w, tgt, o.aimTires, 0); const need = WEAPONS[w.w].toHit - mods.reduce((s, m) => s + m[1], 0); hint = `needs ${need}+ now`; } else hint = cf.why === 'arc' ? 'not in arc' : cf.why === 'range' ? 'out of range' : 'no line of fire'; }
      const line = h('div', { class: 'weaponline' + (dead ? ' dead' : '') });
      const cb = h('input', { type: 'checkbox' }); cb.checked = on && !dead; cb.disabled = locked || dead; cb.addEventListener('change', () => { o.weapons = o.weapons || {}; for (const ww of guns) if (ww.id === w.id || (w.link && ww.link === w.link)) o.weapons[ww.id] = cb.checked; if (app.mode === 'online') throttledDraft(pid); });
      line.append(cb, h('span', { class: 'nm' }, `${w.name}${w.link ? ' ×' + guns.filter((x) => x.link === w.link).length : ''} (${w.side === 'T' ? 'turret' : w.side})`), h('span', { class: 'ammo' }, w.shots === Infinity ? '∞' : w.shots + ' shots'), h('span', { class: 'small muted' }, hint));
      el.append(line);
    }
    const aim = h('input', { type: 'checkbox' }); aim.checked = !!o.aimTires; aim.disabled = locked; aim.addEventListener('change', () => { o.aimTires = aim.checked; changed(); });
    el.append(h('label', { class: 'small' }, aim, ' Aim at tyres (−3 to hit)'));
    const rangeSel = h('select', { class: 'small' }); for (const r of [4, 8, 12, 16, 20, 30]) { const op = h('option', { value: r }, r + '"'); if (o.maxRange === r) op.selected = true; rangeSel.append(op); } rangeSel.disabled = locked; rangeSel.addEventListener('change', () => { o.maxRange = +rangeSel.value; renderer.rangeRing = o.maxRange; if (app.mode === 'online') throttledDraft(pid); });
    renderer.rangeRing = o.maxRange;
    el.append(h('label', { class: 'small' }, 'Hold fire beyond ', rangeSel));
  }
  if (drops.length) {
    el.append(h('h3', {}, 'DROP'));
    const seen = new Set();
    for (const w of drops) {
      if (w.link && seen.has(w.link)) continue; if (w.link) seen.add(w.link);
      const dead = w.dp <= 0 || w.shots <= 0;
      const line = h('div', { class: 'weaponline' + (dead ? ' dead' : '') });
      line.append(h('span', { class: 'nm' }, `${w.name}${w.link ? ' ×' + drops.filter((x) => x.link === w.link).length : ''} (${w.side})`), h('span', { class: 'ammo' }, w.shots + ' left'));
      const ds = h('div', { class: 'dropsel' });
      const cur = o.drops.find((d) => d.weaponId === w.id);
      ds.append(h('button', { class: 'small' + (!cur ? ' on' : ''), disabled: locked || dead, onclick: () => { audio.ui(); o.drops = o.drops.filter((d) => d.weaponId !== w.id); changed(); } }, 'off'));
      for (let p = 1; p <= 5; p++) ds.append(h('button', { class: 'small' + (cur && cur.phase === p ? ' on' : ''), disabled: locked || dead, onclick: () => { audio.ui(); o.drops = o.drops.filter((d) => d.weaponId !== w.id); o.drops.push({ weaponId: w.id, phase: p }); changed(); } }, String(p)));
      line.append(ds); el.append(line);
    }
  }
}
let draftTimer = 0;
function throttledDraft(pid) { clearTimeout(draftTimer); draftTimer = setTimeout(() => { if (app.link && app.game && !app.game.locked.has(pid)) app.link.send({ t: 'orders', orders: getOrders(pid) }, pid); }, 300); }
function updateGhost(pid) {
  const v = myVehicle(pid); if (!v || v.status !== 'alive') { renderer.ghost = null; return; }
  const pr = predictPath(v, getOrders(pid), app.game.map);
  renderer.ghost = pr; app.ghostNotes = pr.notes; app.ghostRisk = pr.risk;
}
function onCarClicked(v) {
  if (!app.planningOpen || !app.current) return;
  const me = myVehicle(app.current); if (!me || me.status !== 'alive' || app.game.locked.has(app.current)) return;
  if (v.id === me.id) { renderer.camMode = renderer.camMode === 'follow' ? 'overview' : 'follow'; renderer.followId = me.id; return; }
  if (v.status !== 'alive') return;
  const o = getOrders(app.current); o.target = v.owner.id; renderer.targetId = v.id; audio.ui();
  renderOrders(me, o, app.current); if (app.mode === 'online') throttledDraft(app.current);
}
function refreshActionBar() {
  const G = app.game; if (!G) return;
  const pid = app.current;
  const v = pid ? myVehicle(pid) : null;
  const alive = v && v.status === 'alive';
  const btn = $('btn-action');
  if (!alive) { btn.disabled = true; btn.textContent = 'WATCHING'; btn.classList.remove('locked'); }
  else if (G.locked.has(pid)) { btn.disabled = false; btn.textContent = 'LOCKED ✓ (undo)'; btn.classList.add('locked'); }
  else { btn.disabled = !app.planningOpen; btn.textContent = app.planningOpen ? 'ACTION!' : 'NEXT TURN SOON…'; btn.classList.remove('locked'); }
  const waiting = G.vehicles.filter((x) => x.status === 'alive' && !x.owner.bot && !G.locked.has(x.owner.id)).map((x) => x.owner.name);
  const timer = G.deadline ? Math.max(0, Math.ceil((G.deadline - Date.now()) / 1000)) : 0;
  $('action-wait').textContent = waiting.length ? 'Waiting on: ' + waiting.join(', ') : 'Everyone is locked in.';
  $('hud-timer').textContent = G.deadline && app.planningOpen ? `⏱ ${timer}s` : '';
  const host = app.mode === 'online' && G.hostId === app.myId;
  show($('btn-force'), host && app.planningOpen && waiting.length > 0 && !waiting.every((n) => v && n === v.owner.name));
  renderTopPlayers();
}
$('btn-action').addEventListener('click', () => {
  const G = app.game, pid = app.current; if (!G || !pid) return;
  if (G.locked.has(pid)) { app.link.send({ t: 'unlock' }, pid); G.locked.delete(pid); audio.ui(); refreshActionBar(); renderOrders(myVehicle(pid), getOrders(pid), pid); return; }
  audio.lockIn();
  const o = getOrders(pid);
  app.link.send({ t: 'lock', orders: o }, pid);
  G.locked.add(pid);
  refreshActionBar();
  if (app.mode === 'local') { renderer.ghost = null; renderer.targetId = null; nextHotseat(); }
  else renderOrders(myVehicle(pid), o, pid);
});
$('btn-force').addEventListener('click', () => { audio.ui(); app.link.send({ t: 'force' }); });
setInterval(() => { if (app.game && app.planningOpen) refreshActionBar(); }, 1000);

// ------------------------------------------------------------ playback
function playNextTurn() {
  const m = app.pendingTurns.shift(); if (!m) return;
  const G = app.game; if (!G) return;
  app.playing = true; app.planningOpen = false;
  show($('passover'), false); show($('side'), true); show($('actionbar'), true); show($('phasebar'), true);
  $('orders').innerHTML = ''; renderer.ghost = null; renderer.targetId = null; renderer.rangeRing = 0;
  showSpectate('All cars move at once. Watch the ticker on the left.', 'TURN ' + m.turn + ' PLAYS OUT');
  $('btn-action').disabled = true; $('btn-action').textContent = 'ACTION!'; $('btn-action').classList.remove('locked'); $('action-wait').textContent = 'Turn ' + m.turn + ' plays out...';
  $('hud-turn').textContent = 'TURN ' + m.turn; $('hud-timer').textContent = '';
  $('ticker').innerHTML = '';
  audio.actionStart();
  const before = G.vehicles.map((v) => ({ ...v }));
  const myIds = app.mode === 'local' ? app.seats : [app.myId];
  renderer.myVehicleId = (before.find((v) => myIds.includes(v.owner.id)) || {}).id ?? null;
  if (renderer.camMode === 'follow' && renderer.followId == null) renderer.followId = renderer.myVehicleId;
  const phases = $('phasebar').querySelectorAll('.phases span'); phases.forEach((p) => p.className = '');
  G.history.push({ turn: m.turn, timeline: m.timeline, vehicles: m.vehicles, counters: m.counters, walls: m.walls, countersBefore: G.counters });
  setTimeout(() => {
    renderer.play(m.timeline, before, {
      duration: G.options.playbackSeconds || 4, director: true,
      onPhase: (p) => phases.forEach((el, i) => el.className = i + 1 < p ? 'done' : i + 1 === p ? 'on' : ''),
      onLog: (text, cls) => addLog(text, cls),
      onDone: () => {
        G.vehicles = m.vehicles; G.counters = m.counters; G.walls = m.walls; G.over = m.over; G.standings = m.standings; G.turn = m.turn + 1; G.locked = new Set();
        renderer.setState(m.vehicles, m.counters, m.walls);
        app.playing = false;
        for (const pid of Object.keys(app.orders)) { const o = app.orders[pid]; o.speed = 0; o.steer = [null, null, null, null, null]; o.special = null; o.drops = []; }
        if (app.pendingTurns.length) { playNextTurn(); return; }
        if (m.over) { setTimeout(() => showResults(false), 800); return; }
        // the room announces the next planning phase with a locks message; open then
        $('action-wait').textContent = 'Next turn starting…';
        if (app.locksTurn === G.turn) openPlanning();
      },
    });
  }, 700);
}
$('btn-ff').addEventListener('click', () => renderer.fastForward());
function addLog(text, cls) {
  const t = h('div', { class: 'tick ' + (cls || '') }, text); $('ticker').append(t); while ($('ticker').children.length > 6) $('ticker').firstChild.remove(); setTimeout(() => t.remove(), 6000);
  const l = h('div', { class: cls || '' }, `T${app.game ? app.game.turn : ''}: ${text}`); $('side-log').prepend(l); while ($('side-log').children.length > 40) $('side-log').lastChild.remove();
}
$('btn-cam').addEventListener('click', () => { audio.ui(); if (renderer.camMode === 'overview') { renderer.followId = renderer.myVehicleId ?? (app.game ? app.game.vehicles[0].id : null); renderer.setCamMode('follow'); toast('Camera: follow'); } else { renderer.setCamMode('overview'); toast('Camera: overview'); } });
$('btn-sound').addEventListener('click', () => { const on = !audio.musicOn; audio.setMusic(on); audio.setSfx(on); $('opt-music').checked = on; $('opt-sfx').checked = on; toast(on ? 'Sound on' : 'Sound off'); });
$('btn-menu').addEventListener('click', () => { show($('gamemenu'), true); });
$('btn-resume').addEventListener('click', () => show($('gamemenu'), false));
$('btn-quit').addEventListener('click', () => { show($('gamemenu'), false); leaveRoom(); go('title'); });

// ------------------------------------------------------------ results and replay
function showResults(afterReplay) {
  const G = app.game; if (!G) return;
  show($('results'), true); show($('phasebar'), false);
  const st = G.standings || [];
  const top = st[0];
  const mine = app.mode === 'local' ? app.seats : [app.myId];
  $('results-title').textContent = top ? (mine.includes(top.owner.id) ? 'YOU WIN!' : top.owner.name.toUpperCase() + ' WINS') : 'NOBODY WINS';
  const table = h('table', { class: 'rtable' }, h('tr', {}, h('th', {}, '#'), h('th', {}, 'Driver'), h('th', {}, 'Car'), h('th', {}, 'Kills'), h('th', {}, 'Damage dealt'), h('th', {}, 'Fate')));
  st.forEach((s, i) => { const v = G.vehicles.find((x) => x.id === s.id); table.append(h('tr', { class: i === 0 ? 'winner' : '' }, h('td', {}, String(i + 1)), h('td', {}, h('span', { class: 'dot', style: 'background:' + (v ? v.color : '#fff') }), s.owner.name), h('td', {}, s.name), h('td', { class: 'n' }, String(s.kills)), h('td', { class: 'n' }, String(s.damage)), h('td', {}, s.alive ? 'still rolling' : s.reason || 'out'))); });
  $('results-table').innerHTML = ''; $('results-table').append(table);
  const host = app.mode === 'local' || G.hostId === app.myId;
  document.body.classList.toggle('not-host', !host);
  show($('btn-watch'), app.mode === 'online' && host && !afterReplay); show($('btn-skipreplay'), app.mode === 'online' && host && !afterReplay);
  show($('btn-watch-local'), app.mode === 'local' || afterReplay);
  $('btn-watch-local').textContent = afterReplay ? 'WATCH IT AGAIN' : 'WATCH IT BACK';
  $('results-wait').textContent = app.mode === 'online' && !host && !afterReplay ? 'The host decides whether everyone watches the replay. Rematch is theirs too.' : '';
  show($('btn-rematch'), host);
  audio.setMode('over');
  if (top && mine.includes(top.owner.id)) audio.sting('win');
}
$('btn-watch').addEventListener('click', () => { audio.ui(); app.link.send({ t: 'replay', choice: 'watch' }); });
$('btn-skipreplay').addEventListener('click', () => { audio.ui(); app.link.send({ t: 'replay', choice: 'skip' }); });
$('btn-watch-local').addEventListener('click', () => { audio.ui(); startCinematic(); });
$('btn-rematch').addEventListener('click', () => { audio.ui(); cinematic.skip(); show($('results'), false); app.link.send({ t: 'rematch' }, app.seats[0]); });
$('btn-results-menu').addEventListener('click', () => { audio.ui(); cinematic.skip(); leaveRoom(); go('title'); });
$('btn-cine-skip').addEventListener('click', () => { audio.ui(); cinematic.skip(); });
function startCinematic() {
  const G = app.game; if (!G || !G.history.length) { showResults(true); return; }
  show($('results'), false); show($('side'), false); show($('actionbar'), false); show($('phasebar'), false); $('ticker').innerHTML = '';
  cinematic.start(G.history, G.startVehicles, G.players, G.standings, () => { renderer.setState(G.vehicles, G.counters, G.walls); show($('side'), true); show($('actionbar'), true); showResults(true); });
}

// ------------------------------------------------------------ main loop
let last = performance.now();
function frame(now) {
  const dt = Math.min(0.05, (now - last) / 1000); last = now;
  renderer.update(dt);
  cinematic.update(dt);
  renderer.draw();
  requestAnimationFrame(frame);
}
requestAnimationFrame(frame);

// deep links: /ABCD or ?room=ABCD join a room
const roomMatch = /^\/([A-Z0-9]{4})$/i.exec(location.pathname) || /[?&]room=([A-Z0-9]{4})/i.exec(location.search);
go('title');
if (roomMatch) { go('online'); $('join-code').value = roomMatch[1].toUpperCase(); $('online-status').textContent = 'Enter your name and press JOIN to join room ' + roomMatch[1].toUpperCase() + '.'; }
window.ccb = { app, renderer, fx, audio, cinematic };
