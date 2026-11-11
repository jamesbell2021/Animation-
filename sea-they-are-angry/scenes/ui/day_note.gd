extends CanvasLayer
## A small note at the top of the screen by day on the story's rock: what today holds
## (RockDays' event) and who of the seven has asked for something. Two short lines at
## most, gone at dusk, and hidden with the HUD.

const PALE := Color(0.92, 0.94, 0.96)
const GOLD := Color(1.0, 0.8, 0.46)

var days: Node
var _panel: PanelContainer
var _today: Label
var _asked: Label

func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.offset_top = 10.0
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.08, 0.5)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	_panel.add_theme_stylebox_override("panel", sb)
	root.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	_panel.add_child(box)
	_today = _line(box, PALE)
	_asked = _line(box, GOLD)
	_panel.visible = false

func _line(parent: Node, c: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(520, 0)
	parent.add_child(l)
	return l

func _process(_delta: float) -> void:
	var hud: Node = days.main.hud if days != null and days.main != null else null
	var show: bool = days != null and Run.active and Cycle.phase == Cycle.Phase.DAY and hud != null and hud.visible and Settings.hud_mode < 2
	var t := ""
	var a := ""
	if show:
		if days.today_line != "" and not days.today_done:
			t = "Today: " + _short(days.today_line)
		a = days.request_line()
		if a != "":
			a = "Asked: " + a
	_today.text = t
	_today.visible = t != ""
	_asked.text = a
	_asked.visible = a != ""
	_panel.visible = show and (t != "" or a != "")

# The day's line, cut at its first colon or full stop to stay short.
static func _short(s: String) -> String:
	for mark in [": ", ". "]:
		var i := s.find(mark)
		if i > 0:
			return s.substr(0, i) + "."
	return s
