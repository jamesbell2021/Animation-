class_name DodgemArena
extends FairgroundCourse
## Dodgem Derby arena: a round dodgem rink on a pier out in the Irish Sea, with
## Belfast across the water. No walls: ram rivals off the edge into the sea.
## The floor is built as a centre disc and three rings; the rings sink one by one
## (outermost first) so the rink keeps shrinking. A sparking ceiling grid, neon
## rims, floodlights and a bobbing "IRISH SEA" buoy finish it off.

## [inner, outer] radius of the centre disc and each ring (the outer ones sink first).
const RINGS: Array = [[0.0, 6.5], [6.5, 10.5], [10.5, 14.0], [14.0, 17.5]]
const FLOOR_THICKNESS := 0.6
const WATER_Y := -5.0
const CEILING_Y := 14.0
## Rubber bumper rail round the outer ring, with gaps to shove rivals through.
const RAIL_HEIGHT := 0.6
const RAIL_GAPS := 6
const RAIL_GAP_WIDTH := 3.6

const WATER_SHADER := """
shader_type spatial;
render_mode cull_disabled;

uniform vec4 deep : source_color = vec4(0.01, 0.04, 0.08, 1.0);
uniform vec4 crest : source_color = vec4(0.06, 0.2, 0.28, 1.0);

varying float height;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME;
	float a = sin(w.x * 0.16 + t * 1.3) * 0.35;
	float b = cos(w.z * 0.12 + t * 1.05) * 0.3;
	float c = sin((w.x + w.z) * 0.33 + t * 2.1) * 0.08;
	VERTEX.y += a + b + c;
	height = a + b + c;
	float dx = 0.16 * 0.35 * cos(w.x * 0.16 + t * 1.3) + 0.33 * 0.08 * cos((w.x + w.z) * 0.33 + t * 2.1);
	float dz = -0.12 * 0.3 * sin(w.z * 0.12 + t * 1.05) + 0.33 * 0.08 * cos((w.x + w.z) * 0.33 + t * 2.1);
	NORMAL = normalize(vec3(-dx, 1.0, -dz));
}

void fragment() {
	ALBEDO = mix(deep.rgb, crest.rgb, clamp(height * 0.9 + 0.4, 0.0, 1.0));
	ROUGHNESS = 0.06;
	SPECULAR = 0.9;
	METALLIC = 0.1;
}
"""

## Where the item boxes go.
var box_spots: Array[Vector3] = []

var _spawns: Array[Vector3] = []
var _rings: Array[Node3D] = []
var _rims: Array[StandardMaterial3D] = []
var _intact: int = 0
var _buoy: Node3D
var _time: float = 0.0


func build() -> void:
	if not is_inside_tree():
		push_error("DodgemArena.build: not inside the scene tree.")
		return
	clear()
	_build_environment()
	var arena := Node3D.new()
	arena.name = "SceneryRink"
	add_child(arena)
	_build_rink(arena)
	_build_pier(arena)
	_build_ceiling(arena)
	_build_sea(arena)
	_build_lights(arena)
	_spawns.clear()
	for i in range(8):
		var a := TAU * (float(i) + 0.5) / 8.0
		_spawns.append(Vector3(cos(a) * 12.0, 1.0, sin(a) * 12.0))
	box_spots.clear()
	for i in range(4):
		var a := TAU * float(i) / 4.0
		box_spots.append(Vector3(cos(a + PI * 0.25) * 4.0, 1.2, sin(a + PI * 0.25) * 4.0))
		box_spots.append(Vector3(cos(a) * 12.0, 1.2, sin(a) * 12.0))
	course_built.emit()


