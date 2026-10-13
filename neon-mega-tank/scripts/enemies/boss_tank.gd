class_name BossTank
extends Enemy
## 鬼戦車 ONI SENSHA - the demon tank boss, every fifth wave. Twin main cannons fire telegraphed
## three-shell salvos, two machine-gun turrets rake the hull, and it launches attack drones.

const SPEED := 2.4
const TURN := 0.6

var _turret: Node3D
var _muzzles: Array[Node3D] = []
var _guns: Array[Node3D] = []
var _laser: MeshInstance3D
var _horns: Array[MeshInstance3D] = []
var _cooldown := 4.0
var _aim_time := 0.0
var _salvo := 0
var _salvo_t := 0.0
var _gun_cd := 1.0
var _drone_cd := 12.0
var _speed := 0.0
var _t := 0.0


func _ready() -> void:
	setup_enemy()
	color = Color(0.95, 0.15, 0.35)
	max_hp = 1500.0
	score_value = 1000
	var cs := CollisionShape3D.new()
	cs.shape = G.box_shape(Vector3(6.6, 3.0, 8.8))
	cs.position.y = 1.5
	add_child(cs)
	var dark := color.darkened(0.3)
	part(self, Vector3(5.6, 1.4, 8.0), Vector3(0, 1.1, 0), 2.4)
	for side in [-1.0, 1.0]:
		part(self, Vector3(1.0, 1.3, 8.8), Vector3(side * 3.2, 0.65, 0), 2.0)
		part(self, Vector3(0.6, 0.6, 1.6), Vector3(side * 2.3, 2.1, 3.2), 2.2)
	part(self, Vector3(5.0, 0.8, 1.0), Vector3(0, 1.0, -4.4), 2.6).rotation_degrees.x = 30.0
	_turret = Node3D.new()
	_turret.position.y = 1.8
	add_child(_turret)
	part(_turret, Vector3(3.4, 1.4, 3.6), Vector3(0, 0.7, 0.3), 2.8)
	part(_turret, Vector3(2.4, 0.5, 2.4), Vector3(0, 1.6, 0.6), 2.2)
	# Oni horns on the turret.
	for side in [-1.0, 1.0]:
		var horn := part(_turret, Vector3(0.35, 1.4, 0.35), Vector3(side * 1.3, 2.3, -0.6), 3.5)
		horn.rotation_degrees.z = -25.0 * side
		_horns.append(horn)
		part(_turret, Vector3(0.4, 0.4, 4.6), Vector3(side * 0.6, 0.8, -3.4), 3.0)
		var m := Node3D.new()
		m.position = Vector3(side * 0.6, 0.8, -5.8)
		_turret.add_child(m)
		_muzzles.append(m)
	part(_turret, Vector3(1.0, 0.25, 0.1), Vector3(0, 1.0, -1.5), 4.0)
	_laser = G.neon_box(_turret, Vector3(0.08, 0.08, 1.0), Vector3.ZERO, color, 3.0)
	_laser.visible = false
	for side in [-1.0, 1.0]:
		var gun := Node3D.new()
		gun.position = Vector3(side * 2.3, 2.5, 2.8)
		add_child(gun)
		part(gun, Vector3(0.6, 0.4, 0.6), Vector3.ZERO, 2.4)
		part(gun, Vector3(0.14, 0.14, 1.4), Vector3(0, 0, -0.8), 3.0)
		_guns.append(gun)
	apply_difficulty()


func death_lines() -> Array:
	return VoiceLines.BOSS_DEATH


func is_aiming() -> bool:
	return _net_aiming if puppet else _aim_time > 0.0


func aux_yaw() -> float:
	return _turret.rotation.y


func die() -> void:
	if dead:
		return
	for i in 6:
		var off := Vector3(randf_range(-3, 3), 1.5, randf_range(-4, 4))
		G.explode(global_position + off, 3.0 + i * 0.4, 0.0, G.Team.ENEMY, color)
	G.add_shake(1.5)
	super.die()


func _process(delta: float) -> void:
	_t += delta
	for h in _horns:
		G.set_neon(h, color, 3.0 + sin(_t * 5.0) * 1.5)


