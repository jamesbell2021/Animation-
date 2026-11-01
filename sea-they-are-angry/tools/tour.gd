extends SceneTree
## A look at the game as a player sees it: a run where every keeper is the computer's,
## rendered with the HUD, saving a frame every few seconds of game time. Use it to
## review how the game looks and reads, start to finish.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --fixed-fps 20 \
##     --script res://tools/tour.gd -- <out_dir> [start_night] [phases] [every_s] [calm|angry|raging] [speed]
## Software rendering is slow, so game time runs `speed` times faster between frames
## (physics still steps at its own rate).
## Phases are counted from the first morning (day, dusk, night, dawn, day...).
## Your Continue save is moved aside first and put back afterwards.

func _init() -> void:
	_go.call_deferred()

func _go() -> void:
	var a := OS.get_cmdline_user_args()
	var out := a[0] if a.size() > 0 else "user://tour"
	var start_night := int(a[1]) if a.size() > 1 else 1
	var phases := int(a[2]) if a.size() > 2 else 4
	var every := float(a[3]) if a.size() > 3 else 6.0
	var sea := maxi(0, ["calm", "angry", "raging"].find(a[4])) if a.size() > 4 else 1
	var speed := float(a[5]) if a.size() > 5 else 6.0
	DirAccess.make_dir_recursive_absolute(out)
	var save := ProjectSettings.globalize_path("user://run.json")
	if FileAccess.file_exists(save):
		DirAccess.rename_absolute(save, save + ".tour")
	var splash := root.get_node_or_null("StudioSplash")
	if splash:
		splash.free()
	root.get_node("Run").next_difficulty = sea
	root.get_node("Players").wanted = 1
	root.get_node("Players").helpers = true
	change_scene_to_file("res://scenes/main.tscn")
	for i in 600:
		if current_scene != null and current_scene.get("title") != null:
			break
		await process_frame
	var main = current_scene
	for i in 40:
		await process_frame
	_shot(out, "000_title")
	main.begin_run(false, 1)
	for i in 30:
		await process_frame
	var run = root.get_node("Run")
	var cyc = root.get_node("Cycle")
	if start_night > 1:
		run.night = start_night
		cyc._enter(cyc.Phase.DAY)
	# Keeper one is the computer's too (as if their person had left the LAN game).
	main.keeper_left(0)
	Engine.max_physics_steps_per_frame = 64
	Engine.time_scale = speed
	var seen := 0
	var last_phase: int = cyc.phase
	var t := 0.0
	var n := 1
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	while seen < phases and run.active:
		await process_frame
		t += get_root().get_process_delta_time()
		if cyc.phase != last_phase:
			last_phase = cyc.phase
			seen += 1
			t = every - 1.0
		if t >= every:
			t = 0.0
			_shot(out, "%03d_n%d_%s_%02d" % [n, run.night, String(cyc.phase_name()).to_lower(), int(cyc.progress() * 100.0)])
			n += 1
	Engine.time_scale = 1.0
	_shot(out, "%03d_end" % n)
	if FileAccess.file_exists(save + ".tour"):
		DirAccess.rename_absolute(save + ".tour", save)
	quit()

func _shot(dir: String, name: String) -> void:
	var img := root.get_texture().get_image()
	if img != null:
		img.save_jpg("%s/%s.jpg" % [dir, name], 0.85)
		print("SHOT ", name)
