// Renders the sound effects and four bars of the battle theme through an OfflineAudioContext to a WAV,
// and prints the loudness of each half second so silence shows up. Needs `npm i playwright`.
// Usage: node tools/render-audio-preview.js [out.wav]; then e.g. ffmpeg -i out.wav -q:a 4 docs/audio-preview.mp3
const { chromium } = require('playwright');
const fs = require('fs');
(async () => {
  const browser = await chromium.launch({ executablePath: process.env.PW_CHROMIUM || undefined });
  const page = await browser.newPage();
  page.on('pageerror', e => console.log('PAGEERROR', e.message));
  await page.goto('file://' + require('path').resolve(__dirname, '../index.html'));
  const res = await page.evaluate(async () => {
    const S = TA.Sfx; S.strict = true;
    const SR = 44100, DUR = 36;
    const off = new OfflineAudioContext(2, SR * DUR, SR);
    // The game created its own context on load? It only does so on input, so inject ours.
    if (!S.ensure(off)) return { error: 'ensure failed' };
    const cue = [];
    const at = (t, name, ...args) => { S.at(t); S[name](...args); cue.push([t, name]); };
    at(0.2, 'blip'); at(0.5, 'select');
    at(1.2, 'launch'); at(2.0, 'explosion', 1);
    at(3.0, 'legHit'); at(3.3, 'legHit'); at(3.9, 'ricochet');
    at(4.8, 'footstep', 1); at(5.5, 'footstep', 1); at(6.2, 'footstep', 1.3);
    at(7.0, 'siren', 1.5); at(8.6, 'heatRay', 1.1); at(9.0, 'scream'); at(9.4, 'burn'); at(9.7, 'scream');
    at(10.6, 'legBreak'); at(11.2, 'collapse');
    at(13.2, 'saved'); at(13.8, 'fanfare');
    at(15.2, 'hurt'); at(15.9, 'stomp'); at(16.8, 'alarm');
    S.at(0);
    const end = S.renderSong('battle', 18.0, 64);       // four bars of the battle theme
    cue.push([18.0, 'music:battle']);
    at(end + 0.3, 'cleared'); at(end + 2.2, 'gameOver'); at(end + 4.2, 'victory');
    const buf = await off.startRendering();
    const L = buf.getChannelData(0), R = buf.getChannelData(1);
    // RMS per half second, so we can see which cues made sound
    const rms = []; const win = SR / 2;
    for (let i = 0; i + win <= L.length; i += win) { let e = 0; for (let j = i; j < i + win; j++) e += L[j] * L[j]; rms.push(Math.sqrt(e / win)); }
    // 16-bit PCM WAV
    const n = L.length, bytes = 44 + n * 4, dv = new DataView(new ArrayBuffer(bytes));
    const w = (o, s) => { for (let i = 0; i < s.length; i++) dv.setUint8(o + i, s.charCodeAt(i)); };
    w(0, 'RIFF'); dv.setUint32(4, bytes - 8, true); w(8, 'WAVE'); w(12, 'fmt '); dv.setUint32(16, 16, true); dv.setUint16(20, 1, true); dv.setUint16(22, 2, true);
    dv.setUint32(24, SR, true); dv.setUint32(28, SR * 4, true); dv.setUint16(32, 4, true); dv.setUint16(34, 16, true); w(36, 'data'); dv.setUint32(40, n * 4, true);
    let peak = 0;
    for (let i = 0, o = 44; i < n; i++, o += 4) { const l = Math.max(-1, Math.min(1, L[i])), r = Math.max(-1, Math.min(1, R[i])); peak = Math.max(peak, Math.abs(l)); dv.setInt16(o, l * 32767, true); dv.setInt16(o + 2, r * 32767, true); }
    let bin = ''; const u8 = new Uint8Array(dv.buffer); for (let i = 0; i < u8.length; i += 0x8000) bin += String.fromCharCode.apply(null, u8.subarray(i, i + 0x8000));
    return { cue, rms: rms.map(v => +v.toFixed(3)), peak: +peak.toFixed(3), wav: btoa(bin), end };
  });
  if (res.error) { console.log(res.error); process.exit(1); }
  fs.writeFileSync((process.argv[2] || require('os').tmpdir() + '/tripod-attack-preview.wav'), Buffer.from(res.wav, 'base64'));
  console.log('peak', res.peak, 'music end', res.end.toFixed(1));
  console.log('cues', JSON.stringify(res.cue));
  console.log('rms per 0.5s', JSON.stringify(res.rms));
  await browser.close();
})();
