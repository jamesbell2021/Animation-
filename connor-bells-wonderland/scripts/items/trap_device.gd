class_name TrapDevice
extends Node3D
## Placed traps. CATAPULT/BOXING_GLOVE/SPRINGER knock the victim and vanish.
## OIL_SLICK stays for a while and makes everyone who crosses it slippery.
## CAKE makes its victim fat and slow, SHRINK_POTION makes it tiny; both then
## vanish. A Shield Bubble blocks any trap once. The host decides hits;
## clients replay animations via trigger_remote().

signal triggered(trap: TrapDevice, victim: Contestant)

@export var arm_delay: float = 1.0
@export var owner_immunity: float = 3.0
@export var trigger_radius: float = 1.3

var kind: ItemKinds.Kind = ItemKinds.Kind.SPRINGER
var owner_name: String = ""
var trap_id: int = 0

var _age: float = 0.0
var _spent: bool = false
var _fire_time: float = -1.0
var _lifetime: float = -1.0
var _victim_cooldowns: Dictionary = {}
var _moving_part: Node3D
var _rest_position: Vector3 = Vector3.ZERO
var _rest_rotation: Vector3 = Vector3.ZERO
var _fired_offset: Vector3 = Vector3.ZERO
var _fired_rotation: Vector3 = Vector3.ZERO
var _punch_dir: Vector3 = Vector3.ZERO


static func create(parent: Node, pos: Vector3, p_kind: ItemKinds.Kind, p_owner: String, p_id: int) -> TrapDevice:
	if parent == null:
		push_error("TrapDevice.create: parent is null.")
		return null
	var trap := TrapDevice.new()
	trap.kind = p_kind
	trap.owner_name = p_owner
	trap.trap_id = p_id
	trap.name = "Trap%d" % p_id
	trap.position = pos
	parent.add_child(trap)
	return trap


func _ready() -> void:
	match kind:
		ItemKinds.Kind.CATAPULT:
			_build_catapult()
		ItemKinds.Kind.BOXING_GLOVE:
			_build_glove()
		ItemKinds.Kind.OIL_SLICK:
			_build_oil()
			_lifetime = float(ItemKinds.get_def(kind).get("lifetime", 12.0))
		ItemKinds.Kind.CAKE:
			_build_cake()
		ItemKinds.Kind.SHRINK_POTION:
			_build_potion()
		_:
			_build_springer()
	var area := Area3D.new()
	area.name = "Trigger"
	area.collision_mask = Contestant.AREA_MASK
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = trigger_radius
	cyl.height = 1.6
	shape.shape = cyl
	shape.position = Vector3(0.0, 0.8, 0.0)
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_age += delta
	if _lifetime > 0.0 and _age > _lifetime:
		queue_free()
		return
	if _fire_time < 0.0:
		var pulse := 1.0 + sin(_age * 8.0) * (0.08 if _age < arm_delay else 0.03)
		if kind != ItemKinds.Kind.OIL_SLICK:
			scale = Vector3(pulse, pulse, pulse)
		return
	var t := clampf((_age - _fire_time) / 0.3, 0.0, 1.0)
	if _moving_part != null:
		_moving_part.position = _rest_position.lerp(_rest_position + _fired_offset, t)
		_moving_part.rotation = _rest_rotation.lerp(_rest_rotation + _fired_rotation, t)
	if kind == ItemKinds.Kind.CAKE or kind == ItemKinds.Kind.SHRINK_POTION:
		scale = Vector3.ONE * maxf(1.0 - t, 0.01)
	if _age - _fire_time > 0.9:
		queue_free()


func is_armed() -> bool:
	return _age >= arm_delay and not _spent


func is_one_shot() -> bool:
	return kind != ItemKinds.Kind.OIL_SLICK


## Client-side replay of a trigger.
func trigger_remote(punch_direction: Vector3 = Vector3.ZERO) -> void:
	if not is_one_shot() or _spent:
		return
	_spent = true
	if punch_direction != Vector3.ZERO:
		_set_punch_direction(punch_direction)
	_fire_time = _age
	_fire_fx()


