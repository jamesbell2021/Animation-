class_name Hornet
extends Enemy
## Swarm mini-drone. Arrives in packs of five, weaves in fast over the rooftops and dives into the
## mega tank, popping like a small grenade. One machine-gun round kills one; the shield stops them
## cold. Like the bigger drones, its glowing ground shadow is where it can be hit.

const SPEED := 10.0
const HOVER := 2.4
const DIVE_RANGE := 5.0

var _body: Node3D
var _wings: Array[MeshInstance3D] = []
var _light: MeshInstance3D
var _phase := 0.0
var _weave := 1.0
var _t := 0.0


func _ready() -> void:
	setup_enemy()
	color = Color(0.8, 1.0, 0.15)
	max_hp = 5.0
	score_value = 12
	shout_chance = 0.15
	_phase = randf() * TAU
	_weave = randf_range(0.6, 1.4) * [-1.0, 1.0].pick_random()
	collision_mask = 0  # flies over everything
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.55
	cap.height = 3.0
	cs.shape = cap
	cs.position.y = 1.5
	add_child(cs)
	_body = Node3D.new()
	_body.position.y = HOVER
	add_child(_body)
	part(_body, Vector3(0.36, 0.22, 0.6), Vector3.ZERO, 3.4).rotation_degrees.y = 45.0
	part(_body, Vector3(0.12, 0.12, 0.4), Vector3(0, -0.05, -0.35), 3.6)
	for side in [-1.0, 1.0]:
		var wing := part(_body, Vector3(0.55, 0.03, 0.22), Vector3(side * 0.38, 0.08, 0.05), 3.0)
		_wings.append(wing)
	_light = G.neon_box(_body, Vector3(0.14, 0.14, 0.14), Vector3(0, 0.16, 0.1), Color(1, 0.15, 0.1), 4.0)
	G.neon_box(self, Vector3(0.8, 0.03, 0.8), Vector3(0, 0.05, 0), color, 1.0).rotation_degrees.y = 45.0
	apply_difficulty()


func death_lines() -> Array:
	return VoiceLines.DRONE_DEATH


func die() -> void:
	if dead:
		return
	G.sparks(_body.global_position, color, 10, 6.0, 0.5, 0.1)
	G.sfx("hit", -6.0, 1.6)
	super.die()


## Self-destructs against the tank (or its shield).
func _pop() -> void:
	if dead:
		return
	G.explode(Vector3(global_position.x, 0.0, global_position.z), 2.2, 6.0 * G.difficulty, G.Team.ENEMY, color)
	score_value = 0
	die()


func _process(delta: float) -> void:
	_t += delta
	for w in _wings:
		w.rotation.z = sin(_t * 60.0) * 0.6
	_body.position.y = HOVER + sin(_t * 7.0 + _phase) * 0.25
	G.set_neon(_light, Color(1, 0.15, 0.1), 5.0 if fmod(_t, 0.3) < 0.15 else 0.8)


func _physics_process(delta: float) -> void:
	if dead:
		return
	if puppet:
		puppet_update(delta)
		_body.rotation.y = lerp_angle(_body.rotation.y, _net_yaw, minf(1.0, delta * 10.0))
		return
	var tank := G.tank
	if tank == null or tank.dead:
		return
	var to := tank.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	var dir := to / maxf(dist, 0.001)
	if dist < DIVE_RANGE or tank.shield_covers(global_position):
		_pop()
		return
	# Weave side to side on the way in, tighter as it closes.
	var side := dir.cross(Vector3.UP) * sin(_t * 3.0 + _phase) * _weave * clampf(dist / 20.0, 0.2, 1.0)
	var want := (dir + side).normalized()
	global_position += want * SPEED * delta
	global_position.y = 0.0
	_body.rotation.y = lerp_angle(_body.rotation.y, atan2(-want.x, -want.z), minf(1.0, delta * 10.0))


func facing_yaw() -> float:
	return _body.rotation.y
