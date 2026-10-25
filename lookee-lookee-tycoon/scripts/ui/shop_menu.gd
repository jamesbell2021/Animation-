extends Overlay
## The SHOP: four big tabs.
##   Wholesaler - buy cheap junk in bulk
##   Upgrades   - the upgrade tree (stall, salesman, supply, escape, empire)
##   Staff      - hire and fire your Lookee Lookee workforce
##   Beaches    - buy new Costa resorts, open kiosks, pick tomorrow's beach
## The game is paused while it's open.

const TABS := ["Wholesaler", "Upgrades", "Staff", "Beaches"]

var tab := 0
var _tab_buttons: Array[Button] = []
var _list: VBoxContainer
var _scroll: ScrollContainer
var _cash: Label


func build() -> void:
	var v := card("", Vector2(1180, 690))
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	v.add_child(top)
	for i in TABS.size():
		var b := UITheme.button(TABS[i], UITheme.SEA, Vector2(0, 66), 22)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_set_tab.bind(i))
		top.add_child(b)
		_tab_buttons.append(b)
	var close_btn := UITheme.button("X", UITheme.DANGER, Vector2(66, 66), 28)
	close_btn.pressed.connect(close)
	top.add_child(close_btn)
	var info := HBoxContainer.new()
	v.add_child(info)
	info.add_child(Widgets.Icon.new("coin", 34))
	_cash = UITheme.label("", 26)
	info.add_child(_cash)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.scroll_deadzone = 12
	v.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	_scroll.add_child(_list)
	Economy.cash_changed.connect(func(_c, _d): _refresh_cash())
	_set_tab(0 if Economy.total_stock() < 10 else tab)


func _set_tab(i: int) -> void:
	tab = i
	for k in _tab_buttons.size():
		UITheme.tint_button(_tab_buttons[k], UITheme.TERRACOTTA if k == i else UITheme.SEA)
	_rebuild()


func _refresh_cash() -> void:
	_cash.text = "%s     Stock %d/%d     %s" % [Lines.money(Economy.cash), Economy.total_stock(), Economy.max_stock(),
		"Hello chicken nugget! What you need?" if tab == 0 else "Very good very nice!"]


func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	_refresh_cash()
	match tab:
		0: _build_wholesaler()
		1: _build_upgrades()
		2: _build_staff()
		3: _build_beaches()
	_scroll.scroll_vertical = 0


func _row(bg := Color(1, 1, 1, 0.6)) -> HBoxContainer:
	var p := UITheme.panel(bg, 16)
	_list.add_child(p)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	return h


func _text_block(parent: Control, title: String, body: String, title_col := UITheme.INK) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	parent.add_child(v)
	v.add_child(UITheme.label(title, 24, title_col))
	var b := UITheme.label(body, 17, Color("#5d4037"))
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(b)
	return v


# --- Wholesaler ---------------------------------------------------------------------------------

func _build_wholesaler() -> void:
	var space := Economy.space_left()
	var head := UITheme.label("Space in the bag: %d.  Buy cheap, sell less cheap. Very good very nice!" % space, 18, UITheme.SEA_DARK)
	_list.add_child(head)
	for id in ItemDB.ids():
		var item := ItemDB.get_item(id)
		var unlocked := Economy.is_unlocked(id)
		var h := _row(Color(1, 1, 1, 0.65) if unlocked else Color(0.8, 0.8, 0.8, 0.5))
		h.add_child(Widgets.ItemIcon.new(id, 64))
		var unit := Economy.wholesale_price(id)
		var body := str(item.desc) if unlocked else "Locked: needs Supplier Contacts \"%s\"" % ItemDB.TIER_NAMES[int(item.tier)]
		var tb := _text_block(h, "%s   (have %d)" % [item.name, Economy.count(id)], body)
		if unlocked:
			tb.add_child(UITheme.label("Buy %s each  ->  sells ~%s" % [Lines.money(unit), Lines.money(Economy.sale_price(id))], 18, UITheme.SEA_DARK))
			for qty: int in [10, 50]:
				var n := mini(qty, space)
				var b := UITheme.button("+%d\n%s" % [qty, Lines.money(unit * qty)], UITheme.LIME, Vector2(120, 76), 18)
				b.disabled = n <= 0 or not Economy.can_afford(unit * maxi(n, 1))
				b.pressed.connect(_buy_stock.bind(id, qty))
				h.add_child(b)


