class_name DodgemsManager
extends Node
## Dodgem Derby rules. Everyone drives a dodgem car with 3 lives. Ram rivals
## (the faster you hit, the harder they fly) and knock them off the rink into
## the Irish Sea; JUMP is a boost for big hits. Item boxes are on the rink too.
## Fall in and you lose a life and drop back into the middle; lose all 3 and
## you're out. The rink's outer rings sink at 1:00, 1:35 and 2:10; at 3:10
## whoever has the most lives left wins. Last driver left wins a silly prize.
## The host runs the rules and sends events; clients only show them.

signal net_event(event: String, args: Array)
signal dunked(victim_name: String, by_name: String, lives: int)
signal eliminated(victim_name: String, by_name: String, remaining: int)
signal bumped(rammer_name: String, victim_name: String, strength: float)
signal battle_over(results: Array)
signal announcement(text: String)

const MAX_LIVES := 3
const BUMP_DISTANCE := 2.05
const BOOST_SPEED := 10.0
const BOOST_COOLDOWN := 1.6
const SAFE_SECONDS := 2.5
## A fall counts as a knock-off by whoever last hit you within this many seconds.
const CREDIT_SECONDS := 5.0
const COLLAPSE_TIMES: Array[float] = [60.0, 95.0, 130.0]
const TIME_LIMIT := 190.0
## Car handling: momentum, sliding, slower turning.
const CAR_SPEED := 8.5
const CAR_ACCEL := 14.0
const CAR_FRICTION := 5.0
const CAR_HOP := 4.0

var game: GameManager
var arena: DodgemArena
var active: bool = false
var battle_time: float = 0.0

var _state: Dictionary = {}
var _out_order: Array[String] = []
var _pair_cooldown: Dictionary = {}
var _collapsed: int = 0
var _warned: int = 0
var _status_timer: float = 0.0
var _ending: bool = false
var _prev_y: Dictionary = {}


func setup(p_game: GameManager, p_arena: DodgemArena) -> void:
	game = p_game
	arena = p_arena


func register(c: Contestant) -> void:
	_state[str(c.name)] = _fresh()
	c.move_speed = CAR_SPEED
	c.acceleration = CAR_ACCEL
	c.friction = CAR_FRICTION
	c.jump_velocity = CAR_HOP
	c.air_control = 0.25
	c.turn_speed = 7.0
	c.fall_limit_y = DodgemArena.WATER_Y - 3.0
	_fit_bumper(c)
	DodgemCar.fit(c)
	if multiplayer.is_server():
		c.fell.connect(_on_fell.bind(c))
		c.jumped.connect(_on_jumped.bind(c))


## A wide round bumper so cars bounce off each other, not walk through.
func _fit_bumper(c: Contestant) -> void:
	var shape := c.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape == null:
		return
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.95
	cylinder.height = 1.3
	shape.shape = cylinder
	shape.position = Vector3(0.0, 0.65, 0.0)


## Hooks up item hits so a fall after one counts as a knock-off by the attacker.
func watch_items(items: ItemManager) -> void:
	if items != null:
		items.hit.connect(func(victim: String, attacker: String, _kind: int) -> void:
			if not attacker.is_empty() and attacker != victim:
				_credit(victim, attacker))


func begin() -> void:
	active = true
	battle_time = 0.0


func reset() -> void:
	active = false
	_ending = false
	battle_time = 0.0
	_collapsed = 0
	_warned = 0
	_out_order.clear()
	_pair_cooldown.clear()
	for key in _state.keys():
		_state[key] = _fresh()
	for node in get_tree().get_nodes_in_group("contestants"):
		var c := node as Contestant
		if c != null:
			_set_out(c, false)
	if arena != null:
		arena.restore_rings()


func get_lives(contestant_name: String) -> int:
	return int((_state.get(contestant_name, {}) as Dictionary).get("lives", 0))


func get_hits(contestant_name: String) -> int:
	return int((_state.get(contestant_name, {}) as Dictionary).get("dunks", 0))


func boost_ready(contestant_name: String) -> bool:
	return float((_state.get(contestant_name, {}) as Dictionary).get("boost", 0.0)) <= 0.0


func is_alive(contestant_name: String) -> bool:
	return bool((_state.get(contestant_name, {}) as Dictionary).get("alive", false))


func is_safe(contestant_name: String) -> bool:
	return float((_state.get(contestant_name, {}) as Dictionary).get("safe", 0.0)) > 0.0


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


func _fresh() -> Dictionary:
	return {"lives": MAX_LIVES, "alive": true, "dunks": 0, "out_time": 0.0, "safe": 0.0, "boost": 0.0,
		"last_by": "", "last_by_time": -100.0}


func _process(_delta: float) -> void:
	# Splashdown effects on every screen.
	for node in get_tree().get_nodes_in_group("contestants"):
		var c := node as Contestant
		if c == null or not c.visible:
			continue
		var key := str(c.name)
		var y := c.global_position.y
		var prev := float(_prev_y.get(key, y))
		if prev >= DodgemArena.WATER_Y and y < DodgemArena.WATER_Y:
			var pos := Vector3(c.global_position.x, DodgemArena.WATER_Y, c.global_position.z)
			FX.burst(self, "splash", pos, Color.WHITE, 1.6)
			FX.ring(self, pos + Vector3.UP * 0.1, 4.0, Color(0.6, 0.85, 1.0))
			SoundManager.world(self, "splash", pos, randf_range(0.7, 0.9), 8.0)
		_prev_y[key] = y


