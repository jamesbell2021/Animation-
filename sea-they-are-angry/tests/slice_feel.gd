extends SceneTree
# Run: godot --headless --path sea-they-are-angry --script res://tests/slice_feel.gd
# How a blow lands (the hit-stop, the shove) and each keeper's own knack (Players.PERKS):
# Callum's heavier hook, Hamish's shotgun and bow, Mairi's quicker mending and pouring
# and cheaper mends, Ewan's pace. A knack goes with the slot, so the one keeper here is
# moved from slot to slot.

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

func _bloated(main, at: Vector3):
	var b = load("res://scenes/enemies/bloated.gd").new()
	b.lighthouse = main.lighthouse
	b.position = at
	main.get_node("Enemies").add_child(b)
	return b

func _clear() -> void:
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	await _wait(2)

# A Bloated standing still on the beach, out of the water and ready to be hit.
func _target(main, spot: Vector3):
	var b = _bloated(main, spot)
	await _wait(120)
	b.speed = 0.0
	return b

# The keeper a step from it, facing it.
func _face(p: Player, b) -> void:
	var to: Vector3 = b.global_position - p.global_position
	to.y = 0.0
	if to.length() < 0.01:
		to = Vector3(0.0, 0.0, -1.0)
	p.global_position = b.global_position - to.normalized() * 1.5 + Vector3(0.0, 0.3, 0.0)
	to = b.global_position - p.global_position
	to.y = 0.0
	p._aim = to.normalized()
	p.facing = atan2(-to.x, -to.z)
	p.rotation.y = p.facing

# One boathook swing from slot `slot`: the damage it did.
func _hook_damage(main, p: Player, spot: Vector3, slot: int) -> int:
	await _clear()
	var b = await _target(main, spot)
	_face(p, b)
	p.idx = slot
	p._attack_cd = 0.0
	var hp0: int = b.hp
	p._attack()
	await _wait(2)
	var dealt: int = hp0 - (b.hp if is_instance_valid(b) else 0)
	return dealt