func _physics_process(delta: float) -> void:
	if dead:
		return
	if puppet:
		puppet_update(delta)
		rotation.y = lerp_angle(rotation.y, _net_yaw, minf(1.0, delta * 6.0))
		_turret.rotation.y = lerp_angle(_turret.rotation.y, _net_aux, minf(1.0, delta * 6.0))
		_update_laser(_net_aiming)
		return
	var tank := G.tank
	if tank == null or tank.dead:
		_laser.visible = false
		return
	var to := tank.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	var dir := to / maxf(dist, 0.001)
	var want := Vector3.ZERO
	if dist > 20.0:
		want = steer(dir, delta)
	elif dist < 12.0:
		want = steer(-dir, delta)
	var target_speed := 0.0
	if want.length() > 0.1:
		var ang := (-global_basis.z).signed_angle_to(want, Vector3.UP)
		rotate_y(clampf(ang, -TURN * delta, TURN * delta))
		target_speed = SPEED * maxf(0.0, cos(ang))
	_speed = move_toward(_speed, target_speed, 3.0 * delta)
	velocity = -global_basis.z * _speed
	move_and_slide()
	global_position.y = 0.0
	# The boss bulldozes buildings in its way.
	for i in get_slide_collision_count():
		var b := get_slide_collision(i).get_collider() as Block
		if b:
			b.take_damage(80.0 * delta, global_position, G.Team.PLAYER)

	var diff := wrapf(atan2(-dir.x, -dir.z) - _turret.global_rotation.y, -PI, PI)
	_turret.rotation.y += clampf(diff, -0.9 * delta, 0.9 * delta)
	for gun in _guns:
		gun.look_at(tank.global_position + Vector3(0, 1.0, 0), Vector3.UP)
	_main_guns(delta, dist, absf(diff))
	_side_guns(delta, dist, tank)
	_drone_cd -= delta
	if _drone_cd <= 0.0 and G.main:
		_drone_cd = 15.0
		G.main.spawn_quick("drone", global_position + Vector3(0, 0, 0))
		G.main.spawn_quick("drone", global_position + global_basis.x * 3.0)
		G.sfx("wave", -6.0, 1.5)


func _main_guns(delta: float, dist: float, aim_error: float) -> void:
	_cooldown -= delta
	if _salvo > 0:
		_salvo_t -= delta
		if _salvo_t <= 0.0:
			_salvo -= 1
			_salvo_t = 0.3
			# Barrels fire alternately: three shells per salvo.
			var m := _muzzles[_salvo % _muzzles.size()]
			var d := -m.global_basis.z
			d.y = 0.0
			d = d.normalized().rotated(Vector3.UP, randf_range(-0.07, 0.07))
			G.spawn_projectile(m.global_position, d * 24.0, G.Team.ENEMY, "enemy_shell", color)
			G.ring(m.global_position, color, 2.0, 0.25, 3.0)
			G.sfx("enemy_cannon", 2.0, 0.8)
			G.add_shake(0.2)
	elif _aim_time > 0.0:
		_aim_time -= delta
		_update_laser(true)
		if _aim_time <= 0.0:
			_update_laser(false)
			_salvo = 3
			_salvo_t = 0.0
			_cooldown = randf_range(5.0, 6.5)
	elif dist < 30.0 and _cooldown <= 0.0 and aim_error < 0.15:
		_aim_time = 1.0


func _side_guns(delta: float, dist: float, tank: MegaTank) -> void:
	_gun_cd -= delta
	if _gun_cd > 0.0 or dist > 22.0:
		return
	_gun_cd = 0.3
	var gun := _guns[randi() % _guns.size()]
	var d := tank.global_position - gun.global_position
	d.y = 0.0
	d = d.normalized().rotated(Vector3.UP, randf_range(-0.12, 0.12))
	G.spawn_projectile(gun.global_position, d * 30.0, G.Team.ENEMY, "enemy_bullet", color)
	G.sfx("rifle", -14.0, 0.8)


func _update_laser(on: bool) -> void:
	_laser.visible = on and G.tank != null
	if _laser.visible:
		var length := maxf(global_position.distance_to(G.tank.global_position) - 5.0, 1.0)
		_laser.position = Vector3(0, 0.8, -5.8 - length * 0.5)
		_laser.scale = Vector3(1, 1, length)
		G.set_neon(_laser, color, 2.0 + 3.0 * absf(sin(_aim_time * 20.0)))
