extends Node
## Local co-op: up to three keepers on one screen.
## P1 always plays on keyboard and mouse with the original action names.
## P2 and P3 get their own actions ("p1_attack", "p2_move_left", ...) bound to a
## gamepad, or for P2 to the arrow-key side of the keyboard when no pad is free.

const MAX := 3
const KEYBOARD_MOUSE := -1
const KEYBOARD_ARROWS := -2
const NAMES := ["Callum", "Hamish", "Mairi", "Ewan"]
const MODELS := ["callum_keeper", "hamish_keeper", "mairi_keeper", "ewan_keeper"]
const COLORS := [Color(1.0, 0.72, 0.25), Color(0.35, 0.85, 1.0), Color(1.0, 0.4, 0.8), Color(0.45, 1.0, 0.45)]
const ACTIONS := ["move_left", "move_right", "move_up", "move_down", "aim_left", "aim_right", "aim_up", "aim_down", "attack", "interact", "operate", "beam_mode", "sprint", "flare", "use_dirty"]

var wanted := 1
## Fill the empty places with helper keepers run by the computer, so there are always
## MAX keepers on the rock. Tests that script every keeper turn this off.
var helpers := true
var devices: Array[int] = [KEYBOARD_MOUSE]
var nodes: Array[Node] = []

func _ready() -> void:
	if not InputMap.has_action("pause"):
		InputMap.add_action("pause")
		var esc := InputEventKey.new()
		esc.keycode = KEY_ESCAPE
		InputMap.action_add_event("pause", esc)
		var start := InputEventJoypadButton.new()
		start.button_index = JOY_BUTTON_START
		start.device = -1
		InputMap.action_add_event("pause", start)

func count() -> int:
	return maxi(1, nodes.size())

## How many keepers people are playing (at least 1): what the creatures scale with.
func humans() -> int:
	var n := 0
	for p in nodes:
		if is_instance_valid(p) and not p.ai:
			n += 1
	return maxi(1, n)

func alive_count() -> int:
	var n := 0
	for p in nodes:
		if is_instance_valid(p) and not p.downed:
			n += 1
	return n

func all_down() -> bool:
	return not nodes.is_empty() and alive_count() == 0

## Decide each keeper's device for a run of n players and (re)create their actions.
func configure(n: int) -> void:
	wanted = clampi(n, 1, MAX)
	devices = [KEYBOARD_MOUSE]
	var pads := Input.get_connected_joypads()
	var next_pad := 0
	for i in range(1, wanted):
		if next_pad < pads.size():
			devices.append(pads[next_pad])
			next_pad += 1
		elif not devices.has(KEYBOARD_ARROWS):
			devices.append(KEYBOARD_ARROWS)
		else:
			# Bind to the next pad id anyway, so a controller plugged in later works.
			devices.append(next_pad)
			next_pad += 1
	for i in range(1, wanted):
		bind_device(i, devices[i])
	nodes.clear()

static func action(idx: int, name: String) -> String:
	if idx == 0:
		return name
	return "p%d_%s" % [idx, name]

func device_label(idx: int) -> String:
	var d := devices[idx] if idx < devices.size() else KEYBOARD_MOUSE
	if d == KEYBOARD_MOUSE:
		return "Keyboard + mouse"
	if d == KEYBOARD_ARROWS:
		return "Arrow keys (Ctrl swing, Shift use, / lamp, . beam, ; flare)"
	var pad_name := Input.get_joy_name(d)
	return "Gamepad %d%s" % [d + 1, (": " + pad_name) if pad_name != "" else " (not connected)"]

func bind_device(idx: int, device: int) -> void:
	for a in ACTIONS:
		var name := action(idx, a)
		if InputMap.has_action(name):
			InputMap.erase_action(name)
		InputMap.add_action(name, 0.25)
	if device == KEYBOARD_ARROWS:
		_key(idx, "move_left", KEY_LEFT)
		_key(idx, "move_right", KEY_RIGHT)
		_key(idx, "move_up", KEY_UP)
		_key(idx, "move_down", KEY_DOWN)
		_key(idx, "attack", KEY_CTRL)
		_key(idx, "interact", KEY_SHIFT)
		_key(idx, "operate", KEY_SLASH)
		_key(idx, "beam_mode", KEY_PERIOD)
		_key(idx, "sprint", KEY_COMMA)
		_key(idx, "flare", KEY_SEMICOLON)
		_key(idx, "use_dirty", KEY_APOSTROPHE)
		return
	_axis(idx, "move_left", device, JOY_AXIS_LEFT_X, -1.0)
	_axis(idx, "move_right", device, JOY_AXIS_LEFT_X, 1.0)
	_axis(idx, "move_up", device, JOY_AXIS_LEFT_Y, -1.0)
	_axis(idx, "move_down", device, JOY_AXIS_LEFT_Y, 1.0)
	_axis(idx, "aim_left", device, JOY_AXIS_RIGHT_X, -1.0)
	_axis(idx, "aim_right", device, JOY_AXIS_RIGHT_X, 1.0)
	_axis(idx, "aim_up", device, JOY_AXIS_RIGHT_Y, -1.0)
	_axis(idx, "aim_down", device, JOY_AXIS_RIGHT_Y, 1.0)
	_button(idx, "attack", device, JOY_BUTTON_X)
	_axis(idx, "attack", device, JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_button(idx, "interact", device, JOY_BUTTON_A)
	_button(idx, "operate", device, JOY_BUTTON_Y)
	_button(idx, "beam_mode", device, JOY_BUTTON_B)
	_button(idx, "sprint", device, JOY_BUTTON_RIGHT_SHOULDER)
	_axis(idx, "flare", device, JOY_AXIS_TRIGGER_LEFT, 1.0)
	_button(idx, "use_dirty", device, JOY_BUTTON_LEFT_SHOULDER)

func _key(idx: int, a: String, key: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = key
	InputMap.action_add_event(action(idx, a), ev)

func _button(idx: int, a: String, device: int, button: JoyButton) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = device
	ev.button_index = button
	InputMap.action_add_event(action(idx, a), ev)

func _axis(idx: int, a: String, device: int, axis: JoyAxis, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.device = device
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action(idx, a), ev)
