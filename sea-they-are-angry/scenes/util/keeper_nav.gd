class_name KeeperNav
extends RefCounted
## Where keepers walk: the helper keepers' map (KeeperAI). It is the creatures' graph
## (Nav: up the beaches, round the track at the crag's foot, up the ledge, the
## homestead) plus what only keepers use: the ladders down the crag, the yard round the
## lighthouse and its door, the rope bridge, and the camp on the holm.
## A link is walked, or climbed (a ladder): a route says which.

const SAME_LEVEL := 1.0
const YARD_R := 2.9
const YARD_NODES := 8
## Walking-equivalent length of a ladder (m), so a route weighs climbing against the ledge.
const LADDER_COST := 4.0

static var _nodes: Array[Vector3] = []
static var _links: Array = []      # per node: Array of [to, climb_time] (0 = walk)
static var _ladders: Array = []    # [top, bottom, down_time, up_time]
static var _door := -1

## Forget the map (a new island is being built).
static func reset() -> void:
	_nodes.clear()
	_links.clear()
	_ladders.clear()
	_door = -1

## A ladder keepers can use, between its top and bottom stepping-off points.
static func add_ladder(top: Vector3, bottom: Vector3, down_time: float, up_time: float) -> void:
	_ladders.append([top, bottom, down_time, up_time])
	_nodes.clear()
	_links.clear()

## Where a keeper stands to go in at the lighthouse door.
static func door_point() -> Vector3:
	_ensure()
	return _nodes[_door]

static func _ensure() -> void:
	if not _nodes.is_empty():
		return
	var base := Nav.nodes()
	var goal := Nav._goal
	for p in base:
		_add(p)
	for i in base.size():
		for j in Nav._links[i]:
			if i < j and i != goal and j != goal:
				_link(i, j)
	# The yard round the tower, and the door on its south side.
	var yard: Array[int] = []
	for i in YARD_NODES:
		var a := TAU * float(i) / float(YARD_NODES)
		yard.append(_add(Vector3(sin(a) * YARD_R, Terrain.CRAG_TOP, cos(a) * YARD_R)))
	for i in YARD_NODES:
		_link(yard[i], yard[(i + 1) % YARD_NODES])
	_door = yard[0]
	# The ledge's head comes out onto the yard.
	_link_near(_add_existing(Terrain.ledge_point(1.0)), 2, 4.0, yard)
	for l in _ladders:
		var t := _add(l[0])
		var b := _add(l[1])
		_links[t].append([b, float(l[2])])
		_links[b].append([t, float(l[3])])
		_link_near(t, 2, 6.0)
		_link_near(b, 2, 6.0)
	_build_holm()

# The bridge from the meadow, over the gully, through the gate and round the camp.
static func _build_holm() -> void:
	var e := Terrain.bridge_ends()
	var a: Vector3 = e[0]
	var b: Vector3 = e[1]
	var along := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
	var m0 := _add(a - along * 1.0)
	_link_near(m0, 2, 9.0)
	var prev := m0
	for u in [0.0, 0.5, 1.0]:
		var n := _add(a.lerp(b, u))
		_link(prev, n)
		prev = n
	var h0 := _add(b + along * 1.0)
	_link(prev, h0)
	var g := Terrain.camp_gate()
	var c := Terrain.CAMP_C
	var outside := _add(_on(g.x - 1.6, g.y))
	_link(h0, outside)
	var inside := _add(_on(g.x + 1.6, g.y))
	_link(outside, inside)
	var parade := _add(_on(c.x, c.y))
	var west := _add(_on(c.x - 9.6, c.y - 1.8))
	_link(inside, parade)
	_link(inside, west)
	_link(west, parade)
	# Round the camp: the huts' fronts, the beds, the greenhouse, the generator, and a
	# tower's foot at each corner.
	var spots := {
		"quarters": _on(c.x - 4.6, c.y - 1.7), "mess": _on(c.x + 4.4, c.y - 1.7),
		"beds": _on(c.x - 0.6, c.y + 4.6), "greenhouse": _on(c.x + 0.8, c.y + 4.9),
		"generator": _on(c.x + 6.0, c.y - 1.6), "south": _on(c.x, c.y + 7.6),
	}
	var ids := {}
	for k in spots:
		ids[k] = _add(spots[k])
		_link(parade, ids[k])
	var ne_gap := _add(_on(c.x + 9.8, c.y - 2.0))
	_link(ids["generator"], ne_gap)
	var se_lane := _add(_on(c.x + 4.6, c.y + 7.7))
	_link(ids["south"], se_lane)
	_link(ids["beds"], ids["south"])
	_link(ids["greenhouse"], ids["south"])
	var h := Terrain.CAMP_HALF
	var feet := [_on(c.x - h.x + 1.8, c.y - h.y + 1.8), _on(c.x + h.x - 1.8, c.y - h.y + 1.8),
		_on(c.x + h.x - 1.8, c.y + h.y - 1.6), _on(c.x - h.x + 1.8, c.y + h.y - 1.8)]
	var fid: Array[int] = []
	for f in feet:
		fid.append(_add(f))
	_link(west, fid[0])
	_link(ne_gap, fid[1])
	_link(se_lane, fid[2])
	_link(west, fid[3])

