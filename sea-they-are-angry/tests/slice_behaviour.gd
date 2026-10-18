extends SceneTree
# Run: godot --headless --path sea-they-are-angry --script res://tests/slice_behaviour.gd
# Compile errors printed before the first PASS come from --script loading class scripts before autoloads exist; the second pass runs.
# Drives the real main scene through the vertical-slice verify list.

var fails := 0

func check(cond: bool, what: String) -> void:
	if cond:
		print("PASS  ", what)
	else:
		fails += 1
		print("FAIL  ", what)

func wait_until(cond: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await physics_frame
	return cond.call()

func frames(n: int) -> void:
	for i in n:
		await physics_frame

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var rj := ProjectSettings.globalize_path("user://run.json")
	if FileAccess.file_exists("user://run.json"):
		DirAccess.remove_absolute(rj)
	root.size = Vector2i(1600, 900)
	change_scene_to_file("res://scenes/main.tscn")
	await frames(5)
	var main = current_scene
	check(main != null and main.player != null, "main scene builds")
	var Run = root.get_node("Run")
	var Cycle = root.get_node("Cycle")
	var Stock = root.get_node("Stock")
	var lh = main.lighthouse
	var lamp = lh.lamp
	var player = main.player
	var cam: Camera3D = main.camera

	# Camera framing: whole island rim and lighthouse top in view.
	var all_in := true
	for i in 24:
		var a := TAU * i / 24.0
		var p := Vector3(sin(a) * 14.0, 0.0, cos(a) * 14.0)
		if not cam.is_position_in_frustum(p):
			all_in = false
			print("   off-screen rim point at ", p)
	check(all_in, "island rim r14 fully on screen")
	check(cam.is_position_in_frustum(Vector3(0, 9, 0)), "lighthouse top on screen")

	# Fence ring: eight fences, adjacent ends separated by a keeper-sized gap.
	var fences := []
	for s in get_nodes_in_group("structures"):
		if s is Fence:
			fences.append(s)
	check(fences.size() == 8, "eight fences")
	var f0: Fence = fences[0]
	var tangent: Vector3 = f0.global_transform.basis.x
	var radial := Vector3(f0.global_position.x, 0, f0.global_position.z).normalized()
	check(absf(tangent.dot(radial)) < 0.01, "fence 0 is tangent to the ring")
	var ends := []
	for f in fences:
		ends.append(f.to_global(Vector3(f.length * 0.5, 0, 0)))
		ends.append(f.to_global(Vector3(-f.length * 0.5, 0, 0)))
	var min_gap := 99.0
	for i in ends.size():
		for j in range(i + 1, ends.size()):
			if int(i / 2) == int(j / 2):
				continue
			min_gap = minf(min_gap, Geo.flat_dist(ends[i], ends[j]))
	print("   smallest gap between fence ends: ", snappedf(min_gap, 0.01))
	check(min_gap > 0.75 and min_gap < 1.05, "gaps fit a keeper (0.7) but not a Bloated (1.0)")

	# Movement: W moves up-screen (-Z).
	var z0: float = player.global_position.z
	Input.action_press("move_up")
	await frames(30)
	Input.action_release("move_up")
	check(player.global_position.z < z0 - 1.0, "W moves the keeper toward -Z (up-screen)")
	check(player.is_on_floor(), "keeper stands on the ground")

	# Scavenge.
	var sp: ScavengePoint = null
	for n in get_nodes_in_group("interactable"):
		if n is ScavengePoint and n.kind == "scrap":
			sp = n
	var scrap0: int = Stock.get_amount("scrap")
	player.global_position = sp.global_position + Vector3(1.0, 0.1, 0.0)
	await frames(3)
	check(player.interact_prompt().begins_with("[E] Gather"), "gather prompt near a scavenge box: " + player.interact_prompt())
	Input.action_press("interact")
	await frames(2)
	Input.action_release("interact")
	check(Stock.get_amount("scrap") == scrap0 + 1 and not sp.available, "E gathers scrap")

	# Boathook attack on an emerged Bloated.
	var b := Bloated.new()
	b.lighthouse = lh
	b.position = Vector3(0, 0, 11.5)
	main.get_node("Enemies").add_child(b)
	await wait_until(func(): return b.state == &"Approach", 120)
	b.process_mode = Node.PROCESS_MODE_DISABLED
	player.global_position = b.global_position + Vector3(0, 0.1, 1.5)
	player._aim = Vector3(0, 0, -1)
	player._attack_cd = 0.0
	player._attack()
	check(b.hp == 40, "boathook hit takes 20 hp (hp now %d)" % b.hp)
	b.process_mode = Node.PROCESS_MODE_INHERIT
	player.global_position = Vector3(4, 0.1, 4)
	b.take_damage(20, Vector3.ZERO, player)
	b.take_damage(20, Vector3.ZERO, player)
	check(b.state == &"Bloat", "killing a Bloated starts Bloat")
	var killed := [0]
	root.get_node("Events").enemy_killed.connect(func(_e): killed[0] += 1)
	await wait_until(func(): return not is_instance_valid(b), 200)
	check(not is_instance_valid(b) and killed[0] == 1, "Bloat then Burst frees it and emits enemy_killed once")

	# Fence: Bloated walking in from the sea at angle 0 meets the fence centred at angle 0.
	var fence: Fence = null
	for f in fences:
		if absf(f.global_position.x) < 0.1 and f.global_position.z > 0:
			fence = f
	var e := Bloated.new()
	e.lighthouse = lh
	e.position = Vector3(0, -0.6, 17)
	main.get_node("Enemies").add_child(e)
	Engine.time_scale = 6.0
	await wait_until(func(): return e.state == &"AttackFence", 3000)
	check(e.state == &"AttackFence" and e.attack_target == fence, "Bloated stops at the fence and attacks it")
	await wait_until(func(): return fence.is_destroyed(), 3000)
	check(fence.is_destroyed() and not fence._meshes[0].visible, "fence destroyed and hidden after 10 hits")
	var lh_hp: int = lh.hp
	await wait_until(func(): return not is_instance_valid(e), 4000)
	check(not is_instance_valid(e), "Bloated walks through the broken fence and bursts")
	check(lh.hp == lh_hp - 40, "burst at the lighthouse deals 40 (hp %d -> %d)" % [lh_hp, lh.hp])

	# Repair the broken fence.
	player.global_position = fence.global_position + Vector3(0, 0.1, -1.0)
	await frames(3)
	var dw: int = Stock.get_amount("driftwood")
	check(player.interact_prompt().begins_with("[E] Repair fence"), "repair prompt: " + player.interact_prompt())
	Input.action_press("interact")
	await frames(2)
	Input.action_release("interact")
	await frames(2)
	check(fence.hp == 25 and Stock.get_amount("driftwood") == dw - 1 and fence._meshes[0].visible, "E repairs fence 25 for 1 driftwood")

	# Cycle: skip day -> dusk lights the lamp.
	Engine.time_scale = 1.0
	Cycle.skip()
	await frames(2)
	check(Cycle.phase == 1 and lamp.state == Lamp.State.BURNING, "Enter in day jumps to dusk; lamp BURNING")

	# Operate and beam. Detach the camera so the headless mouse does not overwrite the aim.
	player.camera = null
	player.global_position = Vector3(0, 0.1, 3.0)
	await frames(2)
	Input.action_press("operate")
	await frames(2)
	Input.action_release("operate")
	check(player.operating and lamp.operator == player, "R next to the lighthouse operates the lamp")
	player._aim = Vector3(1, 0, 0)
	await frames(90)
	check(absf(wrapf(lamp.yaw - deg_to_rad(-90.0), -PI, PI)) < 0.05, "beam swings to the keeper's aim (+X)")
	Input.action_press("beam_mode")
	await frames(2)
	Input.action_release("beam_mode")
	check(lamp.mode == Lamp.Mode.FOCUSED and is_equal_approx(lamp._light.spot_angle, 10.0), "Q focuses the beam")
	Input.action_press("operate")
	await frames(2)
	Input.action_release("operate")
	check(not player.operating and lamp.operator == null and lamp.mode == Lamp.Mode.WIDE, "R again releases; beam back to WIDE")

	# Lamp slows enemies in the cone.
	var s := Bloated.new()
	s.lighthouse = lh
	s.position = Vector3(7.6, 0, 0)
	main.get_node("Enemies").add_child(s)
	await wait_until(func(): return s.state == &"Approach", 120)
	lamp.yaw = PI
	await frames(2)
	var p0: Vector3 = s.global_position
	await frames(30)
	var dark_speed: float = Geo.flat_dist(p0, s.global_position) / 0.5
	lamp.set_operator(player)
	player._aim = Vector3(1, 0, 0)
	lamp.yaw = player.aim_yaw()
	await frames(2)
	p0 = s.global_position
	await frames(30)
	var lit_speed: float = Geo.flat_dist(p0, s.global_position) / 0.5
	print("   lamp state ", lamp.state, " lit ", lamp.is_lit(), " yaw ", lamp.yaw, " op ", lamp.operator, " lamp pos ", lamp.global_position, " s pos ", s.global_position, " state ", s.state, " phase ", Cycle.phase, " run ", Run.active)
	s.speed_mult = 1.0
	lamp._sweep(0.016)
	print("   after manual sweep speed_mult ", s.speed_mult)
	print("   Bloated speed unlit ", snappedf(dark_speed, 0.01), "  lit ", snappedf(lit_speed, 0.01))
	check(dark_speed > 1.4 and lit_speed > 0.8 and lit_speed < 1.1, "beam slows a Bloated from 1.6 to ~0.96 m/s")
	check(s._lit_k > 0.9 and s._visual.scale.y < 0.9, "lit Bloated visibly pales and cowers")
	# Focused beam burns at 10/s instead of slowing.
	lamp.toggle_mode()
	var hp0: int = s.hp
	p0 = s.global_position
	await frames(60)
	var f_speed: float = Geo.flat_dist(p0, s.global_position) / 1.0
	print("   focused: hp ", hp0, " -> ", s.hp, " in 1 s, speed ", snappedf(f_speed, 0.01), " state ", s.state)
	check(s.hp <= hp0 - 9 and s.hp >= hp0 - 11, "focused beam burns ~10 hp per second")
	check(s._burn_k > 0.9, "burning Bloated glows orange")
	lamp.toggle_mode()
	lamp.yaw = PI
	lamp.set_operator(null)
	lamp.yaw = PI
	await frames(2)
	lamp.yaw = PI
	lamp.set_operator(null)
	s.queue_free()

	player.camera = cam
	# Dawn save, then stock persists.
	Cycle._enter(3)
	await frames(2)
	check(FileAccess.file_exists("user://run.json"), "save written at dawn")
	var saved = JSON.parse_string(FileAccess.get_file_as_string("user://run.json"))
	check(saved is Dictionary and int(saved["night"]) == 2, "save holds night 2")
	check(sp.available, "scavenge box returns at dawn")
	check(lamp.state == Lamp.State.OFF, "lamp off at dawn")

	# Guttering -> refuel -> dark -> game over.
	Cycle._enter(1)
	await frames(2)
	lamp.fuel = 0.01
	await frames(3)
	check(lamp.state == Lamp.State.GUTTERING, "empty tank -> GUTTERING")
	main.hud._process(0.0)
	check(main.hud._lamp_label.text.begins_with("Lamp: GUTTERING"), "HUD shows: " + main.hud._lamp_label.text)
	lh.hp = lh.max_hp
	Stock.add("bio", 1)
	player.global_position = Vector3(0, 0.1, 2.8)
	await frames(3)
	check(player.interact_prompt().begins_with("[E] Refuel"), "refuel prompt: " + player.interact_prompt())
	Input.action_press("interact")
	await frames(2)
	Input.action_release("interact")
	check(lamp.state == Lamp.State.BURNING and lamp.fuel > 20.0, "E with bio refuels and returns to BURNING")
	lamp.fuel = 0.0
	await frames(2)
	Engine.time_scale = 10.0
	var ended := [""]
	root.get_node("Events").run_ended.connect(func(r, _n): ended[0] = r)
	await wait_until(func(): return ended[0] != "", 400)
	Engine.time_scale = 1.0
	check(ended[0] == "The lamp went dark.", "25 s of guttering ends the run: " + ended[0])
	check(main.hud._over.visible, "game-over overlay shown")
	check(not FileAccess.file_exists("user://run.json"), "run save cleared on game over")

	# New Run.
	main.hud._on_new_run()
	await frames(5)
	var m2 = current_scene
	check(m2 != main and Run.night == 1 and Run.active and Cycle.phase == 0, "New Run restarts at night 1, day")

	print("RESULT: ", "PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit(1 if fails > 0 else 0)
