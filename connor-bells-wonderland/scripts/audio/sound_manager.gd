class_name SoundManager
extends Node
## All audio is synthesised in code (no files). Sound effects are built once per
## session; the disco loop is built on a worker thread so loading doesn't stall.
## play() is for UI/player sounds; play_at() is positional (louder when close).
## Anything in the game can call SoundManager.world(node, "name", pos).

const MIX_RATE := 22050
const BPM := 124.0
const BARS := 8

@export var sfx_volume_db: float = -4.0
@export var music_volume_db: float = -8.0
@export var music_enabled: bool = true
@export var pool_size: int = 10
@export var world_pool_size: int = 16

static var _sounds: Dictionary = {}
static var _music: AudioStreamWAV
static var _music_building: bool = false
static var _noise: PackedFloat32Array

var _pool: Array[AudioStreamPlayer] = []
var _world_pool: Array[AudioStreamPlayer3D] = []
var _world_next: int = 0
var _music_player: AudioStreamPlayer


## Positional sound from anywhere in the game (does nothing if there is no SoundManager).
static func world(anchor: Node, sound_name: String, pos: Vector3, pitch: float = 1.0, volume_offset_db: float = 0.0) -> void:
	if anchor == null or not anchor.is_inside_tree():
		return
	var manager := anchor.get_tree().get_first_node_in_group("sound_manager") as SoundManager
	if manager != null:
		manager.play_at(sound_name, pos, pitch, volume_offset_db)


func _ready() -> void:
	add_to_group("sound_manager")
	for i in range(pool_size):
		var p := AudioStreamPlayer.new()
		p.name = "Sfx%d" % i
		add_child(p)
		_pool.append(p)
	for i in range(world_pool_size):
		var p3 := AudioStreamPlayer3D.new()
		p3.name = "World%d" % i
		p3.unit_size = 7.0
		p3.max_distance = 60.0
		p3.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(p3)
		_world_pool.append(p3)
	if _sounds.is_empty():
		_build_sounds()
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "Music"
	_music_player.volume_db = music_volume_db
	add_child(_music_player)
	if music_enabled:
		_start_music()


func _process(_delta: float) -> void:
	if music_enabled and _music_player.stream == null and _music != null:
		_music_player.stream = _music
		_music_player.play()


func play(sound_name: String, pitch: float = 1.0, volume_offset_db: float = 0.0) -> void:
	if not _sounds.has(sound_name):
		push_warning("SoundManager.play: unknown sound '%s'." % sound_name)
		return
	var player: AudioStreamPlayer = _pool[0]
	for p in _pool:
		if not p.playing:
			player = p
			break
	player.stream = _sounds[sound_name]
	player.pitch_scale = pitch
	player.volume_db = sfx_volume_db + volume_offset_db
	player.play()


func play_at(sound_name: String, pos: Vector3, pitch: float = 1.0, volume_offset_db: float = 0.0) -> void:
	if not _sounds.has(sound_name):
		push_warning("SoundManager.play_at: unknown sound '%s'." % sound_name)
		return
	var player: AudioStreamPlayer3D = null
	for i in range(_world_pool.size()):
		var candidate := _world_pool[(_world_next + i) % _world_pool.size()]
		if not candidate.playing:
			player = candidate
			break
	if player == null:
		player = _world_pool[_world_next]
	_world_next = (_world_next + 1) % _world_pool.size()
	player.stream = _sounds[sound_name]
	player.pitch_scale = pitch * randf_range(0.95, 1.05)
	player.volume_db = sfx_volume_db + volume_offset_db + 4.0
	player.global_position = pos
	player.play()


func set_music_enabled(enabled: bool) -> void:
	music_enabled = enabled
	if _music_player == null:
		return
	if enabled:
		_start_music()
		if _music_player.stream != null and not _music_player.playing:
			_music_player.play()
	else:
		_music_player.stop()


func _start_music() -> void:
	if _music != null:
		_music_player.stream = _music
		if not _music_player.playing:
			_music_player.play()
	elif not _music_building:
		_music_building = true
		WorkerThreadPool.add_task(_build_music_threaded)


static func _build_music_threaded() -> void:
	_music = _build_disco()


# --- Sound effects ------------------------------------------------------------

