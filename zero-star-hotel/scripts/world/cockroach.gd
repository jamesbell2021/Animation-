class_name Cockroach
extends Node2D
## A cockroach scuttling round a room. Tap it to squash it (very satisfying). The room's
## roach count in Hotel is the truth; HotelWorld keeps one node per roach.

var room := 0
var _dir := Vector2.RIGHT
var _speed := 40.0
var _turn := 0.0
var _rect := Rect2()
var _t := 0.0
var _rng := RandomNumberGenerator.new()


func setup(i: int) -> void:
	room = i
	_rng.randomize()
	_rect = HotelLayout.room_rect(i).grow(-12.0)
	position = Vector2(_rng.randf_range(_rect.position.x, _rect.end.x), _rng.randf_range(_rect.position.y + 20.0, _rect.end.y - 4.0))
	_dir = Vector2.from_angle(_rng.randf() * TAU)
	_speed = _rng.randf_range(30.0, 60.0)
	z_index = 3


func _process(delta: float) -> void:
	_t += delta
	_turn -= delta
	if _turn <= 0.0:
		_turn = _rng.randf_range(0.4, 1.4)
		_dir = _dir.rotated(_rng.randf_range(-1.6, 1.6))
		if _rng.randf() < 0.2:
			_speed = 0.0 if _speed > 0.0 else _rng.randf_range(30.0, 70.0)
	position += _dir * _speed * delta
	if position.x < _rect.position.x or position.x > _rect.end.x:
		_dir.x = -_dir.x
	if position.y < _rect.position.y + 10.0 or position.y > _rect.end.y - 2.0:
		_dir.y = -_dir.y
	position = position.clamp(_rect.position + Vector2(0, 10), _rect.end - Vector2(0, 2))
	rotation = _dir.angle()
	queue_redraw()


func hit_test(p: Vector2) -> bool:
	return p.distance_to(position) < 28.0


func _draw() -> void:
	var ink := Color(0.17, 0.11, 0.09)
	var wiggle := sin(_t * 30.0) * 2.0 if _speed > 0.0 else 0.0
	for k in 3:
		var x := -4.0 + k * 4.0
		draw_line(Vector2(x, 0), Vector2(x - 2, -7 + wiggle * (1 if k % 2 == 0 else -1)), ink, 1.5)
		draw_line(Vector2(x, 0), Vector2(x - 2, 7 - wiggle * (1 if k % 2 == 0 else -1)), ink, 1.5)
	draw_colored_polygon(VendorAvatar._ellipse(Vector2.ZERO, 9.0, 5.0, 12), Color("#5d3a1a"))
	draw_circle(Vector2(8, 0), 3.5, Color("#3e2412"))
	draw_line(Vector2(10, -1), Vector2(18, -7), ink, 1.2)
	draw_line(Vector2(10, 1), Vector2(18, 7), ink, 1.2)
	draw_line(Vector2(-6, 0), Vector2(6, 0), Color(1, 1, 1, 0.25), 1.5)
