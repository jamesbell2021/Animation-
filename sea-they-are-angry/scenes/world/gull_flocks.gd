class_name GullFlocks
extends Node3D
## The gulls. By day they're everywhere: a colony on Gull Rock standing about its
## ledges and nests, flocks wheeling over the islands and the sea, and a few loafing on
## the beaches and the jetty. At dusk they go off out to sea, and they stay away at
## night and in a storm, coming back at dawn once it's calm enough.
##
## They don't like keepers: one that comes too close sends them up calling, to circle
## and settle again further off. Take their eggs and the colony mobs you, wheeling and
## swooping and screaming (no harm done). They're each machine's own on the LAN, like
## the weather.

## Stormier than this (Weather.storm_now) and they're gone.
const STORMY := 0.32
const COLONY := 14
const LOAFERS := 5
const FLOCKS := 3
const PER_FLOCK := 6
## A keeper this close puts a standing gull up (sprinting, further).
const FLUSH := 3.4
const FLUSH_SPRINT := 5.0
## How long a mob over a robbed nest lasts, and how far it draws birds from.
const MOB_TIME := 9.0
const MOB_FROM := 16.0
const CALL_EVERY := Vector2(1.2, 3.8)
## Out where they go at dusk, and come in from at dawn.
const AWAY := 70.0
const MIDDLE := Vector3(22.0, 0.0, -12.0)

var birds: Array[Gull] = []
var present := false
## Where a gull can stand: [position, yaw, island, taken by a gull or null].
var perches: Array = []
var _flocks: Array = []
var _check_t := 0.0
var _call_t := 1.0
var _shuffle_t := 4.0
var _mob_t := 0.0
var _mob_at := Vector3.ZERO
var _voices: Array[AudioStreamPlayer3D] = []
var _next_voice := 0

func _ready() -> void:
	name = "Gulls"
	for i in 3:
		var p := AudioStreamPlayer3D.new()
		p.bus = "SFX"
		p.unit_size = 16.0
		p.max_distance = 70.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(p)
		_voices.append(p)
	for i in FLOCKS:
		_flocks.append({"c": Vector3.ZERO, "t": randf() * TAU, "i": i})
	var n := COLONY + LOAFERS + FLOCKS * PER_FLOCK
	for i in n:
		var g := Gull.new()
		g.name = "Gull%d" % i
		if i < COLONY:
			g.role = "colony"
		elif i < COLONY + LOAFERS:
			g.role = "loafer"
		else:
			g.role = "flock"
			g.flock = (i - COLONY - LOAFERS) % FLOCKS
		add_child(g)
		birds.append(g)
	for nest in get_tree().get_nodes_in_group("gull_nests"):
		nest.robbed.connect(mob)

## Add the places a gull can stand (main.gd: Gull Rock's ledges and nests, the beaches,
## the jetty's posts).
func add_perch(at: Vector3, yaw: float, island: int) -> void:
	perches.append([at, yaw, island, null])

## Whether the gulls are about now.
static func wanted() -> bool:
	return (Cycle.phase == Cycle.Phase.DAY or Cycle.phase == Cycle.Phase.DAWN) and Weather.storm_now <= STORMY

func _process(delta: float) -> void:
	var want := wanted()
	if want != present:
		present = want
		if present:
			_arrive()
		else:
			_depart()
	if not present:
		return
	_flock_centres(delta)
	_check_t -= delta
	if _check_t <= 0.0:
		_check_t = 0.15
		_flush()
	_mob_t -= delta
	if _mob_t > 0.0:
		_mobbing()
	_shuffle_t -= delta
	if _shuffle_t <= 0.0:
		_shuffle_t = randf_range(2.5, 5.0)
		_shuffle()
	for g in birds:
		if g.mode == Gull.Mode.FLY and g.task == "orbit" and g.timer <= 0.0 and g.role != "flock" and _mob_t <= 0.0:
			# Done circling: settle again.
			_settle(g)
	_call_t -= delta
	if _call_t <= 0.0:
		_call_t = randf_range(CALL_EVERY.x, CALL_EVERY.y) * (0.4 if _mob_t > 0.0 else 1.0)
		var flying: Array = birds.filter(func(b: Gull) -> bool: return b.mode != Gull.Mode.GONE)
		if not flying.is_empty():
			var g: Gull = flying[randi() % flying.size()]
			_call(g.global_position, "gull_alarm" if _mob_t > 0.0 else ("gull_laugh" if randf() < 0.35 else "gull_call"))

