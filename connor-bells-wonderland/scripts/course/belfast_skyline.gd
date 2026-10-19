class_name BelfastSkyline
extends Node3D
## Far-off Belfast at night: the Cave Hill ridge with Napoleon's Nose, the two
## yellow Harland & Wolff cranes (Samson and Goliath) with blinking red lights,
## and the city's lights spread across dark land below. Scenery only: no
## collision. Build it with the origin at ground level, facing +Z (the viewer).

const HILL_PROFILE: Array[Vector2] = [
	Vector2(0, 0), Vector2(70, 14), Vector2(160, 42), Vector2(270, 70), Vector2(380, 92),
	Vector2(470, 106), Vector2(540, 112), Vector2(600, 118), Vector2(650, 121), Vector2(690, 126),
	Vector2(720, 133), Vector2(742, 140), Vector2(756, 139), Vector2(764, 128), Vector2(772, 104),
	Vector2(782, 84), Vector2(800, 72), Vector2(840, 58), Vector2(900, 36), Vector2(960, 14), Vector2(1010, 0),
]

const CRANE_YELLOW := Color(0.95, 0.72, 0.05)

var _beacons: Array[MeshInstance3D] = []
var _blink: float = 0.0


func _ready() -> void:
	_build()


func _process(delta: float) -> void:
	_blink += delta
	var on := fmod(_blink, 1.6) < 0.8
	for b in _beacons:
		b.visible = on


func _build() -> void:
	_build_land()
	_build_cave_hill(Vector3(-950.0, 0.0, -150.0), 1.5)
	_build_crane("Goliath", Vector3(380.0, 0.0, 200.0), 1.0)
	_build_crane("Samson", Vector3(560.0, 0.0, 140.0), 1.1)
	_build_city_lights()


func _build_land() -> void:
	var land := CourseBuilder.make_box_mesh(Vector3(5000.0, 1.0, 2400.0), Color(0.015, 0.02, 0.025))
	land.name = "Land"
	land.position = Vector3(0.0, -0.6, 300.0)
	land.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(land)


## The ridge as an extruded silhouette, 1010 m long before [param scale].
func _build_cave_hill(origin: Vector3, scale: float) -> void:
	var depth := 260.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(HILL_PROFILE.size() - 1):
		var a := HILL_PROFILE[i] * scale
		var b := HILL_PROFILE[i + 1] * scale
		# Front face (towards +Z) and the sloping top running back.
		var fa := Vector3(a.x, a.y, 0.0)
		var fb := Vector3(b.x, b.y, 0.0)
		var ga := Vector3(a.x, 0.0, 0.0)
		var gb := Vector3(b.x, 0.0, 0.0)
		var ba := Vector3(a.x, a.y * 0.7, -depth)
		var bb := Vector3(b.x, b.y * 0.7, -depth)
		for v in [ga, fb, fa, ga, gb, fb, fa, fb, bb, fa, bb, ba]:
			st.add_vertex(v)
	st.generate_normals()
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.03, 0.04, 0.045)
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.name = "CaveHill"
	mi.mesh = mesh
	mi.position = origin
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	# Street lights climbing the lower slopes.
	var lights: Array[Vector3] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 368
	for i in range(140):
		var x := rng.randf_range(20.0, 980.0)
		var top := _profile_height(x)
		var y := rng.randf_range(0.0, top * 0.45)
		lights.append(origin + Vector3(x * scale, y * scale, rng.randf_range(2.0, 6.0)))
	_add_dots("HillLights", lights, 2.2, Color(1.0, 0.75, 0.4))


func _profile_height(x: float) -> float:
	for i in range(HILL_PROFILE.size() - 1):
		var a := HILL_PROFILE[i]
		var b := HILL_PROFILE[i + 1]
		if x >= a.x and x <= b.x:
			return lerpf(a.y, b.y, (x - a.x) / maxf(b.x - a.x, 0.001))
	return 0.0


## A gantry crane: a solid leg on one side, an A-frame on the other, a girder
## across the top with "H&W" on it, floodlit yellow.
func _build_crane(crane_name: String, origin: Vector3, scale: float) -> void:
	var crane := Node3D.new()
	crane.name = crane_name
	crane.position = origin
	crane.scale = Vector3.ONE * scale
	crane.rotation.y = deg_to_rad(-12.0)
	add_child(crane)
	var mat := CourseBuilder.make_neon_material(CRANE_YELLOW, 0.35)
	mat.roughness = 0.8
	var span := 140.0
	var top := 82.0
	var beam_h := 12.0
	# Girder.
	_crane_box(crane, Vector3(span + 24.0, beam_h, 10.0), Vector3(0.0, top + beam_h * 0.5, 0.0), mat)
	# Solid leg (left).
	_crane_box(crane, Vector3(9.0, top, 18.0), Vector3(-span * 0.5, top * 0.5, 0.0), mat)
	# A-frame (right): two legs splayed front and back.
	for side: float in [-1.0, 1.0]:
		var leg := _crane_box(crane, Vector3(5.0, top * 1.04, 5.0), Vector3(span * 0.5, top * 0.5, side * 11.0), mat)
		leg.rotation.x = side * 0.17
	# Feet / bogies.
	for x: float in [-span * 0.5, span * 0.5]:
		_crane_box(crane, Vector3(16.0, 4.0, 30.0), Vector3(x, 2.0, 0.0), mat)
	# Trolley hanging under the girder.
	_crane_box(crane, Vector3(14.0, 8.0, 12.0), Vector3(-20.0, top - 4.0, 0.0), mat)
	var sign_label := Label3D.new()
	sign_label.text = "H&W"
	sign_label.font_size = 128
	sign_label.font = GameFonts.title()
	sign_label.pixel_size = 0.075
	sign_label.modulate = Color(0.02, 0.02, 0.02)
	sign_label.outline_size = 0
	sign_label.shaded = false
	sign_label.double_sided = false
	sign_label.position = Vector3(0.0, top + beam_h * 0.5, 5.2)
	crane.add_child(sign_label)
	# Red aircraft warning lights.
	for x: float in [-span * 0.5 - 10.0, 0.0, span * 0.5 + 10.0]:
		var beacon := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 1.6
		sphere.height = 3.2
		sphere.material = CourseBuilder.make_neon_material(Color(1.0, 0.05, 0.02), 6.0)
		beacon.mesh = sphere
		beacon.position = Vector3(x, top + beam_h + 2.0, 0.0)
		crane.add_child(beacon)
		_beacons.append(beacon)


func _crane_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = mat
	mi.mesh = box
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## Thousands of warm and cool dots: Belfast's lights across the dark land.
func _build_city_lights() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1912
	var warm: Array[Vector3] = []
	var cool: Array[Vector3] = []
	for i in range(900):
		var p := Vector3(rng.randf_range(-1400.0, 1400.0), 0.6, rng.randf_range(-120.0, 700.0))
		if rng.randf() < 0.75:
			warm.append(p)
		else:
			cool.append(p)
	_add_dots("CityLightsWarm", warm, 2.6, Color(1.0, 0.7, 0.35))
	_add_dots("CityLightsCool", cool, 2.6, Color(0.6, 0.8, 1.0))


func _add_dots(node_name: String, points: Array[Vector3], size: float, colour: Color) -> void:
	var box := BoxMesh.new()
	box.size = Vector3.ONE * size
	box.material = CourseBuilder.make_neon_material(colour, 2.5)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = box
	mm.instance_count = points.size()
	for i in range(points.size()):
		mm.set_instance_transform(i, Transform3D(Basis(), points[i]))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
