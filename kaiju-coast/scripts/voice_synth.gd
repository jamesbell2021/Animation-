class_name VoiceSynth
extends RefCounted
## (Shared with Neon Mega Tank: copied from neon-mega-tank/scripts/audio/voice_synth.gd.)
## Tiny Klatt-style formant speech synthesiser for Japanese shouts, finished with a light
## bit-crush so it sounds like an electronic voice. Japanese suits this well: five vowels and simple
## consonant+vowel syllables.
##
## Voiced sound: a glottal pulse train through a cascade of five resonators (F1-F5); consonants
## add noise bursts and fricative bands, and every syllable glides its formants in from the
## consonant's "locus" - the transition our ears use to tell k from t from p.
## Input is romaji split into syllables with "-", e.g. "ya-ra-re-ta". "Q" is a glottal stop
## (small tsu), a lone "n" is the moraic n. Intelligibility was tuned against an offline Japanese
## speech recogniser.

const RATE := 22050
const VOWELS := {
	"a": [750.0, 1200.0, 2600.0],
	"i": [300.0, 2250.0, 3000.0],
	"u": [350.0, 1400.0, 2400.0],
	"e": [480.0, 1900.0, 2600.0],
	"o": [480.0, 850.0, 2500.0],
}
const VOWEL_TIME := 0.14
const GLIDE_TIME := 0.035


## A segment of speech with targets for every synthesis parameter.
class Seg:
	var dur := 0.1
	var voice := 0.0      # glottal source amplitude
	var aspirate := 0.0   # noise into the formant cascade (h, aspiration after stops)
	var frication := 0.0  # noise through its own band-pass (s, sh, bursts)
	var formants := [500.0, 1500.0, 2500.0]
	var fric_freq := 4000.0
	var fric_bw := 2000.0
	var glide := true     # glide formants in from the previous segment

	func _init(d: float, f: Array, v := 1.0) -> void:
		dur = d
		formants = f
		voice = v


static func say(romaji: String, pitch := 125.0, shout := true) -> AudioStreamWAV:
	return _render(_segments(romaji, shout), pitch, shout)


static func _noise(d: float, f: Array, amount: float, freq: float, bw: float) -> Seg:
	var s := Seg.new(d, f, 0.0)
	s.frication = amount
	s.fric_freq = freq
	s.fric_bw = bw
	return s


static func _silence(d: float, f: Array) -> Seg:
	return Seg.new(d, f, 0.0)


