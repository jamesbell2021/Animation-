extends SceneTree
## Records one shot of the itch.io trailer with Godot's Movie Maker (see README.md here).
## Each shot stages a moment in one of the game's three scenes (Kirkhaven, the Escape,
## the rock), hides the HUD, and moves its own camera low and close. No captions: the
## text cards are added in the edit (tools/trailer/assemble.py).
##
##   godot --path . --resolution 1280x720 --write-movie take.avi --fixed-fps 30 \
##       -s res://tools/trailer/trailer_director.gd -- shot=<name>
##
## It prints "REC <seconds>": where the usable footage starts in the take.
##
## To look at a shot's staging without a full take (a frame costs a second or more with
## no GPU), ask for stills: nothing is drawn but the frames named, saved as PNGs:
##   godot --path . --resolution 1280x720 --fixed-fps 30 \
##       -s res://tools/trailer/trailer_director.gd -- shot=<name> stills=0.5,2.0 out=/tmp/x
##
## Your Continue save and profile are backed up first and put back afterwards.

const FPS := 30.0
const SAVES := ["user://run.json", "user://profile.json"]
const DAY := 0
const DUSK := 1
const NIGHT := 2
const DAWN := 3
const SCENES := {"harbour": "res://scenes/harbour.tscn", "escape": "res://scenes/escape.tscn", "rock": "res://scenes/main.tscn"}
## Each shot: its scene, its length (s), and the frames the scene is given to settle
## before the take starts (creatures rise, lights ease in).
const SHOTS := {
	"dusk": {"scene": "harbour", "len": 4.5, "warm": 20},
	"fog": {"scene": "harbour", "len": 5.0, "warm": 45},
	"hook": {"scene": "harbour", "len": 3.6, "warm": 45},
	"shotgun": {"scene": "harbour", "len": 3.4, "warm": 45},
	"fire": {"scene": "harbour", "len": 4.6, "warm": 45},
	"pier": {"scene": "harbour", "len": 4.2, "warm": 30},
	"boat": {"scene": "escape", "len": 4.4, "warm": 40},
	"arm": {"scene": "escape", "len": 4.6, "warm": 30},
	"beam": {"scene": "rock", "len": 4.6, "warm": 45},
	"rise": {"scene": "rock", "len": 5.0, "warm": 30},
	"camp": {"scene": "rock", "len": 4.4, "warm": 30},
	"blind": {"scene": "rock", "len": 4.6, "warm": 30},
	"rear": {"scene": "rock", "len": 4.6, "warm": 30},
}

var shot := "dusk"
var frame := 0
var main: Node
var player: Player
var cyc: Node
var run: Node
var cam: Camera3D
var _saved := {}
var _ready_at := -1
var _done := {}
var _a := {}
var _held: Array[Node] = []
var _stills: Array[int] = []
var _out := ""
var _opened := false

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("shot="):
			shot = a.substr(5)
		elif a.begins_with("stills="):
			for s in a.substr(7).split(","):
				_stills.append(int(round(float(s) * FPS)))
		elif a.begins_with("out="):
			_out = a.substr(4)
	if not SHOTS.has(shot):
		print("no shot called ", shot)
		quit(1)
		return
	for p in SAVES:
		if FileAccess.file_exists(p):
			_saved[p] = FileAccess.get_file_as_bytes(p)
	if FileAccess.file_exists("user://run.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://run.json"))
	if not _stills.is_empty():
		RenderingServer.render_loop_enabled = false

func _finalize() -> void:
	Terrain.chapter = 1
	for p in SAVES:
		if _saved.has(p):
			var f := FileAccess.open(p, FileAccess.WRITE)
			f.store_buffer(_saved[p])
			f.close()
		elif FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 1:
		var splash := root.get_node_or_null("StudioSplash")
		if splash:
			splash.free()
		_open()
		return false
	if _ready_at < 0:
		var cs := current_scene
		if cs == null or not ("player" in cs) or not ("hud" in cs) or cs.hud == null:
			return frame > 2000
		if cs.get("title") != null and cs.player == null:
			# The rock opens on its title: start the story on it.
			run.story_next = true
			cs.begin_run(false, 1)
		if cs.player == null:
			return frame > 2000
		main = cs
		player = main.player
		_ready_at = frame + 2
		return false
	if frame < _ready_at:
		return false
	var warm := int(SHOTS[shot]["warm"])
	var f := frame - _ready_at
	if f == 0:
		_common()
		call("_setup_" + shot)
	# Risen (Emerge takes under a second), then held still until the take starts.
	if f == warm - 6:
		for e in _held:
			if is_instance_valid(e):
				e.set_physics_process(false)
	if f == warm:
		print("REC %.3f" % (float(frame - 1) / FPS))
		for e in _held:
			if is_instance_valid(e):
				e.set_physics_process(true)
	var t := float(f - warm) / FPS
	call("_direct_" + shot, t)
	_quiet()
	if not _stills.is_empty():
		return _still_step(f - warm)
	return f >= warm + int(float(SHOTS[shot]["len"]) * FPS)

