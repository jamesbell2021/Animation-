extends Node
## Autoload: the game's conductor. Scene flow (menu -> creator -> beach), the day clock,
## owned beaches and kiosks, end-of-day accounting, pausing, the Android back button and the
## toast notifications every other system uses to talk to the player.

signal day_started(day: int)
signal day_ended(summary: Dictionary)
signal time_changed(hour: float)
signal toast(text: String, kind: String)
signal paused_changed(paused: bool)
signal back_pressed
signal empire_changed

const MENU_SCENE := "res://scenes/main_menu.tscn"
const CREATOR_SCENE := "res://scenes/character_creator.tscn"
const BEACH_SCENE := "res://scenes/beach.tscn"

const DAY_START_HOUR := 9.0
const DAY_END_HOUR := 21.0
const DAY_LENGTH_SECONDS := 240.0

var day := 1
var hour := DAY_START_HOUR
var day_running := false
var current_beach := "benidorm"
var next_beach := "benidorm"
var owned_beaches: Array = ["benidorm"]
var kiosks := {}               # beach_id -> true
var tutorial_step := 0         # index into TUTORIAL_ORDER; >= size means done
var creator_mode := "new"      # "new" or "edit" (read by the Character Creator scene)
var best_day := 0.0
var _pause_reasons := {}

