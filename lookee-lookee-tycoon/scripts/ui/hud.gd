extends CanvasLayer
## The beach HUD, built for thumbs: cash, stock, clock and the Heat meter along the top;
## SHOP and PRICE bottom-left; SET UP / PACK UP and the giant SHOUT button bottom-right.
## Also shows toasts, event banners, police warnings, the chase meter and haggle offers.
## Taps that miss every button fall through to the beach camera.

const ShopMenu := preload("res://scenes/ui/shop_menu.tscn")
const PauseMenu := preload("res://scenes/ui/pause_menu.tscn")

var beach: Node

var _root: Control
var _cash: Label
var _stock: Label
var _clock: Label
var _beach_label: Label
var _day_bar: ProgressBar
var _heat_bar: ProgressBar
var _heat_label: Label
var _heat_icon: Widgets.Icon
var _shout: Widgets.RoundButton
var _stall_btn: Button
var _price_btn: Button
var _shop_btn: Button
var _toasts: VBoxContainer
var _banner: PanelContainer
var _warning: Label
var _arrow: Control
var _chase_box: PanelContainer
var _chase_bar: ProgressBar
var _chase_time: ProgressBar
var _haggle: PanelContainer
var _haggle_data := {}
var _haggle_timer := 0.0
var _fps: Label
var _cash_shown := 0.0
var _warn_on := false
var _t := 0.0


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	UITheme.safe_margins(_root)
	_build_top_bar()
	_build_buttons()
	_build_feedback()
	Economy.cash_changed.connect(_on_cash)
	Economy.stock_changed.connect(func(_i, _c): _refresh_stock())
	Economy.markup_changed.connect(func(_i): _refresh_price())
	HeatSystem.heat_changed.connect(_on_heat)
	GameManager.toast.connect(toast)
	GameManager.time_changed.connect(_on_time)
	GameManager.back_pressed.connect(_on_back)
	RandomEvents.event_started.connect(_on_event)
	Upgrades.upgrade_purchased.connect(func(_id, _l): _refresh_stock())
	beach.vendor.state_changed.connect(func(_s): _refresh_stall_button())
	beach.vendor.stall.opened.connect(_refresh_stall_button)
	beach.vendor.stall.closed.connect(_refresh_stall_button)
	_cash_shown = Economy.cash
	_on_cash(Economy.cash, 0.0)
	_refresh_stock()
	_refresh_price()
	_refresh_stall_button()
	_on_heat(HeatSystem.heat, HeatSystem.level)
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


func _build_top_bar() -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 12
	bar.offset_right = -12
	bar.offset_top = 10
	bar.add_theme_constant_override("separation", 10)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bar)

	var cash := _pill(bar, 190)
	cash.add_child(Widgets.Icon.new("coin", 38))
	_cash = UITheme.label("€0", 30)
	cash.add_child(_cash)

	var stock := _pill(bar, 150)
	stock.add_child(Widgets.Icon.new("box", 36))
	_stock = UITheme.label("0/80", 26)
	stock.add_child(_stock)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(spacer)

	var clock := _pill(bar, 230)
	clock.add_child(Widgets.Icon.new("sun", 36))
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 0)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clock.add_child(cv)
	_clock = UITheme.label("Day 1  09:00", 22)
	cv.add_child(_clock)
	_beach_label = UITheme.label("", 14, UITheme.SEA_DARK)
	cv.add_child(_beach_label)
	_day_bar = ProgressBar.new()
	_day_bar.show_percentage = false
	_day_bar.custom_minimum_size = Vector2(160, 8)
	_day_bar.max_value = 1.0
	_day_bar.add_theme_stylebox_override("background", UITheme.box(Color(0, 0, 0, 0.15), 4))
	_day_bar.add_theme_stylebox_override("fill", UITheme.box(Color("#ffb300"), 4))
	cv.add_child(_day_bar)

	var spacer2 := Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(spacer2)

	var heat := _pill(bar, 270)
	_heat_icon = Widgets.Icon.new("police", 38)
	heat.add_child(_heat_icon)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 2)
	hv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heat.add_child(hv)
	_heat_label = UITheme.label("HEAT: Calm", 18)
	hv.add_child(_heat_label)
	_heat_bar = ProgressBar.new()
	_heat_bar.show_percentage = false
	_heat_bar.custom_minimum_size = Vector2(190, 18)
	_heat_bar.max_value = 100.0
	_heat_bar.add_theme_stylebox_override("background", UITheme.box(Color(0, 0, 0, 0.18), 8))
	hv.add_child(_heat_bar)

	var pause := UITheme.button("II", UITheme.SEA, Vector2(72, 72), 30)
	pause.pressed.connect(open_pause)
	bar.add_child(pause)


