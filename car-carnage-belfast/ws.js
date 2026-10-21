// A small WebSocket server (RFC 6455) with no dependencies: text frames, ping/pong, close,
// continuation frames. Enough for a turn-based game.
import crypto from 'node:crypto';
import { EventEmitter } from 'node:events';

const GUID = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';

export class WebSocketServer extends EventEmitter {
  constructor(httpServer, path = '/ws') {
    super();
    this.clients = new Set();
    httpServer.on('upgrade', (req, socket, head) => {
      const url = new URL(req.url, 'http://x');
      if (url.pathname !== path) { socket.destroy(); return; }
      const key = req.headers['sec-websocket-key'];
      if (!key || (req.headers.upgrade || '').toLowerCase() !== 'websocket') { socket.write('HTTP/1.1 400 Bad Request\r\n\r\n'); socket.destroy(); return; }
      const accept = crypto.createHash('sha1').update(key + GUID).digest('base64');
      socket.write('HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: ' + accept + '\r\n\r\n');
      const ws = new WebSocketConnection(socket, head);
      this.clients.add(ws);
      ws.on('close', () => this.clients.delete(ws));
      this.emit('connection', ws, req);
    });
  }
}

export class WebSocketConnection extends EventEmitter {
  constructor(socket, head) {
    super();
    this.socket = socket;
    this.buffer = Buffer.alloc(0);
    this.fragments = [];
    this.fragOp = 0;
    this.closed = false;
    socket.setNoDelay(true);
    socket.on('data', (d) => this.onData(d));
    socket.on('close', () => this.onClose());
    socket.on('error', () => this.onClose());
    socket.on('end', () => this.onClose());
    if (head && head.length) this.onData(head);
    this.pingTimer = setInterval(() => { if (!this.closed) this.sendFrame(9, Buffer.alloc(0)); }, 25000);
  }
  onClose() {
    if (this.closed) return;
    this.closed = true;
    clearInterval(this.pingTimer);
    this.emit('close');
    try { this.socket.destroy(); } catch { /* ignore */ }
  }
  onData(data) {
    this.buffer = this.buffer.length ? Buffer.concat([this.buffer, data]) : data;
    while (true) {
      const b = this.buffer;
      if (b.length < 2) return;
      const fin = (b[0] & 0x80) !== 0, op = b[0] & 0x0f, masked = (b[1] & 0x80) !== 0;
      let len = b[1] & 0x7f, off = 2;
      if (len === 126) { if (b.length < 4) return; len = b.readUInt16BE(2); off = 4; }
      else if (len === 127) { if (b.length < 10) return; const big = b.readBigUInt64BE(2); if (big > 16n * 1024n * 1024n) { this.close(1009); return; } len = Number(big); off = 10; }
      if (masked) off += 4;
      if (b.length < off + len) return;
      let payload = b.subarray(off, off + len);
      if (masked) { const mask = b.subarray(off - 4, off); const out = Buffer.allocUnsafe(len); for (let i = 0; i < len; i++) out[i] = payload[i] ^ mask[i & 3]; payload = out; }
      this.buffer = b.subarray(off + len);
      if (op === 0x8) { this.sendFrame(0x8, Buffer.alloc(0)); this.onClose(); return; }
      if (op === 0x9) { this.sendFrame(0xA, payload); continue; }
      if (op === 0xA) continue;
      if (op === 0x1 || op === 0x2 || op === 0x0) {
        if (op !== 0) this.fragOp = op;
        this.fragments.push(payload);
        if (fin) {
          const whole = this.fragments.length === 1 ? this.fragments[0] : Buffer.concat(this.fragments);
          this.fragments = [];
          if (this.fragOp === 1) this.emit('message', whole.toString('utf8'));
          else this.emit('binary', whole);
        }
      }
    }
  }
  sendFrame(op, payload) {
    if (this.closed) return;
    const len = payload.length;
    let header;
    if (len < 126) { header = Buffer.allocUnsafe(2); header[1] = len; }
    else if (len < 65536) { header = Buffer.allocUnsafe(4); header[1] = 126; header.writeUInt16BE(len, 2); }
    else { header = Buffer.allocUnsafe(10); header[1] = 127; header.writeBigUInt64BE(BigInt(len), 2); }
    header[0] = 0x80 | op;
    try { this.socket.write(Buffer.concat([header, payload])); } catch { this.onClose(); }
  }
  send(text) { this.sendFrame(0x1, Buffer.from(typeof text === 'string' ? text : JSON.stringify(text), 'utf8')); }
  close(code = 1000) {
    if (this.closed) return;
    const b = Buffer.allocUnsafe(2); b.writeUInt16BE(code, 0);
    this.sendFrame(0x8, b);
    setTimeout(() => this.onClose(), 200);
  }
}
