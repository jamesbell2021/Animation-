class_name HarbourMap
extends RefCounted
## Kirkhaven, Chapter Two's ground: a fishing harbour on the mainland whose lights have
## gone out. The sea is to the south (+z, toward the camera); the quay runs east-west
## along z = QUAY_Z with the house fronts facing it across an apron; a stone pier runs
## out from its middle to the harbour light; two slipways and the strand at the east
## end are where the sea comes up. Behind the front, two wynds climb past a back street
## to the kirk on its green.
##
## Terrain hands height, colour and walking over to this class while Terrain.chapter is
## 2, so keepers, creatures and the ground mesh need no changes of their own. The town's
## plan (buildings, lamps, landings) is data here: HarbourMain builds from it, and the
## pathfinding grid (creatures and helper keepers) is laid over it.

const QUAY_Z := 6.0
const QUAY_H := 1.3
const BASIN := -2.6
## The pier: a narrow stem out from the quay, widening to a head where the light stands.
const PIER_HALF := 2.6
const PIER_HEAD_HALF := 5.2
const PIER_HEAD_FROM := 18.0
const PIER_END := 31.0
const LIGHT_AT := Vector2(0.0, 24.0)
## The slipways (x of each centre line), cut seaward from the quay's edge.
const SLIPS := [-15.0, 15.0]
const SLIP_HALF := 2.6
const SLIP_FOOT := 18.0
const SLIP_SEA_H := -1.9
## East of this the quay ends and the strand (a shingle beach) runs down to the water.
const STRAND_X := 25.0
const STRAND_C := 31.0
const STRAND_TOP := 1.0
const STRAND_FOOT := 17.0
## The edges of the town: rock to the west and east, the hill behind.
const WEST := -34.0
const EAST := 38.0
const NORTH := -37.0
## The terraces the town climbs: the front and apron, the back street, the kirk green.
const BACK_H := 2.9
const GREEN_H := 4.5
const RISE_1 := Vector2(-8.0, -13.0)
const RISE_2 := Vector2(-20.0, -24.0)
const KIRK_AT := Vector2(0.0, -29.5)
const KIRK_GATE := Vector2(0.0, -21.5)
## The kirkyard's wall (the gate is a gap in the middle of its south side).
const KIRKYARD := Rect2(-6.5, -36.5, 13.0, 15.0)
const GATE_HALF := 1.0
const GENERATOR_AT := Vector2(-31.0, 3.0)
const START := Vector2(2.0, 12.0)

## The ground mesh's extent.
const GRID := Rect2(-56.0, -45.0, 114.0, 80.0)

const FLAGS := Color(0.40, 0.40, 0.39)
const SETTS := Color(0.33, 0.32, 0.31)
const TURF_A := Color(0.19, 0.28, 0.11)
const TURF_B := Color(0.28, 0.34, 0.14)
const WEED := Color(0.14, 0.17, 0.10)

