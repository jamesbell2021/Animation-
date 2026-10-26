extends SceneTree
# Run: godot --headless --path sea-they-are-angry --script res://tests/slice_camp_raid.gd
# Creatures raid the camp: groups landing on the holm, the way up its beaches and through
# the wire, what they wreck and what stops working, the camp falling, mending it, the
# warden mending it, and the alarm bell.

var fails := 0
# The camp's classes are only reached through the scene, never named here: `--script`
# compiles what a test names before the autoloads exist, which can leave it unusable.

func check(c: bool, w: String) -> void:
	print(("PASS  " if c else "FAIL  ") + w)
	if not c:
		fails += 1

func _init() -> void:
	_go.call_deferred()

func _wait(frames: int) -> void:
	for i in frames:
		await physics_frame

func _load(helpers: bool):
	if FileAccess.file_exists("user://run.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://run.json"))
	var pl = root.get_node("Players")
	pl.wanted = 1
	pl.helpers = helpers
	change_scene_to_file("res://scenes/main.tscn")
	for i in 600:
		if current_scene != null and current_scene.get("player") != null and current_scene.player != null:
			break
		await process_frame
	await _wait(3)
	return current_scene

func _spawn(main, script: String, at: Vector3, camp: bool):
	var e = load(script).new()
	e.lighthouse = main.lighthouse
	e.camp_raid = camp
	e.position = at
	main.get_node("Enemies").add_child(e)
	return e

