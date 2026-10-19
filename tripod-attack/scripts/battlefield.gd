class_name Battlefield
extends Node2D
## The field of battle: ground, skyline, shelter and rubble, the artilleryman, the people, the
## machines and the rockets. Runs the waves and applies the Heat-Ray.

signal sector_cleared
signal game_over

var mode := "off"                 # off, attract, play, idle (wrecks keep settling under end screens)
var attract := false
var skyline: Skyline
var fx: Particles
var player: Player
var tripods: Array = []
var civs: Array = []
var rockets: Array = []
var covers: Array = []
var stars: Array = []
var t := 0.0
var shake_amt := 0.0
var flash_amt := 0.0
var flash_color := Vec.WHITE
var slow := 0.0
var banner := {}
var wave_info := {}
var next_wave_t := 0.0
var civ_timer := 2.0
var dying := false
var game_over_t := 0.0
var battle_quote := {}
var battle_quote_t := 12.0
var attract_t := 0.0
var _spawn_root: Node2D


func _ready() -> void:
	var ground := StaticBody2D.new()
	ground.collision_layer = C.LAYER_GROUND
	ground.collision_mask = 0
	var cs := CollisionShape2D.new()
	var wb := WorldBoundaryShape2D.new()
	wb.normal = Vector2.UP
	wb.distance = -C.GROUND
	cs.shape = wb
	ground.add_child(cs)
	add_child(ground)
	skyline = Skyline.new()
	add_child(skyline)
	_spawn_root = Node2D.new()
	add_child(_spawn_root)
	fx = Particles.new()
	fx.z_index = 5
	add_child(fx)
	player = Player.new()
	player.z_index = 2
	player.fx = fx
	add_child(player)
	skyline.fx = fx
	skyline.building_fell.connect(_on_building_fell)
	for i in 70:
		stars.append([Vector2(randf() * C.W, randf() * (C.GROUND - 120.0)), 1.6 if randf() < 0.1 else 1.0])
	make_covers()


func shake(v: float) -> void:
	shake_amt = minf(28.0, shake_amt + v)


func flash(a: float, color := Vec.WHITE) -> void:
	flash_amt = maxf(flash_amt, a)
	flash_color = color


func make_covers() -> void:
	covers.clear()
	for x in [430.0, 650.0, 870.0]:
		var pts := PackedVector2Array([Vector2(x - 30, C.GROUND)])
		for i in range(1, 6):
			pts.append(Vector2(x - 30 + i * 10, C.GROUND - randf_range(8, 18) * (0.5 if (i == 1 or i == 5) else 1.0)))
		pts.append(Vector2(x + 30, C.GROUND))
		covers.append({"x": x, "pts": pts})


func cover_xs() -> Array:
	return covers.map(func(c): return c.x)


func reset_field() -> void:
	for tp in tripods:
		tp.queue_free()
	for c in civs:
		c.queue_free()
	for r in rockets:
		r.queue_free()
	tripods.clear()
	civs.clear()
	rockets.clear()
	fx.clear()
	slow = 0.0
	Engine.time_scale = 1.0
	dying = false
	banner = {}
	battle_quote = {}
	player.drag = {}
	player.duck_held = false
	player.reload = 0.0
	player.inv = 0.0
	player.burn_t = 0.0


func start_sector(idx: int) -> void:
	skyline.build(EuroMap.SECTORS[idx].key, idx + 1)
	make_covers()
	reset_field()
	attract = false
	player.visible = true
	player.show_preview = false
	mode = "idle"
	G.wave = 0


func set_attract(on: bool) -> void:
	attract = on
	if on:
		reset_field()
		skyline.build("belfast", 1)
		make_covers()
		player.visible = false
		mode = "attract"
		attract_t = 0.0
		for x in [700.0, 980.0]:
			var tp := spawn_tripod({"speed": 26.0, "leg_hp": 3, "cooldown": 6.0, "siren": 1.5, "gap": 0.0}, false)
			tp.x = x
			tp.cool = randf_range(3, 6)
			tp.s = tp.s  # keep
			for i in 3:
				tp.legs[i].foot.x = x + tp.rest[i]
			tp.attract = true


