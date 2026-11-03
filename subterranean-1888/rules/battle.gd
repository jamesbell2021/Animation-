class_name Battle
extends RefCounted
## The whole tactical simulation, with no nodes, no rendering and no input.
##
## Commands in, events out: the view (or the swarm AI, or a test, or later a network host)
## sends a command dictionary to exec(); the battle checks it with can(), applies it, and
## returns a list of events describing what happened, step by step, for the view to play
## back. Commands are plain dictionaries so they can be sent over a network as they are:
##
##   {"t": "move", "u": 2, "to": Vector2i(5, 7)}
##   {"t": "shoot", "u": 2, "target": 9, "mode": "aimed"}
##   {"t": "end_turn"}
##
## The swarm's turn runs inside end_turn and goes through the same can()/_run() path as the
## player, so the AI can't do anything a player couldn't.

enum Phase { PLAYER, ENEMY, OVER }

const SQUAD_ORDER := ["engineer", "naturalist", "grenadier", "cartographer"]
const NO_TILE := Vector2i(-1, -1)

var grid: TacGrid
var units: Array[Unit] = []
var defs: Dictionary = {}
var rng := RandomNumberGenerator.new()
var turn := 1
var phase := Phase.PLAYER
## "" while playing, then "extracted", "exterminated" or "lost".
var outcome := ""
var journal_tile := NO_TILE
var journal_carrier := -1
var lift_tiles: Array[Vector2i] = []
## Tile -> strength. The swarm's shared memory of where the squad was (GDD 6.2).
var pheromones: Dictionary = {}
## Each {"tile", "radius", "turns", "max_turns"}.
var flares: Array[Dictionary] = []
## Tiles the squad has ever seen / sees now (1 or 0 a tile).
var explored := PackedByteArray()
var visible_tiles := PackedByteArray()
## Enemy id -> true for every enemy the squad can see right now.
var spotted: Dictionary = {}
## Seismograph returns: where unseen creatures moved last enemy turn.
var pings: Array[Vector2i] = []
var hive_spawned := 0
var hive_alert_turns := 0
var stats := {"kills": 0, "lost": 0, "shots": 0, "hits": 0, "reactions": 0, "flares": 0}

var _events: Array[Dictionary] = []
var _static_light := PackedFloat32Array()
var _reaction_logged: Dictionary = {}
## Set when vision or light changed since the last event, so the next event carries a
## snapshot of it and the view can reveal the fog step by step as it plays the events back.
var _vision_dirty := true
var _light_dirty := true


# ------------------------------------------------------------------------------------------
# Setup and queries
# ------------------------------------------------------------------------------------------

func setup(level: Dictionary, unit_defs: Dictionary, seed_value: int = 0) -> void:
	defs = unit_defs
	grid = level["grid"]
	rng.seed = seed_value if seed_value != 0 else randi()
	journal_tile = level["journal"]
	lift_tiles.assign(level["lift"])
	var starts: Array = level["squad"]
	for i in mini(starts.size(), SQUAD_ORDER.size()):
		var s := _spawn(defs[SQUAD_ORDER[i]], Unit.SQUAD, starts[i])
		s.facing = 6
	for e in level["enemies"]:
		var u := _spawn(defs[e[0]], Unit.SWARM, e[1])
		u.dormant = not u.def.stationary
		u.facing = rng.randi_range(0, 7)
	var n := grid.width * grid.height
	explored.resize(n)
	explored.fill(0)
	visible_tiles.resize(n)
	visible_tiles.fill(0)
	_recompute_static_light()
	_recompute_light()
	_refresh_vision()


func unit(id: int) -> Unit:
	return units[id] if id >= 0 and id < units.size() else null


func unit_at(c: Vector2i) -> Unit:
	if not grid.in_bounds(c):
		return null
	var id := grid.occupant[grid.idx(c)]
	return units[id] if id >= 0 else null


func squad() -> Array[Unit]:
	return _team(Unit.SQUAD)


func swarm() -> Array[Unit]:
	return _team(Unit.SWARM)


func _team(team: int) -> Array[Unit]:
	var out: Array[Unit] = []
	for u in units:
		if u.alive and u.team == team:
			out.append(u)
	return out


func is_visible(c: Vector2i) -> bool:
	return grid.in_bounds(c) and visible_tiles[grid.idx(c)] == 1


func is_explored(c: Vector2i) -> bool:
	return grid.in_bounds(c) and explored[grid.idx(c)] == 1


func move_reach(u: Unit) -> Dictionary:
	return grid.reach(u.tile, u.tu, u.crouched, u.id)


func shot_cost(u: Unit, mode: String) -> int:
	if not u.has_weapon():
		return 0
	if u.def.weapon.flat_tu > 0:
		return u.def.weapon.flat_tu
	return Rules.shot_tu(mode, u.max_tu)