static func _on(x: float, z: float) -> Vector3:
	return Vector3(x, Terrain.height_at(x, z), z)

## The camp's named spots: where helpers go to tend things.
static func camp_spots() -> Array[Vector3]:
	var c := Terrain.CAMP_C
	return [_on(c.x - 0.6, c.y + 4.6), _on(c.x + 0.8, c.y + 4.9), _on(c.x - 4.6, c.y - 1.7),
		_on(c.x + 4.4, c.y - 1.7), _on(c.x + 6.0, c.y - 1.6), _on(c.x, c.y)]

## A tower's foot inside each corner of the wire, for a night patrol.
static func tower_feet() -> Array[Vector3]:
	var c := Terrain.CAMP_C
	var h := Terrain.CAMP_HALF
	return [_on(c.x - h.x + 1.8, c.y - h.y + 1.8), _on(c.x + h.x - 1.8, c.y - h.y + 1.8),
		_on(c.x + h.x - 1.8, c.y + h.y - 1.6), _on(c.x - h.x + 1.8, c.y + h.y - 1.8)]

static func _add(p: Vector3) -> int:
	_nodes.append(p)
	_links.append([])
	return _nodes.size() - 1

# A node at p, or the existing one already there.
static func _add_existing(p: Vector3) -> int:
	for i in _nodes.size():
		if _nodes[i].distance_to(p) < 0.3:
			return i
	return _add(p)

static func _link(a: int, b: int) -> void:
	_links[a].append([b, 0.0])
	_links[b].append([a, 0.0])

# Walk-links from n to its nearest few nodes on the same level (optionally only among `among`).
static func _link_near(n: int, count: int, max_d: float, among: Array = []) -> void:
	var cands := []
	for i in _nodes.size():
		if i == n or (not among.is_empty() and not among.has(i)):
			continue
		if absf(_nodes[i].y - _nodes[n].y) > SAME_LEVEL:
			continue
		var d := Geo.flat_dist(_nodes[i], _nodes[n])
		if d <= max_d:
			cands.append([d, i])
	cands.sort_custom(func(x, y): return x[0] < y[0])
	for k in mini(count, cands.size()):
		_link(n, int(cands[k][1]))

static func _nearest(p: Vector3) -> int:
	_ensure()
	var best := -1
	var best_d := INF
	var any := 0
	var any_d := INF
	for i in _nodes.size():
		var d := Geo.flat_dist(p, _nodes[i])
		if d < any_d:
			any_d = d
			any = i
		if absf(_nodes[i].y - p.y) < SAME_LEVEL + 0.4 and d < best_d:
			best_d = d
			best = i
	return best if best >= 0 else any

## A keeper's way from here to there: an Array of steps {"p": where to walk, and
## "climb": the far end of a ladder to climb from p, with "time"}. Ends at `to`.
static func route(from: Vector3, to: Vector3) -> Array:
	_ensure()
	var s := _nearest(from)
	var g := _nearest(to)
	var dist: Array[float] = []
	var prev: Array[int] = []
	var climb: Array[float] = []
	dist.resize(_nodes.size())
	prev.resize(_nodes.size())
	climb.resize(_nodes.size())
	dist.fill(INF)
	prev.fill(-1)
	climb.fill(0.0)
	dist[s] = 0.0
	var open: Array[int] = [s]
	while not open.is_empty():
		var bi := 0
		for k in open.size():
			if dist[open[k]] < dist[open[bi]]:
				bi = k
		var u: int = open[bi]
		open.remove_at(bi)
		if u == g:
			break
		for l in _links[u]:
			var v: int = l[0]
			var cost := LADDER_COST if float(l[1]) > 0.0 else _nodes[u].distance_to(_nodes[v])
			if dist[u] + cost < dist[v]:
				if dist[v] == INF:
					open.append(v)
				dist[v] = dist[u] + cost
				prev[v] = u
				climb[v] = float(l[1])
	var chain: Array[int] = []
	var n := g
	while n >= 0:
		chain.push_front(n)
		n = prev[n]
	var steps := []
	for i in chain.size():
		var step := {"p": _nodes[chain[i]]}
		if i + 1 < chain.size() and climb[chain[i + 1]] > 0.0:
			step["climb"] = _nodes[chain[i + 1]]
			step["time"] = climb[chain[i + 1]]
		steps.append(step)
	# Skip the first node if it's behind us, and finish on the spot itself.
	if steps.size() > 1 and not steps[0].has("climb") and Geo.flat_dist(from, steps[1]["p"]) < Geo.flat_dist(steps[0]["p"], steps[1]["p"]):
		steps.pop_front()
	steps.append({"p": to})
	return steps