# Stills: draw only the frames asked for (and the one before each, to settle).
func _still_step(f: int) -> bool:
	var want := false
	for s in _stills:
		if f == s - 2 or f == s - 1 or f == s:
			want = true
	RenderingServer.render_loop_enabled = want
	if _stills.has(f - 1):
		var img := root.get_texture().get_image()
		var path := _out.path_join("%s_%05.2f.png" % [shot, float(f - 1) / FPS])
		img.save_png(path)
		print("still ", path)
	return f - 1 >= _stills.max()

func _open() -> void:
	run = root.get_node("Run")
	cyc = root.get_node("Cycle")
	var pl := root.get_node("Players")
	pl.wanted = 1
	pl.helpers = true
	run.next_difficulty = 1
	match String(SHOTS[shot]["scene"]):
		"harbour":
			run.enter_harbour = true
		"escape":
			run.carry = {"stock": {"arrows": 18, "shells": 12, "bombs": 3, "scrap": 3, "driftwood": 4},
				"arms": [["bow", "shotgun"], ["bow"], ["bow"]],
				"villagers": ["baird", "rennie", "duthie", "buchan", "main", "coull", "geddes"], "lost": [], "difficulty": 1}
			run.enter_escape = true
		"rock":
			run.story_next = true
	change_scene_to_file(String(SCENES[SHOTS[shot]["scene"]]))

# ---- helpers ----

## Every scene: no clock, no landings of its own, no HUD, the helpers standing by.
func _common() -> void:
	cyc.running = false
	if main.get("spawner") != null and main.spawner != null:
		main.spawner.process_mode = Node.PROCESS_MODE_DISABLED
	if main.get("events") != null and main.events != null:
		main.events.process_mode = Node.PROCESS_MODE_DISABLED
	if main.get("jobs") != null and main.jobs != null:
		main.jobs.process_mode = Node.PROCESS_MODE_DISABLED
	main.hud.visible = false
	for k in main.players:
		k.camera = null
		var brain: Node = k.get_node_or_null("KeeperAI")
		if brain != null:
			brain.process_mode = Node.PROCESS_MODE_DISABLED
	if main.get("director") != null and main.director != null:
		main.director.process_mode = Node.PROCESS_MODE_DISABLED
		if main.director.get("_overlay") != null:
			main.director._overlay.visible = false
	cam = Camera3D.new()
	cam.name = "TrailerCamera"
	main.add_child(cam)
	cam.current = true
	# The game's music is left out of the takes: the edit lays its own under them.
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), true)
	# No floating damage numbers (not saved: Settings.save is never called here).
	root.get_node("Settings").damage_numbers = false
	if main.get("ehud") != null and main.ehud != null:
		main.ehud.visible = false

## The game's cards and warnings, the floating name tags and keeper rings: out of shot.
func _quiet() -> void:
	var hud = main.hud
	if hud.get("_report_t") != null:
		hud._report_t = 0.0
		hud._report_label.visible = false
		hud._warn_t = 0.0
		hud._warn_label.visible = false
	if frame % 10 == 0 or frame - _ready_at < 3:
		for l in main.find_children("*", "Label3D", true, false):
			if (l as Label3D).billboard != BaseMaterial3D.BILLBOARD_DISABLED:
				(l as Label3D).layers = 0
		for k in main.players:
			var ring = k.get("_ring")
			if ring is VisualInstance3D:
				ring.layers = 0

func at(t: float, now: float, key: String) -> bool:
	if now >= t and not _done.has(key):
		_done[key] = true
		return true
	return false

