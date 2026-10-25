extends CanvasLayer
## 3BL_Indie credits screen, shared by every 3BL_Indie game (keep the copies identical).
## Open it from a menu:
##   const Credits := preload("res://studio/credits.gd")
##   Credits.open(self, "Game Title", ["Font: ...", ...], optional_title_font)
## It closes on Back, Esc or the cancel button and emits `closed`.

signal closed

const STUDIO := "3BL_Indie"
const TEAM := ["James", "Aaron", "Connor", "Bonnie"]
const BG := Color(0.02, 0.025, 0.04, 0.94)
const INK := Color(0.95, 0.93, 0.9)
const ACCENT := Color(1.0, 0.66, 0.22)
const DIM := Color(0.7, 0.72, 0.76)

var game_title := ""
var extra: Array = []
var title_font: Font
var _back: Button

static func open(parent: Node, title: String, extra_lines: Array = [], font: Font = null) -> CanvasLayer:
	var c: CanvasLayer = load("res://studio/credits.gd").new()
	c.game_title = title
	c.extra = extra_lines
	c.title_font = font
	parent.add_child(c)
	return c

func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	center.add_child(col)
	var t := _line(col, game_title, 58, ACCENT)
	if title_font:
		t.add_theme_font_override("font", title_font)
	_line(col, "A %s game" % STUDIO, 26, INK)
	_gap(col, 22)
	_line(col, "Made by", 22, DIM)
	for name in TEAM:
		var n := _line(col, name, 40, INK)
		if title_font:
			n.add_theme_font_override("font", title_font)
	_gap(col, 22)
	for e in extra:
		_line(col, String(e), 18, DIM)
	_line(col, "Made with Godot Engine (godotengine.org/license)", 18, DIM)
	_gap(col, 18)
	_back = Button.new()
	_back.text = "Back"
	_back.custom_minimum_size = Vector2(220, 56)
	_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back.add_theme_font_size_override("font_size", 26)
	if title_font:
		_back.add_theme_font_override("font", title_font)
	_back.pressed.connect(close)
	col.add_child(_back)
	_back.grab_focus.call_deferred()

func _line(parent: Node, text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(minf(900.0, get_viewport().get_visible_rect().size.x - 48.0), 0)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 4)
	parent.add_child(l)
	return l

func _gap(parent: Node, h: int) -> void:
	var g := Control.new()
	g.custom_minimum_size = Vector2(0, h)
	parent.add_child(g)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		close()

func close() -> void:
	closed.emit()
	queue_free()
