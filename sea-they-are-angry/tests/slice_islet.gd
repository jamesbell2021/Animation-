extends SceneTree
# Run: godot --headless --path sea-they-are-angry --script res://tests/slice_islet.gd
# Gull Rock: the islet's ground, the rowing boat out and back (and only by day, and not
# in a storm, out; always back), hauling it across on its line, the gulls' eggs (taken,
# boiled, laid again at dawn), and the gulls (about by day, gone at night and in a
# storm, put up by a keeper, mobbing an egg thief). Creatures and helpers leave a keeper
# out there alone.

var fails := 0

func check(c: bool, w: String) -> void:
	print(("PASS  " if c else "FAIL  ") + w)
	if not c:
		fails += 1

func _init() -> void:
	_go.call_deferred()

func _wait(frames: int) -> void:
	for i in frames:
		await physics_frame

func _until(cond: Callable, frames: int) -> bool:
	for i in frames:
		if cond.call():
			return true
		await physics_frame
	return cond.call()

func _go() -> void:
	if FileAccess.file_exists("user://run.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://run.json"))
	var pl = root.get_node("Players")
	pl.wanted = 1
	pl.helpers = false
	change_scene_to_file("res://scenes/main.tscn")
	for i in 600:
		if current_scene != null and current_scene.get("player") != null and current_scene.player != null:
			break
		await process_frame
	await _wait(3)
	var main = current_scene
	var CD = load("res://scenes/world/camera_director.gd")
	var Cyc = root.get_node("Cycle")
	var Stk = root.get_node("Stock")
	var p: Player = main.player
	p.camera = null
	Cyc.running = false
	Cyc._enter(0)
	main.spawner.process_mode = Node.PROCESS_MODE_DISABLED
	await _wait(2)

	# ---- the ground ----
	var top := Terrain.islet_world(Vector2(0.0, 0.0))
	check(Terrain.on_islet(top.x, top.z) and Terrain.walkable(top.x, top.z) and Terrain.island_of(top.x, top.z) == 2, "Gull Rock's top is ground to stand on (%.1f m up)" % top.y)
	var walk_up := true
	for k in 12:
		var t := 0.4 + 0.6 * float(k) / 11.0
		var sp := Terrain.islet_slip_point(t)
		walk_up = walk_up and Terrain.walkable(sp.x, sp.z)
	check(walk_up, "the slip can be walked from the water's edge to the top")
	var wet := true
	for k in 10:
		var w: Vector3 = main.rowing_boat._point(main.rowing_boat.length * (0.2 + 0.06 * float(k)))[0]
		wet = wet and Terrain.height_at(w.x, w.z) < Terrain.SEA_LEVEL - 0.2
	check(wet, "open water all along the boat's way: no walking across")
	check(Terrain._islet_height(0.0, 5.0) < Terrain.SEA_FLOOR and Terrain._islet_height(48.0, 3.0) < Terrain.SEA_FLOOR, "the islet changes nothing on the other two islands")
	check(get_nodes_in_group("gull_nests").size() == main.NESTS, "%d nests on the rock" % main.NESTS)

	# ---- out in the boat ----
	var boat = main.rowing_boat
	var foot: Vector3 = boat.landings[0].global_position
	p.global_position = foot + Vector3(0.0, 0.3, 0.0)
	await _wait(10)
	check(p.interact_prompt().contains("Row out to Gull Rock"), "at the jetty: " + p.interact_prompt())
	Cyc._enter(1)
	await _wait(3)
	check(p.interact_prompt().contains("getting dark"), "not at dusk: " + p.interact_prompt())
	Cyc._enter(0)
	main.atmosphere.weather.storm = 0.6
	main.atmosphere.weather._target = 0.6
	await _wait(3)
	check(p.interact_prompt().contains("too rough"), "not in a storm: " + p.interact_prompt())
	main.atmosphere.weather.storm = 0.1
	main.atmosphere.weather._target = 0.1
	await _wait(3)
	p._target = p._find_interactable()
	p._target.interact(p)
	check(p.riding == boat and boat.state == 1, "E: into the boat, at the oars")
	Engine.time_scale = 4.0
	check(await _until(func(): return boat.state == 2, 300), "pushes off and rows")
	var mid := false
	for i in 1200:
		if boat.progress() > 0.4 and boat.progress() < 0.6 and p.riding != null:
			mid = absf(p.global_position.distance_to(boat.global_position)) < 1.5
			if mid:
				check(p.is_busy() and p.interact_prompt() == "", "rowing: the keeper sits in the boat, nothing else to do")
				var f: Vector3 = CD.focus_for_keeper(p)
				check(f.z < CD.MAIN_FOCUS.z - 5.0 and f.z > CD.ISLET_FOCUS.z + 5.0, "the camera follows the boat between the islands")
				break
		await physics_frame
	check(mid, "half way across, in the boat")
	check(await _until(func(): return boat.state == 0 and p.riding == null, 1800), "lands at Gull Rock")
	await _wait(20)
	check(Terrain.on_islet(p.global_position.x, p.global_position.z) and Terrain.walkable(p.global_position.x, p.global_position.z), "the keeper steps ashore on the rock")
	check(CD.focus_for_keeper(p) == CD.ISLET_FOCUS and is_equal_approx(CD.zoom_for_keeper(p), CD.ISLET_ZOOM), "the camera frames Gull Rock, closer in")
	Engine.time_scale = 1.0

	# ---- the eggs ----
	var nests := get_nodes_in_group("gull_nests")
	var nest = nests[0]
	nest.set_eggs(2)
	var eggs0: int = Stk.get_amount("eggs")
	p.global_position = nest.global_position + Vector3(0.6, 0.2, 0.0)
	await _wait(10)
	check(p.interact_prompt().contains("gull eggs (2)"), "at a nest: " + p.interact_prompt())
	p._target = p._find_interactable()
	p._target.interact(p)
	check(Stk.get_amount("eggs") == eggs0 + 2 and nest.eggs == 0, "takes two eggs into the store")
	check(main.gulls._mob_t > 0.0, "the colony goes up and mobs the thief")
	await _wait(10)
	check(nest.interact_prompt() == "", "an empty nest offers nothing")
	Stk.set_amount("eggs", 3)
	var food0: int = Stk.get_amount("food")
	var cottage = null
	for s in get_nodes_in_group("structures"):
		if s.get_script().get_global_name() == "Cottage":
			cottage = s
	var boiled := false
	for r in cottage.menu_rows(p):
		if String(r["text"]).begins_with("Boil gull eggs"):
			r["do"].call()
			boiled = true
	check(boiled and Stk.get_amount("eggs") == 0 and Stk.get_amount("food") == food0 + 1, "the cottage boils 3 eggs into a meal")
	for n in nests:
		n.set_eggs(0)
	Cyc._enter(3)
	await _wait(2)
	var laid := 0
	for n in nests:
		laid += n.eggs
	check(laid > 0, "the gulls lay again by dawn (%d eggs)" % laid)
	Cyc._enter(0)

	# ---- the gulls ----
	var gulls = main.gulls
	check(gulls.present and gulls.about() >= 30, "by day the gulls are about (%d)" % gulls.about())
	Engine.time_scale = 4.0
	var standing := false
	for i in 1500:
		for g in gulls.birds:
			if g.is_perched() and g.role == "colony":
				standing = true
		if standing:
			break
		await physics_frame
	check(standing, "the colony settles on the rock")
	var g0 = null
	for g in gulls.birds:
		if g.is_perched() and g.role == "colony":
			g0 = g
	p.global_position = g0.global_position + Vector3(1.0, 0.2, 0.0)
	await _wait(12)
	check(not g0.is_perched(), "a keeper walking up puts it up")
	Cyc._enter(1)
	check(await _until(func(): return gulls.about() == 0, 1800), "at dusk they go off out to sea")
	Cyc._enter(2)
	await _wait(30)
	check(gulls.about() == 0 and not gulls.present, "none at night")
	Cyc._enter(0)
	check(await _until(func(): return gulls.about() >= 30, 120), "back by day")
	main.atmosphere.weather.storm = 0.8
	main.atmosphere.weather._target = 0.8
	check(await _until(func(): return gulls.about() == 0, 1800), "a storm sends them away")
	main.atmosphere.weather.storm = 0.1
	main.atmosphere.weather._target = 0.1
	check(await _until(func(): return gulls.about() >= 30, 120), "back when it's calm")
	Engine.time_scale = 1.0

	# ---- alone out there ----
	var sq = load("res://scenes/enemies/squid.gd").new()
	sq.lighthouse = main.lighthouse
	sq.position = Terrain.beach_point(0, 0.5)
	main.get_node("Enemies").add_child(sq)
	await _wait(2)
	check(sq.pick_target() == main.lighthouse, "a creature on the main island doesn't go for a keeper out on Gull Rock")
	sq.queue_free()
	Cyc._enter(1)
	await _wait(3)
	check(main.hud._warn_label.text.contains("Gull Rock"), "dusk warns a keeper still out there: " + main.hud._warn_label.text)

	# ---- back, at night, and hauling the boat over ----
	Cyc._enter(2)
	var ifoot: Vector3 = boat.landings[1].global_position
	p.global_position = ifoot + Vector3(0.0, 0.3, 0.0)
	await _wait(10)
	check(p.interact_prompt().contains("Row back"), "rowing back is allowed at night: " + p.interact_prompt())
	Engine.time_scale = 4.0
	p._target = p._find_interactable()
	p._target.interact(p)
	check(await _until(func(): return boat.state == 0 and boat.side == 0 and p.riding == null, 2400), "rows back to the jetty")
	await _wait(10)
	check(Terrain.island_of(p.global_position.x, p.global_position.z) == 0 and Terrain.walkable(p.global_position.x, p.global_position.z), "ashore at the jetty: %s island %d walk %s foot %s" % [p.global_position, Terrain.island_of(p.global_position.x, p.global_position.z), Terrain.walkable(p.global_position.x, p.global_position.z), foot])
	Cyc._enter(0)
	# Stranded on the rock with the boat at the jetty: haul it over on its line.
	p.global_position = ifoot + Vector3(0.0, 0.3, 0.0)
	await _wait(10)
	check(p.interact_prompt().contains("Haul"), "the boat's at the jetty: " + p.interact_prompt())
	p._target = p._find_interactable()
	p._target.interact(p)
	check(boat.state == 3 and p.riding == null, "hauls it across, empty")
	check(await _until(func(): return boat.state == 0 and boat.side == 1, 2400), "it comes in to the rock")
	Engine.time_scale = 1.0

	print("\n%s" % ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails > 0 else 0)
