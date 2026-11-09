extends SceneTree
## Comfort and access options, the strings table, the local play log and the F12 snapshot.
##   godot --headless --path . --script res://tests/slice_access.gd

var fails := 0

func check(c: bool, w: String) -> void:
	print(("PASS  " if c else "FAIL  ") + w)
	if not c:
		fails += 1

func _init() -> void:
	_go.call_deferred()

func _wait(frames: int) -> void:
	for i in frames:
		await process_frame

func _lines(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var out := []
	for l in FileAccess.get_file_as_string(path).split("\n"):
		if l.strip_edges() != "":
			out.append(l)
	return out

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
	root.get_node("Cycle").running = false
	main.spawner.process_mode = Node.PROCESS_MODE_DISABLED
	var St = root.get_node("Settings")
	var F = root.get_node("Feel")
	var T = root.get_node("Telemetry")
	var Ev = root.get_node("Events")

	# ---- strings ----
	var S = load("res://scenes/util/strings.gd")
	check(S.t("title.new_run") == "New Run" and S.t("title.continue", [4]) == "Continue  (night 4)" and S.t("no.such.key") == "no.such.key", "the strings table: a key, a key with a value, and an unknown key says itself")

	# ---- shake levels, hit-stop ----
	F.force_live = true
	St.shake_level = 2
	F.trauma = 0.0
	F.shake(0.5)
	var full: float = F.trauma
	St.shake_level = 1
	F.trauma = 0.0
	F.shake(0.5)
	var low: float = F.trauma
	St.shake_level = 0
	F.trauma = 0.0
	F.shake(0.5)
	check(is_equal_approx(full, 0.5) and low > 0.1 and low < full and F.trauma == 0.0, "screen shake Off, Low and Full (%.2f, %.2f, %.2f)" % [F.trauma, low, full])
	St.shake_level = 2
	St.hitstop = false
	F.hitstop(0.05)
	check(is_equal_approx(Engine.time_scale, 1.0), "hit-stop off: the world doesn't stop")
	St.hitstop = true
	F.force_live = false

	# ---- damage numbers ----
	var fx = load("res://scenes/fx/fx.gd")
	var before := get_nodes_in_group("x").size()
	var count := func() -> int:
		var n := 0
		for c in main.get_children():
			if c is Label3D:
				n += 1
		return n
	var n0: int = count.call()
	St.damage_numbers = true
	fx.damage_number(main, Vector3(0, 2, 0), 12)
	var n1: int = count.call()
	St.damage_numbers = false
	fx.damage_number(main, Vector3(0, 2, 0), 12)
	var n2: int = count.call()
	St.damage_numbers = true
	check(n1 == n0 + 1 and n2 == n1, "damage numbers float up when on, and not when off")

	# ---- reduced flashing ----
	var b = load("res://scenes/enemies/bloated.gd").new()
	b.lighthouse = main.lighthouse
	b.position = Vector3(30.0, 0.0, 30.0)
	main.get_node("Enemies").add_child(b)
	b.process_mode = Node.PROCESS_MODE_DISABLED
	St.calm_lights = true
	b.flash()
	check(b._flash_t <= 0.0, "reduced flashing: a creature doesn't flash when hit")
	St.calm_lights = false
	b.flash()
	check(b._flash_t > 0.0, "and does without it")
	b.queue_free()
	St.calm_lights = false

	# ---- palette ----
	var Pl = root.get_node("Players")
	St.palette = 0
	var usual: Color = Pl.color_of(2)
	St.palette = 1
	var safe: Color = Pl.color_of(2)
	St.palette = 0
	check(usual != safe and safe.r > 0.9 and safe.g > 0.9 and safe.b > 0.9, "the other palette gives keeper three white (not pink)")

	# ---- saved ----
	St.shake_level = 1
	St.hitstop = false
	St.damage_numbers = false
	St.calm_lights = true
	St.palette = 1
	St.ui_scale_idx = 2
	St.telemetry = true
	St.save()
	St.shake_level = 2
	St.hitstop = true
	St.damage_numbers = true
	St.calm_lights = false
	St.palette = 0
	St.ui_scale_idx = 0
	St.telemetry = false
	St._load()
	check(St.shake_level == 1 and not St.hitstop and not St.damage_numbers and St.calm_lights and St.palette == 1 and St.ui_scale_idx == 2 and St.telemetry, "the options are saved and come back")
	# Put everything back for whoever's save this is.
	St.shake_level = 2
	St.hitstop = true
	St.damage_numbers = true
	St.calm_lights = false
	St.palette = 0
	St.ui_scale_idx = 0
	St.telemetry = false
	St.save()

	# ---- the play log ----
	var tele := "user://telemetry_test.jsonl"
	if FileAccess.file_exists(tele):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tele))
	T.path = tele
	St.telemetry = false
	T.record("quiet")
	check(_lines(tele).is_empty(), "the play log is off unless asked for")
	St.telemetry = true
	T.record("probe", {"night": 2})
	Ev.run_ended.emit("The lamp went dark.", 3)
	var rows := _lines(tele)
	var j = JSON.parse_string(rows[0]) if rows.size() > 0 else null
	var k = JSON.parse_string(rows[1]) if rows.size() > 1 else null
	check(rows.size() == 2 and j != null and j["event"] == "probe" and int(j["night"]) == 2 and j.has("t"), "an event is one JSON line with its time")
	check(k != null and k["event"] == "run_end" and k["reason"] == "The lamp went dark.", "the end of a run is logged with its reason")
	St.telemetry = false

	# ---- F12 ----
	var fb := "user://feedback_test.txt"
	if FileAccess.file_exists(fb):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(fb))
	T.feedback_path = fb
	var said := [""]
	Ev.message.connect(func(t: String) -> void: said[0] = t)
	var key := InputEventKey.new()
	key.keycode = KEY_F12
	key.pressed = true
	Input.parse_input_event(key)
	await _wait(3)
	var text := FileAccess.get_file_as_string(fb) if FileAccess.file_exists(fb) else ""
	check(said[0] == "Snapshot saved" and text.contains("night") and text.contains("store") and text.contains("anger"), "F12 writes the moment to feedback.txt and says so")

	for f in [tele, fb]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	print("\n%s" % ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
	quit()
