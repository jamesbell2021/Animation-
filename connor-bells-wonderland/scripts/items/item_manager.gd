class_name ItemManager
extends Node3D
## Fairground Mayhem: gift boxes along the course and what every item does.
## The host decides everything. Each decision also goes out as an item event
## (a name plus an args array) that RaceSync relays, so clients show the same
## traps, effects, held items, launches and explosions. Child "ItemManager" of
## the GameManager.

## Host only: an event for RaceSync to relay to clients.
signal net_event(event: String, args: Array)
## All peers: [param victim_name] was hit by [param attacker_name]'s item.
signal hit(victim_name: String, attacker_name: String, kind: int)
## All peers: someone used an item at [param origin] (for camera shake etc.).
signal item_fx(user_name: String, kind: int, origin: Vector3)
## All peers: someone took an item from a gift box.
signal picked_up(contestant_name: String, kind: int)
## All peers: gold moved from one contestant to another (hits, Giant Magnet).
signal gold_stolen(from_name: String, to_name: String, amount: int)

## How far behind its owner a trap is dropped.
@export var trap_drop_distance: float = 1.8
## Seconds before the same pair can bump each other again (barge, shield, ram).
@export var bump_cooldown: float = 0.7

var game: GameManager
var enabled: bool = true

var _boxes: Array[ItemBox] = []
var _traps: Dictionary = {}
var _traps_root: Node3D
var _fx_root: Node3D
var _next_trap_id: int = 1
var _bumps: Dictionary = {}
var _steal_timers: Dictionary = {}
var _charge_fx: Dictionary = {}


## Launch velocity for a catapult pull-back of [param charge] (0..1).
static func launch_velocity(facing: Vector3, charge: float, def: Dictionary) -> Vector3:
	var speed := lerpf(float(def.get("min_speed", 8.0)), float(def.get("max_speed", 18.0)), charge)
	var up := lerpf(float(def.get("min_up", 7.0)), float(def.get("max_up", 11.0)), charge)
	return facing * speed + Vector3.UP * up


func setup(p_game: GameManager, course: FairgroundCourse, p_enabled: bool) -> void:
	game = p_game
	enabled = p_enabled
	_traps_root = Node3D.new()
	_traps_root.name = "Traps"
	add_child(_traps_root)
	_fx_root = Node3D.new()
	_fx_root.name = "Effects"
	add_child(_fx_root)
	if enabled and course != null:
		_build_boxes(course)


## Hooks up a contestant's ItemHolder and StatusEffects. Call after it is in the tree.
func register_contestant(c: Contestant) -> void:
	var holder := c.get_node_or_null("ItemHolder") as ItemHolder
	if holder != null:
		holder.manager = self
		holder.item_changed.connect(_on_holder_changed.bind(c))
	var status := c.get_node_or_null("StatusEffects") as StatusEffects
	if status != null:
		status.effect_started.connect(_on_effect_started.bind(c))
		status.effect_ended.connect(_on_effect_ended.bind(c))
	if multiplayer.is_server():
		c.launch_landed.connect(_on_launch_landed.bind(c))


func get_box_count() -> int:
	return _boxes.size()


## Clears traps, effects and held items and brings every box back (race restart).
func reset() -> void:
	for child in _traps_root.get_children():
		child.queue_free()
	for child in _fx_root.get_children():
		child.queue_free()
	_traps.clear()
	_bumps.clear()
	for box in _boxes:
		box.reset()
	for node in get_tree().get_nodes_in_group("contestants"):
		var holder := (node as Node).get_node_or_null("ItemHolder") as ItemHolder
		if holder != null:
			holder.clear()


## Host: carries out [param kind] for [param user]. Returns false if it could
## not be used right now (the item is then kept).
func use_item(user: Contestant, kind: int) -> bool:
	if user == null or kind == ItemKinds.Kind.NONE:
		return false
	var def := ItemKinds.get_def(kind)
	var facing := user.get_facing()
	match ItemKinds.mode_of(kind):
		"trap":
			return _place_trap(user, kind)
		"melee":
			_melee(user, kind, def, facing)
		"burst":
			_burst(user, kind, def)
		"throw":
			_throw(user, kind, def, facing)
		"self":
			_self_buff(user, kind, def)
		_:
			return false
	return true


