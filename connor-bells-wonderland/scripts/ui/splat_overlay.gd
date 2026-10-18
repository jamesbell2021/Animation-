class_name SplatOverlay
extends Control
## Custard all over the screen (hit by a pie) and quick colour flashes
## (explosions, zaps). Draws on top of the race; ignores the mouse.

var _blobs: Array = []
var _splat_left: float = 0.0
var _splat_total: float = 1.0
var _flash_colour: Color = Color(1.0, 1.0, 1.0, 0.0)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func splat(seconds: float) -> void:
	_splat_total = seconds
	_splat_left = seconds
	_blobs.clear()
	var area := size if size.x > 0.0 else Vector2(1280.0, 720.0)
	for i in range(9):
		var centre := Vector2(randf_range(0.1, 0.9) * area.x, randf_range(0.1, 0.85) * area.y)
		var radius := randf_range(0.07, 0.16) * area.y
		var drips: Array = []
		for d in range(randi_range(2, 4)):
			drips.append([randf_range(-0.7, 0.7), randf_range(0.6, 1.6)])
		_blobs.append([centre, radius, drips])
	queue_redraw()


func flash(colour: Color, strength: float = 0.5) -> void:
	_flash_colour = Color(colour.r, colour.g, colour.b, maxf(_flash_colour.a, strength))
	queue_redraw()


func _process(delta: float) -> void:
	var dirty := false
	if _splat_left > 0.0:
		_splat_left = maxf(_splat_left - delta, 0.0)
		dirty = true
	if _flash_colour.a > 0.0:
		_flash_colour.a = maxf(_flash_colour.a - delta * 2.5, 0.0)
		dirty = true
	if dirty:
		queue_redraw()


func _draw() -> void:
	if _flash_colour.a > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), _flash_colour)
	if _splat_left <= 0.0:
		return
	var alpha := clampf(_splat_left / (_splat_total * 0.4), 0.0, 1.0) * 0.93
	var slide := (1.0 - _splat_left / _splat_total) * 40.0
	var custard := Color(1.0, 0.86, 0.35, alpha)
	var crust := Color(0.85, 0.65, 0.2, alpha)
	for blob in _blobs:
		var centre: Vector2 = blob[0] + Vector2(0.0, slide)
		var radius: float = blob[1]
		draw_circle(centre, radius * 1.08, crust)
		draw_circle(centre, radius, custard)
		draw_circle(centre + Vector2(-radius * 0.3, -radius * 0.3), radius * 0.25, Color(1.0, 1.0, 0.9, alpha * 0.8))
		for drip: Array in blob[2]:
			var x: float = centre.x + float(drip[0]) * radius
			var length: float = radius * float(drip[1]) + slide
			draw_rect(Rect2(x - radius * 0.1, centre.y, radius * 0.2, length), custard)
			draw_circle(Vector2(x, centre.y + length), radius * 0.12, custard)
