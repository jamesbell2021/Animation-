extends Node
## How the game feels to hit and be hit: the camera shakes with what happens (trauma that
## decays, the shake its square, so small knocks barely stir it and big ones rattle), and
## a heavy blow freezes the world for a few frames (hit-stop) so it lands.
## Shake (and the kick toward a blow) can be turned down or off in Settings. Hit-stop is local play only: on the LAN the
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
var _stop_until := 0
var _last_stop_end := 0
var _kick := Vector2.ZERO
## How many stops there have been (tests read it).
var stops := 0
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

## How long a blow freezes the world (real seconds): a solid one, a heavy one (a big
## arrow, a point-blank barrel, Callum's hook), a kill, and a heavy kill. Chip hits (under
## SOLID damage) don't stop it at all, and a new stop never stacks on one under way or
## starts within GAP of the last, so a busy fight doesn't stutter.
const STOP_SOLID := 0.055
const STOP_HEAVY := 0.075
const STOP_KILL := 0.085
const STOP_HEAVY_KILL := 0.11
const SOLID := 15
const GAP := 0.12
## The world's speed during a stop.
const STOP_SCALE := 0.04
## The camera's kick toward a blow: most lens shift (m), and how fast it springs back.
const KICK_MAX := 0.22
const KICK_RETURN := 16.0

## Freeze the world for `seconds` of real time (a blow landing). Skipped headless (unless
## a test forces it), on a LAN, when Settings turns it off, and whenever something else
## has the clock off 1.0 (the playtest bots and the tour run the game fast).
func hitstop(seconds: float) -> void:
	if not live() or Net.online() or seconds <= 0.0 or not Settings.hitstop:
		return
	if stopping():
		return
	var now := Time.get_ticks_usec()
	if Engine.time_scale != 1.0 or (_last_stop_end > 0 and now < _last_stop_end + int(GAP * 1e6)):
		return
	Engine.time_scale = STOP_SCALE
	_stop_until = now + int(seconds * 1e6)
	stops += 1

## A stop is under way.
func stopping() -> bool:
	return _stop_until > 0 and Time.get_ticks_usec() < _stop_until and is_equal_approx(Engine.time_scale, STOP_SCALE)

# Ends a stop when its time is up (real time, so it can't hang), and only puts the clock
# back if nothing else has changed it meanwhile.
func _end_stop() -> void:
	if _stop_until <= 0 or Time.get_ticks_usec() < _stop_until:
		return
	if is_equal_approx(Engine.time_scale, STOP_SCALE):
		Engine.time_scale = 1.0
	_stop_until = 0
	_last_stop_end = Time.get_ticks_usec()

## Push the view a little the way a blow travelled (`dir` on the ground), springing back.
## Follows the shake setting: off with it, smaller on Low.
func kick(dir: Vector3, amount: float) -> void:
	if not Settings.shake or not live():
		return
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() < 0.01 or _cams.is_empty() or not is_instance_valid(_cams[0]):
		return
	flat = flat.normalized()
	var b := _cams[0].global_transform.basis
	var right := Vector3(b.x.x, 0.0, b.x.z).normalized()
	var up := Vector3(-b.z.x, 0.0, -b.z.z).normalized()
	var k := Vector2(flat.dot(right), flat.dot(up)) * amount * KICK_MAX * float(Settings.SHAKE_SCALE[Settings.shake_level])
	_kick = (_kick + k).limit_length(KICK_MAX)

## A keeper's blow on a creature: harder if it kills. `heavy` is a big blow (see STOP_*),
## `dir` the way it travelled (for the camera's kick), `amount` its damage: under SOLID
## it's a chip and nothing stops. Only a person's blows come here (Enemy.take_damage).
func blow(killed: bool, heavy: bool = false, dir: Vector3 = Vector3.ZERO, amount: int = SOLID) -> void:
	if killed or amount >= SOLID:
		hitstop(STOP_HEAVY_KILL if killed and heavy else (STOP_KILL if killed else (STOP_HEAVY if heavy else STOP_SOLID)))
	shake(0.22 if killed else (0.16 if heavy else 0.08))
	if dir != Vector3.ZERO:
		kick(dir, 1.0 if heavy else (0.75 if killed else 0.45))

## The cameras the director draws through (it registers them).
func use_cameras(cams: Array) -> void:
	_cams.clear()
	for c in cams:
		if c is Camera3D:
			_cams.append(c)

func _process(_delta: float) -> void:
	_end_stop()
	# Real time: the shake runs through a hit-stop.
	var dt := 1.0 / maxf(1.0, Engine.get_frames_per_second()) if Engine.time_scale < 0.5 else _delta / maxf(Engine.time_scale, 0.001)
	dt = clampf(dt, 0.0, 0.1)
	_t += dt
	trauma = maxf(0.0, trauma - DECAY * dt)
	_kick = _kick * exp(-KICK_RETURN * dt)
	if _kick.length() < 0.002:
		_kick = Vector2.ZERO
	var s := trauma * trauma
	for c in _cams:
		if not is_instance_valid(c):
			continue
		c.h_offset = s * MAX_SHIFT * _wave(1.0) + _kick.x
		c.v_offset = s * MAX_SHIFT * _wave(2.7) + _kick.y
		c.rotation.z = s * MAX_ROLL * _wave(5.1)

# A smooth wobble, different on each axis.
func _wave(seed: float) -> float:
	return sin(_t * 31.0 + seed) * 0.6 + sin(_t * 47.0 + seed * 2.3) * 0.4
