class_name CameraRig
extends Camera2D
## Touch-first camera and input router for the beach.
##   - One finger drag pans; pinch zooms (mouse: drag with any button, wheel zooms).
##   - A short tap (no drag) emits tapped(world_pos) for the game to interpret.
##   - Can follow a target (during police chases).
## Emulated mouse events from touch are ignored so nothing is handled twice.

signal tapped(world_pos: Vector2)

const TAP_SLOP := 18.0
const MIN_ZOOM := 0.55
const MAX_ZOOM := 1.5

var follow: Node2D
var world_rect := Rect2(0, -120, 3200, 1020)

var _touches := {}             # index -> position
var _drag_dist := 0.0
var _pinch_start := 0.0
var _zoom_start := 1.0
var _mouse_down := false


func _ready() -> void:
	make_current()
	_apply_limits()
	get_viewport().size_changed.connect(_apply_limits)


func _apply_limits() -> void:
	# Never zoom out further than the whole beach fits.
	var vp := get_viewport_rect().size
	var min_fit := maxf(vp.x / world_rect.size.x, vp.y / world_rect.size.y)
	var z := clampf(zoom.x, maxf(MIN_ZOOM, min_fit), MAX_ZOOM)
	zoom = Vector2(z, z)
	_clamp_position()


func _process(delta: float) -> void:
	if follow and is_instance_valid(follow):
		position = position.lerp(follow.position + Vector2(0, -60), clampf(delta * 5.0, 0.0, 1.0))
		_clamp_position()


func _clamp_position() -> void:
	var half := get_viewport_rect().size / zoom * 0.5
	position.x = clampf(position.x, world_rect.position.x + half.x, world_rect.end.x - half.x) if half.x * 2.0 < world_rect.size.x else world_rect.get_center().x
	position.y = clampf(position.y, world_rect.position.y + half.y, world_rect.end.y - half.y) if half.y * 2.0 < world_rect.size.y else world_rect.get_center().y


func set_zoom_level(z: float, focus_screen := Vector2(-1, -1)) -> void:
	var vp := get_viewport_rect().size
	var min_fit := maxf(vp.x / world_rect.size.x, vp.y / world_rect.size.y)
	z = clampf(z, maxf(MIN_ZOOM, min_fit), MAX_ZOOM)
	if focus_screen.x >= 0.0:
		var before := screen_to_world(focus_screen)
		zoom = Vector2(z, z)
		var after := screen_to_world(focus_screen)
		position += before - after
	else:
		zoom = Vector2(z, z)
	_clamp_position()


func screen_to_world(p: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * p


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_on_drag(event)
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		_on_mouse_button(event)
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		if _mouse_down:
			_pan(event.relative)
			_drag_dist += event.relative.length()


func _on_touch(e: InputEventScreenTouch) -> void:
	if e.pressed:
		_touches[e.index] = e.position
		if _touches.size() == 1:
			_drag_dist = 0.0
		elif _touches.size() == 2:
			_pinch_start = _pinch_distance()
			_zoom_start = zoom.x
			_drag_dist = 999.0  # a pinch is never a tap
	else:
		if _touches.size() == 1 and _drag_dist < TAP_SLOP and _touches.has(e.index):
			tapped.emit(screen_to_world(e.position))
		_touches.erase(e.index)
	get_viewport().set_input_as_handled()


func _on_drag(e: InputEventScreenDrag) -> void:
	_touches[e.index] = e.position
	if _touches.size() >= 2:
		var d := _pinch_distance()
		if _pinch_start > 1.0:
			var mid := Vector2.ZERO
			for p in _touches.values():
				mid += p
			set_zoom_level(_zoom_start * d / _pinch_start, mid / _touches.size())
	else:
		_drag_dist += e.relative.length()
		if _drag_dist >= TAP_SLOP:
			_pan(e.relative)
	get_viewport().set_input_as_handled()


func _on_mouse_button(e: InputEventMouseButton) -> void:
	match e.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if e.pressed:
				set_zoom_level(zoom.x * 1.1, e.position)
		MOUSE_BUTTON_WHEEL_DOWN:
			if e.pressed:
				set_zoom_level(zoom.x / 1.1, e.position)
		MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
			if e.pressed:
				_mouse_down = true
				_drag_dist = 0.0
			else:
				_mouse_down = false
				if _drag_dist < TAP_SLOP and e.button_index == MOUSE_BUTTON_LEFT:
					tapped.emit(screen_to_world(e.position))
	get_viewport().set_input_as_handled()


func _pan(screen_delta: Vector2) -> void:
	if follow:
		return
	position -= screen_delta / zoom
	_clamp_position()


func _pinch_distance() -> float:
	var pts := _touches.values()
	if pts.size() < 2:
		return 0.0
	return (pts[0] as Vector2).distance_to(pts[1])
