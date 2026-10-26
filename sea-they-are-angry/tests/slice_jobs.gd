extends SceneTree
# Run: godot --headless --path sea-they-are-angry --script res://tests/slice_jobs.gd
# The first days' jobs: each ticks off when a person's keeper does it (not a helper),
# they're kept with the run, and the list goes when they're done.

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
	await _wait(3)
	var main = current_scene
	var Cyc = root.get_node("Cycle")
	var Run = root.get_node("Run")
	var Stk = root.get_node("Stock")
	var Ev = root.get_node("Events")
	var p: Player = main.player
	p.camera = null
	Cyc.running = false
	var J = load("res://scenes/systems/jobs.gd")
	await _wait(2)
	check(J.showing() and main.hud._jobs_box.visible and Run.jobs.is_empty(), "a new run: the jobs list is up, none done")

	# A helper's work doesn't count.
	p.ai = true
	Ev.did.emit("eat", p)
	p.ai = false
	check(not J.done("eat"), "a helper eating doesn't tick it")

	# Gather.
	var sp = null
	for n in get_nodes_in_group("interactable"):
		if n is ScavengePoint and n.available and not Terrain.holm_side(n.global_position.x, n.global_position.z):
			sp = n
	sp.interact(p)
	check(J.done("gather"), "gather on a beach")
	# Mend.
	var fence = null
	for s in get_nodes_in_group("structures"):
		if s is Fence and fence == null:
			fence = s
	fence.take_damage(30)
	Stk.add("driftwood", 2)
	fence.interact(p)
	check(J.done("repair"), "mend a fence")
	# Eat.
	Stk.add("food", 1)
	p.hunger = 40.0
	main.camp.mess.interact(p)
	check(J.done("eat"), "eat in the mess")
	# Cross to the camp.
	p.global_position = Vector3(Terrain.CAMP_C.x, Terrain.HOLM_HEIGHT + 0.2, Terrain.CAMP_C.y + 1.0)
	await _wait(40)
	check(J.done("bridge"), "cross to the old camp")
	# The generator.
	Stk.add("diesel", 1)
	main.camp.generator.fuel = 20.0
	main.camp.generator.interact(p)
	check(J.done("generator"), "fill the generator")
	# The shed.
	p.arsenal.give("bow")
	await _wait(40)
	check(J.done("shed"), "take a weapon from the shed")
	# Sow.
	Stk.add("seeds", 1)
	main.camp.plots[0].interact(p)
	check(J.done("sow"), "sow a bed")
	check(J.showing(), "one left: still showing")
	# The lamp, at dusk.
	Cyc._enter(Cyc.Phase.DUSK)
	Cyc.running = false
	p.global_position = main.lighthouse.global_position + Vector3(0.0, 0.1, 2.6)
	await _wait(3)
	p._toggle_operate()
	check(J.done("lamp"), "work the lamp")
	await _wait(3)
	check(not J.showing() and not main.hud._jobs_box.visible, "all done: the list goes")
	root.get_node("SaveSys").save_run()
	check(root.get_node("SaveSys").load_run()["jobs"].size() == 8, "kept with the run")
	# Not done, but past the third night: gone too.
	Run.jobs = ["gather"]
	Run.night = 4
	check(not J.showing(), "after the third night it goes anyway")

	pl.helpers = true
	print("\n%s" % ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails > 0 else 0)
