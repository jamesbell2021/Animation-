class_name Kit
extends RefCounted
## The look: the GDD's palette, the fonts, the UI theme, and grid <-> world conversion.

const TILE := 2.0   # metres a tile (GDD 4.1)

# GDD 4 palette
const BRASS := Color("#C59B27")
const IRON := Color("#2B2B2B")
const LEATHER := Color("#5C3A21")
const PHOSPHOR := Color("#39FF14")
const COPPER := Color("#B87333")

const INK := Color(0.93, 0.89, 0.8)
const DIM_INK := Color(0.66, 0.62, 0.55)
const PANEL := Color(0.07, 0.06, 0.05, 0.9)
const PANEL_EDGE := Color(0.5, 0.38, 0.14)
const DANGER := Color(0.92, 0.27, 0.2)
const TU_GREEN := Color(0.3, 0.85, 0.32)
const TU_RED := Color(0.95, 0.25, 0.18)
const SWARM_GREEN := Color(0.4, 1.0, 0.3)

static var _title_font: Font
static var _body_font: Font
static var _theme: Theme


static func world(c: Vector2i, y := 0.0) -> Vector3:
	return Vector3(c.x * TILE, y, c.y * TILE)


static func tile_of(p: Vector3) -> Vector2i:
	return Vector2i(roundi(p.x / TILE), roundi(p.z / TILE))


## Rotation about Y that points a node's -Z along a grid facing.
static func yaw_for(facing: int) -> float:
	var d: Vector2i = Rules.DIRS[facing]
	return atan2(-float(d.x), -float(d.y))


static func title_font() -> Font:
	if _title_font == null:
		_title_font = load("res://fonts/IMFellEnglishSC.ttf")
	return _title_font


static func body_font() -> Font:
	if _body_font == null:
		_body_font = load("res://fonts/SpecialElite.ttf")
	return _body_font


static func box(bg: Color, edge: Color, width := 2, radius := 4, pad := 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.6
	s.content_margin_bottom = pad * 0.6
	return s


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = 18
	t.set_color("font_color", "Label", INK)
	t.set_stylebox("normal", "Button", box(Color(0.13, 0.1, 0.07, 0.95), PANEL_EDGE))
	t.set_stylebox("hover", "Button", box(Color(0.24, 0.17, 0.08, 0.98), BRASS))
	t.set_stylebox("pressed", "Button", box(Color(0.33, 0.24, 0.08, 1.0), BRASS))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), BRASS, 2))
	t.set_stylebox("disabled", "Button", box(Color(0.08, 0.07, 0.06, 0.8), Color(0.25, 0.22, 0.18)))
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", Color(1, 0.92, 0.7))
	t.set_color("font_pressed_color", "Button", BRASS)
	t.set_color("font_disabled_color", "Button", Color(0.42, 0.39, 0.35))
	t.set_stylebox("panel", "PanelContainer", box(PANEL, PANEL_EDGE))
	t.set_stylebox("panel", "Panel", box(PANEL, PANEL_EDGE))
	t.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	t.set_color("default_color", "RichTextLabel", INK)
	t.set_stylebox("panel", "TooltipPanel", box(Color(0.06, 0.05, 0.04, 0.96), BRASS, 1))
	t.set_color("font_color", "TooltipLabel", INK)
	_theme = t
	return t


static func label(text: String, size := 18, colour := INK, heading := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	if heading:
		l.add_theme_font_override("font", title_font())
	return l


static func mat(colour: Color, rough := 0.85, metal := 0.0, emission := Color.BLACK, energy := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = rough
	m.metallic = metal
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = energy
	return m


static func unshaded(colour: Color, transparent := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = colour
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
