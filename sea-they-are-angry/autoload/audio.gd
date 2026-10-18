extends Node
## Sound for the whole game. Every effect and ambience is synthesised in code at
## startup (then cached in user://), so the game has sound with no audio files.
## Drop a real recording at res://audio/<key>.ogg and it is used instead.
##
## Audio.sfx("swing", position)   one-shot; positional when a position is given
## Audio.loop("wind", true, -12)  start or stop an ambient loop

const RATE := 16000
const CACHE_DIR := "user://audio_cache_v3"
const POOL_3D := 14
const POOL_2D := 6

var _streams := {}
var _pool3d: Array[AudioStreamPlayer3D] = []
var _pool2d: Array[AudioStreamPlayer] = []
var _loops := {}
var _next3d := 0
var _next2d := 0
var _rng := RandomNumberGenerator.new()

# key: [synth function, loops?]
const SOUNDS := {
	"step": ["_s_step", false],
	"swing": ["_s_swing", false],
	"hit": ["_s_hit", false],
	"burst": ["_s_burst", false],
	"splash": ["_s_splash", false],
	"groan": ["_s_groan", false],
	"sizzle": ["_s_sizzle", false],
	"gather": ["_s_gather", false],
	"repair": ["_s_repair", false],
	"refuel": ["_s_refuel", false],
	"ignite": ["_s_ignite", false],
	"gutter": ["_s_gutter", false],
	"dark": ["_s_dark", false],
	"foghorn": ["_s_foghorn", false],
	"foghorn_short": ["_s_foghorn_short", false],
	"night_sting": ["_s_night_sting", false],
	"hurt": ["_s_hurt", false],
	"ui_move": ["_s_ui_move", false],
	"ui_accept": ["_s_ui_accept", false],
	"bell": ["_s_bell", false],
	"creak": ["_s_creak", false],
	"whisper": ["_s_whisper", false],
	"thunder": ["_s_thunder", false],
	"wind": ["_s_wind", true],
	"waves": ["_s_waves", true],
	"drone": ["_s_drone", true],
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 7
	_ensure_buses()
	_build_all()
	for i in POOL_3D:
		var p := AudioStreamPlayer3D.new()
		p.bus = "SFX"
		p.unit_size = 22.0
		p.max_distance = 90.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(p)
		_pool3d.append(p)
	for i in POOL_2D:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool2d.append(p)
	Cycle.phase_changed.connect(_on_phase)
	Events.lamp_state_changed.connect(_on_lamp_state)
	Events.run_ended.connect(_on_run_ended)

func _ensure_buses() -> void:
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")

# ---- playback ----

func sfx(key: String, at: Vector3 = Vector3.INF, volume_db: float = 0.0, pitch_jitter: float = 0.08) -> void:
	var stream: AudioStream = _streams.get(key)
	if stream == null:
		return
	var pitch := 1.0 + _rng.randf_range(-pitch_jitter, pitch_jitter)
	if at == Vector3.INF or not is_inside_tree():
		var p := _pool2d[_next2d]
		_next2d = (_next2d + 1) % POOL_2D
		p.stream = stream
		p.volume_db = volume_db
		p.pitch_scale = pitch
		p.play()
		return
	var p3 := _pool3d[_next3d]
	_next3d = (_next3d + 1) % POOL_3D
	p3.stream = stream
	p3.volume_db = volume_db
	p3.pitch_scale = pitch
	p3.global_position = at
	p3.play()

func loop(key: String, on: bool, volume_db: float = -10.0, fade: float = 2.0) -> void:
	var stream: AudioStream = _streams.get(key)
	if stream == null:
		return
	var p: AudioStreamPlayer = _loops.get(key)
	if p == null:
		p = AudioStreamPlayer.new()
		p.bus = "Music" if key == "drone" else "SFX"
		p.stream = stream
		p.volume_db = -60.0
		add_child(p)
		_loops[key] = p
	var tw := create_tween()
	if on:
		if not p.playing:
			p.volume_db = -60.0
			p.play()
		tw.tween_property(p, "volume_db", volume_db, fade)
	else:
		tw.tween_property(p, "volume_db", -60.0, fade)
		tw.tween_callback(p.stop)

func start_ambience() -> void:
	loop("wind", true, -16.0, 3.0)
	loop("waves", true, -12.0, 3.0)

# ---- reactions to the game ----

func _on_phase(p: int) -> void:
	match p:
		Cycle.Phase.DUSK:
			# Two long blasts: fog is coming in.
			horn([3.0, 3.0], -3.0)
			loop("wind", true, -11.0, 6.0)
		Cycle.Phase.NIGHT:
			sfx("night_sting", Vector3.INF, -6.0, 0.0)
			loop("drone", true, -14.0, 6.0)
		Cycle.Phase.DAWN:
			loop("drone", false, -14.0, 8.0)
			loop("wind", true, -16.0, 8.0)

func _on_lamp_state(s: int) -> void:
	match s:
		Lamp.State.BURNING:
			sfx("ignite", Vector3.INF, -6.0, 0.02)
		Lamp.State.GUTTERING:
			sfx("gutter", Vector3.INF, -4.0, 0.02)
		Lamp.State.DARK:
			sfx("dark", Vector3.INF, -2.0, 0.0)

func _on_run_ended(_reason: String, _night: int) -> void:
	loop("drone", false, -14.0, 3.0)

# ---- building the sounds ----

func _build_all() -> void:
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	for key in SOUNDS:
		var file := "res://audio/%s.ogg" % key
		if ResourceLoader.exists(file):
			_streams[key] = load(file)
			continue
		var cache := "%s/%s.pcm" % [CACHE_DIR, key]
		var data: PackedByteArray
		if FileAccess.file_exists(cache):
			data = FileAccess.get_file_as_bytes(cache)
		else:
			var buf: PackedFloat32Array = call(SOUNDS[key][0])
			data = _to_pcm(buf)
			var f := FileAccess.open(cache, FileAccess.WRITE)
			if f:
				f.store_buffer(data)
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = RATE
		wav.stereo = false
		wav.data = data
		if SOUNDS[key][1]:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = data.size() / 2
		_streams[key] = wav

func _to_pcm(buf: PackedFloat32Array) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(buf.size() * 2)
	for i in buf.size():
		out.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32000.0))
	return out

