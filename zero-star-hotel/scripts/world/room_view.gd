class_name RoomView
extends Node2D
## One hotel room in cut-away. Wallpaper, bed and furniture get nicer with each quality
## level; dirt, cans, a smashed telly, graffiti and a boarded-up door show its state. Closed
## rooms are boarded up, and rooms on unopened floors say why ("ASBESTOS").

const INK := Color(0.17, 0.11, 0.09)

var index := 0
var _font: Font
var _rect := Rect2()
var _party := 0.0
var _t := 0.0


func _ready() -> void:
	_font = UITheme.bold_font()
	z_index = -15
	_rect = HotelLayout.room_rect(index)
	Hotel.rooms_changed.connect(queue_redraw)
	Upgrades.upgrade_purchased.connect(func(_i, _l): queue_redraw())
	set_process(false)


## Pulsing party lights while a rave is on in here.
func set_party(on: bool) -> void:
	_party = 1.0 if on else 0.0
	set_process(on)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if int(_t * 6.0) != int((_t - delta) * 6.0):
		queue_redraw()


func _draw() -> void:
	var r := _rect
	var room: Dictionary = Hotel.rooms[index]
	if not Hotel.floor_unlocked(Hotel.floor_of(index)):
		draw_rect(r, Color("#5d5348"))
		_tape(r)
		draw_string(_font, r.position + Vector2(0, r.size.y * 0.5), "CLOSED", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 22, Color("#ffd23f"))
		draw_string(_font, r.position + Vector2(0, r.size.y * 0.5 + 24), "(asbestos)", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 14, Color("#ffd23f"))
		draw_rect(r, INK, false, 3.0)
		return
	var q := int(room.quality)
	var walls := [Color("#b8a27a"), Color("#e6d3a8"), Color("#cfe8d8"), Color("#f8e1ec")]
	draw_rect(r, walls[q])
	if q == 0:
		# Peeling wallpaper and a damp patch.
		draw_colored_polygon(VendorAvatar._ellipse(r.position + Vector2(170, 40), 30, 20), Color(0.35, 0.4, 0.25, 0.35))
		for k in 3:
			draw_line(r.position + Vector2(30 + k * 60, 10), r.position + Vector2(40 + k * 60, 40), Color(0, 0, 0, 0.12), 3.0)
	else:
		for k in range(1, 8):
			draw_line(r.position + Vector2(k * 28, 0), r.position + Vector2(k * 28, r.size.y - 8), Color(1, 1, 1, 0.18), 3.0)
	# Window with a view (of the neighbour's wall, at first).
	var win := Rect2(r.position + Vector2(140, 26), Vector2(60, 50))
	draw_rect(win, Color("#9e9e9e") if q == 0 else Color("#b3e5fc"))
	if q >= 2:
		draw_rect(Rect2(win.position + Vector2(0, 32), Vector2(60, 18)), Color("#1e9bd7"))
	draw_rect(win, INK, false, 3.0)
	if q >= 2:
		draw_rect(Rect2(win.position - Vector2(10, 4), Vector2(14, 58)), Color("#e57373"))
		draw_rect(Rect2(win.position + Vector2(56, -4), Vector2(14, 58)), Color("#e57373"))
	if not room.open:
		_boarded(r)
		draw_rect(r, INK, false, 3.0)
		_plate(r, room)
		return
	var floor_y := r.end.y
	# Bed.
	var bed := Rect2(r.position + Vector2(64, r.size.y - 46), Vector2(110, 30))
	draw_rect(Rect2(bed.position + Vector2(0, 8), bed.size - Vector2(0, 8)), [Color("#8d6e63"), Color("#a1887f"), Color("#6d4c41"), Color("#5d4037")][q])
	draw_rect(Rect2(bed.position, Vector2(bed.size.x, 14)), [Color("#e0d6b8"), Color("#fafafa"), Color("#fff8e1"), Color("#ffffff")][q])
	draw_rect(Rect2(bed.position + Vector2(0, -2), Vector2(24, 12)), Color.WHITE)
	if q == 0:
		draw_circle(bed.position + Vector2(70, 6), 7, Color(0.7, 0.6, 0.2, 0.45))
	if q >= 3:
		draw_rect(Rect2(bed.position + Vector2(30, 0), Vector2(80, 14)), Color("#ec407a"))
	draw_rect(bed, INK, false, 2.0)
	# Telly (or what's left of it).
	var tv := Rect2(r.position + Vector2(16, r.size.y - 88), Vector2(38, 28))
	if int(room.damage) >= 2:
		draw_rect(tv, Color("#424242"))
		draw_polyline(PackedVector2Array([tv.position + Vector2(4, 4), tv.position + Vector2(18, 16), tv.position + Vector2(12, 24), tv.position + Vector2(34, 10)]), Color.WHITE, 2.0)
	else:
		draw_rect(tv, Color("#263238") if q < 3 else Color("#111111"))
		draw_rect(Rect2(tv.position + Vector2(3, 3), tv.size - Vector2(6, 6)), Color("#4fc3f7") if q >= 3 else Color("#607d8b"))
	draw_rect(tv, INK, false, 2.0)
	draw_line(Vector2(tv.position.x + 19, tv.end.y), Vector2(tv.position.x + 19, floor_y - 6), INK, 3.0)
	if q >= 2:
		draw_rect(Rect2(r.position + Vector2(186, r.size.y - 44), Vector2(22, 30)), Color("#a1887f"))
		draw_circle(r.position + Vector2(197, r.size.y - 52), 9, Color("#fff59d"))
	# Mess.
	var dirt := float(room.dirt)
	if dirt > 30.0:
		var n := int(dirt / 15.0)
		for k in n:
			var p := r.position + Vector2(20 + (k * 47) % 180, r.size.y - 14 - (k % 2) * 4)
			if k % 3 == 0:
				draw_rect(Rect2(p, Vector2(8, 12)), Color("#e53935"))  # a can
			else:
				draw_colored_polygon(VendorAvatar._ellipse(p + Vector2(6, 6), 9, 3), Color(0.35, 0.28, 0.15, 0.4))
	if dirt > 70.0:
		draw_colored_polygon(VendorAvatar._ellipse(r.position + Vector2(40, 60), 14, 9), Color(0.35, 0.28, 0.15, 0.35))
	# Damage: broken lamp, smashed telly, full trashing.
	var dmg := int(room.damage)
	if dmg >= 1:
		draw_line(r.position + Vector2(196, 10), r.position + Vector2(206, 40), INK, 3.0)
		draw_colored_polygon(PackedVector2Array([r.position + Vector2(196, 40), r.position + Vector2(216, 40), r.position + Vector2(206, 50)]), Color("#fff59d"))
	if dmg >= 3:
		draw_string(_font, r.position + Vector2(20, 60), "LADS!!", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#43a047"))
		draw_line(r.position + Vector2(64, r.size.y - 46), r.position + Vector2(174, r.size.y - 26), INK, 4.0)
	# Party lights.
	if _party > 0.0:
		var cols := [Color(1, 0.2, 0.6, 0.25), Color(0.2, 0.8, 1, 0.25), Color(1, 0.9, 0.2, 0.25)]
		draw_rect(r, cols[int(_t * 6.0) % 3])
	draw_rect(r, INK, false, 3.0)
	_plate(r, room)


func _plate(r: Rect2, room: Dictionary) -> void:
	var p := Rect2(r.position + Vector2(8, 8), Vector2(56, 22))
	draw_rect(p, Color("#fffaf0"))
	draw_rect(p, INK, false, 2.0)
	draw_string(_font, p.position + Vector2(0, 17), Hotel.room_label(index), HORIZONTAL_ALIGNMENT_CENTER, p.size.x, 16, INK)
	if room.open and int(room.group) >= 0:
		draw_circle(p.position + Vector2(p.size.x + 10, 11), 6, Color("#43a047"))


func _boarded(r: Rect2) -> void:
	draw_rect(r, Color(0.3, 0.25, 0.2, 0.55))
	for k in 4:
		var y := r.position.y + 30 + k * 34
		draw_colored_polygon(PackedVector2Array([Vector2(r.position.x + 10, y), Vector2(r.end.x - 10, y + 10), Vector2(r.end.x - 10, y + 26), Vector2(r.position.x + 10, y + 16)]), Color("#a1887f"))
	draw_string(_font, r.position + Vector2(0, r.size.y * 0.5 + 6), "OPEN ME", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 18, Color("#fffaf0"))


func _tape(r: Rect2) -> void:
	for k in 2:
		var y := r.position.y + 40 + k * 70
		draw_colored_polygon(PackedVector2Array([Vector2(r.position.x, y), Vector2(r.end.x, y + 30), Vector2(r.end.x, y + 44), Vector2(r.position.x, y + 14)]), Color("#ffd23f"))
