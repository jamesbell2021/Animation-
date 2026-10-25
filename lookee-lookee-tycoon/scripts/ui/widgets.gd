class_name Widgets
extends RefCounted
## Small custom controls shared by the menus: a Control that shows a VendorAvatar, an item
## icon, vector HUD icons and the big round SHOUT button.


## Shows a live VendorAvatar inside a Control (menus, creator preview, staff list).
class AvatarView extends Control:
	var avatar: VendorAvatar
	var zoom := 1.0
	var follow_player := false
	var look: Dictionary = {}

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = false
		avatar = VendorAvatar.new()
		avatar.follow_character_data = follow_player
		add_child(avatar)
		if not follow_player and not look.is_empty():
			avatar.set_appearance(look)
		resized.connect(_layout)
		_layout()

	func set_look(a: Dictionary) -> void:
		look = a
		if avatar:
			avatar.set_appearance(a)

	func _layout() -> void:
		if avatar == null:
			return
		var z := zoom
		if z <= 0.0:
			z = size.y / 150.0
		avatar.scale = Vector2(z, z)
		avatar.position = Vector2(size.x * 0.5, size.y - 10.0 * z)


## Draws one junk item.
class ItemIcon extends Control:
	var item_id := ""

	func _init(id := "", px := 48.0) -> void:
		item_id = id
		custom_minimum_size = Vector2(px, px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_circle(size * 0.5, minf(size.x, size.y) * 0.48, Color(1, 1, 1, 0.7))
		ItemArt.draw_item(self, item_id, size * 0.5, minf(size.x, size.y) * 0.8)


## Vector icons for the HUD: coin, box, police light, clock, star.
class Icon extends Control:
	var kind := "coin"
	var color := Color.WHITE

	func _init(k := "coin", px := 36.0) -> void:
		kind = k
		custom_minimum_size = Vector2(px, px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.45
		var ink := UITheme.INK
		match kind:
			"coin":
				draw_circle(c, r, ink)
				draw_circle(c, r - 2.5, Color("#ffc928"))
				draw_circle(c, r - 7.0, Color("#ffdf6b"))
				draw_string(UITheme.bold_font(), c + Vector2(-r * 0.4, r * 0.4), "€", HORIZONTAL_ALIGNMENT_LEFT, -1, int(r * 1.2), Color("#a86f00"))
			"box":
				var rect := Rect2(c - Vector2(r, r * 0.8), Vector2(r * 2, r * 1.7))
				draw_rect(rect, Color("#c8925a"))
				draw_rect(rect, ink, false, 2.5)
				draw_line(Vector2(c.x, rect.position.y), Vector2(c.x, rect.end.y), ink, 2.0)
				draw_rect(Rect2(c.x - 5, rect.position.y, 10, 8), Color("#f5e6c8"))
			"police":
				draw_rect(Rect2(c + Vector2(-r * 0.8, r * 0.2), Vector2(r * 1.6, r * 0.6)), ink)
				draw_circle(c + Vector2(0, r * 0.1), r * 0.7, ink)
				draw_circle(c + Vector2(0, r * 0.1), r * 0.55, color)
				draw_circle(c + Vector2(-r * 0.2, -r * 0.1), r * 0.15, Color(1, 1, 1, 0.7))
			"clock":
				draw_circle(c, r, ink)
				draw_circle(c, r - 2.5, Color("#fffaf0"))
				draw_line(c, c + Vector2(0, -r * 0.6), ink, 2.5)
				draw_line(c, c + Vector2(r * 0.45, 0), ink, 2.5)
			"star":
				var pts := VendorAvatar._star(c, r, r * 0.45)
				draw_colored_polygon(pts, color)
				pts.append(pts[0])
				draw_polyline(pts, ink, 2.0, true)
			"sun":
				for k in 8:
					var a := TAU * k / 8.0
					draw_line(c + Vector2.from_angle(a) * r * 0.7, c + Vector2.from_angle(a) * r, Color("#ffb300"), 3.0)
				draw_circle(c, r * 0.6, Color("#ffd23f"))


## Big round touch button with a cooldown sweep (SHOUT).
class RoundButton extends Button:
	var fill := UITheme.TERRACOTTA
	var caption := ""
	var sub := ""
	var cooldown := 0.0   # 0..1, drawn as a dark sweep
	var pulse := 0.0

	func _ready() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		for s: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			add_theme_stylebox_override(s, StyleBoxEmpty.new())

	func _process(delta: float) -> void:
		pulse += delta
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 4.0
		var press := 4.0 if button_pressed or is_pressed() else 0.0
		var wob := 1.0 + (sin(pulse * 4.0) * 0.02 if cooldown <= 0.0 else 0.0)
		draw_circle(c + Vector2(0, 6), r * wob, Color(0, 0, 0, 0.3))
		draw_circle(c + Vector2(0, press), r * wob, UITheme.INK)
		draw_circle(c + Vector2(0, press), (r - 4.0) * wob, fill)
		draw_circle(c + Vector2(-r * 0.25, -r * 0.3 + press), r * 0.35, Color(1, 1, 1, 0.18))
		if cooldown > 0.03:
			var pts := PackedVector2Array([c + Vector2(0, press)])
			var steps := 24
			for i in steps + 1:
				var a := -PI * 0.5 + TAU * cooldown * float(i) / steps
				pts.append(c + Vector2(0, press) + Vector2.from_angle(a) * (r - 4.0))
			if pts.size() >= 3:
				draw_colored_polygon(pts, Color(0, 0, 0, 0.35))
		var f := UITheme.bold_font()
		var fs := int(r * 0.34)
		draw_string_outline(f, Vector2(0, c.y - 2 + press), caption, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, 6, UITheme.INK)
		draw_string(f, Vector2(0, c.y - 2 + press), caption, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, Color.WHITE)
		if sub != "":
			var fs2 := int(r * 0.17)
			draw_multiline_string(f, Vector2(r * 0.3, c.y + fs2 + 4 + press), sub, HORIZONTAL_ALIGNMENT_CENTER, size.x - r * 0.6, fs2, -1, UITheme.LEMON)
