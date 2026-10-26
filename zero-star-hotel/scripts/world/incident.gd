class_name Incident
extends Node2D
## A problem that needs sorting: a rave, a fight, vandalism, a thief, someone flailing in the
## pool or a sunlounger war. Shown as a big pulsing bubble with a fuse ring; tap it to send the
## manager, or let staff handle it. If the fuse runs out, the consequences land (see
## HotelWorld.incident_failed).

const FUSES := {"music": 26.0, "fight": 15.0, "vandal": 12.0, "theft": 20.0, "pool": 11.0, "lounger": 16.0}
const COLORS := {"music": Color("#8e24aa"), "fight": Color("#e53935"), "vandal": Color("#ff6f00"),
	"theft": Color("#37474f"), "pool": Color("#0288d1"), "lounger": Color("#ec407a")}
const WORK_TIME := {"music": 1.6, "fight": 2.0, "vandal": 1.6, "theft": 0.8, "pool": 1.4, "lounger": 1.8}

var world: Node
var kind := "fight"
var room := -1
var guests: Array = []          # Guests involved
var thief: Node2D
var fuse := 15.0
var max_fuse := 15.0
var claimed_by: Node2D          # whoever is on the way
var working := false
var done := false
var anchor := Vector2.ZERO
var _t := 0.0


func setup(w: Node, k: String, at: Vector2) -> void:
	world = w
	kind = k
	max_fuse = float(FUSES.get(k, 15.0))
	fuse = max_fuse
	anchor = at
	position = at + Vector2(0, -150)
	z_index = 40
	z_as_relative = false


## Where a helper should stand to deal with it.
func work_spot() -> Vector2:
	match kind:
		"theft":
			return thief.position if thief and is_instance_valid(thief) else anchor
		"pool":
			var g: Node2D = guests[0] if not guests.is_empty() and is_instance_valid(guests[0]) else null
			var x := g.position.x if g else anchor.x
			var edge := HotelLayout.POOL_X0 + 6.0 if x - HotelLayout.POOL_X0 < HotelLayout.POOL_X1 - x else HotelLayout.POOL_X1 - 6.0
			return Vector2(edge, HotelLayout.GROUND_Y)
		"music", "vandal":
			return HotelLayout.room_door(room)
	return anchor + Vector2(-30, 0)


func work_time() -> float:
	return float(WORK_TIME.get(kind, 1.5))


func _process(delta: float) -> void:
	if done:
		return
	_t += delta
	if kind == "theft" and thief and is_instance_valid(thief):
		anchor = thief.position
	elif kind == "pool" and not guests.is_empty() and is_instance_valid(guests[0]):
		anchor = guests[0].position
	position = position.lerp(anchor + Vector2(0, -150 + sin(_t * 4.0) * 6.0), clampf(delta * 10.0, 0.0, 1.0))
	if not working:
		fuse -= delta
		if fuse <= 0.0:
			done = true
			world.incident_failed(self)
			return
	var cam := get_viewport().get_canvas_transform().get_scale().x
	scale = Vector2.ONE * clampf(0.85 / maxf(cam, 0.1), 0.8, 1.8)
	queue_redraw()


func hit_test(world_pos: Vector2) -> bool:
	return world_pos.distance_to(position) < 46.0 * scale.x


func _draw() -> void:
	var col: Color = COLORS.get(kind, Color.RED)
	var pulse := 1.0 + 0.08 * sin(_t * 8.0) * (1.0 if fuse < max_fuse * 0.35 else 0.4)
	var r := 30.0 * pulse
	draw_colored_polygon(PackedVector2Array([Vector2(-10, r - 4), Vector2(10, r - 4), Vector2(0, r + 16)]), Color(0.17, 0.11, 0.09))
	draw_circle(Vector2.ZERO, r + 4, Color(0.17, 0.11, 0.09))
	draw_circle(Vector2.ZERO, r, col)
	# Fuse ring: how long before it all goes wrong.
	var f := clampf(fuse / max_fuse, 0.0, 1.0)
	draw_arc(Vector2.ZERO, r + 9, -PI * 0.5, -PI * 0.5 + TAU * f, 32, Color("#ffd23f") if f > 0.35 else Color("#ff1744"), 6.0, true)
	if claimed_by:
		draw_arc(Vector2.ZERO, r + 16, 0, TAU, 32, Color(1, 1, 1, 0.8), 3.0, true)
	_draw_icon()


func _draw_icon() -> void:
	var w := Color.WHITE
	match kind:
		"music":
			draw_circle(Vector2(-8, 10), 7, w)
			draw_circle(Vector2(10, 6), 7, w)
			draw_line(Vector2(-2, 10), Vector2(-2, -14), w, 4.0)
			draw_line(Vector2(16, 6), Vector2(16, -18), w, 4.0)
			draw_line(Vector2(-2, -14), Vector2(16, -18), w, 5.0)
		"fight":
			draw_circle(Vector2(0, 0), 13, w)
			for k in 4:
				draw_line(Vector2(-10 + k * 7, -12), Vector2(-10 + k * 7, -2), Color(0.17, 0.11, 0.09), 2.0)
			for k in 6:
				var a := TAU * k / 6.0 + _t
				draw_line(Vector2.from_angle(a) * 18, Vector2.from_angle(a) * 24, w, 3.0)
		"vandal":
			draw_rect(Rect2(-14, -10, 28, 20), w)
			draw_polyline(PackedVector2Array([Vector2(-10, -6), Vector2(0, 2), Vector2(-4, 8), Vector2(12, -4)]), Color(0.17, 0.11, 0.09), 3.0)
		"theft":
			ItemArt.draw_item(self, "swag", Vector2.ZERO, 34.0)
		"pool":
			ItemArt.draw_item(self, "lifebuoy", Vector2.ZERO, 36.0)
		"lounger":
			ItemArt.draw_item(self, "towel", Vector2.ZERO, 34.0)
