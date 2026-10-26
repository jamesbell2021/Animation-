class_name Lamp
extends Node3D
## The single fail axis of the game. If this goes DARK, the run ends.

enum State { OFF, BURNING, GUTTERING, DARK }
enum Mode { WIDE, FOCUSED }

signal state_changed(s: int)
signal smothered_changed(on: bool)

const GUTTER_WINDOW := 25.0
const FUEL_MAX := 100.0
const WIDE_ANGLE := 35.0
const FOCUS_ANGLE := 10.0
const WIDE_RANGE := 26.0
const FOCUS_RANGE := 29.0
const BURN_WIDE := 0.35
const BURN_FOCUSED := 1.0
const UNMANNED_MULT := 0.8
const AUTO_SWEEP_DEG := 20.0
const AIM_SHARPNESS := 6.0
# Tipped down far enough that the focused beam lands on the beaches from the crag top.
const TILT_DEG := -38.0
const BOOST_TIME := 30.0
const BOOST_MULT := 1.3
const ENERGY_SCALE := 5.0
const GUTTER_ENERGY := 0.35
const LOW_HP_FLICKER := 0.3
const CONE_INTENSITY := 0.09
const FOG_ENERGY := 0.45
const GLOW_RANGE := 5.0
# A Smotherer wrapped over the lantern: the light barely gets out.
const SMOTHER_ENERGY := 0.12
const SMOTHER_RANGE := 0.3
# Dirty fuel: a brighter, hotter flame for a while (the sea doesn't like the smell).
const BOOST_DPS := 1.5

## Focused-beam damage multiplier from the lighthouse upgrades (Upgrades.apply sets it).
static var focus_mult := 1.0
## What creatures multiply their beam burn by: the upgrade, and dirty fuel's boost.
static var dps_mult := 1.0

var lighthouse: Structure
var state: int = State.OFF
var mode: int = Mode.WIDE
var fuel: float = FUEL_MAX
var operator: Node3D = null
var yaw: float = 0.0
# On the title screen the lamp sweeps for show: no fuel burn, no effect on creatures.
var showcase := false

var _pivot: Node3D
var _light: SpotLight3D
var _cone: MeshInstance3D
var _cone_mesh: CylinderMesh
var _cone_mat: ShaderMaterial
var _glow: OmniLight3D
var _gutter_t := 0.0
var _boost_t := 0.0
var _flicker_t := 0.0
var _smothered := 0

func _ready() -> void:
	fuel = Run.lamp_fuel
	_pivot = Node3D.new()
	add_child(_pivot)
	_light = SpotLight3D.new()
	_light.rotation.x = deg_to_rad(TILT_DEG)
	_light.light_color = Color(1.0, 0.8, 0.5)
	_light.shadow_enabled = true
	_light.spot_attenuation = 0.6
	_light.light_volumetric_fog_energy = FOG_ENERGY
	_pivot.add_child(_light)
	_glow = OmniLight3D.new()
	_glow.light_color = Color(1.0, 0.72, 0.4)
	_glow.omni_range = GLOW_RANGE
	_glow.light_volumetric_fog_energy = 2.0
	add_child(_glow)
	_cone_mesh = CylinderMesh.new()
	_cone_mesh.top_radius = 0.05
	_cone_mat = ShaderMaterial.new()
	_cone_mat.shader = load("res://shaders/beam.gdshader")
	_cone_mat.set_shader_parameter("intensity", CONE_INTENSITY)
	_cone = MeshInstance3D.new()
	_cone.mesh = _cone_mesh
	_cone.material_override = _cone_mat
	_cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# CylinderMesh apex (+Y) is rotated onto +Z; the mesh is then pushed down -Z so the apex sits at the light.
	_cone.rotation.x = deg_to_rad(90.0)
	_light.add_child(_cone)
	_apply_mode()
	_update_visibility()
	Cycle.phase_changed.connect(_on_phase_changed)
	if lighthouse:
		lighthouse.destroyed.connect(_on_lighthouse_destroyed)