# --- waves --------------------------------------------------------------------------------------

func wave_config() -> Dictionary:
	var d := G.setting()
	var cfg: Dictionary
	if G.endless:
		var n := G.wave
		cfg = {"count": 2 + n / 2, "speed": 20.0 + n * 1.5, "leg_hp": 2 + n / 3, "cooldown": maxf(2.4, 6.5 - n * 0.3),
			"siren": maxf(0.7, 1.4 - n * 0.05), "big": n >= 2 and n % 2 == 0, "gap": maxf(2.5, 6.0 - n * 0.3), "civ_rate": 1.0 + n * 0.08,
			"double": n >= int(d.double_from_wave)}
	else:
		var si := G.sector_idx
		var wi := G.wave - 1
		cfg = {"count": 2 + wi + si / 4, "speed": 15.0 + si * 1.6 + wi * 2.0, "leg_hp": 2 + si / 2, "cooldown": maxf(3.0, 8.0 - si * 0.5),
			"siren": maxf(0.8, 1.6 - si * 0.08), "big": si >= int(d.big_from) and wi == C.WAVES_PER_SECTOR - 1, "gap": maxf(3.0, 7.0 - si * 0.4),
			"civ_rate": 1.0, "double": si >= int(d.double_from_sector)}
	cfg.count += int(d.count)
	cfg.speed *= float(d.speed)
	cfg.leg_hp += int(d.leg_hp)
	cfg.cooldown *= float(d.cooldown)
	cfg.siren = maxf(0.6, cfg.siren * float(d.siren))
	cfg.gap *= float(d.gap)
	cfg.pause = d.pause
	cfg.harden = float(d.harden)
	return cfg


func spawn_tripod(cfg: Dictionary, big: bool) -> Tripod:
	var tp := Tripod.new()
	tp.fx = fx
	tp.field = self
	tp.z_index = 1
	_spawn_root.add_child(tp)
	tp.setup({"x": C.W + 130.0 + randf() * 100.0, "scale": 1.3 if big else randf_range(0.92, 1.08),
		"speed": cfg.speed * randf_range(0.9, 1.1) * (0.8 if big else 1.0), "leg_hp": cfg.leg_hp + (2 if big else 0),
		"cooldown": cfg.cooldown * (0.85 if big else 1.0), "siren": cfg.siren, "big": big, "double": cfg.get("double", false),
		"pause": cfg.get("pause", [0.3, 1.0]), "harden": cfg.get("harden", 4.0)})
	tp.collapsed.connect(_on_tripod_collapsed)
	tp.hood_slammed.connect(_on_hood_slammed)
	tp.reached_sandbags.connect(_on_reached_sandbags)
	tripods.append(tp)
	return tp


func start_wave() -> void:
	G.wave += 1
	var cfg := wave_config()
	wave_info = {"to_spawn": cfg.count, "timer": 0.0, "total": cfg.count, "killed": 0, "clear_t": 0.0, "cfg": cfg, "big_left": 1 if cfg.big else 0}
	next_wave_t = 0.0
	civ_timer = 2.0
	var sub: String = "ENDLESS - BELFAST" if G.endless else EuroMap.SECTORS[G.sector_idx].name + " - WAVE " + str(G.wave) + " OF " + str(C.WAVES_PER_SECTOR)
	banner = {"text": "WAVE " + str(G.wave), "sub": sub, "t": 0.0, "dur": 2.4}
	mode = "play"
	attract = false
	player.visible = true
	player.show_preview = true
	player.reload_time = float(G.setting().reload)
	Sfx.play("alarm")
	Sfx.play_music("battle")
	battle_quote_t = 12.0


func _on_wave_cleared() -> void:
	if not G.endless and G.wave >= C.WAVES_PER_SECTOR:
		_sector_cleared()
		return
	banner = {"text": "WAVE CLEARED", "sub": ("SCORE " + str(G.score)) if G.endless else "", "t": 0.0, "dur": 2.4}
	next_wave_t = 2.8
	Sfx.play("fanfare")
	var d := G.setting()
	if G.endless and G.wave % int(d.extra_life_every) == 0 and G.lives < int(d.max_lives):
		G.lives += 1
		fx.float_text(Vector2(C.W / 2, 260), "EXTRA LIFE", Vec.AMBER, 14.0, 2.0)