func get_punch_direction() -> Vector3:
	return _punch_dir


func _on_body_entered(body: Node3D) -> void:
	if _spent or not (body is Contestant) or not multiplayer.is_server():
		return
	if _age < arm_delay:
		return
	var victim := body as Contestant
	if str(victim.name) == owner_name and _age < owner_immunity:
		return
	var def := ItemKinds.get_def(kind)
	var stumble := float(def.get("stumble", 1.0))
	var punch_dir := Vector3.ZERO
	match kind:
		ItemKinds.Kind.CATAPULT:
			StatusEffects.try_knock(victim, Vector3(0.0, float(def.get("launch_up", 14.0)), float(def.get("launch_back", 12.0))), stumble)
		ItemKinds.Kind.BOXING_GLOVE:
			punch_dir = victim.global_position - global_position
			punch_dir.y = 0.0
			punch_dir = punch_dir.normalized() if punch_dir.length() > 0.05 else Vector3.FORWARD
			StatusEffects.try_knock(victim, punch_dir * float(def.get("punch", 14.0)) + Vector3.UP * float(def.get("launch_up", 5.0)), stumble)
		ItemKinds.Kind.OIL_SLICK:
			var now := Time.get_ticks_msec() / 1000.0
			if now - float(_victim_cooldowns.get(str(victim.name), -100.0)) < 1.0:
				return
			_victim_cooldowns[str(victim.name)] = now
			_apply_status(victim, StatusEffects.Effect.OIL, float(def.get("effect_seconds", 4.0)))
			FX.burst(self, "oil", victim.global_position, Color.WHITE, 1.2)
			SoundManager.world(self, "splash", global_position)
			triggered.emit(self, victim)
			return
		ItemKinds.Kind.CAKE:
			_apply_status(victim, StatusEffects.Effect.FAT, float(def.get("effect_seconds", 6.0)))
		ItemKinds.Kind.SHRINK_POTION:
			_apply_status(victim, StatusEffects.Effect.SMALL, float(def.get("effect_seconds", 6.0)))
		_:
			StatusEffects.try_knock(victim, Vector3(victim.velocity.x * 0.5, float(def.get("launch_up", 22.0)), victim.velocity.z * 0.5), stumble)
	_spent = true
	_punch_dir = punch_dir
	if punch_dir != Vector3.ZERO:
		_set_punch_direction(punch_dir)
	_fire_time = _age
	_fire_fx()
	triggered.emit(self, victim)


## Particles and sound when a one-shot trap goes off (host and clients).
func _fire_fx() -> void:
	if not is_inside_tree():
		return
	var pos := global_position + Vector3.UP * 0.8
	match kind:
		ItemKinds.Kind.BOXING_GLOVE:
			FX.burst(self, "impact", pos, Color.WHITE, 1.4)
			SoundManager.world(self, "punch", pos, 1.0, 3.0)
		ItemKinds.Kind.CAKE:
			FX.burst(self, "crumbs", pos, Color.WHITE, 1.5)
			SoundManager.world(self, "munch", pos)
		ItemKinds.Kind.SHRINK_POTION:
			FX.burst(self, "magic", pos, Color.WHITE, 1.5)
			SoundManager.world(self, "bloop", pos)
		_:
			FX.burst(self, "dust", global_position, Color.WHITE, 1.4)
			FX.ring(self, global_position, 2.0, ItemKinds.colour_for(kind))
			SoundManager.world(self, "boing", pos, 1.0, 2.0)


func _apply_status(victim: Contestant, effect: int, seconds: float) -> void:
	var status := victim.get_node_or_null("StatusEffects") as StatusEffects
	if status != null:
		if status.consume_shield():
			return
		status.apply(effect, seconds)
	else:
		victim.knock(Vector3.UP * 3.0, 0.8)


