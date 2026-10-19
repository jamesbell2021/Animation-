class_name VanishTile
extends StaticBody3D
## A glowing tile that shakes when someone lands on it, drops away half a
## second later, and comes back after a few seconds.

const SHAKE_TIME := 0.55
const GONE_TIME := 2.8

var size: Vector3 = Vector3(2.2, 0.4, 2.2)
var colour: Color = Color(0.0, 0.78, 1.0)

var _mesh: MeshInstance3D
var _shape: CollisionShape3D
var _timer: float = -1.0
var _gone: bool = false
var _home: Vector3


func _ready() -> void:
	_home = position
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	_shape.shape = box
	add_child(_shape)
	_mesh = CourseBuilder.make_box_mesh(size, CourseBuilder.surface(colour))
	add_child(_mesh)
	CourseBuilder.add_neon_strip(_mesh, Vector3(size.x + 0.04, 0.08, size.z + 0.04), Vector3(0.0, size.y * 0.5, 0.0), colour, "Glow")
	var sensor := Area3D.new()
	sensor.collision_mask = Contestant.AREA_MASK
	var zone := CollisionShape3D.new()
	var zone_box := BoxShape3D.new()
	zone_box.size = Vector3(size.x * 0.9, 0.6, size.z * 0.9)
	zone.shape = zone_box
	zone.position = Vector3(0.0, size.y * 0.5 + 0.3, 0.0)
	sensor.add_child(zone)
	add_child(sensor)
	sensor.body_entered.connect(func(body: Node3D) -> void:
		if body is Contestant and _timer < 0.0 and not _gone:
			_timer = 0.0)


func _physics_process(delta: float) -> void:
	if _timer < 0.0:
		return
	_timer += delta
	if not _gone:
		_mesh.position = Vector3(randf_range(-0.06, 0.06), 0.0, randf_range(-0.06, 0.06)) * (_timer / SHAKE_TIME)
		if _timer >= SHAKE_TIME:
			_gone = true
			_shape.disabled = true
			_mesh.visible = false
			FX.burst(self, "poof", global_position, Color(colour.r * 1.5, colour.g * 1.5, colour.b * 1.5), 0.8)
			SoundManager.world(self, "poof", global_position, 1.3, -6.0)
	elif _timer >= SHAKE_TIME + GONE_TIME:
		_gone = false
		_timer = -1.0
		_shape.disabled = false
		_mesh.visible = true
		_mesh.position = Vector3.ZERO
		FX.burst(self, "sparkle", global_position, colour, 0.7)