func _n(seconds: float) -> int:
	return int(seconds * RATE)

func _noise(n: int, seed_value: int) -> PackedFloat32Array:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	var b := PackedFloat32Array()
	b.resize(n)
	for i in n:
		b[i] = r.randf_range(-1.0, 1.0)
	return b

# One-pole low-pass; cutoff in Hz.
func _lowpass(b: PackedFloat32Array, cutoff: float) -> PackedFloat32Array:
	var a := 1.0 - exp(-TAU * cutoff / RATE)
	var y := 0.0
	for i in b.size():
		y += a * (b[i] - y)
		b[i] = y
	return b

func _highpass(b: PackedFloat32Array, cutoff: float) -> PackedFloat32Array:
	var a := 1.0 - exp(-TAU * cutoff / RATE)
	var y := 0.0
	for i in b.size():
		y += a * (b[i] - y)
		b[i] = b[i] - y
	return b

func _gain(b: PackedFloat32Array, g: float) -> PackedFloat32Array:
	for i in b.size():
		b[i] *= g
	return b

# Attack/decay envelope.
func _env(b: PackedFloat32Array, attack: float, decay_rate: float) -> PackedFloat32Array:
	var na := maxf(1.0, attack * RATE)
	for i in b.size():
		var t := float(i)
		var e := minf(1.0, t / na) * exp(-maxf(0.0, t - na) / RATE * decay_rate)
		b[i] *= e
	return b

func _tone(n: int, f0: float, f1: float, shape: int = 0) -> PackedFloat32Array:
	# shape 0 sine, 1 soft saw, 2 square-ish
	var b := PackedFloat32Array()
	b.resize(n)
	var ph := 0.0
	for i in n:
		var f := lerpf(f0, f1, float(i) / float(n))
		ph += TAU * f / RATE
		var v := sin(ph)
		if shape == 1:
			v = sin(ph) * 0.6 + sin(ph * 2.0) * 0.25 + sin(ph * 3.0) * 0.12 + sin(ph * 4.0) * 0.06
		elif shape == 2:
			v = clampf(sin(ph) * 3.0, -1.0, 1.0) * 0.7
		b[i] = v
	return b