func _sector_cleared() -> void:
	var bonus: int = G.stats.saved * 100 + G.lives * 250 + G.stats.dodged * 50
	G.score += bonus
	G.clear_bonus = bonus
	G.cleared[G.sector_idx] = true
	if G.all_cleared():
		G.campaign_done = true
	G.record_score()
	G.persist()
	G.lives = mini(int(G.setting().max_lives), G.lives + 1)
	mode = "idle"
	player.show_preview = false
	Sfx.play("cleared")
	Sfx.play_music("map")
	sector_cleared.emit()


func begin_game_over() -> void:
	if dying:
		return
	dying = true
	game_over_t = 2.4
	Sfx.stop_music()


func silence() -> void:
	for tp in tripods:
		if tp.state in ["siren", "pause", "fire"]:
			tp.state = "walk"
			tp.beam = {}
			tp.hood_glow = 0.0
		tp.cool = 1e9


# --- the frame ----------------------------------------------------------------------------------

func _physics_process(dt: float) -> void:
	var real_dt := dt / maxf(Engine.time_scale, 0.01)
	t += dt
	if slow > 0.0:
		slow -= real_dt
		if slow <= 0.0:
			Engine.time_scale = 1.0
	shake_amt = maxf(0.0, shake_amt - real_dt * 40.0)
	flash_amt = maxf(0.0, flash_amt - real_dt * 2.5)
	match mode:
		"play":
			_update_play(dt)
		"attract":
			_update_attract(dt)
		"idle":
			for tp in tripods:
				tp.update(dt)
			_prune_tripods()
			skyline.update(dt)
			fx.update(dt)
	queue_redraw()


func _prune_tripods() -> void:
	var keep: Array = []
	for tp in tripods:
		if tp.gone:
			tp.queue_free()
		else:
			keep.append(tp)
	tripods = keep


func alive_count() -> int:
	var n := 0
	for tp in tripods:
		if tp.alive:
			n += 1
	return n


func remaining() -> int:
	return int(wave_info.get("to_spawn", 0)) + alive_count()


func danger() -> bool:
	for tp in tripods:
		if tp.alive and tp.state in ["siren", "pause", "fire"]:
			return true
	return false


func _update_play(dt: float) -> void:
	var wi := wave_info
	var cfg: Dictionary = wi.cfg
	player.update(dt)
	if not dying:
		wi.timer -= dt
		if wi.to_spawn > 0 and wi.timer <= 0.0:
			var big: bool = wi.big_left > 0 and wi.to_spawn == 1
			spawn_tripod(cfg, big)
			if big:
				wi.big_left -= 1
			wi.to_spawn -= 1
			wi.timer = cfg.gap * randf_range(0.8, 1.2)
		civ_timer -= dt * cfg.civ_rate
		if civ_timer <= 0.0 and civs.size() < 6:
			civ_timer = randf_range(2.5, 6.0)
			_spawn_civ(C.W + 20.0 if randf() < 0.6 else randf_range(380.0, 900.0))
	for tp in tripods:
		tp.update(dt)
		if not tp.beam.is_empty():
			_apply_beam(tp)
	_prune_tripods()
	_update_rockets(dt)
	var dng := danger()
	var cx := cover_xs()
	var keep: Array = []
	for c in civs:
		if c.alive:
			c.update(dt, dng, cx)
		if c.alive:
			keep.append(c)
		else:
			c.queue_free()
	civs = keep
	skyline.update(dt)
	fx.update(dt)
	if not banner.is_empty():
		banner.t += dt
		if banner.t > banner.dur:
			banner = {}
	if dying:
		game_over_t -= dt
		if game_over_t <= 0.0:
			mode = "idle"
			silence()
			game_over.emit()
		return
	if next_wave_t > 0.0:
		next_wave_t -= dt
		if next_wave_t <= 0.0:
			start_wave()
		return
	if wi.to_spawn == 0 and alive_count() == 0:
		wi.clear_t += dt
		if wi.clear_t > 2.6:
			wi.clear_t = -1e9
			_on_wave_cleared()
	battle_quote_t -= dt
	if battle_quote_t <= 0.0:
		battle_quote = {"text": Wells.battle(), "t": 7.0}
		battle_quote_t = randf_range(22.0, 35.0)
	if not battle_quote.is_empty():
		battle_quote.t -= dt
		if battle_quote.t <= 0.0:
			battle_quote = {}


