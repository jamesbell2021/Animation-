class_name BotController
extends Node
## Drives a Contestant along a BotNavigation route. Add as a child of the
## contestant and call setup(). Behaviour is shaped by a BotProfiles dictionary.

@export var look_ahead: float = 1.3
## Distances checked beyond look_ahead for a landing spot across a gap.
@export var gap_probe_distances: Array[float] = [2.2, 3.0, 3.8]
## Seconds from deciding to jump onto a sliding platform until landing on it.
@export var platform_jump_lead: float = 0.85
@export var ground_probe_depth: float = 3.5
@export var coin_check_interval: float = 0.5

var contestant: Contestant
var navigation: BotNavigation
var profile: Dictionary = {}

var _index: int = 0
var _time: float = 0.0
var _steer_offset: float = 0.0
var _steer_timer: float = 0.0
var _jump_timer: float = -1.0
var _stuck_timer: float = 0.0
var _last_pos: Vector3 = Vector3.ZERO
var _unstick_timer: float = 0.0
var _unstick_dir: Vector3 = Vector3.ZERO
var _coin_timer: float = 0.0
var _coin_target: CoinPickup
## Patience is rolled once per edge (not every frame); -1 = not at an edge.
var _edge_roll: float = -1.0
var _gap_jump: bool = false
var _air_target: MovingPlatform


func setup(p_contestant: Contestant, p_navigation: BotNavigation, p_profile: Dictionary) -> void:
	contestant = p_contestant
	navigation = p_navigation
	profile = p_profile
	if contestant == null or navigation == null:
		push_error("BotController.setup: contestant or navigation is null.")
		return
	contestant.is_local_player = false
	contestant.respawned.connect(_on_respawned)
	_index = navigation.nearest_index(contestant.global_position)
	_last_pos = contestant.global_position
	_time = randf() * 10.0


func _physics_process(delta: float) -> void:
	if contestant == null or navigation == null or navigation.count() == 0:
		return
	if not contestant.controls_enabled:
		contestant.move_direction = Vector3.ZERO
		return
	_time += delta
	_update_steer_noise(delta)
	_update_stuck(delta)

	var pos := contestant.global_position
	var wp := navigation.get_waypoint(_index)
	var target: Vector3 = wp["pos"]
	var reach := float(wp["radius"])
	if bool(wp["wait"]):
		reach = maxf(reach, absf(target.x - pos.x) + 0.5)
	if _flat_distance(pos, target) < reach and absf(target.y - pos.y) < 2.0 and _index < navigation.count() - 1:
		_index += 1
		wp = navigation.get_waypoint(_index)
		target = wp["pos"]
	if bool(wp["wait"]):
		# Moving-platform stretch: go straight ahead instead of steering off the side,
		# and while airborne home in on the platform being jumped to.
		target.x = pos.x
		if not contestant.is_on_floor() and is_instance_valid(_air_target):
			target.x = _air_target.global_position.x
	else:
		target = _coin_detour(pos, target, delta)

	var flat := target - pos
	flat.y = 0.0
	var dir := flat.normalized() if flat.length() > 0.01 else Vector3.ZERO
	var side := Vector3(-dir.z, 0.0, dir.x)
	var sway: float = sin(_time * 1.7) * float(profile.get("weave", 0.15)) + _steer_offset
	dir = (dir + side * sway).normalized() if dir != Vector3.ZERO else Vector3.ZERO
	if _unstick_timer > 0.0:
		dir = _unstick_dir

	var want_jump := false
	_gap_jump = false
	if contestant.is_on_floor():
		if dir != Vector3.ZERO and not _ground_ahead(pos, dir):
			_gap_jump = true
			if _edge_roll < 0.0:
				_edge_roll = randf()
			var platform := _sliding_platform_ahead(pos, dir) if bool(wp["wait"]) else null
			if platform != null:
				if _platform_will_be_under(platform, pos):
					want_jump = true
					_air_target = platform
					_gap_jump = false
				else:
					dir = Vector3.ZERO
			elif bool(wp["jump"]) or _landing_across_gap(pos, dir):
				want_jump = true
			elif _edge_roll < float(profile.get("patience", 0.9)):
				dir = Vector3.ZERO
			else:
				want_jump = true
		else:
			_edge_roll = -1.0
		if _gap_jump:
			pass
		elif contestant.is_on_wall():
			want_jump = true
		elif bool(wp["jump"]) and target.y > pos.y + 0.4 and _flat_distance(pos, target) < 2.2:
			want_jump = true
		if _unstick_timer > 0.0:
			want_jump = true
	if want_jump and _gap_jump and not _has_run_up(pos, dir):
		# Build speed before leaping a gap; leap anyway when the edge is right underfoot.
		want_jump = false
	_handle_jump(want_jump, delta)
	contestant.move_direction = dir * float(profile.get("speed", 0.9))


