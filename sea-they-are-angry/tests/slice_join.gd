extends SceneTree
## Joining a local game that's under way: by day, the first computer keeper becomes the
## newcomer's, on their device; not at night; not past three; the screen follows them.
##   godot --headless --path . --script res://tests/slice_join.gd

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
	await _wait(5)
	var main = current_scene
	var cyc = root.get_node("Cycle")
	cyc.running = false
	main.spawner.process_mode = Node.PROCESS_MODE_DISABLED
	var h: Player = main.players[1]
	check(pl.humans() == 1 and h.ai and h.get_node_or_null("KeeperAI") != null, "to begin: one person, keeper two is the computer's")

	# At night nobody can join.
	cyc._enter(cyc.Phase.NIGHT)
	cyc.running = false
	check(pl.join_blocked(pl.KEYBOARD_ARROWS).contains("by day") and pl.join(pl.KEYBOARD_ARROWS) == null and h.ai, "at night: join by day")

	# By day: Insert, the arrow keys' keeper.
	cyc._enter(cyc.Phase.DAY)
	cyc.running = false
	var ev := InputEventKey.new()
	ev.keycode = KEY_INSERT
	ev.pressed = true
	Input.parse_input_event(ev)
	await _wait(4)
	check(not h.ai and pl.wanted == 2 and pl.humans() == 2, "Insert by day: Hamish is a person's (%d people)" % pl.humans())
	await _wait(2)
	check(h.get_node_or_null("KeeperAI") == null or h.get_node("KeeperAI").is_queued_for_deletion(), "the computer's mind is gone from him")
	check(InputMap.has_action("p1_move_left") and InputMap.action_get_events("p1_move_left").size() > 0, "and the arrow keys are bound to him")
	check(main.director._people().size() == 2, "the camera follows two people now")
	check(h.hp == h.max_hp, "on full health")
	check(not pl.join_blocked(pl.KEYBOARD_ARROWS).is_empty(), "the same keys can't join twice")

	# A pad joins as the third.
	var third: Player = main.players[2]
	check(third.ai, "keeper three is still the computer's")
	var j = pl.join(0)
	check(j == third and not third.ai and pl.wanted == 3 and pl.humans() == 3, "a gamepad joins as the third")
	check(pl.join_blocked(1) != "" and pl.join(1) == null, "and there's no fourth")

	print("\n%s" % ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
	quit()