## The time of day at once, the look put on whole (as tools/make_story_stills.gd does).
func phase(p: int, storm: float = 0.0) -> void:
	run.active = false
	cyc._enter(p)
	cyc.running = false
	for tw in get_processed_tweens():
		tw.kill()
	run.active = true
	if main.has_method("_apply_lighting"):
		main._apply_lighting(p, 0.0)
	if main.get("atmosphere") != null:
		main.atmosphere.apply(p, 0.0)
		var w = main.atmosphere.get("weather")
		if w != null:
			w.storm = storm
			w._target = storm
			w._strike_t = 999.0
	main.hud.visible = false
	for k in main.players:
		k._set_lantern(p == DUSK or p == NIGHT)

func shoot(pos: Vector3, look: Vector3, fov: float = 45.0) -> void:
	cam.fov = fov
	cam.look_at_from_position(pos, look, Vector3.UP)
	cam.current = true

func mix(a: Vector3, b: Vector3, k: float) -> Vector3:
	return a.lerp(b, smoothstep(0.0, 1.0, clampf(k, 0.0, 1.0)))

func ground(x: float, z: float, lift: float = 0.05) -> Vector3:
	return Vector3(x, Terrain.height_at(x, z) + lift, z)

func spawn(cls, pos: Vector3, face_to: Vector3 = Vector3.INF) -> Enemy:
	var e: Enemy = cls.new()
	e.lighthouse = main.lighthouse
	e.position = pos
	main.get_node("Enemies").add_child(e)
	if face_to != Vector3.INF:
		var d := face_to - pos
		e.rotation.y = atan2(-d.x, -d.z)
	return e

func hold(e: Node) -> Node:
	_held.append(e)
	return e

## Stand keeper `i` at a spot, facing a point.
func stand(i: int, pos: Vector3, toward: Vector3) -> Player:
	var k: Player = main.players[i]
	k.visible = true
	k.global_position = pos
	k.velocity = Vector3.ZERO
	var d := toward - pos
	d.y = 0.0
	k._aim = d.normalized()
	k.facing = atan2(-d.x, -d.z)
	k.rotation.y = k.facing
	k.ai_move = Vector2.ZERO
	k.ai_held = {}
	k.ai_just = {}
	return k

func away(i: int) -> void:
	var k: Player = main.players[i]
	k.visible = false
	k.global_position = Vector3(-30.0, 3.0, -30.0) + Vector3(float(i) * 2.0, 0.0, 0.0)
	k.set_physics_process(false)
	k._set_lantern(false)

func aim(k: Player, p: Vector3) -> void:
	var d := p - k.global_position
	d.y = 0.0
	if d.length() > 0.05:
		k._aim = d.normalized()
		k.facing = atan2(-d.x, -d.z)

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

## Steer the first keeper toward a point with the move actions, as a stick would.
func walk_to(target: Vector3, stop: float = 0.3, push: float = 1.0) -> bool:
	var d := target - player.global_position
	d.y = 0.0
	var arrived := d.length() < stop
	var dir := Vector3.ZERO if arrived else d.normalized() * push
	_axis("move_right", "move_left", dir.x)
	_axis("move_down", "move_up", dir.z)
	return arrived

func fog() -> FogBank:
	return main.atmosphere.fog

func flood(k: float) -> void:
	fog().flood = k
	fog()._push()

func street_lamps(which: Array) -> void:
	main.generator.fuel = 90.0
	for i in main.lamps.size():
		main.lamps[i].on = which.has(i)

func windows(which: Array) -> void:
	for i in main.houses.size():
		main.houses[i].set_lit(which.has(i), 0.0)

func harbour_light(lit: bool) -> void:
	main.lighthouse.lamp._set_state(1 if lit else 0)

# ---- Kirkhaven ----

# The town at dusk from out over the harbour: every lamp lit, windows lit, calm.
func _setup_dusk() -> void:
	phase(DUSK)
	street_lamps(range(11))
	windows([0, 2, 3, 4, 5, 6, 9, 10, 12, 13, 15])
	harbour_light(false)
	for i in 3:
		away(i)

func _direct_dusk(t: float) -> void:
	var k := t / 4.5
	shoot(mix(Vector3(-13.0, 3.4, 30.0), Vector3(-9.5, 3.0, 24.0), k), mix(Vector3(1.0, 4.4, 0.0), Vector3(1.5, 4.2, 0.0), k), 50.0)

