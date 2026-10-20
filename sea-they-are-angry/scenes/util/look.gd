class_name Look
extends RefCounted
## Shared helpers for the painted low-poly look: vertex-colour materials,
## faceted rocks, and a few palette constants.

const WOOD := Color(0.36, 0.27, 0.18)
const WOOD_PALE := Color(0.58, 0.53, 0.45)
const STONE := Color(0.44, 0.44, 0.42)
const MOSS := Color(0.30, 0.38, 0.18)
const RUST := Color(0.48, 0.26, 0.15)

static func vertex_mat(roughness: float = 0.92) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	# Vertex colours (ours and the GLBs') are authored in sRGB.
	m.vertex_color_is_srgb = true
	m.roughness = roughness
	return m

const TEX := "res://art/textures/%s_%s.png"

## A surface texture from art/textures (art/source/textures/build_textures.py), with its
## normal map, projected from three sides in the object's own space, so boxes and
## cylinders built in code need no UVs. `tile` is metres per repeat; `tint` multiplies
## the colour (white leaves it as painted). Each call makes its own material, so a
## building can tint its own (damage, lit and so on).
static func textured(kind: String, tint: Color = Color.WHITE, tile: float = 1.0, roughness: float = 0.9, bump: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.roughness = roughness
	var a := TEX % [kind, "albedo"]
	var n := TEX % [kind, "normal"]
	if ResourceLoader.exists(a):
		m.albedo_texture = load(a)
	if ResourceLoader.exists(n):
		m.normal_enabled = true
		m.normal_texture = load(n)
		m.normal_scale = bump
	m.uv1_triplanar = true
	m.uv1_triplanar_sharpness = 4.0
	m.uv1_scale = Vector3.ONE / maxf(tile, 0.01)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

## Weathered timber in a painted colour (the planks texture averages about 0.4).
static func wood(color: Color, tile: float = 0.9, roughness: float = 0.92) -> StandardMaterial3D:
	return textured("planks", color * 2.4, tile, roughness, 1.0)

## Rough stonework in a painted colour (the rubble texture averages about 0.38).
static func stone(color: Color, tile: float = 1.3, roughness: float = 0.9) -> StandardMaterial3D:
	return textured("rubble", color * 2.6, tile, roughness, 1.2)

static var _terrain_mat: ShaderMaterial

## The ground's material: shaders/terrain.gdshader with the four ground textures.
static func terrain_mat() -> Material:
	if _terrain_mat != null:
		return _terrain_mat
	var sh := load("res://shaders/terrain.gdshader") as Shader
	if sh == null or not ResourceLoader.exists(TEX % ["grass", "albedo"]):
		return vertex_mat(0.95)
	var m := ShaderMaterial.new()
	m.shader = sh
	var means := {}
	if FileAccess.file_exists("res://art/textures/terrain.json"):
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://art/textures/terrain.json"))
		if d is Dictionary:
			means = d
	for k in ["grass", "dirt", "shingle", "rock"]:
		m.set_shader_parameter(k + "_albedo", load(TEX % [k, "albedo"]))
		m.set_shader_parameter(k + "_normal", load(TEX % [k, "normal"]))
		if means.has(k):
			# The means are of the sRGB pixels; the shader samples in linear.
			var c: Array = means[k]
			m.set_shader_parameter(k + "_mean", Vector3(pow(c[0], 2.2), pow(c[1], 2.2), pow(c[2], 2.2)))
	_terrain_mat = m
	return m

## Faceted rocks, textured: rock detail and relief over their painted vertex colours.
static func rock_mat() -> StandardMaterial3D:
	var m := textured("rock", Color.WHITE, 1.6, 0.9, 1.2)
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	# The texture's colour averages about 0.3: lift it back to the painted colour.
	m.albedo_color = Color(2.5, 2.5, 2.5)
	return m

static func flat_mat(color: Color, roughness: float = 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m

static func glow_mat(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m

## Creature eyes: unshaded and bright enough to bloom, so they glint through the dark and fog.
static func eye_mat(color: Color, energy: float = 9.0) -> StandardMaterial3D:
	var m := glow_mat(color, energy)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color.lightened(0.3)
	return m

static var _glints := {}

## A soft glowing point that always faces the camera: how creatures' eyes read at a
## distance and through fog. Additive, so it only ever adds light.
static func glint(parent: Node3D, pos: Vector3, color: Color, size: float = 0.32) -> MeshInstance3D:
	var key := color.to_html()
	if not _glints.has(key):
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.25, Color(1, 1, 1, 0.55))
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 32
		tex.height = 32
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.albedo_texture = tex
		m.albedo_color = Color(color.r * 2.5, color.g * 2.5, color.b * 2.5, 1.0)
		m.disable_receive_shadows = true
		_glints[key] = m
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(size, size)
	q.mesh = qm
	q.material_override = _glints[key]
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	q.position = pos
	parent.add_child(q)
	return q

static func _hash3(p: Vector3, salt: int) -> float:
	var h := int(p.x * 997.0) * 73856093 ^ int(p.y * 991.0) * 19349663 ^ int(p.z * 983.0) * 83492791 ^ salt * 2654435
	h = (h ^ (h >> 13)) * 1274126177
	return float(h & 0xFFFF) / 65535.0

## A lumpy, flat-shaded rock. Upward faces get moss when moss > 0.
static func rock_mesh(seed: int, size: Vector3, base: Color = STONE, moss: float = 0.6) -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 7
	sphere.rings = 4
	var arrays := sphere.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var moved := PackedVector3Array()
	for v in verts:
		var k := 0.75 + _hash3(v, seed) * 0.5
		var w := Vector3(v.x * size.x, v.y * size.y, v.z * size.z) * k
		if w.y < -size.y * 0.25:
			w.y = -size.y * 0.25
		moved.append(w)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var t := 0
	while t + 2 < idx.size():
		var a := moved[idx[t]]
		var b := moved[idx[t + 1]]
		var c := moved[idx[t + 2]]
		var col := base * (0.85 + _hash3(a + b + c, seed + 3) * 0.25)
		if moss > 0.0 and (a.y + b.y + c.y) / 3.0 > size.y * 0.14:
			col = col.lerp(MOSS, moss)
		col.a = 1.0
		for p in [a, b, c]:
			st.set_color(col)
			st.add_vertex(p)
		t += 3
	st.generate_normals()
	return st.commit()

static var _rock_m: StandardMaterial3D

static func _rock_shared() -> StandardMaterial3D:
	if _rock_m == null:
		_rock_m = rock_mat()
	return _rock_m

static func rock(parent: Node, seed: int, size: Vector3, pos: Vector3, base: Color = STONE, moss: float = 0.6) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = rock_mesh(seed, size, base, moss)
	mi.material_override = _rock_shared()
	mi.position = pos
	mi.rotation.y = float(seed % 360) * 0.0174533
	parent.add_child(mi)
	return mi

## One grass tuft: a handful of thin leaning blades, dark at the root, pale at the tip.
static func grass_tuft_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var root := Color(0.09, 0.15, 0.05)
	var tip := Color(0.34, 0.45, 0.16)
	var blades := 6
	for i in blades:
		var a := TAU * float(i) / float(blades) + float(i) * 0.7
		var lean := Vector3(cos(a), 0.0, sin(a)) * (0.05 + 0.04 * float(i % 3))
		var side := Vector3(-sin(a), 0.0, cos(a)) * 0.035
		var base := Vector3(cos(a), 0.0, sin(a)) * 0.05
		var h := 0.32 + 0.09 * float((i * 7) % 4)
		var t := tip.lerp(Color(0.52, 0.50, 0.24), float(i % 3) * 0.3)
		st.set_color(root)
		st.add_vertex(base - side)
		st.set_color(root)
		st.add_vertex(base + side)
		st.set_color(t)
		st.add_vertex(base + lean + Vector3(0.0, h, 0.0))
	st.generate_normals()
	return st.commit()
