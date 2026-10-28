class_name PlayerInput
extends RefCounted
## Reads one physical device (half a keyboard or one gamepad) directly, bypassing the InputMap,
## so two players can share a keyboard and every gamepad drives exactly one crew member.

const KEYBOARD_1 := -1
const KEYBOARD_2 := -2
const DEADZONE := 0.25

var device := KEYBOARD_1
var move := Vector2.ZERO
## Where the guns point: the right stick on a gamepad when it is pushed, otherwise the move stick.
var aim := Vector2.ZERO
var action_held := false
var action_pressed := false
var interact_pressed := false
## LAN phones: where the repair gauge's needle was on the phone's screen when ACTION went down
## (0..1), so the host judges the tap the player actually saw. -1 means "judge it now".
var press_needle := -1.0

var _action_prev := false
var _interact_prev := false


func _init(dev: int) -> void:
	device = dev


## Builds the right input reader for a saved device id.
static func for_device(dev: int) -> PlayerInput:
	if dev >= Net.REMOTE_BASE:
		return NetInput.new(dev)
	if dev == TouchInput.TOUCH_DEVICE:
		return TouchInput.new()
	return PlayerInput.new(dev)


static func device_name(dev: int) -> String:
	if dev <= -100:
		return G.t("AI CREW")
	if dev >= Net.REMOTE_BASE:
		return G.t("LAN PHONE")
	if dev == -3:
		return G.t("TOUCH")
	match dev:
		KEYBOARD_1:
			return G.t("KEYS WASD")
		KEYBOARD_2:
			return G.t("KEYS ARROWS")
	return G.t("PAD %d") % (dev + 1)


func poll() -> void:
	var m := Vector2.ZERO
	var right := Vector2.ZERO
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
		m = _stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y)
		right = _stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y)
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
	aim = right.limit_length(1.0) if right != Vector2.ZERO else move
	action_pressed = act and not _action_prev
	interact_pressed = inter and not _interact_prev
	action_held = act
	_action_prev = act
	_interact_prev = inter


## One analogue stick with a radial deadzone, rescaled so it starts at 0 just past the deadzone.
func _stick(axis_x: JoyAxis, axis_y: JoyAxis) -> Vector2:
	var v := Vector2(Input.get_joy_axis(device, axis_x), Input.get_joy_axis(device, axis_y))
	var mag := v.length()
	if mag < DEADZONE:
		return Vector2.ZERO
	return v / mag * inverse_lerp(DEADZONE, 1.0, minf(mag, 1.0))


func _key(k: Key) -> float:
	return 1.0 if Input.is_physical_key_pressed(k) else 0.0


func _button(b: JoyButton) -> float:
	return 1.0 if Input.is_joy_button_pressed(device, b) else 0.0
