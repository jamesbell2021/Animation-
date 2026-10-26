extends Node
## The player's settings, kept in user://settings.cfg: the three volumes, the window,
## how hard the graphics work, and the first keeper's keyboard and mouse controls.
## SettingsMenu edits them; main hands over its Environment and sun to apply the
## graphics to.

signal changed

const PATH := "user://settings.cfg"
const QUALITY := ["Low", "Medium", "High"]
const QUALITY_BLURBS := [
	"No ambient shadows or reflections; lighter fog and shorter sun shadows. For older laptops.",
	"Ambient shadows on; no water reflections.",
	"Everything: ambient shadows, water reflections, full fog and long sun shadows.",
]
const SIZES := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const SCALES := [0.5, 0.67, 0.77, 0.85, 1.0]
const VOLUMES := ["Master", "Music", "SFX"]
## The controls that can be changed, in the order the menu lists them, with their names.
## The number keys for the weapons, Esc for pause and the gamepads stay as they are.
const REBINDABLE := [
	["move_up", "Walk up"], ["move_down", "Walk down"], ["move_left", "Walk left"], ["move_right", "Walk right"],
	["attack", "Swing / fire"], ["interact", "Use / pick up / repair"], ["operate", "Lamp on and off"],
	["beam_mode", "Beam: wide or narrow"], ["sprint", "Sprint"], ["flare", "Flare gun"],
	["use_dirty", "Pour dirty fuel"], ["weapon_next", "Next weapon"], ["weapon_prev", "Previous weapon"],
	["skip", "Skip the day"],
]
## Keys that can't be given to anything else: the weapons' numbers and pause.
var RESERVED: Array[String] = ["key:%d" % KEY_1, "key:%d" % KEY_2, "key:%d" % KEY_3, "key:%d" % KEY_4, "key:%d" % KEY_5, "key:%d" % KEY_ESCAPE]
## Bindings that stay alongside whatever key is chosen.
const EXTRAS := {"weapon_next": "mouse:5"}

var volumes := {"Master": 1.0, "Music": 0.8, "SFX": 1.0}
var fullscreen := false
var size_idx := 1
var quality := 2
var scale_idx := 4
## action -> "key:<keycode>" or "mouse:<button>"; only the ones changed from the defaults.
var binds := {}

var env: Environment
var sun: DirectionalLight3D
var _defaults := {}

func _ready() -> void:
	# InputSetup has bound the defaults by now; remember them so they can be restored.
	for row in REBINDABLE:
		_defaults[row[0]] = _primary(row[0])
	_load()
	apply_audio()
	apply_window()
	apply_binds()
	apply_graphics()

# ---- saving ----

func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	for bus in VOLUMES:
		volumes[bus] = clampf(float(cf.get_value("audio", bus, volumes[bus])), 0.0, 1.0)
	fullscreen = bool(cf.get_value("display", "fullscreen", fullscreen))
	size_idx = clampi(int(cf.get_value("display", "size", size_idx)), 0, SIZES.size() - 1)
	quality = clampi(int(cf.get_value("display", "quality", quality)), 0, QUALITY.size() - 1)
	scale_idx = clampi(int(cf.get_value("display", "scale", scale_idx)), 0, SCALES.size() - 1)
	if cf.has_section("controls"):
		for a in cf.get_section_keys("controls"):
			var code := str(cf.get_value("controls", a, ""))
			if _defaults.has(a) and _event(code) != null:
				binds[a] = code

func save() -> void:
	var cf := ConfigFile.new()
	for bus in VOLUMES:
		cf.set_value("audio", bus, volumes[bus])
	cf.set_value("display", "fullscreen", fullscreen)
	cf.set_value("display", "size", size_idx)
	cf.set_value("display", "quality", quality)
	cf.set_value("display", "scale", scale_idx)
	for a in binds:
		cf.set_value("controls", a, binds[a])
	cf.save(PATH)

# ---- sound ----

func set_volume(bus: String, v: float) -> void:
	volumes[bus] = clampf(v, 0.0, 1.0)
	apply_audio()
	changed.emit()

func apply_audio() -> void:
	for bus in VOLUMES:
		var i := AudioServer.get_bus_index(bus)
		if i == -1:
			continue
		var v: float = volumes[bus]
		AudioServer.set_bus_mute(i, v <= 0.001)
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.001)))

# ---- the window ----

func apply_window() -> void:
	# Headless runs (the tests) and the editor's embedded game have no window to change.
	if DisplayServer.get_name() == "headless":
		return
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var screen := DisplayServer.screen_get_usable_rect()
	var want: Vector2i = SIZES[size_idx]
	var size := Vector2i(mini(want.x, screen.size.x), mini(want.y, screen.size.y))
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(screen.position + (screen.size - size) / 2)

# ---- graphics ----

## Main calls this once its sky and sun are made; they're kept to re-apply on change.
func use_world(e: Environment, s: DirectionalLight3D) -> void:
	env = e
	sun = s
	apply_graphics()

func apply_graphics() -> void:
	var root := get_tree().root
	var s: float = SCALES[scale_idx]
	var views: Array = [root]
	views.append_array(get_tree().get_nodes_in_group("game_views"))
	for v in views:
		var vp := v as Viewport
		# Drawn smaller and sharpened back up (FSR) when the scale is below full.
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if s < 0.99 else Viewport.SCALING_3D_MODE_BILINEAR
		vp.scaling_3d_scale = s
	var low := quality == 0
	RenderingServer.directional_shadow_atlas_set_size(2048 if low else 4096, true)
	RenderingServer.environment_set_volumetric_fog_volume_size(48 if low else 64, 32 if low else 64)
	RenderingServer.environment_set_volumetric_fog_filter_active(not low)
	if is_instance_valid(env):
		env.ssao_enabled = quality >= 1
		env.ssr_enabled = quality >= 2
	if is_instance_valid(sun):
		sun.directional_shadow_max_distance = [45.0, 65.0, 80.0][quality]