## Host: fling [param user] with a catapult pull-back of [param charge].
func launch(user: Contestant, charge: float) -> bool:
	if user == null:
		return false
	var def := ItemKinds.get_def(ItemKinds.Kind.CATAPULT)
	var velocity := launch_velocity(user.get_facing(), charge, def)
	user.launch(velocity)
	_fx(user, ItemKinds.Kind.CATAPULT, user.global_position, velocity)
	return true


## Host: start/stop the catapult pull-back effect on [param c].
func set_charging(c: Contestant, on: bool) -> void:
	_apply_charge(str(c.name), on)
	_send("charge", [str(c.name), on])


## Client: apply an event the host sent.
func apply_remote_event(event: String, args: Array) -> void:
	match event:
		"item":
			var c := _find(args[0])
			if c != null:
				var holder := c.get_node_or_null("ItemHolder") as ItemHolder
				if holder != null:
					holder.set_item(int(args[1]), int(args[2]))
		"box":
			var index := int(args[0])
			if index >= 0 and index < _boxes.size():
				_box_taken_fx(_boxes[index])
				_boxes[index].take()
			picked_up.emit(str(args[1]), int(args[2]))
		"trap":
			_spawn_trap(int(args[0]), int(args[1]), args[2], str(args[3]))
			_trap_placed_fx(int(args[1]), args[2])
			item_fx.emit(str(args[3]), int(args[1]), args[2])
		"trap_fire":
			var trap := _traps.get(int(args[0])) as TrapDevice
			if trap != null and is_instance_valid(trap):
				trap.trigger_remote(args[1])
		"fx":
			_play_fx(str(args[0]), int(args[1]), args[2], args[3])
		"charge":
			_apply_charge(str(args[0]), bool(args[1]))
		"effect":
			var status := _status_of(_find(args[0]))
			if status != null:
				status.apply(int(args[1]), float(args[2]))
		"effect_end":
			var status := _status_of(_find(args[0]))
			if status != null:
				status.end_effect(int(args[1]))
		"hit":
			_hit_fx(_find(args[0]), int(args[2]))
			hit.emit(str(args[0]), str(args[1]), int(args[2]))
		"steal":
			_apply_steal(str(args[0]), str(args[1]), int(args[2]))
		"bolt":
			_bolt(args[0], args[1])


# --- Host: continuous effects (barge, shield bump, magnet, catapult ram) ---------

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	var now := Time.get_ticks_msec() / 1000.0
	var everyone := get_tree().get_nodes_in_group("contestants")
	for node in everyone:
		var c := node as Contestant
		if c == null:
			continue
		var status := _status_of(c)
		var rocket := status != null and status.has_effect(StatusEffects.Effect.SPEED)
		var shield := status != null and status.has_effect(StatusEffects.Effect.SHIELD)
		var magnet := status != null and status.has_effect(StatusEffects.Effect.MAGNET)
		if not (rocket or shield or magnet or c.ballistic):
			continue
		for other_node in everyone:
			var other := other_node as Contestant
			if other == null or other == c:
				continue
			var offset := other.global_position - c.global_position
			var dist := offset.length()
			var flat := Vector3(offset.x, 0.0, offset.z)
			var away := flat.normalized() if flat.length() > 0.05 else c.get_facing()
			if dist < 1.5 and (rocket or c.ballistic) and _can_bump(c, other, now):
				var kind := ItemKinds.Kind.ROCKET_BOOTS if rocket else ItemKinds.Kind.CATAPULT
				var force := float(ItemKinds.get_def(ItemKinds.Kind.ROCKET_BOOTS).get("barge", 12.0)) if rocket else 13.0
				if _attack(other, c, away * force + Vector3.UP * 6.0, 1.2, kind):
					_report_hit(other, c, kind)
			elif dist < 1.4 and shield and _can_bump(c, other, now):
				other.knock(away * 8.0 + Vector3.UP * 4.0, 0.5)
				_report_hit(other, c, ItemKinds.Kind.SHIELD)
			if magnet and absf(offset.y) < 3.0:
				var def := ItemKinds.get_def(ItemKinds.Kind.MAGNET)
				var radius := float(def.get("radius", 9.0))
				if flat.length() < radius and flat.length() > 1.2:
					var pull := float(def.get("pull", 16.0)) * (1.0 - flat.length() / radius * 0.5)
					other.velocity -= away * pull * delta
					var key := "%s>%s" % [c.name, other.name]
					var next_steal := float(_steal_timers.get(key, 0.0))
					if now >= next_steal:
						_steal_timers[key] = now + float(def.get("steal_every", 0.6))
						_steal_gold(other, c, 1)


