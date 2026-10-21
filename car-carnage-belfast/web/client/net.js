// Car Carnage: Belfast Edition - links to a game room: over the network, or in memory on this device.
import { Room } from '../shared/room.js';

// Online: talks to server.js over a WebSocket. Messages are JSON objects with a `t` field.
export class NetLink {
  constructor() { this.ws = null; this.handlers = []; this.open = false; }
  // url: a game server address (http://host:8080, https://..., ws://..., wss://...); empty = this page's own server
  connect(url = '') {
    return new Promise((resolve, reject) => {
      let target;
      if (url) { let u = url.trim().replace(/\/+$/, ''); u = u.replace(/^http/, 'ws'); if (!/^wss?:\/\//.test(u)) u = (location.protocol === 'https:' ? 'wss://' : 'ws://') + u; target = u.replace(/\/ws$/, '') + '/ws'; }
      else { const proto = location.protocol === 'https:' ? 'wss' : 'ws'; target = `${proto}://${location.host}/ws`; }
      let ws;
      try { ws = new WebSocket(target); } catch (e) { reject(new Error('Bad server address: ' + target)); return; }
      let settled = false;
      ws.onopen = () => { this.open = true; settled = true; resolve(); };
      ws.onerror = () => { if (!settled) { settled = true; reject(new Error('Could not reach the game server.')); } };
      ws.onclose = () => { const was = this.open; this.open = false; for (const h of this.handlers) h({ t: 'disconnected', was }, null); };
      ws.onmessage = (e) => { let m; try { m = JSON.parse(e.data); } catch { return; } for (const h of this.handlers) h(m, null); };
      this.ws = ws;
    });
  }
  send(msg) { if (this.ws && this.open) this.ws.send(JSON.stringify(msg)); }
  onMessage(fn) { this.handlers.push(fn); }
  close() { if (this.ws) { try { this.ws.close(); } catch { /* ignore */ } } this.open = false; }
  get local() { return false; }
}

// Local: a Room living in this page. Several human seats share the screen (hot-seat), bots fill the rest.
export class LocalLink {
  constructor() {
    this.handlers = [];
    const io = {
      send: (pid, msg) => {
        // one screen: targeted messages reach the human seats; the start of a match is delivered once
        if (msg.t === 'start' || msg.t === 'welcome') { const first = this.seats[0] || this.room.order[0]; if (pid !== first) return; }
        else if (!this.seats.includes(pid)) return;
        this.deliver(msg, pid);
      },
      broadcast: (msg) => this.deliver(msg, null),
      now: () => Date.now(),
      after: (ms, fn) => setTimeout(fn, ms),
    };
    this.room = new Room('LOCAL', io);
    this.seats = [];
    this.timer = setInterval(() => this.room.tick(), 500);
  }
  deliver(msg, pid) { const m = JSON.parse(JSON.stringify(msg)); queueMicrotask(() => { for (const h of this.handlers) h(m, pid); }); }
  onMessage(fn) { this.handlers.push(fn); }
  connect() { return Promise.resolve(); }
  addSeat(info) { const pid = 'local-' + (this.seats.length + 1); this.seats.push(pid); this.room.addPlayer(pid, info); return pid; }
  send(msg, pid) {
    pid = pid || this.seats[0];
    if (msg.t === 'leave') return;
    this.room.handle(pid, msg);
  }
  close() { clearInterval(this.timer); }
  get local() { return true; }
}
