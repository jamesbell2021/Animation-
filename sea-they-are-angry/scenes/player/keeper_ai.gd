class_name KeeperAI
extends Node
## A helper keeper's mind: there are always three keepers on the rock, and any the
## people playing don't take are run by this. It walks the keepers' map (KeeperNav,
## ladders and the bridge included) by steering the keeper like a player would, and
## does the jobs of its role:
##   "light": the lighthouse keeper. By day it gathers what has washed up and mends
##            what's broken; from dusk it works the lamp if nobody else is on it (burning
##            what comes ashore, holding climbers in the wide beam), otherwise it holds
##            the ledge with the boathook.
##   "camp":  the camp's warden on the holm. By day it keeps the generator filled with
##            the diesel that washes up on the holm's beaches, mends the camp and does
##            its rounds; from dusk it climbs the tower facing the danger and works its
##            searchlight, burning whatever comes near the wire.
## Either drops what it's doing to fight anything that comes close, to get a downed
## keeper back on their feet, or to go and pick up its thrown boathook.

const THINK_EVERY := 0.4
const ARRIVE := 0.55
const FIGHT_RANGE := 7.0
const STRIKE_RANGE := 1.7
## Back away from a Bloated about to burst, to this far.
const BURST_CLEAR := 4.5
const STUCK_TIME := 1.6
const POST_S := 0.66
const DWELL := 3.5
## Aiming the lamp: a new target about once a second, a few degrees off, like a person.
const REACTION := 1.0
const AIM_ERROR_DEG := 3.0

var keeper: Player
var role := "light"

var _route: Array = []
var _goal := Vector3.INF
var _think := 0.0
var _task := ""
var _task_target: Node = null
var _dwell := 0.0
var _round := 0
var _stuck_t := 0.0
var _last_d := INF
var _lamp_target: Node3D = null
var _lamp_think := 0.0
var _lamp_error := 0.0

func _init(k: Player = null, r: String = "light") -> void:
	keeper = k
	role = r
	name = "KeeperAI"

func _physics_process(delta: float) -> void:
	if keeper == null or not is_instance_valid(keeper) or not Run.active:
		return
	keeper.ai_held.clear()
	if keeper.downed or keeper.is_climbing() or keeper.is_busy() or keeper.is_staggering():
		keeper.ai_move = Vector2.ZERO
		return
	_think -= delta
	if _think <= 0.0:
		_think = THINK_EVERY
		_decide()
	if keeper.operating:
		keeper.ai_move = Vector2.ZERO
		_work_lamp(delta)
		return
	if keeper.manning != null:
		keeper.ai_move = Vector2.ZERO
		_work_light(delta)
		return
	_act(delta)
	_steer(delta)

# ---- choosing what to do ----

func _decide() -> void:
	# A keeper down: go and get them up.
	var mate := _downed_keeper()
	if mate != null:
		_set_task("revive", mate, mate.global_position)
		return
	# Something close: fight it (or get clear of a Bloated about to burst).
	var e := _threat()
	if e != null:
		_set_task("fight", e, e.global_position)
		return
	# Hungry or cold: see to it before it slows them down.
	if _see_to_needs():
		return
	if not keeper.has_hook:
		var hook := _my_hook()
		if hook != null:
			_set_task("hook", hook, hook.global_position)
			return
	var night := Cycle.phase == Cycle.Phase.DUSK or Cycle.phase == Cycle.Phase.NIGHT
	if role == "light":
		if night:
			_night_light()
		else:
			_day_light()
	else:
		if night:
			_night_camp()
		else:
			_day_camp()

# Still on its way to gather something that's still there: keep at it (the nearest
# thing can change as it walks, and swapping back and forth gets it nowhere).
func _keep_gathering() -> bool:
	if _task == "gather" and _task_target != null and is_instance_valid(_task_target) and _task_target.available:
		_go((_task_target as Node3D).global_position)
		return true
	return false

func _set_task(t: String, target: Node, where: Vector3) -> void:
	if t != _task or target != _task_target:
		_dwell = 0.0
	_task = t
	_task_target = target
	_go(where)

