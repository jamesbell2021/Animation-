extends Node
## Takes screenshots of every screen for checking the art and for the itch.io page.
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


func _run() -> void:
	SaveSystem.delete_save()
	await wait(4.0)  # splash + audio warm-up
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	await wait(1.5)
	await shot("menu")

	GameManager.new_game()
	await wait(0.8)
	var creator := get_tree().current_scene
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	creator.working = AppearanceOptions.random_appearance(rng)
	creator.working.hair_style = 5
	creator.working.hat = 0
	creator.working.glasses = 1
	creator.working.chain = 2
	creator.working.watch = 2
	creator.working.facial_hair = 2
	creator.working.skin_tone = 0.8
	creator.working.skin = AppearanceOptions.skin_color(0.8, 0.1).to_html(false)
	creator.working.name = "Very Nice Vince"
	creator._name_edit.text = creator.working.name
	creator._update_preview(false)
	creator._set_tab(0)
	await wait(0.6)
	await shot("creator_skin")
	creator._set_tab(1)
	await wait(0.4)
	await shot("creator_hair")
	creator._set_tab(5)
	creator._say_it()
	await wait(0.4)
	await shot("creator_extras")
	creator._confirm()
	await wait(2.0)

	var beach := get_tree().current_scene
	Engine.time_scale = 3.0
	beach.vendor.command_toggle_stall()
	await wait(1.0)
	for i in 6:
		beach.vendor.command_shout()
		await wait(2.5)
		while not Overlay.stack.is_empty():
			var top: Node = Overlay.stack.back()
			if top.has_method("_choose"):
				top._choose("fine")
			else:
				top.close()
			await frames(2)
		if not beach.vendor.stall.is_open():
			beach.vendor.release()
			beach.vendor.command_toggle_stall()
	Engine.time_scale = 1.0
	beach.camera.position = beach.vendor.position + Vector2(0, -60)
	beach.camera.set_zoom_level(1.0)
	beach.vendor.command_shout()
	await wait(0.5)
	await shot("beach")
	beach.camera.set_zoom_level(0.6)
	await wait(0.3)
	await shot("beach_wide")

	Economy.add_cash(5000.0, "test")
	for id in ["stall", "stall", "stall", "parasol", "display", "display"]:
		Upgrades.buy(id)
	beach.vendor.stall.close()
	await wait(0.3)
	beach.vendor.command_toggle_stall()
	RandomEvents.trigger("cruise")
	await wait(1.5)
	beach.camera.set_zoom_level(1.1)
	beach.camera.position = beach.vendor.position + Vector2(0, -90)
	await wait(0.3)
	await shot("gazebo_event")

	beach.hud.open_shop()
	await wait(0.4)
	await shot("shop_stock")
	var shop: Node = Overlay.stack.back()
	shop._set_tab(1)
	await wait(0.3)
	await shot("shop_upgrades")
	shop._set_tab(2)
	await wait(0.3)
	await shot("shop_staff")
	shop._set_tab(3)
	await wait(0.3)
	await shot("shop_beaches")
	shop.close()
	await frames(3)

	var cop: Police = beach.police[0]
	cop.position = beach.vendor.stall.position + Vector2(40, 40)
	beach._on_cop_reached_stall(cop, beach.vendor.stall)
	await wait(0.4)
	await shot("busted")
	(Overlay.stack.back() as Node)._choose("fine")
	await frames(3)

	beach.hud.open_pause()
	await wait(0.4)
	await shot("pause")
	(Overlay.stack.back() as Node).close()
	await frames(3)

	GameManager.hour = GameManager.DAY_END_HOUR - 0.01
	await wait(0.6)
	await shot("day_summary")
	SaveSystem.delete_save()
	get_tree().quit()
