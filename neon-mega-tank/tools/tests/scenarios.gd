extends Node
## The scenarios run by game_test.gd (see that file). Loaded once the game's autoloads exist.

const TEAM_PLAYER := 0
const TEAM_ENEMY := 1

var scenario := ""
var frame := 0
var g: Node
var main: Main
var tank: MegaTank
var ready_done := false
var data := {}
var fails := 0
var passes := 0


class TestInput extends PlayerInput:
	var hold := false
	var _was := false

	func _init(dev := 7) -> void:
		device = dev

	func poll() -> void:
		action_pressed = hold and not _was
		action_held = hold
		_was = hold
		interact_pressed = false


func check(ok: bool, what: String) -> void:
	if ok:
		passes += 1
		print("PASS  [%s] %s" % [scenario, what])
	else:
		fails += 1
		print("FAIL  [%s] %s" % [scenario, what])


func finish() -> void:
	print("RESULT [%s] %d passed, %d failed" % [scenario, passes, fails])
	get_tree().quit(1 if fails > 0 else 0)


func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if scene == null or not scene is Main:
		return
	main = scene
	frame += 1
	if not ready_done:
		ready_done = true
		tank = g.tank
		# Saved settings may have switched the AI crew on: every scenario starts without it
		# (the ones that want it turn it on themselves).
		g.ai_crew = false
		main._fill_bots()
		call("_setup_" + scenario)
	call("_run_" + scenario)


# --- Helpers ---------------------------------------------------------------------------------

func _battle() -> void:
	main._set_state(Main.State.PLAYING)
	main._wave_break = 1.0e9


func _seat(station: String) -> TestInput:
	var inp := TestInput.new()
	var crew := main._add_crew(inp)
	tank.occupy(tank.stations[station], crew)
	return inp


func _spawn(kind: String, pos: Vector3) -> Enemy:
	var e := main._create_enemy(kind)
	e.position = Vector3(pos.x, 0.0, pos.z)
	main._enemies_root.add_child(e)
	return e


func _shells() -> int:
	var n := 0
	for c in g.fx_root.get_children():
		if c is Projectile and (c as Projectile).kind == "shell":
			n += 1
	return n


## Points the scripted stick at a world direction.
func _stick_toward(inp: TestInput, world_dir: Vector3) -> void:
	inp.aim = main.world_to_stick(world_dir.normalized()).normalized()
	inp.move = inp.aim


# --- cannon: turret answers the stick fast, buffered fire, aim assist ---------------------------

func _setup_cannon() -> void:
	_battle()
	data["gun"] = _seat("cannon")
	# Somewhere open: clear blocks around the tank so the shell flies.
	tank.global_position = Vector3(0, 0, 0)