func _buy_stock(id: String, qty: int) -> void:
	var got := Economy.buy_stock(id, qty)
	if got > 0:
		AudioManager.play_sfx("buy")
		GameManager.notify("Bought %d %s! Very good very nice!" % [got, ItemDB.item_name(id)], "good")
	else:
		AudioManager.play_sfx("error")
	_rebuild()


# --- Upgrades -----------------------------------------------------------------------------------

func _build_upgrades() -> void:
	for cat in Upgrades.CATEGORIES:
		_list.add_child(UITheme.label(cat.to_upper(), 26, UITheme.TERRACOTTA))
		for id in Upgrades.DEFS:
			var d: Dictionary = Upgrades.DEFS[id]
			if d.category != cat:
				continue
			var lvl := Upgrades.level(id)
			var h := _row()
			var stars := HBoxContainer.new()
			stars.custom_minimum_size = Vector2(110, 0)
			for k in int(d.max):
				var s := Widgets.Icon.new("star", 22)
				s.color = UITheme.LEMON if k < lvl else Color(0.8, 0.8, 0.8)
				stars.add_child(s)
			var title := str(d.name)
			if d.has("levels"):
				title += ":  " + Upgrades.level_name(id)
			var tb := _text_block(h, title, str(d.desc))
			tb.add_child(stars)
			var reason := Upgrades.block_reason(id)
			var label := "MAX" if Upgrades.is_maxed(id) else Lines.money(Upgrades.cost(id))
			if d.has("levels") and not Upgrades.is_maxed(id):
				label = "%s\n%s" % [Upgrades.level_name(id, lvl + 1), Lines.money(Upgrades.cost(id))]
			var b := UITheme.button(label, UITheme.TERRACOTTA, Vector2(190, 76), 18)
			b.disabled = reason != ""
			if reason != "" and not Upgrades.is_maxed(id):
				b.text = "%s\n%s" % [Lines.money(Upgrades.cost(id)), reason]
			b.pressed.connect(_buy_upgrade.bind(id))
			h.add_child(b)


func _buy_upgrade(id: String) -> void:
	if Upgrades.buy(id):
		AudioManager.play_sfx("upgrade")
		GameManager.notify("%s! Very good very nice!" % Upgrades.DEFS[id].name, "good")
	else:
		AudioManager.play_sfx("error")
	_rebuild()


# --- Staff --------------------------------------------------------------------------------------

func _build_staff() -> void:
	var beach := GameManager.current_beach
	var here := Staff.on_beach(beach)
	_list.add_child(UITheme.label("Your crew in %s: %d/%d   (Business Cards upgrade = more staff)   Wages today: %s" % [BeachDB.get_beach(beach).name, here.size(), Upgrades.staff_cap(), Lines.money(Staff.daily_wages())], 18, UITheme.SEA_DARK))
	for w in here:
		_staff_row(w, true)
	var elsewhere := Staff.staff.filter(func(w): return w.beach != beach)
	if not elsewhere.is_empty():
		_list.add_child(UITheme.label("Working your other beaches", 22, UITheme.TERRACOTTA))
		for w in elsewhere:
			_staff_row(w, true)
	_list.add_child(UITheme.label("Looking for work (they start tomorrow... no, right now!)", 22, UITheme.TERRACOTTA))
	for i in Staff.candidates.size():
		_staff_row(Staff.candidates[i], false, i)


func _staff_row(w: Dictionary, hired: bool, index := -1) -> void:
	var h := _row()
	var view := Widgets.AvatarView.new()
	view.look = w.appearance
	view.custom_minimum_size = Vector2(80, 110)
	view.zoom = 0.75
	h.add_child(view)
	var role: Dictionary = Staff.ROLES[w.role]
	var stars := "*".repeat(int(w.skill))
	var where: String = "" if not hired else ("  @ " + str(BeachDB.get_beach(w.beach).name))
	_text_block(h, "%s - %s %s%s" % [w.name, role.name, stars, where], "%s  Wage: %s/day." % [role.desc, Lines.money(float(w.wage))])
	if hired:
		var fire := UITheme.button("Fire", UITheme.DANGER, Vector2(110, 70), 20)
		fire.pressed.connect(_fire.bind(int(w.id)))
		h.add_child(fire)
	else:
		var cost := Staff.hire_cost(w)
		var b := UITheme.button("HIRE\n%s" % Lines.money(cost), UITheme.LIME, Vector2(130, 76), 20)
		b.disabled = not Staff.can_hire(GameManager.current_beach) or not Economy.can_afford(cost)
		b.pressed.connect(_hire.bind(index))
		h.add_child(b)


