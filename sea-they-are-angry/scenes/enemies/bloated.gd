class_name Bloated
extends Enemy
## The Bloated Dead: slow, swollen, walks at the light and bursts.

const BLOAT_TIME := 1.2
const BURST_RADIUS := 3.0
const BURST_STRUCT_DMG := 40
const BURST_PLAYER_DMG := 30
const LIGHT_SLOW := 0.6
const MAX_PULSE := 0.3
const BURST_FX_TIME := 0.25
const BODY_COLOR := Color(0.55, 0.65, 0.5)
const GLOW_COLOR := Color(0.8, 1.0, 0.6)
const HIT_COLOR := Color(0.95, 0.95, 0.9)
const LIT_COLOR := Color(0.9, 0.86, 0.62)
const LIT_HOLD := 0.15
const LIT_FADE := 6.0
const COWER_SCALE := Vector3(1.12, 0.84, 1.12)

var _visual: Node3D
var _body_mat: StandardMaterial3D
var _hit_t := 0.0
var _lit_t := 0.0
var _lit_k := 0.0
var _burst_done := false

func _init() -> void:
	max_hp = 60
	hp = 60
	speed = 1.6
	mass = 2.0
	reach = 3.5

func _build() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var body := Geo.cyl(_visual, 0.55, 1.7, BODY_COLOR, Vector3(0.0, 0.85, 0.0), 0.45)
	_body_mat = body.material_override
	Geo.sphere(_visual, 0.32, Color(0.5, 0.58, 0.46), Vector3(0.0, 1.95, -0.05))
	var arm := Geo.box(_visual, Vector3(0.16, 0.8, 0.16), Color(0.48, 0.56, 0.44), Vector3(0.58, 1.05, -0.1))
	arm.rotation.z = deg_to_rad(12.0)
	Geo.box(_visual, Vector3(0.14, 0.5, 0.14), Color(0.48, 0.56, 0.44), Vector3(-0.55, 1.25, 0.0))
	# Shape bottom sits 0.05 above the body origin so it never snags the island rim.
	Geo.cyl_shape(self, 0.5, 1.7, Vector3(0.0, 0.9, 0.0))

func pick_target() -> Node3D:
	return lighthouse

func in_light(_mode: int, _delta: float) -> void:
	# Either beam mode slows the Bloated; focus does nothing extra (deliberate).
	speed_mult = LIGHT_SLOW
	_lit_t = LIT_HOLD

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if is_bursting() or not is_inside_tree():
		return
	_hit_t = maxf(0.0, _hit_t - delta)
	_lit_t = maxf(0.0, _lit_t - delta)
	# Ease in and out of the lit look so a sweeping beam reads as a wash, not a flicker.
	var lit_target := 1.0 if _lit_t > 0.0 else 0.0
	_lit_k = move_toward(_lit_k, lit_target, LIT_FADE * delta)
	var c := BODY_COLOR.lerp(LIT_COLOR, _lit_k)
	if _hit_t > 0.0:
		c = c.lerp(HIT_COLOR, _hit_t / 0.1)
	_body_mat.albedo_color = c
	# Cower: squat and swell while the light is on it.
	_visual.scale = Vector3.ONE.lerp(COWER_SCALE, _lit_k)

func _on_hit() -> void:
	_hit_t = 0.1

func _enter_Arrived() -> void:
	change_state(&"Bloat")

func is_bursting() -> bool:
	return state == &"Bloat" or state == &"Burst"

func _die() -> void:
	if is_bursting():
		return
	change_state(&"Bloat")

func on_dawn() -> void:
	if is_bursting():
		return
	super.on_dawn()

func _enter_Bloat() -> void:
	velocity = Vector3.ZERO
	_knock = Vector3.ZERO
	_body_mat.emission_enabled = true

func _tick_Bloat(_delta: float) -> void:
	velocity = Vector3.ZERO
	var k := clampf(state_t / BLOAT_TIME, 0.0, 1.0)
	_body_mat.albedo_color = BODY_COLOR.lerp(GLOW_COLOR, k)
	_body_mat.emission = GLOW_COLOR * k * 0.6
	var s := 1.0 + MAX_PULSE * k * absf(sin(state_t * 12.0))
	_visual.scale = Vector3(s, s, s)
	if state_t >= BLOAT_TIME:
		change_state(&"Burst")

func _enter_Burst() -> void:
	if _burst_done:
		return
	_burst_done = true
	velocity = Vector3.ZERO
	var c := global_position
	for s in get_tree().get_nodes_in_group("structures"):
		if s is Structure and s.surface_distance(c) <= BURST_RADIUS:
			s.take_damage(BURST_STRUCT_DMG)
	for p in get_tree().get_nodes_in_group("player"):
		if p is Node3D and Geo.flat_dist(c, p.global_position) <= BURST_RADIUS:
			p.take_damage(BURST_PLAYER_DMG)
	_spawn_burst_fx(c)
	Events.enemy_killed.emit(self)
	queue_free()

func _spawn_burst_fx(at: Vector3) -> void:
	var root := get_parent()
	if root == null:
		return
	var fx := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = 1.0
	m.height = 2.0
	fx.mesh = m
	var mat := Geo.mat(Color(0.7, 1.0, 0.5, 0.35), true)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fx.material_override = mat
	fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(fx)
	fx.global_position = at + Vector3(0.0, 0.8, 0.0)
	fx.scale = Vector3.ONE * 0.1
	var tw := fx.create_tween()
	tw.tween_property(fx, "scale", Vector3.ONE * BURST_RADIUS, BURST_FX_TIME)
	tw.tween_callback(fx.queue_free)
