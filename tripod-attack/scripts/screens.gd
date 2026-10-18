class_name Screens
extends Node2D
## Draws the title, the campaign map, the sector briefing, the HUD and the end screens.

var main: Node


func _process(_dt: float) -> void:
	queue_redraw()


func _draw() -> void:
	if main == null:
		return
	match main.state:
		"title": _draw_title()
		"map": _draw_map()
		"intro": _draw_intro()
		"play": _draw_hud()
		"cleared": _dim(); _draw_cleared()
		"gameover": _dim(); _draw_game_over()
		"victory": _dim(); _draw_victory()


func _dim(a := 0.62) -> void:
	draw_rect(Rect2(-40, -40, C.W + 80, C.H + 80), Color(0, 0, 0, a))


func _blink(hz: float) -> bool:
	return int(main.t * hz) % 2 == 0


## Types `text` out at `speed` chars per second from main.typed. Returns true when complete.
func _typewriter(text: String, pos: Vector2, size: float, max_w: float, color := Vec.GREEN, speed := 36.0) -> bool:
	var n: int = mini(text.length(), int(main.typed * speed))
	var lines := Vec.wrap(text, size, max_w)
	var left := n
	var y := pos.y
	for L in lines:
		var take: int = clampi(left, 0, L.length())
		var cursor := "_" if (take < L.length() and left >= 0 and int(main.t * 8.0) % 2 == 1) else ""
		Vec.text(self, L.substr(0, take) + cursor, Vector2(pos.x, y), size, "center", color)
		left -= L.length() + 1
		y += size * 1.7
		if left <= 0:
			break
	return n >= text.length()


func _draw_title() -> void:
	_dim(0.6)
	var fl := 0.85 + 0.15 * sin(main.t * 9.0) * randf()
	Vec.text(self, "TRIPOD ATTACK!", Vector2(C.W / 2 + 2, 42), 46.0, "center", Vec.faded(Vec.DIM, fl), 7.0)
	Vec.text(self, "TRIPOD ATTACK!", Vector2(C.W / 2, 40), 46.0, "center", Vec.faded(Vec.GREEN, fl), 3.5)
	Vec.text(self, "A VECTOR ARCADE GAME AFTER H. G. WELLS", Vector2(C.W / 2, 98), 10.0, "center", Vec.DIM)
	var items: Array = main.menu_items()
	var y0 := 140.0
	for i in items.size():
		var it: Dictionary = items[i]
		var sel: bool = i == main.menu_idx
		var col := Vec.DIMMER if it.locked else (Vec.WHITE if sel else Vec.GREEN)
		if sel and _blink(6.0):
			Vec.poly(self, PackedVector2Array([Vector2(C.W / 2 - 170, y0 + i * 36 + 2), Vector2(C.W / 2 - 156, y0 + i * 36 + 8), Vector2(C.W / 2 - 170, y0 + i * 36 + 14)]), Vec.WHITE, 2.0, true)
		Vec.text(self, it.label, Vector2(C.W / 2, y0 + i * 36), 16.0, "center", col)
	var hy := y0 + items.size() * 36 + 14
	Vec.text(self, "HIGH SCORES   CAMPAIGN %06d   ENDLESS %06d" % [G.high_campaign, G.high_endless], Vector2(C.W / 2, hy), 9.0, "center", Vec.DIM)
	Vec.text(self, "EUROPE IS FREE" if G.campaign_done else "SECTORS LIBERATED %d / 10" % G.cleared_count(), Vector2(C.W / 2, hy + 18), 9.0, "center", Vec.DIM)
	_typewriter(Wells.opening(), Vector2(C.W / 2, hy + 48), 10.0, 720.0, Vec.GREEN, 30.0)
	if not Sfx.is_ready:
		Vec.text(self, "WARMING UP THE SOUND BOARD" + ".".repeat(int(main.t * 2.0) % 4), Vector2(C.W / 2, C.H - 48), 8.0, "center", Vec.DIM)
	Vec.text(self, "DRAG BACK AND RELEASE TO FIRE   ARROWS AIM   ENTER FIRE   SPACE DUCK   M MUTE", Vector2(C.W / 2, C.H - 28), 8.0, "center", Vec.DIM)


