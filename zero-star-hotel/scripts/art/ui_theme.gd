class_name UITheme
extends RefCounted
## The game's look for every Control: chunky rounded buttons in Mediterranean colours, big
## text and huge touch targets (Android first). GameManager applies it to the root window, so
## every menu inherits it. Helpers build the common widgets in code.

const SEA := Color("#1e9bd7")
const SEA_DARK := Color("#0b5f8a")
const SAND := Color("#f7d89b")
const TERRACOTTA := Color("#e2673f")
const LEMON := Color("#ffd23f")
const LIME := Color("#7cc242")
const WHITE := Color("#fffaf0")
const INK := Color("#2b1d16")
const PANEL := Color("#fff4dc")
const DANGER := Color("#e53935")

const FONT_SIZE := 24
const BUTTON_MIN_H := 68.0

static var _theme: Theme
static var _bold: Font


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = bold_font()
	t.default_font_size = FONT_SIZE

	t.set_stylebox("normal", "Button", box(SEA, 18, 4, SEA_DARK))
	t.set_stylebox("hover", "Button", box(SEA.lightened(0.12), 18, 4, SEA_DARK))
	t.set_stylebox("pressed", "Button", box(SEA_DARK, 18, 4, SEA_DARK.darkened(0.3)))
	t.set_stylebox("disabled", "Button", box(Color("#9fb7c4"), 18, 4, Color("#7d939e")))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(state, "Button", WHITE)
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.75))
	t.set_color("font_outline_color", "Button", Color(0, 0, 0, 0.35))
	t.set_constant("outline_size", "Button", 4)
	t.set_constant("h_separation", "Button", 10)

	t.set_color("font_color", "Label", INK)
	t.set_color("font_outline_color", "Label", WHITE)

	t.set_stylebox("panel", "PanelContainer", box(PANEL, 22, 4, INK))
	t.set_stylebox("panel", "Panel", box(PANEL, 22, 4, INK))

	# Sliders: thick track, big round grabber for thumbs.
	var track := box(Color("#d7c4a0"), 12, 0, INK)
	track.content_margin_top = 10
	track.content_margin_bottom = 10
	t.set_stylebox("slider", "HSlider", track)
	var fill := box(LEMON, 12, 0, INK)
	fill.content_margin_top = 10
	fill.content_margin_bottom = 10
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_icon("grabber", "HSlider", circle_texture(44, WHITE, INK))
	t.set_icon("grabber_highlight", "HSlider", circle_texture(48, LEMON, INK))
	t.set_constant("center_grabber", "HSlider", 1)

	var le := box(WHITE, 14, 3, INK)
	le.content_margin_left = 14
	le.content_margin_right = 14
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", box(WHITE, 14, 4, SEA))
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("caret_color", "LineEdit", INK)

	# Fat scrollbars that are easy to grab, though dragging the content works too.
	var sb := box(Color(0, 0, 0, 0.1), 8, 0, INK)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	t.set_stylebox("scroll", "VScrollBar", sb)
	t.set_stylebox("grabber", "VScrollBar", box(Color(0, 0, 0, 0.35), 8, 0, INK))
	t.set_stylebox("grabber_highlight", "VScrollBar", box(Color(0, 0, 0, 0.5), 8, 0, INK))
	t.set_stylebox("grabber_pressed", "VScrollBar", box(Color(0, 0, 0, 0.6), 8, 0, INK))

	t.set_stylebox("panel", "TooltipPanel", box(PANEL, 10, 2, INK))
	t.set_color("font_color", "TooltipLabel", INK)
	_theme = t
	return t


## Godot's built-in font, emboldened so it reads on small screens and matches the cartoon art.
static func bold_font() -> Font:
	if _bold:
		return _bold
	var fv := FontVariation.new()
	fv.base_font = ThemeDB.fallback_font
	fv.variation_embolden = 0.9
	_bold = fv
	return fv


static func box(bg: Color, radius := 16, border := 0, border_color := INK) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border)
	s.border_color = border_color
	s.border_width_bottom = border + (3 if border > 0 else 0)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	s.anti_aliasing = true
	return s


static func circle_texture(size: int, fill: Color, ring: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size, size) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			var r := size * 0.5 - 1.0
			if d <= r - 3.0:
				img.set_pixel(x, y, fill)
			elif d <= r:
				img.set_pixel(x, y, ring)
			elif d <= r + 1.0:
				var col := ring
				col.a = r + 1.0 - d
				img.set_pixel(x, y, col)
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)


# --- Widget helpers --------------------------------------------------------------------------

static func button(text: String, color := SEA, min_size := Vector2(0, BUTTON_MIN_H), font_size := FONT_SIZE) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	if color != SEA:
		tint_button(b, color)
	b.pressed.connect(func(): AudioManager.play_sfx("click", 0.1))
	return b


static func tint_button(b: Button, color: Color) -> void:
	var dark := color.darkened(0.35)
	b.add_theme_stylebox_override("normal", box(color, 18, 4, dark))
	b.add_theme_stylebox_override("hover", box(color.lightened(0.12), 18, 4, dark))
	b.add_theme_stylebox_override("pressed", box(dark, 18, 4, dark.darkened(0.3)))
	if color.get_luminance() > 0.7:
		for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(state, INK)
		b.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.4))


static func label(text: String, size := FONT_SIZE, color := INK, outline := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", INK if color.get_luminance() > 0.5 else WHITE)
	return l


static func title(text: String, size := 54) -> Label:
	var l := label(text, size, LEMON, 14)
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("shadow_offset_y", 5)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


static func panel(bg := PANEL, radius := 22) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg, radius, 4, INK))
	return p


static func margin(child: Control, m := 16) -> MarginContainer:
	var mc := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + side, m)
	mc.add_child(child)
	return mc


## Full-screen dimmed backdrop for overlays (blocks touches to the game underneath).
static func dimmer(alpha := 0.55) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0.03, 0.05, 0.1, alpha)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	return r


## Keeps a full-screen overlay out of phone notches and rounded corners.
static func safe_margins(root: Control) -> void:
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	if screen.x <= 0 or safe.size.x <= 0 or not (OS.has_feature("mobile") or OS.has_feature("android")):
		return
	var vp := root.get_viewport_rect().size
	var sx := vp.x / float(screen.x)
	root.offset_left = safe.position.x * sx
	root.offset_right = -(screen.x - safe.end.x) * sx
