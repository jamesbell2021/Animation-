class_name Terrain
extends RefCounted
## The island's shape, Bad North style: a meadow ringed by sheer cliffs, three
## shingle beaches where the sea can come ashore, and a crag in the middle with
## the lighthouse on top, reached only by a ledge path that winds up around it.
## East of it, across a gully of sea spanned by a rope bridge, lies the holm: a low,
## flat island with the old wartime camp on it.
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
const GRID_STEP := 0.45
const JITTER := 0.1

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

# The holm: its plateau is a rounded box (centre, half size, corner radius), low and
# flat, with two shingle beaches ([compass angle from its centre, distance to its edge]).
const HOLM_C := Vector2(48.5, 3.0)
const HOLM_HALF := Vector2(16.5, 13.5)
const HOLM_ROUND := 5.0
const HOLM_HEIGHT := 1.4
const HOLM_CLIFF := 1.6
const HOLM_BEACHES := [[90.0, 16.5], [180.0, 13.5]]
## The camp's fenced compound on the holm (centre, half size): flattened, gravel inside.
const CAMP_C := Vector2(48.0, 3.0)
const CAMP_HALF := Vector2(11.0, 8.5)
## The rope bridge leaves the main island's clifftop at this compass angle.
const BRIDGE_ANGLE := 70.0
const BRIDGE_HALF := 0.55
# The ground mesh's extent: the main island's square, and the holm's beside it.
const HOLM_GRID_X := Vector2(GRID_HALF, 77.0)

static var _noise: FastNoiseLite
static var _detail: FastNoiseLite
static var _bridge_ends: Array = []

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

## Height of the ground at a point: the main island or the holm, whichever stands
## higher there (both fall away to the same sea floor).
static func height_at(x: float, z: float) -> float:
	return maxf(_main_height(x, z), _holm_height(x, z))

static func _main_height(x: float, z: float) -> float:
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

## True where a keeper may stand: above the water and not on a cliff or crag wall,
## or on the rope bridge's deck.
static func walkable(x: float, z: float) -> bool:
	if on_bridge(x, z):
		return true
	return height_at(x, z) > SEA_LEVEL - 0.1 and slope_at(x, z) < 1.1

# ---- the holm ----

# Signed distance from the holm's plateau edge (negative inside), with a ragged coast.
static func holm_edge_dist(x: float, z: float) -> float:
	_ensure_noise()
	var q := Vector2(x, z) - HOLM_C
	var b := HOLM_HALF - Vector2(HOLM_ROUND, HOLM_ROUND)
	var d := Vector2(absf(q.x), absf(q.y)) - b
	var sd := Vector2(maxf(d.x, 0.0), maxf(d.y, 0.0)).length() + minf(maxf(d.x, d.y), 0.0) - HOLM_ROUND
	return sd + _noise.get_noise_2d(x * 0.8 + 300.0, z * 0.8) * 0.9

## True on the holm (its plateau, cliffs or beaches) rather than the main island.
static func on_holm(x: float, z: float) -> bool:
	return _holm_height(x, z) > _main_height(x, z)

## True inside the camp's fence.
static func in_camp(x: float, z: float, margin: float = 0.0) -> bool:
	var q := Vector2(x, z) - CAMP_C
	return absf(q.x) < CAMP_HALF.x - margin and absf(q.y) < CAMP_HALF.y - margin

# Beach i of the holm: how far up it (0 at sea, 1 on the plateau), off its centre line, and its weight.
static func _holm_beach(i: int, x: float, z: float) -> Vector3:
	var a := deg_to_rad(float(HOLM_BEACHES[i][0]))
	var edge := float(HOLM_BEACHES[i][1])
	var q := Vector2(x, z) - HOLM_C
	var along := q.x * sin(a) + q.y * cos(a)
	var lateral := absf(q.x * cos(a) - q.y * sin(a))
	var outer := edge + 8.0
	var inner := edge - 1.5
	var t := clampf((outer - along) / (outer - inner), 0.0, 1.0)
	var half := lerpf(4.5, 2.0, smoothstep(0.2, 0.85, t))
	var k := (1.0 - smoothstep(half, half + BEACH_BLEND, lateral)) * smoothstep(inner - 2.0, inner, along)
	return Vector3(t, lateral, k)

