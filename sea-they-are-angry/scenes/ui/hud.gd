extends CanvasLayer
## Heads-up display, built entirely in code. It shows as much as Settings.hud_mode asks:
## full, slim (the clock, the light and your health) or off (prompts, messages and
## warnings only); the hud_mode key steps through them, and held, puts everything back.
## In full its panels shrink themselves once they have said their piece. While the mouse
## is free (the pause menu up, a choice open, the keeper down), and in play with the mouse,
## a panel's heading can be clicked to fold it to one line, and again to unfold it (the
## click is the HUD's: the keeper doesn't swing for it).

const FULL := 0
const SLIM := 1
const OFF := 2
## The hud_mode key held this long puts everything back, rather than stepping the mode.
const HOLD_TIME := 0.5
## Something in the store that just changed shows for this long, even at none.
const STOCK_FRESH := 6.0
## A keeper's fed and warm bars show only below this.
const NEED_SHOWS_BELOW := 50.0
const NEED_FLASH := 1.2
## The jobs list folds to one line once this many are done (or the first night is over).
const JOBS_FULL_UNTIL := 3
## The rock's stores, which Kirkhaven has no use for.
const NOT_IN_TOWN := ["seeds", "seaweed", "food", "eggs", "notes", "poison", "dirty_fuel"]
const HEALTH := Color(0.86, 0.26, 0.24)
const FOLD_OPEN := "▾"
const FOLD_SHUT := "▸"

## Panels folded or unfolded by hand ("light", "store", "jobs", "keeper0"...): true
## folded, false unfolded. One not here follows its own rule. Kept for the session, not saved.
static var folds := {}

const FONT := 18
const MSG_TIME := 2.5
const MSG_FADE := 0.6
const WARN_TIME := 3.0
const REPORT_TIME := 7.0
const REPORT_WIDTH := 880.0
const RED := Color(1.0, 0.35, 0.3)
const AMBER := Color(1.0, 0.8, 0.45)
const PALE := Color(0.92, 0.94, 0.96)
const GOLD := Color(1.0, 0.8, 0.46)
const DIM := Color(0.68, 0.73, 0.78)

var player: Player
var players: Array = []
var lighthouse: Lighthouse
var lamp: Lamp
var camp: Camp
## Chapter Two: a line for the camp's place in the HUD (the town's lamps and generator),
## as [text, alarming].
var status_line: Callable

var markers: ThreatMarkers
var weapon_bar: WeaponBar
## The run's counts (main's): what came ashore and how it was stopped.
var run_tally := {}
var _over_tally: Label
var _over_title: Label
var _phase_label: Label
var _sub_label: Label
var _lh_bar: ProgressBar
var _fuel_label: Label
var _keepers_box: HBoxContainer
var _cards: Array = []
var _stock_box: HFlowContainer
var _stock_chips: Array[Label] = []
var _stock_keys: Array = []
var _jobs_panel: PanelContainer
var _keys_label: Label
var _stock_label: Label
var _lh_label: Label
var _fuel_bar: ProgressBar
var _lamp_label: Label
var _beam_label: Label
var _camp_label: Label
var _jobs_box: VBoxContainer
var _job_labels: Array[Label] = []
var _prompt_label: Label
var _msg_label: Label
var _warn_label: Label
var _report_label: Label
var _report_t := 0.0
var _over: Control
var _over_reason: Label
var _over_btn: Button
var _over_stats: Label
var _msg_t := 0.0
var _warn_t := 0.0
var _light_card: PanelContainer
var _light_col: VBoxContainer
var _light_gap: Control
var _lh_row: HBoxContainer
var _fuel_row: HBoxContainer
var _store_panel: PanelContainer
var _store_name: Label
var _short_col: VBoxContainer
var _jobs_title: Label
var _keys_gap: Control
var _fold_hint: Label
## Each foldable panel's heading row and its mark, by the panel's name.
var _heads := {}
## Which cards are up and in which form, to know when to build them again.
var _cards_sig: Array = []
var _lamp_alarm := false
var _camp_alarm := false
var _beam_on := false
## The HUD's own clock: it stops while the game is paused.
var _now := 0.0
var _dt := 0.0
var _was_active := false
var _stock_last := {}
var _stock_fresh := {}
var _need_low := {}
var _need_flash := {}
var _key_down := false
var _key_at := 0
var _pause: Node

