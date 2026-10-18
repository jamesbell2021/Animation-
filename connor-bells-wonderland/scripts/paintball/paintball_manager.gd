class_name PaintballManager
extends Node
## Paintball Battle rules. Everyone has 5 lives and a gun of paintballs (hold
## the use button to fire; it auto-aims at a rival roughly in front of you).
## Paint refills slowly on its own and fully from PAINT crates. Five hits and
## you're out; the last one standing wins. After 2:30 it's sudden death (one
## hit each) and at 4:00 the healthiest player wins.
## The host runs the rules and sends events; clients only show them.

signal net_event(event: String, args: Array)
signal splatted(victim_name: String, shooter_name: String, lives: int)
signal eliminated(victim_name: String, shooter_name: String, remaining: int)
signal battle_over(results: Array)
signal announcement(text: String)

const MAX_LIVES := 5
const MAX_AMMO := 12
const FIRE_INTERVAL := 0.3
const BALL_SPEED := 24.0
## Seconds you can't be hit again after a hit (you flash).
const SAFE_SECONDS := 1.5
## Random aim error for players (degrees); bots set their own.
const PLAYER_SPREAD := 3.0
const REGEN_SECONDS := 2.5
const CRATE_RESPAWN := 8.0
const SUDDEN_DEATH_AT := 150.0
const TIME_LIMIT := 240.0
const ASSIST_RANGE := 28.0
const ASSIST_DOT := 0.8

var game: GameManager
var arena: PaintballArena
var active: bool = false
var battle_time: float = 0.0

var _state: Dictionary = {}
var _out_order: Array[String] = []
var _crates: Array[PaintCrate] = []
var _crate_timers: Array[float] = []
var _status_timer: float = 0.0
var _sudden: bool = false
var _ending: bool = false


func setup(p_game: GameManager, p_arena: PaintballArena) -> void:
	game = p_game
	arena = p_arena
	for spot in arena.crate_spots:
		var crate := PaintCrate.new()
		crate.name = "PaintCrate%d" % _crates.size()
		game.add_child(crate)
		crate.global_position = spot
		_crates.append(crate)
		_crate_timers.append(0.0)


func register(c: Contestant) -> void:
	_state[str(c.name)] = _fresh()


## Bot gun settings: seconds between shots and aim error in degrees. Bots aim
## themselves, so they get no auto-aim.
func set_bot_gun(c: Contestant, interval: float, spread_degrees: float) -> void:
	var st: Dictionary = _state.get(str(c.name), {})
	if not st.is_empty():
		st["interval"] = interval
		st["spread"] = spread_degrees
		st["assist"] = false


func begin() -> void:
	active = true
	battle_time = 0.0


## Back to a fresh battle (restart): everyone back in with full lives and paint.
func reset() -> void:
	active = false
	_ending = false
	_sudden = false
	battle_time = 0.0
	_out_order.clear()
	for key in _state.keys():
		var old: Dictionary = _state[key]
		_state[key] = _fresh()
		for keep in ["interval", "spread", "assist"]:
			_state[key][keep] = old[keep]
	for i in range(_crates.size()):
		_crates[i].set_active(true)
		_crate_timers[i] = 0.0
	for node in get_tree().get_nodes_in_group("contestants"):
		var c := node as Contestant
		if c != null:
			_set_out(c, false)
	PaintSplat.clear_all(get_tree())


func get_lives(contestant_name: String) -> int:
	return int((_state.get(contestant_name, {}) as Dictionary).get("lives", 0))


func get_ammo(contestant_name: String) -> int:
	return int((_state.get(contestant_name, {}) as Dictionary).get("ammo", 0))


func get_hits(contestant_name: String) -> int:
	return int((_state.get(contestant_name, {}) as Dictionary).get("hits", 0))


func is_alive(contestant_name: String) -> bool:
	return bool((_state.get(contestant_name, {}) as Dictionary).get("alive", false))


func alive_count() -> int:
	var n := 0
	for key in _state.keys():
		if bool(_state[key]["alive"]):
			n += 1
	return n


