class_name HudController
extends CanvasLayer
## Race HUD built in code: timer, coins, held item, position, checkpoint
## progress, countdown, messages and a results panel. Emits restart_requested.

signal restart_requested

@export var message_default_seconds: float = 2.0

var _timer_label: Label
var _coins_label: Label
var _item_box: HBoxContainer
var _item_swatch: ColorRect
var _item_label: Label
var _item_kind: int = -1
var _item_uses: int = -1
var _effects_label: Label
var _overlay: SplatOverlay
var _position_label: Label
var _progress_label: Label
var _countdown_label: Label
var _message_label: Label
var _results_panel: PanelContainer
var _results_box: VBoxContainer
var _prize_line: Label
var _prize_lead: Label
var _prize_label: Label
var _prize_sub: Label
var _prize_token: int = 0
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
	_process_prize(delta)


func set_time(seconds: float) -> void:
	_timer_label.text = format_time(seconds)


func set_coins(coins: int) -> void:
	_coins_label.text = "Gold: %d" % coins


## Shows the held item. [param hint] is the key/button to press, e.g. "E".
func set_item(kind: int, uses: int, hint: String = "") -> void:
	if kind == _item_kind and uses == _item_uses:
		return
	_item_kind = kind
	_item_uses = uses
	if kind == ItemKinds.Kind.NONE:
		_item_box.visible = false
		return
	_item_box.visible = true
	_item_swatch.color = ItemKinds.colour_for(kind)
	var count := " x%d" % uses if uses > 1 else ""
	var press := "   [%s]" % hint if not hint.is_empty() else ""
	_item_label.text = "%s%s%s" % [ItemKinds.display_name(kind), count, press]


## Active effects as [[name, seconds_left, colour], ...] shown under the item slot.
func set_effects(effects: Array) -> void:
	if effects.is_empty():
		_effects_label.text = ""
		return
	var parts: PackedStringArray = []
	for e: Array in effects:
		parts.append("%s %.1fs" % [str(e[0]), float(e[1])])
	_effects_label.text = "   ".join(parts)
	var first: Array = effects[0]
	_effects_label.add_theme_color_override("font_color", first[2])


## Custard over the screen for [param seconds] (hit by a pie).
func splat(seconds: float = 2.2, colour: Color = Color(1.0, 0.86, 0.35), blob_count: int = 9) -> void:
	_overlay.splat(seconds, colour, blob_count)


## Quick full-screen flash (explosions, zaps, hard hits).
func flash(colour: Color, strength: float = 0.45) -> void:
	_overlay.flash(colour, strength)


func set_position(rank: int, total: int) -> void:
	_position_label.text = "%s / %d" % [ordinal(rank), total] if rank > 0 else ""


func set_progress(current: int, total: int) -> void:
	_progress_label.text = "Checkpoints %d / %d" % [current, total]


func show_countdown(seconds_left: int) -> void:
	_countdown_label.text = str(seconds_left) if seconds_left > 0 else "GO!"
	_countdown_time_left = 1.0
	var colours := [CourseBuilder.accent(3), Color(1.0, 0.85, 0.1), CourseBuilder.accent(0), CourseBuilder.accent(2)]
	_countdown_label.add_theme_color_override("font_color", colours[clampi(seconds_left, 0, 3)])
	_pop(_countdown_label, 0.45)


