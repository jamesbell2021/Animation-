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
## By day either picks up the salvage the night's creatures left on its island before the
## sea takes it back at dusk.
## Either drops what it's doing to fight anything that comes close, to get a downed
## keeper back on their feet, or to go and pick up its thrown boathook. It fights with
## the shed's weapons when it has them: the lighthouse keeper takes the shotgun off the
## wall if nobody has it (a person can take it back at the shed), and a longbow made
## for it at the shed. It leaves the flamer and the petrol bombs to the people.

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
## The shotgun at this range or closer; the bow out to this, past the boathook's reach.
const GUN_RANGE := 6.0
const BOW_RANGE := 11.0
## How far it draws the bow before it looses (a full draw is 1).
const BOW_DRAW := 0.8
## Cartridges it leaves in the box for the people when it takes the shotgun.
const SHELLS_SPARE := 2
## Kelp it keeps back for the garden's beds when it boils a broth.
const KELP_KEEP := 3
## The Escape: the chance each frame that a helper at the rail swings at what's climbing.
const REPEL_EAGER := 0.1

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
	keeper.ai_just.clear()
	if keeper.downed or keeper.is_climbing() or keeper.is_busy() or keeper.is_staggering():
		keeper.ai_move = Vector2.ZERO
		return
	if Terrain.chapter == 3 and keeper.in_menu:
		# The Escape: at the Mary Ann's wheel, which steers for it (EscapeHelm).
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
	if Terrain.chapter == 3:
		_escape()
		return
	# The relief boat is in: down to the beach and aboard.
	var boat := get_tree().get_first_node_in_group("relief_boat")
	if boat != null and boat.waiting:
		_set_task("board", boat, boat.shore)
		return
	# A keeper down: go and get them up.
	var mate := _downed_keeper()
	if mate != null:
		_set_task("revive", mate, mate.global_position)
		return
	# The lamp about to run dry under whoever is working it: that comes before any fight.
	var lit := keeper.lamp
	if lit != null and not keeper.operating and lit.is_lit() and lit.fuel < 20.0 and lit.operator != null and lit.lighthouse.work_kind() == "can" \
			and Geo.flat_dist(keeper.global_position, lit.lighthouse.global_position) < 30.0:
		_set_task("refuel", lit.lighthouse, KeeperNav.door_point())
		return
	# Something close: fight it (or get clear of a Bloated about to burst).
	var e := _threat()
	if e != null:
		_set_task("fight", e, e.global_position)
		return
	# Hungry or cold: see to it before it slows them down.
	if _see_to_needs():
		return
	# The shotgun on the wall and cartridges in the box: the lighthouse keeper takes it.
	if _wants_gun():
		var shed := _shed()
		_set_task("arm", shed, shed.global_position)
		return
	if not keeper.has_hook:
		var hook := _my_hook()
		if hook != null:
			_set_task("hook", hook, hook.global_position)
			return
	var night := Cycle.phase == Cycle.Phase.DUSK or Cycle.phase == Cycle.Phase.NIGHT
	if Terrain.chapter == 2:
		_harbour(night)
		return
	if role == "light" or _kraken_at_light():
		if night:
			_night_light()
		else:
			_day_light()
	else:
		if night:
			_night_camp()
		else:
			_day_camp()

# The last night: once the kraken has left the camp for the lighthouse (its second
# stage), everyone's place is at the light, the camp's keeper too (docs/DESIGN.md,
# "The kraken: three stages").
func _kraken_at_light() -> bool:
	var kr := get_tree().get_first_node_in_group("kraken")
	return kr != null and int(kr.get("stage")) >= 2

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
	var fix := _nearest_fixable(false)
	if fix != null:
		_set_task("repair", fix, _work_point(fix))
		return
	var lamp := keeper.lamp
	if lamp != null and lamp.fuel < Lamp.FUEL_MAX - 30.0 and lamp.lighthouse.work_kind() == "can":
		_set_task("refuel", lamp.lighthouse, KeeperNav.door_point())
		return
	if _fetch_salvage(0):
		return
	# Nothing to eat in the store: boil what the beds can spare (eggs, kelp past a few).
	var cot := _cottage()
	if cot != null and Stock.get_amount("food") == 0 and (Stock.can_afford(Cottage.EGGS_MEAL) or Stock.get_amount("seaweed") >= KELP_KEEP + 3):
		_set_task("cook", cot, (cot as Node3D).global_position)
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

## Kirkhaven (Chapter Two). The "light" helper works the harbour light from dusk if
## nobody else is on it; otherwise, and the "lamps" helper always, it mends what's broken,
## switches dark lamps in, keeps the generator and the light fed, fetches the day's
## stores, and at night stands by the landings.
const HARBOUR_POSTS := [Vector2(-15.0, 3.0), Vector2(15.0, 3.0), Vector2(26.0, 1.5), Vector2(0.0, 1.5)]

