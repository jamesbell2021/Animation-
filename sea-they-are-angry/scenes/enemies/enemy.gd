class_name Enemy
extends CharacterBody3D
## Base for every sea creature. A tiny string state machine:
## change_state(&"X") calls _exit_<old>() / _enter_X() if they exist,
## and _physics_process calls _tick_X(delta) each frame.

const EMERGE_TIME := 0.8
const EMERGE_DEPTH := -0.6
const FENCE_HIT_INTERVAL := 1.0
const FENCE_HIT_DMG := 10
const RETREAT_MULT := 2.0
const DESPAWN_RADIUS := 30.0
const SINK_RATE := 0.6
const WAYPOINT_REACHED := 0.7
const STRUCTURE_REACH := 1.0
const REPATH_EVERY := 0.5
const OFF_ROUTE_HEIGHT := 1.2
const FALL_RATE := 9.0
# A boathook blow pointing out over the ledge's edge shoves a creature off it.
const SHOVE_SPEED := 6.5
const SHOVE_DOT := 0.35
# Falls longer than this hurt, more the further they drop.
const FALL_HURT_FROM := 1.2
const FALL_DMG_PER_M := 14.0
const KNOCKBACK := 3.0
const KNOCKBACK_DECAY := 8.0
const DETOUR_TIME := 0.8
# Heights on the body the lamp tests against its cone: feet, waist, head.
const LIGHT_PROBE_HEIGHTS := [0.3, 1.0, 1.8]

var hp := 10
var max_hp := 10
var speed := 1.0
var mass := 1.0
var reach := 1.0
var speed_mult := 1.0
var target: Node3D
var lighthouse: Node3D
var state: StringName = &""
var state_t := 0.0
var attack_target: Structure
## Waypoints still to walk (from Nav). Filled on landing and again at dawn.
var route: Array[Vector3] = []
## What last hurt it: "beam", "hook", "fall", or "reached" once it gets to the light.
var last_hit := ""
## Set by the lamp each frame its beam is on this creature; cleared after moving.
var lit_this_frame := false
## Seconds left hidden inside a Squid's ink cloud (unless the beam is on it).
var inked := 0.0
# Too heavy to be shoved off the ledge at or above this.
const SHOVE_MAX_MASS := 3.0
var _resume_state: StringName = &""
var _stagger_len := 0.0

var _knock := Vector3.ZERO
var _detour_t := 0.0
var _groan_t := 0.0
var _in_water := true
var _detour_dir := Vector3.ZERO
var _attack_t := 0.0
var _repath_t := 0.0
var _sink_t := 0.0
var _fall_top := -INF
var _last_wp := Vector3.INF

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 8
	# No ground layer: creatures follow Terrain.height_at instead, so the beach slope never snags them.
	collision_mask = 2 | 4
	hp = max_hp
	Cycle.phase_changed.connect(_on_phase_changed)
	_build()
	change_state(&"Emerge")

# ---- virtuals ----

func _build() -> void:
	pass

func in_light(_mode: int, _delta: float) -> void:
	pass

func pick_target() -> Node3D:
	return lighthouse

# Points the lamp tests against its cone. Override for odd shapes (the Eel's head).
func light_probe_points() -> Array:
	var out: Array = []
	for h in LIGHT_PROBE_HEIGHTS:
		out.append(global_position + Vector3(0.0, float(h), 0.0))
	return out

const HOME_IDS := ["cottage", "shed", "garden"]

## The nearest standing building of the homestead, or null if all are wrecked.
static func nearest_home(from: Vector3) -> Structure:
	var best: Structure = null
	var best_d := INF
	var tree := Engine.get_main_loop() as SceneTree
	for s in tree.get_nodes_in_group("structures"):
		if s is Structure and HOME_IDS.has(s.id) and not s.is_destroyed():
			var d := Geo.flat_dist(from, s.global_position)
			if d < best_d:
				best_d = d
				best = s
	return best

func _enter_Arrived() -> void:
	velocity = Vector3.ZERO

func on_dawn() -> void:
	change_state(&"Retreat")

# ---- state machine ----

func change_state(s: StringName) -> void:
	if state != &"":
		var ex := "_exit_" + String(state)
		if has_method(ex):
			call(ex)
	state = s
	state_t = 0.0
	var en := "_enter_" + String(s)
	if has_method(en):
		call(en)

func _physics_process(delta: float) -> void:
	state_t += delta
	var tick := "_tick_" + String(state)
	if has_method(tick):
		call(tick, delta)
	if not is_inside_tree() or is_queued_for_deletion():
		return
	velocity += _knock
	_knock = _knock.move_toward(Vector3.ZERO, KNOCKBACK_DECAY * delta)
	move_and_slide()
	# Ink hides it, except while the beam is on it.
	if inked > 0.0:
		inked = maxf(0.0, inked - delta)
	visible = inked <= 0.0 or lit_this_frame
	# Reset after use: the lamp re-applies these every physics frame through in_light().
	speed_mult = 1.0
	lit_this_frame = false

func _on_phase_changed(p: int) -> void:
	if p == Cycle.Phase.DAWN and state != &"Retreat":
		on_dawn()

