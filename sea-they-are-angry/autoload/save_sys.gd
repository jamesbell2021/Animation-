extends Node

const RUN_PATH := "user://run.json"
const PROFILE_PATH := "user://profile.json"

func save_run() -> void:
	# A LAN client's run is the host's: only the host saves it.
	if Net.is_client():
		return
	var f := FileAccess.open(RUN_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(snapshot()))

## The run as the save keeps it (and as the LAN host sends it to the clients).
func snapshot() -> Dictionary:
	return {
		"night": Run.night,
		"chapter": Run.chapter,
		"lamps_on": Run.lamps_on,
		"bell_mended": Run.bell_mended,
		"story": Run.story,
		"diary_read": Run.diary_read,
		"favours": Run.favours,
		"asked": Run.asked,
		"stars": Run.stars,
		"star_nights": Run.star_nights,
		"hard_light": Run.hard_light,
		"villagers": Run.villagers,
		"lost": Run.lost,
		"difficulty": Run.difficulty,
		"endless": Run.endless,
		"jobs": Run.jobs,
		"anger": Anger.value,
		"stock": Stock.all(),
		"fuel": Run.lamp_fuel,
		"camp_fuel": Run.camp_fuel,
		"camp_crops": Run.camp_crops,
		"hunger": Run.hunger,
		"warmth": Run.warmth,
		"research": Run.research,
		"researching": Run.researching,
		"notes_found": Run.notes_found,
		"upgrades": Run.upgrades,
		"max_hp_bonus": Run.max_hp_bonus,
		"crops": Run.crops,
		"flares": Run.flares,
		"arms": Run.arms,
		"flamer_rigged": Run.flamer_rigged,
		"flamer_fuel": Run.flamer_fuel,
		"barrels": Run.barrels,
		"weather_seed": Run.weather_seed,
	}

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

## The player's record across runs: best night, and the chapters finished.
func load_profile() -> Dictionary:
	if not FileAccess.file_exists(PROFILE_PATH):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH))
	return d if d is Dictionary else {}

func _save_profile(d: Dictionary) -> void:
	var f := FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))

func save_best(night: int) -> void:
	if night > load_best():
		var d := load_profile()
		d["best_night"] = night
		_save_profile(d)

func load_best() -> int:
	return int(load_profile().get("best_night", 0))

## A chapter finished (on which sea, the hardest kept). The story finished on a harder
## sea unlocks something (UNLOCKS), and its best dawn rating is kept.
func finish_chapter(n: int) -> void:
	var d := load_profile()
	var done: Dictionary = d.get("chapters", {})
	var key := str(n)
	done[key] = maxi(int(done.get(key, -1)), Run.difficulty)
	d["chapters"] = done
	if n == 1 and Run.story:
		var got: Array = d.get("unlocks", [])
		for id in UNLOCKS:
			if Run.difficulty >= int(UNLOCKS[id]["sea"]) and not got.has(id):
				got.append(id)
		d["unlocks"] = got
		d["best_stars"] = maxi(int(d.get("best_stars", 0)), Run.stars)
	_save_profile(d)

## What finishing the story on a harder sea unlocks: the sea it takes, what it is called
## on the title, and what it does (shown in Settings).
const UNLOCKS := {
	"coat": {"sea": 1, "name": "the keeper's oilskin", "note": "A yellow oilskin for the keepers people play (Settings)."},
	"hard_light": {"sea": 2, "name": "Hard Light", "note": "The lamp burns oil a quarter faster; a night it never goes out earns a fourth star (Settings)."},
}

func unlocked(id: String) -> bool:
	return (load_profile().get("unlocks", []) as Array).has(id)

## The names of what is unlocked, for the title.
func unlocked_names() -> Array:
	var out := []
	for id in UNLOCKS:
		if unlocked(id):
			out.append(String(UNLOCKS[id]["name"]))
	return out

## A choice kept with the profile (the coat, Hard Light), or `default`.
func choice(id: String, default: Variant) -> Variant:
	return load_profile().get("choices", {}).get(id, default)

func set_choice(id: String, v: Variant) -> void:
	var d := load_profile()
	var c: Dictionary = d.get("choices", {})
	c[id] = v
	d["choices"] = c
	_save_profile(d)

func chapter_done(n: int) -> bool:
	return load_profile().get("chapters", {}).has(str(n))
