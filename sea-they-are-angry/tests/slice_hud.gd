extends SceneTree
# Run: godot --headless --path sea-they-are-angry --script res://tests/slice_hud.gd
# The HUD's sea mood line (the hidden Anger in words) and the red pulse round the
# screen when the light is in danger. And how much of it shows: full, slim and off (the
# hud_mode key), the panels that shrink themselves in full, and folding one by a click
# while the game is paused.

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

## The hud_mode key: down and up again at once (a tap), or just one of the two. Returns
## what the HUD's message line said in the frames after (other messages come and go).
func _hud_key(down: bool, up: bool) -> String:
	for pressed in [true, false]:
		if (pressed and down) or (not pressed and up):
			var ev := InputEventKey.new()
			ev.keycode = KEY_H
			ev.pressed = pressed
			Input.parse_input_event(ev)
	var said := ""
	for i in 3:
		await process_frame
		var line := String(current_scene.hud._msg_label.text)
		if not said.contains(line):
			said += " " + line
	return said

## A left click at a point of the HUD's canvas.
func InputSetup_hud_click() -> bool:
	return bool(root.get_node("InputSetup").hud_click)

func _click(at: Vector2) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = root.get_final_transform() * at
		ev.global_position = ev.position
		Input.parse_input_event(ev)
		for i in 2:
			await process_frame

func _pause_menu(main: Node) -> Node:
	for c in main.get_children():
		if c.get_script() != null and c.get_script().resource_path.ends_with("/ui/pause.gd"):
			return c
	return null

