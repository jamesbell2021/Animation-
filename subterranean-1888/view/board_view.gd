class_name BoardView
extends Node3D
## Draws the grid: floor and rock as MultiMeshes (a handful of draw calls for 900 tiles),
## doors, vents, valves, fungus, the lift and the journal as props, flares as lights, and
## two overlay layers (move range / targets, and the light or pheromone map).
## The fog of war is per-instance colour: unexplored black, remembered dim, seen lit.

const WALL_H := 2.4
const SOFT_H := 1.7
const ROCK_VARIANTS := 3

var battle: Battle
var grid: TacGrid

var _floor: MultiMeshInstance3D
var _rocks: Array[MultiMeshInstance3D] = []
var _boulders: MultiMeshInstance3D
var _range_layer: MultiMeshInstance3D
var _info_layer: MultiMeshInstance3D
var _floor_base := PackedColorArray()
var _rock_index: Array = []   # per variant: Array of tile indices drawn by it
var _boulder_tiles: Array[int] = []
var _props: Dictionary = {}   # tile index -> Array of nodes revealed with the tile
var _doors: Dictionary = {}   # tile -> door panel
var _vent_fx: Dictionary = {} # vent tile -> CPUParticles3D
var _valve_wheels: Dictionary = {}
var _flares: Dictionary = {}  # flare id -> Node3D
var _journal: Node3D
var _pings: Array[Node3D] = []
var _cursor: Node3D
var _cursor_mat: StandardMaterial3D
var _vis := PackedByteArray()
var _exp := PackedByteArray()
var _light := PackedFloat32Array()
var _rng := RandomNumberGenerator.new()
var _t := 0.0


func build(b: Battle) -> void:
	battle = b
	grid = b.grid
	_rng.seed = 1888
	_vis = b.visible_tiles.duplicate()
	_exp = b.explored.duplicate()
	_light = grid.light.duplicate()
	_build_floor()
	_build_rocks()
	_build_props()
	_range_layer = _overlay_layer(0.06)
	_info_layer = _overlay_layer(0.035)
	_build_cursor()
	_recolour()


# --- terrain --------------------------------------------------------------------------------

func _build_floor() -> void:
	var n := grid.width * grid.height
	var mesh := BoxMesh.new()
	mesh.size = Vector3(Kit.TILE * 0.985, 0.3, Kit.TILE * 0.985)
	var m := Kit.mat(Color.WHITE, 0.95)
	m.vertex_color_use_as_albedo = true
	mesh.material = m
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = n
	_floor_base.resize(n)
	for i in n:
		var c := grid.cell(i)
		var h := _rng.randf_range(-0.04, 0.03)
		mm.set_instance_transform(i, Transform3D(Basis(), Kit.world(c, -0.15 + h)))
		_floor_base[i] = _floor_colour(grid.terrain[i])
	_floor = MultiMeshInstance3D.new()
	_floor.multimesh = mm
	add_child(_floor)
	# A dark bed under the tiles, so the seams between them read as grout, not as a void.
	var bed := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(grid.width * Kit.TILE + 8.0, grid.height * Kit.TILE + 8.0)
	bed.mesh = plane
	bed.material_override = Kit.mat(Color(0.035, 0.03, 0.028), 1.0)
	bed.position = Vector3((grid.width - 1) * Kit.TILE * 0.5, -0.12, (grid.height - 1) * Kit.TILE * 0.5)
	add_child(bed)


func _floor_colour(t: int) -> Color:
	var j := _rng.randf_range(-0.03, 0.03)
	match t:
		TacGrid.T.LIFT:
			return Color(0.42 + j, 0.33 + j, 0.16)
		TacGrid.T.FUNGUS:
			return Color(0.2 + j, 0.3 + j, 0.27 + j)
		TacGrid.T.RUBBLE:
			return Color(0.36 + j, 0.3 + j, 0.24 + j)
		TacGrid.T.WALL, TacGrid.T.SOFT_ROCK:
			return Color(0.2, 0.18, 0.16)
	return Color(0.33 + j, 0.29 + j, 0.25 + j)


