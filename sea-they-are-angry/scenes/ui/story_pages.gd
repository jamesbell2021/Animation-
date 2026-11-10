class_name StoryPages
extends CanvasLayer
## The keeper's log, shown a page at a time: the whole screen is an open logbook (cream
## ruled paper, a darker edge, the spine's shadow down the left), each page a pencil
## drawing set a little off-square with a typed line or two under it. The drawing comes
## in as if being drawn, then the entry types itself out along the ruled lines.
##
##   var book := StoryPages.open(self, StoryText.intro(), "title")
##   book.finished.connect(...)
##
## A page is {"image": "res://art/story/intro_1.png" (or "" for words alone),
## "text": String, "date": String (a small heading, optional)}. Any key, click or pad
## button turns the page; a page turns itself after about nine seconds; holding Esc (or
## Start or B on a pad) for half a second skips the rest. `finished` is emitted once the
## screen has gone dark after the last page (or the skip); the book then clears and
## frees itself. It runs while the tree is paused and never pauses or unpauses it.
##
## The entries are set in Special Elite (Fonts.LOGBOOK, the typed log the HUD's reports
## already use): it sits on the ruled lines and stays readable at a distance, where IM
## Fell in pencil grey went thin and faint over the rules. Dates are IM Fell small caps.

signal finished

## A page turns by itself after this long (a long entry gets a little longer).
const TURN_AFTER := 9.0
const LONG_ENTRY := 110
const PER_LETTER := 0.05
## The drawing's coming-in, the entry's typing (letters a second), the page's turning.
const DRAW_TIME := 1.2
const TYPE_RATE := 46.0
const FLIP_TIME := 0.45
const SKIP_HOLD := 0.5
const FADE_OUT := 0.35
const PENCIL := Color(0.20, 0.20, 0.23)
const FAINT := Color(0.20, 0.20, 0.23, 0.6)
## The stills' own paper (shaders/sketch.gdshader's `paper`): divided out, so only the
## pencil is laid on the page and the ruled lines show through the drawing.
const STILL_PAPER := Color(0.945, 0.925, 0.87)
const STILL_SHAPE := 1200.0 / 760.0
## How far off-square each drawing sits, in degrees, page after page.
const TILTS := [-1.1, 0.7, -0.5, 1.0]
## The layout is drawn for a screen 900 high and scaled to the one there is.
const DESIGN_H := 900.0
const SPINE := 96.0
const MARGIN := 182.0
const RULE_TOP := 92.0
const RULE_GAP := 46.0
const PLATE_TOP := 76.0
const PLATE_H := 612.0
const ENTRY_W := 1080.0
const ENTRY_SIZE := 30
const WORDS_SIZE := 38
const DATE_SIZE := 27
const HINT_SIZE := 16

const BOOK_SHADER := """
shader_type canvas_item;
// The open logbook: ruled cream paper, a red margin line, the fold's shadow, edges
// gone brown, and the shadow that crosses as a page turns.
uniform vec2 size = vec2(1600.0, 900.0);
uniform float spine = 96.0;
uniform float margin = 182.0;
uniform float rule_top = 92.0;
uniform float rule_gap = 46.0;
uniform float unit = 1.0;
uniform float turn = 0.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += vnoise(p) * a;
		p = p * 2.03 + vec2(17.0, 9.0);
		a *= 0.5;
	}
	return v;
}
void fragment() {
	vec2 px = UV * size;
	vec2 u = px / unit;
	vec3 paper = vec3(0.925, 0.893, 0.80);
	// Foxing and the paper's tooth.
	paper *= 1.0 - (fbm(u * 0.006) - 0.5) * 0.09;
	paper -= (vnoise(u * 0.9) - 0.5) * 0.022;
	paper -= smoothstep(0.82, 1.0, vnoise(vec2(u.x * 0.02, u.y * 0.7))) * 0.012;
	// The rules, and the margin line.
	float dx = px.x - spine;
	float on_page = step(0.0, dx);
	float r = abs(fract((px.y - rule_top) / rule_gap + 0.5) - 0.5) * rule_gap;
	float rule = (1.0 - smoothstep(0.4 * unit, 1.3 * unit, r)) * step(rule_top - rule_gap * 0.5, px.y);
	rule *= 0.75 + 0.25 * vnoise(vec2(u.x * 0.05, floor((px.y - rule_top) / rule_gap + 0.5)));
	paper = mix(paper, vec3(0.50, 0.60, 0.72), rule * 0.34);
	float m = 1.0 - smoothstep(0.5 * unit, 1.5 * unit, abs(px.x - margin));
	paper = mix(paper, vec3(0.74, 0.36, 0.34), m * 0.38 * on_page);
	// The fold: its shadow on both pages, the dark line of the gutter, and the page
	// rising out of it.
	float g = abs(dx) / unit;
	paper *= 1.0 - exp(-g / 46.0) * 0.6;
	paper *= 1.0 - (1.0 - smoothstep(0.0, 2.5, g)) * 0.5;
	paper *= 1.0 + exp(-pow((dx / unit - 120.0) / 70.0, 2.0)) * 0.025;
	paper *= mix(0.9, 1.0, on_page);
	// Edges gone brown with handling.
	vec2 e = min(px, size - px) / unit;
	float edge = 1.0 - smoothstep(0.0, 150.0, min(e.x, e.y) + (fbm(u * 0.012) - 0.5) * 70.0);
	vec2 c = UV - 0.5;
	float corner = smoothstep(0.42, 0.78, length(c * vec2(1.0, 1.1)));
	paper = mix(paper, paper * vec3(0.66, 0.55, 0.42), clamp(edge * 0.55 + corner * 0.4, 0.0, 0.85));
	// A page turning: its shadow sweeps from the right edge to the fold.
	if (turn > 0.0 && turn < 1.0) {
		float at = mix(size.x + 200.0 * unit, spine - 200.0 * unit, turn);
		float band = exp(-pow((px.x - at) / (150.0 * unit), 2.0));
		paper *= 1.0 - band * 0.42 * sin(turn * 3.14159);
	}
	COLOR = vec4(paper, 1.0);
}
"""

