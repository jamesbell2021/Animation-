extends CanvasLayer
## The end of Chapter Two, and of the story: shown over the lit town at first light.
## Three short pages (what happened, what was said of it, what came after), then the
## credits and the way back to the title.

signal back_to_title

const GOLD := Color(1.0, 0.78, 0.42)
const PALE := Color(0.9, 0.92, 0.95)
const DIM := Color(0.72, 0.76, 0.8)
const PAGE_TIME := 9.0
const PAGES := [
	"At first light the fog went back out past the harbour mouth, and the kirk doors opened. They came down the wynds in ones and twos and stood on the quay, and looked at the lamps.",
	"Nobody in Kirkhaven would say what had come up the slips those nights. The harbour board's report records only that the lights failed on a Tuesday, and were restored by three keepers put ashore from the relief boat.",
	"That winter the Board gave up its plan to put the rock's lamp on a timer. In the spring the three of them went back out. The light is kept by hand still. Somebody has to.",
]

var nights := 0
var kills := 0
var sea := ""
var lamps := 0
var lamps_total := 0

var _box: VBoxContainer
var _body: Label
var _page := -1
var _t := 0.0
var _done := false
var _first: Button

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
	_box = VBoxContainer.new()
	_box.custom_minimum_size = Vector2(860, 0)
	_box.add_theme_constant_override("separation", 14)
	center.add_child(_box)
	var over := _label(_box, "Chapter Two", 30, DIM)
	Fonts.use_title(over)
	var title := _label(_box, "The Lights of Kirkhaven", 68, GOLD)
	Fonts.use_title(title)
	_body = _label(_box, "", 24, PALE)
	_body.custom_minimum_size = Vector2(860, 150)
	Fonts.use_serif(_body)
	create_tween().tween_property(shade, "color:a", 0.6, 3.0)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_next_page()

func _next_page() -> void:
	_page += 1
	_t = 0.0
	if _page >= PAGES.size():
		_finish()
		return
	var tw := create_tween()
	tw.tween_property(_body, "modulate:a", 0.0, 0.6 if _page > 0 else 0.0)
	tw.tween_callback(func() -> void: _body.text = PAGES[_page])
	tw.tween_property(_body, "modulate:a", 1.0, 1.2)

func _finish() -> void:
	if _done:
		return
	_done = true
	var tw := create_tween()
	tw.tween_property(_body, "modulate:a", 0.0, 0.6)
	tw.tween_callback(_closing)

func _closing() -> void:
	_body.text = "A light kept is a promise."
	_body.add_theme_color_override("font_color", GOLD)
	_body.custom_minimum_size = Vector2(860, 60)
	_body.modulate.a = 1.0
	_label(_box, "%d nights on the rock and %d in the town, on an %s. %d of them sent back to the sea in Kirkhaven; %d of its %d lamps burning at the end." % [
		Rescue.NIGHTS[Difficulty.level()], nights, sea.to_lower(), kills, lamps, lamps_total], 20, DIM)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	_box.add_child(gap)
	var the_end := _label(_box, "Sea They Are Angry", 34, PALE)
	Fonts.use_title(the_end)
	_label(_box, "Fonts: IM FELL English by Igino Marini (SIL OFL 1.1) · Special Elite by Astigmatic (Apache 2.0)\nSound and music synthesised in code. Thank you for keeping the light.", 16, DIM)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_child(row)
	_first = _button(row, "Back to the title", func() -> void: back_to_title.emit())
	_first.grab_focus()

func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	if _t >= PAGE_TIME:
		_next_page()

func _unhandled_input(event: InputEvent) -> void:
	if _done or _t < 1.0:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed):
		_next_page()

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
