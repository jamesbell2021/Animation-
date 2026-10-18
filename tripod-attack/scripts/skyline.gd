class_name Skyline
extends Node2D
## Background skylines for each sector, built from polylines in local coordinates (origin at the
## element's base centre, y up). Buildings catch fire under the Heat-Ray and crumble into ruins.

signal building_fell(e: Dictionary)

var elements: Array = []
var fx: Particles
var t := 0.0
var _L: Array
var _rng := RandomNumberGenerator.new()


func build(key: String, seed_v: int) -> void:
	elements.clear()
	_rng.seed = seed_v * 7919 + key.length()
	match key:
		"belfast": _belfast()
		"edinburgh": _edinburgh()
		"liverpool": _liverpool()
		"london": _london()
		"paris": _paris()
		"amsterdam": _amsterdam()
		"berlin": _berlin()
		"vienna": _vienna()
		"rome": _rome()
		"athens": _athens()
		_: _belfast()
	# Fill the gaps with ruined tenements and chimneys.
	var occupied: Array = []
	for e in elements:
		occupied.append([e.x - e.w / 2.0, e.x + e.w / 2.0])
	var x := 30.0
	while x < C.W - 10.0:
		var blocked := false
		for o in occupied:
			if x > o[0] - 14.0 and x < o[1] + 14.0:
				blocked = true
				break
		if not blocked:
			var w := 18.0 + _rng.randf() * 30.0
			var h := 18.0 + _rng.randf() * 48.0
			_add(x, w, "")
			var pts := PackedVector2Array([Vector2(-w / 2.0, 0), Vector2(-w / 2.0, h)])
			var n := 2 + _rng.randi() % 3
			for i in range(1, n + 1):
				var px := -w / 2.0 + w * i / n
				pts.append(Vector2(px, h - (0.0 if _rng.randf() < 0.5 else _rng.randf() * h * 0.5)))
			pts.append(Vector2(w / 2.0, 0))
			_L.append(pts)
			if _rng.randf() < 0.5:
				_windows(0, 0, w, h * 0.7, maxi(1, int(w / 9.0)), maxi(1, int(h / 12.0)), true)
			if _rng.randf() < 0.3:
				_ln(w * 0.3, h, w * 0.3, h + 10)
		x += 22.0 + _rng.randf() * 30.0
	queue_redraw()


func _add(x: float, w: float, name: String, anim := "") -> Dictionary:
	var e := {"x": x, "w": w, "lines": [], "name": name, "anim": anim, "heat": 0.0, "ruined": false, "burn_t": 0.0}
	_L = e.lines
	elements.append(e)
	return e


# --- polyline helpers (local coords, y up) -----------------------------------------------------

func _rect(cx: float, y0: float, w: float, h: float) -> void:
	_L.append(PackedVector2Array([Vector2(cx - w / 2, y0), Vector2(cx + w / 2, y0), Vector2(cx + w / 2, y0 + h), Vector2(cx - w / 2, y0 + h), Vector2(cx - w / 2, y0)]))


func _ln(x0: float, y0: float, x1: float, y1: float) -> void:
	_L.append(PackedVector2Array([Vector2(x0, y0), Vector2(x1, y1)]))


func _arc(cx: float, cy: float, r: float, a0: float, a1: float, n := 12, ry := -1.0) -> PackedVector2Array:
	if ry < 0.0:
		ry = r
	var pts := PackedVector2Array()
	for i in range(n + 1):
		var a := a0 + (a1 - a0) * i / n
		pts.append(Vector2(cx + cos(a) * r, cy + sin(a) * ry))
	return pts


func _dome(cx: float, y0: float, r: float, ry := -1.0) -> void:
	_L.append(_arc(cx, y0, r, 0.0, PI, 14, ry))


func _windows(cx: float, y0: float, w: float, h: float, cols: int, rows: int, use_rng := false) -> void:
	var cw := w / (cols + 1)
	var rh := h / (rows + 1)
	for r in range(1, rows + 1):
		for c in range(1, cols + 1):
			if use_rng and _rng.randf() < 0.3:
				continue
			var x := cx - w / 2 + c * cw
			var y := y0 + r * rh
			_ln(x - 1.5, y, x + 1.5, y)


