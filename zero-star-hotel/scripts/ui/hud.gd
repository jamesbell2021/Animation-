extends CanvasLayer
## The hotel HUD, built for thumbs: cash, stars and reputation, the clock, and guests along
## the top; price buttons and a big UPGRADES button bottom-left; a live list of incidents
## bottom-right (tap one to send the manager). Toasts and event banners appear centre-top.
## Taps that miss every control fall through to the hotel camera.

const ShopMenu := preload("res://scripts/ui/shop_menu.gd")
const PauseMenu := preload("res://scripts/ui/pause_menu.gd")

var world: Node

var _root: Control
var _cash: Label
var _rep: Label
var _stars: Array[Widgets.Icon] = []
var _clock: Label
var _phase: Label
var _guests: Label
var _room_btn: Button
var _pint_btn: Button
var _alerts: VBoxContainer
var _alert_rows := {}
var _inspector: Label
var _toasts: VBoxContainer
var _banner: PanelContainer
var _fps: Label
var _cash_shown := 0.0


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	UITheme.safe_margins(_root)
	_build_top()
	_build_bottom()
	_build_feedback()
	Economy.cash_changed.connect(_on_cash)
	Economy.prices_changed.connect(_refresh_prices)
	Hotel.review_added.connect(func(_r): _refresh_rep())
	Hotel.stars_changed.connect(func(_s): _refresh_rep())
	Hotel.guests_changed.connect(_refresh_guests)
	Hotel.rooms_changed.connect(_refresh_guests)
	Hotel.inspection_changed.connect(_refresh_inspector)
	GameManager.toast.connect(toast)
	GameManager.time_changed.connect(_on_time)
	GameManager.phase_changed.connect(func(p): _phase.text = p)
	GameManager.back_pressed.connect(_on_back)
	RandomEvents.event_started.connect(_on_event)
	_cash_shown = Economy.cash
	_cash.text = Lines.money(Economy.cash)
	_refresh_prices()
	_refresh_rep()
	_refresh_guests()
	_refresh_inspector()
	_on_time(GameManager.hour)


func _pill(parent: Control, min_w: float) -> HBoxContainer:
	var p := UITheme.panel(Color(1, 0.98, 0.92, 0.94), 18)
	p.custom_minimum_size = Vector2(min_w, 0)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	return h


func _spacer(parent: Control) -> void:
	var s := Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(s)


func _build_top() -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 12
	bar.offset_right = -12
	bar.offset_top = 10
	bar.add_theme_constant_override("separation", 10)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bar)
	var cash := _pill(bar, 170)
	cash.add_child(Widgets.Icon.new("coin", 36))
	_cash = UITheme.label("€0", 28)
	cash.add_child(_cash)
	var stars := _pill(bar, 230)
	for k in 3:
		var s := Widgets.Icon.new("star", 32)
		stars.add_child(s)
		_stars.append(s)
	_rep = UITheme.label("", 18)
	stars.add_child(_rep)
	_spacer(bar)
	var clock := _pill(bar, 200)
	clock.add_child(Widgets.Icon.new("clock", 32))
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 0)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clock.add_child(cv)
	_clock = UITheme.label("Day 1 08:00", 20)
	cv.add_child(_clock)
	_phase = UITheme.label("Morning", 15, UITheme.SEA_DARK)
	cv.add_child(_phase)
	_spacer(bar)
	var g := _pill(bar, 200)
	_guests = UITheme.label("", 18)
	g.add_child(_guests)
	var pause := UITheme.button("II", UITheme.SEA, Vector2(68, 68), 28)
	pause.pressed.connect(open_pause)
	bar.add_child(pause)


