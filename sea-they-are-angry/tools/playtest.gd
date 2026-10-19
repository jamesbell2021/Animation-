extends SceneTree
## Balance playtest: plays nights with a simple keeper bot and prints what happened.
##   godot --headless --path sea-they-are-angry --script res://tools/playtest.gd -- [nights] [bot|idle] [keepers]
## "bot" keeps the lamp manned: it burns whatever is on the beaches with the focused
## beam and holds the nearest climber in the wide beam. "idle" leaves the lamp to sweep
## by itself. Between nights the bot patches up what it can afford, like a player would.
## Your own Continue save and best night are backed up first and put back afterwards.

var nights := 3
var mode := "bot"
var keepers := 1
var stats := {}
# A human at the lamp: picks a new target about once a second and aims a few degrees off.
const REACTION := 1.1
const AIM_ERROR_DEG := 3.0
var _bot_target: Node3D
var _bot_think := 0.0
var _bot_error := 0.0

func _init() -> void:
	_go.call_deferred()

func _go() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		nights = int(a[0])
	if a.size() > 1:
		mode = a[1]
	if a.size() > 2:
		keepers = int(a[2])
	var saved := _backup()
	if FileAccess.file_exists("user://run.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://run.json"))
	var players = root.get_node("Players")
	players.wanted = keepers
	change_scene_to_file("res://scenes/main.tscn")
	for i in 600:
		if current_scene != null and current_scene.get("player") != null:
			break
		await process_frame
	for i in 3:
		await physics_frame
	var main = current_scene
	var cycle = root.get_node("Cycle")
	var run = root.get_node("Run")
	var events = root.get_node("Events")
	var lamp: Lamp = main.lighthouse.lamp
	var player: Player = main.player
	player.camera = null
	events.enemy_killed.connect(func(e):
		var k: String = e.last_hit if e.last_hit != "" else "?"
		stats[k] = stats.get(k, 0) + 1
		var kinds: Dictionary = stats.get("kinds", {})
		var kind: String = e.get_script().get_global_name()
		kinds[kind] = kinds.get(kind, 0) + 1
		stats["kinds"] = kinds)
	events.structure_destroyed.connect(func(s): stats["destroyed_" + String(s.id)] = stats.get("destroyed_" + String(s.id), 0) + 1)
	Engine.time_scale = 8.0
	for n in nights:
		stats = {}
		var lh_start: int = main.lighthouse.hp
		var fuel_start: float = lamp.fuel
		cycle._enter(cycle.Phase.DUSK)
		await physics_frame
		var spawned := {}
		var first_top := INF
		var reach_times: Array[float] = []
		var landed := {}
		var t := 0.0
		player.global_position = Vector3(0.0, Terrain.CRAG_TOP + 0.2, 2.6)
		for k in range(1, main.players.size()):
			main.players[k].global_position = Terrain.ledge_point(POST_S) + Vector3(0.0, 0.1, 0.0)
			if main.players[k].downed:
				main.players[k].revive(0.5)
		if mode == "bot" and not player.operating:
			# In at the lighthouse door, like a keeper would.
			player._toggle_operate()
		while run.active and cycle.phase != cycle.Phase.DAWN:
			t += Engine.time_scale / 60.0
			for e in get_nodes_in_group("enemies"):
				var id: int = e.get_instance_id()
				if not landed.has(id):
					landed[id] = t
				if (e.state == &"Arrived" or e.state == &"Bloat") and Geo.flat_dist(e.global_position, Vector3.ZERO) < 4.5:
					if not spawned.has(id):
						spawned[id] = true
						reach_times.append(t - float(landed[id]))
						first_top = minf(first_top, t)
			if lamp.is_lit():
				stats["lit_s"] = stats.get("lit_s", 0.0) + Engine.time_scale / 60.0
				if lamp.mode == Lamp.Mode.FOCUSED:
					stats["focus_s"] = stats.get("focus_s", 0.0) + Engine.time_scale / 60.0
					var burning := false
					for e in get_nodes_in_group("enemies"):
						if e.get("_burn_t") != null and e._burn_t > 0.0:
							burning = true
					if burning:
						stats["burn_s"] = stats.get("burn_s", 0.0) + Engine.time_scale / 60.0
			if mode == "bot" and cycle.phase == cycle.Phase.NIGHT:
				# Something on the tower: in co-op the ledge keeper runs up to shake it down;
				# solo the lamp keeper has to go out and do it.
				var climber := _climber_up()
				var shaker: Player = main.players[1] if main.players.size() > 1 and not main.players[1].downed else player
				if climber:
					stats["smothered_s"] = stats.get("smothered_s", 0.0) + Engine.time_scale / 60.0
				if climber and shaker == player:
					_shake_down(player)
				elif not player.operating and not player.is_busy():
					# Back in at the door.
					player.global_position = Vector3(0.0, Terrain.CRAG_TOP + 0.1, 2.6)
					player._toggle_operate()
				else:
					_aim_bot(player, lamp)
				for k in range(1, main.players.size()):
					if climber and main.players[k] == shaker:
						_shake_down(main.players[k])
					else:
						_defend(main.players[k])
				# Top the lamp up from the store when it runs low, as a keeper at the lamp would.
				if lamp.fuel < 12.0 and root.get_node("Stock").spend({"bio": 1}):
					lamp.refuel_clean(Lighthouse.REFUEL_UNITS)
					stats["refuels"] = stats.get("refuels", 0) + 1
			await physics_frame
		var reached := reach_times.size()
		var avg_reach := 0.0
		for r in reach_times:
			avg_reach += r / maxf(1.0, float(reached))
		var fences_down := 0
		for s in get_nodes_in_group("structures"):
			if s is Fence and s.is_destroyed():
				fences_down += 1
		print("NIGHT %d [%s x%d]: landed %d  beam %d  hook %d  fall %d  reached the light %d (avg %.0f s after landing)  lighthouse %d->%d  fences down %d/5  fuel %.0f->%.0f (refuels %d)  run active %s" % [
			run.night - 1 if cycle.phase == cycle.Phase.DAWN else run.night, mode, keepers, landed.size(), stats.get("beam", 0), stats.get("hook", 0), stats.get("fall", 0),
			reached, avg_reach, lh_start, main.lighthouse.hp, fences_down, fuel_start, lamp.fuel, stats.get("refuels", 0), run.active])
		var home: Array[String] = []
		var kinds := {}
		for s in get_nodes_in_group("structures"):
			if s is Structure and Enemy.HOME_IDS.has(s.id):
				home.append("%s %d/%d" % [s.id, s.hp, s.max_hp])
		print("   homestead: %s   killed: %s" % [", ".join(home), stats.get("kinds", {})])
		print("   smothered for %.0f s" % stats.get("smothered_s", 0.0))
		print("   lamp lit %.0f s, focused %.0f s, of which burning something %.0f s" % [stats.get("lit_s", 0.0), stats.get("focus_s", 0.0), stats.get("burn_s", 0.0)])
		if not run.active:
			break
		# Let dawn play out, then patch up like a player would during the day.
		for i in 120:
			await physics_frame
		_day_repairs(main)
	Engine.time_scale = 1.0
	_restore(saved)
	quit()