func _build_buttons() -> void:
	# Bottom-left: SHOP and PRICE.
	var left := VBoxContainer.new()
	left.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	left.offset_left = 14
	left.offset_bottom = -14
	left.grow_vertical = Control.GROW_DIRECTION_BEGIN
	left.add_theme_constant_override("separation", 10)
	_root.add_child(left)
	_price_btn = UITheme.button("Price: Fair", UITheme.LEMON, Vector2(190, 64), 20)
	_price_btn.pressed.connect(_on_price_pressed)
	left.add_child(_price_btn)
	_shop_btn = UITheme.button("SHOP", UITheme.LIME, Vector2(190, 92), 34)
	_shop_btn.pressed.connect(open_shop)
	left.add_child(_shop_btn)

	# Bottom-right: SET UP / PACK UP and SHOUT.
	var right := HBoxContainer.new()
	right.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	right.offset_right = -14
	right.offset_bottom = -10
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.grow_vertical = Control.GROW_DIRECTION_BEGIN
	right.alignment = BoxContainer.ALIGNMENT_END
	right.add_theme_constant_override("separation", 12)
	_root.add_child(right)
	_stall_btn = UITheme.button("SET UP", UITheme.SEA, Vector2(190, 92), 30)
	_stall_btn.size_flags_vertical = Control.SIZE_SHRINK_END
	_stall_btn.pressed.connect(func(): beach.vendor.command_toggle_stall())
	right.add_child(_stall_btn)
	_shout = Widgets.RoundButton.new()
	_shout.caption = "SHOUT!"
	_shout.sub = "Hello chicken nugget!"
	_shout.custom_minimum_size = Vector2(190, 190)
	_shout.pressed.connect(_on_shout_pressed)
	right.add_child(_shout)


func _build_feedback() -> void:
	_toasts = VBoxContainer.new()
	_toasts.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toasts.offset_top = 100
	_toasts.offset_left = -330
	_toasts.offset_right = 330
	_toasts.add_theme_constant_override("separation", 6)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_toasts)

	_warning = UITheme.label("", 34, Color("#ffeb3b"), 12)
	_warning.add_theme_color_override("font_outline_color", Color("#b71c1c"))
	_warning.set_anchors_preset(Control.PRESET_CENTER)
	_warning.offset_top = -40
	_warning.offset_left = -400
	_warning.offset_right = 400
	_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warning.visible = false
	_warning.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_warning)

	_arrow = Control.new()
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow.size = Vector2(60, 60)
	_arrow.pivot_offset = Vector2(30, 30)
	_arrow.draw.connect(_draw_arrow)
	_arrow.visible = false
	_root.add_child(_arrow)

	_chase_box = UITheme.panel(Color(0.1, 0.1, 0.15, 0.85))
	_chase_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_chase_box.offset_top = 96
	_chase_box.offset_left = -260
	_chase_box.offset_right = 260
	_chase_box.visible = false
	_chase_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_chase_box)
	var cv := VBoxContainer.new()
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chase_box.add_child(cv)
	var ct := UITheme.label("ESCAPE! Tap to run, chicken nugget!", 22, UITheme.LEMON, 6)
	ct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(ct)
	_chase_bar = ProgressBar.new()
	_chase_bar.show_percentage = false
	_chase_bar.max_value = 1.0
	_chase_bar.custom_minimum_size = Vector2(480, 22)
	_chase_bar.add_theme_stylebox_override("fill", UITheme.box(UITheme.LIME, 8))
	cv.add_child(_chase_bar)
	_chase_time = ProgressBar.new()
	_chase_time.show_percentage = false
	_chase_time.max_value = 1.0
	_chase_time.custom_minimum_size = Vector2(480, 10)
	_chase_time.add_theme_stylebox_override("fill", UITheme.box(UITheme.LEMON, 4))
	cv.add_child(_chase_time)

	_fps = UITheme.label("", 16, Color.WHITE, 4)
	_fps.position = Vector2(14, 100)
	_fps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fps)


