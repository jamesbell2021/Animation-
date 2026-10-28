class_name Gunship
extends Enemy
## Attack helicopter. Circles the mega tank at a distance over the rooftops, rakes it with its
## nose gun and, after painting it with a laser, fires a salvo of four rockets the machine gun can
## shoot down. Tough: it takes a few cannon hits. Shoot at its big ground shadow.

const SPEED := 5.5
const HOVER := 5.5
const ORBIT := 17.0

var _body: Node3D
var _rotor: Node3D
var _tail_rotor: MeshInstance3D
var _laser: MeshInstance3D
var _pods: Array[Node3D] = []
var _orbit := 1.0
var _cooldown := 3.0
var _aim_time := 0.0
var _salvo := 0
var _salvo_t := 0.0
var _burst := 0
var _burst_t := 0.0
var _gun_cd := 2.0
var _t := 0.0


func _ready() -> void:
	setup_enemy()
	color = Color(1.0, 0.35, 0.15)
	max_hp = 150.0
	score_value = 250
	_orbit = [-1.0, 1.0].pick_random()
	_cooldown = randf_range(3.0, 5.0)
	collision_mask = 0  # flies over everything
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 1.6
	cap.height = 7.0
	cs.shape = cap
	cs.position.y = 3.5
	add_child(cs)
	_body = Node3D.new()
	_body.position.y = HOVER
	add_child(_body)
	part(_body, Vector3(1.3, 1.1, 2.6), Vector3(0, 0, -0.2), 2.8)
	part(_body, Vector3(0.9, 0.6, 0.9), Vector3(0, 0.15, -1.6), 3.4).rotation_degrees.x = 25.0
	part(_body, Vector3(0.35, 0.35, 3.0), Vector3(0, 0.2, 2.4), 2.4)
	part(_body, Vector3(0.12, 0.9, 0.6), Vector3(0, 0.6, 3.8), 2.4)
	part(_body, Vector3(2.6, 0.12, 0.35), Vector3(0, -0.35, -0.1), 2.0)
	for side in [-1.0, 1.0]:
		var pod := Node3D.new()
		pod.position = Vector3(side * 1.3, -0.45, -0.3)
		_body.add_child(pod)
		part(pod, Vector3(0.38, 0.38, 1.1), Vector3.ZERO, 3.2)
		_pods.append(pod)
		part(_body, Vector3(0.1, 0.1, 1.8), Vector3(side * 0.45, -0.75, -0.1), 1.8)
	part(_body, Vector3(0.14, 0.14, 0.9), Vector3(0, -0.5, -1.9), 3.6)
	_rotor = Node3D.new()
	_rotor.position.y = 0.8
	_body.add_child(_rotor)
	for a in [0.0, 90.0]:
		part(_rotor, Vector3(7.0, 0.05, 0.3), Vector3.ZERO, 3.0).rotation_degrees.y = a
	_tail_rotor = part(_body, Vector3(0.05, 1.3, 0.2), Vector3(0.12, 0.7, 3.9), 3.0)
	_laser = G.neon_box(_body, Vector3(0.07, 0.07, 1.0), Vector3.ZERO, color, 3.0)
	_laser.visible = false
	# Ground shadow: where its hitbox is.
	G.neon_box(self, Vector3(3.2, 0.03, 3.2), Vector3(0, 0.05, 0), color, 1.2).rotation_degrees.y = 45.0
	G.neon_box(self, Vector3(1.8, 0.03, 1.8), Vector3(0, 0.05, 0), color, 0.8).rotation_degrees.y = 45.0
	apply_difficulty()


func death_lines() -> Array:
	return VoiceLines.HELI_DEATH


func is_aiming() -> bool:
	return _net_aiming if puppet else _aim_time > 0.0


func facing_yaw() -> float:
	return _body.rotation.y


func die() -> void:
	if dead:
		return
	var at := _body.global_position
	G.explode(at, 3.5, 0.0, G.Team.ENEMY, color)
	G.debris(at, color, Vector3(2.5, 1.5, 2.5))
	G.explode(Vector3(at.x, 0.0, at.z), 3.0, 0.0, G.Team.ENEMY, Color(1.0, 0.6, 0.2))
	G.add_shake(0.6)
	super.die()


