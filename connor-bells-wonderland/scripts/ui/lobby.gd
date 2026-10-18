extends Control
## Wi-Fi lobby: player list, host-only race settings, ready/leave/start.
## Attach to a Control root saved as lobby.tscn.

const MENU_SCENE := "res://scenes/menus/main_menu.tscn"
const DIFFICULTY_NAMES: Array[String] = ["Easy", "Medium", "Hard"]

var _net: Node
var _list: VBoxContainer
var _ip_label: Label
var _sections_spin: SpinBox
var _bots_spin: SpinBox
var _difficulty_option: OptionButton
var _countdown_spin: SpinBox
var _items_check: CheckButton
var _start_button: Button
var _ready_button: Button
var _status: Label
var _is_host: bool = false
var _updating: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_net = get_node_or_null("/root/NetworkManager")
	if _net == null or not _net.is_multiplayer_session:
		push_error("Lobby: no network session; returning to the menu.")
		get_tree().change_scene_to_file.call_deferred(MENU_SCENE)
		return
	_is_host = _net.is_host()
	_build()
	_net.player_list_changed.connect(_refresh_players)
	_net.settings_changed.connect(_apply_settings)
	_net.disconnected_from_host.connect(_on_disconnected)
	_apply_settings(_net.settings)
	_refresh_players()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.045, 0.07)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 30)
	panel.add_child(columns)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(340.0, 0.0)
	columns.add_child(left)
	var title := Label.new()
	title.text = "%s LOBBY%s" % [Branding.HERO_NAME.to_upper() + "'S", " (host)" if _is_host else ""]
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", CourseBuilder.accent(0))
	left.add_child(title)
	_ip_label = Label.new()
	_ip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _is_host:
		var ips: Array[String] = _net.get_local_ip_addresses()
		_ip_label.text = "Friends join with IP: %s" % (", ".join(ips) if not ips.is_empty() else "(no Wi-Fi address found)")
	else:
		_ip_label.text = "Connected to host. Press Ready!"
	left.add_child(_ip_label)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	left.add_child(_list)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(340.0, 0.0)
	right.add_theme_constant_override("separation", 10)
	columns.add_child(right)
	_sections_spin = _spin(1, 6, 6)
	right.add_child(_row("Sections", _sections_spin))
	_bots_spin = _spin(0, 7, 3)
	right.add_child(_row("Bots", _bots_spin))
	_difficulty_option = OptionButton.new()
	for i in range(DIFFICULTY_NAMES.size()):
		_difficulty_option.add_item(DIFFICULTY_NAMES[i], i)
	right.add_child(_row("Difficulty", _difficulty_option))
	_countdown_spin = _spin(1, 10, 3)
	right.add_child(_row("Countdown", _countdown_spin))
	_items_check = CheckButton.new()
	_items_check.text = "On"
	_items_check.button_pressed = true
	_items_check.disabled = not _is_host
	_items_check.toggled.connect(func(_on: bool) -> void: _push_settings())
	right.add_child(_row("Items", _items_check))
	for control: SpinBox in [_sections_spin, _bots_spin, _countdown_spin]:
		control.editable = _is_host
		control.value_changed.connect(func(_v: float) -> void: _push_settings())
	_difficulty_option.disabled = not _is_host
	_difficulty_option.item_selected.connect(func(_i: int) -> void: _push_settings())

	_ready_button = _button("Ready", _on_ready_pressed)
	_ready_button.toggle_mode = true
	_ready_button.visible = not _is_host
	right.add_child(_ready_button)
	_start_button = _button("Start Race", _on_start_pressed)
	_start_button.visible = _is_host
	right.add_child(_start_button)
	right.add_child(_button("Leave", _on_leave_pressed))
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", CourseBuilder.accent(1))
	right.add_child(_status)


func _row(label_text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(130.0, 0.0)
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
	return button


func _refresh_players() -> void:
	if _list == null or not is_instance_valid(_list):
		return
	for child in _list.get_children():
		child.queue_free()
	var count: int = _net.get_player_count()
	for id: int in _net.get_sorted_peer_ids():
		var entry: Dictionary = _net.players[id]
		var row := HBoxContainer.new()
		var swatch := ColorRect.new()
		swatch.color = entry.get("colour", Color.WHITE)
		swatch.custom_minimum_size = Vector2(28.0, 28.0)
		row.add_child(swatch)
		var label := Label.new()
		var tag := " (host)" if id == 1 else (" ready" if bool(entry.get("ready", false)) else " not ready")
		label.text = " %s%s" % [str(entry.get("name", "?")), tag]
		label.add_theme_font_size_override("font_size", 22)
		row.add_child(label)
		_list.add_child(row)
	_bots_spin.max_value = maxi(8 - count, 0)
	if _is_host:
		_status.text = "%d player(s). %s" % [count, "Everyone is ready." if _net.all_ready() else "Waiting for players to press Ready."]


func _apply_settings(settings: Dictionary) -> void:
	_updating = true
	_sections_spin.value = int(settings.get("sections", 6))
	_bots_spin.value = int(settings.get("bots", 3))
	_difficulty_option.selected = clampi(int(settings.get("difficulty", 1)), 0, 2)
	_countdown_spin.value = int(settings.get("countdown", 3))
	_items_check.button_pressed = bool(settings.get("items", true))
	_updating = false


func _push_settings() -> void:
	if _updating or not _is_host:
		return
	_net.update_settings({
		"sections": int(_sections_spin.value),
		"bots": int(_bots_spin.value),
		"difficulty": _difficulty_option.selected,
		"countdown": int(_countdown_spin.value),
		"items": _items_check.button_pressed,
	})


func _on_ready_pressed() -> void:
	_net.set_local_ready(_ready_button.button_pressed)
	_ready_button.text = "Ready!" if _ready_button.button_pressed else "Ready"


func _on_start_pressed() -> void:
	if _net.get_player_count() > 1 and not _net.all_ready():
		_status.text = "Starting anyway - not everyone pressed Ready."
	_net.start_game()


func _on_disconnected(reason: String) -> void:
	_status.text = reason


func _on_leave_pressed() -> void:
	_net.leave()
	get_tree().change_scene_to_file(MENU_SCENE)
