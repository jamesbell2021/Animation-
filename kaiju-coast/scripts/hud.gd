class_name Hud
extends CanvasLayer
## All the 2D UI, built in code: the top bar, the build/upgrade panel, the action buttons, banners,
## the first-person crosshair, radar and target readout, kaiju health bars in the command view,
## drifting sakura petals, and the title and game-over screens.

const PAPER: Color = Color(0.965, 0.925, 0.85)
const DIM: Color = Color(0.6, 0.55, 0.71)
const LINE: Color = Color(0.23, 0.17, 0.32)
const SHU: Color = Color(1.0, 0.23, 0.19)
const JADE: Color = Color(0.24, 1.0, 0.69)
const GOLD: Color = Color(1.0, 0.77, 0.3)
const BLOOD: Color = Color(1.0, 0.12, 0.24)
const SAKURA: Color = Color(1.0, 0.37, 0.64)

var root: Control
var overlay: HudOverlay
var top: PanelContainer
var panel: PanelContainer
var panel_box: VBoxContainer
var acts: VBoxContainer
var banner_box: VBoxContainer
var banner_big: Label
var banner_small: Label
var fps_box: VBoxContainer
var fps_seat: Label
var fps_weap: Label
var fps_bar: ProgressBar
var fps_hint: Label
var fps_abil: Label
var abil_bar: HBoxContainer
var abil_buttons: Dictionary = {}
var abil_bars: Dictionary = {}
var target_hint: Label
var title_screen: Control
var over_screen: Control
var over_big: Label
var over_en: Label
var over_stats: Label
var over_endless: Button
var best_label: Label

var s_funds: Label
var s_city: Label
var s_city_bar: ProgressBar
var s_wave: Label
var s_zep: Label
var s_kaiju: Label
var b_wave: Button
var b_speed: Button
var b_pause: Button
var b_music: Button

var pause_menu: Control
var settings_menu: Control
var tut_box: PanelContainer
var tut_label: Label
var diff_buttons: Array[Button] = []
var _settings_from: String = ""
var _set_widgets: Dictionary = {}
var _banner_t: float = 0.0
var _sig: String = ""
var _tick: float = 0.0