func _battlements(x0: float, x1: float, y: float, h: float, step: float) -> void:
	var pts := PackedVector2Array([Vector2(x0, y)])
	var up := false
	var x := x0
	while x < x1:
		up = not up
		var yy := y + (h if up else 0.0)
		pts.append(Vector2(x, yy))
		pts.append(Vector2(minf(x1, x + step), yy))
		x += step
	_L.append(pts)


func _spire(cx: float, y0: float, w: float, h: float) -> void:
	_L.append(PackedVector2Array([Vector2(cx - w / 2, y0), Vector2(cx, y0 + h), Vector2(cx + w / 2, y0)]))


func _tree(cx: float, h: float) -> void:
	_ln(cx, 0, cx, h * 0.6)
	_L.append(_arc(cx, h * 0.55, h * 0.45, 0.15, PI - 0.15, 10, h * 0.35))
	_ln(cx - h * 0.4, h * 0.6, cx + h * 0.4, h * 0.6)


func _crane(cx: float, w: float, h: float) -> void:
	_L.append(PackedVector2Array([Vector2(cx - w / 2 - 6, 0), Vector2(cx - w / 2 + 4, h), Vector2(cx - w / 2 + 14, 0)]))
	_L.append(PackedVector2Array([Vector2(cx + w / 2 - 14, 0), Vector2(cx + w / 2 - 4, h), Vector2(cx + w / 2 + 6, 0)]))
	_rect(cx, h - 8, w + 10, 10)
	var x := cx - w / 2 + 10
	while x < cx + w / 2 - 10:
		_L.append(PackedVector2Array([Vector2(x, h - 8), Vector2(x + 8, h + 2), Vector2(x + 16, h - 8)]))
		x += 16
	_rect(cx - w * 0.15, h + 2, 14, 9)
	_ln(cx - w * 0.15, h - 8, cx - w * 0.15, h * 0.45)
	_rect(cx - w * 0.15, h * 0.45 - 6, 6, 6)


func _horse(cx: float, y0: float, s: float) -> void:
	_L.append(PackedVector2Array([Vector2(cx - 6 * s, y0), Vector2(cx - 5 * s, y0 + 6 * s), Vector2(cx + 3 * s, y0 + 7 * s), Vector2(cx + 6 * s, y0 + 11 * s), Vector2(cx + 8 * s, y0 + 9 * s)]))
	_ln(cx + 3 * s, y0 + 7 * s, cx + 3 * s, y0)


func _pts(a: Array) -> PackedVector2Array:
	var p := PackedVector2Array()
	for v in a:
		p.append(Vector2(v[0], v[1]))
	return p


# --- the cities --------------------------------------------------------------------------------

func _belfast() -> void:
	_add(170, 150, "GOLIATH"); _crane(0, 110, 92)
	_add(290, 170, "SAMSON"); _crane(0, 120, 106)
	_add(470, 110, "CITY HALL")
	_rect(0, 0, 110, 28); _windows(0, 0, 110, 28, 7, 2)
	for x in [-48.0, 48.0]:
		_rect(x, 28, 12, 20); _dome(x, 48, 6)
	_rect(0, 28, 36, 10); _dome(0, 38, 20, 22); _rect(0, 60, 6, 8); _ln(0, 68, 0, 76)
	_add(620, 110, "ALBERT CLOCK")
	var lean := 0.05
	_L.append(_pts([[-7, 0], [-7 + 60 * lean, 60], [-4 + 60 * lean, 60], [76 * lean, 78], [4 + 60 * lean, 60], [7 + 60 * lean, 60], [7, 0]]))
	_L.append(_arc(50 * lean, 50, 4.5, 0, TAU, 10)); _ln(50 * lean, 50, 50 * lean + 2.5, 52.5)
	_add(820, 150, "OBEL"); _rect(0, 0, 60, 70); _windows(0, 0, 60, 70, 4, 6); _ln(0, 70, 0, 90)