func _mix(a: PackedFloat32Array, b: PackedFloat32Array, gb: float = 1.0, offset: int = 0) -> PackedFloat32Array:
	for i in b.size():
		var j := i + offset
		if j >= a.size():
			break
		a[j] += b[i] * gb
	return a

# Crossfade the tail into the head so the buffer loops without a click.
func _seamless(b: PackedFloat32Array, fade_s: float) -> PackedFloat32Array:
	var f := _n(fade_s)
	var n := b.size() - f
	var out := b.slice(0, n)
	for i in f:
		var k := float(i) / float(f)
		out[i] = b[i] * k + b[n + i] * (1.0 - k)
	return out

# ---- the sounds ----

func _s_step() -> PackedFloat32Array:
	var b := _lowpass(_noise(_n(0.1), 11), 900.0)
	return _gain(_env(b, 0.004, 45.0), 1.6)

func _s_swing() -> PackedFloat32Array:
	var n := _n(0.32)
	var b := _noise(n, 12)
	# Band sweep: a whoosh that rises then falls.
	var y := 0.0
	for i in n:
		var t := float(i) / float(n)
		var cut := 300.0 + 2200.0 * sin(t * PI)
		var a := 1.0 - exp(-TAU * cut / RATE)
		y += a * (b[i] - y)
		b[i] = y * sin(t * PI) * 1.4
	return _highpass(b, 150.0)

func _s_hit() -> PackedFloat32Array:
	var b := _env(_tone(_n(0.22), 120.0, 55.0), 0.002, 22.0)
	var click := _env(_lowpass(_noise(_n(0.05), 13), 2500.0), 0.001, 80.0)
	return _gain(_mix(b, click, 0.8), 0.9)

func _s_burst() -> PackedFloat32Array:
	var n := _n(0.8)
	var b := _env(_lowpass(_noise(n, 14), 700.0), 0.01, 6.0)
	_gain(b, 2.2)
	var thump := _env(_tone(n, 90.0, 35.0), 0.005, 9.0)
	_mix(b, thump, 0.9)
	# Wet gurgle: amplitude wobble.
	for i in n:
		b[i] *= 0.7 + 0.3 * sin(float(i) / RATE * TAU * 23.0)
	return b

func _s_splash() -> PackedFloat32Array:
	var b := _env(_highpass(_lowpass(_noise(_n(0.6), 15), 3500.0), 300.0), 0.01, 7.0)
	return _gain(b, 1.3)

func _s_groan() -> PackedFloat32Array:
	var n := _n(1.1)
	var b := PackedFloat32Array()
	b.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / float(n)
		var f := 70.0 + 18.0 * sin(t * TAU * 1.5) - t * 15.0
		ph += TAU * f / RATE
		# Throaty: a few harmonics with a vowel-ish wobble.
		var v := sin(ph) * 0.5 + sin(ph * 2.0) * 0.3 * (0.6 + 0.4 * sin(t * 9.0)) + sin(ph * 3.0) * 0.18
		b[i] = v * sin(t * PI)
	var breath := _lowpass(_noise(n, 16), 500.0)
	return _gain(_mix(b, breath, 0.25), 0.8)

func _s_sizzle() -> PackedFloat32Array:
	var b := _highpass(_noise(_n(0.5), 17), 2500.0)
	for i in b.size():
		var t := float(i) / float(b.size())
		b[i] *= sin(t * PI) * (0.5 + 0.5 * absf(sin(t * 61.0)))
	return _gain(b, 0.6)

func _s_gather() -> PackedFloat32Array:
	var a := _env(_tone(_n(0.45), 660.0, 660.0), 0.005, 9.0)
	var b := _env(_tone(_n(0.3), 990.0, 990.0), 0.005, 10.0)
	return _gain(_mix(a, b, 0.7, _n(0.09)), 0.35)

func _s_repair() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(_n(0.4))
	for k in 2:
		var knock := _env(_tone(_n(0.12), 220.0, 160.0), 0.001, 35.0)
		_mix(knock, _env(_lowpass(_noise(_n(0.05), 18 + k), 3000.0), 0.001, 90.0), 0.6)
		_mix(out, knock, 0.8, _n(0.17) * k)
	return out

