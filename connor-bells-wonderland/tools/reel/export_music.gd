extends SceneTree
## Writes the game's dance track to a WAV for the reel:
##   godot --headless --path . -s res://tools/reel/export_music.gd -- out=/path/music.wav
func _initialize() -> void:
	var out := "user://reel_music.wav"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	var music: AudioStreamWAV = SoundManager._build_disco()
	music.save_to_wav(out)
	print("music: %.1f s -> %s" % [music.get_length(), out])
	quit()