static func holm_beach_weight(x: float, z: float) -> float:
	var w := 0.0
	for i in HOLM_BEACHES.size():
		w = maxf(w, _holm_beach(i, x, z).z)
	return w

## A point on the holm's beach i: t from 0 (out under the sea) to 1 (the plateau).
static func holm_beach_point(i: int, t: float, lateral: float = 0.0) -> Vector3:
	var a := deg_to_rad(float(HOLM_BEACHES[i][0]))
	var edge := float(HOLM_BEACHES[i][1])
	var along := lerpf(edge + 8.0, edge - 1.5, t)
	var p := Vector3(HOLM_C.x + sin(a) * along + cos(a) * lateral, 0.0, HOLM_C.y + cos(a) * along - sin(a) * lateral)
	p.y = height_at(p.x, p.z)
	return p

static func _holm_height(x: float, z: float) -> float:
	_ensure_noise()
	var d := holm_edge_dist(x, z)
	if d > 14.0:
		return SEA_FLOOR
	# Rough grazing outside the compound; flat ground inside it.
	var flat := 1.0
	var q := Vector2(x, z) - CAMP_C
	var out := Vector2(maxf(absf(q.x) - CAMP_HALF.x, 0.0), maxf(absf(q.y) - CAMP_HALF.y, 0.0)).length()
	flat = smoothstep(0.5, 3.0, out)
	var top := HOLM_HEIGHT + (_noise.get_noise_2d(x * 0.9, z * 0.9) * 0.22 + _detail.get_noise_2d(x, z) * 0.05) * flat
	var t := smoothstep(0.0, HOLM_CLIFF, d)
	var h := lerpf(top, SHELF_DEPTH, t) + _detail.get_noise_2d(x * 1.6, z * 1.6) * 0.4 * t * (1.0 - t) * 4.0
	if d > HOLM_CLIFF:
		h = lerpf(SHELF_DEPTH, SEA_FLOOR, smoothstep(HOLM_CLIFF, 10.0, d))
	for i in HOLM_BEACHES.size():
		var b := _holm_beach(i, x, z)
		if b.z > 0.0:
			var hb := lerpf(BEACH_SEA_H, HOLM_HEIGHT, b.x) + _detail.get_noise_2d(x * 2.2, z * 2.2) * 0.08
			h = lerpf(h, hb, b.z)
	return h

# ---- the rope bridge ----

## The bridge's two ends on the clifftops: [main island end, holm end]. It runs from the
## main island's meadow at BRIDGE_ANGLE toward the holm's middle; each end is just back
## from where its clifftop falls away.
static func bridge_ends() -> Array:
	if not _bridge_ends.is_empty():
		return _bridge_ends
	var a := deg_to_rad(BRIDGE_ANGLE)
	var start := Vector2(sin(a), cos(a)) * 9.0
	var dir := (HOLM_C - start).normalized()
	var main_end := start
	for i in 800:
		var p := start + dir * float(i) * 0.05
		if _main_height(p.x, p.y) < PLATEAU_HEIGHT - 0.6:
			main_end = p - dir * 1.3
			break
	var holm_end := HOLM_C
	for i in 800:
		var p := HOLM_C - dir * float(i) * 0.05
		if _holm_height(p.x, p.y) < HOLM_HEIGHT - 0.5:
			holm_end = p + dir * 1.3
			break
	_bridge_ends = [Vector3(main_end.x, height_at(main_end.x, main_end.y), main_end.y),
		Vector3(holm_end.x, height_at(holm_end.x, holm_end.y), holm_end.y)]
	return _bridge_ends

## How far across the bridge a point is (0 at the main island's end, 1 at the holm's)
## and how far off its centre line, flat.
static func bridge_coords(x: float, z: float) -> Vector2:
	var e := bridge_ends()
	var a := Vector2(e[0].x, e[0].z)
	var b := Vector2(e[1].x, e[1].z)
	var ab := b - a
	var p := Vector2(x, z) - a
	var u := p.dot(ab) / ab.length_squared()
	var side := (p - ab * u).length()
	return Vector2(u, side)

## True on the bridge's deck (between its ends, within its width, allowing for its swing:
## the rope sides are what keep a keeper on it).
static func on_bridge(x: float, z: float) -> bool:
	var c := bridge_coords(x, z)
	return c.x > -0.02 and c.x < 1.02 and c.y < BRIDGE_HALF + 0.5

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