func _build_bottom() -> void:
	var left := VBoxContainer.new()
	left.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	left.offset_left = 14
	left.offset_bottom = -14
	left.grow_vertical = Control.GROW_DIRECTION_BEGIN
	left.add_theme_constant_override("separation", 8)
	_root.add_child(left)
	var prices := HBoxContainer.new()
	prices.add_theme_constant_override("separation", 8)
	left.add_child(prices)
	_room_btn = UITheme.button("Rooms", UITheme.LEMON, Vector2(150, 58), 17)
	_room_btn.pressed.connect(_on_room_price)
	prices.add_child(_room_btn)
	_pint_btn = UITheme.button("Pints", UITheme.LEMON, Vector2(150, 58), 17)
	_pint_btn.pressed.connect(_on_pint_price)
	prices.add_child(_pint_btn)
	var shop := UITheme.button("UPGRADES", UITheme.LIME, Vector2(308, 88), 32)
	shop.pressed.connect(open_shop)
	left.add_child(shop)
	# Incident list, bottom-right.
	var right := VBoxContainer.new()
	right.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	right.offset_right = -14
	right.offset_bottom = -14
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.grow_vertical = Control.GROW_DIRECTION_BEGIN
	right.add_theme_constant_override("separation", 6)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(right)
	_inspector = UITheme.label("", 18, Color("#ffd23f"), 8)
	_inspector.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_inspector)
	_alerts = VBoxContainer.new()
	_alerts.add_theme_constant_override("separation", 6)
	_alerts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(_alerts)


func _build_feedback() -> void:
	_toasts = VBoxContainer.new()
	_toasts.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toasts.offset_top = 96
	_toasts.offset_left = -330
	_toasts.offset_right = 330
	_toasts.add_theme_constant_override("separation", 6)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_toasts)
	_fps = UITheme.label("", 16, Color.WHITE, 4)
	_fps.position = Vector2(14, 96)
	_fps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fps)


# --- Updates -----------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if absf(_cash_shown - Economy.cash) > 0.01:
		_cash_shown = lerpf(_cash_shown, Economy.cash, clampf(delta * 8.0, 0.0, 1.0))
		if absf(_cash_shown - Economy.cash) < 0.05:
			_cash_shown = Economy.cash
		_cash.text = Lines.money(_cash_shown)
	_refresh_alerts()
	if Quality.show_fps:
		_fps.text = "%d FPS  %d people" % [Engine.get_frames_per_second(), world.guests.size()]
	elif _fps.text != "":
		_fps.text = ""


func _on_cash(cash: float, _delta: float) -> void:
	_cash.add_theme_color_override("font_color", UITheme.INK if cash >= 0.0 else UITheme.DANGER)


func _refresh_prices() -> void:
	_room_btn.text = "Rooms: %s" % Economy.ROOM_PRICES[Economy.room_price_index].name
	_pint_btn.text = Economy.PINT_PRICES[Economy.pint_price_index].name


func _refresh_rep() -> void:
	for k in 3:
		_stars[k].color = UITheme.LEMON if k < Hotel.stars else Color(0.8, 0.8, 0.8)
		_stars[k].queue_redraw()
	_rep.text = "%s\nReviews %.1f/5" % [Lines.STAR_NAMES[Hotel.stars], Hotel.reputation()]


func _refresh_guests() -> void:
	var open := Hotel.open_count()
	var booked := Hotel.occupancy()
	_guests.text = "%d guests\n%d/%d rooms booked" % [Hotel.guest_count(), booked, open]


func _refresh_inspector() -> void:
	if Hotel.inspector_visiting():
		_inspector.text = "INSPECTOR VISITING  strikes %d/%d" % [Hotel.strikes, Hotel.MAX_STRIKES + 1]
	elif Hotel.inspection_booked():
		_inspector.text = "Inspector booked: day %d" % Hotel.inspection_day
	else:
		_inspector.text = ""


func _on_time(_h: float) -> void:
	_clock.text = "Day %d  %s" % [GameManager.day, GameManager.time_string()]


