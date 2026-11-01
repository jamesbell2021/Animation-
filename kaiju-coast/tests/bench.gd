extends Node
## Performance bench: a worst-case battle (every gun, seven kaiju with both bosses, a storm,
## burning blocks, the airstrike and the flood) timed section by section.
##   godot --path . res://tests/bench.tscn -- [--frames=600] [--fps]
## --fps sits you in a gun. Prints average and worst milliseconds per frame for each section.

var main: Main
var frames: int = 600
var fps_view: bool = false
var n: int = 0
var times: Dictionary = {}
var worst: Dictionary = {}
var draw_calls: Array[float] = []
var prims: Array[float] = []


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--frames="):
			frames = int(a.substr(9))
		if a == "--fps":
			fps_view = true
	Game.save_path = "user://bench_settings.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.save_path))
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	Settings.set_v("tutorial", false)
	Game.new_game()
	Game.funds = 999999
	Game.wave = 15
	Game.countdown = 1e9
	Game.phase = "wave"
	Game.spawn_q.clear()
	var plan := [[0, "flak", 4], [1, "rocket", 4], [2, "tesla", 4], [3, "cannon", 4], [4, "rail", 4], [5, "rocket", 4], [6, "cannon", 4],
		[7, "flak", 4], [8, "cannon", 4], [9, "rail", 4], [10, "cannon", 4], [11, "tesla", 4], [12, "rocket", 4]]
	for p: Array in plan:
		var t: Turret = main.build_turret(Game.pads[p[0]], p[1])
		while t.lvl < int(p[2]):
			t.level_up("a" if t.lvl == 2 else "")
	Game.zep.lvl = {"bomb": 3, "armor": 3, "pods": 3}
	for s: Array in [["oni", Vector3(-150, 0, -200)], ["kani", Vector3(80, 0, -170)], ["ryu", Vector3(200, 0, -260)],
			["daioni", Vector3(-20, 0, -380)], ["tengu", Vector3(-60, 110, -220)], ["tengu", Vector3(90, 95, -260)], ["orochi", Vector3(240, 0, -480)]]:
		var k: Kaiju = main.spawn_kaiju(s[0])
		k.position = s[1]
		if not k.def["air"]:
			k.position.y = -Game.depth_at(k.position.z)
		k.target_x = k.position.x
		k.hp = 1e7
		k.max_hp = 1e7
	Game.world.set_weather("storm")
	Game.world.rain = 1.0
	Game.world.storm = 1.0
	for i: int in range(6):
		Game.world.smash_near(Vector3(-200.0 + float(i) * 80.0, 0, 120), 60.0)
	if fps_view:
		Game.player.enter(Game.pads[3].turret)
		Game.player.firing = true
	main.set_process(false)
	Game.world.set_process(false)
	Game.hud.set_process(false)
	Game.hud.overlay.set_process(false)


func _t(key: String, us: int) -> void:
	var ms: float = float(us) / 1000.0
	times[key] = float(times.get(key, 0.0)) + ms
	worst[key] = maxf(float(worst.get(key, 0.0)), ms)


func _census(n: Node, out: Dictionary, tag: String, depth: int = 99) -> void:
	for c: Node in n.get_children():
		if c is Label3D and (c as Label3D).visible:
			out[tag + " Label3D"] = int(out.get(tag + " Label3D", 0)) + 1
		elif c is MeshInstance3D and (c as MeshInstance3D).visible:
			out[tag + " Mesh"] = int(out.get(tag + " Mesh", 0)) + 1
		if depth > 0:
			_census(c, out, tag, depth - 1)