func _day_light() -> void:
	# Mend what's broken and can be paid for, nearest first; then gather.
	var fix := _nearest_fixable()
	if fix != null:
		_set_task("repair", fix, (fix as Node3D).global_position)
		return
	var lamp := keeper.lamp
	if lamp != null and lamp.fuel < Lamp.FUEL_MAX - 30.0 and lamp.lighthouse.work_kind() == "can":
		_set_task("refuel", lamp.lighthouse, KeeperNav.door_point())
		return
	var bed := _garden_to_work()
	if bed != null:
		_set_task("plot", bed, bed.global_position)
		return
	if _keep_gathering():
		return
	var sp := _nearest_scavenge(false)
	if sp != null:
		_set_task("gather", sp, sp.global_position)
		return
	# Nothing to do: wait about the cottage.
	_set_task("idle", null, Terrain.at_angle(-18.0, 10.5))

func _night_light() -> void:
	var lamp := keeper.lamp
	var on_lamp := lamp != null and lamp.operator != null and is_instance_valid(lamp.operator) and lamp.operator != keeper
	if not on_lamp and lamp != null:
		_set_task("lamp", lamp, KeeperNav.door_point())
		return
	_set_task("ledge", null, Terrain.ledge_point(POST_S))

func _day_camp() -> void:
	var gen := _generator()
	if gen != null and gen.work_kind() != "":
		_set_task("generator", gen, gen.global_position)
		return
	var plot := _plot_to_work()
	if plot != null:
		_set_task("plot", plot, plot.global_position)
		return
	if _keep_gathering():
		return
	var sp := _nearest_scavenge(true)
	if sp != null:
		_set_task("gather", sp, sp.global_position)
		return
	var spots := KeeperNav.camp_spots()
	if _task != "round":
		_round = randi() % spots.size()
	_set_task("round", null, spots[_round % spots.size()])

func _night_camp() -> void:
	var gen := _generator()
	# The camp dark with diesel in the store: get it running first.
	if gen != null and not gen.running and gen.work_kind() == "can":
		_set_task("generator", gen, gen.global_position)
		return
	var light := _pick_light()
	if light != null and gen != null and gen.has_power():
		var ladder_top := _ladder_top(light)
		_set_task("tower", light, ladder_top)
		return
	var feet := KeeperNav.tower_feet()
	if _task != "patrol":
		_round = 0
	_set_task("patrol", null, feet[_round % feet.size()])

# ---- doing it ----

