class_name SfxBank
extends RefCounted
## Synthesises every sound effect at startup, so the project ships without audio files.
## Big sounds are layered like real recordings: a sub-bass thump, a noisy crack and a short
## room reverb tail.

const RATE := 22050


static func build() -> Dictionary:
	return {
		"cannon": _gun(0.9, 75.0, 1.0, 0.55, true),
		"enemy_cannon": _gun(0.8, 60.0, 0.85, 0.5, true),
		"mg": _gun(0.09, 160.0, 0.5, 1.0, false),
		"rifle": _gun(0.1, 260.0, 0.35, 1.0, false),
		"explosion": _explosion(1.3),
		"crumble": _crumble(0.7),
		"crush": _crumble(0.35),
		"rocket": _rocket(0.6),
		"hit": _synth(0.06, 1800.0, 1100.0, 0.3, 10.0, true),
		"repair": _synth(0.1, 650.0, 1300.0, 0.0, 4.0, true),
		"fix": _synth(0.3, 500.0, 1600.0, 0.0, 2.5, true),
		"join": _synth(0.3, 440.0, 990.0, 0.0, 2.5, true),
		"station": _synth(0.08, 900.0, 1200.0, 0.0, 5.0, true),
		"leave": _synth(0.08, 900.0, 600.0, 0.0, 5.0, true),
		"alarm": _synth(0.45, 760.0, 520.0, 0.0, 1.2, true),
		"wave": _synth(0.8, 220.0, 440.0, 0.1, 1.5, true),
	}


## Gunshot: sub thump + band-limited crack (+ optional reverb tail for big guns).
static func _gun(length: float, thump_hz: float, thump_amt: float, crack_amt: float, tail: bool) -> AudioStreamWAV:
	var n := int(length * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(thump_hz * 13.0 + length * 100.0)
	var phase := 0.0
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		phase += lerpf(thump_hz * 1.8, thump_hz * 0.5, minf(1.0, t * 8.0)) / RATE
		var thump := sin(phase * TAU) * exp(-t * 9.0) * thump_amt
		var w := rng.randf_range(-1.0, 1.0)
		lp = lerpf(lp, w, 0.55)
		lp2 = lerpf(lp2, w, 0.08)
		var crack := (lp * exp(-t * 60.0) + lp2 * exp(-t * 14.0) * 0.8) * crack_amt
		buf[i] = (thump + crack) * minf(1.0, t * 2000.0)
	if tail:
		_reverb(buf, 0.35)
	return _to_wav(buf)


static func _explosion(length: float) -> AudioStreamWAV:
	var n := int(length * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 991
	var phase := 0.0
	var lp := 0.0
	var lp_slow := 0.0
	for i in n:
		var t := float(i) / RATE
		phase += lerpf(90.0, 28.0, minf(1.0, t * 3.0)) / RATE
		var boom := sin(phase * TAU) * exp(-t * 3.5) * 1.1
		var w := rng.randf_range(-1.0, 1.0)
		lp = lerpf(lp, w, lerpf(0.5, 0.05, minf(1.0, t * 2.0)))
		lp_slow = lerpf(lp_slow, w, 0.03)
		var rumble := (lp * exp(-t * 4.0) + lp_slow * 3.0 * exp(-t * 2.0)) * 0.8
		# Sparse crackles of debris in the tail.
		var crackle := 0.0
		if rng.randf() < 0.004 * exp(-t * 2.0):
			crackle = rng.randf_range(-1.0, 1.0) * 0.8
		buf[i] = (boom + rumble + crackle) * minf(1.0, t * 1500.0)
	_reverb(buf, 0.4)
	return _to_wav(buf)


static func _crumble(length: float) -> AudioStreamWAV:
	var n := int(length * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(length * 777.0)
	var lp := 0.0
	var grain := 0.0
	for i in n:
		var t := float(i) / RATE
		if rng.randf() < 0.01:
			grain = rng.randf_range(0.4, 1.0)
		grain *= 0.995
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.12)
		buf[i] = lp * (0.4 + grain) * exp(-t / length * 3.0)
	return _to_wav(buf)


static func _rocket(length: float) -> AudioStreamWAV:
	var n := int(length * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4321
	var lp := 0.0
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var k := t / length
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), lerpf(0.05, 0.4, k))
		phase += 60.0 / RATE
		var launch := sin(phase * TAU) * exp(-t * 25.0)
		buf[i] = (lp * 1.6 * sin(PI * minf(k * 1.4, 1.0)) + launch) * minf(1.0, t * 500.0)
	return _to_wav(buf)


## Three feedback combs: a short, dark room tail.
static func _reverb(buf: PackedFloat32Array, mix: float) -> void:
	var delays := [int(0.031 * RATE), int(0.047 * RATE), int(0.067 * RATE)]
	var dry := buf.duplicate()
	for d in delays:
		var line := PackedFloat32Array()
		line.resize(buf.size())
		var lp := 0.0
		for i in buf.size():
			var fb := line[i - d] if i >= d else 0.0
			lp = lerpf(lp, fb, 0.4)
			line[i] = dry[i] + lp * 0.62
		for i in buf.size():
			buf[i] += (line[i] - dry[i]) * mix / delays.size()


static func _to_wav(buf: PackedFloat32Array) -> AudioStreamWAV:
	var peak := 0.001
	for v in buf:
		peak = maxf(peak, absf(v))
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	var end := buf.size()
	for i in buf.size():
		var fade := minf(1.0, float(end - i) / (RATE * 0.02))
		data.encode_s16(i * 2, clampi(int(buf[i] / peak * 0.8 * fade * 32767.0), -32768, 32767))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


## A pitch-swept tone mixed with low-passed noise under an exponential decay (UI blips).
static func _synth(length: float, f0: float, f1: float, noise: float, decay: float,
		square := false) -> AudioStreamWAV:
	var n := int(length * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(f0 * 31.0 + f1 * 7.0 + length * 1000.0)
	var phase := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var k := t / length
		var f := lerpf(f0, f1, k)
		phase += f / RATE
		var tone := sin(phase * TAU)
		if square:
			tone = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), clampf(f / RATE * 8.0, 0.03, 1.0))
		var s := lerpf(tone * 0.6, lp * 2.2, noise)
		buf[i] = s * exp(-k * decay) * minf(1.0, t * 300.0) * 0.7
	return _to_wav(buf)
