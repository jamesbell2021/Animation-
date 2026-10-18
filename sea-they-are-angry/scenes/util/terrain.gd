class_name Terrain
extends RefCounted
## The island's shape: a grassy plateau, a flat lighthouse yard and a shingle beach
## that runs down under the sea. One height function drives the mesh, the
## collision, and where props and creatures stand.

const PLATEAU_HEIGHT := 1.8
const KNOLL_RISE := 0.5
const CLIFF_START := 9.8
const CLIFF_END := 14.4
const CLIFF_WOBBLE := 0.6
const SEA_FLOOR_END := 22.0
const SHELF_DEPTH := -0.9
const SEA_FLOOR := -1.8
const YARD_RADIUS := 2.8
const YARD_BLEND := 4.5
const SEA_LEVEL := -0.35
const GRID_HALF := 23.0
const GRID_STEP := 0.8
const JITTER := 0.3

const GRASS_A := Color(0.20, 0.30, 0.11)
const GRASS_B := Color(0.33, 0.40, 0.15)
const DIRT := Color(0.33, 0.26, 0.17)
const GRAVEL := Color(0.45, 0.43, 0.39)
const ROCK := Color(0.36, 0.35, 0.33)
const ROCK_DARK := Color(0.24, 0.24, 0.23)
const MOSS := Color(0.26, 0.33, 0.14)
const SHINGLE := Color(0.33, 0.31, 0.27)
const WET := Color(0.20, 0.20, 0.19)
const SEABED := Color(0.16, 0.20, 0.20)

# Flat building pads on the plateau: [x, z, radius]. Kept in sync with main.gd.
const PADS := [[-4.8, 2.9, 2.9], [5.0, -2.9, 2.3], [-5.4, -2.8, 1.8]]
# Gravel tracks: pairs of [x, z] end points.
const PATHS := [[[0.0, 2.6], [-3.6, 2.2]], [[0.0, 2.6], [3.3, 8.0]], [[1.5, -2.2], [3.9, -2.3]]]

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

static func _pad_flatten(x: float, z: float) -> float:
	var k := 1.0
	for p in PADS:
		var d := Vector2(x - float(p[0]), z - float(p[1])).length()
		k = minf(k, smoothstep(float(p[2]), float(p[2]) + 1.2, d))
	return k

static func _cliff_edge(x: float, z: float) -> float:
	# The cliff line wanders in and out so the island is not a perfect circle.
	var a := atan2(z, x)
	return CLIFF_START + _noise.get_noise_2d(cos(a) * 30.0, sin(a) * 30.0) * CLIFF_WOBBLE * 2.0

## Height of the island at a point: a raised plateau with the lighthouse on a
## low knoll, rocky slopes falling to a shelf under the sea, then the sea floor.
static func height_at(x: float, z: float) -> float:
	_ensure_noise()
	var r := Vector2(x, z).length()
	var bumps := _noise.get_noise_2d(x, z) * 0.3 + _detail.get_noise_2d(x, z) * 0.06
	var knoll := (1.0 - smoothstep(YARD_RADIUS, YARD_BLEND, r)) * KNOLL_RISE
	var top := PLATEAU_HEIGHT + knoll + bumps * smoothstep(YARD_RADIUS, YARD_BLEND, r) * _pad_flatten(x, z)
	var edge := _cliff_edge(x, z)
	var t := smoothstep(edge, CLIFF_END, r)
	# Jagged rock on the slopes.
	var crag := _detail.get_noise_2d(x * 1.6, z * 1.6) * 0.35 * t * (1.0 - t) * 4.0
	var h := lerpf(top, SHELF_DEPTH, t) + crag
	if r > CLIFF_END:
		h = lerpf(SHELF_DEPTH, SEA_FLOOR, smoothstep(CLIFF_END, SEA_FLOOR_END, r))
	return h

static func height_at_v(p: Vector3) -> float:
	return height_at(p.x, p.z)

static func _path_dist(x: float, z: float) -> float:
	var best := 99.0
	var p := Vector2(x, z)
	for seg in PATHS:
		var a := Vector2(float(seg[0][0]), float(seg[0][1]))
		var b := Vector2(float(seg[1][0]), float(seg[1][1]))
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		best = minf(best, (a + ab * t).distance_to(p))
	return best

## True where grass may grow: on the plateau, off the yard, pads and paths.
static func is_grassy(x: float, z: float) -> bool:
	var r := Vector2(x, z).length()
	if r < YARD_BLEND - 0.6 or r > _cliff_edge(x, z) - 0.3:
		return false
	if _pad_flatten(x, z) < 0.6:
		return false
	return _path_dist(x, z) > 0.75

static func _hash(i: int, j: int, k: int) -> float:
	var h := (i * 73856093) ^ (j * 19349663) ^ (k * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	return float(h & 0xFFFF) / 65535.0

static func color_at(x: float, z: float, h: float, steep: float) -> Color:
	_ensure_noise()
	var r := Vector2(x, z).length()
	var n := _noise.get_noise_2d(x * 1.7 + 40.0, z * 1.7)
	var c := GRASS_A.lerp(GRASS_B, clampf(n * 0.9 + 0.5, 0.0, 1.0))
	if _detail.get_noise_2d(x * 0.6, z * 0.6 + 90.0) > 0.42:
		c = c.lerp(DIRT, 0.7)
	if _pad_flatten(x, z) < 0.5:
		c = c.lerp(DIRT, 0.55)
	if _path_dist(x, z) < 0.7:
		c = GRAVEL.lerp(c, smoothstep(0.35, 0.7, _path_dist(x, z)))
	if r < YARD_BLEND:
		c = GRAVEL.lerp(c, smoothstep(YARD_RADIUS - 0.4, YARD_BLEND, r))
	# Rock wherever the ground is steep or past the cliff line, mossy on the gentler faces.
	var edge := _cliff_edge(x, z)
	var rockiness := maxf(smoothstep(0.18, 0.4, steep), smoothstep(edge - 0.4, edge + 0.6, r))
	var rock := ROCK.lerp(ROCK_DARK, clampf(_detail.get_noise_2d(x * 2.0, z * 2.0) + 0.5, 0.0, 1.0))
	rock = rock.lerp(MOSS, clampf(0.45 - steep, 0.0, 0.45))
	c = c.lerp(rock, rockiness)
	if h < SEA_LEVEL + 0.35 and r > edge:
		c = c.lerp(SHINGLE, 0.6)
	if h < SEA_LEVEL + 0.1:
		c = c.lerp(WET, clampf((SEA_LEVEL + 0.1 - h) * 3.0, 0.0, 1.0))
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
	var nrm := (b - a).cross(c - a).normalized()
	var col := color_at(mid.x, mid.z, mid.y, 1.0 - absf(nrm.y))
	# Small per-facet value shift gives the hand-painted, faceted read.
	var shade := 0.92 + _hash(i, j, 7 + k) * 0.16
	col = Color(col.r * shade, col.g * shade, col.b * shade)
	st.set_color(col)
	st.add_vertex(a)
	st.set_color(col)
	st.add_vertex(b)
	st.set_color(col)
	st.add_vertex(c)