func _build_rocks() -> void:
	for v in ROCK_VARIANTS:
		var mmi := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = _rock_mesh(v)
		mmi.multimesh = mm
		add_child(mmi)
		_rocks.append(mmi)
	var bm := SphereMesh.new()
	bm.radius = 0.75
	bm.height = 1.1
	bm.radial_segments = 7
	bm.rings = 4
	var bmat := Kit.mat(Color.WHITE, 0.9)
	bmat.vertex_color_use_as_albedo = true
	bm.material = bmat
	_boulders = MultiMeshInstance3D.new()
	var bmm := MultiMesh.new()
	bmm.transform_format = MultiMesh.TRANSFORM_3D
	bmm.use_colors = true
	bmm.mesh = bm
	_boulders.multimesh = bmm
	add_child(_boulders)
	_layout_rocks()


## Re-lay rock and boulder instances (after a drill or a blast changes the terrain).
func _layout_rocks() -> void:
	_rock_index = []
	var per: Array = []
	for v in ROCK_VARIANTS:
		_rock_index.append([])
		per.append([])
	_boulder_tiles.clear()
	var boulder_xf: Array[Transform3D] = []
	var r := RandomNumberGenerator.new()
	for i in grid.terrain.size():
		var t := grid.terrain[i]
		var c := grid.cell(i)
		r.seed = i * 7919 + 13
		if t == TacGrid.T.WALL or t == TacGrid.T.SOFT_ROCK:
			var v := r.randi_range(0, ROCK_VARIANTS - 1)
			var h := (WALL_H if t == TacGrid.T.WALL else SOFT_H) * r.randf_range(0.85, 1.2)
			var basis := Basis(Vector3.UP, r.randi_range(0, 7) * PI / 4.0).scaled(Vector3(1.0, h / WALL_H, 1.0))
			(_rock_index[v] as Array).append(i)
			(per[v] as Array).append(Transform3D(basis, Kit.world(c)))
		elif t == TacGrid.T.BOULDER:
			_boulder_tiles.append(i)
			var s := r.randf_range(0.8, 1.05)
			boulder_xf.append(Transform3D(Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(s, s * 0.85, s)), Kit.world(c, 0.35)))
	for v in ROCK_VARIANTS:
		var mm := _rocks[v].multimesh
		var list: Array = per[v]
		mm.instance_count = list.size()
		for k in list.size():
			mm.set_instance_transform(k, list[k])
	_boulders.multimesh.instance_count = boulder_xf.size()
	for k in boulder_xf.size():
		_boulders.multimesh.set_instance_transform(k, boulder_xf[k])
	for i in grid.terrain.size():
		_floor_base[i] = _floor_colour(grid.terrain[i])


## A faceted rock pillar: an octagon at the base, a jittered waist, a narrower jagged top.
## Slightly wider than a tile so neighbouring walls read as one rock face.
func _rock_mesh(variant: int) -> ArrayMesh:
	var r := RandomNumberGenerator.new()
	r.seed = 4242 + variant * 31
	var sides := 8
	var rings := [
		[0.0, 1.18],
		[WALL_H * 0.45, 1.12],
		[WALL_H * 0.85, 0.95],
		[WALL_H, 0.62],
	]
	var pts: Array = []
	for ring in rings:
		var row: Array[Vector3] = []
		for s in sides:
			var a := TAU * (s + 0.5) / sides
			var rad: float = ring[1] * r.randf_range(0.88, 1.08)
			var y: float = ring[0] + (r.randf_range(-0.22, 0.25) if ring[0] > 0.0 else 0.0)
			row.append(Vector3(cos(a) * rad, y, sin(a) * rad))
		pts.append(row)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in rings.size() - 1:
		var lo: Array[Vector3] = pts[k]
		var hi: Array[Vector3] = pts[k + 1]
		var shade_lo := 0.55 + 0.15 * k
		var shade_hi := 0.55 + 0.15 * (k + 1)
		for s in sides:
			var s2 := (s + 1) % sides
			_tri(st, lo[s], hi[s], hi[s2], shade_lo, shade_hi, shade_hi)
			_tri(st, lo[s], hi[s2], lo[s2], shade_lo, shade_hi, shade_lo)
	var top: Array[Vector3] = pts[rings.size() - 1]
	var peak := Vector3(r.randf_range(-0.1, 0.1), WALL_H + r.randf_range(0.05, 0.35), r.randf_range(-0.1, 0.1))
	for s in sides:
		_tri(st, top[s], peak, top[(s + 1) % sides], 1.0, 1.1, 1.0)
	st.generate_normals()
	var m := Kit.mat(Color.WHITE, 0.92)
	m.vertex_color_use_as_albedo = true
	st.set_material(m)
	return st.commit()


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, sa: float, sb: float, sc: float) -> void:
	# Wound so the faces point outward.
	st.set_color(Color(sa, sa * 0.93, sa * 0.86))
	st.add_vertex(a)
	st.set_color(Color(sc, sc * 0.93, sc * 0.86))
	st.add_vertex(c)
	st.set_color(Color(sb, sb * 0.93, sb * 0.86))
	st.add_vertex(b)


