extends SceneTree
## Headless checks of the rules layer: no scene, no rendering.
##   godot --headless --path subterranean-1888 --script res://tests/test_rules.gd

var fails := 0
var passes := 0


func check(cond: bool, what: String) -> void:
	if cond:
		passes += 1
	else:
		fails += 1
		print("FAIL  " + what)


func _init() -> void:
	_tu_maths()
	_light_bands()
	_grid_and_paths()
	_vision_and_steam()
	_battle_basics()
	_combat()
	_reactions()
	_swarm()
	_full_rounds()
	print("%d passed, %d failed" % [passes, fails])
	quit(1 if fails > 0 else 0)


func _tu_maths() -> void:
	check(Rules.shot_tu("snap", 50) == 13, "snap is 25% of Max TU, rounded up")
	check(Rules.shot_tu("aimed", 65) == 33, "aimed is 50% of Max TU, rounded up")
	check(Rules.shot_tu("burst", 42) == 26, "burst is 60% of Max TU, rounded up")
	check(Rules.overwatch_threshold(60) == 20, "overwatch needs a third of Max TU")
	check(Rules.max_tu(50, 80, 16.0) == 50, "under the carry limit costs nothing")
	check(Rules.max_tu(45, 95, 26.0) == 42, "2.25 kg over costs 3 TU")
	check(Rules.rotation_steps(0, 7) == 1 and Rules.rotation_steps(1, 5) == 4, "rotation takes the short way round")
	check(Rules.dir_toward(Vector2i(0, 0), Vector2i(3, 3)) == 1, "south-east is facing 1")
	check(Rules.dir_toward(Vector2i(5, 5), Vector2i(5, 0)) == 6, "north is facing 6")
	check(Rules.in_cone(Vector2i(0, 0), 0, Vector2i(5, 4), 45.0), "38 degrees off is inside a 90-degree cone")
	check(not Rules.in_cone(Vector2i(0, 0), 0, Vector2i(3, 4), 45.0), "53 degrees off is outside it")
	check(Rules.jam_chance(40) == 0 and Rules.jam_chance(20) == 20, "jams start below 30 pressure")
	var defs := Catalog.load_units()
	check(defs.size() == 7, "all seven unit definitions load")
	check((defs["grenadier"] as UnitDef).max_tu() == 42, "the Grenadier's load costs him 3 TU")
	check((defs["cartographer"] as UnitDef).max_tu() == 58, "the Cartographer's seismograph costs her 2 TU")
	check((defs["naturalist"] as UnitDef).max_tu() == 65, "the Naturalist travels light")


func _light_bands() -> void:
	check(Rules.band(0.0) == Rules.Band.PITCH and Rules.band(0.249) == Rules.Band.PITCH, "below 0.25 is pitch black")
	check(Rules.band(0.25) == Rules.Band.DIM and Rules.band(0.749) == Rules.Band.DIM, "0.25 to 0.75 is dim")
	check(Rules.band(0.75) == Rules.Band.BRIGHT and Rules.band(1.0) == Rules.Band.BRIGHT, "0.75 up is bright")
	check(is_equal_approx(Rules.falloff(1.0, 3.0, 0.0), 1.0), "a light is full strength at its centre")
	check(Rules.falloff(1.0, 3.0, 3.5) == 0.0, "and nothing past its radius")


func _small(map: String) -> Dictionary:
	return LevelLoader.parse(map)


func _grid_and_paths() -> void:
	var lv := _small("#####\n#...#\n#.#.#\n#...#\n#####")
	var g: TacGrid = lv["grid"]
	check(g.step_cost(Vector2i(1, 1), Vector2i(2, 1), false) == 4, "a cardinal step costs 4")
	check(g.step_cost(Vector2i(1, 1), Vector2i(2, 2), false) == -1, "no diagonal past a wall corner")
	check(g.step_cost(Vector2i(1, 1), Vector2i(1, 2), true) == 6, "crouched steps cost 2 more")
	var open := _small("####\n#..#\n#..#\n####")
	var og: TacGrid = open["grid"]
	check(og.step_cost(Vector2i(1, 1), Vector2i(2, 2), false) == 6, "a clear diagonal costs 6")
	var r := g.reach(Vector2i(1, 1), 100, false, -1)
	check(g.reach_cost(r, Vector2i(3, 3)) == 16, "around the pillar costs four steps")
	var path := g.path_to(r, Vector2i(3, 3))
	check(path.size() == 4 and path[-1] == Vector2i(3, 3), "the path ends on the target")
	var tight := g.reach(Vector2i(1, 1), 8, false, -1)
	check(g.reach_cost(tight, Vector2i(3, 3)) >= TacGrid.INF_COST, "a budget cuts the reach short")
	var door := _small("#####\n#.D.#\n#####")
	var dg: TacGrid = door["grid"]
	check(dg.step_cost(Vector2i(1, 1), Vector2i(2, 1), false) == 8, "walking into a shut door opens it for 4 more")
	check(not dg.has_los(Vector2i(1, 1), Vector2i(3, 1)), "a shut door blocks sight")
	dg.door_open[dg.idx(Vector2i(2, 1))] = 1
	check(dg.has_los(Vector2i(1, 1), Vector2i(3, 1)), "an open one doesn't")