## TU to turn and face `c`; free when it's already inside the cone.
func turn_cost_to(u: Unit, c: Vector2i) -> int:
	if Rules.in_cone(u.tile, u.facing, c, u.def.vision_half_angle):
		return 0
	return Rules.rotation_steps(u.facing, Rules.dir_toward(u.tile, c)) * Rules.TU_ROTATE_45


## Can `u` see tile `c` (range, cone or hearing distance, line of sight)? Light aside.
func sees_tile(u: Unit, c: Vector2i) -> bool:
	var d := Rules.dist(u.tile, c)
	if d > u.def.vision_range:
		return false
	if d > Rules.HEARING_RANGE and not Rules.in_cone(u.tile, u.facing, c, u.def.vision_half_angle):
		return false
	return grid.has_los(u.tile, c)


## Can `u` make out `other`: seen tile, and lit (or within hearing distance).
func can_spot(u: Unit, other: Unit) -> bool:
	if not sees_tile(u, other.tile):
		return false
	return grid.light_at(other.tile) >= Rules.PITCH_BELOW \
		or Rules.dist(u.tile, other.tile) <= Rules.HEARING_RANGE


## The hit chance and every modifier behind it, for the HUD's breakdown and the roll.
func hit_breakdown(u: Unit, target: Unit, mode: String) -> Dictionary:
	var w := u.def.weapon
	var parts: Array = [[w.display_name, w.accuracy]]
	if w.melee:
		if not Rules.in_cone(target.tile, target.facing, u.tile, target.def.vision_half_angle):
			parts.append(["Flanking", Rules.FLANK_BONUS])
	else:
		parts.append(["%s shot" % mode.capitalize(), int(Rules.MODE_ACCURACY.get(mode, 0))])
		if u.crouched:
			parts.append(["Crouched (steady)", Rules.CROUCHED_SHOOTER])
		var d := Rules.dist(u.tile, target.tile)
		if d > w.optimal_range:
			parts.append(["Range %d tiles" % roundi(d), -ceili((d - w.optimal_range) * Rules.RANGE_FALLOFF_PER_TILE)])
		var b := Rules.band(grid.light_at(target.tile))
		var lm: int = Rules.LIGHT_ACCURACY[b]
		if lm != 0:
			parts.append(["%s target" % Rules.band_name(b), lm])
		if has_cover(target.tile, u.tile):
			parts.append(["Target in cover", Rules.COVER])
	if target.crouched:
		parts.append(["Target crouched", Rules.CROUCHED_TARGET])
	var total := 0
	for p in parts:
		total += int(p[1])
	return {"chance": clampi(total, Rules.MIN_HIT, Rules.MAX_HIT), "raw": total, "parts": parts}


## Is there something solid beside `target` on the side facing `from`?
func has_cover(target: Vector2i, from: Vector2i) -> bool:
	var sx := signi(from.x - target.x)
	var sy := signi(from.y - target.y)
	if sx != 0 and grid.gives_cover(Vector2i(target.x + sx, target.y)):
		return true
	if sy != 0 and grid.gives_cover(Vector2i(target.x, target.y + sy)):
		return true
	return sx != 0 and sy != 0 and grid.gives_cover(Vector2i(target.x + sx, target.y + sy))


## Everything the HUD needs to show before a shot: can it fire, why not, chance, TU.
func shot_preview(u: Unit, target: Unit, mode: String) -> Dictionary:
	var reason := shot_block(u, target, mode, false)
	var out := {"ok": reason == "", "reason": reason, "chance": 0, "parts": [], "tu": 0}
	if u.has_weapon() and target != null and target.alive and u.def.weapon.modes.has(mode):
		var hb := hit_breakdown(u, target, mode)
		out["chance"] = hb["chance"]
		out["parts"] = hb["parts"]
		out["tu"] = shot_cost(u, mode) + turn_cost_to(u, target.tile)
	return out


# ------------------------------------------------------------------------------------------
# Commands
# ------------------------------------------------------------------------------------------

## Apply a command; returns the events it caused (one "refused" event if it wasn't allowed).
func exec(cmd: Dictionary) -> Array[Dictionary]:
	_events = []
	var err := can(cmd)
	if err != "":
		_emit("refused", {"reason": err, "cmd": cmd})
		return _events
	_run(cmd)
	_check_outcome()
	return _events


## For the swarm AI mid-phase: the same checks, events appended to the running list.
func ai_do(cmd: Dictionary) -> bool:
	if can(cmd) != "":
		return false
	_run(cmd)
	return true


