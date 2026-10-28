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
	# Update 1.1 trailer (assemble.py update)
	"shield": 5.5, "gauge": 5.5, "lockon": 6.0, "hornets": 4.5, "mortars": 4.5,
	"barrier": 5.5, "gunship": 5.0, "storm": 5.5, "demomenu": 4.0,
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


## A scripted crew member: the shot sets its stick and ACTION button directly.
class ScriptInput extends PlayerInput:
	var hold := false
	var stick := Vector2.ZERO
	var _was := false

	func _init(dev: int) -> void:
		device = dev

	func poll() -> void:
		action_pressed = hold and not _was
		action_held = hold
		_was = hold
		interact_pressed = false
		move = stick
		aim = stick


func _initialize() -> void:
	shot = OS.get_cmdline_user_args()[0]
	# No studio splash in trailer takes.
	var splash := root.get_node_or_null("StudioSplash")
	if splash:
		splash.free()
	g = root.get_node("G")
	g.menu_done = true
	g.music_on = false
	g.ai_crew = true
	g.round_seed = SEED
	g.joined_devices.clear()
	if shot == "demomenu":
		# The free demo's title menu.
		g.demo = true
		g.demo_left = g.DEMO_SECONDS
		g.menu_done = false
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
	# Snap the turret round so the shell leaves in that direction this frame.
	tank.turret.global_rotation.y = tank.turret_yaw
	tank._fire_cannon(Color(1.0, 0.3, 0.85))


## True on the one frame that is `k` seconds into the shot.
func _at(k: float) -> bool:
	return frame == WARMUP + int(round(k * FPS))


## Seats the crew: station id -> a ScriptInput, or "bot" (the default) for the AI crew.
func _crew_with(spec: Dictionary) -> void:
	var dev := 7
	for id in ["drive", "cannon", "mg", "repair"]:
		var input: PlayerInput = spec.get(id) if spec.get(id) is PlayerInput else null
		if input == null:
			if spec.get(id, "bot") == "idle":
				input = ScriptInput.new(dev)
				dev += 1
			else:
				input = BotInput.new(main.players.size())
		var c := main._add_crew(input)
		tank.occupy(tank.stations[id], c)


## A free spot for an enemy near a point (or the point itself if nothing is free).
func _free_near(p: Vector3, radius := 1.5) -> Vector3:
	for i in 24:
		var q := p + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * (i * 0.4)
		if main._is_free(q, radius):
			return Vector3(q.x, 0.0, q.z)
	return p


## Screen-space offset on the ground (x right, y up the screen), for framing.
func _screen(right: float, up: float) -> Vector3:
	return main._screen_right * right + main._screen_up * up


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



# --- Update 1.1 shots --------------------------------------------------------------------------

## Hold ACTION: the energy shield takes a barrage of shells and rockets, rippling where they hit.
func _setup_shield() -> void:
	data["mech"] = ScriptInput.new(7)
	_crew_with({"repair": data["mech"], "drive": "idle", "cannon": "idle", "mg": "idle"})
	_hide_labels()
	main._gate.visible = false
	var c := tank.global_position
	data["foes"] = _ring("tank", 2, c, 17.0, 19.0, 0.4, 1.3) + _ring("rpg", 3, c, 13.0, 15.0, 2.2, 3.6)
	for e in data["foes"]:
		e.max_hp = 900.0
		e.hp = 900.0
	main.cinematic = func(_d: float) -> void: pass


func _shot_shield(t: float) -> void:
	var m: ScriptInput = data["mech"]
	m.hold = true
	tank.shield = MegaTank.SHIELD_MAX
	if frame == WARMUP - 25:
		var i := 0
		for e in data["foes"]:
			if is_instance_valid(e):
				e._cooldown = 0.1 + i * 0.55
			i += 1
	# Extra shells and rockets from off-screen, so the bubble is under constant fire.
	if frame >= WARMUP - 12 and (frame - WARMUP) % 9 == 0:
		var a := frame * 0.61
		var c := tank.global_position
		var start := c + Vector3(sin(a), 0, cos(a)) * 21.0 + Vector3(0, 0.7, 0)
		var v := c + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-2, 2)) - start
		v.y = 0.0
		var kind := "rocket" if frame % 2 == 0 else "enemy_shell"
		g.spawn_projectile(start, v.normalized() * 26.0, 1, kind, Color(1.0, 0.3, 0.2))
	var s := _ease(t / DURATION["shield"])
	var c := tank.global_position
	var a := lerpf(0.35, 1.05, s)
	var r := lerpf(18.0, 15.0, s)
	_persp(c + Vector3(sin(a) * r, lerpf(9.0, 6.5, s), cos(a) * r), c + Vector3(0, 1.0, 0), 50.0)


