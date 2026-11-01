extends SceneTree
# Run: godot --headless --path sea-they-are-angry --script res://tests/slice_hud.gd
# The HUD's sea mood line (the hidden Anger in words) and the red pulse round the
# screen when the light is in danger.

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
	pl.helpers = false
	change_scene_to_file("res://scenes/main.tscn")
	for i in 600:
		if current_scene != null and current_scene.get("player") != null and current_scene.player != null:
			break
		await process_frame
	await _wait(5)
	var main = current_scene
	var hud = main.hud
	var Ang = root.get_node("Anger")
	root.get_node("Cycle").running = false
	main.spawner.process_mode = Node.PROCESS_MODE_DISABLED
	var words := []
	for v in [0, 4, 7, 10]:
		Ang.value = v
		await process_frame
		await process_frame
		words.append(hud._mood_label.text)
	print("   moods: ", words)
	check(words == ["The sea is quiet.", "The sea is restless.", "The sea is angry.", "The sea wants the light."], "the sea's mood follows its anger")
	Ang.value = 0
	await process_frame
	check(not hud._danger.visible, "all well: no danger pulse")
	main.lighthouse.hp = int(main.lighthouse.max_hp * 0.2)
	await process_frame
	await process_frame
	var a: float = hud._danger_mat.get_shader_parameter("strength")
	check(hud._danger.visible and a > 0.1, "the lighthouse badly hurt: the screen's edge pulses red (%.2f)" % a)
	var lo := 9.0
	var hi := 0.0
	for i in 70:
		await process_frame
		var v: float = hud._danger_mat.get_shader_parameter("strength")
		lo = minf(lo, v)
		hi = maxf(hi, v)
	check(hi - lo > 0.25, "and it beats (%.2f to %.2f)" % [lo, hi])
	main.lighthouse.hp = main.lighthouse.max_hp
	main.lighthouse.lamp._set_state(main.lighthouse.lamp.State.GUTTERING)
	await process_frame
	await process_frame
	check(hud._danger.visible, "the lamp guttering: it pulses too")
	main.lighthouse.lamp._set_state(main.lighthouse.lamp.State.BURNING)
	await process_frame
	await process_frame
	check(not hud._danger.visible, "burning again: it stops")
	# The debug overlay (a debug build, as tests are): F10 and the testing keys.
	var dbg = null
	for c in main.get_children():
		if c.get_script() != null and c.get_script().resource_path.ends_with("debug_overlay.gd"):
			dbg = c
	check(dbg != null, "debug builds have the F10 overlay")
	var Stk = root.get_node("Stock")
	var wood: int = Stk.get_amount("driftwood")
	var fuel: float = main.lighthouse.lamp.fuel
	main.lighthouse.lamp.fuel = 50.0
	for key in [KEY_F10, KEY_F7, KEY_F6]:
		var ev := InputEventKey.new()
		ev.keycode = key
		ev.pressed = true
		Input.parse_input_event(ev)
		await process_frame
		await process_frame
	check(dbg._panel.visible and dbg.report().contains("Anger") and dbg.report().contains("spawn queue"), "F10 shows the numbers behind the run")
	check(Stk.get_amount("driftwood") == wood + 5 and main.lighthouse.lamp.fuel > 59.0, "F7 stocks the store, F6 tops up the lamp")
	print("\n%s" % ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails > 0 else 0)
