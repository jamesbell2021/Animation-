extends Control
## The Character Creator. Shown when starting a new game, and from the pause menu ("Edit My
## Vendor") at any time. Big live preview on the left, categories on the right:
##   Skin   - 20 swatches across the full range plus a continuous tone slider and undertone
##   Hair   - 13 styles, 24-colour palette plus a custom colour picker
##   Face   - eyes (and eye colour), brows, nose, mouth, facial hair
##   Body   - slim, average, large, muscular
##   Outfit - shirt, bottoms, shoes, each with colours
##   Extras - hats (with colour), glasses, chains, watches, earrings, bags
##   Voice  - pitch of "Hello chicken nugget!" / "Very good very nice!"
## Every change updates the preview instantly. Confirm saves the look into CharacterData
## (and the save file); every VendorAvatar following CharacterData updates at once.

signal finished

const TABS := ["Skin", "Hair", "Face", "Body", "Outfit", "Extras", "Voice"]

var working: Dictionary = {}
var mode := "new"

var _tab := 0
var _tab_buttons: Array[Button] = []
var _content: VBoxContainer
var _scroll: ScrollContainer
var _preview: Widgets.AvatarView
var _bubble: Label
var _bubble_panel: PanelContainer
var _name_edit: LineEdit
var _value_labels := {}        # key -> Label
var _swatches := {}            # key -> Array of [Button, Color]
var _tone_slider: HSlider
var _undertone_slider: HSlider
var _last_reaction := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mode = GameManager.creator_mode
	if mode == "new":
		working = AppearanceOptions.random_appearance(_rng)
	else:
		working = CharacterData.appearance.duplicate()
	_build()
	_set_tab(0)
	_update_preview(false)
	_react(Lines.CREATOR_TITLE)
	if mode == "new":
		AudioManager.play_music("beach")
		GameManager.back_pressed.connect(_on_back)


func _on_back() -> void:
	if is_inside_tree() and mode == "new" and Overlay.stack.is_empty():
		GameManager.goto_menu()


# --- Layout ------------------------------------------------------------------------------------

func _build() -> void:
	var bg := Control.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.draw.connect(_draw_background.bind(bg))
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var main := HBoxContainer.new()
	main.set_anchors_preset(Control.PRESET_FULL_RECT)
	main.offset_left = 14
	main.offset_right = -14
	main.offset_top = 10
	main.offset_bottom = -10
	main.add_theme_constant_override("separation", 14)
	add_child(main)
	UITheme.safe_margins(main)

	# Left: preview.
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.8
	left.add_theme_constant_override("separation", 8)
	main.add_child(left)
	var title := UITheme.title("Lookee Lookee Creator", 38)
	left.add_child(title)
	_bubble_panel = UITheme.panel(Color("#fffaf0"), 18)
	_bubble = UITheme.label("", 22)
	_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bubble_panel.add_child(_bubble)
	left.add_child(_bubble_panel)
	var stage := Button.new()
	stage.flat = true
	stage.focus_mode = Control.FOCUS_NONE
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.custom_minimum_size = Vector2(0, 300)
	stage.draw.connect(_draw_stage.bind(stage))
	stage.pressed.connect(_say_it)
	for s: String in ["normal", "hover", "pressed", "focus"]:
		stage.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	left.add_child(stage)
	_preview = Widgets.AvatarView.new()
	_preview.zoom = 0.0  # fit to height
	_preview.set_anchors_preset(Control.PRESET_FULL_RECT)
	_preview.look = working
	stage.add_child(_preview)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	left.add_child(name_row)
	name_row.add_child(UITheme.label("Name:", 22))
	_name_edit = LineEdit.new()
	_name_edit.text = str(working.get("name", ""))
	_name_edit.max_length = 24
	_name_edit.placeholder_text = "Your name, chicken nugget?"
	_name_edit.custom_minimum_size = Vector2(0, 60)
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.add_theme_font_size_override("font_size", 24)
	_name_edit.text_changed.connect(func(t: String): working.name = t)
	name_row.add_child(_name_edit)
	var dice := UITheme.button("?", UITheme.LEMON, Vector2(64, 60), 26)
	dice.tooltip_text = "Random name"
	dice.pressed.connect(_random_name)
	name_row.add_child(dice)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	left.add_child(row)
	var rnd := UITheme.button("RANDOMISE!", UITheme.LEMON, Vector2(0, 72), 26)
	rnd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rnd.pressed.connect(_randomise)
	row.add_child(rnd)
	var say := UITheme.button("SAY IT!", UITheme.SEA, Vector2(0, 72), 26)
	say.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	say.pressed.connect(_say_it)
	row.add_child(say)

	# Right: categories.
	var right := UITheme.panel(Color(1, 0.97, 0.9, 0.95))
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(right)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 8)
	right.add_child(rv)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	rv.add_child(tabs)
	for i in TABS.size():
		var b := UITheme.button(TABS[i], UITheme.SEA, Vector2(0, 62), 19)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_stylebox_override("normal", UITheme.box(UITheme.SEA, 14, 3, UITheme.SEA_DARK))
		b.pressed.connect(_set_tab.bind(i))
		tabs.add_child(b)
		_tab_buttons.append(b)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.scroll_deadzone = 12
	rv.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 10)
	_scroll.add_child(_content)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	rv.add_child(bottom)
	var back := UITheme.button("Back" if mode == "new" else "Cancel", UITheme.TERRACOTTA, Vector2(150, 80), 24)
	back.pressed.connect(_cancel)
	bottom.add_child(back)
	var confirm := UITheme.button("VERY GOOD VERY NICE! LET'S GO!" if mode == "new" else "VERY GOOD VERY NICE! DONE!", UITheme.LIME, Vector2(0, 80), 24)
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm.pressed.connect(_confirm)
	bottom.add_child(confirm)


