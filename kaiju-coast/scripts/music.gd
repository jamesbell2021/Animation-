class_name Music
extends Node
## The soundtrack: taiko and shime-daiko over a four-on-the-floor kick with side-chain pumping,
## shamisen bass, a pentatonic synth arp, koto melodies with echo and a shakuhachi lead, all in the
## Japanese In scale on D. Four loops (title, calm, battle, boss) are composed from fixed seeds and
## rendered on a background thread at startup, then cached in user:// so later launches are instant.

const CACHE_VERSION: int = 3
const SCALE: Array[int] = [0, 1, 5, 7, 8]
const PROG: Array[int] = [0, -4, -7, -5]          ## D, Bb, G, A
const MODES: Array[String] = ["title", "calm", "battle", "boss"]

var enabled: bool = true
var mode: String = "title"
var streams: Dictionary = {}
var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _cur: AudioStreamPlayer
var _thread: Thread
var _mutex: Mutex = Mutex.new()
var _pending: Array = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	enabled = bool(Game.load_setting("music", true))
	_a = AudioStreamPlayer.new()
	_b = AudioStreamPlayer.new()
	_a.bus = "Music"
	_b.bus = "Music"
	add_child(_a)
	add_child(_b)
	_cur = _a
	for m: String in MODES:
		var path: String = "user://music_%s_v%d.res" % [m, CACHE_VERSION]
		if ResourceLoader.exists(path):
			var s: Resource = ResourceLoader.load(path)
			if s is AudioStreamWAV:
				streams[m] = s
	if streams.size() < MODES.size():
		_thread = Thread.new()
		_thread.start(_render_all)
	else:
		_start(mode)


func _process(_delta: float) -> void:
	_mutex.lock()
	var ready: Array = _pending.duplicate()
	_pending.clear()
	_mutex.unlock()
	for m: String in ready:
		if m == mode and not _cur.playing:
			_start(m)


func _exit_tree() -> void:
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()


func set_enabled(on: bool) -> void:
	enabled = on
	Game.save_setting("music", on)
	var db: float = 0.0 if on else -80.0
	_a.volume_db = db if _a == _cur else -80.0
	_b.volume_db = db if _b == _cur else -80.0


func set_mode(m: String) -> void:
	if m == mode and _cur.playing:
		return
	mode = m
	if streams.has(m):
		_start(m)


func _start(m: String) -> void:
	var nxt: AudioStreamPlayer = _b if _cur == _a else _a
	var prev: AudioStreamPlayer = _cur
	nxt.stream = streams[m]
	nxt.volume_db = -40.0
	nxt.play()
	_cur = nxt
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(nxt, "volume_db", 0.0 if enabled else -80.0, 1.2)
	if prev.playing:
		tw.tween_property(prev, "volume_db", -60.0, 1.2)
		tw.chain().tween_callback(prev.stop)


func _render_all() -> void:
	# Title first so the menu has music as soon as possible.
	for m: String in MODES:
		if streams.has(m):
			continue
		var w: AudioStreamWAV = render(m)
		ResourceSaver.save(w, "user://music_%s_v%d.res" % [m, CACHE_VERSION])
		_mutex.lock()
		streams[m] = w
		_pending.append(m)
		_mutex.unlock()


# ------------------------------------------------------------------ composer --

func _scale_note(deg: int, base: int = 62) -> int:
	var d: int = ((deg % 5) + 5) % 5
	return base + SCALE[d] + 12 * int(floor(float(deg) / 5.0))


func _phrase() -> Array:
	var p: Array = []
	var d: int = 5 + _rng.randi_range(0, 2)
	for i: int in range(16):
		var chance: float = 0.92 if i % 4 == 0 else (0.55 if i % 2 == 0 else 0.28)
		if _rng.randf() < chance:
			d = clampi(d + [-2, -1, -1, 1, 1, 2, 0, 3, -3][_rng.randi() % 9], 2, 12)
			p.append(d)
		else:
			p.append(-99)
	return p


