extends SceneTree
## Records one shot of the gameplay reel with Godot's Movie Maker. Each shot stages a
## moment of play (the keeper is steered by this script) under a caption.
## tools/reel/make_reel.sh records every shot and joins them into one MP4.
##   godot --path . --write-movie out.avi --fixed-fps 30 --resolution 1280x720 \
##     -s res://tools/reel/reel_director.gd -- shot=day
## Each shot prints "REC <seconds>": where the usable footage starts.
## Your save and best night are backed up and put back afterwards.

const WARMUP := 60
const PH_DAY := 0
const PH_DUSK := 1
const PH_NIGHT := 2
const PH_DAWN := 3
const SPAWN := Vector3(-1.6, 0.0, 2.7)
const FPS := 30.0
const SAVES := ["user://run.json", "user://profile.json"]
const LENGTHS := {
	"title": 6.0, "day": 12.0, "dusk": 8.0, "beam": 12.0, "ledge": 8.0, "squid": 7.0, "crab": 7.0,
	"eel": 13.0, "smotherer": 10.0, "storm": 9.0, "garden": 8.0, "cottage": 7.0, "trap": 7.0,
	"flare": 7.0, "dawn": 7.0, "end": 5.0,
}

var shot := "day"
var frame := 0
var main
var player: Player
var lamp: Lamp
var cyc
var cam: Camera3D
var _saved := {}
var _caption: Label
var _sub: Label
var _actors := {}
var _done := {}
# Creatures frozen for the end of the warm-up, let go when the shot starts.
var _held: Array[Node] = []

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("shot="):
			shot = a.substr(5)
	for p in SAVES:
		if FileAccess.file_exists(p):
			_saved[p] = FileAccess.get_file_as_bytes(p)
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	change_scene_to_file("res://scenes/main.tscn")

func _finalize() -> void:
	for p in SAVES:
		if _saved.has(p):
			var f := FileAccess.open(p, FileAccess.WRITE)
			f.store_buffer(_saved[p])
		elif FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 1:
		var splash := root.get_node_or_null("StudioSplash")
		if splash:
			splash.free()
	if frame == 3:
		main = current_scene
		cyc = root.get_node("Cycle")
		_add_captions()
		_setup()
	if frame == WARMUP:
		print("REC %.3f" % (float(WARMUP) / FPS))
	# Out of the ground first (Emerge takes 0.8 s), then frozen until the shot starts.
	if frame == 40:
		for e in _held:
			if is_instance_valid(e):
				e.set_physics_process(false)
	if frame == WARMUP:
		for e in _held:
			if is_instance_valid(e):
				e.set_physics_process(true)
	if frame > 3:
		_direct(float(frame - WARMUP) / FPS)
	return frame >= WARMUP + int(LENGTHS.get(shot, 6.0) * FPS)

# ---- helpers ----

func _add_captions() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	main.add_child(layer)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	box.offset_left = 36.0
	box.offset_top = -132.0
	box.offset_bottom = -30.0
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	layer.add_child(box)
	_caption = _label(box, 38, Color(1.0, 0.8, 0.45))
	Fonts.use_title(_caption)
	_sub = _label(box, 21, Color(0.92, 0.94, 0.96))

func _label(parent: Node, size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 8)
	parent.add_child(l)
	return l

func caption(head: String, sub: String = "") -> void:
	_caption.text = head
	_sub.text = sub

# Run one thing once, at or after time t.
func at(t: float, now: float, key: String) -> bool:
	if now >= t and not _done.has(key):
		_done[key] = true
		return true
	return false

func start_run() -> void:
	main.begin_run(false, 1)
	player = main.player
	lamp = main.lighthouse.lamp
	player.camera = null
	main.spawner.process_mode = Node.PROCESS_MODE_DISABLED
	quiet_hud()

func quiet_hud() -> void:
	var hud = main.hud
	hud._report_t = 0.0
	hud._report_label.visible = false
	hud._warn_t = 0.0
	hud._warn_label.visible = false

func scene(phase: int, storm: float, hud_on: bool) -> void:
	cyc._enter(phase)
	cyc.running = false
	main._apply_lighting(phase, 0.0)
	main.atmosphere.apply(phase, 0.0)
	var w: Weather = main.atmosphere.weather
	w.storm = storm
	w._target = storm
	w._strike_t = 999.0
	if phase == PH_DUSK or phase == PH_NIGHT:
		lamp._set_state(Lamp.State.BURNING)
	else:
		lamp._set_state(Lamp.State.OFF)
	main.hud.visible = hud_on
	quiet_hud()

