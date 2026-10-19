class_name Shed
extends Structure
## The oil and tool store beside the cottage. Creatures that raid the homestead batter it.

const WIDTH := 2.4
const DEPTH := 2.0
const WALL_H := 1.6
const STONE := Color(0.44, 0.43, 0.40)

var _wall_mat: StandardMaterial3D
var _roof: MeshInstance3D
var _door: MeshInstance3D

func _init() -> void:
	id = "shed"
	max_hp = 120

func _build() -> void:
	_wall_mat = Look.flat_mat(STONE)
	var walls := Geo.box(self, Vector3(WIDTH, WALL_H, DEPTH), Color.WHITE, Vector3(0.0, WALL_H * 0.5, 0.0))
	walls.material_override = _wall_mat
	_roof = Geo.box(self, Vector3(2.7, 0.12, 2.4), Color.WHITE, Vector3(0.0, 1.75, 0.0))
	_roof.material_override = Look.flat_mat(Color(0.20, 0.22, 0.25), 0.6)
	_roof.rotation.x = deg_to_rad(-12.0)
	_door = Geo.box(self, Vector3(0.75, 1.25, 0.08), Color(0.30, 0.22, 0.14), Vector3(0.2, 0.62, -1.03))
	var barrel := Geo.cyl(self, 0.28, 0.8, Color.WHITE, Vector3(-0.85, 0.4, -1.35))
	barrel.material_override = Look.flat_mat(Color(0.18, 0.2, 0.22), 0.5)
	Geo.box_shape(self, Vector3(WIDTH, WALL_H, DEPTH), Vector3(0.0, WALL_H * 0.5, 0.0))

func _refresh() -> void:
	if _wall_mat == null:
		return
	var hurt := 1.0 - health_ratio()
	_wall_mat.albedo_color = Color(0.26, 0.25, 0.24).lerp(STONE, health_ratio())
	_roof.rotation = Vector3(deg_to_rad(-12.0) - hurt * 0.2, 0.0, hurt * 0.25)
	_roof.position.y = 1.75 - hurt * 0.3
	# The door hangs off one hinge, then off both.
	_door.rotation.z = hurt * 0.6
	_door.position.x = 0.2 + hurt * 0.2

func smoke_point() -> Vector3:
	return Vector3(0.0, WALL_H + 0.2, 0.0)

func display_name() -> String:
	return "shed"

func surface_distance(p: Vector3) -> float:
	var local := to_local(p)
	var dx := maxf(0.0, absf(local.x) - WIDTH * 0.5)
	var dz := maxf(0.0, absf(local.z) - DEPTH * 0.5)
	return Vector2(dx, dz).length()