class HudOverlay extends Control:
	var hud: Hud
	var petals: Array[Dictionary] = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)
		for i: int in range(46):
			petals.append({"x": randf(), "y": randf(), "vx": randf_range(0.01, 0.04), "vy": randf_range(0.02, 0.06),
				"r": randf() * TAU, "vr": randf_range(-2, 2), "s": randf_range(3, 7), "w": randf() * TAU})

	func _process(delta: float) -> void:
		for p: Dictionary in petals:
			p["x"] = float(p["x"]) + (float(p["vx"]) + sin(Game.t * 0.7 + float(p["w"])) * 0.01) * delta
			p["y"] = float(p["y"]) + float(p["vy"]) * delta
			p["r"] = float(p["r"]) + float(p["vr"]) * delta
			if float(p["y"]) > 1.05:
				p["y"] = -0.05
				p["x"] = randf() * 1.1 - 0.1
			if float(p["x"]) > 1.05:
				p["x"] = -0.05
		queue_redraw()

	func _draw() -> void:
		if Game.rig == null:
			return
		var cam: Camera3D = Game.rig.cam
		var sz: Vector2 = size
		var font: Font = Mats.font_hud()
		if Game.state == Game.State.PLAY and not Game.player.active:
			for k: Kaiju in Game.kaiju:
				if k.dying:
					continue
				var top_p: Vector3 = k.aim + Vector3(0, 28.0 * float(k.def["scale"]), 0)
				if cam.is_position_behind(top_p):
					continue
				var d: float = cam.global_position.distance_to(top_p)
				if d > 2400.0:
					continue
				var sp: Vector2 = cam.unproject_position(top_p)
				var w: float = clampf(1400.0 / d, 26.0, 90.0) * (1.8 if k.def["boss"] else 1.0)
				draw_rect(Rect2(sp.x - w / 2 - 1, sp.y - 1, w + 2, 5), Color(0, 0, 0, 0.6))
				draw_rect(Rect2(sp.x - w / 2, sp.y, w * maxf(0.0, k.hp / k.max_hp), 3), BLOOD if k.hp / k.max_hp < 0.3 else SAKURA)
				if d < 1100.0 or k.def["boss"]:
					var label: String = "%s %s" % [k.def["jp"], k.def["name"]]
					draw_string(font, Vector2(sp.x - w / 2, sp.y - 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, k.def["col"])
		if Game.player.active and not Game.rig.blending():
			_draw_fps(sz, font)
		for p: Dictionary in petals:
			var pos: Vector2 = Vector2(float(p["x"]) * sz.x, float(p["y"]) * sz.y)
			var s: float = float(p["s"])
			draw_set_transform(pos, float(p["r"]), Vector2(1.0, 0.55 + 0.45 * sin(Game.t * 3.0 + float(p["w"]))))
			draw_circle(Vector2.ZERO, s * 0.75, Color(1.0, 0.7, 0.82, 0.55))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _draw_fps(sz: Vector2, font: Font) -> void:
		var pl: Player = Game.player
		var c: Vector2 = sz * 0.5
		var col: Color = JADE if pl.weapon == "gun" else GOLD
		var r: float = (12.0 + pl.heat * 10.0) if pl.weapon == "gun" else 18.0
		draw_arc(c, r, 0, TAU, 32, col, 1.6, true)
		for d: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			draw_line(c + d * (r + 3.0), c + d * (r + 11.0), col, 1.6, true)
		draw_rect(Rect2(c - Vector2(1, 1), Vector2(2, 2)), col)
		if pl.weapon == "gun":
			draw_arc(c, r + 16.0, -PI / 2.0, -PI / 2.0 + TAU * pl.heat * 0.5, 32, BLOOD if pl.over > 0.0 else GOLD, 3.0, true)
		else:
			var n: int = 4 + int(Game.armory["rkt"])
			for i: int in range(n):
				var on: bool = i < pl.ammo and pl.reload <= 0.0
				draw_rect(Rect2(c.x - float(n) * 5.0 + float(i) * 10.0, c.y + r + 18.0, 7, 4), Color(1.0, 0.54, 0.16) if on else LINE)
		if pl.hit_t > 0.0:
			var hc: Color = GOLD if pl.crit_t > 0.0 else Color.WHITE
			var s: float = 14.0 if pl.crit_t > 0.0 else 9.0
			for d2: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
				draw_line(c + d2 * s * 0.5, c + d2 * s * 1.3, hc, 2.0, true)
		# Target readout under the top bar.
		if pl.look != null and is_instance_valid(pl.look) and not pl.look.dying:
			var k: Kaiju = pl.look
			var y: float = hud.top.size.y + 40.0
			var w: float = minf(360.0, sz.x * 0.6)
			var title: String = "%s  %s" % [k.def["jp"], k.def["name"]]
			draw_string(Mats.font_display(), Vector2(c.x - w / 2, y - 6), title, HORIZONTAL_ALIGNMENT_CENTER, w, 18, k.def["col"])
			draw_rect(Rect2(c.x - w / 2 - 2, y, w + 4, 8), Color(0, 0, 0, 0.6))
			draw_rect(Rect2(c.x - w / 2, y + 1, w * maxf(0.0, k.hp / k.max_hp), 6), BLOOD)
			var tip: String = "AIM FOR THE GLOWING EYES%s · ×3 DAMAGE" % (" AND THE CHEST CORE" if k.def["boss"] else "")
			draw_string(font, Vector2(c.x - w / 2, y + 24), tip, HORIZONTAL_ALIGNMENT_CENTER, w, 11, DIM)
		# Radar.
		var rr: float = 74.0
		var rc: Vector2 = Vector2(18.0 + rr, sz.y - 18.0 - rr)
		draw_circle(rc, rr, Color(0.03, 0.02, 0.05, 0.72))
		draw_arc(rc, rr, 0, TAU, 48, Color(JADE, 0.5), 1.0, true)
		draw_arc(rc, rr * 0.5, 0, TAU, 32, Color(JADE, 0.3), 1.0, true)
		var half: float = deg_to_rad(Game.rig.cam.fov) * 0.5 * sz.x / sz.y
		draw_line(rc, rc + Vector2(sin(-half), -cos(half)) * rr, Color(JADE, 0.4), 1.0)
		draw_line(rc, rc + Vector2(sin(half), -cos(half)) * rr, Color(JADE, 0.4), 1.0)
		var cam: Camera3D = Game.rig.cam
		var inv: Transform3D = cam.global_transform.affine_inverse()
		var scale_r: float = rr / 800.0
		var blip: Callable = func(w3: Vector3, bc: Color, bs: float) -> void:
			var l: Vector3 = inv * w3
			var p: Vector2 = Vector2(l.x, l.z) * scale_r
			if p.length() > rr - 3.0:
				p = p.normalized() * (rr - 3.0)
			draw_rect(Rect2(rc + p - Vector2(bs, bs) * 0.5, Vector2(bs, bs)), bc)
		for t: Turret in Game.turrets:
			blip.call(t.pad.pos, JADE, 3.0)
		if not Game.zep.down:
			blip.call(Game.zep.position, PAPER, 5.0)
		for k2: Kaiju in Game.kaiju:
			if not k2.dying:
				blip.call(k2.position, BLOOD if sin(Game.t * 8.0) > 0.0 else SAKURA, 9.0 if k2.def["boss"] else 5.0)


func _ready() -> void:
	layer = 5
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	add_child(root)
	overlay = HudOverlay.new()
	overlay.hud = self
	root.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_top()
	_build_panel()
	_build_acts()
	_build_banner()
	_build_fps()
	_build_title()
	_build_over()
	_build_tutorial()
	_build_pause()
	_build_settings()
	Game.banner.connect(show_banner)
	Game.hud_dirty.connect(func() -> void: refresh(true))
	Game.state_changed.connect(_on_state)
	_on_state()


func _make_theme() -> Theme:
	var th: Theme = Theme.new()
	th.default_font = Mats.font_hud()
	th.default_font_size = 16
	var normal: StyleBoxFlat = _box(Color(0.07, 0.05, 0.11, 0.86), LINE, 1)
	var hover: StyleBoxFlat = _box(Color(0.1, 0.22, 0.17, 0.92), JADE, 1)
	var pressed: StyleBoxFlat = _box(Color(0.12, 0.32, 0.24, 0.95), JADE, 1)
	var disabled: StyleBoxFlat = _box(Color(0.05, 0.04, 0.08, 0.7), Color(LINE, 0.6), 1)
	var focus: StyleBoxFlat = _box(Color(0, 0, 0, 0), GOLD, 2)
	focus.draw_center = false
	th.set_stylebox("normal", "Button", normal)
	th.set_stylebox("hover", "Button", hover)
	th.set_stylebox("pressed", "Button", pressed)
	th.set_stylebox("disabled", "Button", disabled)
	th.set_stylebox("focus", "Button", focus)
	th.set_color("font_color", "Button", PAPER)
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_color("font_pressed_color", "Button", Color.WHITE)
	th.set_color("font_disabled_color", "Button", Color(DIM, 0.6))
	th.set_color("font_color", "Label", PAPER)
	var pnl: StyleBoxFlat = _box(Color(0.04, 0.03, 0.07, 0.92), LINE, 1)
	pnl.border_width_top = 2
	pnl.border_color = LINE
	pnl.content_margin_left = 12
	pnl.content_margin_right = 12
	pnl.content_margin_top = 10
	pnl.content_margin_bottom = 10
	th.set_stylebox("panel", "PanelContainer", pnl)
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0.16, 0.13, 0.22)
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = JADE
	th.set_stylebox("background", "ProgressBar", bg)
	th.set_stylebox("fill", "ProgressBar", fill)
	return th


func _box(bg: Color, border: Color, w: int) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(w)
	s.set_corner_radius_all(2)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


