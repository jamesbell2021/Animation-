class_name Synth
extends RefCounted
## Tiny offline synthesiser: oscillators with pitch glides, filtered noise and envelopes, written
## into a float buffer and wrapped as an AudioStreamWAV. Used for every sound effect and the
## soundtrack, so the game ships no audio files.

const RATE: int = 22050

static var _noise: PackedFloat32Array = PackedFloat32Array()


static func noise_table() -> PackedFloat32Array:
	if _noise.is_empty():
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 1234
		_noise.resize(RATE * 2)
		for i: int in range(_noise.size()):
			_noise[i] = rng.randf() * 2.0 - 1.0
	return _noise


static func alloc(seconds: float) -> PackedFloat32Array:
	var b: PackedFloat32Array = PackedFloat32Array()
	b.resize(int(seconds * RATE) + 1)
	return b


## Oscillator: wave = "sine", "square", "saw", "tri". Pitch glides exponentially f0 -> f1.
## Envelope: linear attack, then exponential decay to silence at the end of `dur`.
## `cut` > 0 runs a one-pole low-pass at that frequency.
static func tone(buf: PackedFloat32Array, t0: float, dur: float, f0: float, f1: float, wave: String, vol: float,
		attack: float = 0.003, cut: float = 0.0) -> void:
	var start: int = int(t0 * RATE)
	var n: int = int(dur * RATE)
	if start >= buf.size():
		return
	n = mini(n, buf.size() - start)
	var a: int = maxi(1, int(attack * RATE))
	var k: float = log(1000.0) / maxf(1.0, float(n - a))
	var ph: float = 0.0
	var glide: float = 0.0 if f1 <= 0.0 or is_equal_approx(f1, f0) else log(f1 / f0) / float(n)
	var lp: float = 0.0
	var ca: float = 1.0 - exp(-TAU * cut / float(RATE)) if cut > 0.0 else 1.0
	var w: int = 0
	match wave:
		"square": w = 1
		"saw": w = 2
		"tri": w = 3
	for i: int in range(n):
		var f: float = f0 * exp(glide * float(i)) if glide != 0.0 else f0
		ph += f / float(RATE)
		ph -= floorf(ph)
		var s: float
		if w == 0:
			s = sin(ph * TAU)
		elif w == 1:
			s = 1.0 if ph < 0.5 else -1.0
		elif w == 2:
			s = ph * 2.0 - 1.0
		else:
			s = 4.0 * absf(ph - 0.5) - 1.0
		if cut > 0.0:
			lp += (s - lp) * ca
			s = lp
		var env: float = float(i) / float(a) if i < a else exp(-k * float(i - a))
		buf[start + i] += s * env * vol


## Filtered noise: kind = "lp", "hp" or "bp" (RBJ biquad). The cutoff glides f0 -> f1.
static func noise(buf: PackedFloat32Array, t0: float, dur: float, vol: float, kind: String, f0: float, f1: float = 0.0,
		q: float = 0.7, attack: float = 0.002) -> void:
	var tab: PackedFloat32Array = noise_table()
	var start: int = int(t0 * RATE)
	var n: int = int(dur * RATE)
	if start >= buf.size():
		return
	n = mini(n, buf.size() - start)
	var a: int = maxi(1, int(attack * RATE))
	var k: float = log(1000.0) / maxf(1.0, float(n - a))
	var off: int = randi() % (tab.size() - n - 1) if tab.size() > n + 1 else 0
	var x1: float = 0.0
	var x2: float = 0.0
	var y1: float = 0.0
	var y2: float = 0.0
	var b0: float = 0.0
	var b1: float = 0.0
	var b2: float = 0.0
	var a1: float = 0.0
	var a2: float = 0.0
	var fend: float = f1 if f1 > 0.0 else f0
	for i: int in range(n):
		if i % 32 == 0:
			var fc: float = clampf(f0 * pow(fend / f0, float(i) / float(n)), 20.0, RATE * 0.45)
			var w0: float = TAU * fc / float(RATE)
			var cw: float = cos(w0)
			var al: float = sin(w0) / (2.0 * q)
			var a0: float = 1.0 + al
			if kind == "lp":
				b0 = (1.0 - cw) * 0.5 / a0
				b1 = (1.0 - cw) / a0
				b2 = b0
			elif kind == "hp":
				b0 = (1.0 + cw) * 0.5 / a0
				b1 = -(1.0 + cw) / a0
				b2 = b0
			else:
				b0 = al / a0
				b1 = 0.0
				b2 = -al / a0
			a1 = -2.0 * cw / a0
			a2 = (1.0 - al) / a0
		var x: float = tab[(off + i) % tab.size()]
		var y: float = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		var env: float = float(i) / float(a) if i < a else exp(-k * float(i - a))
		buf[start + i] += y * env * vol


static func midi_f(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69.0) / 12.0)


## Koto-ish pluck: bright triangle + detuned saw through a closing low-pass.
static func pluck(buf: PackedFloat32Array, t0: float, f: float, vol: float, dur: float = 0.9) -> void:
	var start: int = int(t0 * RATE)
	var n: int = mini(int(dur * RATE), buf.size() - start)
	if n <= 0:
		return
	var k: float = log(1000.0) / float(n)
	var p1: float = 0.0
	var p2: float = 0.0
	var lp: float = 0.0
	for i: int in range(n):
		p1 += f / float(RATE)
		p1 -= floorf(p1)
		p2 += f * 1.003 / float(RATE)
		p2 -= floorf(p2)
		var s: float = (4.0 * absf(p1 - 0.5) - 1.0) + (p2 * 2.0 - 1.0) * 0.25
		var cut: float = 700.0 + 4500.0 * exp(-float(i) / float(RATE) * 6.0)
		lp += (s - lp) * (1.0 - exp(-TAU * cut / float(RATE)))
		var env: float = float(i) / 60.0 if i < 60 else exp(-k * float(i - 60))
		buf[start + i] += lp * env * vol


static func to_wav(buf: PackedFloat32Array, loop: bool = false, gain: float = 1.0) -> AudioStreamWAV:
	var peak: float = 0.0
	for v: float in buf:
		peak = maxf(peak, absf(v))
	var g: float = gain
	if peak * g > 0.98:
		g = 0.98 / peak
	var data: PackedByteArray = PackedByteArray()
	data.resize(buf.size() * 2)
	for i: int in range(buf.size()):
		data.encode_s16(i * 2, int(clampf(buf[i] * g, -1.0, 1.0) * 32767.0))
	var w: AudioStreamWAV = AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = buf.size()
	return w
