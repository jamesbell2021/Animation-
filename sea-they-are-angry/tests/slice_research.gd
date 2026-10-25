extends SceneTree
# Run: godot --headless --path sea-they-are-angry --script res://tests/slice_research.gd
# Research at the camp's desk, the internees' notes, what the research does, and the new
# defences: barbed wire, tripwire flares, sandbag walls, and the holm's defence posts.

var fails := 0
# The camp's and the research's classes are only reached through the scene and load(),
# never named here: `--script` compiles what a test names before the autoloads exist,
# which can leave it unusable.
const PLANTED := 1
const BARE := 0

func check(c: bool, w: String) -> void:
	print(("PASS  " if c else "FAIL  ") + w)
	if not c:
		fails += 1

func _init() -> void:
	_go.call_deferred()

func _wait(frames: int) -> void:
	for i in frames:
		await physics_frame

func _bloated(main, at: Vector3):
	var b = load("res://scenes/enemies/bloated.gd").new()
	b.lighthouse = main.lighthouse
	b.position = at
	main.get_node("Enemies").add_child(b)
	return b

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
	var Cyc = root.get_node("Cycle")
	var Stk = root.get_node("Stock")
	var Run = root.get_node("Run")
	var Ev = root.get_node("Events")
	var p: Player = main.player
	p.camera = null
	Cyc.running = false

	# ---- the internees' notes ----
	var notes := []
	for n in get_nodes_in_group("interactable"):
		if n is ScavengePoint and n.kind == "notes":
			notes.append(n)
	check(notes.size() == 2, "two tins of the internees' papers lie about the camp (%d)" % notes.size())
	check(notes.size() > 0 and Terrain.in_camp(notes[0].global_position.x, notes[0].global_position.z), "inside the wire")
	var read := []
	var on_lore := func(t: String) -> void: read.append(t)
	Ev.lore.connect(on_lore)
	Stk.set_all({})
	check(notes[0].interact_prompt().contains("papers"), "the prompt: " + notes[0].interact_prompt())
	notes[0].interact(p)
	await _wait(2)
	check(Stk.get_amount("notes") == 1 and Run.notes_found == 1, "picking them up gives a page of notes")
	check(read.size() == 1 and read[0].begins_with("September 1940"), "and the first page is read out: " + (read[0].substr(0, 40) if read.size() > 0 else "(none)"))
	notes[1].interact(p)
	await _wait(2)
	check(read.size() == 2 and read[1] != read[0], "the next find is the next page")
	Ev.lore.disconnect(on_lore)

	# ---- the desk ----
	var desk = main.camp.desk
	check(desk != null and Terrain.in_camp(desk.global_position.x, desk.global_position.z), "a research desk in the camp's mess")
	Stk.set_all({})
	var rows: Array = desk.menu_rows()
	var any_on := false
	for r in rows:
		any_on = any_on or r["enabled"]
	check(rows.size() == 9 and not any_on, "nine projects, none affordable with an empty store")
	Stk.set_all({"scrap": 6, "notes": 2})
	rows = desk.menu_rows()
	check(rows[0]["enabled"] and rows[0]["text"].begins_with("Clockwork tracking"), "tracking can be started: " + rows[0]["text"].substr(0, 50))
	rows[0]["do"].call()
	check(Run.researching == "tracking" and Stk.get_amount("scrap") == 3 and Stk.get_amount("notes") == 1, "starting it pays 3 scrap and a page")
	rows = desk.menu_rows()
	check(not rows[2]["enabled"], "one project at a time")
	check(desk.interact_prompt().contains("Clockwork tracking"), "the desk says what's being worked on")
	Cyc._enter(Cyc.Phase.DAWN)
	Cyc.running = false
	await _wait(2)
	check(Run.research.has("tracking") and Run.researching == "", "done by dawn")
	var lying := 0
	for n in get_nodes_in_group("interactable"):
		if n is ScavengePoint and n.kind == "notes" and not n.is_queued_for_deletion():
			lying += 1
	check(lying == 1, "and another tin of papers has turned up (%d)" % lying)
	Cyc._enter(Cyc.Phase.DAY)
	Cyc.running = false

	# ---- the searchlights: tracking, reflectors; the governor ----
	Cyc._enter(Cyc.Phase.DUSK)
	Cyc.running = false
	await _wait(10)
	var gen = main.camp.generator
	gen.fuel = 100.0
	var sl = main.camp.searchlights[1]
	var out := Vector3(-sin(sl.home_yaw), 0.0, -cos(sl.home_yaw))
	var at: Vector3 = sl.global_position + out * 7.0
	at.y = maxf(Terrain.height_at(at.x, at.z), Terrain.SEA_LEVEL)
	var bl = _bloated(main, at)
	await _wait(2)
	bl.speed = 0.0
	var hp0: int = bl.hp
	await _wait(150)
	check(sl.tracked == bl and sl.mode == Lamp.Mode.FOCUSED, "nobody on it, a tracking searchlight fixes on what comes near and narrows")
	check(not is_instance_valid(bl) or bl.hp < hp0, "and burns it (hp %d -> %d)" % [hp0, bl.hp if is_instance_valid(bl) else 0])
	var r0: float = sl._light.spot_range
	Run.research.append("reflectors")
	await _wait(3)
	check(sl._light.spot_range > r0 + 4.0, "silvered reflectors reach further (%.1f -> %.1f m)" % [r0, sl._light.spot_range])
	if is_instance_valid(bl):
		bl.queue_free()
	await _wait(3)
	var d0: float = gen.draw_total()
	Run.research.append("governor")
	check(absf(gen.draw_total() - d0 * 0.67) < 0.01, "the governor cuts the generator's draw by a third (%.3f -> %.3f)" % [d0, gen.draw_total()])
	Cyc._enter(Cyc.Phase.DAY)
	Cyc.running = false

	# ---- the crops: cold frames and tinning ----
	var glass = main.camp.plots[3]
	var bed = main.camp.plots[0]
	check(glass.yield_food() == 3, "the greenhouse gives 3")
	Run.research.append("cloches")
	check(glass.yield_food() == 5, "with cold frames, 5")
	var flat := 0
	for i in 12:
		Run.camp_crops[0] = PLANTED
		Run.weather_for = Run.night
		Run.weather_kind = Weather.Kind.STORM
		bed._on_phase(Cyc.Phase.DAWN)
		if bed.state() == BARE:
			flat += 1
	check(flat == 0, "and the beds come through storms")
	Run.weather_kind = Weather.Kind.CLEAR
	var gplot = null
	for n in get_nodes_in_group("interactable"):
		if n.get_script() != null and n.get_script().get_global_name() == "GardenPlot":
			gplot = n
	var g0: int = gplot.yield_food()
	Run.research.append("rations")
	check(glass.yield_food() == 6 and bed.yield_food() == 3 and gplot.yield_food() == g0 + 1, "tinning puts a food more by from every harvest")

	# ---- the holm's defence posts ----
	var posts := []
	var beach_slot = null
	for s in get_nodes_in_group("trap_slots"):
		if s.holm:
			posts.append(s)
		elif s.index == 0:
			beach_slot = s
	var open := 0
	for s in posts:
		if s.unlocked and Terrain.on_holm(s.global_position.x, s.global_position.z) or s.unlocked and Terrain.holm_beach_weight(s.global_position.x, s.global_position.z) > 0.0:
			open += 1
	check(posts.size() == 4 and open == 4, "four defence posts on the holm, open from the start (%d of %d)" % [open, posts.size()])
	p.global_position = posts[2].global_position + Vector3(0.0, 0.1, 0.3)
	await _wait(3)
	check(p.interact_prompt().contains("defence post"), "at a post: " + p.interact_prompt())

	# ---- barbed wire ----
	Run.research.erase("wire")
	var kinds := []
	for r in beach_slot.menu_rows():
		kinds.append(r["text"].split(" (")[0])
	check(not kinds.has("Barbed wire"), "no wire until it's worked out")
	Run.research.append_array(["wire", "tripwire", "sandbags"])
	kinds = []
	for r in beach_slot.menu_rows():
		kinds.append(r["text"].split(" (")[0])
	check(kinds.has("Barbed wire") and kinds.has("Tripwire flare") and kinds.has("Sandbag wall"), "then wire, tripwires and sandbags: %s" % str(kinds))
	check(posts[0].can_set("sandbags") and not posts[2].can_set("sandbags"), "a wall can go up a holm beach, not across the gate")
	Stk.set_all({"scrap": 4, "driftwood": 6, "bio": 2, "seaweed": 2})
	beach_slot.arm("wire")
	check(beach_slot.kind == "wire" and Stk.get_amount("scrap") == 3, "wire strung for a scrap and a driftwood")
	p.global_position = main.lighthouse.global_position + Vector3(0.0, 0.1, 4.0)
	var wb = _bloated(main, beach_slot.global_position)
	for i in 200:
		await physics_frame
		if wb.state == &"Approach":
			break
	await _wait(2)
	var slow: float = Vector2(wb.velocity.x, wb.velocity.z).length()
	var whp: int = wb.hp
	await _wait(60)
	check(slow < wb.speed * 0.5, "in the wire it crawls (%.2f of %.2f m/s)" % [slow, wb.speed])
	check(wb.hp < whp, "and the wire cuts it (hp %d -> %d)" % [whp, wb.hp])
	wb.queue_free()
	beach_slot._spend_all()
	await _wait(2)

	# ---- tripwire ----
	beach_slot.arm("tripwire")
	var tb = _bloated(main, beach_slot.global_position + Vector3(0.3, 0.0, 0.0))
	var flared := false
	for i in 240:
		await physics_frame
		for n in main.get_children():
			if n.get_script() != null and n.get_script().get_global_name() == "Flare":
				flared = true
		if flared:
			break
	check(flared and beach_slot.kind == "", "a creature trips the wire: a flare goes off into it, and the tripwire's spent")
	await _wait(60)
	check(not is_instance_valid(tb) or tb.hp < 60, "the flare hurts it")
	if is_instance_valid(tb):
		tb.queue_free()
	await _wait(2)

	# ---- sandbags ----
	beach_slot.arm("sandbags")
	var wall = beach_slot.wall
	check(wall != null and wall.is_in_group("barricades") and beach_slot.kind == "sandbags" and Stk.get_amount("seaweed") == 1, "a sandbag wall goes up across the beach")
	var along: Vector3 = Vector3(sin(wall.rotation.y), 0.0, cos(wall.rotation.y))
	check(absf(along.dot(beach_slot.path_dir)) > 0.95, "across the path, not along it")
	var sb = _bloated(main, Terrain.beach_point(0, 0.2))
	var attacked := false
	for i in 900:
		await physics_frame
		if is_instance_valid(sb) and sb.state == &"AttackFence" and sb.attack_target == wall:
			attacked = true
			break
	check(attacked, "a creature coming up the beach stops to batter the wall")
	await _wait(200)
	check(wall.hp < wall.max_hp, "and it takes the beating (%d/%d)" % [wall.hp, wall.max_hp])
	wall.take_damage(999)
	await _wait(2)
	check(beach_slot.kind == "" and wall.is_destroyed(), "battered down, the post is clear for another")
	if is_instance_valid(sb):
		sb.queue_free()

	# ---- saved ----
	Run.researching = "bell"
	root.get_node("SaveSys").save_run()
	var d: Dictionary = root.get_node("SaveSys").load_run()
	check(d["research"].has("governor") and d["researching"] == "bell" and int(d["notes_found"]) == 2, "research and the notes found are saved")

	pl.helpers = true
	print("\n%s" % ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails > 0 else 0)
