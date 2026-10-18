class_name RingFx
extends MeshInstance3D
## A flat glowing ring that expands and fades, then frees itself.

var max_radius: float = 3.0
var colour: Color = Color(1.0, 0.6, 0.2)
var duration: float = 0.35

var _age: float = 0.0
var _mat: StandardMaterial3D


func _ready() -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.85
	torus.outer_radius = 1.0
	torus.rings = 24
	torus.ring_segments = 6
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.albedo_color = Color(colour.r * 2.0, colour.g * 2.0, colour.b * 2.0, 0.9)
	torus.material = _mat
	mesh = torus
	scale = Vector3(0.1, 0.1, 0.1)


func _process(delta: float) -> void:
	_age += delta
	var t := clampf(_age / duration, 0.0, 1.0)
	var r := lerpf(0.2, max_radius, 1.0 - pow(1.0 - t, 2.0))
	scale = Vector3(r, 1.0, r)
	_mat.albedo_color.a = 0.9 * (1.0 - t)
	if t >= 1.0:
		queue_free()
