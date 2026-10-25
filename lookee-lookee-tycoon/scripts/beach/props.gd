class_name BeachProp
extends Node2D
## Static scenery that lives in the y-sorted world so people walk in front of and behind it:
## palm trees, lamp posts, beach umbrellas, towels, lifeguard tower, bins, signs.
## Origin is the point touching the ground. Each prop draws once.

var kind := "palm"
var color := Color("#e53935")
var color2 := Color.WHITE
var flip := false


static func make(k: String, pos: Vector2, c := Color("#e53935"), c2 := Color.WHITE) -> BeachProp:
	var p := BeachProp.new()
	p.kind = k
	p.position = pos
	p.color = c
	p.color2 = c2
	return p


func _ready() -> void:
	if kind in ["towel"]:
		z_index = -5   # towels lie under everyone


func _draw() -> void:
	var ink := Color(0.17, 0.11, 0.09)
	match kind:
		"palm":
			var s := -1.0 if flip else 1.0
			draw_colored_polygon(VendorAvatar._ellipse(Vector2.ZERO, 26, 7), Color(0, 0, 0, 0.18))
			var trunk := PackedVector2Array()
			for i in 9:
				var f := i / 8.0
				trunk.append(Vector2(s * sin(f * 1.6) * 30.0, -f * 210.0))
			draw_polyline(trunk, ink, 17.0)
			draw_polyline(trunk, Color("#9c6b3c"), 13.0)
			for i in 8:
				var p := trunk[i]
				draw_line(p + Vector2(-6, 0), p + Vector2(6, -3), Color("#7a512b"), 2.0)
			var top := trunk[8]
			for k in 7:
				var a := -PI * 0.5 + (k - 3) * 0.5
				var tip := top + Vector2(cos(a) * 85.0, sin(a) * 34.0 + 40.0)
				var mid := top + Vector2(cos(a) * 45.0, sin(a) * 30.0 - 6.0)
				var leaf := PackedVector2Array([top, mid + Vector2(0, -8), tip, mid + Vector2(0, 8)])
				draw_colored_polygon(leaf, Color("#2e7d32").lightened(0.1 * (k % 3)))
				draw_polyline(PackedVector2Array([top, mid, tip]), Color("#1b5e20"), 2.0)
			for k in 3:
				draw_circle(top + Vector2(k * 8 - 8, 8), 6.0, Color("#6d4c41"))
		"lamp":
			draw_colored_polygon(VendorAvatar._ellipse(Vector2.ZERO, 12, 4), Color(0, 0, 0, 0.18))
			draw_line(Vector2(0, 0), Vector2(0, -150), ink, 7.0)
			draw_line(Vector2(0, 0), Vector2(0, -150), Color("#37474f"), 4.0)
			draw_line(Vector2(0, -150), Vector2(22, -160), Color("#37474f"), 4.0)
			draw_circle(Vector2(26, -156), 9.0, ink)
			draw_circle(Vector2(26, -156), 7.0, Color("#fff59d"))
		"bench":
			draw_rect(Rect2(-40, -26, 80, 8), Color("#8d6e63"))
			draw_rect(Rect2(-40, -14, 80, 8), Color("#8d6e63"))
			draw_rect(Rect2(-36, -6, 6, 6), Color("#37474f"))
			draw_rect(Rect2(30, -6, 6, 6), Color("#37474f"))
		"umbrella":
			draw_colored_polygon(VendorAvatar._ellipse(Vector2(0, 0), 40, 12), Color(0, 0, 0, 0.15))
			draw_line(Vector2(0, 0), Vector2(-6, -110), ink, 5.0)
			draw_line(Vector2(0, 0), Vector2(-6, -110), Color.WHITE, 3.0)
			var canopy := VendorAvatar._ellipse(Vector2(-6, -110), 62, 24, 16, PI, TAU)
			canopy.append(Vector2(56, -104))
			canopy.append(Vector2(-68, -104))
			draw_colored_polygon(canopy, color)
			for k in 4:
				var a := PI + PI * (k * 2 + 1) / 8.0
				var seg := PackedVector2Array([Vector2(-6, -134), Vector2(-6, -110) + Vector2(cos(a), sin(a) * 0.4) * 62.0, Vector2(-6, -110) + Vector2(cos(a + PI / 8), sin(a + PI / 8) * 0.4) * 62.0])
				draw_colored_polygon(seg, color2)
			draw_polyline(canopy + PackedVector2Array([canopy[0]]), ink, 2.0)
		"towel":
			var pts := PackedVector2Array([Vector2(-50, -14), Vector2(50, -14), Vector2(56, 10), Vector2(-56, 10)])
			draw_colored_polygon(pts, color)
			for k in 3:
				var x := -40.0 + k * 40.0
				draw_colored_polygon(PackedVector2Array([Vector2(x, -14), Vector2(x + 14, -14), Vector2(x + 16, 10), Vector2(x + 2, 10)]), color2)
			draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0, 0, 0, 0.25), 2.0)
		"lifeguard":
			draw_colored_polygon(VendorAvatar._ellipse(Vector2.ZERO, 40, 10), Color(0, 0, 0, 0.18))
			for x: float in [-26, 26]:
				draw_line(Vector2(x, 0), Vector2(x * 0.6, -110), ink, 6.0)
			draw_rect(Rect2(-34, -150, 68, 42), Color("#e53935"))
			draw_rect(Rect2(-34, -150, 68, 42), ink, false, 3.0)
			draw_rect(Rect2(-40, -158, 80, 10), Color.WHITE)
			draw_line(Vector2(-18, -60), Vector2(18, -60), ink, 4.0)
			draw_line(Vector2(-14, -30), Vector2(14, -30), ink, 4.0)
		"bin":
			draw_rect(Rect2(-12, -36, 24, 36), Color("#43a047"))
			draw_rect(Rect2(-14, -40, 28, 6), Color("#2e7d32"))
		"sign":
			draw_line(Vector2(0, 0), Vector2(0, -80), ink, 6.0)
			draw_rect(Rect2(-56, -122, 112, 48), Color("#fff8e1"))
			draw_rect(Rect2(-56, -122, 112, 48), ink, false, 3.0)
			var f := UITheme.bold_font()
			draw_string(f, Vector2(-50, -103), "NO", HORIZONTAL_ALIGNMENT_CENTER, 100, 16, Color("#c62828"))
			draw_string(f, Vector2(-50, -84), "VENDING!", HORIZONTAL_ALIGNMENT_CENTER, 100, 16, Color("#c62828"))
