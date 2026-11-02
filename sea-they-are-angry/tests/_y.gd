extends SceneTree
func _init() -> void:
	_go.call_deferred()
func _go() -> void:
	var args := OS.get_cmdline_user_args()
	var splash := root.get_node_or_null("StudioSplash")
	if splash:
		splash.free()
	root.size = Vector2i(1280, 720)
	root.get_node("Players").wanted = 1
	change_scene_to_file("res://scenes/main.tscn")
	for i in 3:
		await process_frame
	var main = current_scene
	main.begin_run(false, 1)
	var cyc = root.get_node("Cycle")
	cyc.running = false
	main.spawner.process_mode = Node.PROCESS_MODE_DISABLED
	main.hud.visible = false
	var target: Node3D = null
	for s in get_nodes_in_group("structures"):
		if s.get_script().get_global_name() == args[1] or s.get("id") == args[1]:
			target = s
	var p = main.player
	var d = main.director
	d.zoom_target = float(args[2])
	d.zoom = d.zoom_target
	for phase in [0, 2]:
		if phase == 2:
			cyc._enter(2)
			cyc.running = false
			main._apply_lighting(2, 0.0)
			main.atmosphere.apply(2, 0.0)
		for where in ["out", "in"]:
			p.global_position = (target.to_global(Vector3(0.0, 0.0, -3.0)) if where == "out" else target.to_global(Vector3(float(args[3]) if args.size() > 3 else 0.3, 0.0, -0.4))) + Vector3(0, 0.3, 0)
			for i in 60:
				await process_frame
			root.get_texture().get_image().save_jpg("%s_%d_%s.jpg" % [args[0], phase, where], 0.85)
	quit()
