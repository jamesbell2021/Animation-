extends Overlay
## Pause menu (also what the Android back button opens during play): resume, give your
## manager a new look, settings, or save and quit to the title screen.

const SettingsPanel := preload("res://scripts/ui/settings_panel.gd")

var _name_label: Label


func build() -> void:
	var v := card("Paused. Have a lie down.", Vector2(720, 0))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	v.add_child(h)
	var view := Widgets.AvatarView.new()
	view.follow_player = true
	view.custom_minimum_size = Vector2(200, 330)
	view.zoom = 2.0
	h.add_child(view)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 12)
	h.add_child(col)
	_name_label = UITheme.label("%s, manager of %s" % [CharacterData.appearance.get("name", "You"), Hotel.name_of_hotel], 22, UITheme.TERRACOTTA)
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_name_label)
	var resume := UITheme.button("RESUME", UITheme.LIME, Vector2(0, 80), 30)
	resume.pressed.connect(close)
	col.add_child(resume)
	var look := UITheme.button("New Manager Look", UITheme.LEMON)
	look.pressed.connect(CharacterData.reroll)
	col.add_child(look)
	var settings := UITheme.button("Settings")
	settings.pressed.connect(_settings)
	col.add_child(settings)
	var quit := UITheme.button("Save & Quit to Menu", UITheme.TERRACOTTA)
	quit.pressed.connect(_quit)
	col.add_child(quit)
	var tip := UITheme.label("Tip: " + Lines.pick(Lines.TIPS), 17, UITheme.SEA_DARK)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(tip)


func _settings() -> void:
	add_child(SettingsPanel.new())


func _quit() -> void:
	SaveSystem.save_game()
	close()
	GameManager.goto_menu()
