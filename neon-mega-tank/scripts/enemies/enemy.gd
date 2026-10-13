class_name Enemy
extends CharacterBody3D
## Shared enemy behaviour: health, hit flash, death, line of sight and simple obstacle steering.
## On LAN clients enemies are "puppets": no AI, they just follow the host's snapshots.

const STEER_ANGLES := [0.0, 0.7, -0.7, 1.4, -1.4, 2.1, -2.1]

var hp := 10.0
var max_hp := 10.0
var dead := false
var score_value := 10
var color := G.ENEMY_COLOR
var meshes: Array[MeshInstance3D] = []
var net_id := 0
## Type name used for replication ("rifle", "rpg", "tank", ...).
var kind := ""
var puppet := false

var _net_pos := Vector3.ZERO
var _net_yaw := 0.0
var _net_aux := 0.0
var _net_aiming := false

var _steer_side := 1.0
var _steer_t := 0.0
var _steer_dir := Vector3.ZERO


func setup_enemy() -> void:
	collision_layer = G.LAYER_ENEMY
	collision_mask = G.LAYER_TERRAIN | G.LAYER_PLAYER | G.LAYER_ENEMY
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	add_to_group("enemies")
	if puppet:
		collision_mask = 0
		_net_pos = position
	else:
		net_id = G.next_net_id()


# --- Replication -----------------------------------------------------------------------------

func net_state() -> Array:
	return [net_id, kind, global_position.x, global_position.z, facing_yaw(), aux_yaw(), is_aiming(),
		hp / maxf(max_hp, 1.0)]


func apply_net(s: Array) -> void:
	_net_pos = Vector3(s[2], 0.0, s[3])
	_net_yaw = s[4]
	_net_aux = s[5]
	_net_aiming = s[6]
	hp = float(s[7]) * max_hp


## Client: glide toward the latest snapshot and animate. Returns the movement speed.
func puppet_update(delta: float) -> float:
	var prev := global_position
	global_position = global_position.lerp(_net_pos, minf(1.0, delta * 12.0))
	return (global_position - prev).length() / maxf(delta, 0.0001)


## Facing and secondary yaw (turret / body) sent to clients; overridden per enemy type.
func facing_yaw() -> float:
	return rotation.y


func aux_yaw() -> float:
	return 0.0


func part(parent: Node, size: Vector3, pos: Vector3, energy := 2.6) -> MeshInstance3D:
	var m := G.neon_box(parent, size, pos, color, energy)
	meshes.append(m)
	return m


func take_damage(amount: float, _pos: Vector3, team: int) -> void:
	if dead or team == G.Team.ENEMY or puppet:
		return
	hp -= amount
	G.flash(meshes, 1.0)
	if hp <= 0.0:
		die()


## Scales health with the current difficulty; call at the end of a subclass _ready().
func apply_difficulty() -> void:
	max_hp *= G.difficulty
	hp = max_hp


## Lines this enemy may cry out when it dies.
func death_lines() -> Array:
	return VoiceLines.SOLDIER_DEATH


func die() -> void:
	if dead:
		return
	dead = true
	remove_from_group("enemies")
	G.add_score(score_value)
	if randf() < 0.75:
		G.shout(global_position, death_lines().pick_random(), color)
	G.sparks(global_position + Vector3(0, 1, 0), color, 16, 7.0, 0.8)
	G.ring(global_position, color, 1.6, 0.35)
	queue_free()


## Is something telegraphing an attack? Used by the HUD threat arrows.
func is_aiming() -> bool:
	return _net_aiming


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
