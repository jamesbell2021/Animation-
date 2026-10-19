class_name Terrain
extends RefCounted
## The island's shape, Bad North style: a meadow ringed by sheer cliffs, three
## shingle beaches where the sea can come ashore, and a crag in the middle with
## the lighthouse on top, reached only by a ledge path that winds up around it.
## One height function drives the mesh, the collision, where props stand and
## where creatures walk.
##
## Angles are compass degrees: 0 points south (toward the camera, +Z), 90 east (+X).

const SEA_LEVEL := -0.35
const PLATEAU_HEIGHT := 1.8
const CRAG_TOP := 6.4
const YARD_RADIUS := 3.4
const COAST := 15.0
const COAST_WOBBLE := 0.9
const CLIFF_WIDTH := 1.9
const SHELF_DEPTH := -1.1
const SEA_FLOOR := -2.4
const SEA_FLOOR_END := 26.0
const GRID_HALF := 28.0
const GRID_STEP := 0.55
const JITTER := 0.2

# Beaches: compass angles. Each is a shingle slope from the sea floor up a gully
# to the meadow, narrowing as it climbs.
const BEACHES := [100.0, 180.0, 260.0]
const BEACH_OUT := 23.0
const BEACH_IN := 11.8
const BEACH_SEA_H := -1.7
const BEACH_MOUTH := 5.5
const BEACH_NECK := 1.7
const BEACH_BLEND := 1.4

# The ledge: starts on the meadow at LEDGE_START and winds LEDGE_SWEEP degrees
# round the crag, climbing all the way to the top. R0 - R1 is twice the half
# width, so the crag wall closes up neatly between the ledge's foot and head.
const LEDGE_START := 180.0
const LEDGE_SWEEP := 300.0
const LEDGE_R0 := 7.6
const LEDGE_R1 := 5.0
const LEDGE_HALF := 1.3
const CRAG_BLEND := 0.6

# The worn track round the crag foot that joins the beaches to the ledge.
const RING_R := 9.4

const GRASS_A := Color(0.20, 0.30, 0.11)
const GRASS_B := Color(0.33, 0.40, 0.15)
const DIRT := Color(0.33, 0.26, 0.17)
const GRAVEL := Color(0.45, 0.43, 0.39)
const ROCK := Color(0.36, 0.35, 0.33)
const ROCK_DARK := Color(0.24, 0.24, 0.23)
const MOSS := Color(0.26, 0.33, 0.14)
const SHINGLE := Color(0.56, 0.51, 0.41)
const WET := Color(0.20, 0.20, 0.19)
const SEABED := Color(0.16, 0.20, 0.20)

# Flat building pads on the meadow: [x, z, radius]. Cottage, garden, shed.
const PADS := [[-7.3, 9.3, 2.6], [7.3, 8.9, 2.2], [0.0, 12.0, 1.7]]

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

## A point at compass angle a_deg and radius r, on the ground.
static func at_angle(a_deg: float, r: float) -> Vector3:
	var a := deg_to_rad(a_deg)
	var p := Vector3(sin(a) * r, 0.0, cos(a) * r)
	p.y = height_at(p.x, p.z)
	return p

static func compass_deg(x: float, z: float) -> float:
	return fposmod(rad_to_deg(atan2(x, z)), 360.0)

static func _pad_flatten(x: float, z: float) -> float:
	var k := 1.0
	for p in PADS:
		var d := Vector2(x - float(p[0]), z - float(p[1])).length()
		k = minf(k, smoothstep(float(p[2]), float(p[2]) + 1.2, d))
	return k

## Radius of the cliff edge in the direction of compass angle a_deg.
static func coast_radius(a_deg: float) -> float:
	_ensure_noise()
	var a := deg_to_rad(a_deg)
	return COAST + _noise.get_noise_2d(cos(a) * 30.0, sin(a) * 30.0) * COAST_WOBBLE * 2.0

# ---- ledge ----

static func ledge_height(s: float) -> float:
	return lerpf(PLATEAU_HEIGHT, CRAG_TOP, clampf(s, 0.0, 1.0))

static func ledge_radius(s: float) -> float:
	return lerpf(LEDGE_R0, LEDGE_R1, clampf(s, 0.0, 1.0))

## Centre of the ledge path at s (0 = its foot on the meadow, 1 = the top).
static func ledge_point(s: float) -> Vector3:
	var a := deg_to_rad(LEDGE_START + s * LEDGE_SWEEP)
	var r := ledge_radius(s)
	return Vector3(sin(a) * r, ledge_height(s), cos(a) * r)

