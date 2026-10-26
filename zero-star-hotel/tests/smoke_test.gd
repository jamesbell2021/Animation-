extends Node
## Headless smoke test: plays several hotel days at high speed with a simple "bot" manager
## (sends help to every incident, squashes cockroaches, buys upgrades, hires staff, books the
## inspector) and fails loudly if anything breaks. Run from the project folder:
##   godot --headless --path . res://tests/smoke_test.tscn
## Exit code 0 = passed. Your own save and settings are backed up first and restored after.

var DAYS := 4
var SPEED := 12.0

var failures: Array[String] = []
var kinds_seen := {}
var _logged_day := -1
var _t0 := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Optional: -- <days> <speed> for longer balance runs.
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1:
		DAYS = int(args[0])
	if args.size() >= 2:
		SPEED = float(args[1])
	_t0 = Time.get_ticks_msec()
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
	for id in Upgrades.DEFS:
		check(Upgrades.cost(id) > 0.0 and Upgrades.CATEGORIES.has(Upgrades.DEFS[id].category), "upgrade " + id)
	for s in [1, 2, 3]:
		check(Hotel.requirements(s).size() >= 5, "star %d checklist" % s)
	for t in GuestTypes.TYPES:
		check(GuestTypes.lines_for(t).size() > 0, "guest lines " + t)
	check(Lines.HOTEL_NAMES.size() > 3, "hotel names")

	print("== Avatars draw every guest and staff type")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var av := VendorAvatar.new()
	add_child(av)
	for t in GuestTypes.TYPES:
		av.set_appearance(AppearanceOptions.guest_appearance(t, rng, false))
		await frames(1)
		av.set_appearance(AppearanceOptions.guest_appearance(t, rng, true))
		await frames(1)
	for role: String in ["cleaner", "handyman", "security", "lifeguard", "barman", "inspector", "thief"]:
		av.set_appearance(AppearanceOptions.staff_appearance(role, rng))
		await frames(1)
	for pose in VendorAvatar.Pose.values():
		av.set_pose(pose)
		await frames(1)
	av.queue_free()
	check(true, "all guest/staff looks and poses")

	print("== Menu -> new game")
	SaveSystem.delete_save()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	await frames(5)
	var menu := get_tree().current_scene
	check(menu != null and menu.name == "MainMenu", "main menu shown")
	menu._ask_name()
	await frames(2)
	menu._random_name()
	menu._name_edit.text = "Smoke Towers"
	menu._start()
	await frames(6)
	check(get_tree().current_scene.name == "HotelWorld", "hotel scene loaded (%s)" % get_tree().current_scene.name)
	check(Hotel.name_of_hotel == "Smoke Towers", "hotel named")
	check(Hotel.stars == 0, "starts at zero stars")
	check(SaveSystem.has_save(), "save written")

	print("== Menus open")
	var world: Node = get_tree().current_scene
	world.hud.open_shop()
	await frames(2)
	var shop: Node = Overlay.stack.back()
	for i in 4:
		shop._set_tab(i)
		await frames(1)
	shop.close()
	await frames(1)
	world.hud.open_pause()
	await frames(2)
	Overlay.stack.back().close()
	await frames(1)
	var panel = world.RoomPanel.new()
	panel.world = world
	panel.room = 0
	world.hud.add_child(panel)
	await frames(2)
	panel.close()
	panel = world.RoomPanel.new()
	panel.world = world
	panel.room = 7
	world.hud.add_child(panel)
	await frames(2)
	panel.close()
	await frames(1)
	check(Overlay.stack.is_empty() and not get_tree().paused, "menus close and unpause")
	world.hud._on_room_price()
	world.hud._on_pint_price()
	check(Economy.room_price_index != 1 or Economy.pint_price_index != 0, "price buttons cycle")
	Economy.room_price_index = 1
	Economy.pint_price_index = 0

	for d in DAYS:
		await _play_day()
		if failures.size() > 8:
			break

	print("== Save / load")
	var cash := Economy.cash
	var day := GameManager.day
	SaveSystem.save_game()
	Economy.cash = 1.0
	GameManager.day = 99
	check(SaveSystem.load_game(), "load")
	check(is_equal_approx(Economy.cash, cash) and GameManager.day == day, "state restored")
	print("== Incident kinds seen: ", kinds_seen.keys())
	check(kinds_seen.size() >= 2, "several kinds of trouble happened")

	Engine.time_scale = 1.0
	_restore()
	print("\n%d failures, %.1fs" % [failures.size(), (Time.get_ticks_msec() - _t0) / 1000.0])
	for f in failures:
		print("  - ", f)
	if failures.is_empty():
		print("SMOKE TEST PASSED")
	get_tree().quit(1 if failures.size() > 0 else 0)


