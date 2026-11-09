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

	# Just in the doorway isn't obviously inside: the roof stays on.
	var threshold := cot.to_global(Vector3(Cottage.DOOR_X, 0.0, -Cottage.DEPTH * 0.5 + Cottage.WALL_T + 0.2))
	p.global_position = threshold + Vector3(0.0, 0.3, 0.0)
	await _wait(60)
	check(cot.interior.contains(p.global_position) and cot.interior.fade < 0.01, "standing in the doorway: the roof stays on")

	# Indoors the weapons are put by, and there's no room to swing.
	await _walk(p, cot.to_global(Vector3(Cottage.DOOR_X, 0.0, -Cottage.DEPTH * 0.5 - 1.2)), 5)
	p.global_position = cot.to_global(Vector3(0.3, 0.0, -0.2)) + Vector3(0.0, 0.3, 0.0)
	await _wait(20)
	check(p.indoors and not p._hook_holder.visible, "indoors: the boathook is put by (nothing pokes through the walls)")
	var said := [""]
	var on_msg := func(t: String) -> void: said[0] = t
	root.get_node("Events").message.connect(on_msg)
	Input.action_press("attack")
	await _wait(2)
	Input.action_release("attack")
	check(String(said[0]).contains("No room to swing"), "and no swinging it: " + String(said[0]))
	root.get_node("Events").message.disconnect(on_msg)
	p.global_position = outside + Vector3(0.0, 0.3, 0.0)
	await _wait(20)
	check(not p.indoors and p._hook_holder.visible, "out of doors it's back in hand")

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

	# Down on a beach: back up, over the fence across its gully.
	for i in Terrain.BEACHES.size():
		var low := Terrain.beach_point(i, 0.5)
		p.global_position = low + Vector3(0.0, 0.4, 0.0)
		await _wait(5)
		await _walk(p, Terrain.at_angle(float(Terrain.BEACHES[i]), 9.0), 420)
		var r := Vector2(p.global_position.x, p.global_position.z).length()
		check(r < 11.0, "beach %d: back up past the fence to the path (%.1f m out)" % [i, r])

	# A jump.
	p.global_position = Terrain.at_angle(30.0, 9.0) + Vector3(0.0, 0.3, 0.0)
	await _wait(20)
	var y0 := p.global_position.y
	var top := y0
	Input.action_press("jump")
	for i in 30:
		await physics_frame
		top = maxf(top, p.global_position.y)
	Input.action_release("jump")
	await _wait(40)
	check(top - y0 > 0.4 and absf(p.global_position.y - y0) < 0.15, "Space jumps (%.2f m up) and comes down again" % (top - y0))

	# Two on one screen: no cutaway, an outline instead.
	p.global_position = cot.to_global(Vector3(0.3, 0.0, -0.2)) + Vector3(0.0, 0.3, 0.0)
	await _wait(60)
	check(not p.outlined(), "playing alone, inside a room: the roof is cut away, no outline")
	p.global_position = Terrain.at_angle(60.0, 9.0) + Vector3(0.0, 0.3, 0.0)
	await _wait(30)
	check(p.outlined(), "alone out of doors: the outline is on (it only draws where something hides the keeper)")
	p.global_position = hut.to_global(Vector3(-1.0, 0.0, 0.0)) + Vector3(0.0, 0.3, 0.0)
	await _wait(60)
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
