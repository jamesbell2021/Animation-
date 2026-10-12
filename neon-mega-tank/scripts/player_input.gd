class_name PlayerInput
extends RefCounted
## Reads one physical device (half a keyboard or one gamepad) directly, bypassing the InputMap,
## so two players can share a keyboard and every gamepad drives exactly one crew member.

const KEYBOARD_1 := -1
const KEYBOARD_2 := -2
const DEADZONE := 0.25

var device := KEYBOARD_1
var move := Vector2.ZERO
var action_held := false
var action_pressed := false
var interact_pressed := false

var _action_prev := false
var _interact_prev := false


func _init(dev: int) -> void:
	device = dev


static func device_name(dev: int) -> String:
	match dev:
		KEYBOARD_1:
			return "KEYS WASD"
		KEYBOARD_2:
			return "KEYS ARROWS"
	return "PAD %d" % (dev + 1)


func poll() -> void:
	var m := Vector2.ZERO
	var act := false
	var inter := false
	if device == KEYBOARD_1:
		m = Vector2(_key(KEY_D) - _key(KEY_A), _key(KEY_S) - _key(KEY_W))
		act = Input.is_physical_key_pressed(KEY_SPACE)
		inter = Input.is_physical_key_pressed(KEY_E)
	elif device == KEYBOARD_2:
		m = Vector2(_key(KEY_RIGHT) - _key(KEY_LEFT), _key(KEY_DOWN) - _key(KEY_UP))
		act = Input.is_physical_key_pressed(KEY_ENTER) or Input.is_physical_key_pressed(KEY_KP_ENTER)
		inter = Input.is_physical_key_pressed(KEY_SHIFT) or Input.is_physical_key_pressed(KEY_SLASH)
	else:
		m = Vector2(Input.get_joy_axis(device, JOY_AXIS_LEFT_X), Input.get_joy_axis(device, JOY_AXIS_LEFT_Y))
		var mag := m.length()
		m = Vector2.ZERO if mag < DEADZONE else m / mag * inverse_lerp(DEADZONE, 1.0, minf(mag, 1.0))
		var dpad := Vector2(_button(JOY_BUTTON_DPAD_RIGHT) - _button(JOY_BUTTON_DPAD_LEFT),
				_button(JOY_BUTTON_DPAD_DOWN) - _button(JOY_BUTTON_DPAD_UP))
		if dpad != Vector2.ZERO:
			m = dpad
		act = (Input.is_joy_button_pressed(device, JOY_BUTTON_A)
				or Input.is_joy_button_pressed(device, JOY_BUTTON_RIGHT_SHOULDER)
				or Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT) > 0.4)
		inter = (Input.is_joy_button_pressed(device, JOY_BUTTON_B)
				or Input.is_joy_button_pressed(device, JOY_BUTTON_X)
				or Input.is_joy_button_pressed(device, JOY_BUTTON_Y))
	move = m.limit_length(1.0)
	action_pressed = act and not _action_prev
	interact_pressed = inter and not _interact_prev
	action_held = act
	_action_prev = act
	_interact_prev = inter


func _key(k: Key) -> float:
	return 1.0 if Input.is_physical_key_pressed(k) else 0.0


func _button(b: JoyButton) -> float:
	return 1.0 if Input.is_joy_button_pressed(device, b) else 0.0
