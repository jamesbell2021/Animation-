extends Node
## The first keeper's controls: keyboard and mouse, and (when they're the only one
## playing on this machine: alone, or on the LAN) any gamepad as well.

## True while the first keeper is playing on a pad rather than the mouse: the right
## stick (or the way they walk) aims instead of the cursor.
var pad_active := false
## The gamepad keeper one plays on (-1 until one's used): others' presses can join.
var main_pad := -1
var _pad_events: Array = []

func _ready() -> void:
	_key("move_left", KEY_A)
	_key("move_right", KEY_D)
	_key("move_up", KEY_W)
	_key("move_down", KEY_S)
	_key("interact", KEY_E)
	_key("operate", KEY_R)
	_key("beam_mode", KEY_Q)
	_key("sprint", KEY_SHIFT)
	_key("jump", KEY_SPACE)
	_key("skip", KEY_ENTER)
	_key("use_dirty", KEY_F)
	_mouse("attack", MOUSE_BUTTON_LEFT)
	_mouse("flare", MOUSE_BUTTON_RIGHT)
	# What's in hand: Tab or the wheel to change it, 1 to 5 to pick it. (Playing alone
	# the wheel zooms the camera instead: wheel_zooming.)
	_key("weapon_next", KEY_TAB)
	_mouse("weapon_next", MOUSE_BUTTON_WHEEL_DOWN)
	_mouse("weapon_prev", MOUSE_BUTTON_WHEEL_UP)
	for i in 5:
		_key("weapon_%d" % (i + 1), KEY_1 + i)
	# The camera, playing alone: Z and C turn it, X puts it back (and the middle mouse
	# button dragged, and the wheel to zoom: CameraDirector).
	_key("cam_left", KEY_Z)
	_key("cam_right", KEY_C)
	_key("cam_reset", KEY_X)
	# Zoom by keys too, for a trackpad with no wheel.
	_key("cam_zoom_in", KEY_EQUAL)
	_key("cam_zoom_out", KEY_MINUS)
	for a in ["aim_left", "aim_right", "aim_up", "aim_down"]:
		if not InputMap.has_action(a):
			InputMap.add_action(a, 0.25)

## Put any gamepad on the first keeper's controls too, or take it off again (in local
## co-op the pads belong to the other keepers; see Players.bind_device).
func set_pad(on: bool) -> void:
	for pair in _pad_events:
		if InputMap.has_action(pair[0]):
			InputMap.action_erase_event(pair[0], pair[1])
	_pad_events.clear()
	main_pad = -1
	if not on:
		pad_active = false
		return
	_pad_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_pad_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_pad_axis("move_up", JOY_AXIS_LEFT_Y, -1.0)
	_pad_axis("move_down", JOY_AXIS_LEFT_Y, 1.0)
	_pad_axis("aim_left", JOY_AXIS_RIGHT_X, -1.0)
	_pad_axis("aim_right", JOY_AXIS_RIGHT_X, 1.0)
	_pad_axis("aim_up", JOY_AXIS_RIGHT_Y, -1.0)
	_pad_axis("aim_down", JOY_AXIS_RIGHT_Y, 1.0)
	_pad_button("attack", JOY_BUTTON_X)
	_pad_axis("attack", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_pad_button("interact", JOY_BUTTON_A)
	_pad_button("operate", JOY_BUTTON_Y)
	_pad_button("beam_mode", JOY_BUTTON_B)
	_pad_button("sprint", JOY_BUTTON_RIGHT_SHOULDER)
	# A jumps when there's nothing to hand to use (Player).
	_pad_button("jump", JOY_BUTTON_A)
	_pad_axis("flare", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_pad_button("use_dirty", JOY_BUTTON_LEFT_SHOULDER)
	_pad_button("weapon_next", JOY_BUTTON_DPAD_RIGHT)
	_pad_button("weapon_prev", JOY_BUTTON_DPAD_LEFT)
	_pad_button("skip", JOY_BUTTON_BACK)
	# The free camera on a pad: the d-pad's up and down zoom, a stick pressed in turns it.
	_pad_button("cam_zoom_in", JOY_BUTTON_DPAD_UP)
	_pad_button("cam_zoom_out", JOY_BUTTON_DPAD_DOWN)
	_pad_button("cam_left", JOY_BUTTON_LEFT_STICK)
	_pad_button("cam_right", JOY_BUTTON_RIGHT_STICK)

func _pad_button(action: String, button: JoyButton) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = -1
	ev.button_index = button
	InputMap.action_add_event(action, ev)
	_pad_events.append([action, ev])

func _pad_axis(action: String, axis: JoyAxis, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.device = -1
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)
	_pad_events.append([action, ev])

## When the mouse wheel last turned (ms): with the camera free, the wheel zooms rather
## than changing what's in hand.
var wheel_at := -1000

## Whether a weapon change this moment came from the wheel while it's zooming the camera.
func wheel_zooming() -> bool:
	return CameraDirector.free_on and Time.get_ticks_msec() - wheel_at < 120

## A stick or keys' direction on screen, as a direction on the ground: up the screen is
## away from the camera, however it's turned.
static func on_ground(v: Vector2) -> Vector3:
	return Vector3(v.x, 0.0, v.y).rotated(Vector3.UP, CameraDirector.yaw)

## The right stick, when the first keeper's pad is pushing it.
func pad_stick() -> Vector2:
	return Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")

func _input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and (ev.button_index == MOUSE_BUTTON_WHEEL_UP or ev.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		wheel_at = Time.get_ticks_msec()
	if _pad_events.is_empty():
		return
	if ev is InputEventJoypadButton and ev.pressed or ev is InputEventJoypadMotion and absf(ev.axis_value) > 0.5:
		pad_active = true
		# The first pad keeper one is played on is theirs; later pads can join a friend.
		if main_pad == -1:
			main_pad = ev.device
	elif ev is InputEventMouseMotion and ev.relative.length() > 4.0 or ev is InputEventMouseButton and ev.pressed:
		pad_active = false

func _key(action: String, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.keycode = key
	InputMap.action_add_event(action, ev)

func _mouse(action: String, btn: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = btn
	InputMap.action_add_event(action, ev)
