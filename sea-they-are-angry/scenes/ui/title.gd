extends CanvasLayer
## Start menu over the island at dusk. Keyboard, mouse and gamepad navigable.

signal start_requested(continue_save: bool, players: int)

const GOLD := Color(1.0, 0.78, 0.42)
const PALE := Color(0.9, 0.92, 0.95)

var _keepers := 1
var _keepers_btn: Button
var _device_label: Label
var _first: Button

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	# Darken the left side so the menu reads over the scene.
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.06, 0.62)
	shade.anchor_bottom = 1.0
	shade.offset_right = 640.0
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	var box := VBoxContainer.new()
	box.position = Vector2(90, 150)
	box.custom_minimum_size = Vector2(470, 0)
	box.add_theme_constant_override("separation", 14)
	root.add_child(box)
	var title := _label(box, "Sea They\nAre Angry", 80, GOLD)
	Fonts.use_title(title)
	title.add_theme_constant_override("line_spacing", -22)
	var sub := _label(box, "Keep the light burning.", 26, PALE)
	Fonts.use_serif(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 26)
	box.add_child(gap)
	var save := SaveSys.load_run()
	if not save.is_empty():
		_first = _button(box, "Continue  (night %d)" % int(save.get("night", 1)), _on_continue)
	var new_btn := _button(box, "New Run", _on_new)
	if _first == null:
		_first = new_btn
	_keepers_btn = _button(box, "", _cycle_keepers)
	_keepers_btn.gui_input.connect(_on_keepers_input)
	_button(box, "Quit", _on_quit)
	_device_label = _label(box, "", 16, Color(0.75, 0.8, 0.85))
	_device_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var best := SaveSys.load_best()
	if best > 0:
		_label(box, "Best: night %d" % best, 18, GOLD)
	var hint := _label(root, "WASD move · mouse aim · LMB swing · E use · R lamp · Q beam · Esc pause", 15, Color(0.8, 0.84, 0.9, 0.8))
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = 90.0
	hint.offset_top = -50.0
	_update_keepers()
	_first.grab_focus.call_deferred()

func _label(parent: Node, text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	parent.add_child(l)
	return l

func _button(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.flat = true
	b.add_theme_font_size_override("font_size", 34)
	Fonts.use_title(b)
	b.add_theme_color_override("font_color", PALE)
	b.add_theme_color_override("font_focus_color", GOLD)
	b.add_theme_color_override("font_hover_color", GOLD)
	b.focus_entered.connect(func() -> void: Audio.sfx("ui_move", Vector3.INF, -4.0, 0.0))
	b.pressed.connect(func() -> void:
		Audio.sfx("ui_accept", Vector3.INF, -2.0, 0.0)
		cb.call())
	parent.add_child(b)
	return b

func _cycle_keepers() -> void:
	_keepers = _keepers % Players.MAX + 1
	_update_keepers()

func _on_keepers_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("ui_left"):
		_keepers = maxi(1, _keepers - 1)
		_update_keepers()
		_keepers_btn.accept_event()
	elif ev.is_action_pressed("ui_right"):
		_keepers = mini(Players.MAX, _keepers + 1)
		_update_keepers()
		_keepers_btn.accept_event()

func _update_keepers() -> void:
	# Spelled out: IM Fell's old-style "1" reads as a capital I.
	_keepers_btn.text = "Keepers:  ◀ %s ▶" % ["One", "Two", "Three"][_keepers - 1]
	Players.configure(_keepers)
	var lines: Array[String] = []
	for i in _keepers:
		lines.append("P%d %s — %s" % [i + 1, Players.NAMES[i], Players.device_label(i)])
	_device_label.text = "\n".join(lines)

func _on_continue() -> void:
	start_requested.emit(true, _keepers)

func _on_new() -> void:
	SaveSys.clear_run()
	start_requested.emit(false, _keepers)

func _on_quit() -> void:
	get_tree().quit()