## The two in the middle of the back row stand apart: the kirk wynd runs between them
## from the back street to the kirk gate.
## The town: [x, z of the centre, width, wall height, depth, style, sign, roof, harl tint].
## Fronts face the sea. HarbourMain makes a TownHouse of each.
const BUILDINGS := [
	[-29.5, -4.0, 5.0, 2.8, 5.0, "office", "HARBOUR OFFICE", "slate", 0],
	[-22.3, -4.8, 8.4, 3.6, 6.6, "shed", "KIRKHAVEN ICE & FISH", "slate", 3],
	[-15.0, -4.5, 5.6, 2.8, 6.0, "cottage", "", "pantile", 1],
	[-4.4, -4.5, 7.0, 3.0, 6.0, "shop", "RENNIE & SON · CHANDLERS", "slate", 2],
	[3.6, -4.8, 8.4, 5.2, 6.6, "pub", "THE CREEL", "slate", 0],
	[15.0, -4.5, 5.6, 5.0, 6.0, "house", "", "pantile", 1],
	[21.5, -4.5, 6.0, 2.8, 6.0, "cottage", "", "slate", 2],
	[29.6, -5.2, 6.0, 3.2, 6.0, "shed", "", "pantile", 3],
	[-25.2, -16.4, 6.4, 2.8, 5.6, "cottage", "", "slate", 1],
	[-16.6, -16.4, 6.4, 2.8, 5.6, "cottage", "", "pantile", 0],
	[-5.0, -16.4, 6.4, 4.8, 5.6, "house", "", "slate", 2],
	[5.0, -16.4, 6.4, 2.8, 5.6, "cottage", "", "pantile", 1],
	[15.6, -16.4, 6.4, 2.8, 5.6, "cottage", "", "slate", 0],
	[23.0, -16.4, 6.0, 2.8, 5.6, "cottage", "", "pantile", 2],
	[30.2, -16.4, 6.0, 2.8, 5.6, "cottage", "", "slate", 1],
	[-21.0, -30.0, 7.0, 4.8, 6.0, "house", "", "slate", 0],
	[21.5, -30.0, 8.0, 3.2, 6.0, "cottage", "KIRK HALL", "slate", 2],
]
## The kirk's footprint (nave and tower), for the pathfinding grid.
const KIRK_RECT := Rect2(-5.0, -35.0, 8.6, 11.0)
## The street lamps: [x, z, name]. The quay's from west to east, then the wynds and the
## kirk gate.
const LAMPS := [
	[-25.0, 4.7, "the west quay lamp"],
	[-19.6, 4.7, "the lamp west of the west slip"],
	[-10.4, 4.7, "the lamp east of the west slip"],
	[-3.8, 4.7, "the lamp west of the pier"],
	[3.8, 4.7, "the lamp east of the pier"],
	[10.4, 4.7, "the lamp west of the east slip"],
	[19.6, 4.7, "the lamp east of the east slip"],
	[25.6, 2.6, "the strand lamp"],
	[-10.0, -10.6, "the west wynd lamp"],
	[10.0, -10.6, "the east wynd lamp"],
	[2.4, -20.2, "the kirk gate lamp"],
]
## Where the sea comes up: [name, offshore point, the top (where it meets the town)].
const LANDINGS := [
	["the west slip", Vector2(-15.0, 17.6), Vector2(-15.0, 6.5)],
	["the east slip", Vector2(15.0, 17.6), Vector2(15.0, 6.5)],
	["the strand", Vector2(31.0, 16.4), Vector2(30.0, 3.0)],
]
## Along each landing, from the water up: what Terrain.beach_point walks.
const LANDING_SPREAD := [1.2, 1.2, 2.2]

static var _noise: FastNoiseLite

static func _ensure_noise() -> void:
	if _noise != null:
		return
	_noise = FastNoiseLite.new()
	_noise.seed = 1987
	_noise.frequency = 0.11
	_noise.fractal_octaves = 3

# ---- height ----

# The land: three terraces and the ramps between them.
static func _town(z: float) -> float:
	var h := lerpf(QUAY_H, BACK_H, smoothstep(RISE_1.x, RISE_1.y, z))
	h = lerpf(h, GREEN_H, smoothstep(RISE_2.x, RISE_2.y, z))
	return h

## How far a point is into the pier (0 off it, 1 on its deck).
static func _pier(x: float, z: float) -> float:
	if z < QUAY_Z - 1.0 or z > PIER_END + 1.0:
		return 0.0
	var half := lerpf(PIER_HALF, PIER_HEAD_HALF, smoothstep(PIER_HEAD_FROM - 0.6, PIER_HEAD_FROM, z))
	return (1.0 - smoothstep(half, half + 0.5, absf(x))) * (1.0 - smoothstep(PIER_END, PIER_END + 0.5, z))

## Slip i's weight at a point (0 off it, 1 on its ramp).
static func _slip(i: int, x: float) -> float:
	return 1.0 - smoothstep(SLIP_HALF, SLIP_HALF + 0.5, absf(x - float(SLIPS[i])))

static func _ramp(z: float, top: float, foot: float) -> float:
	var h := lerpf(QUAY_H, SLIP_SEA_H, clampf((z - top) / (foot - top), 0.0, 1.0))
	if z > foot:
		h = lerpf(SLIP_SEA_H, BASIN, smoothstep(foot, foot + 4.0, z))
	return h

