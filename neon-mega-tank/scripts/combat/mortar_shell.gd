class_name MortarShell
extends Node3D
## A mortar round lobbed high over the buildings. A red target ring closes in on the ground where
## it will land, so the driver has time to get out from under it (or the mechanic raises the
## shield). On the host it explodes on arrival; on LAN phones it is visual only.

const APEX := 16.0

var from := Vector3.ZERO
var to := Vector3.ZERO
var flight := 2.0
var damage := 8.0
var color := Color(1.0, 0.45, 0.2)
var visual_only := false

var _t := 0.0
var _shell: MeshInstance3D
var _marker: Node3D
var _marker_parts: Array[MeshInstance3D] = []
var _whistled := false


func setup(start: Vector3, target: Vector3, time: float, tint: Color) -> void:
	from = start
	to = Vector3(target.x, 0.0, target.z)
	flight = time
	color = tint


func _ready() -> void:
	add_to_group("mortar_marks")
	_shell = G.neon_box(self, Vector3(0.35, 0.35, 0.7), Vector3.ZERO, color.lerp(Color.WHITE, 0.3), 5.0)
	_marker = Node3D.new()
	_marker.top_level = true
	add_child(_marker)
	_marker.global_position = to
	for i in 8:
		var ang := i * TAU / 8.0
		var seg := G.neon_box(_marker, Vector3(1.2, 0.05, 0.14), Vector3(sin(ang), 0.06, cos(ang)) * 3.0,
				Color(1, 0.15, 0.1), 3.0, false, true)
		seg.rotation.y = ang + PI * 0.5
		_marker_parts.append(seg)
	for a in [45.0, -45.0]:
		var bar := G.neon_box(_marker, Vector3(1.4, 0.05, 0.16), Vector3(0, 0.06, 0), Color(1, 0.15, 0.1), 3.0, false, true)
		bar.rotation_degrees.y = a
		_marker_parts.append(bar)
	global_position = from


## Seconds until it lands (the AI driver dodges with this).
func time_left() -> float:
	return flight - _t


func _process(delta: float) -> void:
	_t += delta
	var k := clampf(_t / flight, 0.0, 1.0)
	var p := from.lerp(to, k)
	p.y = lerpf(from.y, 0.4, k) + 4.0 * APEX * k * (1.0 - k)
	var next_k := clampf((_t + 0.05) / flight, 0.0, 1.0)
	var next := from.lerp(to, next_k)
	next.y = lerpf(from.y, 0.4, next_k) + 4.0 * APEX * next_k * (1.0 - next_k)
	global_position = p
	if next.distance_to(p) > 0.01:
		look_at(next, Vector3.UP if absf((next - p).normalized().y) < 0.99 else Vector3.RIGHT)
	# The ring closes in and blinks faster as the round comes down.
	var blink := 2.0 + 4.0 * absf(sin(_t * lerpf(6.0, 28.0, k)))
	_marker.scale = Vector3.ONE * lerpf(1.25, 0.7, k)
	_marker.rotation.y = _t * 1.5
	for m in _marker_parts:
		G.set_neon(m, Color(1, 0.15, 0.1), blink)
	if not _whistled and k > 0.55:
		_whistled = true
		if not visual_only:
			G.sfx("whistle", -8.0, randf_range(0.9, 1.1))
	if k >= 1.0:
		if not visual_only:
			G.explode(to, 3.4, damage, G.Team.ENEMY, color)
		queue_free()