func _build_sounds() -> void:
	_ensure_noise()
	var s := _sounds
	s["jump"] = _make(0.18, func(t: float) -> float: return _sq(180.0 + 900.0 * t, t) * 0.25 * _env(t, 0.18) + sin(TAU * (220.0 + 700.0 * t) * t) * 0.4 * _env(t, 0.18))
	s["land"] = _make(0.16, func(t: float) -> float: return (_n(t) * 0.5 + sin(TAU * 70.0 * t) * 0.8) * _env(t, 0.16))
	s["coin"] = _make(0.22, func(t: float) -> float: return (sin(TAU * (1320.0 if t < 0.06 else 1980.0) * t) + 0.3 * _sq(1980.0, t)) * _env(t, 0.22) * 0.45)
	s["shamrock"] = _make(0.42, func(t: float) -> float: return _arp([79, 83, 86, 91], t, 0.1) * 0.6)
	s["pickup"] = _make(0.45, func(t: float) -> float: return _arp([67, 74, 79, 86, 91], t, 0.08) * 0.6 + _n(t) * 0.1 * _env(t, 0.45))
	s["knock"] = _make(0.3, func(t: float) -> float: return _clip((_n(t) * 0.7 + sin(TAU * (160.0 - 200.0 * t) * t) * 0.9) * _env(t, 0.3) * 1.4))
	s["punch"] = _make(0.28, func(t: float) -> float: return _clip((_n(t) * 0.9 * _env(t, 0.05) + sin(TAU * (110.0 - 120.0 * t) * t) * 1.2 * _env(t, 0.28)) * 1.3))
	s["fall"] = _make(0.7, func(t: float) -> float: return sin(TAU * (900.0 - 750.0 * t / 0.7) * t) * _env(t, 0.7) * 0.5 + _n(t) * 0.15 * _env(t, 0.7))
	s["poof"] = _make(0.3, func(t: float) -> float: return _n(t) * sin(PI * t / 0.3) * 0.5)
	s["checkpoint"] = _make(0.35, func(t: float) -> float: return _arp([76, 83, 88], t, 0.1) * 0.6)
	s["beep"] = _make(0.16, func(t: float) -> float: return _sq(523.0, t) * _env(t, 0.16) * 0.45)
	s["go"] = _make(0.5, func(t: float) -> float: return (_sq(1046.0, t) * 0.4 + _sq(523.0, t) * 0.3) * _env(t, 0.5))
	s["finish"] = _make(1.3, func(t: float) -> float: return _arp([72, 76, 79, 84, 88, 91], t, 0.12) * 0.7 + _n(t) * 0.25 * _env(t, 1.3) * sin(PI * minf(t, 1.0)))
	s["cheer"] = _make(1.6, func(t: float) -> float: return _n(t) * sin(PI * t / 1.6) * 0.55 * (0.7 + 0.3 * sin(TAU * 7.0 * t)))
	s["bounce"] = _make(0.3, func(t: float) -> float: return sin(TAU * (150.0 + 900.0 * t) * t) * _env(t, 0.3) * 0.7)
	s["boing"] = _make(0.5, func(t: float) -> float: return sin(TAU * (120.0 + 80.0 * sin(TAU * 18.0 * t)) * t) * _env(t, 0.5) * 0.8)
	s["click"] = _make(0.05, func(t: float) -> float: return _n(t) * _env(t, 0.05) * 0.4)
	s["whoosh"] = _make(0.3, func(t: float) -> float: return _n(t) * sin(PI * t / 0.3) * 0.6)
	s["swish"] = _make(0.22, func(t: float) -> float: return (_n(t) - _n(t - 0.0005)) * sin(PI * t / 0.22) * 0.5)
	s["zap"] = _make(0.4, func(t: float) -> float: return _clip(_sq(70.0 + 50.0 * sin(TAU * 40.0 * t), t) * _env(t, 0.4) * 0.6 + _n(t) * 0.3 * _env(t, 0.4)))
	s["splat"] = _make(0.35, func(t: float) -> float: return (_n(t) * 0.8 + sin(TAU * 90.0 * t) * 0.5) * _env(t, 0.35) * 0.9)
	s["boom"] = _make(0.9, func(t: float) -> float: return _clip((_n(t) * 0.9 + sin(TAU * (60.0 - 30.0 * t) * t) * 1.2) * _env(t, 0.9) * 1.5))
	s["trap"] = _make(0.2, func(t: float) -> float: return _sq(400.0 - 600.0 * t, t) * _env(t, 0.2) * 0.4)
	s["twang"] = _make(0.5, func(t: float) -> float: return (_sq(90.0 + 40.0 * t, t) * 0.5 + sin(TAU * 180.0 * t) * 0.5) * _env(t, 0.5) * (1.0 + 0.5 * sin(TAU * 25.0 * t)))
	s["slam"] = _make(0.6, func(t: float) -> float: return _clip((_n(t) * 0.8 * _env(t, 0.12) + sin(TAU * (55.0 - 25.0 * t) * t) * 1.4 * _env(t, 0.6)) * 1.4))
	s["charge"] = _make(1.0, func(t: float) -> float: return _sq(110.0 + 330.0 * t, t) * 0.25 * minf(t * 4.0, 1.0))
	s["splash"] = _make(0.4, func(t: float) -> float: return (_n(t) - _n(t - 0.0008)) * _env(t, 0.4) * 0.8)
	s["munch"] = _make(0.4, func(t: float) -> float: return _n(t) * absf(sin(TAU * 9.0 * t)) * _env(t, 0.4) * 0.7)
	s["bloop"] = _make(0.35, func(t: float) -> float: return sin(TAU * (700.0 - 1500.0 * t) * t) * _env(t, 0.35) * 0.7)
	s["rocket"] = _make(0.9, func(t: float) -> float: return _clip((_n(t) * 0.8 + _sq(55.0, t) * 0.4) * minf(t * 8.0, 1.0) * _env(t, 0.9) * 1.3))
	s["magnet"] = _make(0.8, func(t: float) -> float: return (_sq(110.0, t) * 0.3 + sin(TAU * 220.0 * t) * 0.3) * (0.6 + 0.4 * sin(TAU * 12.0 * t)) * minf(t * 6.0, 1.0) * _env(t, 0.8))
	s["shield"] = _make(0.5, func(t: float) -> float: return (sin(TAU * 880.0 * t) + sin(TAU * 1320.0 * t) * 0.5) * _env(t, 0.5) * 0.35)
	s["shield_break"] = _make(0.4, func(t: float) -> float: return (_n(t) * 0.6 + sin(TAU * 1760.0 * t) * 0.4) * _env(t, 0.4) * 0.7)
	s["steal"] = _make(0.3, func(t: float) -> float: return _arp([88, 84, 79], t, 0.08) * 0.5)
	s["firework"] = _make(0.8, func(t: float) -> float: return _n(t) * _env(t - 0.15, 0.65) * (1.0 if t > 0.15 else 0.15) * 0.8 + sin(TAU * (1500.0 - 1200.0 * t) * t) * 0.15 * (1.0 if t < 0.15 else 0.0))