## Night in the town: the seven indoors, the fog part-way over the quay.
func town_night(fl: float, lit: Array) -> void:
	phase(NIGHT)
	for v in main.villagers:
		v.go_inside()
	street_lamps(lit)
	windows([4])
	harbour_light(false)
	flood(fl)

## Send a creature at a point (not at whatever it would pick), every frame.
func drive(e, to: Vector3) -> void:
	if not is_instance_valid(e) or e.state != &"Approach":
		return
	if not _a.has("mark"):
		var m := Node3D.new()
		main.add_child(m)
		_a["mark"] = m
	var mark: Node3D = _a["mark"]
	mark.global_position = to
	e.target = mark
	e.route.clear()

func swing(k: Player, at_point: Vector3) -> void:
	aim(k, at_point)
	k.rotation.y = k.facing
	k._attack_cd = 0.0
	k._attack()

# The fog coming over the west slip, the lamps going out one after another, and what
# stands in it.
func _setup_fog() -> void:
	town_night(0.1, [0, 1, 2, 3, 4])
	for i in 3:
		away(i)
	var up := HarbourMap.landing_point(0, 1.0)
	var list: Array = []
	for spot in [[0.86, -1.2], [0.74, 1.0], [0.62, -0.3], [0.5, 1.6], [0.42, -1.6], [0.3, 0.4]]:
		var b := spawn(Bloated, HarbourMap.landing_point(0, float(spot[0]), float(spot[1])), up + Vector3(4.0, 0.0, -6.0))
		b.speed = 0.55
		hold(b)
		list.append(b)
	_a["list"] = list

func _direct_fog(t: float) -> void:
	var k := t / 5.0
	flood(lerpf(0.1, 0.4, smoothstep(0.0, 1.0, k)))
	if at(1.3, t, "l1"):
		main.lamps[1].on = false
	if at(2.3, t, "l2"):
		main.lamps[2].on = false
	if at(3.4, t, "l3"):
		main.lamps[3].on = false
	for b in _a["list"]:
		drive(b, Vector3(-4.0, 0.0, -30.0))
	shoot(mix(Vector3(-6.5, 3.0, 3.4), Vector3(-8.5, 2.7, 4.0), k), mix(Vector3(-15.0, 1.9, 8.5), Vector3(-15.0, 2.0, 8.0), k), 44.0)

# A keeper under the lamp east of the pier, the boathook into one of them.
const HOOK_AT := Vector3(5.2, 0.0, 3.2)

func _setup_hook() -> void:
	town_night(0.3, [4, 5])
	away(1)
	away(2)
	stand(0, ground(HOOK_AT.x, HOOK_AT.z), Vector3(9.0, 0.0, 3.6))
	var b := spawn(Bloated, ground(8.6, 3.5), HOOK_AT)
	hold(b)
	_a["b"] = b
	var c := spawn(Bloated, ground(11.5, 4.6), HOOK_AT)
	hold(c)
	_a["c"] = c

func _direct_hook(t: float) -> void:
	var b: Enemy = _a["b"]
	var bp: Vector3 = b.global_position if is_instance_valid(b) else Vector3(8.0, 0.0, 3.5)
	drive(b, Vector3(-20.0, 0.0, 3.0))
	drive(_a["c"], Vector3(-20.0, 0.0, 3.0))
	if t < 0.0:
		aim(player, bp)
	elif t < 0.75:
		var to := bp - player.global_position
		to.y = 0.0
		walk_to(bp - to.normalized() * 1.5, 0.15)
	elif at(0.75, t, "s1") or at(1.75, t, "s2") or at(2.7, t, "s3"):
		walk_to(player.global_position)
		swing(player, bp)
	else:
		aim(player, bp)
	var mid := (player.global_position + bp) * 0.5
	var k := t / 3.6
	shoot(mid + mix(Vector3(-0.8, 1.25, 4.6), Vector3(0.6, 1.1, 3.9), k), mid + Vector3(0.0, 1.15, 0.0), 40.0)

# The shotgun, both barrels, into three of them coming along the quay.
const GUN_AT := Vector3(-2.0, 0.0, 3.4)

