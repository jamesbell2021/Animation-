class_name PauseMenu
extends CanvasLayer
## Menu button (top centre) and overlay: Resume, Music, Leave to Menu.
## Pauses the scene tree in solo mode only (pause_tree); multiplayer keeps running.
## Also reacts to the Android Back button.

signal music_toggled(enabled: bool)
signal leave_requested

const MENU_SCENE := "res://scenes/menus/main_menu.tscn"

@export var pause_tree: bool = true
@export var music_enabled: bool = true

var _overlay: Control
var _music_button: Button
var _open: bool = false


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		set_open(not _open)


func set_open(open: bool) -> void:
	_open = open
	_overlay.visible = open
	if pause_tree and get_tree() != null:
		get_tree().paused = open


func is_open() -> bool:
	return _open


func _build() -> void:
	var menu_button := Button.new()
	menu_button.name = "MenuButton"
	menu_button.text = "MENU"
	menu_button.custom_minimum_size = Vector2(120.0, 48.0)
	menu_button.anchor_left = 0.5
	menu_button.anchor_right = 0.5
	menu_button.offset_left = -60.0
	menu_button.offset_right = 60.0
	menu_button.offset_top = 10.0
	menu_button.offset_bottom = 58.0
	menu_button.add_theme_font_size_override("font_size", 22)
	menu_button.pressed.connect(func() -> void: set_open(true))
	add_child(menu_button)

	_overlay = Control.new()
	_overlay.name = "Overlay"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	add_child(_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_overlay.add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(320.0, 0.0)
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var title := Label.new()
	title.text = "PAUSED" if pause_tree else "MENU"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", CourseBuilder.accent(0))
	box.add_child(title)
	box.add_child(_button("Resume", func() -> void: set_open(false)))
	_music_button = _button("Music: On" if music_enabled else "Music: Off", _on_music_pressed)
	box.add_child(_music_button)
	box.add_child(_button("Leave to Menu", _on_leave_pressed))


func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 56.0)
	button.add_theme_font_size_override("font_size", 26)
	button.pressed.connect(callback)
	return button


func _on_music_pressed() -> void:
	music_enabled = not music_enabled
	_music_button.text = "Music: On" if music_enabled else "Music: Off"
	music_toggled.emit(music_enabled)


func _on_leave_pressed() -> void:
	leave_requested.emit()
	if get_tree() != null:
		get_tree().paused = false
	var net := get_node_or_null("/root/NetworkManager")
	if net != null:
		net.leave()
	var err := get_tree().change_scene_to_file(MENU_SCENE)
	if err != OK:
		push_error("PauseMenu: could not load %s (error %d)." % [MENU_SCENE, err])
