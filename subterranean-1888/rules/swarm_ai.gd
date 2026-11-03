class_name SwarmAI
extends RefCounted
## The insectoid swarm (GDD 6.2). Each creature, on its turn:
##   1. sees a soldier  -> hunts it: walks to a tile beside it and bites while TU lasts.
##      Crawlers (flankers) prefer a tile outside the target's vision cone, behind it best.
##   2. smells pheromone within AGGRO_RANGE -> heads for the densest trail.
##   3. otherwise wanders a little.
## Every action goes through Battle.ai_do(), the same validation the player's commands use.

const FLANK_OUTSIDE_CONE := 100.0
const FLANK_BEHIND := 40.0
const WANDER_SHARE := 0.5


static func act(b: Battle, u: Unit) -> void:
	if not u.alive or u.dormant or u.def.stationary or not u.has_weapon():
		return
	var target := nearest_spotted(b, u)
	if target != null:
		hunt(b, u, target)
		return
	var goal := pheromone_goal(b, u)
	if goal != Battle.NO_TILE:
		walk_toward(b, u, goal)
		target = nearest_spotted(b, u)
		if target != null and u.alive:
			hunt(b, u, target)
		return
	wander(b, u)


static func nearest_spotted(b: Battle, u: Unit) -> Unit:
	var best: Unit = null
	var best_d := INF
	for s in b.squad():
		if b.can_spot(u, s):
			var d := Rules.dist(u.tile, s.tile)
			if d < best_d:
				best_d = d
				best = s
	return best


## The best tile beside `target` this creature can reach and still attack from, or NO_TILE.
static func attack_tile(b: Battle, u: Unit, target: Unit, r: Dictionary) -> Vector2i:
	var attack_tu := b.shot_cost(u, "snap")
	var best := Battle.NO_TILE
	var best_score := -INF
	for d in Rules.DIRS:
		var c := target.tile + d
		if not b.grid.in_bounds(c) or not b.grid.melee_reach(c, target.tile):
			continue
		if c != u.tile and not b.grid.is_free(c):
			continue
		var cost := 0 if c == u.tile else b.grid.reach_cost(r, c)
		if cost + attack_tu > u.tu:
			continue
		var score := -float(cost)
		if u.def.flanker:
			if not Rules.in_cone(target.tile, target.facing, c, target.def.vision_half_angle):
				score += FLANK_OUTSIDE_CONE
			if Rules.is_behind(target.tile, target.facing, c):
				score += FLANK_BEHIND
		if score > best_score:
			best_score = score
			best = c
	return best


static func hunt(b: Battle, u: Unit, target: Unit) -> void:
	var r := b.grid.reach(u.tile, u.tu, false, u.id)
	var spot := attack_tile(b, u, target, r)
	if spot == Battle.NO_TILE:
		walk_toward(b, u, target.tile)
	elif spot != u.tile:
		b.ai_do({"t": "move", "u": u.id, "to": spot})
	while u.alive and target.alive and b.outcome == "":
		if not b.ai_do({"t": "shoot", "u": u.id, "target": target.id, "mode": "snap"}):
			break


static func pheromone_goal(b: Battle, u: Unit) -> Vector2i:
	var best := Battle.NO_TILE
	var best_score := 0.0
	for p in b.pheromones:
		var d := Rules.dist(u.tile, p)
		if d > Rules.AGGRO_RANGE:
			continue
		var score := b.pheromone_density(p) - d * 0.01
		if score > best_score:
			best_score = score
			best = p
	if best != Battle.NO_TILE and Rules.dist(u.tile, best) < 1.5:
		return Battle.NO_TILE
	return best


## Walk as far along the cheapest route to `goal` as this turn's TU allows.
static func walk_toward(b: Battle, u: Unit, goal: Vector2i) -> void:
	var full := b.grid.reach(u.tile, TacGrid.INF_COST - 1, false, u.id)
	var dest := goal
	if b.grid.reach_cost(full, goal) >= TacGrid.INF_COST:
		# The goal itself is blocked (a soldier stands on it): aim for its nearest neighbour.
		dest = Battle.NO_TILE
		var best := TacGrid.INF_COST
		for d in Rules.DIRS:
			var c := goal + d
			var cost := b.grid.reach_cost(full, c)
			if cost < best:
				best = cost
				dest = c
		if dest == Battle.NO_TILE:
			return
	var path := b.grid.path_to(full, dest)
	var spent := 0
	var at := u.tile
	var stop := Battle.NO_TILE
	for step in path:
		var c := b.grid.step_cost(at, step, false)
		if c < 0 or spent + c > u.tu:
			break
		spent += c
		at = step
		if b.grid.is_free(step):
			stop = step
	if stop != Battle.NO_TILE:
		b.ai_do({"t": "move", "u": u.id, "to": stop})


static func wander(b: Battle, u: Unit) -> void:
	if b.rng.randf() < 0.4:
		return
	var r := b.grid.reach(u.tile, int(u.tu * WANDER_SHARE), false, u.id)
	var options: Array[Vector2i] = []
	var cost: PackedInt32Array = r["cost"]
	for i in cost.size():
		if cost[i] > 0 and cost[i] < TacGrid.INF_COST and b.grid.occupant[i] == -1:
			options.append(b.grid.cell(i))
	if not options.is_empty():
		b.ai_do({"t": "move", "u": u.id, "to": options[b.rng.randi_range(0, options.size() - 1)]})
