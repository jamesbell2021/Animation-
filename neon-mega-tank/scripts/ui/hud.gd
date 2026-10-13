class_name Hud
extends CanvasLayer
## Retro terminal overlay: crew roster, hull and weapon readouts, wave/score, banners,
## off-screen threat arrows and the CRT filter on top of everything.

var roster: Array[Label] = []
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

	var panel := PanelContainer.new()
	panel.position = Vector2(28, 22)
	panel.add_theme_stylebox_override("panel", _panel_style())
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	for i in 4:
		var l := _label(24, G.PLAYER_COLORS[i])
		box.add_child(l)
		roster.append(l)
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
	help_label.text = ("KEYBOARD 1   WASD move   E board/leave station   SPACE action\n"
		+ "KEYBOARD 2   ARROWS move   R-SHIFT or / board/leave   ENTER action\n"
		+ "GAMEPAD   L-STICK move   B / X / Y board/leave   A or RT action\n"
		+ "F2 / BACK  AI crew on-off   M music   F1 CRT   F11 fullscreen   ESC quit / lobby")

	if G.is_mobile():
		help_label.text = ("LEFT SIDE drag to move   ACTION fire / repair / patch breaches\n"
			+ "BOARD get on or off the station you stand on   phone BACK  menu")

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


func banner(title: String, subtitle := "", time := 2.5) -> void:
	title_label.text = title
	sub_label.text = subtitle
	_banner_t = time


func toast(text: String) -> void:
	toast_label.text = text
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
		boss_label.text = "鬼戦車 ONI SENSHA  %s" % _bar(boss.hp / maxf(boss.max_hp, 1.0), 18)
	indicators.camera = main.camera
	for i in 4:
		var l := roster[i]
		var col: Color = G.PLAYER_COLORS[i]
		var tag := "[P%d] %-9s" % [i + 1, "(%s):" % G.PLAYER_NAMES[i]]
		if i < main.players.size():
			var crew: Crew = main.players[i]
			l.text = "%s %-16s %s" % [tag, crew.status_text(), PlayerInput.device_name(crew.input.device)]
			_tint(l, col)
		else:
			l.text = "%s ---- press ACTION to join" % tag
			_tint(l, col.darkened(0.65))

	var frac := tank.hp / MegaTank.MAX_HP
	var hull_col := Color(0.4, 1.0, 0.5) if frac > 0.5 else (Color(1.0, 0.85, 0.2) if frac > 0.25 else Color(1.0, 0.2, 0.15))
	if frac <= 0.25 and fmod(_time, 0.5) < 0.25:
		hull_col = hull_col.darkened(0.5)
	hull_label.text = "HULL   %s %3d" % [_bar(frac, 20), int(ceil(tank.hp))]
	_tint(hull_label, hull_col)

	var cannon := "READY " if tank.cannon_cd <= 0.0 else _bar(1.0 - tank.cannon_cd / MegaTank.CANNON_RELOAD, 6)
	var mg := ("OVERHEAT " + _bar(tank.mg_heat / 100.0, 6)) if tank.mg_overheated else ("HEAT " + _bar(tank.mg_heat / 100.0, 6))
	var breaches := tank.breaches.size()
	weapons_label.text = "CANNON %s   MG %s   BREACHES %d" % [cannon, mg, breaches]
	_tint(weapons_label, Color(1.0, 0.35, 0.25) if breaches > 0 and fmod(_time, 0.6) < 0.3 else Color(0.7, 0.9, 1.0))

	var enemies := get_tree().get_nodes_in_group("enemies").size() + main.spawn_queue.size()
	match main.state:
		Main.State.LOBBY:
			wave_label.text = "AI CREW %s   BEST %s (WAVE %d)" % [
				"ON" if G.ai_crew else "OFF", G.format_time(G.best_time), G.best_wave]
		_:
			wave_label.text = "TIME %s   WAVE %02d   HOSTILES %02d   SCORE %06d" % [
				G.format_time(main.survival_time), main.wave, enemies, G.score]

	help_label.visible = main.state == Main.State.LOBBY
	_place_title(main.state == Main.State.LOBBY)
	if main.state == Main.State.LOBBY:
		title_label.text = "NEON MEGA TANK"
		if main.players.is_empty():
			sub_label.text = "press ACTION on any keyboard half or gamepad to join"
		else:
			var join_hint := "friends: press ACTION to join (up to 4)"
			if Net.is_host():
				join_hint = "HOSTING - friends tap JOIN LAN GAME on their phones\nor enter  %s" % "  /  ".join(Net.local_ips())
			elif Net.is_client():
				join_hint = "connected to the host's tank over the LAN"
			sub_label.text = ("%s%s\nboard DRIVE and roll the tank through the DEPLOY gate"
				% [join_hint, "\nAI crew mans the empty stations" if G.ai_crew else ""])
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