func weather() -> Weather:
	return main.atmosphere.weather

func camera(pos: Vector3, look: Vector3, fov: float = 45.0) -> void:
	if cam == null:
		cam = Camera3D.new()
		main.add_child(cam)
	cam.fov = fov
	cam.look_at_from_position(pos, look, Vector3.UP)
	cam.current = true

func game_camera() -> void:
	main.camera.current = true

func ground(p: Vector3, lift: float = 0.1) -> Vector3:
	return Vector3(p.x, Terrain.height_at(p.x, p.z) + lift, p.z)

func spawn(cls, pos: Vector3) -> Enemy:
	var e: Enemy = cls.new()
	e.lighthouse = main.lighthouse
	e.position = pos
	main.get_node("Enemies").add_child(e)
	return e

func hold(e: Node) -> Node:
	_held.append(e)
	return e

func place(p: Vector3) -> void:
	player.global_position = ground(p)
	player.velocity = Vector3.ZERO

# Steer the keeper toward a point with the move actions, as a stick would.
func walk_to(target: Vector3, stop: float = 0.3) -> bool:
	var d := target - player.global_position
	d.y = 0.0
	var arrived := d.length() < stop
	var dir := Vector3.ZERO if arrived else d.normalized()
	_axis("move_right", "move_left", dir.x)
	_axis("move_down", "move_up", dir.z)
	return arrived

func _axis(pos: String, neg: String, v: float) -> void:
	if v > 0.05:
		Input.action_press(pos, v)
		Input.action_release(neg)
	elif v < -0.05:
		Input.action_press(neg, -v)
		Input.action_release(pos)
	else:
		Input.action_release(pos)
		Input.action_release(neg)

func tap(action: String) -> void:
	Input.action_press(action)
	_release_later.call_deferred(action)

func _release_later(action: String) -> void:
	await physics_frame
	await physics_frame
	Input.action_release(action)

func aim_at(p: Vector3) -> void:
	var d := p - player.global_position
	d.y = 0.0
	if d.length() > 0.05:
		player._aim = d.normalized()

func mix(a: Vector3, b: Vector3, k: float) -> Vector3:
	return a.lerp(b, smoothstep(0.0, 1.0, clampf(k, 0.0, 1.0)))

# ---- shots ----

