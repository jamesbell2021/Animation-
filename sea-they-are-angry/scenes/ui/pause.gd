extends CanvasLayer
## Pause menu: Esc or Start. Freezes the game tree; this layer keeps running.

var _panel: Control
var _resume: Button

func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.visible = false
	add_child(_panel)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.03, 0.05, 0.6)
	_panel.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)
	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1.0, 0.78, 0.42))
	box.add_child(title)
	_resume = _button(box, "Resume", toggle)
	_button(box, "Quit to Title", _quit_to_title)
	var note := Label.new()
	note.text = "Quitting returns you to the start of this day."
	note.add_theme_font_size_override("font_size", 16)
	note.add_theme_color_override("font_color", Color(0.75, 0.8, 0.85))
	box.add_child(note)

func _button(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.add_theme_font_size_override("font_size", 28)
	b.add_theme_color_override("font_focus_color", Color(1.0, 0.78, 0.42))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.78, 0.42))
	b.pressed.connect(func() -> void:
		Audio.sfx("ui_accept", Vector3.INF, -2.0, 0.0)
		cb.call())
	parent.add_child(b)
	return b

func _unhandled_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("pause") and Run.active:
		toggle()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	var paused := not get_tree().paused
	get_tree().paused = paused
	_panel.visible = paused
	if paused:
		_resume.grab_focus()

func _quit_to_title() -> void:
	get_tree().paused = false
	Run.active = false
	Cycle.stop()
	get_tree().reload_current_scene()