const SAVES := ["user://run.json", "user://profile.json"]

func _backup() -> Dictionary:
	var out := {}
	for p in SAVES:
		out[p] = FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else null
	return out

func _restore(saved: Dictionary) -> void:
	for p in SAVES:
		if saved[p] == null:
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
		else:
			var f := FileAccess.open(p, FileAccess.WRITE)
			f.store_string(saved[p])

func _aim_bot(player: Player, lamp: Lamp) -> void:
	_bot_think -= Engine.time_scale / 60.0
	if _bot_think > 0.0 and is_instance_valid(_bot_target) and (_bot_target.state == &"Approach" or _bot_target.state == &"Stalk" or _bot_target.state == &"Coil"):
		_steer(player, lamp, _bot_target)
		return
	_bot_think = REACTION
	_bot_error = deg_to_rad(randf_range(-AIM_ERROR_DEG, AIM_ERROR_DEG))
	# Burn the nearest creature the focused beam can reach; otherwise hold the closest climber in the wide beam.
	var best: Node3D = null
	var best_score := INF
	var focus_target := false
	for e in get_nodes_in_group("enemies"):
		if e.state == &"Retreat" or e.state == &"Emerge" or e.state == &"Bloat" or e.state == &"Burst":
			continue
		# The Crab's shell shrugs off the beam except in its eyes mid-wind-up.
		if e is Crab and e.state != &"WindUp":
			continue
		# Nor does the light burn a Smotherer.
		if e is Smotherer:
			continue
		var probes: Array = e.light_probe_points()
		if probes.is_empty():
			continue
		var at: Vector3 = probes[0]
		var d := Geo.flat_dist(at, Vector3.ZERO)
		var drop: float = lamp.global_position.y - at.y
		var dep := rad_to_deg(atan2(drop, d))
		var reachable: bool = dep > -Lamp.TILT_DEG - Lamp.FOCUS_ANGLE + 1.0 and dep < -Lamp.TILT_DEG + Lamp.FOCUS_ANGLE - 1.0
		var score := d if reachable else 100.0 + d
		if score < best_score:
			best_score = score
			best = e
			focus_target = reachable
	_bot_target = best
	if best != null:
		_steer(player, lamp, best)
	elif lamp.mode == Lamp.Mode.FOCUSED:
		lamp.toggle_mode()

