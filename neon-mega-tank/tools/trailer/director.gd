extends SceneTree
## Films one shot of the Neon Mega Tank trailer inside the game, with Godot's Movie Maker.
## record.sh runs it once per shot, then assemble.py cuts the shots together with title cards
## and the game's music. Usage:
##
##   godot --path . --resolution 1920x1080 --write-movie shot.avi --fixed-fps 30 \
##       -s tools/trailer/director.gd -- <shot> [--touch]
##
## Every shot starts with WARMUP frames (the scene settling) that assemble.py trims off.

const FPS := 30
const WARMUP := 45
const SEED := 20261013
const DURATION := {
	"reveal": 6.0, "crew": 5.0, "collapse": 5.0, "shootdown": 5.0, "combat": 5.5,
	"shouts": 5.0, "drones": 4.5, "phones": 5.0, "boss": 7.0, "finale": 9.0,
}
const ISO := Vector3(-35.264, 45.0, 0.0)

var shot := ""
var frame := 0
var g: Node
var main: Main
var tank: MegaTank
var cam: Camera3D
var ready_done := false
var data := {}


func _initialize() -> void:
	shot = OS.get_cmdline_user_args()[0]
	g = root.get_node("G")
	g.menu_done = true
	g.music_on = false
	g.ai_crew = true
	g.round_seed = SEED
	g.joined_devices.clear()
	change_scene_to_file("res://scenes/main.tscn")


func _process(_delta: float) -> bool:
	var scene := current_scene
	if scene == null or not scene is Main:
		return false
	main = scene
	frame += 1
	if not ready_done:
		ready_done = true
		tank = g.tank
		cam = main.camera
		main.hud.hidden_for_film = true
		call("_setup_" + shot)
	var t := maxf(0.0, float(frame - WARMUP) / FPS)
	call("_shot_" + shot, t)
	if not data.get("hurt", false):
		tank.hp = MegaTank.MAX_HP
	if frame >= WARMUP + int(DURATION[shot] * FPS):
		quit()
	return false


# --- Helpers ---------------------------------------------------------------------------------

func _crew(humans: Array = []) -> void:
	for input in humans:
		main._add_crew(input)
	while main.players.size() < 4:
		main._add_crew(BotInput.new(main.players.size()))


func _battle() -> void:
	main._set_state(Main.State.PLAYING)
	main._wave_break = 1.0e9  # no automatic waves: each shot spawns its own enemies


func _spawn(kind: String, pos: Vector3) -> Enemy:
	var e := main._create_enemy(kind)
	e.position = Vector3(pos.x, 0.0, pos.z)
	main._enemies_root.add_child(e)
	return e


func _ring(kind: String, count: int, center: Vector3, r0: float, r1: float, a0 := 0.0, a1 := TAU) -> Array:
	var out := []
	for i in count:
		var a := lerpf(a0, a1, (i + 0.5) / count) + randf_range(-0.15, 0.15)
		var r := randf_range(r0, r1)
		var p := center + Vector3(sin(a), 0.0, cos(a)) * r
		if main._is_free(p, 1.2):
			out.append(_spawn(kind, p))
	return out


## Fixed isometric camera centred on a point.
func _iso(size: float, focus: Vector3) -> void:
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = size
	cam.rotation_degrees = ISO
	cam.global_position = focus + cam.global_basis.z * 120.0


func _persp(pos: Vector3, look: Vector3, fov := 50.0) -> void:
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = fov
	cam.near = 0.1
	cam.global_position = pos
	cam.look_at(look, Vector3.UP)


func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _fire_at(target: Vector3) -> void:
	var d := target - tank.global_position
	tank.turret_yaw = atan2(-d.x, -d.z)
	tank._fire_cannon(Color(1.0, 0.3, 0.85))


## Tallest building column with a road beside it, for the demolition shot.
func _find_building() -> Dictionary:
	var best := {}
	for key in g.city.columns:
		var col: Array = g.city.columns[key]
		if col.size() < 4:
			continue
		var b: Block = col[0]
		var p := b.position
		var road_x := roundf(p.x / City.PERIOD) * City.PERIOD
		var gap := absf(p.x - road_x)
		if absf(p.x) > 50.0 or absf(p.z) > 50.0 or gap < 5.0 or gap > 9.0:
			continue
		if best.is_empty() or col.size() > best["height"]:
			best = {"height": col.size(), "pos": p, "road_x": road_x}
	return best


# --- Shots -----------------------------------------------------------------------------------

## A slow orbit down out of the night sky onto the mega tank in the neon city.
func _setup_reveal() -> void:
	_crew()
	_hide_labels()
	main.cinematic = func(_d: float) -> void: pass