func _edinburgh() -> void:
	_add(240, 220, "THE CASTLE")
	_L.append(_pts([[-110, 0], [-90, 18], [-70, 30], [-50, 48], [-20, 55], [20, 58], [50, 50], [80, 38], [100, 20], [110, 0]]))
	_battlements(-60, 60, 58, 5, 8)
	_rect(-30, 58, 24, 26); _battlements(-42, -18, 84, 4, 6)
	_rect(25, 58, 30, 18); _battlements(10, 40, 76, 4, 6)
	_rect(-30, 65, 4, 6); _rect(25, 64, 4, 5)
	_add(520, 110, "SCOTT MONUMENT")
	_L.append(_pts([[-16, 0], [-16, 30], [-10, 30], [-6, 60], [-3, 80], [0, 96], [3, 80], [6, 60], [10, 30], [16, 30], [16, 0]]))
	_ln(-16, 30, 16, 30); _ln(-10, 30, 10, 30); _L.append(_arc(0, 14, 9, 0, PI, 8)); _ln(-6, 60, 6, 60)
	_add(720, 110, "ST GILES")
	_rect(0, 0, 50, 46); _windows(0, 0, 50, 46, 3, 4); _L.append(_pts([[-25, 46], [0, 62], [25, 46]])); _rect(14, 46, 6, 26); _spire(14, 72, 6, 12)


func _liverpool() -> void:
	_add(300, 170, "LIVER BUILDING")
	_rect(0, 0, 100, 58); _windows(0, 0, 100, 58, 7, 5)
	for x in [-30.0, 30.0]:
		_rect(x, 58, 20, 30); _L.append(_arc(x, 76, 5, 0, TAU, 10))
		_dome(x, 88, 10, 9); _ln(x, 97, x, 104)
		_L.append(_pts([[x - 6, 108], [x, 104], [x + 6, 108]])); _L.append(_pts([[x - 4, 104], [x, 102], [x + 4, 104]]))
	_add(540, 190, "CATHEDRAL")
	_rect(0, 0, 120, 44); _rect(0, 0, 40, 100); _battlements(-20, 20, 100, 4, 5)
	_L.append(_arc(-40, 20, 8, 0, PI, 8)); _L.append(_arc(40, 20, 8, 0, PI, 8)); _L.append(_arc(0, 60, 9, 0, PI, 8)); _ln(-9, 60, -9, 48); _ln(9, 60, 9, 48)
	_add(760, 130, "RADIO CITY")
	_ln(-3, 0, -3, 100); _ln(3, 0, 3, 100); _L.append(_pts([[-14, 84], [-14, 100], [0, 110], [14, 100], [14, 84], [-14, 84]])); _ln(0, 110, 0, 124)


func _london() -> void:
	_add(180, 160, "TOWER BRIDGE")
	for x in [-45.0, 45.0]:
		_rect(x, 0, 22, 78); _spire(x, 78, 22, 14); _rect(x - 6, 78, 3, 6); _rect(x + 6, 78, 3, 6)
	_ln(-34, 60, 34, 60); _ln(-34, 66, 34, 66); _ln(-34, 18, 34, 18)
	for x in range(-30, 31, 10):
		_ln(x, 60, x, 66)
	_L.append(_arc(-80, 18, 24, PI * 0.5, PI, 8, 44)); _L.append(_arc(80, 18, 24, 0, PI * 0.5, 8, 44)); _ln(-104, 18, -56, 18); _ln(56, 18, 104, 18)
	_add(420, 170, "ST PAULS")
	_rect(0, 0, 100, 26); _windows(0, 0, 100, 26, 8, 1)
	_rect(0, 26, 56, 14)
	for x in range(-24, 25, 8):
		_ln(x, 26, x, 40)
	_dome(0, 40, 30, 30); _rect(0, 70, 10, 10); _dome(0, 80, 5); _ln(0, 85, 0, 94); _ln(-3, 90, 3, 90)
	for x in [-40.0, 40.0]:
		_rect(x, 26, 12, 22); _dome(x, 48, 6)
	_add(640, 180, "BIG BEN")
	_rect(0, 0, 20, 92); _L.append(_arc(0, 80, 7, 0, TAU, 12)); _ln(0, 80, 0, 86); _ln(0, 80, 4, 80)
	_L.append(_pts([[-10, 92], [-10, 100], [0, 118], [10, 100], [10, 92]])); _ln(0, 118, 0, 126)
	_rect(-40, 0, 60, 30); _windows(-40, 0, 60, 30, 5, 2); _battlements(-70, -10, 30, 4, 6)
	_add(860, 160, "LONDON EYE", "eye")
	_L.append(_arc(0, 60, 52, 0, TAU, 28)); _L.append(_arc(0, 60, 44, 0, TAU, 28))
	for i in 16:
		var a := i / 16.0 * TAU
		_ln(0, 60, cos(a) * 52, 60 + sin(a) * 52)
	_L.append(_pts([[-30, 0], [0, 60], [30, 0]]))