func _ready() -> void:
	layer = 10
	# This script runs while the game is paused too, for the key and the clicks (no time
	# passes for it then: _process). Everything under it stops as before.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.process_mode = Node.PROCESS_MODE_PAUSABLE
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_danger(root)
	markers = ThreatMarkers.new()
	root.add_child(markers)

	# Top left: the night, the sea, and the light.
	# (Offsets that meet, here and below: the panel is as big as what's in it, and no bigger.)
	_light_card = _panel(root)
	_light_card.offset_left = 16.0
	_light_card.offset_right = 16.0
	_light_card.offset_top = 14.0
	_light_card.offset_bottom = 14.0
	var col := _vbox(_light_card, 3)
	_light_col = col
	var light_head := _head(col, "light")
	_phase_label = _label(light_head, FONT + 8)
	Fonts.use_title(_phase_label)
	_phase_label.add_theme_color_override("font_color", GOLD)
	_phase_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add_mark(light_head, "light")
	_sub_label = _label(col, FONT - 3)
	_sub_label.add_theme_color_override("font_color", DIM)
	# How the sea feels tonight: the hidden Anger, in words.
	_mood_label = _label(col, FONT - 1)
	_mood_label.add_theme_color_override("font_color", Color(0.72, 0.8, 0.86))
	_light_gap = _gap(col, 4)
	var lh_row := _row(col, "Harbour light" if Run.chapter == 2 else "Lighthouse")
	_lh_row = lh_row
	_lh_bar = _bar(lh_row, Color(0.88, 0.3, 0.26), Vector2(170, 12))
	_lh_bar.max_value = 1.0
	_lh_label = _label(lh_row, FONT - 3)
	var fuel_row := _row(col, "Lamp fuel")
	_fuel_row = fuel_row
	_fuel_bar = _bar(fuel_row, Color(1.0, 0.72, 0.3), Vector2(170, 12))
	_fuel_bar.max_value = Lamp.FUEL_MAX
	_fuel_label = _label(fuel_row, FONT - 3)
	_lamp_label = _label(col, FONT - 1)
	_beam_label = _label(col, FONT - 2)
	_camp_label = _label(col, FONT - 3)
	_camp_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_camp_label.custom_minimum_size = Vector2(336, 0)

	# Bottom left: a card for each keeper, the one-line ones in a stack beside the rest.
	_keepers_box = HBoxContainer.new()
	_keepers_box.anchor_top = 1.0
	_keepers_box.anchor_bottom = 1.0
	_keepers_box.offset_left = 16.0
	_keepers_box.offset_top = -16.0
	_keepers_box.offset_bottom = -16.0
	_keepers_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_keepers_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_keepers_box.add_theme_constant_override("separation", 8)
	root.add_child(_keepers_box)
	_short_col = _vbox(_keepers_box, 6)
	_short_col.size_flags_vertical = Control.SIZE_SHRINK_END

	# Top right: the store, as wide as what's in it.
	var store := _panel(root)
	_store_panel = store
	store.anchor_left = 1.0
	store.anchor_right = 1.0
	store.offset_left = -16.0
	store.offset_right = -16.0
	store.offset_top = 14.0
	store.offset_bottom = 14.0
	store.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var store_head := _head(store, "store")
	_store_name = _label(store_head, FONT - 2)
	_store_name.text = "Store"
	_store_name.add_theme_color_override("font_color", DIM)
	_stock_box = HFlowContainer.new()
	_stock_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stock_box.alignment = FlowContainer.ALIGNMENT_END
	_stock_box.add_theme_constant_override("h_separation", 14)
	_stock_box.add_theme_constant_override("v_separation", 2)
	store_head.add_child(_stock_box)
	_add_mark(store_head, "store")
	_stock_label = Label.new()

	# Down the right: the first days' jobs (Jobs), and the keys while they're up.
	_jobs_panel = _panel(root)
	_jobs_panel.anchor_left = 1.0
	_jobs_panel.anchor_right = 1.0
	_jobs_panel.offset_left = -16.0
	_jobs_panel.offset_right = -16.0
	_jobs_panel.offset_top = 62.0
	_jobs_panel.offset_bottom = 62.0
	_jobs_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_jobs_box = _vbox(_jobs_panel, 3)
	var jobs_head := _head(_jobs_box, "jobs")
	var jt := _label(jobs_head, FONT + 3)
	_jobs_title = jt
	Fonts.use_title(jt)
	jt.add_theme_color_override("font_color", GOLD)
	jt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add_mark(jobs_head, "jobs")
	for j in Jobs.list():
		var l := _label(_jobs_box, FONT - 2)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(396, 0)
		_job_labels.append(l)
	_keys_gap = _gap(_jobs_box, 4)
	_keys_label = _label(_jobs_box, FONT - 3)
	_keys_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_keys_label.custom_minimum_size = Vector2(396, 0)
	_keys_label.add_theme_color_override("font_color", DIM)

	# Bottom middle: the weapons, numbered for their keys.
	weapon_bar = WeaponBar.new()
	root.add_child(weapon_bar)
	_prompt_label = _bottom_label(root, -168.0, FONT + 2)
	_msg_label = _bottom_label(root, -134.0, FONT)
	_msg_label.add_theme_color_override("font_color", AMBER)

	_warn_label = _label(root, 52)
	Fonts.use_title(_warn_label)
	_warn_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_warn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_warn_label.offset_top = -160.0
	_warn_label.visible = false
	# The night's log: on a dark card in the middle, so it reads over the sea.
	_report_label = _label(root, 23)
	_report_label.set_anchors_preset(Control.PRESET_CENTER)
	_report_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_report_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_report_label.custom_minimum_size = Vector2(REPORT_WIDTH, 0)
	_report_label.offset_left = -REPORT_WIDTH * 0.5
	_report_label.offset_right = REPORT_WIDTH * 0.5
	_report_label.offset_top = 70.0
	_report_label.offset_bottom = 70.0
	_report_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_report_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_report_label.add_theme_stylebox_override("normal", _card_style(0.72, 18, 12))
	_report_label.visible = false

	# While the mouse is free: what a click and the key do, small under the top-left card
	# (on a layer of its own, over the pause menu's shade, so it can be read).
	var over_pause := CanvasLayer.new()
	over_pause.layer = 26
	add_child(over_pause)
	_fold_hint = _label(over_pause, FONT - 3)
	_fold_hint.offset_left = 18.0
	_fold_hint.add_theme_color_override("font_color", DIM)
	_fold_hint.visible = false

	_build_game_over(root)

	Events.message.connect(_on_message)
	Events.run_ended.connect(_on_run_ended)
	Cycle.phase_changed.connect(_on_phase_changed)

# ---- building blocks ----

func _card_style(alpha: float = 0.6, mx: int = 12, my: int = 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.08, alpha)
	sb.border_color = Color(1.0, 0.85, 0.6, 0.14)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = mx
	sb.content_margin_right = mx
	sb.content_margin_top = my
	sb.content_margin_bottom = my
	return sb

func _panel(parent: Node) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_theme_stylebox_override("panel", _card_style())
	parent.add_child(pc)
	return pc

func _vbox(parent: Node, sep: int) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", sep)
	parent.add_child(v)
	return v