# --- Updates -----------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	# Count the cash display up/down smoothly.
	if absf(_cash_shown - Economy.cash) > 0.01:
		_cash_shown = lerpf(_cash_shown, Economy.cash, clampf(delta * 8.0, 0.0, 1.0))
		if absf(_cash_shown - Economy.cash) < 0.05:
			_cash_shown = Economy.cash
		_cash.text = Lines.money(_cash_shown)
	_shout.cooldown = clampf(beach.vendor.shout_cooldown / maxf(Upgrades.shout_cooldown(), 0.01), 0.0, 1.0)
	if _warn_on:
		_warning.modulate.a = 0.55 + 0.45 * sin(_t * 10.0)
		_update_arrow()
	if HeatSystem.level >= HeatSystem.Level.WANTED:
		_heat_icon.color = Color("#ff1744") if fmod(_t, 0.5) < 0.25 else Color("#2979ff")
		_heat_icon.queue_redraw()
	if _haggle and _haggle.visible:
		_haggle_timer -= delta
		_position_haggle()
		if _haggle_timer <= 0.0:
			_answer_haggle(false)
	if Quality.show_fps:
		_fps.text = "%d FPS  %s  %d tourists" % [Engine.get_frames_per_second(), Quality.TIER_NAMES[Quality.tier], beach.tourists.active_count()]
	elif _fps.text != "":
		_fps.text = ""


func _on_cash(cash: float, delta: float) -> void:
	_cash.add_theme_color_override("font_color", UITheme.INK if cash >= 0.0 else UITheme.DANGER)
	if delta > 0.0:
		_bump(_cash)


func _refresh_stock() -> void:
	var n := Economy.total_stock()
	_stock.text = "%d/%d" % [n, Economy.max_stock()]
	_stock.add_theme_color_override("font_color", UITheme.DANGER if n < 5 else UITheme.INK)
	if n < 5 and _shop_btn:
		_shop_btn.text = "SHOP!"
	elif _shop_btn:
		_shop_btn.text = "SHOP"


func _refresh_price() -> void:
	var m: Dictionary = Economy.MARKUPS[Economy.markup_index]
	_price_btn.text = "Price: %s" % m.name
	var cols := [UITheme.LIME, UITheme.LEMON, Color("#ffb74d"), UITheme.DANGER]
	UITheme.tint_button(_price_btn, cols[Economy.markup_index])


func _refresh_stall_button() -> void:
	var v: Vendor = beach.vendor
	match v.state:
		Vendor.State.PACKING:
			_stall_btn.text = "PACKING..."
		Vendor.State.SETUP:
			_stall_btn.text = "SETTING UP"
		Vendor.State.RUNNING:
			_stall_btn.text = "RUN!"
		_:
			_stall_btn.text = "PACK UP" if v.stall.is_open() else "SET UP"
	UITheme.tint_button(_stall_btn, UITheme.TERRACOTTA if v.stall.is_open() else UITheme.SEA)
	_stall_btn.disabled = v.state in [Vendor.State.RUNNING, Vendor.State.CAUGHT]


func _on_heat(value: float, level: int) -> void:
	_heat_bar.value = value
	var col: Color = HeatSystem.LEVEL_COLORS[level]
	_heat_bar.add_theme_stylebox_override("fill", UITheme.box(col, 8))
	_heat_label.text = "HEAT: %s" % HeatSystem.LEVEL_NAMES[level]
	_heat_icon.color = col
	_heat_icon.queue_redraw()


