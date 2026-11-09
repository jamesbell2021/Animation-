extends SceneTree
## A smoke test of a whole run: a lone keeper who never moves, at 20 times speed. Checks
## it boots, the lamp is lit at night, a save is written at the first dawn, creatures
## land, and the run ends within four nights with a reason (here the keeper falls: a run
## that can't be lost would show). Script errors show in the output.
##   godot --headless --path . --script res://tests/smoke.gd

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
	var pl = root.get_node("Players")
	pl.wanted = 1
	pl.helpers = false
	var run = root.get_node("Run")
	run.next_difficulty = 1
	change_scene_to_file("res://scenes/main.tscn")
	for i in 600:
		if current_scene != null and current_scene.get("player") != null and current_scene.player != null:
			break
		await process_frame
	var main = current_scene
	check(main != null and run.active, "the game boots into a run")
	var cyc = root.get_node("Cycle")
	var reason := [""]
	root.get_node("Events").run_ended.connect(func(r: String, _n: int) -> void: reason[0] = r)
	var lit := false
	var landed := false
	var saved := false
	Engine.time_scale = 20.0
	Engine.max_physics_steps_per_frame = 64
	var lamp: Lamp = main.lighthouse.lamp
	var ticks := 0
	while run.active and run.night <= 4 and ticks < 400000:
		await physics_frame
		ticks += 1
		if lamp.state == Lamp.State.BURNING:
			lit = true
		if get_nodes_in_group("enemies").size() > 0:
			landed = true
		if not saved and run.night >= 2 and FileAccess.file_exists("user://run.json"):
			saved = true
	Engine.time_scale = 1.0
	check(lit, "the lamp was lit at night")
	check(landed, "creatures came ashore")
	check(saved, "a save was written at the first dawn")
	check(not run.active and reason[0] != "" and run.night <= 4, "the run ended by night %d: \"%s\"" % [run.night, reason[0]])
	print("\n%s" % ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
	quit()