func _label(text: String, size: int, col: Color, display: bool = false) -> Label:
	var l: Label = Label.new()
	l.text = text
	var ls: LabelSettings = LabelSettings.new()
	ls.font = Mats.font_display() if display else Mats.font_hud()
	ls.font_size = size
	ls.font_color = col
	l.label_settings = ls
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, cb: Callable, focusable: bool = true) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL if focusable else Control.FOCUS_NONE
	b.pressed.connect(func() -> void:
		Game.sfx.play("click")
		cb.call()
		# Mouse users never want a button to keep focus (Space would press it again).
		if is_instance_valid(b) and b.is_inside_tree() and (Game.main == null or not Game.main.using_pad) and not menu_open() and Game.state == Game.State.PLAY:
			b.release_focus())
	return b


# ------------------------------------------------------------------ top bar --

func _build_top() -> void:
	top = PanelContainer.new()
	var st: StyleBoxFlat = _box(Color(0.027, 0.024, 0.05, 0.82), Color(0, 0, 0, 0), 0)
	st.content_margin_left = 14
	st.content_margin_right = 14
	st.content_margin_top = 8
	st.content_margin_bottom = 8
	top.add_theme_stylebox_override("panel", st)
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(row)
	var brand: Label = _label("怪獣海岸", 24, SHU, true)
	row.add_child(brand)
	s_funds = _stat(row, "資金 FUNDS", GOLD)
	var cityv: VBoxContainer = VBoxContainer.new()
	cityv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cityv.add_theme_constant_override("separation", 0)
	row.add_child(cityv)
	cityv.add_child(_label("都市 CITY", 10, DIM))
	s_city = _label("100%", 18, Color.WHITE)
	cityv.add_child(s_city)
	s_city_bar = ProgressBar.new()
	s_city_bar.custom_minimum_size = Vector2(70, 3)
	s_city_bar.show_percentage = false
	s_city_bar.max_value = 100
	s_city_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cityv.add_child(s_city_bar)
	s_wave = _stat(row, "波 WAVE", Color.WHITE)
	s_zep = _stat(row, "飛行船 AIRSHIP", Color.WHITE)
	s_kaiju = _stat(row, "怪獣 KAIJU", Color.WHITE)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	b_wave = _button("次の波 NEXT WAVE  [Space]", func() -> void: Game.start_wave(), false)
	var ws: StyleBoxFlat = _box(Color(0.3, 0.05, 0.05, 0.85), SHU, 1)
	b_wave.add_theme_stylebox_override("normal", ws)
	row.add_child(b_wave)
	b_speed = _button("×1", func() -> void: Game.main.cycle_speed(), false)
	row.add_child(b_speed)
	b_pause = _button("一時停止 PAUSE", func() -> void: Game.main.toggle_pause(), false)
	row.add_child(b_pause)
	b_music = _button("♪ ON", func() -> void: Game.main.toggle_music(), false)
	row.add_child(b_music)
	var b_menu: Button = _button("設定 MENU", func() -> void: Game.main.toggle_pause(), false)
	row.add_child(b_menu)


func _stat(parent: Control, key: String, col: Color) -> Label:
	var v: VBoxContainer = VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 0)
	parent.add_child(v)
	v.add_child(_label(key, 10, DIM))
	var l: Label = _label("0", 18, col)
	v.add_child(l)
	return l


# ------------------------------------------------------------------ panel --

func _build_panel() -> void:
	panel = PanelContainer.new()
	var st: StyleBoxFlat = _box(Color(0.04, 0.03, 0.07, 0.93), LINE, 1)
	st.border_width_top = 2
	st.border_color = SHU
	st.content_margin_left = 12
	st.content_margin_right = 12
	st.content_margin_top = 10
	st.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", st)
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 14
	panel.offset_bottom = -14
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.custom_minimum_size = Vector2(370, 0)
	root.add_child(panel)
	panel_box = VBoxContainer.new()
	panel_box.add_theme_constant_override("separation", 6)
	panel.add_child(panel_box)
	panel.visible = false


func _panel_sig() -> String:
	var s: Variant = Game.sel
	var key: String = ""
	if s is Pad:
		var p: Pad = s
		key = "pad%d" % p.index
		if p.turret != null:
			var t: Turret = p.turret
			key += "%s%d%d" % [t.type, t.lvl, int(t.hp / 5.0)]
	elif s is String:
		key = s
	var z: Zeppelin = Game.zep
	return "%s|%d|%s|%d%d%d|%d|%d%d|%d" % [key, Game.funds, z.down, z.lvl["bomb"], z.lvl["pods"], z.lvl["armor"], int(z.hp / 10.0),
		Game.armory["gun"], Game.armory["rkt"], int(Game.city)]


