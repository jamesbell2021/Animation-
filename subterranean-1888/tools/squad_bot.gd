class_name SquadBot
extends RefCounted
## A plain squad player for balance runs and smoke tests. It's deliberately simple (a
## competent-ish first-time player), so its win rate is a floor, not a target:
##   - shoot the likeliest-to-hit spotted creature, keeping a third of TU for Overwatch;
##   - otherwise walk toward the journal, then back to the lift, in a loose file;
##   - light a hand flare when nothing's spotted and the way ahead is dark;
##   - take the journal when beside it; Field Repair when the boiler's low.

static func play_turn(b: Battle) -> void:
	for s in b.squad():
		if b.outcome != "" or b.phase != Battle.Phase.PLAYER:
			return
		_act(b, s)
	if b.outcome == "":
		b.exec({"t": "end_turn"})


static func _act(b: Battle, s: Unit) -> void:
	var reserve := Rules.overwatch_threshold(s.max_tu)
	if s.jammed or s.pressure < Rules.JAM_BELOW + 5:
		b.exec({"t": "repair", "u": s.id})
	if s.has_weapon() and s.def.weapon.clip > 0 and s.ammo == 0:
		b.exec({"t": "reload", "u": s.id})
	if b.journal_carrier == -1 and b.journal_tile != Battle.NO_TILE \
			and Rules.chebyshev(s.tile, b.journal_tile) <= 1:
		b.exec({"t": "journal", "u": s.id})
	# One good shot if there is one.
	if _shoot_best(b, s, reserve):
		_shoot_best(b, s, reserve)
		return
	var goal := b.journal_tile if b.journal_carrier == -1 else _lift_tile(b, s)
	if goal == Battle.NO_TILE:
		return
	if b.spotted.is_empty() and s.hand_flares > 0 and b.grid.light_at(s.tile) < Rules.PITCH_BELOW \
			and b.rng.randf() < 0.15:
		b.exec({"t": "hand_flare", "u": s.id})
	var budget := s.tu - reserve if not b.spotted.is_empty() else s.tu
	_walk(b, s, goal, budget)
	if s.alive:
		_shoot_best(b, s, reserve)


static func _shoot_best(b: Battle, s: Unit, reserve: int) -> bool:
	if not s.has_weapon():
		return false
	var best_cmd := {}
	var best_value := 0.0
	for id in b.spotted:
		var e := b.unit(id)
		for mode in s.def.weapon.modes:
			var p := b.shot_preview(s, e, mode)
			if not p["ok"] or s.tu - int(p["tu"]) < reserve * 0.5:
				continue
			var rounds := 4.0 if mode == "burst" else 1.0
			var value := float(p["chance"]) * rounds / maxf(1.0, float(p["tu"]))
			if value > best_value:
				best_value = value
				best_cmd = {"t": "shoot", "u": s.id, "target": id, "mode": mode}
	if best_cmd.is_empty():
		return false
	var ev := b.exec(best_cmd)
	return not ev.is_empty() and ev[0]["type"] != "refused"


static func _lift_tile(b: Battle, s: Unit) -> Vector2i:
	if b.lift_tiles.has(s.tile):
		return Battle.NO_TILE
	var best := Battle.NO_TILE
	var best_d := INF
	for c in b.lift_tiles:
		if b.grid.is_free(c) and Rules.dist(s.tile, c) < best_d:
			best_d = Rules.dist(s.tile, c)
			best = c
	return best


static func _walk(b: Battle, s: Unit, goal: Vector2i, budget: int) -> void:
	var full := b.grid.reach(s.tile, TacGrid.INF_COST - 1, s.crouched, s.id)
	var dest := goal
	if b.grid.reach_cost(full, goal) >= TacGrid.INF_COST:
		var best := TacGrid.INF_COST
		dest = Battle.NO_TILE
		for d in Rules.DIRS:
			var cost := b.grid.reach_cost(full, goal + d)
			if cost < best:
				best = cost
				dest = goal + d
		if dest == Battle.NO_TILE:
			return
	var path := b.grid.path_to(full, dest)
	var spent := 0
	var at := s.tile
	var stop := Battle.NO_TILE
	for step in path:
		var c := b.grid.step_cost(at, step, s.crouched)
		if c < 0 or spent + c > budget:
			break
		spent += c
		at = step
		if b.grid.is_free(step):
			stop = step
	if stop != Battle.NO_TILE:
		b.exec({"t": "move", "u": s.id, "to": stop})
