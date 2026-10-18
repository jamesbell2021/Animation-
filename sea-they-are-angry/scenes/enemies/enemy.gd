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
const DESPAWN_RADIUS := 20.0
const SHORE_RADIUS := 14.0
const SINK_RATE := 0.25
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

var _knock := Vector3.ZERO
var _detour_t := 0.0
var _groan_t := 0.0
var _in_water := true
var _detour_dir := Vector3.ZERO
var _attack_t := 0.0

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
	# Reset after use: the lamp re-applies its slow every physics frame through in_light().
	speed_mult = 1.0

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

func _tick_Approach(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		target = pick_target()
	if target == null:
		velocity = Vector3.ZERO
		return
	var to := target.global_position - global_position
	to.y = 0.0
	if to.length() < reach:
		change_state(&"Arrived")
		return
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
	position.y = ground_y()

func _enter_AttackFence() -> void:
	_attack_t = 0.0
	velocity = Vector3.ZERO

func _tick_AttackFence(delta: float) -> void:
	velocity = Vector3.ZERO
	if attack_target == null or not is_instance_valid(attack_target) or attack_target.is_destroyed():
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

func _tick_Retreat(_delta: float) -> void:
	var away := Vector3(global_position.x, 0.0, global_position.z)
	if away.length() < 0.01:
		away = Vector3(1.0, 0.0, 0.0)
	var r := away.length()
	if r > DESPAWN_RADIUS:
		queue_free()
		return
	var dir := away.normalized()
	face(dir)
	velocity = dir * speed * RETREAT_MULT
	if global_position.y < Terrain.SEA_LEVEL and not _in_water:
		_in_water = true
		var surface := Vector3(global_position.x, Terrain.SEA_LEVEL, global_position.z)
		FX.splash(get_parent(), surface, 0.7)
		Audio.sfx("splash", surface, -8.0)
	# Walk down the beach and keep sinking once past the shore.
	position.y = ground_y() - maxf(0.0, r - SHORE_RADIUS) * SINK_RATE

# ---- damage ----

func take_damage(amount: int, from_dir: Vector3 = Vector3.ZERO, source: Node = null) -> void:
	if state == &"Emerge" or hp <= 0:
		return
	hp -= amount
	_knock += Vector3(from_dir.x, 0.0, from_dir.z) * (KNOCKBACK / mass)
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
