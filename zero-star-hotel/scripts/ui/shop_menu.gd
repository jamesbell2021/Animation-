extends Overlay
## UPGRADES: four big tabs.
##   Rooms  - open boarded-up rooms and upgrade them from Grim to Nice
##   Hotel  - reception, bar, pool, safety, soundproofing, security, more floors
##   Staff  - hire cleaners, a handyman, security, a lifeguard and a barman
##   Stars  - the inspector's checklist for the next star, the call-the-inspector button,
##            and the latest TrotAdvisor reviews
## The game is paused while it's open.

const TABS := ["Rooms", "Hotel", "Staff", "Stars"]

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
	_cash = UITheme.label("", 24)
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
	_set_tab(3 if Hotel.requirements_met() else tab)


func _set_tab(i: int) -> void:
	tab = i
	for k in _tab_buttons.size():
		UITheme.tint_button(_tab_buttons[k], UITheme.TERRACOTTA if k == i else UITheme.SEA)
	_rebuild()


func _refresh_cash() -> void:
	_cash.text = "%s     %s     Reviews %.1f/5" % [Lines.money(Economy.cash), Lines.STAR_NAMES[Hotel.stars], Hotel.reputation()]


func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	_refresh_cash()
	match tab:
		0: _build_rooms()
		1: _build_hotel()
		2: _build_staff()
		3: _build_stars()
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
	v.add_child(UITheme.label(title, 22, title_col))
	var b := UITheme.label(body, 16, Color("#5d4037"))
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(b)
	return v


func _action(parent: Control, text: String, color: Color, reason: String, cb: Callable, w := 180.0) -> Button:
	var b := UITheme.button(text, color, Vector2(w, 72), 17)
	b.disabled = reason != ""
	if reason != "":
		b.text = "%s\n%s" % [text.split("\n")[0], reason]
		b.add_theme_font_size_override("font_size", 15)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


# --- Rooms -----------------------------------------------------------------------------------

func _build_rooms() -> void:
	_list.add_child(UITheme.label("Open more rooms for more guests; better rooms earn more and keep guests happy.", 17, UITheme.SEA_DARK))
	for i in Hotel.ROOMS:
		var r: Dictionary = Hotel.rooms[i]
		var h := _row(Color(1, 1, 1, 0.65) if r.open else Color(0.85, 0.85, 0.85, 0.5))
		var status := ""
		if not Hotel.floor_unlocked(Hotel.floor_of(i)):
			status = "Closed floor"
		elif not r.open:
			status = "Boarded up"
		else:
			var g := Hotel.group(int(r.group))
			status = "%s, %s per guest%s" % [Hotel.QUALITY_NAMES[int(r.quality)], Lines.money(Hotel.room_rate(i)),
				"" if g.is_empty() else ", " + GuestTypes.get_type(g.type).name]
		var problems := []
		if r.open and float(r.dirt) > 50.0:
			problems.append("dirty")
		if r.open and int(r.roaches) > 0:
			problems.append("%d cockroaches" % int(r.roaches))
		if r.open and int(r.damage) > 0:
			problems.append("damaged")
		_text_block(h, "Room %s" % Hotel.room_label(i), status + ("" if problems.is_empty() else "  (" + ", ".join(problems) + ")"))
		if not Hotel.floor_unlocked(Hotel.floor_of(i)):
			continue
		if not r.open:
			_action(h, "OPEN\n%s" % Lines.money(Hotel.open_cost()), UITheme.LIME, Hotel.can_open(i), _open_room.bind(i))
		elif int(r.quality) < 3:
			var c := Hotel.quality_cost(i)
			_action(h, "To %s\n%s" % [Hotel.QUALITY_NAMES[int(r.quality) + 1], Lines.money(c)], UITheme.TERRACOTTA,
				"" if Economy.can_afford(c) else "Not enough cash", _upgrade_room.bind(i))
		else:
			_action(h, "NICE!", UITheme.LIME, "Maxed", func(): pass)


func _open_room(i: int) -> void:
	if Hotel.open_room(i):
		AudioManager.play_sfx("upgrade")
	_rebuild()


func _upgrade_room(i: int) -> void:
	if Hotel.upgrade_room(i):
		AudioManager.play_sfx("upgrade")
	_rebuild()


# --- Hotel upgrades ------------------------------------------------------------------------------

func _build_hotel() -> void:
	for cat in Upgrades.CATEGORIES:
		_list.add_child(UITheme.label(cat.to_upper(), 24, UITheme.TERRACOTTA))
		for id in Upgrades.DEFS:
			var d: Dictionary = Upgrades.DEFS[id]
			if d.category != cat:
				continue
			var h := _row()
			var title := "%s:  %s" % [d.name, Upgrades.level_name(id)]
			_text_block(h, title, str(d.desc))
			if Upgrades.is_maxed(id):
				_action(h, "DONE!", UITheme.LIME, "Maxed", func(): pass)
				continue
			var label := Lines.money(Upgrades.cost(id))
			if d.has("levels"):
				label = "%s\n%s" % [Upgrades.level_name(id, Upgrades.level(id) + 1), label]
			_action(h, label, UITheme.TERRACOTTA, Upgrades.block_reason(id), _buy.bind(id), 200)