## Why `cmd` can't be done now, or "" if it can.
func can(cmd: Dictionary) -> String:
	if outcome != "":
		return "The expedition is over."
	var t: String = cmd.get("t", "")
	if t == "end_turn":
		return "" if phase == Phase.PLAYER else "Not your turn."
	var u := unit(int(cmd.get("u", -1)))
	if u == null or not u.alive:
		return "No such unit."
	var acting := Unit.SQUAD if phase == Phase.PLAYER else Unit.SWARM
	if u.team != acting:
		return "Not that unit's turn."
	var to: Vector2i = cmd.get("to", NO_TILE)
	match t:
		"move":
			return _can_move(u, to)
		"face":
			var dir := int(cmd.get("dir", -1))
			if dir < 0 or dir > 7:
				return "No such facing."
			if dir == u.facing:
				return "Already facing that way."
			return _need(u, Rules.rotation_steps(u.facing, dir) * Rules.TU_ROTATE_45)
		"stance":
			return _need(u, Rules.TU_STANCE)
		"shoot":
			return shot_block(u, unit(int(cmd.get("target", -1))), str(cmd.get("mode", "snap")), false)
		"reload":
			if not u.has_weapon() or u.def.weapon.clip <= 0:
				return "Nothing to reload."
			if u.ammo >= u.def.weapon.clip:
				return "Already loaded."
			if u.spare_clips <= 0:
				return "No spare ammunition."
			return _need(u, Rules.TU_RELOAD)
		"repair":
			if u.pressure >= Rules.PRESSURE_MAX and not u.jammed:
				return "Gear already at full pressure."
			return _need(u, Rules.TU_FIELD_REPAIR)
		"patch":
			if u.repair_kit <= 0:
				return "No repair kit charges."
			var other := unit(int(cmd.get("target", -1)))
			if other == null or not other.alive or other.team != u.team:
				return "Patch up whom?"
			if Rules.chebyshev(u.tile, other.tile) > 1:
				return "Must stand beside them."
			if other.hp >= other.def.max_hp:
				return "Not hurt."
			return _need(u, Rules.TU_PATCH_UP)
		"hand_flare":
			if u.hand_flares <= 0:
				return "No hand flares left."
			return _need(u, Rules.TU_HAND_FLARE)
		"mortar":
			if u.mortar_flares <= 0:
				return "No mortar flares left."
			if not grid.in_bounds(to) or grid.get_t(to) == TacGrid.T.WALL:
				return "Can't land there."
			if Rules.dist(u.tile, to) > Rules.MORTAR_RANGE:
				return "Beyond the mortar's range."
			return _need(u, Rules.TU_MORTAR)
		"throw":
			var item := str(cmd.get("item", ""))
			if item == "pheromone" and u.pheromones <= 0:
				return "No pheromone grenades left."
			if item == "dynamite" and u.dynamite <= 0:
				return "No dynamite left."
			if item != "pheromone" and item != "dynamite":
				return "Throw what?"
			if not grid.in_bounds(to) or grid.get_t(to) == TacGrid.T.WALL:
				return "Can't throw there."
			if Rules.dist(u.tile, to) > Rules.THROW_RANGE:
				return "Too far to throw."
			if to != u.tile and not grid.has_los(u.tile, to):
				return "No clear throw."
			return _need(u, Rules.TU_THROW)
		"drill":
			if not u.def.can_drill:
				return "Only the Engineer carries the drill."
			if Rules.chebyshev(u.tile, to) != 1:
				return "Must stand beside the rock."
			var dt := grid.get_t(to)
			if dt != TacGrid.T.SOFT_ROCK and dt != TacGrid.T.BOULDER:
				return "The drill only bites soft rock and boulders."
			return _need(u, Rules.TU_DRILL)
		"door":
			if grid.get_t(to) != TacGrid.T.DOOR:
				return "No door there."
			if Rules.chebyshev(u.tile, to) != 1:
				return "Must stand beside the door."
			if grid.door_open[grid.idx(to)] == 1 and grid.occupant[grid.idx(to)] != -1:
				return "Something's in the doorway."
			return _need(u, Rules.TU_DOOR)
		"valve":
			if grid.get_t(to) != TacGrid.T.VALVE:
				return "No valve there."
			if Rules.chebyshev(u.tile, to) > 1:
				return "Must stand at the valve."
			return _need(u, Rules.TU_VALVE)
		"journal":
			if journal_carrier != -1 or journal_tile == NO_TILE:
				return "The journal is already taken."
			if Rules.chebyshev(u.tile, journal_tile) > 1:
				return "Must stand beside the journal."
			return _need(u, Rules.TU_JOURNAL)
		"lamp":
			if u.team != Unit.SQUAD:
				return "No lamp."
			return ""
	return "Unknown command."


