extends Control
## How to play, from the title and the pause menu: the controls as they're set now
## (Settings), the gamepad's, and a page each on the day, the night, the camp and Gull
## Rock, and keeping together. Left and right turn the pages; Back or Esc closes it.

signal closed

const GOLD := Color(1.0, 0.78, 0.42)
const PALE := Color(0.9, 0.92, 0.95)
const DIM := Color(0.72, 0.77, 0.82)

var page := 0
var _title: Label
var _body: VBoxContainer
var _tabs: HBoxContainer
var _back: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.06, 0.97)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 90.0
	box.offset_right = -90.0
	box.offset_top = 50.0
	box.offset_bottom = -40.0
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 22)
	box.add_child(_tabs)
	for i in pages().size():
		var b := _button(_tabs, pages()[i][0], _show.bind(i), 22)
		b.focus_entered.connect(_show.bind(i))
	_title = _label(box, "", 44, GOLD)
	Fonts.use_title(_title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 12)
	scroll.add_child(_body)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 30)
	box.add_child(foot)
	_back = _button(foot, "Back", _close, 30)
	var hint := _label(foot, "◀ ▶ turn the pages", 16, DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_show(0)
	(_tabs.get_child(0) as Button).grab_focus.call_deferred()

## The pages: a tab name, a heading, and its lines ([key, what] pairs, or plain text).
func pages() -> Array:
	var k := func(a: String) -> String: return Settings.key_name(a)
	return [
		["Controls", "Keeper one's keys", [
			["%s %s %s %s" % [k.call("move_up"), k.call("move_left"), k.call("move_down"), k.call("move_right")], "Walk"],
			["Mouse", "Aim"],
			[k.call("attack"), "Swing the boathook, or fire what's in hand (hold to draw the bow or keep the flamer going)"],
			["%s, 1 to 5" % k.call("weapon_next"), "Change what's in hand: boathook, longbow, shotgun, flamer, petrol bombs (the wheel too, with two on one screen)"],
			[k.call("interact"), "Use: gather, mend, refuel, climb, row, take eggs; hold beside a downed keeper to revive them"],
			[k.call("operate"), "Work the lamp (walk in at the lighthouse door), or leave it"],
			[k.call("beam_mode"), "The beam: wide slows them, focused burns"],
			[k.call("flare"), "Fire a flare where you aim"],
			[k.call("use_dirty"), "Pour dirty fuel in at the lighthouse"],
			[k.call("sprint"), "Sprint"],
			[k.call("jump"), "Jump (up a bank or a rock). Walk on into a fence and you climb over it"],
			[k.call("skip"), "Skip the rest of the day"],
			["Middle mouse, %s %s" % [k.call("cam_left"), k.call("cam_right")], "Playing alone: hold the middle button and drag, or the keys, to turn the camera round the island"],
			["Wheel, %s %s" % [k.call("cam_zoom_in"), k.call("cam_zoom_out")], "Playing alone: zoom in toward your keeper and out again"],
			[k.call("cam_reset"), "Camera back to the usual view"],
			["Esc", "Pause"],
			"",
			"Keys can be changed in Settings. A gamepad works too: left stick walks, right stick aims, A use (or jump, with nothing to use), X or right trigger attack, Y lamp, B beam, left trigger flare, left shoulder dirty fuel, right shoulder sprint, d-pad left and right change what's in hand, d-pad up and down zoom, a stick pressed in turns the camera, Start pauses.",
		]],
		["By day", "By day: get ready", [
			"Walk the beaches and gather what the sea brought: driftwood, scrap, kelp, glowing bio, now and then a drum of oil or a tin of cartridges.",
			"Mend the fences and buildings the night broke (a hammer and driftwood). Keep the lamp's tank full: bio is its fuel.",
			"Dig kelp into the garden's beds for potatoes by dawn. Eat at the cottage when you're hungry; get warm by a fire when you're cold.",
			"At the cottage: meals, flares, dirty fuel and upgrades. At the shed: the shotgun, a flamer, longbows, arrows, petrol bombs and rat poison for the trap cairns.",
			"Walk into the cottage, the shed and the camp's huts by their doors. Playing alone, the roof lifts away to show you inside; with friends, you see each other as outlines through the walls.",
			"The first days' jobs, down the right of the screen, walk you through it.",
		]],
		["At night", "At night: keep the light", [
			"At dusk the foghorn sounds and the fog comes in. Things walk up out of the sea toward the light, and the horn names the beach they land on.",
			"Work the lamp: its wide beam slows them, its focused beam burns them on the beaches. Out on the rock, hold them off with the boathook and whatever the shed gave you.",
			"If the lamp goes dark, or every keeper is down, it's over. A downed keeper gets up if a mate holds Use beside them, and everyone gets up at dawn.",
			"Something will climb the tower and smother the lamp: throw your boathook up at it from the crag top, then fetch the hook.",
			"Hold out until the relief boat comes, and get everyone aboard.",
		]],
		["The camp", "The holm, its camp, and Gull Rock", [
			"Across the rope bridge is the holm and the old wartime camp: a diesel generator for its searchlights and huts, a wind turbine for the lights round its wire, crops in its beds and greenhouse, research at the mess.",
			"Creatures raid it from the second night. Climb a tower and work its searchlight; mend what they wreck. The turbine down means a dark camp.",
			"From the east beach's jetty a rowing boat goes out to Gull Rock, by day and not in a storm. Take the gulls' eggs there; the cottage boils three into a meal. The gulls won't thank you.",
		]],
		["Together", "Keepers together", [
			"There are always three keepers. Any nobody plays are the computer's helpers: one keeps the light, one the camp.",
			"Up to three can play on one screen (the screen splits when you're apart), or each on their own machine over the LAN.",
			"Pick how hard the sea is on the title screen. A calm sea never runs you out of ammunition.",
		]],
	]

func _show(i: int) -> void:
	page = clampi(i, 0, pages().size() - 1)
	for c in _body.get_children():
		c.queue_free()
	var p: Array = pages()[page]
	_title.text = p[1]
	for line in p[2]:
		if line is Array:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 18)
			_body.add_child(row)
			var key := _label(row, line[0], 21, GOLD)
			key.custom_minimum_size = Vector2(230, 0)
			key.autowrap_mode = TextServer.AUTOWRAP_OFF
			var what := _label(row, line[1], 19, PALE)
			what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			_label(_body, String(line), 19, PALE if line != "" else DIM)
	for j in _tabs.get_child_count():
		(_tabs.get_child(j) as Button).add_theme_color_override("font_color", GOLD if j == page else PALE)

func _label(parent: Node, text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l

func _button(parent: Node, text: String, cb: Callable, size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.add_theme_font_size_override("font_size", size)
	Fonts.use_title(b)
	b.add_theme_color_override("font_color", PALE)
	b.add_theme_color_override("font_focus_color", GOLD)
	b.add_theme_color_override("font_hover_color", GOLD)
	b.pressed.connect(func() -> void:
		Audio.sfx("ui_accept", Vector3.INF, -2.0, 0.0)
		cb.call())
	parent.add_child(b)
	return b

func _unhandled_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("ui_cancel") or ev.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_close()

func _close() -> void:
	closed.emit()
	queue_free()
