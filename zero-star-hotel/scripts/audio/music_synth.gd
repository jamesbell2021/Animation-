class_name MusicSynth
extends RefCounted
## Procedural Mediterranean beach music: Spanish-rumba guitar strums (Karplus-Strong plucked
## strings) over the Andalusian cadence Am-G-F-E, a bass, cajón and claps. Each note is
## rendered once and then mixed in, so a 16-bar loop costs very little. render_step() does a
## slice per call so the browser and phones never freeze while it builds.
##
## Tracks: "day" (relaxed poolside, 112 BPM) and "night" (club night, 128 BPM, four on the floor).

const RATE := 22050

var track := "day"
var done := false
var stream: AudioStreamWAV

var _buf := PackedFloat32Array()
var _events: Array = []        # [start_sample, note_buffer_key, gain]
var _notes := {}               # key -> PackedFloat32Array, built lazily while rendering
var _specs := {}               # key -> how to build that note
var _cursor := 0
var _rng := RandomNumberGenerator.new()


func _init(which := "day") -> void:
	track = which
	_compose()


## Mixes notes until roughly budget samples have been added. Returns true when ready.
func render_step(budget := 50000) -> bool:
	if done:
		return true
	var mixed := 0
	while _cursor < _events.size() and mixed < budget:
		var ev: Array = _events[_cursor]
		if not _notes.has(ev[1]):
			_notes[ev[1]] = _build_note(_specs[ev[1]])
			mixed += _notes[ev[1]].size()
		var src: PackedFloat32Array = _notes[ev[1]]
		var start: int = ev[0]
		var gain: float = ev[2]
		var n := mini(src.size(), _buf.size() - start)
		for i in n:
			_buf[start + i] += src[i] * gain
		mixed += n
		_cursor += 1
	if _cursor >= _events.size():
		_finish()
	return done


func render_all() -> AudioStreamWAV:
	while not render_step(10000000):
		pass
	return stream


func _compose() -> void:
	_rng.seed = 1234 if track == "day" else 5678
	var bpm := 112.0 if track == "day" else 128.0
	var beat := 60.0 / bpm
	var bars := 16 if track == "day" else 8
	var total := beat * 4.0 * bars
	_buf.resize(int(total * RATE) + RATE)  # 1 s tail, folded back in _finish
	# Andalusian cadence, with a C major lift in the second half for the beach track.
	var chords := [[57, 60, 64], [55, 59, 62], [53, 57, 60], [52, 56, 59]]  # Am G F E
	var lift := [[48, 52, 55], [55, 59, 62], [53, 57, 60], [52, 56, 59]]    # C G F E
	var strum := [1, 0, 1, 1, 0, 1, 1, 0] if track == "day" else [1, 1, 1, 0, 1, 1, 1, 1]
	for bar in bars:
		var prog: Array = lift if (track == "day" and bar >= 8 and bar < 12) else chords
		var chord: Array = prog[bar % 4]
		var bar_t := bar * beat * 4.0
		# Guitar strums on eighth notes, alternating down/up.
		for k in 8:
			if strum[k] == 0:
				continue
			var t: float = bar_t + k * beat * 0.5
			var down := k % 2 == 0
			var notes: Array = chord.duplicate()
			notes.append(int(chord[0]) + 12)
			if not down:
				notes.reverse()
			for j in notes.size():
				var midi: int = notes[j]
				_add(t + j * 0.012, "g%d" % midi, 0.16 if down else 0.11, midi, 0.6, 0.994)
		# Bass on beats 1 and 3, a passing note on 4.
		var root: int = int(chord[0]) - 12
		_add(bar_t, "b%d" % root, 0.5, root, 0.9, 0.998)
		_add(bar_t + beat * 2.0, "b%d" % (root + 7), 0.4, root + 7, 0.8, 0.998)
		_add(bar_t + beat * 3.0, "b%d" % root, 0.3, root, 0.6, 0.998)
		# Cajón: low on 1 and the "and" of 2, slap on 2 and 4. Claps on the off-beats.
		_drum(bar_t, "kick", 0.5)
		_drum(bar_t + beat * 1.5, "kick", 0.35)
		_drum(bar_t + beat, "slap", 0.35)
		_drum(bar_t + beat * 3.0, "slap", 0.35)
		if track == "night":
			# Club night: four on the floor and an off-beat open hat.
			for k in 4:
				_drum(bar_t + k * beat, "kick", 0.6)
				_drum(bar_t + (k + 0.5) * beat, "clap", 0.1)
		if track == "night" or bar % 2 == 1:
			for k: int in [1, 3]:
				_drum(bar_t + beat * (k + 0.5), "clap", 0.18)
		# A whistled melody over the top on the beach track, every other bar.
		if track == "day" and bar % 2 == 0 and bar > 1:
			var scale := [69, 71, 72, 74, 76, 77, 79]
			for k in 4:
				if _rng.randf() < 0.75:
					var note: int = scale[_rng.randi() % scale.size()]
					_add(bar_t + k * beat, "m%d" % note, 0.09, note, 0.5, 0.0, true)