## Floating name tags read as clutter in close perspective shots.
func _hide_labels() -> void:
	for c in main.players:
		c._label.visible = false
	for st in tank.stations.values():
		st.label.visible = false


func _shot_reveal(t: float) -> void:
	var s := _ease(t / DURATION["reveal"])
	var a := lerpf(-0.9, 0.75, s)
	var r := lerpf(60.0, 17.0, s)
	var h := lerpf(42.0, 6.5, s)
	var c := tank.global_position
	_persp(c + Vector3(sin(a) * r, h, cos(a) * r), c + Vector3(0, 1.6, 0), 48.0)


## Close on the deck: the crew run to their stations, then one breaks off to patch a breach.
func _setup_crew() -> void:
	_crew()
	_battle()
	main.cinematic = func(_d: float) -> void: _iso(9.5, tank.global_position + Vector3(0, 1.4, 0))


func _shot_crew(t: float) -> void:
	if frame == WARMUP:
		var spots := [Vector2(0.0, -1.5), Vector2(-1.2, 1.8), Vector2(1.2, 1.8), Vector2(0.0, 3.0)]
		for i in main.players.size():
			var c: Crew = main.players[i]
			tank.leave(c)
			c.deck_pos = spots[i]
	if is_equal_approx(t, 2.6):
		tank._add_breach(Vector2(-1.9, -1.2))


## The cannon takes the legs out from under a tower block and it comes down.
func _setup_collapse() -> void:
	_crew()
	var b := _find_building()
	data["b"] = b
	var p: Vector3 = b["pos"]
	var side := signf(p.x - b["road_x"])
	tank.global_position = Vector3(b["road_x"] - side * 2.0, 0.0, p.z + 12.0)
	tank.rotation.y = 0.0
	main.cinematic = func(_d: float) -> void:
		_iso(17.0, tank.global_position.lerp(p, 0.62) + Vector3(0, 3.0, 0))


func _shot_collapse(t: float) -> void:
	var p: Vector3 = data["b"]["pos"]
	for k in [0.4, 1.1, 1.8, 2.5, 3.2, 3.9]:
		if is_equal_approx(t, k):
			_fire_at(_standing_column_near(p, 7.0))


## Base of the tallest column still standing within reach of a point (the demolition target).
func _standing_column_near(p: Vector3, reach: float) -> Vector3:
	var best := p
	var best_h := 0
	for key in g.city.columns:
		var col: Array = g.city.columns[key]
		if col.is_empty() or not is_instance_valid(col[0]):
			continue
		var b: Block = col[0]
		if b.dead or b.position.distance_to(p) > reach:
			continue
		var d := (b.position - tank.global_position).length()
		if col.size() > best_h or (col.size() == best_h and d < (best - tank.global_position).length()):
			best = b.position
			best_h = col.size()
	return best


## RPG troopers paint the tank with lasers; the machine gun knocks their rockets out of the air.
func _setup_shootdown() -> void:
	_crew()
	var c := tank.global_position
	data["rpg"] = _ring("rpg", 4, c, 14.0, 16.5, 0.15, 1.45)
	for e in data["rpg"]:
		e.max_hp = 600.0
		e.hp = 600.0
	main.cinematic = func(_d: float) -> void: _iso(16.0, c + Vector3(5.0, 0.5, 6.0))


func _shot_shootdown(_t: float) -> void:
	if frame == WARMUP - 20:
		var i := 0
		for e in data["rpg"]:
			if is_instance_valid(e):
				e._cooldown = 0.2 + i * 0.7
			i += 1


## Full battle with the HUD: AI crew fighting a mixed wave.
func _setup_combat() -> void:
	_crew()
	_battle()
	main.hud.hidden_for_film = false
	main.wave = 6
	main.survival_time = 214.0
	g.score = 4210
	var c := tank.global_position
	_ring("rifle", 7, c, 18.0, 25.0)
	_ring("rpg", 3, c, 19.0, 24.0)
	_ring("tank", 1, c, 22.0, 24.0, 2.0, 2.5)
	_ring("drone", 2, c, 18.0, 22.0)


func _shot_combat(_t: float) -> void:
	pass


## Soldiers caught by the cannon cry out in electronic Japanese.
func _setup_shouts() -> void:
	_crew()
	var c := tank.global_position
	data["men"] = _ring("rifle", 6, c, 9.0, 12.5, 0.1, 2.1)
	for e in data["men"]:
		e.puppet = true  # stand and take it: the crew's guns can't kill them before their cue
		e._net_pos = e.position
	main.cinematic = func(_d: float) -> void: _iso(13.0, c + Vector3(6.0, 1.0, 3.0))


