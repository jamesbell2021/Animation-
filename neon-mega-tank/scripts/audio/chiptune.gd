class_name Chiptune
extends RefCounted
## Procedural anime-style chiptune. Songs are composed from a seed (so they are the same every
## run) and rendered once into looping AudioStreamWAVs: pulse-wave lead with vibrato, fast
## arpeggios, a triangle bass and noise drums, like an 8-bit console.
##
## "battle": J-pop "royal road" progression (IV-V-iii-vi) at 160 BPM with a pentatonic lead.
## "lobby":  Japanese In scale (Miyako-bushi) koto-style plucks over a half-step bass.
## "gameover": short descending sting.

const RATE := 22050

# Scale degrees in semitones.
const MAJOR := [0, 2, 4, 5, 7, 9, 11]
const MAJOR_PENTA := [0, 2, 4, 7, 9]
const IN_SCALE := [0, 1, 5, 7, 8]

# Rhythms for one bar of eighth notes: 1 = new note, 0 = hold, -1 = rest.
const RHYTHMS := [
	[1, 0, 1, 0, 1, 1, 0, 1],
	[1, 1, 0, 1, 0, 1, 1, 0],
	[1, 0, 0, 1, 0, 0, 1, 0],
	[1, 0, 1, 1, 0, 1, 0, -1],
	[1, 1, 1, 0, 1, 0, 1, 1],
	[1, 0, 0, 0, 1, 1, 1, 1],
]

var _buf := PackedFloat32Array()
var _rng := RandomNumberGenerator.new()


static func render(track: String) -> AudioStreamWAV:
	var c := Chiptune.new()
	match track:
		"battle":
			return c._battle()
		"lobby":
			return c._lobby()
	return c._gameover()


# --- Songs -----------------------------------------------------------------------------------

func _battle() -> AudioStreamWAV:
	_rng.seed = 7311
	var bpm := 160.0
	var key := 62  # D major
	var beat := 60.0 / bpm
	var bar := beat * 4.0
	# Chords as [scale degree root offset, minor?]. Royal road + "Komuro" progression.
	var a_section := [[5, false], [7, false], [4, true], [9, true]]  # IV V iii vi
	var b_section := [[9, true], [5, false], [7, false], [0, false]]  # vi IV V I
	var chords: Array = []
	for i in 2:
		chords.append(a_section[i % 2 * 2])  # intro: IV IV-ish pad
	for rep in 2:
		chords.append_array(a_section)
	for rep in 2:
		chords.append_array(b_section)
	chords.append_array(a_section)
	var bars := chords.size()
	_alloc(bars * bar)
	var intro_bars := 2

	for b in bars:
		var t0 := b * bar
		var ch: Array = chords[b]
		var root: int = key + ch[0]
		var tones := _chord(root, ch[1])
		_drums(t0, beat, b < intro_bars, b % 4 == 3)
		# Driving octave bass in eighths.
		for e in 8:
			var n := root - 24 + (12 if e % 2 == 1 else 0)
			if e == 6 and b % 2 == 1:
				n = root - 24 + 7
			_note(t0 + e * beat * 0.5, beat * 0.45, n, 0.32, "tri")
		# 16th-note arpeggio sweeping two octaves.
		for s in 16:
			var idx := s % 6
			var n2: int = tones[idx % 3] + (12 if idx >= 3 else 0)
			_note(t0 + s * beat * 0.25, beat * 0.2, n2, 0.07, "pulse50")
	# Lead melody: two motifs, repeated with chord-aware variation.
	var motif_a := _motif(2)
	var motif_b := _motif(2)
	for b in range(intro_bars, bars):
		var section_b := b >= intro_bars + 8 and b < intro_bars + 16
		var motif: Array = motif_b if section_b else motif_a
		var half: int = (b - intro_bars) % 2
		var ch: Array = chords[b]
		var root: int = key + ch[0]
		var shift := 5 if section_b else 0
		_play_motif_bar(motif[half], b * bar, beat, root, ch[1], key + 12 + shift,
				MAJOR_PENTA, (b - intro_bars) % 8 == 7)
	return _finish(intro_bars * bar, bars * bar)


