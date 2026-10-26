extends Node
## Spawns the night's creatures from points in the water, driven by Cycle.night_progress.

const STAGGER := 0.3
const JITTER := 1.0
const SPAWN_Y := -0.6
# The water churns at a landing this long before the first creature surfaces,
# so the keeper at the lamp has time to swing the beam round.
const OMEN_TIME := 4.0
const OMEN_EVERY := 0.6
# From this night, big groups split between two beaches.
const SPLIT_FROM_NIGHT := 2
const SPLIT_MIN := 3
# Rows are [t, kind, count] or [t, kind, count, "opp"]: t is the fraction of the night,
# kind B Bloated, S Squid, C Crab, M Smotherer; "opp" lands on a different beach from the night's
# first group. Waves come early enough that the last still reaches the fences before
# dawn: the walk from a beach to the lighthouse is close to a minute. The Eel is
# scheduled separately (see eel_night).
const NIGHT_TABLES := {
	1: [[0.06, "B", 2], [0.32, "B", 2], [0.58, "B", 3]],
	2: [[0.06, "B", 2], [0.24, "S", 2, "opp"], [0.44, "B", 3], [0.62, "S", 2, "opp"]],
	3: [[0.06, "B", 3], [0.20, "C", 1], [0.38, "S", 2, "opp"], [0.55, "B", 3], [0.68, "S", 2, "opp"]],
	4: [[0.04, "S", 2], [0.12, "B", 3], [0.28, "C", 1], [0.36, "M", 1, "opp"], [0.44, "B", 4], [0.56, "S", 3, "opp"], [0.68, "C", 1]],
	5: [[0.06, "B", 3], [0.20, "C", 1], [0.32, "S", 3, "opp"], [0.52, "M", 1, "opp"], [0.62, "B", 4]],
	6: [[0.04, "B", 4], [0.16, "S", 3, "opp"], [0.28, "C", 2], [0.36, "M", 1], [0.44, "B", 4], [0.56, "S", 3, "opp"], [0.68, "C", 1]],
	7: [[0.04, "S", 3], [0.12, "B", 4], [0.24, "C", 2], [0.32, "M", 1, "opp"], [0.40, "B", 5], [0.52, "S", 4, "opp"], [0.60, "M", 1], [0.68, "C", 2]],
	8: [[0.04, "B", 4], [0.16, "C", 2], [0.28, "S", 4, "opp"], [0.50, "M", 2, "opp"], [0.60, "B", 5], [0.72, "S", 3, "opp"]],
}
const EEL_AT := 0.42
# The second and later Bloated groups of a night (from night 2) make for the homestead.
const RAID_FROM_NIGHT := 2
# While the Eel is about, other landings shrink to a quarter.
const EEL_RATE := 0.25
# The camp: from night 2 every third group of Bloated, Squid or Crabs lands on the holm's
# beaches instead and makes for the camp; from night 5, every other one. They come out of
# the night's table, so the main island sees that many fewer. Nothing is sent once the
# camp has fallen: it all comes for the light again.
const HOLM_FROM_NIGHT := 2
const HOLM_EVERY := 3
const HOLM_EVERY_LATE := 2
const HOLM_LATE_FROM := 5
const HOLM_KINDS := ["B", "S", "C"]
const WARNINGS := {
	"B": "Something stirs in the water",
	"S": "Something skitters in the shallows",
	"C": "Something heavy drags itself ashore",
	"M": "Something pale crawls from the sea",
}

## A group is about to come out of the sea at these landing points.
signal wave_incoming(points: Array, count: int)
## The same, with what kind it is and whether it's making for the homestead (for the warning text).
signal group_warning(kind: String, points: Array, raid: bool)
## A group is coming ashore on the holm, for the camp.
signal holm_warning(kind: String, points: Array)

var points: Array[Vector3] = []
## Landing points on the holm's beaches (two to a beach), for the camp's raiders.
var holm_points: Array[Vector3] = []
var enemies_root: Node
var lighthouse: Node3D

var _queue: Array[Dictionary] = []
# Individual spawns waiting out their stagger delay: {at: Vector3, delay: float, kind, raid}.
var _pending: Array[Dictionary] = []
# Landings about to happen: {at: Vector3, left: float, tick: float}.
var _omens: Array[Dictionary] = []
var _first_point := -1
var _bloated_groups := 0

