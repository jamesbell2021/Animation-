class_name Ladder
extends Node3D
## A keepers' ladder down a crag wall. Creatures can't climb it: it isn't in their
## routes. Two ends, each an interactable; using one carries the keeper to the other.

const RUNG_EVERY := 0.32
const WOOD := Color(0.42, 0.31, 0.2)
const DOWN_TIME := 0.8
const UP_TIME := 1.3

var top: Vector3
var bottom: Vector3
var wall_top: Vector3
var wall_foot: Vector3

func _init(p_top: Vector3, p_bottom: Vector3, p_wall_top: Vector3, p_wall_foot: Vector3) -> void:
	top = p_top
	bottom = p_bottom
	wall_top = p_wall_top
	wall_foot = p_wall_foot

func _ready() -> void:
	_build()
	_end(top, bottom, "[E] Climb down", DOWN_TIME)
	_end(bottom, top, "[E] Climb up", UP_TIME)

func _end(at: Vector3, to: Vector3, prompt: String, time: float) -> void:
	var e := LadderEnd.new()
	e.prompt = prompt
	e.to = to
	e.time = time
	add_child(e)
	e.global_position = at

func _build() -> void:
	var dir := wall_foot - wall_top
	var length := dir.length()
	var side := dir.cross(Vector3.UP).normalized() * 0.28
	var mat := Look.flat_mat(WOOD, 0.9)
	for s in [-1.0, 1.0]:
		var rail := Geo.box(self, Vector3(0.07, 0.07, length + 0.5), Color.WHITE, Vector3.ZERO)
		rail.material_override = mat
		var mid: Vector3 = (wall_top + wall_foot) * 0.5 + side * s
		rail.global_position = mid
		rail.look_at_from_position(mid, wall_foot + side * s, Vector3.UP)
	var rungs := int(length / RUNG_EVERY)
	for i in rungs:
		var p := wall_top.lerp(wall_foot, (float(i) + 0.5) / float(rungs))
		var rung := Geo.box(self, Vector3(0.6, 0.05, 0.05), Color.WHITE, Vector3.ZERO)
		rung.material_override = mat
		rung.global_position = p
		rung.look_at_from_position(p, p + dir.normalized().cross(Vector3.UP), Vector3.UP)
