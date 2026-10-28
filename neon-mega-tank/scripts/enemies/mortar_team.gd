class_name MortarTeam
extends Enemy
## Two soldiers and a mortar. They hang back behind the buildings (they don't need to see the
## tank), set up, and lob rounds high over the rooftops. A red ring marks where each one will
## land a couple of seconds later: drive out of it or raise the shield. The tank crushes them.

const SPEED := 2.6
const MIN_RANGE := 20.0
const MAX_RANGE := 34.0
const FLIGHT := 2.2

var _tube: MeshInstance3D
var _crew: Array[Node3D] = []
var _cooldown := 3.0
var _walk := 0.0
var _set_up := false


func _ready() -> void:
	setup_enemy()
	color = Color(1.0, 0.45, 0.2)
	max_hp = 28.0
	score_value = 60
	_cooldown = randf_range(2.5, 4.0)
	var cs := CollisionShape3D.new()
	cs.shape = G.box_shape(Vector3(2.2, 1.6, 1.6))
	cs.position.y = 0.8
	add_child(cs)
	part(self, Vector3(1.0, 0.12, 1.0), Vector3(0, 0.06, 0), 2.2)
	# A ring of sandbags makes it read as a gun pit from the isometric camera.
	for i in 7:
		var ang := -PI * 0.75 + i * PI * 1.5 / 6.0
		var bag := part(self, Vector3(0.7, 0.32, 0.36), Vector3(sin(ang), 0.16, cos(ang)) * 1.55, 1.6)
		bag.rotation.y = ang
	_tube = part(self, Vector3(0.32, 0.32, 1.6), Vector3(0, 0.75, 0), 3.8)
	_tube.rotation_degrees.x = 50.0
	part(self, Vector3(0.08, 0.7, 0.08), Vector3(0, 0.4, -0.45), 2.0).rotation_degrees.x = -20.0
	for side in [-1.0, 1.0]:
		var body := Node3D.new()
		body.position = Vector3(side * 0.85, 0, 0.3)
		add_child(body)
		part(body, Vector3(0.45, 0.55, 0.3), Vector3(0, 0.7, 0))
		part(body, Vector3(0.28, 0.28, 0.28), Vector3(0, 1.15, 0))
		part(body, Vector3(0.14, 0.42, 0.14), Vector3(-0.1, 0.21, 0))
		part(body, Vector3(0.14, 0.42, 0.14), Vector3(0.1, 0.21, 0))
		_crew.append(body)
	apply_difficulty()


func crush() -> void:
	if dead:
		return
	G.sparks(global_position + Vector3(0, 0.3, 0), color, 20, 5.0, 0.6)
	G.sfx("crush", -2.0, 1.2)
	die()


func _physics_process(delta: float) -> void:
	if dead:
		return
	if puppet:
		var spd := puppet_update(delta)
		_animate(delta, spd > 0.4)
		rotation.y = lerp_angle(rotation.y, _net_yaw, minf(1.0, delta * 8.0))
		return
	var tank := G.tank
	if tank == null or tank.dead:
		velocity = Vector3.ZERO
		return
	var to := tank.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	var dir := to / maxf(dist, 0.001)
	var want := Vector3.ZERO
	if dist > MAX_RANGE:
		want = steer(dir, delta)
	elif dist < MIN_RANGE:
		want = steer(-dir, delta)
	_set_up = want == Vector3.ZERO
	velocity = velocity.lerp(want * SPEED, minf(1.0, delta * 8.0))
	move_and_slide()
	global_position.y = 0.0
	_animate(delta, want != Vector3.ZERO)
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), minf(1.0, delta * 4.0))
	_cooldown -= delta
	if _set_up and _cooldown <= 0.0 and dist <= MAX_RANGE + 4.0:
		_cooldown = randf_range(4.5, 6.5)
		_fire(tank)


func _animate(delta: float, walking: bool) -> void:
	if walking:
		_walk += delta * 9.0
	for i in _crew.size():
		_crew[i].position.y = absf(sin(_walk + i * 1.5)) * 0.08


func _fire(tank: MegaTank) -> void:
	# Aim where the tank will be when the round comes down, give or take.
	var lead := tank.velocity * FLIGHT * randf_range(0.5, 0.9)
	var scatter := Vector3(randf_range(-2.0, 2.0), 0.0, randf_range(-2.0, 2.0))
	var target := tank.global_position + lead + scatter
	var start := _tube.global_position + Vector3(0, 0.6, 0)
	var shell := MortarShell.new()
	shell.setup(start, target, FLIGHT, color)
	shell.damage = 8.0 * G.difficulty
	G.fx_root.add_child(shell)
	Net.send_event("mortar", [start, shell.to, FLIGHT, color], true)
	G.sparks(start, Color(1, 0.85, 0.5), 8, 5.0, 0.35, 0.12, -6.0)
	G.ring(start, color, 1.4, 0.25, start.y)
	G.sfx("mortar", -2.0)
	var tw := _tube.create_tween()
	tw.tween_property(_tube, "position:y", 0.55, 0.05)
	tw.tween_property(_tube, "position:y", 0.75, 0.35)