func _gap(parent: Node, h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	return c

## A panel's heading row: what a click folds it by (click_at).
func _head(parent: Node, id: String) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_constant_override("separation", 8)
	parent.add_child(r)
	_heads[id] = {"head": r, "mark": null}
	return r

## The small mark at the end of a heading that says it folds; up while it can be clicked.
func _add_mark(head: HBoxContainer, id: String) -> void:
	var m := _label(head, FONT - 2)
	m.add_theme_color_override("font_color", GOLD)
	m.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	m.visible = false
	_heads[id]["mark"] = m

## A row with a name on the left, for a bar.
func _row(parent: Node, title: String, width: float = 96.0) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_constant_override("separation", 8)
	parent.add_child(r)
	var t := _label(r, FONT - 3)
	t.text = title
	t.custom_minimum_size = Vector2(width, 0)
	t.add_theme_color_override("font_color", DIM)
	return r

func _bar(parent: Node, color: Color, size: Vector2) -> ProgressBar:
	var b := ProgressBar.new()
	b.min_value = 0.0
	b.show_percentage = false
	b.custom_minimum_size = size
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.0, 0.0, 0.0, 0.55)
	bg.border_color = Color(1, 1, 1, 0.12)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fill)
	parent.add_child(b)
	return b

func _bar_color(b: ProgressBar, c: Color) -> void:
	(b.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = c

## A keeper's card. In full: their name in their colour, health as a bar, fed and warm
## as bars once either runs low, flares, and what's in their hands. Short: one line, the
## name and a thin health bar.
func _keeper_card(p: Player, short: bool) -> Dictionary:
	var id := "keeper%d" % p.idx
	var pc := _panel(_short_col if short else _keepers_box)
	pc.size_flags_vertical = Control.SIZE_SHRINK_END
	var v := _vbox(pc, 2)
	var head := _head(v, id)
	var nm := _label(head, FONT - 2 if short else FONT)
	Fonts.use_title(nm)
	nm.add_theme_color_override("font_color", Players.color_of(p.idx))
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var down: Label
	var bars := {}
	var rows := {}
	var extra: Label = null
	if short:
		down = _label(head, FONT - 4)
		bars["hp"] = _bar(head, HEALTH, Vector2(72, 6))
	else:
		down = _label(v, FONT - 2)
		for k in [["hp", "Health", HEALTH], ["fed", "Fed", Color(0.82, 0.74, 0.42)], ["warm", "Warm", Color(1.0, 0.56, 0.24)]]:
			var r := _row(v, k[1], 46.0)
			r.add_theme_constant_override("separation", 6)
			rows[k[0]] = r
			bars[k[0]] = _bar(r, k[2], Vector2(104, 8))
			bars[k[0]].max_value = 100.0
		extra = _label(v, FONT - 4)
		extra.add_theme_color_override("font_color", DIM)
	down.add_theme_color_override("font_color", RED)
	_add_mark(head, id)
	return {"keeper": p, "panel": pc, "short": short, "name": nm, "down": down, "bars": bars, "rows": rows, "extra": extra}

## Whether a keeper's card is the one-line form: a helper's is, a person's is not,
## unless folded or unfolded by hand; all are in slim.
func _card_short(p: Player) -> bool:
	return mode() == SLIM or folded("keeper%d" % p.idx)

## Whose cards are up. Full: everyone's. Slim: the people on this screen, and anyone who
## is down and wants reviving. Off: nobody's.
func _card_shown(p: Player) -> bool:
	match mode():
		FULL:
			return true
		SLIM:
			return p == player or p.downed or (not p.ai and not Net.online())
	return false

func _update_keepers() -> void:
	var list: Array = players if players.size() > 1 else ([player] if player != null else [])
	var live: Array = []
	for p in list:
		if is_instance_valid(p):
			live.append(p)
	# Fed and warm show only once they run low, and flash as they come in. No hunger or
	# cold in the town.
	for p in live:
		for need in ["fed", "warm"]:
			var key := "%d%s" % [p.idx, need]
			var low: bool = Run.chapter != 2 and (p.hunger if need == "fed" else p.warmth) < NEED_SHOWS_BELOW
			if low and not bool(_need_low.get(key, false)):
				_need_flash[key] = NEED_FLASH
			_need_low[key] = low
			_need_flash[key] = maxf(0.0, float(_need_flash.get(key, 0.0)) - _dt)
	var sig: Array = []
	for p in live:
		if _card_shown(p):
			sig.append([p.get_instance_id(), _card_short(p)])
	if sig != _cards_sig:
		_cards_sig = sig
		for c in _cards:
			c["panel"].visible = false
			c["panel"].queue_free()
		_cards.clear()
		for id in _heads.keys():
			if String(id).begins_with("keeper"):
				_heads.erase(id)
		for p in live:
			if _card_shown(p):
				_cards.append(_keeper_card(p, _card_short(p)))
		_keepers_box.move_child(_short_col, -1)
	_short_col.visible = _short_col.get_child_count() > 0 and not _cards.is_empty()
	for c in _cards:
		var p: Player = c["keeper"]
		if not is_instance_valid(p):
			continue
		var short: bool = c["short"]
		c["name"].text = p.keeper_name() if p.ai or live.size() == 1 else "P%d %s" % [p.idx + 1, p.keeper_name()]
		c["down"].visible = p.downed
		c["down"].text = ("DOWN" if short else "DOWN: hold Use beside them") if p.downed else ""
		var hp: ProgressBar = c["bars"]["hp"]
		hp.max_value = p.max_hp
		hp.value = p.hp
		_bar_color(hp, RED if p.hp < p.max_hp * 0.3 else HEALTH)
		if short:
			continue
		for need in ["fed", "warm"]:
			var key := "%d%s" % [p.idx, need]
			var row: Control = c["rows"][need]
			row.visible = bool(_need_low.get(key, false))
			var ft := float(_need_flash.get(key, 0.0))
			# Reduced flashing (Settings): it just appears.
			row.modulate.a = 1.0 if ft <= 0.0 or Settings.calm_lights else 0.4 + 0.6 * absf(cos(ft * TAU * 1.25))
		c["bars"]["fed"].value = p.hunger
		_bar_color(c["bars"]["fed"], RED if p.hunger < 25.0 else Color(0.82, 0.74, 0.42))
		c["bars"]["warm"].value = p.warmth
		_bar_color(c["bars"]["warm"], Color(0.45, 0.7, 1.0) if p.warmth < 25.0 else Color(1.0, 0.56, 0.24))
		var extra := "Flares " + ("✦".repeat(p.flares()) if p.flares() > 0 else "none")
		if not p.ai and p.arsenal != null:
			extra += "\n" + p.arsenal.hud_text()
		c["extra"].text = extra
		c["panel"].modulate.a = 0.55 if p.downed else 1.0

## What the store can hold, in the order it's always shown: kind, name, colour.
const STOCK_LOOK := [
	["driftwood", "Driftwood", Color(0.72, 0.56, 0.38)], ["scrap", "Scrap", Color(0.68, 0.7, 0.74)],
	["bio", "Bio", Color(0.35, 1.0, 0.85)], ["seaweed", "Kelp", Color(0.38, 0.72, 0.32)],
	["food", "Food", Color(0.95, 0.82, 0.5)], ["eggs", "Gull eggs", Color(0.92, 0.9, 0.82)],
	["seeds", "Seeds", Color(0.7, 0.62, 0.4)], ["oil", "Oil", Color(0.55, 0.45, 0.3)],
	["dirty_fuel", "Dirty fuel", Color(0.8, 0.5, 0.25)], ["diesel", "Diesel", Color(0.85, 0.3, 0.25)],
	["notes", "Notes", Color(0.85, 0.85, 0.75)], ["arrows", "Arrows", Color(0.75, 0.68, 0.55)],
	["shells", "Cartridges", Color(0.9, 0.35, 0.3)], ["bombs", "Petrol bombs", Color(1.0, 0.55, 0.2)],
	["poison", "Rat poison", Color(0.6, 0.85, 0.4)],
]
## The store never grows wider than this; past it the chips wrap to a second line.
const STOCK_WIDTH := 520.0

## The store: only what there is any of, and for a few seconds anything that just
## changed (so the last of something being spent is seen).
func _update_stock() -> void:
	var want: Array = []
	for k in STOCK_LOOK:
		var kind: String = k[0]
		var n := Stock.get_amount(kind)
		if _stock_last.has(kind) and int(_stock_last[kind]) != n:
			_stock_fresh[kind] = _now + STOCK_FRESH
		_stock_last[kind] = n
		if Run.chapter == 2 and kind in NOT_IN_TOWN:
			continue
		if n > 0 or float(_stock_fresh.get(kind, -1.0)) > _now:
			want.append([k, n])
	# Rebuild the chips only when which ones show changes; otherwise just the numbers.
	var keys := []
	for w in want:
		keys.append(w[0][0])
	if keys != _stock_keys:
		_stock_keys = keys
		for c in _stock_box.get_children():
			c.queue_free()
		_stock_chips.clear()
		for w in want:
			var chip := HBoxContainer.new()
			chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chip.add_theme_constant_override("separation", 5)
			_stock_box.add_child(chip)
			var dot := ColorRect.new()
			dot.color = w[0][2]
			dot.custom_minimum_size = Vector2(9, 9)
			dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chip.add_child(dot)
			_stock_chips.append(_label(chip, FONT - 2))
	var parts: Array[String] = []
	var width := 0.0
	for i in want.size():
		var text := "%s %d" % [want[i][0][1], want[i][1]]
		_stock_chips[i].text = text
		_stock_chips[i].add_theme_color_override("font_color", DIM if want[i][1] == 0 else PALE)
		parts.append(text)
		width += (_stock_chips[i].get_parent() as Control).get_combined_minimum_size().x + (14.0 if i > 0 else 0.0)
	_stock_box.custom_minimum_size.x = minf(ceilf(width), STOCK_WIDTH)
	_stock_label.text = " · ".join(parts)

## The keys, as keeper one has them set.
func _keys_text() -> String:
	var k := func(a: String) -> String: return Settings.key_name(a)
	var line := "%s%s%s%s move · %s sprint · %s jump · %s attack · %s use · %s lamp · %s beam · %s flare · %s skip the day" % [
		k.call("move_up"), k.call("move_left"), k.call("move_down"), k.call("move_right"), k.call("sprint"), k.call("jump"),
		k.call("attack"), k.call("interact"), k.call("operate"), k.call("beam_mode"), k.call("flare"), k.call("skip")]
	line += " · %s less on screen" % k.call("hud_mode")
	if CameraDirector.free_on:
		line += " · middle mouse or %s %s turn the camera, wheel or %s %s zoom, %s reset" % [k.call("cam_left"), k.call("cam_right"), k.call("cam_zoom_in"), k.call("cam_zoom_out"), k.call("cam_reset")]
	return line + " · Esc pause, and How to Play"

## The sea's mood, by Anger: what the keepers feel, not a number.
const MOODS := [[2, "The sea is quiet."], [5, "The sea is restless."], [8, "The sea is angry."], [10, "The sea wants the light."]]
const MOOD_COLORS := [Color(0.72, 0.8, 0.86), Color(0.85, 0.82, 0.62), Color(1.0, 0.6, 0.4), Color(1.0, 0.36, 0.3)]

var _mood_label: Label
var _danger: ColorRect
var _danger_mat: ShaderMaterial
var _danger_t := 0.0

static func mood(anger: int) -> int:
	for i in MOODS.size():
		if anger <= int(MOODS[i][0]):
			return i
	return MOODS.size() - 1

## Whether the light is in danger: the lamp guttering or dark, or the lighthouse below 30%.
func in_danger() -> bool:
	if not Run.active:
		return false
	if lamp != null and is_instance_valid(lamp) and (lamp.state == Lamp.State.GUTTERING or lamp.state == Lamp.State.DARK):
		return true
	return lighthouse != null and is_instance_valid(lighthouse) and lighthouse.health_ratio() < 0.3

func _build_danger(root: Control) -> void:
	# A red glow in from the screen's edges, pulsing like a heartbeat.
	_danger = ColorRect.new()
	_danger.set_anchors_preset(Control.PRESET_FULL_RECT)
	_danger.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform float strength = 0.0;
void fragment() {
	vec2 d = UV - vec2(0.5);
	float edge = smoothstep(0.32, 0.75, length(d * vec2(1.0, 1.15)));
	COLOR = vec4(0.75, 0.02, 0.02, edge * strength);
}
"""
	_danger_mat = ShaderMaterial.new()
	_danger_mat.shader = sh
	_danger.material = _danger_mat
	_danger.visible = false
	root.add_child(_danger)
	root.move_child(_danger, 0)

func _process_danger(delta: float) -> void:
	if _danger == null:
		return
	var on := in_danger()
	_danger.visible = on
	if not on:
		_danger_t = 0.0
		return
	# About once a second: a beat and a softer one, like a pulse.
	_danger_t += delta
	var ph := fmod(_danger_t, 1.0)
	var beat := exp(-ph * 9.0) + 0.5 * exp(-maxf(0.0, ph - 0.22) * 11.0) * float(ph > 0.22)
	# Reduced flashing (Settings): a steady glow instead of a pulse.
	_danger_mat.set_shader_parameter("strength", 0.3 if Settings.calm_lights else 0.15 + 0.5 * beat)

func _label(parent: Node, size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", PALE)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _bottom_label(parent: Node, offset: float, size: int) -> Label:
	var l := _label(parent, size)
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.anchor_top = 1.0
	l.anchor_bottom = 1.0
	l.offset_top = offset
	l.offset_bottom = offset + 32.0
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _build_game_over(root: Control) -> void:
	_over = Control.new()
	_over.set_anchors_preset(Control.PRESET_FULL_RECT)
	_over.mouse_filter = Control.MOUSE_FILTER_STOP
	_over.visible = false
	root.add_child(_over)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.03, 0.05, 0.82)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	_over.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)
	var title := _label(box, 68)
	Fonts.use_title(title)
	title.text = Strings.t("over.title")
	title.add_theme_color_override("font_color", GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_over_title = title
	_over_reason = _label(box, 26)
	_over_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_over_stats = _label(box, 22)
	_over_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_over_stats.add_theme_color_override("font_color", DIM)
	# The keeper's log for the whole run, on a card.
	_over_tally = _label(box, 20)
	_over_tally.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_over_tally.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_over_tally.custom_minimum_size = Vector2(860, 0)
	_over_tally.add_theme_stylebox_override("normal", _card_style(0.55, 22, 14))
	_over_tally.add_theme_constant_override("line_spacing", 6)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	box.add_child(row)
	var btn := _over_button(row, Strings.t("over.again"), _on_new_run)
	_over_btn = btn
	_over_button(row, Strings.t("over.title_screen"), _on_title)

func _process(delta: float) -> void:
	# This runs while the game is paused, so the key and the clicks work; no time passes then.
	var dt := 0.0 if get_tree().paused else delta
	_dt = dt
	_now += dt
	if _key_down and Time.get_ticks_msec() - _key_at >= int(HOLD_TIME * 1000.0):
		_key_down = false
		restore_all()
	if Run.active and not _was_active:
		# A new run: its jobs list starts open again, and the store as it stands is no news.
		folds.erase("jobs")
		_stock_last.clear()
		_stock_fresh.clear()
	_was_active = Run.active
	_process_danger(dt)
	var m := mood(Anger.value)
	_mood_label.text = MOODS[m][1]
	_mood_label.add_theme_color_override("font_color", MOOD_COLORS[m])
	var when := ""
	match Cycle.phase:
		Cycle.Phase.DAY:
			when = "Day %d" % Run.night
		Cycle.Phase.DUSK:
			when = "Dusk"
		Cycle.Phase.NIGHT:
			when = "Night %d" % Run.night
		_:
			when = "Dawn"
	_phase_label.text = "%s   %s" % [when, _mmss(Cycle.time_left)]
	var sub: Array[String] = []
	if Cycle.phase == Cycle.Phase.DUSK or Cycle.phase == Cycle.Phase.NIGHT:
		sub.append(Weather.tonight_name())
	sub.append(Difficulty.name())
	var boat := Rescue.countdown()
	if boat != "":
		sub.append(boat)
	_sub_label.text = " · ".join(sub)
	_update_stock()
	_update_keepers()
	weapon_bar.player = player if player != null and is_instance_valid(player) else null
	if player and is_instance_valid(player):
		_prompt_label.text = Settings.keys_in(player.interact_prompt(), player.idx) if Run.active else ""
	if lighthouse and is_instance_valid(lighthouse):
		_lh_bar.value = lighthouse.health_ratio()
		_lh_label.text = "%d / %d" % [lighthouse.hp, lighthouse.max_hp]
		_lh_label.add_theme_color_override("font_color", RED if lighthouse.health_ratio() < 0.3 else PALE)
	if lamp and is_instance_valid(lamp):
		_fuel_bar.value = lamp.fuel
		_fuel_label.text = "%d" % roundi(lamp.fuel)
		_bar_color(_fuel_bar, RED if lamp.fuel < 15.0 else Color(1.0, 0.72, 0.3))
		_update_lamp_label()
		var on_light: bool = player != null and player.manning != null
		_beam_on = player != null and (player.operating or on_light)
		if _beam_on:
			var focused: bool = (player.manning.mode if on_light else lamp.mode) == Lamp.Mode.FOCUSED
			_beam_label.text = Settings.keys_in("%s: %s   [Q] switch" % ["Searchlight" if on_light else "Beam", "FOCUSED" if focused else "WIDE"], player.idx)
	if status_line.is_valid():
		var st: Array = status_line.call()
		_camp_label.text = String(st[0])
		_camp_alarm = bool(st[1])
		_camp_label.add_theme_color_override("font_color", RED if _camp_alarm else PALE)
	if camp and is_instance_valid(camp) and camp.generator != null:
		var g := camp.generator
		var lit := 0
		for sl in camp.searchlights:
			if sl.is_lit():
				lit += 1
		var line := "Camp: generator %d%%" % roundi(g.fuel)
		if g.running:
			line += " · running, %d light%s" % [lit, "" if lit == 1 else "s"]
		if Stock.get_amount("diesel") > 0:
			line += " · Diesel %d" % Stock.get_amount("diesel")
		# What's wrecked or torn down, so a raid on the holm reads from the main island.
		var hurt := false
		if camp.fallen():
			line = "THE CAMP HAS FALLEN · mend the generator and the huts"
			hurt = true
		else:
			var down: Array[String] = []
			for s in [g] + camp.buildings.values():
				if s.is_destroyed():
					down.append(s.display_name().trim_prefix("the ") + " wrecked")
				elif s.health_ratio() < 0.5:
					down.append(s.display_name().trim_prefix("the ") + " %d%%" % roundi(s.health_ratio() * 100.0))
			if camp.wire_down() > 0:
				down.append("wire down %d" % camp.wire_down())
			if not down.is_empty():
				line += " · " + ", ".join(down)
				hurt = true
		_camp_label.text = line
		_camp_alarm = g.fuel < Generator.LOW or hurt
		_camp_label.add_theme_color_override("font_color", RED if _camp_alarm else PALE)
	_layout()
	if _msg_t > 0.0:
		_msg_t = maxf(0.0, _msg_t - dt)
		_msg_label.modulate.a = clampf(_msg_t / MSG_FADE, 0.0, 1.0)
	if _report_t > 0.0:
		_report_t = maxf(0.0, _report_t - dt)
		_report_label.modulate.a = clampf(_report_t / MSG_FADE, 0.0, 1.0)
		if _report_t <= 0.0:
			_report_label.visible = false
	if _warn_t > 0.0:
		_warn_t = maxf(0.0, _warn_t - dt)
		_warn_label.modulate.a = clampf(_warn_t / MSG_FADE, 0.0, 1.0)
		if _warn_t <= 0.0:
			_warn_label.visible = false

# ---- how much shows ----

## How much the HUD shows now: FULL, SLIM or OFF (Settings.hud_mode).
func mode() -> int:
	return clampi(Settings.hud_mode, FULL, OFF)

## Set how much shows, keep it (Settings), and say so, with the key for more.
func set_mode(m: int) -> void:
	Settings.hud_mode = clampi(m, FULL, OFF)
	Settings.save()
	var key := Settings.key_name("hud_mode")
	match Settings.hud_mode:
		FULL:
			_say("HUD: full. [%s] for less." % key)
		SLIM:
			_say("HUD: slim. [%s] hides it; hold [%s] for everything." % [key, key])
		OFF:
			_say("HUD: off. [%s] brings it back." % key)

## Everything back: full, every panel folded by hand open again, the jobs list out in full.
func restore_all() -> void:
	folds.clear()
	folds["jobs"] = false
	Settings.hud_mode = FULL
	Settings.save()
	_say("HUD: everything back.")
	_process(0.0)

## Whether a panel is folded to its heading: as set by hand, or else by its own rule (the
## jobs list once three are done or the first night is over; a helper's card always).
func folded(id: String) -> bool:
	if folds.has(id):
		return bool(folds[id])
	if id == "jobs":
		return Run.jobs.size() >= JOBS_FULL_UNTIL or Run.night > 1
	if id.begins_with("keeper"):
		var i := int(id.substr(6))
		for p in players:
			if is_instance_valid(p) and p.idx == i:
				return p.ai
	return false

func set_folded(id: String, on: bool) -> void:
	folds[id] = on
	_process(0.0)

## Whether folding this panel changes anything as the HUD is now.
func _can_fold(id: String) -> bool:
	var m := mode()
	return m == FULL or (m == SLIM and id == "light")

## Whether the mouse is free to click the HUD rather than aim and swing: the pause menu
## is up, keeper one has a choice open, or is down.
func mouse_free() -> bool:
	if not visible or not Run.active or _over.visible:
		return false
	var pl := _pause_layer()
	if pl != null:
		# Settings or How to Play is over everything.
		if pl.get_child_count() > 1:
			return false
		var menu: Control = pl.get("_panel")
		if menu != null and menu.visible:
			return true
	if get_tree().paused:
		return false
	return player != null and is_instance_valid(player) and (player.in_menu or player.downed)

## The pause menu (main's or the harbour's), which sits beside the HUD.
func _pause_layer() -> Node:
	if _pause == null or not is_instance_valid(_pause):
		_pause = null
		var main := get_parent()
		if main != null:
			for c in main.get_children():
				var sc: Script = c.get_script()
				if sc != null and sc.resource_path.ends_with("/ui/pause.gd"):
					_pause = c
	return _pause

## A click at a point on the screen: fold or unfold the panel whose heading is there.
## True if it was on one.
func click_at(at: Vector2) -> bool:
	for id in _heads:
		var head: Control = _heads[id]["head"]
		if is_instance_valid(head) and head.is_visible_in_tree() and _can_fold(id) and head.get_global_rect().grow(6.0).has_point(at):
			set_folded(id, not folded(id))
			Audio.sfx("ui_move", Vector3.INF, -4.0, 0.0)
			return true
	return false

## In play, with the mouse (not a pad): a heading can be clicked without the pause menu.
func clicks_in_play() -> bool:
	return visible and Run.active and not _over.visible and not get_tree().paused and not InputSetup.pad_active

func _input(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT):
		return
	if not ev.pressed:
		InputSetup.hud_click = false
		return
	if mouse_free() or clicks_in_play():
		# A button of the menu that's open comes first.
		if get_viewport().gui_get_hovered_control() is BaseButton:
			return
		if click_at(ev.position):
			InputSetup.hud_click = true
			get_viewport().set_input_as_handled()

func _unhandled_input(ev: InputEvent) -> void:
	# Not at the title, on the game-over screen, or with Settings or How to Play up.
	var pl := _pause_layer()
	if not visible or not Run.active or _over.visible or (pl != null and pl.get_child_count() > 1):
		_key_down = false
		return
	if ev.is_action_pressed("hud_mode"):
		# Held, it puts everything back (_process); let go sooner, it steps the mode.
		_key_down = true
		_key_at = Time.get_ticks_msec()
		get_viewport().set_input_as_handled()
	elif ev.is_action_released("hud_mode") and _key_down:
		_key_down = false
		set_mode((mode() + 1) % 3)

## Show and hide by the mode, the folds and each panel's own rule.
func _layout() -> void:
	var m := mode()
	var free := mouse_free()
	# Top left: the clock, then the light.
	var light_fold := folded("light")
	var full := m == FULL and not light_fold
	var slim := m == SLIM and not light_fold
	_light_card.visible = m != OFF
	_sub_label.visible = full
	_mood_label.visible = full
	_light_gap.visible = full
	_lh_row.visible = full or slim
	_fuel_row.visible = full or slim
	_lamp_label.visible = full or (slim and _lamp_alarm)
	_beam_label.visible = full and _beam_on
	_camp_label.visible = _camp_label.text != "" and (full or (slim and _camp_alarm))
	# (A little room when it's only the clock, so the card doesn't twitch as the seconds change.)
	_light_col.custom_minimum_size.x = 336.0 if full else (212.0 if light_fold else 0.0)
	# Top right: the store.
	var store_fold := folded("store")
	_store_panel.visible = m == FULL and (store_fold or not _stock_keys.is_empty())
	_store_name.visible = store_fold
	_stock_box.visible = not store_fold
	# Under it: the jobs, in full while they're new, then one line; the keys on the first day.
	var jobs_up := m == FULL and Jobs.showing()
	_jobs_box.visible = jobs_up
	_jobs_panel.visible = jobs_up
	if jobs_up:
		var top := (_store_panel.offset_top + _store_panel.size.y + 8.0) if _store_panel.visible else 14.0
		_jobs_panel.offset_top = top
		_jobs_panel.offset_bottom = top
		var jobs_fold := folded("jobs")
		var all: Array = Jobs.list()
		if jobs_fold:
			_jobs_title.text = "Jobs: %d of %d done" % [Run.jobs.size(), all.size()]
		else:
			_jobs_title.text = "Jobs about the town" if Run.chapter == 2 else "Jobs for the first days"
		_jobs_title.add_theme_font_size_override("font_size", FONT if jobs_fold else FONT + 3)
		for i in all.size():
			var did := Jobs.done(all[i][0])
			_job_labels[i].visible = not jobs_fold
			_job_labels[i].text = ("✓ " if did else "○ ") + Settings.keys_in(String(all[i][1]), player.idx if player != null else 0)
			_job_labels[i].add_theme_color_override("font_color", Color(0.55, 0.62, 0.55) if did else PALE)
		var keys_up := not jobs_fold and Run.night == 1 and Cycle.phase == Cycle.Phase.DAY
		_keys_gap.visible = keys_up
		_keys_label.visible = keys_up
		if keys_up:
			_keys_label.text = _keys_text()
	# The log in the middle keeps clear of the jobs while they're out in full.
	var log_w := REPORT_WIDTH
	if jobs_up and not folded("jobs"):
		log_w = clampf(_jobs_panel.get_viewport_rect().size.x - 2.0 * (_jobs_panel.size.x + 28.0), 560.0, REPORT_WIDTH)
	_report_label.custom_minimum_size.x = log_w
	_report_label.offset_left = -log_w * 0.5
	_report_label.offset_right = log_w * 0.5
	# Bottom: the cards (their own rules are in _update_keepers) and the weapons.
	_keepers_box.visible = m != OFF
	weapon_bar.off = m == OFF
	# The marks that say a heading folds, and what the key does, while the mouse is free.
	for id in _heads:
		var mark: Label = _heads[id]["mark"]
		if mark != null and is_instance_valid(mark):
			mark.visible = (free or clicks_in_play()) and _can_fold(id)
			mark.text = FOLD_SHUT if folded(id) else FOLD_OPEN
	_fold_hint.visible = free
	if free:
		_fold_hint.position.y = (_light_card.position.y + _light_card.size.y + 6.0) if _light_card.visible else 14.0
		var key := Settings.key_name("hud_mode")
		_fold_hint.text = "[%s] brings the HUD back" % key if m == OFF else "Click a heading to fold it or open it · [%s] shows less, held shows everything" % key

func _update_lamp_label() -> void:
	var color := PALE
	match lamp.state:
		Lamp.State.OFF:
			_lamp_label.text = "Lamp: unlit (lights at dusk)"
		Lamp.State.BURNING:
			# Say which beam, and that the focused one drinks oil, so it isn't left on by accident.
			if lamp.is_smothered():
				_lamp_label.text = "Lamp: SMOTHERED — harpoon it off the tower!"
				color = RED
			elif lamp.is_boosted():
				_lamp_label.text = "Lamp: BURNING HOT on dirty fuel (%ds)" % ceili(lamp.boost_left())
				color = Color(1.0, 0.45, 0.2)
			elif lamp.mode == Lamp.Mode.FOCUSED:
				_lamp_label.text = "Lamp: FOCUSED — burns oil fast"
				color = Color(1.0, 0.55, 0.25)
			else:
				_lamp_label.text = "Lamp: BURNING" + ("" if lamp.operator != null else " — sweeping, unmanned")
				color = AMBER
		Lamp.State.GUTTERING:
			_lamp_label.text = "Lamp: GUTTERING — refuel in %ds" % ceili(lamp.gutter_left())
			color = RED
		Lamp.State.DARK:
			_lamp_label.text = "Lamp: DARK"
			color = RED
	_lamp_alarm = color == RED
	_lamp_label.add_theme_color_override("font_color", color)

func _mmss(seconds: float) -> String:
	var s := maxi(0, ceili(seconds))
	return "%02d:%02d" % [floori(s / 60.0), s % 60]

func _on_message(text: String) -> void:
	_say(Settings.keys_in(text))

## Put a line up as a message, word for word.
func _say(text: String) -> void:
	_msg_label.text = text
	_msg_label.modulate.a = 1.0
	# Longer messages stay up long enough to read.
	_msg_t = MSG_TIME + maxf(0.0, float(text.length() - 50)) * 0.04

func _show_warning(text: String) -> void:
	_warn_label.text = Settings.keys_in(text)
	_warn_label.visible = true
	_warn_label.modulate.a = 1.0
	_warn_t = WARN_TIME

## A centred warning, used by the foghorn alarms.
func warn(text: String) -> void:
	Net.relay_warn(text)
	_show_warning(text)

## The keeper's log for the night just survived: a heading and a few lines under it.
func report(heading: String, lines: Array, time: float = REPORT_TIME) -> void:
	Net.relay_report(heading, lines, time)
	_show_warning(heading)
	_warn_t = time
	_report_label.text = Settings.keys_in("\n".join(lines))
	_report_label.visible = true
	_report_label.modulate.a = 1.0
	_report_t = time

func _on_phase_changed(p: int) -> void:
	# The morning: the night to come, and how the sea feels, in a card for a couple of seconds
	# (not over the first day's welcome, or the dawn's log).
	if p == Cycle.Phase.DAY and Run.active and _report_t <= 0.0 and _warn_t <= 0.0:
		_show_warning("Night %d to come" % Run.night)
		_warn_t = 2.5
		_report_label.text = String(MOODS[mood(Anger.value)][1])
		_report_label.visible = true
		_report_label.modulate.a = 1.0
		_report_t = 2.5
	if p == Cycle.Phase.DUSK:
		_show_warning(["A clear night. The fog is coming.", "Squalls coming in with the fog.", "A storm is coming."][Weather.tonight()])
	elif p == Cycle.Phase.NIGHT:
		_show_warning("They are coming.")

func _on_run_ended(reason: String, night: int) -> void:
	if Net.is_client():
		_over_btn.text = "The host starts the next run"
		_over_btn.disabled = true
	_over_reason.text = reason
	_over_stats.text = "Night %d on %s · best night %d" % [night, ["a calm sea", "an angry sea", "a raging sea"][Difficulty.level()], SaveSys.load_best()]
	_over_tally.text = run_summary(night)
	_report_label.visible = false
	_report_t = 0.0
	_warn_label.visible = false
	_warn_t = 0.0
	if not _over_btn.disabled:
		_over_btn.grab_focus.call_deferred()
	_over.visible = true
	_prompt_label.text = ""

func _over_button(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 28)
	Fonts.use_title(b)
	b.custom_minimum_size = Vector2(240, 52)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

## The run in a few lines: how long the light held, what came, and how it was stopped.
func run_summary(night: int) -> String:
	var t := run_tally
	var g := func(k: String) -> int: return int(t.get(k, 0))
	var lines: Array[String] = []
	var held := maxi(0, night - 1)
	lines.append("%s held %d night%s." % ["Kirkhaven" if Run.chapter == 2 else "The light", held, "" if held == 1 else "s"])
	var how: Array[String] = []
	for k in [["beam", "burned in the beam"], ["fall", "sent over the edge"], ["hook", "to the boathook"], ["shot", "shot"], ["arrow", "to arrows"], ["flame", "to the flamer"], ["bomb", "to petrol bombs"], ["trap", "in traps"], ["poison", "poisoned"], ["flare", "to flares"]]:
		if g.call(k[0]) > 0:
			how.append("%d %s" % [g.call(k[0]), k[1]])
	if g.call("ashore") > 0:
		lines.append("%d came up out of the sea." % g.call("ashore"))
	if not how.is_empty():
		lines.append(", ".join(how) + ".")
	var cost: Array[String] = []
	if g.call("reached") > 0:
		cost.append("%d reached the light" % g.call("reached"))
	if g.call("fence") > 0:
		cost.append("%d fence%s broken" % [g.call("fence"), "" if g.call("fence") == 1 else "s"])
	if g.call("camp_lost") > 0:
		cost.append("%d wrecked at the camp" % g.call("camp_lost"))
	if not cost.is_empty():
		lines.append("It cost: " + ", ".join(cost) + ".")
	return "\n".join(lines)

func _on_title() -> void:
	get_tree().paused = false
	Net.leave()
	Run.active = false
	Cycle.stop()
	get_tree().reload_current_scene()

func _on_new_run() -> void:
	if Net.is_host() and Net.started:
		Net.restart()
		return
	Run.quick_start = true
	Run.start_new()
	SaveSys.clear_run()
	get_tree().reload_current_scene()
