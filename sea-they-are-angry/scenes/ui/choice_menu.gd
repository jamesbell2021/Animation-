class_name ChoiceMenu
extends CanvasLayer
## A small list of choices for one keeper: the cottage (eat, flares, dirty fuel,
## upgrades) and the trap slots. The keeper stands still while it is open; the night
## does not wait. Mouse, number keys, arrows or a pad's d-pad and A pick; Esc or B closes.
## `build` returns the rows: [{"text", "enabled", "do": Callable}], rebuilt after each pick.

signal closed

const PANEL := Color(0.05, 0.07, 0.09, 0.97)
const AMBER := Color(1.0, 0.78, 0.42)
const PALE := Color(0.92, 0.94, 0.96)
const DIM := Color(0.55, 0.58, 0.62)

static var current: ChoiceMenu

var keeper: Player
var title := ""
var build: Callable
var _box: VBoxContainer
var _title: Label
var _note: Label
var _rows: Array = []

static func open(p_keeper: Player, p_title: String, p_build: Callable) -> ChoiceMenu:
	if is_instance_valid(current):
		Events.message.emit("Someone else is busy there.")
		return null
	var m := ChoiceMenu.new()
	m.keeper = p_keeper
	m.title = p_title
	m.build = p_build
	p_keeper.get_tree().current_scene.add_child(m)
	current = m
	return m

func _ready() -> void:
	layer = 20
	keeper.in_menu = true
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL
	sb.border_color = Color(AMBER, 0.5)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(620, 0)
	center.add_child(panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 6)
	panel.add_child(_box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 34)
	Fonts.use_title(_title)
	_title.add_theme_color_override("font_color", AMBER)
	_box.add_child(_title)
	_note = Label.new()
	_note.add_theme_font_size_override("font_size", 16)
	_note.add_theme_color_override("font_color", DIM)
	_box.add_child(_note)
	_refresh()
	Events.run_ended.connect(_on_run_ended)
	Audio.sfx("creak", Vector3.INF, -8.0, 0.1)

func _refresh() -> void:
	for r in _rows:
		r.queue_free()
	_rows.clear()
	_title.text = title
	var who := keeper.keeper_name() if Players.count() > 1 else "Keeper"
	_note.text = "%s · HP %d / %d · Flares %d · %s" % [who, keeper.hp, keeper.max_hp, keeper.flares(), _stock_line()]
	var opts: Array = build.call()
	var first: Button = null
	var n := 0
	for o in opts:
		n += 1
		var b := Button.new()
		b.text = "%d.  %s" % [n, o["text"]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.flat = true
		b.add_theme_font_size_override("font_size", 21)
		b.add_theme_color_override("font_color", PALE)
		b.add_theme_color_override("font_disabled_color", DIM)
		b.add_theme_color_override("font_focus_color", AMBER)
		b.add_theme_color_override("font_hover_color", AMBER)
		b.disabled = not bool(o.get("enabled", true))
		b.pressed.connect(_pick.bind(o["do"]))
		_box.add_child(b)
		_rows.append(b)
		if first == null and not b.disabled:
			first = b
	var leave := Button.new()
	leave.text = "%d.  Leave" % (n + 1)
	leave.alignment = HORIZONTAL_ALIGNMENT_LEFT
	leave.flat = true
	leave.add_theme_font_size_override("font_size", 21)
	leave.add_theme_color_override("font_focus_color", AMBER)
	leave.add_theme_color_override("font_hover_color", AMBER)
	leave.pressed.connect(close)
	_box.add_child(leave)
	_rows.append(leave)
	(first if first != null else leave).grab_focus.call_deferred()

func _stock_line() -> String:
	var parts: Array[String] = []
	for k in ["driftwood", "scrap", "bio", "seaweed", "food", "oil", "dirty_fuel"]:
		var v := Stock.get_amount(k)
		if v > 0:
			parts.append("%s %d" % [k.replace("_", " "), v])
	return ", ".join(parts) if not parts.is_empty() else "nothing in store"

func _pick(cb: Callable) -> void:
	Audio.sfx("ui_accept", Vector3.INF, -4.0, 0.0)
	var keep_open: Variant = cb.call()
	if keep_open is bool and not keep_open:
		close()
		return
	if is_inside_tree():
		_refresh()

## Pick the nth enabled-or-not row (1-based), as a test or the number keys would.
func choose(n: int) -> void:
	if n < 1 or n > _rows.size():
		return
	var b: Button = _rows[n - 1]
	if not b.disabled:
		b.pressed.emit()

func _input(ev: InputEvent) -> void:
	if ev.is_action_pressed("ui_cancel") or ev.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()
	elif ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode >= KEY_1 and ev.keycode <= KEY_9:
		choose(ev.keycode - KEY_0)
		get_viewport().set_input_as_handled()

func close() -> void:
	if is_queued_for_deletion():
		return
	if is_instance_valid(keeper):
		keeper.in_menu = false
	if current == self:
		current = null
	closed.emit()
	queue_free()

func _on_run_ended(_r: String, _n: int) -> void:
	close()

func _exit_tree() -> void:
	if current == self:
		current = null
	if is_instance_valid(keeper):
		keeper.in_menu = false
