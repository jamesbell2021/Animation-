class_name SfxBank
extends RefCounted
## Synthesises every sound effect at startup, so the project ships without audio files.

const RATE := 22050


static func build() -> Dictionary:
	return {
		"cannon": _synth(0.7, 150.0, 35.0, 0.7, 5.0),
		"explosion": _synth(1.0, 90.0, 25.0, 0.88, 4.0),
		"mg": _synth(0.07, 700.0, 250.0, 0.65, 7.0, true),
		"rifle": _synth(0.08, 1300.0, 500.0, 0.75, 9.0),
		"rocket": _synth(0.55, 250.0, 900.0, 0.85, 2.5),
		"enemy_cannon": _synth(0.6, 110.0, 40.0, 0.7, 5.0),
		"hit": _synth(0.06, 1800.0, 1100.0, 0.3, 10.0, true),
		"repair": _synth(0.1, 650.0, 1300.0, 0.0, 4.0, true),
		"fix": _synth(0.3, 500.0, 1600.0, 0.0, 2.5, true),
		"join": _synth(0.3, 440.0, 990.0, 0.0, 2.5, true),
		"station": _synth(0.08, 900.0, 1200.0, 0.0, 5.0, true),
		"leave": _synth(0.08, 900.0, 600.0, 0.0, 5.0, true),
		"alarm": _synth(0.45, 760.0, 520.0, 0.0, 1.2, true),
		"crush": _synth(0.35, 220.0, 50.0, 0.9, 5.0),
		"crumble": _synth(0.5, 120.0, 40.0, 0.95, 4.0),
		"wave": _synth(0.8, 220.0, 440.0, 0.1, 1.5, true),
	}


## A pitch-swept tone mixed with low-passed noise under an exponential decay.
static func _synth(length: float, f0: float, f1: float, noise: float, decay: float,
		square := false) -> AudioStreamWAV:
	var n := int(length * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
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
		var env := exp(-k * decay) * minf(1.0, t * 300.0) * minf(1.0, (length - t) * 60.0)
		data.encode_s16(i * 2, clampi(int(s * env * 0.7 * 32767.0), -32768, 32767))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