func _rebuild_panel() -> void:
	for c: Node in panel_box.get_children():
		c.queue_free()
	var s: Variant = Game.sel
	var f: int = Game.funds
	var head: HBoxContainer = HBoxContainer.new()
	panel_box.add_child(head)
	if s is String and s == "armory":
		_title(head, "武器庫", "ARMORY")
		panel_box.add_child(_label("Upgrades for you, in any seat.", 12, DIM))
		for k: String in ["gun", "rkt"]:
			var u: Dictionary = Game.AUP[k]
			var l: int = Game.armory[k]
			var maxed: bool = l >= 4
			var cost: int = 0 if maxed else int(u["costs"][l])
			panel_box.add_child(_item(String(u["jp"])[0], "%s %s" % [u["name"], _stars(l, 4)], u["desc"], "MAX" if maxed else "¥%d" % cost,
				maxed or f < cost, func() -> void: Game.main.act("arm", k)))
		panel_box.add_child(_item("壁", "SHORE UP THE CITY", "Rebuild 15% of the city.", "¥250", f < 250 or Game.city >= 100.0,
			func() -> void: Game.main.act("wall", "")))
	elif s is String and s == "zep":
		var z: Zeppelin = Game.zep
		_title(head, "雷神丸", "RAIJIN-MARU")
		panel_box.add_child(_label("Shot down. Back in %ds." % ceili(30.0 - z.down_t) if z.down else "Airship. Flies the bay; tengu hunt it.", 12, DIM))
		panel_box.add_child(_hp_bar(z.hp / z.max_hp))
		for k2: String in ["bomb", "pods", "armor"]:
			var u2: Dictionary = Game.ZUP[k2]
			var l2: int = z.lvl[k2]
			var maxed2: bool = l2 >= 3
			var cost2: int = 0 if maxed2 else int(u2["costs"][l2])
			panel_box.add_child(_item(String(u2["jp"])[0], "%s %s" % [u2["name"], _stars(l2, 3)], u2["desc"], "MAX" if maxed2 else "¥%d" % cost2,
				maxed2 or f < cost2 or z.down, func() -> void: Game.main.act("zup", k2)))
		var rep: int = ceili((z.max_hp - z.hp) * 0.6)
		var row: HBoxContainer = HBoxContainer.new()
		panel_box.add_child(row)
		var br: Button = _button("修理 REPAIR ¥%d" % rep, func() -> void: Game.main.act("zrep", ""))
		br.disabled = rep <= 0 or f < rep or z.down
		row.add_child(br)
		var bb: Button = _button("搭乗 BOARD [F]", func() -> void: Game.player.enter("zep"))
		bb.disabled = z.down
		row.add_child(bb)
	elif s is Pad:
		var p: Pad = s
		if p.turret == null:
			_title(head, "海上砦" if p.fort else "砲台", "SEA FORT" if p.fort else "EMPLACEMENT")
			panel_box.add_child(_label("Out in the bay: first to fire, first to be trampled." if p.fort else "Behind the seawall.", 12, DIM))
			for i: int in range(Game.TT_KEYS.size()):
				var key: String = Game.TT_KEYS[i]
				var d: Dictionary = Game.TT[key]
				panel_box.add_child(_item(d["kj"], "%s  [%d]" % [d["name"], i + 1], d["desc"], "¥%d" % int(d["cost"]), f < int(d["cost"]),
					func() -> void: Game.main.act("build", key)))
		else:
			var t: Turret = p.turret
			var d2: Dictionary = Game.TT[t.type]
			var st: Dictionary = t.stat()
			_title(head, d2["jp"], d2["name"])
			var tg: String = "GROUND + AIR" if (st["ground"] and st["air"]) else ("AIR ONLY" if st["air"] else "GROUND ONLY")
			var bname: String = ""
			if t.branch != "":
				var bd: Dictionary = Game.BRANCH[t.type][t.branch]
				bname = "  ·  %s %s" % [bd["jp"], bd["name"]]
			var sub: Label = _label("%s  ·  %s%s" % [_stars(t.lvl, 4), tg, bname], 12, GOLD)
			panel_box.add_child(sub)
			panel_box.add_child(_hp_bar(t.hp / Game.max_hp(t.lvl)))
			var nx: Dictionary = Game.tstat(t.type, t.lvl + 1, t.branch) if t.lvl < Game.MAXL else {}
			var grid: GridContainer = GridContainer.new()
			grid.columns = 3
			grid.add_theme_constant_override("h_separation", 18)
			panel_box.add_child(grid)
			_cell(grid, "DAMAGE", "%d" % roundi(st["dmg"]), "" if nx.is_empty() else "%d" % roundi(nx["dmg"]))
			_cell(grid, "PER SEC", "%.2f" % float(st["rate"]), "" if nx.is_empty() else "%.2f" % float(nx["rate"]))
			_cell(grid, "RANGE", "%d" % roundi(st["range"]), "" if nx.is_empty() else "%d" % roundi(nx["range"]))
			if t.lvl == 2:
				var uc2: int = Game.up_cost(t.type, t.lvl)
				panel_box.add_child(_label("LEVEL 3: CHOOSE A PATH", 11, DIM))
				for br: String in ["a", "b"]:
					var bd2: Dictionary = Game.BRANCH[t.type][br]
					panel_box.add_child(_item(bd2["jp"], "%s  %s" % [br.to_upper(), bd2["name"]], bd2["desc"], "¥%d" % uc2, f < uc2,
						func() -> void: Game.main.act("up", br)))
			var row2: HFlowContainer = HFlowContainer.new()
			panel_box.add_child(row2)
			if t.lvl == 2:
				pass
			elif t.lvl < Game.MAXL:
				var uc: int = Game.up_cost(t.type, t.lvl)
				var bu: Button = _button("強化 UPGRADE ¥%d [U]" % uc, func() -> void: Game.main.act("up", ""))
				bu.disabled = f < uc
				row2.add_child(bu)
			else:
				var bm: Button = _button("MAX LEVEL", func() -> void: pass)
				bm.disabled = true
				row2.add_child(bm)
			row2.add_child(_button("搭乗 MAN [F]", func() -> void: Game.player.enter(t)))
			var rc: int = ceili((Game.max_hp(t.lvl) - t.hp) * 0.5)
			var brp: Button = _button("修理 ¥%d [R]" % rc, func() -> void: Game.main.act("rep", ""))
			brp.disabled = rc <= 0 or f < rc
			row2.add_child(brp)
			row2.add_child(_button("売却 SELL ¥%d [X]" % roundi(float(t.spent) * 0.6), func() -> void: Game.main.act("sell", "")))
	var close: Button = _button("✕", func() -> void: Game.main.select(null))
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	var sp: Control = Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	head.add_child(close)


func _title(row: HBoxContainer, jp: String, en: String) -> void:
	row.add_child(_label(jp, 22, SHU, true))
	row.add_child(_label(en, 20, PAPER, true))


func _stars(l: int, n: int) -> String:
	return "★".repeat(l) + "☆".repeat(n - l)


func _hp_bar(f: float) -> ProgressBar:
	var b: ProgressBar = ProgressBar.new()
	b.custom_minimum_size = Vector2(0, 5)
	b.show_percentage = false
	b.max_value = 1.0
	b.step = 0.0
	b.value = clampf(f, 0.0, 1.0)
	if f < 0.35:
		var fl: StyleBoxFlat = StyleBoxFlat.new()
		fl.bg_color = BLOOD
		b.add_theme_stylebox_override("fill", fl)
	return b


