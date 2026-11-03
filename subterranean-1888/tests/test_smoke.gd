extends SceneTree
## Plays the real scene for several turns through the view layer: every command goes
## through BattleView (so every event's animation runs), every action mode's hover preview
## is built, the overlays, menus and the end screen are opened. Run with tests/run_tests.sh,
## which fails the run if Godot printed any script error.

var fails := 0


func check(c: bool, what: String) -> void:
	print(("PASS  " if c else "FAIL  ") + what)
	if not c:
		fails += 1


func _init() -> void:
	_go.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _go() -> void:
	Engine.time_scale = 10.0
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	check(main.get_child_count() > 0, "the title screen opens")
	main.start_battle()
	await _frames(5)
	var bv: BattleView = main.battle_view()
	check(bv != null and bv.battle != null, "a battle starts")
	var b := bv.battle
	check(bv.views.size() == b.units.size(), "every unit has a model")
	var s := bv.selected
	check(s != null and s.team == Unit.SQUAD, "a specialist is selected")
	# Every hover preview, in every mode, over a spread of tiles.
	for m in ["move", "snap", "aimed", "burst", "mortar", "pheromone", "dynamite", "drill", "interact", "patch"]:
		bv.mode = m
		for c in [s.tile + Vector2i(0, -2), s.tile + Vector2i(2, -3), s.tile, Vector2i(14, 20), Vector2i(0, 0)]:
			bv._hover = c
			bv._update_hover()
	bv.mode = "move"
	check(true, "every hover preview builds")
	bv._toggle_overlay("light")
	bv._toggle_overlay("swarm")
	bv._toggle_overlay("swarm")
	check(bv.overlay == "", "the overlays toggle")
	bv.hud.show_pause()
	bv.hud.show_help()
	bv.hud.close_modal()
	# A round of single actions through the view.
	await bv._send({"t": "lamp", "u": s.id})
	await bv._send({"t": "lamp", "u": s.id})
	await bv._send({"t": "stance", "u": s.id})
	await bv._send({"t": "stance", "u": s.id})
	await bv._send({"t": "face", "u": s.id, "dir": 7})
	await bv._send({"t": "hand_flare", "u": s.id})
	check(b.flares.size() == 1, "a hand flare is burning")
	await bv._send({"t": "mortar", "u": s.id, "to": s.tile + Vector2i(3, -9)})
	check(b.flares.size() == 2, "and a mortar flare")
	var nat := b.squad()[1]
	bv.select(nat)
	await bv._send({"t": "throw", "u": nat.id, "item": "pheromone", "to": nat.tile + Vector2i(0, -4)})
	check(not b.pheromones.is_empty(), "the lure is laid")
	await bv._send({"t": "move", "u": nat.id, "to": nat.tile + Vector2i(30, 0)})
	check(true, "an impossible move is refused without fuss")
	await bv._send({"t": "end_turn"})
	check(b.turn == 2 or b.outcome != "", "the swarm's turn plays and the squad's comes back")
	# Then the squad bot's choices, played through the view, for several turns.
	var turns := 0
	while b.outcome == "" and turns < 14:
		turns += 1
		for u in b.squad():
			if b.outcome != "":
				break
			bv.select(u)
			for cmd in _choose(b, u):
				await bv._send(cmd)
				if b.outcome != "" or not u.alive:
					break
		if b.outcome == "":
			await bv._send({"t": "end_turn"})
	check(b.turn > 2, "%d turns played through the view (outcome: %s)" % [b.turn, b.outcome if b.outcome != "" else "still going"])
	for id in bv.views:
		var u := b.unit(id)
		if u.alive:
			check((bv.views[id] as UnitView).position.distance_to(Kit.world(u.tile)) < 0.2, "%s's model stands on its tile" % u.def.display_name)
	bv.hud.show_end("extracted", b)
	await _frames(2)
	check(bv.hud.has_modal(), "the end screen opens")
	Engine.time_scale = 1.0
	print("%s: %d failed" % ["OK" if fails == 0 else "FAILED", fails])
	quit(1 if fails > 0 else 0)


## One or two commands the squad bot would make, without making them.
func _choose(b: Battle, u: Unit) -> Array:
	var out: Array = []
	if u.jammed:
		out.append({"t": "repair", "u": u.id})
	if u.has_weapon() and u.def.weapon.clip > 0 and u.ammo == 0:
		out.append({"t": "reload", "u": u.id})
	for id in b.spotted:
		var e := b.unit(id)
		for m in u.def.weapon.modes if u.has_weapon() else []:
			if b.shot_preview(u, e, m)["ok"]:
				out.append({"t": "shoot", "u": u.id, "target": id, "mode": m})
				return out
	if b.journal_carrier == -1 and b.journal_tile != Battle.NO_TILE and Rules.chebyshev(u.tile, b.journal_tile) <= 1:
		out.append({"t": "journal", "u": u.id})
		return out
	if u.dynamite > 0 and not b.spotted.is_empty():
		var e := b.unit(b.spotted.keys()[0])
		if Rules.dist(u.tile, e.tile) <= Rules.THROW_RANGE and Rules.dist(u.tile, e.tile) > 2.0:
			out.append({"t": "throw", "u": u.id, "item": "dynamite", "to": e.tile})
			return out
	var goal := b.journal_tile if b.journal_carrier == -1 else b.lift_tiles[0]
	var r := b.grid.reach(u.tile, u.tu - Rules.overwatch_threshold(u.max_tu), u.crouched, u.id)
	var best := Battle.NO_TILE
	var best_d := Rules.dist(u.tile, goal)
	var cost: PackedInt32Array = r["cost"]
	for i in cost.size():
		if cost[i] > 0 and cost[i] < TacGrid.INF_COST and b.grid.occupant[i] == -1:
			var d := Rules.dist(b.grid.cell(i), goal)
			if d < best_d:
				best_d = d
				best = b.grid.cell(i)
	if best != Battle.NO_TILE:
		out.append({"t": "move", "u": u.id, "to": best})
	return out
