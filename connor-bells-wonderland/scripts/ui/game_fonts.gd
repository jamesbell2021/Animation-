class_name GameFonts
extends RefCounted
## Typefaces: Bungee (chunky fairground-sign capitals) for titles, signs, the
## countdown and big numbers; Russo One (sporty, easy to read) for everything
## else. Russo One is also the project's default GUI font (project.godot).
## Both are SIL OFL 1.1; licences are in fonts/.

const TITLE := "res://fonts/Bungee-Regular.ttf"
const BODY := "res://fonts/RussoOne-Regular.ttf"
const CREDIT_LINES: Array[String] = [
	Branding.DESIGNER_CREDIT,
	"Fonts: Bungee (The Bungee Project Authors) and Russo One (Jovanny Lemonad), SIL OFL 1.1",
]

static var _cache: Dictionary = {}


static func title() -> Font:
	return _load(TITLE)


static func body() -> Font:
	return _load(BODY)


## Gives [param control] the title face (if the font file is there).
static func use_title(control: Control) -> void:
	var f := title()
	if f != null:
		control.add_theme_font_override("font", f)


static func _load(path: String) -> Font:
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]
