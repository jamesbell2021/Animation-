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

func on_ground(p: Vector3) -> Vector3:
	return Vector3(p.x, Terrain.height_at(p.x, p.z) + 0.15, p.z)

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
	# Scene swaps happen at frame end; wait until the keeper actually exists.
	for i in 600:
		if current_scene != null and current_scene.get("player") != null:
			break
		await process_frame
	for i in 3:
		await physics_frame
	var main = current_scene
	check(main != null and main.player != null, "main scene builds")
	var Run = root.get_node("Run")
	var Cycle = root.get_node("Cycle")
	var Stock = root.get_node("Stock")
	var lh = main.lighthouse
	var lamp = lh.lamp
	var player = main.player
	var cam: Camera3D = main.camera

	# Camera framing: the whole coast, every beach where creatures land, and the lighthouse top in view.
	var all_in := true
	for i in 24:
		var a := 360.0 * i / 24.0
		var p := Terrain.at_angle(a, Terrain.coast_radius(a) + 1.0)
		if not cam.is_position_in_frustum(p):
			all_in = false
			print("   off-screen coast point at ", p)
	for i in Terrain.BEACHES.size():
		if not cam.is_position_in_frustum(Terrain.beach_point(i, 0.3)):
			all_in = false
			print("   off-screen beach ", i)
	check(all_in, "coast and beaches fully on screen")
	check(cam.is_position_in_frustum(lh.global_position + Vector3(0, 10.4, 0)), "lighthouse top on screen")
	check(lh.global_position.y > Terrain.PLATEAU_HEIGHT + 4.0, "lighthouse stands on the crag, %.1f m above the meadow" % (lh.global_position.y - Terrain.PLATEAU_HEIGHT))

	# Fences close the chokepoints: each beach head and the ledge twice, each leaving a keeper-sized gap.
	var fences := []
	for s in get_nodes_in_group("structures"):
		if s is Fence:
			fences.append(s)
	check(fences.size() == 5, "five fences (%d)" % fences.size())
	var gaps_ok := true
	for f in fences:
		var on_ledge := Terrain.on_ledge(f.global_position.x, f.global_position.z)
		var width := Terrain.LEDGE_HALF * 2.0 if on_ledge else Terrain.beach_half_width(0.9) * 2.0
		var gap: float = width - f.length
		if gap < 0.75 or gap > 1.0:
			gaps_ok = false
			print("   fence at ", f.global_position, " leaves ", snappedf(gap, 0.01))
	check(gaps_ok, "gaps fit a keeper (0.7) but not a Bloated (1.0)")
	# The route up crosses every fence: each one sits across a leg of the path.
	var route: Array[Vector3] = Nav.route_to_light(Terrain.beach_point(1, 0.0))
	print("   route from the north beach: %d waypoints, %.0f m" % [route.size(), Nav.route_length(Terrain.beach_point(1, 0.0), route)])
	check(Nav.route_length(Terrain.beach_point(1, 0.0), route) > 45.0, "the way up from a beach is a long walk")
	check(route[route.size() - 2].y > Terrain.CRAG_TOP - 0.5, "the route climbs the ledge to the top")

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
	player.global_position = on_ground(sp.global_position + Vector3(1.0, 0.1, 0.0))
	await frames(3)
	check(player.interact_prompt().begins_with("[E] Gather"), "gather prompt near a scavenge box: " + player.interact_prompt())
	Input.action_press("interact")
	await frames(2)
	Input.action_release("interact")
	check(Stock.get_amount("scrap") == scrap0 + sp.amount and not sp.available, "E gathers scrap")

	# Boathook attack on an emerged Bloated.
	var b := Bloated.new()
	b.lighthouse = lh
	b.position = Terrain.at_angle(60.0, 10.5)
	main.get_node("Enemies").add_child(b)
	await wait_until(func(): return b.state == &"Approach", 120)
	b.process_mode = Node.PROCESS_MODE_DISABLED
	player.global_position = on_ground(b.global_position + Vector3(0, 0.1, 1.5))
	player._aim = Vector3(0, 0, -1)
	player._attack_cd = 0.0
	player._attack()
	check(b.hp == 40, "boathook hit takes 20 hp (hp now %d)" % b.hp)
	b.process_mode = Node.PROCESS_MODE_INHERIT
	player.global_position = on_ground(Vector3(2.6, 0.1, 2.4))
	b.take_damage(20, Vector3.ZERO, player)
	b.take_damage(20, Vector3.ZERO, player)
	check(b.state == &"Bloat", "killing a Bloated starts Bloat")
	var killed := [0]
	root.get_node("Events").enemy_killed.connect(func(_e): killed[0] += 1)
	await wait_until(func(): return not is_instance_valid(b), 200)
	check(not is_instance_valid(b) and killed[0] == 1, "Bloat then Burst frees it and emits enemy_killed once")

	# Fence: a Bloated landing on the east beach meets the fence at the head of its gully.
	var fence: Fence = null
	var east := Terrain.beach_point(0, 0.9)
	for f in fences:
		if Geo.flat_dist(f.global_position, east) < 1.5:
			fence = f
	# Open the ledge so this one goes all the way up.
	for f in fences:
		if f != fence:
			f.take_damage(1000)
	var e := Bloated.new()
	e.lighthouse = lh
	e.position = Terrain.beach_point(0, 0.0)
	main.get_node("Enemies").add_child(e)
	# The day's clock held still: wading up the beach takes it longer than a day.
	var clock_was: bool = Cycle.running
	Cycle.running = false
	Engine.time_scale = 6.0
	await wait_until(func(): return e.state == &"AttackFence", 3000)
	check(e.state == &"AttackFence" and e.attack_target == fence, "Bloated comes up the beach and attacks the fence at its head")
	await wait_until(func(): return fence.is_destroyed(), 3000)
	check(fence.is_destroyed() and not fence._meshes[0].visible, "fence destroyed and hidden after 10 hits")
	var lh_hp: int = lh.hp
	var climbed := [false]
	await wait_until(func():
		if is_instance_valid(e) and Terrain.on_ledge(e.global_position.x, e.global_position.z) and e.global_position.y > 4.0:
			climbed[0] = true
		return not is_instance_valid(e), 8000)
	check(climbed[0], "Bloated climbs the ledge path")
	check(not is_instance_valid(e), "Bloated walks through the broken fence, up to the light and bursts")
	check(lh.hp == lh_hp - 40, "burst at the lighthouse deals 40 (hp %d -> %d)" % [lh_hp, lh.hp])

	# Repair the broken fence from the meadow side.
	var inward := -Vector3(fence.global_position.x, 0, fence.global_position.z).normalized()
	player.global_position = on_ground(fence.global_position + inward * 1.0)
	await frames(3)
	var dw: int = Stock.get_amount("driftwood")
	check(player.interact_prompt().begins_with("[E] Repair fence"), "repair prompt: " + player.interact_prompt())
	Input.action_press("interact")
	await frames(2)
	Input.action_release("interact")
	# A few hammer blows first.
	await wait_until(func(): return not player.is_busy(), 200)
	await frames(2)
	check(fence.hp == 50 and Stock.get_amount("driftwood") == dw - 1 and fence._meshes[0].visible, "E repairs fence 50 for 1 driftwood")

	# Cycle: skip day -> dusk lights the lamp.
	Engine.time_scale = 1.0
	Cycle.running = clock_was
	Cycle.skip()
	await frames(2)
	check(Cycle.phase == 1 and lamp.state == Lamp.State.BURNING, "Enter in day jumps to dusk; lamp BURNING")

	# Operate and beam. Detach the camera so the headless mouse does not overwrite the aim.
	player.camera = null
	player.global_position = on_ground(Vector3(0, 0.1, 3.0))
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
	s.position = Terrain.at_angle(90.0, 7.8)
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
	print("   Bloated speed unlit ", snappedf(dark_speed, 0.01), "  lit ", snappedf(lit_speed, 0.01))
	check(dark_speed > 1.05 and lit_speed > 0.55 and lit_speed < 0.8, "beam slows a Bloated from 1.15 to ~0.69 m/s")
	check(s._lit_k > 0.9 and s._visual.scale.y < 0.9, "lit Bloated visibly pales and cowers")
	# Focused beam: dead zone near the lighthouse, burns 10/s further out.
	lamp.toggle_mode()
	var near_hp: int = s.hp
	var near_d: float = Geo.flat_dist(s.global_position, Vector3.ZERO)
	await frames(30)
	check(s.hp == near_hp, "focused beam cannot reach a Bloated %.1f m from the lighthouse" % near_d)
	s.queue_free()
	var s2 := Bloated.new()
	s2.lighthouse = lh
	s2.position = Terrain.beach_point(0, 0.75)
	main.get_node("Enemies").add_child(s2)
	await wait_until(func(): return s2.state == &"Approach", 120)
	player._aim = Vector3(s2.global_position.x, 0, s2.global_position.z).normalized()
	lamp.yaw = player.aim_yaw()
	await frames(2)
	var hp0: int = s2.hp
	p0 = s2.global_position
	await frames(60)
	var f_speed: float = Geo.flat_dist(p0, s2.global_position) / 1.0
	print("   focused on the east beach: hp ", hp0, " -> ", s2.hp, " in 1 s, speed ", snappedf(f_speed, 0.01))
	check(s2.hp <= hp0 - 9 and s2.hp >= hp0 - 11, "focused beam burns ~10 hp per second down on the beaches")
	# Seared, it stops dead and writhes where it stands.
	check(f_speed < 0.1 and s2.burning > 0.0, "the focused beam holds it still while it burns (%.2f m/s)" % f_speed)
	check(s2._burn_k > 0.9, "burning Bloated glows orange")
	s2.queue_free()
	lamp.toggle_mode()
	lamp.set_operator(null)

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
	player.global_position = on_ground(Vector3(0, 0.1, 2.8))
	await frames(3)
	check(player.interact_prompt().begins_with("[E] Refuel"), "refuel prompt: " + player.interact_prompt())
	Input.action_press("interact")
	await frames(2)
	Input.action_release("interact")
	# Poured from the oil can.
	await wait_until(func(): return not player.is_busy(), 200)
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
	for i in 600:
		if current_scene != null and current_scene != main and current_scene.get("player") != null:
			break
		await process_frame
	var m2 = current_scene
	check(m2 != main and Run.night == 1 and Run.active and Cycle.phase == 0, "New Run restarts at night 1, day")

	print("RESULT: ", "PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit(1 if fails > 0 else 0)
