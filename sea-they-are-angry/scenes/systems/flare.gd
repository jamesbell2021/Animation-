class_name Flare
extends Node3D
## A distress flare from the keeper's gun: arcs out to where it was aimed, strikes
## whatever it lands on, then burns red on the ground for a while. The light holds
## creatures off like the lamp's wide beam, and shows them through ink and dark.

const FLIGHT_TIME := 0.7
const ARC := 3.0
const HIT_R := 1.0
const HIT_DMG := 40
const BURN_TIME := 8.0
const LIGHT_R := 3.5
const COLOR := Color(1.0, 0.32, 0.18)

var from := Vector3.ZERO
var to := Vector3.ZERO
var _t := 0.0
var _landed := false
var _light: OmniLight3D
var _core: MeshInstance3D
var _smoke: GPUParticles3D

func _ready() -> void:
	global_position = from
	_core = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.09
	sm.height = 0.18
	sm.radial_segments = 6
	sm.rings = 3
	_core.mesh = sm
	_core.material_override = Look.eye_mat(COLOR, 12.0)
	add_child(_core)
	Look.glint(self, Vector3.ZERO, COLOR, 1.6)
	_light = OmniLight3D.new()
	_light.light_color = COLOR
	_light.omni_range = 9.0
	_light.omni_attenuation = 0.8
	_light.light_energy = 6.0
	_light.light_volumetric_fog_energy = 1.5
	add_child(_light)
	_smoke = FX.emitter(self, global_position, FX._puff_mesh_ref(), Color(0.85, 0.55, 0.5, 0.35),
		24, 1.6, Vector3.UP, 15.0, 0.4, 1.0, -0.1, 0.25, 0.7, false, false)
	Audio.sfx("flare_shot", from, 0.0, 0.1)

func _physics_process(delta: float) -> void:
	_t += delta
	if not _landed:
		var k := clampf(_t / FLIGHT_TIME, 0.0, 1.0)
		global_position = from.lerp(to, k) + Vector3(0.0, sin(k * PI) * ARC, 0.0)
		if k >= 1.0:
			_land()
		return
	var left := BURN_TIME - (_t - FLIGHT_TIME)
	_light.light_energy = (5.5 + 1.5 * sin(_t * 31.0) * sin(_t * 13.0)) * clampf(left, 0.0, 1.0)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and e.has_method("in_light") and Geo.flat_dist(e.global_position, global_position) <= LIGHT_R:
			e.lit_this_frame = true
			e.inked = 0.0
			e.in_light(Lamp.Mode.WIDE, delta)
	if left <= 0.0:
		queue_free()

func _land() -> void:
	_landed = true
	global_position = to + Vector3(0.0, 0.15, 0.0)
	_light.position.y = 0.8
	Audio.sfx("sizzle", to, 0.0, 0.1)
	FX.sparks(get_parent(), to + Vector3(0.0, 0.2, 0.0))
	var best: Enemy = null
	var best_d := HIT_R
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Enemy) or e.hp <= 0:
			continue
		var d := Geo.flat_dist(e.global_position, to)
		if d <= best_d and absf(e.global_position.y - to.y) < 2.5:
			best = e
			best_d = d
	if best != null:
		best.last_hit = "flare"
		best.take_damage(HIT_DMG, Vector3.ZERO, null)
		FX.burst(get_parent(), to + Vector3(0.0, 0.8, 0.0))
