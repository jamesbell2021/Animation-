class_name Terrain
extends RefCounted
## The island's shape: a grassy plateau, a flat lighthouse yard and a shingle beach
## that runs down under the sea. One height function drives the mesh, the
## collision, and where props and creatures stand.

const PLATEAU_EDGE := 11.6
const BEACH_END := 15.4
const SEA_FLOOR_END := 22.0
const BEACH_DEPTH := -0.9
const SEA_FLOOR := -1.8
const YARD_RADIUS := 2.8
const YARD_BLEND := 4.2
const SEA_LEVEL := -0.35
const GRID_HALF := 23.0
const GRID_STEP := 0.85
const JITTER := 0.32

const GRASS_A := Color(0.20, 0.30, 0.11)
const GRASS_B := Color(0.33, 0.40, 0.15)
const DIRT := Color(0.33, 0.26, 0.17)
const GRAVEL := Color(0.42, 0.40, 0.36)
const SHINGLE := Color(0.33, 0.31, 0.27)
const WET := Color(0.20, 0.20, 0.19)
const SEABED := Color(0.16, 0.20, 0.20)

static var _noise: FastNoiseLite
static var _detail: FastNoiseLite

static func _ensure_noise() -> void:
	if _noise != null:
		return
	_noise = FastNoiseLite.new()
	_noise.seed = 1987
	_noise.frequency = 0.11
	_detail = FastNoiseLite.new()
	_detail.seed = 4242
	_detail.frequency = 0.45

static func height_at(x: float, z: float) -> float:
	_ensure_noise()
	var r := Vector2(x, z).length()
	var bumps := _noise.get_noise_2d(x, z) * 0.26 + _detail.get_noise_2d(x, z) * 0.05
	var yard := smoothstep(YARD_RADIUS, YARD_BLEND, r)
	var plateau := bumps * yard
	var beach := smoothstep(PLATEAU_EDGE, BEACH_END, r)
	var h := lerpf(plateau, BEACH_DEPTH, beach)
	if r > BEACH_END:
		h = lerpf(BEACH_DEPTH, SEA_FLOOR, smoothstep(BEACH_END, SEA_FLOOR_END, r))
	return h

static func height_at_v(p: Vector3) -> float:
	return height_at(p.x, p.z)

static func _hash(i: int, j: int, k: int) -> float:
	var h := (i * 73856093) ^ (j * 19349663) ^ (k * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	return float(h & 0xFFFF) / 65535.0

static func color_at(x: float, z: float, h: float) -> Color:
	_ensure_noise()
	var r := Vector2(x, z).length()
	var n := _noise.get_noise_2d(x * 1.7 + 40.0, z * 1.7)
	var c := GRASS_A.lerp(GRASS_B, clampf(n * 0.9 + 0.5, 0.0, 1.0))
	if _detail.get_noise_2d(x * 0.6, z * 0.6 + 90.0) > 0.42:
		c = c.lerp(DIRT, 0.7)
	if r < YARD_BLEND:
		c = GRAVEL.lerp(c, smoothstep(YARD_RADIUS - 0.4, YARD_BLEND, r))
	var beach := smoothstep(PLATEAU_EDGE - 0.6, PLATEAU_EDGE + 1.4, r)
	c = c.lerp(SHINGLE, beach)
	if h < SEA_LEVEL + 0.12:
		c = c.lerp(WET, clampf((SEA_LEVEL + 0.12 - h) * 3.0, 0.0, 1.0))
	if h < SEA_LEVEL - 0.5:
		c = SEABED
	return c

## Faceted ground mesh: a jittered grid, flat-shaded, one painted colour per triangle.
static func build_mesh() -> ArrayMesh:
	var n := int(GRID_HALF * 2.0 / GRID_STEP) + 1
	var pts: Array[Vector3] = []
	for j in n:
		for i in n:
			var x := -GRID_HALF + float(i) * GRID_STEP
			var z := -GRID_HALF + float(j) * GRID_STEP
			if i > 0 and i < n - 1:
				x += (_hash(i, j, 1) - 0.5) * JITTER * 2.0
			if j > 0 and j < n - 1:
				z += (_hash(i, j, 2) - 0.5) * JITTER * 2.0
			pts.append(Vector3(x, height_at(x, z), z))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for j in n - 1:
		for i in n - 1:
			var a := pts[j * n + i]
			var b := pts[j * n + i + 1]
			var c := pts[(j + 1) * n + i]
			var d := pts[(j + 1) * n + i + 1]
			if (i + j) % 2 == 0:
				_tri(st, a, b, d, i, j, 0)
				_tri(st, a, d, c, i, j, 1)
			else:
				_tri(st, a, b, c, i, j, 0)
				_tri(st, b, d, c, i, j, 1)
	st.generate_normals()
	return st.commit()

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, i: int, j: int, k: int) -> void:
	var mid := (a + b + c) / 3.0
	var col := color_at(mid.x, mid.z, mid.y)
	# Small per-facet value shift gives the hand-painted, faceted read.
	var shade := 0.92 + _hash(i, j, 7 + k) * 0.16
	col = Color(col.r * shade, col.g * shade, col.b * shade)
	st.set_color(col)
	st.add_vertex(a)
	st.set_color(col)
	st.add_vertex(b)
	st.set_color(col)
	st.add_vertex(c)