## Where the camp's gate is: the middle of the compound's west side, facing the bridge.
## Whether a point is nearer the holm than the main island (for which island something is on).
static func holm_side(x: float, z: float) -> bool:
	return Vector2(x, z).distance_to(HOLM_C) < Vector2(x, z).length()

static func camp_gate() -> Vector2:
	return Vector2(CAMP_C.x - CAMP_HALF.x, CAMP_C.y)

# Distance to the holm's worn track: from the bridge's end to the camp gate.
static func _holm_path_dist(x: float, z: float) -> float:
	var e := bridge_ends()
	return _seg_dist(Vector2(x, z), Vector2(e[1].x, e[1].z), camp_gate())

## True where grass may grow: flat meadow or crag top, off the tracks, pads and beaches.
static func is_grassy(x: float, z: float) -> bool:
	if on_holm(x, z):
		if holm_edge_dist(x, z) > -0.5 or in_camp(x, z, -0.8):
			return false
		if absf(height_at(x, z) - HOLM_HEIGHT) > 0.4 or slope_at(x, z) > 0.4 or holm_beach_weight(x, z) > 0.3:
			return false
		return _holm_path_dist(x, z) > 0.75
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
	if on_holm(x, z):
		return _holm_color(x, z, h, steep)
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

## What the ground is made of at a point, for the terrain shader's texture layers:
## x rock, y shingle, z dirt (worn track, bare patches), w wet (by the sea). Grass is
## whatever is left. Follows the same rules as color_at, so texture and paint agree.
static func layers_at(x: float, z: float, h: float, steep: float) -> Vector4:
	_ensure_noise()
	if on_holm(x, z):
		return _holm_layers(x, z, h, steep)
	var r := Vector2(x, z).length()
	var dirt := 0.0
	if _detail.get_noise_2d(x * 0.6, z * 0.6 + 90.0) > 0.42:
		dirt = 0.7
	if _pad_flatten(x, z) < 0.5:
		dirt = maxf(dirt, 0.55)
	var pd := _path_dist(x, z)
	if pd < 0.8:
		dirt = maxf(dirt, 1.0 - smoothstep(0.4, 0.8, pd))
	if on_ledge(x, z):
		dirt = 1.0
	var shingle := 0.0
	if r < YARD_RADIUS + 0.6 and h > CRAG_TOP - 0.2:
		shingle = 1.0 - smoothstep(YARD_RADIUS - 0.4, YARD_RADIUS + 0.6, r)
	var beach := beach_weight(x, z)
	if beach > 0.4 and h < PLATEAU_HEIGHT - 0.25:
		shingle = maxf(shingle, smoothstep(0.4, 0.8, beach))
	if h < SEA_LEVEL - 0.5:
		shingle = 1.0
	var edge := coast_radius(compass_deg(x, z))
	var past_edge := smoothstep(edge - 0.4, edge + 0.6, r) * (1.0 - beach)
	var rock := maxf(smoothstep(0.22, 0.45, steep), past_edge)
	if on_ledge(x, z):
		rock *= 0.25
	if h < SEA_LEVEL - 0.5:
		rock *= 0.3
	var wet := clampf((SEA_LEVEL + 0.25 - h) * 2.5, 0.0, 1.0)
	return Vector4(rock, shingle, dirt, wet)

# The holm: sea-grazed grass, the camp's trodden earth and gravel inside the wire, the
# track to the bridge, shingle on its beaches, rock on its low cliffs.
static func _holm_color(x: float, z: float, h: float, steep: float) -> Color:
	var l := _holm_layers(x, z, h, steep)
	var n := _noise.get_noise_2d(x * 1.7 + 40.0, z * 1.7)
	var c := GRASS_A.lerp(GRASS_B, clampf(n * 0.9 + 0.6, 0.0, 1.0)).lerp(Color(0.42, 0.42, 0.22), 0.18)
	c = c.lerp(DIRT.lerp(GRAVEL, clampf(_detail.get_noise_2d(x * 1.3, z * 1.3) + 0.4, 0.0, 0.7)), l.z)
	c = c.lerp(SHINGLE, l.y)
	var rock := ROCK.lerp(ROCK_DARK, clampf(_detail.get_noise_2d(x * 2.0, z * 2.0) + 0.5, 0.0, 1.0))
	rock = rock.lerp(MOSS, clampf(0.45 - steep, 0.0, 0.45))
	c = c.lerp(rock, l.x)
	if h < SEA_LEVEL + 0.1:
		c = c.lerp(WET, clampf((SEA_LEVEL + 0.1 - h) * 3.0, 0.0, 1.0))
	if h < SEA_LEVEL - 0.5:
		c = SEABED
	return c

