class_name Vec
## Vector drawing helpers and the stroke font. Every glyph lives on a 4 x 6 grid (x 0..4,
## y 0..6, y down); a glyph is strokes separated by '|', each stroke "xy" points joined by lines.

const GREEN := Color("3cff5a")
const DIM := Color("1d8a33")
const DIMMER := Color("135a22")
const RED := Color("ff3b3b")
const WHITE := Color("eaffea")
const AMBER := Color("ffd24a")

const SRC := {
	"A": "06 02 20 42 46|03 43", "B": "00 06|00 30 41 42 33 03|33 44 45 36 06", "C": "41 30 10 01 05 16 36 45",
	"D": "00 06|00 30 42 44 36 06", "E": "40 00 06 46|03 23", "F": "40 00 06|03 23", "G": "41 30 10 01 05 16 36 45 43 23",
	"H": "00 06|40 46|03 43", "I": "10 30|20 26|16 36", "J": "40 44 36 16 05", "K": "00 06|40 03 46", "L": "00 06 46",
	"M": "06 00 23 40 46", "N": "06 00 46 40", "O": "10 30 41 45 36 16 05 01 10", "P": "06 00 30 41 42 33 03",
	"Q": "10 30 41 45 36 16 05 01 10|24 46", "R": "06 00 30 41 42 33 03|23 46", "S": "41 30 10 01 02 13 33 44 45 36 16 05",
	"T": "00 40|20 26", "U": "00 05 16 36 45 40", "V": "00 26 40", "W": "00 06 23 46 40", "X": "00 46|40 06",
	"Y": "00 23 40|23 26", "Z": "00 40 06 46", "0": "10 30 41 45 36 16 05 01 10|05 41", "1": "02 20 26|16 36",
	"2": "01 10 30 41 42 06 46", "3": "00 40 23|23 33 44 45 36 16 05", "4": "30 04 44|30 36", "5": "40 00 03 33 44 45 36 16 05",
	"6": "41 30 10 01 05 16 36 45 44 33 13 04", "7": "00 40 16", "8": "10 30 41 42 33 13 02 01 10|13 04 05 16 36 45 44 33",
	"9": "05 16 36 45 41 30 10 01 02 13 33 42", "!": "20 24|25 26", "?": "01 10 30 41 42 23 24|25 26", ".": "25 26",
	",": "25 16", ":": "21 22|24 25", ";": "21 22|25 16", "-": "13 33", "+": "13 33|21 25", "'": "20 21", "\"": "10 11|30 31",
	"/": "40 06", "(": "30 11 15 36", ")": "10 31 35 16", "<": "40 03 46", ">": "00 43 06", "=": "02 42|04 44",
	"*": "21 25|02 44|04 42", "%": "00 11 02|40 06|34 45 36", "&": "46 02 11 20 31 22 05 16 36 44", "_": "06 46",
	"#": "10 16|30 36|02 42|04 44", " ": ""
}
static var _glyphs := {}


static func _glyph(ch: String) -> Array:
	if _glyphs.is_empty():
		for k in SRC:
			var strokes: Array = []
			if SRC[k] != "":
				for st in SRC[k].split("|"):
					var pts := PackedVector2Array()
					for p in st.strip_edges().split(" "):
						pts.append(Vector2(float(p[0]), float(p[1])))
					strokes.append(pts)
			_glyphs[k] = strokes
		_glyphs["?box"] = [PackedVector2Array([Vector2(0, 1), Vector2(4, 1), Vector2(4, 6), Vector2(0, 6), Vector2(0, 1)])]
	return _glyphs.get(ch, _glyphs["?box"])


static func text_width(s: String, size: float) -> float:
	var u := size / 6.0
	return s.length() * 6.0 * u - 2.0 * u


## Draws `s` with its top-left (or top-centre / top-right) at `pos`. `size` is the glyph height.
static func text(c: CanvasItem, s: String, pos: Vector2, size: float, align := "left", color := GREEN, width := 0.0) -> void:
	var u := size / 6.0
	s = s.to_upper()
	var x := pos.x
	var w := text_width(s, size)
	if align == "center":
		x -= w / 2.0
	elif align == "right":
		x -= w
	if width <= 0.0:
		width = maxf(1.3, size / 9.0)
	for ch in s:
		for stroke in _glyph(ch):
			var pts := PackedVector2Array()
			for p in stroke:
				pts.append(Vector2(x + p.x * u, pos.y + p.y * u))
			if pts.size() == 1:
				c.draw_circle(pts[0], width * 0.6, color)
			else:
				c.draw_polyline(pts, color, width, true)
		x += 6.0 * u


## Word-wraps `s` to at most `max_width` pixels at `size`.
static func wrap(s: String, size: float, max_width: float) -> PackedStringArray:
	var lines := PackedStringArray()
	var cur := ""
	for w in s.split(" ", false):
		var test := w if cur == "" else cur + " " + w
		if text_width(test, size) > max_width and cur != "":
			lines.append(cur)
			cur = w
		else:
			cur = test
	if cur != "":
		lines.append(cur)
	return lines


static func poly(c: CanvasItem, pts: PackedVector2Array, color := GREEN, width := 2.0, closed := false) -> void:
	if pts.size() < 2:
		return
	if closed:
		var p2 := PackedVector2Array(pts)
		p2.append(pts[0])
		c.draw_polyline(p2, color, width, true)
	else:
		c.draw_polyline(pts, color, width, true)


static func line(c: CanvasItem, a: Vector2, b: Vector2, color := GREEN, width := 2.0) -> void:
	c.draw_line(a, b, color, width, true)


static func circle(c: CanvasItem, center: Vector2, r: float, color := GREEN, width := 2.0) -> void:
	c.draw_arc(center, maxf(0.5, r), 0.0, TAU, 24, color, width, true)


static func dot(c: CanvasItem, center: Vector2, r: float, color := GREEN) -> void:
	c.draw_circle(center, r, color)


## Many polylines in local coords (y up) placed with their origin at `origin` on screen.
static func lines(c: CanvasItem, ls: Array, origin: Vector2, color := DIM, width := 1.5) -> void:
	for L in ls:
		var pts := PackedVector2Array()
		for p in L:
			pts.append(Vector2(origin.x + p.x, origin.y - p.y))
		if pts.size() >= 2:
			c.draw_polyline(pts, color, width, true)


static func faded(col: Color, a: float) -> Color:
	return Color(col.r, col.g, col.b, col.a * a)
