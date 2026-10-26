class_name WebAudioFix
extends RefCounted
## Godot 4.3's web export plays sounds as Web Audio "samples" by default, and that mode stays
## silent for audio made at runtime, which is all of this game's sound (music, effects and
## voices are synthesised in code). In the browser every player therefore uses the "stream"
## mode, where the engine mixes the sound itself. Native builds (Android) are unaffected.


static func setup(p: AudioStreamPlayer) -> AudioStreamPlayer:
	if OS.has_feature("web"):
		p.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	return p