func _hire(index: int) -> void:
	if Staff.hire(index, GameManager.current_beach):
		AudioManager.play_sfx("hire")
		var scene := get_tree().current_scene
		if scene and scene.has_method("_spawn_workers"):
			# New hires walk onto the beach straight away.
			var w: Dictionary = Staff.staff.back()
			var node := Worker.new()
			scene.world.add_child(node)
			node.setup(scene, w, Vector2(randf_range(200, 3000), BeachBackdrop.WORLD_H - 20))
			scene.workers.append(node)
	else:
		AudioManager.play_sfx("error")
	_rebuild()


func _fire(id: int) -> void:
	Staff.fire(id)
	var scene := get_tree().current_scene
	if scene and "workers" in scene:
		for node in scene.workers.duplicate():
			if is_instance_valid(node) and int(node.data.get("id", -1)) == id:
				node.leave_beach(false)
				scene.workers.erase(node)
	_rebuild()


# --- Beaches ------------------------------------------------------------------------------------

func _build_beaches() -> void:
	_list.add_child(UITheme.label("Expand across the Costa! Kiosks earn money every day, even when you're elsewhere.", 18, UITheme.SEA_DARK))
	for id in BeachDB.ORDER:
		var b := BeachDB.get_beach(id)
		var owned: bool = id in GameManager.owned_beaches
		var h := _row(Color(1, 1, 1, 0.7) if owned else Color(0.9, 0.9, 0.9, 0.55))
		var swatch := ColorRect.new()
		swatch.color = b.sea
		swatch.custom_minimum_size = Vector2(56, 80)
		h.add_child(swatch)
		var status := ""
		if id == GameManager.current_beach:
			status = "  (you are here)"
		elif id == GameManager.next_beach and owned:
			status = "  (tomorrow)"
		var stats := "Wealth x%.1f   Police x%.1f   Staff here: %d" % [float(b.wealth), float(b.police), Staff.count_on_beach(id)]
		var tb := _text_block(h, BeachDB.display_name(id) + status, "%s\n%s" % [b.blurb, stats])
		if GameManager.kiosks.has(id):
			tb.add_child(UITheme.label("Kiosk open: +%s/day" % Lines.money(float(b.kiosk_income)), 18, UITheme.LIME.darkened(0.3)))
		if owned:
			if id != GameManager.next_beach:
				var go := UITheme.button("Go\ntomorrow", UITheme.SEA, Vector2(130, 76), 18)
				go.pressed.connect(_go.bind(id))
				h.add_child(go)
			if not GameManager.kiosks.has(id):
				var k := UITheme.button("Kiosk\n%s" % Lines.money(float(b.kiosk)), UITheme.LEMON, Vector2(140, 76), 18)
				k.disabled = not Economy.can_afford(float(b.kiosk))
				k.pressed.connect(_kiosk.bind(id))
				h.add_child(k)
		else:
			var reason := GameManager.beach_block_reason(id)
			var buy := UITheme.button("BUY\n%s" % Lines.money(float(b.unlock)), UITheme.TERRACOTTA, Vector2(170, 76), 18)
			buy.disabled = reason != ""
			if reason != "":
				buy.text = "%s\n%s" % [Lines.money(float(b.unlock)), reason]
			buy.pressed.connect(_buy_beach.bind(id))
			h.add_child(buy)


func _go(id: String) -> void:
	GameManager.set_next_beach(id)
	GameManager.notify("Tomorrow: %s! Pack the van, chicken nugget!" % BeachDB.get_beach(id).name, "info")
	_rebuild()


func _kiosk(id: String) -> void:
	GameManager.buy_kiosk(id)
	_rebuild()


func _buy_beach(id: String) -> void:
	if GameManager.buy_beach(id):
		GameManager.set_next_beach(id)
	_rebuild()
