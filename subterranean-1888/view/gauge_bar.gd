class_name GaugeBar
extends Control
## A bar with an optional "ghost" segment (what the hovered action would spend, drawn red
## at the end of the fill) and a tick (the Overwatch threshold). The GDD's classic green/red
## TU bar, also used for HP and boiler pressure.

var value := 0.0
var max_value := 1.0
var ghost := 0.0
var tick := -1.0
var fill := Kit.TU_GREEN
var ghost_colour := Kit.TU_RED
var text := ""
var font_size := 15


func _init() -> void:
	custom_minimum_size = Vector2(120, 18)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_values(v: float, m: float, g := 0.0, t := -1.0, label := "") -> void:
	value = v
	max_value = maxf(1.0, m)
	ghost = g
	tick = t
	text = label
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0.04, 0.035, 0.03, 0.95))
	var w := size.x - 2.0
	var vk := clampf(value / max_value, 0.0, 1.0)
	var fill_rect := Rect2(1, 1, w * vk, size.y - 2.0)
	draw_rect(fill_rect, fill)
	if ghost > 0.0:
		var gk := clampf(ghost / max_value, 0.0, vk)
		var over := ghost > value
		draw_rect(Rect2(1 + w * (vk - gk), 1, w * gk, size.y - 2.0), ghost_colour if not over else Color(1, 0.1, 0.1))
	if tick >= 0.0:
		var x := 1 + w * clampf(tick / max_value, 0.0, 1.0)
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(1, 0.9, 0.55), 2.0)
	draw_rect(r, Kit.PANEL_EDGE, false, 1.0)
	if text != "":
		var f := Kit.body_font()
		var ts := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var pos := Vector2((size.x - ts.x) * 0.5, (size.y + ts.y) * 0.5 - 3.0)
		draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0, 0, 0, 0.9))
		draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Kit.INK)
