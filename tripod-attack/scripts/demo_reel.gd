extends Node
## A choreographed 30-second gameplay take for the trailer / Instagram reel. Attached by main.gd
## when the game runs with `-- --reel`; record it with Godot's movie maker:
##   godot --path . --write-movie /tmp/reel.avi --fixed-fps 60 --resolution 1024x576 -- --reel
## Prints "EVENT <seconds> <name>" lines so the compositing script can place its captions.

var main: Node
var bf: Battlefield
var game_t := 0.0
var clock_on := false


func _ready() -> void:
	main = get_parent()
	bf = main.bf
	_run()


func _process(dt: float) -> void:
	if clock_on:
		game_t += dt / maxf(Engine.time_scale, 0.01)


func _now() -> float:
	return game_t


func _event(name: String) -> void:
	print("EVENT %.2f %s" % [_now(), name])


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _until(time: float) -> void:
	var d := time - _now()
	if d > 0.0:
		await _wait(d)


func _place(tp: Tripod, x: float) -> void:
	tp.x = x
	for i in 3:
		tp.legs[i].foot.x = x + tp.rest[i]
	tp._place_bodies()


## Searches angle and power for a shot whose path crosses the leg segment a-b without passing
## through the hood (centre h, radius r). Two passes: coarse, then fine around the best.
func _aim_at(a: Vector2, b: Vector2, h: Vector2, r: float) -> float:
	var p: Player = bf.player
	var best := INF
	var best_a := -0.6
	var best_pw := 700.0
	for pass_i in 2:
		var a0 := -1.3 if pass_i == 0 else best_a - 0.03
		var a1 := -0.08 if pass_i == 0 else best_a + 0.03
		var da := 0.02 if pass_i == 0 else 0.004
		var p0 := 440.0 if pass_i == 0 else best_pw - 25.0
		var p1 := 1000.0 if pass_i == 0 else best_pw + 25.0
		var dp := 20.0 if pass_i == 0 else 4.0
		var ang := a0
		while ang <= a1:
			var pw := p0
			while pw <= p1:
				var pos := p.shoulder() + Vector2(cos(ang), sin(ang)) * 42.0 * C.PS
				var vel := Vector2(cos(ang), sin(ang)) * pw
				var tt := 0.0
				var d := INF
				var bad := false
				while tt < 3.0 and pos.y <= C.GROUND and pos.x < C.W + 50.0:
					if tt < 0.7:
						vel += vel.normalized() * 260.0 / 60.0
					vel.y += C.GRAV / 60.0
					var prev := pos
					pos += vel / 60.0
					tt += 1.0 / 60.0
					if pos.distance_to(h) < r * 1.2:
						bad = true
						break
					d = minf(d, _seg_seg(prev, pos, a, b))
					if d < 0.5:
						break
				if not bad and d < best:
					best = d
					best_a = ang
					best_pw = pw
				pw += dp
			ang += da
	p.angle = best_a
	p.power = best_pw
	return best


static func _seg_seg(p0: Vector2, p1: Vector2, a: Vector2, b: Vector2) -> float:
	var c := Geometry2D.get_closest_points_between_segments(p0, p1, a, b)
	return c[0].distance_to(c[1])


func _shoot_leg(tp: Tripod, leg: int, deadline: float) -> void:
	while not tp.dynamic and _now() < deadline:
		var lead := Vector2(-tp.speed * 0.75, 0) if tp.state == "walk" else Vector2.ZERO  # lead the walking machine
		var miss := _aim_at(tp.hip(leg) + lead, tp.knee(leg) + lead, Vector2(tp.x, tp.y) + lead, tp.r)
		print("aim miss %.1f" % miss)
		bf.player.reload = 0.0
		bf.fire()
		_event("shot")
		await _wait(1.3)
	if not tp.dynamic:
		tp.break_leg(leg)
		_event("forced_break")


func _duck_through(tp: Tripod, deadline: float) -> void:
	while tp.state == "walk" and _now() < deadline:
		await _wait(0.05)
	_event("siren")
	bf.player.duck_held = true
	while tp.alive and tp.state != "walk" and _now() < deadline + 4.0:
		await _wait(0.05)
	bf.player.duck_held = false
	_event("beam_over")


func _run() -> void:
	await _wait(0.3)
	clock_on = true
	G.reset_campaign()
	G.endless = false
	G.score = 0
	G.lives = 4
	main.start_sector(0)
	main.start_wave()
	bf.wave_info.to_spawn = 0
	_event("wave_banner")
	await _wait(0.6)
	for x in [640.0, 760.0, 900.0]:
		bf._spawn_civ(x)
	# Machine A walks in, cries out and fires; we duck, then take its front leg.
	var a: Tripod = bf.spawn_tripod({"speed": 24.0, "leg_hp": 2, "cooldown": 99.0, "siren": 1.5, "gap": 0.0}, false)
	_place(a, 780.0)
	a.cool = 1.6
	await _duck_through(a, 4.5)
	await _wait(0.5)
	_event("shooting")
	await _shoot_leg(a, 0, 11.0)
	_event("collapse_a")
	await _until(13.0)
	for x in [700.0, 980.0]:
		bf._spawn_civ(x)
	# Machine B: the big one.
	var b: Tripod = bf.spawn_tripod({"speed": 18.0, "leg_hp": 3, "cooldown": 99.0, "siren": 1.3, "gap": 0.0}, true)
	_place(b, 840.0)
	b.cool = 1.4
	await _duck_through(b, 17.0)
	await _wait(0.4)
	_event("shooting_b")
	await _shoot_leg(b, 2, 25.0)
	_event("collapse_b")
	await _until(27.5)
	# The map: Belfast taken back, the line moves east.
	G.cleared[0] = true
	main.map_anim = 0.0
	main._set_state("map")
	_event("map")
	await _until(30.5)
	main.enter_title()
	_event("title")
	await _until(33.5)
	_event("end")
	G.reset_campaign()
	G.persist()
	get_tree().quit()
