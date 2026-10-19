class_name SoundManager
extends Node
## All audio is synthesised in code (no files). Sound effects are built once per
## session; music tracks are built on a worker thread so loading doesn't stall:
## "race" (142 BPM fairground hard dance) and "derby" (150 BPM hardstyle).
## play() is for UI/player sounds; play_at() is positional (louder when close).
## Anything in the game can call SoundManager.world(node, "name", pos).

const MIX_RATE := 22050
const BPM := 142.0
const BARS := 16
const DERBY_BPM := 150.0

@export var sfx_volume_db: float = -4.0
@export var music_volume_db: float = -8.0
@export var music_enabled: bool = true
## Which music track plays: "race" or "derby".
@export var music_track: String = "race"
@export var pool_size: int = 10
@export var world_pool_size: int = 16

static var _sounds: Dictionary = {}
static var _tracks: Dictionary = {}
static var _track_tasks: Dictionary = {}
static var _track_mutex := Mutex.new()
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


func _exit_tree() -> void:
	# Worker tasks must be waited on (and must not outlive the script when quitting).
	for track in _track_tasks.keys():
		var task: int = _track_tasks[track]
		if task >= 0:
			WorkerThreadPool.wait_for_task_completion(task)
			_track_tasks[track] = -1


func _process(_delta: float) -> void:
	if music_enabled and _music_player.stream == null:
		var music := _track(music_track)
		if music != null:
			_music_player.stream = music
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


## Seconds into the music loop, or -1 if it isn't playing (for beat-synced visuals).
func music_position() -> float:
	if _music_player == null or not _music_player.playing:
		return -1.0
	return _music_player.get_playback_position()


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
	var music := _track(music_track)
	if music != null:
		_music_player.stream = music
		if not _music_player.playing:
			_music_player.play()
	elif not _track_tasks.has(music_track):
		_track_tasks[music_track] = WorkerThreadPool.add_task(_build_track_threaded.bind(music_track))


## Beats per minute of the track this manager plays.
func track_bpm() -> float:
	return DERBY_BPM if music_track == "derby" else BPM


static func _track(track: String) -> AudioStreamWAV:
	_track_mutex.lock()
	var music: AudioStreamWAV = _tracks.get(track)
	_track_mutex.unlock()
	return music


static func _build_track_threaded(track: String) -> void:
	var music := _build_hardstyle() if track == "derby" else _build_disco()
	_track_mutex.lock()
	_tracks[track] = music
	_track_mutex.unlock()


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
	s["whistle"] = _make(1.0, func(t: float) -> float: return (sin(TAU * (500.0 + 900.0 * t) * t) * 0.35 + _n(t) * 0.12) * minf(t * 10.0, 1.0) * clampf((1.0 - t) * 6.0, 0.0, 1.0))
	s["crackle"] = _make(1.2, func(t: float) -> float: return _n(t) * (1.0 if fmod(t * 41.0 + sin(t * 97.0) * 3.0, 1.0) < 0.14 else 0.0) * _env(t, 1.2) * 0.9)
	s["drumroll"] = _make(1.9, func(t: float) -> float: return _n(t) * (0.45 + 0.55 * absf(sin(TAU * 15.0 * t))) * minf(0.25 + t / 1.6, 1.0) * 0.6)
	s["tada"] = _make(1.6, func(t: float) -> float: return _clip(_arp([72, 72, 72, 79], t, 0.11) * 0.5 + (_sq(523.0, t) + _sq(659.0, t) + _sq(784.0, t)) * 0.13 * (1.0 if t > 0.33 else 0.0) * _env(t - 0.33, 1.27)))
	s["airhorn"] = _make(1.1, func(t: float) -> float: return _horn_sample(fmod(t, 0.22) if t < 0.44 else t - 0.44, 0.2 if t < 0.44 else 0.66) * 0.8)
	s["paintgun"] = _make(0.16, func(t: float) -> float: return (_n(t) * 0.7 * _env(t, 0.06) + sin(TAU * (260.0 - 900.0 * t) * t) * 0.6 * _env(t, 0.16)) * 0.8)
	s["slash"] = _make(0.32, func(t: float) -> float: return ((_n(t) - _n(t - 0.0004)) * 0.6 + sin(TAU * (300.0 - 600.0 * t) * t) * 0.3) * sin(PI * t / 0.32))
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

