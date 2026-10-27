extends Node
## Renders screenshots for the README (needs a real renderer, not --headless):
##   godot --path . res://tests/showcase.tscn -- --out=/path/to/folder
## Sets up a battle, then frames the title, command view, first person and close-ups.

var out: String = "res://docs"


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	for i: int in range(20):
		await get_tree().process_frame
	await _shot("title")
	Game.new_game()
	Game.funds = 99999
	for spec: Array in [[3, "cannon", 3], [1, "rocket", 2], [5, "tesla", 2], [4, "rail", 3], [8, "flak", 2], [10, "cannon", 4], [11, "rocket", 2], [12, "cannon", 2], [2, "flak", 1], [9, "tesla", 1]]:
		Game.main.select(Game.pads[spec[0]])
		Game.main.act("build", spec[1])
		for l: int in range(int(spec[2]) - 1):
			Game.main.act("up", "")
	Game.main.select(null)
	Game.countdown = 999.0
	Game.wave = 4
	Game.start_wave()
	Game.spawn_q.clear()
	var specs: Array = [["oni", Vector3(-40, 0, -150)], ["kani", Vector3(120, 0, -240)], ["ryu", Vector3(-200, 0, -300)], ["tengu", Vector3(60, 100, -120)], ["daioni", Vector3(30, 0, -420)], ["oni", Vector3(220, 0, -520)]]
	for s: Array in specs:
		var k: Kaiju = Game.main.spawn_kaiju(s[0])
		k.position = s[1]
		if not k.def["air"]:
			k.position.y = -Game.depth_at(k.position.z)
		k.target_x = k.position.x
		k.hp *= 8.0
		k.max_hp = k.hp
	for i: int in range(60):
		Game.main.step(1.0 / 30.0)
	await get_tree().process_frame
	Game.banner.emit("", "", 0.01)
	await get_tree().create_timer(0.5).timeout
	await _shot("command")
	Game.rig.zoom = 0.5
	Game.rig.cmd_x = -20.0
	for i: int in range(20):
		await get_tree().process_frame
	await _shot("command_close")
	Game.main.select(Game.pads[4])
	await get_tree().create_timer(0.4).timeout
	await _shot("panel")
	Game.main.select(null)
	var t: Turret = Game.pads[3].turret
	Game.player.enter(t)
	var oni: Kaiju = _nearest(t.pad.pos)
	for i: int in range(40):
		if oni == null or not is_instance_valid(oni) or oni.dying:
			oni = _nearest(t.pad.pos)
		if oni == null:
			break
		var s2: Vector3 = Game.player.seat_pos()
		var d: Vector3 = oni.aim - s2
		Game.player.yaw = Game.yaw_to(d.x, d.z)
		Game.player.pitch = atan2(d.y, Vector2(d.x, d.z).length()) + 0.05
		Game.player.firing = i > 20
		Game.main.step(1.0 / 30.0)
		await get_tree().process_frame
	await _shot("fps_gunner")
	Game.player.firing = false
	Game.player.swap()
	oni = _nearest(t.pad.pos)
	for i: int in range(30):
		if oni == null or not is_instance_valid(oni) or oni.dying:
			oni = _nearest(t.pad.pos)
		if oni == null:
			break
		var s3: Vector3 = Game.player.seat_pos()
		var d2: Vector3 = oni.aim - s3
		Game.player.yaw = Game.yaw_to(d2.x, d2.z)
		Game.player.pitch = atan2(d2.y, Vector2(d2.x, d2.z).length())
		Game.player.firing = i % 10 == 0
		Game.main.step(1.0 / 30.0)
		await get_tree().process_frame
	await _shot("fps_rockets")
	Game.player.enter("zep")
	Game.player.pitch = -0.45
	for i: int in range(40):
		Game.main.step(1.0 / 30.0)
		await get_tree().process_frame
	await _shot("fps_airship")
	Game.player.exit_seat()
	print("showcase done")
	get_tree().quit()


func _nearest(p: Vector3) -> Kaiju:
	var best: Kaiju = null
	for k: Kaiju in Game.kaiju:
		if not k.dying and not k.def["air"] and (best == null or k.position.distance_to(p) < best.position.distance_to(p)):
			best = k
	return best


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = out.path_join(name + ".png")
	img.save_png(path)
	print("saved ", path, " at ", Time.get_ticks_msec() / 1000, "s")