func _act(delta: float) -> void:
	var here := _arrived()
	match _task:
		"revive":
			if _task_target != null and is_instance_valid(_task_target) and _task_target.downed:
				if Geo.flat_dist(keeper.global_position, _task_target.global_position) <= Player.REVIVE_RANGE - 0.2:
					keeper.ai_held["interact"] = true
					_route.clear()
		"fight":
			_fight()
		"repair":
			if _task_target != null and is_instance_valid(_task_target) and _task_target is Structure:
				var s: Structure = _task_target
				if s.surface_distance(keeper.global_position) <= Player.INTERACT_RANGE - 0.3:
					var tool := s.work_kind()
					if tool != "":
						keeper._start_job(tool, s)
					_task = ""
					_route.clear()
		"refuel":
			if here or Geo.flat_dist(keeper.global_position, KeeperNav.door_point()) < 1.2:
				var lh := keeper.lamp.lighthouse
				if lh.work_kind() == "can":
					keeper._start_job("can", lh)
				_task = ""
				_route.clear()
		"gather":
			if _task_target != null and is_instance_valid(_task_target) and Geo.flat_dist(keeper.global_position, (_task_target as Node3D).global_position) < 1.4:
				_task_target.interact(keeper)
				_task = ""
				_route.clear()
		"lamp":
			if Geo.flat_dist(keeper.global_position, keeper.lamp.lighthouse.global_position) < Player.OPERATE_RANGE - 0.4 \
					and (keeper.lamp.operator == null or not is_instance_valid(keeper.lamp.operator)):
				keeper._toggle_operate()
				_route.clear()
		"generator":
			if _task_target != null and is_instance_valid(_task_target) and _task_target is Structure:
				var g: Structure = _task_target
				if g.surface_distance(keeper.global_position) <= Player.INTERACT_RANGE + 0.6:
					var tool := g.work_kind()
					if tool != "":
						keeper._start_job(tool, g)
					_task = ""
					_route.clear()
		"tower":
			var sl := _task_target as Searchlight
			if sl != null and sl.operator == null and absf(keeper.global_position.y - sl.global_position.y) < 1.5 \
					and Geo.flat_dist(keeper.global_position, sl.global_position) < sl.reach:
				sl.interact(keeper)
				_route.clear()
		"plot":
			if _task_target != null and is_instance_valid(_task_target) and Geo.flat_dist(keeper.global_position, (_task_target as Node3D).global_position) < 1.9:
				_task_target.interact(keeper)
				_task = ""
				_route.clear()
		"eat":
			if _task_target != null and is_instance_valid(_task_target):
				var near := false
				if _task_target is Structure:
					near = (_task_target as Structure).surface_distance(keeper.global_position) <= Player.INTERACT_RANGE
				else:
					near = Geo.flat_dist(keeper.global_position, (_task_target as Node3D).global_position) < 1.9
				if near:
					if _task_target is Cottage:
						_task_target.eat(keeper)
					else:
						_task_target.interact(keeper)
					_task = ""
					_route.clear()
		"warm":
			if _task_target is HutStove and not _task_target.is_lit() and Geo.flat_dist(keeper.global_position, (_task_target as Node3D).global_position) < 1.9:
				_task_target.interact(keeper)
			if keeper.warmth > 80.0:
				_task = ""
		"round", "patrol":
			if here:
				_dwell += delta
				if _dwell >= (DWELL if _task == "round" else 1.0):
					_dwell = 0.0
					_round += 1
					_think = 0.0
		"hook":
			pass

func _fight() -> void:
	var e := _task_target as Node3D
	if e == null or not is_instance_valid(e):
		_task = ""
		return
	var to := e.global_position - keeper.global_position
	to.y = 0.0
	if e.get("state") == &"Bloat" or e.get("state") == &"Burst":
		# Clear out of the blast.
		_route.clear()
		_goal = keeper.global_position - to.normalized() * BURST_CLEAR
		return
	if to.length() <= STRIKE_RANGE:
		_route.clear()
		_goal = Vector3.INF
		keeper.ai_move = Vector2.ZERO
		keeper._aim = to.normalized()
		keeper._aim_face_t = 0.3
		if keeper._attack_cd <= 0.0:
			keeper._attack()
	else:
		# Step in on the near side.
		_route.clear()
		_goal = e.global_position - to.normalized() * (STRIKE_RANGE - 0.4)

# Up in the lamp room: burn the nearest creature the focused beam can reach, or hold
# the closest in the wide beam. Leave to deal with something on the tower.
func _work_lamp(delta: float) -> void:
	var lamp := keeper.lamp
	if lamp == null:
		return
	var night := Cycle.phase == Cycle.Phase.DUSK or Cycle.phase == Cycle.Phase.NIGHT
	if not night or _climber_up():
		keeper._toggle_operate()
		return
	_lamp_think -= delta
	if _lamp_think <= 0.0 or _lamp_target == null or not is_instance_valid(_lamp_target):
		_lamp_think = REACTION
		_lamp_error = deg_to_rad(randf_range(-AIM_ERROR_DEG, AIM_ERROR_DEG))
		_lamp_target = _lamp_pick(lamp)
	if _lamp_target == null:
		if lamp.mode == Lamp.Mode.FOCUSED:
			lamp.toggle_mode()
		return
	var probes: Array = _lamp_target.light_probe_points()
	if probes.is_empty():
		return
	var at: Vector3 = probes[0]
	var c := lamp.lighthouse.global_position
	keeper._aim = Vector3(at.x - c.x, 0.0, at.z - c.z).normalized().rotated(Vector3.UP, _lamp_error)
	var on_target := absf(wrapf(lamp.yaw - keeper.aim_yaw(), -PI, PI)) < deg_to_rad(Lamp.FOCUS_ANGLE * 0.8)
	var want := Lamp.Mode.FOCUSED if _reachable(lamp, at) and on_target else Lamp.Mode.WIDE
	if lamp.mode != want:
		lamp.toggle_mode()

