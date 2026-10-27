class_name Sfx
extends Node
## Sound effects, synthesised once at startup (the same recipes as the web version) and played
## through a small pool of players. Each sound is rate-limited so a battle doesn't turn to mush.

const POOL: int = 16
const POOL3D: int = 28
const GAPS: Dictionary = {
	"cannon": 0.06, "gun": 0.045, "rocket": 0.08, "boom": 0.05, "boom_big": 0.12, "zap": 0.08, "rail": 0.1,
	"flak": 0.07, "hanabi": 0.06, "splat": 0.07, "crit": 0.09, "roar": 0.5, "roar_boss": 0.8, "beam": 0.3,
	"stomp": 0.18, "crash": 0.25, "click": 0.03, "deny": 0.1, "reload": 0.2,
}

var streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _players3d: Array[AudioStreamPlayer3D] = []
var _next: int = 0
var _next3d: int = 0
var _last: Dictionary = {}
var _clock: float = 0.0
var ready_done: bool = false


func _ready() -> void:
	for i: int in range(POOL):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	for i2: int in range(POOL3D):
		var p3: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		p3.bus = "SFX"
		p3.unit_size = 140.0
		p3.max_distance = 4000.0
		p3.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p3.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		p3.max_db = 6.0
		add_child(p3)
		_players3d.append(p3)
	_render()


func _process(delta: float) -> void:
	_clock += delta


## vol is linear 0..1; pitch is randomised slightly so repeats don't sound identical.
func play(name: String, vol: float = 1.0, pitch: float = 1.0) -> void:
	if not streams.has(name) or vol <= 0.01:
		return
	var gap: float = float(GAPS.get(name, 0.0))
	if gap > 0.0 and _last.has(name) and _clock - float(_last[name]) < gap:
		return
	_last[name] = _clock
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % POOL
	p.stream = streams[name]
	p.volume_db = linear_to_db(clampf(vol, 0.0, 1.5) * 0.8)
	p.pitch_scale = pitch * randf_range(0.95, 1.05)
	p.play()


## A sound placed in the world: it pans and fades with distance from the camera.
func play_at(name: String, pos: Vector3, vol: float = 1.0, pitch: float = 1.0) -> void:
	if not streams.has(name) or vol <= 0.01:
		return
	var gap: float = float(GAPS.get(name, 0.0)) * 0.5
	var key: String = name + "@3d"
	if gap > 0.0 and _last.has(key) and _clock - float(_last[key]) < gap:
		return
	_last[key] = _clock
	var p: AudioStreamPlayer3D = _players3d[_next3d]
	_next3d = (_next3d + 1) % POOL3D
	p.stream = streams[name]
	p.global_position = pos
	p.volume_db = linear_to_db(clampf(vol, 0.0, 2.0)) + 4.0
	p.pitch_scale = pitch * randf_range(0.95, 1.05)
	p.play()


## Creates the Music, SFX and Voice buses (all into Master) so each has its own volume.
static func make_buses() -> void:
	for bus: String in ["Music", "SFX", "Voice"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var i: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")


static func set_bus_volume(bus: String, linear: float) -> void:
	var i: int = AudioServer.get_bus_index(bus)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.0001)))
		AudioServer.set_bus_mute(i, linear <= 0.001)


