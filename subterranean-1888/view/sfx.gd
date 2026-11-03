extends Node
## Every sound, synthesised once at start-up (no audio files), and a small pool of players.
## Sfx.play("shot") from anywhere; Sfx.ambience(true) for the cavern's drone.

const RATE := 22050
const POOL := 14

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _ambience: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 1888
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_ambience = AudioStreamPlayer.new()
	_ambience.volume_db = -14.0
	add_child(_ambience)
	_build()


func play(id: String, volume_db := 0.0, pitch_spread := 0.08) -> void:
	var s: AudioStreamWAV = _streams.get(id)
	if s == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % POOL
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + _rng.randf_range(-pitch_spread, pitch_spread)
	p.play()


func ambience(on: bool) -> void:
	if on and not _ambience.playing:
		_ambience.stream = _streams["drone"]
		_ambience.play()
	elif not on:
		_ambience.stop()


# --- synthesis -----------------------------------------------------------------------------

func _build() -> void:
	_streams["shot"] = _wav(_render(0.32, _shot))
	_streams["gatling"] = _wav(_render(0.14, _gatling))
	_streams["dart"] = _wav(_render(0.22, _dart))
	_streams["drill"] = _wav(_render(0.55, _drill))
	_streams["bite"] = _wav(_render(0.22, _bite))
	_streams["hit"] = _wav(_render(0.12, _hit))
	_streams["hiss"] = _wav(_render(0.7, _hiss))
	_streams["step"] = _wav(_render(0.09, _step))
	_streams["chitter"] = _wav(_render(0.4, _chitter))
	_streams["blast"] = _wav(_render(1.3, _blast))
	_streams["flare"] = _wav(_render(0.8, _flare))
	_streams["clank"] = _wav(_render(0.45, _clank))
	_streams["click"] = _wav(_render(0.05, _click))
	_streams["deny"] = _wav(_render(0.18, _deny))
	_streams["bell"] = _wav(_render(1.2, _bell))
	_streams["ping"] = _wav(_render(0.6, _ping))
	_streams["death"] = _wav(_render(0.6, _death))
	var drone := _wav(_render(6.0, _drone))
	drone.loop_mode = AudioStreamWAV.LOOP_FORWARD
	drone.loop_end = int(6.0 * RATE)
	_streams["drone"] = drone


func _render(seconds: float, f: Callable) -> PackedFloat32Array:
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var state := {"lp": 0.0, "lp2": 0.0, "ph": 0.0}
	for i in n:
		out[i] = f.call(float(i) / RATE, seconds, state)
	return out


func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


func _noise() -> float:
	return _rng.randf_range(-1.0, 1.0)


func _lp(state: Dictionary, x: float, k: float, key := "lp") -> float:
	state[key] = state[key] + (x - state[key]) * k
	return state[key]


func _shot(t: float, _len: float, s: Dictionary) -> float:
	var env := exp(-t * 18.0)
	var crack := _noise() * exp(-t * 60.0)
	var boom := sin(TAU * (90.0 - t * 120.0) * t) * env
	return (_lp(s, _noise(), 0.35) * env * 0.8 + crack * 0.5 + boom * 0.7) * 0.8


func _gatling(t: float, _len: float, s: Dictionary) -> float:
	var env := exp(-t * 34.0)
	return (_lp(s, _noise(), 0.4) * env + sin(TAU * 140.0 * t) * env * 0.5) * 0.7


func _dart(t: float, _len: float, s: Dictionary) -> float:
	var env := exp(-t * 14.0)
	return _lp(s, _noise(), 0.12) * env * 0.9 + sin(TAU * 900.0 * t) * exp(-t * 40.0) * 0.15


func _drill(t: float, len: float, s: Dictionary) -> float:
	var env := minf(1.0, t * 30.0) * minf(1.0, (len - t) * 8.0)
	var buzz := signf(sin(TAU * (75.0 + 10.0 * sin(TAU * 9.0 * t)) * t))
	return (_lp(s, buzz, 0.2) * 0.5 + _lp(s, _noise(), 0.5, "lp2") * 0.3) * env * 0.7


