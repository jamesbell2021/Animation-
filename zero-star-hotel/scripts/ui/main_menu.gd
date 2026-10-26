extends Control
## Title screen: a dodgy hotel at sunset with a flickering sign, your manager out front and a
## lad on the balcony shouting. Continue / New Game (name your hotel) / Settings / Credits.

const SettingsPanel := preload("res://scripts/ui/settings_panel.gd")
const Credits := preload("res://studio/credits.gd")

const SHOUTS := [["OI OI!", "oi_oi"], ["Ere we go!", "ere_we_go"], ["Cheers!", "cheers"], ["WOOO!", "woo"], ["Housekeeping!", "housekeeping"]]

var _view: Widgets.AvatarView
var _bubble: Label
var _shout_timer := 1.5
var _rng := RandomNumberGenerator.new()
var _confirm: Overlay
var _name_edit: LineEdit


func _ready() -> void:
	_rng.randomize()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	GameManager.clear_pause()
	var has_save := SaveSystem.has_save()
	if has_save:
		SaveSystem.load_game()
	_build(has_save)
	AudioManager.play_music("day")
	GameManager.back_pressed.connect(_on_back)


func _build(has_save: bool) -> void:
	var bg := Control.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.draw.connect(_draw_bg.bind(bg))
	add_child(bg)
	var tick := Timer.new()
	tick.wait_time = 0.05
	tick.autostart = true
	tick.timeout.connect(bg.queue_redraw)
	add_child(tick)

	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 30
	h.offset_right = -30
	h.offset_top = 20
	h.offset_bottom = -20
	add_child(h)
	UITheme.safe_margins(h)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 12)
	h.add_child(left)
	left.add_child(UITheme.title("ZERO STAR\nHOTEL", 84))
	var sub := UITheme.label("From health hazard to three stars", 28, UITheme.WHITE, 10)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(sub)
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.custom_minimum_size = Vector2(440, 0)
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	left.add_child(buttons)
	if has_save:
		var cont := UITheme.button("CONTINUE  (Day %d)" % GameManager.day, UITheme.LIME, Vector2(0, 84), 30)
		cont.pressed.connect(_continue)
		buttons.add_child(cont)
	var new_btn := UITheme.button("NEW GAME", UITheme.TERRACOTTA if has_save else UITheme.LIME, Vector2(0, 84), 30)
	new_btn.pressed.connect(_new_game.bind(has_save))
	buttons.add_child(new_btn)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	buttons.add_child(row)
	var settings := UITheme.button("Settings")
	settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings.pressed.connect(_settings)
	row.add_child(settings)
	var credits := UITheme.button("Credits")
	credits.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	credits.pressed.connect(_credits)
	row.add_child(credits)
	if not (OS.has_feature("web") or OS.has_feature("mobile") or OS.has_feature("android")):
		var quit := UITheme.button("Quit", UITheme.SEA)
		quit.pressed.connect(get_tree().quit)
		buttons.add_child(quit)
	var tip := UITheme.label("Tip: " + Lines.pick(Lines.TIPS, _rng), 18, UITheme.WHITE, 6)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(tip)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 0.7
	right.alignment = BoxContainer.ALIGNMENT_END
	h.add_child(right)
	var bubble_panel := UITheme.panel(Color("#ffe14d"), 20)
	_bubble = UITheme.label("Welcome!", 30)
	_bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble_panel.add_child(_bubble)
	bubble_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	right.add_child(bubble_panel)
	_view = Widgets.AvatarView.new()
	_view.custom_minimum_size = Vector2(320, 430)
	_view.zoom = 3.0
	_view.follow_player = true
	right.add_child(_view)
	var stats := UITheme.label("", 20, UITheme.WHITE, 6)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if has_save:
		stats.text = "%s  -  %s  -  %s" % [Hotel.name_of_hotel, Lines.money(Economy.cash), Lines.STAR_NAMES[Hotel.stars]]
	right.add_child(stats)
	var studio := UITheme.label("3BL_Indie", 18, Color(1, 1, 1, 0.85), 6)
	studio.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	studio.offset_left = -140
	studio.offset_top = -40
	add_child(studio)


func _process(delta: float) -> void:
	_shout_timer -= delta
	if _shout_timer <= 0.0 and _view and _view.avatar:
		_shout_timer = _rng.randf_range(3.5, 6.0)
		var s: Array = SHOUTS[_rng.randi() % SHOUTS.size()]
		_bubble.text = s[0]
		_view.avatar.shout(1.2)
		AudioManager.say(s[1], _rng.randf_range(0.85, 1.2), "menu", -4.0)


func _continue() -> void:
	if not GameManager.continue_game():
		GameManager.notify("Save not found. Starting fresh!", "bad")
		_ask_name()


func _new_game(has_save: bool) -> void:
	if not has_save:
		_ask_name()
		return
	# Don't wipe a save by accident.
	_confirm = Overlay.new()
	_confirm.pause_game = false
	add_child(_confirm)
	var v: VBoxContainer = _confirm.card("Start again?", Vector2(640, 340))
	var l := UITheme.label("%s on day %d will be bulldozed. The cockroaches will survive." % [Hotel.name_of_hotel, GameManager.day], 22)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var no := UITheme.button("Keep it", UITheme.LIME, Vector2(0, 76))
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	no.pressed.connect(_confirm.close)
	row.add_child(no)
	var yes := UITheme.button("New game!", UITheme.DANGER, Vector2(0, 76))
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yes.pressed.connect(_wipe_and_ask)
	row.add_child(yes)