func _update_attract(dt: float) -> void:
	attract_t += dt
	var alive: Array = tripods.filter(func(tp): return tp.alive)
	if alive.size() < 2 and randf() < dt * 0.5:
		var tp := spawn_tripod({"speed": 24.0, "leg_hp": 3, "cooldown": 6.0, "siren": 1.5, "gap": 0.0}, false)
		tp.attract = true
	for tp in tripods:
		if tp.alive and tp.x < 430.0 and tp.state == "walk":
			tp.x = C.W + 160.0
			for i in 3:
				tp.legs[i].foot.x = tp.x + tp.rest[i]
		tp.update(dt)
		if not tp.beam.is_empty():
			_apply_beam(tp)
	if attract_t > 8.0 and alive.size() >= 2:
		attract_t = 0.0
		alive[randi() % alive.size()].break_leg(randi() % 3)
	_prune_tripods()
	skyline.update(dt)
	fx.update(dt)


func _spawn_civ(x: float) -> void:
	var c := Civilian.new()
	c.position = Vector2(x, 0)
	c.z_index = 2
	c.reached_shelter.connect(_on_civ_saved)
	_spawn_root.add_child(c)
	civs.append(c)


func _on_civ_saved(c: Civilian) -> void:
	G.stats.saved += 1
	var pts := 400 if c.child else 200
	G.score += pts
	fx.float_text(Vector2(C.SHELTER_X + 30, C.GROUND - 60), "+" + str(pts), Vec.GREEN, 11.0)
	fx.sparks(Vector2(C.SHELTER_X, C.GROUND - 30), 6, {"speed": 60.0, "life": 0.4})
	Sfx.play("saved")


func kill_civ(c: Civilian, how: String) -> void:
	if not c.alive:
		return
	c.alive = false
	G.stats.lost += 1
	var p := Vector2(c.position.x, C.GROUND - c.h * 0.6)
	if how == "beam":
		fx.sparks(p, 26, {"speed": 160.0, "color": Vec.WHITE, "life": 0.6, "white": 1.0})
		fx.sparks(p, 10, {"speed": 90.0, "color": Vec.RED, "life": 0.5})
		Sfx.play("burn")
	else:
		fx.sparks(Vector2(c.position.x, C.GROUND - 10), 14, {"speed": 160.0, "life": 0.5})
		Sfx.play("crunch")
	fx.float_text(Vector2(c.position.x, C.GROUND - 50), "TURNED TO FIRE" if how == "beam" else "LOST", Vec.RED, 9.0, 1.2)


static func overlaps(a0: float, a1: float, b0: float, b1: float) -> bool:
	return minf(a0, a1) <= b1 and maxf(a0, a1) >= b0


