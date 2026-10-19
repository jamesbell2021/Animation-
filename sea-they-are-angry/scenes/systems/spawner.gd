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
# Waves come early enough that the last one still reaches the fences before dawn:
# the walk from a beach to the lighthouse is close to a minute.
const NIGHT_TABLES := {
	1: [[0.06, 2], [0.32, 2], [0.58, 3]],
	2: [[0.06, 2], [0.24, 3], [0.44, 3], [0.62, 3]],
	3: [[0.05, 3], [0.22, 3], [0.40, 4], [0.60, 4]],
	4: [[0.04, 3], [0.18, 3], [0.34, 4], [0.50, 4], [0.66, 5]],
}

## A group is about to come out of the sea at these landing points.
signal wave_incoming(points: Array, count: int)

var points: Array[Vector3] = []
var enemies_root: Node
var lighthouse: Node3D

var _queue: Array[Dictionary] = []
# Individual spawns waiting out their stagger delay: {at: Vector3, delay: float}.
var _pending: Array[Dictionary] = []
# Landings about to happen: {at: Vector3, left: float, tick: float}.
var _omens: Array[Dictionary] = []

func _ready() -> void:
	Cycle.phase_changed.connect(_on_phase_changed)
	Cycle.night_progress.connect(_on_night_progress)
	Events.run_ended.connect(_on_run_ended)

func night_table(n: int) -> Array[Dictionary]:
	var rows: Array = NIGHT_TABLES.get(mini(n, 4), NIGHT_TABLES[4])
	var extra := 0
	if n >= 5:
		extra += floori((n - 4) / 2.0)
	extra += floori(Anger.value / 3.0)
	var out: Array[Dictionary] = []
	for row in rows:
		out.append({"t": float(row[0]), "count": int(row[1]) + extra, "point": -1})
	return out

func queue_size() -> int:
	return _queue.size() + _pending.size()

func _on_phase_changed(p: int) -> void:
	if p == Cycle.Phase.NIGHT:
		_queue = night_table(Run.night)
		_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["t"] < b["t"])
	elif p == Cycle.Phase.DAWN:
		_queue.clear()
		_pending.clear()
		_omens.clear()

func _on_night_progress(t: float) -> void:
	while not _queue.is_empty() and float(_queue[0]["t"]) <= t:
		var entry: Dictionary = _queue.pop_front()
		_queue_group(entry)

func _queue_group(entry: Dictionary) -> void:
	if points.is_empty():
		return
	var idx: int = entry["point"]
	if idx < 0 or idx >= points.size():
		idx = randi() % points.size()
	# Co-op: more keepers, more creatures (x1.5 per extra keeper, rounded up).
	var count := ceili(float(entry["count"]) * (1.0 + 0.5 * float(Players.count() - 1)))
	var landings: Array = [points[idx]]
	if Run.night >= SPLIT_FROM_NIGHT and count >= SPLIT_MIN and points.size() > 2:
		# A second landing at a different beach (points come in pairs, one pair per beach).
		var other := (idx + 2 + 2 * (randi() % maxi(1, points.size() / 2 - 1))) % points.size()
		landings.append(points[other])
	wave_incoming.emit(landings, count)
	for l in landings:
		_omens.append({"at": l, "left": OMEN_TIME, "tick": 0.0})
	for i in count:
		_pending.append({"at": landings[i % landings.size()], "delay": OMEN_TIME + STAGGER * float(i)})

func _process(delta: float) -> void:
	if not Run.active:
		return
	_churn(delta)
	if _pending.is_empty():
		return
	var still: Array[Dictionary] = []
	for p in _pending:
		p["delay"] = float(p["delay"]) - delta
		if p["delay"] <= 0.0:
			_spawn_one(p["at"])
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

func _spawn_one(at: Vector3) -> void:
	if enemies_root == null:
		return
	var e := Bloated.new()
	e.lighthouse = lighthouse
	var jitter := Vector3(randf_range(-JITTER, JITTER), 0.0, randf_range(-JITTER, JITTER))
	e.position = Vector3(at.x, SPAWN_Y, at.z) + jitter
	enemies_root.add_child(e)

func _on_run_ended(_reason: String, _night: int) -> void:
	_queue.clear()
	_pending.clear()
