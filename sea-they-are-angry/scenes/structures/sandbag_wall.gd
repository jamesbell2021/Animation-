class_name SandbagWall
extends Structure
## A low wall of sandbags thrown across a creature path at a defence post (Research:
## Sandbag walls). Creatures have to stop and batter through it, which holds them in the
## light; it can be patched, and when it's down the post is clear for another.

const LENGTH := 2.6
const HEIGHT := 0.9
const THICKNESS := 0.7
const HP := 160
const SACK := Color(0.62, 0.55, 0.4)

var length := LENGTH
var _sacks: Array[MeshInstance3D] = []
var _spill: Node3D
var _shape: CollisionShape3D
var _mat: StandardMaterial3D

func _init() -> void:
	id = "sandbags"
	max_hp = HP

func _ready() -> void:
	super._ready()
	add_to_group("barricades")

func _build() -> void:
	_mat = Look.flat_mat(SACK, 0.95)
	# Three courses, staggered like brickwork, each sack a squashed box.
	var rows := 3
	for r in rows:
		var n := 5 - r
		var w := LENGTH / float(n)
		for i in n:
			var x := -LENGTH * 0.5 + w * (float(i) + 0.5) + (0.0 if r % 2 == 0 else w * 0.08)
			var sack := Geo.box(self, Vector3(w * 0.96, HEIGHT / float(rows) * 0.95, THICKNESS * (1.0 - 0.15 * float(r))), Color.WHITE,
				Vector3(x, HEIGHT / float(rows) * (float(r) + 0.5), 0.0))
			sack.material_override = _mat
			sack.rotation.y = 0.05 * float((i * 7 + r * 3) % 5 - 2)
			_sacks.append(sack)
	# What's left when it's battered down: a few burst sacks and spilt sand.
	_spill = Node3D.new()
	add_child(_spill)
	for i in 4:
		var s := Geo.box(_spill, Vector3(0.55, 0.16, 0.5), Color.WHITE, Vector3(-0.9 + 0.6 * float(i), 0.08, 0.15 * float(i % 2)))
		s.material_override = _mat
		s.rotation.y = 0.4 * float(i - 1)
	_shape = Geo.box_shape(self, Vector3(LENGTH, HEIGHT, THICKNESS), Vector3(0.0, HEIGHT * 0.5, 0.0))

func _refresh() -> void:
	if _mat == null:
		return
	var standing := hp > 0
	var r := health_ratio()
	_spill.visible = not standing
	# Sacks split and slump as it's battered: the top course goes first.
	for i in _sacks.size():
		var keep := float(_sacks.size() - i) / float(_sacks.size())
		_sacks[i].visible = standing and r > 1.0 - keep * 1.05
	_mat.albedo_color = SACK.darkened(0.35 * (1.0 - r))
	_shape.set_deferred("disabled", not standing)

func _on_damaged() -> void:
	if is_inside_tree():
		FX.spray(get_parent(), global_position + Vector3(0.0, 0.6, 0.0), Vector3.UP, SACK.lightened(0.2))
		Audio.sfx("hit", global_position, -6.0, 0.15)

func repair_amount() -> int:
	return 60

func display_name() -> String:
	return "sandbag wall"

func smoke_point() -> Vector3:
	return Vector3.INF

func surface_distance(p: Vector3) -> float:
	var local := to_local(p)
	var dx := maxf(0.0, absf(local.x) - length * 0.5)
	var dz := maxf(0.0, absf(local.z) - THICKNESS * 0.5)
	return Vector2(dx, dz).length()
