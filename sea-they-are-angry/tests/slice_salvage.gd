extends SceneTree
# Run: godot --headless --path sea-they-are-angry --script res://tests/slice_salvage.gd
# Salvage: creatures leave bio, scrap or kelp where they fall; a keeper walking over it
# picks it up (it drifts to them); what falls in the sea washes ashore; the sea takes
# back what's left at dusk. The crab's shell scrap comes as salvage now.

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

func _salvage() -> Array:
	return get_nodes_in_group("salvage").filter(func(n): return not n.is_queued_for_deletion())

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
	await _wait(5)
	var main = current_scene
	var Cyc = root.get_node("Cycle")
	var Stk = root.get_node("Stock")
	var p: Player = main.player
	p.camera = null
	Cyc.running = false
	main.spawner.process_mode = Node.PROCESS_MODE_DISABLED
	p.global_position = Terrain.at_angle(0.0, 6.0) + Vector3(0, 0.3, 0)

	# A crab beaten to death leaves its scrap.
	var at := Terrain.at_angle(200.0, 10.5)
	var crab = load("res://scenes/enemies/crab.gd").new()
	crab.lighthouse = main.lighthouse
	crab.position = at + Vector3(0, 0.3, 0)
	main.get_node("Enemies").add_child(crab)
	await _wait(5)
	var scrap0: int = Stk.get_amount("scrap")
	crab.last_hit = "hook"
	crab.hp = 0
	crab._die()
	await _wait(5)
	var drops := _salvage()
	check(drops.size() == 1 and drops[0].kind == "scrap" and drops[0].amount == 2 and Stk.get_amount("scrap") == scrap0, "a crab beaten to death leaves 2 scrap where it fell (not in the store yet)")
	check(Geo.flat_dist(drops[0].global_position, at) < 1.5, "right where it fell")
	# Walk over to it.
	p.global_position = drops[0].global_position + Vector3(1.8, 0.3, 0.0)
	var got := false
	for i in 120:
		if Stk.get_amount("scrap") == scrap0 + 2:
			got = true
			break
		await physics_frame
	check(got and _salvage().is_empty(), "a keeper walks up: it drifts to them and into the store")

	# Dropped in the sea: it washes up.
	var sea := Terrain.at_angle(30.0, 19.0)
	sea.y = Terrain.SEA_LEVEL
	var s = load("res://scenes/systems/salvage.gd").drop(main, sea, "bio", 1)
	check(s != null and Terrain.walkable(s.global_position.x, s.global_position.z), "dropped in the sea, it washes up on firm ground")
	# Left lying till dusk: the sea takes it.
	p.global_position = Terrain.at_angle(180.0, 6.0) + Vector3(0, 0.3, 0)
	await _wait(5)
	check(_salvage().size() == 1, "it lies there by day")
	Cyc._enter(1)
	await _wait(3)
	check(_salvage().is_empty(), "the sea takes it back at dusk")
	Cyc._enter(0)

	# A squid drops bio half the time; a beam-burnt crab nothing.
	var squid_drops := 0
	for i in 20:
		var sq = load("res://scenes/enemies/squid.gd").new()
		sq.lighthouse = main.lighthouse
		sq.position = at + Vector3(0, 0.3, 0)
		main.get_node("Enemies").add_child(sq)
		await physics_frame
		sq._drop_salvage()
		sq.queue_free()
	await _wait(3)
	squid_drops = _salvage().size()
	check(squid_drops >= 3 and squid_drops <= 17, "squids leave bio about half the time (%d of 20)" % squid_drops)
	for n in _salvage():
		n.queue_free()
	var crab2 = load("res://scenes/enemies/crab.gd").new()
	crab2.lighthouse = main.lighthouse
	crab2.position = at + Vector3(0, 0.3, 0)
	main.get_node("Enemies").add_child(crab2)
	await _wait(3)
	crab2.last_hit = "beam"
	check(crab2.salvage().is_empty(), "a crab burnt to nothing leaves nothing")
	print("\n%s" % ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails > 0 else 0)