func _setup_shotgun() -> void:
	town_night(0.3, [2, 3])
	away(1)
	away(2)
	stand(0, ground(GUN_AT.x, GUN_AT.z), Vector3(-9.0, 0.0, 3.6))
	run.arms[0] = ["bow", "shotgun"]
	run.barrels = 2
	root.get_node("Stock").set_amount("shells", 12)
	player.arsenal.select("shotgun")
	var list: Array = []
	for spot in [Vector3(-6.3, 0.0, 3.5), Vector3(-7.6, 0.0, 2.4), Vector3(-8.2, 0.0, 4.6)]:
		var b := spawn(Bloated, ground(spot.x, spot.z), GUN_AT)
		hold(b)
		list.append(b)
	_a["list"] = list

func _direct_shotgun(t: float) -> void:
	var first: Enemy = null
	for b in _a["list"]:
		drive(b, Vector3(20.0, 0.0, 3.4))
		if first == null and is_instance_valid(b) and b.hp > 0:
			first = b
	var tp: Vector3 = first.global_position if first != null else Vector3(-8.0, 0.0, 3.4)
	aim(player, tp)
	player._aim_face_t = 1.0
	if at(0.9, t, "f1") or at(1.9, t, "f2"):
		player.rotation.y = player.facing
		player.arsenal.fire_shot(player._aim)
	var k := t / 3.4
	var p := player.global_position
	shoot(p + mix(Vector3(2.9, 1.7, -1.7), Vector3(2.3, 1.55, -2.0), k), p + Vector3(-2.8, 1.05, 0.2), 44.0)

# A petrol bomb among them at the head of the east slip; then the flamer.
const FIRE_AT := Vector3(15.0, 0.0, 5.0)

func _setup_fire() -> void:
	town_night(0.3, [5])
	away(2)
	stand(0, ground(8.6, 3.2), FIRE_AT)
	stand(1, ground(10.2, 1.6), FIRE_AT)
	run.arms[1] = ["bow", "flamer"]
	run.flamer_fuel = 100.0
	main.players[1].arsenal.select("flamer")
	var list: Array = []
	for spot in [Vector3(14.2, 0.0, 4.6), Vector3(15.6, 0.0, 5.6), Vector3(16.2, 0.0, 3.9), Vector3(14.9, 0.0, 6.6), Vector3(17.2, 0.0, 5.2)]:
		var b := spawn(Bloated, ground(spot.x, spot.z), Vector3(8.0, 0.0, 3.0))
		b.speed = 0.7
		hold(b)
		list.append(b)
	_a["list"] = list

func _direct_fire(t: float) -> void:
	for b in _a["list"]:
		drive(b, Vector3(-10.0, 0.0, 2.5))
	var centre := Vector3.ZERO
	var n := 0
	for b in _a["list"]:
		if is_instance_valid(b):
			centre += b.global_position
			n += 1
	centre = centre / float(maxi(n, 1)) if n > 0 else ground(FIRE_AT.x, FIRE_AT.z)
	aim(player, centre)
	player._aim_face_t = 1.0
	var k2: Player = main.players[1]
	if at(0.25, t, "throw"):
		var bomb := PetrolBomb.new()
		bomb.thrower = player
		bomb.from = player.global_position + Vector3(0.0, 1.6, 0.0) + player._aim * 0.3
		bomb.to = Vector3(centre.x, Terrain.height_at(centre.x, centre.z), centre.z)
		main.add_child(bomb)
		if player.rig != null and player.rig.has_clip("throw"):
			player.rig.shot("throw")
	# The second keeper's flamer, held on whichever is nearest.
	var near: Enemy = null
	for b in _a["list"]:
		if is_instance_valid(b) and b.hp > 0 and (near == null or Geo.flat_dist(b.global_position, k2.global_position) < Geo.flat_dist(near.global_position, k2.global_position)):
			near = b
	if near != null:
		aim(k2, near.global_position)
		k2._aim_face_t = 1.0
	k2.ai_held = {"attack": t > 1.6}
	var k := t / 4.6
	shoot(mix(Vector3(20.6, 2.5, 2.2), Vector3(19.6, 2.7, 1.9), k), mix(Vector3(14.0, 2.4, 4.6), Vector3(13.4, 2.4, 4.4), k), 46.0)