func _harbour(night: bool) -> void:
	var lamp := keeper.lamp
	if night and role == "light" and lamp != null:
		var taken := lamp.operator != null and is_instance_valid(lamp.operator) and lamp.operator != keeper
		if not taken:
			_set_task("lamp", lamp, KeeperNav.door_point())
			return
	var gen := _generator()
	if gen != null and gen.work_kind() == "can" and gen.fuel < Generator.FUEL_MAX - Generator.CAN_UNITS:
		_set_task("generator", gen, gen.global_position + Vector3(0.0, 0.0, 2.4))
		return
	# The harbour light: mended when it's been hit (it can't be refuelled till it is),
	# kept full by day, and never let run dry in the night.
	if lamp != null and lamp.lighthouse.work_kind() == "hammer" and (not night or lamp.fuel < 40.0 or role == "lamps"):
		_set_task("repair", lamp.lighthouse, KeeperNav.door_point())
		return
	if lamp != null and lamp.fuel < (25.0 if night else Lamp.FUEL_MAX - 15.0) and lamp.lighthouse.work_kind() == "can":
		_set_task("refuel", lamp.lighthouse, KeeperNav.door_point())
		return
	# The last night, the one who walks the lamps keeps the kirk doors instead: mends
	# them, and rings the bell once they're ashore in numbers.
	var kirk := get_tree().get_first_node_in_group("kirk")
	if night and role == "lamps" and kirk != null and kirk.besieged and not kirk.is_destroyed():
		if kirk.can_ring() and _ashore() >= 4:
			_set_task("bell", kirk, kirk.door_point())
		elif kirk.work_kind() == "hammer":
			_set_task("repair", kirk, kirk.door_point())
		else:
			_set_task("round", null, kirk.door_point() + Vector3(0.0, 0.0, 1.2))
		return
	# The last night's flight: stay by whoever is still on their way down to the boat.
	if night and role == "lamps":
		var walker := _someone_abroad()
		if walker != null:
			_set_task("escort", walker, walker.global_position + Vector3(0.0, 0.0, 1.2))
			return
	var fix := _nearest_fixable(false)
	if fix != null:
		_set_task("repair", fix, _work_point(fix))
		return
	var dark := _dark_lamp()
	if dark != null:
		_set_task("switch", dark, dark.global_position + Vector3(0.0, 0.0, -0.9))
		return
	if not night:
		# The bell rope, when there's scrap to spare beyond a lamp's mending.
		if kirk != null and role == "lamps" and not Run.bell_mended and Stock.get_amount("scrap") >= 3:
			_set_task("bell", kirk, kirk.door_point())
			return
		if _fetch_salvage(0):
			return
		if _keep_gathering():
			return
		var sp := _nearest_scavenge(false)
		if sp != null:
			_set_task("gather", sp, sp.global_position)
			return
	var post: Vector2 = HARBOUR_POSTS[(_round + keeper.idx) % HARBOUR_POSTS.size()]
	_set_task("round", null, Vector3(post.x, Terrain.height_at(post.x, post.y), post.y))

# One of Kirkhaven's people out of doors in the dark: the one furthest from the boat
# (the last of the file), or null.
func _someone_abroad() -> Node3D:
	var best: Node3D = null
	var best_z := INF
	for v in get_tree().get_nodes_in_group("prey"):
		var n := v as Node3D
		if n.global_position.z < best_z:
			best_z = n.global_position.z
			best = n
	return best

# How many creatures are up out of the water in the town.
func _ashore() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		var st = e.get("state")
		if st != &"Emerge" and st != &"Retreat" and e.global_position.z < HarbourMap.QUAY_Z:
			n += 1
	return n

# The nearest street lamp that's whole and not yet switched in.
func _dark_lamp() -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for l in get_tree().get_nodes_in_group("street_lamps"):
		if l.on or l.hp <= 0:
			continue
		var d := Geo.flat_dist(l.global_position, keeper.global_position)
		if d < best_d:
			best_d = d
			best = l
	return best

func _night_light() -> void:
	var lamp := keeper.lamp
	var on_lamp := lamp != null and lamp.operator != null and is_instance_valid(lamp.operator) and lamp.operator != keeper
	if not on_lamp and lamp != null:
		_set_task("lamp", lamp, KeeperNav.door_point())
		return
	# Somebody else has the lamp: see it doesn't run dry under them.
	if lamp != null and lamp.fuel < 30.0 and lamp.lighthouse.work_kind() == "can":
		_set_task("refuel", lamp.lighthouse, KeeperNav.door_point())
		return
	_set_task("ledge", null, Terrain.ledge_point(POST_S))

