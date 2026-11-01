class_name ShieldTruck
extends Enemy
## 結界車 Barrier truck. Parks behind the front line and throws a red energy dome over itself and
## everything near it. Shots from outside the dome splash off it until it overloads (it comes
## back a few seconds later), so either pour fire into the dome, or drive the mega tank inside
## it, where nothing is blocked.

const SPEED := 3.0
const DOME_RADIUS := 7.5
const DOME_HP := 70.0
const DOME_REGEN := 9.0
const DOME_DOWN_TIME := 6.0
const STAND_OFF := 22.0

var dome_hp := DOME_HP
var dome_max := DOME_HP
## Seconds the dome stays down after overloading.
var dome_down := 0.0
var _since_hit := 9.0
var _speed := 0.0
var _dish: Node3D
var _dome: MeshInstance3D
var _dome_mat: ShaderMaterial
var _dome_vis := 0.0
var _hit_t := 9.0
var _t := 0.0


func _ready() -> void:
	setup_enemy()
	add_to_group("enemy_domes")
	color = Color(1.0, 0.2, 0.45)
	max_hp = 90.0
	score_value = 150
	var cs := CollisionShape3D.new()
	cs.shape = G.box_shape(Vector3(2.4, 1.8, 4.0))
	cs.position.y = 0.9
	add_child(cs)
	part(self, Vector3(2.0, 0.9, 2.4), Vector3(0, 0.85, 0.6))
	part(self, Vector3(1.9, 1.1, 1.2), Vector3(0, 1.0, -1.3), 2.8)
	for x in [-1.0, 1.0]:
		for z in [-1.4, 0.2, 1.3]:
			part(self, Vector3(0.3, 0.6, 0.6), Vector3(x, 0.3, z), 2.0)
	part(self, Vector3(0.25, 1.0, 0.25), Vector3(0, 1.8, 0.8), 2.4)
	_dish = Node3D.new()
	_dish.position = Vector3(0, 2.35, 0.8)
	add_child(_dish)
	part(_dish, Vector3(1.6, 0.12, 0.5), Vector3.ZERO, 3.4)
	part(_dish, Vector3(0.5, 0.12, 1.6), Vector3.ZERO, 3.4)
	part(_dish, Vector3(0.3, 0.5, 0.3), Vector3(0, 0.3, 0), 4.5)
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 32
	sphere.rings = 16
	_dome = MeshInstance3D.new()
	_dome.mesh = sphere
	_dome_mat = ShaderMaterial.new()
	_dome_mat.shader = load("res://shaders/shield.gdshader")
	_dome_mat.set_shader_parameter("color", Color(1.0, 0.2, 0.4))
	_dome.material_override = _dome_mat
	_dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_dome.scale = Vector3(DOME_RADIUS, DOME_RADIUS * 0.75, DOME_RADIUS)
	add_child(_dome)
	apply_difficulty()
	dome_max = DOME_HP * G.difficulty
	dome_hp = dome_max


func death_lines() -> Array:
	return VoiceLines.TRUCK_DEATH


func die() -> void:
	if dead:
		return
	G.explode(global_position, 3.0, 0.0, G.Team.ENEMY, color)
	G.debris(global_position + Vector3(0, 1, 0), color, Vector3(2.0, 1.5, 2.0))
	if dome_up():
		G.ring(global_position, color, DOME_RADIUS * 1.4, 0.5, 1.0)
	super.die()


func dome_up() -> bool:
	if puppet:
		return _net_aux > -0.5
	return dome_down <= 0.0 and not dead


## Dome strength 0..1, or -1 while it is down (sent to phones in the "aux" slot).
func aux_yaw() -> float:
	return dome_hp / maxf(dome_max, 1.0) if dome_up() else -1.0