# Come in from out at sea, staggered, each to its place.
func _arrive() -> void:
	for p in perches:
		p[3] = null
	for g in birds:
		var a := randf() * TAU
		g.appear(MIDDLE + Vector3(sin(a) * AWAY, randf_range(14.0, 24.0), cos(a) * AWAY))
		if g.role == "flock":
			_join_flock(g)
		else:
			# Circle in for a while first, then settle.
			g.orbit(_home_centre(g), randf_range(5.0, 9.0), randf_range(0.35, 0.6) * (1.0 if randf() < 0.5 else -1.0))
			g.timer = randf_range(4.0, 14.0)

func _depart() -> void:
	for p in perches:
		p[3] = null
	for g in birds:
		var away := g.global_position - MIDDLE
		away.y = 0.0
		if away.length() < 0.1:
			away = Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1))
		g.leave(away.rotated(Vector3.UP, randf_range(-0.6, 0.6)))

func _home_centre(g: Gull) -> Vector3:
	if g.role == "colony":
		return Vector3(Terrain.ISLET_C.x, Terrain.ISLET_HEIGHT + 6.0, Terrain.ISLET_C.y)
	return Vector3(14.0, 7.0, -4.0)

func _join_flock(g: Gull) -> void:
	var f: Dictionary = _flocks[g.flock]
	g.orbit(f["c"], randf_range(4.0, 9.0), randf_range(0.3, 0.55) * (1.0 if g.flock % 2 == 0 else -1.0))
	g.orbit_c = f["c"]

# The flocks drift slowly: one over the main island's coast, one over the holm, one
# out over Gull Rock and the channel.
func _flock_centres(delta: float) -> void:
	for f in _flocks:
		f["t"] = float(f["t"]) + delta * 0.035
		var t: float = f["t"]
		var c: Vector3
		match int(f["i"]):
			0:
				c = Vector3(sin(t) * 14.0, 11.0 + sin(t * 2.7) * 2.0, cos(t * 1.3) * 12.0)
			1:
				c = Vector3(Terrain.HOLM_C.x + sin(t * 1.2) * 10.0, 12.0 + cos(t * 2.1) * 2.0, Terrain.HOLM_C.y + cos(t) * 9.0)
			_:
				c = Vector3(Terrain.ISLET_C.x + sin(t * 0.8) * 9.0, 13.0 + sin(t * 1.7) * 3.0, -24.0 + cos(t * 1.1) * 9.0)
		f["c"] = c
	for g in birds:
		if g.role == "flock" and g.mode == Gull.Mode.FLY and g.task == "orbit":
			g.orbit_c = _flocks[g.flock]["c"]

# Standing gulls with a keeper too close go up.
func _flush() -> void:
	var keepers := get_tree().get_nodes_in_group("player")
	for g in birds:
		if not g.is_perched():
			continue
		for k in keepers:
			if not (k is Player) or not k.visible:
				continue
			var near := FLUSH_SPRINT if Vector2(k.velocity.x, k.velocity.z).length() > Player.SPEED + 0.5 else FLUSH
			if Geo.flat_dist(k.global_position, g.global_position) < near and absf(k.global_position.y - g.global_position.y) < 3.0:
				_put_up(g, k.global_position)
				break

func _put_up(g: Gull, from: Vector3) -> void:
	_free_perch(g)
	var c := g.global_position + Vector3(0.0, randf_range(4.0, 7.0), 0.0)
	var away := g.global_position - from
	away.y = 0.0
	c += away.normalized() * 2.0
	g.orbit(c, randf_range(3.0, 6.0), randf_range(0.5, 0.8) * (1.0 if randf() < 0.5 else -1.0))
	g.timer = randf_range(7.0, 14.0)
	if randf() < 0.6:
		_call(g.global_position, "gull_alarm")

