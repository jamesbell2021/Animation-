// Renders the itch.io art from the game's own vector art with Playwright and Chromium:
//   node launch/make_art.mjs            (starts the game server itself on port 8098)
// Writes launch/out/cover_630x500.png, launch/out/banner_1920x480.png and one 1280x720 screenshot
// per arena (launch/out/shot_<arena>.png).
import path from 'node:path';
import fs from 'node:fs';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { spawn } from 'node:child_process';
const __dirname = path.dirname(fileURLToPath(import.meta.url));
let chromium;
try { ({ chromium } = await import('playwright')); } catch { ({ chromium } = await import('/opt/node-tools/node_modules/playwright/index.mjs')); }
const OUT = path.join(__dirname, 'out'); fs.mkdirSync(OUT, { recursive: true });
const PORT = 8098;
const server = spawn(process.execPath, [path.join(__dirname, '..', 'server.js'), String(PORT)], { stdio: 'ignore' });
await new Promise((r) => setTimeout(r, 800));
const INDEX = `http://localhost:${PORT}/`;
const browser = await chromium.launch();

async function title(w, h, file, scale = 1) {
  const page = await browser.newPage({ viewport: { width: w, height: h }, deviceScaleFactor: scale });
  await page.goto(INDEX); await page.waitForTimeout(1200);
  // a busier arena for the cover, with the camera on the cars rather than the whole map
  await page.evaluate(() => { const a = window.ccb.app; if (a.attract) { a.attract.close(); a.attract = null; } const { LocalLink } = window.ccb.net; const link = new LocalLink(); a.attract = link; link.onMessage((m) => { if (m.t === 'start') { window.ccb.renderer.setMap(window.ccb.getMap(m.mapId)); window.ccb.renderer.setState(m.vehicles, m.counters, m.walls); window.__g = { vehicles: m.vehicles }; } else if (m.t === 'turn') { const before = window.__g.vehicles; window.__g.vehicles = m.vehicles; window.ccb.renderer.play(m.timeline, before, { duration: 5, director: false }); } }); link.room.mapId = 'cityhall'; link.room.options.playbackSeconds = 5; link.room.options.startSpeed = 40; for (let i = 0; i < 8; i++) link.room.addBot(); link.room.start(); document.querySelector('.menu').style.display = 'none'; document.querySelector('.credits').style.display = 'none'; document.getElementById('toast').style.display = 'none'; });
  let best = -1;
  for (let i = 0; i < 40; i++) {
    await page.waitForTimeout(350);
    await page.evaluate(() => { const r = window.ccb.renderer; const cars = r.currentVehicles().filter((v) => v.status === 'alive'); if (!cars.length) return; let cx = 0, cy = 0; for (const c of cars) { cx += c.x; cy += c.y; } cx /= cars.length; cy /= cars.length; r.camMode = 'free'; r.userMoved = r.time; r.camTarget = { x: cx, y: cy, zoom: Math.min(r.W, r.H) / 16 }; });
    const n = await page.evaluate(() => window.ccb.fx.p.length + window.ccb.fx.beams.length * 40);
    if (n > best) { best = n; await page.screenshot({ path: path.join(OUT, file) }); }
  }
  await page.close();
}
await title(630, 500, 'cover_630x500.png');
await title(1920, 480, 'banner_1920x480.png');

// one screenshot per arena from a bot match, at the moment with the most going on
const { MAPS } = await import(pathToFileURL(path.join(__dirname, '..', 'web', 'shared', 'maps.js')).href);
for (const map of MAPS) {
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  await page.goto(INDEX); await page.waitForTimeout(500);
  await page.evaluate((id) => { const a = window.ccb.app; if (a.attract) { a.attract.close(); a.attract = null; } document.getElementById('ui').style.display = 'none'; window.ccb.renderer.showLabels = true; window.__map = id; }, map.id);
  await page.evaluate((id) => { const { LocalLink } = window.ccb.net; const link = new LocalLink(); window.ccb.app.attract = link; link.onMessage((m) => { if (m.t === 'start') { const map = window.ccb.getMap(m.mapId); window.ccb.renderer.setMap(map); window.ccb.renderer.setState(m.vehicles, m.counters, m.walls); window.__g = { vehicles: m.vehicles }; } else if (m.t === 'turn') { const before = window.__g.vehicles; window.__g.vehicles = m.vehicles; window.ccb.renderer.play(m.timeline, before, { duration: 5, director: true, onDone: () => window.ccb.renderer.setState(m.vehicles, m.counters, m.walls) }); } }); link.room.mapId = id; link.room.options.playbackSeconds = 5; for (let i = 0; i < 8; i++) link.room.addBot(); link.room.start(); }, map.id);
  let best = -1;
  for (let i = 0; i < 70; i++) {
    await page.waitForTimeout(400);
    const n = await page.evaluate(() => window.ccb.fx.p.length + window.ccb.fx.beams.length * 40 + window.ccb.fx.rings.length * 60);
    if (n > best) { best = n; await page.screenshot({ path: path.join(OUT, `shot_${map.id}.png`) }); }
  }
  console.log(map.id, 'best moment score', best);
  await page.close();
}
await browser.close();
server.kill();
console.log('written to', OUT);
