class_name BotInput
extends PlayerInput
## AI crew member. Pretends to be a controller: it produces the same move/action/interact signals
## a player would, so bots walk the deck, board stations and patch breaches exactly like people.
## Main's bot director hands each bot a task; this class works out how to carry it out.

const ARRIVE := 0.35

## Task from the director: {"kind": "station", "id": "cannon"} / {"kind": "fix", "breach": Breach}
## or {} for idle.
var task := {}
var crew: Crew

var _drive_side := 1.0
var _drive_side_t := 0.0
var _stuck_t := 0.0
var _unstick_t := 0.0
var _wander := Vector3.ZERO
var _aim_error := 0.0
var _aim_error_t := 0.0
## Repair gauge: how close to the zone centre this bot waits for before tapping (fraction of the
## zone's half width; above 1 it will miss), re-rolled after every tap.
var _tap_window := 0.6
var _tap_cool := 0.0
var _shield_hold := 0.0


func _init(slot: int) -> void:
	device = -100 - slot


func poll() -> void:
	_think()
	aim = move


func _think() -> void:
	move = Vector2.ZERO
	action_held = false
	action_pressed = false
	interact_pressed = false
	press_needle = -1.0
	if crew == null or crew.tank == null or crew.tank.dead:
		return
	var tank := crew.tank
	var kind: String = task.get("kind", "")
	var want_station: String = task.get("id", "") if kind == "station" else ""

	# Leave a station we are no longer assigned to.
	if crew.station != null and crew.station.id != want_station:
		interact_pressed = true
		return
	match kind:
		"station":
			if crew.station != null:
				_operate(crew.station.id, tank)
				return
			var st: MegaTank.Station = tank.stations[want_station]
			if crew.deck_pos.distance_to(st.pos) < ARRIVE:
				interact_pressed = true
			else:
				_walk_to(st.pos, tank)
		"fix":
			var b = task.get("breach")
			if not is_instance_valid(b):
				return
			if crew.deck_pos.distance_to(b.deck_pos) < 1.1:
				action_held = true
			else:
				_walk_to(b.deck_pos, tank)


func _walk_to(target: Vector2, tank: MegaTank) -> void:
	var d := target - crew.deck_pos
	# If the turret, MG post or reactor is in the way, walk around it along the shorter arc.
	for o in tank.obstacles:
		var c: Vector2 = o[0]
		var r: float = o[1] + 0.15
		if target.distance_to(c) < r or crew.deck_pos.distance_to(c) > r + 0.8:
			continue
		if Geometry2D.get_closest_point_to_segment(c, crew.deck_pos, target).distance_to(c) < r:
			var radial := (crew.deck_pos - c).normalized()
			var delta := wrapf((target - c).angle() - radial.angle(), -PI, PI)
			d = radial.rotated(PI * 0.5 * signf(delta + 0.0001)) + radial * 0.3
			break
	var world := tank.global_basis * Vector3(d.x, 0.0, d.y)
	move = G.main.world_to_stick(world).limit_length(1.0)
	if d.length() < 0.6:
		move *= 0.6


func _operate(id: String, tank: MegaTank) -> void:
	_aim_error_t -= 1.0 / 60.0
	if _aim_error_t <= 0.0:
		_aim_error_t = 0.5
		_aim_error = randf_range(-0.04, 0.04)
	match id:
		"drive":
			_drive(tank)
		"cannon":
			_cannon(tank)
		"mg":
			_machine_gun(tank)
		"repair":
			_repair(tank)


# --- Station behaviour -----------------------------------------------------------------------