func _setup() -> void:
	if shot == "title" or shot == "end":
		return
	start_run()
	match shot:
		"day":
			scene(PH_DAY, 0.12, true)
			for s in get_nodes_in_group("structures"):
				if s is Fence and Geo.flat_dist(s.global_position, Terrain.beach_point(0, 0.9)) < 2.0:
					s.take_damage(60)
					_actors["fence"] = s
			place(Terrain.beach_point(0, 0.42, 0.5))
			main.hud.visible = true
		"dusk":
			scene(PH_DAY, 0.3, false)
			place(Vector3(-2.6, 0.0, 3.4))
			camera(Vector3(5.5, Terrain.CRAG_TOP + 5.0, 14.0), Vector3(-0.6, Terrain.CRAG_TOP + 4.6, 0.5), 52.0)
		"beam":
			scene(PH_NIGHT, 1.0, true)
			place(SPAWN)
			player._toggle_operate()
			game_camera()
			for i in 3:
				var b := spawn(Bloated, Terrain.beach_point(0, 0.12 + 0.12 * float(i), -1.0 + float(i)))
			spawn(Bloated, Terrain.beach_point(2, 0.25))
			spawn(Bloated, Terrain.beach_point(1, 0.3))
			weather()._strike_t = 7.5
		"ledge":
			scene(PH_NIGHT, 0.9, false)
			var lp := Terrain.ledge_point(0.46)
			var out := Vector3(lp.x, 0.0, lp.z).normalized()
			place(Terrain.ledge_point(0.5) - out * 0.7)
			var lb := spawn(Bloated, Terrain.ledge_point(0.37))
			lb.speed = 0.0
			_actors["b"] = lb
			camera(lp + out * 7.0 + Vector3(0.0, 4.5, 0.0), lp + Vector3(0.0, 0.3, 0.0), 50.0)
		"squid":
			scene(PH_NIGHT, 0.9, false)
			place(Vector3(1.8, 0.0, 2.6))
			var foot := Terrain.at_angle(30.0, 9.6)
			_actors["s"] = hold(spawn(Squid, foot))
			camera(Vector3(9.0, Terrain.CRAG_TOP + 3.5, 11.0), Vector3(2.5, Terrain.CRAG_TOP - 1.5, 4.5), 55.0)
		"crab":
			scene(PH_NIGHT, 0.9, false)
			# Beside the cottage's west gable, out on the meadow.
			var cottage = _find(Cottage)
			var cp: Vector3 = cottage.global_position
			var outdir := Vector3(cp.x, 0.0, cp.z).normalized()
			var side := Vector3(outdir.z, 0.0, -outdir.x)
			if side.x > 0.0:
				side = -side
			var spot: Vector3 = ground(cp + side * (Cottage.WIDTH * 0.5 + 2.2), 0.0)
			var c := spawn(Crab, spot)
			hold(c)
			c.rotation.y = atan2(side.x, side.z)
			place(Vector3(2.0, 0.0, 2.6))
			var mid := (spot + cp) * 0.5
			camera(mid + outdir * 7.0 + side * 2.5 + Vector3(0.0, 5.5, 0.0), mid + Vector3(0.0, 0.8, 0.0), 50.0)
		"eel":
			scene(PH_NIGHT, 0.7, false)
			place(SPAWN)
			player._toggle_operate()
			var e := Eel.new()
			e.lighthouse = main.lighthouse
			var o := Terrain.beach_point(0, -0.2)
			e.origin = Vector3(o.x, Terrain.SEA_LEVEL, o.z)
			main.get_node("Enemies").add_child(e)
			_actors["e"] = e
			camera(Vector3(15.0, 17.0, 20.0), Vector3(4.0, 5.0, 0.0), 50.0)
		"smotherer":
			scene(PH_NIGHT, 0.8, false)
			place(Vector3(0.0, 0.0, Lighthouse.RADIUS + 0.7))
			var lh: Lighthouse = main.lighthouse
			var a := 0.55
			var s := spawn(Smotherer, lh.global_position + Vector3(sin(a) * 2.0, 0.0, cos(a) * 2.0))
			_actors["s"] = s
			camera(lh.global_position + Vector3(6.5, 5.0, 11.0), lh.global_position + Vector3(0.4, 5.0, 0.0), 50.0)
		"storm":
			scene(PH_NIGHT, 1.0, false)
			place(SPAWN)
			player._toggle_operate()
			for i in 3:
				spawn(Bloated, Terrain.beach_point(i, 0.3))
			spawn(Squid, Terrain.beach_point(1, 0.15))
			camera(Vector3(0.0, 30.0, 34.0), Vector3(0.0, 2.0, 2.0), 52.0)
		"garden":
			scene(PH_DAY, 0.15, false)
			var g: Garden = _find(Garden)
			root.get_node("Run").crops = [0, 2, 2, 1, 0]
			for p in g.plots:
				p.refresh()
			root.get_node("Stock").add("seaweed", 2)
			place(g.plots[0].global_position + Vector3(0.0, 0.0, 0.0))
			_actors["g"] = g
			camera(g.global_position + Vector3(-2.5, 4.2, 5.5), g.global_position + Vector3(0.0, 0.3, 0.0), 50.0)
		"cottage":
			scene(PH_DAY, 0.15, true)
			var cottage = _find(Cottage)
			var door: Vector3 = cottage.to_global(Vector3(0.0, 0.0, -Cottage.DEPTH * 0.5 - 0.9))
			place(door)
			_actors["c"] = cottage
			root.get_node("Stock").set_all({"food": 2, "scrap": 8, "bio": 4, "driftwood": 9, "seaweed": 3, "oil": 1})
			player.hp = 55
			game_camera()
		"trap":
			scene(PH_NIGHT, 0.9, false)
			var slot: TrapSlot = null
			for s in get_nodes_in_group("trap_slots"):
				if s.index == 2:
					slot = s
			root.get_node("Stock").add("driftwood", 2)
			slot.arm("spike")
			_actors["b"] = spawn(Bloated, Terrain.beach_point(2, 0.38))
			place(SPAWN)
			var sp := slot.global_position
			camera(sp + Vector3(-3.0, 4.0, 5.0).rotated(Vector3.UP, deg_to_rad(Terrain.BEACHES[2] - 180.0)), sp + Vector3(0.0, 0.4, 0.0), 50.0)
		"flare":
			scene(PH_NIGHT, 0.9, false)
			var target := Terrain.beach_point(1, 0.45)
			_actors["t"] = target
			var b := spawn(Bloated, target)
			b.speed = 0.4
			spawn(Squid, Terrain.beach_point(1, 0.25, 1.5))
			spawn(Bloated, Terrain.beach_point(1, 0.3, -1.5))
			place(Terrain.beach_point(1, 0.97))
			aim_at(target)
			var back := Terrain.beach_point(1, 1.4)
			camera(back + Vector3(1.5, 5.0, 0.0), target + Vector3(0.0, 0.5, 0.0), 50.0)
		"dawn":
			scene(PH_NIGHT, 0.6, true)
			place(SPAWN)
			game_camera()

