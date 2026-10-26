class_name Arrow
extends Node3D
## An arrow from a keeper's longbow: flies fast and nearly flat where it was aimed,
## and sticks in the first creature it meets (or the ground, or is lost to the sea).

const SPEED := 34.0
const RANGE := 26.0
const HIT_R := 0.5
const DROP := 2.5

var shooter: Node
var from := Vector3.ZERO
var dir := Vector3.FORWARD
var damage := 20
var speed := SPEED
var _flown := 0.0
var _fall := 0.0
var _stuck := -1.0

func _ready() -> void:
	global_position = from
	var shaft := Geo.box(self, Vector3(0.025, 0.025, 0.75), Color.WHITE, Vector3.ZERO)
	shaft.material_override = Look.flat_mat(Color(0.6, 0.5, 0.34))
	var head := Geo.box(self, Vector3(0.05, 0.02, 0.09), Color.WHITE, Vector3(0.0, 0.0, -0.4))
	head.material_override = Look.flat_mat(Color(0.25, 0.25, 0.27), 0.4)
	for sx in [-1.0, 1.0]:
		var fletch := Geo.box(self, Vector3(0.005, 0.07, 0.12), Color.WHITE, Vector3(sx * 0.02, 0.0, 0.34))
		fletch.material_override = Look.flat_mat(Color(0.85, 0.85, 0.8))
	_face(dir)

func _face(d: Vector3) -> void:
	if d.length() > 0.001:
		look_at(global_position + d, Vector3.UP if absf(d.normalized().y) < 0.99 else Vector3.RIGHT)

func _physics_process(delta: float) -> void:
	if _stuck >= 0.0:
		_stuck += delta
		if _stuck > 6.0:
			queue_free()
		return
	var step := speed * delta
	_fall += DROP * delta
	var move := dir * step + Vector3(0.0, -_fall * delta, 0.0)
	var a := global_position
	var b := a + move
	# The first living creature whose body this stretch of flight passes through.
	for e in get_tree().get_nodes_in_group("enemies"):
		if not Arsenal._live(e):
			continue
		var c: Vector3 = e.global_position
		var ab := b - a
		var t := clampf((c - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var p := a + ab * t
		if Vector2(p.x - c.x, p.z - c.z).length() <= HIT_R and p.y > c.y - 0.2 and p.y < c.y + 2.2:
			Arsenal.strike(e, damage, Vector3(dir.x, 0.0, dir.z).normalized(), shooter, "arrow")
			Audio.sfx("arrow_hit", p, -2.0, 0.15)
			queue_free()
			return
	global_position = b
	_face(move)
	_flown += step
	var g := Terrain.height_at(b.x, b.z)
	if b.y <= Terrain.SEA_LEVEL and g < Terrain.SEA_LEVEL:
		FX.splash(get_parent(), Vector3(b.x, Terrain.SEA_LEVEL, b.z), 0.2)
		queue_free()
	elif b.y <= g + 0.05 or _flown > RANGE:
		# Into the ground, quivering.
		global_position.y = maxf(b.y, g + 0.1)
		_stuck = 0.0