func _ready() -> void:
	Cycle.phase_changed.connect(_on_phase_changed)
	Cycle.night_progress.connect(_on_night_progress)
	Events.run_ended.connect(_on_run_ended)

## The Eel comes on night 5 then every third night (solo: 6, 9, 12...); a night early when the sea is very angry.
static func eel_night(n: int, keepers: int, anger: int) -> bool:
	var first := 6 if keepers <= 1 else 5
	var m := n + (1 if anger >= 6 else 0)
	return m >= first and (m - first) % 3 == 0

func night_table(n: int) -> Array[Dictionary]:
	var rows: Array = NIGHT_TABLES.get(mini(n, 8), NIGHT_TABLES[8])
	if n >= 9:
		rows = NIGHT_TABLES[7]
	var extra := 0
	if n >= 9:
		extra += floori((n - 7) / 2.0)
	extra += floori(Anger.value / 3.0)
	var out: Array[Dictionary] = []
	for row in rows:
		out.append({"t": float(row[0]), "kind": String(row[1]), "count": int(row[2]) + extra, "opp": row.size() > 3, "point": -1})
	# The last night before the relief boat: the sea throws everything it has.
	if not Run.endless and n == Rescue.night():
		for e in out:
			e["count"] = maxi(int(e["count"]) + 1, roundi(float(e["count"]) * Rescue.LAST_NIGHT_SURGE))
	# Every so many of the groups that can, to the holm (counted in order through the night).
	var every := HOLM_EVERY_LATE if n >= HOLM_LATE_FROM else HOLM_EVERY
	var k := 0
	for e in out:
		e["holm"] = false
		if n >= HOLM_FROM_NIGHT and HOLM_KINDS.has(e["kind"]):
			k += 1
			e["holm"] = k % every == 0
	if eel_night(n, Players.humans(), Anger.value):
		out.append({"t": EEL_AT, "kind": "E", "count": 1, "opp": false, "point": -1, "holm": false})
	return out

## Whether there's anything left on the holm to raid.
func camp_standing() -> bool:
	return not holm_points.is_empty() and Enemy.nearest_camp(Vector3.ZERO) != null

func queue_size() -> int:
	return _queue.size() + _pending.size()

func _on_phase_changed(p: int) -> void:
	if p == Cycle.Phase.NIGHT:
		_first_point = -1
		_bloated_groups = 0
		_queue = night_table(Run.night)
		_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["t"] < b["t"])
	elif p == Cycle.Phase.DAWN:
		_queue.clear()
		_pending.clear()
		_omens.clear()

func _on_night_progress(t: float) -> void:
	# On a LAN client the creatures come from the host.
	if Net.is_client():
		return
	while not _queue.is_empty() and float(_queue[0]["t"]) <= t:
		var entry: Dictionary = _queue.pop_front()
		_queue_group(entry)

func _queue_group(entry: Dictionary) -> void:
	if points.is_empty():
		return
	var kind: String = entry.get("kind", "B")
	if entry.get("holm", false) and camp_standing():
		_queue_holm(entry)
		return
	var idx: int = entry["point"]
	if idx < 0 or idx >= points.size():
		idx = randi() % points.size()
		# "opp": a beach other than the night's first group's (points come in pairs, one pair per beach).
		if entry.get("opp", false) and _first_point >= 0 and points.size() > 2:
			while idx / 2 == _first_point / 2:
				idx = randi() % points.size()
	if _first_point < 0:
		_first_point = idx
	if kind == "E":
		_spawn_eel(points[idx])
		return
	var count := group_size(int(entry["count"]))
	if eel_active():
		count = maxi(1, roundi(count * EEL_RATE))
	var raid := false
	if kind == "B":
		_bloated_groups += 1
		raid = Run.night >= RAID_FROM_NIGHT and _bloated_groups % 2 == 0 and Enemy.nearest_home(Vector3.ZERO) != null
	var landings: Array = [points[idx]]
	if kind == "B" and not raid and Run.night >= SPLIT_FROM_NIGHT and count >= SPLIT_MIN and points.size() > 2:
		# A second landing at a different beach.
		var other := (idx + 2 + 2 * (randi() % maxi(1, points.size() / 2 - 1))) % points.size()
		landings.append(points[other])
	wave_incoming.emit(landings, count)
	group_warning.emit(kind, landings, raid)
	for l in landings:
		_omens.append({"at": l, "left": OMEN_TIME, "tick": 0.0})
	for i in count:
		_pending.append({"at": landings[i % landings.size()], "delay": OMEN_TIME + STAGGER * float(i), "kind": kind, "raid": raid})

