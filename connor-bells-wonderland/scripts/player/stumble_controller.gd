class_name StumbleController
extends Node
## Tumbles the contestant's visual pivot and blocks input for a short time.
## Attach as a child of a Contestant and call setup() with the visual pivot.

signal stumble_started
signal stumble_ended

@export var recover_speed: float = 7.0
@export var wobble_strength: float = 0.35

var is_stumbling: bool = false

var _pivot: Node3D
var _time_left: float = 0.0
var _spin_speed: float = 0.0
var _wobble_dir: float = 1.0


func setup(pivot: Node3D) -> void:
	_pivot = pivot
	if _pivot == null:
		push_warning("StumbleController.setup: pivot is null; stumbles will have no animation.")


## Start a tumble lasting [param seconds]. [param spin] is radians per second forward.
func stumble(seconds: float = 0.9, spin: float = 8.0) -> void:
	if seconds <= 0.0:
		return
	var was_stumbling := is_stumbling
	is_stumbling = true
	_time_left = maxf(_time_left, seconds)
	_spin_speed = spin
	_wobble_dir = 1.0 if randf() < 0.5 else -1.0
	if not was_stumbling:
		stumble_started.emit()


func cancel() -> void:
	var was_stumbling := is_stumbling
	is_stumbling = false
	_time_left = 0.0
	if _pivot != null:
		_pivot.rotation = Vector3.ZERO
	if was_stumbling:
		stumble_ended.emit()


func _process(delta: float) -> void:
	if _pivot == null:
		return
	if is_stumbling:
		_time_left -= delta
		_pivot.rotation.x = wrapf(_pivot.rotation.x + _spin_speed * delta, -PI, PI)
		_pivot.rotation.z = sin(_time_left * 12.0) * wobble_strength * _wobble_dir
		if _time_left <= 0.0:
			is_stumbling = false
			stumble_ended.emit()
	else:
		var w: float = clampf(recover_speed * delta, 0.0, 1.0)
		_pivot.rotation.x = lerp_angle(_pivot.rotation.x, 0.0, w)
		_pivot.rotation.z = lerp_angle(_pivot.rotation.z, 0.0, w)
