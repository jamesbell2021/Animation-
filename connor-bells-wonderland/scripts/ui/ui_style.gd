class_name UiStyle
extends RefCounted
## Shared look for menus: dark glassy panels with a neon border, and neon
## outlined buttons (the main action filled orange).


static func box(bg: Color, border: Color, border_width: int, margin: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(margin)
	return style


static func style_panel(panel: PanelContainer, margin: float = 16.0) -> void:
	panel.add_theme_stylebox_override("panel", box(Color(0.03, 0.035, 0.06, 0.88), CourseBuilder.accent(1), 2, margin))


static func style_button(button: Button, main: bool = false) -> void:
	var accent := CourseBuilder.accent(0) if main else CourseBuilder.accent(1)
	var fill := accent.darkened(0.55) if main else Color(0.06, 0.07, 0.1, 0.9)
	button.add_theme_stylebox_override("normal", box(fill, accent, 2, 6))
	button.add_theme_stylebox_override("hover", box(accent.darkened(0.25), Color.WHITE, 2, 6))
	button.add_theme_stylebox_override("pressed", box(accent, Color.WHITE, 3, 6))
	button.add_theme_stylebox_override("focus", box(Color(0, 0, 0, 0), Color.WHITE, 2, 6))
	button.add_theme_stylebox_override("disabled", box(Color(0.05, 0.05, 0.07, 0.8), accent.darkened(0.6), 2, 6))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
