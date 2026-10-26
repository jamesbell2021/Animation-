class_name BuildingView
extends Node2D
## The hotel building and its surroundings, drawn once (and again when an upgrade changes
## something): sky, distant sea and rival hotels, the street, the stairwell, reception and the
## bar on the ground floor, and the roof sign with its stars. Rooms are separate RoomViews.
## A second instance with front_layer = true draws the floor slabs in front of the characters.

const INK := Color(0.17, 0.11, 0.09)
const WALL := Color("#f3d9b1")
const WALL_DARK := Color("#d9b98c")
const SLAB := Color("#bfae97")

var front_layer := false
var _font: Font


func _ready() -> void:
	_font = UITheme.bold_font()
	z_index = 5 if front_layer else -20
	Upgrades.upgrade_purchased.connect(func(_i, _l): queue_redraw())
	Upgrades.upgrades_reset.connect(queue_redraw)
	Hotel.stars_changed.connect(func(_s): queue_redraw())
	Economy.prices_changed.connect(queue_redraw)


func _draw() -> void:
	if front_layer:
		_draw_front()
	else:
		_draw_back()


func _draw_back() -> void:
	var W := HotelLayout.WORLD_W
	# Sky, sun, sea on the horizon, and rival hotels in the distance.
	draw_rect(Rect2(-400, -400, W + 800, 640), Color("#7fd3f7"))
	draw_rect(Rect2(-400, 240, W + 800, 260), Color("#a7e1f8"))
	draw_circle(Vector2(2250, 120), 60, Color(1, 0.95, 0.7, 0.35))
	draw_circle(Vector2(2250, 120), 42, Color("#fff3b0"))
	draw_rect(Rect2(1300, 520, W, 120), Color("#1e9bd7"))
	for k in 6:
		var x := 1340.0 + k * 210.0
		var h := 120.0 + (k * 53) % 90
		draw_rect(Rect2(x, 640 - h, 120, h), Color("#e8dfd0"))
		for wy in range(int(640 - h + 14), 630, 22):
			for wx in range(int(x + 12), int(x + 110), 24):
				draw_rect(Rect2(wx, wy, 12, 10), Color("#9ec9e0"))
	for x in [1420.0, 1900.0, 2420.0]:
		_palm(Vector2(x, 650), 0.8, Color(0.2, 0.45, 0.3, 0.6))
	# Ground: street on the left, terrace on the right.
	draw_rect(Rect2(-400, HotelLayout.GROUND_Y, W + 800, 400), Color("#d8c3a5"))
	draw_rect(Rect2(-400, HotelLayout.GROUND_Y, HotelLayout.STAIR_X0 + 400, 400), Color("#7b7b85"))
	for x in range(-380, int(HotelLayout.STAIR_X0), 70):
		draw_line(Vector2(x, HotelLayout.GROUND_Y + 60), Vector2(x + 40, HotelLayout.GROUND_Y + 60), Color("#f5f5f5"), 5.0)
	for x in range(int(HotelLayout.BUILD_X1), int(W + 400), 48):
		draw_line(Vector2(x, HotelLayout.GROUND_Y), Vector2(x - 12, HotelLayout.GROUND_Y + 220), Color(0, 0, 0, 0.06), 2.0)
	# Building shell.
	var top := HotelLayout.level_y(3) - HotelLayout.FLOOR_H
	draw_rect(Rect2(HotelLayout.STAIR_X0 - 10, top - 10, HotelLayout.BUILD_X1 - HotelLayout.STAIR_X0 + 20, HotelLayout.GROUND_Y - top + 10), WALL_DARK)
	_draw_stairwell(top)
	_draw_reception()
	_draw_bar()
	# The roof and its (lack of) stars.
	_draw_roof(top)


func _draw_stairwell(top: float) -> void:
	var x0 := HotelLayout.STAIR_X0
	draw_rect(Rect2(x0, top, HotelLayout.STAIR_W, HotelLayout.GROUND_Y - top), Color("#e8cfa6"))
	for lvl in 3:
		var y0 := HotelLayout.level_y(lvl)
		var y1 := HotelLayout.level_y(lvl + 1)
		var a := Vector2(x0 + (HotelLayout.STAIR_W - 20.0 if lvl % 2 == 0 else 20.0), y0)
		var b := Vector2(x0 + (20.0 if lvl % 2 == 0 else HotelLayout.STAIR_W - 20.0), y1)
		var steps := 9
		var pts := PackedVector2Array()
		for s in steps + 1:
			var f := float(s) / steps
			var p := a.lerp(b, f)
			pts.append(Vector2(p.x, p.y))
			if s < steps:
				pts.append(Vector2(a.lerp(b, float(s + 1) / steps).x, p.y))
		draw_polyline(pts, Color("#8d6e63"), 4.0)
	draw_rect(Rect2(x0, top, HotelLayout.STAIR_W, HotelLayout.GROUND_Y - top), INK, false, 3.0)
	# Front door.
	draw_rect(Rect2(x0 + 10, HotelLayout.GROUND_Y - 110, 70, 110), Color("#6d4c41"))
	draw_rect(Rect2(x0 + 18, HotelLayout.GROUND_Y - 100, 54, 60), Color("#b3e5fc"))
	draw_string(_font, Vector2(x0 + 4, HotelLayout.GROUND_Y - 118), "IN", HORIZONTAL_ALIGNMENT_CENTER, 82, 16, INK)


