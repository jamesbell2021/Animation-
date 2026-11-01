class_name Hud
extends CanvasLayer
## Retro terminal overlay: crew roster, hull and weapon readouts, wave/score, banners,
## off-screen threat arrows and the CRT filter on top of everything.

## One row per seat: [tag, status, device] labels in fixed-width columns (Japanese text is wide).
var roster: Array = []
var hull_label: Label
var weapons_label: Label
var wave_label: Label
var title_label: Label
var sub_label: Label
var help_label: Label
var toast_label: Label
var kana_label: Label
var banner_bg: Panel
var crt: ColorRect
var indicators: ThreatIndicators
var boss_label: Label
var touch: TouchControls
var gauge: RepairGauge
var _root: Control
## Hides the gameplay overlay (used when filming the trailer).
var hidden_for_film := false

var _banner_t := 0.0
var _toast_t := 0.0
var _time := 0.0


class ThreatIndicators extends Control:
	## Arrows on the screen edge pointing at enemies outside the view. They flash while aiming.
	var camera: Camera3D
	var time := 0.0

	func _process(delta: float) -> void:
		time += delta
		queue_redraw()

	func _draw() -> void:
		if camera == null:
			return
		var rect := get_viewport_rect().grow(-28.0)
		var center := rect.get_center()
		var half := rect.size * 0.5
		for node in get_tree().get_nodes_in_group("enemies"):
			var e: Enemy = node
			var p := e.global_position + Vector3(0, 1, 0)
			if camera.is_position_behind(p):
				continue
			var sp := camera.unproject_position(p)
			if rect.has_point(sp):
				continue
			var dir := (sp - center).normalized()
			var t := minf(half.x / maxf(absf(dir.x), 0.001), half.y / maxf(absf(dir.y), 0.001))
			var at := center + dir * t
			var side := dir.orthogonal()
			var col := e.color
			var size := 12.0 if e is EnemyTank else 8.0
			if e.is_aiming() and fmod(time, 0.2) < 0.1:
				col = Color.WHITE
				size *= 1.5
			draw_colored_polygon(PackedVector2Array([
				at + dir * size * 1.4, at + side * size - dir * size * 0.5, at - side * size - dir * size * 0.5]), col)