func _process(delta: float) -> void:
	_t += delta
	_rotor.rotation.y += delta * 26.0
	_tail_rotor.rotation.x += delta * 30.0
	_body.position.y = HOVER + sin(_t * 1.7) * 0.3


func _physics_process(delta: float) -> void:
	if dead:
		return
	if puppet:
		puppet_update(delta)
		_body.rotation.y = lerp_angle(_body.rotation.y, _net_yaw, minf(1.0, delta * 6.0))
		_update_laser(_net_aiming)
		return
	var tank := G.tank
	if tank == null or tank.dead:
		_update_laser(false)
		return
	var to := tank.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	var dir := to / maxf(dist, 0.001)
	var want := dir
	if dist < ORBIT + 6.0:
		want = (dir.cross(Vector3.UP) * _orbit + dir * (dist - ORBIT) * 0.15).normalized()
	var spd := SPEED * (0.4 if _aim_time > 0.0 or _salvo > 0 else 1.0)
	global_position += want * spd * delta
	global_position.y = 0.0
	# Keep inside the arena.
	var lim := City.HALF - 3.0
	global_position.x = clampf(global_position.x, -lim, lim)
	global_position.z = clampf(global_position.z, -lim, lim)
	_body.rotation.y = lerp_angle(_body.rotation.y, atan2(-dir.x, -dir.z), minf(1.0, delta * 3.0))
	_body.rotation.z = lerpf(_body.rotation.z, -0.15 * _orbit, minf(1.0, delta * 2.0))
	_rockets(delta, dist)
	_nose_gun(delta, dist, tank)


func _rockets(delta: float, dist: float) -> void:
	_cooldown -= delta
	if _salvo > 0:
		_salvo_t -= delta
		if _salvo_t <= 0.0:
			_salvo -= 1
			_salvo_t = 0.16
			var pod := _pods[_salvo % _pods.size()]
			var start := pod.global_position
			var target := G.tank.global_position + Vector3(randf_range(-2.0, 2.0), 0, randf_range(-2.5, 2.5))
			var d := target - start
			d.y = 0.0
			G.spawn_projectile(Vector3(start.x, 1.6, start.z), d.normalized() * 17.0, G.Team.ENEMY, "rocket", color)
			G.sfx("rocket", -6.0, 1.1)
	elif _aim_time > 0.0:
		_aim_time -= delta
		_update_laser(true)
		if _aim_time <= 0.0:
			_update_laser(false)
			_salvo = 4
			_salvo_t = 0.0
			_cooldown = randf_range(6.0, 8.0)
	elif dist < 26.0 and _cooldown <= 0.0:
		_aim_time = 1.0


func _nose_gun(delta: float, dist: float, tank: MegaTank) -> void:
	_gun_cd -= delta
	if _burst > 0:
		_burst_t -= delta
		if _burst_t <= 0.0:
			_burst -= 1
			_burst_t = 0.09
			var start := _body.global_position + Vector3(0, -0.5, 0)
			var target := tank.global_position + Vector3(randf_range(-2.0, 2.0), 0, randf_range(-2.5, 2.5))
			var d := target - start
			d.y = 0.0
			G.spawn_projectile(start, d.normalized() * 32.0, G.Team.ENEMY, "enemy_bullet", color)
			G.sfx("rifle", -15.0, 1.2)
	elif dist < 22.0 and _gun_cd <= 0.0 and _aim_time <= 0.0 and _salvo == 0:
		_burst = 6
		_gun_cd = randf_range(2.5, 3.5)


func _update_laser(on: bool) -> void:
	_laser.visible = on and G.tank != null
	if _laser.visible:
		var from := _body.global_position
		var target := G.tank.global_position + Vector3(0, 1.5, 0)
		var length := maxf(from.distance_to(target) - 3.0, 1.0)
		_laser.global_position = from.lerp(target, 0.5 * length / maxf(from.distance_to(target), 0.1))
		_laser.look_at(target, Vector3.UP)
		_laser.scale = Vector3(1, 1, length)
		G.set_neon(_laser, color, 2.0 + 3.0 * absf(sin(_t * 20.0)))