const PLATE_SHADER := """
shader_type canvas_item;
render_mode blend_mul;
// A still laid on the page: its own paper is divided out and the pencil multiplied on,
// so the ruled lines run through the drawing. `drawn` (0 to 1) brings it in: a ghost
// of the whole thing first, then the pencil working across from the top left along
// the hatching.
uniform sampler2D still : filter_linear_mipmap, repeat_disable;
uniform vec3 still_paper = vec3(0.945, 0.925, 0.87);
uniform vec2 size = vec2(870.0, 552.0);
uniform float drawn = 1.0;
uniform float ink = 1.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
void fragment() {
	vec3 c = clamp(texture(still, UV).rgb / still_paper, 0.0, 1.0);
	float mark = 1.0 - dot(c, vec3(0.299, 0.587, 0.114));
	// Bare paper in the still is bare page here, grain and all.
	c = mix(vec3(1.0), c, smoothstep(0.03, 0.10, mark));
	vec2 px = UV * size;
	float across = (px.x + px.y) * 0.7071;
	float along = (px.x - px.y) * 0.7071;
	float streak = vnoise(vec2(across * 0.045, along * 0.004));
	float s = UV.x * 0.6 + UV.y * 0.4 + (streak - 0.5) * 0.3;
	float front = drawn * 1.75 - 0.25;
	float show = 1.0 - smoothstep(front - 0.2, front, s);
	show = max(show, smoothstep(0.0, 0.3, drawn) * 0.2);
	show = mix(show, 1.0, step(1.0, drawn));
	vec2 b = min(UV, 1.0 - UV);
	float inside = smoothstep(0.0, 0.03, min(b.x, b.y));
	COLOR = vec4(mix(vec3(1.0), c, show * ink * inside), 1.0);
}
"""

var pages: Array = []
var music := ""
## The page that's open (0 for the first; -1 before any).
var index := -1
var _root: Control
var _book: ColorRect
var _book_mat: ShaderMaterial
var _plate: ColorRect
var _plate_mat: ShaderMaterial
var _date: Label
var _entry: Label
var _hint: Label
var _bar: ColorRect
var _shade: ColorRect
## Seconds the open page has been up, and when it turns itself.
var _page_t := 0.0
var _turn_at := TURN_AFTER
## The page being turned to (-1 for none) and how far the turn has got (0 to 1).
var _pending := -1
var _flip := 1.0
var _holding := false
var _hold := 0.0
var _closing := false
var _has_plate := false
var _mouse_before := Input.MOUSE_MODE_VISIBLE

## Open the log over `parent` and start on its first page.
static func open(parent: Node, p_pages: Array, p_music: String = "") -> StoryPages:
	var book := StoryPages.new()
	book.pages = p_pages
	book.music = p_music
	parent.add_child(book)
	return book

func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_mouse_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build()
	if music != "":
		Audio.music(music, 2.0)
	if pages.is_empty():
		_finish.call_deferred()
		return
	_show(0)
	# Up out of the dark.
	create_tween().tween_property(_shade, "color:a", 0.0, 0.5)

func _exit_tree() -> void:
	if not _closing:
		Input.mouse_mode = _mouse_before

