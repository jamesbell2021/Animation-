class_name Civilian
extends Node2D
## A small figure running for the shelter. Hides behind rubble when the machines cry out.

signal reached_shelter(civ: Civilian)

var speed := randf_range(55.0, 95.0)
var h := randf_range(15.0, 21.0)
var alive := true
var state := "run"
var cover_x := NAN
var panic := 0.0
var child := randf() < 0.2
var scream_t := randf_range(1.0, 4.0)
var hide_t := 0.0
var t := randf() * 10.0


func update(dt: float, danger: bool, covers: Array) -> void:
	t += dt
	scream_t -= dt
	panic = minf(1.0, panic + dt * 2.0) if danger else maxf(0.0, panic - dt)
	if scream_t < 0.0 and panic > 0.5:
		scream_t = randf_range(1.5, 4.0)
		Sfx.play("scream", randf_range(0.85, 1.2))
	match state:
		"run":
			position.x -= speed * (1.0 + panic * 0.6) * dt
			if danger and is_nan(cover_x):
				for cx in covers:
					if absf(cx - position.x) < 110.0 and cx <= position.x + 20.0 and randf() < 0.9:
						cover_x = cx
						state = "tocover"
						break
			if position.x < C.SHELTER_X:
				alive = false
				reached_shelter.emit(self)
		"tocover":
			var target := cover_x - 6.0
			position.x += signf(target - position.x) * speed * 1.5 * dt
			if absf(target - position.x) < 4.0:
				state = "hide"
				hide_t = 0.0
		"hide":
			hide_t += dt
			if not danger and hide_t > 1.2:
				state = "run"
				cover_x = NAN
	queue_redraw()


func _draw() -> void:
	var col := Vec.GREEN
	var g := C.GROUND - position.y
	if state == "hide":
		Vec.circle(self, Vector2(0, g - h * 0.45), h * 0.17, col, 1.4)
		Vec.poly(self, PackedVector2Array([Vector2(0, g - h * 0.3), Vector2(4, g - h * 0.1), Vector2(2, g)]), col, 1.4)
		return
	var run := sin(t * 22.0 * (1.0 + panic * 0.3))
	var bob := absf(cos(t * 22.0)) * 2.0
	var hy := g - h * 0.45 - bob
	var hdy := g - h - bob
	Vec.circle(self, Vector2(0, hdy), h * 0.17, col, 1.4)
	Vec.line(self, Vector2(0, hdy + h * 0.17), Vector2(0, hy), col, 1.6)
	Vec.poly(self, PackedVector2Array([Vector2(0, hy), Vector2(-4 - run * 4, hy + h * 0.25), Vector2(-6 - run * 6, g - (0.0 if run > 0 else 3.0))]), col, 1.4)
	Vec.poly(self, PackedVector2Array([Vector2(0, hy), Vector2(4 + run * 4, hy + h * 0.25), Vector2(6 + run * 6, g - (0.0 if run < 0 else 3.0))]), col, 1.4)
	var ay := hdy + h * 0.3
	Vec.poly(self, PackedVector2Array([Vector2(0, ay), Vector2(-4 + run * 5, ay + 4), Vector2(-6 + run * 5, ay + 1)]), col, 1.3)
	Vec.poly(self, PackedVector2Array([Vector2(0, ay), Vector2(4 - run * 5, ay + 4), Vector2(6 - run * 5, ay + 1)]), col, 1.3)
	if child:
		Vec.circle(self, Vector2(6, hdy + h * 0.5), 2.5, col, 1.2)
		Vec.line(self, Vector2(6, hdy + h * 0.5 + 2.5), Vector2(6, hy + 2), col, 1.2)
