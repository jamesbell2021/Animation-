extends SceneTree
## Buildings you can walk into: in at the door and not through the walls; playing alone
## the roof and upper walls fade away while you're inside; the shed's shotgun on the
## bench comes and goes; the camp's huts too; with two playing, an outline instead.
##   godot --headless --path . --script res://tests/slice_interior.gd

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

# Walk the keeper toward a point (as a stick would) for a while.
func _walk(p: Player, to: Vector3, frames: int) -> void:
	p.ai = true
	for i in frames:
		var d := to - p.global_position
		d.y = 0.0
		p.ai_move = Vector2(d.x, d.z).normalized() if d.length() > 0.2 else Vector2.ZERO
		await physics_frame
	p.ai_move = Vector2.ZERO
	p.ai = false

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
	var p: Player = main.player
	var cot: Cottage = null
	var shed: Shed = null
	for s in get_nodes_in_group("structures"):
		if s is Cottage:
			cot = s
		elif s is Shed:
			shed = s

	# In at the cottage door.
	var outside := cot.to_global(Vector3(Cottage.DOOR_X, 0.0, -Cottage.DEPTH * 0.5 - 1.2))
	p.global_position = outside + Vector3(0.0, 0.3, 0.0)
	await _wait(5)
	check(not cot.interior.contains(p.global_position), "outside the cottage door")
	await _walk(p, cot.to_global(Vector3(Cottage.DOOR_X, 0.0, 0.2)), 120)
	check(cot.interior.contains(p.global_position), "walked in at the door")
	await _wait(40)
	check(Interior.cutaway_mode() and cot.interior.fade > 0.99 and not cot.interior.upper.visible, "playing alone: the roof and upper walls fade away inside (%.2f)" % cot.interior.fade)
	await _walk(p, outside, 120)
	await _wait(40)
	check(not cot.interior.contains(p.global_position) and cot.interior.fade < 0.01 and cot.interior.upper.visible, "out again: the roof comes back")

	# Not through the back wall.
	var behind := cot.to_global(Vector3(0.0, 0.0, Cottage.DEPTH * 0.5 + 1.2))
	p.global_position = behind + Vector3(0.0, 0.3, 0.0)
	await _wait(5)
	await _walk(p, cot.global_position, 90)
	check(not cot.interior.contains(p.global_position), "the back wall stops a keeper")

	# The shed: in at its door; the shotgun on the bench until it's taken.
	var by_shed := shed.to_global(Vector3(Shed.DOOR_X, 0.0, -Shed.DEPTH * 0.5 - 1.0))
	p.global_position = by_shed + Vector3(0.0, 0.3, 0.0)
	await _wait(5)
	await _walk(p, shed.to_global(Vector3(Shed.DOOR_X, 0.0, 0.1)), 120)
	check(shed.interior.contains(p.global_position), "walked into the shed")
	check(shed._gun.visible, "the shotgun lies on the bench")
	p.arsenal.give("shotgun")
	await _wait(40)
	check(not shed._gun.visible, "taken: gone from the bench")
	p.arsenal.take_away("shotgun")
	await _walk(p, by_shed, 100)

	# The quarters hut: in at an end door.
	var hut: Node3D = main.camp.huts[0]
	var room: Interior = hut.get_node("Interior")
	var end_out := hut.to_global(Vector3(-Camp.HUT_LEN * 0.5 - 1.2, 0.0, 0.0))
	p.global_position = end_out + Vector3(0.0, 0.3, 0.0)
	await _wait(5)
	await _walk(p, hut.to_global(Vector3(-1.0, 0.0, 0.0)), 160)
	check(room.contains(p.global_position), "walked into the quarters at the end door")
	await _wait(40)
	check(room.fade > 0.99, "the hut's shell lifts away")
	var side := hut.to_global(Vector3(0.0, 0.0, Camp.HUT_R + 1.0))
	p.global_position = hut.to_global(Vector3(0.0, 0.0, 0.0)) + Vector3(0.0, 0.3, 0.0)
	await _wait(3)
	await _walk(p, side, 90)
	check(room.contains(p.global_position), "and its curved side keeps a keeper in")

	# Two on one screen: no cutaway, an outline instead.
	check(not p.outlined(), "playing alone: no outline")
	var d: CameraDirector = main.director
	var other := Node3D.new()
	var sc := GDScript.new()
	sc.source_code = "extends Node3D\nvar ai := false\nvar idx := 1\nvar riding = null\n"
	sc.reload()
	other.set_script(sc)
	main.add_child(other)
	other.global_position = p.global_position + Vector3(1.0, 0.0, 0.0)
	var was: Array = d.players
	d.players = [p, other]
	await _wait(40)
	check(not Interior.cutaway_mode() and room.fade < 0.01, "two playing: the roof stays on")
	check(p.outlined(), "and the keeper shows as an outline through it")
	d.players = was
	other.queue_free()

	print("\n%s" % ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
	quit()