func _set_tab(i: int) -> void:
	_tab = i
	for k in _tab_buttons.size():
		UITheme.tint_button(_tab_buttons[k], UITheme.TERRACOTTA if k == i else UITheme.SEA)
	for c in _content.get_children():
		c.queue_free()
	_value_labels.clear()
	_swatches.clear()
	_tone_slider = null
	_undertone_slider = null
	match TABS[i]:
		"Skin": _build_skin()
		"Hair": _build_hair()
		"Face": _build_face()
		"Body": _build_body()
		"Outfit": _build_outfit()
		"Extras": _build_extras()
		"Voice": _build_voice()
	_scroll.scroll_vertical = 0


# --- Sections -----------------------------------------------------------------------------------

func _heading(text: String) -> void:
	_content.add_child(UITheme.label(text, 22, UITheme.SEA_DARK))


func _build_skin() -> void:
	_heading("Skin tone: any shade you like, chicken nugget!")
	var tones := AppearanceOptions.skin_swatch_tones()
	var grid := GridContainer.new()
	grid.columns = 10
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	_content.add_child(grid)
	_swatches["skin"] = []
	for t in tones:
		var col := AppearanceOptions.skin_color(t, 0.0)
		var b := _swatch_button(col)
		b.pressed.connect(_set_skin_tone.bind(t, true))
		grid.add_child(b)
		_swatches["skin"].append([b, col])
	_heading("Fine tune: light to dark")
	var g := TextureRect.new()
	var gt := GradientTexture2D.new()
	gt.gradient = AppearanceOptions.skin_gradient()
	gt.width = 256
	gt.height = 8
	g.texture = gt
	g.custom_minimum_size = Vector2(0, 26)
	g.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	g.stretch_mode = TextureRect.STRETCH_SCALE
	_content.add_child(g)
	_tone_slider = _slider(0.0, 1.0, float(working.skin_tone), 0.005)
	_tone_slider.value_changed.connect(func(v: float): _set_skin_tone(v, false))
	_heading("Undertone: rosy <-> olive")
	_undertone_slider = _slider(-1.0, 1.0, float(working.undertone), 0.02)
	_undertone_slider.value_changed.connect(_set_undertone)
	_refresh_swatches()