func _lamp_pick(lamp: Lamp) -> Node3D:
	var best: Node3D = null
	var best_score := INF
	for e in get_tree().get_nodes_in_group("enemies"):
		var st = e.get("state")
		if st == &"Retreat" or st == &"Emerge" or st == &"Bloat" or st == &"Burst":
			continue
		if e is Smotherer or (e is Crab and st != &"WindUp"):
			continue
		var probes: Array = e.light_probe_points()
		if probes.is_empty():
			continue
		var at: Vector3 = probes[0]
		var d := Geo.flat_dist(at, lamp.lighthouse.global_position)
		var score := d if _reachable(lamp, at) else 100.0 + d
		if score < best_score:
			best_score = score
			best = e
	return best

static func _reachable(lamp: Lamp, at: Vector3) -> bool:
	var d := Geo.flat_dist(at, lamp.lighthouse.global_position)
	var dep := rad_to_deg(atan2(lamp.global_position.y - at.y, d))
	return dep > -Lamp.TILT_DEG - Lamp.FOCUS_ANGLE + 1.0 and dep < -Lamp.TILT_DEG + Lamp.FOCUS_ANGLE - 1.0

# Up a tower: sweep its ground, and when something comes near, swing onto it and burn
# it in the focused beam. Down again at dawn.
func _work_light(delta: float) -> void:
	var sl := keeper.manning
	var night := Cycle.phase == Cycle.Phase.DUSK or Cycle.phase == Cycle.Phase.NIGHT
	if not night or not sl.is_lit():
		keeper.leave_light()
		_task = ""
		_think = 0.0
		return
	# A better tower for what's coming: go to it.
	_think -= delta
	if _think <= 0.0:
		_think = THINK_EVERY * 3.0
		var best := _pick_light()
		if best != null and best != sl and best.operator == null and _threat_near(best) and not _threat_near(sl):
			keeper.leave_light()
			_task = ""
			return
	_lamp_think -= delta
	if _lamp_think <= 0.0 or _lamp_target == null or not is_instance_valid(_lamp_target):
		_lamp_think = REACTION
		_lamp_error = randf_range(-0.6, 0.6)
		_lamp_target = _light_pick(sl)
	if _lamp_target == null:
		keeper._lamp_point = Vector3.INF
		var yaw := sl.home_yaw + deg_to_rad(Searchlight.SWEEP_DEG * 0.5) * sin(float(Time.get_ticks_msec()) * 0.00035)
		keeper._aim = Vector3(-sin(yaw), 0.0, -cos(yaw))
		if sl.mode == Lamp.Mode.FOCUSED:
			sl.toggle_mode()
		return
	var probes: Array = _lamp_target.light_probe_points()
	var at: Vector3 = probes[0] if not probes.is_empty() else _lamp_target.global_position
	keeper._lamp_point = at + Vector3(_lamp_error, 0.0, _lamp_error)
	var on_target := sl.aim_point() != Vector3.INF and Geo.flat_dist(sl.aim_point(), at) < 1.8
	var want := Lamp.Mode.FOCUSED if on_target else Lamp.Mode.WIDE
	if sl.mode != want:
		sl.toggle_mode()

