extends SceneTree
## Renders the sound effects and four bars of the battle theme to a WAV, the way the game's
## sound board does at start-up, and prints the loudness of each half second so silence shows up.
##   godot --headless --path . -s tools/render_audio_preview.gd [out.wav]
## Then, for the README:  ffmpeg -i out.wav -q:a 4 docs/audio-preview.mp3

const RATE := 22050


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else "/tmp/tripod-attack-preview.wav"
	var sfx: Node = load("res://scripts/sfx.gd").new()
	var t0 := Time.get_ticks_msec()
	var r: Dictionary = sfx.render_all()
	print("rendered %d sounds and %d songs in %.1f s" % [r.sounds.size(), r.music.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	var cues := [[0.2, "blip"], [0.5, "select"], [1.2, "launch"], [2.0, "explosion"], [3.0, "leg_hit"], [3.3, "leg_hit"], [3.9, "ricochet"],
		[4.8, "footstep"], [5.5, "footstep"], [6.2, "footstep"], [7.0, "siren"], [8.6, "heat_ray"], [9.0, "scream"], [9.4, "burn"], [9.7, "scream"],
		[10.6, "leg_break"], [11.2, "collapse"], [13.2, "saved"], [13.8, "fanfare"], [15.2, "hurt"], [15.9, "stomp"], [16.8, "alarm"]]
	var music_at := 18.0
	var battle: PackedFloat32Array = r.raw["music_battle"]
	var battle_len := battle.size() / float(RATE)
	var tail := music_at + battle_len
	cues.append([tail + 0.3, "cleared"])
	cues.append([tail + 2.2, "game_over"])
	cues.append([tail + 4.2, "victory"])
	var total := tail + 7.5
	var mix := PackedFloat32Array()
	mix.resize(int(total * RATE))
	mix.fill(0.0)
	for c in cues:
		var buf: PackedFloat32Array = r.raw[c[1]]
		var n0 := int(c[0] * RATE)
		for i in buf.size():
			if n0 + i < mix.size():
				mix[n0 + i] += buf[i]
	var m0 := int(music_at * RATE)
	for i in battle.size():
		if m0 + i < mix.size():
			mix[m0 + i] += battle[i] * 0.45
	var data := PackedByteArray()
	data.resize(mix.size() * 2)
	var peak := 0.0
	var rms := PackedStringArray()
	var win := RATE / 2
	var e := 0.0
	for i in mix.size():
		var v := tanh(mix[i] * 1.1)
		peak = maxf(peak, absf(v))
		e += v * v
		if (i + 1) % win == 0:
			rms.append("%.3f" % sqrt(e / win))
			e = 0.0
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_buffer("RIFF".to_ascii_buffer())
	f.store_32(36 + data.size())
	f.store_buffer("WAVE".to_ascii_buffer())
	f.store_buffer("fmt ".to_ascii_buffer())
	f.store_32(16)
	f.store_16(1)
	f.store_16(1)
	f.store_32(RATE)
	f.store_32(RATE * 2)
	f.store_16(2)
	f.store_16(16)
	f.store_buffer("data".to_ascii_buffer())
	f.store_32(data.size())
	f.store_buffer(data)
	f.close()
	print("wrote ", out_path, "  peak %.3f  length %.1f s" % [peak, total])
	print("rms per 0.5 s: ", ", ".join(rms))
	quit()