# The last night: Kirkhaven's people running down the pier for the Mary Ann.
func _setup_pier() -> void:
	town_night(0.42, [3, 4])
	harbour_light(true)
	var board: Vector3 = ground(main.BOARD_AT.x, main.BOARD_AT.y)
	var folk: Array = main.villagers
	for i in folk.size():
		var v = folk[i]
		v.place(ground(-1.4 + float(i % 3) * 1.2, 6.5 + float(i) * 1.4), "about")
		v.walk_to(board, "aboard", true)
	away(1)
	away(2)
	stand(0, ground(1.0, 7.5), Vector3(0.0, 0.0, 0.0))
	run.arms[0] = ["bow", "shotgun"]
	player.arsenal.select("shotgun")
	var list: Array = []
	for spot in [Vector3(-1.5, 0.0, 3.4), Vector3(1.6, 0.0, 2.4), Vector3(3.4, 0.0, 4.0), Vector3(-3.6, 0.0, 2.6)]:
		var b := spawn(Bloated, ground(spot.x, spot.z), Vector3(0.0, 0.0, 12.0))
		hold(b)
		list.append(b)
	_a["list"] = list

func _direct_pier(t: float) -> void:
	for b in _a["list"]:
		drive(b, Vector3(0.0, 0.0, 40.0))
	aim(player, Vector3(0.0, 0.0, 2.0))
	player._aim_face_t = 1.0
	if at(1.2, t, "f1") or at(2.4, t, "f2"):
		player.rotation.y = player.facing
		player.arsenal.fire_shot(player._aim)
	var k := t / 4.2
	shoot(mix(Vector3(4.9, 4.9, 24.0), Vector3(4.6, 4.5, 22.6), k), mix(Vector3(0.6, 1.9, 11.0), Vector3(0.6, 1.9, 10.0), k), 52.0)

# ---- the Escape ----

func escape_common() -> void:
	main._board_t = 1.0e9
	main._next_hazard = 1.0e9
	main.travelled = main.distance * 0.3
	main.speed = main.SPEED
	main._first_board = false
	main._first_hit = false
	main._surge = 99

func deck(x: float, z: float) -> Vector3:
	return Vector3(x, EscapeMap.DECK_Y + 0.05, z)

# The Mary Ann in the fog, climbers up her starboard side, a keeper with the boathook.
func _setup_boat() -> void:
	escape_common()
	var list: Array = []
	var kinds := ["drowned", "bloated", "drowned", "drowned", "drowned"]
	var slots := [8, 9, 10, 12, 13]
	for i in slots.size():
		var b: Boarder = main.spawn_boarder(kinds[i], slots[i])
		b.state_t = 99.0 - float(i) * 0.25
		list.append(b)
	_a["list"] = list
	stand(0, deck(-0.2, 1.2), Vector3(-1.3, 0.0, 4.0))
	stand(2, deck(3.6, 0.9), Vector3(3.3, 0.0, 4.0))

func _direct_boat(t: float) -> void:
	var b: Boarder = _a["list"][1]
	if at(1.5, t, "s1") and is_instance_valid(b):
		player.global_position = b.rail_point() + Vector3(0.0, 0.05, 0.0)
		swing(player, b.global_position)
	var k := t / 4.4
	shoot(mix(Vector3(9.4, 2.3, 6.3), Vector3(8.2, 1.9, 6.6), k), mix(Vector3(0.0, 1.6, 0.6), Vector3(-0.6, 1.6, 0.6), k), 46.0)

# A great arm rears up out of the sea off her bow and comes down across her.
func _setup_arm() -> void:
	escape_common()
	stand(0, deck(3.6, -0.8), Vector3(10.0, 0.0, 2.0))
	stand(2, deck(-4.4, 0.9), Vector3(10.0, 0.0, 2.0))

func _direct_arm(t: float) -> void:
	if at(-0.15, t, "arm"):
		var arm: SeaArm = main._spawn_arm(main.travelled + 14.0)
		arm.side = 1.0
		_a["arm"] = arm
	var k := t / 4.6
	shoot(mix(Vector3(-4.2, 2.3, 6.0), Vector3(-3.2, 1.9, 5.6), k), mix(Vector3(4.5, 4.2, 2.6), Vector3(4.0, 3.6, 2.2), k), 58.0)

# ---- the rock ----

