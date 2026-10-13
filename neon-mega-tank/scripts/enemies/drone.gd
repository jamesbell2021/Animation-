class_name Drone
extends Enemy
## Attack drone: flies straight over the buildings, circles the mega tank and strafes it with
## bursts. Its glowing ground shadow is where it can be hit (the guns fire along the ground).

const SPEED := 6.5
const HOVER := 3.6

var _rotors: Array[MeshInstance3D] = []
var _body: Node3D
var _cooldown := 2.0
var _burst := 0
var _burst_t := 0.0
var _orbit := 1.0
var _bob := 0.0


func _ready() -> void:
	setup_enemy()
	color = Color(1.0, 0.2, 0.55)
	max_hp = 16.0
	score_value = 30
	_cooldown = randf_range(1.5, 3.0)
	_orbit = [-1.0, 1.0].pick_random()
	collision_mask = 0  # flies over everything
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.8
	cap.height = 5.0
	cs.shape = cap
	cs.position.y = 2.5
	add_child(cs)
	_body = Node3D.new()
	_body.position.y = HOVER
	add_child(_body)
	part(_body, Vector3(0.9, 0.35, 0.9), Vector3.ZERO, 3.0)
	part(_body, Vector3(0.2, 0.2, 0.6), Vector3(0, -0.25, -0.4), 3.5)
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			part(_body, Vector3(0.12, 0.12, 0.7), Vector3(x * 0.45, 0, z * 0.45), 2.0).rotation_degrees.y = 45.0 * x * z
			var rotor := part(_body, Vector3(0.9, 0.04, 0.12), Vector3(x * 0.7, 0.25, z * 0.7), 3.5)
			_rotors.append(rotor)
	# Ground shadow: shows where the drone can be shot.
	G.neon_box(self, Vector3(1.4, 0.03, 1.4), Vector3(0, 0.05, 0), color, 1.2).rotation_degrees.y = 45.0
	apply_difficulty()


func death_lines() -> Array:
	return VoiceLines.DRONE_DEATH


func die() -> void:
	if dead:
		return
	G.explode(_body.global_position, 2.0, 0.0, G.Team.ENEMY, color)
	super.die()


func _process(delta: float) -> void:
	_bob += delta
	for r in _rotors:
		r.rotation.y += delta * 30.0
	_body.position.y = HOVER + sin(_bob * 3.0) * 0.2


func _physics_process(delta: float) -> void:
	if dead:
		return
	if puppet:
		puppet_update(delta)
		_body.rotation.y = lerp_angle(_body.rotation.y, _net_yaw, minf(1.0, delta * 8.0))
		return
	var tank := G.tank
	if tank == null or tank.dead:
		return
	var to := tank.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	var dir := to / maxf(dist, 0.001)
	var want := dir
	if dist < 14.0:
		want = (dir.cross(Vector3.UP) * _orbit + dir * (dist - 11.0) * 0.2).normalized()
	global_position += want * SPEED * delta
	global_position.y = 0.0
	_body.rotation.y = lerp_angle(_body.rotation.y, atan2(-dir.x, -dir.z), minf(1.0, delta * 8.0))
	_cooldown -= delta
	if _burst > 0:
		_burst_t -= delta
		if _burst_t <= 0.0:
			_burst -= 1
			_burst_t = 0.1
			var start := _body.global_position
			var target := tank.global_position + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-2.0, 2.0))
			var d := target - start
			d.y = 0.0
			G.spawn_projectile(start, d.normalized() * 30.0, G.Team.ENEMY, "enemy_bullet", color)
			G.sfx("rifle", -16.0, 1.4)
	elif dist < 18.0 and _cooldown <= 0.0:
		_burst = 4
		_cooldown = randf_range(2.5, 3.5)


func facing_yaw() -> float:
	return _body.rotation.y
