extends SceneTree
## Renders the hotel's daytime music loop to a WAV for the trailer edit.
##   godot --headless --path . -s res://tools/trailer/export_music.gd -- <out.wav>

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if not args.is_empty() else "user://day.wav"
	MusicSynth.new("day").render_all().save_to_wav(out)
	print("music -> ", out)
	quit()