func rock_night(storm: float) -> void:
	phase(NIGHT, storm)
	main.lighthouse.lamp._set_state(Lamp.State.BURNING)
	main.lighthouse.lamp.fuel = Lamp.FUEL_MAX
	if main.camp != null and main.camp.generator != null:
		main.camp.generator.fuel = 100.0

func weather() -> Weather:
	return main.atmosphere.weather

## Turn the lamp's focused beam on a point and hold it there (it would sweep by itself).
func aim_lamp(point: Vector3) -> void:
	var lamp: Lamp = main.lighthouse.lamp
	var d := point - lamp.global_position
	lamp.showcase = false
	if lamp.mode != Lamp.Mode.FOCUSED:
		lamp.mode = Lamp.Mode.FOCUSED
		lamp._apply_mode()
	lamp.yaw = atan2(-d.x, -d.z)
	lamp.set_tilt(-rad_to_deg(atan2(-d.y, Vector2(d.x, d.z).length())))
	lamp._pivot.rotation.y = lamp.yaw
	lamp.set_physics_process(false)

# The focused beam down on the east beach, burning what stands on it.
func _setup_beam() -> void:
	rock_night(0.7)
	away(1)
	away(2)
	stand(0, Vector3(-1.6, Terrain.height_at(-1.6, 2.7) + 0.1, 2.7), Terrain.beach_point(0, 0.3))
	player._toggle_operate()
	var list: Array = []
	for spot in [[0.34, -0.6], [0.26, 1.0], [0.18, -1.4], [0.12, 0.3], [0.4, 1.8]]:
		var b := spawn(Bloated, Terrain.beach_point(0, float(spot[0]), float(spot[1])))
		hold(b)
		list.append(b)
	_a["list"] = list

func _direct_beam(t: float) -> void:
	var lamp: Lamp = main.lighthouse.lamp
	var first: Enemy = null
	for b in _a["list"]:
		if is_instance_valid(b) and b.hp > 0 and first == null:
			first = b
	var tp: Vector3 = first.global_position if first != null else Terrain.beach_point(0, 0.25)
	# Swinging in from the north onto them.
	var sweep := tp + Vector3(0.0, 0.0, -9.0) * (1.0 - smoothstep(-0.5, 0.9, t))
	aim(player, sweep)
	if at(-0.6, t, "focus") and lamp.mode == Lamp.Mode.WIDE:
		lamp.toggle_mode()
	var bp := Terrain.beach_point(0, 0.26)
	var k := t / 4.6
	shoot(bp + mix(Vector3(5.2, 1.5, 4.4), Vector3(4.4, 1.3, 3.6), k), bp + mix(Vector3(-3.0, 3.6, -0.5), Vector3(-3.0, 3.2, -0.5), k), 52.0)

func kraken_up(at_point: Vector2, ph: String) -> Kraken:
	main.story.raise_kraken()
	var kr: Kraken = main.story.kraken
	kr.global_position = Vector3(at_point.x, Terrain.SEA_LEVEL, at_point.y)
	kr.body.rise(0.1)
	kr._enter(ph)
	if kr._bar != null:
		kr._bar.visible = false
	_a["kr"] = kr
	return kr

# It rises off the east of the holm, over the camp's huts and wire.
func _setup_rise() -> void:
	rock_night(0.85)
	for i in 3:
		away(i)

func _direct_rise(t: float) -> void:
	if at(-0.1, t, "rise"):
		main.story.raise_kraken()
		var kr: Kraken = main.story.kraken
		kr.body.rise(4.2)
		if kr._bar != null:
			kr._bar.visible = false
		_a["kr"] = kr
	if at(2.2, t, "flash"):
		weather().strike(false, false)
	var c := Terrain.CAMP_C
	var k := t / 5.0
	shoot(mix(Vector3(c.x - 9.0, 3.4, c.y + 5.5), Vector3(c.x - 7.5, 3.0, c.y + 5.0), k), mix(Vector3(66.0, 6.0, 4.0), Vector3(67.0, 10.5, 4.0), k), 56.0)

# Stage one: its arms over the wire and down on the huts, the searchlights on them.
func _setup_camp() -> void:
	rock_night(0.85)
	for i in 3:
		away(i)
	var kr := kraken_up(Kraken.RISE_AT, "camp_east")
	kr._slam_t = 99.0

