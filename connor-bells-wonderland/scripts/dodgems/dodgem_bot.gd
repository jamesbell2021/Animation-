class_name DodgemBot
extends Node
## Dodgem Derby bot (host only). Picks a rival (preferring ones near the edge),
## swings round to hit them from the middle so they fly outwards, boosts into
## the ram, uses items when they'd help, and steers back from the edge itself.

var contestant: Contestant
var manager: DodgemsManager

## 0 Easy, 1 Medium, 2 Hard.
var difficulty: int = 1

var _target: Contestant
var _think: float = 0.0
var _hold_left: float = 0.0
var _item_wait: float = 0.0
var _wander: Vector3 = Vector3.ZERO


func setup(p_contestant: Contestant, p_manager: DodgemsManager, p_difficulty: int) -> void:
	contestant = p_contestant
	manager = p_manager
	difficulty = clampi(p_difficulty, 0, 2)
	contestant.is_local_player = false


func _physics_process(delta: float) -> void:
	if contestant == null or manager == null:
		return
	contestant.use_held = false
	if not manager.active or not manager.is_alive(str(contestant.name)) or not contestant.controls_enabled:
		contestant.move_direction = Vector3.ZERO
		return
	_think -= delta
	if _think <= 0.0:
		_think = [0.6, 0.35, 0.2][difficulty]
		_target = _pick_target()
		_wander = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * 0.25
	var me := _flat(contestant.global_position)
	var edge := manager.arena.outer_radius()
	var move := Vector3.ZERO
	# Keep away from the edge (looking a little ahead at where we're sliding to).
	var look: float = [0.25, 0.45, 0.6][difficulty]
	var ahead: Vector3 = me + _flat(contestant.velocity) * look
	# Mid-ram (target right in front) it only bails out at the very edge.
	var ramming := _target != null and _flat(_target.global_position - contestant.global_position).length() < 3.5
	var margin := 0.6 if ramming else 2.4
	var danger: bool = ahead.length() > edge - margin or me.length() > edge - 1.0
	if danger:
		move = -ahead.normalized()
	elif _target != null:
		var them := _flat(_target.global_position)
		var outward := them.normalized() if them.length() > 0.5 else -me.normalized()
		var behind := them - outward * 3.0
		var to_target := them - me
		var inside := (me - them).dot(outward) < -0.5
		if inside or to_target.length() < 3.0 or difficulty == 0:
			move = to_target.normalized()
			var facing := contestant.get_facing()
			if to_target.length() < 7.0 and facing.dot(move) > 0.9 and manager.boost_ready(str(contestant.name)) and randf() < [0.02, 0.06, 0.15][difficulty]:
				contestant.jump_requested = true
		else:
			move = (behind - me).normalized()
	move += _wander
	contestant.move_direction = move.limit_length(1.0)
	_use_items(delta, me, edge)


func _use_items(delta: float, me: Vector3, edge: float) -> void:
	var holder := contestant.get_node_or_null("ItemHolder") as ItemHolder
	if holder == null or holder.is_empty():
		_item_wait = randf_range(0.3, 1.2)
		return
	_item_wait -= delta
	if _item_wait > 0.0:
		return
	var dist := INF
	var ahead := false
	if _target != null:
		var off := _flat(_target.global_position) - me
		dist = off.length()
		ahead = off.normalized().dot(contestant.get_facing()) > 0.6
	var use := false
	match ItemKinds.get_def(holder.kind).get("mode", ""):
		"self":
			use = dist < 12.0
		"melee":
			use = dist < 3.0 and ahead
		"throw":
			use = dist < 9.0 and ahead
		"burst":
			use = dist < 4.5
		"trap":
			use = me.length() < edge - 3.0
		"launch":
			use = false
	if use:
		contestant.use_requested = true
		_item_wait = randf_range(0.6, 1.5)


func _pick_target() -> Contestant:
	var best: Contestant = null
	var best_score := INF
	var edge := manager.arena.outer_radius()
	for c in manager.alive_contestants():
		if c == contestant or manager.is_safe(str(c.name)):
			continue
		var d := contestant.global_position.distance_to(c.global_position)
		var near_edge := _flat(c.global_position).length() / maxf(edge, 1.0)
		var score := d - near_edge * 6.0
		if score < best_score:
			best_score = score
			best = c
	return best


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