func _direct(t: float) -> void:
	match shot:
		"title":
			pass
		"end":
			if at(0.0, t, "c"):
				# Just the island under the storm: no menu.
				if main.title != null:
					main.title.visible = false
				caption("Sea They Are Angry", "Work in progress · 3BL_Indie")
		"day":
			if at(0.0, t, "c"):
				caption("Day", "Scavenge the beaches, mend what the night broke.")
			var scrap := Terrain.beach_point(0, 0.62, -2.0)
			if t < 3.0:
				walk_to(scrap + (scrap - Terrain.beach_point(0, 0.6)).normalized() * 0.7, 0.2)
			elif at(3.0, t, "gather"):
				walk_to(player.global_position)
				tap("interact")
			elif t > 3.6 and t < 8.5:
				var f: Fence = _actors["fence"]
				walk_to(f.global_position + (Terrain.beach_point(0, 0.7) - f.global_position).normalized() * 1.1, 0.3)
			elif at(8.5, t, "hammer"):
				walk_to(player.global_position)
				tap("interact")
			var p := player.global_position
			if t > -1.5:
				camera(p + Vector3(5.5, 7.0, 7.5), p + Vector3(0.0, 0.6, 0.0), 45.0)
		"dusk":
			if at(0.0, t, "c"):
				caption("Dusk", "The lamp lights. The keeper works it from inside the tower.")
			if at(1.0, t, "light"):
				cyc._enter(PH_DUSK)
				cyc.running = false
				main._apply_lighting(PH_DUSK, 2.0)
				main.atmosphere.apply(PH_DUSK, 4.0)
				quiet_hud()
			if t > 2.5 and t < 3.5:
				walk_to(Vector3(-0.6, 0.0, 3.0))
			if at(3.5, t, "door"):
				walk_to(player.global_position)
				player._toggle_operate()
		"beam":
			if at(0.0, t, "c"):
				caption("Night", "The wide beam slows them. Focused, it burns them on the beaches.")
				main.hud.warn("Something stirs in the water — east.")
				root.get_node("Audio").horn([1.0], -5.0)
			var first: Enemy = null
			for e in get_nodes_in_group("enemies"):
				if e.global_position.x > 10.0:
					first = e
					break
			if t < 10.0 and first != null:
				aim_at(first.global_position)
			elif t >= 10.0:
				aim_at(Terrain.beach_point(2, 0.4))
			if at(2.0, t, "focus"):
				lamp.toggle_mode()
			# Then down onto the east beach to see it burn.
			if at(5.0, t, "close"):
				var bp := Terrain.beach_point(0, 0.3)
				camera(bp + Vector3(-4.0, 7.0, 7.5), bp + Vector3(0.0, 0.8, 0.0), 50.0)
				main.hud.visible = false
		"ledge":
			if at(0.0, t, "c"):
				caption("The ledge", "The only way up. A blow aimed outward knocks them off.")
			var b = _actors["b"]
			if at(0.0, t, "go") and is_instance_valid(b):
				b.speed = 1.15
			if is_instance_valid(b):
				aim_at(b.global_position)
				if t > 2.0 and Geo.flat_dist(b.global_position, player.global_position) < 1.7 and at(0.0, t, "swing"):
					player._attack()
					var out := Vector3(b.global_position.x, 0.0, b.global_position.z).normalized()
					b._knock = out * Enemy.SHOVE_SPEED
		"squid":
			if at(0.0, t, "c"):
				caption("The Wall-Crawling Squid", "Takes no path: straight up the cliffs at the keeper, and hides the others in ink.")
			var s = _actors["s"]
			if is_instance_valid(s):
				aim_at(s.global_position)
				if Geo.flat_dist(s.global_position, player.global_position) < 2.2 and player._attack_cd <= 0.0 and t > 3.0:
					player._attack()
		"crab":
			if at(0.0, t, "c"):
				caption("The Armoured Crab", "Comes for the cottage, shed and garden. Its shell turns blows from the front.")
		"eel":
			if at(0.0, t, "c"):
				caption("The Giant Constrictor Eel", "Surges up the beach and coils round the lighthouse. Burn its head.")
			var e = _actors["e"]
			if at(0.0, t, "skip") and is_instance_valid(e):
				e.state_t = Eel.ANNOUNCE_TIME - 2.5
			if at(2.6, t, "flash"):
				weather().strike(false, false)
			if is_instance_valid(e) and e.state == &"Coil":
				if lamp.mode == Lamp.Mode.WIDE:
					lamp.toggle_mode()
				aim_at(e._head.global_position)
		"smotherer":
			if at(0.0, t, "c"):
				caption("The Smotherer", "Climbs the tower and wraps itself over the lantern. Shake it down.")
			var s = _actors["s"]
			if at(0.0, t, "climb") and is_instance_valid(s):
				s._height = 3.5
				s.change_state(&"Climb")
			aim_at(main.lighthouse.global_position)
			if is_instance_valid(s):
				for k in 3:
					if at(5.5 + 0.7 * float(k), t, "shake%d" % k):
						player._attack_cd = 0.0
						player._attack()
		"storm":
			if at(0.0, t, "c"):
				caption("The storm", "It builds through dusk to a gale. Lightning shows what stands in the surf.")
			if at(2.0, t, "s1"):
				weather().strike(false, true)
			if at(6.0, t, "s2"):
				weather().strike(true, false)
			var k := t / 9.0
			camera(mix(Vector3(0.0, 30.0, 34.0), Vector3(-6.0, 22.0, 26.0), k), Vector3(0.0, 2.0, 2.0), 52.0)
		"garden":
			if at(0.0, t, "c"):
				caption("The garden", "Dig kelp into a bed by day; the potatoes are up by dawn.")
			var g: Garden = _actors["g"]
			if at(1.0, t, "plant"):
				tap("interact")
			if t > 3.0 and t < 4.5:
				walk_to(g.plots[1].global_position, 0.1)
			if at(4.6, t, "lift"):
				walk_to(player.global_position)
				tap("interact")
		"cottage":
			if at(0.0, t, "c"):
				caption("The cottage", "Eat to heal, load flares, mix dirty fuel, buy upgrades.")
			if at(1.0, t, "open"):
				tap("interact")
			if at(3.0, t, "eat") and ChoiceMenu.current != null:
				ChoiceMenu.current.choose(1)
			if at(4.8, t, "up") and ChoiceMenu.current != null:
				ChoiceMenu.current.choose(4)
		"trap":
			if at(0.0, t, "c"):
				caption("Traps", "Spike boards, kelp nets and chain plates on the creatures' paths.")
		"flare":
			if at(0.0, t, "c"):
				caption("The flare gun", "Two shots. It burns red where it lands and holds them off.")
			if at(1.5, t, "fire"):
				var f := Flare.new()
				aim_at(_actors["t"])
				player._aim_face_t = Player.AIM_FACE_TIME
				f.from = player.global_position + Vector3(0.0, 1.4, 0.0) + player._aim * 0.4
				f.to = ground(_actors["t"], 0.0)
				main.add_child(f)
				root.get_node("Run").flares[0] = 1
		"dawn":
			if at(0.0, t, "c"):
				caption("Dawn", "The keeper's log: what came, what stopped it, what it cost.")
			if at(1.0, t, "dawn"):
				main._tally = {"ashore": 14, "beam": 9, "fall": 2, "trap": 2, "flare": 1}
				cyc._enter(PH_DAWN)
				cyc.running = false
				main.atmosphere.apply(PH_DAWN, 3.0)

func _find(cls) -> Node:
	for n in main.get_children():
		if is_instance_of(n, cls):
			return n
	return null