func _light_pick(sl: Searchlight) -> Node3D:
	var best: Node3D = null
	var best_d := Searchlight.MAX_RANGE - 4.0
	for e in get_tree().get_nodes_in_group("enemies"):
		var st = e.get("state")
		if st == &"Retreat" or st == &"Emerge" or st == &"Bloat" or st == &"Burst" or e is Eel:
			continue
		var d := Geo.flat_dist(e.global_position, sl.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best

func _threat_near(sl: Searchlight) -> bool:
	return _light_pick(sl) != null

# ---- needs and crops ----

func _see_to_needs() -> bool:
	if keeper.operating or keeper.manning != null:
		return false
	var on_holm := Terrain.on_holm(keeper.global_position.x, keeper.global_position.z)
	if keeper.hunger < 30.0 and Stock.get_amount("food") > 0:
		var place := _camp_node("mess") if on_holm or role == "camp" else _cottage()
		if place != null:
			_set_task("eat", place, (place as Node3D).global_position)
			return true
	var cold := keeper.warmth < 25.0 or (_task == "warm" and keeper.warmth < 80.0)
	if cold:
		var heat: Node3D = null
		if on_holm or role == "camp":
			var st := _camp_node("stove") as HutStove
			if st != null and (st.is_lit() or Stock.get_amount("driftwood") > 0):
				heat = st
		if heat == null:
			for h in get_tree().get_nodes_in_group("heat"):
				if h is Campfire:
					heat = h
		if heat != null:
			_set_task("warm", heat, heat.global_position + Vector3(1.0, 0.0, 1.0))
			return true
	return false

func _camp_node(which: String) -> Node:
	for c in get_tree().get_nodes_in_group("camp_root"):
		return c.mess if which == "mess" else c.stove
	return null

func _cottage() -> Node:
	for s in get_tree().get_nodes_in_group("structures"):
		if s is Cottage and not s.is_destroyed():
			return s
	return null

# A potato bed in the cottage garden to lift, or to dig kelp into (keeping a little kelp
# back for mending the garden).
func _garden_to_work() -> Node3D:
	for n in get_tree().get_nodes_in_group("interactable"):
		if n is GardenPlot and n.is_open and n.interact_prompt() != "":
			var st: int = n.state()
			if st == GardenPlot.RIPE or (st == GardenPlot.BARE and Stock.get_amount("seaweed") > 1):
				return n
	return null

# A camp plot to sow (with seed in the store) or lift.
func _plot_to_work() -> Node3D:
	for p in get_tree().get_nodes_in_group("camp_plots"):
		var s: int = p.state()
		if s == CampPlot.RIPE or (s == CampPlot.BARE and Stock.get_amount("seeds") > 0):
			return p
	return null

func _generator() -> Generator:
	for g in get_tree().get_nodes_in_group("camp"):
		if g is Generator:
			return g
	return null

# The searchlight to take: one nobody is on, facing whatever is nearest the camp; or the
# one looking out over the beaches.
func _pick_light() -> Searchlight:
	var lights := get_tree().get_nodes_in_group("searchlights")
	if lights.is_empty():
		return null
	var c := Vector3(Terrain.CAMP_C.x, Terrain.HOLM_HEIGHT, Terrain.CAMP_C.y)
	var near: Node3D = null
	var near_d := 40.0
	for e in get_tree().get_nodes_in_group("enemies"):
		var p: Vector3 = e.global_position
		# Only what's on the holm or the bridge is the camp's business.
		if not Terrain.on_holm(p.x, p.z) and not Terrain.on_bridge(p.x, p.z):
			continue
		var d := Geo.flat_dist(p, c)
		if d < near_d and not (e is Eel):
			near_d = d
			near = e
	var best: Searchlight = null
	var best_d := INF
	for sl in lights:
		if sl.operator != null and sl.operator != keeper:
			continue
		var ref: Vector3 = near.global_position if near != null else Terrain.holm_beach_point(0, 0.8)
		var d := Geo.flat_dist(sl.global_position, ref)
		if d < best_d:
			best_d = d
			best = sl
	return best

# Where a tower's ladder lets a keeper off on its platform.
func _ladder_top(sl: Searchlight) -> Vector3:
	var tower := sl.get_parent() as Node3D
	return tower.to_global(Vector3(0.0, Camp.TOWER_DECK + 0.1, -Camp.TOWER_LEG + 0.45))

# ---- walking ----

func _go(where: Vector3) -> void:
	if _goal != Vector3.INF and _goal.distance_to(where) < 0.6 and not _route.is_empty():
		_goal = where
		_route[_route.size() - 1]["p"] = where
		return
	_goal = where
	_route = KeeperNav.route(keeper.global_position, where)
	_last_d = INF
	_stuck_t = 0.0

func _arrived() -> bool:
	return _goal != Vector3.INF and _route.size() <= 1 and Geo.flat_dist(keeper.global_position, _goal) <= ARRIVE

func _steer(delta: float) -> void:
	var p := keeper.global_position
	var target := Vector3.INF
	while not _route.is_empty():
		var step: Dictionary = _route[0]
		var q: Vector3 = step["p"]
		var d := Geo.flat_dist(p, q)
		if step.has("climb") and d <= ARRIVE + 0.25:
			keeper.climb(step["climb"] + Vector3(0.0, 0.1, 0.0), float(step["time"]))
			_route.pop_front()
			if not _route.is_empty():
				_route.pop_front()
			keeper.ai_move = Vector2.ZERO
			return
		if not step.has("climb") and d <= ARRIVE and _route.size() > 1:
			_route.pop_front()
			_last_d = INF
			continue
		target = q
		break
	if target == Vector3.INF:
		target = _goal
	if target == Vector3.INF or Geo.flat_dist(p, target) <= ARRIVE * 0.6:
		keeper.ai_move = Vector2.ZERO
		return
	var to := Vector2(target.x - p.x, target.z - p.z)
	keeper.ai_move = to.normalized()
	keeper.ai_held["sprint"] = _task in ["revive", "lamp"] and to.length() > 6.0
	# Not getting any closer: sidestep, then as a last resort hop to the waypoint.
	var dist := to.length()
	if dist < _last_d - 0.05:
		_last_d = dist
		_stuck_t = 0.0
	else:
		_stuck_t += delta
		if _stuck_t > STUCK_TIME:
			keeper.ai_move = to.normalized().rotated(PI * 0.5 * (1.0 if randf() < 0.5 else -1.0))
		if _stuck_t > STUCK_TIME * 2.5:
			keeper.global_position = Vector3(target.x, Terrain.height_at(target.x, target.z) + 0.1, target.z)
			_stuck_t = 0.0
			_last_d = INF

# ---- what's about ----

func _downed_keeper() -> Player:
	var best: Player = null
	var best_d := 40.0
	for k in get_tree().get_nodes_in_group("player"):
		if k != keeper and k is Player and k.downed:
			var d := Geo.flat_dist(k.global_position, keeper.global_position)
			if d < best_d:
				best_d = d
				best = k
	return best

func _threat() -> Node3D:
	var best: Node3D = null
	var best_d := FIGHT_RANGE
	for e in get_tree().get_nodes_in_group("enemies"):
		var st = e.get("state")
		if st == &"Retreat" or st == &"Emerge" or st == &"Ragdoll" or st == &"Dead":
			continue
		if e is Eel:
			continue
		if absf(e.global_position.y - keeper.global_position.y) > 1.4:
			continue
		var d := Geo.flat_dist(e.global_position, keeper.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best

func _my_hook() -> Node3D:
	for h in get_tree().get_nodes_in_group("harpoons"):
		if h.keeper == keeper and h.is_lying():
			return h
	return null

func _climber_up() -> bool:
	for s in get_tree().get_nodes_in_group("smotherers"):
		if s.is_on_tower():
			return true
	return false

func _nearest_fixable() -> Node:
	var best: Node = null
	var best_d := INF
	for s in get_tree().get_nodes_in_group("structures"):
		if not (s is Structure) or s is Lighthouse:
			continue
		if s.work_kind() != "hammer" or Terrain.on_holm(s.global_position.x, s.global_position.z):
			continue
		var d := Geo.flat_dist(s.global_position, keeper.global_position)
		if d < best_d:
			best_d = d
			best = s
	return best

# The nearest thing washed up and not yet gathered, on the holm or on the main island.
func _nearest_scavenge(holm: bool) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for sp in get_tree().get_nodes_in_group("interactable"):
		if not (sp is ScavengePoint) or not sp.available:
			continue
		if Terrain.on_holm(sp.global_position.x, sp.global_position.z) != holm:
			continue
		var d := Geo.flat_dist(sp.global_position, keeper.global_position)
		if d < best_d:
			best_d = d
			best = sp
	return best
