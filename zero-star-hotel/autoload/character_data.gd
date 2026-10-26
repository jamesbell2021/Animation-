extends Node
## Autoload: how the player's manager looks (re-rollable from the pause menu). Avatars with
## follow_character_data mirror it live.

signal appearance_changed(appearance: Dictionary)

var appearance: Dictionary = {}


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	appearance = AppearanceOptions.sanitize(AppearanceOptions.manager_appearance(rng))


func set_appearance(a: Dictionary) -> void:
	appearance = AppearanceOptions.sanitize(a)
	appearance_changed.emit(appearance)


func reroll() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var keep_name := str(appearance.get("name", ""))
	var a := AppearanceOptions.manager_appearance(rng)
	if keep_name != "":
		a.name = keep_name
	set_appearance(a)


func voice_pitch() -> float:
	return float(appearance.get("voice_pitch", 1.0))


func to_dict() -> Dictionary:
	return appearance.duplicate()


func from_dict(d: Dictionary) -> void:
	if not d.is_empty():
		set_appearance(d)
