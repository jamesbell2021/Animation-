extends Node
## Headless smoke test: plays the real game for several waves without rendering.
##   godot --headless --path . res://tests/smoke_test.tscn
## Exits 0 when every check passes, 1 otherwise.

var _fail: int = 0


func check(cond: bool, label: String) -> void:
	print("  %s  %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_fail += 1


func _steps(n: int) -> void:
	for i: int in range(n):
		Game.main.step(1.0 / 30.0)


func _spawn(t: String, p: Vector3) -> Kaiju:
	var k: Kaiju = Game.main.spawn_kaiju(t)
	k.position = p
	k.target_x = p.x
	k.pose(0.0)
	k.refresh_hits()
	return k


## Weak points, upgrade paths, kaiju specials, the airship helm and special attacks.
func _features() -> void:
	print("-- features --")
	Game.new_game()
	Game.funds = 99999
	Game.spawn_q.clear()
	Game.phase = "wave"
	# Shoot an eye out.
	var oni: Kaiju = _spawn("oni", Vector3(0, 0, -60))
	oni.hp = 1e6
	oni.max_hp = 2000.0
	for s: Dictionary in oni.spheres:
		if s["weak"]:
			s["whp"] = 100.0
	_steps(2)
	var idx: int = -1
	for h: Dictionary in oni.hits:
		if h["weak"]:
			idx = h["idx"]
			break
	check(idx >= 0, "oni has weak points")
	for i: int in range(6):
		Game.combat.hurt_kaiju(oni, 40.0, "kin", oni.aim, Vector3.FORWARD, true, "p", idx)
	check(not oni.spheres[idx]["weak"] and oni.enraged, "shooting out an eye blinds and enrages it")
	check(not (oni.spheres[idx]["eye"] as Node3D).visible, "the destroyed eye goes dark")
	check(oni.stagger > 0.5, "heavy hits stagger (%.2f)" % oni.stagger)
	oni.hp = 1.0
	Game.combat.hurt_kaiju(oni, 50.0, "kin", oni.aim, Vector3.FORWARD, false, "t")
	check(oni.dying, "oni dies")
	_steps(160)
	check(not Game.kaiju.has(oni), "death sequence finishes and removes it")
	# Upgrade paths.
	Game.main.select(Game.pads[3])
	Game.main.act("build", "cannon")
	Game.main.act("up", "")
	Game.main.act("up", "")
	check(Game.pads[3].turret.lvl == 2, "level 3 needs a path choice")
	Game.main.act("up", "a")
	check(Game.pads[3].turret.lvl == 3 and Game.pads[3].turret.branch == "a", "cannon took the SANDAN path")
	check(int(Game.pads[3].turret.stat()["pellets"]) == 6, "SANDAN fires six pellets")
	for t: String in ["rocket", "tesla", "rail", "flak"]:
		var b: Dictionary = Game.tstat(t, 3, "b")
		check(not b.is_empty(), "%s path B stats" % t)
	# Orochi: sever a head.
	var oro: Kaiju = _spawn("orochi", Vector3(60, 0, -120))
	oro.hp = 1e6
	oro.max_hp = 10000.0
	_steps(2)
	var eyes: Array[int] = []
	for i2: int in range(oro.spheres.size()):
		if oro.spheres[i2]["weak"] and eyes.size() < 2:
			eyes.append(i2)
	for e: int in eyes:
		for j: int in range(30):
			Game.combat.hurt_kaiju(oro, 100.0, "kin", oro.aim, Vector3.FORWARD, true, "p", e)
	var severed: int = 0
	for h2: Dictionary in oro._heads:
		if not h2["alive"]:
			severed += 1
	check(oro._heads.size() == 5 and severed == 1, "Orochi has 5 heads and one was severed")
	oro.hp = 1.0
	Game.combat.hurt_kaiju(oro, 50.0, "kin", oro.aim, Vector3.FORWARD, false, "t")
	# Kanizame burrows to a sea fort.
	Game.main.select(Game.pads[10])
	Game.main.act("build", "cannon")
	var fort: Turret = Game.pads[10].turret
	var kani: Kaiju = _spawn("kani", Game.pads[10].pos + Vector3(0, 0, -200))
	kani.hp = 1e6
	var hp0: float = fort.hp
	var saw_burrow: bool = false
	for i3: int in range(30 * 20):
		Game.main.step(1.0 / 30.0)
		saw_burrow = saw_burrow or kani.burrowing
		if not Game.turrets.has(fort) or fort.hp < hp0:
			break
	check(saw_burrow, "Kanizame burrowed")
	check(not Game.turrets.has(fort) or fort.hp < hp0, "and ambushed the sea fort")
	kani.hp = 1.0
	Game.combat.hurt_kaiju(kani, 50.0, "kin", kani.aim, Vector3.FORWARD, false, "t")
	# Ryujin coils round a fort.
	Game.main.select(Game.pads[11])
	Game.main.act("build", "cannon")
	var fort2: Turret = Game.pads[11].turret
	var ryu: Kaiju = _spawn("ryu", Game.pads[11].pos + Vector3(0, 0, -50))
	ryu.hp = 1e6
	var coiled: bool = false
	for i4: int in range(30 * 10):
		Game.main.step(1.0 / 30.0)
		coiled = coiled or ryu.state == "coil"
	check(coiled, "Ryujin coiled round the fort")
	ryu.hp = 1.0
	Game.combat.hurt_kaiju(ryu, 50.0, "kin", ryu.aim, Vector3.FORWARD, false, "t")
	# A tengu dives at the gun you're in.
	var seat: Turret = Game.pads[3].turret
	Game.player.enter(seat)
	var tg: Kaiju = _spawn("tengu", seat.pad.pos + Vector3(0, 80, -150))
	tg.hp = 1e6
	tg.dive = true
	var shp: float = seat.hp
	for i5: int in range(30 * 6):
		Game.main.step(1.0 / 30.0)
		if seat.hp < shp:
			break
	check(seat.hp < shp, "a diving tengu hit your gun")
	tg.hp = 1.0
	Game.combat.hurt_kaiju(tg, 50.0, "kin", tg.aim, Vector3.FORWARD, false, "t")
	# Fly the airship.
	Game.player.enter("zep")
	var z0: Vector3 = Game.zep.position
	var w: InputEventKey = InputEventKey.new()
	w.physical_keycode = KEY_W
	w.pressed = true
	Input.parse_input_event(w)
	await get_tree().process_frame
	_steps(90)
	w.pressed = false
	Input.parse_input_event(w)
	check(Game.zep.pilot_speed > 25.0, "W throttles the airship up (%.0f)" % Game.zep.pilot_speed)
	check(Game.zep.position.distance_to(z0) > 40.0, "the airship flew")
	Game.player.exit_seat()
	_steps(30)
	# Special attacks.
	var target: Kaiju = _spawn("oni", Vector3(-100, 0, -80))
	target.hp = 3000.0
	target.max_hp = 3000.0
	_steps(2)
	var h0: float = target.hp
	Game.wave = 5
	for k: String in Abilities.ORDER:
		check(Game.abilities.is_ready(k), "%s ready" % k)
	Game.abilities.fire("air", Vector3(-100, 0, -80))
	_steps(30 * 6)
	check(target.hp < h0, "airstrike hit (%d -> %d)" % [int(h0), int(target.hp)])
	var h1: float = target.hp
	Game.abilities.fire("storm", Vector3(-100, 0, -80))
	_steps(30 * 9)
	check(target.hp < h1, "lightning storm hit")
	if target.dying:
		target = _spawn("oni", Vector3(-100, 0, -40))
	target.hp = 3000.0
	target.position.z = -40.0
	var z1: float = target.position.z
	Game.abilities.fire("flood", Vector3(-100, 0, -40))
	_steps(30 * 3)
	check(target.position.z < z1 - 40.0, "flood gates pushed it back out (%d -> %d)" % [int(z1), int(target.position.z)])
	check(not Game.abilities.is_ready("air"), "abilities go on cooldown")


## Difficulty, tutorial, pause and settings.
func _menus_and_settings() -> void:
	print("-- menus and settings --")
	Settings.set_v("difficulty", 0)
	Settings.set_v("tutorial", true)
	Game.new_game()
	check(Game.funds == 600 and Game.difficulty == 0, "easy starts with ¥600")
	check(Game.tutorial.active and Game.hud.tut_box.visible, "the tutorial starts on a new game")
	Game.main.select(Game.pads[3])
	Game.main.tutorial_tick()
	check(Game.tutorial.step == 1, "tutorial: picking a ring moves it on")
	Game.main.act("build", "cannon")
	Game.main.tutorial_tick()
	check(Game.tutorial.step == 2, "tutorial: building a gun moves it on")
	Game.start_wave()
	Game.main.tutorial_tick()
	check(Game.tutorial.step == 3, "tutorial: starting the wave moves it on")
	var easy_hp: float = Game.hp_mul
	Game.tutorial.skip()
	check(not Game.tutorial.active and not bool(Settings.get_v("tutorial")), "skipping the tutorial remembers it")
	Settings.set_v("difficulty", 2)
	Game.new_game()
	Game.start_wave()
	check(Game.funds == 340 + 0 and Game.hp_mul > easy_hp, "hard: ¥340 and tougher kaiju")
	Game.main.toggle_pause()
	check(Game.paused and Game.hud.pause_menu.visible, "pause opens the menu")
	var t0: float = Game.t
	await get_tree().process_frame
	await get_tree().process_frame
	check(is_equal_approx(Game.t, t0), "nothing moves while paused")
	Game.hud.show_settings("pause")
	check(Game.hud.settings_menu.visible, "settings open from the pause menu")
	Settings.set_v("quality", 0)
	check(is_equal_approx(Mats.line_width, 1.3) and Game.fx.max_particles == 1400, "low quality thins lines and caps particles")
	Settings.set_v("quality", 2)
	Settings.set_v("sfx_vol", 0.5)
	check(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")) - linear_to_db(0.5)) < 0.01, "effects volume drives the SFX bus")
	Game.hud.back()
	check(Game.hud.pause_menu.visible and not Game.hud.settings_menu.visible, "back returns to the pause menu")
	Game.hud.back()
	check(not Game.paused, "back again resumes")
	# Controller: RB cycles the selection, Y mans the gun, B leaves.
	Game.main.select(null)
	await _pad_press(JOY_BUTTON_RIGHT_SHOULDER)
	check(Game.sel is Pad, "RB selects a gun ring")
	Game.main.select(Game.pads[3])
	Game.main.act("build", "cannon")
	await _pad_press(JOY_BUTTON_Y)
	check(Game.player.active, "Y mans the gun")
	await _pad_press(JOY_BUTTON_B)
	check(not Game.player.active, "B leaves it")
	await _pad_press(JOY_BUTTON_BACK)
	check(Game.paused, "Back pauses")
	await _pad_press(JOY_BUTTON_B)
	check(not Game.paused, "B closes the pause menu")
	Settings.set_v("difficulty", 1)


## Kaiju don't walk through things, and shots leave from the barrels you can see.
func _contact() -> void:
	print("-- contact and barrels --")
	Game.new_game()
	Game.tutorial.skip()
	Game.funds = 99999
	Game.spawn_q.clear()
	Game.phase = "wave"
	# The torii comes down when a kaiju wades into it, and stands again on a new game.
	var tz: float = World.TORII_AT.z
	var oni: Kaiju = _spawn("oni", Vector3(World.TORII_AT.x, 0, tz - 60.0))
	oni.hp = 1e6
	for i: int in range(30 * 8):
		Game.main.step(1.0 / 30.0)
		if not Game.world.torii_up:
			break
	check(not Game.world.torii_up, "an Onigami wading into the torii knocks it down")
	oni.hp = 1.0
	Game.combat.hurt_kaiju(oni, 50.0, "kin", oni.aim, Vector3.FORWARD, false, "t")
	_steps(160)
	Game.new_game()
	Game.tutorial.skip()
	check(Game.world.torii_up, "and it's standing again on a new game")
	Game.funds = 99999
	Game.spawn_q.clear()
	Game.phase = "wave"
	# Kaiju wade round the sea forts and don't stand inside each other.
	var fort: Pad = Game.pads[10]
	var k1: Kaiju = _spawn("oni", fort.pos + Vector3(4, 0, -120))
	k1.target_x = fort.pos.x
	k1.hp = 1e6
	var closest: float = 1e9
	for i2: int in range(30 * 12):
		Game.main.step(1.0 / 30.0)
		closest = minf(closest, Vector2(k1.position.x - fort.pos.x, k1.position.z - fort.pos.z).length())
	check(closest >= Kaiju.FORT_R + Kaiju.BODY["oni"] - 0.5, "an Onigami walked round the empty sea fort (closest %.0f)" % closest)
	check(k1.position.z > fort.pos.z + 20.0, "and carried on past it")
	var a: Kaiju = _spawn("oni", Vector3(-150, 0, -200))
	var b: Kaiju = _spawn("kani", Vector3(-148, 0, -202))
	a.hp = 1e6
	b.hp = 1e6
	_steps(30)
	var gap: float = Vector2(a.position.x - b.position.x, a.position.z - b.position.z).length()
	check(gap > (Kaiju.BODY["oni"] + Kaiju.BODY["kani"]) * 0.8, "two kaiju spawned on top of each other spread apart (%.0f)" % gap)
	# A kaiju standing in the city knocks down the blocks it's standing in.
	var bld: Dictionary = {}
	for bb: Dictionary in Game.world.buildings:
		if bb["kind"] == "box" and not bb["falling"]:
			bld = bb
			break
	check(Game.world.crush_at(Vector3(bld["x"], 0, bld["z"]), 14.0) == 1 or bld["falling"], "a block under a kaiju's feet comes down")
	# The airship climbs over a Dai-Oni instead of flying through its head.
	var big: Kaiju = _spawn("daioni", Vector3(Game.zep.position.x, 0, Game.zep.position.z))
	big.hp = 1e6
	_steps(30 * 5)
	var top: float = 0.0
	for h: Dictionary in big.hits:
		top = maxf(top, float(h["p"].y) + float(h["r"]))
	var zx: float = Game.zep.position.x
	check(Game.zep.alt > 125.0 or Vector2(big.position.x - Game.zep.position.x, big.position.z - Game.zep.position.z).length() > 110.0,
		"the airship climbs over the Dai-Oni (alt %.0f, kaiju top %.0f)" % [Game.zep.alt, top])
	for k: Kaiju in Game.kaiju.duplicate():
		k.hp = 1.0
		Game.combat.hurt_kaiju(k, 50.0, "kin", k.aim, Vector3.FORWARD, false, "t")
	_steps(170)
	# First person: bullets leave from the two barrel mouths in turn, rockets from the tube.
	Game.main.select(Game.pads[3])
	Game.main.act("build", "cannon")
	Game.main.select(null)
	var target: Kaiju = _spawn("oni", Game.pads[3].pos + Vector3(0, 0, -200))
	target.hp = 1e6
	Game.player.enter(Game.pads[3].turret)
	Game.player.set_weapon("gun")
	await get_tree().process_frame
	Game.rig.update(0.0)
	var mouths: Array = []
	for m: Node3D in Game.player._gun_mouths:
		mouths.append(m.global_position)
	Game.combat.shots.clear()
	Game.player.firing = true
	for i3: int in range(6):
		Game.player.cd = 0.0
		Game.player.update(1.0 / 30.0)
	Game.player.firing = false
	var from_a: int = 0
	var from_b: int = 0
	# The barrels sit 0.28 apart in front of the camera: sort each round to the nearer mouth.
	for s: Combat.Shot in Game.combat.shots:
		if s.by == "p" and s.kind == "bullet":
			var da: float = s.origin.distance_to(mouths[0])
			var db: float = s.origin.distance_to(mouths[1])
			if minf(da, db) < 0.12:
				if da < db:
					from_a += 1
				else:
					from_b += 1
	check(from_a >= 2 and from_b >= 2, "machine-gun rounds leave from both barrel mouths (%d / %d)" % [from_a, from_b])
	Game.player.set_weapon("rocket")
	Game.player.ammo = 4
	Game.player.reload = 0.0
	Game.combat.shots.clear()
	Game.player.firing = true
	Game.player.cd = 0.0
	Game.player.update(1.0 / 30.0)
	Game.player.firing = false
	var tube: Vector3 = Game.player._tube_mouth.global_position
	var ok_rkt: bool = false
	for s2: Combat.Shot in Game.combat.shots:
		ok_rkt = ok_rkt or (s2.kind == "rocket" and s2.origin.distance_to(tube) < 0.3)
	check(ok_rkt, "rockets leave from the launcher tube")
	Game.player.exit_seat()
	# A twin-barrel cannon fires one shell from each barrel.
	Game.main.select(Game.pads[3])
	Game.main.act("up", "")
	Game.main.select(null)
	var tu: Turret = Game.pads[3].turret
	Game.combat.shots.clear()
	tu._fire(target, target.aim, tu.stat())
	var origins: Array = []
	for s3: Combat.Shot in Game.combat.shots:
		var near_mouth: bool = false
		for mo: Vector3 in tu._mouths:
			near_mouth = near_mouth or s3.origin.distance_to(tu._gun.global_transform * mo) < 0.5
		if near_mouth and not origins.has(s3.origin):
			origins.append(s3.origin)
	check(tu._mouths.size() == 2 and origins.size() == 2, "a level 2 cannon fires from both of its barrels (%d)" % origins.size())
	target.hp = 1.0
	Game.combat.hurt_kaiju(target, 50.0, "kin", target.aim, Vector3.FORWARD, false, "t")
	_steps(170)


## Voice call-outs, weather, fires and searchlights.
func _atmosphere() -> void:
	print("-- voices and weather --")
	var waited: int = 0
	while not Game.voice.ready_all() and waited < 600:
		await get_tree().process_frame
		waited += 1
	check(Game.voice.ready_all(), "%d voice lines synthesised" % Game.voice.streams.size())
	Game.new_game()
	check(Game.voice.last_key == "deploy", "a new game calls out 出撃")
	check(Game.hud.subtitle.text.contains("出撃"), "with a subtitle")
	Game.funds = 4000
	Game.main.select(Game.pads[3])
	Game.main.act("build", "cannon")
	Game.main.select(null)
	Game.wave = 4
	Game.start_wave()
	check(Game.world.weather == "storm", "boss waves bring a storm")
	for i: int in range(40):
		Game.world._process(0.5)
	check(Game.world.rain > 0.5 and Game.world.storm > 0.9, "rain and storm build up (%.2f, %.2f)" % [Game.world.rain, Game.world.storm])
	check(Game.sea_amp > 1.8, "the swell rises (x%.1f)" % Game.sea_amp)
	var lights: int = 0
	for n: Node in Game.world.get_children():
		if n.name.begins_with("Searchlight") and (n as Node3D).visible:
			lights += 1
	check(lights >= 4, "%d searchlights" % lights)
	var boss: Kaiju = null
	for i2: int in range(30 * 90):
		Game.main.step(1.0 / 30.0)
		for k: Kaiju in Game.kaiju:
			if k.def["boss"]:
				boss = k
		if boss != null:
			break
	check(boss != null, "the Dai-Oni arrives")
	check(Game.voice.last_key == "daioni", "with a call-out (%s)" % Game.voice.last_key)
	var fires_before: int = Game.world._fires.size()
	var fx_before: int = Game.fx.count()
	for i3: int in range(6):
		Game.world.smash_near(Vector3(randf_range(-200, 200), 0, 120), 400.0)
	for i4: int in range(30 * 4):
		Game.world._process(1.0 / 30.0)
		Game.fx.update(1.0 / 30.0)
	check(Game.world._fires.size() > fires_before, "smashed blocks set their neighbours alight (%d fires)" % Game.world._fires.size())
	check(Game.fx.count() > fx_before, "fires throw flames and smoke")
	Game.world.set_weather("clear")
	for i5: int in range(40):
		Game.world._process(0.5)
	check(Game.world.rain < 0.01 and Game.sea_amp < 1.05, "the weather clears")
	Game.city = 30.0
	Game.voice._until = 0.0
	Game.main.step(1.0 / 30.0)
	check(Game.city_warned, "low city warning")


func _touch_ev(index: int, pos: Vector2, pressed: bool) -> void:
	var e: InputEventScreenTouch = InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	Game.hud.touch._input(e)


func _drag_ev(index: int, pos: Vector2, rel: Vector2) -> void:
	var e: InputEventScreenDrag = InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	e.relative = rel
	Game.hud.touch._input(e)


## The on-screen controls used on phones.
func _touch() -> void:
	print("-- touch controls --")
	TouchControls.forced = true
	var tc: TouchControls = Game.hud.touch
	Game.new_game()
	Game.tutorial.skip()
	Game.funds = 4000
	Game.main.select(Game.pads[3])
	Game.main.act("build", "cannon")
	Game.main.select(null)
	Game.player.enter(Game.turrets[0])
	await get_tree().process_frame
	check(tc.visible, "touch controls show in first person")
	var fire: Vector2 = tc._buttons()["fire"][0]
	_touch_ev(0, fire, true)
	check(Game.player.firing, "holding 撃 fires")
	_touch_ev(0, fire, false)
	check(not Game.player.firing, "letting go stops")
	var yaw0: float = Game.player.yaw
	_touch_ev(1, Vector2(tc.size.x * 0.6, tc.size.y * 0.3), true)
	_drag_ev(1, Vector2(tc.size.x * 0.6 + 80, tc.size.y * 0.3), Vector2(80, 0))
	_touch_ev(1, Vector2(tc.size.x * 0.6 + 80, tc.size.y * 0.3), false)
	check(Game.player.yaw < yaw0, "dragging aims")
	Game.player.enter("zep")
	var start: Vector2 = Vector2(250, tc.size.y - 250)
	_touch_ev(2, start, true)
	_drag_ev(2, start + Vector2(80, -80), Vector2(80, -80))
	check(tc.stick().length() > 0.9, "the stick deflects")
	var yaw_z: float = Game.zep.yaw
	for i: int in range(30):
		Game.main.step(1.0 / 30.0)
	check(absf(wrapf(Game.zep.yaw - yaw_z, -PI, PI)) > 0.05, "the stick steers the airship")
	_touch_ev(2, start, false)
	_touch_ev(0, tc._buttons()["exit"][0], true)
	_touch_ev(0, tc._buttons()["exit"][0], false)
	check(not Game.player.active, "EXIT leaves the seat")
	var z0: float = Game.rig.zoom
	_touch_ev(0, Vector2(500, 300), true)
	_touch_ev(1, Vector2(700, 300), true)
	_drag_ev(1, Vector2(900, 300), Vector2(200, 0))
	_touch_ev(0, Vector2(500, 300), false)
	_touch_ev(1, Vector2(900, 300), false)
	check(Game.rig.zoom < z0, "pinch zooms the command view in (%.2f -> %.2f)" % [z0, Game.rig.zoom])
	TouchControls.forced = false
	await get_tree().process_frame
	check(not tc.visible, "hidden without a touchscreen")


func _pad_press(button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var e: InputEventJoypadButton = InputEventJoypadButton.new()
		e.button_index = button
		e.pressed = pressed
		Input.parse_input_event(e)
		await get_tree().process_frame
	await get_tree().process_frame


func _ready() -> void:
	Game.save_path = "user://smoke_test_settings.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.save_path))
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	print("== Kaiju Coast smoke test ==")
	check(Game.state == Game.State.TITLE, "boots to the title screen")
	check(Game.kaiju.size() >= 3, "attract mode has kaiju (%d)" % Game.kaiju.size())
	check(Game.turrets.size() == 7, "attract mode has 7 guns")
	check(Game.world.buildings.size() > 100, "city has %d buildings" % Game.world.buildings.size())
	check(Game.sfx.streams.size() >= 20, "%d sound effects synthesised" % Game.sfx.streams.size())
	# Demo runs on its own.
	for i: int in range(300):
		Game.main.step(1.0 / 30.0)
	check(true, "attract mode ran 10 s")
	# A real game.
	Game.new_game()
	check(Game.state == Game.State.PLAY and Game.funds == 420, "new game: ¥420")
	check(Game.kaiju.is_empty() and Game.turrets.is_empty(), "new game starts empty")
	Game.main.select(Game.pads[3])
	Game.main.act("build", "cannon")
	check(Game.turrets.size() == 1 and Game.funds == 320, "built a cannon for ¥100")
	Game.main.act("up", "")
	check(Game.pads[3].turret.lvl == 2, "upgraded it to level 2")
	Game.main.select(Game.pads[1])
	Game.main.act("build", "rail")
	check(Game.turrets.size() == 1, "can't afford a rail yet")
	Game.funds = 4000
	for spec: Array in [[1, "cannon"], [5, "rocket"], [2, "tesla"], [4, "rail"], [8, "flak"], [10, "cannon"], [11, "rocket"]]:
		Game.main.select(Game.pads[spec[0]])
		Game.main.act("build", spec[1])
	check(Game.turrets.size() == 8, "built 8 guns")
	Game.main.select("zep")
	Game.main.act("zup", "bomb")
	Game.main.act("zup", "pods")
	check(Game.zep.lvl["bomb"] == 1 and Game.zep.lvl["pods"] == 1, "airship upgrades")
	Game.main.select(null)
	# Play three waves; man a gun in the middle of the second.
	var steps: int = 0
	for w: int in range(3):
		Game.start_wave()
		check(Game.phase == "wave" and Game.wave == w + 1, "wave %d started" % (w + 1))
		var s: int = 0
		while Game.phase == "wave" and Game.state == Game.State.PLAY and s < 30 * 300:
			if w == 1 and s == 30 * 30:
				Game.player.enter(Game.turrets[0])
				Game.player.firing = true
			if w == 1 and s == 30 * 45:
				Game.player.swap()
			if w == 1 and s == 30 * 60:
				Game.player.exit_seat()
			Game.main.step(1.0 / 30.0)
			s += 1
		steps += s
		print("    wave %d: %ds, city %d%%, kills %d, funds ¥%d, fx %d" % [Game.wave, s / 30, int(Game.city), Game.kills, Game.funds, Game.fx.count()])
		check(Game.phase == "build", "wave %d cleared" % (w + 1))
	check(Game.kills >= 10, "killed %d kaiju" % Game.kills)
	check(Game.city > 0.0, "city still standing (%d%%)" % int(Game.city))
	# Boss wave.
	Game.wave = 4
	Game.start_wave()
	var s2: int = 0
	var boss_seen: bool = false
	while Game.phase == "wave" and Game.state == Game.State.PLAY and s2 < 30 * 400:
		for k: Kaiju in Game.kaiju:
			if k.def["boss"]:
				boss_seen = true
		Game.main.step(1.0 / 30.0)
		s2 += 1
	check(boss_seen, "wave 5 brought the Dai-Oni")
	print("    wave 5: %ds, city %d%%, kills %d, state %s" % [s2 / 30, int(Game.city), Game.kills, Game.State.keys()[Game.state]])
	# Losing.
	Game.city = 0.5
	Game.wave = 6
	if Game.state == Game.State.PLAY:
		if Game.phase == "build":
			Game.start_wave()
		var s3: int = 0
		while Game.state == Game.State.PLAY and s3 < 30 * 300:
			Game.main.step(1.0 / 30.0)
			s3 += 1
	check(Game.state == Game.State.OVER, "the city can fall")
	await _features()
	await _contact()
	await _atmosphere()
	await _touch()
	await _menus_and_settings()
	Game.main.to_title()
	check(Game.state == Game.State.TITLE, "back to the title")
	print("== %s ==" % ("ALL PASS" if _fail == 0 else "%d FAILED" % _fail))
	get_tree().quit(1 if _fail > 0 else 0)