func _run_cannon() -> void:
	var inp: TestInput = data["gun"]
	var turret_fwd := -tank.turret.global_basis.z
	if frame == 5:
		# Aim 120 degrees away from where the turret points now.
		data["target_dir"] = turret_fwd.rotated(Vector3.UP, deg_to_rad(120.0))
		_stick_toward(inp, data["target_dir"])
		data["start"] = frame
	if frame > 5 and not data.has("aligned"):
		var err := turret_fwd.signed_angle_to(data["target_dir"], Vector3.UP)
		if absf(err) < 0.05:
			data["aligned"] = frame - int(data["start"])
	if frame == 45:
		check(data.has("aligned"), "turret reaches a 120-degree flick")
		if data.has("aligned"):
			var secs := float(data["aligned"]) / 60.0
			print("      120-degree flick took %.2f s (old turret: about 0.9 s)" % secs)
			check(secs <= 0.3, "flick takes 0.3 s or less")
		# Fire buffer: tap fire right as a new flick starts; it should fire once lined up.
		inp.move = Vector2.ZERO
		inp.aim = Vector2.ZERO
		tank.cannon_cd = 0.0
		data["shells0"] = _shells()
	if frame == 50:
		data["target_dir"] = (-tank.turret.global_basis.z).rotated(Vector3.UP, deg_to_rad(-100.0))
		_stick_toward(inp, data["target_dir"])
		inp.hold = true
	if frame == 51:
		inp.hold = false
		check(_shells() == data["shells0"], "no shell leaves while the turret is still swinging")
	if frame == 80:
		check(_shells() == data["shells0"] + 1, "the buffered tap fires once the turret lines up")
		var err := (-tank.turret.global_basis.z).signed_angle_to(data["target_dir"], Vector3.UP)
		check(absf(err) < 0.12, "and it fired in the new direction")
	# Aim assist: a soldier 6 degrees off the stick line gets locked and tracked.
	if frame == 90:
		# Clear the shell fired above so it can't hit the new target.
		for c in g.fx_root.get_children():
			if c is Projectile:
				c.queue_free()
		var dir: Vector3 = data["target_dir"]
		var soldier_dir := dir.rotated(Vector3.UP, deg_to_rad(6.0))
		data["soldier"] = _spawn("rifle", tank.turret.global_position + soldier_dir * 20.0)
		_stick_toward(inp, dir)
	if frame == 110:
		check(tank.aim_target == data["soldier"], "aim assist locks the enemy next to the aim line")
		inp.aim = Vector2.ZERO
		inp.move = Vector2.ZERO
	if frame == 160:
		var s: Variant = data["soldier"]
		if not is_instance_valid(s):
			check(false, "the locked soldier is still there to track")
			finish()
			return
		var to: Vector3 = (s as Enemy).global_position - tank.turret.global_position
		var err := absf((-tank.turret.global_basis.z).signed_angle_to(to, Vector3.UP))
		check(tank.aim_target == s and err < 0.15, "lock keeps tracking after the stick is let go")
		# Keyboards get a wide cone: a direction 20 degrees off still finds it.
		var key_input := TestInput.new(PlayerInput.KEYBOARD_1)
		var off := to.normalized().rotated(Vector3.UP, deg_to_rad(20.0))
		check(tank._assist_target(off, key_input.device) == s, "keyboard aim assist covers 8-way aiming")
		check(tank._assist_target(off, 0) == null, "gamepad aim assist stays narrow")
		finish()


# --- repair: the timing game ---------------------------------------------------------------

func _setup_repair() -> void:
	_battle()
	data["mech"] = _seat("repair")
	tank.hp = 100.0


func _needle_to(v: float) -> void:
	tank.needle_phase = v  # pingpong(v, 1) == v for 0..1


func _run_repair() -> void:
	var inp: TestInput = data["mech"]
	match frame:
		5:
			_needle_to(tank.zone_center)
			data["hp0"] = tank.hp
			inp.hold = true
		6:
			inp.hold = false
			check(tank.last_grade == "perfect", "tap on the zone centre is PERFECT")
			check(tank.hp > data["hp0"] + 10.0, "PERFECT welds about 12 hull (%.1f)" % (tank.hp - data["hp0"]))
			check(tank.combo == 1, "combo starts")
		10:
			var edge := tank.zone_center + tank.zone_half * 0.5
			_needle_to(clampf(edge, 0.0, 1.0))
			data["hp1"] = tank.hp
			inp.hold = true
		11:
			inp.hold = false
			check(tank.last_grade == "good", "tap near the zone edge is GOOD")
			check(tank.combo == 2, "combo grows")
		15:
			# Far from the zone: a miss (shown a moment later).
			var far := 0.02 if tank.zone_center > 0.5 else 0.98
			_needle_to(far)
			data["seq"] = tank.grade_seq
			inp.hold = true
		16:
			inp.hold = false
			check(tank.combo == 0 and tank.rep_stun > 0.0, "a miss drops the combo and stuns the gauge")
		40:
			check(tank.last_grade == "miss" and tank.grade_seq == int(data["seq"]) + 1, "the MISS shows after the hold window")
			# Stunned taps are ignored.
			tank.combo = 3
			tank.rep_stun = 0.3
			_needle_to(tank.zone_center)
			data["seq2"] = tank.grade_seq
			inp.hold = true
		41:
			inp.hold = false
			check(tank.grade_seq == data["seq2"] and tank.combo == 3, "taps during the stun do nothing")
		70:
			# A press that turns into a hold is a shield, not a miss: the combo comes back.
			tank.rep_stun = 0.0
			tank.shield = 80.0
			var far := 0.02 if tank.zone_center > 0.5 else 0.98
			_needle_to(far)
			inp.hold = true
		71:
			check(tank.combo == 0, "(press judged a miss at first)")
		90:
			check(tank.shield_up, "holding ACTION raises the shield")
			check(tank.combo == 3 and tank.rep_stun <= 0.0, "the hold gives the combo back")
			check(tank.last_grade != "miss" or tank.grade_seq == data["seq2"], "no MISS shown for a hold")
		100:
			inp.hold = false
		102:
			check(not tank.shield_up, "letting go drops the shield")
			# Full hull: hits still charge the shield.
			tank.hp = MegaTank.MAX_HP
			tank.shield = 40.0
			tank.rep_stun = 0.0
			_needle_to(tank.zone_center)
			inp.hold = true
		103:
			inp.hold = false
			check(tank.shield > 45.0, "a PERFECT at full hull charges the shield")
			check(tank.hp == MegaTank.MAX_HP, "hull never goes over max")
			finish()