static func _segments(romaji: String, shout: bool) -> Array:
	var segs: Array = []
	var syllables := romaji.split("-")
	for idx in syllables.size():
		var syl: String = syllables[idx]
		var last := idx == syllables.size() - 1
		if syl == "Q":
			segs.append(_silence(0.08, [500.0, 1500.0, 2500.0]))
			continue
		if syl == "n":
			segs.append(Seg.new(0.1, [250.0, 1700.0, 2600.0], 0.55))
			continue
		var vowel := syl.right(1)
		if not VOWELS.has(vowel):
			continue
		var cons := syl.left(syl.length() - 1)
		var vf: Array = VOWELS[vowel]
		# Consonant loci: where F2/F3 start before gliding into the vowel.
		var velar := [300.0, 1900.0 if vowel in ["i", "e"] else 1500.0, 2400.0]
		var alveolar := [300.0, 1800.0, 2700.0]
		var labial := [300.0, 850.0, 2300.0]
		match cons:
			"k":
				segs.append(_silence(0.045, velar))
				segs.append(_noise(0.025, velar, 0.9, 2000.0, 1200.0))
				var asp := Seg.new(0.02, velar, 0.0)
				asp.aspirate = 0.6
				segs.append(asp)
			"g":
				segs.append(Seg.new(0.035, [220.0, velar[1], velar[2]], 0.25))
				segs.append(_noise(0.012, velar, 0.5, 2000.0, 1200.0))
			"t":
				segs.append(_silence(0.04, alveolar))
				segs.append(_noise(0.018, alveolar, 0.9, 4500.0, 2500.0))
				var asp2 := Seg.new(0.015, alveolar, 0.0)
				asp2.aspirate = 0.5
				segs.append(asp2)
			"d":
				segs.append(Seg.new(0.03, [220.0, 1700.0, 2600.0], 0.25))
				segs.append(_noise(0.01, alveolar, 0.5, 4000.0, 2500.0))
			"p":
				segs.append(_silence(0.045, labial))
				segs.append(_noise(0.012, labial, 0.8, 1000.0, 2000.0))
			"b":
				segs.append(Seg.new(0.035, [220.0, 800.0, 2200.0], 0.3))
			"s":
				segs.append(_noise(0.1, alveolar, 0.75, 6500.0, 3000.0))
			"sh":
				segs.append(_noise(0.11, [300.0, 2100.0, 2900.0], 0.85, 3300.0, 1800.0))
			"ch":
				segs.append(_silence(0.035, [300.0, 2100.0, 2900.0]))
				segs.append(_noise(0.07, [300.0, 2100.0, 2900.0], 0.85, 3300.0, 1800.0))
			"ts":
				segs.append(_silence(0.035, alveolar))
				segs.append(_noise(0.07, alveolar, 0.75, 6000.0, 3000.0))
			"z", "j":
				var vz := _noise(0.08, alveolar if cons == "z" else [300.0, 2100.0, 2900.0], 0.4,
						6000.0 if cons == "z" else 3300.0, 2500.0)
				vz.voice = 0.3
				segs.append(vz)
			"h", "f":
				var hs := Seg.new(0.07, vf, 0.0)
				hs.aspirate = 0.9
				hs.glide = false
				if cons == "f":
					hs.frication = 0.3
					hs.fric_freq = 1500.0
				segs.append(hs)
			"m":
				segs.append(Seg.new(0.07, [250.0, 1100.0, 2400.0], 0.6))
			"n":
				segs.append(Seg.new(0.06, [250.0, 1700.0, 2600.0], 0.6))
			"r":
				segs.append(Seg.new(0.03, [350.0, 1350.0, 2500.0], 0.6))
			"y":
				segs.append(Seg.new(0.06, [280.0, 2250.0, 2900.0], 0.9))
			"w":
				segs.append(Seg.new(0.06, [320.0, 750.0, 2300.0], 0.9))
		var dur := VOWEL_TIME
		if last:
			dur = 0.3 if shout else 0.2
		segs.append(Seg.new(dur, vf, 1.0))
	segs.append(_silence(0.06, [500.0, 1500.0, 2500.0]))
	return segs


