extends SceneTree
## Headless Paintball Battle: 7 bots and an idle player in the arena. Prints a
## status line every 15 s, the results, and how many shots, hits and crate
## pickups happened. Run from the project folder:
##   godot --headless --path . --fixed-fps 60 -s res://tools/paintball_test.gd -- diff=1
## It then presses Play Again and checks a second battle starts fresh and finishes.
var frame := 0
var gm: Node
var diff := 1
var max_frames := 60 * 300
var shots := 0
var hits := 0
var outs := 0
var crates := 0
var battles := 0

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
			net.settings = {"sections": 6, "bots": 7, "difficulty": diff, "countdown": 3, "items": true, "mode": "paintball"}
		change_scene_to_file("res://scenes/main/main.tscn")
		return false
	if frame < 4:
		return false
	if gm == null:
		gm = current_scene
		if gm != null and gm.race_manager != null:
			gm.race_manager.race_finished.connect(_on_finished)
			gm.paintball.net_event.connect(_count)
			gm.paintball.splatted.connect(func(_v: String, _s: String, _l: int) -> void: hits += 1)
			gm.paintball.eliminated.connect(func(v: String, s: String, n: int) -> void:
				outs += 1
				print("t=%.1f OUT %s (by %s), %d left" % [gm.paintball.battle_time, v, s, n]))
		return false
	if frame % 900 == 0:
		var line := "t=%d " % (frame / 60)
		for c in gm._contestants:
			var key := str(c.name)
			line += "%s:L%d A%d (%.0f,%.0f) | " % [key, gm.paintball.get_lives(key), gm.paintball.get_ammo(key), c.global_position.x, c.global_position.z]
		print(line)
	return false

func _count(event: String, _args: Array) -> void:
	if event == "shot":
		shots += 1
	elif event == "crate" and not bool(_args[1]):
		crates += 1

func _on_finished(results: Array) -> void:
	battles += 1
	for r in results:
		print("RESULT ", r)
	print("BATTLE %d time=%.1f shots=%d hits=%d outs=%d crates=%d" % [battles, gm.paintball.battle_time, shots, hits, outs, crates])
	if battles >= 2:
		quit()
		return
	shots = 0
	hits = 0
	outs = 0
	crates = 0
	gm.restart_race.call_deferred()
	(func() -> void:
		await create_timer(0.5).timeout
		var visible := 0
		for c in gm._contestants:
			if c.visible and c.is_physics_processing():
				visible += 1
		print("PLAY AGAIN: alive=%d visible=%d splats=%d" % [gm.paintball.alive_count(), visible, get_nodes_in_group("paint_splats").size()])).call()