func _wipe_and_ask() -> void:
	SaveSystem.delete_save()
	_confirm.close()
	_ask_name()


## Name your hotel (or keep the glorious default) before the keys are handed over.
func _ask_name() -> void:
	var o := Overlay.new()
	o.pause_game = false
	add_child(o)
	var v: VBoxContainer = o.card("Name your hotel", Vector2(700, 400))
	var l := UITheme.label("You've bought the worst hotel on the Costa. Zero stars. It has a pool (technically).", 20)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	_name_edit = LineEdit.new()
	_name_edit.text = Lines.HOTEL_DEFAULT_NAME
	_name_edit.max_length = 24
	_name_edit.custom_minimum_size = Vector2(0, 70)
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_edit.add_theme_font_size_override("font_size", 30)
	_name_edit.select_all_on_focus = true
	_name_edit.text_submitted.connect(_start.unbind(1))
	v.add_child(_name_edit)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var dice := UITheme.button("Random", UITheme.LEMON, Vector2(0, 76))
	dice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dice.pressed.connect(_random_name)
	row.add_child(dice)
	var go := UITheme.button("GET THE KEYS", UITheme.LIME, Vector2(0, 76))
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.pressed.connect(_start)
	row.add_child(go)


func _random_name() -> void:
	_name_edit.text = Lines.pick(Lines.HOTEL_NAMES, _rng)


func _start() -> void:
	GameManager.new_game(_name_edit.text)


func _settings() -> void:
	add_child(SettingsPanel.new())


func _credits() -> void:
	Credits.open(self, "Zero Star Hotel", [
		"Made with Godot Engine (godotengine.org/license).",
		"All art, music and voices are generated in code.",
		"No cockroaches were harmed. Well, a few.",
	], UITheme.bold_font())


func _on_back() -> void:
	if not is_inside_tree() or not Overlay.stack.is_empty():
		return
	if OS.has_feature("android"):
		get_tree().quit()


## Sunset, the sea, and the hotel itself: three grubby floors, one flickering sign.
func _draw_bg(c: Control) -> void:
	var s := c.size
	var t := Time.get_ticks_msec() / 1000.0
	for i in 6:
		var y0 := s.y * 0.11 * i
		c.draw_rect(Rect2(0, y0, s.x, s.y * 0.11 + 1), Color("#ff9e5e").lerp(Color("#6a4c93"), 1.0 - i / 5.0))
	c.draw_circle(Vector2(s.x * 0.45, s.y * 0.6), 90, Color("#ffd166"))
	c.draw_rect(Rect2(0, s.y * 0.62, s.x, s.y * 0.12), Color("#1e7fb8"))
	for i in 3:
		var y := s.y * (0.64 + i * 0.03)
		var pts := PackedVector2Array()
		for x in range(0, int(s.x) + 40, 40):
			pts.append(Vector2(x, y + sin(x * 0.02 + t * (1.0 + i * 0.3)) * 3.0))
		c.draw_polyline(pts, Color(1, 1, 1, 0.3), 3.0)
	c.draw_rect(Rect2(0, s.y * 0.74, s.x, s.y * 0.26), Color("#e8c98a"))
	# The hotel, behind the manager on the right.
	var hx := s.x * 0.58
	var hw := s.x * 0.36
	var top := s.y * 0.2
	var base := s.y * 0.8
	c.draw_rect(Rect2(hx, top, hw, base - top), Color("#d9b48f"))
	c.draw_rect(Rect2(hx, top, hw, base - top), UITheme.INK, false, 4.0)
	# Damp stains.
	c.draw_circle(Vector2(hx + hw * 0.2, top + 60), 34, Color(0.45, 0.4, 0.3, 0.25))
	c.draw_circle(Vector2(hx + hw * 0.8, top + 190), 44, Color(0.45, 0.4, 0.3, 0.25))
	for f in 3:
		for k in 4:
			var wr := Rect2(hx + 18 + k * (hw - 36) / 4.0, top + 34 + f * (base - top - 60) / 3.0, (hw - 36) / 4.0 - 14, 60)
			var lit := (int(t * 0.7) + f * 3 + k) % 5 != 0
			c.draw_rect(wr, Color("#ffe08a") if lit else Color("#3b3f5c"))
			c.draw_rect(wr, UITheme.INK, false, 3.0)
			if (f + k) % 3 == 1:
				c.draw_line(wr.position, wr.end, UITheme.INK, 2.0)   # cracked pane
	# Flickering sign with zero stars.
	var flick := 1.0 if fmod(t, 3.1) > 0.25 else 0.25
	var sign_r := Rect2(hx + hw * 0.15, top - 54, hw * 0.7, 46)
	c.draw_rect(sign_r, Color("#2b1d16"))
	c.draw_string(UITheme.bold_font(), sign_r.position + Vector2(10, 34), "HOTEL  - 0 STARS -", HORIZONTAL_ALIGNMENT_CENTER, sign_r.size.x - 20, 26, Color(1, 0.35, 0.5, flick))
