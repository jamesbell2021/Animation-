class_name Buggy
extends Enemy
## Kamikaze buggy: races at the mega tank with a beeping light and detonates next to it.
## Shoot it early - it blows up wherever it dies.

const SPEED := 9.5
const TURN := 3.0
const TRIGGER := 5.0

var _light: MeshInstance3D
var _wheels: Array[MeshInstance3D] = []
var _speed := 0.0
var _beep := 0.0


func _ready() -> void:
	setup_enemy()
	color = Color(1.0, 0.75, 0.1)
	max_hp = 18.0
	score_value = 25
	var cs := CollisionShape3D.new()
	cs.shape = G.box_shape(Vector3(1.6, 1.2, 2.4))
	cs.position.y = 0.6
	add_child(cs)
	part(self, Vector3(1.4, 0.5, 2.2), Vector3(0, 0.6, 0))
	part(self, Vector3(1.0, 0.5, 0.9), Vector3(0, 1.05, 0.3), 2.2)
	part(self, Vector3(0.9, 0.5, 0.5), Vector3(0, 0.75, -0.9), 3.0)
	for x in [-0.8, 0.8]:
		for z in [-0.75, 0.75]:
			_wheels.append(part(self, Vector3(0.3, 0.6, 0.6), Vector3(x, 0.3, z), 2.0))
	_light = G.neon_box(self, Vector3(0.35, 0.25, 0.35), Vector3(0, 1.45, 0.3), Color(1, 0.1, 0.1), 3.0)
	apply_difficulty()


## Blows up: area damage to the mega tank if it is close.
func detonate() -> void:
	if dead:
		return
	G.explode(global_position, 4.0, 22.0 * G.difficulty, G.Team.ENEMY, color)
	die()


func take_damage(amount: float, pos: Vector3, team: int) -> void:
	if dead or team == G.Team.ENEMY or puppet:
		return
	hp -= amount
	G.flash(meshes, 1.0)
	if hp <= 0.0:
		detonate()


func _process(delta: float) -> void:
	_beep -= delta
	var near := G.tank != null and global_position.distance_to(G.tank.global_position) < 14.0
	if _beep <= 0.0:
		_beep = 0.18 if near else 0.5
		G.set_neon(_light, Color(1, 0.1, 0.1), 6.0)
		if near and not puppet:
			G.sfx("station", -10.0, 1.8)
	elif _beep < 0.1:
		G.set_neon(_light, Color(1, 0.1, 0.1), 0.6)
	for w in _wheels:
		w.rotation.x += _speed * delta * 2.0


func _physics_process(delta: float) -> void:
	if dead:
		return
	if puppet:
		_speed = puppet_update(delta)
		rotation.y = lerp_angle(rotation.y, _net_yaw, minf(1.0, delta * 10.0))
		return
	var tank := G.tank
	if tank == null or tank.dead:
		return
	var to := tank.global_position - global_position
	to.y = 0.0
	if to.length() < TRIGGER:
		detonate()
		return
	var want := steer(to.normalized(), delta)
	if want != Vector3.ZERO:
		var ang := (-global_basis.z).signed_angle_to(want, Vector3.UP)
		rotate_y(clampf(ang, -TURN * delta, TURN * delta))
	_speed = move_toward(_speed, SPEED if want != Vector3.ZERO else 2.0, 8.0 * delta)
	velocity = -global_basis.z * _speed
	move_and_slide()
	global_position.y = 0.0
	for i in get_slide_collision_count():
		if get_slide_collision(i).get_collider() is MegaTank:
			detonate()
			return
