extends CanvasLayer
## The Escape's own card, top middle (docs/ESCAPE.md): how far to the rock, the Mary Ann's
## hull, who has the wheel, and who of Kirkhaven is aboard. It sits beside the game's HUD
## (scenes/ui/hud.gd), which still shows the keepers, the store, the weapons, prompts and
## warnings; the HUD's own light card has nothing to say on the crossing and is hidden by
## the Escape.

const GOLD := Color(1.0, 0.8, 0.46)
const PALE := Color(0.92, 0.94, 0.96)
const DIM := Color(0.68, 0.73, 0.78)
const RED := Color(1.0, 0.35, 0.3)
const HULL := Color(0.78, 0.58, 0.36)
const LIGHT := Color(1.0, 0.86, 0.5)

## The Escape scene (scenes/escape/escape.gd): read each frame.
var escape: Node
var _card: PanelContainer
var _miles: Label
var _course: ProgressBar
var _hull: ProgressBar
var _hull_label: Label
var _helm: Label
var _people: Label
var _flash := 0.0
var _last_hull := -1

func _ready() -> void:
	layer = 10
	_card = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.04, 0.06, 0.62)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 10
	_card.add_theme_stylebox_override("panel", sb)
	# Top middle: the HUD's own panels are at the corners (its light card, hidden here,
	# still takes up the top left, and the line that says what a click does sits under it).
	_card.anchor_left = 0.5
	_card.anchor_right = 0.5
	_card.offset_top = 10.0
	_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.custom_minimum_size = Vector2(330, 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(col)
	var title := _label(col, 26, GOLD)
	title.text = "The Escape"
	Fonts.use_title(title)
	_miles = _label(col, 17, LIGHT)
	_course = _bar(col, LIGHT)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	var hl := _label(row, 16, DIM)
	hl.text = "Her hull"
	hl.custom_minimum_size = Vector2(72, 0)
	_hull = _bar(row, HULL)
	_hull.custom_minimum_size = Vector2(170, 12)
	_hull_label = _label(row, 15, PALE)
	_helm = _label(col, 16, PALE)
	_people = _label(col, 15, DIM)
	_people.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _label(parent: Node, size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _bar(parent: Node, color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(320, 10)
	b.max_value = 1.0
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.0, 0.0, 0.0, 0.5)
	bg.set_corner_radius_all(3)
	var fg := StyleBoxFlat.new()
	fg.bg_color = color
	fg.set_corner_radius_all(3)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	parent.add_child(b)
	return b

func _process(delta: float) -> void:
	if escape == null or not is_instance_valid(escape):
		return
	# Off with the rest of the HUD (its key), and over the log's pages.
	var hud: CanvasLayer = escape.get("hud")
	visible = hud != null and hud.visible and Settings.hud_mode != 2
	var left: float = escape.call("miles_left")
	_miles.text = "The rock: %.1f miles" % left if left >= 0.05 else "The rock: under the light"
	_course.value = float(escape.call("progress"))
	var hull: int = int(escape.get("hull"))
	var hull_max: int = int(escape.get("hull_max"))
	_hull.max_value = float(hull_max)
	_hull.value = float(hull)
	if _last_hull >= 0 and hull < _last_hull:
		_flash = 0.6
	_last_hull = hull
	_flash = maxf(0.0, _flash - delta)
	var low := hull < hull_max * 0.3
	_hull_label.text = "%d / %d" % [hull, hull_max]
	_hull_label.add_theme_color_override("font_color", RED if low or _flash > 0.0 else PALE)
	(_hull.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = RED if low or fmod(_flash, 0.2) > 0.1 else HULL
	_helm.text = "At the wheel: %s" % String(escape.call("helm_name"))
	var n: int = int(escape.call("people_count"))
	_people.text = ("Aboard: %d of Kirkhaven's people" % n) if n != 1 else "Aboard: one of Kirkhaven's people"
	if n == 0:
		_people.text = "Nobody from Kirkhaven is aboard"
