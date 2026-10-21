#!/usr/bin/env node
// Car Carnage: Belfast Edition - game server.
// Serves the web client and runs game rooms over WebSockets. No dependencies: `node server.js`.
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';
import { WebSocketServer } from './ws.js';
import { Room, makeCode } from './web/shared/room.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const WEB = path.join(__dirname, 'web');
const PORT = +(process.env.PORT || process.argv[2] || 8080);
const HOST = process.env.HOST || '0.0.0.0';

const TYPES = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.css': 'text/css; charset=utf-8', '.json': 'application/json', '.svg': 'image/svg+xml', '.png': 'image/png', '.ico': 'image/x-icon', '.webmanifest': 'application/manifest+json', '.txt': 'text/plain; charset=utf-8', '.md': 'text/markdown; charset=utf-8' };

const server = http.createServer((req, res) => {
  const url = new URL(req.url, 'http://x');
  if (url.pathname === '/api/rooms') {
    const list = [...rooms.values()].filter((r) => r.phase === 'lobby' && r.players.size < 8).map((r) => ({ code: r.code, players: r.players.size, map: r.mapId }));
    // the game page may live elsewhere (itch.io) and ask this server for its rooms
    res.writeHead(200, { 'content-type': 'application/json', 'cache-control': 'no-store', 'access-control-allow-origin': '*' });
    res.end(JSON.stringify(list));
    return;
  }
  let file = decodeURIComponent(url.pathname);
  if (file === '/' || file === '') file = '/index.html';
  const full = path.normalize(path.join(WEB, file));
  if (!full.startsWith(WEB)) { res.writeHead(403); res.end(); return; }
  fs.stat(full, (err, st) => {
    if (err || !st.isFile()) {
      // any unknown path serves the app (room links like /ABCD)
      if (/^\/[A-Z0-9]{4}$/i.test(file)) { serve(path.join(WEB, 'index.html'), res); return; }
      res.writeHead(404, { 'content-type': 'text/plain' }); res.end('Not found'); return;
    }
    serve(full, res);
  });
});
function serve(full, res) {
  const ext = path.extname(full).toLowerCase();
  res.writeHead(200, { 'content-type': TYPES[ext] || 'application/octet-stream', 'cache-control': 'no-cache' });
  fs.createReadStream(full).pipe(res);
}

// ------------------------------------------------------------ rooms
const rooms = new Map();
const sockets = new Map(); // ws -> { pid, room }
let nextPid = 1;

function roomIo() {
  const io = {
    room: null,
    send(pid, msg) { for (const [ws, c] of sockets) if (c.pid === pid && c.room === io.room) ws.send(JSON.stringify(msg)); },
    broadcast(msg) { const s = JSON.stringify(msg); for (const [ws, c] of sockets) if (c.room === io.room) ws.send(s); },
    now: () => Date.now(),
    after: (ms, fn) => setTimeout(() => { try { fn(); } catch (e) { console.error('room timer error', e); } }, ms),
  };
  return io;
}
function getOrCreateRoom(code) {
  code = (code || '').toUpperCase();
  if (code && rooms.has(code)) return rooms.get(code);
  let c = code && /^[A-Z0-9]{4}$/.test(code) ? code : makeCode();
  while (rooms.has(c)) c = makeCode();
  const io = roomIo();
  const room = new Room(c, io);
  io.room = room;
  rooms.set(c, room);
  return room;
}

const wss = new WebSocketServer(server, '/ws');
wss.on('connection', (ws) => {
  const pid = 'p' + (nextPid++) + '-' + Math.random().toString(36).slice(2, 6);
  sockets.set(ws, { pid, room: null });
  ws.on('message', (text) => {
    let msg;
    try { msg = JSON.parse(text); } catch { return; }
    if (!msg || typeof msg !== 'object') return;
    const c = sockets.get(ws);
    if (!c) return;
    if (msg.t === 'create' || msg.t === 'join') {
      try {
      if (c.room) { c.room.removePlayer(c.pid); c.room = null; }
      const room = msg.t === 'create' ? getOrCreateRoom('') : rooms.get(String(msg.code || '').toUpperCase());
      if (!room) { ws.send(JSON.stringify({ t: 'error', msg: 'No room with code ' + String(msg.code || '').toUpperCase() + '.' })); return; }
      if (room.phase !== 'lobby' && msg.t === 'join' && !msg.spectate) { ws.send(JSON.stringify({ t: 'error', msg: 'That game has already started.' })); return; }
      c.room = room;
      if (!room.addPlayer(c.pid, { name: msg.name, color: msg.color, vehicle: msg.vehicle, custom: msg.custom })) c.room = null;
      } catch (e) { console.error('join error', e); ws.send(JSON.stringify({ t: 'error', msg: 'Server hiccup: ' + e.message })); }
      return;
    }
    if (msg.t === 'leave') { if (c.room) { c.room.removePlayer(c.pid); c.room = null; } return; }
    if (c.room) { try { c.room.handle(c.pid, msg); } catch (e) { console.error('room error', e); ws.send(JSON.stringify({ t: 'error', msg: 'Server hiccup: ' + e.message })); } }
  });
  ws.on('close', () => {
    const c = sockets.get(ws);
    if (c && c.room) c.room.removePlayer(c.pid);
    sockets.delete(ws);
  });
  ws.send(JSON.stringify({ t: 'hello', version: 1 }));
});

setInterval(() => {
  const now = Date.now();
  for (const [code, room] of rooms) {
    try { room.tick(); } catch (e) { console.error('room tick error', e); }
    const empty = ![...sockets.values()].some((c) => c.room === room);
    if (empty && now - room.lastActivity > 10 * 60 * 1000) rooms.delete(code);
    else if (now - room.lastActivity > 6 * 60 * 60 * 1000) rooms.delete(code);
  }
}, 500);

process.on('uncaughtException', (e) => console.error('uncaught', e));
server.listen(PORT, HOST, () => {
  const addrs = [];
  for (const list of Object.values(os.networkInterfaces())) for (const i of list || []) if (i.family === 'IPv4' && !i.internal) addrs.push(i.address);
  console.log('Car Carnage: Belfast Edition');
  console.log('  local:   http://localhost:' + PORT);
  for (const a of addrs) console.log('  network: http://' + a + ':' + PORT + '   (share this on the same Wi-Fi)');
});
