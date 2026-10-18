class_name Contestant
extends CharacterBody3D
## A rounded fairground contestant. Movement, jumping, camera-relative input,
## knocks/stumbles, falling off the course and respawning.
## Local players read Input; bots and touch controls set move_direction/jump_requested.

signal fell
signal respawned
signal jumped
signal landed(impact_speed: float)
signal knocked(impulse: Vector3)

## Physics layer 1 is the course; contestants live on layer 2. Contestants do not
## count as moving platforms, so two of them stacked can't launch each other upward.
const COURSE_LAYER := 1
const CONTESTANT_LAYER := 2
## Mask for trigger areas (checkpoints, coins, traps...) so they see contestants.
const AREA_MASK := COURSE_LAYER | CONTESTANT_LAYER

@export var display_name: String = "Contestant"
@export var move_speed: float = 6.0
@export var acceleration: float = 40.0
@export var friction: float = 30.0
@export_range(0.0, 1.0) var air_control: float = 0.6
@export var jump_velocity: float = 7.5
@export var gravity: float = 20.0
@export var fall_limit_y: float = -5.0
@export var turn_speed: float = 12.0
@export var body_colour: Color = Color(1.0, 0.35, 0.35)
@export var hat_colour: Color = Color(0.1, 0.6, 0.2)
@export var spinner_knock_speed: float = 9.0
@export var spinner_knock_up: float = 4.0
@export var hard_landing_speed: float = 14.0

var respawn_position: Vector3 = Vector3.ZERO
var controls_enabled: bool = true
var is_local_player: bool = true
## World-space desired movement direction (length 0..1). Set by bots/touch when not local.
var move_direction: Vector3 = Vector3.ZERO
var jump_requested: bool = false

var _visual: ContestantVisuals
var _stumble: StumbleController
var _was_on_floor: bool = true


func _ready() -> void:
	collision_layer = CONTESTANT_LAYER
	collision_mask = COURSE_LAYER | CONTESTANT_LAYER
	platform_floor_layers = COURSE_LAYER
	if get_node_or_null("CollisionShape3D") == null:
		_build_collision()
	_visual = get_node_or_null("Visual") as ContestantVisuals
	if _visual == null:
		_visual = ContestantVisuals.new()
		_visual.name = "Visual"
		add_child(_visual)
	_visual.setup(body_colour, hat_colour)
	_visual.move_speed_reference = move_speed
	_stumble = get_node_or_null("StumbleController") as StumbleController
	if _stumble == null:
		_stumble = StumbleController.new()
		_stumble.name = "StumbleController"
		add_child(_stumble)
	_stumble.setup(_visual.pivot)
	if respawn_position == Vector3.ZERO:
		respawn_position = global_position
	for action in ["move_left", "move_right", "move_forward", "move_back", "jump"]:
		if not InputMap.has_action(action):
			push_error("Contestant: missing input action '%s'. Check project.godot." % action)


func _physics_process(delta: float) -> void:
	if is_local_player:
		_gather_local_input()
	var can_act := controls_enabled and not is_stumbling()
	var wish_dir := move_direction if can_act else Vector3.ZERO
	if wish_dir.length() > 1.0:
		wish_dir = wish_dir.normalized()

	var on_floor := is_on_floor()
	if not on_floor:
		velocity.y -= gravity * delta

	var control := 1.0 if on_floor else air_control
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if wish_dir.length() > 0.01:
		horizontal = horizontal.move_toward(wish_dir * move_speed, acceleration * control * delta)
		_face_direction(wish_dir, delta)
	else:
		horizontal = horizontal.move_toward(Vector3.ZERO, friction * control * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	if can_act and on_floor and jump_requested:
		velocity.y = jump_velocity
		jumped.emit()
	jump_requested = false

	var vertical_before := velocity.y
	move_and_slide()
	_handle_collisions()

	if not _was_on_floor and is_on_floor():
		var impact := -vertical_before
		landed.emit(impact)
		if impact > hard_landing_speed:
			_stumble.stumble(0.6, 6.0)
	_was_on_floor = is_on_floor()

	if _visual != null:
		_visual.update_motion(Vector2(velocity.x, velocity.z).length(), is_on_floor(), delta)

	if global_position.y < fall_limit_y:
		_on_fell()


func is_stumbling() -> bool:
	return _stumble != null and _stumble.is_stumbling


## Replace velocity with [param impulse] and tumble for [param stumble_seconds].
func knock(impulse: Vector3, stumble_seconds: float = 0.9) -> void:
	velocity = impulse
	if _stumble != null and stumble_seconds > 0.0:
		_stumble.stumble(stumble_seconds)
	knocked.emit(impulse)


func respawn() -> void:
	velocity = Vector3.ZERO
	global_position = respawn_position
	move_direction = Vector3.ZERO
	jump_requested = false
	if _stumble != null:
		_stumble.cancel()
	respawned.emit()


func set_respawn_point(point: Vector3) -> void:
	respawn_position = point


func _on_fell() -> void:
	fell.emit()
	respawn()


func _gather_local_input() -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	move_direction = _camera_relative_direction(input_dir)
	if Input.is_action_just_pressed("jump"):
		jump_requested = true


func _camera_relative_direction(input_dir: Vector2) -> Vector3:
	if input_dir == Vector2.ZERO:
		return Vector3.ZERO
	var forward := Vector3.FORWARD
	var right := Vector3.RIGHT
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		forward = -cam.global_transform.basis.z
		right = cam.global_transform.basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()
	var dir := right * input_dir.x + forward * (-input_dir.y)
	return dir.limit_length(1.0)


func _face_direction(dir: Vector3, delta: float) -> void:
	if _visual == null:
		return
	var target_angle := atan2(-dir.x, -dir.z)
	_visual.rotation.y = lerp_angle(_visual.rotation.y, target_angle, turn_speed * delta)


## Spinner arms launch the contestant along the arm's direction of travel.
func _handle_collisions() -> void:
	if is_stumbling():
		return
	for i in range(get_slide_collision_count()):
		var collider := get_slide_collision(i).get_collider()
		if collider is SpinnerObstacle:
			var spinner := collider as SpinnerObstacle
			var radial := global_position - spinner.global_position
			radial.y = 0.0
			if radial.length_squared() < 0.01:
				continue
			var tangent := Vector3(radial.z, 0.0, -radial.x).normalized() * signf(spinner.speed_degrees)
			knock(tangent * spinner_knock_speed + Vector3.UP * spinner_knock_up, 0.9)
			return


func _build_collision() -> void:
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.4
	shape.shape = capsule
	shape.position = Vector3(0.0, 0.7, 0.0)
	add_child(shape)
