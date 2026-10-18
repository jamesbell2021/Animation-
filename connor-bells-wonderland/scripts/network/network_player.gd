class_name NetworkPlayer
extends Node
## Child of a Contestant. Host: broadcasts this contestant's state and applies
## input received from its owning peer. Client: sends input if the contestant
## is ours, and smoothly follows received state for every contestant (puppets).

@export var send_rate: float = 20.0
@export var interpolation_speed: float = 12.0
@export var snap_distance: float = 5.0

var peer_id: int = 0
var contestant: Contestant

var _is_host: bool = true
var _is_mine: bool = false
var _send_timer: float = 0.0
var _has_state: bool = false
var _target_pos: Vector3 = Vector3.ZERO
var _target_vel: Vector3 = Vector3.ZERO
var _target_yaw: float = 0.0
var _target_on_floor: bool = true
var _was_stumbling: bool = false
var _target_ballistic: bool = false
var _visual: ContestantVisuals
var _stumble: StumbleController


## [param p_peer_id] is the owning peer (0 for bots). Call after the contestant is in the tree.
func setup(p_contestant: Contestant, p_peer_id: int) -> void:
	contestant = p_contestant
	peer_id = p_peer_id
	if contestant == null:
		push_error("NetworkPlayer.setup: contestant is null.")
		return
	_is_host = multiplayer.is_server()
	_is_mine = peer_id != 0 and peer_id == multiplayer.get_unique_id()
	_visual = contestant.get_node_or_null("Visual") as ContestantVisuals
	_stumble = contestant.get_node_or_null("StumbleController") as StumbleController
	if _is_host:
		contestant.is_local_player = _is_mine
	else:
		contestant.is_local_player = false
		contestant.controls_enabled = false
		contestant.set_physics_process(false)
	_target_pos = contestant.global_position


func is_mine() -> bool:
	return _is_mine


func _physics_process(delta: float) -> void:
	if contestant == null:
		return
	if _is_host:
		_send_timer += delta
		if _send_timer >= 1.0 / maxf(send_rate, 1.0) and _has_clients():
			_send_timer = 0.0
			var yaw := _visual.rotation.y if _visual != null else 0.0
			_rpc_state.rpc(contestant.global_position, contestant.velocity, yaw, contestant.is_on_floor(), contestant.is_stumbling(), contestant.ballistic)
	elif _is_mine:
		var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var jump := Input.is_action_just_pressed("jump")
		var held := InputMap.has_action("use_item") and Input.is_action_pressed("use_item")
		_rpc_input.rpc_id(1, _camera_relative_direction(input_dir), jump, held)
		if InputMap.has_action("use_item") and Input.is_action_just_pressed("use_item"):
			_rpc_use.rpc_id(1)


func _process(delta: float) -> void:
	if _is_host or contestant == null or not _has_state:
		return
	_target_pos += _target_vel * delta
	var w: float = 1.0 - exp(-interpolation_speed * delta)
	if contestant.global_position.distance_to(_target_pos) > snap_distance:
		if _target_pos.y > contestant.global_position.y + 3.0 or contestant.global_position.y < contestant.fall_limit_y + 2.0:
			FX.burst(contestant, "poof", _target_pos)
		contestant.global_position = _target_pos
	else:
		contestant.global_position = contestant.global_position.lerp(_target_pos, w)
	if _visual != null:
		_visual.rotation.y = lerp_angle(_visual.rotation.y, _target_yaw, w)
		_visual.diving = _target_ballistic
		_visual.update_motion(Vector2(_target_vel.x, _target_vel.z).length(), _target_on_floor, delta)


func _has_clients() -> bool:
	return multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0


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
	var dir := right.normalized() * input_dir.x + forward.normalized() * (-input_dir.y)
	return dir.limit_length(1.0)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _rpc_input(direction: Vector3, jump: bool, held: bool) -> void:
	if not _is_host or contestant == null:
		return
	if multiplayer.get_remote_sender_id() != peer_id:
		return
	contestant.move_direction = direction.limit_length(1.0)
	contestant.use_held = held
	if jump:
		contestant.jump_requested = true


## Item presses are rare and must not be lost, so they go reliably.
@rpc("any_peer", "call_remote", "reliable")
func _rpc_use() -> void:
	if not _is_host or contestant == null:
		return
	if multiplayer.get_remote_sender_id() != peer_id:
		return
	contestant.use_requested = true


@rpc("authority", "call_remote", "unreliable_ordered")
func _rpc_state(pos: Vector3, vel: Vector3, yaw: float, on_floor: bool, stumbling: bool, ballistic: bool) -> void:
	if _is_host or contestant == null:
		return
	if not _has_state:
		contestant.global_position = pos
		_has_state = true
	# Effects the host shows from physics, rebuilt here from state changes.
	if on_floor and not _target_on_floor and _target_vel.y < -7.0:
		FX.burst(contestant, "dust", pos, Color.WHITE, clampf(-_target_vel.y / 10.0, 0.6, 1.6))
	if stumbling and not _was_stumbling:
		FX.burst(contestant, "impact", pos + Vector3.UP * 0.9)
		SoundManager.world(contestant, "knock", pos, 1.0, -3.0)
	_was_stumbling = stumbling
	_target_pos = pos
	_target_vel = vel
	_target_yaw = yaw
	_target_on_floor = on_floor
	_target_ballistic = ballistic
	if stumbling and _stumble != null and not _stumble.is_stumbling:
		_stumble.stumble(0.4)
