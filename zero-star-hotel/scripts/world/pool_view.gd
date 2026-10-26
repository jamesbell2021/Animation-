class_name PoolView
extends Node2D
## The pool terrace: the pool itself (a green swamp, then clean, then with a slide),
## sunloungers, palms, the fence and "NO DIVING" signs once bought, and the lifeguard's chair.
## A second instance with front_layer = true draws the water surface over swimmers.

const INK := Color(0.17, 0.11, 0.09)

var front_layer := false
var _t := 0.0
var _font: Font


func _ready() -> void:
	_font = UITheme.bold_font()
	z_index = 6 if front_layer else -10
	Upgrades.upgrade_purchased.connect(func(_i, _l): queue_redraw())
	Upgrades.upgrades_reset.connect(queue_redraw)
	Staff.staff_changed.connect(queue_redraw)


func _process(delta: float) -> void:
	_t += delta
	if front_layer and int(_t * 8.0) != int((_t - delta) * 8.0):
		queue_redraw()


func water_color() -> Color:
	return Color("#6b8e23") if Upgrades.level("pool") == 0 else Color("#29b6f6")


func _draw() -> void:
	if front_layer:
		_draw_water_front()
		return
	var x0 := HotelLayout.POOL_X0
	var x1 := HotelLayout.POOL_X1
	var y := HotelLayout.GROUND_Y
	# Tiles round the pool and the pool basin.
	draw_rect(Rect2(x0 - 20, y, x1 - x0 + 40, HotelLayout.POOL_DEPTH + 20), Color("#eceff1"))
	draw_rect(Rect2(x0, HotelLayout.POOL_TOP, x1 - x0, HotelLayout.POOL_DEPTH), water_color().darkened(0.25))
	draw_rect(Rect2(x0 - 20, y, x1 - x0 + 40, HotelLayout.POOL_DEPTH + 20), INK, false, 3.0)
	# Ladder.
	for k in 2:
		draw_line(Vector2(x0 + 30 + k * 18, y - 20), Vector2(x0 + 30 + k * 18, y + 60), Color("#b0bec5"), 4.0)
	if Upgrades.level("pool") == 0:
		# Things living in the swamp.
		draw_colored_polygon(VendorAvatar._ellipse(Vector2(x0 + 300, HotelLayout.POOL_TOP + 50), 40, 10), Color(0.3, 0.45, 0.15, 0.7))
		draw_string(_font, Vector2(x0 + 400, y - 8), "SWIM AT OWN RISK", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#c62828"))
	if Upgrades.level("pool") >= 2:
		_draw_slide()
	# Sunloungers.
	for i in Upgrades.lounger_count():
		var p := HotelLayout.lounger(i)
		var stripe: Color = [Color("#1e88e5"), Color("#e53935"), Color("#43a047"), Color("#fdd835")][i % 4]
		var bed := PackedVector2Array([p + Vector2(-24, -18), p + Vector2(10, -18), p + Vector2(22, -44), p + Vector2(28, -42), p + Vector2(16, -12), p + Vector2(-24, -12)])
		draw_colored_polygon(bed, Color("#fafafa"))
		draw_line(p + Vector2(-22, -15), p + Vector2(10, -15), stripe, 4.0)
		draw_line(p + Vector2(13, -18), p + Vector2(23, -40), stripe, 4.0)
		bed.append(bed[0])
		draw_polyline(bed, INK, 2.0)
		draw_line(p + Vector2(-20, -12), p + Vector2(-20, 0), INK, 3.0)
		draw_line(p + Vector2(14, -12), p + Vector2(14, 0), INK, 3.0)
	# Palms on the terrace.
	for x in [1310.0, 2560.0]:
		_palm(Vector2(x, y))
	# Fence and signs.
	if Upgrades.level("fence") > 0:
		for x in range(int(x0) - 40, int(x1) + 50, 30):
			draw_line(Vector2(x, y), Vector2(x, y - 46), Color("#90a4ae"), 3.0)
		draw_line(Vector2(x0 - 40, y - 44), Vector2(x1 + 40, y - 44), Color("#90a4ae"), 4.0)
		draw_line(Vector2(x0 - 40, y - 20), Vector2(x1 + 40, y - 20), Color("#90a4ae"), 3.0)
	if Upgrades.level("signs") > 0:
		for x in [x0 + 160.0, x1 - 160.0]:
			draw_line(Vector2(x, y), Vector2(x, y - 70), INK, 4.0)
			draw_rect(Rect2(x - 40, y - 104, 80, 36), Color("#fffaf0"))
			draw_rect(Rect2(x - 40, y - 104, 80, 36), Color("#c62828"), false, 4.0)
			draw_string(_font, Vector2(x - 40, y - 82), "NO DIVING", HORIZONTAL_ALIGNMENT_CENTER, 80, 14, Color("#c62828"))
	# Lifeguard chair (only once there's a lifeguard to sit in it).
	if Staff.count_role("lifeguard") > 0:
		var c := Vector2(HotelLayout.LIFEGUARD_X, y)
		draw_line(c + Vector2(-16, 0), c + Vector2(-8, -90), INK, 5.0)
		draw_line(c + Vector2(16, 0), c + Vector2(8, -90), INK, 5.0)
		draw_rect(Rect2(c + Vector2(-20, -96), Vector2(40, 8)), Color("#e53935"))
		ItemArt.draw_item(self, "lifebuoy", c + Vector2(0, -40), 26.0)


func _draw_slide() -> void:
	var base := Vector2(HotelLayout.POOL_X1 - 40, HotelLayout.GROUND_Y)
	draw_line(base + Vector2(20, 0), base + Vector2(20, -170), Color("#b0bec5"), 6.0)
	var pts := PackedVector2Array()
	for k in 12:
		var f := k / 11.0
		pts.append(base + Vector2(20 - f * 160 + sin(f * PI) * 10, -170 + f * 175))
	draw_polyline(pts, INK, 22.0)
	draw_polyline(pts, Color("#ffd23f"), 16.0)


func _draw_water_front() -> void:
	var x0 := HotelLayout.POOL_X0
	var x1 := HotelLayout.POOL_X1
	var col := water_color()
	col.a = 0.82
	var pts := PackedVector2Array()
	for x in range(int(x0), int(x1) + 1, 20):
		pts.append(Vector2(x, HotelLayout.POOL_TOP + sin(x * 0.05 + _t * 2.5) * 3.0))
	pts.append(Vector2(x1, HotelLayout.POOL_TOP + HotelLayout.POOL_DEPTH))
	pts.append(Vector2(x0, HotelLayout.POOL_TOP + HotelLayout.POOL_DEPTH))
	draw_colored_polygon(pts, col)
	var surf := pts.slice(0, pts.size() - 2)
	draw_polyline(surf, Color(1, 1, 1, 0.6), 3.0)


func _palm(base: Vector2) -> void:
	draw_line(base, base + Vector2(14, -190), INK, 15.0)
	draw_line(base, base + Vector2(14, -190), Color("#9c6b3c"), 11.0)
	var top := base + Vector2(14, -190)
	for k in 7:
		var a := -PI * 0.5 + (k - 3) * 0.5
		var tip := top + Vector2(cos(a) * 80.0, sin(a) * 32.0 + 36.0)
		draw_colored_polygon(PackedVector2Array([top, top + Vector2(cos(a) * 40, sin(a) * 24 - 10), tip, top + Vector2(cos(a) * 40, sin(a) * 24 + 6)]), Color("#2e7d32"))
