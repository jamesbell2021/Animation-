class_name ItemArt
extends RefCounted
## Little held items and icons: pints, cocktails, mops, wrenches, the lifebuoy, suitcases,
## the thief's swag bag. Chunky shapes with a dark outline so they read at 16 px.

const INK := Color(0.17, 0.11, 0.09)


static func draw_item(ci: CanvasItem, id: String, c: Vector2, size: float) -> void:
	var s := size / 20.0
	var w := maxf(1.2, 1.4 * s)
	match id:
		"pint":
			_poly(ci, [c + Vector2(-5, -8) * s, c + Vector2(5, -8) * s, c + Vector2(4, 8) * s, c + Vector2(-4, 8) * s], Color("#f5a623"), w)
			_poly(ci, [c + Vector2(-5.5, -10) * s, c + Vector2(5.5, -10) * s, c + Vector2(5, -6) * s, c + Vector2(-5, -6) * s], Color("#fffaf0"), w)
		"cocktail":
			_poly(ci, [c + Vector2(-7, -6) * s, c + Vector2(7, -6) * s, c + Vector2(0, 2) * s], Color("#ff4fa3"), w)
			ci.draw_line(c + Vector2(0, 2) * s, c + Vector2(0, 8) * s, INK, w)
			ci.draw_line(c + Vector2(-4, 8) * s, c + Vector2(4, 8) * s, INK, w)
			ci.draw_circle(c + Vector2(5, -8) * s, 2.0 * s, Color("#7cc242"))
		"wine":
			_poly(ci, _ellipse(c + Vector2(0, -3) * s, 5.0 * s, 5.0 * s, 12, 0.0, PI), Color("#c2185b"), w)
			ci.draw_line(c + Vector2(0, 2) * s, c + Vector2(0, 8) * s, INK, w)
			ci.draw_line(c + Vector2(-4, 8) * s, c + Vector2(4, 8) * s, INK, w)
		"mop":
			ci.draw_line(c + Vector2(4, -10) * s, c + Vector2(-3, 7) * s, Color("#8d6e63"), 2.4 * s)
			_poly(ci, [c + Vector2(-8, 6) * s, c + Vector2(2, 6) * s, c + Vector2(4, 11) * s, c + Vector2(-10, 11) * s], Color("#e0e0e0"), w)
		"wrench":
			ci.draw_line(c + Vector2(-6, 7) * s, c + Vector2(5, -4) * s, Color("#90a4ae"), 3.4 * s)
			ci.draw_arc(c + Vector2(6, -5) * s, 3.5 * s, 0.6, 5.2, 10, Color("#90a4ae"), 2.6 * s)
		"lifebuoy":
			ci.draw_arc(c, 7.5 * s, 0, TAU, 20, INK, 5.8 * s)
			for k in 4:
				var a0 := TAU * k / 4.0
				ci.draw_arc(c, 7.5 * s, a0, a0 + TAU / 8.0, 6, Color("#e53935"), 4.2 * s)
				ci.draw_arc(c, 7.5 * s, a0 + TAU / 8.0, a0 + TAU / 4.0, 6, Color.WHITE, 4.2 * s)
		"suitcase":
			_poly(ci, [c + Vector2(-8, -5) * s, c + Vector2(8, -5) * s, c + Vector2(8, 7) * s, c + Vector2(-8, 7) * s], Color("#3949ab"), w)
			ci.draw_arc(c + Vector2(0, -6) * s, 3.0 * s, PI, TAU, 8, INK, 1.6 * s)
		"swag":
			_poly(ci, _ellipse(c + Vector2(0, 2) * s, 7.0 * s, 6.5 * s, 14), Color("#a1887f"), w)
			ci.draw_line(c + Vector2(-3, -4) * s, c + Vector2(3, -4) * s, INK, 1.8 * s)
			ci.draw_string(UITheme.bold_font(), c + Vector2(-3, 5) * s, "$", HORIZONTAL_ALIGNMENT_LEFT, -1, int(8 * s), INK)
		"towel":
			_poly(ci, [c + Vector2(-8, -6) * s, c + Vector2(8, -6) * s, c + Vector2(8, 6) * s, c + Vector2(-8, 6) * s], Color("#ff7043"), w)
			ci.draw_line(c + Vector2(-8, -1) * s, c + Vector2(8, -1) * s, Color.WHITE, 2.0 * s)
		"clipboard":
			_poly(ci, [c + Vector2(-6, -8) * s, c + Vector2(6, -8) * s, c + Vector2(6, 8) * s, c + Vector2(-6, 8) * s], Color("#a1887f"), w)
			ci.draw_rect(Rect2(c + Vector2(-4, -5) * s, Vector2(8, 11) * s), Color.WHITE)
			for k in 3:
				ci.draw_line(c + Vector2(-3, -2 + k * 3) * s, c + Vector2(3, -2 + k * 3) * s, INK, 0.8 * s)
		"speaker":
			_poly(ci, [c + Vector2(-7, -8) * s, c + Vector2(7, -8) * s, c + Vector2(7, 8) * s, c + Vector2(-7, 8) * s], Color("#263238"), w)
			ci.draw_circle(c + Vector2(0, 2) * s, 3.6 * s, Color("#00e5ff"))
			ci.draw_circle(c + Vector2(0, -5) * s, 1.6 * s, Color("#00e5ff"))
		_:
			_poly(ci, _ellipse(c, 7.0 * s, 7.0 * s, 12), Color.WHITE, w)


static func _poly(ci: CanvasItem, pts, col: Color, w: float) -> void:
	var p := PackedVector2Array(pts)
	ci.draw_colored_polygon(p, col)
	var closed := p.duplicate()
	closed.append(p[0])
	ci.draw_polyline(closed, INK, w, true)


static func _ellipse(c: Vector2, rx: float, ry: float, n := 14, a0 := 0.0, a1 := TAU) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var full := is_equal_approx(a1 - a0, TAU)
	var count := n if full else n + 1
	for i in count:
		var a := a0 + (a1 - a0) * float(i) / float(n)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts
