extends Overlay
## End of the night: the till roll (rooms, bar, wages, repairs, fines, theft), today's
## TrotAdvisor reviews, and the inspector's verdict on inspection days. NEXT DAY carries on.

var summary: Dictionary = {}

const ROWS := [
	["rooms", "Room money", true], ["bar", "Bar takings", true], ["deposits", "Kept deposits", true],
	["other", "Other", true], ["wages", "Staff wages", false], ["repairs", "Repairs & cleaning", false],
	["upgrades", "Upgrades", false], ["fines", "Fines & compensation", false], ["theft", "Stolen", false],
]


func _init() -> void:
	super._init()
	closable_by_back = false


func build() -> void:
	var v := card("End of Day %d" % int(summary.get("day", 1)), Vector2(1080, 560))
	var verdict := UITheme.label(str(summary.get("verdict", "")), 24, UITheme.TERRACOTTA)
	verdict.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(verdict)
	var insp: Dictionary = summary.get("inspection", {})
	if not insp.is_empty():
		var p := UITheme.panel(Color("#e8f5e9") if insp.passed else Color("#ffebee"), 16)
		var l := UITheme.label((Lines.INSPECTION_PASS % Hotel.name_of_hotel) if insp.passed else (Lines.INSPECTION_FAIL % int(insp.strikes)), 22,
			UITheme.INK)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		p.add_child(l)
		v.add_child(p)
		if insp.passed:
			AudioManager.play_sfx("star")
			AudioManager.play_sfx("cheer")
			if Hotel.stars >= 3:
				var win := UITheme.title("THREE STARS! YOU DID IT!", 40)
				win.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				v.add_child(win)
				var sub_l := UITheme.label("From health hazard to proper hotel in %d days. Keep going for the money (and the reviews)!" % int(summary.get("day", 1)), 18, UITheme.SEA_DARK)
				sub_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				sub_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				v.add_child(sub_l)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 18)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cols)

	var money := VBoxContainer.new()
	money.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	money.add_theme_constant_override("separation", 2)
	cols.add_child(money)
	for row in ROWS:
		var amount := float(summary.get(row[0], 0.0))
		if amount <= 0.0:
			continue
		var h := HBoxContainer.new()
		money.add_child(h)
		var name_l := UITheme.label(str(row[1]), 20)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(name_l)
		h.add_child(UITheme.label(("+" if row[2] else "-") + Lines.money(amount), 20, UITheme.LIME.darkened(0.3) if row[2] else UITheme.DANGER))
	var profit := float(summary.get("profit", 0.0))
	var ph := HBoxContainer.new()
	money.add_child(ph)
	var pl := UITheme.label("PROFIT", 26)
	pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ph.add_child(pl)
	ph.add_child(UITheme.label(("+" if profit >= 0.0 else "-") + Lines.money(absf(profit)), 26, UITheme.LIME.darkened(0.3) if profit >= 0.0 else UITheme.DANGER))
	money.add_child(UITheme.label("Pints sold: %d    Guests tonight: %d" % [int(summary.get("pints", 0)), int(summary.get("guests", 0))], 18, UITheme.SEA_DARK))
	money.add_child(UITheme.label("Cash: %s" % Lines.money(Economy.cash), 22, UITheme.INK))
	money.add_child(UITheme.label("%s  -  reviews %.1f / 5" % [Lines.STAR_NAMES[Hotel.stars], Hotel.reputation()], 20, UITheme.TERRACOTTA))
	if Economy.cash < 0.0:
		var debt := UITheme.label("You're in the red! The bank is \"monitoring the situation\".", 18, UITheme.DANGER)
		debt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		money.add_child(debt)

	var rev_scroll := ScrollContainer.new()
	rev_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rev_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cols.add_child(rev_scroll)
	var reviews := VBoxContainer.new()
	reviews.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reviews.add_theme_constant_override("separation", 6)
	rev_scroll.add_child(reviews)
	reviews.add_child(UITheme.label("Today on %s" % Lines.REVIEW_SITE, 22, UITheme.SEA_DARK))
	var list: Array = summary.get("reviews_today", [])
	if list.is_empty():
		reviews.add_child(UITheme.label("Nobody checked out today.", 18, Color("#5d4037")))
	for r in list:
		var p := UITheme.panel(Color(1, 1, 1, 0.65), 12)
		reviews.add_child(p)
		var rv := VBoxContainer.new()
		rv.add_theme_constant_override("separation", 0)
		p.add_child(rv)
		var stars := HBoxContainer.new()
		for k in 5:
			var s := Widgets.Icon.new("star", 18)
			s.color = UITheme.LEMON if k < int(r.stars) else Color(0.85, 0.85, 0.85)
			stars.add_child(s)
		rv.add_child(stars)
		var t := UITheme.label("\"%s\"  - %s" % [r.text, r.name], 16)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rv.add_child(t)

	var next := UITheme.button("NEXT DAY", UITheme.LIME, Vector2(320, 80), 30)
	next.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	next.pressed.connect(_next)
	v.add_child(next)


func _next() -> void:
	close()
	GameManager.goto_hotel()
