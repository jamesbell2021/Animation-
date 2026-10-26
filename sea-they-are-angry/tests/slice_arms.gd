extends SceneTree
# Run: godot --headless --path sea-they-are-angry --script res://tests/slice_arms.gd
# The shed's weapons: the workbench, switching what's in hand, the longbow, the
# double-barrelled shotgun and its few cartridges, the flamer, petrol bombs, rat poison
# at a trap cairn, and what's kept in the save.

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
	var Run = root.get_node("Run")
	var p: Player = main.player
	p.camera = null
	Cyc.running = false
	var arms = p.arsenal

	# ---- the shed ----
	var shed = null
	for s in get_nodes_in_group("structures"):
		if s.get_script().get_global_name() == "Shed":
			shed = s
	check(Stk.get_amount("shells") == 10 and Stk.get_amount("poison") == 4, "a box of 10 cartridges and 4 tins of rat poison in the shed")
	p.global_position = shed.global_position + Vector3(0.2, 0.1, -1.9)
	await _wait(3)
	check(p.interact_prompt().contains("workbench"), "at the shed: " + p.interact_prompt())
	Stk.set_all({"driftwood": 10, "scrap": 6, "seaweed": 4, "bio": 4, "shells": 10, "poison": 4})
	var rows: Array = shed.menu_rows(p)
	check(rows[0]["text"].contains("shotgun") and rows[1]["text"].contains("flamer") and rows[2]["text"].contains("longbow"), "the workbench: the shotgun, the weed burner, a longbow, arrows, bombs")
	check(arms.weapon == "hook" and not arms.available("bow"), "a keeper starts with the boathook only")
	rows[0]["do"].call()
	check(arms.carries("shotgun") and arms.weapon == "shotgun", "takes the shotgun off the wall, in hand")
	rows = shed.menu_rows(p)
	rows[1]["do"].call()
	check(Run.flamer_rigged and arms.carries("flamer") and Stk.get_amount("scrap") == 4 and Run.flamer_fuel == 50.0, "rigs the weed burner as a flamer (2 scrap), half a tank")
	rows = shed.menu_rows(p)
	for r in rows:
		if r["text"].begins_with("Make a longbow"):
			r["do"].call()
	check(arms.carries("bow") and Stk.get_amount("driftwood") == 7 and Stk.get_amount("seaweed") == 3, "makes a longbow (3 driftwood, a kelp)")
	shed.make(shed.ARROWS_COST, "arrows", shed.ARROWS_MADE)
	shed.make(shed.BOMBS_COST, "bombs", shed.BOMBS_MADE)
	check(Stk.get_amount("arrows") == 5 and Stk.get_amount("bombs") == 2 and Stk.get_amount("bio") == 3, "whittles 5 arrows, fills 2 petrol bombs (a bio, a kelp)")

	# ---- switching ----
	arms.select("hook")
	arms.cycle(1)
	check(arms.weapon == "bow", "next: the longbow")
	arms.cycle(1)
	arms.cycle(1)
	arms.cycle(1)
	check(arms.weapon == "bombs", "then the shotgun, the flamer, the petrol bombs")
	arms.cycle(1)
	check(arms.weapon == "hook", "and round to the boathook")
	arms.select("shotgun")
	check(arms._models["shotgun"].visible and not p._hook_holder.visible and arms._tank.visible, "the gun in hand, the hook put by, the flamer's tank on the back")
	# From here the test works the weapons itself: the keeper's own controls stay quiet.
	p.set_physics_process(false)

	# ---- the shotgun ----
	Cyc._enter(Cyc.Phase.NIGHT)
	Cyc.running = false
	var spot := Terrain.beach_point(0, 0.75)
	p.global_position = spot + Vector3(0.0, 0.3, 0.0)
	await _wait(5)
	var b = _bloated(main, spot + Vector3(0.0, 0.0, 0.0))
	await _wait(120)
	b.speed = 0.0
	var to: Vector3 = b.global_position - p.global_position
	to.y = 0.0
	p.global_position = b.global_position - to.normalized() * 3.0 + Vector3(0.0, 0.3, 0.0)
	p._aim = to.normalized()
	var hp0: int = b.hp
	var shells0: int = Stk.get_amount("shells")
	arms.tick(0.016, true, true)
	await _wait(2)
	check(Run.barrels == 1 and (not is_instance_valid(b) or b.hp < hp0), "one barrel at 3 m tears into a Bloated (%d -> %d)" % [hp0, b.hp if is_instance_valid(b) else 0])
	var main_tally: Dictionary = main._tally
	arms._cd = 0.0
	arms.tick(0.016, true, true)
	await _wait(2)
	check(Run.barrels == 0, "the second barrel")
	check(not is_instance_valid(b) or b.hp <= 0, "two barrels close in finish it")
	for i in 120:
		arms.tick(1.0 / 60.0, false, false)
		await physics_frame
	check(int(main_tally.get("shot", 0)) >= 1, "and the dawn tally counts it as shot")
	check(Run.barrels == 2 and Stk.get_amount("shells") == shells0 - 2, "it breaks open and loads two from the box (%d left)" % Stk.get_amount("shells"))
	Stk.set_all({"shells": 0, "bio": 3, "arrows": 5, "bombs": 2, "poison": 4, "seaweed": 3})
	Run.barrels = 0
	arms._cd = 0.0
	arms.tick(0.016, true, true)
	check(Run.barrels == 0 and arms._reload_t <= 0.0, "no cartridges left: click")
	await _clear()

	# ---- the longbow ----
	arms.select("bow")
	arms._cd = 0.0
	var b2 = _bloated(main, spot)
	await _wait(120)
	b2.speed = 0.0
	to = b2.global_position - p.global_position
	to.y = 0.0
	p.global_position = b2.global_position - to.normalized() * 9.0 + Vector3(0.0, 0.3, 0.0)
	await _wait(2)
	p._aim = (b2.global_position - p.global_position) * Vector3(1, 0, 1)
	p._aim = p._aim.normalized()
	hp0 = b2.hp
	arms.tick(0.016, true, true)
	check(arms.draw >= 0.0 and arms.move_mult() < 1.0, "hold to draw (and walk slower)")
	for i in 60:
		arms.tick(1.0 / 60.0, false, true)
	check(arms.draw == 1.0, "a full draw")
	arms.tick(0.016, false, false)
	check(Stk.get_amount("arrows") == 4 and arms.draw < 0.0, "let go: an arrow flies")
	for i in 60:
		await physics_frame
		if not is_instance_valid(b2) or b2.hp < hp0:
			break
	check(not is_instance_valid(b2) or b2.hp <= hp0 - 30, "and strikes it 9 m off, hard (%d -> %d)" % [hp0, b2.hp if is_instance_valid(b2) else 0])
	await _clear()

	# ---- the flamer ----
	arms.select("flamer")
	var b3 = _bloated(main, spot)
	await _wait(120)
	b3.speed = 0.0
	to = b3.global_position - p.global_position
	to.y = 0.0
	p.global_position = b3.global_position - to.normalized() * 3.5 + Vector3(0.0, 0.3, 0.0)
	p._aim = to.normalized()
	await _wait(2)
	hp0 = b3.hp
	var fuel0: float = Run.flamer_fuel
	var burning_seen := false
	for i in 40:
		arms.tick(1.0 / 60.0, i == 0, true)
		await physics_frame
		if is_instance_valid(b3) and b3.burning > 0.0:
			burning_seen = true
	check(arms._flaming and arms._flame.emitting, "hold: the flamer roars")
	check(burning_seen, "what's in the stream stops and burns")
	check(not is_instance_valid(b3) or b3.hp < hp0 - 15, "and it's deadly (%d -> %d in 2/3 s)" % [hp0, b3.hp if is_instance_valid(b3) else 0])
	check(Run.flamer_fuel < fuel0, "it drinks from the tank (%.0f -> %.0f)" % [fuel0, Run.flamer_fuel])
	check(not is_instance_valid(b3) or b3.on_fire > 0.0 or b3.hp <= 0, "and sets it alight")
	await _wait(3)
	check(not arms._flaming, "let go (no tick): the flame goes out")
	Run.flamer_fuel = 0.0
	var bio0: int = Stk.get_amount("bio")
	for i in 120:
		arms.tick(1.0 / 60.0, false, true)
	check(Run.flamer_fuel > 85.0 and Stk.get_amount("bio") == bio0 - 1, "a dry tank refills from the store's bio (and burns on)")
	arms.tick(0.016, false, false)
	await _clear()

	# ---- petrol bombs ----
	arms.select("bombs")
	var b4 = _bloated(main, spot)
	await _wait(120)
	b4.speed = 0.0
	hp0 = b4.hp
	var pb = load("res://scenes/systems/petrol_bomb.gd").new()
	pb.thrower = p
	pb.from = p.global_position + Vector3(0.0, 1.6, 0.0)
	pb.to = b4.global_position
	main.add_child(pb)
	await _wait(60)
	check(get_nodes_in_group("fire_pools").size() == 1, "a petrol bomb smashes into a pool of fire")
	check(not is_instance_valid(b4) or (b4.hp < hp0 and b4.on_fire > 0.0), "everything near it alight (%d -> %d)" % [hp0, b4.hp if is_instance_valid(b4) else 0])
	await _wait(120)
	check(not is_instance_valid(b4) or b4.hp < hp0 - 30, "and burning in the pool (%d)" % (b4.hp if is_instance_valid(b4) else 0))
	arms._cd = 0.0
	var n0: int = Stk.get_amount("bombs")
	arms.tick(0.016, true, true)
	check(Stk.get_amount("bombs") == n0 - 1, "thrown from the hand, one fewer in store")
	await _wait(80)
	await _clear()

	# ---- rat poison ----
	# (Let the fire die down first.)
	for i in 600:
		if get_nodes_in_group("fire_pools").is_empty():
			break
		await physics_frame
	var slot = null
	for s in get_nodes_in_group("trap_slots"):
		if s.index == 0:
			slot = s
	var kinds := []
	for r in slot.menu_rows():
		kinds.append(r["text"].split(" (")[0])
	check(kinds.has("Rat poison"), "rat poison at a cairn: %s" % str(kinds))
	slot.arm("poison")
	check(slot.kind == "poison" and Stk.get_amount("poison") == 3, "laid as bait for a tin and a kelp")
	var b5 = _bloated(main, slot.global_position + Vector3(0.3, 0.0, 0.0))
	for i in 200:
		await physics_frame
		if is_instance_valid(b5) and b5.poisoned > 0.0:
			break
	check(is_instance_valid(b5) and b5.poisoned > 0.0 and slot.uses == 2, "a Bloated eats it and is poisoned")
	hp0 = b5.hp
	await _wait(240)
	check(not is_instance_valid(b5) or b5.hp < hp0 - 8, "it sickens (%d -> %d in 4 s)" % [hp0, b5.hp if is_instance_valid(b5) else 0])
	await _clear()

	# ---- cartridges wash up; the save ----
	Run.night = 3
	main._wash_up_shells()
	var tin = null
	for n in get_nodes_in_group("interactable"):
		if n is ScavengePoint and n.kind == "shells":
			tin = n
	check(tin != null and tin.amount == 3, "a tin of 3 cartridges washes up on the third dawn")
	root.get_node("SaveSys").save_run()
	var d: Dictionary = root.get_node("SaveSys").load_run()
	check(d["arms"][0].has("shotgun") and d["arms"][0].has("bow") and bool(d["flamer_rigged"]), "what each keeper carries is saved")
	arms.take_away("shotgun")
	check(not arms.carries("shotgun") and Arsenal_holder("shotgun") == -1, "hung back up, it's in the shed for anyone")

	# ---- difficulty ----
	var sp = main.spawner
	var counts := []
	for lv in 3:
		Run.difficulty = lv
		counts.append(sp.group_size(4))
	check(counts[0] < counts[1] and counts[2] > counts[1], "fewer creatures on a calm sea, more on a raging one %s" % str(counts))
	Run.difficulty = 0
	Stk.set_all({})
	arms.give("shotgun")
	Run.barrels = 2
	arms._cd = 0.0
	arms._reload_t = 0.0
	arms.tick(0.016, true, true)
	check(Run.barrels == 2 and arms.available("bombs") and arms._ammo("arrows") > 0, "calm sea: the barrels never empty, bombs and arrows never run out")
	var fl0: int = p.flares()
	p._fire_flare()
	check(p.flares() == fl0, "nor flares")
	p.hp = 100
	p.take_damage(20)
	check(p.hp == 88, "and blows land softer (20 -> %d)" % (100 - p.hp))
	Run.difficulty = 2
	p.hp = 100
	p.take_damage(20)
	check(p.hp == 74, "a raging sea: harder (20 -> %d)" % (100 - p.hp))
	Run.next_difficulty = 2
	Run.start_new()
	check(Run.difficulty == 2 and Stk.get_amount("shells") == 6 and Stk.get_amount("poison") == 2, "and fewer cartridges and less poison in the shed")
	root.get_node("SaveSys").save_run()
	check(int(root.get_node("SaveSys").load_run()["difficulty"]) == 2, "the difficulty is kept with the run")
	Run.next_difficulty = 1
	Run.difficulty = 1

	pl.helpers = true
	print("\n%s" % ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails > 0 else 0)

func Arsenal_holder(w: String) -> int:
	var Run = root.get_node("Run")
	for i in Run.arms.size():
		if Run.arms[i].has(w):
			return i
	return -1