## 16 bars of fairground hard dance at 142 BPM, Am - F - C - G:
## bars 1-4 pounding kick, rolling off-beat bass and a plucked arp; bars 5-8 add the
## supersaw hook; bars 9-12 an air horn and a hoover lead; bars 13-16 everything at
## once with a snare roll into the loop.
static func _build_disco() -> AudioStreamWAV:
	_ensure_noise()
	var beat := 60.0 / BPM
	var bar := beat * 4.0
	var frames := int(bar * BARS * MIX_RATE)
	var buf := PackedFloat32Array()
	buf.resize(frames)
	var saw := _saw_table()
	var roots: Array[int] = [45, 41, 48, 43]
	var arp: Array = [[69, 72, 76, 72, 81, 76, 72, 76], [65, 69, 72, 69, 77, 72, 69, 72],
		[67, 72, 76, 72, 79, 76, 72, 76], [67, 71, 74, 71, 79, 74, 71, 74]]
	var hook: Array = [[76, 76, 79, 76, 81, 79, 76, 74], [77, 77, 81, 77, 84, 81, 77, 76],
		[79, 79, 84, 79, 88, 84, 79, 76], [79, 79, 83, 79, 86, 83, 79, 74]]
	var hoover: Array[int] = [57, 53, 60, 55]
	for b in range(BARS):
		var bar_start := float(b) * bar
		var chord := b % 4
		var section := b / 4
		if b % 4 == 0:
			_crash(buf, bar_start, 0.35 if section != 1 else 0.2)
		for q in range(4):
			var t0 := bar_start + float(q) * beat
			_kick(buf, t0)
			_hat(buf, t0 + beat * 0.5, 0.09, 0.34)
			for s16: float in [0.25, 0.75]:
				_hat(buf, t0 + beat * s16, 0.025, 0.11)
			if q == 1 or q == 3:
				_clap(buf, t0)
			# Rolling bass on the off-beats (the kick owns the beat).
			_tone(buf, saw, t0 + beat * 0.5, beat * 0.42, _freq(roots[chord] - 12), 0.34, 0.003, 2)
			_tone(buf, saw, t0 + beat * 0.75, beat * 0.2, _freq(roots[chord]), 0.14, 0.003, 1)
		var notes: Array = arp[chord]
		var lead: Array = hook[chord]
		for e in range(8):
			var t_e := bar_start + float(e) * beat * 0.5
			if section != 2:
				_tone(buf, saw, t_e, beat * 0.3, _freq(int(notes[e])), 0.06 if section == 0 else 0.045, 0.002, 1)
			if section == 1 or section == 3:
				_supersaw(buf, saw, t_e, beat * 0.46, _freq(int(lead[e])), 0.05)
		if section == 2:
			if b == 8:
				_airhorn(buf, bar_start, beat * 0.4)
				_airhorn(buf, bar_start + beat * 0.5, beat * 0.4)
				_airhorn(buf, bar_start + beat * 1.0, beat * 0.9)
			for half in range(2):
				_hoover(buf, saw, bar_start + float(half) * beat * 2.0, beat * 1.9, _freq(hoover[chord]), 0.07)
		if b == BARS - 1:
			# Snare roll into the loop: 8ths, then 16ths, then 32nds.
			var step := 0.5
			var t_beats := 0.0
			while t_beats < 4.0:
				_snare(buf, bar_start + t_beats * beat, 0.16 + 0.1 * t_beats)
				step = 0.5 if t_beats < 2.0 else (0.25 if t_beats < 3.5 else 0.125)
				t_beats += step
	var peak := 0.001
	for i in range(frames):
		peak = maxf(peak, absf(buf[i]))
	var gain := 1.1 / peak
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var v := buf[i] * gain
		v = v / (1.0 + absf(v) * 0.25)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	return _wav(data, frames, true)