func terrain_changed() -> void:
	_layout_rocks()
	_recolour()


# --- props ----------------------------------------------------------------------------------

func _build_props() -> void:
	var iron := Kit.mat(Kit.IRON, 0.5, 0.7)
	var brass := Kit.mat(Kit.BRASS, 0.35, 0.85)
	var copper := Kit.mat(Kit.COPPER, 0.4, 0.8)
	for i in grid.terrain.size():
		var c := grid.cell(i)
		match grid.terrain[i]:
			TacGrid.T.DOOR:
				_add_door(c, iron, brass)
			TacGrid.T.VENT:
				_add_vent(c, copper)
			TacGrid.T.VALVE:
				_add_valve(c, copper)
			TacGrid.T.FUNGUS:
				_add_fungus(c)
	_add_lift(brass)
	if battle.journal_tile != Battle.NO_TILE:
		_journal = _journal_prop()
		_journal.position = Kit.world(battle.journal_tile)
		add_child(_journal)


func _reveal_with(c: Vector2i, n: Node3D) -> void:
	var i := grid.idx(c)
	if not _props.has(i):
		_props[i] = []
	(_props[i] as Array).append(n)
	n.visible = false


func _mesh(mesh: Mesh, material: Material, pos := Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	(parent if parent != null else self).add_child(mi)
	return mi


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _cyl(r: float, h: float, segs := 10) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = segs
	return c


func _add_door(c: Vector2i, iron: Material, brass: Material) -> void:
	var root := Node3D.new()
	root.position = Kit.world(c)
	# Span the door across whichever axis the walls run along.
	var along_x := grid.get_t(c + Vector2i(1, 0)) == TacGrid.T.WALL or grid.get_t(c + Vector2i(-1, 0)) == TacGrid.T.WALL
	if not along_x:
		root.rotation.y = PI / 2.0
	add_child(root)
	for side in [-1.0, 1.0]:
		_mesh(_box(Vector3(0.22, 2.5, 0.42)), brass, Vector3(side * 0.95, 1.25, 0.0), root)
	_mesh(_box(Vector3(2.1, 0.22, 0.42)), brass, Vector3(0.0, 2.45, 0.0), root)
	var panel := Node3D.new()
	root.add_child(panel)
	_mesh(_box(Vector3(1.75, 2.2, 0.16)), iron, Vector3(0, 1.1, 0), panel)
	for y in [0.45, 1.1, 1.75]:
		_mesh(_box(Vector3(1.78, 0.08, 0.2)), brass, Vector3(0, y, 0), panel)
	_doors[c] = panel
	_reveal_with(c, root)
	set_door(c, grid.door_open[grid.idx(c)] == 1, false)


func set_door(c: Vector2i, open: bool, animate := true) -> void:
	var panel: Node3D = _doors.get(c)
	if panel == null:
		return
	var y := -2.25 if open else 0.0
	if animate:
		create_tween().tween_property(panel, "position:y", y, 0.35).set_trans(Tween.TRANS_QUAD)
	else:
		panel.position.y = y


func _add_vent(c: Vector2i, copper: Material) -> void:
	var root := Node3D.new()
	root.position = Kit.world(c)
	add_child(root)
	_mesh(_cyl(0.55, 0.5), copper, Vector3(0, 0.25, 0), root)
	_mesh(_cyl(0.42, 0.1), Kit.mat(Color(0.05, 0.05, 0.05), 0.9), Vector3(0, 0.52, 0), root)
	var p := CPUParticles3D.new()
	p.amount = 70
	p.lifetime = 2.6
	p.preprocess = 2.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(2.4, 0.4, 2.4)
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 1.1
	p.gravity = Vector3(0, 0.25, 0)
	p.scale_amount_min = 1.4
	p.scale_amount_max = 2.6
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(0.5, 1.0))
	curve.add_point(Vector2(1, 0.7))
	p.scale_amount_curve = curve
	var grad := Gradient.new()
	grad.set_color(0, Color(0.85, 0.87, 0.9, 0.0))
	grad.add_point(0.2, Color(0.85, 0.87, 0.9, 0.55))
	grad.set_color(grad.get_point_count() - 1, Color(0.85, 0.87, 0.9, 0.0))
	p.color_ramp = grad
	var q := QuadMesh.new()
	q.size = Vector2(1.6, 1.6)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1, 1, 1, 0.5)
	m.roughness = 1.0
	m.disable_receive_shadows = true
	q.material = m
	p.mesh = q
	p.position = Vector3(0, 0.8, 0)
	root.add_child(p)
	_vent_fx[c] = p
	p.emitting = grid.vent_on.get(c, false)
	_reveal_with(c, root)


