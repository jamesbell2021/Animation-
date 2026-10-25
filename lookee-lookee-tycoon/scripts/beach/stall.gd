class_name Stall
extends Node2D
## A pitch on the sand where tourists come to buy. The player's stall grows through six tiers
## (blanket, fold-out table, big table, table + parasol, gazebo, kiosk); workers and rivals
## use a blanket. Origin is the front edge on the ground; the seller stands just behind it.
##
## Tourists ask for a serving slot, walk to it, browse, and the Beach decides if they buy.

signal opened
signal closed

enum State { CLOSED, OPEN, PACKING }

var owner_kind := "player"     # "player", "worker" or "rival"
var owner_node: Node2D         # whoever has to be present for sales
var tier := 0
var state: State = State.CLOSED
var slots: Array = []          # tourist or null per serving position
var pack_progress := 0.0       # 0..1 while packing, drawn as a shrinking display

var _items: Array = []
var _font: Font


func _ready() -> void:
	_font = UITheme.bold_font()
	visible = false
	if owner_kind != "rival":
		Economy.stock_changed.connect(_on_stock_changed)


func is_open() -> bool:
	return state == State.OPEN


func open_at(pos: Vector2, new_tier: int) -> void:
	position = pos
	tier = new_tier
	state = State.OPEN
	pack_progress = 0.0
	slots.resize(slot_count())
	slots.fill(null)
	visible = true
	_refresh_items()
	scale = Vector2(0.2, 0.2)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	queue_redraw()
	opened.emit()


func begin_packing() -> void:
	if state == State.OPEN:
		state = State.PACKING
		pack_progress = 0.0


func set_pack_progress(p: float) -> void:
	pack_progress = clampf(p, 0.0, 1.0)
	queue_redraw()


func close() -> void:
	if state == State.CLOSED:
		return
	state = State.CLOSED
	_release_all()
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(0.1, 0.1), 0.15)
	tw.tween_callback(_hide_if_closed)
	closed.emit()


func _hide_if_closed() -> void:
	if state == State.CLOSED:
		visible = false
		scale = Vector2.ONE


## If the packing was interrupted (police pounced first), open again.
func cancel_packing() -> void:
	if state == State.PACKING:
		state = State.OPEN
		pack_progress = 0.0
		queue_redraw()


func slot_count() -> int:
	if owner_kind == "player":
		return Upgrades.stall_slots()
	return 1


func width() -> float:
	return [110.0, 120.0, 160.0, 160.0, 190.0, 200.0][clampi(tier, 0, 5)]


func vendor_spot() -> Vector2:
	return position + Vector2(0, -30)


func slot_position(i: int) -> Vector2:
	var n := slots.size()
	var spread := width() * 0.8
	var x := 0.0 if n <= 1 else lerpf(-spread * 0.5, spread * 0.5, float(i) / float(n - 1))
	return position + Vector2(x, 44.0 + (i % 2) * 10.0)


func attraction_radius() -> float:
	var r := Upgrades.stall_attraction() if owner_kind == "player" else 160.0
	return r * RandomEvents.mult("attraction")


func has_free_slot() -> bool:
	return is_open() and slots.has(null)


func request_slot(t: Node) -> int:
	if not is_open():
		return -1
	var existing := slots.find(t)
	if existing >= 0:
		return existing
	var i := slots.find(null)
	if i >= 0:
		slots[i] = t
	return i


func release_slot(t: Node) -> void:
	var i := slots.find(t)
	if i >= 0:
		slots[i] = null


func _release_all() -> void:
	for t in slots:
		if t and is_instance_valid(t) and t.has_method("stall_closed"):
			t.stall_closed()
	slots.fill(null)


func seller_present() -> bool:
	if owner_node == null or not is_instance_valid(owner_node):
		return false
	if owner_node.has_method("is_at_stall"):
		return owner_node.is_at_stall()
	return owner_node.position.distance_to(vendor_spot()) < 70.0