## True if a shot travelling from `a` to `b` crosses into the dome from outside.
func blocks(a: Vector3, b: Vector3) -> bool:
	if not dome_up():
		return false
	var c := global_position
	var da := Vector2(a.x - c.x, a.z - c.z).length()
	var db := Vector2(b.x - c.x, b.z - c.z).length()
	return da > DOME_RADIUS and db <= DOME_RADIUS


## True if the dome shields a point from a blast centred outside it.
func protects(target: Vector3, blast: Vector3) -> bool:
	if not dome_up():
		return false
	var c := global_position
	return (Vector2(target.x - c.x, target.z - c.z).length() <= DOME_RADIUS
			and Vector2(blast.x - c.x, blast.z - c.z).length() > DOME_RADIUS)


## A shot splashes off the dome. Host only; phones just show the ripple.
func absorb(amount: float, at: Vector3) -> void:
	dome_hit_fx(at)
	G.sparks(at, color, 6, 5.0, 0.3, 0.12, 0.0)
	G.sfx("dome_hit", -8.0, randf_range(0.9, 1.15))
	_since_hit = 0.0
	dome_hp -= amount
	if dome_hp <= 0.0:
		dome_hp = 0.0
		dome_down = DOME_DOWN_TIME
		G.ring(global_position, color, DOME_RADIUS * 1.5, 0.45, 1.5)
		G.sparks(global_position + Vector3(0, 3, 0), color, 26, 10.0, 0.7, 0.16, -8.0)
		G.sfx("shield_break", -2.0, 0.8)
		G.popup(global_position + Vector3(0, 5, 0), "BARRIER DOWN!", Color(1.0, 0.9, 0.3), 1.0)
		G.add_score(40)


func dome_hit_fx(at: Vector3) -> void:
	Net.send_event("dome_hit", [net_id, at])
	_hit_t = 0.0
	var local := at - global_position
	local.y = 0.0
	_dome_mat.set_shader_parameter("hit_dir", local.normalized() if local.length() > 0.01 else Vector3.FORWARD)


func _process(delta: float) -> void:
	_t += delta
	_dish.rotation.y += delta * 3.0
	_hit_t += delta
	var up := dome_up()
	_dome_vis = move_toward(_dome_vis, 1.0 if up else 0.0, delta * 3.0)
	_dome.visible = _dome_vis > 0.01
	if _dome.visible:
		var strength := clampf(aux_yaw(), 0.0, 1.0) if up else 0.0
		_dome_mat.set_shader_parameter("strength", _dome_vis * (0.55 + 0.45 * strength))
		_dome_mat.set_shader_parameter("charge", strength)
		_dome_mat.set_shader_parameter("hit", maxf(0.0, 1.0 - _hit_t * 3.0))


func _physics_process(delta: float) -> void:
	if dead:
		return
	if puppet:
		puppet_update(delta)
		rotation.y = lerp_angle(rotation.y, _net_yaw, minf(1.0, delta * 8.0))
		return
	_since_hit += delta
	if dome_down > 0.0:
		dome_down -= delta
		if dome_down <= 0.0:
			dome_hp = dome_max * 0.5
			G.sfx("shield_up", -8.0, 0.8)
	elif _since_hit > 3.0:
		dome_hp = minf(dome_max, dome_hp + DOME_REGEN * G.difficulty * delta)
	var tank := G.tank
	if tank == null or tank.dead:
		return
	var to := tank.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	var dir := to / maxf(dist, 0.001)
	var want := Vector3.ZERO
	if dist > STAND_OFF + 4.0:
		want = steer(dir, delta)
	elif dist < STAND_OFF - 6.0:
		want = steer(-dir, delta)
	var target_speed := 0.0
	if want.length() > 0.1:
		var ang := (-global_basis.z).signed_angle_to(want, Vector3.UP)
		rotate_y(clampf(ang, -1.6 * delta, 1.6 * delta))
		target_speed = SPEED * maxf(0.0, cos(ang))
	_speed = move_toward(_speed, target_speed, 5.0 * delta)
	velocity = -global_basis.z * _speed
	move_and_slide()
	global_position.y = 0.0
