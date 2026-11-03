extends CanvasLayer
## Heads-up display, built entirely in code.

const FONT := 18
const MSG_TIME := 2.5
const MSG_FADE := 0.6
const WARN_TIME := 3.0
const REPORT_TIME := 7.0
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

func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_danger(root)
	markers = ThreatMarkers.new()
	root.add_child(markers)

	# Top left: the night, the sea, and the light.
	var card := _panel(root)
	card.position = Vector2(16, 14)
	card.custom_minimum_size = Vector2(360, 0)
	var col := _vbox(card, 3)
	_phase_label = _label(col, FONT + 8)
	Fonts.use_title(_phase_label)
	_phase_label.add_theme_color_override("font_color", GOLD)
	_sub_label = _label(col, FONT - 3)
	_sub_label.add_theme_color_override("font_color", DIM)
	# How the sea feels tonight: the hidden Anger, in words.
	_mood_label = _label(col, FONT - 1)
	_mood_label.add_theme_color_override("font_color", Color(0.72, 0.8, 0.86))
	_gap(col, 4)
	var lh_row := _row(col, "Lighthouse")
	_lh_bar = _bar(lh_row, Color(0.88, 0.3, 0.26), Vector2(170, 12))
	_lh_bar.max_value = 1.0
	_lh_label = _label(lh_row, FONT - 3)
	var fuel_row := _row(col, "Lamp fuel")
	_fuel_bar = _bar(fuel_row, Color(1.0, 0.72, 0.3), Vector2(170, 12))
	_fuel_bar.max_value = Lamp.FUEL_MAX
	_fuel_label = _label(fuel_row, FONT - 3)
	_lamp_label = _label(col, FONT - 1)
	_beam_label = _label(col, FONT - 2)
	_camp_label = _label(col, FONT - 3)
	_camp_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_camp_label.custom_minimum_size = Vector2(336, 0)

	# Bottom left: a card for each keeper.
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

	# Top right: the store.
	var store := _panel(root)
	store.anchor_left = 1.0
	store.anchor_right = 1.0
	store.offset_left = -560.0
	store.offset_right = -16.0
	store.offset_top = 14.0
	store.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_stock_box = HFlowContainer.new()
	_stock_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stock_box.alignment = FlowContainer.ALIGNMENT_END
	_stock_box.add_theme_constant_override("h_separation", 14)
	_stock_box.add_theme_constant_override("v_separation", 2)
	store.add_child(_stock_box)
	_stock_label = Label.new()

	# Down the right: the first days' jobs (Jobs), and the keys while they're up.
	_jobs_panel = _panel(root)
	_jobs_panel.anchor_left = 1.0
	_jobs_panel.anchor_right = 1.0
	_jobs_panel.offset_left = -436.0
	_jobs_panel.offset_right = -16.0
	_jobs_panel.offset_top = 96.0
	_jobs_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_jobs_box = _vbox(_jobs_panel, 3)
	var jt := _label(_jobs_box, FONT + 3)
	Fonts.use_title(jt)
	jt.text = "Jobs for the first days"
	jt.add_theme_color_override("font_color", GOLD)
	for j in Jobs.LIST:
		var l := _label(_jobs_box, FONT - 2)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(396, 0)
		_job_labels.append(l)
	_gap(_jobs_box, 4)
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
	_report_label.custom_minimum_size = Vector2(880, 0)
	_report_label.offset_left = -440.0
	_report_label.offset_right = 440.0
	_report_label.offset_top = 70.0
	_report_label.offset_bottom = 70.0
	_report_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_report_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_report_label.add_theme_stylebox_override("normal", _card_style(0.72, 18, 12))
	_report_label.visible = false

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

func _gap(parent: Node, h: float) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)

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

## A keeper's card: their name in their colour, health, hunger and warmth as bars,
## flares, and what's in their hands.
func _keeper_card(p: Player) -> Dictionary:
	var pc := _panel(_keepers_box)
	var v := _vbox(pc, 2)
	var nm := _label(v, FONT)
	Fonts.use_title(nm)
	nm.add_theme_color_override("font_color", Players.COLORS[p.idx % Players.COLORS.size()])
	var down := _label(v, FONT - 2)
	down.add_theme_color_override("font_color", RED)
	var bars := {}
	for k in [["hp", "Health", Color(0.86, 0.26, 0.24)], ["fed", "Fed", Color(0.82, 0.74, 0.42)], ["warm", "Warm", Color(1.0, 0.56, 0.24)]]:
		var r := _row(v, k[1], 46.0)
		r.add_theme_constant_override("separation", 6)
		bars[k[0]] = _bar(r, k[2], Vector2(104, 8))
		bars[k[0]].max_value = 100.0
	var extra := _label(v, FONT - 4)
	extra.add_theme_color_override("font_color", DIM)
	return {"keeper": p, "panel": pc, "name": nm, "down": down, "bars": bars, "extra": extra}

