class_name StatusEffects
extends Node
## Timed effects on a Contestant. Host changes stats; clients only show visuals.
## OIL: no grip. FAT: big and slow. SMALL: tiny. FLOAT: drifts up on a balloon.
## SPEED: rocket boots. MAGNET: collects nearby coins. SHIELD: blocks one item hit.
## Add as a child named "StatusEffects".

signal effect_started(effect: int, duration: float)
signal effect_ended(effect: int)

enum Effect { OIL, FAT, SMALL, FLOAT, SPEED, MAGNET, SHIELD }

@export var oil_friction: float = 1.5
@export var oil_acceleration: float = 6.0
@export var fat_scale: Vector3 = Vector3(1.6, 1.25, 1.6)
@export var small_scale: Vector3 = Vector3(0.55, 0.55, 0.55)
@export var float_gravity: float = 3.0
@export var float_lift: float = 5.0
@export var speed_multiplier: float = 1.6
@export var magnet_radius: float = 5.0

var contestant: Contestant
var _timers: Dictionary = {}
var _saved: Dictionary = {}
var _attachments: Dictionary = {}
var _visual: Node3D
var _magnet_timer: float = 0.0


## Knock [param victim] unless a shield absorbs it. Returns true if the hit landed.
static func try_knock(victim: Contestant, impulse: Vector3, stumble: float) -> bool:
	if victim == null:
		return false
	var status := victim.get_node_or_null("StatusEffects") as StatusEffects
	if status != null and status.consume_shield():
		return false
	victim.knock(impulse, stumble)
	return true


func _ready() -> void:
	contestant = get_parent() as Contestant
	if contestant == null:
		push_error("StatusEffects must be a child of a Contestant.")
		return
	_visual = contestant.get_node_or_null("Visual")
	contestant.respawned.connect(clear_all)


func _process(delta: float) -> void:
	if _timers.is_empty():
		return
	for effect in _timers.keys():
		_timers[effect] = float(_timers[effect]) - delta
		if float(_timers[effect]) <= 0.0:
			_end(int(effect))
	var t := Time.get_ticks_msec() / 1000.0
	if _visual != null and has_effect(Effect.OIL):
		_visual.rotation.z = sin(t * 14.0) * 0.12
	if _visual != null and has_effect(Effect.FAT):
		var w := 1.0 + sin(t * 6.0) * 0.04
		_visual.scale = Vector3(fat_scale.x * w, fat_scale.y / w, fat_scale.z * w)
	if has_effect(Effect.MAGNET) and multiplayer.is_server():
		_magnet_timer -= delta
		if _magnet_timer <= 0.0:
			_magnet_timer = 0.2
			_pull_coins()


func apply(effect: int, duration: float) -> void:
	if contestant == null or duration <= 0.0:
		return
	if effect == Effect.FAT and has_effect(Effect.SMALL):
		_end(Effect.SMALL)
	if effect == Effect.SMALL and has_effect(Effect.FAT):
		_end(Effect.FAT)
	var already := _timers.has(effect)
	_timers[effect] = maxf(float(_timers.get(effect, 0.0)), duration)
	if not already:
		_start(effect)
	effect_started.emit(effect, duration)


func has_effect(effect: int) -> bool:
	return _timers.has(effect)


func remaining(effect: int) -> float:
	return float(_timers.get(effect, 0.0))


func active_effects() -> Array:
	return _timers.keys()


func consume_shield() -> bool:
	if not has_effect(Effect.SHIELD):
		return false
	_end(Effect.SHIELD)
	return true


func clear_all() -> void:
	for effect in _timers.keys():
		_end(int(effect))