func alive_contestants() -> Array[Contestant]:
	var out: Array[Contestant] = []
	for node in get_tree().get_nodes_in_group("contestants"):
		var c := node as Contestant
		if c != null and is_alive(str(c.name)):
			out.append(c)
	return out


## Positions of the crates that currently have paint in them.
func active_crate_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for crate in _crates:
		if crate.active:
			out.append(crate.global_position)
	return out


## Paint colour for a contestant (very dark colours shoot white paint).
static func paint_colour(c: Contestant) -> Color:
	if c == null:
		return Color.WHITE
	var col := c.body_colour
	if col.v < 0.3:
		return Color(0.9, 0.92, 1.0)
	return col


func _fresh() -> Dictionary:
	return {"lives": MAX_LIVES, "ammo": MAX_AMMO, "cooldown": 0.0, "regen": 0.0, "alive": true, "hits": 0, "out_time": 0.0,
		"interval": FIRE_INTERVAL, "spread": PLAYER_SPREAD, "assist": true, "safe": 0.0}


func _physics_process(delta: float) -> void:
	if not active or not multiplayer.is_server():
		return
	battle_time += delta
	for c in alive_contestants():
		var st: Dictionary = _state[str(c.name)]
		st["cooldown"] = float(st["cooldown"]) - delta
		st["safe"] = maxf(float(st["safe"]) - delta, 0.0)
		st["regen"] = float(st["regen"]) + delta
		if float(st["regen"]) >= REGEN_SECONDS:
			st["regen"] = 0.0
			st["ammo"] = mini(int(st["ammo"]) + 1, MAX_AMMO)
		var wants := c.use_held or c.use_requested
		c.use_requested = false
		if wants and float(st["cooldown"]) <= 0.0 and c.controls_enabled and not c.is_stumbling() and not _ending:
			if int(st["ammo"]) > 0:
				_fire(c, st)
			else:
				st["cooldown"] = 0.5
				SoundManager.world(self, "click", c.global_position)
		for i in range(_crates.size()):
			var crate := _crates[i]
			if not crate.active or int(st["ammo"]) >= MAX_AMMO:
				continue
			var off := crate.global_position - c.global_position
			if absf(off.y) < 2.0 and Vector2(off.x, off.z).length() < 1.5:
				st["ammo"] = MAX_AMMO
				crate.set_active(false)
				_crate_timers[i] = CRATE_RESPAWN
				SoundManager.world(self, "pickup", crate.global_position)
				_send("crate", [i, false])
	for i in range(_crates.size()):
		if _crate_timers[i] > 0.0:
			_crate_timers[i] -= delta
			if _crate_timers[i] <= 0.0:
				_crates[i].set_active(true)
				_send("crate", [i, true])
	_status_timer -= delta
	if _status_timer <= 0.0:
		_status_timer = 0.3
		_send_status()
	if battle_time >= SUDDEN_DEATH_AT and not _sudden:
		_sudden = true
		for key in _state.keys():
			if bool(_state[key]["alive"]):
				_state[key]["lives"] = 1
		_announce("SUDDEN DEATH! One hit and you're out!")
	if battle_time >= TIME_LIMIT and not _ending:
		_ending = true
		_announce("TIME UP!")
		_finish()


func _fire(c: Contestant, st: Dictionary) -> void:
	st["ammo"] = int(st["ammo"]) - 1
	st["cooldown"] = float(st["interval"])
	var dir := _aim(c) if bool(st["assist"]) else c.get_facing()
	var spread := deg_to_rad(float(st["spread"]))
	dir = dir.rotated(Vector3.UP, randf_range(-spread, spread))
	var flat := Vector3(dir.x, 0.0, dir.z).normalized()
	var origin := c.global_position + Vector3.UP * 1.15 + flat * 0.6
	var vel := dir * BALL_SPEED + Vector3.UP * 1.6
	var ball := Paintball.create(game, origin, vel, c, paint_colour(c), true)
	if ball != null:
		ball.hit_contestant.connect(_on_ball_hit)
	_shot_fx(origin, flat, paint_colour(c))
	_send("shot", [str(c.name), origin, vel])
	# Face where you shot so the gun points the right way.
	var visuals := c.get_visuals()
	if visuals != null and flat.length() > 0.1:
		visuals.rotation.y = atan2(-flat.x, -flat.z)