func _lobby() -> AudioStreamWAV:
	_rng.seed = 4242
	var bpm := 104.0
	var key := 64  # E, In scale: E F A B C
	var beat := 60.0 / bpm
	var bar := beat * 4.0
	var bass_roots := [0, 1, 0, -4, 0, 1, 3, -5]  # E F E C E F G B
	var bars := 16
	_alloc(bars * bar)
	for b in bars:
		var t0 := b * bar
		var root: int = key - 24 + bass_roots[b % bass_roots.size()]
		# Taiko-style low drum and a woodblock tick.
		_kick(t0, 0.5)
		_kick(t0 + beat * 2.5, 0.35)
		if b % 2 == 1:
			_kick(t0 + beat * 3.5, 0.3)
		for e in 8:
			if e % 2 == 1:
				_noise_hit(t0 + e * beat * 0.5, 0.02, 0.05, 0.9)
		_note(t0, bar * 0.95, root, 0.28, "tri")
		_note(t0 + beat * 2.0, beat * 1.8, root + 7, 0.18, "tri")
		# Koto plucks: In-scale broken pattern in 16ths.
		for s in 16:
			if _rng.randf() < 0.25:
				continue
			var deg: int = [0, 2, 3, 4, 2, 3][s % 6]
			var n: int = key + IN_SCALE[deg] + (12 if s % 8 >= 6 else 0)
			_note(t0 + s * beat * 0.25, beat * 0.5, n, 0.08, "pluck")
	var motif := _motif(2)
	for b in range(4, bars):
		_play_motif_bar(motif[b % 2], b * bar, beat, key, true, key + 12, IN_SCALE, b % 4 == 3, "flute")
	return _finish(0.0, bars * bar)


func _gameover() -> AudioStreamWAV:
	var beat := 60.0 / 90.0
	_alloc(beat * 6.0)
	var notes := [76, 72, 71, 65, 64]
	for i in notes.size():
		_note(i * beat * 0.5, beat * (2.0 if i == notes.size() - 1 else 0.5), notes[i], 0.22, "pulse25")
		_note(i * beat * 0.5, beat * 0.5, notes[i] - 24, 0.25, "tri")
	var w := _finish(-1.0, beat * 6.0)
	return w


# --- Composition helpers ---------------------------------------------------------------------

func _chord(root: int, minor: bool) -> Array:
	return [root, root + (3 if minor else 4), root + 7]


## A motif is an array of bars; each bar is a list of [slot, length, scale_step] events.
func _motif(bar_count: int) -> Array:
	var bars: Array = []
	var step := _rng.randi_range(2, 4)
	for b in bar_count:
		var rhythm: Array = RHYTHMS[_rng.randi() % RHYTHMS.size()]
		var events: Array = []
		var slot := 0
		while slot < 8:
			if rhythm[slot] == 1:
				var length := 1
				while slot + length < 8 and rhythm[slot + length] == 0:
					length += 1
				step = clampi(step + [-2, -1, -1, 1, 1, 2, 0][_rng.randi() % 7], 0, 7)
				events.append([slot, length, step])
				slot += length
			else:
				slot += 1
		bars.append(events)
	return bars


func _play_motif_bar(events: Array, t0: float, beat: float, root: int, minor: bool, base: int,
		scale: Array, cadence: bool, voice := "lead") -> void:
	var tones := _chord(root, minor)
	for i in events.size():
		var ev: Array = events[i]
		var slot: int = ev[0]
		var length: int = ev[1]
		var step: int = ev[2]
		var n: int = base + scale[step % scale.size()] + 12 * (step / scale.size())
		# Strong beats land on a chord tone so repeated motifs fit every chord.
		if slot % 4 == 0:
			n = _nearest_chord_tone(n, tones)
		if cadence and i == events.size() - 1:
			n = _nearest_chord_tone(n, tones)
			length = 8 - slot
		_note(t0 + slot * beat * 0.5, length * beat * 0.5 * 0.92, n, 0.17, voice)


func _nearest_chord_tone(n: int, tones: Array) -> int:
	var best := n
	var best_d := 99
	for t in tones:
		for o in range(-3, 4):
			var c: int = t + o * 12
			if absi(c - n) < best_d:
				best_d = absi(c - n)
				best = c
	return best


