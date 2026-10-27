class_name Settings
extends RefCounted
## Player settings: stored in user://kaiju_coast.cfg (via Game) and applied to the running game.

const DEFAULTS: Dictionary = {
	"sensitivity": 0.0022, "invert_y": false, "music_vol": 0.8, "sfx_vol": 1.0, "voice_vol": 1.0,
	"quality": 2, "fullscreen": false, "crt": true, "tutorial": true, "difficulty": 1,
}
const QUALITY_NAMES: Array[String] = ["LOW", "MEDIUM", "HIGH"]
const DIFFICULTY_NAMES: Array[String] = ["やさしい EASY", "ふつう NORMAL", "むずかしい HARD"]

static var values: Dictionary = {}


static func load_all() -> void:
	for k: String in DEFAULTS:
		var d: Variant = DEFAULTS[k]
		if k == "quality" and OS.has_feature("mobile"):
			d = 0
		values[k] = Game.load_setting(k, d)


static func get_v(k: String) -> Variant:
	return values.get(k, DEFAULTS[k])


static func set_v(k: String, v: Variant) -> void:
	values[k] = v
	Game.save_setting(k, v)
	apply()


static func apply() -> void:
	Sfx.set_bus_volume("Music", float(get_v("music_vol")))
	Sfx.set_bus_volume("SFX", float(get_v("sfx_vol")))
	Sfx.set_bus_volume("Voice", float(get_v("voice_vol")))
	if Game.player != null:
		Game.player.sens = float(get_v("sensitivity"))
		Game.player.invert_y = bool(get_v("invert_y"))
	var q: int = clampi(int(get_v("quality")), 0, 2)
	Mats.set_line_width([1.3, 1.7, 2.1][q])
	if Game.main != null:
		var vp: Viewport = Game.main.get_viewport()
		vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][q]
		Game.main.set_crt(bool(get_v("crt")))
	if Game.fx != null:
		Game.fx.max_particles = [1400, 2600, 3600][q]
	if Game.world != null and Game.world.env != null:
		Game.world.env.glow_intensity = [0.9, 1.1, 1.25][q]
	var fs: bool = bool(get_v("fullscreen"))
	var mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	var is_fs: bool = mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if fs != is_fs and not OS.has_feature("mobile") and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fs else DisplayServer.WINDOW_MODE_WINDOWED)