func render(m: String) -> AudioStreamWAV:
	_rng.seed = {"title": 101, "calm": 202, "battle": 303, "boss": 404}[m]
	var bpm: float = {"title": 136.0, "calm": 124.0, "battle": 142.0, "boss": 154.0}[m]
	var hot: bool = m != "calm"
	var boss: bool = m == "boss"
	var bars: int = 8
	var sd: float = 60.0 / bpm / 4.0
	var length: float = sd * 16.0 * float(bars)
	var main: PackedFloat32Array = Synth.alloc(length + 2.5)
	var duck: PackedFloat32Array = Synth.alloc(length + 2.5)
	var send: PackedFloat32Array = Synth.alloc(length + 2.5)
	var kicks: Array[float] = []
	var phrase_a: Array = []
	var phrase_b: Array = []
	var shime_hot: Array[int] = [1, 0, 1, 0, 1, 1, 0, 1, 1, 0, 1, 0, 1, 1, 1, 1]
	var shime_calm: Array[int] = [0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 1]
	var bass_hot: Array[int] = [1, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 1, 0, 0, 1, 1]
	var bass_calm: Array[int] = [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0]
	var arp_pat: Array[int] = [0, 2, 3, 5, 3, 2, 4, 1]
	for step: int in range(bars * 16):
		var s16: int = step % 16
		var bar: int = step / 16
		var t: float = float(step) * sd
		if s16 == 0 and bar % 4 == 0:
			phrase_a = _phrase()
			phrase_b = _phrase()
		var root: int = 50 + PROG[bar % 4]
		# Kick (with side-chain) and the big o-daiko.
		var kick: bool = (s16 % 4 == 0) if hot else (s16 == 0 or s16 == 10)
		if kick:
			Synth.tone(main, t, 0.34, 160, 38, "sine", 0.9 if hot else 0.6, 0.002)
			Synth.noise(main, t, 0.05, 0.22, "lp", 2000)
			kicks.append(t)
		if s16 == 0 and bar % 2 == 0:
			Synth.tone(main, t, 0.9, 90, 42, "sine", 0.7, 0.004)
		if hot and bar % 4 == 3 and s16 >= 12:
			Synth.tone(main, t, 0.25, 120.0 + s16 * 6.0, 50, "sine", 0.55, 0.002)
			Synth.noise(main, t, 0.06, 0.2, "lp", 900)
		if boss and bar % 2 == 1 and (s16 == 6 or s16 == 7 or s16 == 14):
			Synth.tone(main, t, 0.3, 140, 45, "sine", 0.6, 0.002)
		if hot and (s16 == 4 or s16 == 12):
			Synth.noise(main, t, 0.16, 0.42, "bp", 1700, 0, 0.9)
			Synth.noise(main, t + 0.012, 0.1, 0.25, "bp", 2400, 0, 1.0)
		var shime: Array[int] = shime_hot if hot else shime_calm
		if shime[s16] == 1:
			Synth.noise(main, t, 0.035, 0.2 if s16 % 4 == 2 else 0.11, "bp", 4200, 0, 2.5)
			Synth.tone(main, t, 0.03, 820, 600, "tri", 0.05, 0.001)
		# Shamisen bass.
		var bp: Array[int] = bass_hot if hot else bass_calm
		if bp[s16] == 1:
			var n: int = root + (12 if s16 == 14 else (7 if s16 == 15 else 0)) - 12
			_shamisen(main, t, Synth.midi_f(n), 0.3 if hot else 0.22)
		# Pumping arp.
		if hot:
			var deg: int = arp_pat[s16 % 8]
			var n2: int = root + 12 + SCALE[deg % 5] + (12 if deg >= 5 else 0) + (12 if boss and s16 >= 8 else 0)
			Synth.tone(duck, t, 0.11, Synth.midi_f(n2), 0, "square", 0.055, 0.002, 3200)
		# Pad.
		if s16 == 0:
			for iv: int in [0, 7, 12]:
				Synth.tone(duck, t, sd * 16.0, Synth.midi_f(root + 12 + iv) * (1.0 + _rng.randf_range(-0.003, 0.003)), 0, "saw", 0.03, 0.4, 900)
		# Koto melody, with an echo send.
		var ph: Array = phrase_a if bar % 2 == 0 else phrase_b
		var deg2: int = ph[s16]
		if deg2 != -99 and (not boss or bar % 8 < 4):
			var kn: int = _scale_note(deg2, 62)
			Synth.pluck(main, t, Synth.midi_f(kn), 0.16 if m == "title" else 0.12)
			Synth.pluck(send, t, Synth.midi_f(kn), 0.06)
			if m == "title" and s16 % 4 == 0:
				Synth.pluck(main, t + 0.002, Synth.midi_f(kn - 12), 0.08)
		# Shakuhachi lead.
		if (boss or (hot and bar % 8 >= 4)) and s16 % 8 == 0 and deg2 != -99:
			_shakuhachi(main, send, t, Synth.midi_f(_scale_note(deg2 + 5, 62)), sd * 7.0)
	# Side-chain: duck the pad and arp under every kick.
	var env_len: float = sd * 3.2
	var ki: int = 0
	for i: int in range(duck.size()):
		var tt: float = float(i) / Synth.RATE
		while ki + 1 < kicks.size() and kicks[ki + 1] <= tt:
			ki += 1
		var g: float = 1.0
		if not kicks.is_empty() and tt >= kicks[ki]:
			g = lerpf(0.15, 1.0, minf(1.0, (tt - kicks[ki]) / env_len))
		main[i] += duck[i] * g
	# Echo: dotted-eighth feedback delay on the send, low-passed each repeat.
	var dly: int = int(60.0 / bpm * 0.75 * Synth.RATE)
	var lp: float = 0.0
	for i: int in range(dly, send.size()):
		lp += (send[i - dly] - lp) * 0.5
		send[i] += lp * 0.33
	for i: int in range(send.size()):
		main[i] += send[i] * 0.4
	# Fold the tail back over the start so the loop is seamless.
	var n_loop: int = int(length * Synth.RATE)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n_loop)
	for i: int in range(n_loop):
		out[i] = main[i]
	for i: int in range(n_loop, main.size()):
		out[i - n_loop] += main[i]
	return Synth.to_wav(out, true, 0.9)