func _drive(tank: MegaTank) -> void:
	if G.main.state != Main.State.PLAYING:
		return
	var dt := 1.0 / 60.0
	var pos := tank.global_position
	var target := _nearest_enemy(pos, 999.0, true)
	var dir := Vector3.ZERO
	if target:
		var to := target.global_position - pos
		to.y = 0.0
		var dist := to.length()
		_drive_side_t -= dt
		if _drive_side_t <= 0.0:
			_drive_side_t = randf_range(4.0, 8.0)
			_drive_side = -_drive_side
		if dist > 20.0:
			dir = to.normalized()
		elif dist < 9.0:
			dir = -to.normalized()
		else:
			dir = to.normalized().cross(Vector3.UP) * _drive_side * 0.8
	else:
		if _wander == Vector3.ZERO or pos.distance_to(_wander) < 6.0:
			_wander = Vector3(roundf(randf_range(-2, 2)) * City.PERIOD, 0, roundf(randf_range(-2, 2)) * City.PERIOD)
		dir = (_wander - pos).normalized()
	# Get out from under a mortar round that is about to land.
	for node in tank.get_tree().get_nodes_in_group("mortar_marks"):
		var m: MortarShell = node
		var away := pos - m.to
		away.y = 0.0
		if away.length() < 6.0 and m.time_left() < 1.6:
			dir = (away.normalized() + dir * 0.3).normalized()
			break
	# Stay inside the arena.
	var lim := City.HALF - 10.0
	if absf(pos.x) > lim or absf(pos.z) > lim:
		dir = (dir - pos.normalized()).normalized()
	# If wedged against something, back off and turn for a moment.
	if absf(tank.speed) < 0.8 and dir != Vector3.ZERO:
		_stuck_t += dt
	else:
		_stuck_t = 0.0
	if _stuck_t > 1.5:
		_stuck_t = 0.0
		_unstick_t = 1.2
	if _unstick_t > 0.0:
		_unstick_t -= dt
		dir = (tank.global_basis.z + tank.global_basis.x * _drive_side).normalized()
	elif dir != Vector3.ZERO:
		dir = _avoid(tank, dir)
	move = G.main.world_to_stick(dir)


## Steers around buildings; crushable clutter is fine to drive through.
func _avoid(tank: MegaTank, dir: Vector3) -> Vector3:
	var space := tank.get_world_3d().direct_space_state
	for a in [0.0, 0.5, -0.5, 1.0, -1.0, 1.6, -1.6]:
		var d := dir.rotated(Vector3.UP, a * _drive_side)
		var from := tank.global_position + Vector3(0, 1.0, 0)
		var blocked := false
		for side in [-2.6, 0.0, 2.6]:
			var off: Vector3 = d.cross(Vector3.UP) * side
			var q := PhysicsRayQueryParameters3D.create(from + off, from + off + d * 9.0, G.LAYER_TERRAIN)
			var hit := space.intersect_ray(q)
			if not hit.is_empty():
				var b := hit["collider"] as Block
				if b == null or not b.crushable:
					blocked = true
					break
		if not blocked:
			return d
	return dir


## Plays the repair gauge like a person: waits for the needle to reach the zone and taps, with
## a bit of human sloppiness. Holds ACTION for the shield when something is about to hit.
func _repair(tank: MegaTank) -> void:
	var dt := 1.0 / 60.0
	if _incoming_threat(tank):
		_shield_hold = 0.4
	else:
		_shield_hold -= dt
	if tank.shield_up:
		action_held = _shield_hold > 0.0 and tank.shield > 4.0
		return
	if _shield_hold > 0.0 and tank.shield >= 30.0 and tank.shield_lock <= 0.0:
		action_held = true
		return
	_tap_cool -= dt
	if _tap_cool > 0.0 or tank.rep_stun > 0.0:
		return
	if tank.hp >= MegaTank.MAX_HP and tank.shield >= MegaTank.SHIELD_MAX:
		return
	var d := absf(tank.needle_now() - tank.zone_center) / maxf(tank.zone_half, 0.01)
	if d <= _tap_window:
		action_pressed = true
		action_held = true
		_tap_cool = randf_range(0.15, 0.3)
		var roll := randf()
		_tap_window = 0.3 if roll < 0.25 else (0.85 if roll < 0.9 else 1.3)


