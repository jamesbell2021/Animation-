extends CanvasLayer
## The end of the story: shown over the rock under a clear sky, after the keeper's last
## log pages. The line the story has been heading for, what was saved, the credits, and
## the way back to the title.

signal back_to_title

const GOLD := Color(1.0, 0.78, 0.42)
const PALE := Color(0.9, 0.92, 0.95)
const DIM := Color(0.72, 0.76, 0.8)
const COUNT := ["None", "One", "Two", "Three", "Four", "Five", "Six", "All seven"]

## Nights on the rock, creatures sent back there, the sea's mood, and how many of
## Kirkhaven's seven lived to see the sky clear.
var nights := 0
var kills := 0
var sea := ""
var saved := 0
## The run's dawn ratings (NightRating.total_line), and anything the finish unlocked.
var rating := ""
var unlocked := ""

func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.04, 0.0)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(860, 0)
	box.add_theme_constant_override("separation", 14)
	box.modulate.a = 0.0
	center.add_child(box)
	var title := _label(box, "Sea They Are Angry", 68, GOLD)
	Fonts.use_title(title)
	var line := _label(box, "A light kept is a promise.", 30, PALE)
	Fonts.use_serif(line)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 12)
	box.add_child(gap)
	var people := "%s of Kirkhaven's seven saw the sky clear." % COUNT[clampi(saved, 0, 7)]
	if saved == 0:
		people = "None of Kirkhaven's seven saw the sky clear. The keepers did."
	_label(box, people, 22, PALE)
	_label(box, "%d night%s on the rock, on an %s. %d of them sent back to the sea, and one that will not come again." % [nights, "" if nights == 1 else "s", sea.to_lower(), kills], 20, DIM)
	if rating != "":
		_label(box, rating, 20, GOLD)
	if unlocked != "":
		_label(box, unlocked, 18, GOLD)
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 10)
	box.add_child(gap2)
	_label(box, "Fonts: IM FELL English by Igino Marini (SIL OFL 1.1) · Special Elite by Astigmatic (Apache 2.0)\nMusic and most sounds synthesised in code · the sea, the gulls, the bells and other sounds are public-domain and CC0 recordings · \"The Skye Boat Song\" (traditional air)\nThank you for keeping the light.", 16, DIM)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	var first := _button(row, "Back to the title", func() -> void: back_to_title.emit())
	var tw := create_tween()
	tw.tween_property(shade, "color:a", 0.42, 3.0)
	tw.parallel().tween_property(box, "modulate:a", 1.0, 3.0).set_delay(0.8)
	tw.tween_callback(first.grab_focus)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# The credits' air: the Skye Boat Song (traditional).
	Audio.music("credits", 2.5)

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