func _build_hair() -> void:
	_option_row("Hair style", "hair_style", AppearanceOptions.HAIR_STYLES)
	_choice_grid("hair_style", AppearanceOptions.HAIR_STYLES, 4)
	_heading("Hair colour")
	_color_grid("hair_color", AppearanceOptions.HAIR_PALETTE, 12)
	_custom_color("hair_color")


func _build_face() -> void:
	_option_row("Eyes", "eyes", AppearanceOptions.EYES)
	_heading("Eye colour")
	_color_grid("eye_color", AppearanceOptions.EYE_PALETTE, 10)
	_option_row("Eyebrows", "brows", AppearanceOptions.BROWS)
	_option_row("Nose", "nose", AppearanceOptions.NOSES)
	_option_row("Mouth", "mouth", AppearanceOptions.MOUTHS)
	_option_row("Facial hair", "facial_hair", AppearanceOptions.FACIAL_HAIR)


func _build_body() -> void:
	_heading("Body type: every body is a beach body!")
	_choice_grid("body", AppearanceOptions.BODY_TYPES, 2, 96)


func _build_outfit() -> void:
	_option_row("Shirt", "shirt", AppearanceOptions.SHIRTS)
	_color_grid("shirt_color", AppearanceOptions.CLOTH_PALETTE, 9)
	_custom_color("shirt_color")
	_option_row("Shorts & trousers", "bottoms", AppearanceOptions.BOTTOMS)
	_color_grid("bottoms_color", AppearanceOptions.CLOTH_PALETTE, 9)
	_option_row("Shoes", "shoes", AppearanceOptions.SHOES)
	_color_grid("shoes_color", AppearanceOptions.CLOTH_PALETTE, 9)


func _build_extras() -> void:
	_option_row("Hat", "hat", AppearanceOptions.HATS)
	_color_grid("hat_color", AppearanceOptions.CLOTH_PALETTE, 9)
	_option_row("Sunglasses", "glasses", AppearanceOptions.GLASSES)
	_option_row("Chain", "chain", AppearanceOptions.CHAINS)
	_option_row("Watches", "watch", AppearanceOptions.WATCHES)
	_option_row("Earrings", "earrings", AppearanceOptions.EARRINGS)
	_option_row("Bag", "bag", AppearanceOptions.BAGS)


