extends Overlay
## End of the day at 21:00: takings, costs, the empire's income and a verdict, then off to
## tomorrow (on this beach or another one you own). The game has already autosaved.

const ShopMenu := preload("res://scenes/ui/shop_menu.tscn")

var summary: Dictionary = {}
var _beach_btn: Button


func _init() -> void:
	super._init()
	closable_by_back = false


func build() -> void:
	var s := summary
	var v := card("Day %d done! Very good very nice!" % int(s.get("day", 1)), Vector2(940, 660))
	var verdict := UITheme.label(str(s.get("verdict", "")), 22, UITheme.SEA_DARK)
	verdict.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	verdict.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(verdict)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	v.add_child(h)
	var view := Widgets.AvatarView.new()
	view.follow_player = true
	view.custom_minimum_size = Vector2(160, 240)
	view.zoom = 1.5
	h.add_child(view)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 30)
	h.add_child(grid)
	_row(grid, "Items sold", str(int(s.get("sales", 0))))
	_row(grid, "Takings", "+" + Lines.money(float(s.get("revenue", 0.0))), UITheme.LIME.darkened(0.3))
	if float(s.get("empire", 0.0)) > 0.0:
		_row(grid, "Empire income", "+" + Lines.money(float(s.empire)), UITheme.LIME.darkened(0.3))
	if float(s.get("other", 0.0)) > 0.0:
		_row(grid, "Tips & luck", "+" + Lines.money(float(s.other)), UITheme.LIME.darkened(0.3))
	_row(grid, "Stock bought", "-" + Lines.money(float(s.get("stock_spent", 0.0))), UITheme.DANGER)
	_row(grid, "Fines", "-" + Lines.money(float(s.get("fines", 0.0))), UITheme.DANGER)
	if float(s.get("bribes", 0.0)) > 0.0:
		_row(grid, "Bribes", "-" + Lines.money(float(s.bribes)), UITheme.DANGER)
	_row(grid, "Wages", "-" + Lines.money(float(s.get("wages", 0.0))), UITheme.DANGER)
	var profit := float(s.get("profit", 0.0))
	_row(grid, "PROFIT", Lines.money(profit), UITheme.LIME.darkened(0.35) if profit >= 0.0 else UITheme.DANGER, 30)
	var best := str(s.get("best_seller", ""))
	if best != "":
		_row(grid, "Best seller", ItemDB.item_name(best))
	if bool(s.get("record", false)) and profit > 0.0:
		v.add_child(UITheme.label("NEW RECORD DAY! Very good very VERY nice!", 22, Color("#e65100")))
	v.add_child(UITheme.label("Cash: %s   Spend it in the SHOP. Very good very nice!" % Lines.money(Economy.cash), 18, UITheme.SEA_DARK))

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(buttons)
	var shop := UITheme.button("SHOP", UITheme.LIME, Vector2(180, 80), 28)
	shop.pressed.connect(_open_shop)
	buttons.add_child(shop)
	if GameManager.owned_beaches.size() > 1:
		_beach_btn = UITheme.button("", UITheme.LEMON, Vector2(260, 80), 22)
		_beach_btn.pressed.connect(_cycle_beach)
		buttons.add_child(_beach_btn)
		_refresh_beach()
	var next := UITheme.button("NEXT DAY!", UITheme.TERRACOTTA, Vector2(260, 80), 30)
	next.pressed.connect(_next_day)
	buttons.add_child(next)
	var quit := UITheme.button("Menu", UITheme.SEA, Vector2(130, 80), 24)
	quit.pressed.connect(func(): GameManager.goto_menu())
	buttons.add_child(quit)


func _row(grid: GridContainer, label: String, value: String, col := UITheme.INK, size := 24) -> void:
	grid.add_child(UITheme.label(label, size - 2))
	var l := UITheme.label(value, size, col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(l)


func _open_shop() -> void:
	var s := ShopMenu.instantiate()
	add_child(s)


func _cycle_beach() -> void:
	var owned := GameManager.owned_beaches
	var i := owned.find(GameManager.next_beach)
	GameManager.set_next_beach(owned[(i + 1) % owned.size()])
	_refresh_beach()


func _refresh_beach() -> void:
	if _beach_btn:
		_beach_btn.text = "Tomorrow: %s" % BeachDB.get_beach(GameManager.next_beach).name


func _next_day() -> void:
	close()
	GameManager.goto_beach()