func _update_keepers() -> void:
	var list: Array = players if players.size() > 1 else ([player] if player != null else [])
	var live: Array = []
	for p in list:
		if is_instance_valid(p):
			live.append(p)
	if live.size() != _cards.size() or (not live.is_empty() and _cards[0]["keeper"] != live[0]):
		for c in _cards:
			c["panel"].queue_free()
		_cards.clear()
		for p in live:
			_cards.append(_keeper_card(p))
	for c in _cards:
		var p: Player = c["keeper"]
		if not is_instance_valid(p):
			continue
		c["name"].text = p.keeper_name() if p.ai or live.size() == 1 else "P%d %s" % [p.idx + 1, p.keeper_name()]
		c["down"].visible = p.downed
		c["down"].text = "DOWN: hold Use beside them" if p.downed else ""
		var hp: ProgressBar = c["bars"]["hp"]
		hp.max_value = p.max_hp
		hp.value = p.hp
		_bar_color(hp, RED if p.hp < p.max_hp * 0.3 else Color(0.86, 0.26, 0.24))
		c["bars"]["fed"].value = p.hunger
		_bar_color(c["bars"]["fed"], RED if p.hunger < 25.0 else Color(0.82, 0.74, 0.42))
		c["bars"]["warm"].value = p.warmth
		_bar_color(c["bars"]["warm"], Color(0.45, 0.7, 1.0) if p.warmth < 25.0 else Color(1.0, 0.56, 0.24))
		var extra := "Flares " + ("✦".repeat(p.flares()) if p.flares() > 0 else "none")
		if not p.ai and p.arsenal != null:
			extra += "\n" + p.arsenal.hud_text()
		c["extra"].text = extra
		c["panel"].modulate.a = 0.55 if p.downed else 1.0

const STOCK_LOOK := [
	["driftwood", "Driftwood", Color(0.72, 0.56, 0.38), true], ["scrap", "Scrap", Color(0.68, 0.7, 0.74), true],
	["bio", "Bio", Color(0.35, 1.0, 0.85), true], ["seaweed", "Kelp", Color(0.38, 0.72, 0.32), true],
	["food", "Food", Color(0.95, 0.82, 0.5), true], ["eggs", "Gull eggs", Color(0.92, 0.9, 0.82), false],
	["seeds", "Seeds", Color(0.7, 0.62, 0.4), false], ["oil", "Oil", Color(0.55, 0.45, 0.3), false],
	["dirty_fuel", "Dirty fuel", Color(0.8, 0.5, 0.25), false], ["diesel", "Diesel", Color(0.85, 0.3, 0.25), false],
	["notes", "Notes", Color(0.85, 0.85, 0.75), false], ["arrows", "Arrows", Color(0.75, 0.68, 0.55), false],
	["shells", "Cartridges", Color(0.9, 0.35, 0.3), false], ["bombs", "Petrol bombs", Color(1.0, 0.55, 0.2), false],
	["poison", "Rat poison", Color(0.6, 0.85, 0.4), false],
]

func _update_stock() -> void:
	var want: Array = []
	for k in STOCK_LOOK:
		var n := Stock.get_amount(k[0])
		if k[3] or n > 0:
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
	for i in want.size():
		var text := "%s %d" % [want[i][0][1], want[i][1]]
		_stock_chips[i].text = text
		_stock_chips[i].add_theme_color_override("font_color", DIM if want[i][1] == 0 else PALE)
		parts.append(text)
	_stock_label.text = " · ".join(parts)

## The keys, as keeper one has them set.
func _keys_text() -> String:
	var k := func(a: String) -> String: return Settings.key_name(a)
	var line := "%s%s%s%s move · %s sprint · %s jump · %s attack · %s use · %s lamp · %s beam · %s flare · %s skip the day" % [
		k.call("move_up"), k.call("move_left"), k.call("move_down"), k.call("move_right"), k.call("sprint"), k.call("jump"),
		k.call("attack"), k.call("interact"), k.call("operate"), k.call("beam_mode"), k.call("flare"), k.call("skip")]
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
	_danger_mat.set_shader_parameter("strength", 0.15 + 0.5 * beat)

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
	title.text = "The light is out."
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
	var btn := _over_button(row, "Try again", _on_new_run)
	_over_btn = btn
	_over_button(row, "Back to the title", _on_title)

func _process(delta: float) -> void:
	_process_danger(delta)
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
		_beam_label.visible = player != null and (player.operating or on_light)
		if _beam_label.visible:
			var focused: bool = (player.manning.mode if on_light else lamp.mode) == Lamp.Mode.FOCUSED
			_beam_label.text = Settings.keys_in("%s: %s   [Q] switch" % ["Searchlight" if on_light else "Beam", "FOCUSED" if focused else "WIDE"], player.idx)
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
		_camp_label.add_theme_color_override("font_color", RED if g.fuel < Generator.LOW or hurt else PALE)
	_jobs_box.visible = Jobs.showing()
	_jobs_panel.visible = _jobs_box.visible
	if _jobs_box.visible:
		_keys_label.text = _keys_text()
		for i in Jobs.LIST.size():
			var did := Jobs.done(Jobs.LIST[i][0])
			_job_labels[i].text = ("✓ " if did else "○ ") + Settings.keys_in(String(Jobs.LIST[i][1]), player.idx if player != null else 0)
			_job_labels[i].add_theme_color_override("font_color", Color(0.55, 0.62, 0.55) if did else PALE)
	if _msg_t > 0.0:
		_msg_t = maxf(0.0, _msg_t - delta)
		_msg_label.modulate.a = clampf(_msg_t / MSG_FADE, 0.0, 1.0)
	if _report_t > 0.0:
		_report_t = maxf(0.0, _report_t - delta)
		_report_label.modulate.a = clampf(_report_t / MSG_FADE, 0.0, 1.0)
		if _report_t <= 0.0:
			_report_label.visible = false
	if _warn_t > 0.0:
		_warn_t = maxf(0.0, _warn_t - delta)
		_warn_label.modulate.a = clampf(_warn_t / MSG_FADE, 0.0, 1.0)
		if _warn_t <= 0.0:
			_warn_label.visible = false

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
	_lamp_label.add_theme_color_override("font_color", color)

func _mmss(seconds: float) -> String:
	var s := maxi(0, ceili(seconds))
	return "%02d:%02d" % [floori(s / 60.0), s % 60]

func _on_message(text: String) -> void:
	_msg_label.text = Settings.keys_in(text)
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
	lines.append("The light held %d night%s." % [held, "" if held == 1 else "s"])
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