func _draw_reception() -> void:
	var x0 := HotelLayout.ROOM_X0
	var y := HotelLayout.GROUND_Y
	var lvl := Upgrades.level("reception")
	var wall: Color = [Color("#e9d7b5"), Color("#f5e6cc"), Color("#e0f2f1")][lvl]
	draw_rect(Rect2(x0, y - HotelLayout.FLOOR_H, HotelLayout.BAR_X0 - x0, HotelLayout.FLOOR_H), wall)
	draw_string(_font, Vector2(x0, y - HotelLayout.FLOOR_H + 30), "RECEPTION", HORIZONTAL_ALIGNMENT_CENTER, HotelLayout.BAR_X0 - x0, 20, INK)
	match lvl:
		0:  # a wobbly plastic table
			draw_rect(Rect2(HotelLayout.DESK_X + 20, y - 52, 90, 8), Color("#fafafa"))
			for lx in [HotelLayout.DESK_X + 26, HotelLayout.DESK_X + 100]:
				draw_line(Vector2(lx, y - 44), Vector2(lx - 4, y), Color("#bdbdbd"), 4.0)
			draw_string(_font, Vector2(HotelLayout.DESK_X + 10, y - 62), "ring bell (broken)", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK)
		1:  # a proper desk
			draw_rect(Rect2(HotelLayout.DESK_X + 20, y - 70, 130, 70), Color("#8d6e63"))
			draw_rect(Rect2(HotelLayout.DESK_X + 20, y - 76, 136, 8), Color("#5d4037"))
			draw_circle(Vector2(HotelLayout.DESK_X + 130, y - 82), 7, Color("#ffd23f"))
		2:  # an air-conditioned lobby
			draw_rect(Rect2(HotelLayout.DESK_X + 20, y - 74, 140, 74), Color("#fafafa"))
			draw_rect(Rect2(HotelLayout.DESK_X + 20, y - 80, 146, 8), Color("#26a69a"))
			draw_rect(Rect2(x0 + 20, y - HotelLayout.FLOOR_H + 44, 70, 24), Color("#eceff1"))
			draw_string(_font, Vector2(x0 + 20, y - HotelLayout.FLOOR_H + 62), "*brrr*", HORIZONTAL_ALIGNMENT_CENTER, 70, 12, Color("#0288d1"))
			_plant(Vector2(HotelLayout.BAR_X0 - 30, y))
	draw_rect(Rect2(x0, y - HotelLayout.FLOOR_H, HotelLayout.BAR_X0 - x0, HotelLayout.FLOOR_H), INK, false, 3.0)


func _draw_bar() -> void:
	var x0 := HotelLayout.BAR_X0
	var x1 := HotelLayout.BAR_X1
	var y := HotelLayout.GROUND_Y
	var lvl := Upgrades.level("bar")
	var wall: Color = [Color("#d7ccc8"), Color("#a1887f"), Color("#4a148c")][lvl]
	draw_rect(Rect2(x0, y - HotelLayout.FLOOR_H, x1 - x0, HotelLayout.FLOOR_H), wall)
	var names := ["THE BAR (ish)", "THE DRUNKEN DUCK", "CLUB PARADISO COCKTAILS"]
	var title_col: Color = [INK, Color("#ffd23f"), Color("#ff4fa3")][lvl]
	draw_string(_font, Vector2(x0, y - HotelLayout.FLOOR_H + 30), names[lvl], HORIZONTAL_ALIGNMENT_CENTER, x1 - x0, 22, title_col)
	# Chalkboard with the pint price.
	var board := Rect2(x0 + 20, y - HotelLayout.FLOOR_H + 44, 130, 64)
	draw_rect(board, Color("#263238"))
	draw_rect(board, Color("#8d6e63"), false, 5.0)
	draw_string(_font, board.position + Vector2(0, 28), Lines.money(Economy.pint_price()), HORIZONTAL_ALIGNMENT_CENTER, board.size.x, 26, Color.WHITE)
	draw_string(_font, board.position + Vector2(0, 52), "PINTS!", HORIZONTAL_ALIGNMENT_CENTER, board.size.x, 16, Color("#ffd23f"))
	# Counter on the right, stools in a row.
	var cx := HotelLayout.BAR_COUNTER_X
	match lvl:
		0:  # a humming fridge of cans
			draw_rect(Rect2(cx - 10, y - 110, 60, 110), Color("#eceff1"))
			draw_rect(Rect2(cx - 10, y - 110, 60, 110), INK, false, 3.0)
			for k in 4:
				draw_rect(Rect2(cx - 2 + (k % 2) * 24, y - 100 + (k / 2) * 30, 16, 22), Color("#e53935"))
			draw_string(_font, Vector2(cx - 20, y - 118), "HONESTY BOX", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK)
		_:
			draw_rect(Rect2(cx - 50, y - 76, 110, 76), Color("#6d4c41") if lvl == 1 else Color("#ad1457"))
			draw_rect(Rect2(cx - 56, y - 82, 120, 8), Color("#3e2723") if lvl == 1 else Color("#f8bbd0"))
			for k in 3:
				draw_line(Vector2(cx - 30 + k * 22, y - 82), Vector2(cx - 30 + k * 22, y - 100), Color("#cfd8dc"), 4.0)
			for k in 5:
				var bx := cx - 40 + k * 20
				draw_rect(Rect2(bx, y - HotelLayout.FLOOR_H + 60, 10, 26), [Color("#7cb342"), Color("#ffb300"), Color("#8e24aa"), Color("#29b6f6"), Color("#e53935")][k])
	if Upgrades.level("karaoke") > 0:
		draw_rect(Rect2(x0 + 180, y - 96, 40, 96), Color("#311b92"))
		draw_circle(Vector2(x0 + 200, y - 80), 10, Color("#ff4fa3"))
		draw_string(_font, Vector2(x0 + 160, y - 104), "KARAOKE", HORIZONTAL_ALIGNMENT_CENTER, 80, 12, Color("#ffd23f"))
	for i in 7:
		var s := HotelLayout.stool(i)
		draw_line(s + Vector2(0, -4), s + Vector2(0, -40), INK, 4.0)
		draw_colored_polygon(VendorAvatar._ellipse(s + Vector2(0, -42), 14, 5), Color("#c62828"))
	draw_rect(Rect2(x0, y - HotelLayout.FLOOR_H, x1 - x0, HotelLayout.FLOOR_H), INK, false, 3.0)