func _s_refuel() -> PackedFloat32Array:
	var n := _n(0.7)
	var b := PackedFloat32Array()
	b.resize(n)
	for k in 5:
		var bub := _env(_tone(_n(0.1), 300.0 + 80.0 * k, 600.0 + 90.0 * k), 0.003, 30.0)
		_mix(b, bub, 0.35, _n(0.11) * k)
	return b

func _s_ignite() -> PackedFloat32Array:
	var n := _n(1.0)
	var whoomp := _env(_lowpass(_noise(n, 19), 600.0), 0.05, 3.5)
	_gain(whoomp, 2.0)
	var rise := _env(_tone(n, 80.0, 160.0, 1), 0.08, 3.0)
	return _mix(whoomp, rise, 0.4)

func _s_gutter() -> PackedFloat32Array:
	var n := _n(0.9)
	var b := _lowpass(_noise(n, 20), 900.0)
	for i in n:
		var t := float(i) / RATE
		b[i] *= 1.6 * (0.4 + 0.6 * float(int(t * 14.0) % 2)) * (1.0 - t / 0.9)
	return b

func _s_dark() -> PackedFloat32Array:
	var n := _n(2.4)
	var b := _env(_tone(n, 70.0, 30.0, 1), 0.01, 1.4)
	return _mix(b, _env(_lowpass(_noise(n, 21), 300.0), 0.01, 1.2), 0.8)

func _s_foghorn() -> PackedFloat32Array:
	var n := _n(3.2)
	var b := PackedFloat32Array()
	b.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 98.0 + 1.2 * sin(t * TAU * 5.0)
		ph += TAU * f / RATE
		var v := sin(ph) * 0.55 + sin(ph * 2.0) * 0.3 + sin(ph * 3.0) * 0.16 + sin(ph * 5.0) * 0.05
		var env := smoothstep(0.0, 0.35, t) * (1.0 - smoothstep(2.4, 3.2, t))
		b[i] = v * env * 0.8
	return _lowpass(b, 1200.0)

func _s_foghorn_short() -> PackedFloat32Array:
	var n := _n(1.3)
	var b := PackedFloat32Array()
	b.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 104.0 + 1.0 * sin(t * TAU * 6.0)
		ph += TAU * f / RATE
		var v := sin(ph) * 0.55 + sin(ph * 2.0) * 0.3 + sin(ph * 3.0) * 0.16 + sin(ph * 5.0) * 0.05
		b[i] = v * smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(0.9, 1.3, t)) * 0.8
	return _lowpass(b, 1200.0)

## Play a horn pattern: e.g. [2.6, 0.0] is one long blast, [1.0, 1.0, 1.0] three short.
func horn(pattern: Array, volume_db: float = -4.0) -> void:
	var delay := 0.0
	for length in pattern:
		var key := "foghorn" if float(length) > 2.0 else "foghorn_short"
		if delay <= 0.0:
			sfx(key, Vector3.INF, volume_db, 0.0)
		else:
			get_tree().create_timer(delay).timeout.connect(func() -> void: sfx(key, Vector3.INF, volume_db, 0.0))
		delay += (3.4 if key == "foghorn" else 1.5)

func _s_night_sting() -> PackedFloat32Array:
	var n := _n(2.8)
	var a := _tone(n, 55.0, 52.0, 1)
	var c := _tone(n, 82.4, 77.0, 1)
	_mix(a, c, 0.7)
	for i in n:
		var t := float(i) / RATE
		a[i] *= smoothstep(0.0, 1.0, t) * (1.0 - smoothstep(1.8, 2.8, t)) * 0.6
	return a

func _s_hurt() -> PackedFloat32Array:
	var b := _env(_tone(_n(0.3), 160.0, 80.0, 1), 0.003, 12.0)
	return _mix(b, _env(_lowpass(_noise(_n(0.15), 22), 1500.0), 0.002, 30.0), 0.6)

func _s_ui_move() -> PackedFloat32Array:
	return _gain(_env(_tone(_n(0.06), 880.0, 880.0), 0.002, 60.0), 0.25)

