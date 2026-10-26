extends SceneTree
# The host's half of the LAN test: run tests/run_lan.sh (it starts the client too).
# The two sides step along together: the host shows how far it's got in the store's
# rat poison (the client sees it in the state; nobody else touches it); the client says it's done by holding the
# "sprint" control (the host sees it in the input).

var fails := 0

func check(c: bool, w: String) -> void:
	print(("PASS  host: " if c else "FAIL  host: ") + w)
	if not c:
		fails += 1

func _init() -> void:
	_go.call_deferred()

func _wait(frames: int) -> void:
	for i in frames:
		await physics_frame

func _until(cond: Callable, frames: int) -> bool:
	for i in frames:
		if cond.call():
			return true
		await physics_frame
	return cond.call()

func _stage(n: int) -> void:
	root.get_node("Stock").set_amount("poison", 100 + n)

func _ack() -> bool:
	return await _until(func(): return root.get_node("Net").held(1, "sprint"), 3600)

func _unack() -> bool:
	return await _until(func(): return not root.get_node("Net").held(1, "sprint"), 3600)

func _go() -> void:
	if FileAccess.file_exists("user://run.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://run.json"))
	var Net = root.get_node("Net")
	var Run = root.get_node("Run")
	var Stk = root.get_node("Stock")
	var Cyc = root.get_node("Cycle")
	check(Net.host("Morag") == "", "hosting on port %d" % Net.PORT)
	change_scene_to_file("res://scenes/main.tscn")
	await _wait(10)
	check(await _until(func(): return Net.lobby.size() == 2, 3600), "the client joins the lobby (%s)" % str(Net.lobby))
	Net.start_game(false)
	await _wait(5)
	var main = current_scene
	check(Run.active and main.players.size() == 3, "the run starts: three keepers")
	var me = main.players[0]
	var them = main.players[1]
	check(not me.remote and them.remote and main.players[2].ai, "keeper 1 is the host's, keeper 2 the client's, keeper 3 the computer's")
	check(main.director.players.size() == 1 and main.director.players[0] == me, "the host's screen follows only its own keeper")
	me.camera = null
	Cyc.running = false
	check(await _until(func(): return bool(Net.input_for(1).get("live", false)), 3600), "the client's controls are coming in")
	_stage(1)

	# 1: the client walks its keeper.
	var start: Vector3 = them.global_position
	check(await _ack(), "the client walked")
	check(them.global_position.x > start.x + 1.5, "and its keeper walked right here (%.1f m)" % (them.global_position.x - start.x))

	# 2: the world, as the host has it, on the client's screen.
	var b = load("res://scenes/enemies/bloated.gd").new()
	b.lighthouse = main.lighthouse
	b.position = Terrain.beach_point(0, 0.7)
	main.get_node("Enemies").add_child(b)
	await _wait(2)
	b.speed = 0.0
	check(b.net_id > 0, "a creature gets a network id (%d)" % b.net_id)
	var fence = null
	for s in get_nodes_in_group("structures"):
		if s is Fence and fence == null:
			fence = s
	fence.take_damage(30)
	Stk.set_amount("shells", 42)
	Cyc._enter(Cyc.Phase.DUSK)
	Cyc.running = false
	root.get_node("Events").message.emit("Hello over the LAN")
	main.hud.warn("A warning for everyone")
	FX.burst(main, b.global_position)
	root.get_node("Audio").sfx("hit", b.global_position)
	_stage(2)
	await _unack()
	check(await _ack(), "the client saw it all")

	# 3: the client takes the shotgun at the shed (a menu run here, shown there).
	var shed = null
	for s in get_nodes_in_group("structures"):
		if s.get_script().get_global_name() == "Shed":
			shed = s
	them.global_position = shed.global_position + Vector3(0.2, 0.1, -1.9)
	_stage(3)
	await _unack()
	check(await _ack(), "the client used the shed")
	check(Run.arms[1].has("shotgun"), "the client's keeper took the shotgun: %s" % str(Run.arms[1]))
	check(ChoiceMenu.current == null and not them.in_menu, "and the menu's closed")

	# 4: the client fires it at a Bloated in front of its keeper.
	Run.night = 1
	them.global_position = Terrain.beach_point(1, 0.95) + Vector3(0.0, 0.2, 0.0)
	# Let the client's aim settle from the keeper's new place before standing the Bloated in it.
	await _wait(90)
	var aim: Vector3 = Net.input_for(1).get("aim", Vector3.FORWARD)
	aim.y = 0.0
	aim = aim.normalized()
	b.global_position = them.global_position + aim * 3.0
	b.global_position.y = Terrain.height_at(b.global_position.x, b.global_position.z)
	var hp0: int = b.hp
	_stage(4)
	await _unack()
	check(await _ack(), "the client fired")
	print("   keeper %s aim %s, Bloated %s" % [them.global_position, them.aim_dir(), b.global_position if is_instance_valid(b) else Vector3.ZERO])
	check(not is_instance_valid(b) or b.hp < hp0, "the shot hit the Bloated here (%d -> %d)" % [hp0, b.hp if is_instance_valid(b) else 0])
	check(Run.barrels == 1, "one barrel spent")

	# 5: the end, for everyone.
	_stage(5)
	await _wait(60)
	Run.end_run("Test over")
	await _wait(240)

	# 6: a new run for everyone, from the game-over screen.
	var old = current_scene
	Net.restart()
	check(await _until(func(): return current_scene != old and current_scene != null and current_scene.get("players") != null and current_scene.players.size() == 3 and Run.active, 3600), "New Run starts a new run on the LAN")
	main = current_scene
	check(main.players[1].remote and not main.players[1].ai, "the client's keeper is still the client's")

	# 7: the client leaves: its keeper is the computer's now.
	check(await _until(func(): return main.players[1].ai, 3600), "the client leaves: its keeper goes on, run by the computer")
	check(main.players[1].get_node_or_null("KeeperAI") != null and not main.players[1].remote, "with a helper's brain")
	Net.leave()
	print("\nHOST %s" % ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails > 0 else 0)
