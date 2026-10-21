// Car Carnage: Belfast Edition - a game room. Used by the Node server (over WebSockets) and by the
// browser in local mode (in memory), so both paths run exactly the same game.

import { createMatch, resolveTurn, vehicleSummary, standings } from './engine.js';
import { botOrders, BOT_NAMES } from './ai.js';
import { STOCK, PLAYER_COLORS, DEFAULT_OPTIONS } from './data.js';
import { getMap, MAPS } from './maps.js';

export const MAX_PLAYERS = 8;

export class Room {
  constructor(code, io) {
    this.code = code;
    this.io = io; // { send(pid, msg), broadcast(msg), now() }
    this.players = new Map();
    this.order = []; // join order
    this.phase = 'lobby';
    this.mapId = MAPS[0].id;
    this.options = { ...DEFAULT_OPTIONS };
    this.hostId = null;
    this.state = null;
    this.map = null;
    this.drafts = {};
    this.locked = new Set();
    this.deadline = 0;
    this.turnNo = 0;
    this.history = [];
    this.botCounter = 0;
    this.seed = (Math.random() * 2 ** 31) >>> 0;
    this.lastActivity = io.now();
  }

  // ------------------------------------------------------------ players
  addPlayer(pid, info = {}) {
    if (this.players.size >= MAX_PLAYERS) { this.io.send(pid, { t: 'error', msg: 'Room is full (8 players).' }); return false; }
    const used = new Set([...this.players.values()].map((p) => p.color));
    const color = info.color && !used.has(info.color) ? info.color : PLAYER_COLORS.find((c) => !used.has(c)) || PLAYER_COLORS[0];
    const usedVeh = new Set([...this.players.values()].map((p) => p.vehicle));
    const vehicle = info.vehicle || STOCK.find((s) => !usedVeh.has(s.id))?.id || STOCK[0].id;
    const p = { id: pid, name: (info.name || 'Driver ' + (this.players.size + 1)).slice(0, 18), color, vehicle, custom: info.custom || null, ready: !!info.bot, bot: !!info.bot, connected: true, skill: info.skill || 0 };
    this.players.set(pid, p);
    this.order.push(pid);
    if (!this.hostId || !this.players.get(this.hostId)?.connected) this.hostId = [...this.players.values()].find((x) => !x.bot)?.id || pid;
    this.io.send(pid, { t: 'welcome', id: pid, code: this.code });
    if (this.phase !== 'lobby' && this.state) this.sendStart(pid);
    this.broadcastLobby();
    return true;
  }
  removePlayer(pid) {
    const p = this.players.get(pid);
    if (!p) return;
    if (this.phase === 'lobby') { this.players.delete(pid); this.order = this.order.filter((x) => x !== pid); }
    else { p.connected = false; p.bot = true; p.name = p.name; }
    if (this.hostId === pid) this.hostId = [...this.players.values()].find((x) => !x.bot && x.connected)?.id || null;
    if (this.phase === 'planning') this.maybeResolve();
    this.broadcastLobby();
  }
  addBot() {
    if (this.players.size >= MAX_PLAYERS) return;
    const name = BOT_NAMES[this.botCounter++ % BOT_NAMES.length];
    const used = new Set([...this.players.values()].map((p) => p.vehicle));
    const choices = STOCK.filter((s) => !used.has(s.id));
    const veh = (choices.length ? choices : STOCK)[Math.floor(Math.random() * (choices.length ? choices.length : STOCK.length))].id;
    this.addPlayer('bot-' + Math.random().toString(36).slice(2, 8), { name, bot: true, vehicle: veh, skill: 0 });
  }
  humans() { return [...this.players.values()].filter((p) => !p.bot && p.connected); }

  lobbyView() {
    return {
      t: 'lobby', code: this.code, phase: this.phase, hostId: this.hostId, mapId: this.mapId, options: this.options,
      players: this.order.map((id) => this.players.get(id)).filter(Boolean).map((p) => ({ id: p.id, name: p.name, color: p.color, vehicle: p.vehicle, custom: p.custom ? { name: p.custom.name } : null, ready: p.ready, bot: p.bot, connected: p.connected })),
    };
  }
  broadcastLobby() { this.io.broadcast(this.lobbyView()); }