# --- shield: blocks shells, rockets, blasts and hornets; breaks when empty ---------------------

func _setup_shield() -> void:
	_battle()
	data["mech"] = _seat("repair")
	tank.shield = MegaTank.SHIELD_MAX


func _fire_at_tank(kind: String, from_dir: Vector3, dist := 14.0) -> void:
	var start := tank.global_position + from_dir.normalized() * dist + Vector3(0, 0.7, 0)
	var vel := (tank.global_position - start)
	vel.y = 0.0
	g.spawn_projectile(start, vel.normalized() * 24.0, TEAM_ENEMY, kind, Color.RED)


func _run_shield() -> void:
	var inp: TestInput = data["mech"]
	match frame:
		3:
			inp.hold = true
		30:
			check(tank.shield_up, "shield up")
			data["hp"] = tank.hp
			data["sh"] = tank.shield
			_fire_at_tank("enemy_shell", Vector3(1, 0, 0.3))
			_fire_at_tank("rocket", Vector3(-0.4, 0, 1))
			_fire_at_tank("enemy_shell", Vector3(0.7, 0, -0.7))
			for i in 5:
				_spawn("hornet", tank.global_position + Vector3(9 + i, 0, 3))
		120:
			check(tank.hp == data["hp"], "shells, rockets and hornets do no hull damage through the shield")
			check(tank.breaches.is_empty(), "no breaches through the shield")
			check(tank.shield < data["sh"] - 25.0, "blocking cost shield charge (%.0f -> %.0f)" % [data["sh"], tank.shield])
			var hornets := 0
			for e in main.get_tree().get_nodes_in_group("enemies"):
				if e is Hornet:
					hornets += 1
			check(hornets == 0, "hornets burst on the shield")
		121:
			# A blast centred right on the tank (a mortar landing) is soaked too.
			data["hp"] = tank.hp
			g.explode(tank.global_position, 3.4, 20.0, TEAM_ENEMY)
		122:
			check(tank.hp == data["hp"], "mortar-style blast blocked")
		240:
			# Kept holding: it runs dry, breaks and locks out.
			pass
	if frame > 30 and not data.has("broke") and not tank.shield_up and tank.shield_lock > 0.0:
		data["broke"] = frame
		check(tank.shield <= 0.0, "shield ran out while held and broke")
	if not data.has("broke"):
		if frame == 900:
			check(false, "shield breaks when its charge is gone")
			finish()
		return
	var b: int = data["broke"]
	if frame == b + 30:
		check(not tank.shield_up, "still holding: it stays down")
		inp.hold = false
	if frame == b + 40:
		inp.hold = true
	if frame == b + 70:
		check(not tank.shield_up, "can't raise it again during the lockout")
		inp.hold = false
	if frame == b + 150 + 300:
		# Lockout over and some charge back: a fresh hold raises it again.
		check(tank.shield >= MegaTank.SHIELD_MIN, "charge comes back after the lockout (%.0f)" % tank.shield)
		inp.hold = true
	if frame == b + 150 + 330:
		check(tank.shield_up, "and the shield can be raised again")
		inp.hold = false
	if frame == b + 150 + 340:
		# Without the shield, the same shell does hurt.
		data["hp"] = tank.hp
		_fire_at_tank("enemy_shell", Vector3(1, 0, 0))
	if frame == b + 150 + 440:
		check(tank.hp < data["hp"], "shells hurt again with the shield down")
		finish()


# --- collapse: shot-out base drops the stack, rubble, tower bonus, crushes enemies ------------

func _setup_collapse() -> void:
	_battle()
	var best: Array = []
	for key in g.city.columns:
		var col: Array = g.city.columns[key]
		if col.size() > best.size():
			best = col
	data["column"] = best.duplicate()
	data["base"] = best[0]
	print("      tallest column: %d cubes" % best.size())