func _cell(grid: GridContainer, k: String, v: String, nx: String) -> void:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	grid.add_child(box)
	box.add_child(_label(k, 10, DIM))
	box.add_child(_label(v + ("" if nx == "" else " → " + nx), 14, GOLD if nx != "" else PAPER))


func _item(kj: String, name: String, desc: String, cost: String, disabled: bool, cb: Callable) -> Button:
	var b: Button = _button("", cb)
	b.disabled = disabled
	b.custom_minimum_size = Vector2(0, 50)
	var h: HBoxContainer = HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 8
	h.offset_right = -10
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var k: Label = _label(kj, 22, JADE if not disabled else Color(JADE, 0.4), true)
	k.custom_minimum_size = Vector2(36, 0)
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	k.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(k)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	v.add_child(_label(name, 14, PAPER if not disabled else Color(DIM, 0.7)))
	v.add_child(_label(desc, 11, DIM))
	var c: Label = _label(cost, 15, GOLD if not disabled else Color(GOLD, 0.4))
	c.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(c)
	return b


# ------------------------------------------------------------------ actions, banner, fps --

func _build_acts() -> void:
	acts = VBoxContainer.new()
	acts.anchor_left = 1.0
	acts.anchor_right = 1.0
	acts.anchor_top = 1.0
	acts.anchor_bottom = 1.0
	acts.offset_right = -14
	acts.offset_bottom = -14
	acts.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	acts.grow_vertical = Control.GROW_DIRECTION_BEGIN
	acts.add_theme_constant_override("separation", 6)
	root.add_child(acts)
	var man: Button = _button("搭乗 MAN A GUN  [F]", func() -> void: Game.player.enter(null))
	man.add_theme_stylebox_override("normal", _box(Color(0.06, 0.2, 0.15, 0.88), JADE, 1))
	man.add_theme_font_size_override("font_size", 18)
	acts.add_child(man)
	acts.add_child(_button("飛行船 RAIJIN-MARU  [Z]", func() -> void:
		if Game.sel is String and Game.sel == "zep":
			Game.player.enter("zep")
		else:
			Game.main.select("zep")))
	acts.add_child(_button("武器庫 ARMORY  [B]", func() -> void: Game.main.select(null if (Game.sel is String and Game.sel == "armory") else "armory")))
	# Special attacks along the bottom.
	abil_bar = HBoxContainer.new()
	abil_bar.anchor_left = 0.5
	abil_bar.anchor_right = 0.5
	abil_bar.anchor_top = 1.0
	abil_bar.anchor_bottom = 1.0
	abil_bar.offset_bottom = -14
	abil_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	abil_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	abil_bar.add_theme_constant_override("separation", 6)
	root.add_child(abil_bar)
	for k: String in Abilities.ORDER:
		var d: Dictionary = Abilities.DEFS[k]
		var v: VBoxContainer = VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		abil_bar.add_child(v)
		var b: Button = _button("%s %s [%s]" % [d["jp"], d["name"], d["key"]], func() -> void: Game.abilities.request(k))
		b.tooltip_text = d["desc"]
		b.add_theme_font_size_override("font_size", 13)
		v.add_child(b)
		var pb: ProgressBar = ProgressBar.new()
		pb.custom_minimum_size = Vector2(0, 3)
		pb.show_percentage = false
		pb.max_value = 1.0
		pb.step = 0.0
		pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(pb)
		abil_buttons[k] = b
		abil_bars[k] = pb
	target_hint = _label("", 16, GOLD)
	target_hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	target_hint.anchor_top = 0.14
	target_hint.anchor_bottom = 0.14
	target_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	target_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_hint.label_settings.outline_size = 6
	target_hint.label_settings.outline_color = Color(0, 0, 0, 0.9)
	root.add_child(target_hint)


func _build_banner() -> void:
	banner_box = VBoxContainer.new()
	banner_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner_box.anchor_top = 0.2
	banner_box.anchor_bottom = 0.2
	banner_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(banner_box)
	banner_big = _label("", 76, SHU, true)
	banner_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_big.label_settings.outline_size = 10
	banner_big.label_settings.outline_color = Color(0, 0, 0, 0.9)
	banner_big.label_settings.shadow_color = Color(1, 0.1, 0.1, 0.4)
	banner_big.label_settings.shadow_size = 18
	banner_box.add_child(banner_big)
	banner_small = _label("", 20, Color.WHITE)
	banner_small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_small.label_settings.outline_size = 6
	banner_small.label_settings.outline_color = Color(0, 0, 0, 0.9)
	banner_box.add_child(banner_small)
	banner_box.modulate.a = 0.0


func show_banner(big: String, small: String, duration: float) -> void:
	banner_big.text = big
	banner_small.text = small
	banner_box.modulate.a = 1.0
	_banner_t = duration


func _build_fps() -> void:
	fps_box = VBoxContainer.new()
	fps_box.anchor_left = 0.5
	fps_box.anchor_right = 0.5
	fps_box.anchor_top = 1.0
	fps_box.anchor_bottom = 1.0
	fps_box.offset_bottom = -14
	fps_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	fps_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	fps_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fps_box.add_theme_constant_override("separation", 2)
	root.add_child(fps_box)
	fps_seat = _label("", 12, DIM)
	fps_seat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fps_box.add_child(fps_seat)
	fps_weap = _label("", 26, JADE, true)
	fps_weap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fps_box.add_child(fps_weap)
	fps_bar = ProgressBar.new()
	fps_bar.custom_minimum_size = Vector2(240, 6)
	fps_bar.show_percentage = false
	fps_bar.max_value = 1.0
	fps_bar.step = 0.0
	fps_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	fps_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fps_box.add_child(fps_bar)
	fps_abil = _label("", 12, GOLD)
	fps_abil.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fps_box.add_child(fps_abil)
	fps_hint = _label("", 12, DIM)
	fps_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fps_box.add_child(fps_hint)
	fps_box.visible = false


