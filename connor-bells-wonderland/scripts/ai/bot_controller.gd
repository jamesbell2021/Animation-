class_name BotController
extends Node
## Drives a Contestant along a BotNavigation route. Add as a child of the
## contestant and call setup(). Behaviour is shaped by a BotProfiles dictionary.
## Bots also grab nearby gift boxes and use items when a rival is in reach.

@export var look_ahead: float = 1.3
## Distances checked beyond look_ahead for a landing spot across a gap.
@export var gap_probe_distances: Array[float] = [2.2, 3.0, 3.8]
## Seconds from deciding to jump onto a sliding platform until landing on it.
@export var platform_jump_lead: float = 0.85
@export var ground_probe_depth: float = 3.5
@export var coin_check_interval: float = 0.5
## How far off the route a bot will go for a gift box.
@export var box_detour_radius: float = 4.0
## A bot that has held an item this long uses it even without a good target.
@export var item_patience: float = 20.0

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
var _assist_target: Vector3 = Vector3.INF
var _gap_jump: bool = false
var _air_target: MovingPlatform
var _box_target: ItemBox
var _item_hold: float = 0.0
var _launch_target: float = 0.0


func setup(p_contestant: Contestant, p_navigation: BotNavigation, p_profile: Dictionary) -> void:
	contestant = p_contestant
	navigation = p_navigation
	profile = p_profile
	if contestant == null or navigation == null:
		push_error("BotController.setup: contestant or navigation is null.")
		return
	contestant.is_local_player = false
	contestant.respawned.connect(_on_respawned)
	contestant.jumped.connect(_on_jumped)
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
	_update_jump_assist()

	var pos := contestant.global_position
	var wp := navigation.get_waypoint(_index)
	var target: Vector3 = wp["pos"]
	# Landed well below the route (fell but didn't respawn): pick it up again from here.
	if contestant.is_on_floor() and target.y - pos.y > 4.0:
		_index = navigation.nearest_index(pos)
		wp = navigation.get_waypoint(_index)
		target = wp["pos"]
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
		var box_spot := _box_detour(pos, target)
		target = box_spot if box_spot != Vector3.INF else _coin_detour(pos, target, delta)

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
	_think_items(pos, delta)


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


## Tower Climb: aim the jump that just started at the jump waypoint ahead. The
## aim kicks in once the bot has risen level with the target (so it doesn't
## slam into the side of a step), then it coasts there with an error that
## shrinks with difficulty.
func _on_jumped() -> void:
	_assist_target = Vector3.INF
	if not navigation.assist_jumps:
		return
	var wp := navigation.get_waypoint(_index)
	if not bool(wp["jump"]):
		return
	var target: Vector3 = wp["pos"]
	var pos := contestant.global_position
	var dist := Vector2(target.x - pos.x, target.z - pos.z).length()
	if dist > 0.2 and dist < 4.5:
		_assist_target = target


func _update_jump_assist() -> void:
	if _assist_target == Vector3.INF:
		return
	if contestant.is_on_floor() and contestant.velocity.y <= 0.0:
		_assist_target = Vector3.INF
		return
	var pos := contestant.global_position
	if pos.y < _assist_target.y - 0.05:
		if contestant.velocity.y <= 0.0:
			_assist_target = Vector3.INF
		return
	var flat := Vector3(_assist_target.x - pos.x, 0.0, _assist_target.z - pos.z)
	var dist := flat.length()
	var v := contestant.velocity.y
	var g := contestant.gravity
	var t := (v + sqrt(maxf(v * v - 2.0 * g * (_assist_target.y - pos.y), 0.0))) / g
	if t > 0.02 and dist > 0.05:
		var error: float = [0.15, 0.08, 0.03][clampi(int(profile.get("difficulty", 1)), 0, 2)]
		var speed := minf(dist / t * randf_range(1.0 - error, 1.0 + error), contestant.move_speed * 1.4)
		contestant.velocity.x = flat.x / dist * speed
		contestant.velocity.z = flat.z / dist * speed
		contestant.coast()
	_assist_target = Vector3.INF


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


## Position of a gift box worth a short detour (only with an empty item slot), or INF.
func _box_detour(pos: Vector3, target: Vector3) -> Vector3:
	var holder := contestant.get_node_or_null("ItemHolder") as ItemHolder
	if holder == null or not holder.is_empty():
		_box_target = null
		return Vector3.INF
	if _box_target != null and is_instance_valid(_box_target) and _box_target.is_available():
		var still := _box_target.global_position - pos
		still.y = 0.0
		if still.length() < box_detour_radius + 1.0:
			return _box_target.global_position
	_box_target = null
	var ahead := target - pos
	ahead.y = 0.0
	var best := box_detour_radius * box_detour_radius
	for node in get_tree().get_nodes_in_group("item_boxes"):
		var box := node as ItemBox
		if box == null or not box.is_available():
			continue
		var offset := box.global_position - pos
		if absf(offset.y) > 2.5:
			continue
		offset.y = 0.0
		var d := offset.length_squared()
		if d < best and offset.dot(ahead) > 0.0:
			best = d
			_box_target = box
	return _box_target.global_position if _box_target != null else Vector3.INF


