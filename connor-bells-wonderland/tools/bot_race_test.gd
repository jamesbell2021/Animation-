extends SceneTree
## Headless bot race: 7 bots, all six sections, prints progress every 20 s and the results.
## Run from the project folder:
##   godot --headless --path . --fixed-fps 60 -s res://tools/bot_race_test.gd -- diff=2
## diff=0 Easy, 1 Medium, 2 Hard. The idle "Player" contestant always ends DNF.
var frame := 0
var gm: Node
var diff := 1
var max_frames := 60 * 320

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("diff="):
			diff = int(a.substr(5))

func _process(_d: float) -> bool:
	frame += 1
	if frame > max_frames:
		print("TIMEOUT")
		return true
	if frame == 2:
		var net = root.get_node_or_null("NetworkManager")
		if net != null:
			net.settings = {"sections": 6, "bots": 7, "difficulty": diff, "countdown": 3}
		change_scene_to_file("res://scenes/main/main.tscn")
		return false
	if frame < 4:
		return false
	if gm == null:
		gm = current_scene
		if gm != null and gm.race_manager != null:
			gm.race_manager.race_finished.connect(_on_finished)
		return false
	if frame % 1200 == 0:
		var line := "t=%d " % (frame / 60)
		var cm = gm.course.checkpoint_manager
		for c in gm._contestants:
			line += "%s:cp%d z%.0f y%.0f | " % [c.name, cm.get_progress(c) + 1, c.global_position.z, c.global_position.y]
		print(line)
	return frame > max_frames

func _on_finished(results: Array) -> void:
	for r in results:
		print("RESULT ", r)
	quit()