func shot_block(u: Unit, target: Unit, mode: String, reaction: bool) -> String:
	if not u.has_weapon():
		return "Unarmed."
	var w := u.def.weapon
	if target == null or not target.alive or target.team == u.team:
		return "No target there."
	if not w.modes.has(mode):
		return "The %s can't fire %s." % [w.display_name, mode]
	if u.jammed:
		return "Weapon jammed: Field Repair."
	if w.clip > 0 and u.ammo <= 0:
		return "Out of ammunition: Reload."
	var d := Rules.dist(u.tile, target.tile)
	if w.melee:
		if not grid.melee_reach(u.tile, target.tile):
			return "Out of reach: stand beside it."
	else:
		if d > Rules.MAX_SHOT_RANGE:
			return "Out of range."
		if not grid.has_los(u.tile, target.tile):
			return "No line of sight."
		if Rules.band(grid.light_at(target.tile)) == Rules.Band.PITCH and d > Rules.HEARING_RANGE:
			return "Too dark to target beyond 2 tiles."
	if not reaction:
		if u.team == Unit.SQUAD and not spotted.has(target.id):
			return "Not spotted."
		if u.team == Unit.SWARM and not can_spot(u, target):
			return "Can't see it."
	var cost := shot_cost(u, mode) + (0 if reaction else turn_cost_to(u, target.tile))
	if u.tu < cost:
		return "Not enough TU (%d needed)." % cost
	return ""


func _need(u: Unit, cost: int) -> String:
	return "" if u.tu >= cost else "Not enough TU (%d needed)." % cost


func _can_move(u: Unit, to: Vector2i) -> String:
	if u.def.stationary:
		return "It can't move."
	if not grid.in_bounds(to) or not grid.walkable(to):
		return "Can't stand there."
	if to == u.tile:
		return "Already there."
	if not grid.is_free(to):
		return "Someone's there."
	var r := grid.reach(u.tile, u.tu, u.crouched, u.id)
	if grid.reach_cost(r, to) > u.tu:
		return "Not enough TU."
	return ""


func _run(cmd: Dictionary) -> void:
	var t: String = cmd.get("t", "")
	if t == "end_turn":
		_end_player_phase()
		return
	var u := unit(int(cmd.get("u", -1)))
	var to: Vector2i = cmd.get("to", NO_TILE)
	match t:
		"move":
			_do_move(u, to)
		"face":
			var dir := int(cmd["dir"])
			u.tu -= Rules.rotation_steps(u.facing, dir) * Rules.TU_ROTATE_45
			u.facing = dir
			if u.team == Unit.SQUAD:
				_refresh_vision()
			_emit("face", {"u": u.id, "facing": dir})
		"stance":
			u.tu -= Rules.TU_STANCE
			u.crouched = not u.crouched
			_emit("stance", {"u": u.id, "crouched": u.crouched})
		"shoot":
			_fire(u, unit(int(cmd["target"])), str(cmd.get("mode", "snap")), false)
		"reload":
			u.tu -= Rules.TU_RELOAD
			u.spare_clips -= 1
			u.ammo = u.def.weapon.clip
			_emit("reload", {"u": u.id})
		"repair":
			u.tu -= Rules.TU_FIELD_REPAIR
			u.pressure = Rules.PRESSURE_MAX
			u.jammed = false
			_emit("repair", {"u": u.id})
		"patch":
			var other := unit(int(cmd["target"]))
			u.tu -= Rules.TU_PATCH_UP
			u.repair_kit -= 1
			var healed := mini(Rules.PATCH_UP_HEAL, other.def.max_hp - other.hp)
			other.hp += healed
			_emit("patch", {"u": u.id, "target": other.id, "healed": healed})
		"hand_flare":
			u.tu -= Rules.TU_HAND_FLARE
			u.hand_flares -= 1
			_add_flare(u, u.tile, Rules.HAND_FLARE_RADIUS, false)
		"mortar":
			u.tu -= Rules.TU_MORTAR
			u.mortar_flares -= 1
			u.facing = Rules.dir_toward(u.tile, to) if to != u.tile else u.facing
			_add_flare(u, to, Rules.MORTAR_FLARE_RADIUS, true)
		"throw":
			_do_throw(u, str(cmd["item"]), to)
		"drill":
			u.tu -= Rules.TU_DRILL
			u.facing = Rules.dir_toward(u.tile, to)
			grid.set_t(to, TacGrid.T.RUBBLE)
			_emit("drill", {"u": u.id, "tile": to})
			_noise(to, Rules.NOISE_MELEE)
			_terrain_changed()
		"door":
			u.tu -= Rules.TU_DOOR
			var i := grid.idx(to)
			grid.door_open[i] = 1 - grid.door_open[i]
			_emit("door", {"u": u.id, "tile": to, "open": grid.door_open[i] == 1})
			_terrain_changed()
		"valve":
			u.tu -= Rules.TU_VALVE
			var linked: Array = grid.valves.get(to, [])
			var now_on := true
			for v in linked:
				if grid.vent_on.get(v, false):
					now_on = false
			for v in linked:
				grid.vent_on[v] = now_on
			grid.recompute_steam()
			_emit("valve", {"u": u.id, "tile": to, "vents": linked, "on": now_on})
			_refresh_vision()
		"journal":
			u.tu -= Rules.TU_JOURNAL
			journal_carrier = u.id
			_emit("journal", {"u": u.id, "tile": journal_tile})
			journal_tile = NO_TILE
		"lamp":
			u.lamp_on = not u.lamp_on
			_recompute_light()
			_refresh_vision()
			_emit("lamp", {"u": u.id, "on": u.lamp_on})


