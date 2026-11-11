extends CanvasLayer
## The kraken's strength across the top of the screen, with the fight's three stages
## named over it (the camp, the crossing, the light): the one it is in lit, the ones
## behind ticked off. Kraken makes one of these; it fades out when the kraken dies, and
## keeps out of the way when the HUD is off or hidden.

const GOLD := Color(1.0, 0.85, 0.55)
const DIM := Color(0.62, 0.66, 0.7, 0.75)
const PALE := Color(0.82, 0.86, 0.80)
const BLIND := Color(0.95, 0.95, 0.85)
const WIDTH := 460.0

var kraken: Node
var _root: Control
var _stages: Array[Label] = []
var _bar: ProgressBar
var _fill: StyleBoxFlat
var _note: Label
var _shown := 0.0

func _ready() -> void:
	layer = 4
	_root = VBoxContainer.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_root.position = Vector2(-WIDTH * 0.5, 14.0)
	_root.custom_minimum_size = Vector2(WIDTH, 0.0)
	_root.add_theme_constant_override("separation", 3)
	_root.modulate.a = 0.0
	add_child(_root)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	_root.add_child(row)
	for i in range(1, 4):
		var l := Label.new()
		l.text = "%s  %s" % [["", "I", "II", "III"][i], kraken.STAGE_NAMES[i]]
		l.add_theme_font_size_override("font_size", 14)
		l.add_theme_color_override("font_color", DIM)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		l.add_theme_constant_override("outline_size", 4)
		row.add_child(l)
		_stages.append(l)
	_bar = ProgressBar.new()
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(WIDTH, 12.0)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.0, 0.0, 0.0, 0.6)
	bg.border_color = Color(1.0, 0.85, 0.6, 0.25)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(3)
	_fill = StyleBoxFlat.new()
	_fill.bg_color = PALE
	_fill.set_corner_radius_all(3)
	_bar.add_theme_stylebox_override("background", bg)
	_bar.add_theme_stylebox_override("fill", _fill)
	_root.add_child(_bar)
	_note = Label.new()
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.add_theme_font_size_override("font_size", 13)
	_note.add_theme_color_override("font_color", GOLD)
	_note.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_note.add_theme_constant_override("outline_size", 4)
	_root.add_child(_note)

func _process(delta: float) -> void:
	if kraken == null or not is_instance_valid(kraken):
		return
	var alive: bool = kraken.phase != "dying" and kraken.phase != "dead" and kraken.stage > 0
	var scene := get_tree().current_scene
	var hud = scene.get("hud") if scene != null else null
	var hidden := Settings.hud_mode >= 2 or (hud is CanvasItem and not (hud as CanvasItem).visible) \
		or (hud is CanvasLayer and not (hud as CanvasLayer).visible)
	_shown = move_toward(_shown, 1.0 if alive and not hidden else 0.0, delta * 1.5)
	_root.modulate.a = _shown
	_root.position.x = get_viewport().get_visible_rect().size.x * 0.5 - WIDTH * 0.5
	_root.position.y = 14.0
	if _shown <= 0.0:
		return
	var st: int = kraken.stage
	for i in _stages.size():
		var l := _stages[i]
		var n := i + 1
		l.add_theme_color_override("font_color", GOLD if n == st else (DIM if n > st else Color(DIM.r, DIM.g, DIM.b, 0.45)))
		l.text = ("%s  %s" % [["", "I", "II", "III"][n], kraken.STAGE_NAMES[n]])
	_bar.value = kraken.health_ratio()
	var t := float(Time.get_ticks_msec()) * 0.001
	if kraken.is_rearing():
		_fill.bg_color = PALE.lerp(Color(1.0, 0.5, 0.35), 0.5 + 0.5 * sin(t * 9.0))
		_note.text = "It rears up: everything at it!"
	elif kraken.is_blind():
		_fill.bg_color = BLIND
		_note.text = "Blind: hit it!"
	elif kraken.gripping():
		_fill.bg_color = PALE
		_note.text = "An arm up the tower: blind it!"
	else:
		_fill.bg_color = PALE
		_note.text = ""