func _apply_beam(tp: Tripod) -> void:
	var b: Dictionary = tp.beam
	var gx: float = b.gx
	var prev: float = b.prev
	fx.sparks(Vector2(gx, C.GROUND), 3, {"speed": 220.0, "color": Vec.RED, "life": 0.5, "spread": 1.3, "white": 0.4})
	if randf() < 0.4:
		fx.smoke(Vector2(gx, C.GROUND), 1, Color("5a1a1a"))
	for ei in skyline.elements.size():
		var e: Dictionary = skyline.elements[ei]
		if not e.ruined and e.heat <= 0.0 and not b.touched.has(ei) and overlaps(prev, gx, e.x - e.w * 0.3, e.x + e.w * 0.3):
			b.touched.append(ei)
			if randf() < 0.35:
				skyline.ignite(e)
	if attract:
		return
	if overlaps(prev, gx, C.PLAYER_X - 26.0, C.PLAYER_X + 30.0):
		if not player.duck:
			player_hit("beam")
		elif not b.dodged:
			b.dodged = true
			fx.sparks(Vector2(C.PLAYER_X + 40, C.SANDBAG_TOP), 30, {"speed": 240.0, "color": Vec.RED, "life": 0.6, "spread": 2.0})
			G.score += 50
			G.stats.dodged += 1
			fx.float_text(Vector2(C.PLAYER_X, C.GROUND - 95), "DUCKED +50", Vec.GREEN, 11.0)
	for c in civs:
		if c.alive and c.state != "hide" and overlaps(prev, gx, c.position.x - 6.0, c.position.x + 6.0):
			kill_civ(c, "beam")
	for cv in covers:
		if overlaps(prev, gx, cv.x - 22.0, cv.x + 22.0):
			fx.sparks(Vector2(cv.x, C.GROUND - 16), 8, {"speed": 160.0, "color": Vec.RED, "life": 0.4})


func player_hit(why: String) -> void:
	if player.inv > 0.0 or attract or mode != "play" or dying:
		return
	G.lives -= 1
	player.hurt()
	flash(0.6, Vec.RED)
	shake(14.0)
	Sfx.play("hurt")
	var label := "TURNED TO FIRE" if why == "beam" else ("CRUSHED" if why == "crush" else "OVERRUN")
	fx.float_text(Vector2(C.PLAYER_X, C.GROUND - 110), label, Vec.RED, 13.0, 1.6)
	if G.lives <= 0:
		G.lives = 0
		begin_game_over()


func explosion(pos: Vector2, big := 1.0, color := Vec.GREEN) -> void:
	fx.sparks(pos, int(28 * big), {"speed": 320.0 * big, "color": color, "life": 0.9, "white": 0.5})
	fx.sparks(pos, int(10 * big), {"speed": 120.0 * big, "color": Vec.AMBER, "life": 0.5, "grav": 0.2})
	fx.smoke(pos, int(4 * big))
	fx.ring(pos, 40.0 * big, 0.35)
	shake(5.0 * big)
	flash(0.12 * big)
	Sfx.play("explosion", 1.0 / maxf(0.5, big))
	for c in civs:
		if c.alive and absf(c.position.x - pos.x) < 34.0 * big and pos.y > C.GROUND - 60.0:
			kill_civ(c, "blast")


func fire() -> void:
	if mode != "play" or dying:
		return
	var shot := player.try_fire()
	if shot.is_empty():
		return
	var rk := Rocket.new()
	rk.position = shot.pos
	rk.vel = shot.vel
	rk.z_index = 3
	_spawn_root.add_child(rk)
	rockets.append(rk)
	shake(2.0)


func _update_rockets(dt: float) -> void:
	var space := get_world_2d().direct_space_state
	var keep: Array = []
	for rk in rockets:
		var prev: Vector2 = rk.advance(dt)
		fx.parts.append({"pos": rk.position, "vel": -rk.vel * 0.1 + Vector2(randf_range(-20, 20), randf_range(-20, 20)), "life": 0.3, "max": 0.3,
			"color": Vec.AMBER if rk.t < 0.7 else Vec.DIM, "grav": 0.0, "size": 1.0, "kind": 0})
		var spent := false
		var q := PhysicsRayQueryParameters2D.create(prev, rk.position, C.LAYER_TRIPOD)
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			var b = hit.collider
			if b is RigidBody2D and b.has_meta("tripod"):
				var tp: Tripod = b.get_meta("tripod")
				if is_instance_valid(tp) and not tp.gone:
					spent = tp.hit(b, hit.position, rk.vel)
		if not spent and rk.position.y >= C.GROUND:
			explosion(Vector2(rk.position.x, C.GROUND), 0.8)
			spent = true
		if not spent and (rk.position.x > C.W + 60.0 or rk.position.x < -60.0 or rk.position.y < -300.0):
			spent = true
		if spent:
			rk.queue_free()
		else:
			keep.append(rk)
	rockets = keep