func _build_voice() -> void:
	_heading("Voice pitch: deep and smooth... or squeaky and loud!")
	var s := _slider(AppearanceOptions.VOICE_MIN, AppearanceOptions.VOICE_MAX, float(working.voice_pitch), 0.05)
	s.value_changed.connect(func(v: float): working.voice_pitch = v)
	s.drag_ended.connect(func(_c): AudioManager.say("hello", float(working.voice_pitch), "creator"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_content.add_child(row)
	var a := UITheme.button("\"Hello chicken nugget!\"", UITheme.SEA, Vector2(0, 80), 22)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a.pressed.connect(_say_line.bind("hello", Lines.HELLO))
	row.add_child(a)
	var b := UITheme.button("\"Very good very nice!\"", UITheme.SEA, Vector2(0, 80), 22)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(_say_line.bind("very_good", Lines.VERY_GOOD))
	row.add_child(b)
	var hint := UITheme.label("Your voice is used for every shout and every sale. Very good very nice!", 18, Color("#5d4037"))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(hint)


# --- Widgets ------------------------------------------------------------------------------------

func _option_row(label: String, key: String, options: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_content.add_child(row)
	var l := UITheme.label(label, 22)
	l.custom_minimum_size = Vector2(190, 0)
	row.add_child(l)
	var prev := UITheme.button("<", UITheme.SEA, Vector2(76, 64), 30)
	prev.pressed.connect(_step_option.bind(key, options.size(), -1))
	row.add_child(prev)
	var value := UITheme.label("", 22, UITheme.TERRACOTTA)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(value)
	var next := UITheme.button(">", UITheme.SEA, Vector2(76, 64), 30)
	next.pressed.connect(_step_option.bind(key, options.size(), 1))
	row.add_child(next)
	_value_labels[key] = [value, options]
	_refresh_values()


## Every option as its own big button (used for hair and body type).
func _choice_grid(key: String, options: Array, columns: int, height := 60) -> void:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	_content.add_child(grid)
	_swatches[key + "#choice"] = []
	for i in options.size():
		var b := UITheme.button(str(options[i]), UITheme.SEA, Vector2(0, height), 18)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_set_value.bind(key, i))
		grid.add_child(b)
		_swatches[key + "#choice"].append([b, i])
	_refresh_swatches()


func _color_grid(key: String, palette: Array, columns: int) -> void:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	_content.add_child(grid)
	_swatches[key] = []
	for col in palette:
		var b := _swatch_button(col)
		b.pressed.connect(_set_value.bind(key, (col as Color).to_html(false)))
		grid.add_child(b)
		_swatches[key].append([b, col])
	_refresh_swatches()


func _custom_color(key: String) -> void:
	var row := HBoxContainer.new()
	_content.add_child(row)
	var picker := ColorPickerButton.new()
	picker.text = "Custom colour..."
	picker.custom_minimum_size = Vector2(260, 60)
	picker.color = AppearanceOptions.color_of(working, key)
	picker.edit_alpha = false
	picker.add_theme_font_size_override("font_size", 20)
	picker.color_changed.connect(func(c: Color): _set_value(key, c.to_html(false), false))
	picker.picker_created.connect(_tune_picker.bind(picker))
	row.add_child(picker)


## Big, simple colour picker for fingers.
func _tune_picker(picker: ColorPickerButton) -> void:
	var cp := picker.get_picker()
	cp.picker_shape = ColorPicker.SHAPE_HSV_RECTANGLE
	cp.presets_visible = false
	cp.custom_minimum_size = Vector2(360, 300)


func _swatch_button(col: Color) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(56, 56)
	b.focus_mode = Control.FOCUS_NONE
	_style_swatch(b, col, false)
	return b


func _style_swatch(b: Button, col: Color, selected: bool) -> void:
	var s := UITheme.box(col, 12, 6 if selected else 2, UITheme.LEMON if selected else UITheme.INK)
	s.border_width_bottom = 6 if selected else 2
	for state: String in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(state, s)


func _slider(min_v: float, max_v: float, value: float, step: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(0, 52)
	_content.add_child(s)
	return s


# --- Changes ------------------------------------------------------------------------------------

func _step_option(key: String, count: int, dir: int) -> void:
	_set_value(key, posmod(int(working.get(key, 0)) + dir, count))


func _set_value(key: String, value: Variant, react := true) -> void:
	working[key] = value
	_update_preview(react)
	_refresh_values()
	_refresh_swatches()


func _set_skin_tone(t: float, from_swatch: bool) -> void:
	working.skin_tone = t
	if from_swatch:
		working.undertone = 0.0
		if _undertone_slider:
			_undertone_slider.set_value_no_signal(0.0)
		if _tone_slider:
			_tone_slider.set_value_no_signal(t)
	working.skin = AppearanceOptions.skin_color(t, float(working.undertone)).to_html(false)
	_update_preview(from_swatch)
	_refresh_swatches()


func _set_undertone(u: float) -> void:
	working.undertone = u
	working.skin = AppearanceOptions.skin_color(float(working.skin_tone), u).to_html(false)
	_update_preview(false)


func _refresh_values() -> void:
	for key in _value_labels:
		var pair: Array = _value_labels[key]
		var opts: Array = pair[1]
		(pair[0] as Label).text = str(opts[clampi(int(working.get(key, 0)), 0, opts.size() - 1)])


func _refresh_swatches() -> void:
	for key in _swatches:
		for pair in _swatches[key]:
			var b: Button = pair[0]
			if key.ends_with("#choice"):
				var k: String = key.trim_suffix("#choice")
				UITheme.tint_button(b, UITheme.TERRACOTTA if int(working.get(k, 0)) == int(pair[1]) else UITheme.SEA)
			elif key == "skin":
				var tone_col: Color = pair[1]
				_style_swatch(b, tone_col, AppearanceOptions.skin_color(float(working.skin_tone), 0.0).is_equal_approx(tone_col))
			else:
				var c: Color = pair[1]
				_style_swatch(b, c, AppearanceOptions.color_of(working, key).to_html(false) == c.to_html(false))


func _update_preview(react: bool) -> void:
	working = AppearanceOptions.sanitize(working)
	_preview.set_look(working)
	if react:
		var now := Time.get_ticks_msec()
		if now - _last_reaction > 900:
			_last_reaction = now
			_react(Lines.pick(Lines.CREATOR_REACTIONS, _rng))
			_preview.avatar.present(0.6)
		AudioManager.play_sfx("tap", 0.15, -4.0)


func _react(text: String) -> void:
	_bubble.text = text
	_bubble_panel.pivot_offset = _bubble_panel.size * 0.5
	var tw := create_tween()
	tw.tween_property(_bubble_panel, "scale", Vector2(1.06, 1.06), 0.07)
	tw.tween_property(_bubble_panel, "scale", Vector2.ONE, 0.12)


func _randomise() -> void:
	var keep_name := str(working.get("name", ""))
	working = AppearanceOptions.random_appearance(_rng)
	if keep_name != "" and _rng.randf() < 0.5:
		working.name = keep_name
	_name_edit.text = str(working.name)
	_set_tab(_tab)
	_update_preview(false)
	_react(Lines.pick(Lines.CREATOR_RANDOM, _rng))
	_preview.avatar.shout(0.8)
	AudioManager.play_sfx("upgrade", 0.1)


func _random_name() -> void:
	working.name = Lines.VENDOR_NAMES[_rng.randi() % Lines.VENDOR_NAMES.size()]
	_name_edit.text = working.name


func _say_it() -> void:
	if _rng.randf() < 0.5:
		_say_line("hello", Lines.HELLO)
	else:
		_say_line("very_good", Lines.VERY_GOOD)


func _say_line(id: String, text: String) -> void:
	_preview.avatar.shout(1.3)
	_react(text)
	AudioManager.say(id, float(working.voice_pitch), "creator")


func _confirm() -> void:
	working.name = _name_edit.text.strip_edges()
	CharacterData.set_appearance(working)
	AudioManager.say("very_good", float(working.voice_pitch), "creator")
	AudioManager.play_sfx("upgrade")
	if mode == "new":
		GameManager.creator_confirmed()
	else:
		SaveSystem.save_game()
		GameManager.notify(Lines.CREATOR_CONFIRM, "good")
		finished.emit()


func _cancel() -> void:
	if mode == "new":
		GameManager.goto_menu()
	else:
		finished.emit()


# --- Drawing --------------------------------------------------------------------------------------

func _draw_background(c: Control) -> void:
	var s := c.size
	c.draw_rect(Rect2(0, 0, s.x, s.y * 0.35), Color("#7fd3f7"))
	c.draw_rect(Rect2(0, s.y * 0.35, s.x, s.y * 0.2), Color("#1e9bd7"))
	c.draw_rect(Rect2(0, s.y * 0.55, s.x, s.y * 0.45), Color("#f7d89b"))
	c.draw_circle(Vector2(s.x * 0.85, s.y * 0.12), 50, Color("#fff3b0"))
	for i in 5:
		c.draw_line(Vector2(0, s.y * (0.4 + i * 0.03)), Vector2(s.x, s.y * (0.4 + i * 0.03)), Color(1, 1, 1, 0.25), 2.0)


func _draw_stage(c: Control) -> void:
	var s := c.size
	c.draw_colored_polygon(VendorAvatar._ellipse(Vector2(s.x * 0.5, s.y - 14), s.x * 0.36, 22, 28), Color(0.8, 0.6, 0.35, 0.55))
	c.draw_polyline(VendorAvatar._ellipse(Vector2(s.x * 0.5, s.y - 14), s.x * 0.36, 22, 28) + PackedVector2Array([Vector2(s.x * 0.5 + s.x * 0.36, s.y - 14)]), Color(1, 1, 1, 0.6), 3.0, true)