func get_spawn_positions(count: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i in range(count):
		out.append(_spawns[i % _spawns.size()])
	return out


func get_finish_area() -> Area3D:
	return null


func get_total_length() -> float:
	return outer_radius() * 2.0


## Item box positions for the ItemManager (world space).
func item_box_spots() -> Array[Vector3]:
	return box_spots


## Items that make sense on a dodgem rink.
func item_pool() -> Array[int]:
	return [
		ItemKinds.Kind.CONFETTI, ItemKinds.Kind.BOXING_GLOVE, ItemKinds.Kind.SPRINGER, ItemKinds.Kind.OIL_SLICK,
		ItemKinds.Kind.ROCKET_BOOTS, ItemKinds.Kind.MAGNET, ItemKinds.Kind.SHIELD, ItemKinds.Kind.SWORD,
		ItemKinds.Kind.PIE, ItemKinds.Kind.BALLOON, ItemKinds.Kind.ZAPPER, ItemKinds.Kind.CAKE,
		ItemKinds.Kind.SHRINK_POTION, ItemKinds.Kind.CONFETTI, ItemKinds.Kind.BOXING_GLOVE,
	]


## Radius of the floor that's still there.
func outer_radius() -> float:
	return float(RINGS[_intact - 1][1]) if _intact > 0 else 0.0


## How many rings (counting the centre disc) are still standing.
func intact_rings() -> int:
	return _intact


## Flashes the outermost ring's rim red: it's about to go.
func warn_ring(index: int) -> void:
	if index <= 0 or index >= _rims.size():
		return
	var mat := _rims[index]
	var tween := create_tween().set_loops(10)
	tween.tween_callback(func() -> void: mat.emission = Color(1.0, 0.05, 0.05))
	tween.tween_interval(0.15)
	tween.tween_callback(func() -> void: mat.emission = Color(1.0, 0.8, 0.1))
	tween.tween_interval(0.15)


## Sinks ring [param index] into the sea.
func collapse_ring(index: int) -> void:
	if index <= 0 or index >= _rings.size() or not is_instance_valid(_rings[index]):
		return
	_intact = mini(_intact, index)
	var ring := _rings[index]
	for child in ring.get_children():
		var piece := child as Node3D
		if piece == null:
			continue
		var tween := piece.create_tween()
		tween.tween_interval(randf_range(0.0, 0.5))
		tween.tween_callback(func() -> void:
			var body := piece as StaticBody3D
			if body != null:
				body.collision_layer = 0)
		tween.tween_property(piece, "position:y", piece.position.y - 16.0, 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(piece, "rotation:x", randf_range(-0.6, 0.6), 1.6)
	for i in range(10):
		var a := randf() * TAU
		var r := randf_range(float(RINGS[index][0]), float(RINGS[index][1]))
		FX.burst(self, "sparks", Vector3(cos(a) * r, 0.2, sin(a) * r), Color(1.5, 0.8, 0.3), 1.2)
	get_tree().create_timer(2.6, false).timeout.connect(func() -> void:
		if is_instance_valid(ring):
			ring.visible = false
			for i in range(8):
				var a := randf() * TAU
				FX.burst(self, "splash", Vector3(cos(a), 0.0, sin(a)) * float(RINGS[index][1]) + Vector3.UP * WATER_Y, Color.WHITE, 1.4))


## Puts every ring back (new battle).
func restore_rings() -> void:
	var holder := _rings[0].get_parent() if not _rings.is_empty() and is_instance_valid(_rings[0]) else null
	for ring in _rings:
		if is_instance_valid(ring):
			ring.queue_free()
	_rings.clear()
	_rims.clear()
	if holder != null:
		_build_rink(holder)


func _process(delta: float) -> void:
	_time += delta
	if _buoy != null:
		_buoy.position.y = WATER_Y + 0.3 + sin(_time * 1.4) * 0.35
		_buoy.rotation.z = sin(_time * 1.1) * 0.12


func _build_rink(parent: Node3D) -> void:
	for i in range(RINGS.size()):
		var inner := float(RINGS[i][0])
		var outer := float(RINGS[i][1])
		var ring := Node3D.new()
		ring.name = "Ring%d" % i
		parent.add_child(ring)
		_rings.append(ring)
		var base := Color(0.13, 0.13, 0.17) if i % 2 == 0 else Color(0.18, 0.17, 0.22)
		if i == 0:
			CourseBuilder.add_cylinder(ring, outer, FLOOR_THICKNESS, Vector3(0.0, -FLOOR_THICKNESS * 0.5, 0.0), base, "Disc")
			var logo := CourseBuilder.add_sign(ring, "DERBY", Vector3(0.0, 0.05, 0.0), CourseBuilder.accent(0), 220)
			if logo != null:
				logo.billboard = BaseMaterial3D.BILLBOARD_DISABLED
				logo.rotation.x = -PI * 0.5
				logo.pixel_size = 0.012
				logo.modulate.a = 0.6
		else:
			var mid := (inner + outer) * 0.5
			var depth := outer - inner
			var count := int(TAU * mid / 2.4)
			for k in range(count):
				var a := TAU * (float(k) + 0.5) / float(count)
				var tint := base.lightened(0.08) if k % 2 == 0 else base
				var seg := CourseBuilder.add_box(ring, Vector3(TAU * mid / float(count) * 1.04, FLOOR_THICKNESS, depth), Vector3(cos(a) * mid, -FLOOR_THICKNESS * 0.5, sin(a) * mid), tint, "Plate")
				seg.rotation.y = PI * 0.5 - a
		if i == RINGS.size() - 1:
			_build_rail(ring, outer)
		# Neon rim round the outside of each ring.
		var rim := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = outer - 0.18
		torus.outer_radius = outer
		torus.rings = 64
		var mat := CourseBuilder.make_neon_material(CourseBuilder.accent([1, 0, 3, 2][i]), 2.2)
		torus.material = mat
		rim.mesh = torus
		rim.position = Vector3(0.0, 0.02, 0.0)
		rim.scale = Vector3(1.0, 0.4, 1.0)
		ring.add_child(rim)
		_rims.append(mat)
	_intact = RINGS.size()


## The outer rail: rubber segments with a neon top, and gaps marked by red posts.
func _build_rail(ring: Node3D, outer: float) -> void:
	var r := outer - 0.3
	var count := int(TAU * r / 2.0)
	var gap_half := (RAIL_GAP_WIDTH * 0.5) / r
	for k in range(count):
		var a := TAU * (float(k) + 0.5) / float(count)
		var near_gap := false
		for g in range(RAIL_GAPS):
			var centre := TAU * (float(g) + 0.5) / float(RAIL_GAPS)
			if absf(wrapf(a - centre, -PI, PI)) < gap_half:
				near_gap = true
		if near_gap:
			continue
		var seg := CourseBuilder.add_box(ring, Vector3(TAU * r / float(count) * 1.05, RAIL_HEIGHT, 0.35), Vector3(cos(a) * r, RAIL_HEIGHT * 0.5, sin(a) * r), Color(0.06, 0.06, 0.07), "Rail")
		seg.rotation.y = PI * 0.5 - a
		CourseBuilder.add_neon_strip(seg, Vector3(TAU * r / float(count) * 1.05, 0.08, 0.37), Vector3(0.0, RAIL_HEIGHT * 0.5, 0.0), CourseBuilder.accent(2), "RailTop")
	for g in range(RAIL_GAPS):
		var centre := TAU * (float(g) + 0.5) / float(RAIL_GAPS)
		for side: float in [-1.0, 1.0]:
			var a := centre + side * (gap_half + 0.02)
			CourseBuilder.add_neon_strip(ring, Vector3(0.2, 1.4, 0.2), Vector3(cos(a) * r, 0.7, sin(a) * r), Color(1.0, 0.1, 0.05), "GapPost")


func _build_pier(parent: Node3D) -> void:
	for r: float in [5.0, 12.0, 16.5]:
		var count := int(TAU * r / 6.0)
		for k in range(count):
			var a := TAU * float(k) / float(count)
			CourseBuilder.add_decor_cylinder(parent, 0.35, 9.0, Vector3(cos(a) * r, -FLOOR_THICKNESS - 4.5, sin(a) * r), Color(0.12, 0.1, 0.09), "Pile")


func _build_ceiling(parent: Node3D) -> void:
	var r := 18.5
	for i in range(4):
		var a := TAU * (float(i) + 0.5) / 4.0
		var base := Vector3(cos(a) * r, 0.0, sin(a) * r)
		CourseBuilder.add_decor_box(parent, Vector3(0.5, CEILING_Y - WATER_Y, 0.5), base + Vector3(0.0, (CEILING_Y + WATER_Y) * 0.5, 0.0), CourseBuilder.STEEL, "Post")
		CourseBuilder.add_neon_strip(parent, Vector3(0.12, CEILING_Y - WATER_Y, 0.6), base + Vector3(0.0, (CEILING_Y + WATER_Y) * 0.5, 0.0), CourseBuilder.accent(i), "PostNeon")
	# The electric ceiling grid the dodgem poles spark against.
	var grid_colour := Color(0.12, 0.25, 0.45)
	var x := -15.0
	while x <= 15.0:
		var half := sqrt(maxf(r * r - x * x, 0.0))
		CourseBuilder.add_neon_strip(parent, Vector3(0.06, 0.06, half * 2.0), Vector3(x, CEILING_Y, 0.0), grid_colour, "GridZ")
		CourseBuilder.add_neon_strip(parent, Vector3(half * 2.0, 0.06, 0.06), Vector3(0.0, CEILING_Y, x), grid_colour, "GridX")
		x += 5.0
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = r - 0.15
	torus.outer_radius = r
	torus.rings = 64
	torus.material = CourseBuilder.make_neon_material(CourseBuilder.accent(0), 0.8)
	ring.mesh = torus
	ring.position = Vector3(0.0, CEILING_Y, 0.0)
	parent.add_child(ring)
	var sign_label := CourseBuilder.add_sign(parent, "DODGEM DERBY", Vector3(0.0, CEILING_Y + 2.2, -r), CourseBuilder.accent(0), 200)
	if sign_label != null:
		sign_label.pixel_size = 0.02


func _build_sea(parent: Node3D) -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(900.0, 900.0)
	plane.subdivide_width = 150
	plane.subdivide_depth = 150
	var shader := Shader.new()
	shader.code = WATER_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	plane.material = mat
	var sea := MeshInstance3D.new()
	sea.name = "IrishSea"
	sea.mesh = plane
	sea.position = Vector3(0.0, WATER_Y, -250.0)
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(sea)
	# A buoy so everyone knows where they've ended up.
	_buoy = Node3D.new()
	_buoy.name = "Buoy"
	_buoy.position = Vector3(6.0, WATER_Y, -24.0)
	parent.add_child(_buoy)
	var float_body := CourseBuilder.make_cylinder_mesh(0.9, 1.2, Color(0.8, 0.1, 0.08))
	_buoy.add_child(float_body)
	var mast := CourseBuilder.make_cylinder_mesh(0.12, 2.2, Color(0.9, 0.9, 0.9))
	mast.position = Vector3(0.0, 1.6, 0.0)
	_buoy.add_child(mast)
	var lamp := MeshInstance3D.new()
	var bulb := SphereMesh.new()
	bulb.radius = 0.25
	bulb.height = 0.5
	bulb.material = CourseBuilder.make_neon_material(Color(1.0, 0.2, 0.1), 5.0)
	lamp.mesh = bulb
	lamp.position = Vector3(0.0, 2.8, 0.0)
	_buoy.add_child(lamp)
	CourseBuilder.add_sign(_buoy, "IRISH SEA", Vector3(0.0, 3.8, 0.0), Color(0.6, 0.9, 1.0), 110)


func _build_lights(parent: Node3D) -> void:
	for i in range(4):
		var a := TAU * float(i) / 4.0
		var light := OmniLight3D.new()
		light.light_color = CourseBuilder.accent(i)
		light.light_energy = 2.5
		light.omni_range = 16.0
		light.position = Vector3(cos(a) * 9.0, 5.5, sin(a) * 9.0)
		parent.add_child(light)
	var spot := SpotLight3D.new()
	spot.light_color = Color(0.85, 0.9, 1.0)
	spot.light_energy = 4.0
	spot.spot_range = 40.0
	spot.spot_angle = 40.0
	spot.position = Vector3(0.0, CEILING_Y + 6.0, 0.0)
	spot.rotation.x = -PI * 0.5
	parent.add_child(spot)
