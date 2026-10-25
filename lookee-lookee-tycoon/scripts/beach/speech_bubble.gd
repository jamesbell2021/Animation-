class_name SpeechBubble
extends Node2D
## Cartoon speech bubble. Drawn above everything and counter-scaled against the camera zoom,
## so the text stays readable on a phone however far you zoom out.

const KINDS := {
	"normal": [Color("#fffaf0"), Color("#2b1d16")],
	"shout": [Color("#ffe14d"), Color("#2b1d16")],
	"sale": [Color("#b9f6a0"), Color("#1b3d12")],
	"police": [Color("#bcd7ff"), Color("#0d2350")],
	"bad": [Color("#ffb3a7"), Color("#5a1208")],
	"think": [Color("#ffffff"), Color("#555555")],
}
const FONT_SIZE := 20
const MAX_W := 250.0
const PAD := Vector2(12, 8)

var _text := ""
var _kind := "normal"
var _time := 0.0
var _age := 0.0
var _size := Vector2.ZERO
var _font: Font


func _ready() -> void:
	z_index = 60
	z_as_relative = false
	_font = UITheme.bold_font()
	visible = false


func show_text(text: String, kind := "normal", seconds := 2.2) -> void:
	_text = text
	_kind = kind if KINDS.has(kind) else "normal"
	_time = seconds
	_age = 0.0
	_size = _font.get_multiline_string_size(_text, HORIZONTAL_ALIGNMENT_CENTER, MAX_W, FONT_SIZE) + PAD * 2.0
	visible = true
	set_process(true)
	queue_redraw()


func hide_now() -> void:
	visible = false
	set_process(false)


func _process(delta: float) -> void:
	_age += delta
	if _age >= _time:
		hide_now()
		return
	# Pop in, float, fade out. Counter-scale against the camera so text size is constant.
	var cam_scale := get_viewport().get_canvas_transform().get_scale().x
	var pop := minf(_age / 0.12, 1.0)
	var s := (0.6 + 0.4 * pop) / maxf(cam_scale, 0.1)
	scale = Vector2(s, s)
	modulate.a = clampf((_time - _age) / 0.3, 0.0, 1.0)


func _draw() -> void:
	if _text == "":
		return
	var cols: Array = KINDS[_kind]
	var rect := Rect2(Vector2(-_size.x * 0.5, -_size.y - 12.0), _size)
	var sb := StyleBoxFlat.new()
	sb.bg_color = cols[0]
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(3)
	sb.border_color = cols[1]
	sb.anti_aliasing = true
	if _kind == "think":
		sb.set_corner_radius_all(int(minf(_size.y * 0.5, 22.0)))
	# Tail.
	var tail := PackedVector2Array([Vector2(-9, -14), Vector2(9, -14), Vector2(0, 0)])
	draw_colored_polygon(tail, cols[1])
	sb.draw(get_canvas_item(), rect)
	draw_colored_polygon(PackedVector2Array([Vector2(-6, -16), Vector2(6, -16), Vector2(0, -4)]), cols[0])
	draw_multiline_string(_font, rect.position + Vector2(PAD.x, PAD.y + _font.get_ascent(FONT_SIZE)), _text,
		HORIZONTAL_ALIGNMENT_CENTER, _size.x - PAD.x * 2.0, FONT_SIZE, -1, cols[1])