func _can_bump(a: Contestant, b: Contestant, now: float) -> bool:
	var key := "%s|%s" % [a.name, b.name]
	if now < float(_bumps.get(key, 0.0)):
		return false
	_bumps[key] = now + bump_cooldown
	return true


func _on_launch_landed(c: Contestant) -> void:
	var def := ItemKinds.get_def(ItemKinds.Kind.CATAPULT)
	var radius := float(def.get("impact_radius", 3.2))
	for node in get_tree().get_nodes_in_group("contestants"):
		var other := node as Contestant
		if other == null or other == c:
			continue
		var offset := other.global_position - c.global_position
		if absf(offset.y) > 2.0:
			continue
		offset.y = 0.0
		if offset.length() > radius:
			continue
		var away := offset.normalized() if offset.length() > 0.05 else c.get_facing()
		if _attack(other, c, away * float(def.get("knock", 13.0)) + Vector3.UP * float(def.get("launch_up", 7.0)), float(def.get("stumble", 1.5)), ItemKinds.Kind.CATAPULT):
			_report_hit(other, c, ItemKinds.Kind.CATAPULT)
	_play_fx(str(c.name), -1, c.global_position, Vector3.ZERO)
	_send("fx", [str(c.name), -1, c.global_position, Vector3.ZERO])


# --- Host decisions -----------------------------------------------------------

func _on_box_picked(box: ItemBox, c: Contestant) -> void:
	var holder := c.get_node_or_null("ItemHolder") as ItemHolder
	if holder == null:
		return
	var kind := _roll_item(c)
	holder.give(kind)
	_box_taken_fx(box)
	picked_up.emit(str(c.name), kind)
	_send("box", [box.index, str(c.name), kind])


func _roll_item(c: Contestant) -> int:
	var fraction := 0.5
	if game != null and game.race_manager != null and game._contestants.size() > 1:
		var ranking := RaceRanking.compute(game._contestants, game.race_manager, game.course.checkpoint_manager)
		var place := RaceRanking.position_of(c, ranking)
		if place > 0:
			fraction = float(place - 1) / float(ranking.size() - 1)
	var kind := ItemKinds.roll_for_position(fraction)
	if kind == ItemKinds.Kind.MAGNET and get_tree().get_nodes_in_group("coins").is_empty() and game != null and game._contestants.size() < 2:
		kind = ItemKinds.Kind.ROCKET_BOOTS
	return kind


func _place_trap(user: Contestant, kind: int) -> bool:
	var facing := user.get_facing()
	var spot := _ground_below(user.global_position - facing * trap_drop_distance)
	if spot == Vector3.INF:
		spot = _ground_below(user.global_position)
	if spot == Vector3.INF:
		return false
	var id := _next_trap_id
	_next_trap_id += 1
	_spawn_trap(id, kind, spot, str(user.name))
	_trap_placed_fx(kind, spot)
	item_fx.emit(str(user.name), kind, spot)
	_send("trap", [id, kind, spot, str(user.name)])
	return true


