extends Node
## Every sound is synthesised here, in the manner of an early-80s arcade board: square, saw and
## noise voices through swept filters, a cabinet echo and a soft clip. The effects and the three
## music loops are rendered into AudioStreamWAVs when the game starts, so the project ships no
## audio files. On desktop and Android that happens on a background thread; the browser build is
## single-threaded, so there it renders one effect or one bar of music at a time between frames.

const RATE := 22050
const TAU_R := TAU / RATE

var sounds := {}
var music := {}
var raw := {}
var is_ready := false
var muted := false

var _thread: Thread
var _jobs: Array = []            # browser build: work still to render, a slice per frame
var _out := {}
var _song_state := {}            # song name -> its buffer while it is rendered bar by bar
var _players: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
var _pending_music := ""
var _current_music := ""
var _buf := PackedFloat32Array()


func _ready() -> void:
	for i in 14:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music_player = AudioStreamPlayer.new()
	_music_player.volume_db = -7.0
	add_child(_music_player)
	if OS.has_feature("web"):
		_out = {"sounds": {}, "music": {}, "raw": {}}
		_jobs = _job_list()
	else:
		_thread = Thread.new()
		_thread.start(render_all)


func _process(_dt: float) -> void:
	if is_ready:
		return
	if not _jobs.is_empty():
		# About 12 ms of rendering a frame keeps the title screen moving while it works.
		var t0 := Time.get_ticks_usec()
		while not _jobs.is_empty() and Time.get_ticks_usec() - t0 < 12000:
			_run_job(_jobs.pop_front(), _out)
		if _jobs.is_empty():
			_finish(_out)
	elif _thread and not _thread.is_alive():
		var result: Dictionary = _thread.wait_to_finish()
		_thread = null
		_finish(result)


func _finish(result: Dictionary) -> void:
	sounds = result.sounds
	music = result.music
	raw = result.raw
	is_ready = true
	if _pending_music != "":
		var m := _pending_music
		_pending_music = ""
		play_music(m)


func _exit_tree() -> void:
	if _thread and _thread.is_alive():
		_thread.wait_to_finish()
	for p in _players:
		p.stop()
	_music_player.stop()


## Plays an effect. `pitch` scales speed and pitch, as on a sample-playback board.
func play(name: String, pitch := 1.0, volume_db := 0.0) -> void:
	if not is_ready or not sounds.has(name):
		return
	var best: AudioStreamPlayer = null
	for p in _players:
		if not p.playing:
			best = p
			break
	if best == null:
		best = _players[0]
		_players.remove_at(0)
		_players.append(best)
	best.stream = sounds[name]
	best.pitch_scale = pitch
	best.volume_db = volume_db
	best.play()


func play_music(name: String) -> void:
	if name == _current_music and _music_player.playing:
		return
	if not is_ready:
		_pending_music = name
		return
	if not music.has(name):
		return
	_current_music = name
	_music_player.stream = music[name]
	_music_player.play()


func stop_music() -> void:
	_current_music = ""
	_pending_music = ""
	_music_player.stop()


func toggle_mute() -> bool:
	muted = not muted
	AudioServer.set_bus_mute(0, muted)
	return muted


# --- rendering ----------------------------------------------------------------------------------

func _recipes() -> Dictionary:
	return {
		"blip": _blip, "select": _select, "type": _type, "launch": _launch, "explosion": _explosion,
		"explosion_small": _explosion_small, "leg_hit": _leg_hit, "ricochet": _ricochet, "leg_break": _leg_break,
		"footstep": _footstep, "siren": _siren, "heat_ray": _heat_ray, "burn": _burn, "scream": _scream,
		"saved": _saved, "collapse": _collapse, "crunch": _crunch, "spark": _spark, "hurt": _hurt, "stomp": _stomp,
		"alarm": _alarm, "fanfare": _fanfare, "cleared": _cleared, "victory": _victory, "game_over": _game_over
	}


## Every unit of rendering work: one job per effect, one per bar of each song.
func _job_list() -> Array:
	var jobs: Array = []
	for name in _recipes():
		jobs.append(["sfx", name])
	for song in ["menu", "map", "battle"]:
		var bars: int = SONGS[song].roots.size()
		for b in bars:
			jobs.append(["bar", song, b, bars])
	return jobs


