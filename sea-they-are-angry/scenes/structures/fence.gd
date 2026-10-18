class_name Fence
extends Structure

const WOOD := Color(0.45, 0.33, 0.2)
const ROT := Color(0.2, 0.15, 0.1)
const HEIGHT := 1.4
const THICKNESS := 0.3

var length := 4.0
var _meshes: Array[MeshInstance3D] = []
var _mat: StandardMaterial3D
var _shape: CollisionShape3D

func _init(p_length: float = 4.0) -> void:
	length = p_length
	id = "fence"
	max_hp = 100

func _build() -> void:
	_mat = Geo.mat(WOOD)
	var posts := int(floor(length)) + 1
	var step := length / float(posts - 1)
	for i in posts:
		var x := -length * 0.5 + step * float(i)
		_meshes.append(Geo.box(self, Vector3(0.18, 1.3, 0.18), WOOD, Vector3(x, 0.65, 0.0)))
	_meshes.append(Geo.box(self, Vector3(length, 0.12, 0.08), WOOD, Vector3(0.0, 0.45, 0.0)))
	_meshes.append(Geo.box(self, Vector3(length, 0.12, 0.08), WOOD, Vector3(0.0, 0.95, 0.0)))
	for m in _meshes:
		m.material_override = _mat
	_shape = Geo.box_shape(self, Vector3(length, HEIGHT, THICKNESS), Vector3(0.0, HEIGHT * 0.5, 0.0))

func _refresh() -> void:
	if _mat == null:
		return
	_mat.albedo_color = ROT.lerp(WOOD, health_ratio())
	var standing := hp > 0
	for m in _meshes:
		m.visible = standing
	_shape.set_deferred("disabled", not standing)

func display_name() -> String:
	return "fence"

# Distance to the fence segment rather than its centre, so a long fence is reachable along its length.
func surface_distance(p: Vector3) -> float:
	var local := to_local(p)
	var dx := maxf(0.0, absf(local.x) - length * 0.5)
	var dz := maxf(0.0, absf(local.z) - THICKNESS * 0.5)
	return Vector2(dx, dz).length()