func hit_test(p: Vector2) -> bool:
	return visible and Rect2(position + Vector2(-width() * 0.5, -90), Vector2(width(), 110)).has_point(p)


func _on_stock_changed(_id: String, _count: int) -> void:
	if visible:
		_refresh_items()
		queue_redraw()


func _refresh_items() -> void:
	_items = Economy.stocked_ids() if owner_kind != "rival" else ["sunglasses", "magnet", "watch", "flamingo"]


# --- Drawing --------------------------------------------------------------------------------

const INK := Color(0.17, 0.11, 0.09)


func _draw() -> void:
	var w := width()
	var shown := 1.0 - pack_progress
	draw_colored_polygon(VendorAvatar._ellipse(Vector2(0, 2), w * 0.55, 10), Color(0, 0, 0, 0.18))
	if owner_kind != "player" or tier == 0:
		_draw_blanket(w, shown)
		return
	var top_y := -38.0
	var depth := 26.0
	# Parasol / canopy behind-and-above (drawn first only for the posts).
	if tier >= 4:
		for x: float in [-w * 0.5 + 6, w * 0.5 - 6]:
			draw_line(Vector2(x, 0), Vector2(x, -150), INK, 6.0)
			draw_line(Vector2(x, 0), Vector2(x, -150), Color.WHITE, 3.0)
	# Table top (a parallelogram for depth) and front cloth.
	var top := PackedVector2Array([Vector2(-w * 0.5, top_y), Vector2(w * 0.5, top_y), Vector2(w * 0.5 - 10, top_y - depth), Vector2(-w * 0.5 + 10, top_y - depth)])
	if tier >= 5:
		# Kiosk: a proper wooden booth.
		draw_rect(Rect2(-w * 0.5, -150, w, 150), Color("#8d6e63"))
		draw_rect(Rect2(-w * 0.5, -150, w, 150), INK, false, 3.0)
		draw_rect(Rect2(-w * 0.5 + 10, -140, w - 20, 90), Color("#5d4037"))
	_poly(top, Color("#c8a27a"))
	var cloth := PackedVector2Array([Vector2(-w * 0.5, top_y), Vector2(w * 0.5, top_y), Vector2(w * 0.5 - 4, -2), Vector2(-w * 0.5 + 4, -2)])
	_poly(cloth, Color("#1e88e5") if tier < 4 else Color("#e53935"))
	# Scalloped trim on the cloth.
	for i in int(w / 20.0):
		var x := -w * 0.5 + 10.0 + i * 20.0
		draw_circle(Vector2(x, top_y + 3), 6.0, Color("#ffd23f"))
	# Fairy lights from the Flashy Display upgrade.
	if Upgrades.level("display") >= 1:
		for i in int(w / 14.0):
			var x := -w * 0.5 + 7.0 + i * 14.0
			var col: Color = [Color("#ff5252"), Color("#ffeb3b"), Color("#69f0ae"), Color("#40c4ff")][i % 4]
			draw_circle(Vector2(x, top_y + 14 + sin(i * 1.3) * 3.0), 3.2, col)
	# Goods on the table.
	_draw_goods(Vector2(0, top_y - depth * 0.5), w - 30.0, depth, shown)
	# Legs for plain tables.
	if tier <= 2:
		for x: float in [-w * 0.5 + 8, w * 0.5 - 8]:
			draw_line(Vector2(x, -2), Vector2(x, 2), INK, 4.0)
	# Parasol for tier 3 (or any table with the Shady Parasol upgrade).
	if tier == 3 or (tier < 4 and Upgrades.level("parasol") >= 1 and tier >= 1):
		draw_line(Vector2(-w * 0.5 + 16, top_y), Vector2(-w * 0.5 + 16, -168), INK, 5.0)
		draw_line(Vector2(-w * 0.5 + 16, top_y), Vector2(-w * 0.5 + 16, -168), Color.WHITE, 3.0)
		var c := Vector2(-w * 0.5 + 16, -168)
		var canopy := VendorAvatar._ellipse(c, 90, 34, 16, PI, TAU)
		canopy.append(c + Vector2(90, 8))
		canopy.append(c + Vector2(-90, 8))
		_poly(canopy, Color("#ff7043"))
		for k in 4:
			var a := PI + PI * (k * 2 + 1) / 8.0
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -34), c + Vector2(cos(a), sin(a)) * Vector2(90, 34), c + Vector2(cos(a + PI / 8), sin(a + PI / 8)) * Vector2(90, 34)]), Color("#fff8e1"))
	# Gazebo canopy with a sign.
	if tier >= 4:
		var y := -150.0
		var roof := PackedVector2Array([Vector2(-w * 0.5 - 14, y + 10), Vector2(w * 0.5 + 14, y + 10), Vector2(w * 0.5 - 10, y - 30), Vector2(-w * 0.5 + 10, y - 30)])
		_poly(roof, Color("#fafafa") if tier == 4 else Color("#ffd23f"))
		for i in int((w + 28) / 22.0):
			var x := -w * 0.5 - 14 + 11 + i * 22.0
			draw_circle(Vector2(x, y + 12), 10.0, Color("#e53935") if i % 2 == 0 else Color("#fafafa"))
		var sign_text := "VERY GOOD VERY NICE" if tier == 4 else "LOOKEE LOOKEE"
		draw_string(_font, Vector2(-w * 0.5, y - 6), sign_text, HORIZONTAL_ALIGNMENT_CENTER, w, 15, INK)
	# Cardboard sign from Flashy Display 2.
	if Upgrades.level("display") >= 2:
		var p := Vector2(w * 0.5 + 6, -6)
		_poly(PackedVector2Array([p + Vector2(0, 0), p + Vector2(46, 0), p + Vector2(42, -40), p + Vector2(4, -40)]), Color("#d7b98e"))
		draw_string(_font, p + Vector2(4, -26), "VERY", HORIZONTAL_ALIGNMENT_CENTER, 38, 11, Color("#c62828"))
		draw_string(_font, p + Vector2(4, -12), "NICE!", HORIZONTAL_ALIGNMENT_CENTER, 38, 11, Color("#c62828"))