static func height_at(x: float, z: float) -> float:
	_ensure_noise()
	var h := _town(z)
	# The kirk green and the hill behind are rough ground; the town is paved flat.
	if z < RISE_2.y:
		h += _noise.get_noise_2d(x, z) * 0.12
	if z < NORTH:
		h += (NORTH - z) * 1.7 + _noise.get_noise_2d(x * 2.0, z * 2.0) * 0.5 * smoothstep(NORTH, NORTH - 3.0, z)
	# The quay wall, and the basin beyond it.
	if z > QUAY_Z:
		h = lerpf(QUAY_H, BASIN, smoothstep(QUAY_Z, QUAY_Z + 0.5, z))
		for i in SLIPS.size():
			h = lerpf(h, _ramp(z, QUAY_Z, SLIP_FOOT), _slip(i, x))
		h = lerpf(h, QUAY_H, _pier(x, z))
	# The strand, east of the quay's end: shingle down to the water.
	var strand := smoothstep(STRAND_X, STRAND_X + 2.5, x)
	if strand > 0.0 and z > STRAND_TOP:
		var hs := _ramp(z, STRAND_TOP, STRAND_FOOT) + _noise.get_noise_2d(x * 3.0, z * 3.0) * 0.05
		h = lerpf(h, hs, strand)
	# Rock at either end, running out into the sea as the harbour's arms.
	var west := smoothstep(WEST, WEST - 5.0, x) * (1.0 - smoothstep(20.0, 30.0, z))
	var east := smoothstep(EAST, EAST + 5.0, x) * (1.0 - smoothstep(12.0, 24.0, z))
	var arm := maxf(west, east)
	if arm > 0.0:
		var crag := 4.8 + _noise.get_noise_2d(x * 1.8, z * 1.8) * 1.6
		h = lerpf(h, maxf(h, crag), arm)
	return h

# ---- where things are ----

## Landing i's line, from the water (t = 0) to its top (t = 1), offset sideways.
static func landing_point(i: int, t: float, lateral: float = 0.0) -> Vector3:
	var l: Array = LANDINGS[clampi(i, 0, LANDINGS.size() - 1)]
	var p: Vector2 = (l[1] as Vector2).lerp(l[2], clampf(t, 0.0, 1.0))
	p.x += lateral
	return Vector3(p.x, height_at(p.x, p.y), p.y)

## The landing a point is nearest, and how near (metres).
static func nearest_landing(x: float, z: float) -> int:
	var best := 0
	var best_d := INF
	for i in LANDINGS.size():
		var d := _seg(Vector2(x, z), LANDINGS[i][1], LANDINGS[i][2])
		if d < best_d:
			best_d = d
			best = i
	return best

static func _seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)

## 1 on a slip or the strand below the town's level (where creatures wade), else 0.
static func shore_weight(x: float, z: float) -> float:
	if z <= QUAY_Z - 0.5 and x < STRAND_X:
		return 0.0
	var w := 0.0
	if z > QUAY_Z:
		for i in SLIPS.size():
			w = maxf(w, _slip(i, x))
	if z > STRAND_TOP:
		w = maxf(w, smoothstep(STRAND_X, STRAND_X + 2.5, x) * (1.0 - smoothstep(EAST, EAST + 3.0, x)))
	return w

static func in_bounds(x: float, z: float) -> bool:
	return x > WEST - 1.0 and x < EAST + 1.0 and z > NORTH - 0.5 and z < PIER_END + 1.0

## True where a keeper may stand: dry, not on the quay's lip or a rock face, in the town.
static func walkable(x: float, z: float) -> bool:
	if not in_bounds(x, z):
		return false
	return height_at(x, z) > Terrain.SEA_LEVEL - 0.1 and Terrain.slope_at(x, z) < 1.1

## Grass grows on the kirk green and the hill, off the path to the door.
static func is_grassy(x: float, z: float) -> bool:
	if z > RISE_2.y - 0.5 or absf(x) > EAST - 3.0:
		return false
	if absf(x - KIRK_GATE.x) < 1.1 and z > KIRK_AT.y + 4.0:
		return false
	if KIRK_RECT.grow(0.6).has_point(Vector2(x, z)):
		return false
	for b in BUILDINGS:
		if Rect2(float(b[0]) - float(b[2]) * 0.5, float(b[1]) - float(b[4]) * 0.5, float(b[2]), float(b[4])).grow(0.5).has_point(Vector2(x, z)):
			return false
	return Terrain.slope_at(x, z) < 0.6