## Solid, non-moving ground under [param point], or Vector3.INF.
func _ground_below(point: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 1.5, point + Vector3.DOWN * 4.0, Contestant.COURSE_LAYER)
	var hit_info := space.intersect_ray(query)
	if hit_info.is_empty():
		return Vector3.INF
	var collider: Object = hit_info.get("collider")
	if not (collider is StaticBody3D) or collider is AnimatableBody3D or collider is BouncerObstacle:
		return Vector3.INF
	var normal: Vector3 = hit_info.get("normal", Vector3.UP)
	if normal.y < 0.8:
		return Vector3.INF
	return hit_info["position"]


func _melee(user: Contestant, kind: int, def: Dictionary, facing: Vector3) -> void:
	var targets := _contestants_in_cone(user, facing, float(def.get("range", 2.5)), float(def.get("cone", 0.3)))
	var zapped: Array[Contestant] = []
	for t in targets:
		var landed := false
		match kind:
			ItemKinds.Kind.SWORD:
				landed = _attack(t, user, facing * float(def.get("knock", 15.0)) + Vector3.UP * float(def.get("launch_up", 6.0)), float(def.get("stumble", 1.6)), kind)
			ItemKinds.Kind.ZAPPER:
				landed = _attack(t, user, facing * 1.5 + Vector3.UP * 3.5, float(def.get("stumble", 1.6)), kind)
				zapped.append(t)
			ItemKinds.Kind.BALLOON:
				landed = _status_hit(t, user, StatusEffects.Effect.FLOAT, float(def.get("effect_seconds", 2.5)), kind)
		if landed:
			_report_hit(t, user, kind)
	# The zap jumps on to one more rival standing near each victim.
	for victim in zapped:
		for node in get_tree().get_nodes_in_group("contestants"):
			var other := node as Contestant
			if other == null or other == user or targets.has(other):
				continue
			if other.global_position.distance_to(victim.global_position) < 3.5:
				_bolt(victim.global_position, other.global_position)
				_send("bolt", [victim.global_position, other.global_position])
				if _attack(other, user, Vector3.UP * 3.5, 1.2, kind):
					_report_hit(other, user, kind)
				break
	_fx(user, kind, user.global_position, facing)


func _burst(user: Contestant, kind: int, def: Dictionary) -> void:
	var radius := float(def.get("radius", 5.5))
	for node in get_tree().get_nodes_in_group("contestants"):
		var t := node as Contestant
		if t == null or t == user:
			continue
		var offset := t.global_position - user.global_position
		if absf(offset.y) > 2.5:
			continue
		offset.y = 0.0
		if offset.length() > radius:
			continue
		var dir := offset.normalized() if offset.length() > 0.05 else user.get_facing()
		var falloff := 1.0 - offset.length() / radius * 0.4
		if _attack(t, user, dir * float(def.get("knock", 13.0)) * falloff + Vector3.UP * float(def.get("launch_up", 8.0)), float(def.get("stumble", 1.4)), kind):
			_report_hit(t, user, kind)
	_fx(user, kind, user.global_position, Vector3.UP * radius)


func _throw(user: Contestant, kind: int, def: Dictionary, facing: Vector3) -> void:
	var origin := user.global_position + Vector3.UP * 1.6 + facing * 0.6
	var velocity := facing * float(def.get("speed", 11.0)) + Vector3.UP * float(def.get("arc", 6.0)) + Vector3(user.velocity.x, 0.0, user.velocity.z) * 0.5
	var pie := PieProjectile.create(_fx_root, origin, velocity, str(user.name), true)
	if pie != null:
		pie.splatted.connect(_on_pie_splatted.bind(str(user.name)))
	SoundManager.world(self, "swish", origin)
	item_fx.emit(str(user.name), kind, origin)
	_send("fx", [str(user.name), kind, origin, velocity])