func _add(t: float, key: String, gain: float, midi: int, length: float, damping: float, sine := false) -> void:
	_specs[key] = ["sine" if sine else "pluck", midi, length, damping]
	_events.append([int(t * RATE), key, gain])


func _drum(t: float, kind: String, gain: float) -> void:
	_specs[kind] = ["drum", kind]
	_events.append([int(t * RATE), kind, gain])


func _build_note(spec: Array) -> PackedFloat32Array:
	match spec[0]:
		"sine": return _sine(spec[1], spec[2])
		"pluck": return _pluck(spec[1], spec[2], spec[3])
	return _make_drum(spec[1])


## Karplus-Strong plucked string.
func _pluck(midi: int, length: float, damping: float) -> PackedFloat32Array:
	var f := 440.0 * pow(2.0, (midi - 69) / 12.0)
	var period := maxi(int(RATE / f), 2)
	var ring := PackedFloat32Array()
	ring.resize(period)
	var rng := RandomNumberGenerator.new()
	rng.seed = midi * 31
	for i in period:
		ring[i] = rng.randf_range(-1, 1)
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var idx := 0
	for i in n:
		var a := ring[idx]
		var b := ring[(idx + 1) % period]
		ring[idx] = (a + b) * 0.5 * damping
		out[i] = a
		idx = (idx + 1) % period
	return out


func _sine(midi: int, length: float) -> PackedFloat32Array:
	var f := 440.0 * pow(2.0, (midi - 69) / 12.0)
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var vib := 1.0 + 0.006 * sin(t * TAU * 5.5) * minf(t * 4.0, 1.0)
		out[i] = sin(t * f * vib * TAU) * minf(t / 0.03, 1.0) * clampf(1.0 - t / length, 0.0, 1.0)
	return out


func _make_drum(kind: String) -> PackedFloat32Array:
	var length := 0.25
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = kind.hash()
	var phase := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		match kind:
			"kick":
				phase += lerpf(140.0, 60.0, minf(t * 10.0, 1.0)) / RATE
				out[i] = sin(phase * TAU) * exp(-t * 16.0)
			"slap":
				lp = lerpf(lp, rng.randf_range(-1, 1), 0.5)
				out[i] = (lp * exp(-t * 35.0) + sin(t * 240.0 * TAU) * exp(-t * 25.0) * 0.5)
			_:
				var burst := exp(-fmod(t, 0.012) * 300.0) if t < 0.03 else 0.0
				out[i] = rng.randf_range(-1, 1) * (exp(-t * 28.0) * 0.6 + burst * 0.4)
	return out


func _finish() -> void:
	# Fold the tail back onto the start so the loop is seamless, then normalise.
	var loop_n := _buf.size() - RATE
	for i in RATE:
		_buf[i] += _buf[loop_n + i]
	var peak := 0.001
	for i in loop_n:
		peak = maxf(peak, absf(_buf[i]))
	var data := PackedByteArray()
	data.resize(loop_n * 2)
	var g := 0.85 / peak
	for i in loop_n:
		data.encode_s16(i * 2, clampi(int(_buf[i] * g * 32767.0), -32768, 32767))
	stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = loop_n
	_buf = PackedFloat32Array()
	_notes.clear()
	done = true