func _set_punch_direction(dir: Vector3) -> void:
	_fired_offset = dir * 1.6
	if _moving_part != null:
		_moving_part.rotation.y = atan2(-dir.x, -dir.z)


func _build_catapult() -> void:
	var wood := Color(0.55, 0.35, 0.15)
	CourseBuilder.add_decor_box(self, Vector3(1.4, 0.3, 1.4), Vector3(0.0, 0.15, 0.0), wood, "Base")
	CourseBuilder.add_decor_box(self, Vector3(0.2, 0.9, 0.2), Vector3(-0.4, 0.75, 0.0), wood, "PostL")
	CourseBuilder.add_decor_box(self, Vector3(0.2, 0.9, 0.2), Vector3(0.4, 0.75, 0.0), wood, "PostR")
	_moving_part = Node3D.new()
	_moving_part.name = "Arm"
	_moving_part.position = Vector3(0.0, 1.1, 0.0)
	_moving_part.rotation = Vector3(0.6, 0.0, 0.0)
	add_child(_moving_part)
	CourseBuilder.add_decor_box(_moving_part, Vector3(0.18, 0.14, 1.8), Vector3(0.0, 0.0, 0.4), wood, "Beam")
	var bucket := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.4
	sphere.material = CourseBuilder.make_material(Color(0.3, 0.3, 0.35))
	bucket.mesh = sphere
	bucket.position = Vector3(0.0, 0.1, 1.3)
	_moving_part.add_child(bucket)
	_rest_position = _moving_part.position
	_rest_rotation = _moving_part.rotation
	_fired_rotation = Vector3(-1.9, 0.0, 0.0)


func _build_glove() -> void:
	CourseBuilder.add_decor_cylinder(self, 0.6, 0.3, Vector3(0.0, 0.15, 0.0), Color(0.3, 0.3, 0.35), "Base")
	CourseBuilder.add_decor_box(self, Vector3(0.15, 0.9, 0.15), Vector3(0.0, 0.45, 0.0), Color(0.3, 0.3, 0.35), "Stand")
	_moving_part = Node3D.new()
	_moving_part.name = "Glove"
	_moving_part.position = Vector3(0.0, 0.9, 0.0)
	add_child(_moving_part)
	for i in range(4):
		CourseBuilder.add_decor_cylinder(_moving_part, 0.22, 0.08, Vector3(0.0, 0.0, 0.3 + float(i) * 0.12), Color(0.8, 0.8, 0.85), "Coil")
	var glove := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.45
	sphere.height = 0.9
	sphere.material = CourseBuilder.make_material(Color(0.9, 0.1, 0.1))
	glove.mesh = sphere
	glove.position = Vector3(0.0, 0.0, -0.2)
	_moving_part.add_child(glove)
	CourseBuilder.add_decor_box(_moving_part, Vector3(0.5, 0.3, 0.3), Vector3(0.0, -0.2, 0.15), Color(0.95, 0.95, 0.95), "Cuff")
	_rest_position = _moving_part.position
	_rest_rotation = _moving_part.rotation
	_fired_offset = Vector3(0.0, 0.0, -1.6)


func _build_springer() -> void:
	CourseBuilder.add_decor_cylinder(self, 0.8, 0.2, Vector3(0.0, 0.1, 0.0), Color(0.3, 0.3, 0.35), "Base")
	for i in range(5):
		CourseBuilder.add_decor_cylinder(self, 0.55, 0.1, Vector3(0.0, 0.28 + float(i) * 0.12, 0.0), CourseBuilder.accent(i), "Coil%d" % i)
	_moving_part = Node3D.new()
	_moving_part.name = "Plate"
	_moving_part.position = Vector3(0.0, 0.9, 0.0)
	add_child(_moving_part)
	CourseBuilder.add_decor_cylinder(_moving_part, 0.8, 0.15, Vector3.ZERO, Color(0.2, 0.8, 0.3), "PlateMesh")
	CourseBuilder.add_sign(_moving_part, "BOING", Vector3(0.0, 0.5, 0.0), Color.WHITE, 40)
	_rest_position = _moving_part.position
	_rest_rotation = _moving_part.rotation
	_fired_offset = Vector3(0.0, 2.5, 0.0)