## A plain name for where a point is, for warnings ("the west slip", "the back street").
static func place_name(p: Vector3) -> String:
	var q := Vector2(p.x, p.z)
	if q.y > QUAY_Z or (q.x > STRAND_X and q.y > STRAND_TOP):
		if _pier(q.x, q.y) > 0.5:
			return "the pier"
		return String(LANDINGS[nearest_landing(q.x, q.y)][0])
	if q.y > -1.5:
		return "the quay"
	if q.y < RISE_2.x:
		return "the kirk green"
	if q.y < RISE_1.x:
		return "the back street"
	return "the wynds"

# ---- paint ----

static func color_at(x: float, z: float, h: float, steep: float) -> Color:
	_ensure_noise()
	var n := _noise.get_noise_2d(x * 1.9 + 30.0, z * 1.9)
	var c := FLAGS.lerp(SETTS, clampf(n * 0.8 + 0.5, 0.0, 1.0))
	if z < RISE_1.x and z > RISE_2.y:
		c = SETTS.lerp(Terrain.DIRT, clampf(n * 0.5 + 0.25, 0.0, 0.5))
	if z <= RISE_2.y:
		c = TURF_A.lerp(TURF_B, clampf(n * 0.9 + 0.5, 0.0, 1.0))
		if absf(x - KIRK_GATE.x) < 1.0 and z > KIRK_AT.y + 4.0:
			c = Terrain.DIRT.lerp(Terrain.GRAVEL, 0.4)
	if z < NORTH:
		c = c.lerp(Terrain.HEATHER, 0.5)
	var shore := shore_weight(x, z)
	if shore > 0.3 and x > STRAND_X:
		c = c.lerp(Terrain.SHINGLE, smoothstep(0.3, 0.8, shore))
	var rock := Terrain.ROCK.lerp(Terrain.ROCK_DARK, clampf(_noise.get_noise_2d(x * 3.0, z * 3.0) + 0.5, 0.0, 1.0))
	c = c.lerp(rock, smoothstep(0.25, 0.5, steep))
	if x < WEST or x > EAST:
		c = c.lerp(rock, 0.8)
	if h < Terrain.SEA_LEVEL + 0.5:
		c = c.lerp(WEED, clampf((Terrain.SEA_LEVEL + 0.5 - h) * 1.6, 0.0, 0.8))
	if h < Terrain.SEA_LEVEL - 0.7:
		c = Terrain.SEABED
	return c

## Texture layers for the terrain shader: x rock, y shingle, z dirt, w wet; grass is the
## rest. The paved town is rock and shingle (flags and setts), the green is grass.
static func layers_at(x: float, z: float, h: float, steep: float) -> Vector4:
	_ensure_noise()
	var rock := 0.75
	var shingle := 0.25
	var dirt := 0.0
	if z < RISE_1.x and z > RISE_2.y:
		rock = 0.35
		shingle = 0.5
		dirt = 0.15
	if z <= RISE_2.y:
		rock = 0.0
		shingle = 0.0
		if absf(x - KIRK_GATE.x) < 1.0 and z > KIRK_AT.y + 4.0:
			dirt = 0.9
	var shore := shore_weight(x, z)
	if shore > 0.3 and x > STRAND_X:
		var k := smoothstep(0.3, 0.8, shore)
		rock = lerpf(rock, 0.0, k)
		shingle = lerpf(shingle, 1.0, k)
	rock = maxf(rock, smoothstep(0.25, 0.5, steep))
	if x < WEST or x > EAST:
		rock = maxf(rock, 0.8)
	if h < Terrain.SEA_LEVEL - 0.7:
		shingle = 1.0
		rock *= 0.3
	var wet := clampf((Terrain.SEA_LEVEL + 0.5 - h) * 2.0, 0.0, 1.0)
	return Vector4(rock, shingle, dirt, wet)

# ---- finding the way ----

const CELL := 1.0
const NAV_RECT := Rect2(-37.0, -39.0, 78.0, 73.0)

static var _keepers: AStarGrid2D
static var _creatures: AStarGrid2D
## Things added at run time that block the way (the generator's house): Rect2s.
static var extra_solids: Array = []

static func reset_nav() -> void:
	_keepers = null
	_creatures = null

