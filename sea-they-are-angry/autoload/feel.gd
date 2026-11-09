extends Node
## How the game feels to hit and be hit: the camera shakes with what happens (trauma that
## decays, the shake its square, so small knocks barely stir it and big ones rattle), and
## a heavy blow freezes the world for a few frames (hit-stop) so it lands.
## Shake can be turned off in Settings. Hit-stop is local play only: on the LAN the
## host's clock is everyone's. Neither runs headless, so tests stay frame-exact.

## Most the camera moves at full trauma, in metres of lens shift, and how fast it settles.
const MAX_SHIFT := 0.55
const MAX_ROLL := 0.022
const DECAY := 1.7
## How far from the nearest keeper an event still shakes the screen, at full and none.
const NEAR := 6.0
const FAR := 26.0

var trauma := 0.0
## Tests turn it on headless.
var force_live := false
var _t := 0.0
var _stop_left := 0.0
var _scale_before := 1.0
var _cams: Array[Camera3D] = []

func _ready() -> void:
	# After the camera director has placed the cameras for the frame.
	process_priority = 1000
	process_mode = Node.PROCESS_MODE_ALWAYS

func live() -> bool:
	return force_live or DisplayServer.get_name() != "headless"

## Shake the screen by `amount` (0..1). Given a place, it fades with the distance to the
## nearest keeper a person plays.
func shake(amount: float, at: Vector3 = Vector3.INF) -> void:
	if not Settings.shake or not live():
		return
	amount *= float(Settings.SHAKE_SCALE[Settings.shake_level])
	if at != Vector3.INF:
		var best := INF
		for k in get_tree().get_nodes_in_group("player"):
			if k is Player and not k.ai and not k.remote:
				best = minf(best, Geo.flat_dist(k.global_position, at))
		if best == INF:
			return
		amount *= 1.0 - smoothstep(NEAR, FAR, best)
	trauma = minf(1.0, trauma + amount)

## Freeze the world for `seconds` of real time (a blow landing).
func hitstop(seconds: float) -> void:
	if not live() or Net.online() or seconds <= 0.0 or not Settings.hitstop:
		return
	if _stop_left <= 0.0:
		_scale_before = Engine.time_scale
		Engine.time_scale = _scale_before * 0.04
	_stop_left = maxf(_stop_left, seconds)

## A keeper's blow on a creature: harder if it kills.
func blow(killed: bool, heavy: bool = false) -> void:
	hitstop(0.075 if killed else (0.05 if heavy else 0.035))
	shake(0.22 if killed else (0.16 if heavy else 0.08))

## The cameras the director draws through (it registers them).
func use_cameras(cams: Array) -> void:
	_cams.clear()
	for c in cams:
		if c is Camera3D:
			_cams.append(c)

func _process(_delta: float) -> void:
	# Real time: the shake and the hit-stop run through a hit-stop.
	var dt := 1.0 / maxf(1.0, Engine.get_frames_per_second()) if Engine.time_scale < 0.5 else _delta / maxf(Engine.time_scale, 0.001)
	dt = clampf(dt, 0.0, 0.1)
	if _stop_left > 0.0:
		_stop_left -= dt
		if _stop_left <= 0.0:
			Engine.time_scale = _scale_before
	_t += dt
	trauma = maxf(0.0, trauma - DECAY * dt)
	var s := trauma * trauma
	for c in _cams:
		if not is_instance_valid(c):
			continue
		c.h_offset = s * MAX_SHIFT * _wave(1.0)
		c.v_offset = s * MAX_SHIFT * _wave(2.7)
		c.rotation.z = s * MAX_ROLL * _wave(5.1)

# A smooth wobble, different on each axis.
func _wave(seed: float) -> float:
	return sin(_t * 31.0 + seed) * 0.6 + sin(_t * 47.0 + seed * 2.3) * 0.4
