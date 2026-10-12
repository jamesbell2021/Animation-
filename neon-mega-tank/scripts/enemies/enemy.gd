class_name Enemy
extends CharacterBody3D
## Shared enemy behaviour: health, hit flash, death, line of sight and simple obstacle steering.

const STEER_ANGLES := [0.0, 0.7, -0.7, 1.4, -1.4, 2.1, -2.1]

var hp := 10.0
var max_hp := 10.0
var dead := false
var score_value := 10
var color := G.ENEMY_COLOR
var meshes: Array[MeshInstance3D] = []

var _steer_side := 1.0
var _steer_t := 0.0
var _steer_dir := Vector3.ZERO


func setup_enemy() -> void:
	collision_layer = G.LAYER_ENEMY
	collision_mask = G.LAYER_TERRAIN | G.LAYER_PLAYER | G.LAYER_ENEMY
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	add_to_group("enemies")


func part(parent: Node, size: Vector3, pos: Vector3, energy := 2.6) -> MeshInstance3D:
	var m := G.neon_box(parent, size, pos, color, energy)
	meshes.append(m)
	return m


func take_damage(amount: float, _pos: Vector3, team: int) -> void:
	if dead or team == G.Team.ENEMY:
		return
	hp -= amount
	G.flash(meshes, 1.0)
	if hp <= 0.0:
		die()


func die() -> void:
	if dead:
		return
	dead = true
	remove_from_group("enemies")
	G.add_score(score_value)
	G.sparks(global_position + Vector3(0, 1, 0), color, 16, 7.0, 0.8)
	G.ring(global_position, color, 1.6, 0.35)
	queue_free()


## Is something telegraphing an attack? Used by the HUD threat arrows.
func is_aiming() -> bool:
	return false


func has_line_of_sight(target: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.0, 0),
			target + Vector3(0, 1.0, 0), G.LAYER_TERRAIN)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Picks the closest free direction to `desired`, re-evaluated a few times per second.
func steer(desired: Vector3, delta: float) -> Vector3:
	_steer_t -= delta
	if _steer_t > 0.0 and _steer_dir.dot(desired) > 0.0:
		return _steer_dir
	_steer_t = 0.2
	for a in STEER_ANGLES:
		var d := desired.rotated(Vector3.UP, a * _steer_side)
		if not test_move(global_transform, d * 1.0):
			_steer_dir = d
			return d
	_steer_side = -_steer_side
	_steer_dir = Vector3.ZERO
	return Vector3.ZERO
