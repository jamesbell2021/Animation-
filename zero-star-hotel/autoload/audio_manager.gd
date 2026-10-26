extends Node
## Autoload: all sound. Sound effects, the catchphrase voice and the music are synthesised at
## startup (a little each frame, so nothing freezes), which keeps the download tiny. To use
## real recordings instead, drop OGG files at the paths in VOICE_LINES / res://audio/sfx/ /
## res://audio/music/ and they're picked up automatically.
##
## Voice pitch: each speaker passes their own pitch (the player's comes from the Character
## Creator's Voice Pitch slider), applied with pitch_scale, so one recording serves everyone.

signal ready_to_play

const BUSES := ["Music", "SFX", "Voice"]
const SFX_PLAYERS := 8
const VOICE_PLAYERS := 4

## Catchphrase id -> [syllables for VoiceSynth, optional recording path].
const VOICE_LINES := {
	"oi_oi": ["o-y-Q-o-y", "res://audio/voice/oi_oi.ogg"],
	"ere_we_go": ["e-re-wi-go-Q-e-re-wi-go", "res://audio/voice/ere_we_go.ogg"],
	"cheers": ["chi-ers", "res://audio/voice/cheers.ogg"],
	"woo": ["wu-u-u", "res://audio/voice/woo.ogg"],
	"oi": ["o-y", "res://audio/voice/oi.ogg"],
	"housekeeping": ["hau-s-ki-pi-ng", "res://audio/voice/housekeeping.ogg"],
}

var sfx := {}
var voices := {}
var music := {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _voice_players: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
var _jobs: Array[Callable] = []
var _music_renders := {}       # track -> MusicSynth in progress
var _wanted_music := ""
var _last_voice_time := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for b in BUSES:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, b)
			AudioServer.set_bus_send(idx, "Master")
	for i in SFX_PLAYERS:
		_sfx_players.append(_make_player("SFX"))
	for i in VOICE_PLAYERS:
		_voice_players.append(_make_player("Voice"))
	_music_player = _make_player("Music")
	# Queue the synthesis work: SFX first (small), then voices, then music.
	_jobs.append(_build_sfx)
	for id in VOICE_LINES:
		_jobs.append(_build_voice.bind(id))
	_jobs.append(_queue_music.bind("day"))
	_jobs.append(func(): ready_to_play.emit())


func _make_player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


func _process(_delta: float) -> void:
	if not _jobs.is_empty():
		var job: Callable = _jobs.pop_front()
		job.call()
	for track in _music_renders.keys():
		var r: MusicSynth = _music_renders[track]
		if r.render_step():
			music[track] = r.stream
			_music_renders.erase(track)
			if _wanted_music == track and not _music_player.playing:
				_start_music(track)


func _build_sfx() -> void:
	sfx = SfxSynth.build()
	for name in sfx.keys():
		var path := "res://audio/sfx/%s.ogg" % name
		if ResourceLoader.exists(path):
			sfx[name] = load(path)


func _build_voice(id: String) -> void:
	var path: String = VOICE_LINES[id][1]
	if ResourceLoader.exists(path):
		voices[id] = load(path)
	else:
		voices[id] = VoiceSynth.say(VOICE_LINES[id][0], 150.0)


func _queue_music(track: String) -> void:
	var path := "res://audio/music/%s.ogg" % track
	if ResourceLoader.exists(path):
		var s: AudioStream = load(path)
		if s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = true
		music[track] = s
		return
	if not music.has(track) and not _music_renders.has(track):
		_music_renders[track] = MusicSynth.new(track)


# --- Playback ---------------------------------------------------------------------------------

func play_sfx(name: String, pitch_jitter := 0.06, volume_db := 0.0) -> void:
	if not sfx.has(name):
		return
	var p := _free_player(_sfx_players)
	p.stream = sfx[name]
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.volume_db = volume_db
	p.play()


## Speak a catchphrase. pitch < 0 uses the player's Voice Pitch from the Character Creator.
## speaker_id rate-limits each speaker so crowds don't become a wall of noise.
func say(line_id: String, pitch := -1.0, speaker_id := "manager", volume_db := 0.0) -> void:
	if not voices.has(line_id):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_voice_time.get(speaker_id, -10000)) < 700:
		return
	_last_voice_time[speaker_id] = now
	if pitch < 0.0:
		pitch = CharacterData.voice_pitch()
	var p := _free_player(_voice_players)
	p.stream = voices[line_id]
	p.pitch_scale = clampf(pitch, 0.4, 2.2)
	p.volume_db = volume_db
	p.play()


func play_music(track: String) -> void:
	if _wanted_music == track and _music_player.playing:
		return
	_wanted_music = track
	if music.has(track):
		_start_music(track)
	else:
		_queue_music(track)


func stop_music() -> void:
	_wanted_music = ""
	_music_player.stop()


func _start_music(track: String) -> void:
	_music_player.stream = music[track]
	_music_player.volume_db = -80.0
	_music_player.play()
	var tw := create_tween()
	tw.tween_property(_music_player, "volume_db", -6.0, 1.2)


func _free_player(pool: Array[AudioStreamPlayer]) -> AudioStreamPlayer:
	for p in pool:
		if not p.playing:
			return p
	return pool[0]


func set_volumes(music_v: float, sfx_v: float, voice_v: float) -> void:
	_set_bus("Music", music_v)
	_set_bus("SFX", sfx_v)
	_set_bus("Voice", voice_v)


func _set_bus(bus: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, v <= 0.01)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.01)))