## The REPAIR timing game with the HUD on: a streak of PERFECT welds and a growing combo.
func _setup_gauge() -> void:
	data["mech"] = ScriptInput.new(7)
	_crew_with({"repair": data["mech"], "drive": "idle"})
	_battle()
	main.hud.hidden_for_film = false
	main.wave = 5
	main.survival_time = 187.0
	g.score = 5120
	data["hurt"] = true
	tank.hp = 96.0
	var c := tank.global_position
	_ring("rifle", 5, c, 17.0, 21.0, 2.6, 4.2)
	main.cinematic = func(_d: float) -> void:
		_iso(12.5, tank.global_position + _screen(4.6, 0.6) + Vector3(0, 1.2, 0))


func _shot_gauge(_t: float) -> void:
	var m: ScriptInput = data["mech"]
	if m.hold:
		m.hold = false
		return
	if frame < WARMUP - 6 or tank.rep_stun > 0.0 or frame - int(data.get("last", -99)) < 6:
		return
	# Where the needle will be when the tank reads this press (after this frame's step).
	var next := pingpong(tank.needle_phase + tank.needle_speed() / FPS, 1.0)
	var d := absf(next - tank.zone_center)
	var waited := frame - int(data.get("last", -99)) > FPS * 1.2
	if d < tank.zone_half * 0.3 or (waited and d < tank.zone_half * 0.8):
		m.hold = true
		data["last"] = frame


## Snap-aim: the gunner flicks the stick from target to target; the aim assist locks each one,
## the reticle sits on it and the shell lands.
func _setup_lockon() -> void:
	data["gun"] = ScriptInput.new(7)
	_crew_with({"cannon": data["gun"], "drive": "idle", "mg": "idle", "repair": "idle"})
	main._gate.visible = false
	var c := tank.global_position
	var plan := [["rifle", 35.0, 17.0], ["tank", 205.0, 19.0], ["rifle", 110.0, 16.0],
		["drone", 290.0, 17.0], ["rifle", 160.0, 18.0], ["rifle", 330.0, 15.0]]
	var targets := []
	for p in plan:
		var a := deg_to_rad(p[1])
		var e := _spawn(p[0], _free_near(c + Vector3(sin(a), 0, cos(a)) * float(p[2])))
		if e is EnemyTank:
			e.max_hp = 50.0
			e.hp = 50.0
		targets.append(e)
	data["targets"] = targets
	main.cinematic = func(_d: float) -> void: _iso(16.5, tank.global_position + Vector3(0, 1.0, 0))


func _shot_lockon(t: float) -> void:
	var gun: ScriptInput = data["gun"]
	var targets: Array = data["targets"]
	for i in targets.size():
		var k := 0.25 + i * 1.02
		if _at(k) and is_instance_valid(targets[i]):
			var to: Vector3 = (targets[i] as Enemy).global_position - tank.turret.global_position
			to.y = 0.0
			# Slightly off target: the aim assist does the rest.
			gun.stick = main.world_to_stick(to.normalized().rotated(Vector3.UP, deg_to_rad(5.0))).normalized()
			gun.hold = true
		if _at(k + 0.12):
			gun.hold = false
		if _at(k + 0.4):
			gun.stick = Vector2.ZERO


## Hornet swarms weave in; the MG shreds them and the rest pop on the shield.
func _setup_hornets() -> void:
	_crew_with({"drive": "idle"})
	main._gate.visible = false
	main.cinematic = func(_d: float) -> void: _iso(15.0, tank.global_position + Vector3(0, 1.0, 0))


func _shot_hornets(_t: float) -> void:
	var c := tank.global_position
	for w in 3:
		if frame == WARMUP - 30 + w * 28:
			var a := 0.8 + w * 2.1
			var base := c + Vector3(sin(a), 0, cos(a)) * 24.0
			for i in 5:
				_spawn("hornet", base + Vector3(randf_range(-2.5, 2.5), 0, randf_range(-2.5, 2.5)))


## Mortar rounds rain down: red rings close in, the tank drives out from under them.
func _setup_mortars() -> void:
	data["drive"] = ScriptInput.new(7)
	_crew_with({"drive": data["drive"], "repair": "idle"})
	_battle()
	main._gate.visible = false
	tank.rotation.y = -PI * 0.5  # facing +x, down the street
	var c := tank.global_position
	data["teams"] = [_spawn("mortar", _free_near(c + Vector3(30, 0, 13), 2.0)),
		_spawn("mortar", _free_near(c + Vector3(20, 0, -15), 2.0))]
	main.cinematic = func(_d: float) -> void:
		_iso(16.0, tank.global_position + Vector3(5.0, 1.0, 0))


