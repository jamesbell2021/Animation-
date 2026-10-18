class_name TouchControls
extends Control
## On-screen joystick (left part of the screen, appears where you touch), a
## jump button (right part) and a USE button above it for items. Writes to the standard input actions so the
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
@export var use_button_radius: float = 62.0
## Offset of the USE button from the jump button's centre.
@export var use_button_offset: Vector2 = Vector2(-40.0, -185.0)

const ACTIONS: Array[String] = ["move_left", "move_right", "move_forward", "move_back", "jump", "use_item"]

var _joy_index: int = -1
var _joy_origin: Vector2 = Vector2.ZERO
var _joy_vector: Vector2 = Vector2.ZERO
var _jump_index: int = -1
var _use_index: int = -1
var _has_item: bool = false
var _item_colour: Color = Color.WHITE


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = force_visible or DisplayServer.is_touchscreen_available()
	set_process_unhandled_input(visible)
	for action in ACTIONS:
		if not InputMap.has_action(action):
			push_error("TouchControls: missing input action '%s'." % action)


## Shows whether an item is held (the USE button lights up in the item's colour).
func set_item_state(has_item: bool, colour: Color) -> void:
	if has_item == _has_item and colour == _item_colour:
		return
	_has_item = has_item
	_item_colour = colour
	queue_redraw()


func get_use_centre() -> Vector2:
	return get_jump_centre() + use_button_offset


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
	elif _use_index == -1 and pos.distance_to(get_use_centre()) < use_button_radius * 1.3:
		_use_index = index
		Input.action_press("use_item")
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
	elif index == _use_index:
		_use_index = -1
		Input.action_release("use_item")
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
	for action in ACTIONS:
		if InputMap.has_action(action):
			Input.action_release(action)
	_joy_index = -1
	_jump_index = -1
	_use_index = -1
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

	var use_centre := get_use_centre()
	var use_alpha := 0.6 if _use_index != -1 else (0.45 if _has_item else 0.12)
	draw_circle(use_centre, use_button_radius, Color(_item_colour if _has_item else Color.WHITE, use_alpha))
	draw_arc(use_centre, use_button_radius, 0.0, TAU, 40, Color(1.0, 1.0, 1.0, 0.8 if _has_item else 0.3), 4.0)
	draw_string(font, use_centre + Vector2(-30.0, 9.0), "USE", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1.0, 1.0, 1.0, 0.9 if _has_item else 0.4))

	if _joy_index != -1:
		draw_circle(_joy_origin, joystick_radius, Color(1.0, 1.0, 1.0, 0.15))
		draw_arc(_joy_origin, joystick_radius, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.6), 3.0)
		draw_circle(_joy_origin + _joy_vector * joystick_radius, knob_radius, Color(accent_colour, 0.7))
	else:
		var hint := Vector2(jump_button_margin.x, size.y - jump_button_margin.y)
		draw_arc(hint, joystick_radius * 0.6, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.25), 3.0)
		draw_circle(hint, knob_radius * 0.5, Color(1.0, 1.0, 1.0, 0.2))