func _physics_process(delta: float) -> void:
	if not active or not multiplayer.is_server():
		return
	battle_time += delta
	var alive := alive_contestants()
	for c in alive:
		var st: Dictionary = _state[str(c.name)]
		st["safe"] = maxf(float(st["safe"]) - delta, 0.0)
		st["boost"] = maxf(float(st["boost"]) - delta, 0.0)
	for key in _pair_cooldown.keys():
		_pair_cooldown[key] = float(_pair_cooldown[key]) - delta
	for i in range(alive.size()):
		for j in range(i + 1, alive.size()):
			_check_bump(alive[i], alive[j])
	_rink_schedule()
	_status_timer -= delta
	if _status_timer <= 0.0:
		_status_timer = 0.3
		_send_status()
	if battle_time >= TIME_LIMIT and not _ending:
		_ending = true
		_announce("TIME UP!")
		_finish()


## Two cars touching: the one closing faster does the ramming.
func _check_bump(a: Contestant, b: Contestant) -> void:
	var offset := b.global_position - a.global_position
	if absf(offset.y) > 1.2:
		return
	offset.y = 0.0
	var dist := offset.length()
	if dist > BUMP_DISTANCE or dist < 0.01:
		return
	var n := offset / dist
	var closing := Vector3(a.velocity.x - b.velocity.x, 0.0, a.velocity.z - b.velocity.z).dot(n)
	if closing < 2.0:
		return
	var key := "%s|%s" % [a.name, b.name]
	if float(_pair_cooldown.get(key, 0.0)) > 0.0:
		return
	_pair_cooldown[key] = 0.35
	# Whoever was moving faster along the hit line is the rammer.
	var a_speed := Vector3(a.velocity.x, 0.0, a.velocity.z).dot(n)
	var b_speed := -Vector3(b.velocity.x, 0.0, b.velocity.z).dot(n)
	var rammer := a if a_speed >= b_speed else b
	var victim := b if rammer == a else a
	var dir := n if rammer == a else -n
	var push := closing * 0.95 + 3.0
	if is_safe(str(victim.name)):
		push *= 0.3
	push *= _weight(victim)
	victim.velocity += dir * push + Vector3.UP * (2.0 + closing * 0.15)
	rammer.velocity -= dir * (closing * 0.35 + 1.0)
	_credit(str(victim.name), str(rammer.name))
	var pos := (a.global_position + b.global_position) * 0.5 + Vector3.UP * 0.5
	_bump_fx(str(rammer.name), str(victim.name), pos, closing)
	_send("bump", [str(rammer.name), str(victim.name), pos, closing])


## Fat (cake) cars are hard to shift; shrunk ones fly.
func _weight(c: Contestant) -> float:
	var status := c.get_node_or_null("StatusEffects") as StatusEffects
	if status == null:
		return 1.0
	if status.has_effect(StatusEffects.Effect.FAT):
		return 0.45
	if status.has_effect(StatusEffects.Effect.SMALL):
		return 1.6
	return 1.0


func _credit(victim_name: String, by_name: String) -> void:
	var st: Dictionary = _state.get(victim_name, {})
	if st.is_empty():
		return
	st["last_by"] = by_name
	st["last_by_time"] = battle_time


func _on_jumped(c: Contestant) -> void:
	var st: Dictionary = _state.get(str(c.name), {})
	if st.is_empty() or not active or not bool(st["alive"]) or float(st["boost"]) > 0.0:
		return
	st["boost"] = BOOST_COOLDOWN
	c.velocity += c.get_facing() * BOOST_SPEED
	_boost_fx(str(c.name))
	_send("boost", [str(c.name)])


## Host: a contestant went into the sea (fires just before they respawn).
func _on_fell(c: Contestant) -> void:
	var key := str(c.name)
	var st: Dictionary = _state.get(key, {})
	if st.is_empty() or not bool(st["alive"]) or not active:
		return
	st["lives"] = int(st["lives"]) - 1
	var by := ""
	if battle_time - float(st["last_by_time"]) < CREDIT_SECONDS:
		by = str(st["last_by"])
		if _state.has(by):
			_state[by]["dunks"] = int(_state[by]["dunks"]) + 1
	st["last_by"] = ""
	if int(st["lives"]) > 0:
		# Drop back in somewhere in the middle, safe for a moment.
		var r := minf(3.5, arena.outer_radius() * 0.5)
		var a := randf() * TAU
		c.set_respawn_point(Vector3(cos(a) * r, 4.0, sin(a) * r))
		st["safe"] = SAFE_SECONDS
		_apply_dunk(key, by, int(st["lives"]))
		_send("dunk", [key, by, int(st["lives"])])
	else:
		st["alive"] = false
		st["out_time"] = battle_time
		_out_order.append(key)
		c.set_respawn_point(Vector3(0.0, -60.0, 0.0))
		_apply_out.call_deferred(key, by)
		_send("out", [key, by])
		if alive_count() <= 1 and not _ending:
			_ending = true
			get_tree().create_timer(2.0, false).timeout.connect(_finish)


