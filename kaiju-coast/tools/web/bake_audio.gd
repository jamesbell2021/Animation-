extends Node
## Renders the music loops, sound effects and voice lines to WAV for tools/web/bake_audio.sh,
## which encodes them to Ogg in res://web_audio/ for the browser build.
##   godot --headless --path . res://tools/web/bake_audio.tscn -- --out=/some/folder


func _ready() -> void:
	var out: String = "user://"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	var cfg: ConfigFile = ConfigFile.new()
	var m: Music = Music.new()
	for mode: String in Music.MODES:
		m.render(mode).save_to_wav(out.path_join("music_%s.wav" % mode))
	m.free()
	cfg.set_value("audio", "music", PackedStringArray(Music.MODES))
	var s: Sfx = Sfx.new()
	add_child(s)
	var names: PackedStringArray = PackedStringArray()
	for name: String in s.streams:
		(s.streams[name] as AudioStreamWAV).save_to_wav(out.path_join("sfx_%s.wav" % name))
		names.append(name)
	cfg.set_value("audio", "sfx", names)
	var voices: PackedStringArray = PackedStringArray()
	for key: String in Voice.LINES:
		var l: Array = Voice.LINES[key]
		VoiceSynth.say(l[0], l[3], true).save_to_wav(out.path_join("voice_%s.wav" % key))
		voices.append(key)
	cfg.set_value("audio", "voice", voices)
	cfg.save(out.path_join("manifest.cfg"))
	print("baked %d music, %d sfx, %d voice lines to %s" % [Music.MODES.size(), names.size(), voices.size(), out])
	get_tree().quit()
