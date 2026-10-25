extends Overlay
## ¡POLICÍA! The cop reached your open stall. Three choices:
##   Bribe   - costs cash, might work (Charm School helps), backfires badly if it doesn't
##   Pay up  - a fine and some stock confiscated, but it's over
##   Leg it  - grab the bag and run; escape and it costs only what you dropped

var beach: Node
var cop: Police


func _init() -> void:
	super._init()
	closable_by_back = false


func build() -> void:
	var terms: Dictionary = beach.bust_terms()
	var v := card(Lines.pick(Lines.BUSTED_TITLES), Vector2(980, 600), Color("#fff1ec"))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	v.add_child(h)
	var view := Widgets.AvatarView.new()
	view.look = cop.avatar.appearance
	view.custom_minimum_size = Vector2(170, 230)
	view.zoom = 1.6
	h.add_child(view)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(info)
	var say := UITheme.label("\"Hello chicken nugget. Is this... your stall? Very not good, very not nice.\"", 22)
	say.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(say)
	info.add_child(UITheme.label("Heat: %d   You have: %s   Stock: %d" % [int(HeatSystem.heat), Lines.money(Economy.cash), Economy.total_stock()], 18, UITheme.SEA_DARK))

	var bribe_cost: float = terms.bribe
	var bribe := _option("BRIBE  %s" % Lines.money(bribe_cost), "%d%% chance. If it fails: big fine + lose 40%% stock." % int(float(terms.bribe_chance) * 100.0), UITheme.LEMON)
	bribe.disabled = not Economy.can_afford(bribe_cost)
	if bribe.disabled:
		bribe.text += " (not enough cash)"
	bribe.pressed.connect(_choose.bind("bribe"))
	v.add_child(bribe)
	var fine := _option("PAY FINE  %s" % Lines.money(float(terms.fine)), "Lose %d%% of your stock. Safe, boring, very not nice." % int(float(terms.fine_confiscate) * 100.0), UITheme.SEA)
	fine.pressed.connect(_choose.bind("fine"))
	v.add_child(fine)
	var run := _option("LEG IT!", "Drop %d%% of your stock and run! Get away and you're free. Get caught: double fine." % int(float(terms.run_drop) * 100.0), UITheme.TERRACOTTA)
	run.pressed.connect(_choose.bind("run"))
	v.add_child(run)


func _option(text: String, hint: String, color: Color) -> Button:
	var b := UITheme.button(text, color, Vector2(0, 76), 28)
	b.tooltip_text = hint
	b.text = text + "\n" + hint
	b.add_theme_font_size_override("font_size", 20)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(0, 84)
	return b


func _choose(choice: String) -> void:
	close()
	beach.bust_choice(choice, cop)