func _paris() -> void:
	_add(220, 150, "ARC DE TRIOMPHE")
	_rect(0, 0, 66, 52); _ln(-33, 44, 33, 44)
	var arch := PackedVector2Array([Vector2(-14, 0), Vector2(-14, 24)])
	arch.append_array(_arc(0, 24, 14, PI, TAU, 10).slice(1)); arch.append(Vector2(14, 0)); _L.append(arch)
	_add(480, 280, "TOUR EIFFEL")
	var prof := [[0.0, 60.0], [34.0, 42.0], [66.0, 24.0], [96.0, 9.0], [130.0, 3.0]]
	for sgn in [-1.0, 1.0]:
		var side := PackedVector2Array()
		for p in prof:
			side.append(Vector2(sgn * p[1], p[0]))
		_L.append(side)
	for p in prof:
		_ln(-p[1], p[0], p[1], p[0])
	_ln(-28, 34, 28, 34); _ln(-21, 66, 21, 66)
	_L.append(_arc(0, 20, 30, 0.35, PI - 0.35, 10, 22))
	for i in range(prof.size() - 1):
		var y0: float = prof[i][0]; var w0: float = prof[i][1]; var y1: float = prof[i + 1][0]; var w1: float = prof[i + 1][1]
		var n := 2 if i < 2 else 1
		for k in n:
			var ya := y0 + (y1 - y0) * k / n; var yb := y0 + (y1 - y0) * (k + 1) / n
			var wa := w0 + (w1 - w0) * k / n; var wb := w0 + (w1 - w0) * (k + 1) / n
			_ln(-wa, ya, wb, yb); _ln(wa, ya, -wb, yb)
	_ln(0, 130, 0, 148); _rect(0, 130, 6, 4)
	_add(760, 160, "NOTRE-DAME")
	for x in [-20.0, 20.0]:
		_rect(x, 0, 22, 66); _windows(x, 36, 22, 26, 1, 2); _L.append(_arc(x, 50, 5, 0, PI, 6))
	_rect(0, 0, 18, 52); _L.append(_arc(0, 36, 7, 0, TAU, 12)); _L.append(_arc(0, 36, 3, 0, TAU, 8))
	_ln(0, 52, 0, 60); _L.append(_pts([[12, 0], [14, 40], [14, 50], [15, 98], [16, 50], [16, 40], [18, 0]]))