func _self_buff(user: Contestant, kind: int, def: Dictionary) -> void:
	var status := _status_of(user)
	if status != null:
		var seconds := float(def.get("effect_seconds", 3.0))
		match kind:
			ItemKinds.Kind.ROCKET_BOOTS:
				status.apply(StatusEffects.Effect.SPEED, seconds)
			ItemKinds.Kind.MAGNET:
				status.apply(StatusEffects.Effect.MAGNET, seconds)
			ItemKinds.Kind.SHIELD:
				status.apply(StatusEffects.Effect.SHIELD, seconds)
	_fx(user, kind, user.global_position, Vector3.UP)


## Knock [param victim] unless a shield blocks it; a blocked hit bounces back at
## the attacker if they are close. True if the hit landed.
func _attack(victim: Contestant, attacker: Contestant, impulse: Vector3, stumble: float, _kind: int) -> bool:
	var status := _status_of(victim)
	if status != null and status.consume_shield():
		_reflect(victim, attacker, impulse)
		return false
	victim.knock(impulse, stumble)
	return true


## Applies a status effect unless a shield blocks it. True if it landed.
func _status_hit(victim: Contestant, attacker: Contestant, effect: int, seconds: float, _kind: int) -> bool:
	var status := _status_of(victim)
	if status == null:
		return false
	if status.consume_shield():
		_reflect(victim, attacker, Vector3.UP * 4.0)
		return false
	status.apply(effect, seconds)
	return true


func _reflect(victim: Contestant, attacker: Contestant, impulse: Vector3) -> void:
	if attacker == null or attacker == victim:
		return
	if attacker.global_position.distance_to(victim.global_position) > 6.0:
		return
	var back := attacker.global_position - victim.global_position
	back.y = 0.0
	back = back.normalized() if back.length() > 0.05 else -attacker.get_facing()
	var strength := clampf(Vector2(impulse.x, impulse.z).length(), 6.0, 14.0)
	attacker.knock(back * strength + Vector3.UP * 5.0, 1.0)
	_report_hit(attacker, victim, ItemKinds.Kind.SHIELD)


func _contestants_in_cone(user: Contestant, facing: Vector3, reach: float, min_dot: float) -> Array[Contestant]:
	var result: Array[Contestant] = []
	for node in get_tree().get_nodes_in_group("contestants"):
		var t := node as Contestant
		if t == null or t == user:
			continue
		var offset := t.global_position - user.global_position
		if absf(offset.y) > 2.0:
			continue
		offset.y = 0.0
		var dist := offset.length()
		if dist > reach:
			continue
		if dist > 0.6 and offset.normalized().dot(facing) < min_dot:
			continue
		result.append(t)
	return result


func _on_trap_triggered(trap: TrapDevice, victim: Contestant) -> void:
	if trap.is_one_shot():
		_send("trap_fire", [trap.trap_id, trap.get_punch_direction()])
	_report_hit(victim, _find(trap.owner_name), trap.kind, trap.owner_name)


func _on_pie_splatted(_pie: PieProjectile, _pos: Vector3, victims: Array, owner_name: String) -> void:
	for v in victims:
		_report_hit(_find(str(v)), _find(owner_name), ItemKinds.Kind.PIE, owner_name)


func _report_hit(victim: Contestant, attacker: Contestant, kind: int, attacker_name: String = "") -> void:
	if victim == null:
		return
	var a_name := str(attacker.name) if attacker != null else attacker_name
	_hit_fx(victim, kind)
	hit.emit(str(victim.name), a_name, kind)
	_send("hit", [str(victim.name), a_name, kind])
	if attacker != null and attacker != victim:
		_steal_gold(victim, attacker, 1)


## Host: move up to [param amount] gold from [param from_c] to [param to_c].
func _steal_gold(from_c: Contestant, to_c: Contestant, amount: int) -> void:
	if game == null or from_c == null or to_c == null:
		return
	var have := int(game._coins.get(str(from_c.name), 0))
	var taken := mini(have, amount)
	if taken <= 0:
		return
	_apply_steal(str(from_c.name), str(to_c.name), taken)
	_send("steal", [str(from_c.name), str(to_c.name), taken])


