extends Node
## Autoload: the player's vendor appearance. Every VendorAvatar with follow_character_data
## (the vendor on the beach, menu previews) listens to appearance_changed, so editing the look
## in the Character Creator updates the whole game instantly. SaveSystem stores it in the save.

signal appearance_changed(appearance: Dictionary)

var appearance: Dictionary = AppearanceOptions.default_appearance()


func set_appearance(a: Dictionary) -> void:
	appearance = AppearanceOptions.sanitize(a)
	appearance_changed.emit(appearance)


func get_value(key: String, fallback: Variant = null) -> Variant:
	return appearance.get(key, fallback)


func voice_pitch() -> float:
	return float(appearance.get("voice_pitch", 1.0))


func vendor_name() -> String:
	return str(appearance.get("name", "Chicken Nugget King"))


func randomise() -> Dictionary:
	set_appearance(AppearanceOptions.random_appearance())
	return appearance


func reset() -> void:
	set_appearance(AppearanceOptions.default_appearance())


func to_dict() -> Dictionary:
	return appearance.duplicate()


func from_dict(d: Dictionary) -> void:
	set_appearance(d)
