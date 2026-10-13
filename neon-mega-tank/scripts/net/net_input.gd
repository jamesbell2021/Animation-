class_name NetInput
extends PlayerInput
## Host side: a crew member controlled by a phone on the LAN. Reads the latest input that phone
## sent; button presses arrive as counters so a dropped packet never loses a press.

var peer_id := 0
var _last_action_seq := 0
var _last_interact_seq := 0


func _init(dev: int) -> void:
	device = dev
	peer_id = dev - Net.REMOTE_BASE


func poll() -> void:
	var d: Dictionary = Net.remote_inputs.get(peer_id, {})
	if d.is_empty():
		move = Vector2.ZERO
		action_held = false
		action_pressed = false
		interact_pressed = false
		return
	move = d["move"]
	action_held = d["action"]
	action_pressed = int(d["action_seq"]) != _last_action_seq
	interact_pressed = int(d["interact_seq"]) != _last_interact_seq
	_last_action_seq = d["action_seq"]
	_last_interact_seq = d["interact_seq"]
