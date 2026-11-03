class_name CameraRig
extends Node3D
## A tactics camera: a pivot on the ground that glides to its goal, turned in 90-degree
## steps (Q/E), zoomed with the wheel, panned with WASD / arrows / middle-drag.
## Screen shake is added on top as a decaying offset so it never drifts the rig.

const PITCH_DEG := 56.0
const MIN_DIST := 9.0
const MAX_DIST := 34.0
const PAN_SPEED := 18.0
const FOLLOW := 7.0

var camera: Camera3D
var goal := Vector3.ZERO
var bounds := AABB(Vector3.ZERO, Vector3(60, 0, 60))
var _yaw_goal := 0.0
var _dist := 26.0
var _dist_goal := 26.0
var _shake := 0.0
var _drag := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 45.0
	camera.near = 0.3
	camera.far = 200.0
	add_child(camera)
	camera.current = true
	_place_camera(Vector3.ZERO)


func focus(p: Vector3, snap := false) -> void:
	goal = _clamp(Vector3(p.x, 0.0, p.z))
	if snap:
		position = goal


func shake(amount: float) -> void:
	_shake = minf(1.2, _shake + amount)


func rotate_step(dir: int) -> void:
	_yaw_goal += dir * PI / 2.0


func zoom(step: float) -> void:
	_dist_goal = clampf(_dist_goal + step, MIN_DIST, MAX_DIST)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			zoom(-2.0)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			zoom(2.0)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_drag = mb.pressed
	elif event is InputEventMouseMotion and _drag:
		var mm := event as InputEventMouseMotion
		var k := _dist / 600.0
		goal = _clamp(goal + _flat_basis() * Vector3(-mm.relative.x * k, 0.0, -mm.relative.y * k))
	elif event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_Q:
				rotate_step(1)
			KEY_E:
				rotate_step(-1)
			KEY_EQUAL, KEY_KP_ADD:
				zoom(-3.0)
			KEY_MINUS, KEY_KP_SUBTRACT:
				zoom(3.0)


func _process(delta: float) -> void:
	var pan := Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		pan.z -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		pan.z += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		pan.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		pan.x += 1.0
	if pan != Vector3.ZERO:
		goal = _clamp(goal + _flat_basis() * pan.normalized() * PAN_SPEED * delta * (_dist / 20.0))
	var k := 1.0 - exp(-FOLLOW * delta)
	position = position.lerp(goal, k)
	rotation.y = lerp_angle(rotation.y, _yaw_goal, k)
	_dist = lerpf(_dist, _dist_goal, k)
	var offset := Vector3.ZERO
	if _shake > 0.001:
		offset = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), 0.0) * _shake * 0.35
		_shake = maxf(0.0, _shake - delta * 2.2)
	_place_camera(offset)


func _place_camera(offset: Vector3) -> void:
	if camera == null:
		return
	var pitch := deg_to_rad(PITCH_DEG)
	camera.position = Vector3(0.0, sin(pitch) * _dist, cos(pitch) * _dist)
	camera.rotation = Vector3(-pitch, 0.0, 0.0)
	camera.position += camera.basis * offset


func _flat_basis() -> Basis:
	return Basis(Vector3.UP, rotation.y)


func _clamp(p: Vector3) -> Vector3:
	return Vector3(clampf(p.x, bounds.position.x, bounds.end.x), 0.0,
		clampf(p.z, bounds.position.z, bounds.end.z))


## Where the mouse ray meets the ground plane (y = 0), or null.
func ground_point(screen: Vector2) -> Variant:
	var from := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	if absf(dir.y) < 0.0001:
		return null
	var t := -from.y / dir.y
	if t < 0.0:
		return null
	return from + dir * t