## main.step, timed piece by piece (same order, battle path only).
func _step(dt: float) -> void:
	Game.t += dt
	var a: int = Time.get_ticks_usec()
	for k: Kaiju in Game.kaiju:
		k.update(dt)
	var b: int = Time.get_ticks_usec()
	for k3: Kaiju in Game.kaiju:
		k3.pose(dt)
		k3.refresh_hits()
	var c: int = Time.get_ticks_usec()
	for t: Turret in Game.turrets.duplicate():
		t.update(dt)
	var d: int = Time.get_ticks_usec()
	Game.zep.update(dt)
	Game.player.update(dt)
	Game.abilities.update(dt)
	var e: int = Time.get_ticks_usec()
	Game.combat.update(dt)
	var f: int = Time.get_ticks_usec()
	Game.fx.update(dt)
	var g: int = Time.get_ticks_usec()
	_t("  kaiju.update", b - a)
	_t("  kaiju.pose+hits", c - b)
	_t("  turrets", d - c)
	_t("  zep+player+abilities", e - d)
	_t("  combat.update", f - e)
	_t("  fx.update", g - f)


func _process(delta: float) -> void:
	if main == null or main.is_processing():
		return
	n += 1
	# Keep the specials and the fight going all the time.
	if n % 150 == 1:
		Game.abilities.cd = {"air": 0.0, "storm": 0.0, "flood": 0.0}
		Game.abilities.fire("air", Vector3(-100, 0, -220))
		Game.abilities.fire("storm", Vector3(100, 0, -250))
	if n % 150 == 75:
		Game.abilities.fire("flood", Vector3(0, 0, -100))
	if fps_view:
		Game.player.firing = true
		Game.player.heat = 0.0
	var dt: float = 1.0 / 60.0
	var t0: int = Time.get_ticks_usec()
	_step(dt)
	var t1: int = Time.get_ticks_usec()
	Game.rig.update(dt)
	Game.combat.draw()
	var t2: int = Time.get_ticks_usec()
	Game.abilities.draw()
	var t3: int = Time.get_ticks_usec()
	Game.fx.draw()
	var t4: int = Time.get_ticks_usec()
	main._update_pads()
	var t5: int = Time.get_ticks_usec()
	Game.world._process(dt)
	var t6: int = Time.get_ticks_usec()
	Game.hud._process(dt)
	var t7: int = Time.get_ticks_usec()
	Game.hud.overlay._process(dt)
	var t8: int = Time.get_ticks_usec()
	_t("world._process", t6 - t5)
	_t("hud._process", t7 - t6)
	_t("overlay._process", t8 - t7)
	_t("step (sim)", t1 - t0)
	_t("combat.draw", t2 - t1)
	_t("abilities.draw", t3 - t2)
	_t("fx.draw", t4 - t3)
	_t("total main", t4 - t0)
	if n > 30:
		_t("frame (Godot process)", int(Performance.get_monitor(Performance.TIME_PROCESS) * 1e6))
		draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		prims.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	if n == frames:
		print("== bench: %d frames, %d kaiju, %d particles at the end, fps view %s ==" % [n, Game.kaiju.size(), Game.fx.count(), fps_view])
		var kinds: Dictionary = {}
		for kk: int in Game.fx._k:
			kinds[kk] = int(kinds.get(kk, 0)) + 1
		var names: Array = ["SPARK", "BLOOD", "GIB", "RING", "STAIN", "SPLAT", "BOOM", "SMOKE", "FLAME"]
		var line: String = "  particles:"
		for kk2: int in kinds:
			line += " %s %d" % [names[kk2], kinds[kk2]]
		print(line)
		print("  fx line segments last frame: %d, beams %d, texts %d" % [Game.fx._lines.count(), Game.fx._beams.size(), Game.fx._texts.size()])
		for k: String in times:
			print("  %-24s avg %6.2f ms   worst %6.2f ms" % [k, float(times[k]) / float(n), float(worst[k])])
		var dc: float = 0.0
		var pr: float = 0.0
		for v: float in draw_calls:
			dc += v
		for v2: float in prims:
			pr += v2
		print("  draw calls avg %.0f, primitives avg %.0f" % [dc / maxf(1, draw_calls.size()), pr / maxf(1, prims.size())])
		var census: Dictionary = {}
		_census(Game.world.get_node("City"), census, "city")
		_census(Game.world, census, "world", 1)
		_census(main.get_node("Kaiju") if main.has_node("Kaiju") else main, census, "kaiju")
		print("  nodes drawn: ", census)
		print("  fps %.1f (software GL here; the GPU on a real PC is far faster)" % Engine.get_frames_per_second())
		get_tree().quit()
