class_name Hud
extends CanvasLayer
## The battle HUD. It only displays and reports clicks: BattleView decides what the
## buttons mean and calls refresh() whenever the battle's state changes.

signal action_pressed(id: String)
signal unit_picked(id: int)
signal end_turn_pressed
signal overlay_toggled(id: String)
signal menu_chosen(id: String)

var _root: Control
var _cards: HBoxContainer
var _card_nodes: Dictionary = {}   # unit id -> {panel, hp, tu, name}
var _turn_label: Label
var _phase_label: Label
var _objective: Label
var _unit_name: Label
var _unit_role: Label
var _hp_bar: GaugeBar
var _tu_bar: GaugeBar
var _pressure_bar: GaugeBar
var _unit_line: Label
var _items_line: Label
var _actions: HFlowContainer
var _end_turn: Button
var _log: RichTextLabel
var _log_lines: Array[String] = []
var _hint: Label
var _tip: PanelContainer
var _tip_text: RichTextLabel
var _banner: VBoxContainer
var _banner_title: Label
var _banner_sub: Label
var _toast: Label
var _modal: Control
var _overlay_buttons: Dictionary = {}


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = Kit.theme()
	add_child(_root)
	_build_top()
	_build_bottom()
	_build_log()
	_build_floating()


# --- building -------------------------------------------------------------------------------

func _build_top() -> void:
	_cards = HBoxContainer.new()
	_cards.position = Vector2(14, 12)
	_cards.add_theme_constant_override("separation", 8)
	_root.add_child(_cards)
	var right := VBoxContainer.new()
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.position = Vector2(-14, 10)
	right.alignment = BoxContainer.ALIGNMENT_END
	right.add_theme_constant_override("separation", 2)
	_root.add_child(right)
	_turn_label = Kit.label("Turn 1", 34, Kit.BRASS, true)
	_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_turn_label)
	_phase_label = Kit.label("Your squad", 18, Kit.INK)
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_phase_label)
	_objective = Kit.label("", 16, Kit.DIM_INK)
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_objective.custom_minimum_size = Vector2(430, 0)
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_objective)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 6)
	right.add_child(row)
	for spec in [["light", "O  Light map"], ["swarm", "P  Swarm sense"], ["menu", "Esc  Menu"]]:
		var b := Button.new()
		b.text = spec[1]
		b.add_theme_font_size_override("font_size", 15)
		b.focus_mode = Control.FOCUS_NONE
		if spec[0] == "menu":
			b.pressed.connect(func() -> void: menu_chosen.emit("open"))
		else:
			b.toggle_mode = true
			b.toggled.connect(func(_on: bool) -> void: overlay_toggled.emit(spec[0]))
			_overlay_buttons[spec[0]] = b
		row.add_child(b)


func _build_bottom() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = 10
	panel.offset_right = -10
	panel.offset_bottom = -10
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	var info := VBoxContainer.new()
	info.custom_minimum_size = Vector2(390, 0)
	info.add_theme_constant_override("separation", 3)
	row.add_child(info)
	_unit_name = Kit.label("", 28, Kit.BRASS, true)
	info.add_child(_unit_name)
	_unit_role = Kit.label("", 14, Kit.DIM_INK)
	info.add_child(_unit_role)
	_hp_bar = GaugeBar.new()
	_hp_bar.fill = Color(0.75, 0.22, 0.18)
	info.add_child(_hp_bar)
	_tu_bar = GaugeBar.new()
	_tu_bar.custom_minimum_size = Vector2(120, 24)
	_tu_bar.font_size = 16
	info.add_child(_tu_bar)
	_pressure_bar = GaugeBar.new()
	_pressure_bar.fill = Kit.COPPER
	_pressure_bar.custom_minimum_size = Vector2(120, 14)
	_pressure_bar.font_size = 12
	info.add_child(_pressure_bar)
	_unit_line = Kit.label("", 15)
	info.add_child(_unit_line)
	_items_line = Kit.label("", 14, Kit.DIM_INK)
	info.add_child(_items_line)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(mid)
	_hint = Kit.label("", 16, Kit.DIM_INK)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mid.add_child(_hint)
	_actions = HFlowContainer.new()
	_actions.add_theme_constant_override("h_separation", 6)
	_actions.add_theme_constant_override("v_separation", 6)
	_actions.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_child(_actions)
	_end_turn = Button.new()
	_end_turn.text = "END\nTURN"
	_end_turn.custom_minimum_size = Vector2(150, 0)
	_end_turn.add_theme_font_override("font", Kit.title_font())
	_end_turn.add_theme_font_size_override("font_size", 30)
	_end_turn.add_theme_color_override("font_color", Kit.BRASS)
	_end_turn.focus_mode = Control.FOCUS_NONE
	_end_turn.tooltip_text = "End the squad's turn (Enter). Anyone holding a third of their TU goes on Overwatch."
	_end_turn.pressed.connect(func() -> void: end_turn_pressed.emit())
	row.add_child(_end_turn)


