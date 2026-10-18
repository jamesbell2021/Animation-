class_name TouchControls
extends Control
## On-screen joystick (left part of the screen, appears where you touch) and a
## jump button (right part). Writes to the standard input actions so the
## contestant and network code work unchanged. Hidden on non-touch devices
## unless force_visible is set (use with "Emulate Touch From Mouse" for testing).

@export var force_visible: bool = false
@export var joystick_radius: float = 110.0
@export var knob_radius: float = 45.0
@export var dead_zone: float = 0.12
@export var jump_button_radius: float = 75.0
@export var jump_button_margin: Vector2 = Vector2(150.0, 150.0)
## Fraction of the screen width (from the left) that acts as the joystick zone.
@export_range(0.2, 0.8) var split_ratio: float = 0.55
@export var accent_colour: Color = Color(1.0, 0.85, 0.2)

var _joy_index: int = -1
var _joy_origin: Vector2 = Vector2.ZERO
var _joy_vector: Vector2 = Vector2.ZERO
var _jump_index: int = -1


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = force_visible or DisplayServer.is_touchscreen_available()
	set_process_unhandled_input(visible)
	for action in ["move_left", "move_right", "move_forward", "move_back", "jump"]:
		if not InputMap.has_action(action):
			push_error("TouchControls: missing input action '%s'." % action)


func _exit_tree() -> void:
	_release_all()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_touch_down(touch.index, touch.position)
		else:
			_touch_up(touch.index)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_touch_move(drag.index, drag.position)


func _touch_down(index: int, pos: Vector2) -> void:
	if pos.x < size.x * split_ratio:
		if _joy_index == -1:
			_joy_index = index
			_joy_origin = pos
			_joy_vector = Vector2.ZERO
			queue_redraw()
	elif _jump_index == -1:
		_jump_index = index
		Input.action_press("jump")
		queue_redraw()


func _touch_move(index: int, pos: Vector2) -> void:
	if index != _joy_index:
		return
	var raw := (pos - _joy_origin) / joystick_radius
	if raw.length() > 1.0:
		raw = raw.normalized()
	if raw.length() < dead_zone:
		raw = Vector2.ZERO
	else:
		raw = raw.normalized() * ((raw.length() - dead_zone) / (1.0 - dead_zone))
	_joy_vector = raw
	_apply_joystick()
	queue_redraw()


func _touch_up(index: int) -> void:
	if index == _joy_index:
		_joy_index = -1
		_joy_vector = Vector2.ZERO
		_apply_joystick()
		queue_redraw()
	elif index == _jump_index:
		_jump_index = -1
		Input.action_release("jump")
		queue_redraw()


func _apply_joystick() -> void:
	_set_axis("move_left", "move_right", _joy_vector.x)
	_set_axis("move_forward", "move_back", _joy_vector.y)


func _set_axis(negative: String, positive: String, value: float) -> void:
	if value < 0.0:
		Input.action_release(positive)
		Input.action_press(negative, -value)
	elif value > 0.0:
		Input.action_release(negative)
		Input.action_press(positive, value)
	else:
		Input.action_release(negative)
		Input.action_release(positive)


func _release_all() -> void:
	for action in ["move_left", "move_right", "move_forward", "move_back", "jump"]:
		if InputMap.has_action(action):
			Input.action_release(action)
	_joy_index = -1
	_jump_index = -1
	_joy_vector = Vector2.ZERO


func get_jump_centre() -> Vector2:
	return Vector2(size.x - jump_button_margin.x, size.y - jump_button_margin.y)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var jump_centre := get_jump_centre()
	var pressed := _jump_index != -1
	draw_circle(jump_centre, jump_button_radius, Color(accent_colour, 0.55 if pressed else 0.3))
	draw_arc(jump_centre, jump_button_radius, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.8), 4.0)
	draw_string(font, jump_centre + Vector2(-38.0, 10.0), "JUMP", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1.0, 1.0, 1.0, 0.9))

	if _joy_index != -1:
		draw_circle(_joy_origin, joystick_radius, Color(1.0, 1.0, 1.0, 0.15))
		draw_arc(_joy_origin, joystick_radius, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.6), 3.0)
		draw_circle(_joy_origin + _joy_vector * joystick_radius, knob_radius, Color(accent_colour, 0.7))
	else:
		var hint := Vector2(jump_button_margin.x, size.y - jump_button_margin.y)
		draw_arc(hint, joystick_radius * 0.6, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.25), 3.0)
		draw_circle(hint, knob_radius * 0.5, Color(1.0, 1.0, 1.0, 0.2))