  // ------------------------------------------------------------ messages
  handle(pid, msg) {
    this.lastActivity = this.io.now();
    const p = this.players.get(pid);
    if (!p) return;
    const isHost = pid === this.hostId;
    switch (msg.t) {
      case 'setup': {
        if (msg.name) p.name = String(msg.name).slice(0, 18);
        if (msg.color && PLAYER_COLORS.includes(msg.color)) { const taken = [...this.players.values()].some((o) => o.id !== pid && o.color === msg.color); if (!taken) p.color = msg.color; }
        if (msg.vehicle && STOCK.some((s) => s.id === msg.vehicle)) { p.vehicle = msg.vehicle; p.custom = null; }
        if (msg.custom && validCustom(msg.custom)) { p.custom = msg.custom; p.vehicle = 'custom'; }
        if (typeof msg.ready === 'boolean') p.ready = msg.ready;
        this.broadcastLobby();
        break;
      }
      case 'ready': p.ready = !!msg.ready; this.broadcastLobby(); break;
      case 'map': if (isHost && this.phase === 'lobby' && getMap(msg.mapId)) { this.mapId = getMap(msg.mapId).id; this.broadcastLobby(); } break;
      case 'options': if (isHost && this.phase === 'lobby') { this.options = sanitizeOptions({ ...this.options, ...(msg.options || {}) }); this.broadcastLobby(); } break;
      case 'addBot': if (isHost && this.phase === 'lobby') this.addBot(); break;
      case 'removeBot': case 'kick': if (isHost && this.phase === 'lobby' && msg.pid !== pid) { const q = this.players.get(msg.pid); if (q) { this.players.delete(msg.pid); this.order = this.order.filter((x) => x !== msg.pid); this.io.send(msg.pid, { t: 'kicked' }); this.broadcastLobby(); } } break;
      case 'start': if (isHost && this.phase === 'lobby') this.start(); break;
      case 'orders': if (this.phase === 'planning' || this.phase === 'action') { this.drafts[pid] = msg.orders; } break;
      case 'lock':
        // a lock that arrives while the last turn is still playing back counts for the next turn
        if (this.phase === 'planning' || this.phase === 'action') {
          if (msg.orders) this.drafts[pid] = msg.orders;
          this.locked.add(pid);
          if (this.phase === 'planning') { this.broadcastLocks(); this.maybeResolve(); }
        }
        break;
      case 'unlock': if (this.phase === 'planning' || this.phase === 'action') { this.locked.delete(pid); if (this.phase === 'planning') this.broadcastLocks(); } break;
      case 'force': if (isHost && this.phase === 'planning') this.resolve(); break;
      case 'replay': if (isHost && this.phase === 'over') this.io.broadcast({ t: 'replay', choice: msg.choice === 'watch' ? 'watch' : 'skip' }); break;
      case 'rematch': if (isHost && this.phase === 'over') this.toLobby(); break;
      case 'chat': this.io.broadcast({ t: 'chat', from: p.name, color: p.color, text: String(msg.text || '').slice(0, 200) }); break;
      default: break;
    }
  }

