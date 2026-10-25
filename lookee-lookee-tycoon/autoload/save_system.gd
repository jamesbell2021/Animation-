extends Node
## Autoload: saving and loading. One JSON file in user:// holds the whole game; a small
## ConfigFile holds settings. On Android user:// is the app's private storage; in browsers
## Godot maps user:// to IndexedDB, and we also mirror the save into localStorage so it
## survives on itch.io even if IndexedDB is cleared or blocked.
##
## Writes go to a temp file first and are then renamed, so a crash mid-save can't corrupt it.

signal saved
signal loaded

const SAVE_PATH := "user://lookee_save.json"
const TMP_PATH := "user://lookee_save.tmp"
const SETTINGS_PATH := "user://settings.cfg"
const WEB_KEY := "lookee_lookee_tycoon_save"
const VERSION := 1

var settings := {
	"music": 0.7, "sfx": 0.9, "voice": 1.0, "quality": -1, "show_fps": false, "tutorial_done": false,
}


func _ready() -> void:
	load_settings()


func has_save() -> bool:
	if FileAccess.file_exists(SAVE_PATH):
		return true
	return _web_read() != ""


func save_game() -> bool:
	var data := {
		"version": VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"game": GameManager.to_dict(),
		"economy": Economy.to_dict(),
		"upgrades": Upgrades.to_dict(),
		"staff": Staff.to_dict(),
		"vendor": CharacterData.to_dict(),
	}
	var text := JSON.stringify(data, "\t")
	var f := FileAccess.open(TMP_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("SaveSystem: can't write %s (%s)" % [TMP_PATH, FileAccess.get_open_error()])
		return false
	f.store_string(text)
	f.close()
	var dir := DirAccess.open("user://")
	if dir == null or dir.rename(TMP_PATH.get_file(), SAVE_PATH.get_file()) != OK:
		# Some platforms won't rename over an existing file: write directly instead.
		var f2 := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if f2 == null:
			return false
		f2.store_string(text)
		f2.close()
	_web_write(text)
	saved.emit()
	return true


func load_game() -> bool:
	var text := ""
	if FileAccess.file_exists(SAVE_PATH):
		text = FileAccess.get_file_as_string(SAVE_PATH)
	if text == "":
		text = _web_read()
	if text == "":
		return false
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("SaveSystem: save file is damaged, starting fresh.")
		return false
	var data: Dictionary = parsed
	# Future versions: migrate old saves here, e.g. if data.version < 2: ...
	Upgrades.from_dict(data.get("upgrades", {}))
	Economy.from_dict(data.get("economy", {}))
	Staff.from_dict(data.get("staff", {}))
	CharacterData.from_dict(data.get("vendor", {}))
	GameManager.from_dict(data.get("game", {}))
	loaded.emit()
	return true


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	if OS.has_feature("web"):
		JavaScriptBridge.eval("try { localStorage.removeItem('%s'); } catch (e) {}" % WEB_KEY, true)


# --- Settings ---------------------------------------------------------------------------------

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		for key in settings:
			settings[key] = cfg.get_value("settings", key, settings[key])
	apply_settings()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in settings:
		cfg.set_value("settings", key, settings[key])
	cfg.save(SETTINGS_PATH)


func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	apply_settings()
	save_settings()


func apply_settings() -> void:
	AudioManager.set_volumes(float(settings.music), float(settings.sfx), float(settings.voice))
	Quality.show_fps = bool(settings.show_fps)
	if int(settings.quality) != Quality.forced:
		Quality.force(int(settings.quality))


# --- Browser mirror ---------------------------------------------------------------------------

func _web_write(text: String) -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("try { localStorage.setItem('%s', %s); } catch (e) {}" % [WEB_KEY, JSON.stringify(text)], true)


func _web_read() -> String:
	if not OS.has_feature("web"):
		return ""
	var v: Variant = JavaScriptBridge.eval("(function(){ try { return localStorage.getItem('%s') || ''; } catch (e) { return ''; } })()" % WEB_KEY, true)
	return str(v) if v != null else ""
