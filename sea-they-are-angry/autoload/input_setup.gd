extends Node
## The first keeper's controls: keyboard and mouse, and (when they're the only one
## playing on this machine: alone, or on the LAN) any gamepad as well.

## True while the first keeper is playing on a pad rather than the mouse: the right
## stick (or the way they walk) aims instead of the cursor.
var pad_active := false
var _pad_events: Array = []

func _ready() -> void:
	_key("move_left", KEY_A)
	_key("move_right", KEY_D)
	_key("move_up", KEY_W)
	_key("move_down", KEY_S)
	_key("interact", KEY_E)
	_key("operate", KEY_R)
	_key("beam_mode", KEY_Q)
	_key("sprint", KEY_SPACE)
	_key("skip", KEY_ENTER)
	_key("use_dirty", KEY_F)
	_mouse("attack", MOUSE_BUTTON_LEFT)
	_mouse("flare", MOUSE_BUTTON_RIGHT)
	# What's in hand: Tab or the wheel to change it, 1 to 5 to pick it.
	_key("weapon_next", KEY_TAB)
	_mouse("weapon_next", MOUSE_BUTTON_WHEEL_DOWN)
	_mouse("weapon_prev", MOUSE_BUTTON_WHEEL_UP)
	for i in 5:
		_key("weapon_%d" % (i + 1), KEY_1 + i)
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
	_pad_axis("flare", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_pad_button("use_dirty", JOY_BUTTON_LEFT_SHOULDER)
	_pad_button("weapon_next", JOY_BUTTON_DPAD_RIGHT)
	_pad_button("weapon_prev", JOY_BUTTON_DPAD_LEFT)
	_pad_button("skip", JOY_BUTTON_BACK)

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

## The right stick, when the first keeper's pad is pushing it.
func pad_stick() -> Vector2:
	return Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")

func _input(ev: InputEvent) -> void:
	if _pad_events.is_empty():
		return
	if ev is InputEventJoypadButton and ev.pressed or ev is InputEventJoypadMotion and absf(ev.axis_value) > 0.5:
		pad_active = true
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
