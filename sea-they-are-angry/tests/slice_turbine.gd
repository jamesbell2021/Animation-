extends SceneTree
# Run: godot --headless --path sea-they-are-angry --script res://tests/slice_turbine.gd
# The camp's wind turbine and the strings of lights round the wire: it turns in the
# wind, the lights come on at dusk while it stands, blink when it's hit, flicker when
# it's badly damaged, go out when it's wrecked and come back when it's mended. Raiders
# make for it, the lit wire slows creatures, and the camp hasn't fallen while only the
# turbine stands.

var fails := 0

func check(c: bool, w: String) -> void:
	print(("PASS  " if c else "FAIL  ") + w)
	if not c:
		fails += 1

func _init() -> void:
	_go.call_deferred()

func _wait(frames: int) -> void:
	for i in frames:
		await physics_frame

func _go() -> void:
	if FileAccess.file_exists("user://run.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://run.json"))
	var pl = root.get_node("Players")
	pl.wanted = 1
	pl.helpers = false
	change_scene_to_file("res://scenes/main.tscn")
	for i in 600:
		if current_scene != null and current_scene.get("player") != null and current_scene.player != null:
			break
		await process_frame
	await _wait(3)
	var main = current_scene
	var Cyc = root.get_node("Cycle")
	var Stk = root.get_node("Stock")
	var p: Player = main.player
	p.camera = null
	Cyc.running = false
	main.spawner.process_mode = Node.PROCESS_MODE_DISABLED
	Cyc._enter(0)
	await _wait(5)
	var camp = main.camp
	var t = camp.turbine
	check(t != null and Terrain.on_holm(t.global_position.x, t.global_position.z) and not Terrain.in_camp(t.global_position.x, t.global_position.z), "the turbine stands on the holm, outside the wire")
	var a0: Basis = t.rotor.global_basis
	await _wait(30)
	check(t.spin > 0.5 and not t.rotor.global_basis.is_equal_approx(a0), "its rotor turns in the wind (%.1f rad/s)" % t.spin)
	var fwd: Vector3 = -t.nacelle.global_basis.z
	var w: Vector3 = Weather.wind_now.normalized()
	check(fwd.dot(-w) > 0.9, "and faces into the wind")
	# The wind: a day's breeze, then a gale. The rotor follows.
	var weather = main.atmosphere.weather
	weather.storm = 0.0
	weather._target = 0.0
	await _wait(240)
	var calm: float = t.spin
	weather.storm = 1.0
	weather._target = 1.0
	await _wait(300)
	var gale: float = t.spin
	check(calm > 0.2 and calm < 2.5 and gale > calm * 2.5, "it turns slowly in a breeze (%.1f rad/s) and races in a gale (%.1f)" % [calm, gale])
	weather.storm = 0.1
	weather._target = 0.1
	# The wind veers: the head follows it round.
	var before: float = t.nacelle.rotation.y
	weather._wind_t += 100.0
	await _wait(5)
	print("   the wind swung from %.2f to %.2f" % [before, atan2(Weather.wind_now.x, Weather.wind_now.z)])
	await _wait(600)
	var into: float = atan2(Weather.wind_now.x, Weather.wind_now.z)
	check(absf(angle_difference(t.nacelle.rotation.y, into)) < 0.15 and absf(angle_difference(before, t.nacelle.rotation.y)) > 0.2, "the wind veers and its head turns to follow (now %.2f, the wind %.2f)" % [t.nacelle.rotation.y, into])
	check(camp.targets().has(t), "creatures raiding the holm make for it")

	# The lights.
	await _wait(10)
	check(camp.lights_level == 0.0 and not camp._string_lights[0].visible, "by day the lights round the wire are off")
	check(camp._bulbs.multimesh.instance_count > 40 and camp._string_lights.size() >= 8, "%d bulbs strung round the wire" % camp._bulbs.multimesh.instance_count)
	Cyc._enter(1)
	await _wait(40)
	check(camp.lights_level > 0.95 and camp._string_lights[0].visible and camp._bulb_mat.emission_energy_multiplier > 4.0, "at dusk they come on")
	t.take_damage(10)
	await _wait(2)
	check(camp.lights_level == 0.0, "a blow to the turbine: they blink out")
	await _wait(40)
	check(camp.lights_level > 0.95, "and come back")
	t.take_damage(t.hp - int(t.max_hp * 0.3))
	var lowest := 1.0
	for i in 400:
		await physics_frame
		if camp._blink_t <= 0.0:
			lowest = minf(lowest, camp.lights_level)
	check(lowest < 0.6, "badly damaged it smokes, and the lights flicker (down to %.2f)" % lowest)

	# The lit wire slows creatures.
	var b = load("res://scenes/enemies/bloated.gd").new()
	b.lighthouse = main.lighthouse
	b.position = Vector3(Terrain.CAMP_C.x, Terrain.HOLM_HEIGHT + 0.2, Terrain.CAMP_C.y)
	main.get_node("Enemies").add_child(b)
	await _wait(3)
	t.repair(t.max_hp)
	await _wait(30)
	b.speed_mult = 1.0
	camp._physics_process(0.016)
	check(is_equal_approx(b.speed_mult, camp.LIT_SLOW), "inside the lit wire, a creature slows (x%.2f)" % b.speed_mult)
	b.queue_free()

	# Wrecked: dark. The camp hasn't fallen for that.
	t.take_damage(t.hp)
	await _wait(5)
	check(t.is_destroyed() and camp.lights_level == 0.0 and not camp._string_lights[0].visible, "wrecked: the lights are out")
	check(main.hud._warn_label.text.contains("lights"), "and the keepers are told: " + main.hud._warn_label.text)
	check(not camp.targets().has(t) and not camp.fallen(), "a wrecked turbine is no target, and the camp hasn't fallen")
	await _wait(240)
	check(t.spin < 0.1, "its rotor has stopped, a blade hanging")
	# Mended at the cabinet with scrap.
	Stk.set_amount("scrap", 20)
	p.global_position = t.global_position + Vector3(1.4, 0.3, 1.6)
	await _wait(10)
	check(p.interact_prompt().contains("wind turbine"), "at its foot: " + p.interact_prompt())
	var n := 0
	while t.is_damaged() and n < 12:
		t.interact(p)
		n += 1
	await _wait(200)
	check(not t.is_destroyed() and camp.lights_level > 0.95, "mended: the lights are back on")
	check(t.spin > 0.5, "and it turns again")

	print("\n%s" % ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails > 0 else 0)
