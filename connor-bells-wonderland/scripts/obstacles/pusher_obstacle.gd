class_name PusherObstacle
extends AnimatableBody3D
## A dodgem car that drives back and forth along [member travel] at constant speed.
## Contestants entering its bumper zone are knocked away and tumble.

signal pushed(contestant: Contestant)

@export var body_size: Vector3 = Vector3(1.6, 0.7, 2.2)
## Offset from the start position to the far end of the drive.
@export var travel: Vector3 = Vector3(8.0, 0.0, 0.0)
@export var speed: float = 4.0
@export var push_force: float = 9.0
@export var push_up: float = 4.5
@export var stumble_seconds: float = 0.8
@export var colour: Color = Color(1.0, 0.3, 0.3)
## 0..1 fraction of the path to start at, so cars are not synchronised.
@export var phase: float = 0.0

var _origin: Vector3
var _direction: Vector3 = Vector3.ZERO
var _length: float = 0.0
var _distance: float = 0.0
var _forward: bool = true


## [param pos] is local to [param parent]; y is the floor level under the car.
static func create(parent: Node, pos: Vector3, p_travel: Vector3, p_speed: float, p_colour: Color, p_phase: float = 0.0) -> PusherObstacle:
	if parent == null:
		push_error("PusherObstacle.create: parent is null.")
		return null
	var car := PusherObstacle.new()
	car.travel = p_travel
	car.speed = p_speed
	car.colour = p_colour
	car.phase = p_phase
	car.position = pos
	parent.add_child(car)
	return car


func _ready() -> void:
	sync_to_physics = true
	_origin = position
	_length = travel.length()
	if _length > 0.0:
		_direction = travel / _length
	_distance = clampf(phase, 0.0, 1.0) * _length
	if get_child_count() == 0:
		_build_geometry()
	_update_transform()


func _physics_process(delta: float) -> void:
	if _length <= 0.0:
		return
	var step := speed * delta
	if _forward:
		_distance += step
		if _distance >= _length:
			_distance = _length
			_forward = false
	else:
		_distance -= step
		if _distance <= 0.0:
			_distance = 0.0
			_forward = true
	_update_transform()


func _update_transform() -> void:
	position = _origin + _direction * _distance
	var move_dir := _direction if _forward else -_direction
	if move_dir.length_squared() > 0.0:
		rotation.y = atan2(-move_dir.x, -move_dir.z)


func _build_geometry() -> void:
	var half_h := body_size.y * 0.5
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = body_size
	shape.shape = box
	shape.position = Vector3(0.0, half_h + 0.2, 0.0)
	add_child(shape)

	var body := CourseBuilder.make_box_mesh(body_size, colour)
	body.name = "CarBody"
	body.position = Vector3(0.0, half_h + 0.2, 0.0)
	add_child(body)

	var bumper := CourseBuilder.make_box_mesh(body_size + Vector3(0.3, -0.35, 0.3), Color(0.1, 0.1, 0.1))
	bumper.name = "Bumper"
	bumper.position = Vector3(0.0, 0.45, 0.0)
	add_child(bumper)

	var seat := CourseBuilder.make_box_mesh(Vector3(body_size.x * 0.6, 0.4, body_size.z * 0.35), colour.darkened(0.4))
	seat.name = "Seat"
	seat.position = Vector3(0.0, body_size.y + 0.35, body_size.z * 0.15)
	add_child(seat)

	var pole := CourseBuilder.make_cylinder_mesh(0.05, 2.5, Color(0.8, 0.8, 0.8))
	pole.name = "Pole"
	pole.position = Vector3(0.0, body_size.y + 1.3, body_size.z * 0.4)
	pole.rotation.x = deg_to_rad(-20.0)
	add_child(pole)

	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			var wheel := CourseBuilder.make_cylinder_mesh(0.22, 0.2, Color(0.15, 0.15, 0.15))
			wheel.name = "Wheel"
			wheel.rotation.z = deg_to_rad(90.0)
			wheel.position = Vector3(x * body_size.x * 0.5, 0.22, z * body_size.z * 0.3)
			add_child(wheel)

	var zone := Area3D.new()
	zone.name = "PushZone"
	zone.collision_mask = Contestant.AREA_MASK
	var zone_shape := CollisionShape3D.new()
	var zone_box := BoxShape3D.new()
	zone_box.size = body_size + Vector3(0.8, 1.2, 0.8)
	zone_shape.shape = zone_box
	zone_shape.position = Vector3(0.0, half_h + 0.5, 0.0)
	zone.add_child(zone_shape)
	add_child(zone)
	zone.body_entered.connect(_on_push_zone_entered)


func _on_push_zone_entered(body: Node3D) -> void:
	if not (body is Contestant):
		return
	var contestant := body as Contestant
	var dir := contestant.global_position - global_position
	dir.y = 0.0
	if dir.length_squared() < 0.01:
		dir = _direction if _forward else -_direction
	dir = dir.normalized()
	var impulse := dir * push_force + Vector3.UP * push_up
	contestant.knock(impulse, stumble_seconds)
	pushed.emit(contestant)