func _on_time(_hour: float) -> void:
	_clock.text = "Day %d  %s" % [GameManager.day, GameManager.time_string()]
	_beach_label.text = BeachDB.display_name(GameManager.current_beach)
	_day_bar.value = GameManager.day_progress()


func _bump(c: Control) -> void:
	c.pivot_offset = c.size * 0.5
	var tw := create_tween()
	tw.tween_property(c, "scale", Vector2(1.15, 1.15), 0.06)
	tw.tween_property(c, "scale", Vector2.ONE, 0.12)


# --- Buttons -----------------------------------------------------------------------------------

func _on_price_pressed() -> void:
	Economy.cycle_markup()
	toast("%s: %s" % [Economy.MARKUPS[Economy.markup_index].name, Economy.MARKUPS[Economy.markup_index].desc], "info")


func _on_shout_pressed() -> void:
	if beach.vendor.command_shout():
		_bump(_shout)


func open_shop() -> void:
	if get_tree().paused:
		return
	var s := ShopMenu.instantiate()
	add_child(s)
	GameManager.tutorial_event("shop")


func open_pause() -> void:
	if get_tree().paused:
		return
	add_child(PauseMenu.instantiate())


func _on_back() -> void:
	if Overlay.stack.is_empty() and not get_tree().paused:
		open_pause.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if event.is_action_pressed("shout"):
		_on_shout_pressed()
	elif event.is_action_pressed("toggle_stall"):
		beach.vendor.command_toggle_stall()
	elif event.is_action_pressed("open_shop"):
		open_shop()
	elif event.is_action_pressed("markup"):
		Economy.cycle_markup()


# --- Feedback ----------------------------------------------------------------------------------

func toast(text: String, kind := "info") -> void:
	var colors := {"info": UITheme.PANEL, "good": Color("#c8f7b0"), "bad": Color("#ffc4b8"),
		"warning": Color("#ffe082"), "tutorial": UITheme.LEMON}
	var p := UITheme.panel(colors.get(kind, UITheme.PANEL), 16)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UITheme.label(text, 20)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(600, 0)
	p.add_child(l)
	_toasts.add_child(p)
	while _toasts.get_child_count() > 3:
		_toasts.get_child(0).queue_free()
		_toasts.remove_child(_toasts.get_child(0))
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


func police_warning(on: bool) -> void:
	_warn_on = on
	_warning.visible = on
	_arrow.visible = on
	if on:
		_warning.text = Lines.pick(Lines.COPS_COMING)
		AudioManager.play_sfx("whistle")
		if Input.is_action_pressed("ui_accept") == false and OS.has_feature("mobile"):
			Input.vibrate_handheld(200)


func _update_arrow() -> void:
	if not beach.any_cop_chasing_player():
		police_warning(false)
		return
	var cop: Police = null
	var best := INF
	for c in beach.police:
		if c.is_chasing() or c.state == Police.State.CHASE_VENDOR:
			var d: float = c.position.distance_to(beach.vendor.position)
			if d < best:
				best = d
				cop = c
	if cop == null:
		_arrow.visible = false
		return
	var screen: Vector2 = beach.get_viewport().get_canvas_transform() * cop.position
	var vp := _root.get_viewport_rect().size
	var inside := Rect2(Vector2.ZERO, vp).grow(-40).has_point(screen)
	_arrow.visible = not inside
	if not inside:
		var c := vp * 0.5
		var dir := (screen - c).normalized()
		var edge := c + dir * minf((vp.x * 0.5 - 50.0) / maxf(absf(dir.x), 0.01), (vp.y * 0.5 - 50.0) / maxf(absf(dir.y), 0.01))
		_arrow.position = edge - Vector2(30, 30)
		_arrow.rotation = dir.angle()
		_arrow.queue_redraw()


