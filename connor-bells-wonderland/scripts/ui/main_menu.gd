extends Control
## Main menu: player identity, solo race settings, host or join a Wi-Fi game.
## All controls are built in code; attach to a Control root saved as main_menu.tscn.

const GAME_SCENE := "res://scenes/main/main.tscn"
const LOBBY_SCENE := "res://scenes/menus/lobby.tscn"
const COLOUR_NAMES: Array[String] = CourseBuilder.PLAYER_COLOUR_NAMES
const DIFFICULTY_NAMES: Array[String] = ["Easy", "Medium", "Hard"]
const MODES: Array[String] = ["race", "tower", "paintball", "dodgems"]
const MODE_NAMES: Array[String] = ["Fairground Race", "Tower Climb", "Paintball Battle", "Dodgem Derby"]
const PLAY_TEXT: Array[String] = ["PLAY SOLO", "TOWER CLIMB!", "PAINTBALL BATTLE!", "DODGEM DERBY!"]

var _net: Node
var _name_edit: LineEdit
var _colour_option: OptionButton
var _sections_spin: SpinBox
var _bots_spin: SpinBox
var _difficulty_option: OptionButton
var _items_check: CheckButton
var _mode_option: OptionButton
var _ip_edit: LineEdit
var _status: Label
var _buttons: Array[Button] = []
var _tip: Label
var _play_button: Button
var _credits_button: Button
var _tip_left: float = 0.0
var _tip_index: int = -1

const TIPS: Array[String] = [
	"Hold E to aim the Catapult, let go to launch yourself",
	"Every item hit steals 1 gold off your victim",
	"The Giant Magnet drags rivals in and nicks their gold",
	"Shield Bubble bounces attacks back at whoever threw them",
	"Rocket Boots: barge straight through the pack",
	"Mega Bomb blasts everyone near you off their feet",
	"Win the race to win a ridiculous prize",
	"Falling behind? The back of the pack gets the best items",
	"Paintball Battle: last one standing wins Fruit of the Month!",
	"Paintball: hold E to fire, grab PAINT crates to reload",
	"Dodgem Derby: ram them into the Irish Sea, SPACE to boost",
	"Tower Climb: fall off and it's back to the last landing!",
	"Tower Climb: every weapon is in the boxes - use them!",
	"Dodgem Derby: hit them from the middle so they fly off the edge",
]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
		_items_check.button_pressed = bool(_net.settings.get("items", true))
		_mode_option.selected = maxi(MODES.find(str(_net.settings.get("mode", "race"))), 0)
	_update_mode_rows()