func _apply_steal(from_name: String, to_name: String, amount: int) -> void:
	var from_c := _find(from_name)
	if from_c != null:
		FX.burst(self, "coins", from_c.global_position + Vector3.UP * 1.0, Color.WHITE, 1.2)
		SoundManager.world(self, "steal", from_c.global_position, 1.0, -2.0)
	gold_stolen.emit(from_name, to_name, amount)


func _on_holder_changed(kind: int, uses: int, c: Contestant) -> void:
	_send("item", [str(c.name), kind, uses])


func _on_effect_started(effect: int, duration: float, c: Contestant) -> void:
	_send("effect", [str(c.name), effect, duration])


func _on_effect_ended(effect: int, c: Contestant) -> void:
	_send("effect_end", [str(c.name), effect])


func _send(event: String, args: Array) -> void:
	if multiplayer.is_server():
		net_event.emit(event, args)


# --- Shared visuals and sounds ----------------------------------------------------

func _fx(user: Contestant, kind: int, origin: Vector3, dir: Vector3) -> void:
	_play_fx(str(user.name), kind, origin, dir)
	_send("fx", [str(user.name), kind, origin, dir])


## Kind -1 is the catapult landing slam.
func _play_fx(user_name: String, kind: int, origin: Vector3, dir: Vector3) -> void:
	item_fx.emit(user_name, kind, origin)
	match kind:
		-1:
			var radius := float(ItemKinds.get_def(ItemKinds.Kind.CATAPULT).get("impact_radius", 3.2))
			FX.ring(self, origin, radius, CourseBuilder.accent(0))
			FX.burst(self, "dust", origin, Color.WHITE, 2.0)
			FX.burst(self, "impact", origin + Vector3.UP * 0.4, Color.WHITE, 1.3)
			SoundManager.world(self, "slam", origin, 1.0, 2.0)
		ItemKinds.Kind.CATAPULT:
			FX.burst(self, "dust", origin, Color.WHITE, 1.4)
			FX.burst(self, "sparks", origin + Vector3.UP * 0.5, Color(1.4, 0.8, 0.3))
			FX.ring(self, origin, 2.0, CourseBuilder.accent(0))
			SoundManager.world(self, "twang", origin, 1.0, 2.0)
		ItemKinds.Kind.SWORD:
			var user := _find(user_name)
			if user != null:
				SwordSwipe.spawn(user, dir, ItemKinds.colour_for(kind))
				var visuals := user.get_visuals()
				if visuals != null:
					visuals.swing_arm()
			else:
				_swoosh(origin, dir, ItemKinds.colour_for(kind), 2.2)
			SoundManager.world(self, "slash", origin, randf_range(0.9, 1.1), 2.0)
		ItemKinds.Kind.ZAPPER:
			_zap(origin, dir, float(ItemKinds.get_def(kind).get("range", 3.5)))
			SoundManager.world(self, "zap", origin)
		ItemKinds.Kind.BALLOON:
			_swoosh(origin, dir, ItemKinds.colour_for(kind), 2.8)
			SoundManager.world(self, "whoosh", origin)
		ItemKinds.Kind.CONFETTI:
			var radius := float(ItemKinds.get_def(kind).get("radius", 5.5))
			FX.burst(self, "fire", origin + Vector3.UP * 0.8, Color.WHITE, 1.8)
			FX.burst(self, "sparks", origin + Vector3.UP * 0.8, Color(1.5, 0.9, 0.4), 1.6)
			FX.burst(self, "smoke", origin + Vector3.UP * 0.5, Color.WHITE, 1.6)
			FX.ring(self, origin, radius, CourseBuilder.accent(2))
			SoundManager.world(self, "boom", origin, 1.0, 4.0)
		ItemKinds.Kind.PIE:
			if not multiplayer.is_server():
				PieProjectile.create(_fx_root, origin, dir, user_name, false)
				SoundManager.world(self, "swish", origin)
		_:
			pass


