class_name HotelLayout
extends RefCounted
## Where everything is, in one place. The hotel is drawn as a cut-away side view:
##
##   x: street | stairwell | four rooms per floor           | pool deck, pool, deck, sea view
##   y: three upper floors of rooms above a ground floor with reception and the bar.
##
## Positions are feet-on-the-floor points. route() turns any two points into walkable
## waypoints through the stairwell.

const WORLD_W := 2600.0
const WORLD_H := 1000.0
const GROUND_Y := 780.0
const FLOOR_H := 170.0
const STAIR_X0 := 260.0
const STAIR_W := 120.0
const ROOM_X0 := 380.0
const ROOM_W := 220.0
const BUILD_X1 := ROOM_X0 + 4.0 * ROOM_W   # 1260
const STREET_X := -60.0

const DESK_X := 470.0                        # reception desk (guest side)
const BAR_X0 := 640.0
const BAR_X1 := 1240.0
const BAR_COUNTER_X := 1180.0

const POOL_X0 := 1560.0
const POOL_X1 := 2240.0
const POOL_TOP := GROUND_Y + 10.0           # water surface
const POOL_DEPTH := 105.0
const SWIM_Y := GROUND_Y + 62.0             # a swimmer's feet point
const LIFEGUARD_X := 1525.0
const SEA_X := 2620.0                       # "off to the beach" exit


static func level_y(level: int) -> float:
	return GROUND_Y - level * FLOOR_H


static func level_of(y: float) -> int:
	if y > GROUND_Y + 20.0:
		return 0  # in the pool counts as ground level
	return clampi(int(roundf((GROUND_Y - y) / FLOOR_H)), 0, 3)


static func room_level(i: int) -> int:
	return i / 4 + 1


static func room_rect(i: int) -> Rect2:
	var lvl := room_level(i)
	return Rect2(ROOM_X0 + (i % 4) * ROOM_W, level_y(lvl) - FLOOR_H, ROOM_W, FLOOR_H)


## A random standing spot inside a room.
static func room_spot(i: int, rng: RandomNumberGenerator) -> Vector2:
	var r := room_rect(i)
	return Vector2(rng.randf_range(r.position.x + 40.0, r.end.x - 40.0), level_y(room_level(i)))


static func room_door(i: int) -> Vector2:
	var r := room_rect(i)
	return Vector2(r.position.x + 24.0, level_y(room_level(i)))


static func bed_spot(i: int) -> Vector2:
	var r := room_rect(i)
	return Vector2(r.position.x + 120.0, level_y(room_level(i)) - 28.0)


static func stool(i: int) -> Vector2:
	return Vector2(BAR_X0 + 60.0 + (i % 7) * 66.0, GROUND_Y)


static func lounger(i: int) -> Vector2:
	# Left deck holds 4, the right deck the rest.
	if i < 4:
		return Vector2(1330.0 + i * 52.0, GROUND_Y)
	return Vector2(2280.0 + (i - 4) * 46.0, GROUND_Y)


static func swim_spot(rng: RandomNumberGenerator) -> Vector2:
	return Vector2(rng.randf_range(POOL_X0 + 50.0, POOL_X1 - 50.0), SWIM_Y)


static func in_pool(p: Vector2) -> bool:
	return p.y > GROUND_Y + 20.0 and p.x > POOL_X0 and p.x < POOL_X1


## Waypoints from one point to another: climb the stairwell zig-zag between levels, and step
## down into (or out of) the pool at its edge.
static func route(from: Vector2, to: Vector2) -> Array[Vector2]:
	var pts: Array[Vector2] = []
	var cur := from
	if in_pool(cur) and not in_pool(to):
		var exit_x := POOL_X0 + 10.0 if absf(cur.x - POOL_X0) < absf(cur.x - POOL_X1) else POOL_X1 - 10.0
		cur = Vector2(exit_x, GROUND_Y)
		pts.append(cur)
	var l0 := level_of(cur.y)
	var l1 := level_of(to.y)
	if l0 != l1:
		var step := 1 if l1 > l0 else -1
		var l := l0
		var left_side := true
		pts.append(Vector2(STAIR_X0 + STAIR_W - 20.0, level_y(l)))
		while l != l1:
			l += step
			left_side = not left_side
			pts.append(Vector2(STAIR_X0 + (20.0 if left_side else STAIR_W - 20.0), level_y(l)))
	if in_pool(to) and not in_pool(cur):
		var edge := POOL_X0 + 10.0 if absf(to.x - POOL_X0) < absf(to.x - POOL_X1) else POOL_X1 - 10.0
		pts.append(Vector2(edge, GROUND_Y))
	pts.append(to)
	return pts
