class_name Fonts
extends RefCounted
## Typefaces: IM Fell English (old-print serif) for titles and warnings,
## Special Elite (typewriter, the keeper's logbook) for everyday text.
## Special Elite is also the project's default GUI font (project.godot).

const TITLE := "res://fonts/IMFellEnglishSC.ttf"
const SERIF := "res://fonts/IMFellEnglish.ttf"
const LOGBOOK := "res://fonts/SpecialElite.ttf"

static func get_font(path: String) -> Font:
	if ResourceLoader.exists(path):
		return load(path)
	return null

static func title() -> Font:
	return get_font(TITLE)

static func serif() -> Font:
	return get_font(SERIF)

static func logbook() -> Font:
	return get_font(LOGBOOK)

## Apply the title face to a control if the font is available.
static func use_title(c: Control) -> void:
	var f := title()
	if f:
		c.add_theme_font_override("font", f)

static func use_serif(c: Control) -> void:
	var f := serif()
	if f:
		c.add_theme_font_override("font", f)