# --- Synthesis -------------------------------------------------------------------------------

func _alloc(seconds: float) -> void:
	_buf = PackedFloat32Array()
	_buf.resize(int(seconds * RATE) + RATE)


func _note(t: float, dur: float, midi: int, vol: float, voice: String) -> void:
	var start := int(t * RATE)
	var release := 0.03 if voice != "pluck" else 0.15
	var n := int((dur + release) * RATE)
	var f := 440.0 * pow(2.0, (midi - 69) / 12.0)
	var duty := 0.5
	match voice:
		"lead", "pulse25":
			duty = 0.25
		"flute":
			duty = 0.125
	var phase := 0.0
	var end := mini(start + n, _buf.size())
	for i in range(start, end):
		var k := float(i - start) / RATE
		var freq := f
		if voice == "lead" or voice == "flute":
			freq *= 1.0 + 0.012 * sin(k * TAU * 5.5) * clampf((k - 0.12) * 6.0, 0.0, 1.0)
		phase = fmod(phase + freq / RATE, 1.0)
		var s: float
		if voice == "tri":
			s = 4.0 * absf(phase - 0.5) - 1.0
		else:
			s = 1.0 if phase < duty else -1.0
		var env := minf(1.0, k * 400.0)
		if voice == "pluck":
			env *= exp(-k * 9.0)
		elif voice == "pulse50":
			env *= exp(-k * 14.0)
		else:
			env *= 0.75 + 0.25 * exp(-k * 8.0)
		if k > dur:
			env *= maxf(0.0, 1.0 - (k - dur) / release)
		_buf[i] += s * env * vol


func _drums(t0: float, beat: float, sparse: bool, fill: bool) -> void:
	_kick(t0, 0.6)
	_kick(t0 + beat * 2.0, 0.6)
	if not sparse:
		_kick(t0 + beat * 2.75, 0.45)
		_snare(t0 + beat, 0.4)
		_snare(t0 + beat * 3.0, 0.4)
	for s in 8:
		_noise_hit(t0 + s * beat * 0.5, 0.025, 0.06 if s % 2 == 0 else 0.04, 1.0)
	if fill:
		for s in 4:
			_snare(t0 + beat * 3.0 + s * beat * 0.25, 0.25 + s * 0.05)


func _kick(t: float, vol: float) -> void:
	var start := int(t * RATE)
	var phase := 0.0
	for i in range(start, mini(start + int(0.16 * RATE), _buf.size())):
		var k := float(i - start) / RATE
		phase += lerpf(160.0, 45.0, minf(1.0, k * 9.0)) / RATE
		_buf[i] += sin(phase * TAU) * exp(-k * 22.0) * vol


func _snare(t: float, vol: float) -> void:
	_noise_hit(t, 0.12, vol * 0.7, 0.55)
	var start := int(t * RATE)
	for i in range(start, mini(start + int(0.06 * RATE), _buf.size())):
		var k := float(i - start) / RATE
		_buf[i] += sin(k * TAU * 190.0) * exp(-k * 40.0) * vol * 0.5


## Noise burst; `bright` 1.0 = raw white noise (hats), lower = smoother (snare body).
func _noise_hit(t: float, dur: float, vol: float, bright: float) -> void:
	var start := int(t * RATE)
	var lp := 0.0
	var prev := 0.0
	for i in range(start, mini(start + int(dur * RATE), _buf.size())):
		var k := float(i - start) / RATE
		var w := _rng.randf_range(-1.0, 1.0)
		lp = lerpf(lp, w, bright)
		var hp := lp - prev * 0.7 if bright >= 0.9 else lp
		prev = lp
		_buf[i] += hp * exp(-k / dur * 4.0) * vol


func _finish(loop_start: float, length: float) -> AudioStreamWAV:
	var n := int(length * RATE)
	var peak := 0.001
	for i in n:
		peak = maxf(peak, absf(_buf[i]))
	var gain := 0.85 / peak
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, clampi(int(_buf[i] * gain * 32767.0), -32768, 32767))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop_start >= 0.0:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = int(loop_start * RATE)
		w.loop_end = n
	return w
