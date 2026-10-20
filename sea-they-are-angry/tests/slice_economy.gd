extends SceneTree
# Run: godot --headless --path sea-they-are-angry --script res://tests/slice_economy.gd
# The garden, the cottage menu and upgrades, traps, the flare gun, dirty fuel, the campfire.

var fails := 0
var main
var player: Player
var lh: Lighthouse
var lamp: Lamp

func check(cond: bool, what: String) -> void:
	if cond:
		print("PASS  ", what)
	else:
		fails += 1
		print("FAIL  ", what)

func frames(n: int) -> void:
	for i in n:
		await physics_frame

func wait_until(cond: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await physics_frame
	return cond.call()

func press(action: String) -> void:
	Input.action_press(action)
	await frames(2)
	Input.action_release(action)

func spawn(e: Enemy, at: Vector3) -> Enemy:
	e.lighthouse = lh
	e.position = at
	main.get_node("Enemies").add_child(e)
	return e

func clear_enemies() -> void:
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	await frames(2)

func first_of(cls) -> Node:
	for n in main.get_children():
		if is_instance_of(n, cls):
			return n
	return null

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	if FileAccess.file_exists("user://run.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://run.json"))
	change_scene_to_file("res://scenes/main.tscn")
	for i in 600:
		if current_scene != null and current_scene.get("player") != null:
			break
		await process_frame
	await frames(3)
	main = current_scene
	player = main.player
	lh = main.lighthouse
	lamp = lh.lamp
	player.camera = null
	var Cycle = root.get_node("Cycle")
	var Stock = root.get_node("Stock")
	var Anger = root.get_node("Anger")
	var Run = root.get_node("Run")
	var SaveSys = root.get_node("SaveSys")
	var garden: Garden = first_of(Garden)
	var cottage: Cottage = first_of(Cottage)
	var fire: Campfire = first_of(Campfire)

	# ---- the garden ----
	check(garden.open_plots() == 3, "three beds dug to start")
	var plot: GardenPlot = garden.plots[0]
	player.global_position = plot.global_position + Vector3(0.0, 0.1, 0.0)
	await frames(3)
	Stock.set_all({"seaweed": 2})
	check(player.interact_prompt().contains("Plant potatoes"), "beside a bed: " + player.interact_prompt())
	await press("interact")
	check(Run.crops[0] == GardenPlot.PLANTED and Stock.get_amount("seaweed") == 1, "E digs in a kelp and plants")
	check(player.interact_prompt().contains("ready at dawn"), "planted: " + player.interact_prompt())
	garden.plots[1].interact(player)
	check(Run.crops[1] == GardenPlot.PLANTED, "a second bed planted")
	Cycle._enter(Cycle.Phase.DAWN)
	await frames(2)
	check(Run.crops[0] == GardenPlot.RIPE and Run.crops[1] == GardenPlot.RIPE, "by dawn both beds are ready")
	await frames(3)
	check(player.interact_prompt().contains("Lift potatoes"), "ripe: " + player.interact_prompt())
	await press("interact")
	check(Stock.get_amount("food") == 1 and Run.crops[0] == GardenPlot.BARE, "lifting a bed gives 1 food")
	garden.take_damage(10)
	check(Run.crops[1] == GardenPlot.BARE, "trampling ruins the other bed")
	garden.repair(100)
	Cycle._enter(Cycle.Phase.DAY)
	await frames(2)

	# ---- the cottage ----
	var door := cottage.to_global(Vector3(0.0, 0.0, -Cottage.DEPTH * 0.5 - 0.8))
	player.global_position = Vector3(door.x, Terrain.height_at(door.x, door.z) + 0.1, door.z)
	await frames(3)
	check(player.interact_prompt().contains("Go in"), "at the cottage: " + player.interact_prompt())
	Stock.set_all({"food": 1, "scrap": 7, "bio": 2, "oil": 1, "driftwood": 11, "seaweed": 3})
	Run.flares[0] = 1
	player.hp = 40
	await press("interact")
	var menu: ChoiceMenu = ChoiceMenu.current
	check(menu != null and player.in_menu, "E opens the cottage menu")
	var at := player.global_position
	Input.action_press("move_up")
	await frames(10)
	Input.action_release("move_up")
	check(player.global_position.distance_to(at) < 0.05, "the keeper stands still in the menu")
	menu.choose(1)
	check(player.max_hp == 110 and player.hp == 110 and Stock.get_amount("food") == 0, "eating: full health and +10 max (%d/%d)" % [player.hp, player.max_hp])
	menu.choose(2)
	check(player.flares() == 2 and Stock.get_amount("scrap") == 6, "a flare loaded for 1 scrap")
	menu.choose(3)
	check(Stock.get_amount("dirty_fuel") == 2 and Stock.get_amount("oil") == 0, "oil and driftwood mixed into 2 dirty fuel")
	var range0: float = lamp.current_range()
	menu.choose(4)
	check(Run.upgrades["lighthouse"] == 2 and lh.max_hp == 400 and lh.hp == 400, "lighthouse upgraded: tower 400")
	check(is_equal_approx(lamp.current_range(), range0 + 3.0) and Lamp.focus_mult == 1.5, "beam 3 m longer, focus burns 1.5x")
	check(lh._fittings[2][0].visible and not lh._fittings[3][0].visible, "brass hoops on the tower")
	menu.choose(5)
	var open := 0
	for s in get_nodes_in_group("trap_slots"):
		if s.unlocked:
			open += 1
	check(Run.upgrades["defences"] == 2 and open == 4, "defences upgraded: 4 trap slots (%d)" % open)
	var fence_ok := true
	for s in get_nodes_in_group("structures"):
		if s is Fence and s.max_hp != 200:
			fence_ok = false
	check(fence_ok, "fences 200")
	menu.choose(6)
	check(Run.upgrades["garden"] == 2 and garden.open_plots() == 4, "garden upgraded: 4 beds")
	check(is_instance_valid(menu) and ChoiceMenu.current == menu, "the menu stays open between picks")
	menu.close()
	await frames(2)
	check(not player.in_menu and ChoiceMenu.current == null, "Leave closes it")
	cottage.take_damage(20)
	Stock.set_all({"driftwood": 1})
	await frames(2)
	check(player.interact_prompt().contains("Repair"), "a damaged cottage asks for the hammer first")
	cottage.repair(100)

	# ---- traps ----
	var slots: Array = get_nodes_in_group("trap_slots")
	slots.sort_custom(func(a, b): return a.index < b.index)
	var slot: TrapSlot = slots[0]
	player.global_position = slot.global_position + Vector3(0.0, 0.1, 0.3)
	await frames(3)
	check(player.interact_prompt().contains("Set a trap"), "at a cairn: " + player.interact_prompt())
	Stock.set_all({"driftwood": 6, "seaweed": 2, "scrap": 4})
	await press("interact")
	ChoiceMenu.current.choose(1)
	await frames(2)
	check(slot.kind == "spike" and slot.uses == 3 and ChoiceMenu.current == null and Stock.get_amount("driftwood") == 4, "spike board set for 2 driftwood")
	player.global_position = lh.global_position + Vector3(0.0, 0.1, 4.0)
	var b := spawn(Bloated.new(), slot.global_position + Vector3(0.3, 0.0, 0.0)) as Bloated
	await wait_until(func(): return b.state == &"Bloat", 120)
	check(b.state == &"Bloat" and b.last_hit == "trap" and slot.uses == 2, "a Bloated steps on the spikes and bursts there")
	await clear_enemies()
	var sq := spawn(Squid.new(), slot.global_position) as Squid
	# Out of the water (1.6 s) and over the board.
	await frames(170)
	check(slot.uses == 2 and sq.state != &"Stagger", "a Squid skitters over the spikes")
	await clear_enemies()
	slot.wreck()
	slot.arm("net")
	sq = spawn(Squid.new(), slot.global_position) as Squid
	await wait_until(func(): return sq.state == &"Stagger", 200)
	check(sq.state == &"Stagger" and slot.uses == 1, "the kelp net tangles a Squid")
	await clear_enemies()
	slot.wreck()
	slot.arm("chain")
	var crab := spawn(Crab.new(), slot.global_position) as Crab
	# Out of the water first (traps ignore a creature still emerging), then onto the plate.
	await wait_until(func(): return crab.state == &"Stagger" or crab.state == &"Ragdoll", 200)
	check((crab.state == &"Stagger" or crab.state == &"Ragdoll") and crab.exposed_t > 0.0, "the chain plate flips a Crab (%s)" % crab.state)
	var hp0 := crab.hp
	crab.take_damage(20, Vector3.ZERO, player)
	check(hp0 - crab.hp == 40, "flipped, the boathook bites twice as deep (%d)" % (hp0 - crab.hp))
	crab._enter_Slam()
	check(slot.kind == "", "its slam smashes the trap")
	await clear_enemies()

	# ---- the flare gun ----
	var spot := Terrain.beach_point(1, 0.4)
	b = spawn(Bloated.new(), spot) as Bloated
	b.speed = 0.0
	var b2 := spawn(Bloated.new(), spot + Vector3(2.0, 0.0, 0.0)) as Bloated
	b2.speed = 0.0
	await frames(60)
	var f := Flare.new()
	f.from = spot + Vector3(0.0, 2.0, 6.0)
	f.to = spot
	main.add_child(f)
	await frames(60)
	check(b.hp == 20 and b.last_hit == "flare", "a flare strikes a Bloated for 40 (hp %d)" % b.hp)
	check(b2._lit_k > 0.5, "the burning flare lights and cows the one beside it")
	await clear_enemies()
	f.queue_free()
	player.global_position = lh.global_position + Vector3(0.0, 0.1, 4.0)
	Run.flares[0] = 1
	var before := get_nodes_in_group("player").size()
	await press("flare")
	await frames(2)
	var shot := false
	for n in main.get_children():
		if n is Flare:
			shot = true
	check(shot and player.flares() == 0, "RMB fires a flare")
	await press("flare")
	check(player.flares() == 0, "no flares: nothing fires")

	# ---- dirty fuel ----
	player.global_position = Vector3(0.0, Terrain.CRAG_TOP + 0.1, Lighthouse.RADIUS + 0.8)
	await frames(3)
	Stock.set_all({"dirty_fuel": 1})
	lamp.fuel = 50.0
	var anger0: int = Anger.value
	check(player.interact_prompt().contains("[F] Dirty fuel"), "the lighthouse offers: " + player.interact_prompt())
	await press("use_dirty")
	await wait_until(func(): return not player.is_busy(), 120)
	check(is_equal_approx(lamp.fuel, 80.0) and lamp.is_boosted() and Anger.value == anger0 + 1, "F pours dirty fuel: +30, burns hot, and the sea is angrier")
	lamp._burn(0.01)
	check(Lamp.dps_mult > Lamp.focus_mult, "the hot flame burns creatures harder")

	# ---- the campfire ----
	Stock.set_all({"driftwood": 1})
	player.hp = 50
	fire.interact(player)
	check(player.hp == 80 and Stock.get_amount("driftwood") == 0, "the campfire warms a keeper through: +30 for 1 driftwood")

	# ---- oil, and the save ----
	Run.night = 2
	main._wash_up_oil()
	var drum: ScavengePoint = null
	for n in main.get_children():
		if n is ScavengePoint and n.kind == "oil":
			drum = n
	check(drum != null and drum.once, "an oil drum washes up after night 2")
	drum.interact(player)
	await frames(2)
	check(Stock.get_amount("oil") == 1 and not is_instance_valid(drum), "gathered once, and gone")
	Run.night = 3
	main._wash_up_oil()
	check(not main._oil_tonight, "none after night 3")
	Run.crops = [2, 1, 0, 0, 0]
	SaveSys.save_run()
	var d: Dictionary = SaveSys.load_run()
	check(int(d["upgrades"]["lighthouse"]) == 2 and int(d["crops"][0]) == 2 and int(d["max_hp_bonus"][0]) == 10, "upgrades, beds and meals are saved")

	# ---- the weather ----
	check(Weather.roll(123, 1, 10) == Weather.Kind.CLEAR, "the first night is always clear")
	check(Weather.roll(77, 5, 2) == Weather.roll(77, 5, 2), "the same run and night gives the same weather")
	var counts := [[0, 0, 0], [0, 0, 0]]
	for seed_value in 400:
		counts[0][Weather.roll(seed_value, 4, 0)] += 1
		counts[1][Weather.roll(seed_value, 4, 10)] += 1
	print("   calm sea: clear/squalls/storm %s   angry sea: %s" % [counts[0], counts[1]])
	check(counts[0][0] > 100 and counts[0][1] > 80 and counts[0][2] > 40, "all three kinds of night come up")
	check(counts[1][2] > counts[0][2] * 2, "an angry sea brings more storms")
	Run.night = 6
	Run.weather_for = 0
	var kind := Weather.tonight()
	Cycle._enter(Cycle.Phase.DUSK)
	await frames(2)
	check(main.hud._phase_label.text.ends_with(Weather.KIND_NAMES[kind]), "the HUD names tonight's weather: " + main.hud._phase_label.text)
	check(is_equal_approx(main.atmosphere.weather._target, Weather.KIND_LEVELS[kind][Cycle.Phase.DUSK]), "the storm builds to tonight's level")

	print("RESULT: ", "PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit()
