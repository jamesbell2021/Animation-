class_name EnemyTank
extends Enemy
## Enemy armour: rolls in along the streets, stops at range, paints a target laser and lobs a shell.
## Heavy tanks (later waves) are slower, much tougher and fire a three-shell salvo.

const SPEED := 3.6
const TURN := 1.4

var _turret: Node3D
var _muzzle: Node3D
var _laser: MeshInstance3D
var _cooldown := 3.0
var _aim_time := 0.0
var _speed := 0.0
var heavy := false
var _salvo := 0
var _salvo_t := 0.0


func _ready() -> void:
	setup_enemy()
	color = Color(0.85, 0.25, 1.0) if heavy else Color(1.0, 0.3, 0.2)
	max_hp = 260.0 if heavy else 110.0
	score_value = 200 if heavy else 75
	_cooldown = randf_range(2.0, 4.0)
	var cs := CollisionShape3D.new()
	cs.shape = G.box_shape(Vector3(2.8, 1.6, 3.9))
	cs.position.y = 0.8
	add_child(cs)
	part(self, Vector3(2.3, 0.8, 3.4), Vector3(0, 0.75, 0))
	for side in [-1.0, 1.0]:
		part(self, Vector3(0.6, 0.75, 3.9), Vector3(side * 1.35, 0.38, 0), 2.0)
	_turret = Node3D.new()
	_turret.position.y = 1.15
	add_child(_turret)
	part(_turret, Vector3(1.4, 0.6, 1.6), Vector3(0, 0.3, 0.1), 2.8)
	part(_turret, Vector3(0.24, 0.24, 2.2), Vector3(0, 0.35, -1.7), 3.0)
	_muzzle = Node3D.new()
	_muzzle.position = Vector3(0, 0.35, -2.9)
	_turret.add_child(_muzzle)
	_laser = G.neon_box(_turret, Vector3(0.06, 0.06, 1.0), Vector3.ZERO, color, 3.0)
	_laser.visible = false
	if heavy:
		part(self, Vector3(2.7, 0.35, 3.0), Vector3(0, 1.3, 0.2), 2.0)
		part(_turret, Vector3(1.8, 0.4, 0.5), Vector3(0, 0.75, 0.6), 2.4)
		part(_turret, Vector3(0.24, 0.24, 2.2), Vector3(0.35, 0.35, -1.7), 3.0)
	apply_difficulty()


func death_lines() -> Array:
	return VoiceLines.TANK_DEATH


func is_aiming() -> bool:
	return _aim_time > 0.0


func die() -> void:
	if dead:
		return
	G.explode(global_position, 3.5, 0.0, G.Team.ENEMY, color)
	G.debris(global_position + Vector3(0, 1, 0), color, Vector3.ONE * 2.0)
	super.die()


func _physics_process(delta: float) -> void:
	if dead:
		return
	var tank := G.tank
	if tank == null or tank.dead:
		_laser.visible = false
		return
	var to := tank.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	var dir := to / maxf(dist, 0.001)
	var los := dist < 28.0 and has_line_of_sight(tank.global_position)
	var want := Vector3.ZERO
	if dist > 19.0 or not los:
		want = steer(dir, delta)
	elif dist < 10.0:
		want = steer(-dir, delta)
	var target_speed := 0.0
	if want.length() > 0.1:
		var fwd := -global_basis.z
		var ang := fwd.signed_angle_to(want, Vector3.UP)
		rotate_y(clampf(ang, -TURN * delta, TURN * delta))
		target_speed = SPEED * (0.7 if heavy else 1.0) * maxf(0.0, cos(ang))
	_speed = move_toward(_speed, target_speed, 6.0 * delta)
	velocity = -global_basis.z * _speed
	move_and_slide()
	global_position.y = 0.0

	var diff := wrapf(atan2(-dir.x, -dir.z) - _turret.global_rotation.y, -PI, PI)
	_turret.rotation.y += clampf(diff, -1.6 * delta, 1.6 * delta)

	_cooldown -= delta
	if _salvo > 0:
		_salvo_t -= delta
		if _salvo_t <= 0.0:
			_salvo -= 1
			_salvo_t = 0.3
			_fire()
	elif _aim_time > 0.0:
		_aim_time -= delta
		var length := maxf(dist - 3.0, 1.0)
		_laser.visible = true
		_laser.position = Vector3(0, 0.35, -2.9 - length * 0.5)
		_laser.scale = Vector3(1, 1, length)
		G.set_neon(_laser, color, 2.0 + 3.0 * absf(sin(_aim_time * 18.0)))
		if _aim_time <= 0.0:
			_laser.visible = false
			_salvo = 3 if heavy else 1
			_salvo_t = 0.0
			_cooldown = randf_range(3.5, 5.0)
	elif los and dist < 26.0 and _cooldown <= 0.0 and absf(diff) < 0.12:
		_aim_time = 0.8


func _fire() -> void:
	var dir := -_muzzle.global_basis.z
	dir.y = 0.0
	if heavy:
		dir = dir.rotated(Vector3.UP, randf_range(-0.08, 0.08))
	G.spawn_projectile(_muzzle.global_position, dir.normalized() * 22.0, G.Team.ENEMY, "enemy_shell", color)
	G.ring(_muzzle.global_position, color, 1.3, 0.25, _muzzle.global_position.y)
	G.sfx("enemy_cannon", -2.0)
