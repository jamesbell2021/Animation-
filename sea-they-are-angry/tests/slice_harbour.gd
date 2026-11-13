extends SceneTree
## Act One, Kirkhaven: the map and its paths, the generator and the street lamps, lit
## landings, raiders and the kirk, the bell, the seven, the last night's flight to the
## boat, and the crossing to the rock.
##   godot --headless --path . --script res://tests/slice_harbour.gd

var fails := 0
var _ended := ""
var _said := ""

func check(c: bool, w: String) -> void:
	print(("PASS  " if c else "FAIL  ") + w)
	if not c:
		fails += 1

func _init() -> void:
	_go.call_deferred()

func _wait(frames: int) -> void:
	for i in frames:
		await physics_frame

func _go() -> void:
	if FileAccess.file_exists("user://run.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://run.json"))
	var pl = root.get_node("Players")
	var run = root.get_node("Run")
	var stock = root.get_node("Stock")
	var cyc = root.get_node("Cycle")
	var events = root.get_node("Events")
	pl.wanted = 1
	pl.helpers = true
	run.enter_harbour = true
	change_scene_to_file("res://scenes/harbour.tscn")
	for i in 900:
		if current_scene != null and current_scene.get("player") != null and current_scene.player != null:
			break
		await process_frame
	await _wait(5)
	var main = current_scene
	cyc.running = false
	main.spawner.process_mode = Node.PROCESS_MODE_DISABLED
	events.run_ended.connect(func(reason: String, _n: int) -> void: _ended = reason)
	# The seven keep indoors until their own part of this test.
	for v in main.villagers:
		v.go_inside()

	# The place.
	check(Terrain.chapter == 2 and run.chapter == 2, "the ground is Kirkhaven's")
	check(main.players.size() == 3 and main.lamps.size() == HarbourMap.LAMPS.size() and main.houses.size() == HarbourMap.BUILDINGS.size(),
		"three keepers, %d lamps, %d houses" % [main.lamps.size(), main.houses.size()])
	var p: Player = main.player
	check(HarbourMap.place_name(p.global_position) == "the quay" and absf(p.global_position.y - HarbourMap.QUAY_H) < 0.6, "the keepers begin on the quay, outside The Creel")
	check(Terrain.walkable(-20.0, 2.0) and Terrain.walkable(0.0, 20.0) and not Terrain.walkable(-8.0, 12.0) and not Terrain.walkable(-20.0, 6.2),
		"the quay and the pier can be walked; the basin and the quay's lip can't")
	check(Terrain.height_at(-15.0, 17.5) < Terrain.SEA_LEVEL - 1.0 and Terrain.height_at(-15.0, 6.5) > 1.0, "a slip runs from the quay down under the water")
	var way := Nav.route_to_light(HarbourMap.landing_point(0, 0.0))
	var keeps := true
	for q in way:
		keeps = keeps and Terrain.height_at(q.x, q.z) > HarbourMap.BASIN + 0.3
	check(way.size() >= 3 and keeps and Geo.flat_dist(way[way.size() - 1], main.lighthouse.global_position) < 2.5, "a creature's way from the west slip to the harbour light (%d corners)" % way.size())
	var kway: Array = KeeperNav.route(p.global_position, main.kirk.door_point())
	var through := false
	for s in kway:
		through = through or (absf(absf(s["p"].x) - 10.0) < 2.2 and s["p"].z < 0.0)
	check(kway.size() >= 3 and through, "a keeper's way to the kirk door goes up a wynd")
	check(Geo.flat_dist(Nav.route_to_sea(Vector3(5.0, 1.3, 2.0))[-1], HarbourMap.landing_point(1, 0.0)) < 3.5, "and the nearest way back to the sea is the east slip")
	check(Rescue.night() == Rescue.HARBOUR_NIGHTS[Difficulty.level()] and Rescue.countdown().contains("nights to hold"), "the town is to be held %d nights (%s)" % [Rescue.night(), Rescue.countdown()])
	check(main.spawner.night_table(1)[0]["kind"] == "B" and not main.spawner.night_table(5).any(func(e): return e["kind"] == "E"), "its nights start further down the table, and no Eel comes into the harbour")

	# The generator and the lamps.
	for k in main.players:
		if k.ai:
			k.get_node("KeeperAI").process_mode = Node.PROCESS_MODE_DISABLED
	var gen: Generator = main.generator
	var lamp: StreetLamp = main.lamps[1]
	check(gen.fuel < 20.0 and not lamp.on and lamp.interact_prompt().begins_with("[E] Switch in"), "the generator is nearly dry and the lamps are switched out")
	check(lamp.interact(p) and lamp.on and not lamp.is_lit() and run.lamps_on.has(1), "switched in by day, the lamp waits for dusk")
	check(gen.interact(p) and gen.fuel > 40.0 and stock.get_amount("diesel") == 0, "the can of diesel goes into the generator (%d%%)" % roundi(gen.fuel))
	cyc._enter(cyc.Phase.DUSK)
	cyc.running = false
	await _wait(30)
	check(gen.has_power() and lamp.is_lit() and not main.lamps[5].is_lit(), "at dusk the generator starts and the lamp burns; the others stay dark")
	await _wait(60)
	check(lamp.fog_hole().z > 6.0 and main.lamps[5].fog_hole().z == 0.0, "its light holds the fog off (%.1f m)" % lamp.fog_hole().z)
	check(main.landing_lit(0) and not main.landing_lit(1) and not main.landing_lit(2), "the west slip has a lamp at its head; the east slip and the strand are dark")
	# A villager walking faces the way they go (they once walked backwards).
	var wv: Villager = main.villagers[0]
	var was_at: Vector3 = wv.global_position
	var was_state: String = wv.state
	wv.place(Vector3(-6.0, 0.0, 2.6))
	wv.walk_to(Vector3(20.0, 0.0, 2.6))
	for i in 40:
		await physics_frame
	var fwd: Vector3 = -wv.rig.global_transform.basis.z if wv.rig != null else Vector3.RIGHT
	check(wv.global_position.x > -5.9 and Vector2(fwd.x, fwd.z).normalized().dot(Vector2(1.0, 0.0)) > 0.8, "a villager walking east faces east")
	wv.place(was_at, was_state)
	# The boats hauled up the strand are solid, and the paths go round them.
	var hulls := main.find_children("Hull", "StaticBody3D", true, false).size()
	var hq := PhysicsPointQueryParameters3D.new()
	hq.position = Vector3(29.0, Terrain.height_at(29.0, 6.4) + 0.8, 6.4)
	hq.collision_mask = HarbourProps.SOLID_LAYER
	check(hulls == 2 and not main.get_world_3d().direct_space_state.intersect_point(hq).is_empty() and HarbourMap._blocked(29.0, 6.4), "the boats on the strand are solid (%d hulls) and the paths go round them" % hulls)
	check(is_equal_approx(main._landing_scale(HarbourMap.landing_point(0, 0.0)) / main._landing_scale(HarbourMap.landing_point(2, 0.0)), main.LIT_LANDING), "a lit landing lets fewer through")
	var picks := [0, 0, 0]
	for i in 600:
		picks[main._pick_landing({}) / 2] += 1
	check(picks[0] * 2 < picks[1] and picks[0] * 2 < picks[2], "and they would sooner come up in the dark (%s)" % str(picks))
	check(main._status_line()[0].contains("1 of %d" % main.lamps.size()), "the HUD: %s" % main._status_line()[0])

	# What the lamplight does, and what they do about it.
	var b := Bloated.new()
	b.lighthouse = main.lighthouse
	b.raid = true
	b.position = lamp.global_position + Vector3(2.5, 0.0, 0.5)
	main.get_node("Enemies").add_child(b)
	await _wait(12)
	check(b._lit_t > 0.0, "a Bloated in the lamplight is slowed")
	check(b.pick_target() == lamp, "a raider makes for the nearest burning lamp")
	b.raid_goal = main.kirk
	check(b.pick_target() == main.kirk, "one sent at the kirk makes for the kirk")
	b.queue_free()
	var crab := Crab.new()
	crab.lighthouse = main.lighthouse
	crab.position = HarbourMap.landing_point(2, 1.0)
	main.get_node("Enemies").add_child(crab)
	await _wait(3)
	check(crab.pick_target() == gen or crab.pick_target() == lamp, "a Crab goes for what's lit or running")
	crab.queue_free()
	lamp.take_damage(60)
	await _wait(5)
	check(lamp.is_destroyed() and not lamp.is_lit() and lamp.fog_hole().z == 0.0 and not lamp.draws_raiders(), "a smashed lamp is dark, and the fog comes back")
	stock.set_amount("scrap", 1)
	check(lamp.interact_prompt().contains("Mend") and lamp.interact(p) and lamp.hp == lamp.max_hp, "one scrap mends it")
	await _wait(5)
	check(lamp.is_lit(), "and it burns again without being switched in twice")

	# The kirk and its bell.
	var kirk = main.kirk
	kirk.spoke.connect(func(t: String) -> void: _said = t)
	check(kirk.interact_prompt().contains("Knock") and kirk.interact(p) and _said.contains("Mr Baird"), "a knock at the kirk door is answered")
	stock.set_amount("scrap", 0)
	kirk.alt_use(p)
	check(not run.bell_mended, "the bell rope wants scrap")
	stock.set_amount("scrap", 2)
	kirk.alt_use(p)
	check(run.bell_mended and stock.get_amount("scrap") == 0, "two scrap splice it")
	check(kirk.can_ring(), "it can be rung in the dark")
	kirk.alt_use(p)
	await _wait(3)
	check(lamp.flare > 0.0 and main.lamps[5].flare == 0.0 and not kirk.can_ring(), "rung, every burning lamp flares; once a night")
	var b2 := Bloated.new()
	b2.lighthouse = main.lighthouse
	b2.position = lamp.global_position + Vector3(4.0, 0.0, -3.0)
	main.get_node("Enemies").add_child(b2)
	var hp0 := b2.max_hp
	await _wait(260)
	check(not is_instance_valid(b2) or b2.hp < hp0, "and what stands in the flare burns")
	if is_instance_valid(b2):
		b2.queue_free()
	check(not kirk.draws_raiders(), "while a lamp burns, raiders leave the kirk be")
	kirk.take_damage(160)
	check(main._status_line()[0].contains("kirk doors"), "the HUD shows the doors when they're hurt: %s" % main._status_line()[0])

	# A helper walks the lamps.
	cyc._enter(cyc.Phase.DAY)
	cyc.running = false
	stock.set_amount("scrap", 0)
	stock.set_amount("driftwood", 0)
	stock.set_amount("diesel", 0)
	var helper: Player = main.players[2]
	helper.get_node("KeeperAI").process_mode = Node.PROCESS_MODE_INHERIT
	var before: int = main._lamps_on()
	for i in 1500:
		await physics_frame
		if main._lamps_on() > before:
			break
	check(main._lamps_on() > before, "the helper who walks the lamps switches one in")
	helper.get_node("KeeperAI").process_mode = Node.PROCESS_MODE_DISABLED

	# The seven.
	for v in main.villagers:
		v.place(main._home_of(v), "about")
	check(main.villagers.size() == 7 and run.villagers.size() == 7 and run.story, "seven of Kirkhaven are left, and this is the story")
	var isla: Villager = null
	for v in main.villagers:
		if v.id == "rennie":
			isla = v
	check(isla != null and isla.state == "about" and isla.visible and not isla.is_in_group("prey"), "by day they are about their doors, and nothing's prey")
	main._call_in()
	check(isla.state == "walking", "late in the day they make for the kirk")
	for v in main.villagers:
		v.go_inside()
	check(main._inside().size() == 7 and not isla.visible, "and shut themselves in")

	# The kirk doors down in the night: those inside are taken one by one.
	cyc._enter(cyc.Phase.NIGHT)
	cyc.running = false
	await _wait(3)
	kirk.take_damage(1000)
	check(run.active and _ended == "", "the kirk doors down does not end it")
	main._breach_t = main.BREACH_EVERY
	await _wait(4)
	check(run.villagers.size() == 6 and run.lost.size() == 1 and main._inside().size() == 6, "but one of those inside is taken (%s)" % str(run.lost))
	kirk.repair(1000)
	main._breach_t = main.BREACH_EVERY
	await _wait(4)
	check(run.villagers.size() == 6, "mended, the doors hold")

	# Out of doors in the dark, within a creature's reach.
	var out: Villager = main._inside()[0]
	out.place(Vector3(-20.0, 0.0, 2.0), "about")
	await _wait(3)
	check(out.is_in_group("prey"), "one of them out of doors in the dark is prey")
	var hunter := Bloated.new()
	hunter.lighthouse = main.lighthouse
	hunter.position = out.global_position + Vector3(6.0, 0.0, 0.0)
	main.get_node("Enemies").add_child(hunter)
	await _wait(3)
	check(hunter.pick_target() == out, "a creature turns aside for them")
	hunter.global_position = out.global_position + Vector3(0.8, 0.0, 0.0)
	hunter.state = &"Approach"
	hunter.process_mode = Node.PROCESS_MODE_DISABLED
	await _wait(50)
	check(out.state == "lost" and run.villagers.size() == 5, "and anything that gets within reach takes them")
	hunter.queue_free()

	# Dawn: the night is counted, the living bring what they can, the run is saved.
	stock.set_amount("scrap", 0)
	stock.set_amount("food", 0)
	p.hp = 40
	cyc._enter(cyc.Phase.DAWN)
	cyc.running = false
	await _wait(3)
	var save: Dictionary = root.get_node("SaveSys").load_run()
	check(run.night == 2 and int(save.get("chapter", 0)) == 2 and (save.get("villagers", []) as Array).size() == 5 and bool(save.get("story", false)),
		"dawn: night 2 to come, saved with who is left")
	check(stock.get_amount("scrap") == (1 if run.villagers.has("rennie") else 0) and stock.get_amount("food") == (1 if run.villagers.has("duthie") else 0), "the chandler and the publican bring what they can")
	check(p.hp == p.max_hp or not run.villagers.has("buchan"), "the nurse sees to the keepers")
	var abroad := 0
	for v in main.villagers:
		if v.state == "walking" or v.state == "about":
			abroad += 1
	check(abroad == 5, "and the five come out of the kirk")

	# The last night: the fog over the quay, the skipper's horn, down to the boat.
	run.night = Rescue.night()
	cyc._enter(cyc.Phase.DUSK)
	cyc.running = false
	for v in main.villagers:
		v.go_inside()
	check(kirk.besieged and kirk.draws_raiders(), "the last night, the kirk is besieged")
	cyc._enter(cyc.Phase.NIGHT)
	cyc.running = false
	await _wait(90)
	check(main.atmosphere.fog.flood > 0.0, "and the fog is coming over the town (%.3f)" % main.atmosphere.fog.flood)
	var raider := Bloated.new()
	main._raid_groups = 1
	main._on_spawn(raider, "B", true)
	check(raider.raid_goal == kirk, "the night's raiders are sent at the kirk doors")
	raider.free()
	check(not main.boat.waiting and main.boat.interact_prompt() == "", "the Mary Ann lies at the pier, her plank in")
	main._begin_evacuation()
	check(main._evac == 1 and not cyc.running, "the horn: the night holds while they come down")
	main._trickle_t = 9999.0
	Engine.time_scale = 6.0
	for i in 4000:
		await physics_frame
		if main._evac == 2:
			break
	Engine.time_scale = 1.0
	var aboard := 0
	for v in main.villagers:
		if v.state == "aboard":
			aboard += 1
	check(main._evac == 2 and aboard == run.villagers.size() and aboard >= 1, "they come down through the streets and go aboard (%d of the five)" % aboard)
	check(main.boat.waiting and main.boat.interact_prompt().contains("Go aboard"), "then her plank is out for the keepers")
	stock.set_amount("scrap", 3)
	for k in main.players:
		main.boat.take_aboard(k)
	Engine.time_scale = 8.0
	for i in 6000:
		await process_frame
		if current_scene != null and current_scene != main and current_scene.get("player") != null and current_scene.player != null:
			break
	Engine.time_scale = 1.0
	await _wait(5)
	# Up the coast first: the Escape (tests/slice_escape.gd plays it); here she is brought
	# straight in under the rock's light.
	var escape = current_scene
	check(escape != main and escape.get("helm") != null and Terrain.chapter == 3 and escape.villagers.size() == aboard, "she sails, and the Escape is next, with the %d aboard" % aboard)
	escape.travelled = escape.distance - 0.5
	for i in 3000:
		await process_frame
		if current_scene != null and current_scene != escape and current_scene.get("player") != null and current_scene.player != null:
			break
	await _wait(5)
	var rock = current_scene
	check(rock != main and Terrain.chapter == 1 and run.chapter == 1 and root.get_node("SaveSys").chapter_done(2), "she sails, and the rock is next")
	check(run.active and run.story and run.night == 1 and run.villagers.size() == aboard, "Act Two begins with those who were saved (%d)" % run.villagers.size())
	check(rock.story != null and rock.story.people.size() == aboard, "and they are in the old camp")
	check(stock.get_amount("scrap") >= 3 and run.arms[0].has("shotgun"), "what the keepers carried came with them")
	print("ALL PASS" if fails == 0 else "FAILED: %d" % fails)
	Terrain.chapter = 1
	quit(1 if fails > 0 else 0)
