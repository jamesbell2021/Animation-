class_name TacGrid
extends RefCounted
## The tactical grid: terrain, doors, steam, light and who stands where, in flat packed
## arrays (one entry a tile, index = y * width + x) so the per-step queries the battle makes
## thousands of times a turn stay cheap and allocation-free.

enum T { FLOOR, WALL, SOFT_ROCK, BOULDER, DOOR, VENT, VALVE, FUNGUS, LIFT, RUBBLE }

const INF_COST := 1 << 29

var width := 0
var height := 0
var terrain := PackedByteArray()
var door_open := PackedByteArray()
var steam := PackedByteArray()
var light := PackedFloat32Array()
var occupant := PackedInt32Array()
var vents: Array[Vector2i] = []
## Valve tile -> Array of the vent tiles it shuts.
var valves: Dictionary = {}
## Vent tile -> is it venting.
var vent_on: Dictionary = {}


func setup(w: int, h: int) -> void:
	width = w
	height = h
	var n := w * h
	terrain.resize(n)
	terrain.fill(T.WALL)
	door_open.resize(n)
	door_open.fill(0)
	steam.resize(n)
	steam.fill(0)
	light.resize(n)
	light.fill(0.0)
	occupant.resize(n)
	occupant.fill(-1)


func idx(c: Vector2i) -> int:
	return c.y * width + c.x


func cell(i: int) -> Vector2i:
	return Vector2i(i % width, i / width)


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < height


func get_t(c: Vector2i) -> int:
	return terrain[idx(c)] if in_bounds(c) else T.WALL


func set_t(c: Vector2i, t: int) -> void:
	terrain[idx(c)] = t


func is_door_closed(c: Vector2i) -> bool:
	return get_t(c) == T.DOOR and door_open[idx(c)] == 0


func walkable(c: Vector2i) -> bool:
	match get_t(c):
		T.FLOOR, T.FUNGUS, T.LIFT, T.RUBBLE, T.DOOR, T.VALVE:
			return true
	return false


func is_free(c: Vector2i) -> bool:
	return walkable(c) and occupant[idx(c)] == -1


## Rock and shut doors stop sight; so does steam (GDD 2.2.3: total visual occluder).
func blocks_los(c: Vector2i) -> bool:
	if not in_bounds(c):
		return true
	var t := terrain[idx(c)]
	if t == T.WALL or t == T.SOFT_ROCK:
		return true
	if t == T.DOOR and door_open[idx(c)] == 0:
		return true
	return steam[idx(c)] != 0


## Light is stopped by rock and shut doors, but scatters through steam.
func blocks_light(c: Vector2i) -> bool:
	if not in_bounds(c):
		return true
	var t := terrain[idx(c)]
	return t == T.WALL or t == T.SOFT_ROCK or (t == T.DOOR and door_open[idx(c)] == 0)


func gives_cover(c: Vector2i) -> bool:
	match get_t(c):
		T.WALL, T.SOFT_ROCK, T.BOULDER, T.VENT:
			return true
		T.DOOR:
			return door_open[idx(c)] == 0
	return false


## Diagonals need both orthogonal neighbours clear (GDD: "unblocked corner clearance"), and
## doors are only passed straight through.
func diagonal_clear(a: Vector2i, d: Vector2i) -> bool:
	var side_a := Vector2i(a.x + d.x, a.y)
	var side_b := Vector2i(a.x, a.y + d.y)
	if not walkable(side_a) or not walkable(side_b):
		return false
	if get_t(a) == T.DOOR or get_t(a + d) == T.DOOR:
		return false
	return not (is_door_closed(side_a) or is_door_closed(side_b))


## TU to step from a to the neighbouring b, or -1 if the step is illegal. Walking into a
## shut door opens it on the way, for the door's own cost.
func step_cost(a: Vector2i, b: Vector2i, crouched: bool) -> int:
	if not walkable(b):
		return -1
	var d := b - a
	if absi(d.x) > 1 or absi(d.y) > 1 or d == Vector2i.ZERO:
		return -1
	var cost := Rules.TU_STEP
	if d.x != 0 and d.y != 0:
		if not diagonal_clear(a, d):
			return -1
		cost = Rules.TU_DIAGONAL
	if crouched:
		cost += Rules.TU_CROUCHED_STEP_EXTRA
	if is_door_closed(b):
		cost += Rules.TU_DOOR
	return cost


## Melee reach: the eight neighbours, diagonals only past a clear corner.
func melee_reach(a: Vector2i, b: Vector2i) -> bool:
	var d := b - a
	if absi(d.x) > 1 or absi(d.y) > 1 or d == Vector2i.ZERO:
		return false
	if d.x != 0 and d.y != 0:
		return not blocks_los(Vector2i(a.x + d.x, a.y)) and not blocks_los(Vector2i(a.x, a.y + d.y))
	return true