## Ledge parameter s at this point's angle, or -1 in the wedge it doesn't cover.
static func ledge_s(x: float, z: float) -> float:
	var u := fposmod(compass_deg(x, z) - LEDGE_START, 360.0)
	return u / LEDGE_SWEEP if u <= LEDGE_SWEEP else -1.0

# Height of the crag above the meadow: a flat top, the ledge cut round it, sheer walls.
static func _crag(x: float, z: float, r: float) -> float:
	if r > LEDGE_R0 + LEDGE_HALF + CRAG_BLEND + 0.1:
		return 0.0
	var top := CRAG_TOP - PLATEAU_HEIGHT
	var s := ledge_s(x, z)
	var h: float
	var walls: float
	if s >= 0.0:
		var rho := ledge_radius(s)
		var ledge := ledge_height(s) - PLATEAU_HEIGHT
		var inner := smoothstep(rho - LEDGE_HALF - CRAG_BLEND, rho - LEDGE_HALF, r)
		var outer := smoothstep(rho + LEDGE_HALF, rho + LEDGE_HALF + CRAG_BLEND, r)
		h = lerpf(top, lerpf(ledge, 0.0, outer), inner)
		walls = inner * (1.0 - inner) * clampf((top - ledge) * 0.5, 0.0, 1.0) + outer * (1.0 - outer) * clampf(ledge * 0.5, 0.0, 1.0)
	else:
		var wall := LEDGE_R0 - LEDGE_HALF
		var k := smoothstep(wall, wall + CRAG_BLEND, r)
		h = lerpf(top, 0.0, k)
		walls = k * (1.0 - k)
	# Jagged rock on the walls.
	return h + _detail.get_noise_2d(x * 1.4, z * 1.4) * 2.0 * walls

# ---- beaches ----

# How far along beach i a point lies (0 at the sea end, 1 at the meadow), its
# distance off the beach's centre line, and the beach's weight there.
static func _beach(i: int, x: float, z: float) -> Vector3:
	var a := deg_to_rad(float(BEACHES[i]))
	var along := x * sin(a) + z * cos(a)
	var lateral := absf(x * cos(a) - z * sin(a))
	var t := clampf((BEACH_OUT - along) / (BEACH_OUT - BEACH_IN), 0.0, 1.0)
	var half := lerpf(BEACH_MOUTH, BEACH_NECK, smoothstep(0.2, 0.85, t))
	var k := (1.0 - smoothstep(half, half + BEACH_BLEND, lateral)) * smoothstep(BEACH_IN - 2.0, BEACH_IN, along)
	return Vector3(t, lateral, k)

## Weight of the strongest beach at this point (0 off the beaches).
static func beach_weight(x: float, z: float) -> float:
	var w := 0.0
	for i in BEACHES.size():
		w = maxf(w, _beach(i, x, z).z)
	return w

## A point on beach i: t from 0 (out under the sea) to 1 (top of the gully), lateral offset in metres.
static func beach_point(i: int, t: float, lateral: float = 0.0) -> Vector3:
	var a := deg_to_rad(float(BEACHES[i]))
	var along := lerpf(BEACH_OUT, BEACH_IN, t)
	var p := Vector3(sin(a) * along + cos(a) * lateral, 0.0, cos(a) * along - sin(a) * lateral)
	p.y = height_at(p.x, p.z)
	return p

## Half width of beach i's walkable shingle at t.
static func beach_half_width(t: float) -> float:
	return lerpf(BEACH_MOUTH, BEACH_NECK, smoothstep(0.2, 0.85, t))

# ---- height ----

## Height of the island at a point.
static func height_at(x: float, z: float) -> float:
	_ensure_noise()
	var r := Vector2(x, z).length()
	var bumps := (_noise.get_noise_2d(x, z) * 0.3 + _detail.get_noise_2d(x, z) * 0.06) * smoothstep(9.2, 10.4, r) * _pad_flatten(x, z)
	var top := PLATEAU_HEIGHT + bumps
	var edge := coast_radius(compass_deg(x, z))
	var t := smoothstep(edge, edge + CLIFF_WIDTH, r)
	var crag := _detail.get_noise_2d(x * 1.6, z * 1.6) * 0.45 * t * (1.0 - t) * 4.0
	var h := lerpf(top, SHELF_DEPTH, t) + crag
	if r > edge + CLIFF_WIDTH:
		h = lerpf(SHELF_DEPTH, SEA_FLOOR, smoothstep(edge + CLIFF_WIDTH, SEA_FLOOR_END, r))
	for i in BEACHES.size():
		var b := _beach(i, x, z)
		if b.z > 0.0:
			var hb := lerpf(BEACH_SEA_H, PLATEAU_HEIGHT, b.x) + _detail.get_noise_2d(x * 2.2, z * 2.2) * 0.08
			h = lerpf(h, hb, b.z)
	return h + _crag(x, z, r)

