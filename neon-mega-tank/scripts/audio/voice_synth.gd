class_name VoiceSynth
extends RefCounted
## Tiny formant speech synthesiser for Japanese shouts, bit-crushed into a robotic "electronic
## voice". Japanese suits this well: five vowels and simple consonant+vowel syllables.
## Input is romaji split into syllables with "-", e.g. "ya-ra-re-ta". "Q" is a glottal stop
## (small tsu), a lone "n" is the moraic n.

const RATE := 22050
const VOWELS := {
	"a": [800.0, 1250.0, 2600.0],
	"i": [300.0, 2300.0, 3000.0],
	"u": [350.0, 1350.0, 2400.0],
	"e": [480.0, 1900.0, 2600.0],
	"o": [480.0, 850.0, 2500.0],
}
const NASAL_M := [250.0, 1100.0, 2300.0]
const NASAL_N := [250.0, 1600.0, 2600.0]

# A segment: [kind, seconds, formants or noise centre, amplitude]
#   "v" voiced vowel-like, "h" aspirated noise through formants, "x" noise band, "s" silence.


static func say(romaji: String, pitch := 130.0, shout := true) -> AudioStreamWAV:
	var segs := _segments(romaji, shout)
	return _render(segs, pitch, shout)


static func _segments(romaji: String, shout: bool) -> Array:
	var segs: Array = []
	var syllables := romaji.split("-")
	for idx in syllables.size():
		var syl: String = syllables[idx]
		var last := idx == syllables.size() - 1
		if syl == "Q":
			segs.append(["s", 0.07, null, 0.0])
			continue
		if syl == "n":
			segs.append(["v", 0.09, NASAL_N, 0.45])
			continue
		var vowel := syl.right(1)
		if not VOWELS.has(vowel):
			continue
		var cons := syl.left(syl.length() - 1)
		var vf: Array = VOWELS[vowel]
		match cons:
			"k":
				segs.append(["s", 0.035, null, 0.0])
				segs.append(["x", 0.025, 1900.0, 0.5])
			"g":
				segs.append(["v", 0.03, [220.0, 900.0, 2300.0], 0.2])
				segs.append(["x", 0.012, 1800.0, 0.3])
			"t":
				segs.append(["s", 0.035, null, 0.0])
				segs.append(["x", 0.02, 4200.0, 0.5])
			"d":
				segs.append(["v", 0.025, [220.0, 1500.0, 2600.0], 0.2])
				segs.append(["x", 0.01, 3800.0, 0.3])
			"b":
				segs.append(["v", 0.03, [220.0, 700.0, 2200.0], 0.2])
			"p":
				segs.append(["s", 0.035, null, 0.0])
				segs.append(["x", 0.015, 900.0, 0.5])
			"s":
				segs.append(["x", 0.09, 6500.0, 0.45])
			"sh":
				segs.append(["x", 0.1, 3200.0, 0.55])
			"ch":
				segs.append(["s", 0.03, null, 0.0])
				segs.append(["x", 0.06, 3200.0, 0.55])
			"ts":
				segs.append(["s", 0.03, null, 0.0])
				segs.append(["x", 0.06, 6000.0, 0.5])
			"z", "j":
				segs.append(["x", 0.07, 3500.0 if cons == "j" else 6000.0, 0.35])
			"h", "f":
				segs.append(["h", 0.06, vf, 0.5])
			"m":
				segs.append(["v", 0.06, NASAL_M, 0.45])
			"n":
				segs.append(["v", 0.055, NASAL_N, 0.45])
			"r":
				segs.append(["v", 0.025, [350.0, 1400.0, 2400.0], 0.5])
			"y":
				segs.append(["v", 0.05, VOWELS["i"], 0.6])
			"w":
				segs.append(["v", 0.05, [300.0, 700.0, 2300.0], 0.6])
		var dur := 0.11
		if last:
			dur = 0.3 if shout else 0.18
		segs.append(["v", dur, vf, 1.0])
	return segs


static func _render(segs: Array, pitch: float, shout: bool) -> AudioStreamWAV:
	var total := 0.0
	for s in segs:
		total += s[1]
	total += 0.08
	var n := int(total * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pitch * 13.0) + n
	var bank := [_Resonator.new(), _Resonator.new(), _Resonator.new()]
	var noise_bp := _Resonator.new()
	var gains := [1.0, 0.55, 0.3]
	var phase := 0.0
	var cur_f := [500.0, 1500.0, 2500.0]
	var amp := 0.0
	var t := 0.0
	var seg_i := 0
	var seg_t := 0.0
	var held := 0.0
	for i in n:
		var seg: Array = segs[mini(seg_i, segs.size() - 1)]
		var kind: String = seg[0] if seg_i < segs.size() else "s"
		var target_amp: float = seg[3] if seg_i < segs.size() else 0.0
		# Glide formants toward the current target (coarticulation) and update filters.
		if (kind == "v" or kind == "h") and i % 32 == 0:
			var tf: Array = seg[2]
			for k in 3:
				cur_f[k] = lerpf(cur_f[k], tf[k], 0.35)
				bank[k].tune(cur_f[k], 70.0 + 40.0 * k)
		if kind == "x" and i % 32 == 0:
			noise_bp.tune(seg[2], seg[2] * 0.5)
		amp = lerpf(amp, target_amp, 0.01)
		# Pitch: a shout starts high and falls; slight wobble for a robotic edge.
		var prog := t / total
		var f0 := pitch * (1.35 - 0.5 * prog if shout else 1.1 - 0.2 * prog)
		f0 *= 1.0 + 0.03 * sin(t * TAU * 7.0)
		phase = fmod(phase + f0 / RATE, 1.0)
		var glottal := (1.0 - 2.0 * phase) * 0.8 + (0.4 if phase < 0.1 else 0.0)
		var noise := rng.randf_range(-1.0, 1.0)
		var s := 0.0
		match kind:
			"v":
				for k in 3:
					s += bank[k].process(glottal) * gains[k]
			"h":
				for k in 3:
					s += bank[k].process(noise * 0.6) * gains[k]
			"x":
				s = noise_bp.process(noise) * 1.6
		out[i] = s * amp
		t += 1.0 / RATE
		seg_t += 1.0 / RATE
		if seg_i < segs.size() and seg_t >= float(seg[1]):
			seg_t = 0.0
			seg_i += 1
	# Electronic voice: ring modulation, sample-and-hold and bit crushing.
	var peak := 0.001
	for i in n:
		peak = maxf(peak, absf(out[i]))
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		# Sample-and-hold halves the sample rate for a lo-fi chip sound.
		if i % 2 == 0:
			held = out[i] / peak
		var v := held * (0.8 + 0.2 * sin(float(i) / RATE * TAU * 55.0))
		v = roundf(v * 40.0) / 40.0
		data.encode_s16(i * 2, clampi(int(v * 0.9 * 32767.0), -32768, 32767))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


class _Resonator:
	## Two-pole band-pass filter (RBJ, constant 0 dB peak).
	var b0 := 0.0
	var b2 := 0.0
	var a1 := 0.0
	var a2 := 0.0
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0

	func tune(freq: float, bandwidth: float) -> void:
		var w0 := TAU * minf(freq, RATE * 0.45) / RATE
		var q := maxf(freq / maxf(bandwidth, 1.0), 0.5)
		var alpha := sin(w0) / (2.0 * q)
		var a0 := 1.0 + alpha
		b0 = alpha / a0
		b2 = -alpha / a0
		a1 = -2.0 * cos(w0) / a0
		a2 = (1.0 - alpha) / a0

	func process(x: float) -> float:
		var y := b0 * x + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		return y
