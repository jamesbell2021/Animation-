// Drives the game headlessly in Chromium and screenshots every screen. Needs `npm i playwright`
// (and a Chromium it can find, or PW_CHROMIUM=/path/to/chrome). Usage: node tools/smoke-test.js [outdir]
const { chromium } = require('playwright');
const path = require('path');
const OUT = process.argv[2] || require('os').tmpdir() + '/tripod-attack-shots';
require('fs').mkdirSync(OUT, { recursive: true });
(async () => {
  const browser = await chromium.launch({ executablePath: process.env.PW_CHROMIUM || undefined, args: ['--autoplay-policy=no-user-gesture-required'] });
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  const errors = [];
  page.on('pageerror', e => errors.push('PAGEERROR ' + e.message + '\n' + e.stack));
  page.on('console', m => { if (m.type() === 'error' || m.type() === 'warning') errors.push('CONSOLE ' + m.type() + ': ' + m.text()); });
  await page.goto('file://' + path.resolve(__dirname, '../index.html'));
  await page.waitForTimeout(2500);
  await page.screenshot({ path: OUT + '/01-title.png' });
  // attract mode for a while, then force a collapse
  await page.evaluate(() => { TA.G.attractT = 100; TA.G.typed = 100; });
  await page.waitForTimeout(3500);
  await page.screenshot({ path: OUT + '/02-title-attract.png' });
  // map
  await page.evaluate(() => TA.startCampaign(true));
  await page.waitForTimeout(800);
  await page.screenshot({ path: OUT + '/03-map.png' });
  await page.evaluate(() => TA.press());
  await page.waitForTimeout(1500);
  await page.screenshot({ path: OUT + '/04-intro.png' });
  await page.evaluate(() => { TA.G.typed = 100; TA.press(); });
  await page.waitForTimeout(3000);
  await page.screenshot({ path: OUT + '/05-play-wave1.png' });
  // Put a tripod in range and fire rockets at its legs with a sweep of angles.
  const legRes = await page.evaluate(async () => {
    const G = TA.G, P = TA.P;
    G.tripods.length = 0; G.waveInfo.toSpawn = 0;
    TA.spawnTripod(TA.waveConfig(), false);
    const tp = G.tripods[0]; tp.x = 620; tp.cool = 999; for (const l of tp.legs) { l.footX = tp.x + l.footX - (tp.x + 0) ; }
    tp.legs.forEach((l, i) => l.footX = tp.x + tp.rest[i]);
    let hits = 0, shots = 0;
    for (let a = -1.1; a < 0; a += 0.06) {
      P.angle = a; P.power = 700 + Math.random() * 200; P.reload = 0;
      if (TA.fireRocket()) shots++;
      for (let i = 0; i < 90; i++) TA.update(1 / 60);
      if (tp.legs.some(l => l.hp < l.max) || tp.dynamic) hits++;
      if (tp.dynamic) break;
    }
    return { shots, hits, dynamic: tp.dynamic, legs: tp.legs.map(l => l.hp), score: G.score };
  });
  console.log('rocket sweep:', JSON.stringify(legRes));
  await page.waitForTimeout(600);
  await page.screenshot({ path: OUT + '/06-collapse.png' });
  // Siren + heat ray with the player standing, then ducking
  const beamRes = await page.evaluate(async () => {
    const G = TA.G, P = TA.P;
    G.tripods.length = 0; G.waveInfo.toSpawn = 0; G.lives = 4;
    TA.spawnTripod(TA.waveConfig(), false);
    const tp = G.tripods[0]; tp.x = 560; tp.legs.forEach((l, i) => l.footX = tp.x + tp.rest[i]); tp.cool = 0;
    let sawSiren = false, sawFire = false; const states = [];
    for (let i = 0; i < 60 * 4; i++) { TA.update(1 / 60); if (tp.state === 'siren') sawSiren = true; if (tp.state === 'fire') sawFire = true; if (!states.includes(tp.state)) states.push(tp.state); }
    const livesAfterStanding = G.lives;
    // now duck for the next one
    tp.cool = 0; P.inv = 0; P.keys.duck = true;
    for (let i = 0; i < 60 * 4; i++) TA.update(1 / 60);
    P.keys.duck = false;
    return { sawSiren, sawFire, states, livesAfterStanding, livesAfterDuck: G.lives, dodged: G.stats.dodged };
  });
  console.log('beam:', JSON.stringify(beamRes));
  // Freeze a beam mid-sweep for a screenshot
  await page.evaluate(() => { const tp = TA.G.tripods[0]; tp.cool = 0; tp.state = 'walk'; TA.P.inv = 99; });
  await page.waitForTimeout(1500);
  for (let i = 0; i < 30; i++) { const s = await page.evaluate(() => TA.G.tripods[0] && TA.G.tripods[0].state); if (s === 'fire') break; await page.waitForTimeout(100); }
  await page.waitForTimeout(300);
  await page.screenshot({ path: OUT + '/07-heatray.png' });
  // Long soak: simulate ~4 minutes of play quickly and look for NaN or errors
  const soak = await page.evaluate(() => {
    const G = TA.G, P = TA.P; let nan = 0, maxTripods = 0;
    for (let i = 0; i < 60 * 240; i++) {
      if (i % 50 === 0) { P.angle = -0.3 - Math.random() * 0.9; P.power = 500 + Math.random() * 400; TA.fireRocket(); }
      P.keys.duck = G.tripods.some(t => t.alive && (t.state === 'siren' || t.state === 'fire'));
      TA.update(1 / 60);
      G.lives = Math.max(G.lives, 2);
      maxTripods = Math.max(maxTripods, G.tripods.length);
      for (const t of G.tripods) { if (!isFinite(t.x) || !isFinite(t.y)) nan++; if (t.world) for (const p of t.world.particles) if (!isFinite(p.x) || !isFinite(p.y)) nan++; }
      for (const p of G.parts) if (!isFinite(p.x)) nan++;
    }
    return { nan, maxTripods, state: G.state, wave: G.wave, score: G.score, stats: G.stats, parts: G.parts.length, debris: G.debris.length, civs: G.civs.length, tripods: G.tripods.length };
  });
  console.log('soak:', JSON.stringify(soak));
  await page.screenshot({ path: OUT + '/08-soak.png' });
  // Sector cleared flow
  const clr = await page.evaluate(() => {
    const G = TA.G; G.state = 'play'; G.dying = false; G.nextWaveT = 0; G.banner = null;
    G.wave = 3; G.waveInfo.toSpawn = 0; G.waveInfo.clearT = 0; for (const t of G.tripods) { t.alive = false; t.gone = true; }
    for (let i = 0; i < 60 * 4; i++) TA.update(1 / 60);
    return { state: G.state, cleared: G.save.cleared, lives: G.lives };
  });
  console.log('cleared:', JSON.stringify(clr));
  await page.waitForTimeout(500);
  await page.screenshot({ path: OUT + '/09-cleared.png' });
  await page.evaluate(() => { TA.G.stateT = 5; TA.press(); });
  await page.waitForTimeout(500);
  await page.screenshot({ path: OUT + '/10-map-after.png' });
  // Game over via overrun
  const go = await page.evaluate(() => {
    const G = TA.G; TA.press(); G.typed = 100; TA.press();
    G.lives = 1; G.tripods.length = 0; G.waveInfo.toSpawn = 0; TA.spawnTripod(TA.waveConfig(), false); const tp = G.tripods[0]; tp.x = 336; tp.cool = 999;
    for (let i = 0; i < 60 * 4; i++) TA.update(1 / 60);
    return { state: G.state, lives: G.lives, lost: G.lostSector, cleared: G.save.cleared };
  });
  console.log('gameover:', JSON.stringify(go));
  await page.waitForTimeout(500);
  await page.screenshot({ path: OUT + '/11-gameover.png' });
  // Victory
  const vic = await page.evaluate(() => {
    const G = TA.G; G.save.cleared = new Array(10).fill(true); G.save.cleared[9] = false; G.save.campaignDone = false;
    TA.startCampaign(false); TA.press(); G.typed = 100; TA.press();
    G.wave = 3; G.waveInfo.toSpawn = 0; G.waveInfo.clearT = 0; G.tripods.length = 0;
    for (let i = 0; i < 60 * 4; i++) TA.update(1 / 60);
    G.stateT = 5; TA.press();
    return { state: G.state, done: G.save.campaignDone };
  });
  console.log('victory:', JSON.stringify(vic));
  await page.waitForTimeout(800);
  await page.screenshot({ path: OUT + '/12-victory.png' });
  // Endless
  const endless = await page.evaluate(() => { const G = TA.G; TA.press(); TA.G.menuIdx = TA.G.save.campaignDone ? 1 : 0; TA.press(); G.typed = 100; TA.press(); for (let i = 0; i < 60 * 20; i++) { TA.G.lives = 4; TA.update(1 / 60); } return { state: G.state, endless: G.endless, wave: G.wave, cfg: TA.waveConfig() }; });
  console.log('endless:', JSON.stringify(endless));
  await page.screenshot({ path: OUT + '/13-endless.png' });
  // Narrow phone-ish viewport and touch duck zone
  await page.setViewportSize({ width: 740, height: 360 });
  await page.evaluate(() => { TA.G.touch = true; });
  await page.waitForTimeout(400);
  await page.screenshot({ path: OUT + '/14-phone.png' });
  console.log('ERRORS:', errors.length ? errors.join('\n') : 'none');
  await browser.close();
})().catch(e => { console.error('TEST FAILED', e); process.exit(1); });
