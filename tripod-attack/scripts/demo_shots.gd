extends Node
## Drives the game through every screen and saves screenshots. Started by main.gd when the game
## is run with `-- --shots=/some/dir` (used by tools/screenshots.sh under a virtual display).

var out_dir := ""
var main: Node


func _ready() -> void:
	main = get_parent()
	_run()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("shot ", name)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true).timeout


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	await _wait(2.5)
	await _shot("01-title")
	main.typed = 100.0
	main.bf.attract_t = 100.0
	await _wait(3.0)
	await _shot("02-title-attract")
	main.start_campaign(true)
	await _wait(0.8)
	await _shot("03-map")
	main.press()
	await _wait(1.5)
	await _shot("04-intro")
	main.typed = 100.0
	main.press()
	await _wait(3.0)
	await _shot("05-play-wave1")
	# A machine in range, hit in the leg until it falls.
	var bf: Battlefield = main.bf
	for tp in bf.tripods:
		tp.gone = true
	bf.wave_info.to_spawn = 0
	var tp: Tripod = bf.spawn_tripod(bf.wave_config(), false)
	tp.x = 620.0
	tp.cool = 999.0
	for i in 3:
		tp.legs[i].foot.x = tp.x + tp.rest[i]
	await _wait(0.5)
	await _shot("06-tripod")
	tp.break_leg(0)
	await _wait(0.6)
	await _shot("07-falling")
	await _wait(2.0)
	await _shot("08-collapsed")
	# Siren then Heat-Ray, with the player ducking.
	for t2 in bf.tripods:
		t2.gone = true
	bf.wave_info.to_spawn = 0
	tp = bf.spawn_tripod(bf.wave_config(), false)
	tp.x = 560.0
	tp.cool = 0.0
	for i in 3:
		tp.legs[i].foot.x = tp.x + tp.rest[i]
	await _wait(0.8)
	await _shot("09-siren")
	bf.player.duck_held = true
	while tp.state != "fire":
		await _wait(0.05)
	await _wait(0.5)
	await _shot("10-heatray")
	bf.player.duck_held = false
	await _wait(1.5)
	# Sector cleared.
	G.wave = 3
	bf.wave_info.to_spawn = 0
	bf.wave_info.clear_t = 0.0
	for t2 in bf.tripods:
		t2.alive = false
	await _wait(3.5)
	await _shot("11-cleared")
	main.state_t = 5.0
	main.press()
	await _wait(0.5)
	await _shot("12-map-after")
	# Game over by overrun.
	main.press()
	main.typed = 100.0
	main.press()
	G.lives = 1
	for t2 in bf.tripods:
		t2.gone = true
	bf.wave_info.to_spawn = 0
	tp = bf.spawn_tripod(bf.wave_config(), false)
	tp.x = 351.0
	tp.cool = 999.0
	await _wait(3.5)
	await _shot("13-gameover")
	print("demo done")
	get_tree().quit()
