class_name Nav
extends RefCounted
## Where creatures can walk: a small waypoint graph laid over the island.
## Up each beach, round the track at the crag's foot, then up the ledge to the
## lighthouse. Routes are shortest paths through it. Creatures don't collide with
## the ground, so the graph is what keeps them off the cliffs.
## The holm has its own graph, not joined to the main island's: up each of its beaches,
## straight at the camp's wire (which they must tear through), and on to the generator
## and the buildings inside. Raiders that land on the holm stay on it.

const BEACH_STEPS := [0.05, 0.3, 0.55, 0.8, 1.0]
const RING_NODES := 16
const LEDGE_NODES := 13
const ENTRY_BEFORE := 14.0
const SAME_LEVEL := 1.0
const HOLM_BEACH_STEPS := [0.05, 0.35, 0.65, 0.85]
## Either side of the wire, this far out and in; kept this far from the corner towers.
const WIRE_SIDE := 1.6
const CORNER_CLEAR := 3.0
## Inside the camp: the parade ground, before each building, and the gate (from its centre).
const CAMP_STOPS := [Vector2(0.0, 0.0), Vector2(-4.6, -2.3), Vector2(4.4, -2.3), Vector2(4.6, 2.5), Vector2(6.4, 0.6), Vector2(-8.6, 0.0)]

static var _nodes: Array[Vector3] = []
static var _links: Array = []
static var _offshore: Array[int] = []
static var _goal := -1

static func _ensure() -> void:
	if not _nodes.is_empty():
		return
	# Ring round the crag's foot.
	var ring: Array[int] = []
	for i in RING_NODES:
		ring.append(_add(Terrain.at_angle(360.0 * float(i) / float(RING_NODES), Terrain.RING_R)))
	for i in RING_NODES:
		_link(ring[i], ring[(i + 1) % RING_NODES])
	# Each beach: a chain from offshore up the gully, joined to the two nearest ring nodes.
	for b in Terrain.BEACHES.size():
		var prev := -1
		for t in BEACH_STEPS:
			var n := _add(Terrain.beach_point(b, float(t)))
			if prev < 0:
				_offshore.append(n)
			else:
				_link(prev, n)
			prev = n
		_link_to_ring(prev, float(Terrain.BEACHES[b]), ring)
	# The ledge, reached from the ring just short of its foot.
	var entry := _add(Terrain.at_angle(Terrain.LEDGE_START - ENTRY_BEFORE, Terrain.LEDGE_R0))
	_link_to_ring(entry, Terrain.LEDGE_START - ENTRY_BEFORE, ring)
	var prev := entry
	for i in LEDGE_NODES:
		var n := _add(Terrain.ledge_point(float(i) / float(LEDGE_NODES - 1)))
		_link(prev, n)
		prev = n
	# The lighthouse yard.
	_goal = _add(Vector3(0.0, Terrain.CRAG_TOP, 0.0))
	_link(prev, _goal)
	# The homestead: a stop on the meadow side of each building's pad, off the ring.
	for pad in Terrain.PADS:
		var c := Vector2(float(pad[0]), float(pad[1]))
		var at := c.normalized() * (c.length() - float(pad[2]) * 0.8)
		var n := _add(Vector3(at.x, Terrain.height_at(at.x, at.y), at.y))
		_link_to_ring(n, Terrain.compass_deg(at.x, at.y), ring)
	_build_holm()

static func _build_holm() -> void:
	var c := Terrain.CAMP_C
	var h := Terrain.CAMP_HALF
	var stops: Array[int] = []
	for o in CAMP_STOPS:
		stops.append(_add2(c + o))
	for i in range(1, stops.size()):
		_link(stops[0], stops[i])
	# The gate, from outside.
	var gate := Terrain.camp_gate()
	var out_gate := _add2(gate + Vector2(-WIRE_SIDE, 0.0))
	_link(out_gate, stops[stops.size() - 1])
	for b in Terrain.HOLM_BEACHES.size():
		var prev := -1
		for t in HOLM_BEACH_STEPS:
			var n := _add(Terrain.holm_beach_point(b, float(t)))
			if prev < 0:
				_offshore.append(n)
			else:
				_link(prev, n)
			prev = n
		# Straight at the nearest stretch of wire, clear of the corner towers.
		var top := Vector2(_nodes[prev].x, _nodes[prev].z)
		var q := Vector2(clampf(top.x, c.x - h.x + CORNER_CLEAR, c.x + h.x - CORNER_CLEAR), clampf(top.y, c.y - h.y + CORNER_CLEAR, c.y + h.y - CORNER_CLEAR))
		var gap := Vector2(absf(top.x - c.x) - h.x, absf(top.y - c.y) - h.y)
		var normal := Vector2(signf(top.x - c.x), 0.0) if gap.x > gap.y else Vector2(0.0, signf(top.y - c.y))
		if gap.x > gap.y:
			q.x = c.x + normal.x * h.x
		else:
			q.y = c.y + normal.y * h.y
		var outside := _add2(q + normal * WIRE_SIDE)
		var inside := _add2(q - normal * WIRE_SIDE)
		_link(prev, outside)
		_link(outside, inside)
		_link(prev, out_gate)
		var best := stops[0]
		for s in stops:
			if _nodes[s].distance_to(_nodes[inside]) < _nodes[best].distance_to(_nodes[inside]):
				best = s
		_link(inside, best)
		if best != stops[0]:
			_link(inside, stops[0])

