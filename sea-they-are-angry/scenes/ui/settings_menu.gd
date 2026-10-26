extends Control
## The settings screen, from the title or the pause menu: sound, the window and the
## graphics, and keeper one's keys. Keyboard, mouse and gamepad navigable; changes
## take effect at once and are saved (Settings) when it closes.

signal closed

const GOLD := Color(1.0, 0.78, 0.42)
const PALE := Color(0.9, 0.92, 0.95)
const DIM := Color(0.7, 0.75, 0.8)
const BUS_NAMES := {"Master": "Volume", "Music": "Music", "SFX": "Sounds"}

var _box: VBoxContainer
var _scroll: ScrollContainer
var _note: Label
## The control waiting for a new key, and its row's button.
var _listening := ""
var _listen_btn: Button
var _bind_btns := {}
var _first: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.06, 0.92)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.offset_left = 90.0
	_scroll.offset_top = 60.0
	_scroll.offset_bottom = -60.0
	_scroll.offset_right = -90.0
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	add_child(_scroll)
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override("separation", 8)
	_scroll.add_child(_box)
	var t := _label(_box, "Settings", 52, GOLD)
	Fonts.use_title(t)

	_heading("Sound")
	for bus in Settings.VOLUMES:
		_slider(BUS_NAMES[bus], bus)

	_heading("Display")
	_cycler("Screen", func() -> String: return "Full screen" if Settings.fullscreen else "In a window",
		func(_d: int) -> void:
			Settings.fullscreen = not Settings.fullscreen
			Settings.apply_window())
	_cycler("Window size", func() -> String:
			var v: Vector2i = Settings.SIZES[Settings.size_idx]
			return "%d × %d" % [v.x, v.y],
		func(d: int) -> void:
			Settings.size_idx = wrapi(Settings.size_idx + d, 0, Settings.SIZES.size())
			Settings.apply_window())
	_cycler("Graphics", func() -> String: return Settings.QUALITY[Settings.quality],
		func(d: int) -> void:
			Settings.quality = wrapi(Settings.quality + d, 0, Settings.QUALITY.size())
			Settings.apply_graphics()
			_note.text = Settings.QUALITY_BLURBS[Settings.quality])
	_note = _label(_box, Settings.QUALITY_BLURBS[Settings.quality], 16, DIM)
	_cycler("Render scale", func() -> String: return "%d%%" % roundi(Settings.SCALES[Settings.scale_idx] * 100.0),
		func(d: int) -> void:
			Settings.scale_idx = clampi(Settings.scale_idx + d, 0, Settings.SCALES.size() - 1)
			Settings.apply_graphics())
	_label(_box, "Below 100% the world is drawn smaller and sharpened up: faster, a little softer.", 16, DIM)

	_heading("Keeper one's keys")
	_label(_box, "Pick a control, then press the key or mouse button for it (Esc to leave it). Two controls can't share a key: they swap. Gamepads keep their own layout: A use, X or RT swing, Y lamp, B beam, LT flare, LB dirty fuel, RB sprint, the right stick aims.", 16, DIM)
	for row in Settings.REBINDABLE:
		var a: String = row[0]
		var b := _button(_box, "", _listen.bind(a), 24)
		_bind_btns[a] = b
	_refresh_binds()
	_button(_box, "Put the keys back as they were", func() -> void:
		Settings.reset_controls()
		_refresh_binds(), 24)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 12)
	_box.add_child(gap)
	_button(_box, "Back", _close, 32)
	_first.grab_focus.call_deferred()

