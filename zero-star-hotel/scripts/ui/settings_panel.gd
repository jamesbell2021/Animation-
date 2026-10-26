extends Overlay
## Settings: volumes, graphics quality (Auto picks for your device), FPS counter, and a
## way to wipe the save. Saved to user://settings.cfg straight away.


func _init() -> void:
	super._init()
	pause_game = false


func build() -> void:
	var v := card("Settings", Vector2(760, 640))
	_slider(v, "Music", "music")
	_slider(v, "Sound effects", "sfx")
	_slider(v, "Voices (Oi oi!)", "voice")
	v.add_child(UITheme.label("Graphics quality", 22))
	var q := HBoxContainer.new()
	q.add_theme_constant_override("separation", 8)
	v.add_child(q)
	var names := ["Auto", "Low", "Medium", "High"]
	for i in names.size():
		var value := i - 1
		var b := UITheme.button(names[i], UITheme.TERRACOTTA if int(SaveSystem.settings.quality) == value else UITheme.SEA, Vector2(0, 64), 20)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_set_quality.bind(value))
		q.add_child(b)
	v.add_child(UITheme.label("Now: %s (%d people on screen max)" % [Quality.tier_name(), Quality.max_walkers], 16, UITheme.SEA_DARK))
	var fps := CheckButton.new()
	fps.text = "Show FPS"
	fps.button_pressed = bool(SaveSystem.settings.show_fps)
	fps.add_theme_font_size_override("font_size", 22)
	fps.add_theme_color_override("font_color", UITheme.INK)
	fps.toggled.connect(func(on: bool): SaveSystem.set_setting("show_fps", on))
	v.add_child(fps)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	v.add_child(h)
	var done := UITheme.button("Done", UITheme.LIME, Vector2(0, 64), 24)
	done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	done.pressed.connect(close)
	h.add_child(done)


func _slider(v: VBoxContainer, label: String, key: String) -> void:
	v.add_child(UITheme.label(label, 22))
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = float(SaveSystem.settings[key])
	s.custom_minimum_size = Vector2(0, 48)
	s.value_changed.connect(func(x: float): SaveSystem.set_setting(key, x))
	s.drag_ended.connect(_preview.bind(key).unbind(1))
	v.add_child(s)


func _preview(key: String) -> void:
	if key == "sfx":
		AudioManager.play_sfx("coin")
	else:
		AudioManager.say("oi_oi", -1.0, "settings")


func _set_quality(value: int) -> void:
	SaveSystem.set_setting("quality", value)
	for c in root.get_children():
		if c != root.get_child(0):
			c.queue_free()
	build()

