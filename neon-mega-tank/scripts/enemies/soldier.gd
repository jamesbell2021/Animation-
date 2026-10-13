class_name Soldier
extends Enemy
## Infantry. Riflemen pepper the hull in bursts; RPG troopers paint the tank with a laser for a
## second, then fire a rocket that the machine gun can shoot down. The mega tank crushes them.

const SPEED := 3.2

var rpg := false

var _cooldown := 1.5
var _aim_time := 0.0
var _burst := 0
var _burst_t := 0.0
var _body: Node3D
var _legs: Array[MeshInstance3D] = []
var _laser: MeshInstance3D
var _walk := 0.0
var _strafe := 0.0
var _strafe_t := 0.0


func _ready() -> void:
	setup_enemy()
	color = G.ENEMY_ALT_COLOR if rpg else G.ENEMY_COLOR
	max_hp = 14.0 if rpg else 9.0
	hp = max_hp
	score_value = 25 if rpg else 10
	_cooldown = randf_range(1.0, 3.0)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	_body = Node3D.new()
	add_child(_body)
	part(_body, Vector3(0.5, 0.6, 0.32), Vector3(0, 0.75, 0))
	part(_body, Vector3(0.3, 0.3, 0.3), Vector3(0, 1.25, 0))
	for side in [-1.0, 1.0]:
		_legs.append(part(_body, Vector3(0.16, 0.45, 0.16), Vector3(side * 0.13, 0.23, 0)))
	if rpg:
		part(_body, Vector3(0.18, 0.18, 1.3), Vector3(0.3, 1.15, -0.1), 3.2)
	else:
		part(_body, Vector3(0.08, 0.1, 0.8), Vector3(0.25, 0.85, -0.35), 3.2)
	_laser = G.neon_box(_body, Vector3(0.05, 0.05, 1.0), Vector3.ZERO, color, 3.0)
	_laser.visible = false
	apply_difficulty()


func is_aiming() -> bool:
	return _net_aiming if puppet else _aim_time > 0.0


func facing_yaw() -> float:
	return _body.rotation.y


func crush() -> void:
	if dead:
		return
	G.sparks(global_position + Vector3(0, 0.3, 0), color, 20, 5.0, 0.6)
	G.sfx("crush", -2.0, 1.4)
	die()


func _physics_process(delta: float) -> void:
	if dead:
		return
	if puppet:
		var spd := puppet_update(delta)
		if spd > 0.5:
			_walk += delta * 11.0
		_legs[0].rotation.x = sin(_walk) * 0.7
		_legs[1].rotation.x = -sin(_walk) * 0.7
		_body.rotation.y = lerp_angle(_body.rotation.y, _net_yaw, minf(1.0, delta * 10.0))
		_laser.visible = rpg and _net_aiming and G.tank != null
		if _laser.visible:
			var length := maxf(global_position.distance_to(G.tank.global_position) - 2.0, 1.0)
			_laser.position = Vector3(0.3, 1.15, -length * 0.5)
			_laser.scale = Vector3(1, 1, length)
		return
	var tank := G.tank
	if tank == null or tank.dead:
		_laser.visible = false
		velocity = Vector3.ZERO
		return
	var to := tank.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	var dir := to / maxf(dist, 0.001)
	var attack_range := 18.0 if rpg else 14.0
	var los := dist < attack_range + 4.0 and has_line_of_sight(tank.global_position)
	var want := Vector3.ZERO
	if dist > attack_range or not los:
		want = steer(dir, delta)
	elif dist < 8.0:
		want = steer(-dir, delta)
	elif _aim_time <= 0.0:
		_strafe_t -= delta
		if _strafe_t <= 0.0:
			_strafe_t = randf_range(1.0, 2.5)
			_strafe = [-1.0, 0.0, 1.0].pick_random()
		if _strafe != 0.0:
			want = steer(dir.cross(Vector3.UP) * _strafe, delta) * 0.6
	velocity = velocity.lerp(want * SPEED, minf(1.0, delta * 10.0))
	move_and_slide()
	global_position.y = 0.0
	if want.length() > 0.1:
		_walk += delta * 11.0
	_legs[0].rotation.x = sin(_walk) * 0.7
	_legs[1].rotation.x = -sin(_walk) * 0.7
	var face := dir if los else (want if want.length() > 0.1 else -_body.global_basis.z)
	_body.rotation.y = lerp_angle(_body.rotation.y, atan2(-face.x, -face.z), minf(1.0, delta * 10.0))
	_attack(delta, los and dist <= attack_range + 2.0, dist)


func _attack(delta: float, can_shoot: bool, dist: float) -> void:
	_cooldown -= delta
	if rpg:
		if _aim_time > 0.0:
			_aim_time -= delta
			var length := maxf(dist - 2.0, 1.0)
			_laser.visible = true
			_laser.position = Vector3(0.3, 1.15, -length * 0.5)
			_laser.scale = Vector3(1, 1, length)
			G.set_neon(_laser, color, 2.0 + 3.0 * absf(sin(_aim_time * 20.0)))
			if _aim_time <= 0.0:
				_laser.visible = false
				_fire("rocket", 16.0, 0.03)
				_cooldown = randf_range(4.5, 6.5)
		elif can_shoot and _cooldown <= 0.0:
			_aim_time = 1.1
	elif _burst > 0:
		_burst_t -= delta
		if _burst_t <= 0.0:
			_burst -= 1
			_burst_t = 0.13
			_fire("enemy_bullet", 26.0, 0.16)
	elif can_shoot and _cooldown <= 0.0:
		_burst = 3
		_cooldown = randf_range(2.8, 4.0)


func _fire(kind: String, projectile_speed: float, spread: float) -> void:
	var target := G.tank.global_position + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-2.0, 2.0))
	var start := global_position + Vector3(0, 1.1, 0)
	var dir := target - start
	dir.y = 0.0
	dir = dir.normalized().rotated(Vector3.UP, randf_range(-spread, spread))
	G.spawn_projectile(start + dir * 0.7, dir * projectile_speed, G.Team.ENEMY, kind, color)
	G.sfx("rocket" if kind == "rocket" else "rifle", -6.0 if kind == "rocket" else -14.0)
