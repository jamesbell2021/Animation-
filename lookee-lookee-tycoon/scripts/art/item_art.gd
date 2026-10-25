class_name ItemArt
extends RefCounted
## Draws the little junk icons (on stalls, in hands, in the shop). Every icon is a few chunky
## shapes with a dark outline so it reads at 16 px on a phone. Drop a PNG at
## res://art/items/<item_id>.png to replace any of them.

const INK := Color(0.17, 0.11, 0.09)

static var _tex_cache := {}


static func draw_item(ci: CanvasItem, id: String, c: Vector2, size: float) -> void:
	var path := "res://art/items/%s.png" % id
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path) if ResourceLoader.exists(path) else null
	var tex: Texture2D = _tex_cache[path]
	if tex:
		ci.draw_texture_rect(tex, Rect2(c - Vector2(size, size) * 0.5, Vector2(size, size)), false)
		return
	var item := ItemDB.get_item(id)
	var col: Color = item.get("color", Color.WHITE)
	var s := size / 20.0  # icons are designed on a 20 px grid
	var w := maxf(1.2, 1.4 * s)
	match str(item.get("art", "")):
		"magnet":
			_poly(ci, [c + Vector2(-8, -6) * s, c + Vector2(8, -6) * s, c + Vector2(8, 6) * s, c + Vector2(-8, 6) * s], col, w)
			ci.draw_circle(c + Vector2(-2, 0) * s, 2.2 * s, Color.WHITE)
			ci.draw_circle(c + Vector2(2, 0) * s, 2.2 * s, Color.WHITE)
		"sunglasses":
			for sx: float in [-1.0, 1.0]:
				_poly(ci, _ellipse(c + Vector2(sx * 4.5, 1) * s, 4.0 * s, 3.4 * s), col, w)
			ci.draw_line(c + Vector2(-1, 0) * s, c + Vector2(1, 0) * s, INK, w)
			ci.draw_line(c + Vector2(-8.5, -1) * s, c + Vector2(-10, -3) * s, INK, w)
		"bracelet":
			ci.draw_arc(c, 6.5 * s, 0, TAU, 18, INK, 4.2 * s, true)
			ci.draw_arc(c, 6.5 * s, 0, TAU, 18, col, 2.6 * s, true)
			for k in 6:
				ci.draw_circle(c + Vector2.from_angle(TAU * k / 6.0) * 6.5 * s, 1.4 * s, [Color("#e53935"), Color("#1e88e5"), Color("#43a047")][k % 3])
		"umbrella":
			_poly(ci, _ellipse(c + Vector2(0, -1) * s, 9.0 * s, 7.0 * s, 14, PI, TAU), col, w)
			ci.draw_line(c + Vector2(0, -1) * s, c + Vector2(0, 8) * s, INK, w)
			ci.draw_arc(c + Vector2(-1.5, 8) * s, 1.5 * s, 0, PI, 6, INK, w)
		"bunny_ears":
			ci.draw_arc(c + Vector2(0, 5) * s, 7.0 * s, PI, TAU, 12, INK, w * 1.6)
			for sx: float in [-1.0, 1.0]:
				_poly(ci, _ellipse(c + Vector2(sx * 4, -3) * s, 2.6 * s, 6.5 * s), col, w)
			ci.draw_circle(c + Vector2(-4, -3) * s, 1.0 * s, Color.WHITE)
		"selfie_stick":
			ci.draw_line(c + Vector2(-7, 8) * s, c + Vector2(4, -4) * s, INK, 2.6 * s)
			_poly(ci, [c + Vector2(2, -9) * s, c + Vector2(9, -6) * s, c + Vector2(6, 1) * s, c + Vector2(-1, -2) * s], col, w)
		"sun_hat":
			_poly(ci, _ellipse(c + Vector2(0, 3) * s, 10.0 * s, 3.5 * s), col, w)
			_poly(ci, _ellipse(c + Vector2(0, 1) * s, 5.0 * s, 6.0 * s, 12, PI, TAU), col, w)
			ci.draw_line(c + Vector2(-5, 0) * s, c + Vector2(5, 0) * s, Color("#e53935"), 1.6 * s)
		"flamingo":
			_poly(ci, _ellipse(c + Vector2(1, 4) * s, 8.0 * s, 4.5 * s), col, w)
			ci.draw_line(c + Vector2(-5, 2) * s, c + Vector2(-6, -6) * s, INK, 4.2 * s)
			ci.draw_line(c + Vector2(-5, 2) * s, c + Vector2(-6, -6) * s, col, 2.6 * s)
			_poly(ci, _ellipse(c + Vector2(-5, -7) * s, 2.6 * s, 2.4 * s), col, w)
			ci.draw_line(c + Vector2(-3, -7) * s, c + Vector2(0, -6) * s, INK, 1.8 * s)
		"fan":
			_poly(ci, _ellipse(c + Vector2(0, 5) * s, 9.0 * s, 10.0 * s, 10, PI + 0.3, TAU - 0.3) + PackedVector2Array([c + Vector2(0, 5) * s]), col, w)
			for k in 4:
				var a := PI + 0.5 + (PI - 1.0) * k / 3.0
				ci.draw_line(c + Vector2(0, 5) * s, c + (Vector2(0, 5) + Vector2.from_angle(a) * 9.0) * s, col.darkened(0.3), 1.0 * s)
		"watch":
			ci.draw_rect(Rect2(c + Vector2(-2.5, -9) * s, Vector2(5, 18) * s), Color("#cfd8dc"))
			_poly(ci, _ellipse(c, 5.0 * s, 5.0 * s), col, w)
			ci.draw_circle(c, 3.2 * s, Color.WHITE)
			ci.draw_line(c, c + Vector2(0, -2.5) * s, INK, 1.0 * s)
			ci.draw_line(c, c + Vector2(2, 0) * s, INK, 1.0 * s)
		"speaker":
			_poly(ci, [c + Vector2(-8, -5) * s, c + Vector2(8, -5) * s, c + Vector2(8, 5) * s, c + Vector2(-8, 5) * s], col, w)
			ci.draw_circle(c + Vector2(-4, 0) * s, 3.0 * s, INK)
			ci.draw_circle(c + Vector2(4, 0) * s, 3.0 * s, INK)
			ci.draw_circle(c + Vector2(-4, 0) * s, 1.2 * s, col.lightened(0.4))
			ci.draw_circle(c + Vector2(4, 0) * s, 1.2 * s, col.lightened(0.4))
		"henna":
			_poly(ci, [c + Vector2(-7, -8) * s, c + Vector2(7, -8) * s, c + Vector2(7, 8) * s, c + Vector2(-7, 8) * s], Color("#fff8e1"), w)
			var swirl := _ellipse(c, 4.0 * s, 4.0 * s, 10, 0.0, TAU * 0.8)
			ci.draw_polyline(swirl, col, 1.8 * s, true)
			ci.draw_circle(c, 1.2 * s, col)
		"unicorn":
			_poly(ci, _ellipse(c + Vector2(1, 3) * s, 8.5 * s, 5.0 * s), col, w)
			_poly(ci, _ellipse(c + Vector2(-6, -4) * s, 3.4 * s, 3.4 * s), col, w)
			_poly(ci, [c + Vector2(-7, -7) * s, c + Vector2(-5, -7) * s, c + Vector2(-8, -12) * s], Color("#ffd23f"), 1.0 * s)
			ci.draw_line(c + Vector2(0, -1) * s, c + Vector2(6, -1) * s, Color("#ff80ab"), 2.0 * s)
		"gold_chain":
			var pts := _ellipse(c + Vector2(0, -3) * s, 7.0 * s, 8.0 * s, 12, 0.2, PI - 0.2)
			ci.draw_polyline(pts, INK, 4.4 * s, true)
			ci.draw_polyline(pts, col, 2.8 * s, true)
			_poly(ci, _ellipse(c + Vector2(0, 6) * s, 3.0 * s, 3.0 * s), col, w)
		"drone":
			_poly(ci, [c + Vector2(-4, -2) * s, c + Vector2(4, -2) * s, c + Vector2(4, 3) * s, c + Vector2(-4, 3) * s], col, w)
			for sx: float in [-1.0, 1.0]:
				ci.draw_line(c + Vector2(sx * 3, 0) * s, c + Vector2(sx * 8, -4) * s, INK, 1.6 * s)
				ci.draw_line(c + Vector2(sx * 5, -5) * s, c + Vector2(sx * 11, -5) * s, Color("#90a4ae"), 2.0 * s)
			ci.draw_circle(c + Vector2(0, 0.5) * s, 1.4 * s, Color("#ff1744"))
		"handbag":
			ci.draw_arc(c + Vector2(0, -3) * s, 4.5 * s, PI, TAU, 10, INK, 1.8 * s)
			_poly(ci, [c + Vector2(-8, -3) * s, c + Vector2(8, -3) * s, c + Vector2(7, 8) * s, c + Vector2(-7, 8) * s], col, w)
			for p: Vector2 in [Vector2(-4, 1), Vector2(0, 4), Vector2(4, 1), Vector2(-3, 6), Vector2(3, 6)]:
				ci.draw_circle(c + p * s, 1.0 * s, Color("#ffd23f"))
		"light_shoes":
			_poly(ci, [c + Vector2(-8, -4) * s, c + Vector2(-2, -4) * s, c + Vector2(1, 0) * s, c + Vector2(9, 2) * s, c + Vector2(9, 5) * s, c + Vector2(-8, 5) * s], Color.WHITE, w)
			ci.draw_line(c + Vector2(-8, 4) * s, c + Vector2(9, 4) * s, col, 2.4 * s)
			ci.draw_circle(c + Vector2(-5, 4) * s, 1.0 * s, Color("#ff4081"))
		"yacht":
			_poly(ci, [c + Vector2(-10, 2) * s, c + Vector2(10, 2) * s, c + Vector2(6, 7) * s, c + Vector2(-7, 7) * s], col, w)
			_poly(ci, [c + Vector2(-4, -3) * s, c + Vector2(5, -3) * s, c + Vector2(6, 2) * s, c + Vector2(-5, 2) * s], Color("#b3e5fc"), w)
			ci.draw_line(c + Vector2(0, -3) * s, c + Vector2(0, -9) * s, INK, 1.4 * s)
		_:
			_poly(ci, _ellipse(c, 7.0 * s, 7.0 * s), col, w)


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
