extends Node
## Writes the four music loops and a few sound effects as WAV files (for docs/soundtrack-preview.mp3):
##   godot --headless --path . res://tests/audio_preview.tscn -- --out=/tmp/audio


func _ready() -> void:
	var out: String = "user://"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	var m: Music = Music.new()
	for mode: String in ["title", "battle", "boss"]:
		m.render(mode).save_to_wav(out.path_join("music_%s.wav" % mode))
	m.free()
	var s: Sfx = Sfx.new()
	add_child(s)
	for name: String in ["gong", "roar", "cannon", "gun", "rocket", "boom_big", "hanabi", "rail", "splat", "roar_boss"]:
		(s.streams[name] as AudioStreamWAV).save_to_wav(out.path_join("sfx_%s.wav" % name))
	print("audio written to ", out)
	get_tree().quit()
