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
	m.roughness = roughness
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

static func rock(parent: Node, seed: int, size: Vector3, pos: Vector3, base: Color = STONE, moss: float = 0.6) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = rock_mesh(seed, size, base, moss)
	mi.material_override = vertex_mat()
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