## Auto-aim: the best rival in front of you that you can see, else straight ahead.
func _aim(c: Contestant) -> Vector3:
	var facing := c.get_facing()
	var eye := c.global_position + Vector3.UP * 1.15
	var best: Contestant = null
	var best_score := -INF
	var space := c.get_world_3d().direct_space_state
	for other in alive_contestants():
		if other == c:
			continue
		var off := other.global_position + Vector3.UP * 0.8 - eye
		var dist := off.length()
		if dist > ASSIST_RANGE or dist < 0.1:
			continue
		var flat := Vector3(off.x, 0.0, off.z).normalized()
		var dot := flat.dot(facing)
		if dot < ASSIST_DOT:
			continue
		var query := PhysicsRayQueryParameters3D.create(eye, other.global_position + Vector3.UP * 0.8, Contestant.COURSE_LAYER)
		if not space.intersect_ray(query).is_empty():
			continue
		var score := dot * 2.0 - dist / ASSIST_RANGE
		if score > best_score:
			best_score = score
			best = other
	if best == null:
		return facing
	# Aim a little ahead of a moving target.
	var target := best.global_position + Vector3.UP * 0.8
	var travel := eye.distance_to(target) / BALL_SPEED
	target += Vector3(best.velocity.x, 0.0, best.velocity.z) * travel * 0.6
	return (target - eye).normalized()


func _on_ball_hit(ball: Paintball, victim: Contestant) -> void:
	if not active or _ending:
		return
	var key := str(victim.name)
	var st: Dictionary = _state.get(key, {})
	if st.is_empty() or not bool(st["alive"]) or float(st["safe"]) > 0.0:
		return
	st["lives"] = int(st["lives"]) - 1
	st["safe"] = SAFE_SECONDS
	var shooter_key := ball.owner_name
	if _state.has(shooter_key):
		_state[shooter_key]["hits"] = int(_state[shooter_key]["hits"]) + 1
	var push := Vector3(ball.velocity.x, 0.0, ball.velocity.z).normalized()
	victim.knock(push * 5.0 + Vector3.UP * 3.0, 0.35)
	_apply_hit(key, shooter_key, int(st["lives"]))
	_send("hit", [key, shooter_key, int(st["lives"])])
	if int(st["lives"]) <= 0:
		_eliminate(key, shooter_key)


func _eliminate(victim_name: String, shooter_name: String) -> void:
	var st: Dictionary = _state[victim_name]
	st["alive"] = false
	st["out_time"] = battle_time
	_out_order.append(victim_name)
	_apply_out(victim_name, shooter_name)
	_send("out", [victim_name, shooter_name])
	if alive_count() <= 1 and not _ending:
		_ending = true
		get_tree().create_timer(1.8, false).timeout.connect(_finish)


func _finish() -> void:
	if not active:
		return
	active = false
	var standing: Array = []
	for key in _state.keys():
		if bool(_state[key]["alive"]):
			standing.append(key)
	standing.sort_custom(func(a: String, b: String) -> bool:
		if get_lives(a) != get_lives(b):
			return get_lives(a) > get_lives(b)
		return get_hits(a) > get_hits(b))
	var order: Array = standing.duplicate()
	for i in range(_out_order.size() - 1, -1, -1):
		order.append(_out_order[i])
	var results: Array = []
	for i in range(order.size()):
		var key: String = order[i]
		var st: Dictionary = _state[key]
		results.append({
			"name": key,
			"place": i + 1,
			"time": battle_time if bool(st["alive"]) else float(st["out_time"]),
			"falls": 0,
			"finished": true,
			"hits": int(st["hits"]),
		})
	battle_over.emit(results)


# --- Shown on every screen ------------------------------------------------------

