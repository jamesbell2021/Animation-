extends Node
## Spawns the night's creatures from points in the water, driven by Cycle.night_progress.

const STAGGER := 0.3
const JITTER := 1.0
const SPAWN_Y := -0.6
const NIGHT_TABLES := {
	1: [[0.10, 2], [0.45, 2], [0.75, 3]],
	2: [[0.10, 2], [0.30, 2], [0.60, 3], [0.80, 3]],
	3: [[0.10, 3], [0.35, 3], [0.55, 3], [0.75, 4]],
	4: [[0.05, 3], [0.25, 3], [0.45, 4], [0.65, 4], [0.85, 4]],
}

var points: Array[Vector3] = []
var enemies_root: Node
var lighthouse: Node3D

var _queue: Array[Dictionary] = []
# Individual spawns waiting out their stagger delay: {at: Vector3, delay: float}.
var _pending: Array[Dictionary] = []

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
	for i in count:
		_pending.append({"at": points[idx], "delay": STAGGER * float(i)})

func _process(delta: float) -> void:
	if _pending.is_empty() or not Run.active:
		return
	var still: Array[Dictionary] = []
	for p in _pending:
		p["delay"] = float(p["delay"]) - delta
		if p["delay"] <= 0.0:
			_spawn_one(p["at"])
		else:
			still.append(p)
	_pending = still

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
