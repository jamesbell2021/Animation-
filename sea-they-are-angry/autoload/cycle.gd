extends Node

enum Phase { DAY, DUSK, NIGHT, DAWN }

signal phase_changed(phase: int)
signal night_progress(t: float)

var phase: int = Phase.DAY
var time_left := 0.0
var running := false
var _duration := 1.0

func start(p: int = Phase.DAY) -> void:
	running = true
	_enter(p)

func stop() -> void:
	running = false

func skip() -> void:
	if phase == Phase.DAY:
		_enter(Phase.DUSK)
	elif phase == Phase.DAWN:
		_enter(Phase.DAY)

func duration_for(p: int) -> float:
	var n: int = Run.night
	match p:
		Phase.DAY:
			return 60.0
		Phase.DUSK:
			return 15.0
		Phase.NIGHT:
			return minf(120.0 + 10.0 * (n - 1), 210.0)
		Phase.DAWN:
			return 30.0
	return 1.0

func progress() -> float:
	return 1.0 - time_left / _duration

func phase_name() -> String:
	return ["Day", "Dusk", "Night", "Dawn"][phase]

func _enter(p: int) -> void:
	phase = p
	_duration = duration_for(p)
	time_left = _duration
	phase_changed.emit(p)

func _process(delta: float) -> void:
	if not running:
		return
	time_left -= delta
	if phase == Phase.NIGHT:
		night_progress.emit(progress())
	if time_left <= 0.0:
		_enter((phase + 1) % 4)
