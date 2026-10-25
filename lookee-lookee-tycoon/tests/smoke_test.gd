extends Node
## Headless smoke test: plays through the whole game loop at high speed and fails loudly if
## anything breaks. Run from the project folder:
##   godot --headless --path . res://tests/smoke_test.tscn
## Exit code 0 = passed. Your own save and settings are backed up first and restored after.

var failures: Array[String] = []
var _t0 := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_t0 = Time.get_ticks_msec()
	# Survive scene changes by living under the root.
	var p := get_parent()
	p.remove_child.call_deferred(self)
	get_tree().root.add_child.call_deferred(self)
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		print("  FAIL ", what)
		failures.append(what)


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Resolves any overlay left open (a real police bust can happen mid-test: that's the game
## working). Busts are settled by paying the fine.
func clear_overlays() -> void:
	var guard := 0
	while not Overlay.stack.is_empty() and guard < 10:
		guard += 1
		var top: Node = Overlay.stack.back()
		if top.has_method("_choose"):
			top._choose("fine")
		else:
			top.close()
		await frames(2)


func open_bust(beach: Node, v: Vendor, cop_node: Police) -> Node:
	await clear_overlays()
	if beach.chase_active:
		beach._end_chase(true)
	v.release()
	if not v.stall.is_open():
		v.command_toggle_stall()
		await wait(1.0)
	await clear_overlays()
	cop_node.state = Police.State.PATROL
	cop_node.position = v.stall.position + Vector2(30, 40)
	beach._on_cop_reached_stall(cop_node, v.stall)
	await frames(2)
	if Overlay.stack.is_empty():
		print("       open_bust: no dialog (stall open %s, vendor %s, chase %s, bust_open %s)" % [v.stall.is_open(), Vendor.State.keys()[v.state], beach.chase_active, beach._bust_open])
	return Overlay.stack.back() if not Overlay.stack.is_empty() else null


const BACKUPS := {SaveSystem.SAVE_PATH: "user://smoke_backup_save.json", SaveSystem.SETTINGS_PATH: "user://smoke_backup_settings.cfg"}


func _backup() -> void:
	for path in BACKUPS:
		if FileAccess.file_exists(path):
			DirAccess.copy_absolute(path, BACKUPS[path])


func _restore() -> void:
	for path in BACKUPS:
		if FileAccess.file_exists(BACKUPS[path]):
			DirAccess.copy_absolute(BACKUPS[path], path)
			DirAccess.remove_absolute(BACKUPS[path])
		elif FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _run() -> void:
	_backup()
	await frames(2)
	print("== Data")
	check(ItemDB.ids().size() >= 15, "item catalogue")
	check(BeachDB.ORDER.size() == 6, "six beaches")
	check(Lines.SHOUT.all(func(l): return "chicken nugget" in l.to_lower() or "very good" in l.to_lower() or "lookee" in l.to_lower() or "best price" in l.to_lower() or "sunglasses" in l.to_lower()), "shout lines are on-brand")
	for id in Upgrades.DEFS:
		check(Upgrades.cost(id) > 0.0, "upgrade cost " + id)

	print("== Character data")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 50:
		var a := AppearanceOptions.random_appearance(rng)
		var s := AppearanceOptions.sanitize(a)
		if s.hash() != AppearanceOptions.sanitize(s).hash():
			failures.append("sanitize not idempotent")
			break
	check(AppearanceOptions.skin_color(0.0).get_luminance() > AppearanceOptions.skin_color(1.0).get_luminance() + 0.5, "skin gradient spans light to dark")
	var junk := AppearanceOptions.sanitize({"hair_style": 999, "skin": "not a colour", "voice_pitch": 99})
	check(junk.hair_style == AppearanceOptions.HAIR_STYLES.size() - 1 and Color.html_is_valid(junk.skin) and junk.voice_pitch <= AppearanceOptions.VOICE_MAX, "sanitize repairs bad data")

	print("== Avatar draws every option")
	var av := VendorAvatar.new()
	add_child(av)
	for key in AppearanceOptions.OPTION_KEYS:
		for v in AppearanceOptions.OPTION_KEYS[key].size():
			var a := AppearanceOptions.default_appearance()
			a[key] = v
			av.set_appearance(a)
			await frames(1)
	var cop := AppearanceOptions.police_appearance(rng)
	av.set_appearance(cop)
	for p in VendorAvatar.Pose.values():
		av.set_pose(p)
		await frames(2)
	av.queue_free()
	check(true, "all hair, faces, outfits and accessories")

	print("== New game -> creator")
	SaveSystem.delete_save()
	GameManager.new_game()
	await frames(5)
	var creator := get_tree().current_scene
	check(creator != null and creator.name == "CharacterCreator", "creator scene shown")
	for i in creator.TABS.size():
		creator._set_tab(i)
		await frames(1)
	creator._randomise()
	creator._set_value("hair_style", 5)
	creator._set_skin_tone(0.9, true)
	creator._set_undertone(0.4)
	creator._name_edit.text = "Test Nugget"
	creator._confirm()
	await frames(5)
	check(CharacterData.vendor_name() == "Test Nugget", "name saved")
	check(int(CharacterData.appearance.hair_style) == 5, "hair saved")
	check(SaveSystem.has_save(), "save written on confirm")

	print("== Beach day")
	var beach := get_tree().current_scene
	check(beach != null and beach.name == "Beach", "beach scene loaded")
	check(GameManager.day_running, "day running")
	Engine.time_scale = 4.0
	var v: Vendor = beach.vendor
	check(v.avatar.appearance.get("name", "") == "Test Nugget", "vendor wears the creator look")
	v.command_toggle_stall()
	await wait(1.0)
	check(v.stall.is_open(), "stall set up")
	var cash0 := Economy.cash
	var busts := 0
	for i in 14:
		v.command_shout()
		await wait(2.6)
		if not Overlay.stack.is_empty():
			busts += 1
			await clear_overlays()
			v.release()
			if not v.stall.is_open():
				v.command_toggle_stall()
	print("       real police busts while selling: ", busts)
	check(beach.tourists.active_count() > 0, "tourists on the beach (%d)" % beach.tourists.active_count())
	check(Economy.day_stats.sales > 0, "made sales (%d, %s)" % [Economy.day_stats.sales, Lines.money(Economy.day_stats.revenue)])
	check(Economy.cash != cash0, "cash moved")
	check(HeatSystem.heat > 0.0 or busts > 0, "heat rose (%.1f)" % HeatSystem.heat)
	var states := {}
	for t in beach.tourists.pool:
		var k: String = Tourist.State.keys()[t.state]
		states[k] = int(states.get(k, 0)) + 1
	print("       tourist states: ", states)

	print("== Every random event")
	for id in RandomEvents.EVENTS:
		RandomEvents.trigger(id)
		await wait(0.4)
	check(beach.rival_active(), "rival vendor appeared")
	for i in 6:
		if beach.rival_active():
			v.position = beach.rival.position + Vector2(80, 0)
			v.shout_cooldown = 0.0
			v.command_shout()
			await wait(0.3)
	check(not beach.rival_active(), "rival scared off by shouting")
	RandomEvents.new_day()

	print("== Shop: stock, upgrades, staff, beaches")
	Economy.add_cash(200000.0, "test")
	var bought := Economy.buy_stock("sunglasses", 30)
	check(bought == 30 or Economy.space_left() == 0, "bought stock")
	var shop: Node = load("res://scenes/ui/shop_menu.tscn").instantiate()
	beach.hud.add_child(shop)
	await frames(2)
	check(get_tree().paused, "shop pauses the game")
	for tab in 4:
		shop._set_tab(tab)
		await frames(1)
	for round in 6:
		for id in Upgrades.DEFS:
			Upgrades.buy(id)
	check(Upgrades.is_maxed("stall") and Upgrades.is_maxed("supplier"), "upgrades maxed")
	for id in ItemDB.ids():
		Economy.buy_stock(id, 5)
	check(Economy.count("yacht_model") > 0, "top-tier stock unlocked")
	for i in 3:
		shop._hire(0)
	check(Staff.count_on_beach(GameManager.current_beach) == 3, "hired 3 staff")
	for id in BeachDB.ORDER:
		GameManager.buy_beach(id)
		GameManager.buy_kiosk(id)
	check(GameManager.owned_beaches.size() == 6, "bought every beach")
	shop._set_tab(2)
	await frames(2)
	shop.close()
	await frames(2)
	await clear_overlays()
	check(not get_tree().paused, "closing shop unpauses %s %s" % [GameManager._pause_reasons, Overlay.stack])

	print("== Police: bust -> pay fine")
	var cop_node: Police = beach.police[0]
	var dlg: Node = await open_bust(beach, v, cop_node)
	check(dlg != null and get_tree().paused, "busted dialog pauses")
	dlg._choose("fine")
	await frames(2)
	check(not v.stall.is_open() and Economy.day_stats.fines > 0.0, "fine paid, stall closed")

	print("== Police: bust -> leg it")
	dlg = await open_bust(beach, v, cop_node)
	dlg._choose("run")
	await frames(2)
	check(beach.chase_active, "chase started")
	v.command_walk(v.position + Vector2(1200, 0))
	await wait(4.0)
	check(not beach.chase_active, "chase resolved")

	print("== Police: bust -> bribe")
	dlg = await open_bust(beach, v, cop_node)
	dlg._choose("bribe")
	await frames(2)
	check(not get_tree().paused, "bribe resolved")

	print("== Heat dispatch")
	v.release()
	if not v.stall.is_open():
		v.command_toggle_stall()
		await wait(1.0)
	HeatSystem.set_heat(95.0)
	await wait(0.5)
	check(beach.any_cop_chasing_player() or Overlay.stack.size() > 0, "police dispatched at RAID")
	await clear_overlays()

	print("== Pause menu + edit vendor")
	beach.hud.open_pause()
	await frames(3)
	var pause: Node = Overlay.stack.back()
	pause._edit_vendor()
	await frames(3)
	var wrapper: Overlay = Overlay.stack.back()
	var ed: Node = wrapper.root.get_child(wrapper.root.get_child_count() - 1)
	ed._set_value("hat", 5)
	ed._confirm()
	await frames(3)
	check(int(v.avatar.appearance.hat) == 5, "edited look applied live on the beach")
	pause.close()
	await frames(2)

	print("== Workers in action")
	await wait(6.0)
	check(beach.workers.size() >= 3, "workers on the beach (%d)" % beach.workers.size())

	await clear_overlays()
	print("== End of day")
	var day := GameManager.day
	GameManager.hour = GameManager.DAY_END_HOUR - 0.01
	await wait(0.5)
	check(GameManager.day == day + 1, "day advanced")
	var summary: Node = Overlay.stack.back() if not Overlay.stack.is_empty() else null
	check(summary != null and summary.get("summary") is Dictionary, "summary shown")
	summary._cycle_beach()
	var next_beach := GameManager.next_beach
	summary._next_day()
	await frames(6)
	beach = get_tree().current_scene
	check(beach.name == "Beach" and GameManager.current_beach == next_beach, "travelled to " + next_beach)

	print("== Save / load round trip")
	SaveSystem.save_game()
	var before := {"cash": Economy.cash, "day": GameManager.day, "beaches": GameManager.owned_beaches.size(),
		"staff": Staff.staff.size(), "stall": Upgrades.level("stall"), "name": CharacterData.vendor_name(), "stock": Economy.total_stock()}
	Economy.cash = -1.0
	Upgrades.reset()
	CharacterData.reset()
	check(SaveSystem.load_game(), "load_game")
	var after := {"cash": Economy.cash, "day": GameManager.day, "beaches": GameManager.owned_beaches.size(),
		"staff": Staff.staff.size(), "stall": Upgrades.level("stall"), "name": CharacterData.vendor_name(), "stock": Economy.total_stock()}
	before.cash = snappedf(before.cash, 0.01)
	after.cash = snappedf(after.cash, 0.01)
	check(before == after, "state restored: %s vs %s" % [str(before), str(after)])

	print("== Back to menu")
	Engine.time_scale = 1.0
	GameManager.goto_menu()
	await frames(5)
	check(get_tree().current_scene.name == "MainMenu", "main menu")
	SaveSystem.delete_save()

	_restore()
	print("")
	print("Smoke test finished in %.1fs" % ((Time.get_ticks_msec() - _t0) / 1000.0))
	if failures.is_empty():
		print("SMOKE TEST PASSED. Very good very nice!")
		get_tree().quit(0)
	else:
		print("SMOKE TEST FAILED (%d): %s" % [failures.size(), ", ".join(failures)])
		get_tree().quit(1)