func _draw_roof(top: float) -> void:
	var x0 := HotelLayout.STAIR_X0 - 20
	var x1 := HotelLayout.BUILD_X1 + 20
	draw_rect(Rect2(x0, top - 24, x1 - x0, 24), Color("#c1543c"))
	var sign := Rect2(HotelLayout.ROOM_X0 + 80, top - 112, 560, 80)
	draw_line(Vector2(sign.position.x + 60, sign.end.y), Vector2(sign.position.x + 60, top - 24), INK, 5.0)
	draw_line(Vector2(sign.end.x - 60, sign.end.y), Vector2(sign.end.x - 60, top - 24), INK, 5.0)
	draw_rect(sign, Color("#fffaf0"))
	draw_rect(sign, INK, false, 4.0)
	var title := Hotel.name_of_hotel.to_upper()
	# A missing letter until the first star: classic.
	if Hotel.stars == 0 and title.length() > 4:
		title = title.substr(0, 3) + " " + title.substr(4)
	draw_string(_font, sign.position + Vector2(0, 40), title, HORIZONTAL_ALIGNMENT_CENTER, sign.size.x, 34, Color("#c62828"))
	for k in 3:
		var c := sign.position + Vector2(sign.size.x * 0.5 - 50 + k * 50, 62)
		var pts := VendorAvatar._star(c, 13, 6)
		draw_colored_polygon(pts, Color("#ffd23f") if k < Hotel.stars else Color("#cfd8dc"))
		pts.append(pts[0])
		draw_polyline(pts, INK, 2.0)


func _draw_front() -> void:
	# Floor slabs between levels, the building edge, and the ground-floor sill.
	for lvl in range(0, 4):
		var y := HotelLayout.level_y(lvl)
		draw_rect(Rect2(HotelLayout.STAIR_X0 - 10, y, HotelLayout.BUILD_X1 - HotelLayout.STAIR_X0 + 20, 12), SLAB)
		draw_line(Vector2(HotelLayout.STAIR_X0 - 10, y), Vector2(HotelLayout.BUILD_X1 + 10, y), INK, 3.0)
	for x in [HotelLayout.STAIR_X0 - 10, HotelLayout.BUILD_X1 + 10]:
		draw_rect(Rect2(x - 6, HotelLayout.level_y(3) - HotelLayout.FLOOR_H, 12, HotelLayout.GROUND_Y - HotelLayout.level_y(3) + HotelLayout.FLOOR_H + 12), Color("#c9b192"))


func _palm(base: Vector2, s: float, col: Color) -> void:
	draw_line(base, base + Vector2(10, -160) * s, Color(0.45, 0.32, 0.2, col.a), 10.0 * s)
	var top := base + Vector2(10, -160) * s
	for k in 6:
		var a := -PI * 0.5 + (k - 2.5) * 0.55
		draw_line(top, top + Vector2(cos(a) * 70, sin(a) * 30 + 30) * s, col, 8.0 * s)


func _plant(base: Vector2) -> void:
	draw_rect(Rect2(base.x - 14, base.y - 30, 28, 30), Color("#8d6e63"))
	for k in 5:
		var a := -PI * 0.5 + (k - 2) * 0.45
		draw_line(base + Vector2(0, -30), base + Vector2(cos(a) * 30, -30 + sin(a) * 40), Color("#2e7d32"), 6.0)