func on_seat_changed() -> void:
	var pl: Player = Game.player
	fps_box.visible = pl.active
	if pl.active:
		fps_seat.text = pl.seat_name()
		fps_weap.text = "機関砲 GUNNER" if pl.weapon == "gun" else "噴進砲 ROCKETEER"
		fps_weap.label_settings.font_color = JADE if pl.weapon == "gun" else GOLD
		if pl.seat is String:
			fps_hint.text = "WASD fly the airship · Mouse aim · Click fire · Right-click zoom · Q swap weapon · Tab next gun · Esc leave"
		else:
			fps_hint.text = "Mouse aim · Click fire · Right-click zoom · Q / wheel swap weapon · R reload · Tab next gun · Esc leave"
	refresh(true)


# ------------------------------------------------------------------ title & game over --

func _screen_bg() -> ColorRect:
	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.027, 0.024, 0.05, 0.55)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bg


func _build_title() -> void:
	title_screen = Control.new()
	title_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title_screen)
	title_screen.add_child(_screen_bg())
	var cc: CenterContainer = CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_screen.add_child(cc)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	cc.add_child(v)
	var logo: Label = _label("怪獣海岸", 100, SHU, true)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.label_settings.outline_size = 14
	logo.label_settings.outline_color = Color(0.05, 0, 0.02)
	logo.label_settings.shadow_color = Color(1.0, 0.15, 0.1, 0.5)
	logo.label_settings.shadow_size = 30
	v.add_child(logo)
	var en: Label = _label("K A I J U   C O A S T", 30, Color.WHITE, true)
	en.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	en.label_settings.shadow_color = Color(SAKURA, 0.6)
	en.label_settings.shadow_size = 12
	v.add_child(en)
	var tag: Label = _label("赤い月の夜、海が歩き出した — the blood moon is up, and the sea is walking.", 15, SAKURA)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tag)
	var deploy: Button = _button("出撃  DEPLOY", func() -> void: Game.new_game())
	deploy.add_theme_font_override("font", Mats.font_display())
	deploy.add_theme_font_size_override("font_size", 28)
	deploy.add_theme_stylebox_override("normal", _box(Color(0.35, 0.05, 0.04, 0.85), SHU, 2))
	deploy.add_theme_stylebox_override("hover", _box(Color(0.55, 0.08, 0.06, 0.95), Color.WHITE, 2))
	deploy.custom_minimum_size = Vector2(300, 60)
	deploy.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(deploy)
	var how: PanelContainer = PanelContainer.new()
	how.custom_minimum_size = Vector2(620, 0)
	how.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(how)
	var hv: VBoxContainer = VBoxContainer.new()
	hv.add_theme_constant_override("separation", 6)
	how.add_child(hv)
	var intro: Label = _label("Giant kaiju are wading in from Oni-ga-shima. Build guns along the seawall and on the sea forts, upgrade them between waves, and fit out the airship Raijin-maru. Then climb into any gun and fire it yourself. Shoot out the glowing eyes and cores. Don't let them reach the city.", 12, Color(0.86, 0.82, 0.91))
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size = Vector2(590, 0)
	hv.add_child(intro)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	hv.add_child(grid)
	for row: Array in [["Click a ring", "Build or upgrade a gun"], ["Drag · A/D · wheel", "Pan and zoom the command view"],
			["F · Z", "Man the selected gun · board the airship"], ["Mouse · click · Q", "Aim · fire · swap machine gun and rockets"],
			["Tab · Esc", "Jump to the next gun · back to command (Esc: menu)"], ["7 · 8 · 9", "Airstrike · lightning storm · flood gates"],
			["Space · T · P · M", "Next wave · speed · pause · music"], ["Controller", "Fully supported: see Settings"]]:
		grid.add_child(_label(row[0], 12, JADE))
		grid.add_child(_label(row[1], 12, PAPER))
	var drow: HBoxContainer = HBoxContainer.new()
	drow.alignment = BoxContainer.ALIGNMENT_CENTER
	drow.add_theme_constant_override("separation", 8)
	v.add_child(drow)
	for d: int in range(3):
		var db: Button = _button(Settings.DIFFICULTY_NAMES[d], func() -> void:
			Settings.set_v("difficulty", d)
			_sync_difficulty())
		db.toggle_mode = true
		drow.add_child(db)
		diff_buttons.append(db)
	best_label = _label("", 13, DIM)
	best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(best_label)
	var trow: HBoxContainer = HBoxContainer.new()
	trow.alignment = BoxContainer.ALIGNMENT_CENTER
	trow.add_theme_constant_override("separation", 10)
	v.add_child(trow)
	trow.add_child(_button("設定 SETTINGS", func() -> void: show_settings("title")))
	if not OS.has_feature("web"):
		trow.add_child(_button("終了 QUIT", func() -> void: get_tree().quit()))
	title_screen.set_meta("focus", deploy)


func _build_over() -> void:
	over_screen = Control.new()
	over_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	over_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(over_screen)
	over_screen.add_child(_screen_bg())
	var cc: CenterContainer = CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	over_screen.add_child(cc)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	cc.add_child(v)
	over_big = _label("都市陥落", 96, SHU, true)
	over_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	over_big.label_settings.outline_size = 12
	over_big.label_settings.outline_color = Color(0.05, 0, 0.02)
	v.add_child(over_big)
	over_en = _label("THE CITY HAS FALLEN", 30, Color.WHITE, true)
	over_en.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(over_en)
	over_stats = _label("", 16, SAKURA)
	over_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(over_stats)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var again: Button = _button("再出撃  TRY AGAIN", func() -> void: Game.new_game())
	again.add_theme_font_override("font", Mats.font_display())
	again.add_theme_font_size_override("font_size", 22)
	row.add_child(again)
	over_endless = _button("続行  KEEP FIGHTING", func() -> void: Game.continue_endless())
	over_endless.add_theme_font_override("font", Mats.font_display())
	over_endless.add_theme_font_size_override("font_size", 22)
	row.add_child(over_endless)
	row.add_child(_button("TITLE", func() -> void: Game.main.to_title()))
	over_screen.set_meta("focus", again)
	over_screen.visible = false


