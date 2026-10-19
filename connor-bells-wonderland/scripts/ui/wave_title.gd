class_name WaveTitle
extends Control
## Neon sign title: letters bob in a wave to the beat, glow, and the odd letter
## flickers like a dodgy fairground bulb.

@export var text: String = ""
@export var font_size: int = 64
@export var glow_colour: Color = Color(1.0, 0.42, 0.0)
@export var core_colour: Color = Color(1.0, 0.92, 0.75)
@export var bpm: float = 142.0

var _time: float = 0.0
var _flicker_index: int = -1
var _flicker_left: float = 0.0


func _process(delta: float) -> void:
	_time += delta
	if _flicker_left > 0.0:
		_flicker_left -= delta
	elif randf() < delta * 0.5 and not text.is_empty():
		_flicker_index = randi() % text.length()
		_flicker_left = randf_range(0.15, 0.5)
	queue_redraw()


func _draw() -> void:
	if text.is_empty():
		return
	var font: Font = GameFonts.title()
	if font == null:
		font = ThemeDB.fallback_font
	var fs := font_size
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if width > size.x - 40.0 and width > 0.0:
		fs = int(float(fs) * (size.x - 40.0) / width)
		width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x := (size.x - width) * 0.5
	var base_y := size.y * 0.5 + float(fs) * 0.35
	var beat := _time * bpm / 60.0
	var pump := 1.0 - fmod(beat, 1.0)
	for i in range(text.length()):
		var ch := text[i]
		var adv := font.get_char_size(ch.unicode_at(0), fs).x
		var y := base_y - absf(sin(beat * PI * 0.5 + float(i) * 0.35)) * float(fs) * 0.11
		var pos := Vector2(x, y)
		var lit := not (i == _flicker_index and _flicker_left > 0.0 and fmod(_time * 20.0, 1.0) < 0.6)
		if ch != " ":
			var glow := glow_colour
			glow.a = (0.25 + 0.2 * pump) if lit else 0.08
			draw_char_outline(font, pos, ch, fs, int(float(fs) * 0.32), glow)
			draw_char_outline(font, pos, ch, fs, int(float(fs) * 0.14), Color(0.0, 0.0, 0.0, 0.9))
			var core := core_colour if lit else core_colour.darkened(0.7)
			draw_char(font, pos, ch, fs, core.lerp(glow_colour, 0.35 * (1.0 - pump)) if lit else core)
		x += adv