func _day_camp() -> void:
	var gen := _generator()
	if gen != null and gen.work_kind() != "":
		_set_task("generator", gen, gen.global_position)
		return
	# Mend the camp after a raid: the wire, the huts, the greenhouse.
	var fix := _nearest_fixable(true)
	if fix != null:
		_set_task("repair", fix, _work_point(fix))
		return
	if _fetch_salvage(1):
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
		"arm":
			var shed := _task_target as Shed
			if shed != null and is_instance_valid(shed) and shed.surface_distance(keeper.global_position) <= Player.INTERACT_RANGE:
				if _wants_gun():
					keeper.arsenal.give("shotgun")
					keeper.arsenal.select("hook")
					Events.message.emit("%s takes the shotgun off the shed wall. (Take it back at the shed if you want it.)" % keeper.keeper_name())
				_task = ""
				_route.clear()
		"board":
			if _task_target != null and is_instance_valid(_task_target) and Geo.flat_dist(keeper.global_position, _task_target.shore) <= ReliefBoat.BOARD_RANGE:
				_task_target.take_aboard(keeper)
				_route.clear()
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
		"cook":
			var cot := _task_target as Cottage
			if cot != null and cot.surface_distance(keeper.global_position) <= Player.INTERACT_RANGE:
				if Stock.can_afford(Cottage.EGGS_MEAL):
					cot.boil_eggs()
				elif Stock.get_amount("seaweed") >= KELP_KEEP + 3:
					cot.kelp_broth()
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
		"switch":
			if _task_target != null and is_instance_valid(_task_target) and Geo.flat_dist(keeper.global_position, (_task_target as Node3D).global_position) < 1.7:
				_task_target.interact(keeper)
				_task = ""
				_route.clear()
		"bell":
			if _task_target != null and is_instance_valid(_task_target) and Geo.flat_dist(keeper.global_position, _task_target.door_point()) < 1.8:
				_task_target.alt_use(keeper)
				_task = ""
				_route.clear()
		"helm":
			if _task_target != null and is_instance_valid(_task_target) and Geo.flat_dist(keeper.global_position, EscapeMap.HELM_STAND) < 0.9:
				_task_target.take(keeper)
				_task = ""
				_route.clear()
		"repel":
			_repel()

## The Escape (Chapter "3", the crossing on the Mary Ann): the "helm" helper takes the
## wheel from Dod unless a person has it; every helper not at the wheel keeps the
## gunwales, knocking off what climbs her sides and fighting what gets aboard, and
## otherwise stands by the seven.
func _escape() -> void:
	var esc := get_tree().get_first_node_in_group("escape")
	if esc == null:
		return
	var mate := _downed_keeper()
	if mate != null:
		_set_task("revive", mate, mate.global_position)
		return
	if role == "helm" and esc.call("helm_free_for", keeper):
		_set_task("helm", esc.get("helm"), EscapeMap.HELM_STAND)
		return
	var e: Node3D = esc.call("threat_for", keeper)
	if e != null:
		if e.call("clinging"):
			_set_task("repel", e, e.call("rail_point"))
		else:
			_set_task("fight", e, e.global_position)
		return
	_set_task("post", null, esc.call("post_for", keeper))

# The Escape: at the rail by something climbing her side, one blow knocks it back into the
# sea; from further off, a shot or an arrow does as well once it is high on her side.
func _repel() -> void:
	var e: Node3D = _task_target if is_instance_valid(_task_target) else null
	if e == null or e.get("hp") <= 0 or not e.call("clinging"):
		_task = ""
		return
	var to := e.global_position - keeper.global_position
	to.y = 0.0
	var d := to.length()
	var arms := keeper.arsenal
	if d <= Player.ATTACK_RANGE - 0.35:
		if arms != null and arms.in_hand():
			arms.cease()
			arms.select("hook")
		_route.clear()
		_goal = Vector3.INF
		keeper.ai_move = Vector2.ZERO
		keeper._aim = to.normalized()
		keeper._aim_face_t = 0.3
		# Not quite at once, as a person wouldn't be (a fifth of a second, give or take).
		if keeper._attack_cd <= 0.0 and randf() < REPEL_EAGER:
			keeper._attack()
		return
	if arms != null and d > 4.0 and float(e.call("climb_progress")) > 0.8 and _shoot(e, to, d):
		return
	if arms != null and arms.in_hand():
		arms.cease()
		arms.select("hook")
	_go(e.call("rail_point"))