func _vision_and_steam() -> void:
	var lv := _small("#######\n#.....#\n#..V..#\n#.....#\n#v....#\n#######")
	var g: TacGrid = lv["grid"]
	check(g.steam[g.idx(Vector2i(3, 1))] == 1, "a vent fills its neighbours with steam")
	check(not g.has_los(Vector2i(1, 2), Vector2i(5, 2)), "steam blocks sight through it")
	check(g.has_light_path(Vector2i(1, 2), Vector2i(5, 2)), "but light scatters through")
	check((g.valves[Vector2i(1, 4)] as Array).has(Vector2i(3, 2)), "the valve is linked to the vent")


func _battle(map: String, enemies_dormant := true) -> Battle:
	var b := Battle.new()
	b.setup(LevelLoader.parse(map), Catalog.load_units(), 12345)
	for e in b.swarm():
		e.dormant = enemies_dormant and not e.def.stationary
	return b


## Turn a test soldier into another class, fully re-equipped.
func _as(u: Unit, id: String) -> void:
	var d: UnitDef = Catalog.load_units()[id]
	var fresh := Unit.create(u.id, d, u.team, u.tile)
	u.def = d
	u.max_tu = fresh.max_tu
	u.tu = fresh.tu
	u.hp = fresh.hp
	u.ammo = fresh.ammo
	u.spare_clips = fresh.spare_clips
	u.pheromones = fresh.pheromones
	u.dynamite = fresh.dynamite


func _battle_basics() -> void:
	var b := Catalog.new_battle(Catalog.LEVELS[0], 7)
	check(b.squad().size() == 4, "four specialists start")
	check(b.swarm().size() >= 10, "the cavern holds the swarm and its hive")
	check(b.lift_tiles.size() >= 12, "the lift is laid out")
	check(b.journal_tile != Battle.NO_TILE, "the journal is placed")
	var eng: Unit = b.squad()[0]
	check(eng.def.id == &"engineer" and eng.max_tu == 50, "the Engineer leads with 50 TU")
	var ev := b.exec({"t": "move", "u": eng.id, "to": eng.tile + Vector2i(0, -10)})
	check(ev.size() == 1 and ev[0]["type"] == "refused", "a move beyond TU is refused")
	var before := eng.tu
	ev = b.exec({"t": "stance", "u": eng.id})
	check(eng.crouched and eng.tu == before - 3, "crouching costs 3 TU")
	ev = b.exec({"t": "face", "u": eng.id, "dir": 2})
	check(eng.facing == 2 and eng.tu == before - 3 - 4, "turning 180 degrees costs 4 TU")
	var lone := _battle("#######\n#S....#\n#######")
	var ls: Unit = lone.squad()[0]
	var lamp_before := lone.grid.light_at(ls.tile)
	lone.exec({"t": "lamp", "u": ls.id})
	check(not ls.lamp_on and lone.grid.light_at(ls.tile) < lamp_before, "shuttering a lamp darkens the tile")


func _combat() -> void:
	# A Cartographer and a worker, lit by fungus, six tiles apart.
	var b := _battle("##########\n#S.......#\n#........#\n#ff....w.#\n##########")
	var s: Unit = b.squad()[0]
	_as(s, "cartographer")
	var w: Unit = b.swarm()[0]
	s.facing = Rules.dir_toward(s.tile, w.tile)
	b._refresh_vision()
	var hb := b.hit_breakdown(s, w, "snap")
	check(hb["chance"] >= Rules.MIN_HIT and hb["chance"] <= Rules.MAX_HIT, "the hit chance is clamped")
	var aimed := b.hit_breakdown(s, w, "aimed")
	check(int(aimed["chance"]) > int(hb["chance"]), "an aimed shot beats a snap shot")
	# Pitch black, far off: a crawler (no glow) can't be seen or targeted.
	var dark := _battle("##############\n#S...........#\n#...........c#\n##############")
	var ds: Unit = dark.squad()[0]
	ds.lamp_on = false
	dark._recompute_light()
	var dw: Unit = dark.swarm()[0]
	ds.facing = Rules.dir_toward(ds.tile, dw.tile)
	dark._refresh_vision()
	_as(ds, "cartographer")
	check(dark.is_visible(dw.tile), "the crawler's tile is in the cone")
	check(not dark.spotted.has(dw.id), "but a dark crawler 11 tiles off isn't spotted")
	check(dark.shot_block(ds, dw, "snap", true).begins_with("Too dark"), "and pitch black blocks a shot beyond 2 tiles")
	var glow := _battle("##############\n#S...........#\n#...........w#\n##############")
	var gls: Unit = glow.squad()[0]
	gls.lamp_on = false
	gls.facing = Rules.dir_toward(gls.tile, glow.swarm()[0].tile)
	glow._recompute_light()
	glow._refresh_vision()
	check(glow.spotted.has(glow.swarm()[0].id), "a worker's own glow gives it away in the dark")
	# Burst pins; a shot spends TU and ammunition.
	var g := _battle("#########\n#S..w...#\n#########")
	var gs: Unit = g.squad()[0]
	_as(gs, "grenadier")
	gs.facing = 0
	g._refresh_vision()
	var gw: Unit = g.swarm()[0]
	check(g.spotted.has(gw.id), "a glowing worker three tiles off is spotted")
	var ev := g.exec({"t": "shoot", "u": gs.id, "target": gw.id, "mode": "burst"})
	var shots := ev.filter(func(e): return e["type"] == "shot").size()
	check(shots >= 3 and shots <= 5, "a burst fires 3 to 5 rounds")
	check(gs.tu == gs.max_tu - Rules.shot_tu("burst", gs.max_tu), "the burst cost 60% of Max TU")
	check(not gw.alive or gw.pinned, "a burst pins whatever survives it")
	check(gs.ammo == gs.def.weapon.clip - shots, "every round came out of the clip")
	# Cover.
	var c := _battle("#########\n#S...ow.#\n#########")
	check(c.has_cover(Vector2i(6, 1), Vector2i(1, 1)), "a boulder between gives cover")
	check(not c.has_cover(Vector2i(6, 1), Vector2i(8, 1)), "but not from behind")


