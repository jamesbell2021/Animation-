class_name Rocket
extends Node2D
## A rocket: thrust for the first 0.7 s, then a ballistic arc. The battlefield moves it and
## tests it against the machines with a ray cast.

var vel := Vector2.ZERO
var t := 0.0
var alive := true


func advance(dt: float) -> Vector2:
	t += dt
	if t < 0.7:
		vel += vel.normalized() * 260.0 * dt
	vel.y += C.GRAV * dt
	var prev := position
	position += vel * dt
	queue_redraw()
	return prev


func _draw() -> void:
	var u := vel.normalized()
	var n := Vector2(-u.y, u.x)
	draw_line(-u * 10.0, u * 4.0, Vec.WHITE, 3.0, true)
	draw_line(-u * 10.0 - n * 4.0, -u * 10.0 + n * 4.0, Vec.GREEN, 2.0, true)
	if t < 0.7:
		draw_line(-u * 10.0, -u * (18.0 + randf() * 10.0), Vec.AMBER, 2.0, true)