func _build() -> void:
	add_child(MenuBackdrop.new())
	# Darken the left side so the menu reads clearly over the fair.
	var shade := TextureRect.new()
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.42, 0.62])
	gradient.colors = PackedColorArray([Color(0.0, 0.0, 0.02, 0.75), Color(0.0, 0.0, 0.02, 0.55), Color(0.0, 0.0, 0.02, 0.0)])
	var shade_tex := GradientTexture2D.new()
	shade_tex.gradient = gradient
	shade_tex.width = 256
	shade_tex.height = 4
	shade.texture = shade_tex
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var title := WaveTitle.new()
	title.text = Branding.title_upper()
	title.font_size = 62
	title.glow_colour = CourseBuilder.accent(0)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 4.0
	title.offset_bottom = 96.0
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)
	var subtitle := Label.new()
	subtitle.text = Branding.SUBTITLE.to_upper()
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	subtitle.offset_top = 92.0
	subtitle.offset_bottom = 124.0
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", CourseBuilder.accent(1))
	subtitle.add_theme_color_override("font_outline_color", Color.BLACK)
	subtitle.add_theme_constant_override("outline_size", 6)
	add_child(subtitle)

	var panel := PanelContainer.new()
	panel.position = Vector2(24.0, 136.0)
	panel.custom_minimum_size = Vector2(470.0, 0.0)
	panel.add_theme_stylebox_override("panel", UiStyle.box(Color(0.03, 0.035, 0.06, 0.85), CourseBuilder.accent(1), 2, 16))
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	panel.add_child(box)

	_mode_option = OptionButton.new()
	for i in range(MODE_NAMES.size()):
		_mode_option.add_item(MODE_NAMES[i], i)
	_mode_option.item_selected.connect(func(_i: int) -> void: _update_mode_rows())
	box.add_child(_row("Mode", _mode_option))
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
	_items_check = CheckButton.new()
	_items_check.text = "Item boxes"
	_items_check.button_pressed = true
	box.add_child(_row("Items", _items_check))

	var play := _button("PLAY SOLO", _on_play_solo, true)
	_play_button = play
	play.custom_minimum_size = Vector2(0.0, 58.0)
	play.add_theme_font_size_override("font_size", 26)
	GameFonts.use_title(play)
	box.add_child(play)
	var host_row := HBoxContainer.new()
	host_row.add_theme_constant_override("separation", 8)
	box.add_child(host_row)
	# The browser version can't do Wi-Fi games (or quit): just Credits there.
	var web := OS.has_feature("web")
	var host := _button("Host Wi-Fi Game", _on_host)
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.visible = not web
	host_row.add_child(host)
	_credits_button = _button("Credits", _on_credits)
	_credits_button.custom_minimum_size = Vector2(110.0, 46.0)
	if web:
		_credits_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host_row.add_child(_credits_button)
	var quit := _button("Quit", func() -> void: get_tree().quit())
	quit.custom_minimum_size = Vector2(110.0, 46.0)
	quit.visible = not web
	host_row.add_child(quit)
	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 8)
	box.add_child(join_row)
	_ip_edit = LineEdit.new()
	_ip_edit.placeholder_text = "Host IP, e.g. 192.168.1.20"
	_ip_edit.custom_minimum_size = Vector2(0.0, 46.0)
	_ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_row.add_child(_ip_edit)
	var join := _button("Join", _on_join)
	join.custom_minimum_size = Vector2(110.0, 46.0)
	join_row.add_child(join)
	join_row.visible = not web

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", CourseBuilder.accent(1))
	box.add_child(_status)

	var designer := Label.new()
	designer.text = Branding.DESIGNER_CREDIT
	designer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	designer.offset_left = -640.0
	designer.offset_top = -84.0
	designer.offset_right = -20.0
	designer.offset_bottom = -52.0
	designer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	designer.add_theme_font_size_override("font_size", 20)
	designer.add_theme_color_override("font_color", CourseBuilder.accent(1))
	designer.add_theme_color_override("font_outline_color", Color.BLACK)
	designer.add_theme_constant_override("outline_size", 6)
	designer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(designer)

	_tip = Label.new()
	_tip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_tip.offset_left = -640.0
	_tip.offset_top = -48.0
	_tip.offset_right = -20.0
	_tip.offset_bottom = -14.0
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_tip.add_theme_font_size_override("font_size", 20)
	_tip.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_tip.add_theme_color_override("font_outline_color", Color.BLACK)
	_tip.add_theme_constant_override("outline_size", 6)
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tip)
	_next_tip()


func _process(delta: float) -> void:
	_tip_left -= delta
	if _tip_left <= 0.0:
		_next_tip()


func _next_tip() -> void:
	_tip_left = 4.5
	_tip_index = (_tip_index + 1) % TIPS.size()
	var tip := TIPS[_tip_index]
	if DisplayServer.is_touchscreen_available():
		# Phones: name the on-screen buttons instead of keys.
		tip = tip.replace("Hold E", "Hold USE").replace("hold E", "hold USE").replace("SPACE", "JUMP")
	_tip.text = tip
	_tip.modulate.a = 0.0
	_tip.create_tween().tween_property(_tip, "modulate:a", 1.0, 0.4)


func _row(label_text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(120.0, 0.0)
	label.add_theme_font_size_override("font_size", 20)
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.custom_minimum_size = Vector2(0.0, 40.0)
	row.add_child(control)
	return row


func _spin(min_value: int, max_value: int, value: int) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.value = value
	spin.rounded = true
	return spin


func _button(text: String, callback: Callable, main: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 46.0)
	button.add_theme_font_size_override("font_size", 22)
	UiStyle.style_button(button, main)
	button.pressed.connect(func() -> void:
		var sm := get_tree().get_first_node_in_group("sound_manager") as SoundManager
		if sm != null:
			sm.play("click"))
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
		var c := CourseBuilder.player_colour(i)
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
	_net.local_colour = CourseBuilder.player_colour(_colour_option.selected)
	_net.settings = {
		"sections": int(_sections_spin.value),
		"bots": int(_bots_spin.value),
		"difficulty": _difficulty_option.selected,
		"countdown": 3,
		"items": _items_check.button_pressed,
		"mode": MODES[_mode_option.selected],
	}


func _on_credits() -> void:
	var c := preload("res://studio/credits.gd").open(self, Branding.GAME_TITLE, GameFonts.CREDIT_LINES, GameFonts.title())
	c.closed.connect(func() -> void: _credits_button.grab_focus())


## Sections only matter for the race; items for the race and Dodgem Derby.
func _update_mode_rows() -> void:
	var chosen := MODES[_mode_option.selected]
	_sections_spin.get_parent().visible = chosen == "race"
	_items_check.get_parent().visible = chosen != "paintball"
	if _play_button != null:
		_play_button.text = PLAY_TEXT[_mode_option.selected]


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
