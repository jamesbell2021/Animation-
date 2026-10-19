class_name Props
extends RefCounted
## Set dressing for the island: jetty and rowboat, lobster pots, crates, barrels,
## a washing line, flowers and gulls. All built from primitives.

static func _box(parent: Node, size: Vector3, color: Color, pos: Vector3, rough: float = 0.9) -> MeshInstance3D:
	var mi := Geo.box(parent, size, color, pos)
	mi.material_override = Look.flat_mat(color, rough)
	return mi

static func _cyl(parent: Node, r: float, h: float, color: Color, pos: Vector3, segs: int = 8, top: float = -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.bottom_radius = r
	m.top_radius = r if top < 0.0 else top
	m.height = h
	m.radial_segments = segs
	m.rings = 1
	mi.mesh = m
	mi.material_override = Look.flat_mat(color)
	mi.position = pos
	parent.add_child(mi)
	return mi

## A short timber jetty running out to sea from a point on the shore, with a rowboat tied alongside.
static func jetty(parent: Node, start: Vector3, angle: float) -> void:
	var root := Node3D.new()
	root.name = "Jetty"
	root.position = start + Vector3(0.0, -0.05, 0.0)
	root.rotation.y = angle
	parent.add_child(root)
	var deck_y := Terrain.SEA_LEVEL + 0.45 - root.position.y
	var plank := Color(0.48, 0.40, 0.30)
	for i in 9:
		var z := 0.3 + float(i) * 0.42
		var p := _box(root, Vector3(1.3, 0.07, 0.38), plank.darkened(0.05 * float(i % 3)), Vector3(0.0, lerpf(0.05, deck_y, minf(1.0, float(i) / 2.0)), z))
		p.rotation.y = 0.03 * float((i * 5) % 3 - 1)
	for i in 4:
		var z := 1.1 + float(i) * 0.9
		for side in [-0.6, 0.6]:
			_cyl(root, 0.08, 2.2, Color(0.30, 0.24, 0.18), Vector3(side, deck_y - 0.8, z), 6)
	# Rowboat: a hull from a squashed, open half-box with a bench and oars.
	var boat := Node3D.new()
	boat.position = Vector3(1.4, Terrain.SEA_LEVEL - root.position.y + 0.12, 2.6)
	boat.rotation.y = 0.12
	root.add_child(boat)
	var hull := Color(0.20, 0.32, 0.38)
	_box(boat, Vector3(0.9, 0.12, 2.4), hull.darkened(0.2), Vector3(0.0, 0.0, 0.0))
	for side in [-0.45, 0.45]:
		var s := _box(boat, Vector3(0.08, 0.38, 2.3), hull, Vector3(side, 0.18, 0.0))
		s.rotation.z = side * 0.4
	_box(boat, Vector3(0.9, 0.35, 0.08), hull, Vector3(0.0, 0.18, 1.15))
	var bow := _box(boat, Vector3(0.6, 0.35, 0.08), hull, Vector3(0.0, 0.2, -1.2))
	bow.rotation.x = 0.3
	_box(boat, Vector3(0.85, 0.06, 0.25), Color(0.55, 0.45, 0.33), Vector3(0.0, 0.25, 0.1))
	for side in [-1.0, 1.0]:
		var oar := _box(boat, Vector3(0.05, 0.05, 1.8), Color(0.62, 0.52, 0.38), Vector3(side * 0.3, 0.32, -0.1))
		oar.rotation.y = side * 0.15
	var rope := _cyl(root, 0.015, 1.2, Color(0.6, 0.52, 0.34), Vector3(0.9, deck_y - 0.05, 2.6), 4)
	rope.rotation.z = PI * 0.5

## A lobster pot: a domed creel of net on a wooden base.
static func lobster_pot(parent: Node, pos: Vector3, yaw: float) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = yaw
	parent.add_child(root)
	_box(root, Vector3(0.6, 0.06, 0.45), Color(0.40, 0.31, 0.22), Vector3(0.0, 0.03, 0.0))
	var net := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = 0.22
	m.bottom_radius = 0.22
	m.height = 0.58
	m.radial_segments = 6
	m.rings = 1
	net.mesh = m
	var mat := Look.flat_mat(Color(0.26, 0.34, 0.36), 0.95)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.7
	net.material_override = mat
	net.rotation.z = PI * 0.5
	net.position = Vector3(0.0, 0.2, 0.0)
	root.add_child(net)
	var buoy := _cyl(root, 0.09, 0.14, Color(0.85, 0.35, 0.15), Vector3(0.35, 0.07, 0.2), 6)
	buoy.rotation.x = 0.4

static func crate(parent: Node, pos: Vector3, yaw: float, s: float = 0.55) -> void:
	var c := _box(parent, Vector3(s, s, s), Color(0.50, 0.40, 0.27), pos + Vector3(0.0, s * 0.5, 0.0))
	c.rotation.y = yaw
	for k in 2:
		var slat := _box(c, Vector3(s * 1.02, 0.05, 0.06), Color(0.36, 0.28, 0.19), Vector3(0.0, -s * 0.25 + float(k) * s * 0.5, s * 0.5))
		slat.rotation.z = 0.0

static func barrel(parent: Node, pos: Vector3, color: Color = Color(0.40, 0.29, 0.18)) -> void:
	_cyl(parent, 0.3, 0.8, color, pos + Vector3(0.0, 0.4, 0.0), 8)
	for y in [0.15, 0.65]:
		_cyl(parent, 0.31, 0.05, Color(0.16, 0.16, 0.17), pos + Vector3(0.0, y, 0.0), 8)

## Two poles and a sagging line with washing on it.
static func washing_line(parent: Node, a: Vector3, b: Vector3) -> void:
	var wood := Color(0.40, 0.31, 0.21)
	_cyl(parent, 0.05, 1.9, wood, a + Vector3(0.0, 0.95, 0.0), 5)
	_cyl(parent, 0.05, 1.9, wood, b + Vector3(0.0, 0.95, 0.0), 5)
	var colors := [Color(0.85, 0.82, 0.74), Color(0.22, 0.28, 0.42), Color(0.55, 0.20, 0.18), Color(0.30, 0.40, 0.25)]
	var n := 4
	for i in n:
		var t := (float(i) + 0.5) / float(n)
		var p := a.lerp(b, t) + Vector3(0.0, 1.75 - sin(t * PI) * 0.12, 0.0)
		var cloth := _box(parent, Vector3(0.42, 0.55, 0.03), colors[i % colors.size()], p - Vector3(0.0, 0.3, 0.0), 1.0)
		cloth.look_at_from_position(cloth.position, cloth.position + (b - a).cross(Vector3.UP), Vector3.UP)
	var seg := 6
	for i in seg:
		var t0 := float(i) / float(seg)
		var t1 := float(i + 1) / float(seg)
		var p0 := a.lerp(b, t0) + Vector3(0.0, 1.8 - sin(t0 * PI) * 0.12, 0.0)
		var p1 := a.lerp(b, t1) + Vector3(0.0, 1.8 - sin(t1 * PI) * 0.12, 0.0)
		var line := _box(parent, Vector3(0.015, 0.015, p0.distance_to(p1)), Color(0.8, 0.78, 0.7), (p0 + p1) * 0.5)
		line.look_at_from_position(line.position, p1, Vector3.UP)

## Clumps of heather, sea thrift and buttercups through the grass.
static func flowers(parent: Node, count: int) -> void:
	var palette := [Color(0.55, 0.32, 0.62), Color(0.88, 0.50, 0.66), Color(0.95, 0.85, 0.30), Color(0.92, 0.92, 0.88)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	for k in palette.size():
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var stem := Color(0.16, 0.26, 0.08)
		var head: Color = palette[k]
		for i in 4:
			var a := TAU * float(i) / 4.0 + 0.4
			var base := Vector3(cos(a), 0.0, sin(a)) * 0.07
			var top := base * 1.6 + Vector3(0.0, 0.2 + 0.05 * float(i % 2), 0.0)
			st.set_color(stem)
			st.add_vertex(base - Vector3(0.01, 0, 0))
			st.set_color(stem)
			st.add_vertex(base + Vector3(0.01, 0, 0))
			st.set_color(stem)
			st.add_vertex(top)
			# A small flat flower head on each stem.
			for j in 3:
				var b := TAU * float(j) / 3.0
				st.set_color(head)
				st.add_vertex(top)
				st.set_color(head)
				st.add_vertex(top + Vector3(cos(b), 0.3, sin(b)) * 0.05)
				st.set_color(head)
				st.add_vertex(top + Vector3(cos(b + 2.1), 0.3, sin(b + 2.1)) * 0.05)
		st.generate_normals()
		var mesh := st.commit()
		var xforms: Array[Transform3D] = []
		var clumps := count / palette.size()
		for c in clumps:
			var ca := rng.randf() * TAU
			var cr := rng.randf_range(4.0, 14.2)
			var centre := Vector3(sin(ca) * cr, 0.0, cos(ca) * cr)
			for f in 7:
				var p := centre + Vector3(rng.randf_range(-0.6, 0.6), 0.0, rng.randf_range(-0.6, 0.6))
				if not Terrain.is_grassy(p.x, p.z):
					continue
				p.y = Terrain.height_at_v(p)
				xforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.3)), p))
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = xforms.size()
		for i in xforms.size():
			mm.set_instance_transform(i, xforms[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/grass.gdshader")
		mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mmi)

## A gull: two flapping wings on a little body, circling.
static func gull(parent: Node, seed_value: int) -> Node3D:
	var g := Gull.new()
	g.seed_value = seed_value
	parent.add_child(g)
	return g

## Stakes and a sagging rope along the outer edge of the crag ledge, so the way up reads from above.
static func ledge_rope(parent: Node, from_s: float, to_s: float, posts: int) -> void:
	var wood := Color(0.36, 0.27, 0.18)
	var prev := Vector3.INF
	for i in posts:
		var s := lerpf(from_s, to_s, float(i) / float(posts - 1))
		var a := deg_to_rad(Terrain.LEDGE_START + s * Terrain.LEDGE_SWEEP)
		var r := Terrain.ledge_radius(s) + Terrain.LEDGE_HALF - 0.2
		var base := Vector3(sin(a) * r, Terrain.ledge_height(s), cos(a) * r)
		_cyl(parent, 0.07, 0.9, wood, base + Vector3(0.0, 0.45, 0.0), 5)
		var top := base + Vector3(0.0, 0.8, 0.0)
		if prev != Vector3.INF:
			var mid := (prev + top) * 0.5 - Vector3(0.0, 0.12, 0.0)
			for seg in [[prev, mid], [mid, top]]:
				var p0: Vector3 = seg[0]
				var p1: Vector3 = seg[1]
				var line := _box(parent, Vector3(0.035, 0.035, p0.distance_to(p1)), Color(0.62, 0.53, 0.36), (p0 + p1) * 0.5)
				line.look_at_from_position(line.position, p1, Vector3.UP)
		prev = top