func _go() -> void:
	if FileAccess.file_exists("user://run.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://run.json"))
	# Everything showing, whatever was last saved.
	root.get_node("Settings").hud_mode = 0
	var pl = root.get_node("Players")
	pl.wanted = 1
	pl.helpers = false
	change_scene_to_file("res://scenes/main.tscn")
	for i in 600:
		if current_scene != null and current_scene.get("player") != null and current_scene.player != null:
			break
		await process_frame
	await _wait(5)
	var main = current_scene
	var hud = main.hud
	var Ang = root.get_node("Anger")
	root.get_node("Cycle").running = false
	main.spawner.process_mode = Node.PROCESS_MODE_DISABLED
	var words := []
	for v in [0, 4, 7, 10]:
		Ang.value = v
		await process_frame
		await process_frame
		words.append(hud._mood_label.text)
	print("   moods: ", words)
	check(words == ["The sea is quiet.", "The sea is restless.", "The sea is angry.", "The sea wants the light."], "the sea's mood follows its anger")
	Ang.value = 0
	await process_frame

	# The layout: a card per keeper with bars, the store in words players use, and the
	# jobs list inside the screen.
	root.get_node("Stock").set_amount("seaweed", 7)
	root.get_node("Stock").set_amount("arrows", 0)
	await process_frame
	await process_frame
	check(hud._cards.size() == main.players.size() and hud._cards[0]["bars"]["hp"].value == main.player.hp, "a card for each keeper (%d), health as a bar" % hud._cards.size())
	check(hud._stock_label.text.contains("Kelp 7") and not hud._stock_label.text.contains("Arrows"), "the store: " + hud._stock_label.text)
	var vp: Vector2 = hud._jobs_panel.get_viewport_rect().size
	var jr: Rect2 = hud._jobs_panel.get_global_rect()
	check(hud._jobs_panel.visible and jr.position.x >= 0.0 and jr.end.x <= vp.x + 0.5, "the jobs list sits inside the screen (%.0f..%.0f of %.0f)" % [jr.position.x, jr.end.x, vp.x])
	var cr: Rect2 = hud._cards[0]["panel"].get_global_rect()
	check(cr.end.y <= vp.y + 0.5 and cr.position.y > vp.y * 0.6, "the keepers' cards sit at the bottom (%.0f..%.0f)" % [cr.position.y, cr.end.y])
	check(hud._phase_label.text.begins_with("Day 1"), "the heading: " + hud._phase_label.text)
	check(not hud._danger.visible, "all well: no danger pulse")
	main.lighthouse.hp = int(main.lighthouse.max_hp * 0.2)
	await process_frame
	await process_frame
	var a: float = hud._danger_mat.get_shader_parameter("strength")
	check(hud._danger.visible and a > 0.1, "the lighthouse badly hurt: the screen's edge pulses red (%.2f)" % a)
	var lo := 9.0
	var hi := 0.0
	for i in 70:
		await process_frame
		var v: float = hud._danger_mat.get_shader_parameter("strength")
		lo = minf(lo, v)
		hi = maxf(hi, v)
	check(hi - lo > 0.25, "and it beats (%.2f to %.2f)" % [lo, hi])
	main.lighthouse.hp = main.lighthouse.max_hp
	main.lighthouse.lamp._set_state(main.lighthouse.lamp.State.GUTTERING)
	await process_frame
	await process_frame
	check(hud._danger.visible, "the lamp guttering: it pulses too")
	main.lighthouse.lamp._set_state(main.lighthouse.lamp.State.BURNING)
	await process_frame
	await process_frame
	check(not hud._danger.visible, "burning again: it stops")
	# The debug overlay (a debug build, as tests are): F10 and the testing keys.
	var dbg = null
	for c in main.get_children():
		if c.get_script() != null and c.get_script().resource_path.ends_with("debug_overlay.gd"):
			dbg = c
	check(dbg != null, "debug builds have the F10 overlay")
	var Stk = root.get_node("Stock")
	var wood: int = Stk.get_amount("driftwood")
	var fuel: float = main.lighthouse.lamp.fuel
	main.lighthouse.lamp.fuel = 50.0
	for key in [KEY_F10, KEY_F7, KEY_F6]:
		var ev := InputEventKey.new()
		ev.keycode = key
		ev.pressed = true
		Input.parse_input_event(ev)
		await process_frame
		await process_frame
	check(dbg._panel.visible and dbg.report().contains("Anger") and dbg.report().contains("spawn queue"), "F10 shows the numbers behind the run")
	check(Stk.get_amount("driftwood") == wood + 5 and main.lighthouse.lamp.fuel > 59.0, "F7 stocks the store, F6 tops up the lamp")
	# Off-screen creatures: a chevron at the edge of the screen points at them.
	var far_one = load("res://scenes/enemies/bloated.gd").new()
	far_one.lighthouse = main.lighthouse
	far_one.position = Vector3(Terrain.HOLM_C.x + 6.0, Terrain.HOLM_HEIGHT + 0.3, Terrain.HOLM_C.y)
	main.get_node("Enemies").add_child(far_one)
	far_one.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	await process_frame
	var ms: Array = hud.markers.marks
	var vr: Rect2 = hud.markers.get_viewport_rect()
	check(ms.size() == 1 and vr.grow(-10.0).has_point(ms[0][0]) and Vector2.from_angle(ms[0][1]).x > 0.3, "a creature over on the holm: a chevron at the right of the screen points to it (%s)" % [ms])
	far_one.global_position = main.player.global_position + Vector3(1.5, 0.0, 0.0)
	await process_frame
	await process_frame
	check(hud.markers.marks.is_empty(), "in view: no chevron")
	far_one.queue_free()

	# The end of a run: a summary of it, and a way back to the title.
	main.run_tally.merge({"ashore": 12, "beam": 7, "fall": 2}, true)
	var summary: String = hud.run_summary(4)
	check(summary.contains("held 3 nights") and summary.contains("12 came up out of the sea") and summary.contains("7 burned in the beam"), "the run's summary: " + summary.replace("\n", " / "))

	# The weapons across the bottom, numbered for their keys.
	var bar = hud.weapon_bar
	root.get_node("Run").arms[0].append("bow")
	root.get_node("Stock").set_amount("arrows", 7)
	await process_frame
	check(bar.shown() and bar.ammo_text("bow") == "7" and bar.ammo_text("shotgun") == "", "the weapon bar: the longbow with 7 arrows, no shotgun yet")
	# Every line said (the camera's keys can be said in the same moment, playing alone).
	var said := [""]
	var on_msg := func(t: String) -> void: said[0] = (said[0] + " | " + t) if t.contains("shotgun") or said[0] == "" else said[0]
	root.get_node("Events").message.connect(on_msg)
	Input.action_press("weapon_3")
	await physics_frame
	await physics_frame
	Input.action_release("weapon_3")
	await process_frame
	check(main.player.arsenal.weapon != "shotgun" and String(said[0]).contains("shotgun"), "3 with no shotgun to hand says where it is: " + String(said[0]))
	Input.action_press("weapon_2")
	await physics_frame
	await physics_frame
	Input.action_release("weapon_2")
	check(main.player.arsenal.weapon == "bow", "2 takes up the longbow")
	root.get_node("Events").message.disconnect(on_msg)

	# How it feels: the screen shakes with a blow and settles; a heavy blow freezes the
	# world for a moment; the shake can be turned off.
	var F = root.get_node("Feel")
	var Set = root.get_node("Settings")
	F.force_live = true
	F.shake(0.6)
	await process_frame
	await process_frame
	var cam: Camera3D = main.camera_director.main_camera if main.get("camera_director") != null else get_root().get_camera_3d()
	var shook: float = absf(cam.h_offset) + absf(cam.v_offset)
	check(F.trauma > 0.3 and shook > 0.0, "a blast shakes the screen (trauma %.2f, lens %.3f)" % [F.trauma, shook])
	for i in 90:
		await process_frame
	check(F.trauma == 0.0 and absf(cam.h_offset) < 0.001, "and it settles")
	Set.shake = false
	F.shake(0.6)
	check(F.trauma == 0.0, "Settings: shake off, no shake")
	Set.shake = true
	F.hitstop(0.05)
	check(Engine.time_scale < 0.1, "a heavy blow: the world stops for a moment (time %.2f)" % Engine.time_scale)
	for i in 30:
		await process_frame
	check(is_equal_approx(Engine.time_scale, 1.0), "and goes on")
	F.force_live = false

	# ---- How much shows ----
	var R = root.get_node("Run")
	var Stk2 = root.get_node("Stock")
	hud.folds.clear()

	# Folding by a click, when the mouse is free: the pause menu up.
	var light_head: Control = hud._heads["light"]["head"]
	var light_mark: Label = hud._heads["light"]["mark"]
	check(not hud.mouse_free() and light_mark.visible, "in play with the mouse: the headings show they fold")
	await _click(light_head.get_global_rect().get_center())
	check(hud.folded("light") and not hud._lh_row.visible, "a click on a heading in play folds it")
	check(main.player._swing_t <= 0.0 and not InputSetup_hud_click(), "and the keeper doesn't swing for it")
	await _click(light_head.get_global_rect().get_center())
	check(not hud.folded("light") and hud._lh_row.visible, "a click again opens it")
	var pm = _pause_menu(main)
	pm.toggle()
	await process_frame
	await process_frame
	check(paused and hud.mouse_free() and light_mark.visible and light_mark.text == hud.FOLD_OPEN, "paused: the headings show they fold (%s)" % light_mark.text)
	var open_h: float = hud._light_card.size.y
	await _click(light_head.get_global_rect().get_center())
	await process_frame
	check(hud.folded("light") and hud._phase_label.is_visible_in_tree() and not hud._lh_row.visible and not hud._mood_label.visible and light_mark.text == hud.FOLD_SHUT,
		"a click on the top-left card's heading folds it to the clock line")
	check(hud._light_card.size.y < open_h * 0.5, "and the card is a line high (%.0f, from %.0f)" % [hud._light_card.size.y, open_h])
	await _click(light_head.get_global_rect().get_center())
	check(not hud.folded("light") and hud._lh_row.visible and hud._mood_label.visible, "a click again unfolds it")
	await _click((hud._heads["store"]["head"] as Control).get_global_rect().get_center())
	check(hud.folded("store") and hud._store_name.visible and not hud._stock_box.visible, "the store folds to its name")
	await _click((hud._heads["keeper0"]["head"] as Control).get_global_rect().get_center())
	check(hud._cards.size() == 1 and hud._cards[0]["short"], "a keeper's card folds to its one line")
	await _click((hud._heads["keeper0"]["head"] as Control).get_global_rect().get_center())
	check(not hud._cards[0]["short"], "and opens again")
	pm.toggle()
	await process_frame
	check(not paused and not hud.mouse_free(), "resumed: the mouse is the keeper's again")

	# A new game, with the computer's helpers; what was folded by hand stays folded.
	var old_id: int = main.get_instance_id()
	pl.wanted = 1
	pl.helpers = true
	root.get_node("Run").quick_start = true
	change_scene_to_file("res://scenes/main.tscn")
	for i in 900:
		await process_frame
		if current_scene != null and current_scene.get_instance_id() != old_id and current_scene.get("player") != null and current_scene.player != null:
			break
	await _wait(5)
	main = current_scene
	hud = main.hud
	root.get_node("Cycle").running = false
	main.spawner.process_mode = Node.PROCESS_MODE_DISABLED
	for i in 3:
		await process_frame
	check(hud.folded("store") and hud._store_name.is_visible_in_tree(), "the store, folded by hand, is still folded in the next game")
	# The helpers stand still, so nothing they do puts a message up in the middle of this.
	for k in main.players:
		if k.ai and k.has_node("KeeperAI"):
			k.get_node("KeeperAI").process_mode = Node.PROCESS_MODE_DISABLED
	hud.folds.clear()
	var me: Player = main.player
	var mate: Player = main.players[1]
	me.hunger = 90.0
	me.warmth = 90.0
	Stk2.set_amount("driftwood", 5)
	for i in 3:
		await process_frame

	# Full, on the first day: everything, the helpers' cards one line each.
	check(hud.mode() == hud.FULL and hud._light_card.visible and hud._sub_label.visible and hud._mood_label.visible and hud._lamp_label.visible
		and hud._store_panel.visible and hud._jobs_panel.visible and hud.weapon_bar.visible, "full: the clock, the sea, the light, the store, the jobs, the weapons")
	check(hud._job_labels[0].visible and hud._keys_label.visible and hud._jobs_title.text == "Jobs for the first days", "the first day: the jobs in full, the keys under them")
	check(hud._cards.size() == 3 and not hud._cards[0]["short"] and hud._cards[0]["bars"].has("fed"), "a person's card is the full one")
	var own_h: float = hud._cards[0]["panel"].size.y
	var mate_h: float = hud._cards[1]["panel"].size.y
	check(mate.ai and hud._cards[1]["short"] and not hud._cards[1]["bars"].has("fed") and hud._cards[1]["name"].text == mate.keeper_name()
		and hud._cards[1]["bars"]["hp"].value == mate.hp and mate_h < own_h * 0.6, "a helper's card is one line: name and health (%.0f high, by %.0f)" % [mate_h, own_h])
	mate.downed = true
	await process_frame
	await process_frame
	check(hud._cards[1]["down"].visible and hud._cards[1]["down"].text == "DOWN", "a helper down: DOWN on their line")
	mate.downed = false

	# Fed and warm: only once they run low, and never in the town.
	var rows: Dictionary = hud._cards[0]["rows"]
	check(not rows["fed"].visible and not rows["warm"].visible and rows["hp"].visible, "fed and warm above half: only the health bar")
	me.hunger = 40.0
	await process_frame
	await process_frame
	check(rows["fed"].visible and not rows["warm"].visible and absf(hud._cards[0]["bars"]["fed"].value - 40.0) < 1.0 and float(hud._need_flash["0fed"]) > 0.0, "hungry: the fed bar comes in, flashing")
	me.warmth = 30.0
	await process_frame
	await process_frame
	check(rows["warm"].visible, "cold: the warm bar too")
	R.chapter = 2
	await process_frame
	await process_frame
	check(not rows["fed"].visible and not rows["warm"].visible, "in Kirkhaven: neither, ever")
	R.chapter = 1
	me.hunger = 90.0
	me.warmth = 90.0

	# The store: what there is any of, and what just changed.
	for k in ["scrap", "seaweed", "seeds", "food", "eggs", "notes", "poison", "dirty_fuel"]:
		Stk2.set_amount(k, 3)
	Stk2.set_amount("diesel", 0)
	hud._now += 10.0
	await process_frame
	await process_frame
	var store: String = hud._stock_label.text
	check(store.contains("Scrap 3") and not store.contains("Diesel") and store.find("Driftwood") < store.find("Scrap") and store.find("Scrap") < store.find("Kelp"), "the store shows what there is, in its usual order: " + store)
	Stk2.set_amount("scrap", 0)
	await process_frame
	await process_frame
	check(hud._stock_label.text.contains("Scrap 0"), "the last scrap spent: it shows at none for a moment")
	hud._now += hud.STOCK_FRESH + 1.0
	await process_frame
	await process_frame
	check(not hud._stock_label.text.contains("Scrap"), "then it goes: " + hud._stock_label.text)
	var store_r: Rect2 = hud._store_panel.get_global_rect()
	check(store_r.end.x <= vp.x + 0.5 and store_r.position.x > vp.x * 0.5, "the store sits at the top right, as wide as what's in it (%.0f..%.0f)" % [store_r.position.x, store_r.end.x])
	R.chapter = 2
	await process_frame
	await process_frame
	store = hud._stock_label.text
	var rock_only := false
	for word in ["Kelp", "Seeds", "Food", "Gull eggs", "Notes", "Rat poison", "Dirty fuel"]:
		rock_only = rock_only or store.contains(word)
	check(store.contains("Driftwood") and not rock_only, "in Kirkhaven the rock's stores are left out: " + store)
	R.chapter = 1
	await process_frame

	# The jobs: in full until three are done or the first night is over, then one line.
	R.jobs = ["gather", "repair"]
	await process_frame
	check(hud._job_labels[0].visible and not hud.folded("jobs"), "two jobs done: still the whole list")
	var list_h: float = hud._jobs_panel.size.y
	R.jobs = ["gather", "repair", "eat"]
	for i in 3:
		await process_frame
	check(hud._jobs_panel.visible and not hud._job_labels[0].visible and not hud._keys_label.visible and hud._jobs_title.text == "Jobs: 3 of 8 done"
		and hud._jobs_panel.size.y < list_h * 0.3, "three done: it folds to a line: %s (%.0f high, from %.0f)" % [hud._jobs_title.text, hud._jobs_panel.size.y, list_h])
	jr = hud._jobs_panel.get_global_rect()
	check(jr.end.x <= vp.x + 0.5 and jr.position.y >= hud._store_panel.get_global_rect().end.y, "and sits under the store, inside the screen")
	R.jobs = ["gather"]
	R.night = 2
	await process_frame
	check(hud.folded("jobs") and not hud._job_labels[0].visible, "the first night over: one line too")
	hud.set_folded("jobs", false)
	await process_frame
	check(hud._job_labels[0].visible and not hud._keys_label.visible, "opened by hand it shows the list again, without the keys (they're for the first day)")
	hud.folds.clear()
	R.night = 1
	var every: Array = []
	for j in load("res://scenes/systems/jobs.gd").list():
		every.append(j[0])
	R.jobs = every
	await process_frame
	check(not hud._jobs_panel.visible, "every job done: the list goes")
	R.jobs = ["gather"]
	await process_frame

	# The key: full, slim, off and round again; said in a message, and kept.
	check(Set.key_name("hud_mode") == "H" and InputMap.has_action("hud_mode"), "H shows more or less (and can be changed in Settings)")
	var named := false
	for row in Set.REBINDABLE:
		named = named or row[0] == "hud_mode"
	check(named, "it is among the keys Settings can change")
	var told: String = await _hud_key(true, true)
	check(hud.mode() == hud.SLIM and Set.hud_mode == 1 and told.contains("HUD: slim") and told.contains("[H]"), "H: slim, and it says so:" + told)
	check(hud._light_card.visible and hud._phase_label.is_visible_in_tree() and hud._lh_row.visible and hud._fuel_row.visible
		and not hud._sub_label.visible and not hud._mood_label.visible and not hud._lamp_label.visible, "slim: the clock and the two light bars, no weather or mood")
	check(hud._camp_label.visible == hud._camp_alarm, "the camp's line only when something's wrong there")
	check(not hud._store_panel.visible and not hud._jobs_panel.visible and not hud._jobs_box.visible, "no store, no jobs, no keys")
	check(hud._cards.size() == 1 and hud._cards[0]["keeper"] == me and hud._cards[0]["short"] and not hud._cards[0]["bars"].has("fed"), "the keeper's own card, as a health bar; no helpers' cards")
	check(hud.weapon_bar.shown() and hud._prompt_label.is_visible_in_tree() and hud._msg_label.is_visible_in_tree(), "the weapons, the use prompt and messages stay")
	main.lighthouse.lamp._set_state(main.lighthouse.lamp.State.GUTTERING)
	await process_frame
	await process_frame
	check(hud._lamp_label.visible and hud._lamp_label.text.contains("GUTTERING"), "the lamp guttering: its line comes back, in slim")
	main.lighthouse.lamp._set_state(main.lighthouse.lamp.State.OFF)
	mate.downed = true
	await process_frame
	await process_frame
	check(hud._cards.size() == 2 and hud._cards[1]["down"].text == "DOWN", "a helper down shows, in slim, till they're up")
	mate.downed = false
	await process_frame
	var fresh = load("res://autoload/settings.gd").new()
	fresh._defaults = Set._defaults.duplicate()
	fresh._load()
	check(fresh.hud_mode == 1, "slim is saved and read back")
	fresh.free()
	told = await _hud_key(true, true)
	hud.warn("A warning.")
	hud.report("A night held.", ["And its log."], 3.0)
	await process_frame
	await process_frame
	check(hud.mode() == hud.OFF and told.contains("HUD: off"), "H again: off:" + told)
	check(not hud._light_card.visible and not hud._store_panel.visible and not hud._jobs_panel.visible and not hud._keepers_box.visible and not hud.weapon_bar.visible,
		"off: no cards, no store, no jobs, no weapon bar")
	check(hud._warn_label.visible and hud._report_label.visible and hud._msg_label.is_visible_in_tree() and hud._prompt_label.is_visible_in_tree() and hud.markers.is_visible_in_tree(),
		"warnings, the dawn's log, messages, the use prompt and the arrows at the screen's edge stay")
	await _hud_key(true, true)
	check(hud.mode() == hud.FULL and hud._store_panel.visible and hud._cards.size() == 3, "H again: full")
	# Held for half a second: everything back, whatever was folded.
	await _hud_key(true, true)
	hud.set_folded("light", true)
	R.jobs = ["gather", "repair", "eat"]
	await _hud_key(true, false)
	var t0 := Time.get_ticks_msec()
	told = ""
	while Time.get_ticks_msec() - t0 < 3000 and hud.mode() != hud.FULL:
		await process_frame
		told = hud._msg_label.text
	check(Time.get_ticks_msec() - t0 >= 400, "(not before it has been held a while: %d ms)" % (Time.get_ticks_msec() - t0))
	check(hud.mode() == hud.FULL and not hud.folded("light") and hud._lh_row.visible and hud._job_labels[0].visible and told.contains("everything"),
		"H held: full, the folded card open, the jobs out in full: " + told)
	await _hud_key(false, true)
	check(hud.mode() == hud.FULL, "and letting go doesn't step it on")
	hud.folds.clear()
	Set.hud_mode = 0
	Set.save()

	print("\n%s" % ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails > 0 else 0)
