class_name TitleScreen
extends CanvasLayer
## The title: the name in brass, a phosphor pulse, and the way in.

signal begin

const Credits := preload("res://studio/credits.gd")

var _root: Control
var _glow: Label
var _t := 0.0
var _menu: VBoxContainer


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = Kit.theme()
	add_child(_root)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.025, 0.02)
	_root.add_child(bg)
	var shaft := ColorRect.new()
	shaft.set_anchors_preset(Control.PRESET_CENTER_TOP)
	shaft.custom_minimum_size = Vector2(420, 900)
	shaft.position = Vector2(-210, 0)
	shaft.color = Color(0.09, 0.07, 0.04, 0.6)
	_root.add_child(shaft)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.grow_horizontal = Control.GROW_DIRECTION_BOTH
	v.grow_vertical = Control.GROW_DIRECTION_BOTH
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 6)
	_root.add_child(v)
	var crown := Kit.label("Her Majesty's Royal Subterranean Expedition", 22, Kit.DIM_INK, true)
	crown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(crown)
	var title := Kit.label("Subterranean", 112, Kit.BRASS, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 6)
	title.add_theme_color_override("font_outline_color", Color(0.2, 0.12, 0.03))
	v.add_child(title)
	_glow = Kit.label("1888", 64, Kit.PHOSPHOR, true)
	_glow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_glow)
	var tag := Kit.label("Turn-based tactics in the Earth's mantle", 18, Kit.INK)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tag)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 30)
	v.add_child(gap)
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 10)
	_menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(_menu)
	var first := _button("Begin the Descent", func() -> void: begin.emit())
	_button("How to Play", func() -> void:
		_menu.visible = false
		_root.add_child(HowToPlay.panel(func() -> void:
			_menu.visible = true
			first.grab_focus())))
	_button("Credits", func() -> void:
		var c := Credits.open(self, "Subterranean: 1888", [
			"A prototype built from the Subterranean: 1888 design document.",
			"Fonts: IM FELL English by Igino Marini (SIL OFL 1.1) and Special Elite by Astigmatic (Apache 2.0).",
			"Models, effects and sound are built in code. Made with Godot Engine."], Kit.title_font()))
	_button("Quit", func() -> void: get_tree().quit())
	first.call_deferred("grab_focus")
	var foot := Kit.label("v%s  ·  a 3BL_Indie prototype" % ProjectSettings.get_setting("application/config/version", "0.1"), 14, Kit.DIM_INK)
	_root.add_child(foot)
	foot.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 16)


func _button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(340, 50)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(func() -> void:
		Audio.play("click", -6)
		on_press.call())
	_menu.add_child(b)
	return b


func _process(delta: float) -> void:
	_t += delta
	var k := 0.75 + 0.25 * sin(_t * 2.2)
	_glow.add_theme_color_override("font_color", Kit.PHOSPHOR * Color(k, k, k, 1.0))
