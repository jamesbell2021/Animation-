class_name Searchlight
extends Node3D
## A guard tower's searchlight: an arc lamp in a drum on a yoke, powered by the camp's
## generator from dusk to dawn. Left alone it sweeps slowly back and forth across the
## ground outside its corner of the wire, in its wide beam. A keeper up the tower can
## take it ([E]) and aim it where they like (the mouse, or the stick), and narrow it to
## a hot focused beam that burns, like the lighthouse's. The wide beam slows what it
## catches, the focused one burns it. It draws more from the generator focused.

const WIDE_ANGLE := 16.0
const FOCUS_ANGLE := 6.0
const MAX_RANGE := 34.0
## Where it looks when sweeping, and when a keeper aims along the stick: this far out.
const AUTO_DIST := 13.0
const SWEEP_DEG := 120.0
const SWEEP_RATE := 0.35
const AIM_SHARPNESS := 5.0
## Fuel a second it takes from the generator, wide and focused.
const DRAW_WIDE := 0.1
const DRAW_FOCUSED := 0.2
const ENERGY := 10.0
const CONE_INTENSITY := 0.07
const TIN := Color(0.27, 0.31, 0.27)
## Research: silvered reflectors reach further and burn harder.
const REFLECT_RANGE := 5.0
const REFLECT_BURN := 1.6
## Research: clockwork tracking follows the nearest creature in its sector, this far out,
## and narrows onto it.
const TRACK_RANGE := 24.0

var generator: Generator
## Which way it looks out from the camp (radians, Node3D yaw: 0 looks -Z).
var home_yaw := 0.0
var operator: Node3D = null
var mode: int = Lamp.Mode.WIDE
## A keeper standing this close (and on its level) can take it.
var reach := 2.2

var _head: Node3D
var _light: SpotLight3D
var _cone: MeshInstance3D
var _cone_mesh: CylinderMesh
var _cone_mat: ShaderMaterial
var _glass: StandardMaterial3D
var _aim := Vector3.INF
var _t := 0.0
var _on := false
## What clockwork tracking has fixed on (no keeper on it), or null.
var tracked: Node3D = null

func _ready() -> void:
	add_to_group("searchlights")
	add_to_group("interactable")
	_t = randf() * 20.0
	var tin := Look.flat_mat(TIN, 0.55)
	tin.metallic = 0.5
	Geo.cyl(self, 0.08, 0.5, Color.WHITE, Vector3(0.0, -0.25, 0.0)).material_override = tin
	_head = Node3D.new()
	add_child(_head)
	var drum := Geo.cyl(_head, 0.3, 0.55, Color.WHITE, Vector3(0.0, 0.0, 0.05))
	drum.rotation.x = PI * 0.5
	drum.material_override = tin
	_glass = Look.glow_mat(Color(0.35, 0.33, 0.28), 0.0)
	var glass := Geo.cyl(_head, 0.26, 0.04, Color.WHITE, Vector3(0.0, 0.0, -0.24))
	glass.rotation.x = PI * 0.5
	glass.material_override = _glass
	_light = SpotLight3D.new()
	_light.light_color = Color(0.92, 0.95, 1.0)
	_light.shadow_enabled = false
	_light.spot_attenuation = 0.5
	_light.light_volumetric_fog_energy = 0.6
	_light.position = Vector3(0.0, 0.0, -0.3)
	_head.add_child(_light)
	_cone_mesh = CylinderMesh.new()
	_cone_mesh.top_radius = 0.2
	_cone_mat = ShaderMaterial.new()
	_cone_mat.shader = load("res://shaders/beam.gdshader")
	_cone_mat.set_shader_parameter("intensity", CONE_INTENSITY)
	_cone = MeshInstance3D.new()
	_cone.mesh = _cone_mesh
	_cone.material_override = _cone_mat
	_cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cone.rotation.x = deg_to_rad(90.0)
	_light.add_child(_cone)
	_set_on(false)

func is_lit() -> bool:
	return _on

func current_angle() -> float:
	return WIDE_ANGLE if mode == Lamp.Mode.WIDE else FOCUS_ANGLE

func toggle_mode() -> void:
	mode = Lamp.Mode.FOCUSED if mode == Lamp.Mode.WIDE else Lamp.Mode.WIDE

func set_operator(k: Node3D) -> void:
	operator = k
	if k == null:
		mode = Lamp.Mode.WIDE

## Where it is pointing right now (a point on the ground).
func aim_point() -> Vector3:
	return _aim

func _night() -> bool:
	return Cycle.phase == Cycle.Phase.DUSK or Cycle.phase == Cycle.Phase.NIGHT