class RepairGauge extends Control:
	## The REPAIR station's timing game, drawn just above the reactor on every screen: a needle
	## sweeps across the bar; tap ACTION while it is in the green (bright middle = PERFECT).
	## Underneath, the shield charge that holding ACTION spends.
	const W := 330.0
	const H := 34.0
	var camera: Camera3D
	var _t := 0.0
	var _seen_seq := 0
	var _flash := 0.0
	var _flash_col := Color.WHITE
	var _combo_pop := 0.0
	var _last_combo := 0

	func _process(delta: float) -> void:
		_t += delta
		_flash = maxf(0.0, _flash - delta * 3.0)
		_combo_pop = maxf(0.0, _combo_pop - delta * 4.0)
		queue_redraw()

	func _draw() -> void:
		var tank := G.tank
		if tank == null or tank.dead or camera == null or not is_instance_valid(tank.reactor):
			return
		var st: MegaTank.Station = tank.stations["repair"]
		if st.occupant == null:
			return
		var col: Color = st.occupant.color
		if tank.grade_seq != _seen_seq:
			_seen_seq = tank.grade_seq
			_flash = 1.0
			match tank.last_grade:
				"perfect":
					_flash_col = Color(0.5, 1.0, 0.6)
				"good":
					_flash_col = Color(0.5, 0.9, 1.0)
				_:
					_flash_col = Color(1.0, 0.3, 0.2)
		if tank.combo > _last_combo:
			_combo_pop = 1.0
		_last_combo = tank.combo
		# Beside the tank (right of it on screen), clear of the crew panel and the touch buttons.
		var anchor := camera.unproject_position(tank.global_position + Vector3(0, 1.4, 0))
		var view := get_viewport_rect().size
		var x0 := clampf(anchor.x + 170.0, 16.0, view.x - W - 70.0)
		var y0 := clampf(anchor.y - 80.0, 260.0, view.y - 330.0)
		var font := G.jp_font
		# Panel
		draw_rect(Rect2(x0 - 10, y0 - 34, W + 20, H + 100), Color(0.0, 0.01, 0.03, 0.72))
		var title := G.t("REPAIR") if not st.jammed else G.t("JAMMED")
		draw_string(font, Vector2(x0, y0 - 10), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, col)
		var hint := G.t("TAP in the green   HOLD = shield")
		draw_string(font, Vector2(x0, y0 + H + 58), hint, HORIZONTAL_ALIGNMENT_CENTER, W, 17, Color(0.75, 0.85, 1.0, 0.8))
		# Bar, zone and perfect strip
		draw_rect(Rect2(x0, y0, W, H), Color(0.05, 0.08, 0.12, 0.9))
		var zc := tank.zone_center
		var zh := tank.zone_half
		var pf := zh * MegaTank.PERFECT_FRACTION
		var near := maxf(0.0, 1.0 - absf(tank.needle_now() - zc) / maxf(zh, 0.01))
		draw_rect(Rect2(x0 + (zc - zh) * W, y0, zh * 2.0 * W, H), Color(0.25, 1.0, 0.45, 0.35 + 0.3 * near))
		draw_rect(Rect2(x0 + (zc - pf) * W, y0, pf * 2.0 * W, H), Color(0.7, 1.0, 0.8, 0.75 + 0.25 * near))
		for i in range(1, 10):
			var tx := x0 + W * i / 10.0
			draw_line(Vector2(tx, y0 + H - 6), Vector2(tx, y0 + H), Color(1, 1, 1, 0.25), 1.0)
		var border := col.lerp(_flash_col, _flash)
		draw_rect(Rect2(x0, y0, W, H), border, false, 3.0 + 3.0 * _flash)
		# Needle
		var nx := x0 + tank.needle_now() * W
		var ncol := Color.WHITE if tank.rep_stun <= 0.0 else Color(1.0, 0.25, 0.15)
		draw_line(Vector2(nx, y0 - 8), Vector2(nx, y0 + H + 8), Color(ncol, 0.35), 11.0)
		draw_line(Vector2(nx, y0 - 8), Vector2(nx, y0 + H + 8), ncol, 4.0)
		# Combo
		if tank.combo >= 2:
			var size := int(26 + 14 * _combo_pop)
			draw_string(font, Vector2(x0 + W + 14, y0 + H - 4), "x%d" % tank.combo, HORIZONTAL_ALIGNMENT_LEFT,
					-1, size, Color(1.0, 0.9, 0.3))
		# Shield charge
		var sy := y0 + H + 14
		var frac := clampf(tank.shield / MegaTank.SHIELD_MAX, 0.0, 1.0)
		var scol := Color(0.4, 0.9, 1.0)
		var label := G.t("SHIELD")
		if tank.shield_up:
			scol = scol.lerp(Color.WHITE, 0.4 + 0.3 * sin(_t * 18.0))
			label = G.t("SHIELD UP")
		elif tank.shield_lock > 0.0:
			scol = Color(1.0, 0.3, 0.2)
			label = G.t("RECHARGING")
		elif tank.shield < MegaTank.SHIELD_MIN:
			scol = Color(0.4, 0.6, 0.8)
		draw_string(font, Vector2(x0, sy + 15), label, HORIZONTAL_ALIGNMENT_LEFT, 120, 17, scol)
		draw_rect(Rect2(x0 + 120, sy + 2, W - 120, 14), Color(0.05, 0.08, 0.12, 0.9))
		draw_rect(Rect2(x0 + 120, sy + 2, (W - 120) * frac, 14), Color(scol, 0.85))
		var min_x := x0 + 120 + (W - 120) * MegaTank.SHIELD_MIN / MegaTank.SHIELD_MAX
		draw_line(Vector2(min_x, sy), Vector2(min_x, sy + 18), Color(1, 1, 1, 0.5), 2.0)


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_root = root

	indicators = ThreatIndicators.new()
	indicators.set_anchors_preset(Control.PRESET_FULL_RECT)
	indicators.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(indicators)

	gauge = RepairGauge.new()
	gauge.set_anchors_preset(Control.PRESET_FULL_RECT)
	gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(gauge)

	var panel := PanelContainer.new()
	panel.position = Vector2(28, 22)
	panel.add_theme_stylebox_override("panel", _panel_style())
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	for i in 4:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		box.add_child(row)
		var cells := []
		for width in [230, 310, 180]:
			var l := _label(24, G.PLAYER_COLORS[i])
			l.custom_minimum_size.x = width
			l.clip_text = true
			row.add_child(l)
			cells.append(l)
		roster.append(cells)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	box.add_child(spacer)
	hull_label = _label(24, Color(0.4, 1.0, 0.5))
	box.add_child(hull_label)
	weapons_label = _label(20, Color(0.7, 0.9, 1.0))
	box.add_child(weapons_label)

	wave_label = _label(26, Color(0.4, 0.95, 1.0))
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_anchor(wave_label, 0.5, 1.0, 0.0, 0.0, Vector2(0, 30), Vector2(-40, 70))

	banner_bg = Panel.new()
	banner_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := _panel_style()
	bg.bg_color = Color(0.0, 0.01, 0.03, 0.6)
	banner_bg.add_theme_stylebox_override("panel", bg)
	root.add_child(banner_bg)
	title_label = _label(72, Color(1.0, 0.3, 0.85), G.jp_font)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_anchor(title_label, 0.0, 1.0, 0.1, 0.1, Vector2(0, 0), Vector2(0, 100))
	kana_label = _label(34, Color(0.3, 0.9, 1.0), G.jp_font)
	kana_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kana_label.text = "ネオン・メガ・タンク　～ 生き残れ！ ～"
	_anchor(kana_label, 0.0, 1.0, 0.1, 0.1, Vector2(0, 78), Vector2(0, 122))
	sub_label = _label(26, Color(0.85, 0.95, 1.0), G.jp_font)
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_anchor(sub_label, 0.0, 1.0, 0.1, 0.1, Vector2(0, 95), Vector2(0, 200))

	help_label = _label(19, Color(0.6, 0.75, 1.0))
	help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	help_label.add_theme_stylebox_override("normal", _panel_style())
	_anchor(help_label, 0.5, 0.5, 1.0, 1.0, Vector2(-430, -160), Vector2(430, -28))
	help_label.text = G.tx([
		["KEYBOARD 1   WASD move   E board/leave station   SPACE action"],
		["KEYBOARD 2   ARROWS move   R-SHIFT or / board/leave   ENTER action"],
		["GAMEPAD   L-STICK move   R-STICK aim guns   B / X / Y board/leave   A or RT action"],
		["REPAIR: tap ACTION when the needle is in the green - hold ACTION for an energy shield"],
		["F2 / BACK  AI crew on-off   M music   F1 CRT   F11 fullscreen   ESC quit / lobby"]])
	_anchor_help(5)

	if G.is_mobile():
		help_label.text = G.tx([
			["LEFT SIDE drag to move   ACTION fire / repair / patch breaches"],
			["REPAIR: tap ACTION when the needle is in the green - hold ACTION for an energy shield"],
			["BOARD get on or off the station you stand on   phone BACK  menu"]])
		_anchor_help(3)

	boss_label = _label(30, Color(0.95, 0.15, 0.35), G.jp_font)
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_anchor(boss_label, 0.0, 1.0, 1.0, 1.0, Vector2(0, -78), Vector2(0, -36))

	if G.is_mobile():
		touch = TouchControls.new()
		root.add_child(touch)

	toast_label = _label(28, Color(1.0, 0.9, 0.3), G.jp_font)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_anchor(toast_label, 0.0, 1.0, 1.0, 1.0, Vector2(0, -215), Vector2(0, -175))

	var crt_layer := CanvasLayer.new()
	crt_layer.layer = 20
	add_child(crt_layer)
	crt = ColorRect.new()
	crt.set_anchors_preset(Control.PRESET_FULL_RECT)
	crt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/crt.gdshader")
	crt.material = mat
	crt_layer.add_child(crt)
	# The CRT pass costs a full-screen copy; phones start without it (F1 toggles on desktop).
	crt.visible = not G.is_mobile()