func _reactions() -> void:
	check(Rules.reaction_score(90, 33, 65) > Rules.reaction_score(30, 36, 36), "a sharp-eyed watcher with half TU beats a fresh worker")
	check(Rules.reaction_score(55, 17, 50) < Rules.reaction_score(60, 52, 52), "a tired Engineer loses to a fresh crawler")
	# A soldier on overwatch fires at a worker walking into a lit cone.
	var b := _battle("############\n#S.........#\n#ffffffffff#\n#.........w#\n############", false)
	var s: Unit = b.squad()[0]
	_as(s, "naturalist")
	s.facing = 0
	var w: Unit = b.swarm()[0]
	w.facing = 4
	b._refresh_vision()
	var ev := b.exec({"t": "end_turn"})
	var fired := ev.filter(func(e): return e["type"] == "reaction" and e["fires"]).size()
	check(fired >= 1, "overwatch fires at a worker crossing the cone")
	check(b.stats["reactions"] >= 1, "the reaction is counted")


func _swarm() -> void:
	# A crawler picks the tile behind a soldier facing it.
	var b := _battle("#########\n#.......#\n#...S...#\n#.......#\n#.c.....#\n#########", false)
	var s: Unit = b.squad()[0]
	s.facing = 3
	var c: Unit = b.swarm()[0]
	var r := b.grid.reach(c.tile, c.tu, false, c.id)
	var spot := SwarmAI.attack_tile(b, c, s, r)
	check(spot != Battle.NO_TILE, "the crawler finds an attack tile")
	check(not Rules.in_cone(s.tile, s.facing, spot, 45.0), "and it is outside the soldier's cone")
	# Pheromone decays and finally goes.
	b._add_pheromone(Vector2i(1, 1), 1.0)
	for i in 4:
		b._decay_pheromones()
	check(b.pheromones.is_empty(), "a single sighting fades in four enemy turns")
	b._add_pheromone(Vector2i(1, 1), 2.5)
	b._add_pheromone(Vector2i(1, 1), 2.5)
	check(is_equal_approx(b.pheromones[Vector2i(1, 1)], Rules.PHEROMONE_CAP), "pheromone is capped")
	# A lure pulls a waking worker.
	var lb := _battle("##############\n#S...........#\n#............#\n#..........w.#\n##############", true)
	var ls: Unit = lb.squad()[0]
	_as(ls, "naturalist")
	var lw: Unit = lb.swarm()[0]
	var start := lw.tile
	lb.exec({"t": "throw", "u": ls.id, "item": "pheromone", "to": Vector2i(6, 3)})
	lb.exec({"t": "end_turn"})
	check(not lw.dormant, "the lure wakes the worker")
	check(Rules.dist(lw.tile, Vector2i(6, 3)) < Rules.dist(start, Vector2i(6, 3)), "and it heads for the lure")


## Whole turns on the real level with nobody acting: the swarm must keep acting legally.
func _full_rounds() -> void:
	var b := Catalog.new_battle(Catalog.LEVELS[0], 99)
	var t0 := Time.get_ticks_msec()
	for i in 12:
		if b.outcome != "":
			break
		var ev := b.exec({"t": "end_turn"})
		check(not ev.is_empty() and ev[0]["type"] != "refused", "end turn %d runs" % i)
	var ms := Time.get_ticks_msec() - t0
	print("12 idle turns took %d ms" % ms)
	check(ms < 8000, "an enemy phase is fast enough to feel instant")
	for u in b.units:
		if u.alive:
			check(b.grid.occupant[b.grid.idx(u.tile)] == u.id, "unit %d's tile knows it" % u.id)
