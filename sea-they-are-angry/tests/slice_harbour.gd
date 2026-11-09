extends SceneTree
## Chapter Two, Kirkhaven harbour: the map and its paths, the generator and the street
## lamps, lit landings, raiders and the kirk, the bell, the last night's fog, the ending.
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

	# The place.
	check(Terrain.chapter == 2 and run.chapter == 2, "the ground is Kirkhaven's")
	check(main.players.size() == 3 and main.lamps.size() == HarbourMap.LAMPS.size() and main.houses.size() == HarbourMap.BUILDINGS.size(),
		"three keepers, %d lamps, %d houses" % [main.lamps.size(), main.houses.size()])
	var p: Player = main.player
	check(HarbourMap.place_name(p.global_position) == "the pier" and absf(p.global_position.y - HarbourMap.QUAY_H) < 0.6, "the keepers are put ashore on the pier")
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
	check(is_equal_approx(main._landing_scale(HarbourMap.landing_point(0, 0.0)), main.LIT_LANDING) and main._landing_scale(HarbourMap.landing_point(2, 0.0)) == 1.0, "a lit landing lets fewer through")
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
	check(kirk.interact_prompt().contains("Knock") and kirk.interact(p) and _said.contains("Keepers"), "a knock at the kirk door is answered")
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
	kirk.take_damage(120)
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

	# Dawn: the night is counted and the run saved, in Kirkhaven.
	cyc._enter(cyc.Phase.NIGHT)
	cyc.running = false
	await _wait(3)
	cyc._enter(cyc.Phase.DAWN)
	cyc.running = false
	await _wait(3)
	var save: Dictionary = root.get_node("SaveSys").load_run()
	check(run.night == 2 and int(save.get("chapter", 0)) == 2 and (save.get("lamps_on", []) as Array).size() == main._lamps_on() and bool(save.get("bell_mended", false)),
		"dawn: night 2 to come, saved with its lamps and the bell")

	# The last night: the fog comes over the quay, and they go for the kirk.
	run.night = Rescue.night()
	cyc._enter(cyc.Phase.DUSK)
	cyc.running = false
	check(kirk.besieged and kirk.draws_raiders(), "the last night, the kirk is besieged")
	cyc._enter(cyc.Phase.NIGHT)
	cyc.running = false
	await _wait(90)
	check(main.atmosphere.fog.flood > 0.0, "and the fog is coming over the town (%.3f)" % main.atmosphere.fog.flood)
	var raider := Bloated.new()
	main._on_spawn(raider, "B", true)
	check(raider.raid_goal == kirk, "the night's raiders are sent at the kirk doors")
	raider.free()

	# If the doors go, it's over.
	kirk.take_damage(1000)
	check(_ended == "They got into the kirk." and not run.active, "the kirk doors down ends it: %s" % _ended)

	# Held to the last dawn: the ending.
	run.active = true
	kirk.repair(1000)
	cyc._enter(cyc.Phase.DAWN)
	await _wait(5)
	check(main._ending and not run.active and root.get_node("SaveSys").chapter_done(2), "the last dawn: the chapter is finished")
	check(main._townsfolk.size() > 0, "the people come out of the kirk (%d)" % main._townsfolk.size())
	main._ending_t = main.ENDING_SECONDS - 0.1
	await _wait(200)
	var card = main.get_node_or_null("HarbourEnd")
	check(card != null, "and the last card comes up")
	var lit := 0
	for h in main.houses:
		if h.lit:
			lit += 1
	check(lit > 0, "the windows of Kirkhaven are lighting (%d so far)" % lit)
	print("ALL PASS" if fails == 0 else "FAILED: %d" % fails)
	Terrain.chapter = 1
	quit(1 if fails > 0 else 0)