## Uses the held item when it would hit someone (or after holding it a long time).
func _think_items(pos: Vector3, delta: float) -> void:
	var holder := contestant.get_node_or_null("ItemHolder") as ItemHolder
	if holder == null or holder.is_empty():
		_item_hold = 0.0
		return
	_item_hold += delta
	if holder.is_charging():
		contestant.use_held = holder.get_charge() < _launch_target
		return
	contestant.use_held = false
	if _item_hold < float(profile.get("item_delay", 1.2)) or not holder.can_use():
		return
	var def := ItemKinds.get_def(holder.kind)
	var facing := contestant.get_facing()
	if ItemKinds.mode_of(holder.kind) == "launch":
		_think_catapult(pos, facing, def)
		return
	var want := false
	match ItemKinds.mode_of(holder.kind):
		"self":
			want = true
		"trap":
			want = _rival_near(pos, -facing, 7.0, 0.3, 0.0) or _item_hold > 8.0
		"melee":
			want = _rival_near(pos, facing, float(def.get("range", 2.5)) * 0.9, float(def.get("cone", 0.3)) + 0.15, 0.0)
		"burst":
			want = _rival_near(pos, Vector3.ZERO, float(def.get("radius", 4.5)) * 0.8, -2.0, 0.0)
		"throw":
			want = _rival_near(pos, facing, 11.0, 0.85, 6.5)
	if want or _item_hold > item_patience:
		contestant.use_requested = true
		_item_hold = 0.0


## Catapult: aim at a rival 6-19 m ahead (or just fling forward after a while),
## but only if there is solid ground where the launch would land.
func _think_catapult(pos: Vector3, facing: Vector3, def: Dictionary) -> void:
	if not contestant.is_on_floor():
		return
	var aim_distance := -1.0
	for node in get_tree().get_nodes_in_group("contestants"):
		var other := node as Contestant
		if other == null or other == contestant:
			continue
		var offset := other.global_position - pos
		if absf(offset.y) > 1.5:
			continue
		offset.y = 0.0
		var dist := offset.length()
		if dist < 6.0 or dist > 19.0 or offset.normalized().dot(facing) < 0.85:
			continue
		aim_distance = dist
		break
	if aim_distance < 0.0 and _item_hold > 12.0:
		aim_distance = 30.0
	if aim_distance < 0.0:
		return
	var best_charge := -1.0
	var best_error := INF
	for i in range(11):
		var charge := float(i) / 10.0
		var landing := pos + facing * _launch_distance(charge, def)
		if not _ground_at(landing):
			continue
		var error := absf(_launch_distance(charge, def) - aim_distance)
		if error < best_error:
			best_error = error
			best_charge = charge
	if best_charge < 0.0:
		return
	_launch_target = best_charge
	contestant.use_requested = true
	contestant.use_held = true
	_item_hold = 0.0


## Flat distance a catapult launch of [param charge] travels before landing at the same height.
func _launch_distance(charge: float, def: Dictionary) -> float:
	var v := ItemManager.launch_velocity(Vector3.FORWARD, charge, def)
	var flight := 2.0 * v.y / contestant.gravity
	return Vector2(v.x, v.z).length() * flight


## Is another contestant between [param min_dist] and [param reach] away, roughly in
## direction [param dir] (dot >= [param min_dot]; dir ZERO means any direction)?
func _rival_near(pos: Vector3, dir: Vector3, reach: float, min_dot: float, min_dist: float) -> bool:
	for node in get_tree().get_nodes_in_group("contestants"):
		var other := node as Contestant
		if other == null or other == contestant:
			continue
		var offset := other.global_position - pos
		if absf(offset.y) > 2.0:
			continue
		offset.y = 0.0
		var dist := offset.length()
		if dist > reach or dist < min_dist:
			continue
		if dir != Vector3.ZERO and dist > 0.3 and offset.normalized().dot(dir) < min_dot:
			continue
		return true
	return false


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
	_box_target = null
	_edge_roll = -1.0
	if navigation == null:
		return
	_index = navigation.nearest_index(contestant.global_position)
	_jump_timer = -1.0
	_unstick_timer = 0.0
	_stuck_timer = 0.0
	_coin_target = null
	_last_pos = contestant.global_position