func _do_move(u: Unit, to: Vector2i) -> void:
	var r := grid.reach(u.tile, u.tu, u.crouched, u.id)
	var path := grid.path_to(r, to)
	var known := spotted.duplicate()
	for step in path:
		if not u.alive or outcome != "":
			return
		var cost := grid.step_cost(u.tile, step, u.crouched)
		if cost < 0 or cost > u.tu or not grid.is_free(step):
			return
		if grid.is_door_closed(step):
			grid.door_open[grid.idx(step)] = 1
			_emit("door", {"u": u.id, "tile": step, "open": true})
			_terrain_changed()
		var from := u.tile
		u.facing = Rules.dir_toward(from, step)
		_place(u, step)
		u.tu -= cost
		u.moved_this_phase = true
		if u.team == Unit.SQUAD:
			if u.lamp_on:
				_recompute_light()
			_refresh_vision()
		else:
			if u.def.glow > 0.0:
				_recompute_light()
			_refresh_spotted()
		_emit("move", {"u": u.id, "from": from, "to": step, "facing": u.facing,
			"seen": u.team == Unit.SQUAD or spotted.has(u.id)})
		if u.team == Unit.SWARM:
			_swarm_perceive(u)
		_check_reactions(u)
		if u.team == Unit.SQUAD and u.alive:
			# Contact: a soldier stops walking the moment a new creature comes into view.
			for id in spotted:
				if not known.has(id):
					_emit("contact", {"u": u.id, "enemy": id})
					return


func _place(u: Unit, c: Vector2i) -> void:
	grid.occupant[grid.idx(u.tile)] = -1
	u.tile = c
	grid.occupant[grid.idx(c)] = u.id


func _spawn(d: UnitDef, team: int, at: Vector2i) -> Unit:
	var u := Unit.create(units.size(), d, team, at)
	units.append(u)
	grid.occupant[grid.idx(at)] = u.id
	return u


func _add_flare(u: Unit, at: Vector2i, radius: float, mortar: bool) -> void:
	flares.append({"tile": at, "radius": radius, "turns": Rules.FLARE_TURNS,
		"max_turns": Rules.FLARE_TURNS, "born": stats["flares"]})
	stats["flares"] += 1
	_recompute_light()
	_refresh_spotted()
	_emit("flare", {"u": u.id, "from": u.tile, "tile": at, "radius": radius, "mortar": mortar})


func _do_throw(u: Unit, item: String, to: Vector2i) -> void:
	u.tu -= Rules.TU_THROW
	if to != u.tile:
		u.facing = Rules.dir_toward(u.tile, to)
	_emit("throw", {"u": u.id, "item": item, "from": u.tile, "tile": to})
	if item == "pheromone":
		u.pheromones -= 1
		_add_pheromone(to, Rules.PHEROMONE_LURE)
		_emit("pheromone", {"tile": to, "strength": pheromones.get(to, 0.0), "lure": true})
	else:
		u.dynamite -= 1
		_explode(to)


func _explode(at: Vector2i) -> void:
	var destroyed: Array[Vector2i] = []
	var r := ceili(Rules.DYNAMITE_RADIUS)
	for oy in range(-r, r + 1):
		for ox in range(-r, r + 1):
			var c := at + Vector2i(ox, oy)
			if not grid.in_bounds(c) or Vector2(ox, oy).length() > Rules.DYNAMITE_RADIUS:
				continue
			var t := grid.get_t(c)
			if t == TacGrid.T.SOFT_ROCK or t == TacGrid.T.BOULDER:
				grid.set_t(c, TacGrid.T.RUBBLE)
				destroyed.append(c)
	_emit("explosion", {"tile": at, "destroyed": destroyed})
	for u in units:
		if not u.alive:
			continue
		var d := Rules.dist(u.tile, at)
		if d > Rules.DYNAMITE_RADIUS:
			continue
		var dmg := float(Rules.DYNAMITE_DAMAGE) * (1.0 if d < 0.5 else Rules.DYNAMITE_EDGE)
		_hurt(u, maxi(1, roundi(dmg) - u.def.armour))
	_noise(at, Rules.NOISE_BLAST)
	_terrain_changed()


