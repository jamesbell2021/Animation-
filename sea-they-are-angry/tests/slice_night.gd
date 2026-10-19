extends SceneTree
# Run: godot --headless --path sea-they-are-angry --script res://tests/slice_night.gd  (overwrites user://run.json)
var fails := 0
func check(c: bool, w: String) -> void:
	print(("PASS  " if c else "FAIL  ") + w)
	if not c:
		fails += 1
func _init() -> void:
	_go.call_deferred()
func _go() -> void:
	var f := FileAccess.open("user://run.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"night": 3, "anger": 4, "stock": {"driftwood": 9, "scrap": 2, "seaweed": 0, "bio": 5}, "fuel": 61.5}))
	f = null
	change_scene_to_file("res://scenes/main.tscn")
	# Scene swaps happen at frame end; wait until the keeper actually exists.
	for i in 600:
		if current_scene != null and current_scene.get("player") != null:
			break
		await process_frame
	for i in 3:
		await physics_frame
	var main = current_scene
	var Run = root.get_node("Run")
	var Cycle = root.get_node("Cycle")
	var Stock = root.get_node("Stock")
	var Anger = root.get_node("Anger")
	check(Run.night == 3 and Stock.get_amount("driftwood") == 9 and Stock.get_amount("bio") == 5 and Anger.value == 4, "relaunch resumes night 3 with saved stock and anger")
	check(is_equal_approx(main.lighthouse.lamp.fuel, 61.5), "saved fuel restored")
	var table: Array = main.spawner.night_table(3)
	check(table.size() == 4 and int(table[0]["count"]) == 4, "night 3 table with anger 4 adds +1 per group: %s" % str(table.map(func(e): return e["count"])))
	var t9: Array = main.spawner.night_table(9)
	check(t9.size() == 5 and int(t9[0]["count"]) == 3 + 2 + 1, "night 9 uses night 4 pattern +2, +1 anger")
	# Keep the keeper out of the way and the lamp fuelled, then run a night fast.
	main.player.global_position = Vector3(-2.6, Terrain.height_at(-2.6, 2.2) + 0.15, 2.2)
	Run.night = 1
	Anger.set_value(0)
	Cycle._enter(Cycle.Phase.NIGHT)
	main.lighthouse.lamp._set_state(Lamp.State.BURNING)
	main.lighthouse.lamp.fuel = 100.0
	var waves := [0]
	main.spawner.wave_incoming.connect(func(_p, _c): waves[0] += 1)
	var compass_ok: bool = main.compass(Vector3(0, 0, -10)) == "north" and main.compass(Vector3(10, 0, 0)) == "east" and main.compass(Vector3(0, 0, 10)) == "south" and main.compass(Vector3(-7, 0, -7)) == "north-west"
	check(compass_ok, "compass directions match the camera (north is up-screen)")
	Engine.time_scale = 20.0
	var seen := 0
	while Cycle.phase == Cycle.Phase.NIGHT and Run.active:
		seen = maxi(seen, get_nodes_in_group("enemies").size())
		main.lighthouse.lamp.fuel = 100.0
		await physics_frame
	var killed_or_present := seen
	print("   max enemies alive at once during night 1: ", seen, "   run active ", Run.active, "  lighthouse hp ", main.lighthouse.hp)
	check(seen >= 2, "enemies spawn during the night")
	check(waves[0] == 3, "a foghorn warning for each of night 1's three waves (%d)" % waves[0])
	check(Cycle.phase == Cycle.Phase.DAWN, "night ends in dawn")
	var retreating := 0
	for e in get_nodes_in_group("enemies"):
		if e.state == &"Retreat":
			retreating += 1
	print("   at dawn: ", get_nodes_in_group("enemies").size(), " enemies, ", retreating, " retreating")
	# Back down the ledge and out by the nearest beach: up to ~60 m of walking.
	for i in 4000:
		if get_nodes_in_group("enemies").is_empty():
			break
		await physics_frame
	check(get_nodes_in_group("enemies").size() == 0, "survivors walk back to the sea and despawn")
	Engine.time_scale = 1.0
	print("RESULT: ", "PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit()
