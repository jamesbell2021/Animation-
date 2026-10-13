extends SceneTree
## Writes the trailer's music and announcer lines as WAV files (see record.sh).

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	for track in ["lobby", "battle"]:
		Chiptune.render(track).save_to_wav(out + "/music_" + track + ".wav")
	for key in ["boss", "deploy", "wave"]:
		var line: Array = VoiceLines.ANNOUNCER[key]
		VoiceSynth.say(line[0], 100.0, true).save_to_wav(out + "/voice_" + key + ".wav")
	SfxBank.build()["explosion"].save_to_wav(out + "/sfx_explosion.wav")
	quit()