static func _render(segs: Array, pitch: float, shout: bool) -> AudioStreamWAV:
	var total := 0.0
	for s: Seg in segs:
		total += s.dur
	var n := int(total * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = n + int(pitch)
	# Resonator coefficients (a, b, c) and state (y1, y2) for the five-formant cascade,
	# unrolled into locals because this loop runs ~20k times per second of speech.
	var bw1 := 70.0
	var bw2 := 90.0
	var bw3 := 150.0
	var c4 := _coef(3300.0, 250.0)
	var c5 := _coef(3750.0, 200.0)
	var c1 := _coef(500.0, bw1)
	var c2 := _coef(1500.0, bw2)
	var c3 := _coef(2500.0, bw3)
	var p11 := 0.0
	var p12 := 0.0
	var p21 := 0.0
	var p22 := 0.0
	var p31 := 0.0
	var p32 := 0.0
	var p41 := 0.0
	var p42 := 0.0
	var p51 := 0.0
	var p52 := 0.0
	var fx1 := 0.0
	var fx2 := 0.0
	var fy1 := 0.0
	var fy2 := 0.0
	var phase := 0.0
	var prev_out := 0.0
	var cur := [500.0, 1500.0, 2500.0]
	var av := 0.0
	var ah := 0.0
	var af := 0.0
	var i := 0
	var t := 0.0
	var inv_rate := 1.0 / RATE
	for s: Seg in segs:
		var start: Array = cur.duplicate() if s.glide else s.formants.duplicate()
		var seg_n := int(s.dur * RATE)
		var fb := _bandpass(s.fric_freq, s.fric_bw)
		for k in seg_n:
			if i >= n:
				break
			if k % 32 == 0:
				var g := clampf(float(k) * inv_rate / GLIDE_TIME, 0.0, 1.0)
				g = g * g * (3.0 - 2.0 * g)
				cur = [lerpf(start[0], s.formants[0], g), lerpf(start[1], s.formants[1], g),
					lerpf(start[2], s.formants[2], g)]
				c1 = _coef(cur[0], bw1)
				c2 = _coef(cur[1], bw2)
				c3 = _coef(cur[2], bw3)
			av += (s.voice - av) * 0.02
			ah += (s.aspirate - ah) * 0.05
			af += (s.frication - af) * 0.08
			# Pitch: an exclamation starts high and falls; tiny jitter keeps it from buzzing.
			var prog := t / total
			var f0 := pitch * ((1.18 - 0.3 * prog) if shout else (1.1 - 0.2 * prog))
			f0 *= 1.0 + 0.01 * sin(t * TAU * 5.0) + rng.randf_range(-0.004, 0.004)
			phase += f0 * inv_rate
			if phase >= 1.0:
				phase -= 1.0
			# Rosenberg glottal pulse.
			var glottal := 0.0
			if phase < 0.4:
				glottal = 0.5 * (1.0 - cos(PI * phase / 0.4))
			elif phase < 0.56:
				glottal = cos(PI * 0.5 * (phase - 0.4) / 0.16)
			var noise := rng.randf_range(-1.0, 1.0)
			var x := glottal * av + noise * ah * 0.25
			var y := c1.x * x + c1.y * p11 + c1.z * p12
			p12 = p11
			p11 = y
			x = y
			y = c2.x * x + c2.y * p21 + c2.z * p22
			p22 = p21
			p21 = y
			x = y
			y = c3.x * x + c3.y * p31 + c3.z * p32
			p32 = p31
			p31 = y
			x = y
			y = c4.x * x + c4.y * p41 + c4.z * p42
			p42 = p41
			p41 = y
			x = y
			y = c5.x * x + c5.y * p51 + c5.z * p52
			p52 = p51
			p51 = y
			# Lip radiation (first difference) brightens the voiced sound.
			var voiced := y - prev_out
			prev_out = y
			var fr := fb.x * noise - fb.x * fx2 + fb.y * fy1 + fb.z * fy2
			fx2 = fx1
			fx1 = noise
			fy2 = fy1
			fy1 = fr
			out[i] = voiced * 6.0 + fr * af * 0.6
			i += 1
			t += inv_rate
	var peak := 0.001
	for j in n:
		peak = maxf(peak, absf(out[j]))
	# Electronic voice: soft sample-and-hold and gentle bit-crush.
	var data := PackedByteArray()
	data.resize(n * 2)
	var held := 0.0
	for j in n:
		if j % 2 == 0:
			held = out[j] / peak
		var v := roundf(held * 48.0) / 48.0
		data.encode_s16(j * 2, clampi(int(v * 0.9 * 32767.0), -32768, 32767))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


## Klatt resonator coefficients (a, b, c): all-pole, unity gain at DC.
static func _coef(freq: float, bw: float) -> Vector3:
	var T := 1.0 / RATE
	var c := -exp(-TAU * bw * T)
	var b := 2.0 * exp(-PI * bw * T) * cos(TAU * minf(freq, RATE * 0.45) * T)
	return Vector3(1.0 - b - c, b, c)


## Constant-peak band-pass for noise (gain, b1, b2) with y = g*x - g*x2 + b1*y1 + b2*y2.
static func _bandpass(freq: float, bw: float) -> Vector3:
	var w0 := TAU * minf(freq, RATE * 0.45) / RATE
	var q := maxf(freq / maxf(bw, 1.0), 0.5)
	var alpha := sin(w0) / (2.0 * q)
	var a0 := 1.0 + alpha
	return Vector3(alpha / a0, 2.0 * cos(w0) / a0, -(1.0 - alpha) / a0)