func _shot_shouts(t: float) -> void:
	var lines := [0, 7, 4, 8, 9, 5]
	var men: Array = data["men"]
	for i in men.size():
		if is_equal_approx(t, 0.4 + i * 0.75) and is_instance_valid(men[i]):
			var e: Enemy = men[i]
			_fire_at(e.global_position)
			g._last_voice = 0
			g.shout(e.global_position, VoiceLines.SOLDIER_DEATH[lines[i]], e.color)
			g.explode(e.global_position, 1.8, 0.0, 0, Color(1.0, 0.3, 0.85))
			e.die()


## Drones circle and strafe; kamikaze buggies race in.
func _setup_drones() -> void:
	_crew()
	var c := tank.global_position
	_ring("drone", 3, c, 16.0, 20.0, 0.0, 2.0)
	data["buggies"] = [_spawn("buggy", c + Vector3(-26.0, 0, 0)), _spawn("buggy", c + Vector3(0, 0, 28.0))]
	main.cinematic = func(_d: float) -> void: _iso(19.0, c + Vector3(0, 1.0, 2.0))


func _shot_drones(_t: float) -> void:
	data["hurt"] = true


## The phone interface: touch controls on screen while a player works the cannon.
func _setup_phones() -> void:
	# --touch already seated this device's touch player as P1; the AI fills the rest.
	_crew()
	_battle()
	main.hud.hidden_for_film = false
	main.wave = 4
	main.survival_time = 151.0
	g.score = 2380
	var me: Crew = main.players[0]
	tank.occupy(tank.stations["cannon"], me)
	var c := tank.global_position
	_ring("rifle", 6, c, 17.0, 23.0)
	_ring("rpg", 2, c, 18.0, 22.0)


func _shot_phones(t: float) -> void:
	var vp := root.get_viewport().get_visible_rect().size
	var stick := Vector2(230.0, vp.y - 200.0)
	if frame == WARMUP:
		_touch(0, stick, true)
	if frame >= WARMUP:
		var a := t * 1.3
		_drag(0, stick + Vector2(cos(a), sin(a)) * 90.0)
	var fire := fmod(t, 1.1) < 0.25
	if fire != data.get("fire", false):
		data["fire"] = fire
		_touch(1, Vector2(vp.x - 170.0, vp.y - 190.0), fire)


func _touch(idx: int, pos: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.position = pos
	e.pressed = down
	Input.parse_input_event(e)


func _drag(idx: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = idx
	e.position = pos
	Input.parse_input_event(e)


## 鬼戦車 ONI SENSHA rolls down the street towards the camera, horns glowing.
func _setup_boss() -> void:
	_crew()
	main._gate.visible = false
	var boss := _spawn("boss", Vector3(0.0, 0.0, -40.0))
	boss.rotation.y = PI
	boss._cooldown = 3.2
	boss._drone_cd = 4.0
	data["boss"] = boss
	main.cinematic = func(_d: float) -> void: pass


func _shot_boss(t: float) -> void:
	var boss: Enemy = data["boss"]
	if not is_instance_valid(boss):
		return
	var s := _ease(t / DURATION["boss"])
	var bp := boss.global_position
	var fwd := -boss.global_basis.z
	var side := boss.global_basis.x
	var pos := bp + fwd * lerpf(9.0, 15.0, s) + side * lerpf(5.0, 9.0, s) + Vector3(0, lerpf(1.2, 4.5, s), 0)
	_persp(pos, bp + Vector3(0, lerpf(3.0, 2.0, s), 0), 52.0)


## Hero shot to close on: low and in front of the tank as it opens fire on the city.
func _setup_finale() -> void:
	_crew()
	var b := _find_building()
	data["b"] = b
	var p: Vector3 = b["pos"]
	tank.global_position = Vector3(b["road_x"] - signf(p.x - b["road_x"]) * 2.0, 0.0, p.z + 13.0)
	tank.rotation.y = 0.0
	_hide_labels()
	main.cinematic = func(_d: float) -> void: pass


func _shot_finale(t: float) -> void:
	var s := _ease(t / 8.0)
	var c := tank.global_position
	# Low, in front of the tank on the side away from the building, so the shells fly past.
	var side := signf(data["b"]["pos"].x - c.x)
	var a := PI + side * lerpf(0.95, 0.45, s)
	var r := lerpf(9.5, 13.0, s)
	_persp(c + Vector3(sin(a) * r, lerpf(1.3, 3.2, s), cos(a) * r), c + Vector3(0, 2.0, 0), 50.0)
	var p: Vector3 = data["b"]["pos"]
	for k in [0.6, 1.5, 2.4, 3.3, 4.2]:
		if is_equal_approx(t, k):
			_fire_at(_standing_column_near(p, 7.0))