## Effects on a contestant who just got hit, per item.
func _hit_fx(victim: Contestant, kind: int) -> void:
	if victim == null or not victim.is_inside_tree():
		return
	var pos := victim.global_position + Vector3.UP * 0.9
	match kind:
		ItemKinds.Kind.SWORD, ItemKinds.Kind.BOXING_GLOVE, ItemKinds.Kind.ROCKET_BOOTS, ItemKinds.Kind.CATAPULT:
			FX.burst(self, "impact", pos, Color.WHITE, 1.3)
			SoundManager.world(self, "punch", pos, randf_range(0.9, 1.1), 2.0)
		ItemKinds.Kind.ZAPPER:
			FX.burst(self, "electric", pos, Color.WHITE, 1.4)
			FX.attach_for(victim, "electric", 1.5, Vector3(0.0, 0.9, 0.0))
			SoundManager.world(self, "zap", pos)
		ItemKinds.Kind.PIE:
			FX.burst(self, "custard", pos + Vector3.UP * 0.4, Color.WHITE, 1.2)
			SoundManager.world(self, "splat", pos, 1.0, 2.0)
		ItemKinds.Kind.CONFETTI:
			FX.burst(self, "sparks", pos, Color(1.5, 0.8, 0.3))
		ItemKinds.Kind.SPRINGER:
			FX.burst(self, "dust", victim.global_position, Color.WHITE, 1.5)
			SoundManager.world(self, "boing", pos)
		ItemKinds.Kind.SHIELD:
			FX.burst(self, "sparkle", pos, Color(0.6, 1.4, 2.0))
			SoundManager.world(self, "shield", pos)
		_:
			pass


func _trap_placed_fx(kind: int, pos: Vector3) -> void:
	FX.burst(self, "poof", pos + Vector3.UP * 0.4, ItemKinds.colour_for(kind).lightened(0.4), 0.8)
	SoundManager.world(self, "trap", pos)


func _box_taken_fx(box: ItemBox) -> void:
	FX.burst(self, "sparkle", box.global_position, CourseBuilder.accent(box.index) * 1.5, 1.4)
	FX.burst(self, "poof", box.global_position, Color.WHITE, 0.7)
	SoundManager.world(self, "pickup", box.global_position)


func _apply_charge(contestant_name: String, on: bool) -> void:
	var c := _find(contestant_name)
	if _charge_fx.has(contestant_name):
		var old: Node = _charge_fx[contestant_name]
		if is_instance_valid(old):
			old.queue_free()
		_charge_fx.erase(contestant_name)
	if c == null:
		return
	if on:
		_charge_fx[contestant_name] = FX.attach(c, "charge", Vector3(0.0, 0.8, 0.0))
		SoundManager.world(self, "charge", c.global_position)


func _spawn_trap(id: int, kind: int, pos: Vector3, owner_name: String) -> void:
	var trap := TrapDevice.create(_traps_root, pos, kind as ItemKinds.Kind, owner_name, id)
	if trap == null:
		return
	_traps[id] = trap
	trap.tree_exited.connect(_forget_trap.bind(id))
	if multiplayer.is_server():
		trap.triggered.connect(_on_trap_triggered)


func _forget_trap(id: int) -> void:
	_traps.erase(id)


func _swoosh(origin: Vector3, dir: Vector3, colour: Color, reach: float) -> void:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() < 0.01:
		flat = Vector3.FORWARD
	flat = flat.normalized()
	var arc := CourseBuilder.make_box_mesh(Vector3(reach * 1.4, 0.1, 0.3), colour)
	arc.mesh.material = CourseBuilder.make_neon_material(colour, 3.0)
	arc.position = origin + Vector3.UP * 1.0 + flat * reach * 0.6
	arc.rotation.y = atan2(-flat.x, -flat.z)
	_fx_root.add_child(arc)
	FX.burst(self, "sparks", origin + Vector3.UP * 1.0 + flat * reach * 0.8, colour * 1.5, 0.7)
	_expire(arc, 0.15)