func _run_collapse() -> void:
	var col: Array = data["column"]
	var base: Variant = data["base"]  # untyped: it gets freed
	if frame == 3:
		# An enemy standing right next to the building, under where the cubes come down.
		data["victim"] = _spawn("rifle", base.global_position + Vector3(0.0, 0, 0.0))
		data["victim"].global_position = Vector3(base.global_position.x + 0.6, 0.0, base.global_position.z)
		# Keep it standing there for the test.
		data["victim"].set_physics_process(false)
		data["score0"] = g.score
	if frame == 5:
		base.take_damage(999.0, base.global_position + Vector3(-3, 0, 0), TEAM_PLAYER)
	if frame == 6:
		var all_dead := true
		for b in col:
			if is_instance_valid(b) and not (b as Block).dead:
				all_dead = false
		check(all_dead, "the whole stack above the base goes")
		var falling := 0
		for i in g.debris_field._cap:
			if g.debris_field._state[i] == 3:
				falling += 1
		check(falling == col.size() - 1, "%d cubes fall as whole pieces" % falling)
		check(g.debris_field.active_count() > falling, "plus flying chunks from the base")
	if frame == 300:
		var falling := 0
		var rubble := 0
		for i in g.debris_field._cap:
			if g.debris_field._state[i] == 3:
				falling += 1
			elif g.debris_field._state[i] == 2:
				rubble += 1
		check(falling == 0, "every falling cube has landed and shattered")
		check(rubble > 4, "rubble settles on the street (%d pieces)" % rubble)
		if col.size() >= 3:
			check(g.score >= data["score0"] + (col.size() - 1) * 15, "TOWER DOWN bonus scored")
		var v: Variant = data["victim"]
		check(not is_instance_valid(v) or (v as Enemy).dead, "the soldier under the falling cubes got squashed")
	if frame == 1100:
		check(g.debris_field.active_count() == 0, "rubble clears away after a while")
		finish()


# --- enemies: each new type does its job -------------------------------------------------------

func _setup_enemies() -> void:
	_battle()
	tank.global_position = Vector3.ZERO
	var p := tank.global_position
	data["mortar"] = _spawn("mortar", p + Vector3(26, 0, 4))
	data["gunship"] = _spawn("gunship", p + Vector3(-15, 0, -18))
	data["truck"] = _spawn("truck", p + Vector3(4, 0, 24))
	data["hp0"] = tank.hp
	data["seen_mark"] = false
	data["seen_rocket"] = false


func _run_enemies() -> void:
	if not main.get_tree().get_nodes_in_group("mortar_marks").is_empty():
		data["seen_mark"] = true
	for r in main.get_tree().get_nodes_in_group("rockets"):
		if (r as Projectile).team == TEAM_ENEMY:
			data["seen_rocket"] = true
	if frame == 60 * 4:
		# Shoot the barrier truck from outside its dome: the dome takes it, not the truck.
		var truck: ShieldTruck = data["truck"]
		data["truck_hp"] = truck.hp
		data["dome_hp"] = truck.dome_hp
		var start := truck.global_position + Vector3(-14, 0.7, 0)
		g.spawn_projectile(start, Vector3(40, 0, 0), TEAM_PLAYER, "shell", Color.WHITE)
	if frame == 60 * 5:
		var truck: ShieldTruck = data["truck"]
		check(truck.hp == data["truck_hp"], "barrier dome stops a shell from outside")
		check(truck.dome_hp < data["dome_hp"], "the dome took the hit")
		# A shell fired from inside the dome goes straight through.
		var start := truck.global_position + Vector3(-5, 0.7, 0)
		g.spawn_projectile(start, Vector3(30, 0, 0), TEAM_PLAYER, "shell", Color.WHITE)
	if frame == 60 * 6:
		var truck: ShieldTruck = data["truck"]
		check(not is_instance_valid(truck) or truck.hp < data["truck_hp"], "shots from inside the dome hit the truck")
	if frame == 60 * 7:
		# Overload the dome.
		var truck: ShieldTruck = data["truck"]
		if is_instance_valid(truck):
			truck.absorb(9999.0, truck.global_position + Vector3(0, 1, -7))
			check(not truck.dome_up(), "dome overloads and drops")
	if frame == 60 * 16:
		check(data["seen_mark"], "mortar team lobbed a round with a target ring")
		check(data["seen_rocket"], "gunship fired a rocket salvo")
		check(tank.hp < data["hp0"], "the new enemies hurt an undefended tank (%.0f -> %.0f)" % [data["hp0"], tank.hp])
		# Hornets: a swarm dives in.
		for i in 5:
			_spawn("hornet", tank.global_position + Vector3(20 + i, 0, -10 + i))
		data["hp1"] = tank.hp
	if frame == 60 * 20:
		check(tank.hp < data["hp1"], "hornet swarm dove into the tank")
		var hornets := 0
		for e in main.get_tree().get_nodes_in_group("enemies"):
			if e is Hornet:
				hornets += 1
		check(hornets == 0, "and burst")
		# The tank crushes a mortar team by driving over it.
		var m: MortarTeam = data["mortar"]
		if is_instance_valid(m) and not m.dead:
			m.crush()
		check(not is_instance_valid(m) or m.dead, "mortar team can be crushed")
		var gs: Gunship = data["gunship"]
		gs.take_damage(9999.0, gs.global_position, TEAM_PLAYER)
		check(gs.dead, "gunship goes down")
		finish()