# ------------------------------------------------------------------------------------------
# Combat
# ------------------------------------------------------------------------------------------

func _fire(u: Unit, target: Unit, mode: String, reaction: bool) -> void:
	var w := u.def.weapon
	var cost := shot_cost(u, mode)
	if not reaction:
		cost += turn_cost_to(u, target.tile)
	u.tu -= cost
	u.facing = Rules.dir_toward(u.tile, target.tile)
	_emit("aim", {"u": u.id, "target": target.id, "facing": u.facing, "mode": mode, "reaction": reaction})
	var jam := Rules.jam_chance(u.pressure)
	if jam > 0 and rng.randi_range(1, 100) <= jam:
		u.jammed = true
		_emit("jam", {"u": u.id})
		return
	var rounds := 1
	if mode == "burst":
		rounds = rng.randi_range(w.burst_min, w.burst_max)
	for i in rounds:
		if w.clip > 0:
			if u.ammo <= 0:
				_emit("click", {"u": u.id})
				break
			u.ammo -= 1
		u.pressure = maxi(0, u.pressure - w.pressure_per_shot)
		var hb := hit_breakdown(u, target, mode)
		var chance: int = hb["chance"]
		var hit := rng.randi_range(1, 100) <= chance
		stats["shots"] += 1
		_emit("shot", {"u": u.id, "target": target.id, "from": u.tile, "to": target.tile,
			"hit": hit, "chance": chance, "round": i, "rounds": rounds, "melee": w.melee,
			"mode": mode, "reaction": reaction})
		if hit:
			stats["hits"] += 1
			_hurt(target, _damage_roll(u, target))
			if target.alive and w.poison_turns > 0:
				target.poison_turns = w.poison_turns
				target.poison_damage = w.poison_damage
				_emit("poisoned", {"u": target.id})
		if not target.alive:
			break
	if mode == "burst" and target.alive:
		target.pinned = true
		_emit("pinned", {"u": target.id})
	_noise(u.tile, Rules.NOISE_MELEE if w.melee else Rules.NOISE_GUNFIRE)


func _damage_roll(u: Unit, target: Unit) -> int:
	var base := float(u.def.weapon.damage) * rng.randf_range(1.0 - Rules.DAMAGE_SPREAD, 1.0 + Rules.DAMAGE_SPREAD)
	var armour := target.def.armour
	if target.def.frontal_armour > 0 and Rules.in_cone(target.tile, target.facing, u.tile, target.def.vision_half_angle):
		armour += target.def.frontal_armour
	return maxi(1, roundi(base) - armour)


func _hurt(u: Unit, dmg: int) -> void:
	if not u.alive:
		return
	u.hp = maxi(0, u.hp - dmg)
	_emit("hurt", {"u": u.id, "dmg": dmg, "hp": u.hp})
	if u.dormant:
		u.dormant = false
		_emit("wake", {"u": u.id})
	if u.hp <= 0:
		_kill(u)


func _kill(u: Unit) -> void:
	grid.occupant[grid.idx(u.tile)] = -1
	_emit("death", {"u": u.id, "tile": u.tile})
	stats["kills" if u.team == Unit.SWARM else "lost"] += 1
	spotted.erase(u.id)
	if journal_carrier == u.id:
		journal_carrier = -1
		journal_tile = u.tile
		_emit("journal_dropped", {"tile": u.tile})
	if u.lamp_on or u.def.glow > 0.0:
		_recompute_light()
	if u.team == Unit.SQUAD:
		_refresh_vision()
	else:
		_refresh_spotted()
	_check_outcome()


## Overwatch (GDD 2.3, normalised): after every step a mover takes, each opposing unit on
## Overwatch that can see it compares reaction scores; the higher fires a snap shot first.
func _check_reactions(mover: Unit) -> void:
	for r in units:
		if not mover.alive or outcome != "":
			return
		if not r.alive or r.team == mover.team or not r.overwatch or r.dormant or r.pinned:
			continue
		if not can_spot(r, mover):
			continue
		if shot_block(r, mover, "snap", true) != "":
			continue
		var rs := Rules.reaction_score(r.def.perception, r.tu, r.max_tu)
		var ms := Rules.reaction_score(mover.def.agility, mover.tu, mover.max_tu)
		var fires := rs > ms
		var key := "%d>%d" % [r.id, mover.id]
		if fires or not _reaction_logged.has(key):
			_reaction_logged[key] = true
			_emit("reaction", {"u": r.id, "target": mover.id, "score": rs, "against": ms, "fires": fires})
		if fires:
			stats["reactions"] += 1
			_fire(r, mover, "snap", true)


