class_name CourseBuilder
extends RefCounted
## Static helpers for building low-poly fairground geometry in code.
## All positions are local to the given parent. Sections build along -Z.

const RAINBOW: Array[Color] = [
	Color(1.0, 0.3, 0.3),
	Color(1.0, 0.6, 0.2),
	Color(1.0, 0.9, 0.2),
	Color(0.3, 0.85, 0.4),
	Color(0.25, 0.6, 1.0),
	Color(0.5, 0.35, 0.9),
	Color(0.9, 0.4, 0.8),
]


static func rainbow(index: int) -> Color:
	return RAINBOW[posmod(index, RAINBOW.size())]


static func make_material(colour: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 0.8
	return mat


static func make_box_mesh(size: Vector3, colour: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = make_material(colour)
	mi.mesh = mesh
	return mi


static func make_cylinder_mesh(radius: float, height: float, colour: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.material = make_material(colour)
	mi.mesh = mesh
	return mi


## Solid coloured box with collision.
static func add_box(parent: Node, size: Vector3, pos: Vector3, colour: Color, node_name: String = "Box") -> StaticBody3D:
	if parent == null:
		push_error("CourseBuilder.add_box: parent is null.")
		return null
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.add_child(make_box_mesh(size, colour))
	parent.add_child(body)
	return body


## Box tilted around the X axis to make a ramp. Positive angle raises the far (-Z) end.
static func add_ramp(parent: Node, size: Vector3, pos: Vector3, angle_degrees: float, colour: Color, node_name: String = "Ramp") -> StaticBody3D:
	var body := add_box(parent, size, pos, colour, node_name)
	if body != null:
		body.rotation.x = deg_to_rad(angle_degrees)
	return body


## Solid coloured cylinder (standing upright) with collision.
static func add_cylinder(parent: Node, radius: float, height: float, pos: Vector3, colour: Color, node_name: String = "Cylinder") -> StaticBody3D:
	if parent == null:
		push_error("CourseBuilder.add_cylinder: parent is null.")
		return null
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	shape.shape = cyl
	body.add_child(shape)
	body.add_child(make_cylinder_mesh(radius, height, colour))
	parent.add_child(body)
	return body


## Decorative box with no collision.
static func add_decor_box(parent: Node, size: Vector3, pos: Vector3, colour: Color, node_name: String = "Decor") -> MeshInstance3D:
	if parent == null:
		push_error("CourseBuilder.add_decor_box: parent is null.")
		return null
	var mi := make_box_mesh(size, colour)
	mi.name = node_name
	mi.position = pos
	parent.add_child(mi)
	return mi


## Decorative cylinder with no collision.
static func add_decor_cylinder(parent: Node, radius: float, height: float, pos: Vector3, colour: Color, node_name: String = "Decor") -> MeshInstance3D:
	if parent == null:
		push_error("CourseBuilder.add_decor_cylinder: parent is null.")
		return null
	var mi := make_cylinder_mesh(radius, height, colour)
	mi.name = node_name
	mi.position = pos
	parent.add_child(mi)
	return mi


## Invisible trigger volume.
static func add_area(parent: Node, size: Vector3, pos: Vector3, node_name: String = "Area") -> Area3D:
	if parent == null:
		push_error("CourseBuilder.add_area: parent is null.")
		return null
	var area := Area3D.new()
	area.name = node_name
	area.position = pos
	area.collision_mask = Contestant.AREA_MASK
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	area.add_child(shape)
	parent.add_child(area)
	return area


## Floating 3D text sign.
static func add_sign(parent: Node, text: String, pos: Vector3, colour: Color = Color.WHITE, size: int = 96) -> Label3D:
	if parent == null:
		push_error("CourseBuilder.add_sign: parent is null.")
		return null
	var label := Label3D.new()
	label.text = text
	label.position = pos
	label.font_size = size
	label.modulate = colour
	label.outline_size = 12
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)
	return label


## Row of alternating-colour "bunting" cubes between two points (decorative).
static func add_bunting(parent: Node, from: Vector3, to: Vector3, count: int = 12) -> void:
	if parent == null or count <= 0:
		return
	for i in range(count + 1):
		var t := float(i) / float(count)
		var pos := from.lerp(to, t)
		pos.y -= sin(t * PI) * 0.6
		add_decor_box(parent, Vector3(0.25, 0.35, 0.08), pos, rainbow(i), "Bunting%d" % i)