# --- demo: battle stops at the limit -----------------------------------------------------------

func _setup_demo() -> void:
	g.demo = true
	g.demo_left = 4.0
	main._add_crew(TestInput.new())
	main.start_game()


func _run_demo() -> void:
	if frame == 60 * 2:
		check(main.state == Main.State.PLAYING, "demo battle runs")
		_spawn("rifle", tank.global_position + Vector3(15, 0, 0))
	if frame == 60 * 5:
		check(main.state == Main.State.GAMEOVER, "battle stops when the demo time is up")
		check(main.get_tree().get_nodes_in_group("enemies").is_empty(), "enemies cleared")
		check(main.spawn_queue.is_empty(), "no more waves")
		var hp := tank.hp
		tank.take_damage(50.0, tank.global_position, TEAM_ENEMY)
		check(tank.hp == hp, "the tank can't be hurt after the demo ends")
		check(g.demo_left <= 0.0, "demo time used up")
		finish()


# --- waves: the line-up per wave (printed, plus sanity checks) --------------------------------

func _setup_waves() -> void:
	pass


func _run_waves() -> void:
	print("      wave  rifle rpg tank heavy drone buggy hornets mortar truck gunship  theme")
	for w in range(1, 17):
		var c := Main.wave_counts(w, 4)
		print("      %4d  %5d %3d %4d %5d %5d %5d %7d %6d %5d %7d  %s" % [w, c["rifle"], c["rpg"], c["tank"],
			c["heavy"], c["drone"], c["buggy"], c["hornets"], c["mortar"], c["truck"], c["gunship"], c["theme"]])
	check(Main.wave_counts(1, 4)["mortar"] == 0, "wave 1 is only infantry")
	check(Main.wave_counts(3, 4)["mortar"] >= 1, "mortars from wave 3")
	check(Main.wave_counts(4, 4)["truck"] >= 1, "barrier trucks from wave 4")
	check(Main.wave_counts(6, 4)["gunship"] >= 1, "gunships from wave 6")
	check(Main.wave_counts(9, 4)["theme"] != "", "themed waves")
	finish()


# --- battle: four AI crew play a whole game (balance numbers) ----------------------------------

func _setup_battle() -> void:
	g.ai_crew = true
	main._add_crew(TestInput.new())
	main._fill_bots()
	# The scripted human just stands on deck; the three bots and the director do the rest.
	main.players[0].set_input(BotInput.new(0))
	data["log_t"] = 0
	data["stats"] = {"perfect": 0, "good": 0, "miss": 0, "shield": 0, "falls": 0}
	data["seq"] = tank.grade_seq
	data["shield_was"] = false
	tank.global_position = Vector3(0, 0, -15)