func _fight() -> void:
	var e: Node3D = _task_target if is_instance_valid(_task_target) else null
	if e == null:
		_task = ""
		return
	var to := e.global_position - keeper.global_position
	to.y = 0.0
	if e.get("state") == &"Bloat" or e.get("state") == &"Burst":
		# Clear out of the blast.
		_route.clear()
		_goal = keeper.global_position - to.normalized() * BURST_CLEAR
		return
	var d := to.length()
	var arms := keeper.arsenal
	if arms != null and _shoot(e, to, d):
		return
	if arms != null and arms.in_hand():
		arms.cease()
		arms.select("hook")
	if d <= STRIKE_RANGE:
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

# Fight with what it carries from the shed: stand, aim and fire the shotgun when it's
# close, or draw and loose the bow at something past the boathook's reach. False to
# fight with the boathook instead.
func _shoot(e: Node3D, to: Vector3, d: float) -> bool:
	var arms := keeper.arsenal
	var free := Difficulty.free_ammo()
	var gun := arms.available("shotgun") and (Run.barrels > 0 or Stock.get_amount("shells") > 0 or free)
	var bow := arms.available("bow") and (Stock.get_amount("arrows") > 0 or free or arms.draw >= 0.0)
	var use := ""
	if gun and d <= GUN_RANGE:
		use = "shotgun"
	elif bow and d > STRIKE_RANGE + 0.5 and d <= BOW_RANGE:
		use = "bow"
	if use == "":
		return false
	if arms.weapon != use:
		arms.cease()
		arms.select(use)
	_route.clear()
	_goal = Vector3.INF
	keeper.ai_move = Vector2.ZERO
	keeper._aim = to.normalized()
	keeper._aim_face_t = 0.3
	keeper.ai_point = e.global_position
	if use == "shotgun":
		keeper.ai_just["attack"] = arms._cd <= 0.0 and arms._reload_t <= 0.0
	elif arms.draw < 0.0:
		keeper.ai_just["attack"] = arms._cd <= 0.0
		keeper.ai_held["attack"] = true
	else:
		# Hold the draw until it's far enough back, then let go.
		keeper.ai_held["attack"] = arms.draw < BOW_DRAW
	return true

func _shed() -> Shed:
	for s in get_tree().get_nodes_in_group("structures"):
		if s is Shed and not s.is_destroyed():
			return s
	return null

func _wants_gun() -> bool:
	if role != "light" or keeper.arsenal == null or keeper.operating or keeper.manning != null \
			or Arsenal.holder("shotgun") >= 0 or _shed() == null:
		return false
	return Difficulty.free_ammo() or Run.barrels + Stock.get_amount("shells") > SHELLS_SPARE

# Up in the lamp room: burn the nearest creature the focused beam can reach, or hold
# the closest in the wide beam. Leave to deal with something on the tower.
func _work_lamp(delta: float) -> void:
	var lamp := keeper.lamp
	if lamp == null:
		return
	var night := Cycle.phase == Cycle.Phase.DUSK or Cycle.phase == Cycle.Phase.NIGHT
	if not night or _climber_up() or _task == "board":
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
	return dep > -lamp.tilt_deg - Lamp.FOCUS_ANGLE + 1.0 and dep < -lamp.tilt_deg + Lamp.FOCUS_ANGLE - 1.0

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
		# Out on Gull Rock or in the boat, they're out of reach: they'll get up at dawn.
		if k != keeper and k is Player and k.downed and k.riding == null and Terrain.island_of(k.global_position.x, k.global_position.z) != 2:
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

## Where to stand to mend something: its own work point (the camp's wire, from inside),
## or the thing itself.
func _work_point(s: Node) -> Vector3:
	if s.has_method("work_point"):
		return s.work_point()
	return (s as Node3D).global_position

# The nearest thing broken that can be paid for, on the holm (the warden) or the main island.
func _nearest_fixable(holm: bool) -> Node:
	var best: Node = null
	var best_d := INF
	for s in get_tree().get_nodes_in_group("structures"):
		if not (s is Structure) or s is Lighthouse:
			continue
		if s.work_kind() != "hammer" or Terrain.holm_side(s.global_position.x, s.global_position.z) != holm:
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

## The nearest salvage lying on this island (0 the crag's, 1 the holm): walk onto it, and
## it comes into the keeper's hands (Salvage picks itself up).
func _fetch_salvage(island: int) -> bool:
	var best: Node3D = null
	var best_d := INF
	for s in get_tree().get_nodes_in_group("salvage"):
		var n := s as Node3D
		if n == null or n.is_queued_for_deletion() or Terrain.island_of(n.global_position.x, n.global_position.z) != island:
			continue
		var d := Geo.flat_dist(n.global_position, keeper.global_position)
		if d < best_d:
			best_d = d
			best = n
	if best == null:
		return false
	_set_task("salvage", best, best.global_position)
	return true
