class_name TouchInput
extends PlayerInput
## The phone's own on-screen controls (also merges in a keyboard or the first gamepad, so the
## same seat can be played on a PC or a phone with a controller).

const TOUCH_DEVICE := -3

var _fallback_pad := PlayerInput.new(0)
var _fallback_keys := PlayerInput.new(PlayerInput.KEYBOARD_1)
var _interact_prev_t := false


func _init() -> void:
	device = TOUCH_DEVICE


func poll() -> void:
	_fallback_pad.poll()
	_fallback_keys.poll()
	var t := G.touch
	var m := t.move if t else Vector2.ZERO
	var act := t != null and t.action_held
	var inter := t != null and t.interact_held
	for f in [_fallback_pad, _fallback_keys]:
		if f.move != Vector2.ZERO:
			m = f.move
		act = act or f.action_held
		inter = inter or f.interact_pressed
	move = m.limit_length(1.0)
	action_pressed = act and not action_held
	interact_pressed = inter and not _interact_prev_t
	_interact_prev_t = inter
	action_held = act