static func _holm_layers(x: float, z: float, h: float, steep: float) -> Vector4:
	var dirt := 0.0
	if in_camp(x, z, -0.6):
		dirt = 0.85
	var pd := _holm_path_dist(x, z)
	if pd < 0.9:
		dirt = maxf(dirt, 1.0 - smoothstep(0.5, 0.9, pd))
	if _detail.get_noise_2d(x * 0.6, z * 0.6 + 90.0) > 0.45:
		dirt = maxf(dirt, 0.6)
	var beach := holm_beach_weight(x, z)
	var shingle := smoothstep(0.4, 0.8, beach) if h < HOLM_HEIGHT - 0.2 else 0.0
	if h < SEA_LEVEL - 0.5:
		shingle = 1.0
	var past_edge := smoothstep(-0.4, 0.6, holm_edge_dist(x, z)) * (1.0 - beach)
	var rock := maxf(smoothstep(0.22, 0.45, steep), past_edge)
	if h < SEA_LEVEL - 0.5:
		rock *= 0.3
	var wet := clampf((SEA_LEVEL + 0.25 - h) * 2.5, 0.0, 1.0)
	return Vector4(rock, shingle, dirt, wet)

## The ground's surface normal from the height function itself (smooth everywhere).
static func normal_at(x: float, z: float) -> Vector3:
	var e := 0.12
	var hx := height_at(x + e, z) - height_at(x - e, z)
	var hz := height_at(x, z + e) - height_at(x, z - e)
	return Vector3(-hx, 2.0 * e, -hz).normalized()

## The ground mesh: a jittered grid with shared, smooth-shaded vertices. Each vertex
## carries its painted colour and, for the terrain shader, its texture layer weights
## (UV: rock, shingle; UV2: dirt, wet).
static func build_mesh() -> ArrayMesh:
	return _grid_mesh(-GRID_HALF, GRID_HALF, -GRID_HALF, GRID_HALF)

## The holm's ground, beside the main island's: the same grid, so the two meet exactly.
static func build_holm_mesh() -> ArrayMesh:
	return _grid_mesh(HOLM_GRID_X.x, HOLM_GRID_X.y, -GRID_HALF, GRID_HALF)

static func _grid_mesh(x0: float, x1: float, z0: float, z1: float) -> ArrayMesh:
	var nx := int(roundf((x1 - x0) / GRID_STEP)) + 1
	var nz := int(roundf((z1 - z0) / GRID_STEP)) + 1
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	verts.resize(nx * nz)
	normals.resize(nx * nz)
	colors.resize(nx * nz)
	uv.resize(nx * nz)
	uv2.resize(nx * nz)
	for j in nz:
		for i in nx:
			var x := x0 + float(i) * GRID_STEP
			var z := z0 + float(j) * GRID_STEP
			# Jittered inside; the border stays on the grid, so neighbouring meshes meet.
			var inside := i > 0 and i < nx - 1 and j > 0 and j < nz - 1
			if inside:
				x += (_hash(i, j, 1) - 0.5) * JITTER * 2.0
				z += (_hash(i, j, 2) - 0.5) * JITTER * 2.0
			var h := height_at(x, z)
			var nrm := normal_at(x, z)
			var steep := 1.0 - absf(nrm.y)
			var k := j * nx + i
			verts[k] = Vector3(x, h, z)
			normals[k] = nrm
			colors[k] = color_at(x, z, h, steep)
			var l := layers_at(x, z, h, steep)
			uv[k] = Vector2(l.x, l.y)
			uv2[k] = Vector2(l.z, l.w)
	var idx := PackedInt32Array()
	for j in nz - 1:
		for i in nx - 1:
			var a := j * nx + i
			var b := a + 1
			var c := a + nx
			var d := c + 1
			# Split each quad along the diagonal that best follows the ground.
			if absf(verts[a].y - verts[d].y) < absf(verts[b].y - verts[c].y):
				idx.append_array([a, b, d, a, d, c])
			else:
				idx.append_array([a, b, c, b, d, c])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
