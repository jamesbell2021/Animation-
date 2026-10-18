extends SceneTree
# Run: godot --headless --path sea-they-are-angry --script res://tests/slice_retreat.gd
func _init() -> void:
	_go.call_deferred()
func _go() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://run.json"))
	change_scene_to_file("res://scenes/main.tscn")
	# Scene swaps happen at frame end; wait until the keeper actually exists.
	for i in 600:
		if current_scene != null and current_scene.get("player") != null:
			break
		await process_frame
	for i in 3:
		await physics_frame
	var main = current_scene
	var Cycle = root.get_node("Cycle")
	var ids := []
	for pos in [Vector3(0, 0, 11), Vector3(-6, 0, -6), Vector3(5, 0, 0)]:
		var b := Bloated.new()
		b.lighthouse = main.lighthouse
		b.position = pos
		main.get_node("Enemies").add_child(b)
		ids.append(b)
	for i in 120:
		await physics_frame
	var states := ids.map(func(e): return String(e.state))
	print("   before dawn: ", states)
	Cycle._enter(Cycle.Phase.DAWN)
	await physics_frame
	print("   after dawn: ", ids.map(func(e): return String(e.state)))
	Engine.time_scale = 10.0
	var gone := false
	for i in 1500:
		gone = get_nodes_in_group("enemies").is_empty()
		if gone:
			break
		await physics_frame
	print(("PASS" if gone else "FAIL") + "  survivors retreat through fences into the sea and despawn")
	quit()