func _amsterdam() -> void:
	_add(170, 130, "WINDMILL", "windmill")
	_L.append(_pts([[-14, 0], [-9, 50], [9, 50], [14, 0]])); _dome(0, 50, 9, 7); _rect(0, 0, 10, 14)
	_add(430, 190, "CANAL HOUSES")
	var xs := [-80.0, -52.0, -24.0, 4.0, 32.0, 60.0]
	for i in xs.size():
		var x: float = xs[i]
		var h := 48.0 + (i % 3) * 8.0
		var w := 26.0
		_ln(x - w / 2, 0, x - w / 2, h); _ln(x + w / 2, 0, x + w / 2, h)
		if i % 3 == 0:
			_L.append(_pts([[x - w / 2, h], [x - w / 2 + 5, h], [x - w / 2 + 5, h + 6], [x - 5, h + 6], [x - 5, h + 12], [x + 5, h + 12], [x + 5, h + 6], [x + w / 2 - 5, h + 6], [x + w / 2 - 5, h], [x + w / 2, h]]))
		elif i % 3 == 1:
			_L.append(_pts([[x - w / 2, h], [x, h + 16], [x + w / 2, h]]))
		else:
			var g := PackedVector2Array([Vector2(x - w / 2, h)])
			g.append_array(_arc(x, h, w / 2, PI, TAU, 8, 12).slice(1)); _L.append(g)
		_windows(x, 0, w, h, 2, 3)
	_add(700, 140, "WESTERKERK")
	_rect(0, 0, 16, 70); _L.append(_arc(0, 60, 5, 0, TAU, 10)); _rect(0, 70, 10, 10); _L.append(_pts([[-8, 80], [-5, 90], [0, 86], [5, 90], [8, 80]])); _ln(0, 90, 0, 100)
	_add(880, 130, "WINDMILL", "windmill2")
	_L.append(_pts([[-14, 0], [-9, 50], [9, 50], [14, 0]])); _dome(0, 50, 9, 7)


func _berlin() -> void:
	_add(240, 160, "BRANDENBURG GATE")
	for i in 6:
		var x := -45.0 + i * 18.0
		_rect(x, 4, 7, 50); _ln(x - 5, 54, x + 5, 54)
	_rect(0, 0, 112, 4); _rect(0, 54, 112, 12); _rect(0, 66, 60, 8)
	for i in 4:
		_horse(-20 + i * 9, 74, 1)
	_rect(14, 74, 10, 8); _ln(19, 82, 19, 94); _L.append(_arc(19, 94, 3, 0, TAU, 8))
	_add(520, 190, "FERNSEHTURM")
	_L.append(_pts([[-7, 0], [-3, 96], [3, 96], [7, 0]])); _L.append(_arc(0, 112, 15, 0, TAU, 20)); _ln(-15, 112, 15, 112); _ln(-14, 106, 14, 106)
	_ln(0, 127, 0, 165); _ln(-3, 150, 3, 150)
	_add(780, 180, "REICHSTAG")
	_rect(0, 0, 120, 40); _windows(0, 0, 120, 40, 9, 2)
	for x in [-52.0, 52.0]:
		_rect(x, 40, 14, 12)
	_rect(0, 40, 30, 10); _dome(0, 50, 22, 20)
	var a := 0.3
	while a < PI:
		_ln(0, 50, cos(a) * 22, 50 + sin(a) * 20)
		a += 0.5


func _vienna() -> void:
	_add(230, 200, "STEPHANSDOM")
	_rect(-20, 0, 70, 36); _L.append(_pts([[-55, 36], [-20, 70], [15, 36]]))
	var x := -50.0
	while x < 12.0:
		_ln(x, 36 + (x + 55) * 0.6, x + 5, 36)
		x += 6.0
	_L.append(_pts([[28, 0], [28, 70], [31, 88], [34, 100], [36, 112], [38, 100], [41, 88], [44, 70], [44, 0]])); _ln(36, 112, 36, 124)
	_L.append(_arc(36, 60, 4, 0, PI, 6)); _ln(32, 60, 32, 50); _ln(40, 60, 40, 50)
	_add(500, 180, "RIESENRAD", "wheel")
	_L.append(_arc(0, 50, 45, 0, TAU, 28)); _L.append(_pts([[-34, 0], [0, 50], [34, 0]]))
	for i in 15:
		var a := i / 15.0 * TAU
		_ln(0, 50, cos(a) * 45, 50 + sin(a) * 45)
	_add(780, 160, "KARLSKIRCHE")
	_rect(0, 0, 90, 28)
	for xx in range(-30, 31, 10):
		_ln(xx, 0, xx, 28)
	_L.append(_pts([[-40, 28], [0, 42], [40, 28]]))
	_rect(0, 42, 34, 12); _dome(0, 54, 24, 26); _rect(0, 80, 8, 8); _ln(0, 88, 0, 96)
	for xx in [-62.0, 62.0]:
		_rect(xx, 0, 10, 56); _rect(xx, 56, 14, 5); _ln(xx, 61, xx, 70)