func _start(effect: int) -> void:
	var saved := {}
	match effect:
		Effect.OIL:
			saved = {"friction": contestant.friction, "acceleration": contestant.acceleration}
			contestant.friction = oil_friction
			contestant.acceleration = oil_acceleration
		Effect.FAT:
			saved = {"move_speed": contestant.move_speed, "jump_velocity": contestant.jump_velocity}
			contestant.move_speed *= 0.5
			contestant.jump_velocity *= 0.8
		Effect.SMALL:
			saved = {"move_speed": contestant.move_speed}
			contestant.move_speed *= 0.85
		Effect.FLOAT:
			saved = {"gravity": contestant.gravity}
			contestant.gravity = float_gravity
			if multiplayer.is_server():
				contestant.velocity.y = float_lift
		Effect.SPEED:
			saved = {"move_speed": contestant.move_speed, "acceleration": contestant.acceleration}
			contestant.move_speed *= speed_multiplier
			contestant.acceleration *= 1.5
		Effect.MAGNET:
			_magnet_timer = 0.0
	_saved[effect] = saved
	_attach_visual(effect)
	_update_scale()


func _end(effect: int) -> void:
	if not _timers.has(effect):
		return
	_timers.erase(effect)
	var saved: Dictionary = _saved.get(effect, {})
	for key in saved.keys():
		contestant.set(key, saved[key])
	_saved.erase(effect)
	if effect == Effect.OIL and _visual != null:
		_visual.rotation.z = 0.0
	if _attachments.has(effect):
		var node: Node = _attachments[effect]
		if is_instance_valid(node):
			node.queue_free()
		_attachments.erase(effect)
	_update_scale()
	effect_ended.emit(effect)


func _update_scale() -> void:
	if _visual == null:
		return
	if has_effect(Effect.FAT):
		_visual.scale = fat_scale
	elif has_effect(Effect.SMALL):
		_visual.scale = small_scale
	else:
		_visual.scale = Vector3.ONE


func _pull_coins() -> void:
	for node in get_tree().get_nodes_in_group("coins"):
		var coin := node as CoinPickup
		if coin == null or coin.is_taken():
			continue
		if coin.global_position.distance_to(contestant.global_position) <= magnet_radius:
			coin.take_remote()
			coin.collected.emit(contestant, coin.value)


func _attach_visual(effect: int) -> void:
	if _visual == null:
		return
	var holder := Node3D.new()
	holder.name = "Effect%d" % effect
	_visual.add_child(holder)
	_attachments[effect] = holder
	match effect:
		Effect.FLOAT:
			var balloon := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 0.4
			sphere.height = 0.95
			sphere.material = CourseBuilder.make_material(CourseBuilder.rainbow(randi() % 7))
			balloon.mesh = sphere
			balloon.position = Vector3(0.0, 2.9, 0.0)
			holder.add_child(balloon)
			CourseBuilder.add_decor_box(holder, Vector3(0.02, 0.9, 0.02), Vector3(0.0, 2.0, 0.0), Color.WHITE, "String")
		Effect.SPEED:
			for x: float in [-0.18, 0.18]:
				CourseBuilder.add_decor_box(holder, Vector3(0.22, 0.14, 0.4), Vector3(x, 0.08, 0.0), Color(0.6, 0.6, 0.65), "Boot")
				CourseBuilder.add_decor_box(holder, Vector3(0.14, 0.14, 0.5), Vector3(x, 0.08, 0.45), Color(1.0, 0.5, 0.1), "Flame")
		Effect.MAGNET:
			CourseBuilder.add_decor_box(holder, Vector3(0.6, 0.18, 0.18), Vector3(0.0, 2.1, 0.0), Color(0.85, 0.1, 0.1), "MagnetBar")
			for x: float in [-0.21, 0.21]:
				CourseBuilder.add_decor_box(holder, Vector3(0.18, 0.4, 0.18), Vector3(x, 1.85, 0.0), Color(0.85, 0.1, 0.1), "MagnetLeg")
				CourseBuilder.add_decor_box(holder, Vector3(0.18, 0.12, 0.18), Vector3(x, 1.6, 0.0), Color(0.9, 0.9, 0.95), "MagnetTip")
		Effect.SHIELD:
			var bubble := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 1.0
			sphere.height = 2.0
			var mat := CourseBuilder.make_material(Color(0.5, 0.8, 1.0, 0.3))
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			sphere.material = mat
			bubble.mesh = sphere
			bubble.position = Vector3(0.0, 0.75, 0.0)
			holder.add_child(bubble)
		_:
			pass