func _render() -> void:
	var b: PackedFloat32Array
	b = Synth.alloc(0.3)
	Synth.noise(b, 0, 0.22, 0.45, "lp", 1400, 300, 1.0)
	Synth.tone(b, 0, 0.16, 140, 40, "square", 0.18, 0.002, 900)
	streams["cannon"] = Synth.to_wav(b)
	b = Synth.alloc(0.1)
	Synth.noise(b, 0, 0.07, 0.4, "bp", 2200, 0, 1.2)
	Synth.tone(b, 0, 0.06, 260, 70, "square", 0.16, 0.001, 2000)
	streams["gun"] = Synth.to_wav(b)
	b = Synth.alloc(0.6)
	Synth.noise(b, 0, 0.52, 0.4, "bp", 500, 2600, 2.0, 0.02)
	streams["rocket"] = Synth.to_wav(b)
	for v: Array in [["boom", 1.0], ["boom_big", 2.4]]:
		var size: float = v[1]
		b = Synth.alloc(1.2 + size * 0.5)
		Synth.noise(b, 0, 0.5 + size * 0.5, 0.6, "lp", 900, 80, 0.8)
		Synth.tone(b, 0, 0.5 + size * 0.3, 90, 28, "sine", 0.55, 0.003)
		if size > 2.0:
			Synth.noise(b, 0.05, 1.4, 0.3, "lp", 400, 60, 0.6)
		streams[v[0]] = Synth.to_wav(b)
	b = Synth.alloc(0.35)
	for i: int in range(5):
		Synth.tone(b, i * 0.025, 0.05, randf_range(500, 2400), randf_range(200, 900), "square", 0.1, 0.001, 4000)
	Synth.noise(b, 0, 0.2, 0.25, "hp", 3000)
	streams["zap"] = Synth.to_wav(b)
	b = Synth.alloc(0.7)
	Synth.tone(b, 0, 0.2, 300, 3000, "saw", 0.12, 0.01, 6000)
	Synth.noise(b, 0.15, 0.36, 0.5, "hp", 1500)
	Synth.tone(b, 0.15, 0.42, 120, 40, "sine", 0.4)
	streams["rail"] = Synth.to_wav(b)
	b = Synth.alloc(0.25)
	Synth.tone(b, 0, 0.18, 2400, 700, "sine", 0.06)
	Synth.noise(b, 0, 0.08, 0.3, "bp", 1800, 0, 1.0)
	streams["flak"] = Synth.to_wav(b)
	b = Synth.alloc(0.6)
	Synth.noise(b, 0, 0.25, 0.4, "lp", 2500, 0, 0.7)
	for i: int in range(7):
		Synth.noise(b, 0.08 + randf() * 0.4, 0.03, 0.14, "hp", 5000)
	streams["hanabi"] = Synth.to_wav(b)
	b = Synth.alloc(0.22)
	Synth.noise(b, 0, 0.16, 0.42, "lp", 700, 150, 3.0)
	Synth.tone(b, 0, 0.12, 180, 50, "sine", 0.28)
	streams["splat"] = Synth.to_wav(b)
	b = Synth.alloc(0.22)
	Synth.tone(b, 0, 0.12, 1400, 1400, "tri", 0.16)
	Synth.tone(b, 0.04, 0.14, 2100, 2100, "tri", 0.12)
	streams["crit"] = Synth.to_wav(b)
	for v2: Array in [["roar", 1.0], ["roar_boss", 0.6]]:
		streams[v2[0]] = Synth.to_wav(_roar(float(v2[1])))
	b = Synth.alloc(1.3)
	Synth.tone(b, 0, 1.15, 55, 40, "saw", 0.25, 0.05, 700)
	Synth.noise(b, 0, 1.1, 0.35, "bp", 400, 2500, 3.0, 0.08)
	streams["beam"] = Synth.to_wav(b)
	b = Synth.alloc(0.5)
	Synth.tone(b, 0, 0.45, 60, 22, "sine", 0.6, 0.004)
	Synth.noise(b, 0, 0.25, 0.25, "lp", 300)
	streams["stomp"] = Synth.to_wav(b)
	b = Synth.alloc(1.6)
	Synth.noise(b, 0, 1.4, 0.4, "lp", 1200, 120, 0.5, 0.01)
	for i: int in range(8):
		Synth.noise(b, randf() * 0.9, 0.06, 0.15, "bp", randf_range(800, 3000), 0, 3.0)
	streams["crash"] = Synth.to_wav(b)
	b = Synth.alloc(3.8)
	var parts: Array[float] = [1.0, 2.41, 3.93, 5.17, 6.8]
	for i: int in range(parts.size()):
		Synth.tone(b, 0, 3.5 - i * 0.5, 82.0 * parts[i], 80.0 * parts[i], "sine", 0.22 / float(i + 1), 0.004)
	Synth.noise(b, 0, 0.3, 0.2, "bp", 600, 0, 1.0)
	streams["gong"] = Synth.to_wav(b)
	b = Synth.alloc(0.07)
	Synth.tone(b, 0, 0.05, 1320, 1320, "sine", 0.1, 0.001)
	streams["click"] = Synth.to_wav(b)
	b = Synth.alloc(0.2)
	Synth.tone(b, 0, 0.16, 150, 120, "square", 0.1, 0.002, 1200)
	streams["deny"] = Synth.to_wav(b)
	b = Synth.alloc(0.9)
	var steps: Array[int] = [0, 5, 7, 12]
	for i: int in range(steps.size()):
		Synth.pluck(b, i * 0.06, Synth.midi_f(62 + steps[i]), 0.2, 0.6)
	streams["build"] = Synth.to_wav(b)
	b = Synth.alloc(0.25)
	Synth.noise(b, 0, 0.05, 0.25, "bp", 3000, 0, 4.0)
	Synth.noise(b, 0.12, 0.05, 0.25, "bp", 2200, 0, 4.0)
	streams["reload"] = Synth.to_wav(b)
	ready_done = true


func _roar(p: float) -> PackedFloat32Array:
	var b: PackedFloat32Array = Synth.alloc(2.2)
	var n: int = b.size() - 1
	var ph: Array[float] = [0.0, 0.0, 0.0]
	var lp1: float = 0.0
	var lp2: float = 0.0
	for i: int in range(n):
		var t: float = float(i) / Synth.RATE
		var f: float
		if t < 0.4:
			f = lerpf(70.0, 110.0, t / 0.4)
		else:
			f = 110.0 * pow(45.0 / 110.0, (t - 0.4) / 1.5)
		f *= p
		var s: float = 0.0
		for v: int in range(3):
			var vib: float = sin(t * TAU * (23.0 + v * 5.0)) * 18.0 * p
			ph[v] += (f * (1.0 + v * 0.013) + vib) / Synth.RATE
			ph[v] -= floorf(ph[v])
			s += ph[v] * 2.0 - 1.0
		var cut: float = (400.0 + 1100.0 * p * minf(1.0, t / 0.35)) if t < 0.35 else 1500.0 * p * pow(200.0 / (1500.0 * p), (t - 0.35) / 1.55)
		var c: float = 1.0 - exp(-TAU * cut / Synth.RATE)
		lp1 += (s - lp1) * c
		lp2 += (lp1 - lp2) * c
		var env: float = minf(1.0, t / 0.15) * exp(-maxf(0.0, t - 0.15) * 2.2)
		b[i] += lp2 * env * 0.32
	Synth.noise(b, 0, 1.6, 0.25, "bp", 600.0 * p, 200, 2.0, 0.2)
	return b
