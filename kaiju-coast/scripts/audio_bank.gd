class_name AudioBank
extends RefCounted
## Sounds baked ahead of time for the browser build. A web build has no background threads, and
## synthesising the soundtrack, effects and voices on the main thread would freeze the page for
## many seconds, so it plays the same sounds rendered to Ogg files by tools/web/bake_audio.sh
## (res://web_audio/, left out of the desktop builds). Desktop builds still synthesise them.

const DIR: String = "res://web_audio/"


static func baked() -> bool:
	return OS.has_feature("web")


## Every sound in a group ("music", "sfx" or "voice") listed in the manifest, by name.
static func load_group(group: String, loop: bool = false) -> Dictionary:
	var out: Dictionary = {}
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(DIR + "manifest.cfg") != OK:
		push_error("AudioBank: no %smanifest.cfg (run tools/web/bake_audio.sh)" % DIR)
		return out
	for key: String in cfg.get_value("audio", group, PackedStringArray()):
		var s: AudioStream = load(DIR + "%s_%s.ogg" % [group, key]) as AudioStream
		if s == null:
			continue
		if s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = loop
		out[key] = s
	return out
