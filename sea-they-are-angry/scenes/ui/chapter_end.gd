extends CanvasLayer
## The end of Chapter One: the keepers taken off by the relief boat. A card over the
## sea as the Mary Ann steams away: what they held out through, and what's waiting in the
## next chapter. Back to the title, or stay on the rock for endless nights.

signal back_to_title
signal stay_on

const GOLD := Color(1.0, 0.78, 0.42)
const PALE := Color(0.9, 0.92, 0.95)
const DIM := Color(0.72, 0.76, 0.8)

var nights := 0
var kills := 0
var sea := ""
## On a LAN client the host decides: the buttons say so.
var host_decides := false

func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.04, 0.0)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(820, 0)
	box.add_theme_constant_override("separation", 14)
	box.modulate.a = 0.0
	center.add_child(box)
	var over := _label(box, "Chapter One", 30, DIM)
	Fonts.use_title(over)
	var title := _label(box, "The Light Held", 72, GOLD)
	Fonts.use_title(title)
	var body := _label(box, ("%d nights on the rock, on an %s. The relief boat took the keepers off at dawn, the internees' diary " +
		"buttoned inside Callum's coat. Behind them the lamp still turned, with nobody to tend it.") % [nights, sea.to_lower()], 22, PALE)
	Fonts.use_serif(body)
	_label(box, "%d of them sent back to the sea." % kills, 20, DIM)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 18)
	box.add_child(gap)
	var next := _label(box, "Next: Chapter Two — The Harbour", 30, GOLD)
	Fonts.use_title(next)
	var tease := _label(box, "Halfway to Kirkhaven the skipper came down from the wheelhouse. The harbour lights had gone out " +
		"three nights since, he said, and nobody had answered the wireless from the town since Tuesday. " +
		"The sea was angry there too.", 20, PALE)
	Fonts.use_serif(tease)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	box.add_child(row)
	var first: Button
	if host_decides:
		_label(box, "The host decides what's next.", 18, DIM)
	else:
		first = _button(row, "Back to the title", func() -> void: back_to_title.emit())
		_button(row, "Stay on the rock (endless nights)", func() -> void: stay_on.emit())
	var tw := create_tween()
	tw.tween_property(shade, "color:a", 0.72, 2.5)
	tw.parallel().tween_property(box, "modulate:a", 1.0, 3.0).set_delay(1.0)
	if first != null:
		tw.tween_callback(first.grab_focus)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _label(parent: Node, text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 5)
	parent.add_child(l)
	return l

func _button(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.add_theme_font_size_override("font_size", 28)
	Fonts.use_title(b)
	b.add_theme_color_override("font_color", PALE)
	b.add_theme_color_override("font_focus_color", GOLD)
	b.add_theme_color_override("font_hover_color", GOLD)
	b.pressed.connect(func() -> void:
		Audio.sfx("ui_accept", Vector3.INF, -2.0, 0.0)
		cb.call())
	parent.add_child(b)
	return b