  // ------------------------------------------------------------ the match
  start() {
    const list = this.order.map((id) => this.players.get(id)).filter(Boolean);
    if (list.length < 2) { this.io.send(this.hostId, { t: 'error', msg: 'You need at least two cars. Add a bot.' }); return; }
    this.map = getMap(this.mapId);
    this.seed = (Math.random() * 2 ** 31) >>> 0;
    const players = list.map((p) => ({ id: p.id, name: p.name, color: p.color, bot: p.bot, skill: p.skill || 0, def: resolveDef(p) }));
    this.state = createMatch(this.map, players, this.options, this.seed);
    this.history = [];
    this.phase = 'planning';
    this.locked = new Set();
    this.drafts = {};
    this.turnNo = 1;
    for (const p of list) p.ready = false;
    for (const pid of this.players.keys()) this.sendStart(pid);
    this.beginPlanning();
  }
  sendStart(pid) {
    this.io.send(pid, {
      t: 'start', code: this.code, mapId: this.map.id, options: this.options, seed: this.seed, hostId: this.hostId, phase: this.phase,
      players: this.order.map((id) => this.players.get(id)).filter(Boolean).map((p) => ({ id: p.id, name: p.name, color: p.color, bot: p.bot })),
      vehicles: this.state.vehicles.map(vehicleSummary), counters: this.state.counters, walls: this.state.walls.map((w) => ({ id: w.id, dp: w.dp, breached: w.breached })),
      turn: this.state.turn, history: this.history, over: this.state.over, standings: this.state.standings, locked: [...this.locked], deadline: this.deadline,
    });
  }
  beginPlanning() {
    this.phase = 'planning';
    this.deadline = this.options.turnTimer > 0 ? this.io.now() + this.options.turnTimer * 1000 : 0;
    this.broadcastLocks();
    this.maybeResolve();
  }
  broadcastLocks() { this.io.broadcast({ t: 'locks', locked: [...this.locked], deadline: this.deadline, turn: this.state ? this.state.turn : 0 }); }
  // humans with a living car must lock before the turn resolves
  waitingOn() {
    if (!this.state) return [];
    return this.state.vehicles.filter((v) => v.status === 'alive' && !v.owner.bot).map((v) => this.players.get(v.owner.id)).filter((p) => p && !p.bot && p.connected && !this.locked.has(p.id)).map((p) => p.id);
  }
  maybeResolve() {
    if (this.phase !== 'planning') return;
    if (this.waitingOn().length === 0) this.resolve();
  }
  tick() {
    if (this.phase === 'planning' && this.deadline && this.io.now() >= this.deadline) this.resolve();
  }
  resolve() {
    if (this.phase !== 'planning' || !this.state) return;
    this.phase = 'action';
    const orders = {};
    for (const v of this.state.vehicles) {
      if (v.status !== 'alive') continue;
      const p = this.players.get(v.owner.id);
      if (!p || p.bot || !p.connected) orders[v.owner.id] = botOrders(this.state, this.map, v, this.seed + this.state.turn);
      else orders[v.owner.id] = this.drafts[v.owner.id] || { speed: 0, steer: [null, null, null, null, null] };
    }
    const timeline = resolveTurn(this.state, orders, this.map);
    this.locked = new Set();
    this.drafts = {};
    const msg = {
      t: 'turn', turn: timeline.turn, timeline, orders, vehicles: this.state.vehicles.map(vehicleSummary), counters: this.state.counters,
      walls: this.state.walls.map((w) => ({ id: w.id, dp: w.dp, breached: w.breached })), over: this.state.over, standings: this.state.standings,
    };
    this.history.push({ turn: timeline.turn, timeline, vehicles: msg.vehicles, counters: msg.counters, walls: msg.walls });
    this.io.broadcast(msg);
    if (this.state.over) { this.phase = 'over'; this.broadcastLobby(); }
    else {
      // playback runs on the clients; the next planning phase starts after it
      const wait = (this.options.playbackSeconds || 4) * 1000 + 1500;
      this.io.after(wait, () => { if (this.phase === 'action') this.beginPlanning(); });
    }
  }
  toLobby() {
    this.phase = 'lobby'; this.state = null; this.history = [];
    for (const p of this.players.values()) p.ready = p.bot;
    this.broadcastLobby();
  }
}

export function resolveDef(p) {
  if (p.vehicle === 'custom' && p.custom && validCustom(p.custom)) return { ...p.custom, id: 'custom', color: p.custom.color || p.color };
  const s = STOCK.find((x) => x.id === p.vehicle) || STOCK[0];
  return { ...s, color: p.color };
}
export function validCustom(c) {
  return c && typeof c === 'object' && typeof c.name === 'string' && c.body && c.plant && c.armor && Array.isArray(c.weapons) && c.weapons.length <= 10;
}
export function sanitizeOptions(o) {
  const n = { ...DEFAULT_OPTIONS };
  n.startSpeed = [0, 10, 20, 30, 40].includes(+o.startSpeed) ? +o.startSpeed : 20;
  n.turnTimer = [0, 30, 60, 90, 120].includes(+o.turnTimer) ? +o.turnTimer : 0;
  n.maxTurns = [15, 20, 30, 50, 100].includes(+o.maxTurns) ? +o.maxTurns : 30;
  n.playbackSeconds = [3, 4, 6, 8].includes(+o.playbackSeconds) ? +o.playbackSeconds : 4;
  n.fallout = o.fallout !== false;
  return n;
}
export function makeCode(len = 4) {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let s = '';
  for (let i = 0; i < len; i++) s += chars[Math.floor(Math.random() * chars.length)];
  return s;
}