func _free_perch(g: Gull) -> void:
	if g.perch_id >= 0 and g.perch_id < perches.size() and perches[g.perch_id][3] == g:
		perches[g.perch_id][3] = null
	for p in perches:
		if p[3] == g:
			p[3] = null

# Land somewhere free on its own island, as far from the keepers as it can find.
func _settle(g: Gull) -> void:
	var island := 2 if g.role == "colony" else 0
	var keepers := get_tree().get_nodes_in_group("player")
	var best := -1
	var best_score := -INF
	for i in perches.size():
		var p: Array = perches[i]
		if p[3] != null or int(p[2]) != island and not (g.role == "loafer" and int(p[2]) != 2):
			continue
		var clear := 99.0
		for k in keepers:
			if k is Node3D:
				clear = minf(clear, Geo.flat_dist(k.global_position, p[0]))
		if clear < FLUSH + 2.0:
			continue
		var score := minf(clear, 12.0) + randf() * 6.0 - g.global_position.distance_to(p[0]) * 0.05
		if score > best_score:
			best_score = score
			best = i
	if best < 0:
		# Nowhere quiet: keep circling a while longer.
		g.timer = randf_range(5.0, 9.0)
		return
	perches[best][3] = g
	g.land_at(perches[best][0], float(perches[best][1]) + randf_range(-0.6, 0.6), best)

# Now and then one standing gull flies a circuit and lands somewhere else, and a flock
# bird and a loafer change places, so the place stays alive.
func _shuffle() -> void:
	var standing: Array = birds.filter(func(b: Gull) -> bool: return b.is_perched())
	if standing.is_empty():
		return
	var g: Gull = standing[randi() % standing.size()]
	_free_perch(g)
	g.orbit(g.global_position + Vector3(0.0, randf_range(5.0, 9.0), 0.0), randf_range(4.0, 8.0), randf_range(0.4, 0.7) * (1.0 if randf() < 0.5 else -1.0))
	g.timer = randf_range(6.0, 15.0)

## Someone's taken eggs here: the colony goes up and mobs them.
func mob(at: Vector3) -> void:
	if not present:
		return
	_mob_t = MOB_TIME
	_mob_at = at
	for g in birds:
		if g.mode == Gull.Mode.GONE or g.role == "flock":
			continue
		if g.global_position.distance_to(at) > MOB_FROM:
			continue
		_free_perch(g)
		g.orbit(at + Vector3(0.0, randf_range(3.5, 6.0), 0.0), randf_range(2.5, 5.0), randf_range(0.7, 1.1) * (1.0 if randf() < 0.5 else -1.0))
		g.timer = MOB_TIME + randf_range(0.0, 3.0)
	_call(at + Vector3(0.0, 3.0, 0.0), "gull_alarm")

func _mobbing() -> void:
	# Every so often one of them swoops at the nearest keeper.
	if randf() > 0.04:
		return
	var victim: Node3D = null
	var best := 14.0
	for k in get_tree().get_nodes_in_group("player"):
		if k is Node3D and k.global_position.distance_to(_mob_at) < best:
			best = k.global_position.distance_to(_mob_at)
			victim = k
	if victim == null:
		return
	var circling: Array = birds.filter(func(b: Gull) -> bool: return b.mode == Gull.Mode.FLY and b.task == "orbit" and b.role == "colony")
	if circling.is_empty():
		return
	var g: Gull = circling[randi() % circling.size()]
	g.dive(victim)
	_call(g.global_position, "gull_alarm")

func _call(at: Vector3, key: String) -> void:
	var p := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	p.stream = Audio.stream(key)
	p.pitch_scale = randf_range(0.9, 1.12)
	p.volume_db = -9.0 if key != "gull_alarm" else -6.0
	p.global_position = at
	p.play()

## How many gulls are out and about (not gone off to sea).
func about() -> int:
	var n := 0
	for g in birds:
		if g.mode != Gull.Mode.GONE:
			n += 1
	return n