func _env(t: float, duration: float) -> float:
	var x := clampf(1.0 - t / duration, 0.0, 1.0)
	return x * x


static func _ensure_noise() -> void:
	if not _noise.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	_noise.resize(MIX_RATE)
	for i in range(MIX_RATE):
		_noise[i] = rng.randf() * 2.0 - 1.0


static func _n(t: float) -> float:
	return _noise[posmod(int(t * MIX_RATE), _noise.size())]


static func _sq(freq: float, t: float) -> float:
	return 1.0 if fmod(absf(t * freq), 1.0) < 0.5 else -1.0


static func _clip(v: float) -> float:
	return clampf(v, -1.5, 1.5) / (1.0 + absf(clampf(v, -1.5, 1.5)) * 0.6)


static func _freq(midi_note: int) -> float:
	return 440.0 * pow(2.0, float(midi_note - 69) / 12.0)


## Notes in sequence, [param step] seconds each, with a bright synth voice.
func _arp(notes: Array, t: float, step: float) -> float:
	var index := int(t / step)
	if index >= notes.size():
		index = notes.size() - 1
	var nt := t - float(index) * step
	var f := _freq(int(notes[index]))
	var env := minf(nt / 0.005, 1.0) * clampf(1.0 - nt / (step * 2.5), 0.0, 1.0)
	return (sin(TAU * f * nt) + 0.35 * _sq(f, nt)) * env


func _make(duration: float, generator: Callable) -> AudioStreamWAV:
	var frames := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var t := float(i) / float(MIX_RATE)
		var v: float = clampf(float(generator.call(t)), -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32767.0))
	return _wav(data, frames, false)


static func _wav(data: PackedByteArray, frames: int, loop: bool) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = frames
	return stream


# --- Disco loop -----------------------------------------------------------------