func set_vents(vents: Array, on: bool) -> void:
	for v in vents:
		var p: CPUParticles3D = _vent_fx.get(v)
		if p != null:
			p.emitting = on


func _add_valve(c: Vector2i, copper: Material) -> void:
	var root := Node3D.new()
	root.position = Kit.world(c)
	add_child(root)
	_mesh(_cyl(0.12, 1.1), copper, Vector3(0.6, 0.55, 0.6), root)
	var wheel := Node3D.new()
	wheel.position = Vector3(0.6, 1.15, 0.6)
	root.add_child(wheel)
	var t := TorusMesh.new()
	t.inner_radius = 0.26
	t.outer_radius = 0.36
	_mesh(t, Kit.mat(Color(0.6, 0.12, 0.08), 0.5, 0.4), Vector3.ZERO, wheel)
	_mesh(_box(Vector3(0.6, 0.05, 0.06)), copper, Vector3.ZERO, wheel)
	_mesh(_box(Vector3(0.06, 0.05, 0.6)), copper, Vector3.ZERO, wheel)
	_valve_wheels[c] = wheel
	_reveal_with(c, root)


func turn_valve(c: Vector2i) -> void:
	var w: Node3D = _valve_wheels.get(c)
	if w != null:
		create_tween().tween_property(w, "rotation:y", w.rotation.y + TAU, 0.6)


func _add_fungus(c: Vector2i) -> void:
	var root := Node3D.new()
	root.position = Kit.world(c)
	add_child(root)
	var cap_mat := Kit.mat(Color(0.25, 0.9, 0.7), 0.6, 0.0, Color(0.3, 1.0, 0.75), 2.4)
	var stem_mat := Kit.mat(Color(0.75, 0.8, 0.7), 0.8)
	for k in _rng.randi_range(3, 6):
		var h := _rng.randf_range(0.2, 0.55)
		var p := Vector3(_rng.randf_range(-0.7, 0.7), 0.0, _rng.randf_range(-0.7, 0.7))
		_mesh(_cyl(0.045, h, 6), stem_mat, p + Vector3(0, h / 2.0, 0), root)
		var cap := SphereMesh.new()
		cap.radius = _rng.randf_range(0.12, 0.28)
		cap.height = cap.radius
		cap.radial_segments = 8
		cap.rings = 3
		cap.is_hemisphere = true
		_mesh(cap, cap_mat, p + Vector3(0, h, 0), root)
	var l := OmniLight3D.new()
	l.light_color = Color(0.35, 1.0, 0.7)
	l.light_energy = 0.9
	l.omni_range = 5.5
	l.omni_attenuation = 1.4
	l.position = Vector3(0, 0.7, 0)
	root.add_child(l)
	_reveal_with(c, root)