func _run_job(job: Array, out: Dictionary) -> void:
	if job[0] == "sfx":
		var name: String = job[1]
		_buf = PackedFloat32Array()
		_recipes()[name].call()
		_echo(0.23, 0.25, 0.3)
		out.raw[name] = _buf
		out.sounds[name] = _to_wav(_buf, false)
		return
	var song: String = job[1]
	var bar: int = job[2]
	var bars: int = job[3]
	_buf = _song_state.get(song, PackedFloat32Array())
	_render_song_bars(song, bar, bar + 1)
	if bar < bars - 1:
		_song_state[song] = _buf
		return
	_song_state.erase(song)
	_trim_song(song)
	out.raw["music_" + song] = _buf
	out.music[song] = _to_wav(_buf, true)


## Renders everything in one go. Runs on the worker thread; also callable synchronously by the tools.
func render_all() -> Dictionary:
	var out := {"sounds": {}, "music": {}, "raw": {}}
	for job in _job_list():
		_run_job(job, out)
	return out


func _ensure(n: int) -> void:
	if _buf.size() < n:
		var old := _buf.size()
		_buf.resize(n)
		for i in range(old, n):
			_buf[i] = 0.0


static func _env(t: float, dur: float, a: float, d: float, s: float, r: float) -> float:
	if t < a:
		return t / a
	if t < a + d:
		return lerpf(1.0, s, (t - a) / d)
	if t < dur:
		return s
	return s * maxf(0.0, 1.0 - (t - dur) / r)


## wave: 0 square, 1 saw, 2 sine, 3 triangle. filt: {"type": "lp"/"hp"/"bp", "f0", "f1", "q"}.
func _tone(t0: float, dur: float, wave: int, f0: float, f1: float, vol: float, a := 0.004, d := 0.05, s := 0.6, r := 0.06, filt := {}, detune := 0.0) -> void:
	var n0 := int(t0 * RATE)
	var n := int((dur + r) * RATE)
	_ensure(n0 + n + 1)
	if f1 <= 0.0:
		f1 = f0
	var ratio := f1 / f0
	var det := pow(2.0, detune / 1200.0)
	var phase := 0.0
	var use_filt := not filt.is_empty()
	var ftype := 0
	var ff0 := 1000.0
	var ff1 := 1000.0
	var q := 1.0
	var b0 := 1.0; var b1 := 0.0; var b2 := 0.0; var a1 := 0.0; var a2 := 0.0
	var x1 := 0.0; var x2 := 0.0; var y1 := 0.0; var y2 := 0.0
	if use_filt:
		ftype = {"lp": 0, "hp": 1, "bp": 2}[filt.get("type", "lp")]
		ff0 = filt.get("f0", 1000.0)
		ff1 = filt.get("f1", ff0)
		q = filt.get("q", 1.0)
	var inv_dur := 1.0 / maxf(dur, 0.0001)
	for i in n:
		var t := i / float(RATE)
		var u := minf(1.0, t * inv_dur)
		var f := f0 * pow(ratio, u) * det
		phase += f / RATE
		var ph := phase - floorf(phase)
		var v: float
		if wave == 0:
			v = 1.0 if ph < 0.5 else -1.0
		elif wave == 1:
			v = 2.0 * ph - 1.0
		elif wave == 2:
			v = sin(ph * TAU)
		else:
			v = 4.0 * absf(ph - 0.5) - 1.0
		if use_filt:
			if i % 32 == 0:
				var fc := clampf(ff0 * pow(ff1 / ff0, u), 20.0, RATE * 0.45)
				var w0 := fc * TAU_R
				var alpha := sin(w0) / (2.0 * q)
				var cw := cos(w0)
				var a0 := 1.0 + alpha
				if ftype == 0:
					b0 = (1.0 - cw) / 2.0 / a0; b1 = (1.0 - cw) / a0; b2 = b0
				elif ftype == 1:
					b0 = (1.0 + cw) / 2.0 / a0; b1 = -(1.0 + cw) / a0; b2 = b0
				else:
					b0 = alpha / a0; b1 = 0.0; b2 = -alpha / a0
				a1 = -2.0 * cw / a0; a2 = (1.0 - alpha) / a0
			var y := b0 * v + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
			x2 = x1; x1 = v; y2 = y1; y1 = y
			v = y
		_buf[n0 + i] += v * vol * _env(t, dur, a, d, s, r)