func apply_remote_event(event: String, args: Array) -> void:
	match event:
		"shot":
			var shooter := game.find_contestant(str(args[0]))
			var origin: Vector3 = args[1]
			var vel: Vector3 = args[2]
			Paintball.create(game, origin, vel, shooter, paint_colour(shooter), false)
			_shot_fx(origin, Vector3(vel.x, 0.0, vel.z).normalized(), paint_colour(shooter))
		"hit":
			var key := str(args[0])
			if _state.has(key):
				_state[key]["lives"] = int(args[2])
			_apply_hit(key, str(args[1]), int(args[2]))
		"out":
			var key := str(args[0])
			if _state.has(key):
				_state[key]["alive"] = false
			_apply_out(key, str(args[1]))
		"crate":
			var i := int(args[0])
			if i >= 0 and i < _crates.size():
				_crates[i].set_active(bool(args[1]))
		"status":
			var names: Array = args[0]
			var lives: Array = args[1]
			var ammo: Array = args[2]
			for i in range(names.size()):
				var key := str(names[i])
				if _state.has(key):
					_state[key]["lives"] = int(lives[i])
					_state[key]["ammo"] = int(ammo[i])
		"announce":
			announcement.emit(str(args[0]))


func _apply_hit(victim_name: String, shooter_name: String, lives: int) -> void:
	var victim := game.find_contestant(victim_name)
	var shooter := game.find_contestant(shooter_name)
	if victim != null:
		var colour := paint_colour(shooter)
		var pos := victim.global_position + Vector3.UP * 0.9
		_blink(victim)
		FX.burst(self, "paint", pos, colour, 1.4)
		FX.burst(self, "impact", pos, Color.WHITE, 0.8)
		PaintSplat.stick(victim, colour)
		SoundManager.world(self, "splat", pos, randf_range(0.9, 1.2), 3.0)
	splatted.emit(victim_name, shooter_name, lives)


func _apply_out(victim_name: String, shooter_name: String) -> void:
	var victim := game.find_contestant(victim_name)
	if victim != null:
		var colour := paint_colour(game.find_contestant(shooter_name))
		var pos := victim.global_position + Vector3.UP * 0.8
		FX.burst(self, "paint", pos, colour, 2.6)
		FX.burst(self, "paint", pos, paint_colour(victim), 2.0)
		FX.burst(self, "poof", pos, Color.WHITE, 1.5)
		FX.ring(self, victim.global_position, 4.0, colour)
		PaintSplat.place(game, victim.global_position + Vector3.UP * 0.05, Vector3.UP, colour)
		SoundManager.world(self, "boom", pos, 1.4, 1.0)
		_set_out(victim, true)
	eliminated.emit(victim_name, shooter_name, alive_count())


## Flashes a contestant while they're safe after a hit.
func _blink(c: Contestant) -> void:
	var visuals := c.get_visuals()
	if visuals == null:
		return
	var tween := visuals.create_tween()
	for i in range(int(SAFE_SECONDS / 0.15)):
		tween.tween_callback(func() -> void: visuals.visible = not visuals.visible).set_delay(0.075)
	tween.tween_callback(func() -> void: visuals.visible = true)


func _set_out(c: Contestant, out: bool) -> void:
	c.visible = not out
	c.controls_enabled = not out
	c.use_held = false
	if multiplayer.is_server():
		c.set_physics_process(not out)
		c.collision_layer = 0 if out else Contestant.CONTESTANT_LAYER
		c.collision_mask = 0 if out else (Contestant.COURSE_LAYER | Contestant.CONTESTANT_LAYER)


func _shot_fx(origin: Vector3, dir: Vector3, colour: Color) -> void:
	FX.burst(self, "sparks", origin + dir * 0.2, Color(colour.r * 1.5, colour.g * 1.5, colour.b * 1.5), 0.4)
	SoundManager.world(self, "paintgun", origin, randf_range(0.9, 1.1), -2.0)


func _send_status() -> void:
	var names: Array = []
	var lives: Array = []
	var ammo: Array = []
	for key in _state.keys():
		names.append(key)
		lives.append(int(_state[key]["lives"]))
		ammo.append(int(_state[key]["ammo"]))
	_send("status", [names, lives, ammo])


func _announce(text: String) -> void:
	announcement.emit(text)
	_send("announce", [text])


func _send(event: String, args: Array) -> void:
	if multiplayer.is_server():
		net_event.emit(event, args)
