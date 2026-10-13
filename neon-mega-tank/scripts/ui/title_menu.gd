class_name TitleMenu
extends Control
## Title screen: PLAY (this device + AI crew), HOST a LAN game, or JOIN one found on the Wi-Fi.
## Big neon buttons that work with touch, mouse, keyboard and gamepad.

signal play_local
signal host_game
signal join_game(ip: String)

var _main_box: VBoxContainer
var _join_box: VBoxContainer
var _hosts_box: VBoxContainer
var _ip_edit: LineEdit
var _status: Label
var _searching: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.02, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)

	column.add_child(_label("NEON MEGA TANK", 88, Color(1.0, 0.3, 0.85)))
	column.add_child(_label("ネオン・メガ・タンク　～ 生き残れ！ ～", 38, Color(0.3, 0.9, 1.0)))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	column.add_child(spacer)

	_main_box = VBoxContainer.new()
	_main_box.add_theme_constant_override("separation", 14)
	column.add_child(_main_box)
	var play := _button("▶  PLAY", "this device + controllers, AI crew fills empty seats", Color(0.3, 1.0, 0.5))
	play.pressed.connect(func() -> void: play_local.emit())
	var host := _button("HOST LAN GAME", "friends join from their own phones on this Wi-Fi", Color(0.3, 0.8, 1.0))
	host.pressed.connect(func() -> void: host_game.emit())
	var join := _button("JOIN LAN GAME", "find a game hosted on this Wi-Fi", Color(1.0, 0.85, 0.2))
	join.pressed.connect(_show_join)
	for b in [play, host, join]:
		_main_box.add_child(b)
	if not OS.has_feature("mobile"):
		var quit := _button("QUIT", "", Color(1.0, 0.3, 0.3))
		quit.pressed.connect(func() -> void: get_tree().quit())
		_main_box.add_child(quit)

	_join_box = VBoxContainer.new()
	_join_box.add_theme_constant_override("separation", 12)
	_join_box.visible = false
	column.add_child(_join_box)
	_searching = _label("searching for games on your Wi-Fi ...", 30, Color(0.7, 0.9, 1.0))
	_join_box.add_child(_searching)
	_hosts_box = VBoxContainer.new()
	_hosts_box.add_theme_constant_override("separation", 10)
	_join_box.add_child(_hosts_box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_join_box.add_child(row)
	_ip_edit = LineEdit.new()
	_ip_edit.placeholder_text = "host IP, e.g. 192.168.1.20"
	_ip_edit.custom_minimum_size = Vector2(560, 84)
	_ip_edit.add_theme_font_override("font", G.jp_font)
	_ip_edit.add_theme_font_size_override("font_size", 32)
	_ip_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL
	_ip_edit.text_submitted.connect(func(t: String) -> void: _connect(t))
	row.add_child(_ip_edit)
	var go := _button("CONNECT", "", Color(0.3, 1.0, 0.5), 200)
	go.pressed.connect(func() -> void: _connect(_ip_edit.text))
	row.add_child(go)
	var back := _button("BACK", "", Color(1.0, 0.3, 0.3))
	back.pressed.connect(_show_main)
	_join_box.add_child(back)

	_status = _label(G.menu_message, 28, Color(1.0, 0.85, 0.3))
	G.menu_message = ""
	column.add_child(_status)
	Net.hosts_changed.connect(_refresh_hosts)
	visibility_changed.connect(_on_visibility)
	_on_visibility()


func _exit_tree() -> void:
	if Net.hosts_changed.is_connected(_refresh_hosts):
		Net.hosts_changed.disconnect(_refresh_hosts)
	Net.stop_discovery()


func _on_visibility() -> void:
	if visible:
		_show_main()
	else:
		Net.stop_discovery()


func show_status(text: String) -> void:
	_status.text = text


func _show_main() -> void:
	Net.stop_discovery()
	_main_box.visible = true
	_join_box.visible = false
	(_main_box.get_child(0) as Button).call_deferred("grab_focus")


func _show_join() -> void:
	_main_box.visible = false
	_join_box.visible = true
	_status.text = ""
	Net.start_discovery()
	_refresh_hosts()


func _refresh_hosts() -> void:
	for c in _hosts_box.get_children():
		c.queue_free()
	_searching.text = "searching for games on your Wi-Fi ..." if Net.hosts.is_empty() else "games found on your Wi-Fi:"
	for ip in Net.hosts:
		var h: Dictionary = Net.hosts[ip]
		var b := _button("JOIN  %s" % ip, "%s  -  %d player(s) aboard" % [h["name"], h["crew"]], Color(0.3, 0.9, 1.0))
		b.pressed.connect(_connect.bind(ip))
		_hosts_box.add_child(b)
	if not Net.hosts.is_empty():
		(_hosts_box.get_child(0) as Button).call_deferred("grab_focus")


func _connect(ip: String) -> void:
	if ip.strip_edges().is_valid_ip_address():
		join_game.emit(ip.strip_edges())
	else:
		_status.text = "that is not an IP address"


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", G.jp_font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 10)
	return l


func _button(title: String, subtitle: String, color: Color, width := 720) -> Button:
	var b := Button.new()
	b.text = title + ("\n" + subtitle if subtitle != "" else "")
	b.custom_minimum_size = Vector2(width, 110 if subtitle != "" else 84)
	b.add_theme_font_override("font", G.jp_font)
	b.add_theme_font_size_override("font_size", 34 if subtitle == "" else 30)
	b.add_theme_color_override("font_color", color)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	for state in ["normal", "hover", "pressed", "focus"]:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(color, 0.08 if state == "normal" else 0.25)
		s.border_color = Color(color, 0.6 if state == "normal" else 1.0)
		s.set_border_width_all(3)
		s.set_corner_radius_all(6)
		s.set_content_margin_all(10)
		b.add_theme_stylebox_override(state, s)
	return b