func _set_on(on: bool) -> void:
	_on = on
	_light.visible = on
	_cone.visible = on
	_glass.emission_energy_multiplier = 3.0 if on else 0.0
	_glass.albedo_color = Color(1.0, 0.98, 0.9) if on else Color(0.35, 0.33, 0.28)
	if not on and generator != null:
		generator.set_draw(self, 0.0)

func _physics_process(delta: float) -> void:
	_t += delta
	if operator != null and not is_instance_valid(operator):
		set_operator(null)
	var want := Run.active and _night() and generator != null and generator.has_power()
	if want != _on:
		_set_on(want)
		if want and is_inside_tree():
			Audio.sfx("searchlight", global_position, -8.0, 0.1)
	if not _on:
		return
	if operator == null:
		tracked = _track() if Research.has("tracking") else null
		mode = Lamp.Mode.FOCUSED if tracked != null else Lamp.Mode.WIDE
	var target := _target()
	if _aim == Vector3.INF:
		_aim = target
	_aim = _aim.lerp(target, 1.0 - exp(-delta * AIM_SHARPNESS))
	if _aim.distance_to(global_position) > 0.5:
		_head.look_at(_aim, Vector3.UP)
	var bonus := REFLECT_RANGE if Research.has("reflectors") else 0.0
	var r := clampf(global_position.distance_to(_aim) + 7.0 + bonus, 10.0, MAX_RANGE + bonus)
	var a := current_angle()
	_light.spot_angle = a
	_light.spot_range = r
	_cone_mesh.height = r
	_cone_mesh.bottom_radius = r * tan(deg_to_rad(a))
	_cone.position = Vector3(0.0, 0.0, -r * 0.5)
	var level := generator.power_level()
	_light.light_energy = ENERGY * level * (1.4 if mode == Lamp.Mode.FOCUSED else 1.0)
	_cone_mat.set_shader_parameter("intensity", CONE_INTENSITY * level)
	generator.set_draw(self, DRAW_FOCUSED if mode == Lamp.Mode.FOCUSED else DRAW_WIDE)
	_sweep(delta, r, a)

# Where it should be looking: where its keeper aims, or along its sweep.
func _target() -> Vector3:
	if operator != null:
		var p: Vector3 = operator.lamp_target() if operator.has_method("lamp_target") else Vector3.INF
		if p != Vector3.INF:
			return p
		var d: Vector3 = operator.aim_dir() if operator.has_method("aim_dir") else Vector3.FORWARD
		return _ground(global_position + Vector3(d.x, 0.0, d.z).normalized() * AUTO_DIST)
	if tracked != null:
		return tracked.global_position + Vector3(0.0, 0.5, 0.0)
	var yaw := home_yaw + deg_to_rad(SWEEP_DEG * 0.5) * sin(_t * SWEEP_RATE)
	return _ground(global_position + Vector3(-sin(yaw), 0.0, -cos(yaw)) * AUTO_DIST)

# The nearest living creature in its sector and reach, for clockwork tracking.
func _track() -> Node3D:
	var best: Node3D = null
	var best_d := TRACK_RANGE
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Enemy) or e.hp <= 0 or e.state == &"Emerge":
			continue
		var d: Vector3 = e.global_position - global_position
		var flat := Vector2(d.x, d.z).length()
		if flat >= best_d or flat < 1.0:
			continue
		if absf(angle_difference(home_yaw, atan2(-d.x, -d.z))) > deg_to_rad(SWEEP_DEG * 0.5 + 10.0):
			continue
		best = e
		best_d = flat
	return best

static func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, maxf(Terrain.height_at(p.x, p.z), Terrain.SEA_LEVEL), p.z)

# The same true 3D cone test as the lighthouse's lamp.
func _sweep(delta: float, r: float, a: float) -> void:
	var origin := _light.global_position
	var fwd := -_light.global_transform.basis.z
	var half := deg_to_rad(a)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Node3D) or not e.has_method("in_light"):
			continue
		var probes: Array = e.light_probe_points() if e.has_method("light_probe_points") else [e.global_position]
		for p in probes:
			var to: Vector3 = p - origin
			if to.length() <= r and fwd.angle_to(to) <= half:
				if "lit_this_frame" in e:
					e.lit_this_frame = true
				e.in_light(mode, delta * (REFLECT_BURN if Research.has("reflectors") else 1.0))
				break

# ---- a keeper taking it ----

func interact_prompt() -> String:
	if operator != null:
		return ""
	if not _on:
		return "[E] Take the searchlight  (dark: it needs the generator, from dusk)"
	return "[E] Take the searchlight"

func interact(player: Node) -> bool:
	if operator != null or not player.has_method("man"):
		return false
	player.man(self)
	return true