func _build_log() -> void:
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	p.position = Vector2(-12, -150)
	p.custom_minimum_size = Vector2(440, 0)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", Kit.box(Color(0.05, 0.045, 0.04, 0.72), Color(0.3, 0.24, 0.12), 1))
	_root.add_child(p)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.fit_content = true
	_log.scroll_active = false
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log.add_theme_font_size_override("normal_font_size", 14)
	_log.add_theme_font_size_override("bold_font_size", 14)
	p.add_child(_log)


func _build_floating() -> void:
	_tip = PanelContainer.new()
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.add_theme_stylebox_override("panel", Kit.box(Color(0.05, 0.04, 0.035, 0.95), Kit.BRASS, 1, 4, 10))
	_tip.visible = false
	_root.add_child(_tip)
	_tip_text = RichTextLabel.new()
	_tip_text.bbcode_enabled = true
	_tip_text.fit_content = true
	_tip_text.scroll_active = false
	_tip_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	_tip_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_text.add_theme_font_size_override("normal_font_size", 15)
	_tip_text.add_theme_font_size_override("bold_font_size", 15)
	_tip.add_child(_tip_text)
	_banner = VBoxContainer.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.position = Vector2(0, 150)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.modulate.a = 0.0
	_root.add_child(_banner)
	_banner_title = Kit.label("", 62, Kit.BRASS, true)
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_title.add_theme_constant_override("outline_size", 12)
	_banner_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_banner.add_child(_banner_title)
	_banner_sub = Kit.label("", 20, Kit.INK)
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_sub.add_theme_constant_override("outline_size", 8)
	_banner_sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_banner.add_child(_banner_sub)
	_toast = Kit.label("", 19, Kit.INK)
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.position = Vector2(0, 96)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_constant_override("outline_size", 8)
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_toast.modulate.a = 0.0
	_root.add_child(_toast)


# --- squad cards ----------------------------------------------------------------------------

func build_cards(team: Array[Unit]) -> void:
	for c in _cards.get_children():
		c.queue_free()
	_card_nodes.clear()
	for u in team:
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(176, 0)
		p.mouse_filter = Control.MOUSE_FILTER_STOP
		p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var id := u.id
		p.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				unit_picked.emit(id))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 3)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(v)
		var name_l := Kit.label(u.def.display_name.trim_prefix("The "), 20, Kit.INK, true)
		name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(name_l)
		var hp := GaugeBar.new()
		hp.fill = Color(0.75, 0.22, 0.18)
		hp.custom_minimum_size = Vector2(150, 12)
		hp.font_size = 11
		v.add_child(hp)
		var tu := GaugeBar.new()
		tu.custom_minimum_size = Vector2(150, 12)
		tu.font_size = 11
		v.add_child(tu)
		var status := Kit.label("", 12, Kit.DIM_INK)
		status.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(status)
		_cards.add_child(p)
		_card_nodes[u.id] = {"panel": p, "hp": hp, "tu": tu, "name": name_l, "status": status}


func _refresh_cards(b: Battle, selected: Unit) -> void:
	for id in _card_nodes:
		var u := b.unit(id)
		var n: Dictionary = _card_nodes[id]
		var p: PanelContainer = n["panel"]
		var edge := Kit.BRASS if selected != null and selected.id == id else Kit.PANEL_EDGE
		var bg := Color(0.16, 0.12, 0.06, 0.95) if selected != null and selected.id == id else Kit.PANEL
		if not u.alive:
			bg = Color(0.1, 0.03, 0.03, 0.8)
			edge = Color(0.35, 0.1, 0.08)
		p.add_theme_stylebox_override("panel", Kit.box(bg, edge, 2 if edge == Kit.BRASS else 1))
		(n["hp"] as GaugeBar).set_values(u.hp, u.def.max_hp, 0, -1, "%d / %d HP" % [u.hp, u.def.max_hp])
		(n["tu"] as GaugeBar).set_values(u.tu, u.max_tu, 0, Rules.overwatch_threshold(u.max_tu), "%d TU" % u.tu)
		var tags: Array[String] = []
		if not u.alive:
			tags.append("FALLEN")
		else:
			if u.overwatch:
				tags.append("Overwatch")
			if u.crouched:
				tags.append("Crouched")
			if not u.lamp_on:
				tags.append("Dark")
			if u.jammed:
				tags.append("JAMMED")
			if u.poison_turns > 0:
				tags.append("Poisoned")
			if b.journal_carrier == u.id:
				tags.append("Journal")
		(n["status"] as Label).text = " · ".join(tags)
		(n["name"] as Label).add_theme_color_override("font_color", Kit.INK if u.alive else Color(0.5, 0.3, 0.28))