func _rome() -> void:
	_add(230, 180, "COLOSSEUM")
	var w := 160.0
	for y in [0.0, 18.0, 36.0]:
		var x_end := w / 2 if y < 36.0 else w / 2 - 44.0
		_ln(-w / 2, y, x_end, y)
		var x := -w / 2 + 8.0
		while x < x_end - 6.0:
			var a := PackedVector2Array([Vector2(x, y + 3)])
			a.append_array(_arc(x + 5, y + 10, 5, PI, TAU, 6).slice(0, 4)); a.append(Vector2(x + 10, y + 3)); _L.append(a)
			_ln(x, y + 3, x, y + 10); _ln(x + 10, y + 3, x + 10, y + 10)
			x += 14.0
	_ln(-w / 2, 0, -w / 2, 54)
	_L.append(_pts([[-w / 2, 54], [-w / 2 + 40, 54], [-w / 2 + 50, 48], [-w / 2 + 62, 54], [-w / 2 + 80, 50], [-w / 2 + 100, 54], [-w / 2 + 116, 46], [w / 2 - 44, 36]]))
	_ln(w / 2, 0, w / 2, 36); _L.append(_pts([[w / 2 - 44, 36], [w / 2 - 30, 40], [w / 2 - 20, 30], [w / 2 - 8, 36], [w / 2, 36]]))
	_add(530, 200, "ST PETERS")
	_rect(0, 0, 130, 30)
	for x in range(-55, 56, 11):
		_ln(x, 0, x, 30)
	_rect(0, 30, 130, 6); _L.append(_pts([[-30, 36], [0, 48], [30, 36]]))
	_rect(0, 36, 50, 18)
	for x in range(-20, 21, 8):
		_ln(x, 36, x, 54)
	_dome(0, 54, 34, 34); _rect(0, 88, 12, 10); _dome(0, 98, 6); _ln(0, 104, 0, 112); _ln(-3, 108, 3, 108)
	_add(760, 90, "PINES"); _tree(-30, 60); _tree(10, 72); _tree(50, 56)
	_add(900, 90, "VILLA"); _rect(0, 0, 50, 40); _windows(0, 0, 50, 40, 3, 3); _L.append(_pts([[-25, 40], [0, 50], [25, 40]]))


func _athens() -> void:
	_add(360, 300, "ACROPOLIS")
	_L.append(_pts([[-150, 0], [-130, 22], [-100, 40], [-60, 52], [0, 56], [60, 54], [100, 44], [130, 28], [150, 0]]))
	_rect(0, 56, 120, 6); _rect(0, 62, 110, 4)
	for i in 8:
		var x := -49.0 + i * 14.0
		_rect(x, 66, 5, 26); _ln(x - 4, 92, x + 4, 92)
	_rect(0, 92, 112, 6); _L.append(_pts([[-56, 98], [-20, 112], [-8, 106], [10, 114], [40, 100]]))
	_rect(-90, 40, 30, 14); _ln(-90, 54, -84, 60)
	_add(720, 120, "LYCABETTUS")
	_L.append(_pts([[-70, 0], [-40, 40], [-10, 70], [10, 70], [40, 40], [70, 0]])); _rect(0, 70, 14, 10); _dome(0, 80, 5); _ln(0, 85, 0, 92)
	_add(900, 100, "FLATS"); _rect(0, 0, 60, 46); _windows(0, 0, 60, 46, 4, 4)


# --- animation, burning, drawing ----------------------------------------------------------------