func _add_lift(brass: Material) -> void:
	if battle.lift_tiles.is_empty():
		return
	var lo := Vector2i(999, 999)
	var hi := Vector2i(-1, -1)
	for c in battle.lift_tiles:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	var a := Kit.world(lo) - Vector3(Kit.TILE * 0.5, 0, Kit.TILE * 0.5)
	var b := Kit.world(hi) + Vector3(Kit.TILE * 0.5, 0, Kit.TILE * 0.5)
	var root := Node3D.new()
	add_child(root)
	var h := 4.2
	for corner in [Vector3(a.x, 0, a.z), Vector3(b.x, 0, a.z), Vector3(a.x, 0, b.z), Vector3(b.x, 0, b.z)]:
		_mesh(_cyl(0.13, h), brass, corner + Vector3(0, h / 2.0, 0), root)
	var mid := (a + b) * 0.5
	var size := b - a
	for z in [a.z, b.z]:
		_mesh(_box(Vector3(size.x, 0.16, 0.16)), brass, Vector3(mid.x, h, z), root)
	for x in [a.x, b.x]:
		_mesh(_box(Vector3(0.16, 0.16, size.z)), brass, Vector3(x, h, mid.z), root)
	_mesh(_cyl(0.05, 3.0), Kit.mat(Kit.IRON, 0.5, 0.6), Vector3(mid.x, h + 1.5, mid.z), root)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.78, 0.45)
	lamp.light_energy = 1.6
	lamp.omni_range = 10.0
	lamp.position = Vector3(mid.x, h - 0.4, mid.z)
	root.add_child(lamp)
	_mesh(_cyl(0.18, 0.3), Kit.mat(Color(1, 0.85, 0.5), 0.4, 0.0, Color(1, 0.8, 0.45), 3.0), lamp.position, root)
	var sign := Label3D.new()
	sign.text = "THE LIFT"
	sign.font = Kit.title_font()
	sign.font_size = 72
	sign.pixel_size = 0.004
	sign.modulate = Kit.BRASS
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.position = Vector3(mid.x, h + 0.6, mid.z)
	root.add_child(sign)


func _journal_prop() -> Node3D:
	var root := Node3D.new()
	_mesh(_box(Vector3(1.1, 0.7, 0.75)), Kit.mat(Kit.LEATHER.darkened(0.3), 0.9), Vector3(0, 0.35, 0), root)
	_mesh(_box(Vector3(0.5, 0.09, 0.36)), Kit.mat(Color(0.5, 0.1, 0.08), 0.7), Vector3(0.05, 0.75, 0), root)
	_mesh(_box(Vector3(0.44, 0.06, 0.3)), Kit.mat(Color(0.9, 0.85, 0.7), 0.9), Vector3(0.05, 0.8, 0), root)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.75, 0.4)
	l.light_energy = 1.2
	l.omni_range = 4.0
	l.position = Vector3(-0.35, 1.0, 0.1)
	root.add_child(l)
	_mesh(_cyl(0.05, 0.25), Kit.mat(Color(1, 0.9, 0.7), 0.5, 0.0, Color(1, 0.75, 0.4), 4.0), Vector3(-0.35, 0.82, 0.1), root)
	var tag := Label3D.new()
	tag.text = "Survey Journal"
	tag.font = Kit.title_font()
	tag.font_size = 64
	tag.pixel_size = 0.006
	tag.modulate = Color(1, 0.85, 0.55)
	tag.outline_size = 10
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.position = Vector3(0, 1.7, 0)
	root.add_child(tag)
	return root


func remove_journal() -> void:
	if _journal != null:
		_journal.queue_free()
		_journal = null


func place_journal(c: Vector2i) -> void:
	remove_journal()
	_journal = _journal_prop()
	_journal.position = Kit.world(c)
	add_child(_journal)


# --- flares ---------------------------------------------------------------------------------

