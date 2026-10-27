class_name LineBuilder
extends RefCounted
## Collects coloured line segments and bakes them into an ArrayMesh (PRIMITIVE_LINES).
## Every glowing edge in the game is drawn through this (the same approach as Rust & Iron).

var verts: PackedVector3Array = PackedVector3Array()
var colors: PackedColorArray = PackedColorArray()
## Applied to every point added, so a part can be built in its own frame.
var xf: Transform3D = Transform3D.IDENTITY


func line(a: Vector3, b: Vector3, color: Color) -> void:
	verts.append(xf * a)
	verts.append(xf * b)
	colors.append(color)
	colors.append(color)


func polyline(points: PackedVector3Array, color: Color, closed: bool = false) -> void:
	for i: int in range(points.size() - 1):
		line(points[i], points[i + 1], color)
	if closed and points.size() > 2:
		line(points[points.size() - 1], points[0], color)


func circle(center: Vector3, radius: float, axis_a: Vector3, axis_b: Vector3, color: Color, segments: int = 24) -> void:
	var pts: PackedVector3Array = PackedVector3Array()
	for i: int in range(segments):
		var t: float = TAU * float(i) / float(segments)
		pts.append(center + (axis_a * cos(t) + axis_b * sin(t)) * radius)
	polyline(pts, color, true)


## The 12 edges of an axis-aligned box (in the builder's frame).
func box(center: Vector3, size: Vector3, color: Color) -> void:
	var h: Vector3 = size * 0.5
	var c: Array[Vector3] = []
	for i: int in range(8):
		c.append(center + Vector3(h.x if (i & 1) else -h.x, h.y if (i & 2) else -h.y, h.z if (i & 4) else -h.z))
	for p: Vector2i in [Vector2i(0, 1), Vector2i(2, 3), Vector2i(4, 5), Vector2i(6, 7), Vector2i(0, 2), Vector2i(1, 3),
			Vector2i(4, 6), Vector2i(5, 7), Vector2i(0, 4), Vector2i(1, 5), Vector2i(2, 6), Vector2i(3, 7)]:
		line(c[p.x], c[p.y], color)


## Returns null when empty (an ArrayMesh with no surfaces makes the renderer complain).
func build_mesh() -> ArrayMesh:
	if verts.is_empty():
		return null
	var mesh: ArrayMesh = ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	return mesh