func _draw_blanket(w: float, shown: float) -> void:
	var sheet := PackedVector2Array([Vector2(-w * 0.5, 0), Vector2(w * 0.5, 0), Vector2(w * 0.5 - 14, -40), Vector2(-w * 0.5 + 14, -40)])
	# While packing, the corners pull together like the real rope-blanket trick.
	if pack_progress > 0.0:
		var k := pack_progress * 0.85
		for i in sheet.size():
			sheet[i] = sheet[i].lerp(Vector2(0, -20), k)
	var col := Color("#f5f5f5") if owner_kind != "rival" else Color("#9575cd")
	_poly(sheet, col)
	draw_polyline(PackedVector2Array([sheet[0], sheet[2]]), Color(0, 0, 0, 0.08), 2.0)
	# Rope corners.
	for p in sheet:
		draw_circle(p, 3.0, Color("#8d6e63"))
	if pack_progress < 0.6:
		_draw_goods(Vector2(0, -20), (w - 40.0) * (1.0 - pack_progress), 26.0, shown)


func _draw_goods(center: Vector2, span: float, depth: float, shown: float) -> void:
	if _items.is_empty() or shown <= 0.3:
		return
	var per_row := clampi(int(span / 24.0), 2, 6)
	var count := mini(_items.size() * 2, per_row * 2)
	for i in count:
		var row := i / per_row
		var col := i % per_row
		var x := lerpf(-span * 0.5, span * 0.5, (col + 0.5) / per_row)
		var y := center.y - depth * 0.25 + row * depth * 0.5
		var id: String = _items[i % _items.size()]
		ItemArt.draw_item(self, id, Vector2(x, y), 20.0 * shown)


func _poly(pts: PackedVector2Array, col: Color) -> void:
	draw_colored_polygon(pts, col)
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, INK, 2.5, true)