func sync_flares() -> void:
	var live := {}
	for f in battle.flares:
		var key := "%d,%d,%d" % [f["tile"].x, f["tile"].y, int(f.get("born", 0))]
		live[key] = f
		if not _flares.has(key):
			_flares[key] = _flare_node(f["tile"], float(f["radius"]))
		var n: Node3D = _flares[key]
		var share := float(f["turns"]) / float(f["max_turns"])
		n.set_meta("energy", 3.2 * share)
	for key in _flares.keys():
		if not live.has(key):
			(_flares[key] as Node3D).queue_free()
			_flares.erase(key)


func _flare_node(c: Vector2i, radius: float) -> Node3D:
	var root := Node3D.new()
	root.position = Kit.world(c)
	add_child(root)
	_mesh(_cyl(0.06, 0.4, 6), Kit.mat(Color(0.7, 0.1, 0.05), 0.6), Vector3(0, 0.2, 0), root).rotation.z = 0.6
	_mesh(SphereMesh.new(), Kit.mat(Color(1, 0.6, 0.5), 0.3, 0.0, Color(1.0, 0.45, 0.3), 8.0), Vector3(0.12, 0.4, 0), root).scale = Vector3.ONE * 0.18
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.62, 0.48)
	l.light_energy = 3.2
	l.omni_range = radius * Kit.TILE * 1.6
	l.omni_attenuation = 1.2
	l.shadow_enabled = true
	l.position = Vector3(0, 1.4, 0)
	l.name = "Light"
	root.add_child(l)
	var sparks := CPUParticles3D.new()
	sparks.amount = 24
	sparks.lifetime = 0.7
	sparks.direction = Vector3.UP
	sparks.spread = 35.0
	sparks.initial_velocity_min = 1.0
	sparks.initial_velocity_max = 2.5
	sparks.gravity = Vector3(0, -4, 0)
	sparks.scale_amount_min = 0.04
	sparks.scale_amount_max = 0.08
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.material = Kit.mat(Color(1, 0.7, 0.4), 0.5, 0.0, Color(1, 0.6, 0.3), 6.0)
	sparks.mesh = sm
	sparks.position = Vector3(0.12, 0.45, 0)
	root.add_child(sparks)
	root.set_meta("energy", 3.2)
	return root


# --- overlays and cursor --------------------------------------------------------------------

