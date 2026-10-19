extends Node
## Headless smoke test, attached by main.gd when the game is started with `-- --smoke-test`:
##   godot --headless --fixed-fps 60 --path . -- --smoke-test
## Drives the game through the campaign flow and checks the mechanics. Exits non-zero on failure.

var failures := 0
var main: Node


func check(cond: bool, what: String) -> void:
	if cond:
		printerr("  ok   ", what)
	else:
		failures += 1
		printerr("  FAIL ", what)


func physics_frame_wrap() -> void:
	await get_tree().physics_frame


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ready() -> void:
	main = get_parent()
	_run()


func _run() -> void:
	await frames(5)
	check(main.state == "title", "starts on the title")
	await frames(60)
	check(main.bf.tripods.size() >= 2, "attract mode walks tripods")
	main.start_campaign(true)
	check(main.state == "map", "campaign opens the map")
	main.press()
	check(main.state == "intro", "map leads to the briefing")
	main.typed = 100.0
	main.press()
	check(main.state == "play", "briefing leads to play")
	await frames(30)
	var bf: Battlefield = main.bf
	check(bf.tripods.size() >= 1, "wave 1 spawned a tripod")
	# Rockets at a machine in range.
	for tp in bf.tripods:
		tp.gone = true
	bf.wave_info.to_spawn = 0
	await frames(2)
	var tp: Tripod = bf.spawn_tripod(bf.wave_config(), false)
	tp.x = 620.0
	tp.cool = 999.0
	for i in 3:
		tp.legs[i].foot.x = tp.x + tp.rest[i]
	await frames(2)
	var hits_before: int = G.score
	var a := -1.1
	var shots := 0
	while a < 0.0 and not tp.dynamic:
		bf.player.angle = a
		bf.player.power = 700.0 + randf() * 200.0
		bf.player.reload = 0.0
		bf.fire()
		shots += 1
		await frames(90)
		a += 0.06
	check(G.score > hits_before, "rockets scored hits (%d shots)" % shots)
	check(tp.dynamic, "a leg broke and the machine collapsed")
	await frames(240)
	check(tp.crushed, "the hood hit the ground")
	var hood_y: float = tp.hood.global_position.y
	check(hood_y > C.GROUND - 160.0 * tp.s, "the wreck lies low (hood y %.0f)" % hood_y)
	# Siren then Heat-Ray: standing costs a life, ducking does not.
	for t2 in bf.tripods:
		t2.gone = true
	bf.wave_info.to_spawn = 0
	await frames(2)
	G.lives = 4
	tp = bf.spawn_tripod(bf.wave_config(), false)
	tp.x = 560.0
	tp.cool = 0.0
	for i in 3:
		tp.legs[i].foot.x = tp.x + tp.rest[i]
	var seen := {}
	for i in 240:
		seen[tp.state] = true
		await get_tree().physics_frame
	check(seen.has("siren") and seen.has("pause") and seen.has("fire"), "siren, a pause, then fire (%s)" % str(seen.keys()))
	check(G.lives == 3, "standing in the beam cost a life (lives %d)" % G.lives)
	tp.cool = 0.0
	bf.player.inv = 0.0
	bf.player.duck_held = true
	var dodged_before: int = G.stats.dodged
	await frames(240)
	bf.player.duck_held = false
	check(G.lives == 3, "ducking under the beam kept the life")
	check(G.stats.dodged == dodged_before + 1, "the dodge was counted")
	# Leg hardening: a damaged leg reseals one hit when left alone.
	for t2 in bf.tripods:
		t2.gone = true
	bf.wave_info.to_spawn = 0
	await frames(2)
	tp = bf.spawn_tripod(bf.wave_config(), false)
	tp.x = 700.0
	tp.cool = 999.0
	tp.legs[0].hp = tp.legs[0].max
	tp._damage_leg(0, tp.knee(0), Vector2(300, 0))
	var hp_after_hit: int = tp.legs[0].hp
	await frames(int((tp.harden_time + 0.5) * 60))
	check(hp_after_hit == tp.legs[0].max - 1 and tp.legs[0].hp == tp.legs[0].max, "a leg left alone reseals (hp %d -> %d)" % [hp_after_hit, tp.legs[0].hp])
	# Double sweep: the beam goes out to the shelter and comes back.
	for t2 in bf.tripods:
		t2.gone = true
	await frames(2)
	var dcfg := bf.wave_config()
	dcfg.double = true
	tp = bf.spawn_tripod(dcfg, false)
	tp.x = 600.0
	tp.cool = 0.0
	for i in 3:
		tp.legs[i].foot.x = tp.x + tp.rest[i]
	var min_gx := INF
	var returned := false
	for i in 420:
		if tp.state == "fire":
			min_gx = minf(min_gx, tp.beam.gx)
			if tp.beam.gx > min_gx + 100.0:
				returned = true
		await physics_frame_wrap()
	check(tp.double_sweep and tp.fire_dur > 2.0 and returned, "double sweep returns (min gx %.0f)" % min_gx)
	# Difficulty: the menu cycles it and the tables are separate.
	main.enter_title()
	var items: Array = main.menu_items()
	check(items.back().label.begins_with("DIFFICULTY: NORMAL"), "title shows the difficulty item")
	main.menu_idx = items.size() - 1
	main.press()
	check(G.difficulty == 1 and main.menu_items().back().label.ends_with("VETERAN"), "fire on it cycles to VETERAN")
	check(G.setting().lives == 3 and bf.wave_config().leg_hp >= 3, "VETERAN starts with 3 lives and tougher legs")
	G.score = 777
	G.endless = false
	G.high_campaign = [0, 0, 0]
	check(G.record_score() and G.hi_campaign() == 777 and G.high_campaign[0] == 0, "high score lands in the VETERAN table only")
	G.high_campaign = [0, 0, 0]
	G.difficulty = 0
	main.start_campaign(true)
	main.press()
	main.typed = 100.0
	main.press()
	G.lives = 4
	# Soak: a few minutes of play, shooting and ducking, watching for NaNs and leaks.
	var nan := 0
	for i in 60 * 150:
		if i % 50 == 0:
			bf.player.angle = -0.3 - randf() * 0.9
			bf.player.power = 500.0 + randf() * 400.0
			bf.player.reload = 0.0
			bf.fire()
		bf.player.duck_held = bf.danger()
		G.lives = maxi(G.lives, 2)
		for t3 in bf.tripods:
			if not is_finite(t3.x) or not is_finite(t3.hood.global_position.x):
				nan += 1
		await get_tree().physics_frame
	check(nan == 0, "no NaN positions in the soak")
	check(main.state in ["play", "cleared"], "soak ended in play or cleared (%s, wave %d, score %d)" % [main.state, G.wave, G.score])
	printerr("  stats ", G.stats, " tripods ", bf.tripods.size(), " civs ", bf.civs.size(), " parts ", bf.fx.parts.size())
	# Sector cleared flow.
	if main.state == "play":
		G.wave = 3
		bf.wave_info.to_spawn = 0
		bf.wave_info.clear_t = 0.0
		bf.next_wave_t = 0.0
		bf.banner = {}
		for t3 in bf.tripods:
			t3.alive = false
		await frames(240)
	check(main.state == "cleared", "sector cleared")
	check(G.cleared[0], "Belfast marked cleared")
	main.state_t = 5.0
	main.press()
	check(main.state == "map", "back to the map")
	# Game over by overrun.
	main.press()
	main.typed = 100.0
	main.press()
	G.lives = 1
	for t3 in bf.tripods:
		t3.gone = true
	bf.wave_info.to_spawn = 0
	await frames(2)
	tp = bf.spawn_tripod(bf.wave_config(), false)
	tp.x = 351.0
	tp.cool = 999.0
	await frames(240)
	check(main.state == "gameover", "overrun with one life ends the game")
	check(G.lost_sector == 0 and not G.cleared[0], "the Martians retook Belfast")
	main.state_t = 5.0
	main.press()
	check(main.state == "title", "game over returns to the title")
	# Victory.
	for i in 10:
		G.cleared[i] = true
	G.cleared[9] = false
	G.campaign_done = false
	main.start_campaign(false)
	main.press()
	main.typed = 100.0
	main.press()
	check(G.sector_idx == 9, "last sector is Athens")
	G.wave = 3
	bf.wave_info.to_spawn = 0
	bf.wave_info.clear_t = 0.0
	for t3 in bf.tripods:
		t3.alive = false
	await frames(240)
	main.state_t = 5.0
	main.press()
	check(main.state == "victory" and G.campaign_done, "clearing Athens wins and unlocks endless")
	main.state_t = 5.0
	main.press()
	main.menu_idx = 1
	main.press()
	check(main.state == "intro" and G.endless, "endless mode starts in Belfast")
	main.typed = 100.0
	main.press()
	await frames(300)
	check(main.state == "play", "endless wave runs")
	# Audio rendered?
	var waited := 0
	while not Sfx.is_ready and waited < 3000:
		await get_tree().physics_frame
		waited += 1
	check(Sfx.is_ready, "sound board rendered (%d sounds, %d songs)" % [Sfx.sounds.size(), Sfx.music.size()])
	G.reset_campaign()
	G.campaign_done = false
	G.persist()
	printerr("RESULT: %d failure(s)" % failures)
	get_tree().quit(1 if failures > 0 else 0)
