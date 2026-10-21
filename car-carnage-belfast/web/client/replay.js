// Car Carnage: Belfast Edition - the cinematic replay director.
// Plays the whole match back turn by turn with a camera that hunts for the action, slow-mo on the
// big hits, title cards and captions. Anyone can skip it.

const BIG = new Set(['explode', 'death', 'roll', 'vault', 'jump', 'mine', 'breach']);

export class Cinematic {
  constructor(renderer, fx, audio, ui) {
    this.r = renderer; this.fx = fx; this.audio = audio; this.ui = ui;
    this.active = false;
  }
  start(history, startVehicles, players, standings, onDone) {
    this.history = history; this.players = players; this.standings = standings; this.onDone = onDone;
    this.turnIndex = 0; this.active = true; this.r.cinematic = true; this.r.camMode = 'cine'; this.r.showLabels = true;
    this.before = startVehicles.map((v) => ({ ...v }));
    this.ui.show(true); this.ui.caption('');
    this.audio.setMode('replay');
    this.fx.clear();
    this.r.breached = new Set(); this.r.counters = [];
    if (this.r.mctx) this.r.mctx.clearRect(0, 0, 1e4, 1e4);
    this.r.setState(this.before, [], null);
    this.ui.title('THE CARNAGE');
    this.wait = 1.6; this.phaseOfTurn = 'title';
  }
  skip() { if (!this.active) return; this.finish(); }
  finish() {
    this.active = false; this.r.cinematic = false; this.r.stopPlayback(); this.ui.show(false); this.ui.title(''); this.ui.caption('');
    this.r.camMode = 'overview'; this.fx.clear();
    if (this.onDone) this.onDone();
  }
  nextTurn() {
    const h = this.history[this.turnIndex];
    if (!h) { this.ui.title('FINAL STANDINGS'); this.phaseOfTurn = 'end'; this.wait = 2.2; this.audio.sting('win'); return; }
    const tl = h.timeline;
    this.ui.title('TURN ' + h.turn); this.titleTimer = 1.1;
    // who is this turn about? the car in the most events
    const score = {};
    for (const e of tl.events) { for (const k of ['id', 'from', 'to', 'a', 'b']) if (e[k] != null) score[e[k]] = (score[e[k]] || 0) + (BIG.has(e.type) ? 6 : e.type === 'shot' && e.hit ? 2 : 1); }
    let subject = null, best = -1;
    for (const v of this.before) if (v.status === 'alive' && (score[v.id] || 0) > best) { best = score[v.id] || 0; subject = v.id; }
    this.subject = subject;
    this.interest = tl.events.filter((e) => BIG.has(e.type) || (e.type === 'collision' && e.speed >= 30) || (e.type === 'shot' && e.hit && e.dmg >= 6)).map((e) => ({ t: e.t, e }));
    this.calm = this.interest.length === 0 && best < 4;
    const dur = this.calm ? 2.2 : 4.5;
    this.r.setState(this.before, h.countersBefore || [], null);
    this.r.play(tl, this.before, {
      duration: dur, cinematic: true, director: false,
      onDone: () => { this.before = h.vehicles.map((v) => ({ ...v })); this.r.setState(this.before, h.counters, h.walls); this.turnIndex++; this.phaseOfTurn = 'gap'; this.wait = 0.5; },
      onBig: (kind, e) => this.captionFor(kind, e),
      onLog: () => {},
    });
    this.phaseOfTurn = 'play';
  }
  captionFor(kind, e) {
    const name = (id) => { const v = this.before.find((x) => x.id === id); return v ? v.owner.name.toUpperCase() : '?'; };
    if (kind === 'death') this.ui.caption(e.by != null && e.by !== e.id ? `${name(e.by)} TAKES OUT ${name(e.id)}` : `${name(e.id)} IS OUT`);
    else if (kind === 'explode') this.ui.caption(`${name(e.id)} GOES UP`);
    else if (kind === 'roll') this.ui.caption(`${name(e.id)} ROLLS IT`);
    else if (kind === 'vault') this.ui.caption(`${name(e.id)} TAKES FLIGHT`);
    this.captionTimer = 2.2;
  }
  update(dt) {
    if (!this.active) return;
    if (this.titleTimer > 0) { this.titleTimer -= dt; if (this.titleTimer <= 0) this.ui.title(''); }
    if (this.captionTimer > 0) { this.captionTimer -= dt; if (this.captionTimer <= 0) this.ui.caption(''); }
    if (this.phaseOfTurn === 'title' || this.phaseOfTurn === 'gap') { this.wait -= dt; if (this.wait <= 0) { this.ui.title(''); this.nextTurn(); } this.driftCamera(dt); return; }
    if (this.phaseOfTurn === 'end') { this.wait -= dt; if (this.wait <= 0) this.finish(); return; }
    // the camera during play
    const p = this.r.playback; if (!p) return;
    const W = this.r.W, H = this.r.H, base = Math.min(W, H);
    let target = null, zoom = base / 13;
    for (const it of this.interest) {
      if (p.pos >= it.t - 7 && p.pos <= it.t + 9) {
        const e = it.e; const id = e.id ?? e.a ?? e.to;
        const v = id != null ? this.r.vehicleAt(id) : null;
        target = v ? [v.x, v.y] : e.x != null ? [e.x, e.y] : null;
        zoom = base / (e.type === 'shot' || e.type === 'collision' ? 11 : 8);
        if (target) break;
      }
    }
    if (!target && this.subject != null) { const v = this.r.vehicleAt(this.subject); if (v) { target = [v.x + Math.cos(v.heading) * 1.2, v.y + Math.sin(v.heading) * 1.2]; zoom = this.calm ? base / 18 : base / 13; } }
    if (!target) { this.r.fitMap(false); return; }
    this.r.camTarget.x = target[0]; this.r.camTarget.y = target[1]; this.r.camTarget.zoom = Math.max(this.r.minZoom(), zoom);
  }
  driftCamera(dt) {
    // between turns: a slow pull back over the map
    this.r.camTarget.zoom = Math.max(this.r.minZoom(), this.r.camTarget.zoom * (1 - dt * 0.08));
  }
}