# Frames of a job (at 60 a second) from start to done, for slot `slot`.
func _job_frames(p: Player, tool: String, target: Node, slot: int) -> int:
	p.idx = slot
	p._start_job(tool, target)
	var n := 0
	while p._job_tool != "" and n < 1000:
		p._work(1.0 / 60.0)
		n += 1
	return n

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
	var Fl = root.get_node("Feel")
	var p: Player = main.player
	p.camera = null
	Cyc.running = false
	# The test works the keeper itself: its own controls stay quiet.
	p.set_physics_process(false)
	Cyc._enter(Cyc.Phase.NIGHT)
	Cyc.running = false
	var spot := Terrain.beach_point(0, 0.75)
	p.global_position = spot + Vector3(0.0, 0.3, 2.0)
	await _wait(5)

	# ---- the table ----
	check(pl.perk(0, "hook_dmg") > 1.0 and pl.perk(1, "hook_dmg") == 1.0 and pl.perk(1, "pellets") == 1.0 and pl.perk(0, "pellets") == 0.0,
		"the knacks are read by slot, and a keeper without one gets the plain number")

	# ---- Callum's hook ----
	var callum := await _hook_damage(main, p, spot, 0)
	var hamish := await _hook_damage(main, p, spot, 1)
	check(callum == roundi(Player.ATTACK_DMG * 1.35) and hamish == Player.ATTACK_DMG, "Callum's boathook hits harder than Hamish's (%d against %d)" % [callum, hamish])

	# ---- Hamish's shotgun and bow ----
	var arms: Arsenal = p.arsenal
	p.idx = 1
	var h_pellets := arms.pellet_count()
	var h_spread := arms.spread_deg()
	p.idx = 0
	check(h_pellets == Arsenal.PELLETS + 1 and arms.pellet_count() == Arsenal.PELLETS, "Hamish's shotgun throws an extra pellet (%d against %d)" % [h_pellets, arms.pellet_count()])
	check(h_spread < arms.spread_deg(), "in a tighter cone (%.0f against %.0f degrees)" % [h_spread, arms.spread_deg()])
	var draws := []
	for slot in [0, 1]:
		p.idx = slot
		arms.draw = 0.0
		arms._bow(0.4, false, true)
		draws.append(arms.draw)
	arms.draw = -1.0
	p.idx = 0
	check(draws[1] > draws[0] * 1.2, "and Hamish draws the bow faster (%.2f against %.2f in 0.4 s)" % [draws[1], draws[0]])

	# ---- Mairi's mending and pouring ----
	var lh = main.lighthouse
	p.global_position = lh.global_position + Vector3(0.0, 0.1, 3.0)
	await _wait(2)
	Stk.set_all({"bio": 10, "driftwood": 10, "scrap": 10})
	var lamp = lh.lamp
	lamp.fuel = 20.0
	var pour_c := _job_frames(p, "can", lh, 0)
	var fuel_c: float = lamp.fuel
	lamp.fuel = 20.0
	var pour_m := _job_frames(p, "can", lh, 2)
	check(fuel_c > 20.0 and lamp.fuel > 20.0 and pour_m < pour_c, "Mairi refuels the lamp faster (%d frames against %d)" % [pour_m, pour_c])
	lamp.fuel = Lamp.FUEL_MAX
	lh.take_damage(100)
	var hp_lh: int = lh.hp
	var ham_c := _job_frames(p, "hammer", lh, 0)
	check(lh.hp > hp_lh and Stk.get_amount("driftwood") == 9 and Stk.get_amount("scrap") == 9, "Callum's mend of the lighthouse: a driftwood and a scrap")
	var ham_m := _job_frames(p, "hammer", lh, 2)
	check(ham_m < ham_c, "Mairi mends faster (%d frames against %d)" % [ham_m, ham_c])
	check(Stk.get_amount("driftwood") == 9 and Stk.get_amount("scrap") == 8, "and saves the driftwood on a mend that costs two things (driftwood %d, scrap %d)" % [Stk.get_amount("driftwood"), Stk.get_amount("scrap")])
	check(pl.mend_cost({"driftwood": 1}, 2) == {"driftwood": 1}, "a one-driftwood mend still costs her the driftwood")

	# ---- Ewan's pace ----
	p.global_position = spot + Vector3(0.0, 0.3, 2.0)
	p.ai = true
	p.ai_move = Vector2(1.0, 0.0)
	var speeds := []
	for slot in [0, 3]:
		p.idx = slot
		p._move(1.0 / 60.0)
		speeds.append(Vector2(p.velocity.x, p.velocity.z).length())
	check(speeds[1] > speeds[0] * 1.1, "Ewan walks faster (%.2f against %.2f m/s)" % [speeds[1], speeds[0]])
	p.ai_held = {"sprint": true}
	var lasts := []
	for slot in [0, 3]:
		p.idx = slot
		p._sprint_t = 0.0
		p._sprint_cd = 0.0
		var n := 0
		while p._sprint_cd <= 0.0 and n < 2000:
			p._move(1.0 / 60.0)
			n += 1
		lasts.append([n, p._sprint_cd])
	check(lasts[1][0] > lasts[0][0] and lasts[1][1] < lasts[0][1], "and sprints longer (%d frames against %d) with a shorter rest (%.1f s against %.1f)" % [lasts[1][0], lasts[0][0], lasts[1][1], lasts[0][1]])
	p.ai_held = {}
	p.ai_move = Vector2.ZERO
	p._sprint_t = 0.0
	p._sprint_cd = 0.0
	p.ai = false
	p.idx = 0

	# ---- the hit-stop ----
	await _clear()
	Fl.force_live = true
	var b = await _target(main, spot)
	_face(p, b)
	Engine.time_scale = 1.0
	var stops0: int = Fl.stops
	b.take_damage(20, p._aim, p)
	check(Fl.stops == stops0 + 1 and Engine.time_scale < 0.5, "a person's solid blow freezes the world a moment (time scale %.2f)" % Engine.time_scale)
	var t0 := Time.get_ticks_msec()
	while Engine.time_scale != 1.0 and Time.get_ticks_msec() - t0 < 2000:
		await process_frame
	var took := Time.get_ticks_msec() - t0
	check(Engine.time_scale == 1.0 and took < 400, "and lets go again: time scale back to 1 after %d ms" % took)
	# Past the gap between stops, then a helper's blow, a chip, and the clock off 1.
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 300:
		await process_frame
	b.hp = 60
	p.ai = true
	b.take_damage(20, p._aim, p)
	check(Fl.stops == stops0 + 1 and Engine.time_scale == 1.0, "a helper's blow doesn't stop it")
	p.ai = false
	b.hp = 60
	b.take_damage(5, p._aim, p)
	check(Fl.stops == stops0 + 1 and Engine.time_scale == 1.0, "nor a chip (5)")
	Engine.time_scale = 2.0
	b.hp = 60
	b.take_damage(25, p._aim, p)
	check(Fl.stops == stops0 + 1 and Engine.time_scale == 2.0, "nor anything while the clock runs fast (a bot's run)")
	Engine.time_scale = 1.0
	root.get_node("Settings").hitstop = false
	b.hp = 60
	b.take_damage(25, p._aim, p)
	check(Fl.stops == stops0 + 1 and Engine.time_scale == 1.0, "nor with it turned off in Settings")
	root.get_node("Settings").hitstop = true
	Fl.force_live = false
	Engine.time_scale = 1.0

	# ---- the shove ----
	await _clear()
	b = await _target(main, spot)
	_face(p, b)
	var from: Vector3 = b.global_position
	Arsenal.strike(b, 1, p._aim, p, "arrow", Arsenal.arrow_push(Arsenal.ARROW_DMG_MAX))
	await _wait(40)
	var moved := Geo.flat_dist(b.global_position, from)
	var along: float = (b.global_position - from).dot(p._aim)
	check(moved > 0.4 and along > 0.3, "a full-draw arrow's shove drives a Bloated back (%.2f m)" % moved)
	await _clear()
	b = await _target(main, spot)
	_face(p, b)
	from = b.global_position
	Arsenal.strike(b, 1, p._aim, p, "arrow", Arsenal.arrow_push(14))
	await _wait(40)
	var weak := Geo.flat_dist(b.global_position, from)
	check(weak < moved, "a weak arrow barely moves it (%.2f m)" % weak)
	await _clear()

	pl.helpers = true
	print("\n%s" % ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails > 0 else 0)