func _noise(t0: float, dur: float, vol: float, a := 0.002, d := 0.05, s := 0.5, r := 0.1, ftype_s := "lp", f0 := 1200.0, f1 := 200.0, q := 1.0) -> void:
	var n0 := int(t0 * RATE)
	var n := int((dur + r) * RATE)
	_ensure(n0 + n + 1)
	var ftype: int = {"lp": 0, "hp": 1, "bp": 2}[ftype_s]
	var b0 := 1.0; var b1 := 0.0; var b2 := 0.0; var a1 := 0.0; var a2 := 0.0
	var x1 := 0.0; var x2 := 0.0; var y1 := 0.0; var y2 := 0.0
	var inv_dur := 1.0 / maxf(dur, 0.0001)
	for i in n:
		var t := i / float(RATE)
		var u := minf(1.0, t * inv_dur)
		var v := randf() * 2.0 - 1.0
		if i % 32 == 0:
			var fc := clampf(f0 * pow(f1 / f0, u), 20.0, RATE * 0.45)
			var w0 := fc * TAU_R
			var alpha := sin(w0) / (2.0 * q)
			var cw := cos(w0)
			var a0 := 1.0 + alpha
			if ftype == 0:
				b0 = (1.0 - cw) / 2.0 / a0; b1 = (1.0 - cw) / a0; b2 = b0
			elif ftype == 1:
				b0 = (1.0 + cw) / 2.0 / a0; b1 = -(1.0 + cw) / a0; b2 = b0
			else:
				b0 = alpha / a0; b1 = 0.0; b2 = -alpha / a0
			a1 = -2.0 * cw / a0; a2 = (1.0 - alpha) / a0
		var y := b0 * v + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1; x1 = v; y2 = y1; y1 = y
		_buf[n0 + i] += y * vol * _env(t, dur, a, d, s, r)


## The cabinet: a short feedback echo, low in the mix.
func _echo(delay: float, fb: float, wet: float) -> void:
	var d := int(delay * RATE)
	var n := _buf.size()
	var out := PackedFloat32Array()
	out.resize(n + d * 3)
	for i in out.size():
		var v := _buf[i] if i < n else 0.0
		if i >= d and i - d < n:
			v += wet * _buf[i - d]
		if i >= 2 * d and i - 2 * d < n:
			v += wet * fb * _buf[i - 2 * d]
		if i >= 3 * d and i - 3 * d < n:
			v += wet * fb * fb * _buf[i - 3 * d]
		out[i] = v
	_buf = out


