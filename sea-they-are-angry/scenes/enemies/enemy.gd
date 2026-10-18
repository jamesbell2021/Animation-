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
var _attack_t := 0.0

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 8
	collision_mask = 1 | 2 | 4
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

func _enter_Emerge() -> void:
	velocity = Vector3.ZERO
	position.y = EMERGE_DEPTH

func _tick_Emerge(_delta: float) -> void:
	velocity = Vector3.ZERO
	position.y = lerpf(EMERGE_DEPTH, 0.0, clampf(state_t / EMERGE_TIME, 0.0, 1.0))
	if state_t >= EMERGE_TIME:
		position.y = 0.0
		change_state(&"Approach")

func _enter_Approach() -> void:
	target = pick_target()

func _tick_Approach(_delta: float) -> void:
	if target == null or not is_instance_valid(target):
		target = pick_target()
	if target == null:
		velocity = Vector3.ZERO
		return
	for i in get_slide_collision_count():
		var col := get_slide_collision(i).get_collider()
		if col is Structure and col != target and not col.is_destroyed():
			attack_target = col
			change_state(&"AttackFence")
			return
	var to := target.global_position - global_position
	to.y = 0.0
	if to.length() < reach:
		change_state(&"Arrived")
		return
	var dir := to.normalized()
	face(dir)
	velocity = dir * speed * speed_mult
	position.y = 0.0

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

func _tick_Retreat(delta: float) -> void:
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
	if r > SHORE_RADIUS:
		position.y = maxf(EMERGE_DEPTH * 2.0, position.y - SINK_RATE * delta * speed * RETREAT_MULT)

# ---- damage ----

func take_damage(amount: int, from_dir: Vector3 = Vector3.ZERO, _source: Node = null) -> void:
	if state == &"Emerge" or hp <= 0:
		return
	hp -= amount
	_knock += Vector3(from_dir.x, 0.0, from_dir.z) * (KNOCKBACK / mass)
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
