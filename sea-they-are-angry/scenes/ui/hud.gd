extends CanvasLayer
## Heads-up display, built entirely in code.

const FONT := 18
const MSG_TIME := 2.5
const MSG_FADE := 0.6
const WARN_TIME := 3.0
const REPORT_TIME := 7.0
const RED := Color(1.0, 0.35, 0.3)
const AMBER := Color(1.0, 0.8, 0.45)
const PALE := Color(0.92, 0.94, 0.96)
const CONTROLS := "WASD move · Mouse aim · LMB attack · RMB flare · E interact · R operate lamp · Q beam · F dirty fuel · Space sprint · Enter skip day/dawn"

var player: Player
var players: Array = []
var lighthouse: Lighthouse
var lamp: Lamp

var _phase_label: Label
var _stock_label: Label
var _player_label: Label
var _lh_label: Label
var _fuel_bar: ProgressBar
var _lamp_label: Label
var _beam_label: Label
var _prompt_label: Label
var _msg_label: Label
var _warn_label: Label
var _report_label: Label
var _report_t := 0.0
var _over: Control
var _over_reason: Label
var _over_stats: Label
var _msg_t := 0.0
var _warn_t := 0.0

func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var panel := VBoxContainer.new()
	panel.position = Vector2(20, 16)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_constant_override("separation", 4)
	root.add_child(panel)
	_phase_label = _label(panel, FONT + 6)
	_stock_label = _label(panel, FONT)
	_player_label = _label(panel, FONT)
	_lh_label = _label(panel, FONT)
	var fuel_row := HBoxContainer.new()
	fuel_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(fuel_row)
	var fuel_text := _label(fuel_row, FONT)
	fuel_text.text = "Fuel "
	_fuel_bar = ProgressBar.new()
	_fuel_bar.min_value = 0.0
	_fuel_bar.max_value = Lamp.FUEL_MAX
	_fuel_bar.show_percentage = false
	_fuel_bar.custom_minimum_size = Vector2(260, 20)
	_fuel_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_fuel_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fuel_row.add_child(_fuel_bar)
	_lamp_label = _label(panel, FONT)
	_beam_label = _label(panel, FONT)

	var controls := _label(root, 14)
	controls.text = CONTROLS
	controls.anchor_left = 1.0
	controls.anchor_right = 1.0
	controls.offset_left = -760.0
	controls.offset_right = -20.0
	controls.offset_top = 16.0
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.modulate = Color(1, 1, 1, 0.75)

	_prompt_label = _bottom_label(root, -120.0, FONT + 2)
	_msg_label = _bottom_label(root, -84.0, FONT)
	_msg_label.add_theme_color_override("font_color", AMBER)

	_warn_label = _label(root, 52)
	Fonts.use_title(_warn_label)
	_warn_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_warn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_warn_label.offset_top = -160.0
	_warn_label.visible = false
	_report_label = _label(root, 24)
	_report_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_report_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_report_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_report_label.offset_top = 60.0
	_report_label.offset_left = 80.0
	_report_label.offset_right = -80.0
	_report_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_report_label.add_theme_constant_override("outline_size", 8)
	_report_label.visible = false

	_build_game_over(root)

	Events.message.connect(_on_message)
	Events.run_ended.connect(_on_run_ended)
	Cycle.phase_changed.connect(_on_phase_changed)

func _label(parent: Node, size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", PALE)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _bottom_label(parent: Node, offset: float, size: int) -> Label:
	var l := _label(parent, size)
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.anchor_top = 1.0
	l.anchor_bottom = 1.0
	l.offset_top = offset
	l.offset_bottom = offset + 32.0
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _build_game_over(root: Control) -> void:
	_over = Control.new()
	_over.set_anchors_preset(Control.PRESET_FULL_RECT)
	_over.mouse_filter = Control.MOUSE_FILTER_STOP
	_over.visible = false
	root.add_child(_over)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.03, 0.05, 0.82)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	_over.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)
	var title := _label(box, 64)
	Fonts.use_title(title)
	title.text = "The light is out."
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_over_reason = _label(box, 26)
	_over_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_over_stats = _label(box, 22)
	_over_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var btn := Button.new()
	btn.text = "New Run"
	btn.add_theme_font_size_override("font_size", 28)
	Fonts.use_title(btn)
	btn.custom_minimum_size = Vector2(220, 52)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(_on_new_run)
	box.add_child(btn)

