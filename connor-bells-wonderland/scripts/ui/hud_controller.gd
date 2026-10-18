class_name HudController
extends CanvasLayer
## Race HUD built in code: timer, coins, position, checkpoint progress,
## countdown, messages and a results panel. Emits restart_requested.

signal restart_requested

@export var message_default_seconds: float = 2.0

var _timer_label: Label
var _coins_label: Label
var _position_label: Label
var _progress_label: Label
var _countdown_label: Label
var _message_label: Label
var _results_panel: PanelContainer
var _results_box: VBoxContainer
var _message_time_left: float = 0.0
var _countdown_time_left: float = 0.0


func _ready() -> void:
	_build()


func _process(delta: float) -> void:
	if _message_time_left > 0.0:
		_message_time_left -= delta
		if _message_time_left <= 0.0:
			_message_label.text = ""
	if _countdown_time_left > 0.0:
		_countdown_time_left -= delta
		if _countdown_time_left <= 0.0:
			_countdown_label.text = ""


func set_time(seconds: float) -> void:
	_timer_label.text = format_time(seconds)


func set_coins(coins: int) -> void:
	_coins_label.text = "Gold: %d" % coins


func set_position(rank: int, total: int) -> void:
	_position_label.text = "%s / %d" % [ordinal(rank), total] if rank > 0 else ""


func set_progress(current: int, total: int) -> void:
	_progress_label.text = "Checkpoints %d / %d" % [current, total]


func show_countdown(seconds_left: int) -> void:
	_countdown_label.text = str(seconds_left) if seconds_left > 0 else "GO!"
	_countdown_time_left = 1.0


func show_message(text: String, seconds: float = -1.0) -> void:
	_message_label.text = text
	_message_time_left = seconds if seconds > 0.0 else message_default_seconds


func clear_message() -> void:
	_message_label.text = ""
	_message_time_left = 0.0


func show_results(results: Array) -> void:
	for child in _results_box.get_children():
		if str(child.name).begins_with("Row"):
			_results_box.remove_child(child)
			child.queue_free()
	var button := _results_box.get_node_or_null("RaceAgainButton")
	for entry in results:
		var row := _make_label(26, Color.WHITE)
		row.name = "Row%d" % int(entry.get("place", 0))
		var time_text := "DNF"
		if bool(entry.get("finished", false)):
			time_text = format_time(float(entry.get("time", 0.0)))
		row.text = "%s   %s   %s   falls: %d   gold: %d" % [
			ordinal(int(entry.get("place", 0))), str(entry.get("name", "?")), time_text,
			int(entry.get("falls", 0)), int(entry.get("coins", 0)),
		]
		_results_box.add_child(row)
		if button != null:
			_results_box.move_child(button, _results_box.get_child_count() - 1)
	_results_panel.visible = true


func hide_results() -> void:
	_results_panel.visible = false


func format_time(seconds: float) -> String:
	return "%02d:%05.2f" % [int(seconds) / 60, fmod(seconds, 60.0)]


func ordinal(place: int) -> String:
	var suffix := "th"
	if place % 100 < 11 or place % 100 > 13:
		match place % 10:
			1: suffix = "st"
			2: suffix = "nd"
			3: suffix = "rd"
	return "%d%s" % [place, suffix]


func _build() -> void:
	_timer_label = _make_label(30, Color.WHITE)
	_timer_label.name = "TimerLabel"
	_timer_label.position = Vector2(20.0, 16.0)
	add_child(_timer_label)

	_coins_label = _make_label(26, Color(1.0, 0.85, 0.2))
	_coins_label.name = "CoinsLabel"
	_coins_label.position = Vector2(20.0, 58.0)
	_coins_label.text = "Gold: 0"
	add_child(_coins_label)

	_position_label = _make_label(44, Color(0.6, 1.0, 0.7))
	_position_label.name = "PositionLabel"
	_position_label.anchor_left = 1.0
	_position_label.anchor_right = 1.0
	_position_label.offset_left = -420.0
	_position_label.offset_right = -20.0
	_position_label.offset_top = 10.0
	_position_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_position_label)

	_progress_label = _make_label(24, Color(1.0, 0.95, 0.6))
	_progress_label.name = "ProgressLabel"
	_progress_label.anchor_left = 1.0
	_progress_label.anchor_right = 1.0
	_progress_label.offset_left = -420.0
	_progress_label.offset_right = -20.0
	_progress_label.offset_top = 66.0
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_progress_label)

	_countdown_label = _make_label(110, Color(1.0, 0.9, 0.2))
	_countdown_label.name = "CountdownLabel"
	_countdown_label.set_anchors_preset(Control.PRESET_CENTER)
	_countdown_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_countdown_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_countdown_label)

	_message_label = _make_label(36, Color.WHITE)
	_message_label.name = "MessageLabel"
	_message_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_message_label.offset_top = 90.0
	_message_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_message_label)

	_results_panel = PanelContainer.new()
	_results_panel.name = "ResultsPanel"
	_results_panel.set_anchors_preset(Control.PRESET_CENTER)
	_results_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_results_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_results_panel.visible = false
	add_child(_results_panel)

	_results_box = VBoxContainer.new()
	_results_box.name = "ResultsBox"
	_results_box.add_theme_constant_override("separation", 10)
	_results_panel.add_child(_results_box)

	var title := _make_label(44, Color(1.0, 0.85, 0.2))
	title.name = "Title"
	title.text = Branding.RESULTS_TITLE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_results_box.add_child(title)

	var button := Button.new()
	button.name = "RaceAgainButton"
	button.text = "Race Again"
	button.custom_minimum_size = Vector2(240.0, 60.0)
	button.add_theme_font_size_override("font_size", 28)
	button.pressed.connect(func() -> void: restart_requested.emit())
	_results_box.add_child(button)


func _make_label(font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	return label