func _steer(player: Player, lamp: Lamp, best: Node3D) -> void:
	var probes: Array = best.light_probe_points()
	if probes.is_empty():
		return
	var at: Vector3 = probes[0]
	var d := Geo.flat_dist(at, Vector3.ZERO)
	var drop: float = lamp.global_position.y - at.y
	var dep := rad_to_deg(atan2(drop, d))
	var focus_target: bool = dep > -Lamp.TILT_DEG - Lamp.FOCUS_ANGLE + 1.0 and dep < -Lamp.TILT_DEG + Lamp.FOCUS_ANGLE - 1.0
	player._aim = Vector3(at.x, 0.0, at.z).normalized().rotated(Vector3.UP, _bot_error)
	# Only pay for the focused beam once it is actually on target.
	var on_target := absf(wrapf(lamp.yaw - player.aim_yaw(), -PI, PI)) < deg_to_rad(Lamp.FOCUS_ANGLE * 0.8)
	var want := Lamp.Mode.FOCUSED if focus_target and on_target else Lamp.Mode.WIDE
	if lamp.mode != want:
		lamp.toggle_mode()

# A second keeper holds the ledge above the upper fence: steps in on the crag side of
# the nearest climber and strikes outward, so blows shove them over the edge.
const POST_S := 0.66
func _defend(k: Player) -> void:
	if k.downed:
		return
	k.camera = null
	var dt := Engine.time_scale / 60.0
	var target: Node3D = null
	var best := 9.0
	for e in get_nodes_in_group("enemies"):
		if e.state == &"Retreat" or e.state == &"Emerge":
			continue
		var d := Geo.flat_dist(e.global_position, k.global_position)
		if absf(e.global_position.y - k.global_position.y) < 1.4 and d < best:
			best = d
			target = e
	var goal := Terrain.ledge_point(POST_S)
	if target != null:
		var out := Vector3(target.global_position.x, 0.0, target.global_position.z).normalized()
		if target.state == &"Bloat" or target.state == &"Burst":
			goal = target.global_position - (target.global_position - k.global_position).normalized() * 4.0
		else:
			goal = target.global_position - out * 1.1
	var step := Vector3(goal.x - k.global_position.x, 0.0, goal.z - k.global_position.z)
	if step.length() > 0.1:
		var mv := step.normalized() * minf(step.length(), Player.SPEED * dt)
		var np := k.global_position + mv
		if Terrain.walkable(np.x, np.z):
			k.global_position = Vector3(np.x, Terrain.height_at(np.x, np.z) + 0.05, np.z)
	if target != null and target.state != &"Bloat" and target.state != &"Burst" and Geo.flat_dist(target.global_position, k.global_position) < 1.8 and k._attack_cd <= 0.0:
		k._aim = Vector3(target.global_position.x - k.global_position.x, 0.0, target.global_position.z - k.global_position.z).normalized()
		k._attack()

func _climber_up() -> bool:
	for s in get_nodes_in_group("smotherers"):
		if s.is_on_tower():
			return true
	return false

# Out of the lamp room if need be, round to the tower's foot, and strike it.
func _shake_down(k: Player) -> void:
	if k.downed or k.is_busy():
		return
	if k.operating:
		k._toggle_operate()
		return
	var foot := Vector3(0.0, Terrain.CRAG_TOP, Lighthouse.RADIUS + 0.6)
	var dt := Engine.time_scale / 60.0
	var step := Vector3(foot.x - k.global_position.x, 0.0, foot.z - k.global_position.z)
	if step.length() > 0.3:
		var np := k.global_position + step.normalized() * minf(step.length(), Player.SPEED * dt)
		if Terrain.walkable(np.x, np.z) or absf(Terrain.height_at(np.x, np.z) - k.global_position.y) < 1.0:
			k.global_position = Vector3(np.x, Terrain.height_at(np.x, np.z) + 0.05, np.z)
		else:
			# Off on the ledge: take the ladder-ish shortcut a real keeper would.
			k.global_position = foot + Vector3(0.0, 0.1, 0.0)
		return
	if k._attack_cd <= 0.0:
		k._attack()

func _day_repairs(main) -> void:
	var stock = root.get_node("Stock")
	# A day's scavenging: everything on the beaches.
	stock.add("driftwood", 6)
	stock.add("scrap", 1)
	stock.add("bio", 2)
	stock.add("seaweed", 2)
	for s in get_nodes_in_group("structures"):
		while s is Structure and s.is_damaged() and stock.spend(s.repair_cost()):
			s.repair(s.repair_amount())
	while main.lighthouse.lamp.fuel <= Lamp.FUEL_MAX - Lighthouse.REFUEL_UNITS and stock.spend({"bio": 1}):
		main.lighthouse.lamp.refuel_clean(Lighthouse.REFUEL_UNITS)
	print("   day: stock ", stock.all(), "  lighthouse ", main.lighthouse.hp, "  fuel ", roundi(main.lighthouse.lamp.fuel))
