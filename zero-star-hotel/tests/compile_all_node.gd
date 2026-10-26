extends Node
func _ready() -> void:
	var bad := 0
	for dir: String in ["res://autoload", "res://data", "res://scripts/art", "res://scripts/audio", "res://scripts/character", "res://scripts/ui", "res://scripts/world", "res://studio"]:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd"):
				var s: Script = load(dir + "/" + f)
				if s == null or not s.can_instantiate():
					print("BAD ", dir, "/", f)
					bad += 1
	print("compile check done, bad=", bad)
	get_tree().quit(bad)