const TUTORIAL_ORDER := ["setup", "shout", "sell", "heat", "pack", "shop", "done"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	# Merge into Godot's default theme too: Controls under a CanvasLayer (HUD, overlays)
	# don't inherit the root window's theme.
	ThemeDB.get_default_theme().merge_with(UITheme.get_theme())
	ThemeDB.get_default_theme().default_font = UITheme.bold_font()
	ThemeDB.get_default_theme().default_font_size = UITheme.FONT_SIZE
	get_tree().root.theme = UITheme.get_theme()
	get_tree().set_auto_accept_quit(false)
	get_tree().set_quit_on_go_back(false)
	if OS.has_feature("web"):
		# Browsers: right-click and the context menu would get in the way of play.
		get_tree().root.gui_embed_subwindows = true


func _setup_input() -> void:
	var keys := {
		"shout": [KEY_SPACE, KEY_S],
		"toggle_stall": [KEY_E, KEY_P],
		"open_shop": [KEY_B, KEY_TAB],
		"markup": [KEY_M],
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)


func _process(delta: float) -> void:
	if not day_running or get_tree().paused:
		return
	hour += delta * (DAY_END_HOUR - DAY_START_HOUR) / DAY_LENGTH_SECONDS
	time_changed.emit(hour)
	if hour >= DAY_END_HOUR:
		end_day()


# --- Scene flow -------------------------------------------------------------------------------

func goto_menu() -> void:
	_stop_day()
	clear_pause()
	get_tree().change_scene_to_file(MENU_SCENE)


func new_game() -> void:
	Economy.new_game()
	Upgrades.reset()
	Staff.new_game()
	CharacterData.reset()
	day = 1
	hour = DAY_START_HOUR
	current_beach = "benidorm"
	next_beach = "benidorm"
	owned_beaches = ["benidorm"]
	kiosks = {}
	best_day = 0.0
	tutorial_step = 0 if not SaveSystem.settings.tutorial_done else TUTORIAL_ORDER.size()
	creator_mode = "new"
	clear_pause()
	get_tree().change_scene_to_file(CREATOR_SCENE)


func continue_game() -> bool:
	if not SaveSystem.load_game():
		return false
	goto_beach()
	return true


func goto_beach() -> void:
	clear_pause()
	get_tree().change_scene_to_file(BEACH_SCENE)


## Called by the Character Creator when the player confirms a brand-new vendor.
func creator_confirmed() -> void:
	SaveSystem.save_game()
	goto_beach()


# --- Day cycle --------------------------------------------------------------------------------

func start_day() -> void:
	if next_beach in owned_beaches:
		current_beach = next_beach
	hour = DAY_START_HOUR
	day_running = true
	Economy.reset_day_stats()
	HeatSystem.new_day()
	HeatSystem.active = true
	RandomEvents.new_day()
	RandomEvents.enabled = true
	Staff.refresh_candidates()
	day_started.emit(day)
	time_changed.emit(hour)


func end_day() -> void:
	if not day_running:
		return
	_stop_day()
	var s := Economy.day_stats
	# Wages for everyone, everywhere.
	var wages := Staff.daily_wages()
	if wages > 0.0:
		Economy.force_spend(wages, "wages")
	# Income from the rest of the empire.
	var empire := 0.0
	for b in owned_beaches:
		if b != current_beach:
			empire += Staff.offsite_income(b)
		if kiosks.has(b):
			empire += float(BeachDB.get_beach(b).kiosk_income)
	if empire > 0.0:
		Economy.add_cash(empire, "empire")
	var profit: float = s.revenue + s.empire + s.other - s.stock_spent - s.fines - s.bribes - s.wages
	var summary := s.duplicate(true)
	summary.day = day
	summary.beach = current_beach
	summary.profit = profit
	summary.best_seller = Economy.best_seller_today()
	summary.record = profit > best_day
	best_day = maxf(best_day, profit)
	if profit > 150.0:
		summary.verdict = Lines.pick(Lines.DAY_GREAT)
	elif profit >= 0.0:
		summary.verdict = Lines.pick(Lines.DAY_OK)
	else:
		summary.verdict = Lines.pick(Lines.DAY_BAD)
	Economy.lifetime.days += 1
	day += 1
	SaveSystem.save_game()
	day_ended.emit(summary)


func _stop_day() -> void:
	day_running = false
	HeatSystem.active = false
	RandomEvents.enabled = false


func time_string() -> String:
	var h := int(hour)
	var m := int((hour - h) * 60.0) / 10 * 10
	return "%02d:%02d" % [h, m]


func day_progress() -> float:
	return clampf((hour - DAY_START_HOUR) / (DAY_END_HOUR - DAY_START_HOUR), 0.0, 1.0)


# --- Empire -----------------------------------------------------------------------------------

func beach_block_reason(id: String) -> String:
	if id in owned_beaches:
		return ""
	var b := BeachDB.get_beach(id)
	if bool(b.needs_van) and Upgrades.level("van") < 1:
		return "Needs a Rusty Van"
	if not Economy.can_afford(float(b.unlock)):
		return "Need %s" % Lines.money(float(b.unlock))
	return ""


func buy_beach(id: String) -> bool:
	if id in owned_beaches or beach_block_reason(id) != "":
		return false
	if not Economy.spend(float(BeachDB.get_beach(id).unlock), "beach"):
		return false
	owned_beaches.append(id)
	notify("%s is yours! Hello chicken nugget, hello %s! Very good very nice!" % [BeachDB.get_beach(id).name, BeachDB.get_beach(id).name], "good")
	AudioManager.play_sfx("upgrade")
	empire_changed.emit()
	return true


func buy_kiosk(id: String) -> bool:
	if not (id in owned_beaches) or kiosks.has(id):
		return false
	if not Economy.spend(float(BeachDB.get_beach(id).kiosk), "beach"):
		return false
	kiosks[id] = true
	notify("Kiosk open in %s! Money while you sleep. Very good very nice!" % BeachDB.get_beach(id).name, "good")
	AudioManager.play_sfx("upgrade")
	empire_changed.emit()
	return true


func set_next_beach(id: String) -> void:
	if id in owned_beaches:
		next_beach = id
		empire_changed.emit()


## Rough "how big is my empire" score for the menu and summary.
func empire_value() -> float:
	var v := Economy.cash
	for b in owned_beaches:
		v += float(BeachDB.get_beach(b).unlock)
	for b in kiosks:
		v += float(BeachDB.get_beach(b).kiosk)
	for id in Upgrades.levels:
		v += Upgrades.level(id) * 100.0
	return v


# --- Tutorial ---------------------------------------------------------------------------------

func tutorial_key() -> String:
	return TUTORIAL_ORDER[tutorial_step] if tutorial_step < TUTORIAL_ORDER.size() else ""


## Advance when the player does the thing the current tip asks for.
func tutorial_event(key: String) -> void:
	if tutorial_key() != key:
		return
	tutorial_step += 1
	var next := tutorial_key()
	if next != "":
		notify(Lines.TUTORIAL[next], "tutorial")
	if tutorial_step >= TUTORIAL_ORDER.size() - 1:
		tutorial_step = TUTORIAL_ORDER.size()
		SaveSystem.set_setting("tutorial_done", true)


# --- Pause, notifications, platform events --------------------------------------------------

func notify(text: String, kind := "info") -> void:
	toast.emit(text, kind)


## Several things can pause at once (shop, pause menu, busted dialog); the tree unpauses only
## when every reason is gone.
func set_paused(reason: String, on: bool) -> void:
	if on:
		_pause_reasons[reason] = true
	else:
		_pause_reasons.erase(reason)
	var p := not _pause_reasons.is_empty()
	if get_tree().paused != p:
		get_tree().paused = p
		paused_changed.emit(p)


func is_paused_by(reason: String) -> bool:
	return _pause_reasons.has(reason)


func clear_pause() -> void:
	_pause_reasons.clear()
	get_tree().paused = false
	paused_changed.emit(false)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			# Android back button: screens listen and close themselves / open the pause menu.
			back_pressed.emit()
		NOTIFICATION_WM_CLOSE_REQUEST:
			_save_if_playing()
			get_tree().quit()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			_save_if_playing()
			if day_running and not get_tree().paused:
				back_pressed.emit()  # opens the pause menu so the game waits for you


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		back_pressed.emit()
		get_viewport().set_input_as_handled()


func _save_if_playing() -> void:
	var scene := get_tree().current_scene
	if scene and scene.name == "Beach":
		SaveSystem.save_game()


# --- Save ------------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"day": day, "current_beach": current_beach, "next_beach": next_beach,
		"owned_beaches": owned_beaches.duplicate(), "kiosks": kiosks.keys(),
		"tutorial_step": tutorial_step, "best_day": best_day,
	}


func from_dict(d: Dictionary) -> void:
	day = maxi(int(d.get("day", 1)), 1)
	owned_beaches = []
	for b in d.get("owned_beaches", ["benidorm"]):
		if BeachDB.BEACHES.has(str(b)) and not (str(b) in owned_beaches):
			owned_beaches.append(str(b))
	if owned_beaches.is_empty():
		owned_beaches = ["benidorm"]
	current_beach = str(d.get("current_beach", "benidorm"))
	if not (current_beach in owned_beaches):
		current_beach = owned_beaches[0]
	next_beach = str(d.get("next_beach", current_beach))
	if not (next_beach in owned_beaches):
		next_beach = current_beach
	kiosks = {}
	for b in d.get("kiosks", []):
		if str(b) in owned_beaches:
			kiosks[str(b)] = true
	tutorial_step = int(d.get("tutorial_step", TUTORIAL_ORDER.size()))
	best_day = float(d.get("best_day", 0.0))
	empire_changed.emit()