func _refresh_alerts() -> void:
	var live := {}
	for inc in world.incidents:
		live[inc.get_instance_id()] = inc
	for id in _alert_rows.keys():
		if not live.has(id):
			_alert_rows[id].queue_free()
			_alert_rows.erase(id)
	for id in live:
		var inc: Incident = live[id]
		if not _alert_rows.has(id):
			var b := UITheme.button(_alert_label(inc), Incident.COLORS.get(inc.kind, UITheme.DANGER), Vector2(230, 54), 18)
			b.pressed.connect(_on_alert.bind(inc))
			_alerts.add_child(b)
			_alert_rows[id] = b
		var btn: Button = _alert_rows[id]
		var f := clampf(inc.fuse / inc.max_fuse, 0.0, 1.0)
		btn.text = "%s %s" % [_alert_label(inc), "(on it)" if inc.claimed_by else "%ds" % int(ceil(inc.fuse))]
		btn.modulate = Color.WHITE if f > 0.35 or int(Time.get_ticks_msec() / 250) % 2 == 0 else Color(1, 0.7, 0.7)


func _alert_label(inc: Incident) -> String:
	match inc.kind:
		"music": return "Rave %s" % Hotel.room_label(inc.room)
		"vandal": return "Vandal %s" % Hotel.room_label(inc.room)
		"fight": return "Fight!"
		"theft": return "Thief!"
		"pool": return "Pool help!"
		"lounger": return "Lounger war"
	return inc.kind


func _on_alert(inc: Incident) -> void:
	if not is_instance_valid(inc) or inc.done:
		return
	world.camera.position = inc.anchor + Vector2(0, -80)
	world.camera._clamp_position()
	world.dispatch_manager(inc)


# --- Buttons -----------------------------------------------------------------------------------

func _on_room_price() -> void:
	Economy.cycle_room_price()
	toast("Room price: %s. Higher prices mean fewer bookings and fussier guests." % Economy.ROOM_PRICES[Economy.room_price_index].name, "info")


func _on_pint_price() -> void:
	Economy.cycle_pint_price()
	toast("%s Cheaper pints sell more and get guests drunker." % Economy.PINT_PRICES[Economy.pint_price_index].name, "info")


func open_shop() -> void:
	if get_tree().paused:
		return
	add_child(ShopMenu.new())


func open_pause() -> void:
	if get_tree().paused:
		return
	add_child(PauseMenu.new())


func _on_back() -> void:
	if Overlay.stack.is_empty() and not get_tree().paused:
		open_pause.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if event.is_action_pressed("open_shop"):
		open_shop()
	elif event.is_action_pressed("room_price"):
		Economy.cycle_room_price()
	elif event.is_action_pressed("pint_price"):
		Economy.cycle_pint_price()


# --- Feedback ----------------------------------------------------------------------------------

func toast(text: String, kind := "info") -> void:
	var colors := {"info": UITheme.PANEL, "good": Color("#c8f7b0"), "bad": Color("#ffc4b8"),
		"warning": Color("#ffe082"), "tutorial": UITheme.LEMON}
	var p := UITheme.panel(colors.get(kind, UITheme.PANEL), 16)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UITheme.label(text, 19)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(600, 0)
	p.add_child(l)
	_toasts.add_child(p)
	while _toasts.get_child_count() > 3:
		var old := _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()
	var life := 6.5 if kind == "tutorial" else 3.8
	var tw := p.create_tween()
	p.modulate.a = 0.0
	tw.tween_property(p, "modulate:a", 1.0, 0.15)
	tw.tween_interval(life)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)


func _on_event(_id: String, def: Dictionary) -> void:
	if is_instance_valid(_banner):
		_banner.queue_free()
	_banner = UITheme.panel(Color("#fff3c4") if bool(def.get("good", true)) else Color("#ffd0c4"))
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.offset_left = -360
	_banner.offset_right = 360
	_banner.offset_top = -170
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(v)
	v.add_child(UITheme.title(str(def.title), 40))
	var l := UITheme.label(str(def.text), 20)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(680, 0)
	v.add_child(l)
	_root.add_child(_banner)
	var b := _banner
	b.pivot_offset = Vector2(360, 60)
	b.scale = Vector2(0.4, 0.4)
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(3.6)
	tw.tween_property(b, "modulate:a", 0.0, 0.4)
	tw.tween_callback(b.queue_free)