func _run_battle() -> void:
	var st: Dictionary = data["stats"]
	if tank.grade_seq != data["seq"]:
		data["seq"] = tank.grade_seq
		st[tank.last_grade] = int(st.get(tank.last_grade, 0)) + 1
	if tank.shield_up and not data["shield_was"]:
		st["shield"] += 1
	data["shield_was"] = tank.shield_up
	if main.state == Main.State.LOBBY and frame > 30:
		# Roll through the gate.
		main.start_game()
	if main.state == Main.State.PLAYING and frame % (60 * 60) == 0:
		print("      %s  wave %2d  hull %3d  score %6d  enemies %2d  debris %3d  fps-free" % [
			g.format_time(main.survival_time), main.wave, int(tank.hp), g.score,
			main.get_tree().get_nodes_in_group("enemies").size(), g.debris_field.active_count()])
	if main.state == Main.State.GAMEOVER or main.survival_time > 600.0:
		print("      survived %s, reached wave %d, score %d" % [g.format_time(main.survival_time), main.wave, g.score])
		print("      repair taps: %d perfect, %d good, %d miss; shield raised %d times" % [
			st["perfect"], st["good"], st["miss"], st["shield"]])
		check(main.survival_time > 120.0, "AI crew survives more than 2 minutes")
		check(st["perfect"] + st["good"] > 10, "the AI mechanic plays the repair gauge")
		check(st["shield"] > 0, "the AI mechanic uses the shield")
		finish()


# --- shot: real-renderer screenshots for checking the look (not part of run_tests.sh) ---------
#   xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --resolution 1600x900 \
#       --rendering-driver opengl3 -s tools/tests/game_test.gd -- shot <name> <seed> <out_dir>

func _shot_args() -> PackedStringArray:
	return OS.get_cmdline_user_args()


func _save(name: String) -> void:
	var dir := _shot_args()[3] if _shot_args().size() > 3 else "user://"
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [dir, name])
	print("SHOT  %s/%s.png" % [dir, name])


func _setup_shot() -> void:
	var name := _shot_args()[1]
	data["name"] = name
	match name:
		"menu", "menu_demo":
			# For the demo menu, launch with "--demo" after the other arguments.
			g.menu_done = false
			main._set_state(Main.State.MENU)
			return
		"lobby":
			main._add_crew(TestInput.new())
			g.ai_crew = true
			main._fill_bots()
			main._set_state(Main.State.LOBBY)
			return
	g.ai_crew = true
	data["mech"] = TestInput.new()
	var crew := main._add_crew(data["mech"])
	main._fill_bots()
	tank.occupy(tank.stations["repair"], crew)
	_battle()
	tank.global_position = Vector3(0, 0, 0)


