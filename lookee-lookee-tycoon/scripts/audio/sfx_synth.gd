class_name SfxSynth
extends RefCounted
## Synthesises the sound effects at startup so the game ships tiny. Each is a few hundred ms
## of 22 kHz mono. Replace any with a real recording by dropping res://audio/sfx/<name>.ogg.

const RATE := 22050


static func build() -> Dictionary:
	return {
		"coin": _coin(),
		"click": _tone(0.05, 900.0, 700.0, 0.0, 30.0, 0.5),
		"tap": _tone(0.04, 600.0, 500.0, 0.0, 40.0, 0.35),
		"shout": _whoosh(0.35, 0.5),
		"setup": _thunk(),
		"pack": _whoosh(0.28, 0.9),
		"whistle": _whistle(),
		"siren": _siren(),
		"buy": _register(),
		"error": _tone(0.22, 160.0, 140.0, 0.0, 6.0, 0.6, true),
		"upgrade": _arp([0, 4, 7, 12], 0.07, 880.0),
		"event": _arp([0, 7, 12, 7, 12], 0.08, 660.0),
		"bad_event": _arp([12, 6, 0], 0.11, 440.0),
		"busted": _arp([7, 6, 5, 4, 0], 0.13, 330.0),
		"escape": _arp([0, 4, 7, 12, 16], 0.07, 660.0),
		"day_end": _arp([0, 4, 7, 4, 7, 12], 0.11, 523.0),
		"hire": _arp([0, 7], 0.08, 784.0),
		"seagull": _seagull(),
		"no": _tone(0.18, 300.0, 220.0, 0.0, 8.0, 0.5),
	}


static func _env(t: float, length: float, attack := 0.005) -> float:
	return minf(1.0, t / attack) * clampf(1.0 - t / length, 0.0, 1.0)


static func _tone(length: float, f0: float, f1: float, noise: float, decay: float, vol: float, square := false) -> AudioStreamWAV:
	var n := int(length * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = int(f0 * 7.0)
	for i in n:
		var t := float(i) / RATE
		phase += lerpf(f0, f1, t / length) / RATE
		var w := sin(phase * TAU)
		if square:
			w = signf(w) * 0.6
		w = w * (1.0 - noise) + rng.randf_range(-1, 1) * noise
		buf[i] = w * exp(-t * decay) * _env(t, length) * vol
	return _to_wav(buf)


static func _coin() -> AudioStreamWAV:
	var length := 0.42
	var n := int(length * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in n:
		var t := float(i) / RATE
		var f := 1318.5 if t < 0.07 else 1760.0
		var w := sin(t * f * TAU) * 0.6 + sin(t * f * 2.0 * TAU) * 0.2
		buf[i] = w * exp(-t * 7.0) * _env(t, length) * 0.6
	return _to_wav(buf)


static func _whoosh(length: float, brightness: float) -> AudioStreamWAV:
	var n := int(length * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(length * 1000.0)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var cut := lerpf(0.05, brightness * 0.4, sin(t / length * PI))
		lp = lerpf(lp, rng.randf_range(-1, 1), cut)
		buf[i] = lp * sin(t / length * PI) * 1.4
	return _to_wav(buf)


static func _thunk() -> AudioStreamWAV:
	var length := 0.25
	var n := int(length * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		phase += lerpf(180.0, 70.0, minf(t * 8.0, 1.0)) / RATE
		buf[i] = (sin(phase * TAU) * exp(-t * 18.0) + rng.randf_range(-1, 1) * exp(-t * 60.0) * 0.4) * 0.8
	return _to_wav(buf)


static func _whistle() -> AudioStreamWAV:
	# Police whistle: two sharp trilled blasts.
	var length := 0.7
	var n := int(length * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for i in n:
		var t := float(i) / RATE
		var blast := 1.0 if (t < 0.22 or (t > 0.32 and t < 0.68)) else 0.0
		var f := 2900.0 + 120.0 * sin(t * TAU * 38.0)
		phase += f / RATE
		buf[i] = (sin(phase * TAU) * 0.8 + rng.randf_range(-1, 1) * 0.15) * blast * 0.45
	return _to_wav(buf)


static func _siren() -> AudioStreamWAV:
	var length := 1.2
	var n := int(length * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 720.0 if fmod(t, 0.6) < 0.3 else 960.0
		phase += f / RATE
		var w := 0.6 * sin(phase * TAU) + 0.25 * sin(phase * 2.0 * TAU)
		buf[i] = w * _env(t, length, 0.03) * 0.5
	return _to_wav(buf)


static func _register() -> AudioStreamWAV:
	var length := 0.55
	var n := int(length * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in n:
		var t := float(i) / RATE
		var drawer := rng.randf_range(-1, 1) * exp(-t * 30.0) * 0.5
		var bell := 0.0
		if t > 0.08:
			var tb := t - 0.08
			bell = (sin(tb * 2093.0 * TAU) + 0.5 * sin(tb * 2637.0 * TAU)) * exp(-tb * 6.0) * 0.4
		buf[i] = (drawer + bell) * _env(t, length)
	return _to_wav(buf)


static func _arp(semis: Array, step: float, base: float) -> AudioStreamWAV:
	var length := step * semis.size() + 0.25
	var n := int(length * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for k in semis.size():
		var f := base * pow(2.0, float(semis[k]) / 12.0)
		var start := int(k * step * RATE)
		for i in range(start, n):
			var t := float(i - start) / RATE
			var w := sin(t * f * TAU) * 0.5 + sin(t * f * 2.0 * TAU) * 0.15 + (fmod(t * f, 1.0) - 0.5) * 0.2
			buf[i] += w * exp(-t * 9.0) * minf(1.0, t / 0.004) * 0.45
	return _to_wav(buf)


static func _seagull() -> AudioStreamWAV:
	var length := 0.6
	var n := int(length * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	for i in n:
		var t := float(i) / RATE
		var cycle := fmod(t, 0.2) / 0.2
		var f := lerpf(1900.0, 1100.0, cycle)
		phase += f / RATE
		var w := (fmod(phase, 1.0) - 0.5) * 2.0
		buf[i] = (w * 0.5 + rng.randf_range(-1, 1) * 0.15) * sin(cycle * PI) * _env(t, length) * 0.4
	return _to_wav(buf)


static func _to_wav(buf: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, clampi(int(buf[i] * 32767.0), -32768, 32767))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
