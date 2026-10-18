# Screenshot tool. Renders the real scene and saves a PNG; needs a display (or Xvfb).
# godot --path sea-they-are-angry --script res://tools/screenshot.gd -- out.png <phase 0-3> [focused 0/1] [close]
# Headless containers: install mesa-vulkan-drivers, then wrap in: xvfb-run -a -s "-screen 0 1600x900x24"
extends SceneTree
func _init() -> void:
	_go.call_deferred()
func _go() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	var phase := int(args[1])
	var focused := args.size() > 2 and args[2] == "1"
	if FileAccess.file_exists("user://run.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://run.json"))
	root.size = Vector2i(1600, 900)
	change_scene_to_file("res://scenes/main.tscn")
	for i in 3:
		await process_frame
	var main = current_scene
	var cyc = root.get_node("Cycle")
	cyc._enter(phase)
	cyc.running = false
	main._apply_lighting(phase, 0.0)
	var lamp = main.lighthouse.lamp
	if phase == 1 or phase == 2:
		lamp._set_state(1)
	var bscript = load("res://scenes/enemies/bloated.gd")
	for pos in [Vector3(-7.5, 0, 9.5), Vector3(10.5, 0, 2.0), Vector3(-3, 0, -11), Vector3(5.5, 0, 9.0)]:
		var b = bscript.new()
		b.lighthouse = main.lighthouse
		b.position = pos
		main.get_node("Enemies").add_child(b)
	main.player.global_position = Vector3(3.0, 0.1, 4.5)
	main.player.camera = null
	main.player._aim = Vector3(0.5, 0, 1).normalized()
	if focused:
		lamp.set_operator(main.player)
		lamp.mode = 1
		lamp._apply_mode()
	for i in 50:
		lamp.yaw = deg_to_rad(150.0)
		await process_frame
	if args.size() > 3 and args[3] == "close":
		var hud = main.hud
		hud.visible = false
		var b2 = bscript.new()
		b2.lighthouse = main.lighthouse
		b2.position = main.player.global_position + Vector3(1.6, 0, -1.2)
		main.get_node("Enemies").add_child(b2)
		b2.process_mode = Node.PROCESS_MODE_DISABLED
		b2.global_position.y = Terrain.height_at_v(b2.global_position)
		b2.rotation.y = 0.9
		main.player._aim = Vector3(0, 0, 1)
		main.player.rotation.y = main.player.aim_yaw()
		main.player.set_physics_process(false)
		var c := Camera3D.new()
		main.add_child(c)
		var at: Vector3 = main.player.global_position + Vector3(0.8, 1.0, -0.4)
		c.look_at_from_position(at + Vector3(0.6, 1.6, 4.2), at, Vector3.UP)
		c.fov = 40.0
		c.current = true
		for i in 10:
			await process_frame
	var img := root.get_texture().get_image()
	if img == null:
		quit()
		return
	img.save_png(out)
	print("saved ", out)
	quit()