func _s_ui_accept() -> PackedFloat32Array:
	var a := _env(_tone(_n(0.2), 523.0, 523.0), 0.003, 18.0)
	return _gain(_mix(a, _env(_tone(_n(0.18), 784.0, 784.0), 0.003, 18.0), 0.8, _n(0.06)), 0.3)

func _s_bell() -> PackedFloat32Array:
	# A bell buoy: inharmonic partials with a long ring, slightly detuned.
	var n := _n(3.5)
	var b := PackedFloat32Array()
	b.resize(n)
	for p in [[220.0, 1.0, 1.2], [440.5, 0.5, 1.6], [583.0, 0.45, 2.0], [748.0, 0.3, 2.6], [1043.0, 0.18, 3.4]]:
		var t := _env(_tone(n, p[0], p[0] * 0.998), 0.002, p[2])
		_mix(b, t, p[1])
	return _gain(_lowpass(b, 2400.0), 0.35)

func _s_creak() -> PackedFloat32Array:
	# Timber under strain: a slow, wavering resonance driven by rough pulses.
	var n := _n(1.4)
	var b := PackedFloat32Array()
	b.resize(n)
	var ph := 0.0
	var r := RandomNumberGenerator.new()
	r.seed = 33
	for i in n:
		var t := float(i) / float(n)
		var f := 140.0 + 90.0 * sin(t * PI * 1.3) + r.randf_range(-12.0, 12.0)
		ph += TAU * f / RATE
		var pulse := 1.0 if fmod(ph, TAU) < 0.6 else 0.0
		b[i] = pulse * sin(t * PI)
	return _gain(_lowpass(_highpass(b, 120.0), 1400.0), 0.9)

func _s_whisper() -> PackedFloat32Array:
	# Breathy, half-heard: band-limited noise in syllable-like swells.
	var n := _n(2.2)
	var b := _highpass(_lowpass(_noise(n, 34), 3200.0), 900.0)
	for i in n:
		var t := float(i) / RATE
		var syll := pow(maxf(0.0, sin(t * TAU * 2.6 + sin(t * 3.0))), 2.0)
		b[i] *= syll * sin(t / 2.2 * PI) * 1.6
	return b

func _s_thunder() -> PackedFloat32Array:
	var n := _n(4.0)
	var b := _lowpass(_noise(n, 35), 180.0)
	var r := _lowpass(_noise(n, 36), 3.0)
	for i in n:
		var t := float(i) / RATE
		b[i] *= 7.0 * (smoothstep(0.0, 0.15, t) * exp(-t * 0.9)) * (0.6 + r[i] * 10.0)
	return b

func _s_wind() -> PackedFloat32Array:
	var n := _n(7.0)
	var b := _lowpass(_noise(n, 23), 420.0)
	var r := _lowpass(_noise(n, 24), 1.2)
	for i in n:
		var t := float(i) / RATE
		var gust := 0.55 + 0.45 * sin(t * TAU / 7.0 * 2.0 + 0.6) * sin(t * TAU / 7.0 * 3.0)
		b[i] *= 3.2 * gust * (1.0 + r[i] * 8.0)
	return _seamless(b, 1.0)

func _s_waves() -> PackedFloat32Array:
	var n := _n(9.0)
	var b := _lowpass(_noise(n, 25), 650.0)
	for i in n:
		var t := float(i) / RATE
		# Two overlapping swells per loop: rush in, hiss out.
		var s1 := pow(maxf(0.0, sin(t * TAU / 9.0 * 2.0)), 2.0)
		var s2 := pow(maxf(0.0, sin(t * TAU / 9.0 * 3.0 + 1.3)), 3.0) * 0.6
		b[i] *= 2.6 * (0.18 + s1 + s2)
	return _seamless(b, 1.0)

func _s_drone() -> PackedFloat32Array:
	var n := _n(9.0)
	var a := _tone(n, 49.0, 49.0, 1)
	_mix(a, _tone(n, 49.7, 49.7, 1), 0.8)
	_mix(a, _tone(n, 73.6, 73.6), 0.35)
	for i in n:
		var t := float(i) / RATE
		a[i] *= 0.35 * (0.7 + 0.3 * sin(t * TAU / 9.0))
	return _seamless(a, 1.5)
