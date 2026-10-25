extends Overlay
## Pause menu (also what the Android back button opens during play): resume, edit your
## vendor in the Character Creator, settings, or save and quit to the main menu.

const SettingsPanel := preload("res://scripts/ui/settings_panel.gd")
const CreatorScene := preload("res://scenes/character_creator.tscn")


func build() -> void:
	var v := card("Paused. Very good very nice!", Vector2(720, 640))
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
	col.add_child(UITheme.label(CharacterData.vendor_name(), 26, UITheme.TERRACOTTA))
	var resume := UITheme.button("RESUME", UITheme.LIME, Vector2(0, 80), 30)
	resume.pressed.connect(close)
	col.add_child(resume)
	var edit := UITheme.button("Edit My Vendor", UITheme.LEMON)
	edit.pressed.connect(_edit_vendor)
	col.add_child(edit)
	var settings := UITheme.button("Settings")
	settings.pressed.connect(func(): add_child(SettingsPanel.new()))
	col.add_child(settings)
	var quit := UITheme.button("Save & Quit to Menu", UITheme.TERRACOTTA)
	quit.pressed.connect(_quit)
	col.add_child(quit)
	var tip := UITheme.label("Tip: " + Lines.pick(Lines.TIPS), 17, UITheme.SEA_DARK)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(tip)
	SaveSystem.save_game()


func _edit_vendor() -> void:
	GameManager.creator_mode = "edit"
	var creator: Node = CreatorScene.instantiate()
	# Shown as an overlay so the beach keeps its place while you change outfits; the back
	# button closes it and returns here.
	var wrapper := Overlay.new()
	wrapper.pause_game = false
	add_child(wrapper)
	wrapper.root.add_child(creator)
	creator.finished.connect(wrapper.close)


func _quit() -> void:
	SaveSystem.save_game()
	close()
	GameManager.goto_menu()
