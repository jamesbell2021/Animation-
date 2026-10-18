extends Control
## Main menu: player identity, solo race settings, host or join a Wi-Fi game.
## All controls are built in code; attach to a Control root saved as main_menu.tscn.

const GAME_SCENE := "res://scenes/main/main.tscn"
const LOBBY_SCENE := "res://scenes/menus/lobby.tscn"
const COLOUR_NAMES: Array[String] = ["Red", "Orange", "Yellow", "Green", "Blue", "Purple", "Pink"]
const DIFFICULTY_NAMES: Array[String] = ["Easy", "Medium", "Hard"]

var _net: Node
var _name_edit: LineEdit
var _colour_option: OptionButton
var _sections_spin: SpinBox
var _bots_spin: SpinBox
var _difficulty_option: OptionButton
var _ip_edit: LineEdit
var _status: Label
var _buttons: Array[Button] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	get_tree().paused = false
	_net = get_node_or_null("/root/NetworkManager")
	if _net == null:
		push_error("MainMenu: NetworkManager autoload is missing (Project Settings > Autoload).")
	_build()
	if _net != null:
		_net.leave()
		_net.connection_failed.connect(_on_connection_failed)
		_net.connected_to_host.connect(_on_connected_to_host)
		_name_edit.text = _net.local_name
		_colour_option.selected = _nearest_colour_index(_net.local_colour)
		_sections_spin.value = int(_net.settings.get("sections", 6))
		_bots_spin.value = int(_net.settings.get("bots", 3))
		_difficulty_option.selected = clampi(int(_net.settings.get("difficulty", 1)), 0, 2)


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.3, 0.55, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	for i in range(7):
		var stripe := ColorRect.new()
		stripe.color = CourseBuilder.rainbow(i)
		stripe.anchor_right = 1.0
		stripe.offset_top = 10.0 + float(i) * 8.0
		stripe.offset_bottom = 18.0 + float(i) * 8.0
		add_child(stripe)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(620.0, 0.0)
	panel.add_child(box)

	var title := Label.new()
	title.text = Branding.title_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = Branding.SUBTITLE
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 22)
	box.add_child(subtitle)

	_name_edit = LineEdit.new()
	_name_edit.max_length = 14
	_name_edit.placeholder_text = "Your name"
	box.add_child(_row("Name", _name_edit))
	_colour_option = OptionButton.new()
	for i in range(COLOUR_NAMES.size()):
		_colour_option.add_item(COLOUR_NAMES[i], i)
	box.add_child(_row("Colour", _colour_option))
	_sections_spin = _spin(1, 6, 6)
	box.add_child(_row("Sections", _sections_spin))
	_bots_spin = _spin(0, 7, 3)
	box.add_child(_row("Bots", _bots_spin))
	_difficulty_option = OptionButton.new()
	for i in range(DIFFICULTY_NAMES.size()):
		_difficulty_option.add_item(DIFFICULTY_NAMES[i], i)
	_difficulty_option.selected = 1
	box.add_child(_row("Difficulty", _difficulty_option))

	box.add_child(_button("Play Solo", _on_play_solo))
	box.add_child(_button("Host Wi-Fi Game", _on_host))
	_ip_edit = LineEdit.new()
	_ip_edit.placeholder_text = "Host IP, e.g. 192.168.1.20"
	box.add_child(_row("Join IP", _ip_edit))
	box.add_child(_button("Join Wi-Fi Game", _on_join))
	box.add_child(_button("Quit", func() -> void: get_tree().quit()))

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	box.add_child(_status)


func _row(label_text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(150.0, 0.0)
	label.add_theme_font_size_override("font_size", 22)
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.custom_minimum_size = Vector2(0.0, 44.0)
	row.add_child(control)
	return row


func _spin(min_value: int, max_value: int, value: int) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.value = value
	spin.rounded = true
	return spin


func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 52.0)
	button.add_theme_font_size_override("font_size", 24)
	button.pressed.connect(callback)
	_buttons.append(button)
	return button


func _set_buttons_enabled(enabled: bool) -> void:
	for b in _buttons:
		b.disabled = not enabled


func _nearest_colour_index(colour: Color) -> int:
	var best := 0
	var best_dist := INF
	for i in range(COLOUR_NAMES.size()):
		var c := CourseBuilder.rainbow(i)
		var d := Vector3(c.r - colour.r, c.g - colour.g, c.b - colour.b).length_squared()
		if d < best_dist:
			best_dist = d
			best = i
	return best


func _apply_identity_and_settings() -> void:
	if _net == null:
		return
	var player_name := _name_edit.text.strip_edges()
	_net.local_name = player_name if not player_name.is_empty() else "Player"
	_net.local_colour = CourseBuilder.rainbow(_colour_option.selected)
	_net.settings = {
		"sections": int(_sections_spin.value),
		"bots": int(_bots_spin.value),
		"difficulty": _difficulty_option.selected,
		"countdown": 3,
	}


func _on_play_solo() -> void:
	_apply_identity_and_settings()
	if _net != null:
		_net.leave()
	var err := get_tree().change_scene_to_file(GAME_SCENE)
	if err != OK:
		_status.text = "Could not load the game scene (error %d)." % err


func _on_host() -> void:
	_apply_identity_and_settings()
	if _net == null:
		return
	if _net.host():
		get_tree().change_scene_to_file(LOBBY_SCENE)


func _on_join() -> void:
	_apply_identity_and_settings()
	if _net == null:
		return
	if _net.join(_ip_edit.text):
		_status.text = "Connecting to %s..." % _ip_edit.text.strip_edges()
		_set_buttons_enabled(false)


func _on_connected_to_host() -> void:
	get_tree().change_scene_to_file(LOBBY_SCENE)


func _on_connection_failed(reason: String) -> void:
	_status.text = reason
	_set_buttons_enabled(true)