func _noise(at: Vector2i, radius: float) -> void:
	for e in units:
		if e.alive and e.dormant and Rules.dist(e.tile, at) <= radius:
			e.dormant = false
			_emit("wake", {"u": e.id})


# ------------------------------------------------------------------------------------------
# Turns
# ------------------------------------------------------------------------------------------

func _end_player_phase() -> void:
	var watching: Array[int] = []
	for s in squad():
		s.overwatch = s.has_weapon() and not s.pinned and s.tu >= Rules.overwatch_threshold(s.max_tu)
		if s.overwatch:
			watching.append(s.id)
	_emit("overwatch", {"units": watching})
	phase = Phase.ENEMY
	_reaction_logged.clear()
	_emit("phase", {"phase": "enemy", "turn": turn})
	_enemy_phase()
	if outcome == "":
		_start_player_phase()


func _enemy_phase() -> void:
	_decay_pheromones()
	for e in swarm():
		e.moved_this_phase = false
		e.marked_this_phase = false
		e.overwatch = false
		e.tu = e.max_tu / 2 if e.pinned else e.max_tu
		e.pinned = false
		_tick_poison(e)
	for e in swarm():
		if e.dormant and _rouses(e):
			e.dormant = false
			_emit("wake", {"u": e.id})
	for e in swarm():
		if outcome != "":
			return
		if e.alive:
			SwarmAI.act(self, e)
	_hive_turn()
	for e in swarm():
		e.overwatch = not e.dormant and e.has_weapon() and e.tu >= Rules.overwatch_threshold(e.max_tu)
	_tick_flares()


func _start_player_phase() -> void:
	turn += 1
	phase = Phase.PLAYER
	_reaction_logged.clear()
	for s in squad():
		s.tu = (s.max_tu + 1) / 2 if s.pinned else s.max_tu
		s.pinned = false
		s.overwatch = false
		s.moved_this_phase = false
		s.pressure = mini(Rules.PRESSURE_MAX, s.pressure + Rules.PRESSURE_REGEN)
		_tick_poison(s)
	if outcome != "":
		return
	_refresh_vision()
	pings.clear()
	var listener: Unit = null
	for s in squad():
		if s.def.seismograph:
			listener = s
	if listener != null:
		for e in swarm():
			if e.moved_this_phase and not spotted.has(e.id) \
					and Rules.dist(listener.tile, e.tile) <= Rules.SEISMOGRAPH_RANGE:
				pings.append(e.tile)
	_emit("phase", {"phase": "player", "turn": turn, "pings": pings.duplicate()})


## A dormant creature wakes if it sees the squad, or a pheromone trail is within reach.
func _rouses(e: Unit) -> bool:
	for s in squad():
		if can_spot(e, s):
			return true
	for p in pheromones:
		if Rules.dist(e.tile, p) <= Rules.AGGRO_RANGE:
			return true
	return false


func _tick_poison(u: Unit) -> void:
	if u.poison_turns <= 0 or not u.alive:
		return
	u.poison_turns -= 1
	_emit("poison", {"u": u.id, "dmg": u.poison_damage})
	_hurt(u, u.poison_damage)


func _tick_flares() -> void:
	if flares.is_empty():
		return
	var kept: Array[Dictionary] = []
	for f in flares:
		f["turns"] = int(f["turns"]) - 1
		if int(f["turns"]) > 0:
			kept.append(f)
	flares = kept
	_recompute_light()
	_refresh_spotted()
	_emit("light", {})


func _hive_turn() -> void:
	var hive: Unit = null
	var alert := not pheromones.is_empty()
	for e in swarm():
		if e.def.stationary:
			hive = e
		elif not e.dormant:
			alert = true
	if hive == null or not alert:
		return
	hive_alert_turns += 1
	if hive_alert_turns % Rules.HIVE_SPAWN_EVERY != 0 or hive_spawned >= Rules.HIVE_SPAWN_CAP:
		return
	for d in Rules.DIRS:
		var c := hive.tile + d
		if grid.is_free(c):
			var u := _spawn(defs["crawler"], Unit.SWARM, c)
			u.facing = Rules.dir_toward(hive.tile, c)
			u.tu = 0
			hive_spawned += 1
			_refresh_spotted()
			_emit("spawn", {"u": u.id, "tile": c, "seen": spotted.has(u.id)})
			return


# ------------------------------------------------------------------------------------------
# The swarm's senses
# ------------------------------------------------------------------------------------------

## GDD 6.2.1: a creature that sees the squad marks its own tile with pheromone.
func _swarm_perceive(e: Unit) -> void:
	if e.marked_this_phase or not e.alive or e.def.stationary:
		return
	for s in squad():
		if can_spot(e, s):
			e.marked_this_phase = true
			_add_pheromone(e.tile, Rules.PHEROMONE_SIGHTING)
			_emit("pheromone", {"tile": e.tile, "strength": pheromones[e.tile], "lure": false})
			return


