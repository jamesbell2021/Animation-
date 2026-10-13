class_name TouchControls
extends Control
## On-screen controls for phones: a floating stick on the left half of the screen, ACTION and
## INTERACT buttons on the right. Read by TouchInput like any other device.

const STICK_RADIUS := 110.0

var move := Vector2.ZERO
var action_held := false
var interact_held := false

var _stick_finger := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _button_fingers := {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	G.touch = self


func _exit_tree() -> void:
	if G.touch == self:
		G.touch = null


func _action_center() -> Vector2:
	var s := get_viewport_rect().size
	return Vector2(s.x - 170.0, s.y - 190.0)


func _interact_center() -> Vector2:
	var s := get_viewport_rect().size
	return Vector2(s.x - 360.0, s.y - 110.0)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var touch := event as InputEventScreenTouch
	var drag := event as InputEventScreenDrag
	if touch:
		var p := touch.position
		if touch.pressed:
			if p.distance_to(_action_center()) < 130.0:
				_button_fingers[touch.index] = "action"
			elif p.distance_to(_interact_center()) < 95.0:
				_button_fingers[touch.index] = "interact"
			elif p.x < get_viewport_rect().size.x * 0.5 and _stick_finger == -1:
				_stick_finger = touch.index
				_stick_origin = p
				_stick_pos = p
		else:
			_button_fingers.erase(touch.index)
			if touch.index == _stick_finger:
				_stick_finger = -1
				move = Vector2.ZERO
	elif drag and drag.index == _stick_finger:
		_stick_pos = drag.position
		var v := (_stick_pos - _stick_origin) / STICK_RADIUS
		move = v.limit_length(1.0) if v.length() > 0.15 else Vector2.ZERO
	action_held = _button_fingers.values().has("action")
	interact_held = _button_fingers.values().has("interact")
	queue_redraw()


func _draw() -> void:
	var col := Color(0.3, 0.9, 1.0, 0.5)
	if _stick_finger != -1:
		draw_arc(_stick_origin, STICK_RADIUS, 0.0, TAU, 48, col, 4.0, true)
		draw_circle(_stick_origin + move * STICK_RADIUS, 44.0, Color(0.3, 0.9, 1.0, 0.35))
	else:
		var hint := Vector2(230.0, get_viewport_rect().size.y - 200.0)
		draw_arc(hint, STICK_RADIUS, 0.0, TAU, 48, Color(col, 0.2), 3.0, true)
	var a := _action_center()
	draw_circle(a, 120.0, Color(1.0, 0.3, 0.85, 0.45 if action_held else 0.2))
	draw_arc(a, 120.0, 0.0, TAU, 48, Color(1.0, 0.3, 0.85, 0.9), 4.0, true)
	draw_string(G.jp_font, a + Vector2(-100, 14), G.t("ACTION"), HORIZONTAL_ALIGNMENT_CENTER, 200, 34, Color.WHITE)
	var i := _interact_center()
	draw_circle(i, 85.0, Color(0.3, 1.0, 0.5, 0.45 if interact_held else 0.2))
	draw_arc(i, 85.0, 0.0, TAU, 48, Color(0.3, 1.0, 0.5, 0.9), 4.0, true)
	draw_string(G.jp_font, i + Vector2(-70, 10), G.t("BOARD"), HORIZONTAL_ALIGNMENT_CENTER, 140, 28, Color.WHITE)