func _run_shot() -> void:
	var name: String = data["name"]
	var inp: TestInput = data.get("mech")
	match name:
		"menu", "menu_demo", "lobby":
			if frame == 40:
				_save(name)
				get_tree().quit()
		"gauge":
			# A run of PERFECT welds, then the shield goes up under fire.
			tank.hp = minf(tank.hp, 130.0)
			if frame > 20 and frame < 140 and frame % 18 == 0:
				tank.rep_stun = 0.0
				tank.needle_phase = tank.zone_center - 0.01
				inp.hold = true
			elif frame < 150:
				inp.hold = false
			if frame == 60:
				for i in 4:
					_spawn("rifle", Vector3(18 + i * 2, 0, 6 - i * 3))
				_spawn("tank", Vector3(-20, 0, 14))
			if frame == 128:
				_save("gauge_combo")
			if frame == 150:
				inp.hold = true
			if frame >= 175 and frame % 6 == 0 and frame < 230:
				var a := frame * 0.37
				var start := tank.global_position + Vector3(sin(a), 0, cos(a)) * 13.0 + Vector3(0, 0.7, 0)
				var v := (tank.global_position - start)
				v.y = 0.0
				g.spawn_projectile(start, v.normalized() * 26.0, TEAM_ENEMY, "enemy_shell", Color(1, 0.3, 0.2))
			if frame == 214:
				_save("shield_up")
				get_tree().quit()
		"collapse":
			if frame == 10:
				var best: Array = []
				for key in g.city.columns:
					var col: Array = g.city.columns[key]
					if col.size() > best.size():
						best = col
				data["base"] = best[0]
				var at := (best[0] as Block).global_position
				# Park the tank on a crossroads beyond the building, so it isn't drawn see-through.
				tank.global_position = Vector3(roundf((at.x + 14.0) / City.PERIOD) * City.PERIOD, 0.0,
						roundf((at.z + 14.0) / City.PERIOD) * City.PERIOD)
				data["mech"].hold = false
				# Frame the building, not the tank (it would be between the camera and the tank).
				var cam := main.camera
				main.cinematic = func(_d: float) -> void:
					cam.global_position = Vector3(at.x, 4.0, at.z) + cam.global_basis.z * 120.0
			if frame == 30:
				var b: Block = data["base"]
				b.take_damage(999.0, b.global_position + Vector3(0, 0, 5), TEAM_PLAYER)
			if frame in [62, 78, 94, 110]:
				_save("collapse_%d" % frame)
			if frame == 150:
				_save("collapse_rubble")
				get_tree().quit()
		"lineup":
			# Every new enemy side by side, nobody shooting them.
			if frame == 2:
				for c in main.players.duplicate():
					if c.is_bot():
						tank.leave(c)
						c.visible = false
				g.ai_crew = false
				_spawn("truck", Vector3(13, 0, -6))
				_spawn("gunship", Vector3(-9, 0, -9))
				_spawn("mortar", Vector3(9, 0, 9))
				for i in 5:
					_spawn("hornet", Vector3(-12 + i * 1.3, 0, 6 + i * 0.8))
			if frame == 50:
				for e in main.get_tree().get_nodes_in_group("enemies"):
					e.set_physics_process(false)
				var shell := MortarShell.new()
				shell.setup(Vector3(9, 1.5, 9), tank.global_position + Vector3(-2, 0, 3), 3.0, Color(1.0, 0.45, 0.2))
				g.fx_root.add_child(shell)
			if frame == 110:
				_save("lineup")
				get_tree().quit()
		"enemies":
			if frame == 10:
				_spawn("truck", Vector3(14, 0, -12))
				_spawn("rifle", Vector3(16, 0, -14))
				_spawn("rifle", Vector3(12, 0, -10))
				_spawn("gunship", Vector3(-12, 0, -10))
				_spawn("mortar", Vector3(26, 0, 10))
				for i in 5:
					_spawn("hornet", Vector3(-14 + i * 1.5, 0, 10 + i))
			if frame == 150:
				# Make sure a mortar ring is on screen.
				var shell := MortarShell.new()
				shell.setup(Vector3(26, 1.5, 10), tank.global_position + Vector3(4, 0, 5), 2.2, Color(1.0, 0.45, 0.2))
				g.fx_root.add_child(shell)
			if frame == 200:
				_save("new_enemies")
				get_tree().quit()
		"cannon":
			# A player on the cannon pushes the stick roughly at an enemy tank: the aim assist
			# locks it (corner brackets), the laser stops at it and the reticle sits on it.
			if frame == 2:
				for c in main.players.duplicate():
					if c.is_bot():
						tank.leave(c)
						c.visible = false
				g.ai_crew = false
				tank.leave(main.players[0])
				tank.occupy(tank.stations["cannon"], main.players[0])
				data["enemy"] = _spawn("tank", Vector3(-15, 0, 9))
				_spawn("rifle", Vector3(12, 0, -12))
				_spawn("rifle", Vector3(14, 0, -10))
			if frame == 20:
				for e in main.get_tree().get_nodes_in_group("enemies"):
					e.set_physics_process(false)
				var to: Vector3 = (data["enemy"] as Enemy).global_position - tank.global_position
				_stick_toward(inp, to.rotated(Vector3.UP, deg_to_rad(5.0)))
			if frame == 70:
				_save("cannon_lock")
				get_tree().quit()
		"demo_over":
			if frame == 5:
				g.demo = true
				g.demo_left = 1.5
				for i in 3:
					_spawn("rifle", Vector3(16, 0, i * 3))
			if frame == 300:
				_save("demo_over")
				get_tree().quit()


# --- lan_host / lan_client: a real LAN game between two processes on this machine -------------
# Start the host first, then the client (see run_tests.sh, "lan"). Checks that phones mirror the
# new enemies, the shield, the repair gauge and falling buildings, and that their stick reaches
# the host.

func _clock() -> float:
	data["t"] = float(data.get("t", 0.0)) + get_process_delta_time()
	return data["t"]


func _setup_lan_host() -> void:
	var net := get_tree().root.get_node("Net")
	check(net.host(), "host opened the game port")
	data["mech"] = _seat("repair")
	g.ai_crew = true
	main._fill_bots()