## Every tile reachable from `start` within `budget` TU (Dijkstra with a binary heap).
## Other units block; `self_id` is the mover, whose own tile doesn't block it.
## Returns {"cost": PackedInt32Array, "prev": PackedInt32Array, "start": Vector2i}.
func reach(start: Vector2i, budget: int, crouched: bool, self_id: int) -> Dictionary:
	var n := width * height
	var cost := PackedInt32Array()
	cost.resize(n)
	cost.fill(INF_COST)
	var prev := PackedInt32Array()
	prev.resize(n)
	prev.fill(-1)
	var heap := _Heap.new()
	var s := idx(start)
	cost[s] = 0
	heap.push(0, s)
	while not heap.is_empty():
		var c := heap.top_cost()
		var i := heap.pop()
		if c > cost[i]:
			continue
		var here := cell(i)
		for d in Rules.DIRS:
			var nb := here + d
			if not in_bounds(nb):
				continue
			var j := idx(nb)
			var occ := occupant[j]
			if occ != -1 and occ != self_id:
				continue
			var sc := step_cost(here, nb, crouched)
			if sc < 0:
				continue
			var nc := c + sc
			if nc > budget or nc >= cost[j]:
				continue
			cost[j] = nc
			prev[j] = i
			heap.push(nc, j)
	return {"cost": cost, "prev": prev, "start": start}


func reach_cost(r: Dictionary, c: Vector2i) -> int:
	if not in_bounds(c):
		return INF_COST
	return (r["cost"] as PackedInt32Array)[idx(c)]


## The steps from the reach's start to `target`, start excluded. Empty if unreachable.
func path_to(r: Dictionary, target: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if reach_cost(r, target) >= INF_COST:
		return out
	var prev: PackedInt32Array = r["prev"]
	var start: Vector2i = r["start"]
	var i := idx(target)
	var s := idx(start)
	while i != s and i != -1:
		out.push_front(cell(i))
		i = prev[i]
	return out


## Line of sight between tile centres. The end tiles never block; anything between does.
func has_los(a: Vector2i, b: Vector2i) -> bool:
	return _clear_line(a, b, false)


func has_light_path(a: Vector2i, b: Vector2i) -> bool:
	return _clear_line(a, b, true)


func _clear_line(a: Vector2i, b: Vector2i, for_light: bool) -> bool:
	var dx := b.x - a.x
	var dy := b.y - a.y
	var n := maxi(absi(dx), absi(dy)) * 3
	if n <= 3:
		# Neighbours: a diagonal is only seen past one clear corner.
		if absi(dx) == 1 and absi(dy) == 1:
			var ca := Vector2i(a.x + dx, a.y)
			var cb := Vector2i(a.x, a.y + dy)
			if for_light:
				return not (blocks_light(ca) and blocks_light(cb))
			return not (blocks_los(ca) and blocks_los(cb))
		if n == 0:
			return true
	var last := a
	for i in range(1, n):
		var t := float(i) / float(n)
		var c := Vector2i(floori(a.x + 0.5 + dx * t), floori(a.y + 0.5 + dy * t))
		if c == last or c == a or c == b:
			continue
		last = c
		if for_light:
			if blocks_light(c):
				return false
		elif blocks_los(c):
			return false
	return true


## Each venting vent fills itself and its eight neighbours with steam (rock excepted).
func recompute_steam() -> void:
	steam.fill(0)
	for v in vents:
		if not vent_on.get(v, false):
			continue
		for oy in range(-1, 2):
			for ox in range(-1, 2):
				var c := v + Vector2i(ox, oy)
				if in_bounds(c) and get_t(c) != T.WALL and get_t(c) != T.SOFT_ROCK:
					steam[idx(c)] = 1


func light_at(c: Vector2i) -> float:
	return light[idx(c)] if in_bounds(c) else 0.0


## A min-heap of (cost, index) in two packed arrays: no per-node allocations.
class _Heap:
	var costs := PackedInt32Array()
	var items := PackedInt32Array()

	func is_empty() -> bool:
		return costs.is_empty()

	func top_cost() -> int:
		return costs[0]

	func push(c: int, item: int) -> void:
		costs.push_back(c)
		items.push_back(item)
		var i := costs.size() - 1
		while i > 0:
			var p := (i - 1) >> 1
			if costs[p] <= costs[i]:
				break
			_swap(i, p)
			i = p

	func pop() -> int:
		var out := items[0]
		var last := costs.size() - 1
		costs[0] = costs[last]
		items[0] = items[last]
		costs.resize(last)
		items.resize(last)
		var i := 0
		var n := last
		while true:
			var l := i * 2 + 1
			var r := l + 1
			var m := i
			if l < n and costs[l] < costs[m]:
				m = l
			if r < n and costs[r] < costs[m]:
				m = r
			if m == i:
				break
			_swap(i, m)
			i = m
		return out

	func _swap(a: int, b: int) -> void:
		var tc := costs[a]
		costs[a] = costs[b]
		costs[b] = tc
		var ti := items[a]
		items[a] = items[b]
		items[b] = ti
