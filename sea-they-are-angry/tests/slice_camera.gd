extends SceneTree
## The free camera, playing alone: turn it (keys, the middle mouse dragged), zoom it with
## the wheel (not too close), put it back; walking follows the way it faces; the wheel
## doesn't change weapons while it zooms. With two people on one screen it's fixed.
##   godot --headless --path . --script res://tests/slice_camera.gd

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

func _wheel(up: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
	ev.pressed = true
	ev.factor = 1.0
	Input.parse_input_event(ev)
	var off := ev.duplicate()
	off.pressed = false
	Input.parse_input_event(off)

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
	var d: CameraDirector = main.director
	var cam: Camera3D = d.main_camera
	var p: Player = main.player
	root.get_node("Cycle").running = false
	main.spawner.process_mode = Node.PROCESS_MODE_DISABLED
	await _wait(5)
	check(CameraDirector.free_on, "alone: the camera is free")
	var at0 := cam.global_position
	var look0 := -cam.global_transform.basis.z

	# Turn it with the keys.
	Input.action_press("cam_right")
	await _wait(40)
	Input.action_release("cam_right")
	await _wait(40)
	var look1 := -cam.global_transform.basis.z
	var turned := rad_to_deg(Vector2(look0.x, look0.z).angle_to(Vector2(look1.x, look1.z)))
	check(absf(turned) > 30.0, "C turns the camera round the island (%.0f°)" % turned)

	# The middle mouse dragged turns it too.
	var y0 := d.yaw_target
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_MIDDLE
	press.pressed = true
	Input.parse_input_event(press)
	var drag := InputEventMouseMotion.new()
	drag.relative = Vector2(120, 0)
	Input.parse_input_event(drag)
	var rel := press.duplicate()
	rel.pressed = false
	Input.parse_input_event(rel)
	await _wait(2)
	# (Headless the window is tiny, so the drag is scaled up: any turn will do.)
	check(absf(d.yaw_target - y0) > 0.1, "dragging with the middle button turns it")

	# Walking follows the camera: up the screen is away from it.
	await _wait(60)
	var away := -cam.global_transform.basis.z
	away.y = 0.0
	away = away.normalized()
	var from := p.global_position
	Input.action_press("move_up")
	await _wait(30)
	Input.action_release("move_up")
	var went := p.global_position - from
	went.y = 0.0
	check(went.length() > 0.5 and went.normalized().dot(away) > 0.9, "W walks away from the camera, however it's turned (dot %.2f)" % went.normalized().dot(away))

	# The wheel zooms, never too close; it doesn't change what's in hand.
	var weapon: String = p.arsenal.weapon
	var dist0 := cam.global_position.distance_to(p.global_position)
	for i in 30:
		_wheel(true)
		await _wait(1)
	await _wait(60)
	var dist1 := cam.global_position.distance_to(p.global_position)
	check(is_equal_approx(d.zoom_target, CameraDirector.ZOOM_MIN) and dist1 < dist0 * 0.6, "the wheel zooms in toward the keeper (%.1f m from %.1f)" % [dist1, dist0])
	check(dist1 > 12.0, "but not too close (%.1f m)" % dist1)
	check(p.arsenal.weapon == weapon, "and doesn't change what's in hand")
	for i in 40:
		_wheel(false)
		await _wait(1)
	check(is_equal_approx(d.zoom_target, CameraDirector.ZOOM_MAX), "out a little past the usual view, no further")

	# The = and - keys zoom too (a trackpad has no wheel).
	d.zoom_target = 1.0
	Input.action_press("cam_zoom_in")
	await _wait(30)
	Input.action_release("cam_zoom_in")
	check(d.zoom_target < 0.9, "the = key zooms in (%.2f)" % d.zoom_target)
	check(InputMap.has_action("cam_zoom_out"), "and - zooms out")

	# X puts it back.
	Input.action_press("cam_reset")
	await _wait(2)
	Input.action_release("cam_reset")
	await _wait(90)
	check(absf(CameraDirector.yaw) < 0.02 and absf(d.zoom - 1.0) < 0.02, "X: back to the usual view")

	# Two people on one screen: the camera is the director's again.
	d.yaw_target = 1.0
	var other := Node3D.new()
	var sc := GDScript.new()
	sc.source_code = "extends Node3D\nvar ai := false\nvar idx := 1\nvar riding = null\n"
	sc.reload()
	other.set_script(sc)
	main.add_child(other)
	other.global_position = p.global_position + Vector3(1.0, 0.0, 0.0)
	var was: Array = d.players
	d.players = [p, other]
	await _wait(90)
	check(not CameraDirector.free_on and absf(CameraDirector.yaw) < 0.05, "two on one screen: fixed, from the south")
	d.players = was
	other.queue_free()

	print("\n%s" % ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
	quit()