func _shamisen(buf: PackedFloat32Array, t0: float, f: float, vol: float) -> void:
	var start: int = int(t0 * Synth.RATE)
	var n: int = mini(int(0.26 * Synth.RATE), buf.size() - start)
	var ph: float = 0.0
	var lp1: float = 0.0
	var lp2: float = 0.0
	for i: int in range(n):
		ph += f / Synth.RATE
		ph -= floorf(ph)
		var s: float = ph * 2.0 - 1.0
		var cut: float = 220.0 + 2400.0 * exp(-float(i) / Synth.RATE * 16.0)
		var c: float = 1.0 - exp(-TAU * cut / Synth.RATE)
		lp1 += (s - lp1) * c
		lp2 += (lp1 - lp2) * c
		var env: float = minf(1.0, float(i) / 40.0) * exp(-float(i) / Synth.RATE * 10.0)
		buf[start + i] += lp2 * env * vol * 1.4


func _shakuhachi(buf: PackedFloat32Array, send: PackedFloat32Array, t0: float, f0: float, dur: float) -> void:
	var start: int = int(t0 * Synth.RATE)
	var n: int = mini(int(dur * Synth.RATE), buf.size() - start)
	var ph: float = 0.0
	for i: int in range(n):
		var t: float = float(i) / Synth.RATE
		var bend: float = lerpf(0.94, 1.0, minf(1.0, t / 0.14))
		var vib: float = 1.0 + sin(t * TAU * 5.5) * 0.018 * (t / dur)
		ph += f0 * bend * vib / Synth.RATE
		ph -= floorf(ph)
		var env: float = minf(1.0, t / 0.09) * (1.0 if t < dur * 0.8 else maxf(0.0, (dur - t) / (dur * 0.2)))
		var s: float = sin(ph * TAU) * env * 0.11
		buf[start + i] += s
		send[start + i] += s * 0.5
	Synth.noise(buf, t0, dur * 0.6, 0.03, "bp", f0 * 2.0, 0, 3.0, 0.05)