## Something that will hurt the tank in the next moment: shells or rockets closing in, a buggy
## or hornet right next to it, a mortar round about to land on it.
func _incoming_threat(tank: MegaTank) -> bool:
	var pos := tank.global_position
	for node in tank.get_tree().get_nodes_in_group("enemy_shots"):
		var p: Projectile = node
		if p.dead or p.kind == "enemy_bullet":
			continue
		var to := pos - p.global_position
		to.y = 0.0
		if to.length() < 11.0 and to.dot(p.velocity) > 0.0:
			return true
	for node in tank.get_tree().get_nodes_in_group("mortar_marks"):
		var m: MortarShell = node
		if m.time_left() < 0.9 and Vector2(m.to.x - pos.x, m.to.z - pos.z).length() < 7.0:
			return true
	for node in tank.get_tree().get_nodes_in_group("enemies"):
		if node is Buggy or node is Hornet:
			if (node as Node3D).global_position.distance_to(pos) < 9.0:
				return true
	return false


func _cannon(tank: MegaTank) -> void:
	var pos := tank.global_position
	var target := _nearest_enemy(pos, 40.0, true)
	if target == null:
		return
	var to := target.global_position - pos
	var lead := target.velocity * (to.length() / MegaTank.SHELL_SPEED)
	var aim := (to + lead)
	aim.y = 0.0
	aim = aim.normalized().rotated(Vector3.UP, _aim_error)
	move = G.main.world_to_stick(aim)
	var facing := -tank.turret.global_basis.z
	facing.y = 0.0
	action_held = facing.normalized().angle_to(aim) < 0.08 and to.length() > 5.0


func _machine_gun(tank: MegaTank) -> void:
	var muzzle := tank.mg_muzzle.global_position
	var target_pos := Vector3.INF
	var urgent := false
	var best := 24.0
	for r in tank.get_tree().get_nodes_in_group("rockets"):
		var d: float = (r as Node3D).global_position.distance_to(muzzle)
		if d < best:
			best = d
			target_pos = (r as Node3D).global_position
			urgent = true
	if not urgent:
		# Hornets diving in come next: one round each.
		for node in tank.get_tree().get_nodes_in_group("enemies"):
			if node is Hornet:
				var hp := (node as Node3D).global_position
				var d := hp.distance_to(muzzle)
				if d < best:
					best = d
					target_pos = hp + (node as Enemy).velocity * 0.15
					urgent = true
	if not urgent:
		var e := _nearest_enemy(muzzle, 26.0, false)
		if e:
			target_pos = e.global_position + e.velocity * 0.25
	if target_pos == Vector3.INF:
		return
	var aim := target_pos - muzzle
	aim.y = 0.0
	aim = aim.normalized().rotated(Vector3.UP, _aim_error * 0.5)
	move = G.main.world_to_stick(aim)
	var facing := -tank.mg_pivot.global_basis.z
	facing.y = 0.0
	var aligned := facing.normalized().angle_to(aim) < 0.12
	action_held = aligned and (urgent or tank.mg_heat < 80.0)


## Nearest living enemy; with prefer_tanks, enemy tanks count as if they were closer.
func _nearest_enemy(from: Vector3, max_dist: float, prefer_tanks: bool) -> Enemy:
	var best: Enemy = null
	var best_score := max_dist
	for node in crew.get_tree().get_nodes_in_group("enemies"):
		var e: Enemy = node
		var d := e.global_position.distance_to(from)
		var big := e is EnemyTank or e is MortarTeam or e is ShieldTruck or e is Gunship or e is BossTank
		var score := d * (0.6 if prefer_tanks and big else 1.0)
		if prefer_tanks and e is Hornet:
			score *= 2.0  # leave the swarms to the machine gun
		if d < max_dist and score < best_score:
			best = e
			best_score = score
	return best
