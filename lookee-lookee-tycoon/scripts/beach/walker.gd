class_name Walker
extends Node2D
## Base for everyone who walks around the beach: the vendor, tourists, police and workers.
## Owns a VendorAvatar, simple straight-line movement and a speech bubble.

var beach: Node                # the Beach scene controller (scripts/beach/beach.gd)
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
		stop()
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
