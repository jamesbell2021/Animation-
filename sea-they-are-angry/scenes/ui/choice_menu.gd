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
## LAN, on the host: menus open for keepers on other machines, by peer (they don't
## stop anyone here using a menu of their own).
static var remote_menus := {}

## LAN, on the host: the peer whose keeper has this menu open (0: it's on this screen).
## The rows are sent to that machine, and its picks come back (Net._menu_pick).
var remote_peer := 0
## LAN, on a client: a menu run on the host, shown here; picks go back to the host.
var display_only := false
var _shown_rows: Array = []
var _shown_note := ""

var keeper: Player
var title := ""
var build: Callable
var _box: VBoxContainer
var _title: Label
var _note: Label
var _rows: Array = []

static func open(p_keeper: Player, p_title: String, p_build: Callable) -> ChoiceMenu:
	if p_keeper.remote:
		var peer := Net.peer_for_slot(p_keeper.idx)
		if is_instance_valid(remote_menus.get(peer)):
			return null
		var r := ChoiceMenu.new()
		r.keeper = p_keeper
		r.title = p_title
		r.build = p_build
		r.remote_peer = peer
		remote_menus[peer] = r
		p_keeper.get_tree().current_scene.add_child(r)
		return r
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

## A client: show a menu the host is running for this machine's keeper.
static func open_display(p_keeper: Player, p_title: String, note: String, rows: Array) -> ChoiceMenu:
	if is_instance_valid(current):
		current.close()
	var m := ChoiceMenu.new()
	m.keeper = p_keeper
	m.title = p_title
	m.display_only = true
	m._shown_note = note
	m._shown_rows = rows
	p_keeper.get_tree().current_scene.add_child(m)
	current = m
	return m

func show_rows(p_title: String, note: String, rows: Array) -> void:
	title = p_title
	_shown_note = note
	_shown_rows = rows
	if is_inside_tree():
		_refresh()

func _ready() -> void:
	layer = 20
	keeper.in_menu = true
	if remote_peer > 0:
		# Shown on the keeper's own machine, not here.
		_refresh_remote()
		Events.run_ended.connect(_on_run_ended)
		return
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
	if remote_peer > 0:
		_refresh_remote()
		return
	for r in _rows:
		r.queue_free()
	_rows.clear()
	_title.text = title
	var who := keeper.keeper_name() if Players.count() > 1 else "Keeper"
	_note.text = "%s · HP %d / %d · Flares %d · %s" % [who, keeper.hp, keeper.max_hp, keeper.flares(), _stock_line()]
	var opts: Array = _shown_rows if display_only else build.call()
	if display_only:
		_note.text = _shown_note
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
		if display_only:
			b.pressed.connect(Net.pick.bind(n))
		else:
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

# The host's side of a menu shown on another machine: the rows go there as text.
var _remote_opts: Array = []

func _refresh_remote() -> void:
	_remote_opts = build.call()
	var rows := []
	for o in _remote_opts:
		rows.append({"text": String(o["text"]), "enabled": bool(o.get("enabled", true))})
	var who := keeper.keeper_name()
	Net.send_menu(remote_peer, title, "%s · HP %d / %d · Flares %d · %s" % [who, keeper.hp, keeper.max_hp, keeper.flares(), _stock_line()], rows)

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
	if remote_peer > 0:
		if n >= 1 and n <= _remote_opts.size() and bool(_remote_opts[n - 1].get("enabled", true)):
			_pick(_remote_opts[n - 1]["do"])
		elif n == _remote_opts.size() + 1:
			close()
		return
	if n < 1 or n > _rows.size():
		return
	var b: Button = _rows[n - 1]
	if not b.disabled:
		b.pressed.emit()

func _input(ev: InputEvent) -> void:
	if remote_peer > 0:
		return
	if ev.is_action_pressed("ui_cancel") or ev.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()
	elif ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode >= KEY_1 and ev.keycode <= KEY_9:
		choose(ev.keycode - KEY_0)
		get_viewport().set_input_as_handled()

## Close it. `tell` (a LAN menu): let the other machine know too.
func close(tell: bool = true) -> void:
	if is_queued_for_deletion():
		return
	if remote_peer > 0:
		if tell:
			Net.shut_menu(remote_peer)
		if remote_menus.get(remote_peer) == self:
			remote_menus.erase(remote_peer)
	if display_only and tell:
		Net.menu_left()
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
	if remote_peer > 0 and remote_menus.get(remote_peer) == self:
		remote_menus.erase(remote_peer)
	if is_instance_valid(keeper):
		keeper.in_menu = false