# --- refresh --------------------------------------------------------------------------------

## actions: Array of {id, label, key, tu, enabled, tip, active}.
func refresh(b: Battle, selected: Unit, actions: Array, hint: String, objective: String, busy: bool) -> void:
	_refresh_cards(b, selected)
	_turn_label.text = "Turn %d" % b.turn
	_phase_label.text = "Your squad" if b.phase == Battle.Phase.PLAYER else ("The swarm moves..." if b.phase == Battle.Phase.ENEMY else "")
	_phase_label.add_theme_color_override("font_color", Kit.INK if b.phase == Battle.Phase.PLAYER else Kit.SWARM_GREEN)
	_objective.text = objective
	_end_turn.disabled = busy or b.phase != Battle.Phase.PLAYER or b.outcome != ""
	_hint.text = hint
	if selected == null or not selected.alive:
		_unit_name.text = ""
		_unit_role.text = ""
		_unit_line.text = ""
		_items_line.text = ""
		_hp_bar.set_values(0, 1)
		_tu_bar.set_values(0, 1)
		_pressure_bar.set_values(0, 1)
		_set_actions([], busy)
		return
	var u := selected
	_unit_name.text = u.def.display_name
	var weapon := u.def.weapon.display_name if u.has_weapon() else "unarmed"
	_unit_role.text = "%s  ·  %s" % [u.def.role, weapon]
	_hp_bar.set_values(u.hp, u.def.max_hp, 0, -1, "Health %d / %d" % [u.hp, u.def.max_hp])
	set_preview_cost(u, 0)
	_pressure_bar.set_values(u.pressure, Rules.PRESSURE_MAX, 0, Rules.JAM_BELOW, "Boiler %d%s" % [u.pressure, "  JAMMED" if u.jammed else ""])
	var bits: Array[String] = []
	if u.has_weapon() and u.def.weapon.clip > 0:
		bits.append("Ammo %d/%d (+%d)" % [u.ammo, u.def.weapon.clip, u.spare_clips])
	bits.append("Crouched" if u.crouched else "Standing")
	bits.append("Lamp lit" if u.lamp_on else "Lamp shuttered")
	bits.append("Facing %s" % Rules.DIR_NAMES[u.facing])
	_unit_line.text = "  ·  ".join(bits)
	var items: Array[String] = []
	items.append("Hand flares %d" % u.hand_flares)
	if u.def.mortar_flares > 0:
		items.append("Mortar flares %d" % u.mortar_flares)
	if u.def.pheromone_grenades > 0:
		items.append("Pheromone %d" % u.pheromones)
	if u.def.dynamite > 0:
		items.append("Dynamite %d" % u.dynamite)
	if u.def.repair_kit > 0:
		items.append("Repair kit %d" % u.repair_kit)
	var load_kg := u.def.load_kg()
	var penalty := u.def.base_tu - u.max_tu
	items.append("Load %.0f kg%s" % [load_kg, " (-%d TU)" % penalty if penalty > 0 else ""])
	_items_line.text = "  ·  ".join(items)
	_set_actions(actions, busy)


## The TU bar's red ghost: what the hovered action would spend.
func set_preview_cost(u: Unit, cost: int) -> void:
	if u == null:
		return
	var left := u.tu - cost
	var label := "%d / %d TU" % [u.tu, u.max_tu]
	if cost > 0:
		label = "%d TU  -%d  =  %d%s" % [u.tu, cost, left, "  (Overwatch kept)" if left >= Rules.overwatch_threshold(u.max_tu) else ""]
		if left < 0:
			label = "%d TU: needs %d" % [u.tu, cost]
	_tu_bar.set_values(u.tu, u.max_tu, cost, Rules.overwatch_threshold(u.max_tu), label)


func _set_actions(actions: Array, busy: bool) -> void:
	for c in _actions.get_children():
		c.queue_free()
	for a in actions:
		var b := Button.new()
		var cost := "" if int(a.get("tu", 0)) <= 0 else "%d TU" % int(a["tu"])
		b.text = "%s  %s\n%s" % [a["key"], a["label"], cost]
		b.custom_minimum_size = Vector2(118, 56)
		b.add_theme_font_size_override("font_size", 15)
		b.disabled = busy or not a.get("enabled", true)
		b.tooltip_text = a.get("tip", "")
		b.focus_mode = Control.FOCUS_NONE
		if a.get("active", false):
			b.add_theme_stylebox_override("normal", Kit.box(Color(0.3, 0.22, 0.07, 1.0), Kit.BRASS, 2))
			b.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
		var id: String = a["id"]
		b.pressed.connect(func() -> void: action_pressed.emit(id))
		_actions.add_child(b)


