extends SceneTree
# Run: godot --headless --path sea-they-are-angry --script res://tests/slice_rescue.gd
# The end of Chapter One: the relief boat's countdown, the last night, the boat coming
# in, everyone going aboard (the helpers too), sailing away, the chapter's card, and a run
# kept on past it.

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
	if FileAccess.file_exists("user://profile.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://profile.json"))
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
	var Run = root.get_node("Run")
	var Save = root.get_node("SaveSys")
	var p: Player = main.player
	p.camera = null
	Cyc.running = false
	var R = load("res://scenes/systems/rescue.gd")

	# ---- the countdown ----
	var nights := []
	for lv in 3:
		Run.difficulty = lv
		nights.append(R.night())
	Run.difficulty = 1
	check(nights == [8, 10, 12], "the boat comes after 8, 10 or 12 nights by the sea (%s)" % str(nights))
	Run.research.append("wireless")
	check(R.night() == 8, "two sooner with the camp's wireless mended")
	Run.research.erase("wireless")
	Run.night = 3
	check(R.nights_left() == 8 and R.countdown() == "boat in 8 nights", "night 3: %s" % R.countdown())
	Run.night = 10
	check(R.is_last_night() and R.countdown() == "the boat comes at dawn", "night 10, the last: %s" % R.countdown())
	var last: Array = main.spawner.night_table(10)
	Run.endless = true
	var plain: Array = main.spawner.night_table(10)
	Run.endless = false
	var more := 0
	for i in mini(last.size(), plain.size()):
		if int(last[i]["count"]) > int(plain[i]["count"]):
			more += 1
	check(more == last.size(), "the last night's landings are all bigger")

	# ---- the boat comes in ----
	Cyc._enter(Cyc.Phase.DAWN)
	Cyc.running = false
	await _wait(3)
	var boat = main.boat
	check(boat != null and main._rescue, "the dawn after the last night: the relief boat")
	check(Run.night == 11 and not Cyc.running, "the dawn holds while she comes in")
	Engine.time_scale = 4.0
	check(await _until(func(): return boat.waiting, 1200), "she lies off the east beach, the plank out")
	check(Terrain.beach_weight(boat.shore.x, boat.shore.z) > 0.3 and boat.shore.y > Terrain.SEA_LEVEL, "its end on the shingle, above the water")
	# The keeper walks down to her and goes aboard.
	p.global_position = boat.shore + Vector3(0.0, 0.2, 0.0)
	await _wait(4)
	check(p.interact_prompt().contains("aboard"), "at the plank: " + p.interact_prompt())
	Input.action_press("interact")
	await _wait(2)
	Input.action_release("interact")
	await _wait(2)
	check(p.boarded and not p.visible, "aboard")
	# The helpers come down from the light and the camp, and board.
	check(await _until(func(): return main.players[1].boarded and main.players[2].boarded, 3600), "the helpers make their own way down and aboard (%s, %s)" % [main.players[1].boarded, main.players[2].boarded])
	check(await _until(func(): return not boat.waiting, 120), "everyone aboard: she sails")
	check(await _until(func(): return main._cine != null and main._cine.current, 60), "the camera watches her away")
	check(await _until(func(): return not Run.active, 1800), "and the chapter ends")
	Engine.time_scale = 1.0
	var card = null
	for c in main.get_children():
		if c is CanvasLayer and c.has_signal("stay_on"):
			card = c
	check(card != null, "Chapter One's card")
	check(Save.chapter_done(1), "the chapter's marked done on the profile")

	# ---- a run kept on ----
	Run.endless = true
	check(R.nights_left() == 0 and R.countdown() == "", "kept on: no boat to wait for")
	Run.active = true
	main.boat.queue_free()
	main.boat = null
	main._rescue = false
	Run.night = 20
	var b0 = main.boat
	Cyc._enter(Cyc.Phase.DAWN)
	Cyc.running = false
	await _wait(3)
	check(main.boat == b0, "and no boat comes at dawn")

	pl.helpers = true
	print("\n%s" % ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails > 0 else 0)
