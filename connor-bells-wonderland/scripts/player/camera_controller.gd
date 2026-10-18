class_name CameraController
extends Camera3D
## Third-person follow camera. Sits behind and above the target (+Z side, the
## course runs toward -Z) and can orbit slowly for the results screen.

@export var distance: float = 8.0
@export var height: float = 5.0
@export var look_height: float = 1.0
@export var smoothing: float = 6.0
@export var orbit_speed_degrees: float = 25.0
@export var orbit_distance: float = 10.0

var _target: Node3D
var _yaw: float = 0.0
var _orbit: bool = false


func _ready() -> void:
	current = true


func set_target(node: Node3D) -> void:
	_target = node
	if is_instance_valid(_target):
		global_position = _target.global_position + _offset()
		_look_at_target()


func set_orbit(enabled: bool) -> void:
	_orbit = enabled
	if not enabled:
		_yaw = 0.0


func get_target() -> Node3D:
	return _target


func _process(delta: float) -> void:
	if not is_instance_valid(_target):
		return
	if _orbit:
		_yaw = wrapf(_yaw + deg_to_rad(orbit_speed_degrees) * delta, 0.0, TAU)
	var desired := _target.global_position + _offset()
	var weight: float = clampf(smoothing * delta, 0.0, 1.0)
	global_position = global_position.lerp(desired, weight)
	_look_at_target()


func _offset() -> Vector3:
	var d := orbit_distance if _orbit else distance
	return Vector3(sin(_yaw) * d, height, cos(_yaw) * d)


func _look_at_target() -> void:
	var focus := _target.global_position + Vector3.UP * look_height
	if global_position.distance_squared_to(focus) > 0.001:
		look_at(focus)
