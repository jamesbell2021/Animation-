class_name PaintballBot
extends Node
## Paintball Battle bot (host only). Picks the nearest rival, keeps a fighting
## distance while strafing, stops to turn and shoot when it has a clear shot,
## goes for a PAINT crate when it runs low, and steers round cover.

var contestant: Contestant
var manager: PaintballManager

## 0 Easy, 1 Medium, 2 Hard.
var difficulty: int = 1

var _target: Contestant
var _think: float = 0.0
var _strafe: float = 1.0
var _strafe_timer: float = 0.0
var _aim_left: float = 0.0
var _fire_left: float = 0.0
var _reload_left: float = 0.0
var _stuck_time: float = 0.0
var _detour: Vector3 = Vector3.ZERO
var _detour_left: float = 0.0
var _last_pos: Vector3 = Vector3.ZERO


func setup(p_contestant: Contestant, p_manager: PaintballManager, p_difficulty: int) -> void:
	contestant = p_contestant
	manager = p_manager
	difficulty = clampi(p_difficulty, 0, 2)
	contestant.is_local_player = false
	manager.set_bot_gun(contestant, [0.8, 0.55, 0.4][difficulty], [11.0, 7.0, 4.0][difficulty])
	_strafe = 1.0 if randf() < 0.5 else -1.0


func _physics_process(delta: float) -> void:
	if contestant == null or manager == null:
		return
	contestant.use_held = false
	if not manager.active or not manager.is_alive(str(contestant.name)) or not contestant.controls_enabled:
		contestant.move_direction = Vector3.ZERO
		return
	_think -= delta
	if _think <= 0.0:
		_think = [0.5, 0.3, 0.2][difficulty]
		_target = _pick_target()
	_strafe_timer -= delta
	if _strafe_timer <= 0.0:
		_strafe_timer = randf_range(1.2, 3.0)
		_strafe = -_strafe
	_track_stuck(delta)

	var me := contestant.global_position
	var ammo := manager.get_ammo(str(contestant.name))
	var move := Vector3.ZERO
	if ammo <= 2:
		var crate := _nearest_crate()
		if crate != Vector3.INF:
			move = _flat(crate - me).normalized()
	if move == Vector3.ZERO and _target != null:
		var off := _flat(_target.global_position - me)
		var dist := off.length()
		var toward := off.normalized()
		var side := Vector3(-toward.z, 0.0, toward.x) * _strafe
		if dist > 13.0:
			move = toward + side * 0.3
		elif dist < 6.0:
			move = -toward + side * 0.6
		else:
			move = side + toward * 0.15
		# Stop, turn and fire when there's a clear shot.
		if _fire_left > 0.0:
			_fire_left -= delta
			contestant.use_held = true
			move = toward * 0.05
		elif _aim_left > 0.0:
			_aim_left -= delta
			move = toward * 0.05
			if _aim_left <= 0.0:
				_fire_left = [0.15, 0.35, 0.6][difficulty]
		elif ammo > 0 and dist < 22.0 and _reload_left <= 0.0 and _can_see(_target):
			_aim_left = [0.45, 0.28, 0.15][difficulty]
			_reload_left = randf_range(0.8, 1.6) * [1.6, 1.0, 0.6][difficulty]
		_reload_left -= delta
	if _detour_left > 0.0:
		_detour_left -= delta
		move = _detour
	elif move.length() > 0.1:
		move = _avoid(move.normalized())
	contestant.move_direction = move.limit_length(1.0)
	contestant.jump_requested = _stuck_time > 0.5 and randf() < 0.1


func _pick_target() -> Contestant:
	var best: Contestant = null
	var best_d := INF
	for c in manager.alive_contestants():
		if c == contestant:
			continue
		var d := contestant.global_position.distance_to(c.global_position)
		if not _can_see(c):
			d += 10.0
		if d < best_d:
			best_d = d
			best = c
	return best


func _nearest_crate() -> Vector3:
	var best := Vector3.INF
	var best_d := INF
	for p in manager.active_crate_positions():
		var d := contestant.global_position.distance_to(p)
		if d < best_d:
			best_d = d
			best = p
	return best


func _can_see(c: Contestant) -> bool:
	var space := contestant.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(contestant.global_position + Vector3.UP * 1.15, c.global_position + Vector3.UP * 0.8, Contestant.COURSE_LAYER)
	return space.intersect_ray(query).is_empty()


## Steers round cover: tries the wanted direction, then angles either side.
func _avoid(dir: Vector3) -> Vector3:
	var space := contestant.get_world_3d().direct_space_state
	var origin := contestant.global_position + Vector3.UP * 0.6
	for angle: float in [0.0, 0.6, -0.6, 1.2, -1.2, 1.9, -1.9]:
		var d := dir.rotated(Vector3.UP, angle * _strafe)
		var query := PhysicsRayQueryParameters3D.create(origin, origin + d * 1.8, Contestant.COURSE_LAYER)
		if space.intersect_ray(query).is_empty():
			return d
	return -dir


func _track_stuck(delta: float) -> void:
	var moved := _flat(contestant.global_position - _last_pos).length()
	_last_pos = contestant.global_position
	if contestant.move_direction.length() > 0.5 and moved < 0.02:
		_stuck_time += delta
	else:
		_stuck_time = maxf(_stuck_time - delta, 0.0)
	if _stuck_time > 1.0:
		_stuck_time = 0.0
		var a := randf() * TAU
		_detour = Vector3(cos(a), 0.0, sin(a))
		_detour_left = 0.8


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
