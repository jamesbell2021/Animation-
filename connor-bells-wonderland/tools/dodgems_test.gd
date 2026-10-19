extends SceneTree
## Headless Dodgem Derby: 7 bots and an idle player on the rink. Prints who
## knocks whom into the Irish Sea, the results, and how many bumps, dunks,
## boosts and item uses there were; then presses Play Again and runs a second
## derby. Run from the project folder:
##   godot --headless --path . --fixed-fps 60 -s res://tools/dodgems_test.gd -- diff=1
var frame := 0
var gm: Node
var diff := 1
var max_frames := 60 * 480
var bumps := 0
var big_bumps := 0
var dunks := 0
var boosts := 0
var items_used := 0
var derbies := 0

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
			net.settings = {"sections": 6, "bots": 7, "difficulty": diff, "countdown": 3, "items": true, "mode": "dodgems"}
		change_scene_to_file("res://scenes/main/main.tscn")
		return false
	if frame < 4:
		return false
	if gm == null:
		gm = current_scene
		if gm != null and gm.race_manager != null:
			gm.race_manager.race_finished.connect(_on_finished)
			gm.dodgems.bumped.connect(func(_r: String, _v: String, s: float) -> void:
				bumps += 1
				if s > 8.0:
					big_bumps += 1)
			gm.dodgems.dunked.connect(func(v: String, b: String, l: int) -> void:
				dunks += 1
				print("t=%.1f SPLASH %s (by %s), %d lives left" % [gm.dodgems.battle_time, v, b if not b.is_empty() else "nobody", l]))
			gm.dodgems.eliminated.connect(func(v: String, b: String, n: int) -> void:
				dunks += 1
				print("t=%.1f OUT %s (by %s), %d left" % [gm.dodgems.battle_time, v, b if not b.is_empty() else "nobody", n]))
			gm.dodgems.net_event.connect(func(e: String, _a: Array) -> void:
				if e == "boost":
					boosts += 1)
			gm.items.item_fx.connect(func(_n: String, _k: int, _o: Vector3) -> void: items_used += 1)
		return false
	if frame % 1200 == 0:
		var line := "t=%d ring_r=%.1f " % [frame / 60, gm.course.outer_radius()]
		for c in gm._contestants:
			var key := str(c.name)
			line += "%s:L%d (%.0f,%.0f) | " % [key, gm.dodgems.get_lives(key), c.global_position.x, c.global_position.z]
		print(line)
	return false

func _on_finished(results: Array) -> void:
	derbies += 1
	for r in results:
		print("RESULT ", r)
	print("DERBY %d time=%.1f bumps=%d big=%d dunks=%d boosts=%d items=%d" % [derbies, gm.dodgems.battle_time, bumps, big_bumps, dunks, boosts, items_used])
	if derbies >= 2:
		quit()
		return
	bumps = 0
	big_bumps = 0
	dunks = 0
	boosts = 0
	items_used = 0
	gm.restart_race.call_deferred()
	(func() -> void:
		await create_timer(0.5).timeout
		var visible := 0
		for c in gm._contestants:
			if c.visible and c.is_physics_processing():
				visible += 1
		print("PLAY AGAIN: alive=%d visible=%d rings=%d" % [gm.dodgems.alive_count(), visible, gm.course.intact_rings()])).call()