static func _add2(p: Vector2) -> int:
	return _add(Vector3(p.x, Terrain.height_at(p.x, p.y), p.y))

static func _add(p: Vector3) -> int:
	_nodes.append(p)
	_links.append([])
	return _nodes.size() - 1

static func _link(a: int, b: int) -> void:
	_links[a].append(b)
	_links[b].append(a)

static func _link_to_ring(n: int, a_deg: float, ring: Array[int]) -> void:
	var step := 360.0 / float(RING_NODES)
	var i := int(floor(fposmod(a_deg, 360.0) / step))
	_link(n, ring[i % RING_NODES])
	_link(n, ring[(i + 1) % RING_NODES])

static func nodes() -> Array[Vector3]:
	_ensure()
	return _nodes

static func offshore_points() -> Array[Vector3]:
	_ensure()
	var out: Array[Vector3] = []
	for i in _offshore:
		out.append(_nodes[i])
	return out

## The node a creature standing here would head for first: the nearest one on
## its own level, so one knocked off the ledge goes back round, not up the wall.
static func _nearest(p: Vector3) -> int:
	_ensure()
	var ground := Terrain.height_at(p.x, p.z)
	var best := -1
	var best_d := INF
	var any := -1
	var any_d := INF
	for i in _nodes.size():
		var d := Geo.flat_dist(p, _nodes[i])
		if d < any_d:
			any_d = d
			any = i
		var level := maxf(_nodes[i].y, Terrain.SEA_LEVEL)
		if absf(level - maxf(ground, Terrain.SEA_LEVEL)) < SAME_LEVEL and d < best_d:
			best_d = d
			best = i
	return best if best >= 0 else any

static func _dijkstra(from: int) -> Array:
	var dist: Array[float] = []
	var prev: Array[int] = []
	dist.resize(_nodes.size())
	prev.resize(_nodes.size())
	dist.fill(INF)
	prev.fill(-1)
	dist[from] = 0.0
	var open: Array[int] = [from]
	while not open.is_empty():
		var bi := 0
		for k in open.size():
			if dist[open[k]] < dist[open[bi]]:
				bi = k
		var u: int = open[bi]
		open.remove_at(bi)
		for v in _links[u]:
			var d := dist[u] + _nodes[u].distance_to(_nodes[v])
			if d < dist[v]:
				if dist[v] == INF:
					open.append(v)
				dist[v] = d
				prev[v] = u
	return [dist, prev]

static func _walk(prev: Array[int], to: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var n := to
	while n >= 0:
		out.push_front(_nodes[n])
		n = prev[n]
	return out

## Waypoints from here to the lighthouse yard.
static func route_to_light(from: Vector3) -> Array[Vector3]:
	_ensure()
	var res := _dijkstra(_nearest(from))
	return _walk(res[1], _goal)

## Waypoints from here to the graph node nearest a goal on its own level.
static func route_to(from: Vector3, goal: Vector3) -> Array[Vector3]:
	_ensure()
	var res := _dijkstra(_nearest(from))
	return _walk(res[1], _nearest(goal))

## Waypoints from here back out to sea, by the nearest beach.
static func route_to_sea(from: Vector3) -> Array[Vector3]:
	_ensure()
	var res := _dijkstra(_nearest(from))
	var dist: Array[float] = res[0]
	var best := _offshore[0]
	for i in _offshore:
		if dist[i] < dist[best]:
			best = i
	return _walk(res[1], best)

## Total walking length of a route from a point.
static func route_length(from: Vector3, route: Array[Vector3]) -> float:
	var total := 0.0
	var p := from
	for q in route:
		total += Geo.flat_dist(p, q)
		p = q
	return total
