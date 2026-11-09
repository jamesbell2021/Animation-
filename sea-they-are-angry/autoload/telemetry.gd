extends Node
## A local play log for playtests, and the F12 snapshot.
##
## Telemetry: one JSON line per event of a run, appended to user://telemetry.jsonl. Off
## unless Settings, Comfort and access, "Keep a local play log" is on or the game is
## started with `--telemetry`. Nothing is sent anywhere. The format is in
## docs/TELEMETRY.md.
##
## F12 (always on, in release builds too): appends the moment to user://feedback.txt, the
## night, the phase, the sea's anger, the store, the upgrades and a time, and says
## "Snapshot saved", so a tester can mark where something felt wrong and say so after.

var path := "user://telemetry.jsonl"
var feedback_path := "user://feedback.txt"
var forced := false

var _was_active := false
var _killed := {}
var _lost := 0
var _gutters := 0
var _started_ms := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	forced = OS.get_cmdline_args().has("--telemetry") or OS.get_cmdline_user_args().has("--telemetry")
	Events.enemy_killed.connect(_on_killed)
	Events.structure_destroyed.connect(func(_s: Node) -> void: _lost += 1)
	Events.lamp_state_changed.connect(func(s: int) -> void:
		if s == Lamp.State.GUTTERING:
			_gutters += 1)
	Events.run_ended.connect(_on_run_ended)
	Cycle.phase_changed.connect(_on_phase)

func enabled() -> bool:
	return forced or Settings.telemetry

func _process(_delta: float) -> void:
	if Run.active != _was_active:
		_was_active = Run.active
		if Run.active:
			_killed.clear()
			_lost = 0
			_gutters = 0
			_started_ms = Time.get_ticks_msec()
			record("run_start", {"night": Run.night, "sea": Difficulty.name(), "people": Players.humans(), "keepers": Players.nodes.size(), "version": ProjectSettings.get_setting("application/config/version", "")})

## Append one event. `data` is merged into the line.
func record(kind: String, data: Dictionary = {}) -> void:
	if not enabled():
		return
	var f := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	var row := {"t": Time.get_datetime_string_from_system(true), "event": kind}
	row.merge(data)
	f.store_line(JSON.stringify(row))
	f.close()

func _on_killed(e: Node) -> void:
	var kind := String(e.get_script().get_global_name()).to_lower() if e.get_script() != null else "creature"
	_killed[kind] = int(_killed.get(kind, 0)) + 1

func _on_phase(p: int) -> void:
	if not Run.active:
		return
	if p == Cycle.Phase.DAWN:
		var lamp_fuel := -1.0
		var scene := get_tree().current_scene
		if scene != null and scene.get("lighthouse") != null:
			lamp_fuel = snappedf(scene.lighthouse.lamp.fuel, 0.1)
		record("night", {
			"night": Run.night, "anger": Anger.value, "people": Players.humans(),
			"killed": _killed.duplicate(), "structures_lost": _lost, "lamp_gutters": _gutters,
			"lamp_fuel": lamp_fuel, "store": _store(), "weather": Weather.tonight_name(),
		})
		_killed.clear()
		_lost = 0
		_gutters = 0

func _on_run_ended(reason: String, night: int) -> void:
	record("run_end", {"reason": reason, "night": night, "anger": Anger.value, "seconds": int((Time.get_ticks_msec() - _started_ms) / 1000.0)})

func _store() -> Dictionary:
	var out := {}
	for k in Stock.KINDS:
		var n := Stock.get_amount(k)
		if n > 0:
			out[k] = n
	return out

# ---- F12 ----

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_F12:
		snapshot()
		get_viewport().set_input_as_handled()

## Write the moment to feedback.txt (and say so on screen).
func snapshot() -> void:
	var f := FileAccess.open(feedback_path, FileAccess.READ_WRITE if FileAccess.file_exists(feedback_path) else FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	var lines: Array[String] = []
	lines.append("--- %s ---" % Time.get_datetime_string_from_system(false))
	lines.append("version %s · %s sea · night %d · %s (%d s left)" % [ProjectSettings.get_setting("application/config/version", "?"), Difficulty.name(), Run.night, Cycle.phase_name(), roundi(Cycle.time_left)])
	lines.append("anger %d · %d people · weather %s" % [Anger.value, Players.humans(), Weather.tonight_name()])
	lines.append("store %s" % JSON.stringify(_store()))
	lines.append("upgrades %s · research %s" % [JSON.stringify(Run.upgrades), JSON.stringify(Run.research)])
	var scene := get_tree().current_scene
	if scene != null and scene.get("lighthouse") != null:
		var lh: Node = scene.lighthouse
		lines.append("lamp fuel %.0f (%s) · lighthouse %d/%d" % [lh.lamp.fuel, Lamp.State.keys()[lh.lamp.state], lh.hp, lh.max_hp])
	lines.append("creatures about: %d" % get_tree().get_nodes_in_group("enemies").size())
	lines.append("")
	f.store_string("\n".join(lines) + "\n")
	f.close()
	Events.message.emit("Snapshot saved")
	record("snapshot", {"night": Run.night, "phase": Cycle.phase_name()})