## Dodgem Derby: 16 bars of 150 BPM hardstyle in F minor (Fm - Db - Ab - Eb).
## Bars 1-4 distorted kicks with a reverse bass swelling into each one; 5-8 add
## a screeching lead; 9-12 a big supersaw breakdown with an air horn and a rising
## sweep while the kick keeps pounding; 13-16 everything, ending in a kick roll.
static func _build_hardstyle() -> AudioStreamWAV:
	_ensure_noise()
	var beat := 60.0 / DERBY_BPM
	var bar := beat * 4.0
	var frames := int(bar * BARS * MIX_RATE)
	var buf := PackedFloat32Array()
	buf.resize(frames)
	var saw := _saw_table()
	var roots: Array[int] = [41, 37, 44, 39]
	var chords: Array = [[65, 68, 72], [61, 65, 68], [68, 72, 75], [63, 67, 70]]
	var lead: Array = [[77, 0, 77, 80, 77, 0, 75, 72], [77, 0, 77, 80, 82, 0, 80, 77],
		[80, 0, 80, 84, 82, 0, 80, 79], [79, 0, 77, 75, 79, 0, 82, 84]]
	for b in range(BARS):
		var bar_start := float(b) * bar
		var chord := b % 4
		var section := b / 4
		if b % 4 == 0:
			_crash(buf, bar_start, 0.4)
		var kick_roll := b == BARS - 1
		for q in range(4):
			var t0 := bar_start + float(q) * beat
			_hard_kick(buf, t0, _freq(roots[chord] + 12))
			if kick_roll and q >= 2:
				_hard_kick(buf, t0 + beat * 0.5, _freq(roots[chord] + 12))
			_hat(buf, t0 + beat * 0.5, 0.08, 0.36)
			for s16: float in [0.25, 0.75]:
				_hat(buf, t0 + beat * s16, 0.02, 0.13)
			if (q == 1 or q == 3) and b >= 2:
				_clap(buf, t0)
			if section != 2:
				_reverse_bass(buf, saw, t0 + beat * 0.22, beat * 0.76, _freq(roots[chord]), 0.38)
		if section == 2:
			for n in chords[chord]:
				_supersaw(buf, saw, bar_start, bar * 0.97, _freq(int(n)), 0.035)
			if b == 8:
				_airhorn(buf, bar_start, beat * 0.35)
				_airhorn(buf, bar_start + beat * 0.5, beat * 0.35)
				_airhorn(buf, bar_start + beat, beat * 0.8)
			if b == 11:
				_sweep(buf, bar_start, bar, 0.25)
		if section == 1 or section == 3:
			var notes: Array = lead[chord]
			for e in range(8):
				var midi := int(notes[e])
				if midi > 0:
					_screech(buf, bar_start + float(e) * beat * 0.5, beat * 0.44, _freq(midi), 0.06)
		if section == 3:
			for n in chords[chord]:
				for stab: float in [0.5, 1.5, 2.5, 3.5]:
					_tone(buf, saw, bar_start + beat * stab, beat * 0.25, _freq(int(n)), 0.035, 0.002, 1)
		if kick_roll:
			_sweep(buf, bar_start, bar, 0.2)
	var peak := 0.001
	for i in range(frames):
		peak = maxf(peak, absf(buf[i]))
	var gain := 1.15 / peak
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var v := buf[i] * gain
		v = v / (1.0 + absf(v) * 0.3)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	return _wav(data, frames, true)


## Hardstyle kick: a punchy click and a long distorted tail tuned to the note.
static func _hard_kick(buf: PackedFloat32Array, start: float, tail_freq: float) -> void:
	var s0 := int(start * MIX_RATE)
	var n := int(0.22 * MIX_RATE)
	var phase := 0.0
	for i in range(n):
		var idx := s0 + i
		if idx >= buf.size():
			return
		var t := float(i) / MIX_RATE
		var f := tail_freq + 260.0 * exp(-t * 45.0)
		phase += f / MIX_RATE
		var v := sin(TAU * phase) * 5.0
		v = v / (1.0 + absf(v))
		var amp := exp(-t * 9.0)
		buf[idx] += v * amp * 1.2 + (_noise[(i * 3) % _noise.size()] * 0.45 if i < 60 else 0.0)


## Reverse bass: a distorted saw that swells up into the next kick.
static func _reverse_bass(buf: PackedFloat32Array, table: PackedFloat32Array, start: float, length: float, freq: float, amp: float) -> void:
	var s0 := int(start * MIX_RATE)
	var n := int(length * MIX_RATE)
	var step := freq / MIX_RATE * float(table.size())
	var phase := 0.0
	for i in range(n):
		var idx := s0 + i
		if idx >= buf.size():
			return
		var k := float(i) / float(n)
		var v := (table[int(phase) % table.size()] + table[int(phase * 2.0) % table.size()] * 0.5) * 3.0
		v = v / (1.0 + absf(v))
		buf[idx] += v * amp * k * k * clampf((1.0 - k) * 30.0, 0.0, 1.0)
		phase += step


## Screech lead: a detuned square that bends down into each note.
static func _screech(buf: PackedFloat32Array, start: float, length: float, freq: float, amp: float) -> void:
	var s0 := int(start * MIX_RATE)
	var n := int(length * MIX_RATE)
	var phases := [0.0, 0.0, 0.0]
	var detune := [1.0, 1.009, 0.991]
	for i in range(n):
		var idx := s0 + i
		if idx >= buf.size():
			return
		var t := float(i) / MIX_RATE
		var bend := 1.0 + 0.19 * exp(-t * 40.0) + 0.006 * sin(TAU * 6.0 * t)
		var v := 0.0
		for k in range(3):
			phases[k] = fmod(float(phases[k]) + freq * float(detune[k]) * bend / MIX_RATE, 1.0)
			v += 1.0 if float(phases[k]) < 0.42 else -1.0
		var env := minf(t / 0.004, 1.0) * clampf((length - t) / 0.03, 0.0, 1.0)
		buf[idx] += v * amp * env


