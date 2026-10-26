class_name Walker
extends Node2D
## Base for everyone who walks around the hotel: guests, staff, the manager, thieves and the
## inspector. Owns a VendorAvatar, waypoint movement through the stairwell and a speech bubble.

var world: Node                # the Hotel scene controller (scripts/world/hotel_world.gd)
var path: Array[Vector2] = []
var avatar: VendorAvatar
var speed := 80.0
var target := Vector2.ZERO
var moving := false
var running := false
var bubble: SpeechBubble


func setup_avatar(appearance: Dictionary, cull := true, follow_player := false) -> void:
	if avatar == null:
		avatar = VendorAvatar.new()
		avatar.cull_offscreen = cull
		avatar.follow_character_data = follow_player
		add_child(avatar)
	if not follow_player:
		avatar.set_appearance(appearance)


func walk_to(p: Vector2, run := false) -> void:
	target = p
	moving = true
	running = run
	path.clear()


## Walk anywhere in the hotel: stairs and pool edges are handled by HotelLayout.route().
func go_to(p: Vector2, run := false) -> void:
	path = HotelLayout.route(position, p)
	running = run
	if path.is_empty():
		return
	target = path.pop_front()
	moving = true


## Follows the route. Returns true once the final waypoint is reached (or if idle).
func step_path(delta: float, spd := -1.0) -> bool:
	if not moving:
		return path.is_empty()
	if step_move(delta, spd):
		if path.is_empty():
			return true
		target = path.pop_front()
		moving = true
		if avatar:
			avatar.set_pose(VendorAvatar.Pose.RUN if running else VendorAvatar.Pose.WALK)
	return false


func stop() -> void:
	moving = false
	if avatar and avatar.pose in [VendorAvatar.Pose.WALK, VendorAvatar.Pose.RUN]:
		avatar.set_pose(VendorAvatar.Pose.IDLE)


## Moves toward the target. Returns true on the frame it arrives (or if not moving).
func step_move(delta: float, spd := -1.0) -> bool:
	if not moving:
		return true
	var to := target - position
	var d := to.length()
	if d < 3.0:
		position = target
		if path.is_empty():
			stop()
		else:
			moving = false
		return true
	var s := (speed if spd < 0.0 else spd) * delta
	position += to / d * minf(s, d)
	avatar.set_facing(to.x)
	avatar.move_speed = clampf((speed if spd < 0.0 else spd) / 90.0, 0.6, 1.8)
	avatar.set_pose(VendorAvatar.Pose.RUN if running else VendorAvatar.Pose.WALK)
	return false


func face(p: Vector2) -> void:
	if avatar:
		avatar.set_facing(p.x - position.x)


## Speech bubble above the head. kind: normal, shout, sale, police, bad, think.
func say(text: String, kind := "normal", seconds := 2.2) -> void:
	if text == "":
		return
	if bubble == null:
		bubble = SpeechBubble.new()
		add_child(bubble)
	bubble.position = Vector2(0, avatar.get_head_top() - 4.0 if avatar else -130.0)
	bubble.show_text(text, kind, seconds)
	if avatar and kind in ["normal", "shout", "sale", "police", "bad"]:
		avatar.talk(minf(seconds * 0.6, 1.6))


func hide_bubble() -> void:
	if bubble:
		bubble.hide_now()
