class_name PaintSplat
extends RefCounted
## Paint left behind by paintballs: flat splats on walls and floors (the oldest
## fade away past a limit) and blobs stuck to the contestants who got hit.

const MAX_SPLATS := 240
const MAX_BLOBS := 18

static var _splats: Array[Node3D] = []
static var _materials: Dictionary = {}
static var _disc: CylinderMesh
static var _blob: SphereMesh


## A splat of [param colour] on the surface at [param pos] facing [param normal],
## [param size] times the usual size.
static func place(parent: Node, pos: Vector3, normal: Vector3, colour: Color, size: float = 1.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	if _disc == null:
		_disc = CylinderMesh.new()
		_disc.top_radius = 0.5
		_disc.bottom_radius = 0.5
		_disc.height = 0.02
		_disc.radial_segments = 10
		_disc.rings = 1
	var splat := Node3D.new()
	splat.name = "PaintSplat"
	splat.add_to_group("paint_splats")
	parent.add_child(splat)
	var up := normal.normalized()
	var side := up.cross(Vector3.UP if absf(up.y) < 0.9 else Vector3.RIGHT).normalized()
	splat.global_basis = Basis(side, up, side.cross(up)).rotated(up, randf() * TAU)
	splat.global_position = pos + up * 0.015
	# A main blob and a few droplets around it.
	for i in range(4):
		var mi := MeshInstance3D.new()
		mi.mesh = _disc
		mi.material_override = _material(colour)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var s := (randf_range(0.8, 1.5) if i == 0 else randf_range(0.15, 0.4)) * size
		mi.scale = Vector3(s * randf_range(0.8, 1.2), 1.0, s)
		if i > 0:
			var a := randf() * TAU
			mi.position = Vector3(cos(a) * randf_range(0.6, 1.1) * size, 0.003 * float(i), sin(a) * randf_range(0.6, 1.1) * size)
		splat.add_child(mi)
	_splats.append(splat)
	while _splats.size() > MAX_SPLATS:
		var old: Node3D = _splats.pop_front()
		if is_instance_valid(old):
			old.queue_free()


## A blob of paint stuck on [param contestant]'s body.
static func stick(contestant: Contestant, colour: Color) -> void:
	if contestant == null:
		return
	var visuals := contestant.get_visuals()
	if visuals == null or visuals.rig == null:
		return
	if _blob == null:
		_blob = SphereMesh.new()
		_blob.radius = 0.21
		_blob.height = 0.14
		_blob.radial_segments = 8
		_blob.rings = 4
	var count := 0
	for child in visuals.rig.get_children():
		if child.is_in_group("paint_blobs"):
			count += 1
	if count >= MAX_BLOBS:
		return
	var a := randf() * TAU
	var y := randf_range(0.35, 1.1)
	var normal := Vector3(sin(a), 0.0, cos(a))
	var mi := MeshInstance3D.new()
	mi.mesh = _blob
	mi.material_override = _material(colour)
	mi.add_to_group("paint_blobs")
	# Flat side against the body (the blob's local Y points out along the normal).
	var side := normal.cross(Vector3.UP).normalized()
	var basis := Basis(side, normal, side.cross(normal)).scaled(Vector3.ONE * randf_range(0.9, 1.6))
	mi.transform = Transform3D(basis, Vector3(0.0, y, 0.0) + normal * 0.4)
	visuals.rig.add_child(mi)


## Removes every splat and every stuck blob (new battle).
static func clear_all(tree: SceneTree) -> void:
	for node in tree.get_nodes_in_group("paint_splats"):
		node.queue_free()
	for node in tree.get_nodes_in_group("paint_blobs"):
		node.queue_free()
	_splats.clear()


static func _material(colour: Color) -> Material:
	var key := colour.to_html(false)
	if not _materials.has(key):
		var mat := CourseBuilder.make_neon_material(colour, 0.45)
		mat.roughness = 0.2
		_materials[key] = mat
	return _materials[key]