func _anim_lines(e: Dictionary) -> Array:
	var out: Array = []
	match e.anim:
		"eye":
			for i in 16:
				var a := i / 16.0 * TAU + t * 0.08
				out.append(_rect_pts(cos(a) * 52, 58 + sin(a) * 52, 5, 4))
		"wheel":
			for i in 15:
				var a := i / 15.0 * TAU - t * 0.1
				out.append(_rect_pts(cos(a) * 45, 46 + sin(a) * 45, 7, 6))
		"windmill":
			for i in 4:
				var a := i * PI / 2 + t * 0.6
				out.append(PackedVector2Array([Vector2(0, 55), Vector2(cos(a) * 38, 55 + sin(a) * 38)]))
				out.append(PackedVector2Array([Vector2(cos(a) * 10, 55 + sin(a) * 10), Vector2(cos(a) * 36 + cos(a + PI / 2) * 5, 55 + sin(a) * 36 + sin(a + PI / 2) * 5)]))
		"windmill2":
			for i in 4:
				var a := i * PI / 2 - t * 0.45 + 0.4
				out.append(PackedVector2Array([Vector2(0, 55), Vector2(cos(a) * 38, 55 + sin(a) * 38)]))
	return out


func _rect_pts(cx: float, y0: float, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(cx - w / 2, y0), Vector2(cx + w / 2, y0), Vector2(cx + w / 2, y0 + h), Vector2(cx - w / 2, y0 + h), Vector2(cx - w / 2, y0)])


func ignite(e: Dictionary) -> void:
	if e.heat > 0.0 or e.ruined:
		return
	e.heat = 1.0
	e.burn_t = 0.0
	Sfx.play("burn")


func _max_h(e: Dictionary) -> float:
	var m := 0.0
	for L in e.lines:
		for p in L:
			m = maxf(m, p.y)
	return m


static func clip_lines(lines: Array, limit: float) -> Array:
	var out: Array = []
	for L in lines:
		var cur := PackedVector2Array()
		for i in L.size():
			var p: Vector2 = L[i]
			var inside := p.y <= limit
			if i > 0:
				var q: Vector2 = L[i - 1]
				var qin := q.y <= limit
				if inside != qin:
					var tt := (limit - q.y) / (p.y - q.y)
					var ix := Vector2(q.x + (p.x - q.x) * tt, limit)
					if qin:
						cur.append(ix)
						out.append(cur)
						cur = PackedVector2Array()
					else:
						cur.append(ix)
			if inside:
				cur.append(p)
		if cur.size() > 1:
			out.append(cur)
	return out


func update(dt: float) -> void:
	t += dt
	for e in elements:
		if e.heat <= 0.0 or e.ruined:
			continue
		e.burn_t += dt
		var max_h := _max_h(e)
		if fx and randf() < 0.7:
			fx.sparks(Vector2(e.x + randf_range(-e.w / 2, e.w / 2), C.GROUND - randf() * max_h), 2,
				{"speed": 90.0, "color": Vec.RED if randf() < 0.5 else Vec.AMBER, "life": 0.5, "grav": 0.3})
		if e.burn_t > 1.1:
			e.ruined = true
			e.heat = 0.0
			var keep := max_h * randf_range(0.25, 0.45)
			var ruin := clip_lines(e.lines, keep)
			var jag := PackedVector2Array([Vector2(-e.w / 2, keep)])
			var x: float = -e.w / 2
			while x < e.w / 2:
				jag.append(Vector2(x, keep - randf_range(2, 10)))
				x += 6.0 + randf() * 8.0
			jag.append(Vector2(e.w / 2, keep))
			ruin.append(jag)
			e.lines = ruin
			e.anim = ""
			e["keep"] = keep
			building_fell.emit(e)
	queue_redraw()


func _draw() -> void:
	for e in elements:
		var col := Vec.DIM
		if e.heat > 0.0:
			col = Vec.RED if int(t * 30) % 2 == 1 else Vec.WHITE
		col = Vec.faded(col, 0.6 if e.ruined else 0.85)
		var origin := Vector2(e.x, C.GROUND)
		Vec.lines(self, e.lines, origin, col, 1.4)
		if e.anim != "":
			Vec.lines(self, _anim_lines(e), origin, col, 1.2)