func _run_lan_host() -> void:
	var net := get_tree().root.get_node("Net")
	if not data.has("joined"):
		if not net.multiplayer.get_peers().is_empty():
			data["joined"] = _clock()
			print("      a phone joined the host")
		elif _clock() > 30.0:
			check(false, "a phone joined")
			finish()
		else:
			_clock()
		return
	var t := _clock() - float(data["joined"])
	var inp: TestInput = data["mech"]
	for c in main.players:
		if c.input is NetInput and c.input.move.x > 0.5 and c.input.aim.x > 0.5:
			data["remote_moved"] = true
	if t > 1.0 and not data.has("spawned"):
		data["spawned"] = true
		_battle()
		_spawn("truck", tank.global_position + Vector3(14, 0, -8))
		_spawn("gunship", tank.global_position + Vector3(-10, 0, -10))
		_spawn("mortar", tank.global_position + Vector3(22, 0, 10))
		for i in 5:
			_spawn("hornet", tank.global_position + Vector3(-20 + i, 0, 12))
	if t > 2.0 and not data.has("shield"):
		data["shield"] = true
		tank.shield = MegaTank.SHIELD_MAX
		inp.hold = true
	if t > 3.5 and data.has("shield") and not data.has("shield_off"):
		data["shield_off"] = true
		inp.hold = false
	if t > 4.0 and not data.has("collapse"):
		data["collapse"] = true
		var best: Array = []
		for key in g.city.columns:
			var col: Array = g.city.columns[key]
			if col.size() > best.size():
				best = col
		(best[0] as Block).take_damage(999.0, (best[0] as Block).global_position, TEAM_PLAYER)
	if t > 5.0 and t < 8.0:
		var k := int(t * 10.0)
		if k % 4 == 0 and not data.has("tap%d" % k):
			data["tap%d" % k] = true
			tank.rep_stun = 0.0
			tank.needle_phase = tank.zone_center
			inp.hold = true
		elif k % 4 == 1:
			inp.hold = false
	if t > 12.0:
		check(data.has("remote_moved"), "the phone's stick and aim reached the host")
		finish()


func _setup_lan_client() -> void:
	var net := get_tree().root.get_node("Net")
	net.join("127.0.0.1")
	data["kinds"] = {}


func _key(code: Key, down: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = down
	Input.parse_input_event(ev)


func _run_lan_client() -> void:
	var net := get_tree().root.get_node("Net")
	var t := _clock()
	if net.is_client() and g.tank and is_instance_valid(g.tank) and g.main:
		data["connected"] = true
		var m: Main = g.main
		for e in m._puppets.values():
			if is_instance_valid(e):
				data["kinds"][(e as Enemy).kind] = true
		if g.tank.shield_up:
			data["saw_shield"] = true
		if g.tank.grade_seq > 0:
			data["saw_grade"] = true
		if g.debris_field and g.debris_field.active_count() > 0:
			data["saw_debris"] = true
		for i in g.debris_field._cap:
			if g.debris_field._state[i] == 3:
				data["saw_fall"] = true
				break
		if not get_tree().get_nodes_in_group("mortar_marks").is_empty():
			data["saw_mortar"] = true
		var dome := false
		for e in m._puppets.values():
			if is_instance_valid(e) and e is ShieldTruck and (e as ShieldTruck).dome_up():
				dome = true
		if dome:
			data["saw_dome"] = true
		# Push the stick right for a second (keyboard 1 merges into the phone's controls).
		if not data.has("pushed") and t > 4.0:
			data["pushed"] = t
			_key(KEY_D, true)
		if data.has("pushed") and not data.has("released") and t > float(data["pushed"]) + 1.5:
			data["released"] = true
			_key(KEY_D, false)
	var lost: bool = data.has("connected") and not net.is_client()
	if lost or t > 40.0:
		check(data.has("connected"), "phone joined the host's game")
		var kinds: Dictionary = data["kinds"]
		for k in ["truck", "gunship", "mortar", "hornet"]:
			check(kinds.has(k), "phone shows the new enemy: %s" % k)
		check(data.has("saw_dome"), "phone shows the barrier dome")
		check(data.has("saw_shield"), "phone shows the tank's shield")
		check(data.has("saw_grade"), "phone sees repair gauge results")
		check(data.has("saw_fall"), "phone sees building cubes falling")
		check(data.has("saw_debris"), "phone sees debris")
		check(data.has("saw_mortar"), "phone sees mortar rounds and target rings")
		finish()