func _tripod_icon(p: Vector2, s: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 9:
		var a := PI + PI * i / 8.0
		pts.append(Vector2(p.x + cos(a) * 5 * s, p.y - 8 * s + sin(a) * 4 * s))
	Vec.poly(self, pts, col, 1.3, true)
	Vec.poly(self, PackedVector2Array([p + Vector2(-4 * s, -7 * s), p + Vector2(-8 * s, -2 * s), p + Vector2(-7 * s, 0)]), col, 1.2)
	Vec.poly(self, PackedVector2Array([p + Vector2(0, -7 * s), p + Vector2(1 * s, -2 * s), p + Vector2(0, 0)]), col, 1.2)
	Vec.poly(self, PackedVector2Array([p + Vector2(4 * s, -7 * s), p + Vector2(8 * s, -2 * s), p + Vector2(7 * s, 0)]), col, 1.2)


func _draw_map() -> void:
	var rect := Rect2(30, 40, 590, 500)
	Vec.text(self, "THE TRIPOD ADVANCE", Vector2(325, 16), 14.0, "center", Vec.GREEN)
	for coast in EuroMap.COAST:
		var pts := PackedVector2Array()
		for ll in coast:
			pts.append(EuroMap.project(ll[0], ll[1], rect))
		Vec.poly(self, pts, Vec.DIM, 1.3)
	var S: Array = EuroMap.SECTORS
	var next := G.next_sector_idx()
	for i in S.size() - 1:
		var a := EuroMap.project(S[i].lon, S[i].lat, rect)
		var b := EuroMap.project(S[i + 1].lon, S[i + 1].lat, rect)
		var held: bool = not G.cleared[i + 1]
		draw_dashed_line(a, b, Vec.RED if held else Vec.GREEN, 1.2, 6.0)
		if held:
			for k in 2:
				var u := fposmod(main.map_anim * 0.05 + k / 2.0 + i * 0.17, 1.0)
				_tripod_icon(b.lerp(a, u), 0.75, Vec.RED)
	for i in S.size():
		var p := EuroMap.project(S[i].lon, S[i].lat, rect)
		var cleared: bool = G.cleared[i]
		if cleared:
			Vec.circle(self, p, 7.0, Vec.GREEN, 1.6)
			Vec.poly(self, PackedVector2Array([p + Vector2(-3, 0), p + Vector2(-1, 3), p + Vector2(4, -3)]), Vec.GREEN, 1.6)
		elif i == next:
			Vec.circle(self, p, 9.0 + fmod(main.t * 20.0, 8.0), Vec.AMBER if _blink(4.0) else Vec.WHITE, 1.4)
			for d in [Vector2(-14, 0), Vector2(14, 0), Vector2(0, -14), Vector2(0, 14)]:
				Vec.line(self, p + d, p + d * (6.0 / 14.0), Vec.AMBER, 1.2)
			_tripod_icon(p + Vector2(0, 6), 1.1, Vec.RED)
		else:
			_tripod_icon(p + Vector2(0, 6), 1.3, Vec.RED)
		var right := EuroMap.LABEL_RIGHT[i] == "R"
		var lp := p + Vector2(14 if right else -14, -5)
		var al := "left" if right else "right"
		Vec.text(self, S[i].name, lp, 8.0, al, Vec.GREEN if cleared else (Vec.AMBER if i == next else Vec.RED))
		if G.lost_sector == i and _blink(5.0):
			Vec.text(self, "RETAKEN", lp + Vector2(0, 11), 7.0, al, Vec.RED)
	# the briefing panel
	var px := 660.0
	var py := 50.0
	Vec.poly(self, PackedVector2Array([Vector2(px - 14, py - 14), Vector2(C.W - 24, py - 14), Vector2(C.W - 24, C.H - 40), Vector2(px - 14, C.H - 40)]), Vec.DIM, 1.2, true)
	var sec: Dictionary = S[next]
	var held_n := 10 - G.cleared_count()
	Vec.text(self, "SECTOR %d OF 10" % (next + 1), Vector2(px, py), 12.0, "left", Vec.DIM)
	Vec.text(self, sec.name, Vector2(px, py + 24), 24.0, "left", Vec.WHITE)
	var yy := py + 62.0
	for L in Vec.wrap(sec.blurb, 9.0, 320.0):
		Vec.text(self, L, Vector2(px, yy), 9.0, "left", Vec.GREEN)
		yy += 15.0
	Vec.text(self, "EUROPE HELD BY MARTIANS: %d%%" % (held_n * 10), Vector2(px, py + 110), 9.0, "left", Vec.RED)
	Vec.text(self, "TRIPODS SIGHTED: %d" % (6 + next * 2 + (1 if next >= 2 else 0)), Vector2(px, py + 126), 9.0, "left", Vec.RED)
	Vec.text(self, "SCORE %06d" % G.score, Vector2(px, py + 160), 11.0, "left", Vec.GREEN)
	Vec.text(self, "LIFE " + "I".repeat(G.lives), Vector2(px, py + 178), 11.0, "left", Vec.RED if G.lives <= 1 else Vec.GREEN)
	if G.lost_sector >= 0:
		yy = py + 210.0
		for L in Vec.wrap("THE MARTIANS HAVE RETAKEN %s. THE LINE FALLS BACK." % S[G.lost_sector].name, 9.0, 320.0):
			Vec.text(self, L, Vector2(px, yy), 9.0, "left", Vec.RED if _blink(5.0) else Vec.WHITE)
			yy += 15.0
	yy = py + 260.0
	for L in Vec.wrap(Wells.sector_intro(next), 8.0, 320.0):
		Vec.text(self, L, Vector2(px, yy), 8.0, "left", Vec.DIM)
		yy += 13.0
	if _blink(2.5):
		Vec.text(self, "PRESS FIRE TO ADVANCE", Vector2(px + 160, C.H - 70), 12.0, "center", Vec.WHITE)


func _draw_intro() -> void:
	var sec: Dictionary = EuroMap.SECTORS[G.sector_idx]
	Vec.text(self, "ENDLESS MODE" if G.endless else "SECTOR %d OF 10" % (G.sector_idx + 1), Vector2(C.W / 2, 70), 14.0, "center", Vec.DIM)
	Vec.text(self, sec.name, Vector2(C.W / 2, 100), 40.0, "center", Vec.WHITE, 3.0)
	Vec.text(self, "HOLD BELFAST FOR AS LONG AS YOU CAN. THEY NEVER STOP." if G.endless else sec.blurb, Vector2(C.W / 2, 160), 10.0, "center", Vec.GREEN)
	var done := _typewriter(Wells.sector_intro(G.sector_idx), Vector2(C.W / 2, 220), 12.0, 820.0, Vec.GREEN, 36.0)
	Vec.text(self, "SHOOT THE LEGS.  DUCK THE HEAT-RAY WHEN YOU HEAR THE CRY.  GET THE PEOPLE TO SHELTER.", Vector2(C.W / 2, 330), 8.0, "center", Vec.DIM)
	if done and _blink(2.5):
		Vec.text(self, "PRESS FIRE", Vector2(C.W / 2, 380), 14.0, "center", Vec.WHITE)


func _draw_cleared() -> void:
	var sec: Dictionary = EuroMap.SECTORS[G.sector_idx]
	Vec.text(self, "SECTOR CLEARED", Vector2(C.W / 2, 60), 34.0, "center", Vec.WHITE, 3.0)
	Vec.text(self, sec.name + " IS FREE", Vector2(C.W / 2, 110), 14.0, "center", Vec.GREEN)
	var rows := [["TRIPODS DESTROYED", G.stats.destroyed], ["PEOPLE SAVED", G.stats.saved], ["PEOPLE LOST", G.stats.lost],
		["HEAT-RAYS DUCKED", G.stats.dodged], ["SECTOR BONUS", G.clear_bonus], ["SCORE", G.score]]
	for i in rows.size():
		Vec.text(self, rows[i][0], Vector2(C.W / 2 - 20, 150 + i * 22), 11.0, "right", Vec.RED if i == 2 else Vec.GREEN)
		Vec.text(self, str(rows[i][1]), Vector2(C.W / 2 + 20, 150 + i * 22), 11.0, "left", Vec.WHITE)
	_typewriter(Wells.sector_cleared(G.sector_idx), Vector2(C.W / 2, 300), 11.0, 820.0, Vec.DIM, 36.0)
	if _blink(2.5):
		Vec.text(self, "PRESS FIRE", Vector2(C.W / 2, 380), 14.0, "center", Vec.WHITE)


func _draw_game_over() -> void:
	Vec.text(self, "GAME OVER", Vector2(C.W / 2, 70), 44.0, "center", Vec.RED, 3.5)
	_typewriter(Wells.game_over(), Vector2(C.W / 2, 140), 12.0, 820.0, Vec.GREEN, 36.0)
	Vec.text(self, "SCORE %06d" % G.score, Vector2(C.W / 2, 200), 16.0, "center", Vec.WHITE)
	var hi: int = G.high_endless if G.endless else G.high_campaign
	var is_new: bool = G.score >= hi and G.score > 0
	Vec.text(self, ("NEW HIGH SCORE  " if is_new else "HIGH SCORE  ") + "%06d" % hi, Vector2(C.W / 2, 228), 11.0, "center", Vec.AMBER if is_new else Vec.DIM)
	if G.endless:
		Vec.text(self, "WAVES SURVIVED %d" % (G.wave - 1), Vector2(C.W / 2, 250), 11.0, "center", Vec.GREEN)
	elif G.lost_sector >= 0:
		Vec.text(self, "THE MARTIANS RETAKE " + EuroMap.SECTORS[G.lost_sector].name, Vector2(C.W / 2, 250), 11.0, "center", Vec.RED)
	if _blink(2.5):
		Vec.text(self, "PRESS FIRE", Vector2(C.W / 2, 380), 14.0, "center", Vec.WHITE)


func _draw_victory() -> void:
	Vec.text(self, "EUROPE IS FREE", Vector2(C.W / 2, 50), 40.0, "center", Vec.WHITE, 3.5)
	Vec.text(self, Wells.victory2(), Vector2(C.W / 2, 104), 14.0, "center", Vec.GREEN)
	_typewriter(Wells.victory(), Vector2(C.W / 2, 140), 11.0, 820.0, Vec.GREEN, 36.0)
	Vec.text(self, "SCORE %06d" % G.score, Vector2(C.W / 2, 220), 16.0, "center", Vec.AMBER)
	Vec.text(self, "ENDLESS MODE UNLOCKED: BELFAST", Vector2(C.W / 2, 260), 12.0, "center", Vec.WHITE if _blink(3.0) else Vec.GREEN)
	if _blink(2.5):
		Vec.text(self, "PRESS FIRE", Vector2(C.W / 2, 380), 14.0, "center", Vec.WHITE)


func _draw_hud() -> void:
	var bf: Battlefield = main.bf
	var p: Player = bf.player
	Vec.text(self, "SCORE: %06d" % G.score, Vector2(40, 22), 14.0, "left", Vec.GREEN)
	Vec.text(self, "TRIPOD ATTACK!", Vector2(C.W / 2, 18), 15.0, "center", Vec.GREEN)
	Vec.text(self, "WAVE: %d" % G.wave if G.endless else "WAVE: %d/%d" % [G.wave, C.WAVES_PER_SECTOR], Vector2(C.W - 40, 22), 14.0, "right", Vec.GREEN)
	Vec.text(self, ("ENDLESS - " if G.endless else "SECTOR %d: " % (G.sector_idx + 1)) + EuroMap.SECTORS[G.sector_idx].name, Vector2(40, 44), 8.0, "left", Vec.DIM)
	Vec.text(self, "SAVED: %d   LOST: %d" % [G.stats.saved, G.stats.lost], Vector2(C.W - 40, 44), 8.0, "right", Vec.DIM)
	var ready := p.reload <= 0.0 and not p.duck
	Vec.text(self, "CANNON: " + ("DUCKED" if p.duck else ("READY" if ready else "LOADING")), Vector2(60, C.H - 40), 14.0, "left", Vec.AMBER if p.duck else (Vec.GREEN if ready else Vec.DIM))
	Vec.text(self, "TRIPODS: %d" % bf.remaining(), Vector2(C.W / 2, C.H - 40), 14.0, "center", Vec.GREEN)
	var life_col := Vec.GREEN
	if G.lives <= 1:
		life_col = Vec.RED if _blink(4.0) else Vec.WHITE
	Vec.text(self, "LIFE: " + "I".repeat(maxi(0, G.lives)), Vector2(C.W - 60, C.H - 40), 14.0, "right", life_col)
	if main.touch:
		var dc := Vec.AMBER if p.duck else Vec.DIMMER
		var a := Vector2(12, 250)
		var b := Vector2(226, C.GROUND + 14)
		draw_dashed_line(a, Vector2(b.x, a.y), dc, 1.2, 6.0)
		draw_dashed_line(Vector2(b.x, a.y), b, dc, 1.2, 6.0)
		draw_dashed_line(b, Vector2(a.x, b.y), dc, 1.2, 6.0)
		draw_dashed_line(Vector2(a.x, b.y), a, dc, 1.2, 6.0)
		Vec.text(self, "HOLD TO DUCK", Vector2(118, 258), 8.0, "center", dc)
	if not bf.battle_quote.is_empty():
		var q: Dictionary = bf.battle_quote
		var al: float = clampf(minf(q.t, 7.0 - q.t), 0.0, 1.0)
		var yy := 62.0
		for L in Vec.wrap(q.text, 8.0, 700.0):
			Vec.text(self, L, Vector2(C.W / 2, yy), 8.0, "center", Vec.faded(Vec.DIM, al))
			yy += 13.0
	if not bf.banner.is_empty():
		var b: Dictionary = bf.banner
		var al: float = clampf(minf(b.t * 3.0, (b.dur - b.t) * 2.0), 0.0, 1.0) * (0.8 + 0.2 * sin(main.t * 20.0))
		Vec.text(self, b.text, Vector2(C.W / 2, 190), 38.0, "center", Vec.faded(Vec.WHITE, al), 3.0)
		if b.sub != "":
			Vec.text(self, b.sub, Vector2(C.W / 2, 240), 11.0, "center", Vec.faded(Vec.GREEN, al))
	if main.paused:
		Vec.text(self, "PAUSED", Vector2(C.W / 2, 200), 34.0, "center", Vec.WHITE, 3.0)
		Vec.text(self, "P TO RESUME   M TO MUTE", Vector2(C.W / 2, 250), 10.0, "center", Vec.DIM)