func _on_tripod_collapsed(tp: Tripod) -> void:
	if wave_info.has("killed"):
		wave_info.killed += 1
	if alive_count() == 0 and mode == "play":
		slow = 0.9
		Engine.time_scale = 0.35


func _on_hood_slammed(tp: Tripod, pos: Vector2) -> void:
	if not tp.has_meta("exploded"):
		tp.set_meta("exploded", true)
		explosion(pos + Vector2(0, -10), 1.6 if tp.big else 1.1)
	for c in civs:
		if c.alive and absf(c.position.x - pos.x) < 44.0 * tp.s:
			kill_civ(c, "crush")
	if not attract and absf(C.PLAYER_X - pos.x) < 50.0 * tp.s:
		player_hit("crush")


func _on_reached_sandbags(_tp: Tripod) -> void:
	Sfx.play("stomp")
	shake(22.0)
	flash(0.3, Vec.RED)
	fx.sparks(Vector2(C.PLAYER_X + 60, C.GROUND), 40, {"speed": 300.0, "life": 0.8})
	fx.debris_burst(Vector2(C.SANDBAG_R, C.GROUND - 20), 8, {"len": 10.0})
	player_hit("overrun")


func _on_building_fell(e: Dictionary) -> void:
	var keep: float = e.get("keep", 20.0)
	fx.debris_burst(Vector2(e.x, C.GROUND - keep), 10, {"color": Vec.DIM, "len": 12.0})
	fx.smoke(Vector2(e.x, C.GROUND - keep), 8)
	shake(3.0)
	Sfx.play("crunch")
	if e.name != "":
		fx.float_text(Vector2(e.x, C.GROUND - keep - 30), e.name + " FALLS", Vec.DIM, 9.0, 1.6)


# --- scenery ------------------------------------------------------------------------------------

func _draw() -> void:
	if mode == "off":
		return
	for st in stars:
		Vec.dot(self, st[0], st[1], Vec.faded(Vec.DIM, 0.35 + 0.3 * sin(t * 2.0 + st[0].x)))
	Vec.circle(self, Vector2(C.W - 150, 70), 6.0, Vec.faded(Vec.RED, 0.8), 1.5)
	Vec.dot(self, Vector2(C.W - 150, 70), 3.0, Vec.faded(Vec.RED, 0.8))
	Vec.line(self, Vector2(0, C.GROUND), Vector2(C.W, C.GROUND), Vec.GREEN, 2.0)
	var x := 20.0
	while x < C.W:
		Vec.line(self, Vector2(x, C.GROUND + 8), Vector2(x - 10, C.GROUND + 18), Vec.DIMMER, 1.2)
		x += 48.0
	# the shelter doorway on the left
	Vec.poly(self, PackedVector2Array([Vector2(14, C.GROUND), Vector2(14, C.GROUND - 46), Vector2(C.SHELTER_X + 4, C.GROUND - 46), Vector2(C.SHELTER_X + 4, C.GROUND)]), Vec.GREEN, 2.0)
	Vec.poly(self, PackedVector2Array([Vector2(20, C.GROUND), Vector2(20, C.GROUND - 38), Vector2(C.SHELTER_X - 2, C.GROUND - 38), Vector2(C.SHELTER_X - 2, C.GROUND)]), Vec.DIM, 1.2)
	if int(t * 2.0) % 2 == 0 or mode != "play":
		Vec.text(self, "SHELTER", Vector2(30, C.GROUND - 62), 8.0, "center", Vec.GREEN)
	Vec.poly(self, PackedVector2Array([Vector2(60, C.GROUND - 56), Vector2(48, C.GROUND - 56), Vector2(52, C.GROUND - 60)]), Vec.GREEN, 1.2)
	Vec.line(self, Vector2(48, C.GROUND - 56), Vector2(52, C.GROUND - 52), Vec.GREEN, 1.2)
	for cv in covers:
		Vec.poly(self, cv.pts, Vec.GREEN, 1.6)
