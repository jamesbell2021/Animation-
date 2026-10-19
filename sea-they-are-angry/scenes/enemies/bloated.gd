class_name Bloated
extends Enemy
## The Bloated Dead: slow, swollen, walks at the light and bursts.

const BLOAT_TIME := 1.2
const BURST_RADIUS := 3.0
const BURST_STRUCT_DMG := 40
const BURST_PLAYER_DMG := 30
const LIGHT_SLOW := 0.6
const MAX_PULSE := 0.3
const BODY_COLOR := Color(0.40, 0.46, 0.39)
const GLOW_COLOR := Color(0.8, 1.0, 0.6)
const HIT_COLOR := Color(0.95, 0.95, 0.9)
const LIT_COLOR := Color(0.9, 0.86, 0.62)
const BURN_COLOR := Color(1.0, 0.5, 0.2)
const BEAM_DPS := 10.0
const LIT_HOLD := 0.15
const LIT_FADE := 6.0
const COWER_SCALE := Vector3(1.12, 0.84, 1.12)

var _visual: Node3D
var _body_mat: StandardMaterial3D
var _hit_t := 0.0
var _lit_t := 0.0
var _lit_k := 0.0
var _burn_t := 0.0
var _burn_k := 0.0
var _burn_acc := 0.0
var _burst_done := false
var _steam_t := 0.0
var _sizzle_t := 0.0

func _init() -> void:
	max_hp = 60
	hp = 60
	speed = 1.15
	mass = 2.0
	reach = 3.5

func _part_sphere(r: float, scale: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 8
	m.rings = 5
	mi.mesh = m
	mi.material_override = mat
	mi.scale = scale
	mi.position = pos
	_visual.add_child(mi)
	return mi

func _build() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	# Low roughness gives the drowned skin a wet sheen in the lamp light.
	_body_mat = Look.flat_mat(BODY_COLOR, 0.32)
	var limb := Look.flat_mat(Color(0.33, 0.39, 0.32), 0.4)
	var weed := Look.flat_mat(Color(0.12, 0.20, 0.10), 0.9)
	# Swollen, hunched torso and a sagging belly.
	_part_sphere(0.6, Vector3(1.0, 1.25, 0.9), Vector3(0.0, 1.0, 0.0), _body_mat)
	_part_sphere(0.45, Vector3(1.0, 0.85, 1.0), Vector3(0.0, 0.72, -0.18), _body_mat)
	# Head slumped forward, with two drowned-lantern eyes that glint in the dark.
	_part_sphere(0.27, Vector3(1.0, 0.9, 1.05), Vector3(0.0, 1.72, -0.28), limb)
	var eye := Look.eye_mat(Color(0.8, 1.0, 0.35))
	_part_sphere(0.06, Vector3.ONE, Vector3(-0.1, 1.76, -0.53), eye)
	_part_sphere(0.06, Vector3.ONE, Vector3(0.1, 1.76, -0.53), eye)
	for side in [-1.0, 1.0]:
		Look.glint(_visual, Vector3(side * 0.1, 1.76, -0.6), Color(0.8, 1.0, 0.35))
	# Long arms hanging to the knees, stubby legs.
	for side in [-1.0, 1.0]:
		var arm := Geo.box(_visual, Vector3(0.16, 0.95, 0.16), Color.WHITE, Vector3(side * 0.62, 0.95, -0.12))
		arm.material_override = limb
		arm.rotation.z = side * deg_to_rad(10.0)
		arm.rotation.x = deg_to_rad(-12.0)
		var leg := Geo.cyl(_visual, 0.15, 0.5, Color.WHITE, Vector3(side * 0.24, 0.25, 0.0), 0.12)
		leg.material_override = limb
	# Strands of kelp and a few barnacles.
	for i in 5:
		var a := float(i) * 1.3
		var strand := Geo.box(_visual, Vector3(0.05, 0.55, 0.02), Color.WHITE, Vector3(sin(a) * 0.5, 0.9 + float(i % 2) * 0.35, cos(a) * 0.45))
		strand.material_override = weed
		strand.rotation.y = a
	for i in 6:
		var a := float(i) * 1.05 + 0.4
		_part_sphere(0.05, Vector3.ONE, Vector3(sin(a) * 0.55, 0.85 + float(i % 3) * 0.25, cos(a) * 0.48), Look.flat_mat(Color(0.75, 0.72, 0.64)))
	# Shape bottom sits 0.05 above the body origin so it never snags the island rim.
	Geo.cyl_shape(self, 0.5, 1.7, Vector3(0.0, 0.9, 0.0))

## Set by the spawner for a group that comes for the cottage, shed and garden instead of the light.
var raid := false

func pick_target() -> Node3D:
	if raid:
		var home := Enemy.nearest_home(global_position)
		if home != null:
			return home
	return lighthouse

func in_light(mode: int, delta: float) -> void:
	# Wide beam slows the Bloated; the focused beam burns it instead.
	if mode != Lamp.Mode.FOCUSED:
		speed_mult = LIGHT_SLOW
		_lit_t = LIT_HOLD
	elif state != &"Emerge" and not is_bursting():
		_burn_t = LIT_HOLD
		_burn_acc += BEAM_DPS * Lamp.dps_mult * delta
		var dmg := floori(_burn_acc)
		if dmg > 0:
			_burn_acc -= float(dmg)
			last_hit = "beam"
			take_damage(dmg, Vector3.ZERO, null)
			# The burn has its own glow; skip the white hit flash it would trigger every tick.
			_hit_t = 0.0
		_steam_t -= delta
		if _steam_t <= 0.0:
			_steam_t = 0.18
			FX.steam(get_parent(), global_position + Vector3(randf_range(-0.3, 0.3), 1.6, randf_range(-0.3, 0.3)))
		_sizzle_t -= delta
		if _sizzle_t <= 0.0:
			_sizzle_t = 0.55
			Audio.sfx("sizzle", global_position, -8.0, 0.2)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if is_bursting() or not is_inside_tree():
		return
	_hit_t = maxf(0.0, _hit_t - delta)
	_lit_t = maxf(0.0, _lit_t - delta)
	_burn_t = maxf(0.0, _burn_t - delta)
	_burn_k = move_toward(_burn_k, 1.0 if _burn_t > 0.0 else 0.0, LIT_FADE * delta)
	# Ease in and out of the lit look so a sweeping beam reads as a wash, not a flicker.
	var lit_target := 1.0 if _lit_t > 0.0 else 0.0
	_lit_k = move_toward(_lit_k, lit_target, LIT_FADE * delta)
	var c := BODY_COLOR.lerp(LIT_COLOR, _lit_k)
	if _burn_k > 0.0:
		var flicker := 0.85 + 0.15 * sin(state_t * 40.0)
		c = c.lerp(BURN_COLOR, _burn_k * flicker)
	if _hit_t > 0.0:
		c = c.lerp(HIT_COLOR, _hit_t / 0.1)
	_body_mat.albedo_color = c
	# Cower: squat and swell while the light is on it.
	_visual.scale = Vector3.ONE.lerp(COWER_SCALE, _lit_k)

func _on_hit() -> void:
	_hit_t = 0.1

func _enter_Arrived() -> void:
	last_hit = "reached"
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
	Audio.sfx("groan", global_position, -2.0, 0.05)
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
	FX.burst(get_parent(), c + Vector3(0.0, 0.9, 0.0))
	Audio.sfx("burst", c, 0.0)
	Events.enemy_killed.emit(self)
	queue_free()