func show_over(win: bool) -> void:
	over_big.text = "勝利" if win else "都市陥落"
	over_en.text = "THE COAST HOLDS" if win else "THE CITY HAS FALLEN"
	if win:
		over_stats.text = "All %d waves held. %d kaiju destroyed." % [Game.WIN_WAVE, Game.kills]
	else:
		over_stats.text = "You held %d waves. %d kaiju destroyed." % [maxi(0, Game.wave - 1), Game.kills]
	over_endless.visible = win
	over_stats.text += "  ·  " + Settings.DIFFICULTY_NAMES[Game.difficulty]
	(over_screen.get_meta("focus") as Button).call_deferred("grab_focus")


func _on_state() -> void:
	var play: bool = Game.state == Game.State.PLAY
	title_screen.visible = Game.state == Game.State.TITLE
	over_screen.visible = Game.state == Game.State.OVER
	top.visible = play
	acts.visible = play and not Game.player.active
	if Game.state == Game.State.TITLE:
		best_label.text = ("最高記録 BEST: WAVE %d" % Game.best) if Game.best > 0 else ""
		_sync_difficulty()
		(title_screen.get_meta("focus") as Button).call_deferred("grab_focus")
	else:
		get_viewport().gui_release_focus()
	pause_menu.visible = false
	settings_menu.visible = false
	refresh(true)


func _sync_difficulty() -> void:
	var d: int = int(Settings.get_v("difficulty"))
	for i: int in range(diff_buttons.size()):
		diff_buttons[i].set_pressed_no_signal(i == d)


# ------------------------------------------------------------------ tutorial, pause, settings --

func _build_tutorial() -> void:
	tut_box = PanelContainer.new()
	var st: StyleBoxFlat = _box(Color(0.05, 0.04, 0.09, 0.94), GOLD, 1)
	st.border_width_left = 4
	st.content_margin_left = 14
	st.content_margin_right = 12
	st.content_margin_top = 10
	st.content_margin_bottom = 10
	tut_box.add_theme_stylebox_override("panel", st)
	tut_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	tut_box.anchor_top = 0.0
	tut_box.offset_top = 74
	tut_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(tut_box)
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	tut_box.add_child(h)
	h.add_child(_label("指南", 20, GOLD, true))
	tut_label = _label("", 15, PAPER)
	tut_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tut_label.custom_minimum_size = Vector2(560, 0)
	h.add_child(tut_label)
	h.add_child(_button("SKIP", func() -> void: Game.tutorial.skip(), false))
	tut_box.visible = false


func show_tutorial(text: String) -> void:
	tut_label.text = text
	tut_box.visible = text != ""


func _overlay() -> Control:
	var o: Control = Control.new()
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(o)
	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.015, 0.04, 0.7)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	o.add_child(bg)
	var cc: CenterContainer = CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	o.add_child(cc)
	var p: PanelContainer = PanelContainer.new()
	p.custom_minimum_size = Vector2(420, 0)
	var st: StyleBoxFlat = _box(Color(0.04, 0.03, 0.07, 0.97), LINE, 1)
	st.border_width_top = 3
	st.border_color = SHU
	st.content_margin_left = 22
	st.content_margin_right = 22
	st.content_margin_top = 18
	st.content_margin_bottom = 20
	p.add_theme_stylebox_override("panel", st)
	cc.add_child(p)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	o.set_meta("box", v)
	o.visible = false
	return o


