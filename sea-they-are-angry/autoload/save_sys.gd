extends Node

const RUN_PATH := "user://run.json"
const PROFILE_PATH := "user://profile.json"

func save_run() -> void:
	var d := {
		"night": Run.night,
		"anger": Anger.value,
		"stock": Stock.all(),
		"fuel": Run.lamp_fuel,
		"upgrades": Run.upgrades,
		"max_hp_bonus": Run.max_hp_bonus,
		"crops": Run.crops,
		"flares": Run.flares,
	}
	var f := FileAccess.open(RUN_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))

func load_run() -> Dictionary:
	if not FileAccess.file_exists(RUN_PATH):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(RUN_PATH))
	if parsed is Dictionary:
		return parsed
	return {}

func clear_run() -> void:
	if FileAccess.file_exists(RUN_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RUN_PATH))

func save_best(night: int) -> void:
	if night > load_best():
		var f := FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify({"best_night": night}))

func load_best() -> int:
	if not FileAccess.file_exists(PROFILE_PATH):
		return 0
	var d = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH))
	if d is Dictionary:
		return int(d.get("best_night", 0))
	return 0