func _build_oil() -> void:
	trigger_radius = 1.6
	var puddle := CourseBuilder.make_cylinder_mesh(1.6, 0.06, Color(0.15, 0.1, 0.2))
	puddle.name = "Puddle"
	puddle.position = Vector3(0.0, 0.03, 0.0)
	add_child(puddle)
	for i in range(5):
		var a := i * TAU / 5.0
		var sheen := CourseBuilder.make_cylinder_mesh(0.35, 0.04, CourseBuilder.accent(i + 2))
		sheen.position = Vector3(cos(a) * 0.9, 0.07, sin(a) * 0.9)
		add_child(sheen)
	var can := CourseBuilder.make_cylinder_mesh(0.25, 0.5, Color(0.9, 0.8, 0.1))
	can.position = Vector3(1.2, 0.2, 0.6)
	can.rotation.z = PI * 0.4
	add_child(can)


func _build_cake() -> void:
	var tiers := [[0.9, 0.35, Color(1.0, 0.6, 0.8)], [0.65, 0.3, Color(0.95, 0.9, 0.7)], [0.4, 0.3, Color(0.6, 0.3, 0.2)]]
	var y := 0.0
	for tier: Array in tiers:
		var radius: float = tier[0]
		var height: float = tier[1]
		var colour: Color = tier[2]
		CourseBuilder.add_decor_cylinder(self, radius, height, Vector3(0.0, y + height * 0.5, 0.0), colour, "Tier")
		CourseBuilder.add_decor_cylinder(self, radius + 0.03, 0.06, Vector3(0.0, y + height, 0.0), Color.WHITE, "Icing")
		y += height
	for i in range(6):
		var a := i * TAU / 6.0
		var cherry := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.08
		sphere.height = 0.16
		sphere.material = CourseBuilder.make_material(Color(0.9, 0.1, 0.2))
		cherry.mesh = sphere
		cherry.position = Vector3(cos(a) * 0.7, 0.42, sin(a) * 0.7)
		add_child(cherry)
	CourseBuilder.add_decor_box(self, Vector3(0.05, 0.3, 0.05), Vector3(0.0, y + 0.15, 0.0), Color(1.0, 0.9, 0.3), "Candle")
	var flame := MeshInstance3D.new()
	var fs := SphereMesh.new()
	fs.radius = 0.06
	fs.height = 0.14
	fs.material = CourseBuilder.make_material(Color(1.0, 0.6, 0.1))
	flame.mesh = fs
	flame.position = Vector3(0.0, y + 0.35, 0.0)
	add_child(flame)


func _build_potion() -> void:
	var glass := CourseBuilder.make_material(Color(0.4, 0.9, 0.6, 0.75))
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var flask := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.45
	sphere.height = 0.85
	sphere.material = glass
	flask.mesh = sphere
	flask.position = Vector3(0.0, 0.45, 0.0)
	add_child(flask)
	CourseBuilder.add_decor_cylinder(self, 0.14, 0.35, Vector3(0.0, 1.0, 0.0), Color(0.4, 0.9, 0.6), "Neck")
	CourseBuilder.add_decor_cylinder(self, 0.16, 0.14, Vector3(0.0, 1.22, 0.0), Color(0.55, 0.35, 0.15), "Cork")
	var fizz := MeshInstance3D.new()
	var bubble := SphereMesh.new()
	bubble.radius = 0.32
	bubble.height = 0.5
	bubble.material = CourseBuilder.make_material(Color(0.6, 0.2, 0.8))
	fizz.mesh = bubble
	fizz.position = Vector3(0.0, 0.38, 0.0)
	add_child(fizz)
	CourseBuilder.add_sign(self, "SHRINK", Vector3(0.0, 1.7, 0.0), Color(0.7, 1.0, 0.8), 40)
