class_name VoiceSynth
extends RefCounted
## Tiny Klatt-style formant speech synthesiser that shouts the catchphrases, so the game ships
## without voice recordings (adapted from the 3BL_Indie Neon Mega Tank voice, tuned for
## cartoon English). Drop real recordings in res://audio/voice/ to replace it (see
## AudioManager.VOICE_FILES).
##
## Input is syllables split by "-": consonant(s) + vowel ("he", "chi"), a vowel alone ("i"),
## or a consonant alone for word endings ("t", "d", "s"). "Q" is a short pause.
## Pitch is set per player with AudioStreamPlayer.pitch_scale, so each phrase renders once.

const RATE := 22050
const VOWELS := {
	"a": [700.0, 1220.0, 2600.0],   # nUgget
	"e": [550.0, 1770.0, 2490.0],   # hEllo
	"i": [390.0, 1990.0, 2550.0],   # chIcken
	"o": [500.0, 900.0, 2400.0],    # hellO
	"u": [400.0, 1100.0, 2350.0],   # gOOd
	"y": [300.0, 2300.0, 3000.0],   # verY, nIce glide end
	"ai": [750.0, 1300.0, 2550.0],  # nIce start
}
const VOWEL_TIME := 0.13
const GLIDE_TIME := 0.035


class Seg:
	var dur := 0.1
	var voice := 0.0
	var aspirate := 0.0
	var frication := 0.0
	var formants := [500.0, 1500.0, 2500.0]
	var fric_freq := 4000.0
	var fric_bw := 2000.0
	var glide := true

	func _init(d: float, f: Array, v := 1.0) -> void:
		dur = d
		formants = f
		voice = v


static func say(syllables: String, pitch := 140.0) -> AudioStreamWAV:
	return _render(_segments(syllables), pitch)


static func _noise(d: float, f: Array, amount: float, freq: float, bw: float) -> Seg:
	var s := Seg.new(d, f, 0.0)
	s.frication = amount
	s.fric_freq = freq
	s.fric_bw = bw
	return s


static func _split(syl: String) -> Array:
	for v: String in ["ai", "a", "e", "i", "o", "u", "y"]:
		if syl.ends_with(v) and syl.length() >= v.length():
			return [syl.left(syl.length() - v.length()), v]
	return [syl, ""]


static func _segments(text: String) -> Array:
	var segs: Array = []
	var syllables := text.split("-")
	var neutral := [500.0, 1500.0, 2500.0]
	for idx in syllables.size():
		var syl: String = syllables[idx]
		var last := idx == syllables.size() - 1
		if syl == "Q":
			segs.append(Seg.new(0.06, neutral, 0.0))
			continue
		var parts := _split(syl)
		var cons: String = parts[0]
		var vowel: String = parts[1]
		var vf: Array = VOWELS.get(vowel, neutral)
		var velar := [300.0, 1900.0 if vowel in ["i", "e", "y"] else 1500.0, 2400.0]
		var alveolar := [300.0, 1800.0, 2700.0]
		var labial := [300.0, 850.0, 2300.0]
		match cons:
			"k", "c":
				segs.append(Seg.new(0.04, velar, 0.0))
				segs.append(_noise(0.025, velar, 0.9, 2000.0, 1200.0))
				var asp := Seg.new(0.02, velar, 0.0)
				asp.aspirate = 0.6
				segs.append(asp)
			"g":
				segs.append(Seg.new(0.035, [220.0, velar[1], velar[2]], 0.25))
				segs.append(_noise(0.012, velar, 0.5, 2000.0, 1200.0))
			"t":
				segs.append(Seg.new(0.04, alveolar, 0.0))
				segs.append(_noise(0.03, alveolar, 0.9, 4500.0, 2500.0))
			"d":
				segs.append(Seg.new(0.03, [220.0, 1700.0, 2600.0], 0.25))
				segs.append(_noise(0.015, alveolar, 0.5, 4000.0, 2500.0))
			"p":
				segs.append(Seg.new(0.045, labial, 0.0))
				segs.append(_noise(0.012, labial, 0.8, 1000.0, 2000.0))
			"b":
				segs.append(Seg.new(0.035, [220.0, 800.0, 2200.0], 0.3))
			"s":
				segs.append(_noise(0.11, alveolar, 0.75, 6500.0, 3000.0))
			"ch":
				segs.append(Seg.new(0.035, [300.0, 2100.0, 2900.0], 0.0))
				segs.append(_noise(0.07, [300.0, 2100.0, 2900.0], 0.85, 3300.0, 1800.0))
			"h":
				var hs := Seg.new(0.07, vf, 0.0)
				hs.aspirate = 0.9
				hs.glide = false
				segs.append(hs)
			"v":
				var vs := _noise(0.06, [250.0, 1100.0, 2300.0], 0.35, 3500.0, 3000.0)
				vs.voice = 0.45
				segs.append(vs)
			"m":
				segs.append(Seg.new(0.07, [250.0, 1100.0, 2400.0], 0.6))
			"n":
				segs.append(Seg.new(0.065, [250.0, 1700.0, 2600.0], 0.6))
			"l":
				segs.append(Seg.new(0.06, [360.0, 1050.0, 2700.0], 0.8))
			"r":
				segs.append(Seg.new(0.05, [380.0, 1250.0, 1700.0], 0.75))
			"w":
				segs.append(Seg.new(0.06, [320.0, 750.0, 2300.0], 0.9))
			"y":
				segs.append(Seg.new(0.05, [280.0, 2250.0, 2900.0], 0.9))
		if vowel != "":
			var dur := VOWEL_TIME
			if last:
				dur = 0.26
			if vowel == "ai":
				segs.append(Seg.new(dur * 0.8, vf, 1.0))
				segs.append(Seg.new(dur * 0.6, VOWELS["y"], 1.0))
			else:
				segs.append(Seg.new(dur, vf, 1.0))
	segs.append(Seg.new(0.06, neutral, 0.0))
	return segs


static func _render(segs: Array, pitch: float) -> AudioStreamWAV:
	var total := 0.0
	for s: Seg in segs:
		total += s.dur
	var n := int(total * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = n + int(pitch)
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
			# Sing-song salesman intonation: up on the stressed middle, down at the end.
			var prog := t / total
			var f0 := pitch * (1.05 + 0.22 * sin(prog * PI * 1.6) - 0.25 * prog)
			f0 *= 1.0 + 0.012 * sin(t * TAU * 5.5) + rng.randf_range(-0.004, 0.004)
			phase += f0 * inv_rate
			if phase >= 1.0:
				phase -= 1.0
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
	var data := PackedByteArray()
	data.resize(n * 2)
	for j in n:
		data.encode_s16(j * 2, clampi(int(out[j] / peak * 0.9 * 32767.0), -32768, 32767))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


static func _coef(freq: float, bw: float) -> Vector3:
	var T := 1.0 / RATE
	var c := -exp(-TAU * bw * T)
	var b := 2.0 * exp(-PI * bw * T) * cos(TAU * minf(freq, RATE * 0.45) * T)
	return Vector3(1.0 - b - c, b, c)


static func _bandpass(freq: float, bw: float) -> Vector3:
	var w0 := TAU * minf(freq, RATE * 0.45) / RATE
	var q := maxf(freq / maxf(bw, 1.0), 0.5)
	var alpha := sin(w0) / (2.0 * q)
	var a0 := 1.0 + alpha
	return Vector3(alpha / a0, 2.0 * cos(w0) / a0, -(1.0 - alpha) / a0)