# A group for the camp: one of the holm's beaches, all of them making for the camp.
func _queue_holm(entry: Dictionary) -> void:
	var kind: String = entry.get("kind", "B")
	var idx := randi() % holm_points.size()
	var count := group_size(int(entry["count"]))
	if eel_active():
		count = maxi(1, roundi(count * EEL_RATE))
	var landings: Array = [holm_points[idx]]
	wave_incoming.emit(landings, count)
	holm_warning.emit(kind, landings)
	_omens.append({"at": landings[0], "left": OMEN_TIME, "tick": 0.0})
	for i in count:
		_pending.append({"at": landings[0], "delay": OMEN_TIME + STAGGER * float(i), "kind": kind, "raid": false, "camp": true})

## How many come ashore for a row of the table: more with more people playing (x1.5 per
## extra keeper, halves rounded up), and fewer or more with the difficulty.
func group_size(base: int) -> int:
	return maxi(1, roundi(float(base) * (1.0 + 0.5 * float(Players.humans() - 1)) * Difficulty.creatures()))

## True while an Eel encounter is under way.
func eel_active() -> bool:
	return not get_tree().get_nodes_in_group("eel").is_empty()

## Debug: bring the Eel now (F9 in debug builds).
func force_eel() -> void:
	if eel_active() or points.is_empty():
		return
	_spawn_eel(points[randi() % points.size()])

func _spawn_eel(at: Vector3) -> void:
	if enemies_root == null or eel_active():
		return
	var e := Eel.new()
	e.lighthouse = lighthouse
	e.origin = Vector3(at.x, Terrain.SEA_LEVEL, at.z)
	enemies_root.add_child(e)

func _process(delta: float) -> void:
	if not Run.active or Net.is_client():
		return
	_churn(delta)
	if _pending.is_empty():
		return
	var still: Array[Dictionary] = []
	for p in _pending:
		p["delay"] = float(p["delay"]) - delta
		if p["delay"] <= 0.0:
			_spawn_one(p["at"], String(p.get("kind", "B")), bool(p.get("raid", false)), bool(p.get("camp", false)))
		else:
			still.append(p)
	_pending = still

# Bubbles and slaps of water where something is about to come up.
func _churn(delta: float) -> void:
	var still: Array[Dictionary] = []
	for o in _omens:
		o["left"] = float(o["left"]) - delta
		o["tick"] = float(o["tick"]) - delta
		if float(o["tick"]) <= 0.0:
			o["tick"] = OMEN_EVERY
			var at: Vector3 = o["at"] + Vector3(randf_range(-1.5, 1.5), 0.0, randf_range(-1.5, 1.5))
			FX.splash(get_parent(), Vector3(at.x, Terrain.SEA_LEVEL, at.z), 0.45)
		if float(o["left"]) > 0.0:
			still.append(o)
	_omens = still

func _spawn_one(at: Vector3, kind: String = "B", raid: bool = false, camp: bool = false) -> void:
	if enemies_root == null:
		return
	var e: Enemy
	match kind:
		"S":
			e = Squid.new()
		"C":
			e = Crab.new()
		"M":
			e = Smotherer.new()
		_:
			var b := Bloated.new()
			b.raid = raid
			e = b
	e.lighthouse = lighthouse
	e.camp_raid = camp
	var jitter := Vector3(randf_range(-JITTER, JITTER), 0.0, randf_range(-JITTER, JITTER))
	e.position = Vector3(at.x, SPAWN_Y, at.z) + jitter
	enemies_root.add_child(e)

func _on_run_ended(_reason: String, _night: int) -> void:
	_queue.clear()
	_pending.clear()