func _draw_arrow() -> void:
	var pts := PackedVector2Array([Vector2(56, 30), Vector2(14, 8), Vector2(22, 30), Vector2(14, 52)])
	_arrow.draw_colored_polygon(pts, Color("#ff1744"))
	pts.append(pts[0])
	_arrow.draw_polyline(pts, Color.WHITE, 3.0, true)


func show_chase(on: bool) -> void:
	_chase_box.visible = on


func update_chase(time_ratio: float, distance_ratio: float) -> void:
	_chase_bar.value = clampf(distance_ratio, 0.0, 1.0)
	_chase_time.value = clampf(time_ratio, 0.0, 1.0)


func show_shout_ring(world_pos: Vector2, radius: float) -> void:
	beach.fx.float_text(world_pos + Vector2(0, -150), "HELLO CHICKEN NUGGET!", UITheme.LEMON, 22)
	_ring(world_pos, radius, Color(1, 0.95, 0.4, 0.7))


func show_tap_marker(world_pos: Vector2) -> void:
	_ring(world_pos, 26.0, Color(1, 1, 1, 0.8), 0.35)


## An expanding circle in the world (shout reach, tap marker).
class Ring extends Node2D:
	var color := Color.WHITE
	var width := 4.0
	var radius := 0.0:
		set(v):
			radius = v
			queue_redraw()

	func _draw() -> void:
		draw_arc(Vector2.ZERO, radius, 0, TAU, 48, color, width, true)


func _ring(world_pos: Vector2, radius: float, col: Color, time := 0.6) -> void:
	var ring := Ring.new()
	ring.position = world_pos
	ring.z_index = 40
	ring.color = col
	ring.width = 4.0 / maxf(beach.camera.zoom.x, 0.3)
	beach.add_child(ring)
	var tw := ring.create_tween()
	tw.tween_property(ring, "radius", radius, time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, time)
	tw.tween_callback(ring.queue_free)


# --- Haggling ----------------------------------------------------------------------------------

func haggle_active() -> bool:
	return _haggle != null and _haggle.visible


func show_haggle(t: Tourist, item: String, offer: float, seller: Walker) -> void:
	if _haggle == null:
		_haggle = UITheme.panel(UITheme.PANEL, 18)
		_root.add_child(_haggle)
	for c in _haggle.get_children():
		c.queue_free()
	var v := VBoxContainer.new()
	_haggle.add_child(v)
	var h0 := HBoxContainer.new()
	h0.add_child(Widgets.ItemIcon.new(item, 44))
	var l := UITheme.label("%s for %s?\n(asking %s)" % [Lines.money(offer), ItemDB.item_name(item), Lines.money(Economy.sale_price(item))], 18)
	h0.add_child(l)
	v.add_child(h0)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var yes := UITheme.button("DEAL!", UITheme.LIME, Vector2(120, 60), 22)
	yes.pressed.connect(_answer_haggle.bind(true))
	var no := UITheme.button("NO", UITheme.DANGER, Vector2(100, 60), 22)
	no.pressed.connect(_answer_haggle.bind(false))
	h.add_child(yes)
	h.add_child(no)
	v.add_child(h)
	_haggle_data = {"t": t, "item": item, "offer": offer, "seller": seller}
	_haggle_timer = 5.5
	_haggle.visible = true
	_haggle.reset_size()
	_position_haggle()


func _position_haggle() -> void:
	var t: Tourist = _haggle_data.get("t")
	if t == null or not is_instance_valid(t):
		return
	var screen: Vector2 = beach.get_viewport().get_canvas_transform() * (t.position + Vector2(0, -150))
	var vp := _root.get_viewport_rect().size
	_haggle.position = Vector2(clampf(screen.x - _haggle.size.x * 0.5, 10, vp.x - _haggle.size.x - 10), clampf(screen.y - _haggle.size.y, 100, vp.y - _haggle.size.y - 220))


func _answer_haggle(accepted: bool) -> void:
	if not haggle_active():
		return
	_haggle.visible = false
	var d := _haggle_data
	_haggle_data = {}
	beach.haggle_result(d.t, d.item, d.offer, d.seller, accepted)
