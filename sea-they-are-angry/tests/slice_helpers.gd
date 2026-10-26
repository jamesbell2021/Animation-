extends SceneTree
# Run: godot --headless --path sea-they-are-angry --script res://tests/slice_helpers.gd
# The helper keepers and the shed's weapons: the lighthouse keeper takes the shotgun off
# the wall and a person can take it back; a longbow made for a helper; a helper fires
# the shotgun at something close and looses arrows at something further off.

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

func _bloated(main, at: Vector3):
	var b = load("res://scenes/enemies/bloated.gd").new()
	b.lighthouse = main.lighthouse
	b.position = at
	main.get_node("Enemies").add_child(b)
	return b

func _clear() -> void:
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	await _wait(2)

func _go() -> void:
	if FileAccess.file_exists("user://run.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://run.json"))
	var pl = root.get_node("Players")
	pl.wanted = 1
	pl.helpers = true
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
	var p: Player = main.player
	p.camera = null
	Cyc.running = false
	main.spawner.process_mode = Node.PROCESS_MODE_DISABLED
	var h: Player = main.players[1]
	check(h.ai and h.get_node("KeeperAI").role == "light", "keeper two is the computer's lighthouse keeper")
	Stk.set_all({"driftwood": 10, "scrap": 6, "seaweed": 4, "bio": 4, "shells": 10, "poison": 4, "arrows": 10})
	var shed = null
	for s in get_nodes_in_group("structures"):
		if s.get_script().get_global_name() == "Shed":
			shed = s

	# The shotgun on the wall, cartridges in the box: the helper goes and takes it.
	h.global_position = shed.global_position + Vector3(2.5, 0.2, -2.5)
	h.global_position.y = Terrain.height_at(h.global_position.x, h.global_position.z) + 0.2
	for i in 600:
		if h.arsenal.carries("shotgun"):
			break
		await physics_frame
	check(h.arsenal.carries("shotgun") and h.arsenal.weapon == "hook", "the helper takes the shotgun off the wall (the boathook in hand till there's a fight)")
	var rows: Array = shed.menu_rows(p)
	var back = null
	for r in rows:
		if r["text"].begins_with("Take the shotgun back"):
			back = r
	check(back != null, "the workbench offers to take it back from %s" % h.keeper_name())
	back["do"].call()
	check(p.arsenal.carries("shotgun") and not h.arsenal.carries("shotgun"), "taken back: the person has it")
	await _wait(60)
	check(not h.arsenal.carries("shotgun"), "the helper doesn't take it off a person")
	p.arsenal.take_away("shotgun")

	# A longbow for the helper, once the person has their own.
	rows = shed.menu_rows(p)
	var for_h := false
	for r in rows:
		for_h = for_h or r["text"].begins_with("Make a longbow for")
	check(not for_h, "no bow for a helper until the person has one")
	shed.make_bow(p)
	rows = shed.menu_rows(p)
	for r in rows:
		if r["text"] .begins_with("Make a longbow for %s" % h.keeper_name()):
			r["do"].call()
	check(h.arsenal.carries("bow") and Stk.get_amount("driftwood") == 4, "a longbow made for %s (another 3 driftwood)" % h.keeper_name())

	# A fight: the shotgun at close range. (It took the shotgun back off the wall by now.)
	for i in 600:
		if h.arsenal.carries("shotgun"):
			break
		await physics_frame
	check(h.arsenal.carries("shotgun"), "with the shotgun back on the wall, the helper has it again")
	var spot := Terrain.at_angle(-18.0, 10.5)
	h.global_position = spot + Vector3(0.0, 0.3, 0.0)
	p.global_position = Terrain.at_angle(150.0, 9.0) + Vector3(0.0, 0.5, 0.0)
	await _wait(10)
	var at: Vector3 = spot + Vector3(4.5, 0.0, 0.0)
	at.y = Terrain.height_at(at.x, at.z) + 0.3
	var shells_before: int = Stk.get_amount("shells") + Run.barrels
	var b = _bloated(main, at)
	b.state = &"Approach"
	var hp0: int = b.hp
	var fired := false
	for i in 300:
		if not is_instance_valid(b) or b.hp < hp0:
			fired = true
			break
		await physics_frame
	check(fired and Stk.get_amount("shells") + Run.barrels < shells_before, "a creature close: the helper fires the shotgun")
	check(h.arsenal.weapon == "shotgun", "shotgun in hand")
	await _clear()

	# Further off, without the shotgun: the bow.
	h.arsenal.take_away("shotgun")
	Stk.set_amount("shells", 0)
	Run.barrels = 0
	h.global_position = spot + Vector3(0.0, 0.3, 0.0)
	await _wait(10)
	var arrows0: int = Stk.get_amount("arrows")
	at = spot + Vector3(5.5, 0.0, 1.0)
	at.y = Terrain.height_at(at.x, at.z) + 0.3
	b = _bloated(main, at)
	b.state = &"Approach"
	hp0 = b.hp
	var loosed := false
	for i in 400:
		if Stk.get_amount("arrows") < arrows0:
			loosed = true
			break
		await physics_frame
	check(loosed and h.arsenal.weapon == "bow", "something past the boathook's reach: the helper draws and looses an arrow")
	var hit := false
	for i in 200:
		if not is_instance_valid(b) or b.hp < hp0:
			hit = true
			break
		await physics_frame
	check(hit, "the arrow finds it")
	await _clear()

	print("\n%s" % ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails > 0 else 0)
