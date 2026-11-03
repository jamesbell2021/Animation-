extends SceneTree
## Saves a few screenshots of the game to a folder (default user://shots):
##   godot --path subterranean-1888 --script res://tools/screenshot.gd -- /some/folder
## Needs a display (xvfb-run works, with --rendering-driver opengl3 on machines without Vulkan).

var out_dir := "user://shots"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and not args[0].begins_with("--"):
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_go.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await _frames(2)
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("saved ", out_dir.path_join(name + ".png"))


## Put the real mouse over a tile, so the view's own hover logic builds the previews.
func _point_at(bv: BattleView, c: Vector2i) -> void:
	var p := bv.rig.camera.unproject_position(Kit.world(c))
	root.get_viewport().warp_mouse(p)
	await _frames(3)


func _go() -> void:
	root.size = Vector2i(1600, 900)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(40)
	await _shot("01_title")
	var help := HowToPlay.panel(func() -> void: pass)
	main.get_child(0).add_child(help)
	await _frames(5)
	await _shot("01b_how_to_play")
	help.queue_free()
	main.start_battle()
	await _frames(150)
	var bv: BattleView = main.battle_view()
	var b := bv.battle
	await _shot("02_start")
	# The Engineer lobs a mortar flare up the cavern; the camera follows; a move is previewed.
	Engine.time_scale = 4.0
	var eng := b.squad()[0]
	await bv._send({"t": "mortar", "u": eng.id, "to": eng.tile + Vector2i(2, -9)})
	var nat := b.squad()[1]
	bv.select(nat)
	await bv._send({"t": "move", "u": nat.id, "to": nat.tile + Vector2i(1, -5)})
	Engine.time_scale = 1.0
	await _frames(40)
	bv.rig.focus(Kit.world(nat.tile) + Vector3(0, 0, -4))
	await _frames(60)
	await _point_at(bv, nat.tile + Vector2i(2, -4))
	await _frames(10)
	await _shot("03_move_preview")
	bv._toggle_overlay("light")
	await _frames(10)
	await _shot("04_light_map")
	bv._toggle_overlay("light")
	# Walk the squad up into the great cavern and look for trouble.
	Engine.time_scale = 6.0
	for t in 3:
		for u in b.squad():
			bv.select(u)
			var r := b.grid.reach(u.tile, u.tu - Rules.overwatch_threshold(u.max_tu), false, u.id)
			var best := Battle.NO_TILE
			var best_d := Rules.dist(u.tile, b.journal_tile)
			var cost: PackedInt32Array = r["cost"]
			for i in cost.size():
				if cost[i] > 0 and cost[i] < TacGrid.INF_COST and b.grid.occupant[i] == -1:
					var d := Rules.dist(b.grid.cell(i), b.journal_tile)
					if d < best_d:
						best_d = d
						best = b.grid.cell(i)
			if best != Battle.NO_TILE:
				await bv._send({"t": "move", "u": u.id, "to": best})
		if not b.spotted.is_empty() or b.outcome != "":
			break
		await bv._send({"t": "end_turn"})
	Engine.time_scale = 1.0
	await _frames(60)
	var team := b.squad()
	if not team.is_empty():
		bv.select(team[0])
		if not b.spotted.is_empty() and team[0].has_weapon():
			bv.mode = team[0].def.weapon.modes[0]
			bv._refresh()
			var e := b.unit(b.spotted.keys()[0])
			bv.rig.focus(Kit.world(e.tile).lerp(Kit.world(team[0].tile), 0.5))
			await _frames(60)
			await _point_at(bv, e.tile)
	await _frames(20)
	await _shot("05_contact")
	# Play the swarm's turn and catch it mid-way.
	Engine.time_scale = 1.0
	bv.mode = "move"
	bv.end_turn()
	await _frames(150)
	await _shot("06_swarm_turn")
	while bv.busy:
		await _frames(10)
	await _frames(30)
	await _shot("07_next_turn")
	quit()