func _overlay_layer(y: float) -> MultiMeshInstance3D:
	var q := PlaneMesh.new()
	q.size = Vector2(Kit.TILE * 0.9, Kit.TILE * 0.9)
	var m := Kit.unshaded(Color.WHITE)
	m.vertex_color_use_as_albedo = true
	q.material = m
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = q
	var n := grid.width * grid.height
	mm.instance_count = n
	for i in n:
		mm.set_instance_transform(i, Transform3D(Basis(), Kit.world(grid.cell(i), y)))
		mm.set_instance_color(i, Color(0, 0, 0, 0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi


## tiles: tile index -> Color. Everything else is cleared.
func set_range_overlay(tiles: Dictionary) -> void:
	_fill_layer(_range_layer, tiles)


func set_info_overlay(tiles: Dictionary) -> void:
	_fill_layer(_info_layer, tiles)


func _fill_layer(layer: MultiMeshInstance3D, tiles: Dictionary) -> void:
	var mm := layer.multimesh
	for i in mm.instance_count:
		mm.set_instance_color(i, tiles.get(i, Color(0, 0, 0, 0)))


func light_overlay() -> Dictionary:
	var out := {}
	for i in _light.size():
		if _exp[i] == 0 or not grid.walkable(grid.cell(i)):
			continue
		match Rules.band(_light[i]):
			Rules.Band.PITCH:
				out[i] = Color(0.15, 0.25, 0.9, 0.38)
			Rules.Band.DIM:
				out[i] = Color(0.95, 0.65, 0.15, 0.32)
			Rules.Band.BRIGHT:
				out[i] = Color(1.0, 1.0, 0.85, 0.45)
	return out


func pheromone_overlay() -> Dictionary:
	var out := {}
	for p in battle.pheromones:
		var s: float = battle.pheromones[p]
		var r := 2
		for oy in range(-r, r + 1):
			for ox in range(-r, r + 1):
				var c: Vector2i = p + Vector2i(ox, oy)
				if not grid.in_bounds(c) or not grid.walkable(c):
					continue
				var d := Vector2(ox, oy).length()
				if d > Rules.PHEROMONE_DENSITY_RADIUS:
					continue
				var i := grid.idx(c)
				var a := clampf(s / Rules.PHEROMONE_CAP * (1.0 - d / 3.0), 0.0, 1.0) * 0.7
				var prev: Color = out.get(i, Color(0.35, 1.0, 0.2, 0.0))
				out[i] = Color(0.35, 1.0, 0.2, minf(0.75, prev.a + a))
	return out


func _build_cursor() -> void:
	_cursor = Node3D.new()
	add_child(_cursor)
	_cursor_mat = Kit.unshaded(Color(1, 0.85, 0.4, 0.95))
	var e := Kit.TILE * 0.47
	for k in 4:
		var bar := _mesh(_box(Vector3(Kit.TILE * 0.98, 0.05, 0.08)), _cursor_mat, Vector3.ZERO, _cursor)
		var a := k * PI / 2.0
		bar.rotation.y = a
		bar.position = Vector3(sin(a) * e, 0.09, cos(a) * e)
	_cursor.visible = false


func show_cursor(c: Vector2i, colour: Color) -> void:
	_cursor.visible = grid.in_bounds(c)
	_cursor.position = Kit.world(c)
	_cursor_mat.albedo_color = colour


func hide_cursor() -> void:
	_cursor.visible = false


func show_pings(tiles: Array) -> void:
	for p in _pings:
		p.queue_free()
	_pings.clear()
	for c in tiles:
		var root := Node3D.new()
		root.position = Kit.world(c, 0.08)
		add_child(root)
		var t := TorusMesh.new()
		t.inner_radius = 0.75
		t.outer_radius = 0.85
		t.rings = 24
		var m := Kit.unshaded(Color(1.0, 0.7, 0.2, 0.8))
		_mesh(t, m, Vector3.ZERO, root).scale = Vector3(1, 0.1, 1)
		root.set_meta("mat", m)
		_pings.append(root)


# --- fog of war -----------------------------------------------------------------------------

func apply_vision(vis: PackedByteArray, explored: PackedByteArray) -> void:
	_vis = vis
	_exp = explored
	_recolour()


func apply_light(light: PackedFloat32Array) -> void:
	_light = light
	_recolour()


func _recolour() -> void:
	var fmm := _floor.multimesh
	for i in fmm.instance_count:
		fmm.set_instance_color(i, _fog(_floor_base[i], i))
	for v in ROCK_VARIANTS:
		var mm := _rocks[v].multimesh
		var list: Array = _rock_index[v]
		for k in list.size():
			var i: int = list[k]
			var base := Color(0.36, 0.3, 0.26) if grid.terrain[i] == TacGrid.T.WALL else Color(0.5, 0.33, 0.2)
			mm.set_instance_color(k, _fog(base, i, true))
	for k in _boulder_tiles.size():
		var i := _boulder_tiles[k]
		_boulders.multimesh.set_instance_color(k, _fog(Color(0.42, 0.38, 0.33), i))
	for i in _props:
		var shown := _exp[i] == 1
		for n in _props[i]:
			(n as Node3D).visible = shown


func _fog(base: Color, i: int, rock := false) -> Color:
	if _exp[i] == 0:
		return Color(0, 0, 0)
	if _vis[i] == 0:
		var g := base.v * 0.3
		return Color(g * 0.9, g * 0.95, g * 1.1)
	var lit := 0.55 + 0.45 * _light[i]
	if rock:
		lit = 0.7 + 0.3 * _light[i]
	return base * lit


func _process(delta: float) -> void:
	_t += delta
	for key in _flares:
		var n: Node3D = _flares[key]
		var l := n.get_node_or_null("Light") as OmniLight3D
		if l != null:
			var e: float = n.get_meta("energy", 3.0)
			l.light_energy = e * (0.82 + 0.18 * sin(_t * 23.0 + n.position.x) * sin(_t * 7.0 + n.position.z))
	for p in _pings:
		var k := fmod(_t * 0.7, 1.0)
		p.scale = Vector3.ONE * (0.4 + k * 1.8)
		(p.get_meta("mat") as StandardMaterial3D).albedo_color.a = 0.85 * (1.0 - k)
