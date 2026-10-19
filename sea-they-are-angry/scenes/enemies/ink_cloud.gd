class_name InkCloud
extends Node3D
## A Squid's ink: a dark cloud that hides every creature inside it, unless the beam is on them.

const RADIUS := 4.0
const LIFE := 5.0
const COLOR := Color(0.05, 0.12, 0.16, 0.42)

var _t := 0.0
var _mat: StandardMaterial3D
var _mesh: MeshInstance3D

func _ready() -> void:
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = COLOR
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = RADIUS
	s.height = RADIUS * 1.1
	s.radial_segments = 12
	s.rings = 6
	_mesh.mesh = s
	_mesh.material_override = _mat
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.scale = Vector3.ONE * 0.2
	add_child(_mesh)
	var tw := create_tween()
	tw.tween_property(_mesh, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	FX.emitter(get_parent(), global_position + Vector3(0.0, 0.4, 0.0), FX._puff_mesh_ref(), Color(0.04, 0.1, 0.13, 0.6),
		16, 1.6, Vector3.UP, 90.0, 1.0, 2.5, 0.0, 1.2, 2.2, true, true)

func _physics_process(delta: float) -> void:
	_t += delta
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and Geo.flat_dist(e.global_position, global_position) < RADIUS:
			e.inked = maxf(e.inked, 0.15)
	if _t > LIFE - 1.0:
		_mat.albedo_color.a = COLOR.a * clampf(LIFE - _t, 0.0, 1.0)
	if _t >= LIFE:
		queue_free()