func face(dir: Vector3) -> void:
	if Vector2(dir.x, dir.z).length() > 0.001:
		rotation.y = atan2(-dir.x, -dir.z)

# ---- shared states ----

func ground_y() -> float:
	return Terrain.height_at(global_position.x, global_position.z)

func _enter_Emerge() -> void:
	velocity = Vector3.ZERO
	position.y = ground_y() + EMERGE_DEPTH
	var surface := Vector3(global_position.x, Terrain.SEA_LEVEL, global_position.z)
	FX.splash(get_parent(), surface, 1.0)
	Audio.sfx("splash", surface, -4.0)
	_groan_t = randf_range(0.5, 4.0)

func _tick_Emerge(_delta: float) -> void:
	velocity = Vector3.ZERO
	var g := ground_y()
	position.y = lerpf(g + EMERGE_DEPTH, g, clampf(state_t / EMERGE_TIME, 0.0, 1.0))
	if state_t >= EMERGE_TIME:
		position.y = g
		_in_water = false
		change_state(&"Approach")

func _enter_Approach() -> void:
	target = pick_target()
	if _last_wp == Vector3.INF:
		# First time ashore: plot the way unless the spawner already did.
		if route.is_empty():
			replan()
		else:
			_last_wp = global_position

## Plot a fresh route from here to the current target.
func replan() -> void:
	if target != null and is_instance_valid(target):
		set_route(Nav.route_to(global_position, target.global_position))
	else:
		set_route(Nav.route_to_light(global_position))

## Virtual: whether it has reached its target. Buildings are measured to their walls.
func at_target() -> bool:
	if target is Structure and target != lighthouse:
		return target.surface_distance(global_position) < STRUCTURE_REACH
	var to := target.global_position - global_position
	return Vector2(to.x, to.z).length() < reach

func set_route(r: Array[Vector3]) -> void:
	route = r
	_last_wp = global_position

## Next point to walk to: the route's head, then the target itself.
func _steer_point() -> Vector3:
	while not route.is_empty() and Geo.flat_dist(global_position, route[0]) < WAYPOINT_REACHED:
		_last_wp = route.pop_front()
	if not route.is_empty():
		return route[0]
	return target.global_position if target != null and is_instance_valid(target) else global_position

# Knocked off the ledge or out of the gully: find a way back on from here.
func _check_route(delta: float) -> void:
	_repath_t -= delta
	if _repath_t > 0.0 or route.is_empty() or _last_wp == Vector3.INF:
		return
	_repath_t = REPATH_EVERY
	var a := _last_wp
	var b := route[0]
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var k := 0.0
	if ab.length_squared() > 0.001:
		k = clampf(Vector2(global_position.x - a.x, global_position.z - a.z).dot(ab) / ab.length_squared(), 0.0, 1.0)
	if absf(ground_y() - lerpf(a.y, b.y, k)) > OFF_ROUTE_HEIGHT:
		replan()

func _tick_Approach(delta: float) -> void:
	if target == null or not is_instance_valid(target) or (target is Structure and target != lighthouse and target.is_destroyed()):
		# Its building is already wrecked: on to the next thing.
		target = pick_target()
		replan()
	if target == null:
		velocity = Vector3.ZERO
		return
	if at_target():
		change_state(&"Arrived")
		return
	_check_route(delta)
	var to := _steer_point() - global_position
	to.y = 0.0
	if to.length() < 0.01:
		to = target.global_position - global_position
		to.y = 0.0
	var dir := to.normalized()
	_groan_t -= delta
	if _groan_t <= 0.0:
		_groan_t = randf_range(6.0, 12.0)
		Audio.sfx("groan", global_position, -6.0, 0.15)
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		var col := hit.get_collider()
		if col == target or col is CharacterBody3D:
			continue
		if col is Fence and not col.is_destroyed():
			attack_target = col
			change_state(&"AttackFence")
			return
		if col is StaticBody3D and _detour_t <= 0.0:
			# Buildings and scenery: step sideways along the wall for a moment.
			var n := hit.get_normal()
			var side := Vector3(n.z, 0.0, -n.x).normalized()
			if side.dot(dir) < 0.0 or (absf(side.dot(dir)) < 0.05 and get_instance_id() % 2 == 0):
				side = -side
			_detour_dir = side
			_detour_t = DETOUR_TIME
	if _detour_t > 0.0:
		_detour_t -= delta
		dir = _detour_dir
	face(dir)
	velocity = dir * speed * speed_mult
	_follow_ground(delta)

# Stick to the ground, but drop rather than teleport when knocked off a ledge.
func _follow_ground(delta: float) -> void:
	var g := ground_y()
	if position.y > g + 0.05:
		if _fall_top == -INF:
			_fall_top = position.y
		position.y = maxf(g, position.y - FALL_RATE * delta)
		if position.y <= g:
			_landed(_fall_top - g)
	else:
		position.y = g
		_fall_top = -INF