## Rising white-noise sweep (builds into the next section).
static func _sweep(buf: PackedFloat32Array, start: float, length: float, amp: float) -> void:
	var s0 := int(start * MIX_RATE)
	var n := int(length * MIX_RATE)
	var prev := 0.0
	for i in range(n):
		var idx := s0 + i
		if idx >= buf.size():
			return
		var k := float(i) / float(n)
		var x := _noise[(i * 13 + 7) % _noise.size()]
		var hp := x - prev * (0.95 - 0.9 * k)
		prev = x
		buf[idx] += hp * amp * k * k


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


## Hard dance kick: a fast pitch drop with some distortion so it punches through.
static func _kick(buf: PackedFloat32Array, start: float) -> void:
	var s0 := int(start * MIX_RATE)
	var n := int(0.3 * MIX_RATE)
	var phase := 0.0
	for i in range(n):
		var idx := s0 + i
		if idx >= buf.size():
			return
		var t := float(i) / MIX_RATE
		var f := 50.0 + 190.0 * exp(-t * 30.0)
		phase += f / MIX_RATE
		var amp := exp(-t * 7.5)
		var v := sin(TAU * phase) * 2.6
		v = v / (1.0 + absf(v))
		buf[idx] += v * amp * 1.25 + (_noise[i % _noise.size()] * 0.35 if i < 80 else 0.0)


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


static func _snare(buf: PackedFloat32Array, start: float, amp: float) -> void:
	var s0 := int(start * MIX_RATE)
	var n := int(0.12 * MIX_RATE)
	for i in range(n):
		var idx := s0 + i
		if idx >= buf.size():
			return
		var t := float(i) / MIX_RATE
		buf[idx] += (_noise[(i * 5 + 99) % _noise.size()] * 0.8 + sin(TAU * 190.0 * t) * 0.5) * amp * exp(-t * 28.0)


static func _crash(buf: PackedFloat32Array, start: float, amp: float) -> void:
	var s0 := int(start * MIX_RATE)
	var n := int(1.4 * MIX_RATE)
	var prev := 0.0
	for i in range(n):
		var idx := s0 + i
		if idx >= buf.size():
			return
		var x := _noise[(i * 11 + 5) % _noise.size()]
		buf[idx] += (x - prev) * amp * exp(-float(i) / MIX_RATE * 2.8)
		prev = x


## Three detuned saws plus a sub-octave: the big trance/hard dance lead.
static func _supersaw(buf: PackedFloat32Array, table: PackedFloat32Array, start: float, length: float, freq: float, amp: float) -> void:
	for detune: float in [0.993, 1.0, 1.007]:
		_tone(buf, table, start, length, freq * detune, amp, 0.004, 1)
	_tone(buf, table, start, length, freq * 0.5, amp * 0.6, 0.004, 1)


## Rave "hoover": detuned saws that swoop down into the note.
static func _hoover(buf: PackedFloat32Array, table: PackedFloat32Array, start: float, length: float, freq: float, amp: float) -> void:
	var s0 := int(start * MIX_RATE)
	var n := int(length * MIX_RATE)
	var phases := [0.0, 0.0, 0.0, 0.0]
	var ratios := [1.0, 1.012, 0.988, 0.5]
	for i in range(n):
		var idx := s0 + i
		if idx >= buf.size():
			return
		var t := float(i) / MIX_RATE
		var glide := 1.0 + 0.12 * exp(-t * 14.0) + 0.01 * sin(TAU * 5.5 * t)
		var env := minf(t / 0.01, 1.0) * clampf((length - t) / 0.08, 0.0, 1.0)
		var v := 0.0
		for k in range(4):
			phases[k] = float(phases[k]) + freq * float(ratios[k]) * glide / MIX_RATE * float(table.size())
			v += table[int(phases[k]) % table.size()]
		buf[idx] += v * amp * env


## Rave air horn: three detuned square-ish saws with a pitch dip.
static func _airhorn(buf: PackedFloat32Array, start: float, length: float) -> void:
	var s0 := int(start * MIX_RATE)
	var n := int(length * MIX_RATE)
	for i in range(n):
		var idx := s0 + i
		if idx >= buf.size():
			return
		var t := float(i) / MIX_RATE
		buf[idx] += _horn_sample(t, length) * 0.4


static func _horn_sample(t: float, length: float) -> float:
	var f := 466.0 * (1.0 - 0.06 * minf(t / 0.05, 1.0))
	var v := 0.0
	for d: float in [1.0, 1.006, 0.994, 1.5]:
		v += 2.0 * fmod(t * f * d, 1.0) - 1.0
	var env := minf(t / 0.01, 1.0) * clampf((length - t) / 0.04, 0.0, 1.0)
	return clampf(v * 0.6, -1.0, 1.0) * env


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