func _zap(origin: Vector3, dir: Vector3, reach: float) -> void:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() < 0.01:
		flat = Vector3.FORWARD
	flat = flat.normalized()
	_bolt(origin + Vector3.UP * 1.0, origin + Vector3.UP * 1.0 + flat * reach)


## A jagged electric bolt between two points.
func _bolt(from: Vector3, to: Vector3) -> void:
	var bolt := Node3D.new()
	bolt.name = "Zap"
	_fx_root.add_child(bolt)
	var mat := CourseBuilder.make_neon_material(Color(0.5, 0.9, 1.0), 4.0)
	var steps := 8
	var prev := from
	for i in range(1, steps + 1):
		var t := float(i) / float(steps)
		var p := from.lerp(to, t)
		if i < steps:
			p += Vector3(randf_range(-0.35, 0.35), randf_range(-0.35, 0.35), randf_range(-0.35, 0.35))
		var seg := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.07, 0.07, prev.distance_to(p))
		box.material = mat
		seg.mesh = box
		bolt.add_child(seg)
		seg.global_position = (prev + p) * 0.5
		if prev.distance_to(p) > 0.01:
			seg.look_at_from_position(seg.global_position, p, Vector3.UP if absf((p - prev).normalized().y) < 0.95 else Vector3.RIGHT)
		prev = p
	FX.burst(self, "electric", to, Color.WHITE, 0.8)
	_expire(bolt, 0.22)


func _expire(node: Node, seconds: float) -> void:
	get_tree().create_timer(seconds, false).timeout.connect(node.queue_free)


# --- Gift boxes -----------------------------------------------------------------

func _build_boxes(course: FairgroundCourse) -> void:
	var root := Node3D.new()
	root.name = "ItemBoxes"
	add_child(root)
	for section in course.sections:
		for local in _box_spots(section):
			var box := ItemBox.create(root, section.to_global(local), _boxes.size())
			if box != null:
				_boxes.append(box)
				if multiplayer.is_server():
					box.picked.connect(_on_box_picked)


## Local positions of gift boxes for each section (two rows across the track).
func _box_spots(section: CourseSection) -> Array[Vector3]:
	var rows: Array = []
	var y := 1.2
	if section is SectionBigTop:
		rows = [[-9.5, [-4.5, -1.5, 1.5, 4.5]], [-24.0, [-3.0, 0.0, 3.0]]]
	elif section is SectionDodgems:
		rows = [[-14.0, [-5.0, 0.0, 5.0]], [-36.0, [-5.0, -1.7, 1.7, 5.0]]]
	elif section is SectionDizzyRides:
		rows = [[-4.0, [-4.0, 0.0, 4.0]], [-34.5, [-3.5, 0.0, 3.5]]]
	elif section is SectionBouncyYard:
		rows = [[-3.0, [-4.0, 0.0, 4.0]], [-33.0, [-4.0, 0.0, 4.0]]]
	elif section is SectionHighRides:
		rows = [[-3.0, [-4.0, 0.0, 4.0]], [-44.0, [-4.0, 0.0, 4.0]]]
		y += 0.0
	elif section is SectionFinaleTower:
		rows = [[-5.5, [-4.0, 0.0, 4.0]], [-10.5, [-4.0, 0.0, 4.0]]]
	var spots: Array[Vector3] = []
	for row: Array in rows:
		var z: float = row[0]
		var height := y
		if section is SectionHighRides and z < -40.0:
			height += (section as SectionHighRides).top_height
		for x: float in row[1]:
			spots.append(Vector3(x, height, z))
	return spots


# --- Helpers ----------------------------------------------------------------------

func _find(contestant_name: Variant) -> Contestant:
	if game == null:
		return null
	return game.find_contestant(str(contestant_name))


func _status_of(c: Contestant) -> StatusEffects:
	return c.get_node_or_null("StatusEffects") as StatusEffects if c != null else null