func current_angle() -> float:
	return WIDE_ANGLE if mode == Mode.WIDE else FOCUS_ANGLE

func current_range() -> float:
	var r: float = (WIDE_RANGE if mode == Mode.WIDE else FOCUS_RANGE) + Upgrades.pick("lighthouse", Upgrades.RANGE_BONUS)
	return r * SMOTHER_RANGE if is_smothered() else r

## Something is wrapped over the lantern (counted, in case more than one is up there).
func smother(on: bool) -> void:
	var was := is_smothered()
	_smothered = maxi(0, _smothered + (1 if on else -1))
	if was != is_smothered():
		_apply_mode()
		smothered_changed.emit(is_smothered())

func is_smothered() -> bool:
	return _smothered > 0

func is_lit() -> bool:
	return state == State.BURNING or state == State.GUTTERING

func burn_rate() -> float:
	var rate := BURN_WIDE if mode == Mode.WIDE else BURN_FOCUSED
	if operator == null:
		rate *= UNMANNED_MULT
	return rate * Upgrades.pick("lighthouse", Upgrades.BURN_MULT)

func _apply_mode() -> void:
	var a := current_angle()
	var r := current_range()
	_light.spot_angle = a
	_light.spot_range = r
	_cone_mesh.height = r
	_cone_mesh.bottom_radius = r * tan(deg_to_rad(a))
	_cone.position = Vector3(0.0, 0.0, -r * 0.5)

func toggle_mode() -> void:
	mode = Mode.FOCUSED if mode == Mode.WIDE else Mode.WIDE
	_apply_mode()

func set_operator(p: Node3D) -> void:
	operator = p
	if p == null:
		mode = Mode.WIDE
		_apply_mode()

func _on_phase_changed(p: int) -> void:
	if state == State.DARK:
		return
	if p == Cycle.Phase.DUSK:
		if lighthouse and lighthouse.is_destroyed():
			_set_state(State.GUTTERING)
		elif fuel <= 0.0:
			_set_state(State.GUTTERING)
		else:
			_set_state(State.BURNING)
	elif p == Cycle.Phase.DAWN:
		_set_state(State.OFF)

func _on_lighthouse_destroyed() -> void:
	if state == State.BURNING:
		_set_state(State.GUTTERING)

## LAN, on a client: where the host has the lamp pointing.
var _net_yaw := 0.0

func net_apply(a: Array) -> void:
	_net_yaw = float(a[0])
	if int(a[1]) != state:
		# As _set_state, but the host decides when the lamp has gone dark for good.
		state = int(a[1])
		_update_visibility()
		state_changed.emit(state)
		Events.lamp_state_changed.emit(state)
	if int(a[2]) != mode:
		mode = int(a[2])
		_apply_mode()
	fuel = float(a[3])
	if int(a[4]) != _smothered:
		var was := is_smothered()
		_smothered = int(a[4])
		if was != is_smothered():
			_apply_mode()
			smothered_changed.emit(is_smothered())

func _physics_process(delta: float) -> void:
	if not is_lit():
		return
	if Net.is_client() and Net.playing():
		# A client's lamp turns as the host's does; its beam still lights what it falls on.
		yaw = lerp_angle(yaw, _net_yaw, 1.0 - exp(-delta * Net.FOLLOW))
		_pivot.rotation.y = yaw
		_sweep(delta)
		_flicker(delta)
		return
	if showcase:
		_aim(delta)
		_flicker(delta)
		return
	if not Run.active:
		return
	if operator != null and not is_instance_valid(operator):
		set_operator(null)
	_aim(delta)
	_burn(delta)
	if not is_lit():
		return
	_sweep(delta)
	_flicker(delta)

func _aim(delta: float) -> void:
	if operator != null and operator.has_method("aim_yaw"):
		var want: float = operator.aim_yaw()
		# A mouse gives a point on the ground: aim from the lamp itself, not from the keeper beside it.
		if operator.has_method("lamp_target"):
			var t: Vector3 = operator.lamp_target()
			if t != Vector3.INF:
				var d := t - global_position
				if Vector2(d.x, d.z).length() > 0.5:
					want = atan2(-d.x, -d.z)
		yaw = lerp_angle(yaw, want, 1.0 - exp(-delta * AIM_SHARPNESS))
	else:
		yaw = wrapf(yaw + deg_to_rad(AUTO_SWEEP_DEG) * delta, -PI, PI)
	_pivot.rotation.y = yaw