func _bite(t: float, _len: float, s: Dictionary) -> float:
	var env := exp(-t * 22.0)
	var snap := _noise() * exp(-t * 90.0)
	return (snap * 0.7 + _lp(s, _noise(), 0.25) * env * 0.6 + sin(TAU * 180.0 * t) * env * 0.3) * 0.8


func _hit(t: float, _len: float, s: Dictionary) -> float:
	return _lp(s, _noise(), 0.3) * exp(-t * 40.0) * 0.8


func _hiss(t: float, len: float, s: Dictionary) -> float:
	var env := minf(1.0, t * 20.0) * exp(-t * 3.5)
	var hp := _noise() - _lp(s, _noise(), 0.1)
	return hp * env * 0.35


func _step(t: float, _len: float, s: Dictionary) -> float:
	return _lp(s, _noise(), 0.08) * exp(-t * 50.0) * 1.2


func _chitter(t: float, _len: float, _s: Dictionary) -> float:
	var clicks := maxf(0.0, sin(TAU * 38.0 * t)) ** 12.0
	var tone := sin(TAU * (1900.0 + 600.0 * sin(TAU * 7.0 * t)) * t)
	return clicks * tone * exp(-t * 3.0) * 0.45


func _blast(t: float, _len: float, s: Dictionary) -> float:
	var env := exp(-t * 3.2)
	var rumble := _lp(s, _noise(), 0.03) * 3.0
	var crack := _noise() * exp(-t * 25.0)
	return clampf((rumble * env + crack * 0.6) * 0.9, -1.0, 1.0)


func _flare(t: float, len: float, s: Dictionary) -> float:
	var env := minf(1.0, t * 8.0) * minf(1.0, (len - t) * 3.0)
	var fizz := _noise() - _lp(s, _noise(), 0.2)
	var pop := sin(TAU * 260.0 * t) * exp(-t * 30.0)
	return (fizz * 0.3 * env + pop * 0.4)


func _clank(t: float, _len: float, _s: Dictionary) -> float:
	var env := exp(-t * 9.0)
	return (sin(TAU * 220.0 * t) * 0.5 + sin(TAU * 563.0 * t) * 0.35 + sin(TAU * 1187.0 * t) * 0.2) * env * 0.6 \
		+ _noise() * exp(-t * 80.0) * 0.4


func _click(t: float, _len: float, _s: Dictionary) -> float:
	return sin(TAU * 1600.0 * t) * exp(-t * 120.0) * 0.4


func _deny(t: float, _len: float, _s: Dictionary) -> float:
	return signf(sin(TAU * 110.0 * t)) * exp(-t * 14.0) * 0.18


func _bell(t: float, _len: float, _s: Dictionary) -> float:
	var env := exp(-t * 2.8)
	return (sin(TAU * 523.0 * t) * 0.5 + sin(TAU * 1310.0 * t) * 0.25 + sin(TAU * 2093.0 * t) * 0.12) * env * 0.5


func _ping(t: float, _len: float, _s: Dictionary) -> float:
	return sin(TAU * (700.0 - t * 200.0) * t) * exp(-t * 6.0) * 0.35


func _death(t: float, _len: float, s: Dictionary) -> float:
	var env := exp(-t * 5.0)
	return (_lp(s, _noise(), 0.1) * 0.8 + sin(TAU * (160.0 - t * 150.0) * t) * 0.5) * env * 0.7


func _drone(t: float, len: float, s: Dictionary) -> float:
	# Low cavern hum: two slow-beating sines, breath of filtered noise, the odd far drip.
	# Every frequency is a whole number of cycles in the loop, so it loops without a click.
	var hum := sin(TAU * 41.0 * t) * 0.35 + sin(TAU * 41.5 * t) * 0.3 + sin(TAU * 62.0 * t) * 0.12
	var breath := _lp(s, _noise(), 0.01) * (0.6 + 0.4 * sin(TAU * t / len))
	var drip := 0.0
	for at in [1.3, 3.9, 5.1]:
		var d: float = t - at
		if d >= 0.0 and d < 0.25:
			drip += sin(TAU * (1500.0 - d * 2500.0) * d) * exp(-d * 30.0) * 0.25
	return (hum * 0.5 + breath * 2.0 + drip) * 0.6
