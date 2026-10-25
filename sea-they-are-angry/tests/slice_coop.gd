extends SceneTree
# Run: godot --headless --path sea-they-are-angry --script res://tests/slice_coop.gd
# Three-keeper co-op: spawning, scaled waves, downed and revive, lanterns, lamp operator rule.

var fails := 0

func check(c: bool, w: String) -> void:
	print(("PASS  " if c else "FAIL  ") + w)
	if not c:
		fails += 1

func _init() -> void:
	_go.call_deferred()

func _go() -> void:
	if FileAccess.file_exists("user://run.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://run.json"))
	var players_al = root.get_node("Players")
	players_al.wanted = 3
	# Every keeper here is scripted: no helpers.
	root.get_node("Players").helpers = false
	change_scene_to_file("res://scenes/main.tscn")
	for i in 600:
		if current_scene != null and current_scene.get("player") != null:
			break
		await process_frame
	for i in 3:
		await physics_frame
	var main = current_scene
	var Run = root.get_node("Run")
	var Cycle = root.get_node("Cycle")
	check(main.players.size() == 3 and players_al.count() == 3, "three keepers spawn")
	var names: Array = main.players.map(func(p): return p.keeper_name())
	check(names == ["Callum", "Hamish", "Mairi"], "keepers are %s" % str(names))
	check(players_al.devices.size() == 3, "devices assigned: %s" % str(players_al.devices))
	check(InputMap.has_action("p1_attack") and InputMap.has_action("p2_move_left"), "per-player actions exist")
	# Wave scaling: a group of 2 becomes 4 with three keepers (x2).
	main.spawner._pending.clear()
	main.spawner._queue_group({"t": 0.1, "count": 2, "point": 0})
	check(main.spawner._pending.size() == 4, "group of 2 scales to %d for three keepers" % main.spawner._pending.size())
	main.spawner._pending.clear()
	# Lanterns light at dusk.
	Cycle._enter(Cycle.Phase.DUSK)
	await physics_frame
	check(main.players[1]._lantern_light.visible, "lanterns light at dusk")
	# Lamp: one operator at a time.
	var p0 = main.players[0]
	var p1 = main.players[1]
	var p2 = main.players[2]
	for p in [p0, p1]:
		p.global_position = Vector3(0.0, Terrain.height_at(0.0, 3.0) + 0.15, 3.0)
	await physics_frame
	p0._toggle_operate()
	p1._toggle_operate()
	check(p0.operating and not p1.operating and main.lighthouse.lamp.operator == p0, "second keeper is turned away from the lamp")
	p0._toggle_operate()
	# Downed and revived by a teammate.
	p1.take_damage(500)
	check(p1.downed and Run.active, "a fallen keeper goes down; the run continues")
	p0.global_position = p1.global_position + Vector3(0.6, 0.2, 0.0)
	await physics_frame
	Input.action_press("interact")
	for i in 200:
		if not p1.downed:
			break
		# The downed keeper's ragdoll can slide a little: stay beside them.
		p0.global_position = p1.global_position + Vector3(0.6, 0.2, 0.0)
		await physics_frame
	Input.action_release("interact")
	check(not p1.downed and p1.hp == 40, "holding interact beside them revives at 40%% hp (hp %d)" % p1.hp)
	# Everyone down ends the run.
	var ended := [""]
	root.get_node("Events").run_ended.connect(func(r, _n): ended[0] = r)
	for p in [p0, p1, p2]:
		p.take_damage(500)
	check(ended[0] == "Every keeper is down.", "all three down ends the run: '%s'" % ended[0])
	print("RESULT: ", "PASS" if fails == 0 else "FAIL (%d)" % fails)
	players_al.wanted = 1
	quit()
