// End-to-end test with Playwright and the real server: a local game to the end with the cinematic replay,
// then an online game with two browsers. Run with `npm run test:e2e` (needs the playwright package).
import { spawn } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PORT = 8097;
const shots = process.env.SHOTS || '/tmp/ccb-shots';
let chromium;
try { ({ chromium } = await import('playwright')); } catch { try { ({ chromium } = await import('/opt/node-tools/node_modules/playwright/index.mjs')); } catch { console.log('playwright not installed; skipping e2e'); process.exit(0); } }

const server = spawn(process.execPath, [path.join(__dirname, '..', 'server.js'), String(PORT)], { stdio: 'ignore' });
await new Promise((r) => setTimeout(r, 800));
const browser = await chromium.launch();
const errors = [];
const newPage = async (w = 1280, h = 800) => { const ctx = await browser.newContext({ viewport: { width: w, height: h } }); const page = await ctx.newPage(); page.on('pageerror', (e) => errors.push('pageerror: ' + e.message)); page.on('console', (m) => { if (m.type() === 'error') errors.push('console: ' + m.text()); }); await page.goto(`http://localhost:${PORT}/`); return page; };
let failures = 0;
const check = (c, m) => { if (!c) { failures++; console.log('  FAIL', m); } else console.log('  ok  ', m); };

try {
  // ---------------- local game, 2 humans hot-seat + 4 bots, short match
  const p = await newPage();
  await p.click('[data-go="local"]'); await p.click('#local-humans-plus'); await p.click('#local-bots-minus'); await p.click('#btn-local-start');
  await p.waitForTimeout(500);
  await p.selectOption('#opt-maxTurns', '15'); await p.selectOption('#opt-playbackSeconds', '3');
  await p.click('#lobby-maps .map:nth-child(3)'); await p.waitForTimeout(300);
  await p.screenshot({ path: shots + '/lobby-local.png' });
  await p.click('#btn-start'); await p.waitForTimeout(1200);
  check(await p.isVisible('#passover'), 'hot-seat pass-over shows for the first player');
  await p.click('#btn-pass-ok'); await p.waitForTimeout(300);
  await p.click('#orders .speed-row button:last-child'); await p.click('#orders .steer-row:nth-child(1) button:nth-child(8)');
  await p.waitForTimeout(200); await p.screenshot({ path: shots + '/planning.png' });
  const risk = await p.textContent('#orders .risk'); check(/D|safe/.test(risk), 'risk readout present: ' + risk);
  await p.click('#btn-action'); await p.waitForTimeout(300);
  check(await p.isVisible('#passover'), 'pass-over for the second player');
  await p.click('#btn-pass-ok'); await p.waitForTimeout(200);
  await p.click('#btn-action');
  await p.waitForTimeout(1800); await p.screenshot({ path: shots + '/action.png' });
  // let the rest of the match run with fast forward, locking in straight away each turn
  let turns = 0, lastTurn = 0;
  for (let i = 0; i < 400; i++) {
    await p.waitForTimeout(400);
    const st = await p.evaluate(() => ({ playing: window.ccb.app.playing, planning: window.ccb.app.planningOpen, over: window.ccb.app.game && window.ccb.app.game.over, pass: !document.getElementById('passover').classList.contains('hidden'), turn: window.ccb.app.game && window.ccb.app.game.turn }));
    if (st.over) break;
    lastTurn = st.turn;
    if (st.playing) { await p.click('#btn-ff').catch(() => {}); continue; }
    if (st.pass) { await p.click('#btn-pass-ok'); await p.waitForTimeout(100); }
    if (st.planning) { const b = await p.$('#btn-action:not([disabled])'); if (b) { await b.click(); turns++; } }
  }
  await p.waitForTimeout(1500);
  check(await p.isVisible('#results'), 'results screen after the match (' + turns + ' locks, turn ' + lastTurn + ')');
  await p.screenshot({ path: shots + '/results.png' });
  await p.click('#btn-watch-local'); await p.waitForTimeout(2500);
  check(await p.isVisible('#cinematic'), 'cinematic replay runs');
  await p.screenshot({ path: shots + '/replay.png' });
  await p.click('#btn-cine-skip'); await p.waitForTimeout(500);
  check(await p.isVisible('#results'), 'skip returns to results');
  await p.click('#btn-results-menu'); await p.waitForTimeout(300);
  check(await p.isVisible('#screen-title'), 'back to the title');

  // ---------------- online: host + joiner
  const a = await newPage(), b = await newPage();
  await a.click('[data-go="online"]'); await a.fill('#online-name', 'Host'); await a.click('#btn-create'); await a.waitForTimeout(600);
  const code = await a.textContent('#lobby-code');
  check(/^[A-Z0-9]{4}$/.test(code.trim()), 'room code ' + code);
  await b.click('[data-go="online"]'); await b.fill('#online-name', 'Guest'); await b.fill('#join-code', code.trim()); await b.click('#btn-join'); await b.waitForTimeout(800);
  check((await b.textContent('#lobby-code')).trim() === code.trim(), 'guest joined the room');
  await a.click('#btn-add-bot'); await a.waitForTimeout(200);
  await b.click('#lobby-garage .car:nth-child(5)'); await b.click('#btn-ready'); await a.click('#btn-ready'); await a.waitForTimeout(400);
  await a.screenshot({ path: shots + '/lobby-online.png' });
  check(!(await a.isDisabled('#btn-start')), 'host can start once everyone is ready');
  await a.click('#btn-start'); await a.waitForTimeout(1500);
  check(await a.isVisible('#hud') && await b.isVisible('#hud'), 'both clients in the game');
  await b.click('#orders .speed-row button:last-child'); await b.click('#btn-action'); await a.waitForTimeout(400);
  const waitA = await a.textContent('#action-wait'); check(/Host/.test(waitA), 'host sees it is waiting on them: ' + waitA);
  await a.click('#btn-action'); await a.waitForTimeout(2500);
  const playingB = await b.evaluate(() => window.ccb.app.playing); check(playingB, 'guest plays the turn back');
  await b.screenshot({ path: shots + '/online-action.png' });
  await a.waitForTimeout(5500);
  const t2 = await a.textContent('#hud-turn'); check(/TURN 2/.test(t2), 'turn 2 reached on the host: ' + t2);
  const t2b = await b.textContent('#hud-turn'); check(/TURN 2/.test(t2b), 'turn 2 reached on the guest: ' + t2b);
  // mobile layout
  const m = await newPage(390, 844);
  await m.click('[data-go="local"]'); await m.click('#btn-local-start'); await m.waitForTimeout(400); await m.click('#btn-start'); await m.waitForTimeout(1200);
  await m.screenshot({ path: shots + '/mobile.png' });
  check(await m.isVisible('#btn-action'), 'action button visible on a phone');
} catch (e) { failures++; console.log('  FAIL exception', e.stack); }
console.log('page errors:', errors.length ? errors.join('\n') : 'none');
if (errors.length) failures++;
await browser.close();
server.kill();
console.log(failures ? failures + ' failures' : 'all e2e checks passed');
process.exit(failures ? 1 : 0);