# ---- controls ----

## The key or button an action is on now, as the menu and the hints should name it.
func key_name(action: String) -> String:
	return describe(_primary(action))

static func describe(code: String) -> String:
	if code.begins_with("key:"):
		var k := int(code.substr(4))
		return OS.get_keycode_string(k) if k != 0 else "?"
	if code.begins_with("mouse:"):
		match int(code.substr(6)):
			MOUSE_BUTTON_LEFT: return "Left mouse"
			MOUSE_BUTTON_RIGHT: return "Right mouse"
			MOUSE_BUTTON_MIDDLE: return "Middle mouse"
			MOUSE_BUTTON_WHEEL_UP: return "Wheel up"
			MOUSE_BUTTON_WHEEL_DOWN: return "Wheel down"
			MOUSE_BUTTON_XBUTTON1: return "Mouse 4"
			MOUSE_BUTTON_XBUTTON2: return "Mouse 5"
			var b: return "Mouse %d" % b
	return "—"

## The game's text names keeper one's default keys ("[E] Repair"). Put the keys this
## keeper really uses in their place: changed keys, the arrow-key layout, or a pad's.
const HINT_ACTIONS := {"[E]": "interact", "[R]": "operate", "[Q]": "beam_mode", "[F]": "use_dirty",
	"[LMB]": "attack", "[RMB]": "flare", "[Tab]": "weapon_next"}
const PAD_NAMES := {"interact": "A", "operate": "Y", "beam_mode": "B", "use_dirty": "LB", "attack": "X / RT", "flare": "LT", "weapon_next": "D-pad"}
const ARROW_NAMES := {"interact": "Shift", "operate": "/", "beam_mode": ".", "use_dirty": "'", "attack": "Ctrl", "flare": ";", "weapon_next": "]"}

func keys_in(text: String, keeper_idx: int = 0) -> String:
	if text.find("[") == -1:
		return text
	# On the LAN every machine's own keeper plays on its keyboard, mouse or pad.
	var first := keeper_idx == 0 or Net.online()
	var device: int = Players.KEYBOARD_MOUSE if first or keeper_idx >= Players.devices.size() else Players.devices[keeper_idx]
	for token in HINT_ACTIONS:
		if text.find(token) == -1:
			continue
		var a: String = HINT_ACTIONS[token]
		var named: String
		if first and InputSetup.pad_active or device >= 0:
			named = PAD_NAMES[a]
		elif device == Players.KEYBOARD_ARROWS:
			named = ARROW_NAMES[a]
		else:
			named = _short(key_name(a))
		text = text.replace(token, "[%s]" % named)
	return text

static func _short(n: String) -> String:
	return {"Left mouse": "LMB", "Right mouse": "RMB", "Middle mouse": "MMB"}.get(n, n)

## The code for a pressed key or mouse button, or "" for anything else.
static func code_of(ev: InputEvent) -> String:
	if ev is InputEventKey and ev.pressed and not ev.echo:
		var k: int = ev.physical_keycode if ev.keycode == 0 else ev.keycode
		return "key:%d" % k if k != 0 else ""
	if ev is InputEventMouseButton and ev.pressed:
		return "mouse:%d" % ev.button_index
	return ""

## Put an action on a key or mouse button. Whatever else was on it trades places,
## taking this action's old key, so nothing is left without one.
func rebind(action: String, code: String) -> void:
	var old := _primary(action)
	for row in REBINDABLE:
		var other: String = row[0]
		if other != action and _primary(other) == code:
			_set_bind(other, old)
	_set_bind(action, code)
	apply_binds()
	changed.emit()

func reset_controls() -> void:
	binds.clear()
	apply_binds()
	changed.emit()

func _set_bind(action: String, code: String) -> void:
	if code == _defaults.get(action, ""):
		binds.erase(action)
	else:
		binds[action] = code

func _primary(action: String) -> String:
	if binds.has(action):
		return binds[action]
	if _defaults.has(action):
		return _defaults[action]
	if not InputMap.has_action(action):
		return ""
	# The first key or mouse button the action is on, skipping the fixed extras.
	for ev in InputMap.action_get_events(action):
		var code := code_of_bound(ev)
		if code != "" and code != EXTRAS.get(action, ""):
			return code
	return ""

static func code_of_bound(ev: InputEvent) -> String:
	if ev is InputEventKey:
		return "key:%d" % (ev.keycode if ev.keycode != 0 else ev.physical_keycode)
	if ev is InputEventMouseButton:
		return "mouse:%d" % ev.button_index
	return ""

func apply_binds() -> void:
	for row in REBINDABLE:
		var a: String = row[0]
		if not InputMap.has_action(a):
			continue
		for ev in InputMap.action_get_events(a):
			if ev is InputEventKey or ev is InputEventMouseButton:
				InputMap.action_erase_event(a, ev)
		var main_code := _primary(a)
		var e := _event(main_code)
		if e != null:
			InputMap.action_add_event(a, e)
		var extra: String = EXTRAS.get(a, "")
		if extra != "" and extra != main_code:
			InputMap.action_add_event(a, _event(extra))

static func _event(code: String) -> InputEvent:
	if code.begins_with("key:"):
		var ev := InputEventKey.new()
		ev.keycode = int(code.substr(4)) as Key
		return ev
	if code.begins_with("mouse:"):
		var ev := InputEventMouseButton.new()
		ev.button_index = int(code.substr(6)) as MouseButton
		return ev
	return null