static func _blocked(x: float, z: float) -> bool:
	var p := Vector2(x, z)
	if KIRK_RECT.grow(0.5).has_point(p):
		return true
	# The kirkyard wall, but for its gate.
	if KIRKYARD.grow(0.3).has_point(p) and not KIRKYARD.grow(-0.3).has_point(p):
		if not (absf(p.x - KIRK_GATE.x) < GATE_HALF and p.y > KIRKYARD.end.y - 1.0):
			return true
	for b in BUILDINGS:
		if Rect2(float(b[0]) - float(b[2]) * 0.5, float(b[1]) - float(b[4]) * 0.5, float(b[2]), float(b[4])).grow(0.55).has_point(p):
			return true
	for r in extra_solids:
		if (r as Rect2).grow(0.5).has_point(p):
			return true
	return false

static func _grid(for_creatures: bool) -> AStarGrid2D:
	var g := AStarGrid2D.new()
	g.region = Rect2i(0, 0, int(NAV_RECT.size.x / CELL), int(NAV_RECT.size.y / CELL))
	g.cell_size = Vector2(CELL, CELL)
	g.offset = NAV_RECT.position + Vector2(CELL, CELL) * 0.5
	g.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	g.update()
	for j in g.region.size.y:
		for i in g.region.size.x:
			var p := g.offset + Vector2(i, j) * CELL
			var ok := walkable(p.x, p.y)
			if not ok and for_creatures:
				# They come up through the water on the slips and the strand.
				ok = shore_weight(p.x, p.y) > 0.9 and height_at(p.x, p.y) > BASIN + 0.3 and p.y < 21.0
			if ok and _blocked(p.x, p.y):
				ok = false
			g.set_point_solid(Vector2i(i, j), not ok)
	return g

static func _cell(g: AStarGrid2D, p: Vector2) -> Vector2i:
	var c := Vector2i(((p - NAV_RECT.position) / CELL).floor())
	c = c.clamp(Vector2i.ZERO, g.region.size - Vector2i.ONE)
	if not g.is_point_solid(c):
		return c
	# The nearest open cell, ring by ring.
	for r in range(1, 12):
		var best := Vector2i(-1, -1)
		var best_d := INF
		for dj in range(-r, r + 1):
			for di in range(-r, r + 1):
				if maxi(absi(di), absi(dj)) != r:
					continue
				var q := c + Vector2i(di, dj)
				if q.x < 0 or q.y < 0 or q.x >= g.region.size.x or q.y >= g.region.size.y or g.is_point_solid(q):
					continue
				var d := (g.offset + Vector2(q) * CELL).distance_squared_to(p)
				if d < best_d:
					best_d = d
					best = q
		if best.x >= 0:
			return best
	return c

## The way from one point to another over the town's ground, as corner points (the
## straight runs between them are clear). `for_creatures` lets it wade the landings.
static func path(from: Vector3, to: Vector3, for_creatures: bool) -> Array[Vector3]:
	if for_creatures and _creatures == null:
		_creatures = _grid(true)
	if not for_creatures and _keepers == null:
		_keepers = _grid(false)
	var g := _creatures if for_creatures else _keepers
	var a := _cell(g, Vector2(from.x, from.z))
	var b := _cell(g, Vector2(to.x, to.z))
	var raw := g.get_point_path(a, b)
	var out: Array[Vector3] = []
	# Keep only the corners.
	for i in raw.size():
		if i > 0 and i < raw.size() - 1:
			var d0 := (raw[i] - raw[i - 1]).normalized()
			var d1 := (raw[i + 1] - raw[i]).normalized()
			if d0.dot(d1) > 0.999:
				continue
		out.append(Vector3(raw[i].x, height_at(raw[i].x, raw[i].y), raw[i].y))
	if out.size() > 1:
		out.pop_front()
	return out

## A creature's way back to the sea: the nearest landing's foot.
static func path_to_sea(from: Vector3) -> Array[Vector3]:
	var best: Array[Vector3] = []
	var best_len := INF
	for i in LANDINGS.size():
		var foot := landing_point(i, 0.0)
		var r := path(from, foot, true)
		r.append(foot)
		var total := 0.0
		var p := from
		for q in r:
			total += Geo.flat_dist(p, q)
			p = q
		if total < best_len:
			best_len = total
			best = r
	return best