func show_message(text: String, seconds: float = -1.0) -> void:
	var fresh := text != _message_label.text
	_message_label.text = text
	if fresh and not text.is_empty():
		_message_label.pivot_offset = Vector2(_message_label.get_combined_minimum_size().x * 0.5, 20.0)
		_message_label.scale = Vector2(0.7, 0.7)
		_message_label.create_tween().tween_property(_message_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
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
		if entry.has("hits"):
			row.text = "%s   %s   lasted %s   %s: %d" % [
				ordinal(int(entry.get("place", 0))), str(entry.get("name", "?")), time_text,
				str(entry.get("stat", "hits")), int(entry.get("hits", 0)),
			]
		_results_box.add_child(row)
		if button != null:
			_results_box.move_child(button, _results_box.get_child_count() - 1)
	_results_panel.visible = true


func hide_results() -> void:
	_results_panel.visible = false
	_prize_token += 1
	_prize_lead.visible = false
	_prize_label.visible = false
	_prize_sub.visible = false
	_prize_line.text = ""


## Big centre-screen prize reveal: [param lead] first ("Connor won..."), then
## after [param reveal_after] seconds the prize pops in. It also goes on the
## results panel. Calls [param on_reveal] at the moment of the reveal.
func show_prize(lead: String, prize: String, reveal_after: float, subline: String = "", on_reveal: Callable = Callable()) -> void:
	_prize_token += 1
	var token := _prize_token
	clear_message()
	_prize_lead.text = lead
	_prize_lead.visible = true
	_prize_label.visible = false
	_prize_line.text = "%s %s" % [lead, prize.to_upper()]
	if not subline.is_empty():
		_prize_line.text += "\n" + subline
	_prize_sub.text = subline
	_prize_sub.visible = false
	_pop(_prize_lead, 0.4)
	get_tree().create_timer(reveal_after, false).timeout.connect(func() -> void:
		if token != _prize_token:
			return
		_prize_label.text = prize.to_upper()
		_prize_label.visible = true
		_pop(_prize_label, 0.6)
		_prize_sub.visible = not _prize_sub.text.is_empty()
		if on_reveal.is_valid():
			on_reveal.call())


## Hides the big prize text (the prize stays on the results panel).
func hide_prize_banner() -> void:
	_prize_lead.visible = false
	_prize_label.visible = false
	_prize_sub.visible = false


func set_results_title(text: String) -> void:
	var title := _results_box.get_node_or_null("Title") as Label
	if title != null:
		title.text = text


## Arena mode status (Paintball Battle, Dodgem Derby): a status line (lives,
## paint or boost), a score line, and how many are still in.
func set_battle(status: String, warn: bool, score: String, alive: int, total: int, in_game: bool) -> void:
	_position_label.text = "%d / %d LEFT" % [alive, total]
	_coins_label.text = score
	if not in_game:
		_progress_label.text = "Spectating"
		_progress_label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
		return
	_progress_label.text = status
	_progress_label.add_theme_color_override("font_color", CourseBuilder.accent(2) if warn else Color(0.85, 0.88, 0.95))


func _pop(label: Label, seconds: float) -> void:
	var wraps := label.autowrap_mode != TextServer.AUTOWRAP_OFF
	label.pivot_offset = (label.size if wraps else label.get_combined_minimum_size()) * 0.5
	label.scale = Vector2(0.1, 0.1)
	var tween := label.create_tween()
	tween.tween_property(label, "scale", Vector2.ONE, seconds).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _process_prize(_delta: float) -> void:
	if _prize_label.visible:
		var t := Time.get_ticks_msec() / 1000.0
		_prize_label.rotation = sin(t * 3.0) * 0.04
		_prize_label.pivot_offset = _prize_label.size * 0.5
		_prize_label.add_theme_color_override("font_color", CourseBuilder.accent(0).lerp(Color(1.0, 0.9, 0.3), 0.5 + 0.5 * sin(t * 8.0)))


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
	_timer_label = _make_label(28, Color.WHITE, true)
	_timer_label.name = "TimerLabel"
	_timer_label.position = Vector2(20.0, 16.0)
	add_child(_timer_label)

	_coins_label = _make_label(26, Color(1.0, 0.85, 0.2))
	_coins_label.name = "CoinsLabel"
	_coins_label.position = Vector2(20.0, 58.0)
	_coins_label.text = "Gold: 0"
	add_child(_coins_label)

	_item_box = HBoxContainer.new()
	_item_box.name = "ItemSlot"
	_item_box.position = Vector2(20.0, 100.0)
	_item_box.add_theme_constant_override("separation", 10)
	_item_box.visible = false
	add_child(_item_box)
	_item_swatch = ColorRect.new()
	_item_swatch.custom_minimum_size = Vector2(34.0, 34.0)
	_item_box.add_child(_item_swatch)
	_item_label = _make_label(28, Color(1.0, 1.0, 1.0))
	_item_box.add_child(_item_label)

	_effects_label = _make_label(24, CourseBuilder.accent(1))
	_effects_label.name = "EffectsLabel"
	_effects_label.position = Vector2(20.0, 140.0)
	add_child(_effects_label)

	_overlay = SplatOverlay.new()
	_overlay.name = "SplatOverlay"
	add_child(_overlay)
	move_child(_overlay, 0)

	_position_label = _make_label(40, CourseBuilder.accent(1), true)
	_position_label.name = "PositionLabel"
	_position_label.anchor_left = 1.0
	_position_label.anchor_right = 1.0
	_position_label.offset_left = -420.0
	_position_label.offset_right = -20.0
	_position_label.offset_top = 10.0
	_position_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_position_label)

	_progress_label = _make_label(24, Color(0.85, 0.88, 0.95))
	_progress_label.name = "ProgressLabel"
	_progress_label.anchor_left = 1.0
	_progress_label.anchor_right = 1.0
	_progress_label.offset_left = -420.0
	_progress_label.offset_right = -20.0
	_progress_label.offset_top = 66.0
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_progress_label)

	_countdown_label = _make_label(130, CourseBuilder.accent(0), true)
	_countdown_label.name = "CountdownLabel"
	_countdown_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_countdown_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_countdown_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_countdown_label)

	_message_label = _make_label(30, Color.WHITE, true)
	_message_label.name = "MessageLabel"
	_message_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_message_label.offset_top = 150.0
	_message_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_message_label)

	_results_panel = PanelContainer.new()
	_results_panel.name = "ResultsPanel"
	_results_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_results_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_results_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_results_panel.visible = false
	UiStyle.style_panel(_results_panel, 22.0)
	add_child(_results_panel)

	_prize_lead = _make_label(34, Color.WHITE, true)
	_prize_lead.name = "PrizeLead"
	_prize_lead.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_prize_lead.offset_top = -150.0
	_prize_lead.offset_bottom = -90.0
	_prize_lead.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prize_lead.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prize_lead.add_theme_constant_override("outline_size", 10)
	_prize_lead.visible = false
	add_child(_prize_lead)
	_prize_label = _make_label(54, CourseBuilder.accent(0), true)
	_prize_label.name = "PrizeLabel"
	_prize_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_prize_label.offset_left = -600.0
	_prize_label.offset_right = 600.0
	_prize_label.offset_top = -80.0
	_prize_label.offset_bottom = 60.0
	_prize_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prize_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prize_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prize_label.add_theme_constant_override("outline_size", 14)
	_prize_label.visible = false
	add_child(_prize_label)
	_prize_sub = _make_label(30, Color(0.6, 1.0, 0.4))
	_prize_sub.name = "PrizeSub"
	_prize_sub.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_prize_sub.offset_top = 100.0
	_prize_sub.offset_bottom = 145.0
	_prize_sub.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prize_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prize_sub.visible = false
	add_child(_prize_sub)

	_results_box = VBoxContainer.new()
	_results_box.name = "ResultsBox"
	_results_box.add_theme_constant_override("separation", 10)
	_results_panel.add_child(_results_box)

	var title := _make_label(38, CourseBuilder.accent(0), true)
	title.name = "Title"
	title.text = Branding.RESULTS_TITLE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_results_box.add_child(title)

	_prize_line = _make_label(24, Color(1.0, 0.85, 0.3))
	_prize_line.name = "PrizeLine"
	_prize_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prize_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prize_line.custom_minimum_size = Vector2(640.0, 0.0)
	_results_box.add_child(_prize_line)

	var button := Button.new()
	button.name = "RaceAgainButton"
	button.text = "Play Again"
	button.custom_minimum_size = Vector2(240.0, 60.0)
	button.add_theme_font_size_override("font_size", 28)
	UiStyle.style_button(button, true)
	GameFonts.use_title(button)
	button.pressed.connect(func() -> void: restart_requested.emit())
	_results_box.add_child(button)


func _make_label(font_size: int, colour: Color, title_font: bool = false) -> Label:
	var label := Label.new()
	if title_font:
		GameFonts.use_title(label)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	return label