static func height_at_v(p: Vector3) -> float:
	return height_at(p.x, p.z)

## Steepest rise per metre around a point.
static func slope_at(x: float, z: float) -> float:
	var e := 0.3
	var dx := height_at(x + e, z) - height_at(x - e, z)
	var dz := height_at(x, z + e) - height_at(x, z - e)
	return Vector2(dx, dz).length() / (2.0 * e)

## True where a keeper may stand: above the water and not on a cliff or crag wall.
static func walkable(x: float, z: float) -> bool:
	return height_at(x, z) > SEA_LEVEL - 0.1 and slope_at(x, z) < 1.1

# ---- paint ----

static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return (a + ab * t).distance_to(p)

## Distance to the nearest worn track: the ring round the crag, the beach gullies
## and the paths from the buildings to the ring.
static func _path_dist(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var best := absf(p.length() - RING_R)
	for i in BEACHES.size():
		var a := deg_to_rad(float(BEACHES[i]))
		var d := Vector2(sin(a), cos(a))
		best = minf(best, _seg_dist(p, d * RING_R, d * (COAST + 0.5)))
	for pad in PADS:
		var c := Vector2(float(pad[0]), float(pad[1]))
		best = minf(best, _seg_dist(p, c, c.normalized() * RING_R))
	return best

## True on the ledge's walking surface.
static func on_ledge(x: float, z: float) -> bool:
	var s := ledge_s(x, z)
	return s >= 0.0 and absf(Vector2(x, z).length() - ledge_radius(s)) < LEDGE_HALF - 0.1

## True where grass may grow: flat meadow or crag top, off the tracks, pads and beaches.
static func is_grassy(x: float, z: float) -> bool:
	var r := Vector2(x, z).length()
	if r > coast_radius(compass_deg(x, z)) - 0.4 or r < YARD_RADIUS + 0.5:
		return false
	var h := height_at(x, z)
	if absf(h - PLATEAU_HEIGHT) > 0.45 and absf(h - CRAG_TOP) > 0.15:
		return false
	if slope_at(x, z) > 0.4 or on_ledge(x, z) or beach_weight(x, z) > 0.3:
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
	var pd := _path_dist(x, z)
	if pd < 0.8:
		c = DIRT.lerp(c, smoothstep(0.4, 0.8, pd))
	if on_ledge(x, z):
		# A worn track, like the one round the foot, so the way up reads from above.
		c = DIRT.lerp(GRAVEL, clampf(_detail.get_noise_2d(x * 2.0, z * 2.0) * 0.8 + 0.2, 0.0, 0.5))
	if r < YARD_RADIUS + 0.6 and h > CRAG_TOP - 0.2:
		c = GRAVEL.lerp(c, smoothstep(YARD_RADIUS - 0.4, YARD_RADIUS + 0.6, r))
	var beach := beach_weight(x, z)
	if beach > 0.4 and h < PLATEAU_HEIGHT - 0.25:
		c = c.lerp(SHINGLE, smoothstep(0.4, 0.8, beach))
	# Rock wherever the ground is steep or past the cliff line, mossy on the gentler faces.
	var edge := coast_radius(compass_deg(x, z))
	var past_edge := smoothstep(edge - 0.4, edge + 0.6, r) * (1.0 - beach)
	var rockiness := maxf(smoothstep(0.22, 0.45, steep), past_edge)
	var rock := ROCK.lerp(ROCK_DARK, clampf(_detail.get_noise_2d(x * 2.0, z * 2.0) + 0.5, 0.0, 1.0))
	rock = rock.lerp(MOSS, clampf(0.45 - steep, 0.0, 0.45))
	if on_ledge(x, z):
		rockiness *= 0.25
	c = c.lerp(rock, rockiness)
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
