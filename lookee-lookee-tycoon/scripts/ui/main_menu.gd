extends Control
## Title screen: your vendor (or a random one) waving on the beach, shouting catchphrases.
## Continue / New Game / Settings / Credits / Quit (Quit is hidden on phones and browsers).

const SettingsPanel := preload("res://scripts/ui/settings_panel.gd")
const Credits := preload("res://studio/credits.gd")

var _view: Widgets.AvatarView
var _bubble: Label
var _bubble_panel: PanelContainer
var _shout_timer := 1.5
var _rng := RandomNumberGenerator.new()
var _confirm: Overlay


func _ready() -> void:
	_rng.randomize()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	GameManager.clear_pause()
	var has_save := SaveSystem.has_save()
	if has_save:
		SaveSystem.load_game()
	_build(has_save)
	AudioManager.play_music("beach")
	GameManager.back_pressed.connect(_on_back)


func _build(has_save: bool) -> void:
	var bg := Control.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.draw.connect(_draw_bg.bind(bg))
	add_child(bg)
	bg.set_process(true)
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
	var t := UITheme.title("LOOKEE LOOKEE\nTYCOON", 76)
	left.add_child(t)
	var sub := UITheme.label("The Chicken Nugget Tycoon", 30, UITheme.WHITE, 10)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(sub)
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.custom_minimum_size = Vector2(420, 0)
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
	settings.pressed.connect(func(): add_child(SettingsPanel.new()))
	row.add_child(settings)
	var credits := UITheme.button("Credits")
	credits.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	credits.pressed.connect(_credits)
	row.add_child(credits)
	if not (OS.has_feature("web") or OS.has_feature("mobile") or OS.has_feature("android")):
		var quit := UITheme.button("Quit", UITheme.SEA)
		quit.pressed.connect(func(): get_tree().quit())
		buttons.add_child(quit)
	var tip := UITheme.label("Tip: " + Lines.pick(Lines.TIPS), 18, UITheme.INK)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(tip)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 0.7
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(right)
	_bubble_panel = UITheme.panel(Color("#ffe14d"), 20)
	_bubble = UITheme.label(Lines.HELLO, 30)
	_bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bubble_panel.add_child(_bubble)
	_bubble_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	right.add_child(_bubble_panel)
	_view = Widgets.AvatarView.new()
	_view.custom_minimum_size = Vector2(320, 430)
	_view.zoom = 3.0
	if has_save:
		_view.follow_player = true
	else:
		_view.look = AppearanceOptions.random_appearance(_rng)
	right.add_child(_view)
	var stats := UITheme.label("", 18, UITheme.INK)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if has_save:
		stats.text = "%s  -  %s  -  %d beach%s" % [CharacterData.vendor_name(), Lines.money(Economy.cash), GameManager.owned_beaches.size(), "" if GameManager.owned_beaches.size() == 1 else "es"]
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
		var hello := _rng.randf() < 0.5
		_bubble.text = Lines.HELLO if hello else Lines.VERY_GOOD
		_view.avatar.shout(1.2)
		var pitch := CharacterData.voice_pitch() if _view.follow_player else float(_view.avatar.appearance.get("voice_pitch", 1.0))
		AudioManager.say("hello" if hello else "very_good", pitch, "menu", -4.0)


func _continue() -> void:
	if not GameManager.continue_game():
		GameManager.notify("Save not found. New game, chicken nugget!", "bad")
		GameManager.new_game()


func _new_game(has_save: bool) -> void:
	if not has_save:
		GameManager.new_game()
		return
	# Don't wipe a save by accident.
	_confirm = Overlay.new()
	_confirm.pause_game = false
	add_child(_confirm)
	var v: VBoxContainer = _confirm.card("Start again?", Vector2(640, 340))
	var l := UITheme.label("Your empire on day %d will be gone. Not very good, not very nice!" % GameManager.day, 22)
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
	yes.pressed.connect(_wipe_and_start)
	row.add_child(yes)


func _wipe_and_start() -> void:
	SaveSystem.delete_save()
	GameManager.new_game()


func _credits() -> void:
	Credits.open(self, "Lookee Lookee Tycoon", [
		"Made with Godot Engine (godotengine.org/license).",
		"All art, music and voices are generated in code.",
		"Hello chicken nugget! Very good very nice!",
	], UITheme.bold_font())


func _on_back() -> void:
	if not is_inside_tree() or not Overlay.stack.is_empty():
		return
	if OS.has_feature("android"):
		get_tree().quit()


func _draw_bg(c: Control) -> void:
	var s := c.size
	var t := Time.get_ticks_msec() / 1000.0
	c.draw_rect(Rect2(0, 0, s.x, s.y * 0.4), Color("#7fd3f7"))
	c.draw_circle(Vector2(s.x * 0.12, s.y * 0.14), 60, Color("#fff3b0"))
	c.draw_rect(Rect2(0, s.y * 0.4, s.x, s.y * 0.22), Color("#1e9bd7"))
	for i in 4:
		var y := s.y * (0.44 + i * 0.045)
		var pts := PackedVector2Array()
		for x in range(0, int(s.x) + 40, 40):
			pts.append(Vector2(x, y + sin(x * 0.02 + t * (1.0 + i * 0.3)) * 4.0))
		c.draw_polyline(pts, Color(1, 1, 1, 0.35), 3.0)
	c.draw_rect(Rect2(0, s.y * 0.62, s.x, s.y * 0.38), Color("#f7d89b"))
	var foam := PackedVector2Array()
	for x in range(0, int(s.x) + 30, 30):
		foam.append(Vector2(x, s.y * 0.62 + sin(x * 0.015 + t * 1.2) * 6.0))
	c.draw_polyline(foam, Color.WHITE, 6.0)