func _label(parent: Node, text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l

func _heading(text: String) -> void:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	_box.add_child(gap)
	var l := _label(_box, text, 30, GOLD)
	Fonts.use_title(l)

func _button(parent: Node, text: String, cb: Callable, size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.flat = true
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", PALE)
	b.add_theme_color_override("font_focus_color", GOLD)
	b.add_theme_color_override("font_hover_color", GOLD)
	b.focus_entered.connect(func() -> void: Audio.sfx("ui_move", Vector3.INF, -4.0, 0.0))
	b.pressed.connect(func() -> void:
		Audio.sfx("ui_accept", Vector3.INF, -2.0, 0.0)
		cb.call())
	parent.add_child(b)
	if _first == null:
		_first = b
	return b

## A row of a name and a slider (0 to 100) for one of the sound buses.
func _slider(text: String, bus: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	_box.add_child(row)
	var l := _label(row, text, 24, PALE)
	l.custom_minimum_size = Vector2(220, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 100.0
	s.step = 5.0
	s.value = roundf(float(Settings.volumes[bus]) * 100.0)
	s.custom_minimum_size = Vector2(360, 32)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(s)
	var pct := _label(row, "%d%%" % roundi(s.value), 22, DIM)
	pct.autowrap_mode = TextServer.AUTOWRAP_OFF
	s.value_changed.connect(func(v: float) -> void:
		Settings.set_volume(bus, v / 100.0)
		pct.text = "%d%%" % roundi(v)
		if bus != "Music":
			Audio.sfx("ui_move", Vector3.INF, -4.0, 0.0))
	s.focus_entered.connect(func() -> void: l.add_theme_color_override("font_color", GOLD))
	s.focus_exited.connect(func() -> void: l.add_theme_color_override("font_color", PALE))
	if _first == null:
		_first = s

## A button showing "Name:  ◀ value ▶": press or right for the next value, left for the last.
func _cycler(text: String, value: Callable, change: Callable) -> void:
	var b := _button(_box, "", Callable(), 24)
	var show := func() -> void: b.text = "%s:  ◀ %s ▶" % [text, value.call()]
	show.call()
	# Replace the plain press with a step forward.
	for c in b.pressed.get_connections():
		b.pressed.disconnect(c["callable"])
	b.pressed.connect(func() -> void:
		Audio.sfx("ui_accept", Vector3.INF, -2.0, 0.0)
		change.call(1)
		show.call())
	b.gui_input.connect(func(ev: InputEvent) -> void:
		var d := -1 if ev.is_action_pressed("ui_left") else (1 if ev.is_action_pressed("ui_right") else 0)
		if d != 0:
			change.call(d)
			show.call()
			Audio.sfx("ui_move", Vector3.INF, -4.0, 0.0)
			b.accept_event())

func _refresh_binds() -> void:
	for row in Settings.REBINDABLE:
		var a: String = row[0]
		var b: Button = _bind_btns[a]
		var key := "press a key…" if a == _listening else Settings.key_name(a)
		b.text = "%s:  %s" % [row[1], key]

func _listen(action: String) -> void:
	# Wait a frame, so the press that picked the row isn't taken as its new key.
	await get_tree().process_frame
	_listening = action
	_listen_btn = _bind_btns[action]
	_refresh_binds()

func _input(ev: InputEvent) -> void:
	if _listening == "":
		return
	var code := Settings.code_of(ev)
	var cancel: bool = ev is InputEventKey and ev.pressed and (ev.keycode == KEY_ESCAPE or ev.physical_keycode == KEY_ESCAPE) \
		or ev is InputEventJoypadButton and ev.pressed and ev.button_index == JOY_BUTTON_B
	if code == "" and not cancel:
		return
	get_viewport().set_input_as_handled()
	if code in Settings.RESERVED:
		# The number keys pick the weapons; Esc pauses. Keep waiting for another.
		return
	var a := _listening
	_listening = ""
	if not cancel:
		Settings.rebind(a, code)
		Audio.sfx("ui_accept", Vector3.INF, -2.0, 0.0)
	_refresh_binds()
	if is_instance_valid(_listen_btn):
		_listen_btn.grab_focus()

func _unhandled_input(ev: InputEvent) -> void:
	if _listening == "" and (ev.is_action_pressed("ui_cancel") or ev.is_action_pressed("pause")):
		get_viewport().set_input_as_handled()
		_close()

func _close() -> void:
	Settings.save()
	closed.emit()
	queue_free()
