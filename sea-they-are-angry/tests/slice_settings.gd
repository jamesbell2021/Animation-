extends SceneTree
# Run: godot --headless --path sea-they-are-angry --script res://tests/slice_settings.gd
# The settings: volumes, graphics quality and render scale, keeper one's keys (changed,
# swapped, saved, put back, named in the game's text), the menu's rebinding, and a pad
# for keeper one when they play alone.

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

func _has_key(action: String, key: Key) -> bool:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey and ev.keycode == key:
			return true
	return false

func _has_pad(action: String) -> bool:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
			return true
	return false

func _key(k: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.pressed = true
	Input.parse_input_event(ev)

func _go() -> void:
	if FileAccess.file_exists("user://run.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://run.json"))
	var St = root.get_node("Settings")
	var Inp = root.get_node("InputSetup")
	var pl = root.get_node("Players")
	St.reset_controls()

	# Keys.
	check(St.key_name("interact") == "E" and St.key_name("attack") == "Left mouse", "defaults: E to use, left mouse to swing")
	check(St.keys_in("[E] Repair the fence") == "[E] Repair the fence", "the default key's hint is left alone")
	St.rebind("interact", "key:%d" % KEY_G)
	check(_has_key("interact", KEY_G) and not _has_key("interact", KEY_E), "use moved to G: on G, off E")
	check(St.keys_in("[E] Repair the fence") == "[G] Repair the fence", "hints name the new key")
	St.rebind("interact", "key:%d" % KEY_R)
	check(_has_key("interact", KEY_R) and _has_key("operate", KEY_G) and not _has_key("operate", KEY_R), "use onto the lamp's R: the lamp takes G (they swap)")
	St.rebind("weapon_next", "key:%d" % KEY_V)
	var wheel := false
	for ev in InputMap.action_get_events("weapon_next"):
		wheel = wheel or ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_WHEEL_DOWN
	check(_has_key("weapon_next", KEY_V) and not _has_key("weapon_next", KEY_TAB) and wheel, "next weapon onto V keeps the wheel too")
	St.save()
	var fresh = load("res://autoload/settings.gd").new()
	fresh._defaults = St._defaults.duplicate()
	fresh._load()
	check(fresh.binds.get("interact", "") == "key:%d" % KEY_R and fresh.binds.get("operate", "") == "key:%d" % KEY_G, "the keys are saved and read back")
	fresh.free()
	St.reset_controls()
	check(_has_key("interact", KEY_E) and _has_key("operate", KEY_R) and _has_key("weapon_next", KEY_TAB) and St.binds.is_empty(), "put back: E, R and Tab again")

	# Sound.
	St.set_volume("Music", 0.5)
	var db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))
	check(absf(db - linear_to_db(0.5)) < 0.05, "music at half: %.1f dB" % db)
	St.set_volume("SFX", 0.0)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")), "sounds at nothing: muted")
	St.set_volume("SFX", 1.0)
	St.set_volume("Music", 0.8)

	# The game: graphics on the real sky and sun, a pad for keeper one.
	pl.wanted = 1
	pl.helpers = false
	change_scene_to_file("res://scenes/main.tscn")
	for i in 600:
		if current_scene != null and current_scene.get("player") != null and current_scene.player != null:
			break
		await process_frame
	await _wait(3)
	var main = current_scene
	root.get_node("Cycle").running = false
	check(St.env == main._env and St.sun == main._sun, "main hands its sky and sun to the settings")
	St.quality = 0
	St.scale_idx = 0
	St.apply_graphics()
	check(not main._env.ssao_enabled and not main._env.ssr_enabled and main._sun.directional_shadow_max_distance < 50.0, "low: no ambient shadows or reflections, short sun shadows")
	check(is_equal_approx(root.scaling_3d_scale, 0.5) and root.scaling_3d_mode == Viewport.SCALING_3D_MODE_FSR, "half render scale, sharpened")
	var views := get_nodes_in_group("game_views")
	check(views.size() > 0 and is_equal_approx((views[0] as Viewport).scaling_3d_scale, 0.5), "the split-screen views follow")
	St.quality = 2
	St.scale_idx = St.SCALES.size() - 1
	St.apply_graphics()
	check(main._env.ssao_enabled and main._env.ssr_enabled and is_equal_approx(root.scaling_3d_scale, 1.0), "high, full scale: all back on")

	check(_has_pad("interact") and _has_pad("move_left") and _has_pad("aim_right"), "playing alone: a pad works for keeper one")
	var p: Player = main.player
	var stick := InputEventJoypadMotion.new()
	stick.device = 0
	stick.axis = JOY_AXIS_RIGHT_X
	stick.axis_value = 1.0
	Input.parse_input_event(stick)
	# Input events reach the game on the next drawn frame.
	for f in 3:
		await process_frame
	await _wait(3)
	check(Inp.pad_active, "the stick pushed: keeper one is on the pad")
	check(p.aim_dir().dot(Vector3.RIGHT) > 0.95, "the right stick aims: %s" % p.aim_dir())
	check(St.keys_in("[E] Repair the fence") == "[A] Repair the fence", "on the pad the hints name its buttons")
	stick.axis_value = 0.0
	Input.parse_input_event(stick)
	var mm := InputEventMouseMotion.new()
	mm.relative = Vector2(30, 0)
	mm.position = Vector2(400, 300)
	Input.parse_input_event(mm)
	await _wait(2)
	check(not Inp.pad_active, "the mouse moved: back on the mouse")
	pl.configure(2)
	check(not _has_pad("interact"), "two keepers on one screen: the pads go to keeper two")
	pl.configure(1)

	# The menu: pick a control, press a key.
	var menu = load("res://scenes/ui/settings_menu.gd").new()
	root.add_child(menu)
	await _wait(2)
	menu._listen("sprint")
	await process_frame
	await process_frame
	_key(KEY_1)
	await process_frame
	check(menu._listening == "sprint", "a weapon's number key isn't taken")
	_key(KEY_K)
	await process_frame
	check(St.key_name("sprint") == "K" and _has_key("sprint", KEY_K) and menu._listening == "", "the menu: sprint onto K")
	menu._listen("flare")
	await process_frame
	await process_frame
	_key(KEY_ESCAPE)
	await process_frame
	check(St.key_name("flare") == "Right mouse" and is_instance_valid(menu), "Esc leaves a control as it was, menu still open")
	menu._close()
	await process_frame
	var cf := ConfigFile.new()
	check(cf.load("user://settings.cfg") == OK and cf.get_value("controls", "sprint", "") == "key:%d" % KEY_K, "closing the menu saves")
	St.reset_controls()
	St.save()

	print("ALL PASS" if fails == 0 else "FAILED: %d" % fails)
	quit(fails)