func _buy(id: String) -> void:
	if Upgrades.buy(id):
		GameManager.notify("%s: %s!" % [Upgrades.DEFS[id].name, Upgrades.level_name(id)], "good")
	else:
		AudioManager.play_sfx("error")
	_rebuild()


# --- Staff ---------------------------------------------------------------------------------------

func _build_staff() -> void:
	_list.add_child(UITheme.label("Wages today: %s. Staff handle trouble on their own; you pay them at the end of each day." % Lines.money(Staff.daily_wages()), 17, UITheme.SEA_DARK))
	for role in Staff.ROLES:
		var d: Dictionary = Staff.ROLES[role]
		var h := _row()
		var rng := RandomNumberGenerator.new()
		rng.seed = role.hash()
		var view := Widgets.AvatarView.new()
		view.look = AppearanceOptions.staff_appearance(role, rng)
		view.custom_minimum_size = Vector2(70, 100)
		view.zoom = 0.7
		h.add_child(view)
		var names := Staff.staff.filter(func(s): return s.role == role).map(func(s): return str(s.name))
		var have := "  Hired: %s" % ", ".join(names) if not names.is_empty() else ""
		_text_block(h, "%s  (%d/%d)" % [d.name, Staff.count_role(role), int(d.max)], "%s Wage %s/day.%s" % [d.desc, Lines.money(float(d.wage)), have])
		if Staff.count_role(role) > 0:
			_action(h, "Fire", UITheme.DANGER, "", _fire.bind(role), 110)
		_action(h, "HIRE\n%s" % Lines.money(Staff.hire_cost(role)), UITheme.LIME, Staff.can_hire(role), _hire.bind(role), 150)


func _hire(role: String) -> void:
	var s := Staff.hire(role)
	if not s.is_empty():
		AudioManager.play_sfx("hire")
		GameManager.notify("%s the %s starts now!" % [s.name, Staff.ROLES[role].name.to_lower()], "good")
	_rebuild()


func _fire(role: String) -> void:
	for s in Staff.staff:
		if s.role == role:
			Staff.fire(int(s.id))
			GameManager.notify("%s leaves. They take a towel." % s.name, "info")
			break
	_rebuild()


# --- Stars --------------------------------------------------------------------------------------

func _build_stars() -> void:
	if Hotel.stars >= 3:
		_list.add_child(UITheme.title("THREE STARS!", 48))
		_list.add_child(UITheme.label("%s is officially a three-star hotel. From zero to (nearly) hero!" % Hotel.name_of_hotel, 20))
	else:
		_list.add_child(UITheme.label("Next: %s  (%s)" % [Lines.STAR_NAMES[Hotel.stars + 1], Lines.STAR_TITLES[Hotel.stars + 1]], 24, UITheme.TERRACOTTA))
		for req in Hotel.requirements():
			var h := _row(Color("#e8f5e9") if req[1] else Color("#fff3e0"))
			var tick := Widgets.Icon.new("star", 30)
			tick.color = UITheme.LIME if req[1] else Color(0.8, 0.8, 0.8)
			h.add_child(tick)
			var l := UITheme.label(("DONE  " if req[1] else "TO DO  ") + str(req[0]), 19, UITheme.INK)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(l)
		var h2 := _row(Color(1, 0.95, 0.8))
		_text_block(h2, "The Inspector", "Meet every requirement, then book a visit. On inspection day they tour every room, the bar and the pool. %d strikes and you fail (cockroaches, dirty or smashed rooms, raves, fights, pool rescues, burglaries)." % (Hotel.MAX_STRIKES + 1))
		_action(h2, "BOOK\nINSPECTION", UITheme.TERRACOTTA, Hotel.can_request_inspection(), _book_inspection, 200)
	_list.add_child(UITheme.label("Latest reviews on %s" % Lines.REVIEW_SITE, 22, UITheme.SEA_DARK))
	var recent := Hotel.reviews.slice(maxi(Hotel.reviews.size() - 8, 0))
	recent.reverse()
	for r in recent:
		var h := _row()
		var stars := HBoxContainer.new()
		for k in 5:
			var s := Widgets.Icon.new("star", 20)
			s.color = UITheme.LEMON if k < int(r.stars) else Color(0.85, 0.85, 0.85)
			stars.add_child(s)
		var v := _text_block(h, "\"%s\"" % r.text, "%s, day %d" % [r.name, int(r.day)])
		v.add_child(stars)


func _book_inspection() -> void:
	if Hotel.request_inspection():
		AudioManager.play_sfx("event")
		GameManager.notify("Inspector booked for tomorrow (day %d). Hide the cockroaches!" % Hotel.inspection_day, "warning")
	_rebuild()