static func _to_wav(buf: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		var v := tanh(buf[i] * 1.1)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = buf.size()
	return w


# --- the effects --------------------------------------------------------------------------------

func _blip() -> void:
	_tone(0, 0.05, 0, 900, 1400, 0.12, 0.004, 0.05, 0.3, 0.03)


func _select() -> void:
	_tone(0, 0.06, 0, 660, 0, 0.14, 0.004, 0.05, 0.5)
	_tone(0.06, 0.12, 0, 1320, 0, 0.14, 0.004, 0.05, 0.5)


func _type() -> void:
	_tone(0, 0.02, 0, 1800, 0, 0.05, 0.002, 0.01, 0.2, 0.015)


func _launch() -> void:
	_noise(0, 0.55, 0.55, 0.002, 0.05, 0.5, 0.25, "bp", 3500, 250, 0.6)
	_tone(0, 0.5, 1, 380, 70, 0.28, 0.004, 0.05, 0.4, 0.2, {"type": "lp", "f0": 2200.0, "f1": 250.0})
	_tone(0, 0.12, 0, 120, 50, 0.3, 0.004, 0.05, 0.3)


func _explosion() -> void:
	_noise(0, 0.45, 0.75, 0.002, 0.05, 0.5, 0.35, "lp", 1800, 50)
	_tone(0, 0.4, 2, 140, 28, 0.7, 0.004, 0.05, 0.5, 0.25)
	_noise(0, 0.12, 0.4, 0.002, 0.05, 0.5, 0.08, "hp", 7000, 2500)


func _explosion_small() -> void:
	_noise(0, 0.22, 0.6, 0.002, 0.05, 0.5, 0.18, "lp", 1800, 50)
	_tone(0, 0.2, 2, 140, 28, 0.6, 0.004, 0.05, 0.5, 0.12)


func _leg_hit() -> void:
	var base := 800.0
	var i := 0
	for m in [1.0, 1.47, 2.09, 3.3]:
		_tone(0, 0.1, 0, base * m, base * m * 0.96, 0.14 / (i + 1), 0.001, 0.04, 0.35, 0.22)
		i += 1
	_noise(0, 0.07, 0.35, 0.002, 0.05, 0.5, 0.05, "bp", 6000, 1200, 1.5)
	_tone(0, 0.15, 2, 110, 60, 0.4, 0.004, 0.05, 0.3)


func _ricochet() -> void:
	_tone(0, 0.22, 0, 2200, 350, 0.14, 0.004, 0.05, 0.35, 0.12)
	_noise(0, 0.05, 0.25, 0.002, 0.05, 0.5, 0.04, "hp", 8000, 3000)


func _leg_break() -> void:
	_noise(0, 0.6, 0.7, 0.002, 0.05, 0.5, 0.4, "lp", 2500, 120)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 5:
		var f := 300.0 + rng.randf() * 1200.0
		_tone(i * 0.05, 0.12, 0, f, f * 0.7, 0.14, 0.004, 0.05, 0.4, 0.2)
	_tone(0, 0.6, 1, 900, 90, 0.25, 0.004, 0.05, 0.5, 0.3, {"type": "lp", "f0": 3000.0, "f1": 300.0})


func _footstep() -> void:
	_tone(0, 0.28, 2, 75, 32, 0.6, 0.002, 0.12, 0.35, 0.18)
	_noise(0, 0.14, 0.28, 0.002, 0.05, 0.5, 0.12, "lp", 500, 80)
	_tone(0, 0.05, 0, 260, 240, 0.09, 0.004, 0.05, 0.2, 0.1)


## The fighting-machine's cry before it fires: "Ulla, ulla". Detuned saws and a square through a
## sweeping band-pass, with vibrato and a sub-tone underneath: a siren with a throat.
func _siren() -> void:
	var dur := 1.5
	var n := int((dur + 0.45) * RATE)
	_ensure(n + 1)
	var voices := [[1, 1.0, 0.0], [1, 1.006, 6.0], [0, 0.5, 0.0], [1, 1.498, -8.0]]
	var phases: Array[float] = [0.0, 0.0, 0.0, 0.0]
	var b0 := 0.0; var b1 := 0.0; var b2 := 0.0; var a1 := 0.0; var a2 := 0.0
	var x1 := 0.0; var x2 := 0.0; var y1 := 0.0; var y2 := 0.0
	for i in n:
		var t := i / float(RATE)
		var env := _env(t, dur, 0.12, 0.25, 0.85, 0.35)
		# pitch glide: up to 3.1x over the first 40 percent, then back down to 1.3x
		var mul: float
		if t < dur * 0.4:
			mul = pow(3.1, t / (dur * 0.4))
		else:
			mul = 3.1 * pow(1.3 / 3.1, minf(1.0, (t - dur * 0.4) / (dur * 0.6)))
		var vib := 1.0 + 0.013 * sin(t * 5.2 * TAU)
		var mix := 0.0
		for k in 4:
			var v: Array = voices[k]
			var f: float = 105.0 * v[1] * mul * vib * pow(2.0, v[2] / 1200.0)
			phases[k] += f / RATE
			var ph: float = phases[k] - floorf(phases[k])
			mix += (1.0 if ph < 0.5 else -1.0) if v[0] == 0 else (2.0 * ph - 1.0)
		# wave-shaper
		mix = (1.0 + 28.0) * mix * 0.25 / (1.0 + 28.0 * absf(mix * 0.25))
		if i % 32 == 0:
			var fc: float
			if t < dur * 0.42:
				fc = 320.0 * pow(1500.0 / 320.0, t / (dur * 0.42))
			else:
				fc = 1500.0 * pow(450.0 / 1500.0, minf(1.0, (t - dur * 0.42) / (dur * 0.58)))
			var w0 := fc * TAU_R
			var alpha := sin(w0) / (2.0 * 2.2)
			var cw := cos(w0)
			var a0 := 1.0 + alpha
			b0 = alpha / a0; b1 = 0.0; b2 = -alpha / a0; a1 = -2.0 * cw / a0; a2 = (1.0 - alpha) / a0
		var y := b0 * mix + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1; x1 = mix; y2 = y1; y1 = y
		_buf[i] += y * 0.55 * env
	_tone(0, dur, 2, 52, 38, 0.35, 0.05, 0.05, 0.8, 0.3)
	_noise(0, dur, 0.08, 0.002, 0.05, 0.8, 0.3, "bp", 900, 2500, 3.0)


func _heat_ray() -> void:
	var dur := 1.15
	_noise(0, dur, 0.4, 0.002, 0.05, 0.85, 0.15, "hp", 2200, 4500)
	_tone(0, dur, 1, 1600, 2900, 0.13, 0.004, 0.05, 0.85, 0.15, {"type": "bp", "f0": 2000.0, "f1": 3200.0, "q": 5.0})
	_tone(0, dur, 0, 85, 65, 0.22, 0.004, 0.05, 0.9, 0.2)
	_tone(0, dur, 2, 3200, 5200, 0.05, 0.004, 0.05, 0.8, 0.1)


func _burn() -> void:
	_noise(0, 0.35, 0.5, 0.002, 0.05, 0.5, 0.3, "bp", 4500, 500, 0.8)
	_tone(0, 0.3, 1, 1000, 110, 0.2, 0.004, 0.05, 0.5, 0.1)


func _scream() -> void:
	var f := 850.0
	_tone(0, 0.1, 1, f, f * 1.7, 0.07, 0.004, 0.05, 0.9, 0.02, {"type": "bp", "f0": 1900.0, "q": 2.0})
	_tone(0.1, 0.28, 1, f * 1.7, f * 0.6, 0.07, 0.004, 0.05, 0.7, 0.08, {"type": "bp", "f0": 1700.0, "q": 2.0})


func _saved() -> void:
	var i := 0
	for f in [880.0, 1175.0, 1760.0]:
		_tone(i * 0.06, 0.06, 0, f, 0, 0.09, 0.004, 0.05, 0.5, 0.08)
		i += 1


func _collapse() -> void:
	_noise(0, 1.3, 0.85, 0.002, 0.05, 0.5, 0.7, "lp", 900, 35)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 7:
		var f := 180.0 + rng.randf() * 1000.0
		_tone(0.04 + i * 0.09 + rng.randf() * 0.06, 0.14, 0, f, f * 0.75, 0.16, 0.004, 0.05, 0.4, 0.25)
	_tone(0, 0.9, 2, 65, 22, 0.8, 0.004, 0.05, 0.6, 0.5)
	_noise(0, 0.2, 0.5, 0.002, 0.05, 0.5, 0.3, "hp", 8000, 2000)


func _crunch() -> void:
	_noise(0, 0.18, 0.5, 0.002, 0.05, 0.5, 0.15, "lp", 1400, 120)
	_tone(0, 0.2, 2, 90, 35, 0.5, 0.004, 0.05, 0.4)


func _spark() -> void:
	_noise(0, 0.035, 0.1, 0.002, 0.01, 0.5, 0.03, "hp", 8000, 3500)


func _hurt() -> void:
	_tone(0, 0.5, 1, 420, 55, 0.45, 0.004, 0.05, 0.5, 0.2)
	_noise(0, 0.45, 0.55, 0.002, 0.05, 0.5, 0.3, "lp", 3200, 180)
	_tone(0, 0.3, 0, 1200, 200, 0.15, 0.004, 0.05, 0.4)


func _stomp() -> void:
	_tone(0, 0.5, 2, 60, 25, 0.9, 0.004, 0.05, 0.5, 0.3)
	_noise(0, 0.4, 0.6, 0.002, 0.05, 0.5, 0.3, "lp", 900, 60)


func _alarm() -> void:
	for i in 3:
		_tone(i * 0.3, 0.22, 0, 660, 440, 0.14, 0.004, 0.05, 0.7, 0.05)


func _fanfare() -> void:
	var i := 0
	for f in [440.0, 554.0, 659.0, 880.0]:
		_tone(i * 0.1, 0.11, 0, f, 0, 0.14, 0.004, 0.05, 0.6, 0.05)
		i += 1
	_tone(0.42, 0.45, 0, 1108, 0, 0.14, 0.004, 0.05, 0.6, 0.3)
	_tone(0.42, 0.9, 1, 277, 0, 0.1, 0.004, 0.05, 0.6, 0.3, {"type": "lp", "f0": 1200.0})


func _cleared() -> void:
	var t := 0.0
	for m in [[440.0, 0.12], [523.0, 0.12], [659.0, 0.12], [880.0, 0.25], [659.0, 0.12], [880.0, 0.5]]:
		_tone(t, m[1], 0, m[0], 0, 0.14, 0.004, 0.05, 0.6, 0.08)
		_tone(t, m[1], 0, m[0] / 2.0, 0, 0.1, 0.004, 0.05, 0.6, 0.08, {}, 6.0)
		t += m[1]


func _victory() -> void:
	var t := 0.0
	for m in [[523.0, 0.15], [659.0, 0.15], [784.0, 0.15], [1047.0, 0.3], [784.0, 0.15], [1047.0, 0.3], [1319.0, 0.6]]:
		_tone(t, m[1], 0, m[0], 0, 0.15, 0.004, 0.05, 0.6, 0.1)
		_tone(t, m[1], 1, m[0] / 2.0, 0, 0.1, 0.004, 0.05, 0.6, 0.1, {"type": "lp", "f0": 1500.0})
		t += m[1]


func _game_over() -> void:
	var i := 0
	for f in [330.0, 311.0, 294.0, 220.0]:
		_tone(i * 0.38, 0.38, 1, f, f * 0.96, 0.2, 0.004, 0.05, 0.7, 0.25, {"type": "lp", "f0": 1400.0, "q": 1.0})
		_tone(i * 0.38, 0.38, 0, f / 2.0, 0, 0.12, 0.004, 0.05, 0.7, 0.25)
		i += 1


# --- music: a sixteen-step sequencer -------------------------------------------------------------

const SONGS := {
	"battle": {
		"bpm": 132.0,
		"roots": [0, 0, -4, -2, 0, 0, -4, 3],
		"bass": [0, 0, 12, 0, 0, 0, 10, 0, 0, 0, 12, 0, 7, 7, 8, 10],
		"lead": [12, null, 15, null, 19, null, 15, null, 12, null, 15, null, 19, null, 22, 24],
		"kick": [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0],
		"snare": [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0],
		"hat": [0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 1]
	},
	"menu": {
		"bpm": 84.0,
		"roots": [0, 0, -4, -2],
		"bass": [0, null, null, null, null, null, null, null, 0, null, null, null, null, null, 12, null],
		"lead": [null, null, 12, null, null, null, 15, null, null, null, 19, null, null, null, 15, null],
		"kick": [1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0],
		"snare": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
		"hat": [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0]
	},
	"map": {
		"bpm": 112.0,
		"roots": [0, -4, -2, -5],
		"bass": [0, null, 0, null, 12, null, 0, null, 0, null, 0, null, 12, null, 10, null],
		"lead": [12, 15, 19, 24, 19, 15, 12, 15, 19, 24, 27, 24, 19, 15, 12, null],
		"kick": [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0],
		"snare": [0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0],
		"hat": [1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0]
	}
}


static func _note(semi: float, base := 55.0) -> float:
	return base * pow(2.0, semi / 12.0)


func _render_song_bars(name: String, from_bar: int, to_bar: int) -> void:
	var song: Dictionary = SONGS[name]
	var sp: float = 60.0 / song.bpm / 4.0
	var bars: int = song.roots.size()
	var total := bars * 16 * sp
	_ensure(int(total * RATE) + 1)
	for bar in range(from_bar, to_bar):
		var root: int = song.roots[bar]
		for step in 16:
			var t := (bar * 16 + step) * sp
			var b = song.bass[step]
			if b != null:
				_tone(t, sp * 0.9, 0, _note(root + b, 55.0), 0, 0.22, 0.004, 0.05, 0.7, 0.03, {"type": "lp", "f0": 1100.0, "q": 2.0})
			var l = song.lead[step]
			if l != null:
				_tone(t, sp * 1.6, 0, _note(root + l, 110.0), 0, 0.09, 0.004, 0.05, 0.5, 0.12, {}, 4.0)
				_tone(t, sp * 1.6, 1, _note(root + l, 110.0), 0, 0.05, 0.004, 0.05, 0.5, 0.12, {"type": "lp", "f0": 2500.0}, -5.0)
			if song.kick[step] == 1:
				_tone(t, 0.12, 2, 150, 40, 0.5, 0.004, 0.05, 0.3, 0.05)
			if song.snare[step] == 1:
				_noise(t, 0.12, 0.25, 0.002, 0.05, 0.5, 0.08, "bp", 2500, 800, 0.8)
			if song.hat[step] == 1:
				_noise(t, 0.03, 0.09, 0.002, 0.01, 0.5, 0.02, "hp", 9000, 7000)


## Trims the tail back to the loop length so the loop is seamless.
func _trim_song(name: String) -> void:
	var song: Dictionary = SONGS[name]
	var total: float = song.roots.size() * 16 * (60.0 / song.bpm / 4.0)
	_buf.resize(int(total * RATE))
