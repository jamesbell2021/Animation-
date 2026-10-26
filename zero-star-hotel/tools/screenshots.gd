extends Node
## Takes screenshots of every screen for checking the art and for store pages.
##   godot --path . res://tools/screenshots.tscn -- <output_dir>
## (needs a display; on a headless Linux box wrap it in xvfb-run). Uses a fresh game and
## deletes the save afterwards.

var out_dir := "user://screens"
var _n := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var p := get_parent()
	p.remove_child.call_deferred(self)
	get_tree().root.add_child.call_deferred(self)
	_run.call_deferred()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	_n += 1
	var path := "%s/%02d_%s.png" % [out_dir, _n, name]
	img.save_png(path)
	print("saved ", path)


func close_all() -> void:
	while not Overlay.stack.is_empty():
		(Overlay.stack.back() as Node).close()
		await frames(2)


func _run() -> void:
	SaveSystem.delete_save()
	await wait(4.0)  # splash + audio warm-up
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	await wait(1.5)
	await shot("menu")
	var menu := get_tree().current_scene
	menu._ask_name()
	await wait(0.4)
	await shot("name_hotel")
	menu._start()
	await wait(1.0)

	var world := get_tree().current_scene
	await close_all()
	await shot("day1_morning")
	world.camera.set_zoom_level(0.5)
	await wait(0.3)
	await shot("whole_hotel")
	# Fast-forward into the afternoon so guests arrive.
	Engine.time_scale = 8.0
	while GameManager.hour < 16.5:
		await wait(0.25)
	Engine.time_scale = 1.0
	world.camera.set_zoom_level(1.0)
	world.camera.position = Vector2(1300, 600)
	await wait(0.5)
	await shot("afternoon")
	# A towel war on the terrace.
	var at_pool: Array = world.guests.filter(func(x): return x.is_present() and not x.is_busy())
	if at_pool.size() >= 2:
		at_pool[0].lounger = world.claim_lounger(at_pool[0])
		world._start_lounger_war(at_pool[1], at_pool[0])
	world.camera.position = Vector2(1600, 600)
	await wait(0.6)
	await shot("pool")
	# Stage some chaos for the camera.
	var g: Array = world.guests.filter(func(x): return x.is_present())
	if g.size() >= 2:
		world._start_incident("fight", g[0].position, [g[0], g[1]])
	world._start_incident("music", HotelLayout.room_door(0), [], 0)
	Hotel.add_roaches(1, 4)
	await wait(1.0)
	world.camera.position = Vector2(700, 520)
	await wait(0.3)
	await shot("chaos")
	Engine.time_scale = 8.0
	while GameManager.hour < 22.5:
		await wait(0.25)
		await close_all()
	Engine.time_scale = 1.0
	world.camera.set_zoom_level(0.62)
	await wait(0.4)
	await shot("night")

	Economy.earn(20000.0, "other")
	world.hud.open_shop()
	await wait(0.4)
	var shop: Node = Overlay.stack.back()
	for i in 4:
		shop._set_tab(i)
		await wait(0.3)
		await shot("shop_%s" % shop.TABS[i].to_lower())
	shop.close()
	await frames(3)
	var panel = world.RoomPanel.new()
	panel.world = world
	panel.room = 0
	world.hud.add_child(panel)
	await wait(0.4)
	await shot("room_panel")
	panel.close()
	world.hud.open_pause()
	await wait(0.4)
	await shot("pause")
	await close_all()

	# A smartened-up hotel: everything bought.
	for id in Upgrades.DEFS:
		while not Upgrades.is_maxed(id):
			if not Upgrades.buy(id):
				break
	for i in Hotel.ROOMS:
		Hotel.open_room(i)
		while int(Hotel.rooms[i].quality) < 3 and Hotel.upgrade_room(i):
			pass
		Hotel.clean(i)
	Hotel.stars = 3
	Hotel.stars_changed.emit(3)
	await wait(0.5)
	world.camera.set_zoom_level(0.5)
	await wait(0.3)
	await shot("three_star_hotel")

	GameManager.hour = GameManager.DAY_END_HOUR - 0.01
	await wait(0.8)
	await shot("day_summary")
	SaveSystem.delete_save()
	get_tree().quit()