# ---- building it ----

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	_book = ColorRect.new()
	_book.set_anchors_preset(Control.PRESET_FULL_RECT)
	_book.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book_mat = _material(BOOK_SHADER)
	_book.material = _book_mat
	_root.add_child(_book)
	_plate = ColorRect.new()
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate_mat = _material(PLATE_SHADER)
	_plate_mat.set_shader_parameter("still_paper", Vector3(STILL_PAPER.r, STILL_PAPER.g, STILL_PAPER.b))
	_plate.material = _plate_mat
	_root.add_child(_plate)
	_date = _label(Fonts.title(), PENCIL)
	_entry = _label(Fonts.logbook(), PENCIL)
	_entry.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint = _label(Fonts.logbook(), FAINT)
	_bar = ColorRect.new()
	_bar.color = PENCIL
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bar)
	_shade = ColorRect.new()
	_shade.color = Color(0.0, 0.0, 0.0, 1.0)
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_shade)
	_root.resized.connect(_layout)

func _material(code: String) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = code
	var m := ShaderMaterial.new()
	m.shader = sh
	return m

func _label(font: Font, color: Color) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font != null:
		l.add_theme_font_override("font", font)
	l.add_theme_color_override("font_color", color)
	_root.add_child(l)
	return l

# ---- a page ----

## A page's drawing, or null: a still that's missing leaves the words on a bare page.
func _still(path: String) -> Texture2D:
	if path == "":
		return null
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	# Not imported yet (a still just made): read the file itself.
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null:
			img.generate_mipmaps()
			return ImageTexture.create_from_image(img)
	return null

func _show(i: int) -> void:
	index = i
	var page: Dictionary = pages[i] if pages[i] is Dictionary else {}
	var tex := _still(String(page.get("image", "")))
	_has_plate = tex != null
	_plate.visible = _has_plate
	if _has_plate:
		_plate_mat.set_shader_parameter("still", tex)
		_plate_mat.set_shader_parameter("drawn", 0.0)
		Audio.sfx("pencil", Vector3.INF, -8.0, 0.1)
	_date.text = String(page.get("date", ""))
	_entry.text = String(page.get("text", ""))
	_entry.visible_characters = 0
	_page_t = 0.0
	_turn_at = TURN_AFTER + maxf(0.0, float(_entry.text.length() - LONG_ENTRY)) * PER_LETTER
	_hint.text = "Hold %s to skip" % ("B" if InputSetup.pad_active else "Esc")
	_layout()
	_animate()

## Everything in its place for the screen there is. The entry's lines sit on the rules.
func _layout() -> void:
	if _root == null or index < 0:
		return
	var size := _root.size
	if size.x <= 0.0 or size.y <= 0.0:
		size = Vector2(get_viewport().get_visible_rect().size)
	var u := size.y / DESIGN_H
	var gap := RULE_GAP * u
	var top := RULE_TOP * u
	_book_mat.set_shader_parameter("size", size)
	_book_mat.set_shader_parameter("unit", u)
	_book_mat.set_shader_parameter("spine", SPINE * u)
	_book_mat.set_shader_parameter("margin", MARGIN * u)
	_book_mat.set_shader_parameter("rule_top", top)
	_book_mat.set_shader_parameter("rule_gap", gap)
	var left := (MARGIN + 34.0) * u
	var right := size.x - 64.0 * u
	var mid := (left + right) * 0.5
	# The date, on the first rule.
	_set_type(_date, roundi(DATE_SIZE * u), gap)
	_date.position = Vector2(left, top - _ascent(_date))
	# The drawing.
	var ph := PLATE_H * u
	var pw := minf(ph * STILL_SHAPE, right - left)
	ph = pw / STILL_SHAPE
	_plate.size = Vector2(pw, ph)
	_plate.position = Vector2(mid - pw * 0.5, PLATE_TOP * u)
	_plate.pivot_offset = _plate.size * 0.5
	_plate.rotation_degrees = float(TILTS[index % TILTS.size()])
	_plate_mat.set_shader_parameter("size", _plate.size / u)
	# The entry: under the drawing, or, with no drawing, alone in the upper half of the page.
	var width := minf(ENTRY_W * u, right - left)
	_set_type(_entry, roundi((ENTRY_SIZE if _has_plate else WORDS_SIZE) * u), gap)
	_entry.size = Vector2(width, 0.0)
	_entry.custom_minimum_size = Vector2(width, 0.0)
	_entry.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if _has_plate else HORIZONTAL_ALIGNMENT_CENTER
	var under := (PLATE_TOP * u + ph + gap * 0.2) if _has_plate else size.y * 0.36
	var rule := ceilf((under - top) / gap)
	_entry.position = Vector2(mid - width * 0.5, top + rule * gap - _ascent(_entry) - 1.0 * u)
	# The hint and its line, bottom right.
	_set_type(_hint, roundi(HINT_SIZE * u), 0.0)
	var hint_size := _hint.get_minimum_size()
	_hint.position = Vector2(size.x - hint_size.x - 46.0 * u, size.y - hint_size.y - 26.0 * u)
	_bar.position = _hint.position + Vector2(0.0, hint_size.y + 2.0 * u)
	_bar.size = Vector2(hint_size.x * clampf(_hold / SKIP_HOLD, 0.0, 1.0), maxf(2.0 * u, 1.0))

