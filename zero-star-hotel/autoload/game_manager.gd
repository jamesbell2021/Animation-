extends Node
## Autoload: scene flow, the day clock (08:00 to 02:00), end-of-day accounting, pausing, the
## Android back button and the toast notifications every system uses to talk to the player.

signal day_started(day: int)
signal day_ended(summary: Dictionary)
signal time_changed(hour: float)
signal phase_changed(phase: String)
signal toast(text: String, kind: String)
signal paused_changed(paused: bool)
signal back_pressed

const MENU_SCENE := "res://scenes/main_menu.tscn"
const HOTEL_SCENE := "res://scenes/hotel.tscn"

const DAY_START_HOUR := 8.0
const DAY_END_HOUR := 26.0      # 02:00 the next morning
const DAY_LENGTH_SECONDS := 360.0

## Phases of a hotel day. The hotel scene reads these to decide what guests get up to.
const PHASES := [
	[8.0, "Morning"], [10.0, "Check-out"], [12.0, "Pool time"], [14.0, "Check-in"],
	[19.0, "Happy hour"], [22.0, "Night out"], [24.0, "Small hours"],
]

var day := 1
var hour := DAY_START_HOUR
var day_running := false
var phase := "Morning"
var first_day_hints := true
var _pause_reasons := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	ThemeDB.get_default_theme().merge_with(UITheme.get_theme())
	ThemeDB.get_default_theme().default_font = UITheme.bold_font()
	ThemeDB.get_default_theme().default_font_size = UITheme.FONT_SIZE
	get_tree().root.theme = UITheme.get_theme()
	get_tree().set_auto_accept_quit(false)
	get_tree().set_quit_on_go_back(false)


func _setup_input() -> void:
	var keys := {"open_shop": [KEY_U, KEY_TAB], "room_price": [KEY_R], "pint_price": [KEY_P]}
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
	var p := phase_at(hour)
	if p != phase:
		phase = p
		phase_changed.emit(phase)
	if hour >= DAY_END_HOUR:
		end_day()


static func phase_at(h: float) -> String:
	var name := "Morning"
	for ph in PHASES:
		if h >= float(ph[0]):
			name = ph[1]
	return name


# --- Scene flow --------------------------------------------------------------------------------

func goto_menu() -> void:
	_stop_day()
	clear_pause()
	get_tree().change_scene_to_file(MENU_SCENE)


func new_game(hotel_name: String) -> void:
	Economy.new_game()
	Upgrades.reset()
	Staff.new_game()
	Hotel.new_game()
	if hotel_name.strip_edges() != "":
		Hotel.name_of_hotel = hotel_name.strip_edges().left(24)
	day = 1
	first_day_hints = true
	SaveSystem.save_game()
	goto_hotel()


func continue_game() -> bool:
	if not SaveSystem.load_game():
		return false
	goto_hotel()
	return true


func goto_hotel() -> void:
	clear_pause()
	get_tree().change_scene_to_file(HOTEL_SCENE)


# --- Day cycle ---------------------------------------------------------------------------------

func start_day() -> void:
	hour = DAY_START_HOUR
	phase = phase_at(hour)
	day_running = true
	Economy.reset_day_stats()
	RandomEvents.new_day()
	RandomEvents.enabled = true
	day_started.emit(day)
	time_changed.emit(hour)
	phase_changed.emit(phase)


func end_day() -> void:
	if not day_running:
		return
	_stop_day()
	var night := Hotel.process_night()
	var wages := Staff.daily_wages()
	if wages > 0.0:
		Economy.force_spend(wages, "wages")
	var inspection := Hotel.finish_inspection()
	var s := Economy.day_stats.duplicate(true)
	s.day = day
	s.profit = Economy.profit_today()
	s.inspection = inspection
	s.reputation = Hotel.reputation()
	s.stars = Hotel.stars
	s.guests = Hotel.guest_count()
	if s.profit > 120.0:
		s.verdict = Lines.pick(Lines.DAY_GOOD)
	elif s.profit >= 0.0:
		s.verdict = Lines.pick(Lines.DAY_OK)
	else:
		s.verdict = Lines.pick(Lines.DAY_BAD)
	s.leaving = night.leaving
	day += 1
	first_day_hints = false
	SaveSystem.save_game()
	day_ended.emit(s)


func _stop_day() -> void:
	day_running = false
	RandomEvents.enabled = false


func time_string() -> String:
	var h := int(hour) % 24
	var m := int((hour - floor(hour)) * 60.0) / 10 * 10
	return "%02d:%02d" % [h, m]


func day_progress() -> float:
	return clampf((hour - DAY_START_HOUR) / (DAY_END_HOUR - DAY_START_HOUR), 0.0, 1.0)


func is_night() -> bool:
	return hour >= 22.0


# --- Pause, notifications, platform ------------------------------------------------------------

func notify(text: String, kind := "info") -> void:
	toast.emit(text, kind)


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
			back_pressed.emit()
		NOTIFICATION_WM_CLOSE_REQUEST:
			_save_if_playing()
			get_tree().quit()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			_save_if_playing()
			if day_running and not get_tree().paused:
				back_pressed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		back_pressed.emit()
		get_viewport().set_input_as_handled()


func _save_if_playing() -> void:
	var scene := get_tree().current_scene
	if scene and scene.name == "HotelWorld":
		SaveSystem.save_game()


func to_dict() -> Dictionary:
	return {"day": day}


func from_dict(d: Dictionary) -> void:
	day = maxi(int(d.get("day", 1)), 1)
	first_day_hints = day == 1