## 8 bars at 124 BPM: four-on-the-floor kick, offbeat open hats, 16th closed hats,
## claps on 2 and 4, octave-bouncing bass, syncopated chord stabs and (bars 5-8)
## a lead riff. Am - Am - Dm - E, twice.
static func _build_disco() -> AudioStreamWAV:
	_ensure_noise()
	var beat := 60.0 / BPM
	var bar := beat * 4.0
	var frames := int(bar * BARS * MIX_RATE)
	var buf := PackedFloat32Array()
	buf.resize(frames)
	var saw := _saw_table()
	var roots: Array[int] = [45, 45, 50, 52, 45, 45, 50, 52]
	var chords: Array = [[57, 60, 64, 67], [57, 60, 64, 67], [62, 65, 69, 72], [56, 59, 62, 64], [57, 60, 64, 67], [57, 60, 64, 67], [62, 65, 69, 72], [56, 59, 62, 64]]
	var lead: Array[int] = [76, 0, 72, 76, 79, 0, 76, 72, 77, 0, 74, 77, 81, 0, 77, 74, 76, 0, 72, 76, 79, 0, 81, 79, 80, 0, 76, 80, 83, 0, 80, 76]
	for b in range(BARS):
		var bar_start := float(b) * bar
		for q in range(4):
			var t0 := bar_start + float(q) * beat
			_kick(buf, t0)
			_hat(buf, t0 + beat * 0.5, 0.11, 0.32)
			for s16 in [0.25, 0.75]:
				_hat(buf, t0 + beat * s16, 0.03, 0.12)
			if q == 1 or q == 3:
				_clap(buf, t0)
		for e in range(8):
			var note := roots[b] + (12 if e % 2 == 1 else 0)
			_tone(buf, saw, bar_start + float(e) * beat * 0.5, beat * 0.49, _freq(note), 0.32, 0.004, 3)
		for n in chords[b]:
			_tone(buf, saw, bar_start, bar * 0.98, _freq(int(n) - 12), 0.03, 0.25, 1)
		for stab in [1.5, 2.5, 3.25]:
			for n in chords[b]:
				_tone(buf, saw, bar_start + beat * stab, beat * 0.3, _freq(int(n)), 0.07, 0.003, 1)
		if b >= 4:
			for i in range(8):
				var midi: int = lead[(b - 4) * 8 + i]
				if midi > 0:
					_tone(buf, saw, bar_start + float(i) * beat * 0.5, beat * 0.45, _freq(midi), 0.11, 0.01, 1)
	var peak := 0.001
	for i in range(frames):
		peak = maxf(peak, absf(buf[i]))
	var gain := 0.95 / peak
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var v := buf[i] * gain
		v = v / (1.0 + absf(v) * 0.15)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	return _wav(data, frames, true)


static func _saw_table() -> PackedFloat32Array:
	var table := PackedFloat32Array()
	table.resize(2048)
	for i in range(2048):
		var x := float(i) / 2048.0
		var v := 0.0
		for h in range(1, 9):
			v += sin(TAU * float(h) * x) / float(h)
		table[i] = v * 0.55
	return table


static func _kick(buf: PackedFloat32Array, start: float) -> void:
	var s0 := int(start * MIX_RATE)
	var n := int(0.24 * MIX_RATE)
	var phase := 0.0
	for i in range(n):
		var idx := s0 + i
		if idx >= buf.size():
			return
		var t := float(i) / MIX_RATE
		var f := 48.0 + 110.0 * exp(-t * 35.0)
		phase += f / MIX_RATE
		var amp := exp(-t * 11.0)
		buf[idx] += sin(TAU * phase) * amp * 0.95 + (_noise[i % _noise.size()] * 0.25 if i < 60 else 0.0)


static func _hat(buf: PackedFloat32Array, start: float, length: float, amp: float) -> void:
	var s0 := int(start * MIX_RATE)
	var n := int(length * MIX_RATE)
	var prev := 0.0
	for i in range(n):
		var idx := s0 + i
		if idx >= buf.size():
			return
		var x := _noise[(i * 7 + s0) % _noise.size()]
		buf[idx] += (x - prev) * amp * exp(-float(i) / float(n) * 4.0)
		prev = x


static func _clap(buf: PackedFloat32Array, start: float) -> void:
	var s0 := int(start * MIX_RATE)
	var n := int(0.18 * MIX_RATE)
	var prev := 0.0
	for i in range(n):
		var idx := s0 + i
		if idx >= buf.size():
			return
		var t := float(i) / MIX_RATE
		var bursts := 1.0 if (t < 0.01 or (t > 0.018 and t < 0.028) or t > 0.036) else 0.3
		var x := _noise[(i * 3 + 777) % _noise.size()]
		buf[idx] += (x - prev * 0.6) * 0.42 * bursts * exp(-t * 18.0)
		prev = x


static func _tone(buf: PackedFloat32Array, table: PackedFloat32Array, start: float, length: float, freq: float, amp: float, attack: float, octave_layers: int) -> void:
	var s0 := int(start * MIX_RATE)
	var n := int(length * MIX_RATE)
	var step := freq / MIX_RATE * float(table.size())
	var phase := 0.0
	for i in range(n):
		var idx := s0 + i
		if idx >= buf.size():
			return
		var t := float(i) / MIX_RATE
		var env := minf(t / attack, 1.0) * clampf(1.0 - t / length, 0.0, 1.0)
		var v := table[int(phase) % table.size()]
		if octave_layers > 1:
			v = v * 0.6 + sin(TAU * freq * 0.5 * t) * 0.8
		buf[idx] += v * amp * env
		phase += step