## A label's size of type, and (with `line` over 0) its lines set that far apart.
func _set_type(l: Label, px: int, line: float) -> void:
	l.add_theme_font_size_override("font_size", maxi(px, 6))
	if line > 0.0:
		var f := l.get_theme_font("font")
		l.add_theme_constant_override("line_spacing", roundi(line - f.get_height(maxi(px, 6))))

func _ascent(l: Label) -> float:
	return l.get_theme_font("font").get_ascent(l.get_theme_font_size("font_size"))

## The open page as it stands `_page_t` seconds in: the drawing coming in, then the words.
func _animate() -> void:
	var words_from := 0.25
	if _has_plate:
		_plate_mat.set_shader_parameter("drawn", clampf(_page_t / DRAW_TIME, 0.0, 1.0))
		words_from = DRAW_TIME * 0.8
	var letters := _entry.text.length()
	var typed := clampi(int((_page_t - words_from) * TYPE_RATE), 0, letters)
	_entry.visible_characters = -1 if typed >= letters else typed
	_date.modulate.a = clampf(_page_t / 0.5, 0.0, 1.0)
	# The page being left fades as it turns; the new one comes up from nothing.
	var ink := 1.0
	if _pending >= 0:
		ink = clampf(1.0 - _flip * 2.0, 0.0, 1.0)
	_plate_mat.set_shader_parameter("ink", ink)
	_entry.modulate.a = ink
	_date.modulate.a *= ink
	_book_mat.set_shader_parameter("turn", _flip)

func _process(delta: float) -> void:
	if _closing or index < 0:
		return
	if _holding:
		_hold += delta
		_bar.size.x = _hint.size.x * clampf(_hold / SKIP_HOLD, 0.0, 1.0)
		if _hold >= SKIP_HOLD:
			skip()
			return
	if _flip < 1.0:
		_flip = minf(1.0, _flip + delta / FLIP_TIME)
		if _pending >= 0 and _flip >= 0.5:
			_land()
	_page_t += delta
	_animate()
	if _pending < 0 and _page_t >= _turn_at:
		turn()

# ---- turning ----

## On to the next page; from the last, the end. (A second turn before the first has
## landed lands it at once.)
func turn() -> void:
	if _closing:
		return
	if _pending >= 0:
		_land()
	if index + 1 >= pages.size():
		_finish()
		return
	Audio.sfx("page_turn", Vector3.INF, -4.0, 0.05)
	_pending = index + 1
	_flip = 0.0

func _land() -> void:
	var to := _pending
	_pending = -1
	_show(to)

## Straight to the end.
func skip() -> void:
	if _closing:
		return
	Audio.sfx("page_turn", Vector3.INF, -4.0, 0.05)
	_finish()

# The screen goes dark, `finished` is emitted, and the book clears and frees itself.
func _finish() -> void:
	_closing = true
	_holding = false
	var tw := create_tween()
	tw.tween_property(_shade, "color:a", 1.0, FADE_OUT)
	tw.tween_callback(_gone)
	tw.tween_property(_shade, "color:a", 0.0, FADE_OUT)
	tw.tween_callback(queue_free)

func _gone() -> void:
	for c in _root.get_children():
		if c != _shade:
			(c as CanvasItem).visible = false
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Input.mouse_mode = _mouse_before
	finished.emit()

func _input(event: InputEvent) -> void:
	var pressed := false
	var skips := false
	if event is InputEventKey:
		if event.echo:
			get_viewport().set_input_as_handled()
			return
		pressed = event.pressed
		skips = event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE
	elif event is InputEventJoypadButton:
		pressed = event.pressed
		skips = event.button_index == JOY_BUTTON_START or event.button_index == JOY_BUTTON_B
	elif event is InputEventMouseButton:
		if event.button_index > MOUSE_BUTTON_MIDDLE:
			return
		pressed = event.pressed
	elif event is InputEventAction:
		pressed = event.pressed
		skips = event.action == &"pause" or event.action == &"ui_cancel"
	else:
		return
	# Nothing under the book hears a key while it's open (the pause menu least of all).
	get_viewport().set_input_as_handled()
	if _closing:
		return
	if skips:
		if pressed:
			_holding = true
			_hold = 0.0
		elif _holding:
			# Let go early: a tap, which turns the page like any other key.
			_holding = false
			_hold = 0.0
			_bar.size.x = 0.0
			turn()
	elif pressed:
		turn()