func _add_pheromone(at: Vector2i, amount: float) -> void:
	pheromones[at] = minf(Rules.PHEROMONE_CAP, float(pheromones.get(at, 0.0)) + amount)


func _decay_pheromones() -> void:
	for k in pheromones.keys():
		var v: float = pheromones[k] * Rules.PHEROMONE_DECAY
		if v < Rules.PHEROMONE_FLOOR:
			pheromones.erase(k)
		else:
			pheromones[k] = v


## Pheromone summed within a couple of tiles of `at`: the GDD's "density".
func pheromone_density(at: Vector2i) -> float:
	var total := 0.0
	for p in pheromones:
		if Rules.dist(at, p) <= Rules.PHEROMONE_DENSITY_RADIUS:
			total += float(pheromones[p])
	return total


# ------------------------------------------------------------------------------------------
# Light and vision
# ------------------------------------------------------------------------------------------

func _terrain_changed() -> void:
	_recompute_static_light()
	_recompute_light()
	_refresh_vision()


func _recompute_static_light() -> void:
	var n := grid.width * grid.height
	_static_light.resize(n)
	_static_light.fill(Rules.AMBIENT_LIGHT)
	for i in n:
		if grid.terrain[i] == TacGrid.T.FUNGUS:
			_add_light(_static_light, grid.cell(i), Rules.FUNGUS_POWER, Rules.FUNGUS_RADIUS)


func _recompute_light() -> void:
	var l := _static_light.duplicate()
	for u in units:
		if not u.alive:
			continue
		if u.team == Unit.SQUAD and u.lamp_on:
			_add_light(l, u.tile, Rules.LAMP_POWER, Rules.LAMP_RADIUS)
		if u.def.glow > 0.0:
			_add_light(l, u.tile, u.def.glow, 1.5)
	for f in flares:
		var power := Rules.FLARE_POWER * float(f["turns"]) / float(f["max_turns"])
		_add_light(l, f["tile"], power, f["radius"])
	for i in l.size():
		l[i] = minf(1.0, l[i])
	grid.light = l
	_light_dirty = true


func _add_light(arr: PackedFloat32Array, src: Vector2i, power: float, radius: float) -> void:
	var r := ceili(radius)
	for oy in range(-r, r + 1):
		for ox in range(-r, r + 1):
			var c := src + Vector2i(ox, oy)
			if not grid.in_bounds(c):
				continue
			var d := Vector2(ox, oy).length()
			if d > radius or not grid.has_light_path(src, c):
				continue
			arr[grid.idx(c)] += Rules.falloff(power, radius, d)


func _refresh_vision() -> void:
	visible_tiles.fill(0)
	for s in squad():
		var r := ceili(s.def.vision_range)
		for oy in range(-r, r + 1):
			for ox in range(-r, r + 1):
				var c := s.tile + Vector2i(ox, oy)
				if not grid.in_bounds(c):
					continue
				var i := grid.idx(c)
				if visible_tiles[i] == 1:
					continue
				if sees_tile(s, c):
					visible_tiles[i] = 1
					explored[i] = 1
	_vision_dirty = true
	_refresh_spotted()


func _refresh_spotted() -> void:
	spotted.clear()
	var team := squad()
	for e in swarm():
		if visible_tiles[grid.idx(e.tile)] == 0:
			continue
		var seen := grid.light_at(e.tile) >= Rules.PITCH_BELOW
		if not seen:
			for s in team:
				if Rules.dist(s.tile, e.tile) <= Rules.HEARING_RANGE and grid.has_los(s.tile, e.tile):
					seen = true
					break
		if seen:
			spotted[e.id] = true


# ------------------------------------------------------------------------------------------
# Outcome
# ------------------------------------------------------------------------------------------

func _check_outcome() -> void:
	if outcome != "":
		return
	var team := squad()
	if team.is_empty():
		_finish("lost")
		return
	if swarm().is_empty():
		_finish("exterminated")
		return
	if journal_carrier == -1:
		return
	for s in team:
		if not lift_tiles.has(s.tile):
			return
	_finish("extracted")


func _finish(result: String) -> void:
	outcome = result
	phase = Phase.OVER
	_emit("outcome", {"outcome": result})


func _emit(type: String, data: Dictionary) -> void:
	data["type"] = type
	data["spotted"] = spotted.keys()
	if _vision_dirty:
		data["vis"] = visible_tiles.duplicate()
		data["exp"] = explored.duplicate()
		_vision_dirty = false
	if _light_dirty:
		data["light"] = grid.light.duplicate()
		_light_dirty = false
	_events.append(data)