func set_overlay_pressed(id: String, on: bool) -> void:
	var b: Button = _overlay_buttons.get(id)
	if b != null:
		b.set_pressed_no_signal(on)


# --- log, tips, banners ---------------------------------------------------------------------

func log_line(text: String) -> void:
	_log_lines.append(text)
	while _log_lines.size() > 9:
		_log_lines.pop_front()
	_log.text = "\n".join(_log_lines)


func show_tip(bbcode: String, at: Vector2) -> void:
	if bbcode == "":
		_tip.visible = false
		return
	if _tip_text.text != bbcode or not _tip.visible:
		_tip_text.text = bbcode
		_tip.visible = true
		_tip.reset_size()
	var vp := _root.get_viewport_rect().size
	var pos := at + Vector2(22, 18)
	if pos.x + _tip.size.x > vp.x - 8:
		pos.x = at.x - _tip.size.x - 22
	if pos.y + _tip.size.y > vp.y - 8:
		pos.y = at.y - _tip.size.y - 18
	_tip.position = pos


func hide_tip() -> void:
	_tip.visible = false


func banner(title: String, sub := "", colour := Kit.BRASS, hold := 0.9) -> void:
	_banner_title.text = title
	_banner_title.add_theme_color_override("font_color", colour)
	_banner_sub.text = sub
	_banner.reset_size()
	_banner.position.x = -_banner.size.x * 0.5
	var tw := create_tween()
	_banner.modulate.a = 0.0
	_banner.scale = Vector2.ONE
	tw.tween_property(_banner, "modulate:a", 1.0, 0.18)
	tw.tween_interval(hold)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.35)
	await tw.finished


func toast(text: String, warn := false) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", Color(1, 0.6, 0.45) if warn else Kit.INK)
	_toast.reset_size()
	_toast.position.x = -_toast.size.x * 0.5
	var tw := create_tween()
	_toast.modulate.a = 1.0
	tw.tween_interval(1.6)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.5)


# --- modals ---------------------------------------------------------------------------------

func has_modal() -> bool:
	return _modal != null and is_instance_valid(_modal)


func close_modal() -> void:
	if has_modal():
		_modal.queue_free()
	_modal = null


func show_pause() -> void:
	close_modal()
	_modal = _menu_panel("Expedition Paused", "", [
		["resume", "Resume"], ["help", "How to Play"], ["restart", "Restart Expedition"],
		["title", "Return to Title"], ["quit", "Quit"]])


func show_help() -> void:
	close_modal()
	_modal = HowToPlay.panel(func() -> void: _modal = null)
	_root.add_child(_modal)


func show_end(outcome: String, b: Battle) -> void:
	close_modal()
	var title := ""
	var sub := ""
	match outcome:
		"extracted":
			title = "Expedition Returned"
			sub = "The journal is safe and the lift rises. %d of 4 came home." % b.squad().size()
		"exterminated":
			title = "The Cavern Is Silent"
			sub = "Every creature, the hive too, lies still."
		_:
			title = "Lost Beneath the Earth"
			sub = "No one answers the telegraph."
	var hit_rate := roundi(100.0 * b.stats["hits"] / maxf(1.0, b.stats["shots"]))
	sub += "\n\nTurns %d  ·  Creatures killed %d  ·  Specialists lost %d\nShots %d (%d%% hit)  ·  Reaction shots %d  ·  Flares %d" % [
		b.turn, b.stats["kills"], b.stats["lost"], b.stats["shots"], hit_rate, b.stats["reactions"], b.stats["flares"]]
	_modal = _menu_panel(title, sub, [["restart", "Try Again"], ["title", "Return to Title"]])


func _menu_panel(title: String, sub: String, buttons: Array) -> Control:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(shade)
	var p := PanelContainer.new()
	shade.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	var t := Kit.label(title, 44, Kit.BRASS, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	if sub != "":
		var s := Kit.label(sub, 18)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(s)
	var first: Button = null
	for spec in buttons:
		var b := Button.new()
		b.text = spec[1]
		b.custom_minimum_size = Vector2(320, 46)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var id: String = spec[0]
		b.pressed.connect(func() -> void: menu_chosen.emit(id))
		v.add_child(b)
		if first == null:
			first = b
	p.reset_size()
	var vp := _root.get_viewport_rect().size
	p.position = (vp - p.size) * 0.5
	if first != null:
		first.call_deferred("grab_focus")
	return shade