func _anchor_help(lines: int) -> void:
	help_label.offset_left = -470.0
	help_label.offset_right = 470.0
	help_label.offset_top = -40.0 - lines * 28.0
	help_label.offset_bottom = -28.0


func _panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.0, 0.01, 0.03, 0.72)
	s.border_color = Color(0.2, 0.6, 1.0, 0.45)
	s.set_border_width_all(2)
	s.set_content_margin_all(12)
	return s


func _label(size: int, color: Color, font: Font = null) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", font if font else G.ui_font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tint(l, color)
	return l


func _tint(l: Label, color: Color) -> void:
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(color, 0.25))


func _anchor(l: Label, left: float, right: float, top: float, bottom: float,
		offset_tl: Vector2, offset_br: Vector2) -> void:
	l.anchor_left = left
	l.anchor_right = right
	l.anchor_top = top
	l.anchor_bottom = bottom
	l.offset_left = offset_tl.x
	l.offset_top = offset_tl.y
	l.offset_right = offset_br.x
	l.offset_bottom = offset_br.y
	get_child(0).add_child(l)


## In the lobby the title sits top-right, clear of the roster; banners are centred.
func _place_title(lobby: bool) -> void:
	var left := 0.44 if lobby else 0.0
	var top := 0.09 if lobby else 0.3
	for l in [title_label, sub_label, kana_label]:
		l.anchor_left = left
		l.anchor_top = top
		l.anchor_bottom = top
	kana_label.visible = lobby
	sub_label.offset_top = 130.0 if lobby else 100.0
	sub_label.offset_bottom = sub_label.offset_top + 170.0
	# Dark band behind the title block so it reads over the busy city.
	banner_bg.anchor_left = left
	banner_bg.anchor_right = 1.0
	banner_bg.anchor_top = top
	banner_bg.anchor_bottom = top
	banner_bg.offset_left = 20.0 if lobby else -10.0
	banner_bg.offset_right = -20.0 if lobby else 10.0
	banner_bg.offset_top = -10.0
	var lines := sub_label.get_line_count() if sub_label.text != "" else 0
	banner_bg.offset_bottom = sub_label.offset_top + 18.0 + lines * 36.0 if lines > 0 else 100.0
	banner_bg.modulate.a = title_label.modulate.a
	title_label.add_theme_font_size_override("font_size", 60 if lobby else 72)


