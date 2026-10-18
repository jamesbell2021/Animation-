class_name Fence
extends Structure

const WOOD := Color(0.40, 0.30, 0.20)
const ROT := Color(0.2, 0.15, 0.1)
const HEIGHT := 1.4
const THICKNESS := 0.3

var length := 4.0
var _meshes: Array[MeshInstance3D] = []
var _mat: StandardMaterial3D
var _shape: CollisionShape3D
var _post_mats: Array[StandardMaterial3D] = []
var _posts: Array[MeshInstance3D] = []
var _post_lean: Array[Vector3] = []
var _stumps: Array[MeshInstance3D] = []
var _braces: Array[MeshInstance3D] = []
var _top_rail: MeshInstance3D
var _low_rail: MeshInstance3D

func _init(p_length: float = 4.0) -> void:
	length = p_length
	id = "fence"
	max_hp = 100

func _stake(x: float, h: float, dy: float, tint: float) -> MeshInstance3D:
	var post := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = 0.085
	m.bottom_radius = 0.1
	m.height = h
	m.radial_segments = 6
	m.rings = 1
	post.mesh = m
	post.material_override = _post_mats[int(tint * 2.99)]
	post.position = Vector3(x, h * 0.5 + dy - 0.08, 0.0)
	add_child(post)
	# Sharpened point.
	var tip := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.0
	tm.bottom_radius = 0.085
	tm.height = 0.26
	tm.radial_segments = 6
	tm.rings = 1
	tip.mesh = tm
	tip.material_override = post.material_override
	tip.position = Vector3(0.0, h * 0.5 + 0.13, 0.0)
	post.add_child(tip)
	return post

func _plank(a: Vector3, b: Vector3, thick: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = Vector3(a.distance_to(b), thick, 0.06)
	mi.mesh = m
	mi.material_override = mat
	mi.position = (a + b) * 0.5
	mi.rotation.z = atan2(b.y - a.y, b.x - a.x)
	add_child(mi)
	return mi

func _build() -> void:
	_mat = Geo.mat(WOOD)
	_post_mats = [Look.flat_mat(Color(0.42, 0.32, 0.21), 0.95), Look.flat_mat(Color(0.52, 0.47, 0.39), 0.95), Look.flat_mat(Color(0.33, 0.25, 0.17), 0.95)]
	var rope := Look.flat_mat(Color(0.55, 0.47, 0.30), 1.0)
	var posts := int(floor(length / 0.9)) + 1
	var step := length / float(posts - 1)
	var tops: Array[float] = []
	for i in posts:
		var x := -length * 0.5 + step * float(i)
		var g := to_global(Vector3(x, 0.0, 0.0))
		var dy := Terrain.height_at(g.x, g.z) - global_position.y
		var h := 1.15 + 0.22 * float((i * 5) % 4) / 3.0
		var post := _stake(x, h, dy, float((i * 7) % 3) / 3.0)
		var lean := Vector3(0.05 * float((i * 7) % 3 - 1), 0.0, 0.06 * float((i * 3) % 3 - 1))
		post.rotation = lean
		_posts.append(post)
		_post_lean.append(lean)
		_meshes.append(post)
		tops.append(dy)
		for ry in [0.45, 0.95]:
			var lash := Geo.box(self, Vector3(0.24, 0.07, 0.24), Color.WHITE, Vector3(x, ry + dy, 0.0))
			lash.material_override = rope
			_meshes.append(lash)
		var stump := _stake(x, 0.35, dy, 0.9)
		stump.rotation = Vector3(0.25 * float((i % 3) - 1), 0.0, 0.3)
		stump.visible = false
		_stumps.append(stump)
	var avg := 0.0
	for t in tops:
		avg += t
	avg /= float(tops.size())
	_low_rail = _plank(Vector3(-length * 0.5, 0.45 + avg, 0.07), Vector3(length * 0.5, 0.45 + avg, 0.07), 0.13, _mat)
	_top_rail = _plank(Vector3(-length * 0.5, 0.95 + avg, 0.07), Vector3(length * 0.5, 0.95 + avg, 0.07), 0.13, _mat)
	_meshes.append(_low_rail)
	_meshes.append(_top_rail)
	# Cross braces on alternate bays.
	for i in range(0, posts - 1, 2):
		var x0 := -length * 0.5 + step * float(i)
		var x1 := x0 + step
		var brace := _plank(Vector3(x0, 0.4 + avg, -0.07), Vector3(x1, 1.0 + avg, -0.07), 0.08, _mat)
		_braces.append(brace)
		_meshes.append(brace)
	_shape = Geo.box_shape(self, Vector3(length, HEIGHT, THICKNESS), Vector3(0.0, HEIGHT * 0.5, 0.0))

func _refresh() -> void:
	if _mat == null:
		return
	var r := health_ratio()
	_mat.albedo_color = ROT.lerp(WOOD, r)
	var standing := hp > 0
	for m in _meshes:
		m.visible = standing
	for st in _stumps:
		st.visible = not standing
	if standing:
		# Damage shows: braces snap first, then the top rail, and the stakes lean.
		for b in _braces:
			b.visible = r > 0.66
		_top_rail.visible = r > 0.4
		var sag := (1.0 - r) * 0.35
		for i in _posts.size():
			_posts[i].rotation = _post_lean[i] + Vector3(sag * (1.0 if i % 2 == 0 else -0.6), 0.0, sag * 0.5)
	_shape.set_deferred("disabled", not standing)

func display_name() -> String:
	return "fence"

# Distance to the fence segment rather than its centre, so a long fence is reachable along its length.
func surface_distance(p: Vector3) -> float:
	var local := to_local(p)
	var dx := maxf(0.0, absf(local.x) - length * 0.5)
	var dz := maxf(0.0, absf(local.z) - THICKNESS * 0.5)
	return Vector2(dx, dz).length()
