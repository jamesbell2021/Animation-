extends SceneTree
# Run: godot --headless --path sea-they-are-angry --script res://tests/slice_survival.gd
# Hunger and warmth, the camp's crops, the stove and the mess, and the helpers seeing to them.

var fails := 0
# A camp plot's states (CampPlot's). The camp's classes are only reached through the
# scene, never named here: `--script` compiles what a test names before the autoloads
# exist, which can leave it unusable.
const BARE := 0
const PLANTED := 1
const RIPE := 2

func check(c: bool, w: String) -> void:
	print(("PASS  " if c else "FAIL  ") + w)
	if not c:
		fails += 1

func _init() -> void:
	_go.call_deferred()

func _load(helpers: bool):
	if FileAccess.file_exists("user://run.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://run.json"))
	var pl = root.get_node("Players")
	pl.wanted = 1
	pl.helpers = helpers
	change_scene_to_file("res://scenes/main.tscn")
	for i in 600:
		if current_scene != null and current_scene.get("player") != null and current_scene.player != null:
			break
		await process_frame
	for i in 3:
		await physics_frame
	return current_scene

func _wait(frames: int) -> void:
	for i in frames:
		await physics_frame

func _go() -> void:
	var main = await _load(false)
	var Cyc = root.get_node("Cycle")
	var Stk = root.get_node("Stock")
	var Run = root.get_node("Run")
	var p: Player = main.player
	p.camera = null
	Cyc.running = false
	var c := Terrain.CAMP_C
	var spot := Vector3(c.x, Terrain.HOLM_HEIGHT + 0.2, c.y + 1.0)

	# ---- hunger ----
	check(p.hunger > 99.0 and p.warmth > 99.0, "a keeper starts fed and warm")
	p.global_position = spot
	var h0 := p.hunger
	await _wait(300)
	check(p.hunger < h0 - 0.5, "hunger drains (%.1f -> %.1f)" % [h0, p.hunger])
	p.hunger = 10.0
	check(p.need_speed() < 1.0, "a hungry keeper is slower (x%.2f)" % p.need_speed())
	# The mess: eat from the store.
	var mess = main.camp.mess
	Stk.set_all({"food": 0})
	check(not mess.interact(p), "nothing in the store: nothing to eat")
	Stk.add("food", 1)
	p.hp = 60
	check(mess.interact(p) and p.hunger == 100.0 and p.hp == 90 and Stk.get_amount("food") == 0, "a meal in the mess feeds them and heals 30")
	# Starving hurts.
	p.hunger = 0.0
	var hp0 := p.hp
	await _wait(400)
	check(p.hp < hp0, "starving costs health (%d -> %d)" % [hp0, p.hp])
	p.hunger = 100.0

	# ---- warmth ----
	Run.weather_for = Run.night
	Run.weather_kind = Weather.Kind.CLEAR
	Cyc._enter(Cyc.Phase.NIGHT)
	Cyc.running = false
	p.global_position = spot
	var w0 := p.warmth
	await _wait(300)
	var clear_drop := w0 - p.warmth
	check(clear_drop > 0.3, "outdoors at night a keeper cools (%.2f in 5 s)" % clear_drop)
	Run.weather_kind = Weather.Kind.STORM
	w0 = p.warmth
	await _wait(300)
	check(w0 - p.warmth > clear_drop * 1.5, "faster in a storm (%.2f)" % (w0 - p.warmth))
	p.warmth = 10.0
	check(p.need_speed() < 1.0, "a cold keeper is slower")
	# The quarters' stove.
	var stove = main.camp.stove
	Stk.set_all({"driftwood": 1})
	check(not stove.is_lit() and stove.interact(p) and stove.is_lit() and Stk.get_amount("driftwood") == 0, "the stove lights with a driftwood")
	p.global_position = stove.global_position + Vector3(0.0, 0.2, 0.6)
	w0 = p.warmth
	await _wait(120)
	check(p.warmth > w0 + 3.0, "by the lit stove a keeper warms through (%.1f -> %.1f)" % [w0, p.warmth])
	# The campfire by the cottage.
	var fire = null
	for n in get_nodes_in_group("heat"):
		if n.get_script().get_global_name() == "Campfire":
			fire = n
	check(fire != null and fire.heat_at(fire.global_position + Vector3(1.0, 0.0, 0.0)) > 0.0, "the campfire gives heat")
	check(fire.heat_at(fire.global_position + Vector3(8.0, 0.0, 0.0)) == 0.0, "but only close by")

	# ---- crops ----
	Run.weather_kind = Weather.Kind.CLEAR
	var bed = main.camp.plots[0]
	var glass = main.camp.plots[3]
	check(main.camp.plots.size() == 4 and glass.under_glass and not bed.under_glass, "three beds and the greenhouse")
	Stk.set_all({"seeds": 2})
	check(bed.state() == BARE and bed.interact(p) and bed.state() == PLANTED, "sow a bed with seed")
	check(glass.interact(p) and glass.state() == PLANTED and Stk.get_amount("seeds") == 0, "and the greenhouse")
	Cyc._enter(Cyc.Phase.DAWN)
	Cyc.running = false
	check(bed.state() == RIPE and glass.state() == RIPE, "ready at dawn")
	check(bed.interact(p) and Stk.get_amount("food") == 2 and Stk.get_amount("seeds") == 1, "a bed lifts for 2 food and a seed back")
	check(glass.interact(p) and Stk.get_amount("food") == 5, "the greenhouse for 3")
	# A storm flattens the outdoor beds (often), never the greenhouse.
	var flattened := 0
	for i in 20:
		Run.camp_crops[0] = PLANTED
		Run.camp_crops[3] = PLANTED
		Run.weather_for = Run.night
		Run.weather_kind = Weather.Kind.STORM
		bed._on_phase(Cyc.Phase.DAWN)
		glass._on_phase(Cyc.Phase.DAWN)
		if bed.state() == BARE:
			flattened += 1
		if i == 0:
			check(glass.state() == RIPE, "the greenhouse comes through the storm")
	check(flattened > 3 and flattened < 17, "a storm flattens an outdoor bed about half the time (%d of 20)" % flattened)
	# Needs carry over a save.
	p.hunger = 42.0
	Run.hunger[p.idx] = p.hunger
	root.get_node("SaveSys").save_run()
	var d: Dictionary = root.get_node("SaveSys").load_run()
	check(absf(float(d["hunger"][0]) - 42.0) < 0.01 and d.has("camp_crops"), "hunger and the camp's crops are saved")

	# ---- the helpers see to themselves ----
	main = await _load(true)
	Cyc = root.get_node("Cycle")
	Stk = root.get_node("Stock")
	main.player.camera = null
	var warden: Player = main.players[2]
	Stk.add("food", 3)
	warden.hunger = 20.0
	Engine.time_scale = 4.0
	for i in 900:
		await physics_frame
		if warden.hunger > 90.0:
			break
	check(warden.hunger > 90.0, "a hungry helper goes and eats")
	# The warden sows the camp's beds by day.
	Run = root.get_node("Run")
	for i in 1800:
		await physics_frame
		if Run.camp_crops.count(PLANTED) >= 3:
			break
	Engine.time_scale = 1.0
	check(Run.camp_crops.count(PLANTED) >= 3, "the warden sows the camp's plots (%s)" % str(Run.camp_crops))

	root.get_node("Players").helpers = true
	print("\n%s" % ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails > 0 else 0)
