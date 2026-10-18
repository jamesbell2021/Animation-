class_name SoundManager
extends Node
## Generates all sound effects and a looping fairground-organ tune in code
## (16-bit mono WAV buffers). Call play("name") for effects.

const MIX_RATE := 22050
const MELODY: Array[int] = [72, 74, 76, 72, 76, 77, 79, 79, 79, 81, 79, 77, 76, 72, 76, 72, 74, 76, 74, 72, 71, 72, 74, 76, 72, 69, 71, 72, 72, 74, 72, 72]
const BASS: Array[int] = [48, 55, 52, 55, 53, 57, 55, 48]
const NOTE_LENGTH := 0.25

@export var sfx_volume_db: float = -6.0
@export var music_volume_db: float = -16.0
@export var music_enabled: bool = true
@export var pool_size: int = 8

var _sounds: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer


func _ready() -> void:
	for i in range(pool_size):
		var p := AudioStreamPlayer.new()
		p.name = "Sfx%d" % i
		add_child(p)
		_pool.append(p)
	_build_sounds()
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "Music"
	_music_player.volume_db = music_volume_db
	add_child(_music_player)
	if music_enabled:
		_music_player.stream = _make_stream(float(MELODY.size()) * NOTE_LENGTH, _music_sample, true)
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


func set_music_enabled(enabled: bool) -> void:
	music_enabled = enabled
	if _music_player == null:
		return
	if enabled and not _music_player.playing:
		if _music_player.stream == null:
			_music_player.stream = _make_stream(float(MELODY.size()) * NOTE_LENGTH, _music_sample, true)
		_music_player.play()
	elif not enabled:
		_music_player.stop()


func _build_sounds() -> void:
	_sounds["jump"] = _make_stream(0.2, func(t: float) -> float: return sin(TAU * (300.0 + 1500.0 * t) * t) * _env(t, 0.2))
	_sounds["land"] = _make_stream(0.12, func(t: float) -> float: return (_noise() * 0.5 + sin(TAU * 80.0 * t) * 0.5) * _env(t, 0.12))
	_sounds["coin"] = _make_stream(0.25, func(t: float) -> float: return sin(TAU * (1200.0 if t < 0.08 else 1800.0) * t) * _env(t, 0.25) * 0.7)
	_sounds["shamrock"] = _make_stream(0.45, func(t: float) -> float: return _tone([76, 80, 83, 88], t, 0.11) * 0.7)
	_sounds["knock"] = _make_stream(0.25, func(t: float) -> float: return (_noise() * 0.6 + sin(TAU * 150.0 * t) * 0.4) * _env(t, 0.25))
	_sounds["fall"] = _make_stream(0.6, func(t: float) -> float: return sin(TAU * (600.0 - 450.0 * t / 0.6) * t) * _env(t, 0.6) * 0.6)
	_sounds["checkpoint"] = _make_stream(0.3, func(t: float) -> float: return _tone([72, 79], t, 0.15) * 0.6)
	_sounds["beep"] = _make_stream(0.15, func(t: float) -> float: return _square(440.0, t) * _env(t, 0.15) * 0.5)
	_sounds["go"] = _make_stream(0.4, func(t: float) -> float: return _square(880.0, t) * _env(t, 0.4) * 0.5)
	_sounds["finish"] = _make_stream(1.0, func(t: float) -> float: return _tone([72, 76, 79, 84, 84], t, 0.2))
	_sounds["bounce"] = _make_stream(0.2, func(t: float) -> float: return sin(TAU * (200.0 + 800.0 * t) * t) * _env(t, 0.2) * 0.6)
	_sounds["click"] = _make_stream(0.05, func(t: float) -> float: return _noise() * _env(t, 0.05) * 0.4)
	_sounds["pickup"] = _make_stream(0.36, func(t: float) -> float: return _tone([79, 83, 86, 91], t, 0.09) * 0.7)
	_sounds["whoosh"] = _make_stream(0.25, func(t: float) -> float: return _noise() * sin(PI * t / 0.25) * 0.5)
	_sounds["zap"] = _make_stream(0.3, func(t: float) -> float: return _square(90.0 + 60.0 * sin(TAU * 30.0 * t), t) * _env(t, 0.3) * 0.45)
	_sounds["splat"] = _make_stream(0.3, func(t: float) -> float: return (_noise() * 0.7 + sin(TAU * 110.0 * t) * 0.3) * _env(t, 0.3) * 0.8)
	_sounds["boom"] = _make_stream(0.7, func(t: float) -> float: return (_noise() * 0.6 + sin(TAU * (70.0 - 40.0 * t) * t) * 0.6) * _env(t, 0.7))
	_sounds["trap"] = _make_stream(0.18, func(t: float) -> float: return sin(TAU * (500.0 - 900.0 * t) * t) * _env(t, 0.18) * 0.6)


func _env(t: float, duration: float) -> float:
	var x := clampf(1.0 - t / duration, 0.0, 1.0)
	return x * x


func _noise() -> float:
	return randf() * 2.0 - 1.0


func _square(freq: float, t: float) -> float:
	return 1.0 if fmod(t * freq, 1.0) < 0.5 else -1.0


func _freq(midi_note: int) -> float:
	return 440.0 * pow(2.0, float(midi_note - 69) / 12.0)


## Plays [param notes] in sequence, each lasting [param step] seconds, with an organ-like voice.
func _tone(notes: Array, t: float, step: float) -> float:
	var index := int(t / step)
	if index >= notes.size():
		return 0.0
	var nt := fmod(t, step)
	var f := _freq(int(notes[index]))
	var env := minf(nt / 0.01, 1.0) * clampf(1.0 - nt / step, 0.0, 1.0)
	return (sin(TAU * f * nt) + 0.4 * sin(TAU * 2.0 * f * nt) + 0.2 * sin(TAU * 3.0 * f * nt)) * env * 0.6


func _music_sample(t: float) -> float:
	var i := int(t / NOTE_LENGTH) % MELODY.size()
	var nt := fmod(t, NOTE_LENGTH)
	var f := _freq(MELODY[i])
	var env := minf(nt / 0.015, 1.0) * clampf(1.0 - nt / NOTE_LENGTH, 0.0, 1.0)
	var melody := (sin(TAU * f * nt) + 0.5 * sin(TAU * 2.0 * f * nt) + 0.25 * sin(TAU * 3.0 * f * nt)) * env
	var bass_len := NOTE_LENGTH * float(MELODY.size()) / float(BASS.size())
	var bi := int(t / bass_len) % BASS.size()
	var bt := fmod(t, bass_len)
	var bf := _freq(BASS[bi])
	var bass := sin(TAU * bf * bt) * clampf(1.0 - bt / bass_len, 0.0, 1.0) * 0.8
	var beat := fmod(t, NOTE_LENGTH * 2.0)
	var tick := sin(TAU * 1500.0 * beat) * _env(beat, 0.03) * 0.3
	return (melody * 0.45 + bass * 0.4 + tick) * 0.7


func _make_stream(duration: float, generator: Callable, loop: bool = false) -> AudioStreamWAV:
	var frames := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var t := float(i) / float(MIX_RATE)
		var v: float = clampf(float(generator.call(t)), -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32767.0))
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
