class_name RaceManager
extends Node
## Runs a single race: countdown, timer, finish detection, falls and results.
## Contestants are registered before start_countdown() is called.

signal countdown_tick(seconds_left: int)
signal race_started
signal contestant_finished(contestant: Contestant, place: int, time: float)
signal contestant_fell(contestant: Contestant, fall_count: int)
signal race_finished(results: Array)

enum State { WAITING, COUNTDOWN, RACING, FINISHED }

@export var countdown_seconds: int = 3
## After the first contestant finishes, everyone else has this long to finish.
@export var finish_grace_seconds: float = 30.0
## Hard limit for a race, in case nobody finishes.
@export var max_race_seconds: float = 300.0
## False for modes with no finish line (Paintball Battle).
@export var needs_finish_area: bool = true

var state: State = State.WAITING
var race_time: float = 0.0
## Optional: returns contestants in running order, so non-finishers are placed by progress.
var ranking_provider: Callable

var _contestants: Array[Contestant] = []
var _results: Array[Dictionary] = []
var _finished_ids: Dictionary = {}
var _falls: Dictionary = {}
var _countdown_left: float = 0.0
var _last_tick: int = -1
var _grace_left: float = -1.0
var _finish_area: Area3D


func _process(delta: float) -> void:
	match state:
		State.COUNTDOWN:
			_countdown_left -= delta
			var tick := int(ceil(_countdown_left))
			if tick != _last_tick:
				_last_tick = tick
				countdown_tick.emit(maxi(tick, 0))
			if _countdown_left <= 0.0:
				_begin_race()
		State.RACING:
			race_time += delta
			if _grace_left >= 0.0:
				_grace_left -= delta
				if _grace_left <= 0.0:
					_end_race()
			if race_time >= max_race_seconds:
				_end_race()


func register_finish_area(area: Area3D) -> void:
	if area == null:
		push_error("RaceManager.register_finish_area: area is null.")
		return
	if _finish_area != null and _finish_area.body_entered.is_connected(_on_finish_body_entered):
		_finish_area.body_entered.disconnect(_on_finish_body_entered)
	_finish_area = area
	_finish_area.body_entered.connect(_on_finish_body_entered)


func register_contestant(contestant: Contestant) -> void:
	if contestant == null or _contestants.has(contestant):
		return
	_contestants.append(contestant)
	contestant.controls_enabled = false
	contestant.fell.connect(_on_contestant_fell.bind(contestant))


func clear_contestants() -> void:
	for c in _contestants:
		if is_instance_valid(c) and c.fell.is_connected(_on_contestant_fell):
			c.fell.disconnect(_on_contestant_fell)
	_contestants.clear()


func start_countdown() -> void:
	if _finish_area == null and needs_finish_area:
		push_error("RaceManager.start_countdown: no finish area registered.")
	race_time = 0.0
	_results.clear()
	_finished_ids.clear()
	_falls.clear()
	_grace_left = -1.0
	_countdown_left = float(countdown_seconds)
	_last_tick = -1
	for c in _contestants:
		c.controls_enabled = false
	state = State.COUNTDOWN


func is_racing() -> bool:
	return state == State.RACING


func get_contestants() -> Array[Contestant]:
	return _contestants


func get_results() -> Array:
	return _results.duplicate()


func get_fall_count(contestant: Contestant) -> int:
	if contestant == null:
		return 0
	return _falls.get(contestant.get_instance_id(), 0)


func has_finished(contestant: Contestant) -> bool:
	return contestant != null and _finished_ids.has(contestant.get_instance_id())


func _begin_race() -> void:
	state = State.RACING
	for c in _contestants:
		c.controls_enabled = true
	race_started.emit()


func _on_finish_body_entered(body: Node3D) -> void:
	if state != State.RACING or not (body is Contestant):
		return
	var contestant := body as Contestant
	var id := contestant.get_instance_id()
	if _finished_ids.has(id):
		return
	_finished_ids[id] = true
	var place := _results.size() + 1
	_results.append({
		"name": contestant.name,
		"place": place,
		"time": race_time,
		"falls": _falls.get(id, 0),
		"finished": true,
	})
	contestant.controls_enabled = false
	contestant_finished.emit(contestant, place, race_time)
	if _results.size() == 1 and _contestants.size() > 1:
		_grace_left = finish_grace_seconds
	if _results.size() >= _contestants.size():
		_end_race()


func _on_contestant_fell(contestant: Contestant) -> void:
	if state != State.RACING or contestant == null:
		return
	var id := contestant.get_instance_id()
	_falls[id] = _falls.get(id, 0) + 1
	contestant_fell.emit(contestant, _falls[id])


## Ends the race with results worked out elsewhere (Paintball Battle).
func end_with_results(results: Array) -> void:
	if state == State.FINISHED:
		return
	state = State.FINISHED
	for c in _contestants:
		if is_instance_valid(c):
			c.controls_enabled = false
	_results.clear()
	for entry in results:
		_results.append(entry)
	race_finished.emit(_results.duplicate())


func _end_race() -> void:
	if state == State.FINISHED:
		return
	state = State.FINISHED
	var order: Array = _contestants
	if ranking_provider.is_valid():
		order = ranking_provider.call()
	for c: Contestant in order:
		if not is_instance_valid(c):
			continue
		c.controls_enabled = false
		if not _finished_ids.has(c.get_instance_id()):
			_results.append({
				"name": c.name,
				"place": _results.size() + 1,
				"time": -1.0,
				"falls": _falls.get(c.get_instance_id(), 0),
				"finished": false,
			})
	race_finished.emit(_results.duplicate())
