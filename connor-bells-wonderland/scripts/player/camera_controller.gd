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

## Paintball: the camera swings round to stay on the far side of the target
## from [member arena_centre], so it always looks in towards the action.
var arena_mode: bool = false
var arena_centre: Vector3 = Vector3.ZERO

var _target: Node3D
var _yaw: float = 0.0
var _orbit: bool = false
var _trauma: float = 0.0
var _defaults: Array[float] = []


func _ready() -> void:
	current = true


func set_target(node: Node3D) -> void:
	_target = node
	if is_instance_valid(_target):
		if arena_mode and not _orbit:
			var out := _target.global_position - arena_centre
			if Vector2(out.x, out.z).length() > 5.0:
				_yaw = atan2(out.x, out.z)
		global_position = _target.global_position + _offset()
		_look_at_target()


func set_orbit(enabled: bool) -> void:
	_orbit = enabled
	if not enabled:
		_yaw = 0.0
		if not _defaults.is_empty():
			orbit_distance = _defaults[0]
			height = _defaults[1]
			look_height = _defaults[2]
			orbit_speed_degrees = _defaults[3]


## Wide, low orbit around [param node] looking up at the sky (fireworks finale).
func set_finale(node: Node3D) -> void:
	if _defaults.is_empty():
		_defaults = [orbit_distance, height, look_height, orbit_speed_degrees]
	_target = node
	_orbit = true
	orbit_distance = 26.0
	height = 4.0
	look_height = 12.0
	orbit_speed_degrees = 10.0


## Screen shake: 0..1 (adds up, fades over about half a second).
func add_shake(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func get_target() -> Node3D:
	return _target


func _process(delta: float) -> void:
	if not is_instance_valid(_target):
		return
	if _orbit:
		_yaw = wrapf(_yaw + deg_to_rad(orbit_speed_degrees) * delta, 0.0, TAU)
	elif arena_mode:
		var out := _target.global_position - arena_centre
		out.y = 0.0
		if out.length() > 5.0:
			_yaw = lerp_angle(_yaw, atan2(out.x, out.z), clampf(1.5 * delta, 0.0, 1.0))
	var desired := _target.global_position + _offset()
	if _orbit or arena_mode:
		desired = _unblocked(desired)
	var weight: float = clampf(smoothing * delta, 0.0, 1.0)
	global_position = global_position.lerp(desired, weight)
	_look_at_target()
	if _trauma > 0.0:
		_trauma = maxf(_trauma - delta * 1.8, 0.0)
		var s := _trauma * _trauma
		rotate_object_local(Vector3.RIGHT, randf_range(-1.0, 1.0) * 0.06 * s)
		rotate_object_local(Vector3.UP, randf_range(-1.0, 1.0) * 0.06 * s)
		h_offset = randf_range(-1.0, 1.0) * 0.35 * s
		v_offset = randf_range(-1.0, 1.0) * 0.35 * s
	else:
		h_offset = 0.0
		v_offset = 0.0


## Pulls the orbiting camera in front of any scenery between it and the target.
func _unblocked(desired: Vector3) -> Vector3:
	var focus := _target.global_position + Vector3.UP * look_height
	var query := PhysicsRayQueryParameters3D.create(focus, desired, 1)
	var hit_info := get_world_3d().direct_space_state.intersect_ray(query)
	if hit_info.is_empty():
		return desired
	var hit_pos: Vector3 = hit_info["position"]
	return hit_pos + (focus - hit_pos).normalized() * 0.6


func _offset() -> Vector3:
	var d := orbit_distance if _orbit else distance
	return Vector3(sin(_yaw) * d, height, cos(_yaw) * d)


func _look_at_target() -> void:
	var focus := _target.global_position + Vector3.UP * look_height
	if global_position.distance_squared_to(focus) > 0.001:
		look_at(focus)
