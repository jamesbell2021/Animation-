class_name Breach
extends Node3D
## A hole punched into the tank deck: burns, drains hull and jams nearby stations
## until a crew member holds ACTION on it.

var deck_pos := Vector2.ZERO
var net_id := 0
var progress := 0.0

var _marks: Array[MeshInstance3D] = []
var _bar: MeshInstance3D
var _t := 0.0


func _ready() -> void:
	for angle in [45.0, -45.0]:
		var m := G.neon_box(self, Vector3(1.0, 0.06, 0.14), Vector3(0, 0.06, 0), Color(1, 0.2, 0.1), 3.0)
		m.rotation_degrees.y = angle
		_marks.append(m)
	_bar = G.neon_box(self, Vector3(1.0, 0.1, 0.1), Vector3(0, 1.5, 0), Color(0.3, 1.0, 0.45), 3.5, false, true)
	_bar.visible = false
	var fire := CPUParticles3D.new()
	fire.amount = 14
	fire.lifetime = 0.6
	fire.local_coords = false
	fire.mesh = G.box_mesh(Vector3.ONE * 0.16)
	fire.material_override = G.additive_material
	fire.direction = Vector3.UP
	fire.spread = 25.0
	fire.initial_velocity_min = 1.5
	fire.initial_velocity_max = 3.0
	fire.gravity = Vector3(0, 1.5, 0)
	fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fire.emission_sphere_radius = 0.3
	fire.scale_amount_min = 0.6
	fire.scale_amount_max = 1.4
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.85, 0.3, 1.0))
	ramp.set_color(1, Color(1.0, 0.15, 0.05, 0.0))
	fire.color_ramp = ramp
	add_child(fire)
	G.sparks(global_position + Vector3(0, 0.3, 0), Color(1, 0.5, 0.1), 10, 5.0)


func _process(delta: float) -> void:
	_t += delta
	var e := 1.2 + 2.5 * absf(sin(_t * 7.0))
	for m in _marks:
		G.set_neon(m, Color(1.0, 0.2, 0.1), e)
	_bar.visible = progress > 0.0
	_bar.scale.x = maxf(progress, 0.03)