func _process(delta: float) -> void:
	_phase_label.text = "Night %d — %s  (%s)" % [Run.night, Cycle.phase_name(), _mmss(Cycle.time_left)]
	if Cycle.phase == Cycle.Phase.DUSK or Cycle.phase == Cycle.Phase.NIGHT:
		_phase_label.text += "  · " + Weather.tonight_name()
	var stock := "Driftwood %d · Scrap %d · Bio %d · Kelp %d · Food %d" % [Stock.get_amount("driftwood"), Stock.get_amount("scrap"), Stock.get_amount("bio"), Stock.get_amount("seaweed"), Stock.get_amount("food")]
	if Stock.get_amount("oil") > 0:
		stock += " · Oil %d" % Stock.get_amount("oil")
	if Stock.get_amount("dirty_fuel") > 0:
		stock += " · Dirty fuel %d" % Stock.get_amount("dirty_fuel")
	_stock_label.text = stock
	if player and is_instance_valid(player):
		var parts: Array[String] = []
		var list: Array = players if players.size() > 1 else [player]
		for p in list:
			if not is_instance_valid(p):
				continue
			var who: String = ((p.keeper_name() + " ") if p.ai else ("P%d %s " % [p.idx + 1, p.keeper_name()])) if list.size() > 1 else "Keeper "
			parts.append(who + ("DOWN" if p.downed else "HP %d / %d · Flares %d" % [p.hp, p.max_hp, p.flares()]))
		_player_label.text = "   ".join(parts)
		_prompt_label.text = player.interact_prompt() if Run.active else ""
	if lighthouse and is_instance_valid(lighthouse):
		_lh_label.text = "Lighthouse %d / %d" % [lighthouse.hp, lighthouse.max_hp]
		_lh_label.add_theme_color_override("font_color", RED if lighthouse.health_ratio() < 0.3 else PALE)
	if lamp and is_instance_valid(lamp):
		_fuel_bar.value = lamp.fuel
		_update_lamp_label()
		_beam_label.visible = player != null and player.operating
		_beam_label.text = "Beam: %s   [Q] switch" % ("FOCUSED" if lamp.mode == Lamp.Mode.FOCUSED else "WIDE")
	if _msg_t > 0.0:
		_msg_t = maxf(0.0, _msg_t - delta)
		_msg_label.modulate.a = clampf(_msg_t / MSG_FADE, 0.0, 1.0)
	if _report_t > 0.0:
		_report_t = maxf(0.0, _report_t - delta)
		_report_label.modulate.a = clampf(_report_t / MSG_FADE, 0.0, 1.0)
		if _report_t <= 0.0:
			_report_label.visible = false
	if _warn_t > 0.0:
		_warn_t = maxf(0.0, _warn_t - delta)
		_warn_label.modulate.a = clampf(_warn_t / MSG_FADE, 0.0, 1.0)
		if _warn_t <= 0.0:
			_warn_label.visible = false

func _update_lamp_label() -> void:
	var color := PALE
	match lamp.state:
		Lamp.State.OFF:
			_lamp_label.text = "Lamp: unlit (lights at dusk)"
		Lamp.State.BURNING:
			# Say which beam, and that the focused one drinks oil, so it isn't left on by accident.
			if lamp.is_smothered():
				_lamp_label.text = "Lamp: SMOTHERED — harpoon it off the tower!"
				color = RED
			elif lamp.is_boosted():
				_lamp_label.text = "Lamp: BURNING HOT on dirty fuel (%ds)" % ceili(lamp.boost_left())
				color = Color(1.0, 0.45, 0.2)
			elif lamp.mode == Lamp.Mode.FOCUSED:
				_lamp_label.text = "Lamp: FOCUSED — burns oil fast"
				color = Color(1.0, 0.55, 0.25)
			else:
				_lamp_label.text = "Lamp: BURNING" + ("" if lamp.operator != null else " — sweeping, unmanned")
				color = AMBER
		Lamp.State.GUTTERING:
			_lamp_label.text = "Lamp: GUTTERING — refuel in %ds" % ceili(lamp.gutter_left())
			color = RED
		Lamp.State.DARK:
			_lamp_label.text = "Lamp: DARK"
			color = RED
	_lamp_label.add_theme_color_override("font_color", color)

func _mmss(seconds: float) -> String:
	var s := maxi(0, ceili(seconds))
	return "%02d:%02d" % [floori(s / 60.0), s % 60]

func _on_message(text: String) -> void:
	_msg_label.text = text
	_msg_label.modulate.a = 1.0
	_msg_t = MSG_TIME

func _show_warning(text: String) -> void:
	_warn_label.text = text
	_warn_label.visible = true
	_warn_label.modulate.a = 1.0
	_warn_t = WARN_TIME

## A centred warning, used by the foghorn alarms.
func warn(text: String) -> void:
	_show_warning(text)

## The keeper's log for the night just survived: a heading and a few lines under it.
func report(heading: String, lines: Array, time: float = REPORT_TIME) -> void:
	_show_warning(heading)
	_warn_t = time
	_report_label.text = "\n".join(lines)
	_report_label.visible = true
	_report_label.modulate.a = 1.0
	_report_t = time

func _on_phase_changed(p: int) -> void:
	if p == Cycle.Phase.DUSK:
		_show_warning(["A clear night. The fog is coming.", "Squalls coming in with the fog.", "A storm is coming."][Weather.tonight()])
	elif p == Cycle.Phase.NIGHT:
		_show_warning("They are coming.")

func _on_run_ended(reason: String, night: int) -> void:
	_over_reason.text = reason
	_over_stats.text = "Reached night %d · Best night %d" % [night, SaveSys.load_best()]
	_over.visible = true
	_prompt_label.text = ""

func _on_new_run() -> void:
	Run.quick_start = true
	Run.start_new()
	SaveSys.clear_run()
	get_tree().reload_current_scene()