func _rink_schedule() -> void:
	if _collapsed >= COLLAPSE_TIMES.size():
		return
	var ring := arena.intact_rings() - 1
	var at := COLLAPSE_TIMES[_collapsed]
	if _warned <= _collapsed and battle_time >= at - 3.0:
		_warned = _collapsed + 1
		_apply_warn(ring)
		_send("warn", [ring])
		_announce("THE OUTER RING IS SINKING!" if ring > 1 else "LAST RING GOING! HOLD ON!")
	if battle_time >= at:
		_collapsed += 1
		_apply_collapse(ring)
		_send("collapse", [ring])


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
			"falls": MAX_LIVES - int(st["lives"]),
			"finished": true,
			"hits": int(st["dunks"]),
			"stat": "knock-offs",
		})
	battle_over.emit(results)


# --- Shown on every screen ------------------------------------------------------

func apply_remote_event(event: String, args: Array) -> void:
	match event:
		"bump":
			_bump_fx(str(args[0]), str(args[1]), args[2], float(args[3]))
		"boost":
			_boost_fx(str(args[0]))
		"dunk":
			var key := str(args[0])
			if _state.has(key):
				_state[key]["lives"] = int(args[2])
			_apply_dunk(key, str(args[1]), int(args[2]))
		"out":
			var key := str(args[0])
			if _state.has(key):
				_state[key]["alive"] = false
				_state[key]["lives"] = 0
			_apply_out(key, str(args[1]))
		"warn":
			_apply_warn(int(args[0]))
		"collapse":
			_apply_collapse(int(args[0]))
		"status":
			var names: Array = args[0]
			var lives: Array = args[1]
			var boosts: Array = args[2]
			var dunks: Array = args[3]
			for i in range(names.size()):
				var key := str(names[i])
				if _state.has(key):
					_state[key]["lives"] = int(lives[i])
					_state[key]["boost"] = float(boosts[i])
					_state[key]["dunks"] = int(dunks[i])
		"announce":
			announcement.emit(str(args[0]))


func _bump_fx(rammer_name: String, victim_name: String, pos: Vector3, strength: float) -> void:
	var size := clampf(strength / 8.0, 0.6, 1.8)
	FX.burst(self, "impact", pos, Color.WHITE, size)
	FX.burst(self, "sparks", pos, Color(1.6, 1.2, 0.5), size)
	if strength > 9.0:
		FX.ring(self, pos - Vector3.UP * 0.4, 2.5, CourseBuilder.accent(0))
	SoundManager.world(self, "punch" if strength > 7.0 else "bounce", pos, randf_range(0.85, 1.15), 3.0 if strength > 7.0 else 0.0)
	bumped.emit(rammer_name, victim_name, strength)


func _boost_fx(contestant_name: String) -> void:
	var c := game.find_contestant(contestant_name)
	if c == null:
		return
	FX.burst(self, "fire", c.global_position - c.get_facing() * 1.1 + Vector3.UP * 0.4, Color.WHITE, 0.8)
	FX.attach_for(c, "flames", 0.5, Vector3(0.0, 0.4, 1.0))
	SoundManager.world(self, "rocket", c.global_position, 1.3, -2.0)


func _apply_dunk(victim_name: String, by_name: String, lives: int) -> void:
	dunked.emit(victim_name, by_name, lives)


func _apply_out(victim_name: String, by_name: String) -> void:
	var victim := game.find_contestant(victim_name)
	if victim != null:
		_set_out(victim, true)
	eliminated.emit(victim_name, by_name, alive_count())


func _apply_warn(ring: int) -> void:
	arena.warn_ring(ring)
	SoundManager.world(self, "trap", Vector3.ZERO, 0.6, 6.0)


func _apply_collapse(ring: int) -> void:
	arena.collapse_ring(ring)
	SoundManager.world(self, "boom", Vector3.ZERO, 0.6, 8.0)


func _set_out(c: Contestant, out: bool) -> void:
	c.visible = not out
	c.controls_enabled = not out
	if multiplayer.is_server():
		c.set_physics_process(not out)
		c.collision_layer = 0 if out else Contestant.CONTESTANT_LAYER
		c.collision_mask = 0 if out else (Contestant.COURSE_LAYER | Contestant.CONTESTANT_LAYER)


func _send_status() -> void:
	var names: Array = []
	var lives: Array = []
	var boosts: Array = []
	var dunks: Array = []
	for key in _state.keys():
		names.append(key)
		lives.append(int(_state[key]["lives"]))
		boosts.append(float(_state[key]["boost"]))
		dunks.append(int(_state[key]["dunks"]))
	_send("status", [names, lives, boosts, dunks])


func _announce(text: String) -> void:
	announcement.emit(text)
	_send("announce", [text])


func _send(event: String, args: Array) -> void:
	if multiplayer.is_server():
		net_event.emit(event, args)
