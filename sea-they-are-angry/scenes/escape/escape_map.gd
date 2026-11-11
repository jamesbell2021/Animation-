class_name EscapeMap
extends RefCounted
## The Escape's ground: the deck of the Mary Ann (docs/ESCAPE.md). The boat stays at the
## origin with her bow to +X (east, to the right of the screen) and the world goes past
## her, so everything the keepers stand on is fixed: Terrain hands height and walking to
## this class while Terrain.chapter is 3, KeeperNav its routes, and CameraDirector its
## framing.
##
## Port is -Z (up the screen, toward the coast), starboard +Z (toward the camera).

## The boat's model is ReliefBoat at this scale (her deck wants room for three keepers,
## the seven and what comes over the side).
const SCALE := 1.6
## Where her root sits: ReliefBoat lies at the sea level less this.
const ROOT_Y := Terrain.SEA_LEVEL - 0.25
## The deck's planking: the height keepers stand at.
const DECK_Y := ROOT_Y + 1.01 * SCALE
## The hull's half breadth at the waterline (her outer face), and her length each way.
const HALF_BEAM := ReliefBoat.BEAM * 0.5 * SCALE
const STERN_X := -4.3 * SCALE
const BOW_X := 4.6 * SCALE
## Where a keeper's middle can be: inside the bulwarks, from the stern to the bow.
const WALK_STERN := -5.1
const WALK_BOW := 4.8
const WALK_HALF := 1.45
## The wheelhouse (narrowed for the Escape: ReliefBoat.escape_fit), solid, x from to.
const HOUSE_AFT := -1.8 * SCALE
const HOUSE_FORE := 0.0
const HOUSE_HALF := 0.5 * SCALE
## How far off the wheelhouse walls a keeper's middle keeps.
const BODY := 0.36
## The wheel, on the after face of the wheelhouse, and where its helmsman stands.
const WHEEL := Vector3(HOUSE_AFT - 0.12, DECK_Y + 1.0, 0.0)
const HELM_STAND := Vector3(HOUSE_AFT - 0.62, DECK_Y, 0.0)
## Where the seven sit: in the well of the fore deck, two rows either side of the hatch.
const SEATS := [Vector3(1.0, 0.0, -0.5), Vector3(1.0, 0.0, 0.5), Vector3(1.75, 0.0, -0.5), Vector3(1.75, 0.0, 0.5),
	Vector3(2.5, 0.0, -0.5), Vector3(2.5, 0.0, 0.5), Vector3(3.25, 0.0, -0.05)]
## Where things come over the side: along each gunwale, outside the hull (x; the side
## gives z = side * CLIMB_OUT).
const CLIMB_XS := [-4.4, -3.3, -1.3, 0.7, 2.0, 3.3, 4.4]
const CLIMB_OUT := HALF_BEAM + 0.28
## Where on the deck a keeper stands to strike at the gunwale (side * RAIL_IN).
const RAIL_IN := 1.3
## The camera: the boat a little left of the middle, so what comes from ahead shows in
## time, and closer than an island's framing.
const FOCUS := Vector3(5.0, DECK_Y, 0.8)
const ZOOM := 0.58
## Under the water, everywhere off her: deep.
const SEA_FLOOR := Terrain.SEA_LEVEL - 6.0

## The deck's height where she has one; the sea floor elsewhere.
static func height_at(x: float, z: float) -> float:
	return DECK_Y if on_hull(x, z) else SEA_FLOOR

## Inside her outline (the waterline, a little in).
static func on_hull(x: float, z: float) -> bool:
	return x >= STERN_X and x <= BOW_X and absf(z) <= HALF_BEAM - 0.05

## Where a keeper may stand: on her deck, inside the bulwarks, not in the wheelhouse.
static func walkable(x: float, z: float) -> bool:
	if x < WALK_STERN or x > WALK_BOW or absf(z) > WALK_HALF:
		return false
	return not in_house(x, z, BODY)

static func in_house(x: float, z: float, margin: float = 0.0) -> bool:
	return x > HOUSE_AFT - margin and x < HOUSE_FORE + margin and absf(z) < HOUSE_HALF + margin

## A keeper's (or a creature's) way along her deck: round the wheelhouse by whichever
## side is nearer, else straight. Steps as KeeperNav.route gives them ({"p": ...}).
static func route(from: Vector3, to: Vector3) -> Array:
	var way := []
	for p in path(from, to):
		way.append({"p": p})
	return way

static func path(from: Vector3, to: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var lo := minf(from.x, to.x)
	var hi := maxf(from.x, to.x)
	# Only a way that crosses the wheelhouse's length and would go through it bends.
	if hi > HOUSE_AFT - 0.2 and lo < HOUSE_FORE + 0.2 and (absf(from.z) < HOUSE_HALF + BODY + 0.1 or absf(to.z) < HOUSE_HALF + BODY + 0.1 or signf(from.z) != signf(to.z)):
		var side := signf(from.z + to.z)
		if side == 0.0:
			side = 1.0
		var lane := side * (HOUSE_HALF + BODY + 0.14)
		if from.x < HOUSE_AFT:
			out.append(Vector3(HOUSE_AFT - 0.5, DECK_Y, lane))
			if to.x > HOUSE_FORE:
				out.append(Vector3(HOUSE_FORE + 0.5, DECK_Y, lane))
		elif from.x > HOUSE_FORE:
			out.append(Vector3(HOUSE_FORE + 0.5, DECK_Y, lane))
			if to.x < HOUSE_AFT:
				out.append(Vector3(HOUSE_AFT - 0.5, DECK_Y, lane))
		else:
			# Alongside it already: out to the lane, then along.
			out.append(Vector3(from.x, DECK_Y, lane))
			out.append(Vector3(HOUSE_AFT - 0.5 if to.x < from.x else HOUSE_FORE + 0.5, DECK_Y, lane))
	out.append(Vector3(to.x, DECK_Y, to.z))
	return out

## The nearest point a keeper can stand at to `p`.
static func nearest_walkable(p: Vector3) -> Vector3:
	var q := Vector3(clampf(p.x, WALK_STERN, WALK_BOW), DECK_Y, clampf(p.z, -WALK_HALF, WALK_HALF))
	if in_house(q.x, q.z, BODY):
		var lane := HOUSE_HALF + BODY + 0.05
		q.z = lane if q.z >= 0.0 else -lane
	return q

## A gunwale slot's climbing point (outside the hull) and the deck point inside it.
static func slot_point(slot: int) -> Vector3:
	var side := -1.0 if slot < CLIMB_XS.size() else 1.0
	var x: float = CLIMB_XS[slot % CLIMB_XS.size()]
	return Vector3(x, DECK_Y - 0.5, side * CLIMB_OUT)

static func slot_rail(slot: int) -> Vector3:
	var side := -1.0 if slot < CLIMB_XS.size() else 1.0
	var x: float = CLIMB_XS[slot % CLIMB_XS.size()]
	return nearest_walkable(Vector3(x, DECK_Y, side * RAIL_IN))

static func slots() -> int:
	return CLIMB_XS.size() * 2

## Which side of her a point is on: -1 port, 1 starboard.
static func side_of(p: Vector3) -> float:
	return -1.0 if p.z < 0.0 else 1.0

## How far a point (on the water) is from her hull's outline, in metres (0 touching).
static func hull_gap(p: Vector3) -> float:
	var dx := maxf(0.0, maxf(STERN_X - p.x, p.x - BOW_X))
	var dz := maxf(0.0, absf(p.z) - HALF_BEAM)
	return Vector2(dx, dz).length()
