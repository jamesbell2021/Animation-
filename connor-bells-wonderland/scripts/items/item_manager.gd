class_name ItemManager
extends Node3D
## Fairground Mayhem: gift boxes along the course and what every item does.
## The host decides everything. Each decision also goes out as an item event
## (a name plus an args array) that RaceSync relays, so clients show the same
## traps, effects, held items and explosions. Child "ItemManager" of the GameManager.

## Host only: an event for RaceSync to relay to clients.
signal net_event(event: String, args: Array)
## All peers: [param victim_name] was hit by [param attacker_name]'s item.
signal hit(victim_name: String, attacker_name: String, kind: int)
## All peers: someone used an item at [param origin] (for sounds).
signal item_fx(user_name: String, kind: int, origin: Vector3)
## All peers: someone took an item from a gift box.
signal picked_up(contestant_name: String, kind: int)

## How far behind its owner a trap is dropped.
@export var trap_drop_distance: float = 1.8

var game: GameManager
var enabled: bool = true

var _boxes: Array[ItemBox] = []
var _traps: Dictionary = {}
var _traps_root: Node3D
var _fx_root: Node3D
var _next_trap_id: int = 1


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


func get_box_count() -> int:
	return _boxes.size()


## Clears traps, effects and held items and brings every box back (race restart).
func reset() -> void:
	for child in _traps_root.get_children():
		child.queue_free()
	for child in _fx_root.get_children():
		child.queue_free()
	_traps.clear()
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
				_boxes[index].take()
			picked_up.emit(str(args[1]), int(args[2]))
		"trap":
			_spawn_trap(int(args[0]), int(args[1]), args[2], str(args[3]))
			item_fx.emit(str(args[3]), int(args[1]), args[2])
		"trap_fire":
			var trap := _traps.get(int(args[0])) as TrapDevice
			if trap != null and is_instance_valid(trap):
				trap.trigger_remote(args[1])
		"fx":
			_play_fx(str(args[0]), int(args[1]), args[2], args[3])
		"effect":
			var status := _status_of(_find(args[0]))
			if status != null:
				status.apply(int(args[1]), float(args[2]))
		"effect_end":
			var status := _status_of(_find(args[0]))
			if status != null:
				status.end_effect(int(args[1]))
		"hit":
			hit.emit(str(args[0]), str(args[1]), int(args[2]))


# --- Host decisions -----------------------------------------------------------

func _on_box_picked(box: ItemBox, c: Contestant) -> void:
	var holder := c.get_node_or_null("ItemHolder") as ItemHolder
	if holder == null:
		return
	var kind := _roll_item()
	holder.give(kind)
	picked_up.emit(str(c.name), kind)
	_send("box", [box.index, str(c.name), kind])


func _roll_item() -> int:
	var kind := ItemKinds.random_kind()
	if kind == ItemKinds.Kind.MAGNET and get_tree().get_nodes_in_group("coins").is_empty():
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
	for t in targets:
		var landed := false
		match kind:
			ItemKinds.Kind.SWORD:
				landed = StatusEffects.try_knock(t, facing * float(def.get("knock", 12.0)) + Vector3.UP * float(def.get("launch_up", 5.0)), float(def.get("stumble", 1.5)))
			ItemKinds.Kind.ZAPPER:
				landed = StatusEffects.try_knock(t, facing * 1.5 + Vector3.UP * 3.5, float(def.get("stumble", 1.6)))
			ItemKinds.Kind.BALLOON:
				landed = _status_hit(t, StatusEffects.Effect.FLOAT, float(def.get("effect_seconds", 2.5)))
		if landed:
			_report_hit(t, user, kind)
	_fx(user, kind, user.global_position, facing)


func _burst(user: Contestant, kind: int, def: Dictionary) -> void:
	var radius := float(def.get("radius", 4.5))
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
		if StatusEffects.try_knock(t, dir * float(def.get("knock", 10.0)) + Vector3.UP * float(def.get("launch_up", 6.0)), float(def.get("stumble", 1.2))):
			_report_hit(t, user, kind)
	_fx(user, kind, user.global_position, Vector3.UP * radius)


func _throw(user: Contestant, kind: int, def: Dictionary, facing: Vector3) -> void:
	var origin := user.global_position + Vector3.UP * 1.6 + facing * 0.6
	var velocity := facing * float(def.get("speed", 11.0)) + Vector3.UP * float(def.get("arc", 6.0)) + Vector3(user.velocity.x, 0.0, user.velocity.z) * 0.5
	var pie := PieProjectile.create(_fx_root, origin, velocity, str(user.name), true)
	if pie != null:
		pie.splatted.connect(_on_pie_splatted.bind(str(user.name)))
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


## Applies a status effect unless a shield blocks it. True if it landed.
func _status_hit(victim: Contestant, effect: int, seconds: float) -> bool:
	var status := _status_of(victim)
	if status == null:
		return false
	if status.consume_shield():
		return false
	status.apply(effect, seconds)
	return true


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
	hit.emit(str(victim.name), a_name, kind)
	_send("hit", [str(victim.name), a_name, kind])


