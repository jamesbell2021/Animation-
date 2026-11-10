class_name WeaponBar
extends Control
## The weapons across the bottom of the screen, numbered for their keys (1 to 5): what
## the keeper carries, what's in hand (lit gold), and what each has left. One not to
## hand yet (made at the shed, or out of ammunition) is dim. Icons are drawn here.

const SLOT := 64.0
const GAP := 8.0
const GOLD := Color(1.0, 0.8, 0.46)
const PALE := Color(0.92, 0.94, 0.96)
const DIM := Color(0.68, 0.73, 0.78)
const FLAME := Color(1.0, 0.55, 0.2)

var player: Player
## Put away with the rest of the HUD (its "off").
var off := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var w := SLOT * Arsenal.ORDER.size() + GAP * (Arsenal.ORDER.size() - 1)
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -w * 0.5
	offset_right = w * 0.5
	offset_top = -16.0 - SLOT - 14.0
	offset_bottom = -16.0

func _process(_delta: float) -> void:
	visible = shown()
	if visible:
		queue_redraw()

func shown() -> bool:
	return not off and Run.active and player != null and is_instance_valid(player) and not player.ai \
		and player.arsenal != null and player.riding == null and not player.boarded

## What a slot says under its icon.
func ammo_text(w: String) -> String:
	var a := player.arsenal
	if Difficulty.free_ammo() and w != "hook":
		return "free" if a.available(w) else ""
	match w:
		"hook":
			return "" if player.has_hook else "thrown"
		"bow":
			return "%d" % Stock.get_amount("arrows") if a.carries("bow") else ""
		"shotgun":
			return "%d" % Stock.get_amount("shells") if a.carries("shotgun") else ""
		"flamer":
			return "%d%%" % roundi(Run.flamer_fuel) if a.carries("flamer") else ""
		"bombs":
			return "%d" % Stock.get_amount("bombs")
	return ""

func _draw() -> void:
	if not shown():
		return
	var font := get_theme_default_font()
	var a := player.arsenal
	for i in Arsenal.ORDER.size():
		var w: String = Arsenal.ORDER[i]
		var r := Rect2(Vector2(i * (SLOT + GAP), 0.0), Vector2(SLOT, SLOT))
		var held := a.weapon == w
		var have := a.available(w)
		var alpha := 1.0 if have else 0.35
		draw_rect(r, Color(0.03, 0.05, 0.08, 0.72 if held else 0.55))
		draw_rect(r, Color(GOLD.r, GOLD.g, GOLD.b, 0.95) if held else Color(1.0, 0.85, 0.6, 0.18), false, 2.0 if held else 1.0)
		var ink := (GOLD if held else PALE)
		ink.a = alpha
		_icon(w, r.get_center() + Vector2(0.0, -4.0), ink)
		if font != null:
			draw_string_outline(font, r.position + Vector2(5.0, 15.0), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 3, Color(0, 0, 0, 0.8))
			draw_string(font, r.position + Vector2(5.0, 15.0), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, GOLD if held else DIM)
			var t := ammo_text(w)
			if t != "":
				var c := ink
				if t == "0" or t == "0%" or t == "thrown":
					c = Color(1.0, 0.4, 0.35, alpha)
				draw_string_outline(font, Vector2(r.position.x, r.end.y - 5.0), t, HORIZONTAL_ALIGNMENT_CENTER, SLOT, 13, 3, Color(0, 0, 0, 0.8))
				draw_string(font, Vector2(r.position.x, r.end.y - 5.0), t, HORIZONTAL_ALIGNMENT_CENTER, SLOT, 13, c)

# Small line drawings of each, about 36 px across.
func _icon(w: String, c: Vector2, ink: Color) -> void:
	match w:
		"hook":
			# A long pole on the slant with a hook and spike at its head.
			draw_line(c + Vector2(-15, 15), c + Vector2(12, -12), ink, 3.0)
			draw_arc(c + Vector2(9, -9), 6.0, PI * 1.25, PI * 2.4, 10, ink, 2.5)
			draw_line(c + Vector2(12, -12), c + Vector2(17, -17), ink, 2.5)
		"bow":
			draw_arc(c + Vector2(-10, 0), 17.0, -PI * 0.42, PI * 0.42, 16, ink, 3.0)
			var top := c + Vector2(-10, 0) + Vector2.from_angle(-PI * 0.42) * 17.0
			var bot := c + Vector2(-10, 0) + Vector2.from_angle(PI * 0.42) * 17.0
			draw_line(top, bot, Color(ink.r, ink.g, ink.b, ink.a * 0.7), 1.0)
			draw_line(c + Vector2(-6, 0), c + Vector2(16, 0), ink, 2.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(19, 0), c + Vector2(13, -4), c + Vector2(13, 4)]), ink)
		"shotgun":
			draw_line(c + Vector2(-4, -3), c + Vector2(18, -3), ink, 3.0)
			draw_line(c + Vector2(-4, 0), c + Vector2(18, 0), ink, 2.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-4, -5), c + Vector2(-4, 3), c + Vector2(-18, 9), c + Vector2(-20, 3), c + Vector2(-10, -5)]), ink)
		"flamer":
			draw_rect(Rect2(c + Vector2(-17, -9), Vector2(10, 20)), ink, false, 2.5)
			draw_line(c + Vector2(-7, 6), c + Vector2(0, 6), ink, 2.0)
			draw_line(c + Vector2(0, 6), c + Vector2(8, -2), ink, 3.0)
			var f := FLAME
			f.a = ink.a
			draw_colored_polygon(PackedVector2Array([c + Vector2(9, -3), c + Vector2(19, -12), c + Vector2(16, -3), c + Vector2(20, 2), c + Vector2(11, 1)]), f)
		"bombs":
			draw_rect(Rect2(c + Vector2(-7, -2), Vector2(14, 17)), ink, false, 2.5)
			draw_line(c + Vector2(0, -2), c + Vector2(0, -9), ink, 4.0)
			var f2 := FLAME
			f2.a = ink.a
			draw_colored_polygon(PackedVector2Array([c + Vector2(-3, -10), c + Vector2(0, -19), c + Vector2(4, -11), c + Vector2(1, -8)]), f2)