## Nearest sliding platform ahead (not the one underfoot) at about this height.
func _sliding_platform_ahead(pos: Vector3, dir: Vector3) -> MovingPlatform:
	var best: MovingPlatform = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("moving_platforms"):
		var platform := node as MovingPlatform
		if platform == null or platform.travel == Vector3.ZERO:
			continue
		var offset := platform.global_position - pos
		var ahead := offset.dot(dir)
		if ahead < platform.size.z * 0.5 + 0.3 or ahead > 6.0:
			continue
		if absf(platform.get_top_y() - pos.y) > 1.5:
			continue
		if ahead < best_d:
			best_d = ahead
			best = platform
	return best


## Will [param platform] be lined up with this bot when a jump started now lands?
func _platform_will_be_under(platform: MovingPlatform, pos: Vector3) -> bool:
	var predicted := platform.predict_global_position(platform_jump_lead)
	var half := maxf(platform.size.x * 0.5 - 0.5, 0.3)
	return absf(predicted.x - pos.x) < half and absf(platform.global_position.x - pos.x) < platform.size.x * 1.5


func _has_run_up(pos: Vector3, dir: Vector3) -> bool:
	var horizontal := Vector2(contestant.velocity.x, contestant.velocity.z)
	if dir == Vector3.ZERO or horizontal.length() >= contestant.move_speed * 0.6:
		return true
	return not _ground_at(pos + dir * 0.45)


func get_waypoint_index() -> int:
	return _index


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _ground_ahead(pos: Vector3, dir: Vector3) -> bool:
	return _ground_at(pos + dir * look_ahead)


## True when there is something to land on a short jump away (gondolas, teacups, pads).
func _landing_across_gap(pos: Vector3, dir: Vector3) -> bool:
	for d in gap_probe_distances:
		if _ground_at(pos + dir * d):
			return true
	return false


## Raycasts down from just above [param point]; only course geometry counts as ground.
func _ground_at(point: Vector3) -> bool:
	var space := contestant.get_world_3d().direct_space_state
	if space == null:
		return true
	var from := point + Vector3.UP * 0.6
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * ground_probe_depth, Contestant.COURSE_LAYER)
	return not space.intersect_ray(query).is_empty()


func _handle_jump(want_jump: bool, delta: float) -> void:
	if not want_jump:
		_jump_timer = -1.0
		return
	if _jump_timer < 0.0:
		_jump_timer = float(profile.get("jump_delay", 0.1)) * randf_range(0.5, 1.5)
	_jump_timer -= delta
	if _jump_timer <= 0.0:
		contestant.jump_requested = true
		_jump_timer = -1.0


func _update_steer_noise(delta: float) -> void:
	_steer_timer -= delta
	if _steer_timer <= 0.0:
		_steer_timer = randf_range(0.4, 1.2)
		_steer_offset = randf_range(-1.0, 1.0) * float(profile.get("steer_noise", 0.15))


func _update_stuck(delta: float) -> void:
	if _unstick_timer > 0.0:
		_unstick_timer -= delta
		return
	_stuck_timer += delta
	if _stuck_timer < float(profile.get("stuck_time", 1.5)):
		return
	_stuck_timer = 0.0
	var moved := contestant.global_position.distance_to(_last_pos)
	_last_pos = contestant.global_position
	if moved < 0.6 and contestant.is_on_floor():
		var wp := navigation.get_waypoint(_index)
		var forward: Vector3 = wp["pos"] - contestant.global_position
		forward.y = 0.0
		forward = forward.normalized() if forward.length() > 0.01 else Vector3.FORWARD
		var side := Vector3(-forward.z, 0.0, forward.x) * (1.0 if randf() < 0.5 else -1.0)
		_unstick_dir = (side * 0.8 - forward * 0.4).normalized()
		_unstick_timer = 0.7


func _coin_detour(pos: Vector3, target: Vector3, delta: float) -> Vector3:
	var greed := float(profile.get("coin_greed", 0.0))
	if greed <= 0.0:
		return target
	_coin_timer -= delta
	if _coin_timer <= 0.0:
		_coin_timer = coin_check_interval
		_coin_target = null
		var best := greed * greed
		var ahead := target - pos
		ahead.y = 0.0
		for node in get_tree().get_nodes_in_group("coins"):
			var coin := node as CoinPickup
			if coin == null or coin.is_taken():
				continue
			var offset := coin.global_position - pos
			offset.y = 0.0
			var d := offset.length_squared()
			if d < best and offset.dot(ahead) > 0.0 and absf(coin.global_position.y - pos.y) < 2.0 and _ground_at(coin.global_position):
				best = d
				_coin_target = coin
	if _coin_target != null and is_instance_valid(_coin_target) and not _coin_target.is_taken():
		return _coin_target.global_position
	return target


func _on_respawned() -> void:
	_air_target = null
	_edge_roll = -1.0
	if navigation == null:
		return
	_index = navigation.nearest_index(contestant.global_position)
	_jump_timer = -1.0
	_unstick_timer = 0.0
	_stuck_timer = 0.0
	_coin_target = null
	_last_pos = contestant.global_position