func _landed(drop: float) -> void:
	_fall_top = -INF
	if drop < FALL_HURT_FROM or state == &"Retreat":
		return
	FX.spray(get_parent(), global_position + Vector3(0.0, 0.3, 0.0), Vector3.UP, Color(0.33, 0.27, 0.2))
	Audio.sfx("hit", global_position, -2.0, 0.1)
	Audio.sfx("groan", global_position, -4.0, 0.2)
	Events.message.emit("Over the edge!")
	last_hit = "fall"
	take_damage(int(drop * FALL_DMG_PER_M), Vector3.ZERO, null)
	# Find the way back round from down here.
	_repath_t = 0.0

func _enter_AttackFence() -> void:
	_attack_t = 0.0
	velocity = Vector3.ZERO

func _tick_AttackFence(delta: float) -> void:
	velocity = Vector3.ZERO
	_follow_ground(delta)
	var gone := attack_target == null or not is_instance_valid(attack_target) or attack_target.is_destroyed()
	# Shoved away from it (or off the ledge below it): back to walking.
	if not gone and (Geo.flat_dist(global_position, attack_target.global_position) > attack_target.length * 0.5 + 1.5 \
			or absf(global_position.y - attack_target.global_position.y) > 1.0):
		gone = true
	if gone:
		attack_target = null
		change_state(&"Approach")
		return
	face(attack_target.global_position - global_position)
	_attack_t += delta
	if _attack_t >= FENCE_HIT_INTERVAL:
		_attack_t -= FENCE_HIT_INTERVAL
		attack_target.take_damage(FENCE_HIT_DMG)

func _enter_Retreat() -> void:
	# Walk through fences and keepers on the way out; nothing should wedge a retreating creature.
	collision_mask = 0
	attack_target = null
	set_route(Nav.route_to_sea(global_position))

func _tick_Retreat(delta: float) -> void:
	# Back down the way they came, to the nearest beach, and under.
	while not route.is_empty() and Geo.flat_dist(global_position, route[0]) < WAYPOINT_REACHED:
		route.pop_front()
	var flat := Vector3(global_position.x, 0.0, global_position.z)
	var dir: Vector3
	if route.is_empty():
		dir = flat.normalized() if flat.length() > 0.01 else Vector3.RIGHT
	else:
		dir = Vector3(route[0].x - global_position.x, 0.0, route[0].z - global_position.z).normalized()
	if route.is_empty() and (_in_water or flat.length() > DESPAWN_RADIUS):
		_sink_t += delta
		if _sink_t > 2.0 or flat.length() > DESPAWN_RADIUS:
			queue_free()
			return
	face(dir)
	velocity = dir * speed * RETREAT_MULT
	var g := ground_y()
	if g < Terrain.SEA_LEVEL - 0.6 and not _in_water:
		_in_water = true
		var surface := Vector3(global_position.x, Terrain.SEA_LEVEL, global_position.z)
		FX.splash(get_parent(), surface, 0.7)
		Audio.sfx("splash", surface, -8.0)
	# Walk down the beach and sink once the water closes over them.
	_follow_ground(delta)
	if _in_water:
		position.y = g - _sink_t * SINK_RATE * 2.0 - SINK_RATE

## Reeling for a moment: stops, wobbles, then carries on with what it was doing.
func stagger(duration: float) -> void:
	if state == &"Stagger" or state == &"Emerge" or state == &"Retreat":
		return
	_resume_state = state
	_stagger_len = duration
	change_state(&"Stagger")

func _enter_Stagger() -> void:
	velocity = Vector3.ZERO

func _tick_Stagger(_delta: float) -> void:
	velocity = Vector3.ZERO
	rotation.z = sin(state_t * 22.0) * 0.12 * (1.0 - state_t / maxf(_stagger_len, 0.01))
	if state_t >= _stagger_len:
		rotation.z = 0.0
		change_state(_resume_state if _resume_state != &"" else &"Approach")

## Virtual: whether hits land at all right now.
func is_vulnerable() -> bool:
	return true

# ---- damage ----

func take_damage(amount: int, from_dir: Vector3 = Vector3.ZERO, source: Node = null) -> void:
	if state == &"Emerge" or hp <= 0 or not is_vulnerable():
		return
	if source is Player:
		last_hit = "hook"
	hp -= amount
	_knock += Vector3(from_dir.x, 0.0, from_dir.z) * (KNOCKBACK / mass)
	# On the ledge, a blow aimed outward sends it over the edge.
	if source != null and hp > 0 and mass < SHOVE_MAX_MASS and Terrain.on_ledge(global_position.x, global_position.z):
		var out := Vector3(global_position.x, 0.0, global_position.z).normalized()
		if Vector3(from_dir.x, 0.0, from_dir.z).dot(out) > SHOVE_DOT:
			_knock = out * SHOVE_SPEED
	if source != null:
		FX.spray(get_parent(), global_position + Vector3(0.0, 1.1, 0.0), from_dir, Color(0.55, 0.65, 0.45))
		Audio.sfx("hit", global_position)
	_on_hit()
	if hp <= 0:
		hp = 0
		_die()

# Virtual: visual reaction to a hit.
func _on_hit() -> void:
	pass

func _die() -> void:
	Events.enemy_killed.emit(self)
	queue_free()