func _shot_mortars(_t: float) -> void:
	var d: ScriptInput = data["drive"]
	if frame >= WARMUP - 10:
		d.stick = main.world_to_stick(Vector3(1, 0, 0)).normalized()
	if frame >= WARMUP - 20 and (frame - WARMUP + 20) % 17 == 0:
		var c := tank.global_position
		var fwd := -tank.global_basis.z
		var target := c + fwd * randf_range(1.0, 5.0) + fwd.cross(Vector3.UP) * randf_range(-2.5, 2.5)
		var start := c + Vector3(randf_range(18, 26), 1.5, randf_range(-14, 14))
		var shell := MortarShell.new()
		shell.setup(start, target, 1.5, Color(1.0, 0.45, 0.2))
		shell.damage = 8.0
		g.fx_root.add_child(shell)


## The cannon pounds a barrier truck's dome until it overloads, then takes out the truck.
func _setup_barrier() -> void:
	_crew_with({"drive": "idle", "cannon": "idle", "mg": "idle", "repair": "idle"})
	_hide_labels()
	main._gate.visible = false
	var c := tank.global_position
	var at := _free_near(c + Vector3(-12.0, 0, 13.0), 2.5)
	var truck: ShieldTruck = _spawn("truck", at)
	truck.dome_max = 300.0
	truck.dome_hp = 300.0
	truck.set_physics_process(false)
	data["truck"] = truck
	data["men"] = []
	for off in [Vector3(2.6, 0, 1.5), Vector3(-2.4, 0, 2.2), Vector3(1.5, 0, -2.6)]:
		data["men"].append(_spawn("rifle", _free_near(at + off, 0.8)))
	data["at"] = at
	main.cinematic = func(_d: float) -> void: _iso(14.5, c.lerp(at, 0.55) + Vector3(0, 1.5, 0))


func _shot_barrier(_t: float) -> void:
	var truck: Variant = data["truck"]
	var at: Vector3 = data["at"]
	for k in [0.3, 0.95, 1.6, 2.25, 3.0, 3.7]:
		if _at(k):
			_fire_at(at + Vector3(0, 0, 0))
	if _at(4.4):
		for m in data["men"]:
			if is_instance_valid(m):
				_fire_at((m as Enemy).global_position)
				break


## A gunship circles and fires a rocket salvo; the MG shoots the rockets down, the cannon
## brings the gunship down.
func _setup_gunship() -> void:
	_crew_with({"drive": "idle"})
	main._gate.visible = false
	var c := tank.global_position
	var gs: Gunship = _spawn("gunship", c + Vector3(-13.0, 0, -11.0))
	gs.max_hp = 5000.0
	gs.hp = 5000.0
	data["gs"] = gs
	data["mid"] = c.lerp(gs.global_position, 0.5)
	main.cinematic = func(_d: float) -> void:
		if is_instance_valid(data["gs"]) and not (data["gs"] as Enemy).dead:
			var want: Vector3 = tank.global_position.lerp((data["gs"] as Enemy).global_position, 0.45)
			data["mid"] = (data["mid"] as Vector3).lerp(want, 0.06)
		_iso(17.0, data["mid"] + Vector3(0, 2.5, 0))


func _shot_gunship(_t: float) -> void:
	var gs: Variant = data["gs"]
	if frame == WARMUP - 15 and is_instance_valid(gs):
		(gs as Gunship)._cooldown = 0.0
	if _at(3.4) and is_instance_valid(gs):
		_fire_at((gs as Enemy).global_position)
	if _at(3.8) and is_instance_valid(gs) and not (gs as Enemy).dead:
		(gs as Enemy).die()


## A themed wave with the HUD on: DRONE STORM banner, hornets, drones, a gunship.
func _setup_storm() -> void:
	_crew()
	_battle()
	main.hud.hidden_for_film = false
	main.wave = 8
	main.survival_time = 402.0
	g.score = 21480
	var c := tank.global_position
	_ring("drone", 3, c, 15.0, 19.0, 0.0, 2.0)
	_ring("rifle", 4, c, 17.0, 22.0, 3.0, 4.6)
	for a in [1.0, 4.0]:
		var base := c + Vector3(sin(a), 0, cos(a)) * 20.0
		for i in 5:
			_spawn("hornet", base + Vector3(randf_range(-2.5, 2.5), 0, randf_range(-2.5, 2.5)))
	_spawn("gunship", c + Vector3(16.0, 0, 12.0))


func _shot_storm(_t: float) -> void:
	if frame == WARMUP - 8:
		main._start_wave()
		main._wave_break = 0.0


## The free demo's title menu (record with g.demo on; see _initialize).
func _setup_demomenu() -> void:
	main.cinematic = func(_d: float) -> void:
		_iso(26.0, tank.global_position + Vector3(0, 1.0, 0))


func _shot_demomenu(_t: float) -> void:
	pass