func _on_holder_changed(kind: int, uses: int, c: Contestant) -> void:
	_send("item", [str(c.name), kind, uses])


func _on_effect_started(effect: int, duration: float, c: Contestant) -> void:
	_send("effect", [str(c.name), effect, duration])


func _on_effect_ended(effect: int, c: Contestant) -> void:
	_send("effect_end", [str(c.name), effect])


func _send(event: String, args: Array) -> void:
	if multiplayer.is_server():
		net_event.emit(event, args)


# --- Shared visuals -----------------------------------------------------------

func _fx(user: Contestant, kind: int, origin: Vector3, dir: Vector3) -> void:
	_play_fx(str(user.name), kind, origin, dir)
	_send("fx", [str(user.name), kind, origin, dir])


func _play_fx(user_name: String, kind: int, origin: Vector3, dir: Vector3) -> void:
	item_fx.emit(user_name, kind, origin)
	match kind:
		ItemKinds.Kind.SWORD:
			_swoosh(origin, dir, ItemKinds.colour_for(kind), 2.0)
		ItemKinds.Kind.ZAPPER:
			_zap(origin, dir, float(ItemKinds.get_def(kind).get("range", 3.5)))
		ItemKinds.Kind.BALLOON:
			_swoosh(origin, dir, ItemKinds.colour_for(kind), 2.6)
		ItemKinds.Kind.CONFETTI:
			ConfettiBurst.create(_fx_root, origin + Vector3.UP * 0.8, float(ItemKinds.get_def(kind).get("radius", 4.5)))
		ItemKinds.Kind.PIE:
			if not multiplayer.is_server():
				PieProjectile.create(_fx_root, origin, dir, user_name, false)
		ItemKinds.Kind.ROCKET_BOOTS, ItemKinds.Kind.MAGNET, ItemKinds.Kind.SHIELD:
			ConfettiBurst.create(_fx_root, origin + Vector3.UP * 0.8, 1.2, 40)


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
	var arc := CourseBuilder.make_box_mesh(Vector3(reach * 1.4, 0.12, 0.35), colour)
	var mat := arc.mesh.material as StandardMaterial3D
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	arc.position = origin + Vector3.UP * 1.0 + flat * reach * 0.6
	arc.rotation.y = atan2(-flat.x, -flat.z)
	_fx_root.add_child(arc)
	_expire(arc, 0.18)


func _zap(origin: Vector3, dir: Vector3, reach: float) -> void:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() < 0.01:
		flat = Vector3.FORWARD
	flat = flat.normalized()
	var side := Vector3(-flat.z, 0.0, flat.x)
	var bolt := Node3D.new()
	bolt.name = "Zap"
	_fx_root.add_child(bolt)
	var steps := 7
	for i in range(steps):
		var t := float(i) / float(steps - 1)
		var p := origin + Vector3.UP * 1.0 + flat * reach * t + side * (0.3 if i % 2 == 0 else -0.3)
		var spark := CourseBuilder.make_box_mesh(Vector3(0.12, 0.12, 0.6), Color(0.6, 0.95, 1.0))
		(spark.mesh.material as StandardMaterial3D).shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		spark.position = p
		spark.rotation.y = atan2(-flat.x, -flat.z) + (0.6 if i % 2 == 0 else -0.6)
		bolt.add_child(spark)
	_expire(bolt, 0.25)


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


## Local positions of gift boxes for each section (one row across the track).
func _box_spots(section: CourseSection) -> Array[Vector3]:
	var xs: Array[float] = []
	var z := 0.0
	var y := 1.2
	if section is SectionBigTop:
		xs = [-4.5, -1.5, 1.5, 4.5]
		z = -9.5
	elif section is SectionDodgems:
		xs = [-5.0, -1.7, 1.7, 5.0]
		z = -26.0
	elif section is SectionDizzyRides:
		xs = [-3.5, 0.0, 3.5]
		z = -34.5
	elif section is SectionBouncyYard:
		xs = [-4.0, 0.0, 4.0]
		z = -33.0
	elif section is SectionHighRides:
		xs = [-4.0, 0.0, 4.0]
		z = -44.0
		y += (section as SectionHighRides).top_height
	elif section is SectionFinaleTower:
		xs = [-4.0, 0.0, 4.0]
		z = -10.5
	var spots: Array[Vector3] = []
	for x in xs:
		spots.append(Vector3(x, y, z))
	return spots


# --- Helpers ----------------------------------------------------------------------

func _find(contestant_name: Variant) -> Contestant:
	if game == null:
		return null
	return game.find_contestant(str(contestant_name))


func _status_of(c: Contestant) -> StatusEffects:
	return c.get_node_or_null("StatusEffects") as StatusEffects if c != null else null
