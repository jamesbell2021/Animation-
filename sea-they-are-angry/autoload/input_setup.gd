extends Node

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