func _go() -> void:
	var main = await _load(false)
	var Cyc = root.get_node("Cycle")
	var Stk = root.get_node("Stock")
	var Run = root.get_node("Run")
	var p: Player = main.player
	p.camera = null
	Cyc.running = false
	var camp = main.camp

	# ---- the camp as something to raid ----
	var b: Dictionary = camp.buildings
	check(b.has("quarters") and b.has("mess") and b.has("greenhouse"), "the quarters, the mess and the greenhouse can be wrecked")
	check(camp.wire.size() == 5 and camp.wire[0].is_in_group("barricades"), "five runs of wire to tear through (%d)" % camp.wire.size())
	check(camp.targets().size() == 4 and not camp.fallen(), "four things for creatures to make for: the generator and the buildings")

	# ---- the way ----
	var off: Vector3 = Terrain.holm_beach_point(0, 0.0)
	var route: Array = Nav.route_to(off, camp.generator.global_position)
	var all_holm := true
	for q in route:
		all_holm = all_holm and Terrain.holm_side(q.x, q.z)
	check(route.size() >= 5 and all_holm, "a way up the holm's east beach to the generator, all on the holm (%d steps)" % route.size())
	var crosses := false
	for i in range(1, route.size()):
		if Terrain.in_camp(route[i].x, route[i].z) != Terrain.in_camp(route[i - 1].x, route[i - 1].z):
			crosses = true
	check(crosses, "straight through the wire, not round by the gate")
	var sea: Array = Nav.route_to_sea(camp.generator.global_position)
	check(not sea.is_empty() and Terrain.holm_side(sea[-1].x, sea[-1].z) and sea[-1].y < Terrain.SEA_LEVEL + 0.3, "and back out to sea off the holm at dawn")

	# ---- the night table ----
	var sp = main.spawner
	var holm_rows := func(n: int) -> int:
		var k := 0
		for e in sp.night_table(n):
			if e["holm"]:
				k += 1
		return k
	check(holm_rows.call(1) == 0, "night 1: nothing for the camp")
	check(holm_rows.call(2) >= 1 and holm_rows.call(5) > holm_rows.call(3), "from night 2 groups go for the camp, more from night 5 (%d, %d, %d)" % [holm_rows.call(2), holm_rows.call(3), holm_rows.call(5)])
	var none_m := true
	for n in range(2, 9):
		for e in sp.night_table(n):
			if e["holm"] and not (e["kind"] in ["B", "S", "C"]):
				none_m = false
	check(none_m, "only Bloated, Squid and Crabs: Smotherers and the Eel stay with the light")
	check(sp.holm_points.size() == 4 and sp.camp_standing(), "landing points off the holm's two beaches")

	# ---- a raid: up the beach, through the wire, at the generator ----
	Cyc._enter(Cyc.Phase.NIGHT)
	Cyc.running = false
	p.global_position = main.lighthouse.global_position + Vector3(0.0, 0.1, 4.0)
	var bl = _spawn(main, "res://scenes/enemies/bloated.gd", Terrain.holm_beach_point(0, 0.05), true)
	Engine.time_scale = 3.0
	var at_wire = null
	for i in 1500:
		await physics_frame
		if bl.state == &"AttackFence" and bl.attack_target != null and bl.attack_target.is_in_group("camp_wire"):
			at_wire = bl.attack_target
			break
	check(at_wire != null, "a Bloated comes up the east beach and tears at the wire")
	if at_wire != null:
		await _wait(200)
		check(at_wire.hp < at_wire.max_hp, "the wire takes it (%d/%d)" % [at_wire.hp, at_wire.max_hp])
		at_wire.take_damage(999)
	check(bl.target == camp.generator, "it's making for the generator")
	var g0: int = camp.generator.hp
	for i in 1500:
		await physics_frame
		if not is_instance_valid(bl) or camp.generator.hp < g0:
			break
	await _wait(30)
	Engine.time_scale = 1.0
	check(camp.generator.hp < g0, "through the gap, it bursts against the generator (%d -> %d)" % [g0, camp.generator.hp])
	check(main.hud._camp_label.text.contains("wire down"), "the HUD says so: " + main.hud._camp_label.text)
	# A Squid off the holm doesn't go after a keeper on the main island.
	var sq = _spawn(main, "res://scenes/enemies/squid.gd", Terrain.holm_beach_point(1, 0.6), true)
	await _wait(120)
	check(sq.target != p and sq.target != main.lighthouse and sq.target != null, "a Squid on the holm goes for the camp, not a keeper over the water")
	var cr = _spawn(main, "res://scenes/enemies/crab.gd", Terrain.holm_beach_point(1, 0.6), true)
	await _wait(120)
	check(cr.target != null and cr.target.is_in_group("camp"), "and a Crab for the camp's nearest building")
	sq.queue_free()
	cr.queue_free()
	await _wait(2)

	# ---- what stops working ----
	camp.generator.fuel = 80.0
	camp.generator.repair(999)
	await _wait(10)
	b["quarters"].take_damage(999)
	await _wait(5)
	check(not camp._hut_lights[0].visible and camp._hut_lights[2].visible, "a wrecked hut goes dark; the other stays lit")
	Stk.set_all({"driftwood": 2, "food": 2, "scrap": 6, "notes": 2, "seeds": 2})
	check(not camp.stove.interact(p) and not camp.stove.is_lit() and camp.stove.interact_prompt().contains("wrecked"), "the quarters wrecked: no lighting the stove")
	b["mess"].take_damage(999)
	p.hunger = 30.0
	check(not camp.mess.interact(p) and not camp.desk.usable() and not camp.desk.interact(p), "the mess wrecked: no meals, no research")
	Run.researching = "governor"
	Cyc._enter(Cyc.Phase.DAWN)
	Cyc.running = false
	await _wait(2)
	check(Run.researching == "governor" and not Run.research.has("governor"), "and the night's research waits")
	Cyc._enter(Cyc.Phase.DAY)
	Cyc.running = false
	var glass = camp.plots[3]
	b["greenhouse"].take_damage(999)
	check(not glass.interact(p) and glass.interact_prompt().contains("smashed") and not b["greenhouse"].breakable[0].visible, "the greenhouse smashed: its glass gone, nothing sown")
	check(not camp.fallen(), "with the generator standing, the camp holds")
	camp.generator.take_damage(999)
	await _wait(2)
	check(camp.fallen() and not sp.camp_standing(), "the generator wrecked too: the camp has fallen, and raids go back to the light")
	check(main.hud._camp_label.text.begins_with("THE CAMP HAS FALLEN"), "the HUD: " + main.hud._camp_label.text)
	check(main._camp_report() == "the camp has fallen", "and so does the dawn report")
	check(Run.active, "losing the camp doesn't end the run")

	# ---- mending ----
	camp.generator.repair(999)
	b["mess"].repair(999)
	b["greenhouse"].repair(999)
	check(glass.interact(p) and b["greenhouse"].breakable[0].visible, "the greenhouse mended: glazed, and sown again")
	# The east run (the north one is behind the mess hut, which wants mending first).
	var w = camp.wire[1]
	p.global_position = w.work_point() + Vector3(0.0, 0.1, 0.0)
	await _wait(3)
	check(p.interact_prompt().contains("Repair") and p._find_interactable() == w, "at the torn wire: " + p.interact_prompt())
	var s0: int = Stk.get_amount("scrap")
	w.interact(p)
	w.interact(p)
	check(not w.is_destroyed() and w.hp == 120 and Stk.get_amount("scrap") == s0 - 2, "two scrap mend a run of wire")
	b["quarters"].repair(999)
	check(camp.stove.interact(p), "mend the quarters and the stove lights again")

	# ---- the warden mends the camp ----
	main = await _load(true)
	Cyc = root.get_node("Cycle")
	Stk = root.get_node("Stock")
	main.player.camera = null
	camp = main.camp
	var torn = camp.wire[1]
	torn.take_damage(80)
	Stk.set_all({"scrap": 4, "driftwood": 4, "seeds": 0, "diesel": 0})
	camp.generator.fuel = 100.0
	Engine.time_scale = 4.0
	for i in 2400:
		await physics_frame
		if torn.hp == torn.max_hp:
			break
	Engine.time_scale = 1.0
	check(torn.hp == torn.max_hp, "the warden mends the torn wire by day (%d/%d)" % [torn.hp, torn.max_hp])

	# ---- the alarm bell ----
	var hud = main.hud
	hud._warn_label.text = ""
	var sp2 = main.spawner
	sp2._queue_holm({"kind": "B", "count": 1})
	check(hud._warn_label.text == "", "without the bell, a landing on the holm goes unannounced on the main island")
	root.get_node("Run").research.append("bell")
	sp2._queue_holm({"kind": "B", "count": 1})
	check(hud._warn_label.text.contains("bell") and hud._warn_label.text.contains("beach"), "with it, the camp's bell rings and says where: " + hud._warn_label.text)

	root.get_node("Players").helpers = true
	print("\n%s" % ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails > 0 else 0)