func _direct_camp(t: float) -> void:
	var kr: Kraken = _a["kr"]
	var c := Terrain.CAMP_C
	kr._slam_t = 99.0
	if at(0.2, t, "a1"):
		kr.body.arm_slam(1, Vector3(c.x + 4.4, Terrain.height_at(c.x + 4.4, c.y - 5.0), c.y - 5.0), 1.1)
	if at(1.0, t, "a2"):
		kr.body.arm_slam(2, Vector3(c.x + 4.6, Terrain.height_at(c.x + 4.6, c.y + 4.9), c.y + 4.9), 1.2)
	if at(1.9, t, "a3"):
		kr.body.arm_slam(3, Vector3(c.x - 4.6, Terrain.height_at(c.x - 4.6, c.y - 5.0), c.y - 5.0), 1.2)
	if at(2.6, t, "flash"):
		weather().strike(false, false)
	var k := t / 4.4
	shoot(mix(Vector3(c.x - 10.5, 3.2, c.y + 9.0), Vector3(c.x - 9.0, 2.7, c.y + 8.0), k), mix(Vector3(c.x + 9.0, 6.0, c.y - 1.0), Vector3(c.x + 9.0, 6.5, c.y - 1.0), k), 58.0)

func eyes_mid(kr: Kraken) -> Vector3:
	var eyes: Array = kr.body.eye_points()
	if eyes.size() >= 2:
		return ((eyes[0] as Vector3) + (eyes[1] as Vector3)) * 0.5
	return kr.global_position + Vector3(0.0, 4.0, 0.0)

# Stage three: at the east beach, the focused beam in its eyes. It is blinded.
func _setup_blind() -> void:
	rock_night(0.85)
	for i in 3:
		away(i)
	var kr := kraken_up(Kraken.LIGHT_AT, "light")
	kr.body.face(main.lighthouse.global_position)
	kr.body.arm_reach(1, Vector3(8.0, 5.0, -7.0))
	kr.body.arm_reach(2, Vector3(9.0, 3.0, 9.0))
	main.lighthouse.lamp.mode = Lamp.Mode.FOCUSED
	main.lighthouse.lamp._apply_mode()

func _direct_blind(t: float) -> void:
	var kr: Kraken = _a["kr"]
	kr._slam_t = 99.0
	kr._grip_t = 0.0
	var e := eyes_mid(kr)
	# The beam comes round from the south onto its face.
	var off := Vector3(0.0, 0.0, 16.0) * (1.0 - smoothstep(-0.2, 1.1, t))
	aim_lamp(e + off)
	if t > 1.1 and not kr.is_blind():
		kr.lit(Lamp.Mode.FOCUSED, 1.0 / FPS)
	if kr.is_blind():
		kr._lit_t = 0.2
		if at(0.0, t, "arms"):
			kr.body.arm_slam(3, Vector3(12.0, 2.0, -14.0), 2.5)
			kr.body.arm_slam(5, Vector3(24.0, 0.0, -14.0), 2.2)
	var k := t / 4.6
	shoot(mix(Vector3(-5.0, 13.5, 19.0), Vector3(-2.0, 12.6, 15.5), k), mix(Vector3(7.0, 10.6, 0.0), Vector3(9.0, 10.0, -1.0), k), 45.0)

# The last gasp: it heaves itself up out of the sea, pale eyes in the rain.
func _setup_rear() -> void:
	rock_night(1.0)
	for i in 3:
		away(i)
	var kr := kraken_up(Kraken.LIGHT_AT, "light")
	kr.body.face(main.lighthouse.global_position)
	kr._slam_t = 99.0

func _direct_rear(t: float) -> void:
	var kr: Kraken = _a["kr"]
	kr._slam_t = 99.0
	kr._grip_t = 0.0
	aim_lamp(kr.global_position + Vector3(0.0, 3.0, 0.0))
	if at(0.3, t, "rear"):
		kr._rear()
	if at(2.3, t, "flash"):
		weather().strike(false, false)
	var bp := Terrain.beach_point(0, 0.55, 3.0)
	var k := t / 4.6
	shoot(bp + mix(Vector3(0.0, 1.6, 2.0), Vector3(0.6, 1.3, 1.0), k), mix(kr.global_position + Vector3(0.0, 5.0, 0.0), kr.global_position + Vector3(0.0, 8.5, 0.0), k), 60.0)
