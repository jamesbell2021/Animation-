class_name ThreatMarkers
extends Control
## Chevrons at the edge of the screen pointing at creatures out of view: a raid on the
## camp while you're at the light, something landing on a beach behind the camera.
## Ones close together share a chevron with a count. The Eel and the Crab get a bigger,
## gold one. Fainter the further away. One view only: a split screen already shows both
## islands.

const INSET := 34.0
const BINS := 24
const NEAR := 10.0
const FAR := 45.0
const RED := Color(1.0, 0.36, 0.3)
const GOLD := Color(1.0, 0.78, 0.35)

var director: CameraDirector
## [screen point, angle, count, big, strength] per chevron, for drawing and tests.
var marks: Array = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	marks = _gather()
	queue_redraw()

func _gather() -> Array:
	var out: Array = []
	if not Run.active or (director != null and director.split_amount() > 0.0):
		return out
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return out
	var rect := get_viewport_rect()
	var mid := rect.size * 0.5
	var inner := rect.grow(-INSET)
	var bins := {}
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Enemy) or e.hp <= 0 or not e.visible:
			continue
		var at: Vector3 = (e as Node3D).global_position + Vector3(0.0, 1.0, 0.0)
		var behind := cam.is_position_behind(at)
		var sp := cam.unproject_position(at)
		if not behind and inner.has_point(sp):
			continue
		var d := sp - mid
		if behind:
			d = -d
		if d.length() < 1.0:
			continue
		var ang := d.angle()
		var b := int(floor((ang + PI) / TAU * BINS)) % BINS
		var dist := cam.global_position.distance_to(at)
		var big: bool = e is Eel or e is Crab
		if not bins.has(b):
			bins[b] = {"dir": Vector2.ZERO, "n": 0, "big": false, "dist": INF}
		bins[b]["dir"] += d.normalized()
		bins[b]["n"] += 1
		bins[b]["big"] = bins[b]["big"] or big
		bins[b]["dist"] = minf(bins[b]["dist"], dist)
	for b in bins:
		var g: Dictionary = bins[b]
		var dir: Vector2 = (g["dir"] as Vector2).normalized()
		out.append([_edge_point(mid, dir, inner), dir.angle(), g["n"], g["big"], 1.0 - 0.3 * smoothstep(NEAR + 30.0, FAR + 30.0, g["dist"])])
	return out

# Where a ray from the middle of the screen leaves the inset rectangle.
static func _edge_point(mid: Vector2, dir: Vector2, inner: Rect2) -> Vector2:
	var tx := INF
	var ty := INF
	if absf(dir.x) > 0.0001:
		tx = ((inner.end.x if dir.x > 0.0 else inner.position.x) - mid.x) / dir.x
	if absf(dir.y) > 0.0001:
		ty = ((inner.end.y if dir.y > 0.0 else inner.position.y) - mid.y) / dir.y
	return mid + dir * minf(tx, ty)

func _draw() -> void:
	var font := get_theme_default_font()
	var pulse := 0.8 + 0.2 * sin(Time.get_ticks_msec() * 0.008)
	for m in marks:
		var p: Vector2 = m[0]
		var a: float = m[1]
		var big: bool = m[3]
		var s := (34.0 if big else 26.0) * pulse
		var col: Color = GOLD if big else RED
		col.a = float(m[4])
		var fwd := Vector2.from_angle(a)
		var side := fwd.orthogonal()
		var tip := p + fwd * s
		var pts := PackedVector2Array([tip, p - fwd * s * 0.5 + side * s * 0.75, p - fwd * s * 0.1, p - fwd * s * 0.5 - side * s * 0.75])
		draw_colored_polygon(pts, Color(0, 0, 0, 0.55 * col.a))
		var inner_pts := PackedVector2Array()
		for q in pts:
			inner_pts.append(p + (q - p) * 0.8)
		draw_colored_polygon(inner_pts, col)
		if int(m[2]) > 1 and font != null:
			var text := str(m[2])
			var at := p - fwd * (s + 16.0) + Vector2(-6.0, 8.0)
			draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 5, Color(0, 0, 0, col.a))
			draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, col)
