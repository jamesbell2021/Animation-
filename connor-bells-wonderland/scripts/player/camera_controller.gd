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
## Tower Climb: swing the camera this far (degrees) from straight-out towards
## behind the target as it runs anticlockwise round [member arena_centre].
var arena_swing_degrees: float = 0.0

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
				_yaw = _arena_yaw(out)
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
			_yaw = lerp_angle(_yaw, _arena_yaw(out), clampf(1.5 * delta, 0.0, 1.0))
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


## Keeps scenery from getting between the camera and the target. In the arena
## the camera first rises up over low walls; otherwise (or if that fails) it is
## pulled in front of whatever is in the way.
func _unblocked(desired: Vector3) -> Vector3:
	var focus := _target.global_position + Vector3.UP * look_height
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(focus, desired, 1)
	var hit_info := space.intersect_ray(query)
	if hit_info.is_empty():
		return desired
	if arena_mode and not _orbit:
		var flat := Vector3(desired.x - _target.global_position.x, 0.0, desired.z - _target.global_position.z)
		for step in range(1, 6):
			var lift := float(step) * 3.0
			var candidate := _target.global_position + flat * (1.0 - float(step) * 0.08) + Vector3.UP * (height + lift)
			if space.intersect_ray(PhysicsRayQueryParameters3D.create(focus, candidate, 1)).is_empty():
				return candidate
		# Pressed against a wall: look down from almost straight above.
		var overhead := _target.global_position + flat * 0.12 + Vector3.UP * (height + 6.0)
		if space.intersect_ray(PhysicsRayQueryParameters3D.create(focus, overhead, 1)).is_empty():
			return overhead
	var hit_pos: Vector3 = hit_info["position"]
	return hit_pos + (focus - hit_pos).normalized() * 0.6


## Camera direction for arena mode: straight out from the centre, swung back
## along the way the target runs round it by arena_swing_degrees.
func _arena_yaw(out: Vector3) -> float:
	var flat := Vector3(out.x, 0.0, out.z).normalized()
	var swing := deg_to_rad(arena_swing_degrees)
	var tangent := Vector3(-flat.z, 0.0, flat.x)
	var dir := flat * cos(swing) - tangent * sin(swing)
	return atan2(dir.x, dir.z)


func _offset() -> Vector3:
	var d := orbit_distance if _orbit else distance
	return Vector3(sin(_yaw) * d, height, cos(_yaw) * d)


func _look_at_target() -> void:
	var focus := _target.global_position + Vector3.UP * look_height
	if global_position.distance_squared_to(focus) > 0.001:
		look_at(focus)