func _burn(delta: float) -> void:
	if _boost_t > 0.0:
		_boost_t = maxf(0.0, _boost_t - delta)
	Lamp.dps_mult = focus_mult * (BOOST_DPS if _boost_t > 0.0 else 1.0)
	if state == State.GUTTERING:
		_gutter_t += delta
		if _gutter_t >= GUTTER_WINDOW:
			_set_state(State.DARK)
		return
	fuel = maxf(0.0, fuel - burn_rate() * delta)
	if fuel <= 0.0:
		_set_state(State.GUTTERING)

func _sweep(delta: float) -> void:
	# True 3D cone test, so only what the player can see lit is affected.
	# The lamp is high and tilted, so it cannot reach the ground near its own base.
	var origin := _light.global_position
	var fwd := -_light.global_transform.basis.z
	var r := current_range()
	var half := deg_to_rad(current_angle())
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Node3D) or not e.has_method("in_light"):
			continue
		var probes: Array = []
		if e.has_method("light_probe_points"):
			probes = e.light_probe_points()
		else:
			probes = [e.global_position]
		for p in probes:
			var to: Vector3 = p - origin
			if to.length() <= r and fwd.angle_to(to) <= half:
				if "lit_this_frame" in e:
					e.lit_this_frame = true
				e.in_light(mode, delta)
				break

func _flicker(delta: float) -> void:
	_flicker_t += delta
	var base := 1.0 if state == State.BURNING else GUTTER_ENERGY
	var low_hp := lighthouse != null and lighthouse.health_ratio() < LOW_HP_FLICKER
	if state == State.GUTTERING or low_hp:
		var n := 0.8 + 0.2 * sin(_flicker_t * 37.0) * sin(_flicker_t * 13.0 + 1.3) + randf_range(-0.2, 0.2)
		base *= clampf(n, 0.2, 1.2)
	if _boost_t > 0.0:
		base *= BOOST_MULT
	if is_smothered():
		base *= SMOTHER_ENERGY
	_light.light_energy = base * ENERGY_SCALE
	_glow.light_energy = base * 1.6
	_cone_mat.set_shader_parameter("intensity", CONE_INTENSITY * base)
	if lighthouse and lighthouse.has_method("set_lantern"):
		lighthouse.set_lantern(base)

func refuel_clean(units: float) -> void:
	fuel = minf(FUEL_MAX, fuel + units)
	_recover()

func refuel_dirty(units: float) -> void:
	fuel = minf(FUEL_MAX, fuel + units)
	_boost_t = BOOST_TIME
	Anger.add(1)
	_recover()

func is_boosted() -> bool:
	return _boost_t > 0.0

func boost_left() -> float:
	return _boost_t

func _recover() -> void:
	if state == State.GUTTERING and fuel > 0.0 and lighthouse != null and lighthouse.hp > 0:
		_set_state(State.BURNING)

func _set_state(s: int) -> void:
	if s == state:
		return
	state = s
	_gutter_t = 0.0
	_update_visibility()
	state_changed.emit(s)
	Events.lamp_state_changed.emit(s)
	if s == State.BURNING and is_inside_tree():
		FX.sparks(self, global_position)
	if s == State.DARK:
		Run.end_run("The lamp went dark.")

func _update_visibility() -> void:
	_light.visible = is_lit()
	_cone.visible = is_lit()
	_glow.visible = is_lit()
	if lighthouse and lighthouse.has_method("set_lantern"):
		lighthouse.set_lantern(1.0 if is_lit() else 0.0)

func gutter_left() -> float:
	if state != State.GUTTERING:
		return GUTTER_WINDOW
	return maxf(0.0, GUTTER_WINDOW - _gutter_t)