## Title and subtitle are text specs (see G.tx), translated on this device.
func banner(title: Variant, subtitle: Variant = "", time := 2.5) -> void:
	title_label.text = G.tx(title)
	sub_label.text = G.tx(subtitle)
	_banner_t = time


func toast(text: Variant) -> void:
	toast_label.text = G.tx(text)
	_toast_t = 2.0


func _bar(fraction: float, width: int) -> String:
	var filled := clampi(int(round(fraction * width)), 0, width)
	return "█".repeat(filled) + "░".repeat(width - filled)


func refresh(main: Main, delta: float) -> void:
	_time += delta
	_root.visible = main.state != Main.State.MENU and not hidden_for_film
	if main.state == Main.State.MENU:
		return
	var tank := G.tank
	var boss := main.boss
	boss_label.visible = is_instance_valid(boss) and not boss.dead
	if boss_label.visible:
		boss_label.text = G.t("鬼戦車 ONI SENSHA  %s") % _bar(boss.hp / maxf(boss.max_hp, 1.0), 18)
	indicators.camera = main.camera
	gauge.camera = main.camera
	gauge.visible = main.state != Main.State.GAMEOVER
	for i in 4:
		var cells: Array = roster[i]
		var col: Color = G.PLAYER_COLORS[i]
		cells[0].text = "[P%d] (%s):" % [i + 1, G.t(G.PLAYER_NAMES[i])]
		if i < main.players.size():
			var crew: Crew = main.players[i]
			cells[1].text = crew.status_text()
			cells[2].text = PlayerInput.device_name(crew.input.device)
		else:
			cells[1].text = G.t("---- press ACTION to join")
			cells[2].text = ""
			col = col.darkened(0.65)
		for c in cells:
			_tint(c, col)

	var frac := tank.hp / MegaTank.MAX_HP
	var hull_col := Color(0.4, 1.0, 0.5) if frac > 0.5 else (Color(1.0, 0.85, 0.2) if frac > 0.25 else Color(1.0, 0.2, 0.15))
	if frac <= 0.25 and fmod(_time, 0.5) < 0.25:
		hull_col = hull_col.darkened(0.5)
	hull_label.text = G.t("HULL   %s %3d") % [_bar(frac, 20), int(ceil(tank.hp))]
	_tint(hull_label, hull_col)

	var heat := _bar(tank.mg_heat / 100.0, 6)
	var cannon := G.t("READY ") if tank.cannon_cd <= 0.0 else _bar(1.0 - tank.cannon_cd / MegaTank.CANNON_RELOAD, 6)
	var mg := (G.t("OVERHEAT ") if tank.mg_overheated else G.t("HEAT ")) + heat
	var shield := (G.t("UP ") if tank.shield_up else "") + _bar(tank.shield / MegaTank.SHIELD_MAX, 6)
	var breaches := tank.breaches.size()
	weapons_label.text = G.t("CANNON %s   MG %s   SHIELD %s   BREACHES %d") % [cannon, mg, shield, breaches]
	_tint(weapons_label, Color(1.0, 0.35, 0.25) if breaches > 0 and fmod(_time, 0.6) < 0.3 else Color(0.7, 0.9, 1.0))

	var enemies := get_tree().get_nodes_in_group("enemies").size() + main.spawn_queue.size()
	match main.state:
		Main.State.LOBBY:
			wave_label.text = G.t("AI CREW %s   BEST %s (WAVE %d)") % [
				G.t("ON" if G.ai_crew else "OFF"), G.format_time(G.best_time), G.best_wave]
		_:
			wave_label.text = G.t("TIME %s   WAVE %02d   HOSTILES %02d   SCORE %06d") % [
				G.format_time(main.survival_time), main.wave, enemies, G.score]
	if G.demo:
		wave_label.text += "\n" + G.t("DEMO  %s LEFT") % G.format_time(ceilf(G.demo_left))

	help_label.visible = main.state == Main.State.LOBBY
	_place_title(main.state == Main.State.LOBBY)
	if main.state == Main.State.LOBBY:
		title_label.text = "NEON MEGA TANK"
		if main.players.is_empty():
			sub_label.text = G.t("press ACTION on any keyboard half or gamepad to join")
		else:
			var lines: Array[String] = [G.t("friends: press ACTION to join (up to 4)")]
			if Net.is_host():
				lines = [G.t("HOSTING - friends tap JOIN LAN GAME on their phones"),
					G.t("or enter  %s") % "  /  ".join(Net.local_ips())]
			elif Net.is_client():
				lines = [G.t("connected to the host's tank over the LAN")]
			if G.ai_crew:
				lines.append(G.t("AI crew mans the empty stations"))
			lines.append(G.t("board DRIVE and roll the tank through the DEPLOY gate"))
			sub_label.text = "\n".join(lines)
		title_label.modulate.a = 1.0
		sub_label.modulate.a = 1.0
	elif main.state == Main.State.PLAYING:
		_banner_t -= delta
		var a := clampf(_banner_t * 2.0, 0.0, 1.0)
		title_label.modulate.a = a
		sub_label.modulate.a = a
	else:
		title_label.modulate.a = 1.0
		sub_label.modulate.a = 1.0
	_toast_t -= delta
	toast_label.modulate.a = clampf(_toast_t * 2.0, 0.0, 1.0)