## One day with a bot manager. Returns once the next day's scene is loaded.
func _play_day() -> void:
	var world: Node = get_tree().current_scene
	var day := GameManager.day
	print("== Day %d  (cash %s, %s, rep %.1f)" % [day, Lines.money(Economy.cash), Lines.STAR_NAMES[Hotel.stars], Hotel.reputation()])
	_shop_bot()
	if not GameManager.toast.is_connected(_on_toast):
		GameManager.toast.connect(_on_toast)
	Engine.time_scale = SPEED
	var guard := 0.0
	var max_guests := 0
	while GameManager.day == day and guard < GameManager.DAY_LENGTH_SECONDS * 1.5:
		await wait(0.5)
		guard += 0.5 * SPEED
		if is_instance_valid(world) and int(GameManager.hour) == 19 and _logged_day != day:
			_logged_day = day
			print("       19:00 groups %d (arrived %d), free rooms %d, booking chance %.2f" % [Hotel.groups.size(), Hotel.groups.filter(func(g): return g.get("arrived", false)).size(), Hotel.free_rooms().size(), Hotel.booking_chance()])
		if not is_instance_valid(world) or world.is_queued_for_deletion():
			break
		max_guests = maxi(max_guests, world.guests.size())
		for inc in world.incidents:
			kinds_seen[inc.kind] = true
			if not inc.done and inc.claimed_by == null:
				world.dispatch_manager(inc)
		for room in world.roaches:
			for c in world.roaches[room]:
				if is_instance_valid(c) and randf() < 0.3:
					world.squash(c)
					break
		# Settle anything that popped up (only the day summary should).
		for o in Overlay.stack.duplicate():
			if o.has_method("_next"):
				pass
	Engine.time_scale = 1.0
	check(GameManager.day == day + 1, "day %d ended" % day)
	check(max_guests > 0, "day %d had guests (max %d on screen)" % [day, max_guests])
	await frames(2)
	var summary: Node = null
	for o in Overlay.stack:
		if o.has_method("_next"):
			summary = o
	check(summary != null, "day %d summary shown" % day)
	if summary:
		var s: Dictionary = summary.summary
		print("       profit %s, rooms %s, bar %s (%d pints), reviews %d, verdict \"%s\"" % [Lines.money(float(s.profit)), Lines.money(float(s.get("rooms", 0.0))),
			Lines.money(float(s.get("bar", 0.0))), int(s.get("pints", 0)), s.reviews_today.size(), s.verdict])
		if not s.inspection.is_empty():
			print("       INSPECTION: ", s.inspection)
		await frames(3)
		summary._next()
	await frames(6)
	check(get_tree().current_scene != null and get_tree().current_scene.name == "HotelWorld" and get_tree().current_scene != world, "day %d -> next day scene (%s)" % [day, get_tree().current_scene.name if get_tree().current_scene else "none"])


## Spend like a sensible player: work down the next star's checklist, then more rooms.
func _shop_bot() -> void:
	var wants := {
		0: [["hire", "cleaner"], ["pool"], ["signs"], ["fence"]],
		1: [["reception"], ["bar"], ["pest_control"], ["hire", "security"], ["hire", "lifeguard"], ["floors"], ["hire", "barman"]],
		2: [["floors"], ["soundproofing"], ["safes"], ["hire", "handyman"], ["reception"], ["bar"], ["pool"], ["floors"]],
	}
	var target_q: int = [1, 2, 3, 3][Hotel.stars]
	var target_rooms: int = [4, 6, 10, 12][Hotel.stars]
	for step in 6:
		var did := false
		if Hotel.stars == 0 and Hotel.open_count() < 4:
			for i in Hotel.ROOMS:
				if Hotel.can_open(i) == "" and Economy.cash > Hotel.open_cost() + 40.0:
					did = Hotel.open_room(i) or did
					break
		for i in Hotel.ROOMS:
			if Hotel.rooms[i].open and int(Hotel.rooms[i].quality) < target_q and Economy.can_afford(Hotel.quality_cost(i) + 60.0):
				did = Hotel.upgrade_room(i) or did
		for w in wants.get(Hotel.stars, []):
			if w[0] == "hire":
				if Staff.count_role(w[1]) == 0 and Staff.can_hire(w[1]) == "" and Economy.cash > Staff.hire_cost(w[1]) + 100.0:
					did = not Staff.hire(w[1]).is_empty() or did
			elif Upgrades.block_reason(w[0]) == "" and Economy.cash > Upgrades.cost(w[0]) + 60.0:
				did = Upgrades.buy(w[0]) or did
		if Hotel.open_count() < target_rooms:
			for i in Hotel.ROOMS:
				if Hotel.can_open(i) == "" and Economy.cash > Hotel.open_cost() + 120.0:
					did = Hotel.open_room(i) or did
					break
		if not did:
			break
	if Hotel.request_inspection():
		print("       bot booked the inspector for day ", Hotel.inspection_day)
	var todo := Hotel.requirements().filter(func(r): return not r[1]).map(func(r): return str(r[0]))
	print("       shop bot: cash %s, rooms %d, staff %d, to do: %s" % [Lines.money(Economy.cash), Hotel.open_count(), Staff.staff.size(), ", ".join(todo)])


func _on_toast(text: String, _kind: String) -> void:
	if text.begins_with("Inspector saw"):
		print("       ", text)