func _build_pause() -> void:
	pause_menu = _overlay()
	var v: VBoxContainer = pause_menu.get_meta("box")
	var t: Label = _label("一時停止  PAUSED", 30, SHU, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var resume: Button = _button("再開  RESUME", func() -> void: Game.main.toggle_pause())
	v.add_child(resume)
	v.add_child(_button("設定  SETTINGS", func() -> void: show_settings("pause")))
	v.add_child(_button("タイトル  QUIT TO TITLE", func() -> void:
		Game.paused = false
		Game.main.to_title()))
	if not OS.has_feature("web") and not OS.has_feature("mobile"):
		v.add_child(_button("終了  QUIT GAME", func() -> void: get_tree().quit()))
	pause_menu.set_meta("focus", resume)


func show_pause(on: bool) -> void:
	pause_menu.visible = on
	settings_menu.visible = false
	if on:
		(pause_menu.get_meta("focus") as Button).call_deferred("grab_focus")
	else:
		get_viewport().gui_release_focus()


func _build_settings() -> void:
	settings_menu = _overlay()
	var v: VBoxContainer = settings_menu.get_meta("box")
	var t: Label = _label("設定  SETTINGS", 30, SHU, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	_slider_row(grid, "Mouse sensitivity", "sensitivity", 0.0006, 0.006)
	_check_row(grid, "Invert Y", "invert_y")
	_slider_row(grid, "Music volume", "music_vol", 0.0, 1.0)
	_slider_row(grid, "Effects volume", "sfx_vol", 0.0, 1.0)
	_slider_row(grid, "Voice volume", "voice_vol", 0.0, 1.0)
	grid.add_child(_label("Graphics", 15, PAPER))
	var q: OptionButton = OptionButton.new()
	for n: String in Settings.QUALITY_NAMES:
		q.add_item(n)
	q.item_selected.connect(func(i: int) -> void: Settings.set_v("quality", i))
	grid.add_child(q)
	_set_widgets["quality"] = q
	_check_row(grid, "CRT scanlines", "crt")
	if not OS.has_feature("mobile"):
		_check_row(grid, "Fullscreen", "fullscreen")
	_check_row(grid, "Show the tutorial", "tutorial")
	v.add_child(_label("Controller: sticks aim and pan, RT fire, LT zoom, A select, B back, Y man a gun / swap,\nX airship / reload, LB RB cycle guns, d-pad special attacks, Start next wave, Back pause.", 11, DIM))
	var back: Button = _button("戻る  BACK", func() -> void: close_settings())
	v.add_child(back)
	settings_menu.set_meta("focus", back)


func _slider_row(grid: GridContainer, label: String, key: String, lo: float, hi: float) -> void:
	grid.add_child(_label(label, 15, PAPER))
	var s: HSlider = HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = (hi - lo) / 100.0
	s.custom_minimum_size = Vector2(220, 24)
	s.value_changed.connect(func(val: float) -> void: Settings.set_v(key, val))
	grid.add_child(s)
	_set_widgets[key] = s


func _check_row(grid: GridContainer, label: String, key: String) -> void:
	grid.add_child(_label(label, 15, PAPER))
	var c: CheckButton = CheckButton.new()
	c.toggled.connect(func(on: bool) -> void: Settings.set_v(key, on))
	grid.add_child(c)
	_set_widgets[key] = c


func refresh_settings() -> void:
	for k: String in _set_widgets:
		var w: Control = _set_widgets[k]
		if w is HSlider:
			(w as HSlider).set_value_no_signal(float(Settings.get_v(k)))
		elif w is CheckButton:
			(w as CheckButton).set_pressed_no_signal(bool(Settings.get_v(k)))
		elif w is OptionButton:
			(w as OptionButton).select(int(Settings.get_v(k)))


func show_settings(from: String) -> void:
	_settings_from = from
	refresh_settings()
	pause_menu.visible = false
	settings_menu.visible = true
	(settings_menu.get_meta("focus") as Button).call_deferred("grab_focus")


func close_settings() -> void:
	settings_menu.visible = false
	if _settings_from == "pause":
		show_pause(true)
	elif Game.state == Game.State.TITLE:
		(title_screen.get_meta("focus") as Button).call_deferred("grab_focus")


func menu_open() -> bool:
	return pause_menu.visible or settings_menu.visible


## Back out of whatever menu is open (Esc or the controller's B).
func back() -> void:
	if settings_menu.visible:
		close_settings()
	elif pause_menu.visible:
		Game.main.toggle_pause()


## Controller: put focus on the first usable button in the side panel.
func focus_panel() -> void:
	for c: Node in panel_box.get_children():
		var b: Button = _first_button(c)
		if b != null:
			b.grab_focus()
			return


func _first_button(n: Node) -> Button:
	if n is Button and not (n as Button).disabled and (n as Button).focus_mode != Control.FOCUS_NONE:
		return n
	for c: Node in n.get_children():
		var b: Button = _first_button(c)
		if b != null:
			return b
	return null


# ------------------------------------------------------------------ per frame --

func refresh(force: bool = false) -> void:
	var play: bool = Game.state == Game.State.PLAY
	acts.visible = play and not Game.player.active
	abil_bar.visible = play and not Game.player.active
	target_hint.visible = play and Game.abilities.targeting != ""
	if not play:
		panel.visible = false
		return
	var ab: Abilities = Game.abilities
	var line: PackedStringArray = PackedStringArray()
	for k: String in Abilities.ORDER:
		var d: Dictionary = Abilities.DEFS[k]
		var b: Button = abil_buttons[k]
		var ready: bool = ab.is_ready(k)
		var cdv: float = float(ab.cd[k])
		var state_txt: String = "READY" if ready else ("WAVE %d" % int(d["unlock"]) if not ab.unlocked(k) else "%ds" % ceili(cdv))
		b.text = "%s %s [%s]  %s" % [d["jp"], d["name"], d["key"], state_txt]
		b.disabled = not ready
		(abil_bars[k] as ProgressBar).value = 1.0 if ready else (1.0 - cdv / float(d["cd"]) if ab.unlocked(k) else 0.0)
		if ab.targeting == k:
			b.add_theme_stylebox_override("normal", _box(Color(0.3, 0.22, 0.04, 0.9), GOLD, 2))
		else:
			b.remove_theme_stylebox_override("normal")
		line.append("%s %s %s" % [d["key"], d["jp"], state_txt])
	fps_abil.text = "  ·  ".join(line)
	if ab.targeting != "":
		target_hint.text = "Click the sea to call %s · right-click or Esc to cancel" % Abilities.DEFS[ab.targeting]["name"]
	s_funds.text = "¥%d" % Game.funds
	var c: int = maxi(0, ceili(Game.city))
	s_city.text = "%d%%" % c
	s_city_bar.value = c
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = BLOOD if c < 30 else (GOLD if c < 60 else JADE)
	s_city_bar.add_theme_stylebox_override("fill", fill)
	s_wave.text = ("%d" % Game.wave) if Game.endless else ("%d/%d" % [Game.wave, Game.WIN_WAVE])
	s_zep.text = ("撃墜 %ds" % ceili(30.0 - Game.zep.down_t)) if Game.zep.down else ("%d%%" % ceili(Game.zep.hp / Game.zep.max_hp * 100.0))
	s_kaiju.text = "%d" % (Game.live_kaiju() + Game.spawn_q.size())
	b_wave.disabled = Game.phase != "build"
	b_wave.text = ("次の波 NEXT WAVE %ds  [Space]" % maxi(0, ceili(Game.countdown))) if Game.phase == "build" else "交戦中 KAIJU INCOMING"
	b_speed.text = "×%d" % Game.speed
	b_pause.text = "再開 RESUME" if Game.paused else "一時停止 PAUSE"
	b_music.text = "♪ ON" if Game.music.enabled else "♪ OFF"
	var show_panel: bool = Game.sel != null and not Game.player.active
	panel.visible = show_panel
	if show_panel:
		var sig: String = _panel_sig()
		if force or sig != _sig:
			_sig = sig
			_rebuild_panel()
			if Game.main.using_pad:
				call_deferred("focus_panel")
	if Game.player.active:
		var pl: Player = Game.player
		if pl.weapon == "gun":
			fps_bar.value = pl.heat
		else:
			fps_bar.value = (1.0 - pl.reload / 2.1) if pl.reload > 0.0 else float(pl.ammo) / float(4 + int(Game.armory["rkt"]))


func _process(delta: float) -> void:
	if _banner_t > 0.0:
		_banner_t -= delta
		if _banner_t <= 0.0:
			create_tween().tween_property(banner_box, "modulate:a", 0.0, 0.35)
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.2
		refresh()
