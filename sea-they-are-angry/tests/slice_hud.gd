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

	# The layout: a card per keeper with bars, the store in words players use, and the
	# jobs list inside the screen.
	root.get_node("Stock").set_amount("seaweed", 7)
	root.get_node("Stock").set_amount("arrows", 0)
	await process_frame
	await process_frame
	check(hud._cards.size() == main.players.size() and hud._cards[0]["bars"]["hp"].value == main.player.hp, "a card for each keeper (%d), health as a bar" % hud._cards.size())
	check(hud._stock_label.text.contains("Kelp 7") and not hud._stock_label.text.contains("Arrows"), "the store: " + hud._stock_label.text)
	var vp: Vector2 = hud._jobs_panel.get_viewport_rect().size
	var jr: Rect2 = hud._jobs_panel.get_global_rect()
	check(hud._jobs_panel.visible and jr.position.x >= 0.0 and jr.end.x <= vp.x + 0.5, "the jobs list sits inside the screen (%.0f..%.0f of %.0f)" % [jr.position.x, jr.end.x, vp.x])
	var cr: Rect2 = hud._cards[0]["panel"].get_global_rect()
	check(cr.end.y <= vp.y + 0.5 and cr.position.y > vp.y * 0.6, "the keepers' cards sit at the bottom (%.0f..%.0f)" % [cr.position.y, cr.end.y])
	check(hud._phase_label.text.begins_with("Day 1"), "the heading: " + hud._phase_label.text)
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
	# Off-screen creatures: a chevron at the edge of the screen points at them.
	var far_one = load("res://scenes/enemies/bloated.gd").new()
	far_one.lighthouse = main.lighthouse
	far_one.position = Vector3(Terrain.HOLM_C.x + 6.0, Terrain.HOLM_HEIGHT + 0.3, Terrain.HOLM_C.y)
	main.get_node("Enemies").add_child(far_one)
	far_one.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	await process_frame
	var ms: Array = hud.markers.marks
	var vr: Rect2 = hud.markers.get_viewport_rect()
	check(ms.size() == 1 and vr.grow(-10.0).has_point(ms[0][0]) and Vector2.from_angle(ms[0][1]).x > 0.3, "a creature over on the holm: a chevron at the right of the screen points to it (%s)" % [ms])
	far_one.global_position = main.player.global_position + Vector3(1.5, 0.0, 0.0)
	await process_frame
	await process_frame
	check(hud.markers.marks.is_empty(), "in view: no chevron")
	far_one.queue_free()

	# The end of a run: a summary of it, and a way back to the title.
	main.run_tally.merge({"ashore": 12, "beam": 7, "fall": 2}, true)
	var summary: String = hud.run_summary(4)
	check(summary.contains("held 3 nights") and summary.contains("12 came up out of the sea") and summary.contains("7 burned in the beam"), "the run's summary: " + summary.replace("\n", " / "))

	# How it feels: the screen shakes with a blow and settles; a heavy blow freezes the
	# world for a moment; the shake can be turned off.
	var F = root.get_node("Feel")
	var Set = root.get_node("Settings")
	F.force_live = true
	F.shake(0.6)
	await process_frame
	await process_frame
	var cam: Camera3D = main.camera_director.main_camera if main.get("camera_director") != null else get_root().get_camera_3d()
	var shook: float = absf(cam.h_offset) + absf(cam.v_offset)
	check(F.trauma > 0.3 and shook > 0.0, "a blast shakes the screen (trauma %.2f, lens %.3f)" % [F.trauma, shook])
	for i in 90:
		await process_frame
	check(F.trauma == 0.0 and absf(cam.h_offset) < 0.001, "and it settles")
	Set.shake = false
	F.shake(0.6)
	check(F.trauma == 0.0, "Settings: shake off, no shake")
	Set.shake = true
	F.hitstop(0.05)
	check(Engine.time_scale < 0.1, "a heavy blow: the world stops for a moment (time %.2f)" % Engine.time_scale)
	for i in 30:
		await process_frame
	check(is_equal_approx(Engine.time_scale, 1.0), "and goes on")
	F.force_live = false

	print("\n%s" % ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails > 0 else 0)
