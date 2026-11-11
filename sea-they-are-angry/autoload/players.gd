extends Node
## Local co-op: up to three keepers on one screen.
## P1 always plays on keyboard and mouse with the original action names.
## P2 and P3 get their own actions ("p1_attack", "p2_move_left", ...) bound to a
## gamepad, or for P2 to the arrow-key side of the keyboard when no pad is free.

const MAX := 3
const KEYBOARD_MOUSE := -1
const KEYBOARD_ARROWS := -2
const NAMES := ["Callum", "Hamish", "Mairi", "Ewan"]
const MODELS := ["callum_keeper", "hamish_keeper", "mairi_keeper", "ewan_keeper"]
const COLORS := [Color(1.0, 0.72, 0.25), Color(0.35, 0.85, 1.0), Color(1.0, 0.4, 0.8), Color(0.45, 1.0, 0.45)]
## The other palette (Settings): amber, blue, white and green, which stay apart for most
## kinds of colour blindness.
const SAFE_COLORS := [Color(1.0, 0.72, 0.25), Color(0.30, 0.55, 1.0), Color(0.96, 0.96, 0.96), Color(0.40, 0.90, 0.40)]

## Each keeper's own knack, by slot, whoever plays them (a person or a helper). Read with
## perk(slot, key); a key a keeper doesn't list is 1.0 (or 0 for "pellets" and
## "mend_wood"). The host computes them (keepers run there), so on a LAN they follow the
## slot. docs/DESIGN.md and docs/DECISIONS.md (2026-11-11) have the reasons.
##  hook_dmg, hook_push: the boathook's damage and shove; ledge_shove: how surely an
##    outward blow puts a creature over the ledge (the aim it needs is SHOVE_DOT / this).
##  pellets: extra shotgun pellets; spread: the cone, x; draw: how fast the bow draws, x.
##  work: how fast a hammer job or a pour (lamp oil, diesel) goes, x; mend_wood: driftwood
##    off a mend that costs more than one thing.
##  walk: speed on foot (walking and sprinting), x; sprint_len: how long a sprint lasts,
##    x; sprint_rest: the wait after it, x; getup: time lying after a knock-down, x.
const PERKS := [
	{"hook_dmg": 1.35, "hook_push": 1.6, "ledge_shove": 2.5},
	{"pellets": 1.0, "spread": 0.75, "draw": 1.25},
	{"work": 1.4, "mend_wood": 1.0},
	{"walk": 1.15, "sprint_len": 1.4, "sprint_rest": 0.6, "getup": 0.65},
]
## The line each keeper's knack gets on the title and in How to Play.
const PERK_TEXT := [
	"the old hand with the hook: boathook blows hit 35% harder and shove further",
	"the shot: the shotgun throws an extra pellet in a tighter cone, the bow draws 25% faster",
	"the mechanic: mends and refuels 40% faster, and a mend costs a driftwood less",
	"the young one: 15% faster on foot, sprints longer, gets up sooner",
]

## The same, in a few words (the title's keeper lines).
const PERK_SHORT := ["hits hardest with the hook", "the best shot", "mends and refuels fastest", "the quickest on foot"]

## A keeper's knack (see PERKS): the multiplier, or the amount, for `key` in this slot.
static func perk(slot: int, key: String) -> float:
	var row: Dictionary = PERKS[posmod(slot, PERKS.size())]
	if row.has(key):
		return float(row[key])
	return 0.0 if key in ["pellets", "mend_wood"] else 1.0

## A mend's cost for the keeper in this slot: Mairi pays a driftwood less when it costs
## more than one thing (the lighthouse's driftwood and scrap, the garden's driftwood and kelp).
static func mend_cost(cost: Dictionary, slot: int) -> Dictionary:
	var off := int(perk(slot, "mend_wood"))
	var things := 0
	for k in cost:
		things += int(cost[k])
	if off <= 0 or things <= 1 or int(cost.get("driftwood", 0)) <= 0:
		return cost
	var out := cost.duplicate()
	out["driftwood"] = int(out["driftwood"]) - off
	if int(out["driftwood"]) <= 0:
		out.erase("driftwood")
	return out

## A keeper's colour, in the palette that's chosen.
static func color_of(idx: int) -> Color:
	var list: Array = SAFE_COLORS if Settings.palette == 1 else COLORS
	return list[idx % list.size()]
const ACTIONS := ["move_left", "move_right", "move_up", "move_down", "aim_left", "aim_right", "aim_up", "aim_down", "attack", "interact", "operate", "beam_mode", "sprint", "jump", "flare", "use_dirty", "weapon_next", "weapon_prev"]

var wanted := 1
## Fill the empty places with helper keepers run by the computer, so there are always
## MAX keepers on the rock. Tests that script every keeper turn this off.
var helpers := true
var devices: Array[int] = [KEYBOARD_MOUSE]
var nodes: Array[Node] = []

func _ready() -> void:
	if not InputMap.has_action("pause"):
		InputMap.add_action("pause")
		var esc := InputEventKey.new()
		esc.keycode = KEY_ESCAPE
		InputMap.action_add_event("pause", esc)
		var start := InputEventJoypadButton.new()
		start.button_index = JOY_BUTTON_START
		start.device = -1
		InputMap.action_add_event("pause", start)

## A second or third person joins a local game that's under way: press Insert (the
## arrow keys' keeper) or A on a gamepad that keeper one isn't using. By day or at dawn
## (not in the dark); the first computer keeper becomes theirs, at the cottage, on full
## health, and the screen splits when they're apart (the camera follows whoever isn't the
## computer's).
func _input(ev: InputEvent) -> void:
	if not Run.active or nodes.is_empty() or wanted >= MAX:
		return
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_INSERT:
		join(KEYBOARD_ARROWS)
	elif ev is InputEventJoypadButton and ev.pressed and ev.button_index == JOY_BUTTON_A and ev.device != InputSetup.main_pad:
		join(ev.device)

## Why nobody can join now ("" when someone can).
func join_blocked(device: int) -> String:
	if Net.online():
		return "Joining a LAN game is done from the lobby."
	if devices.has(device):
		return "That controller is already playing."
	if wanted >= MAX:
		return "All three keepers are people already."
	if Cycle.phase != Cycle.Phase.DAY and Cycle.phase != Cycle.Phase.DAWN:
		return "Join by day: wait for the light."
	if wanted >= nodes.size() or not is_instance_valid(nodes[wanted]) or not nodes[wanted].ai:
		return "No computer keeper to hand over."
	return ""

## Seat a new person on `device`. Returns their keeper, or null (with a word on screen).
func join(device: int) -> Player:
	var why := join_blocked(device)
	if why != "":
		if not why.begins_with("That controller"):
			Events.message.emit(why)
		return null
	var p: Player = nodes[wanted]
	var brain := p.get_node_or_null("KeeperAI")
	if brain != null:
		brain.queue_free()
	p.ai = false
	p.ai_move = Vector2.ZERO
	p.in_menu = false
	devices.append(device)
	bind_device(wanted, device)
	wanted += 1
	# Playing with someone: the pad is theirs now, not keeper one's.
	InputSetup.set_pad(false)
	var at := Terrain.at_angle(-18.0, 10.5)
	p.global_position = Vector3(at.x, Terrain.height_at(at.x, at.z) + 0.2, at.z)
	p.hp = p.max_hp
	Events.message.emit("%s joins: %s" % [p.keeper_name(), device_label(wanted - 1)])
	Audio.sfx("ui_accept", Vector3.INF, -2.0, 0.0)
	return p

func count() -> int:
	return maxi(1, nodes.size())

## How many keepers people are playing (at least 1): what the creatures scale with.
func humans() -> int:
	var n := 0
	for p in nodes:
		if is_instance_valid(p) and not p.ai:
			n += 1
	return maxi(1, n)

func alive_count() -> int:
	var n := 0
	for p in nodes:
		if is_instance_valid(p) and not p.downed:
			n += 1
	return n

func all_down() -> bool:
	return not nodes.is_empty() and alive_count() == 0

## Decide each keeper's device for a run of n players and (re)create their actions.
func configure(n: int) -> void:
	wanted = clampi(n, 1, MAX)
	devices = [KEYBOARD_MOUSE]
	var pads := Input.get_connected_joypads()
	var next_pad := 0
	for i in range(1, wanted):
		if next_pad < pads.size():
			devices.append(pads[next_pad])
			next_pad += 1
		elif not devices.has(KEYBOARD_ARROWS):
			devices.append(KEYBOARD_ARROWS)
		else:
			# Bind to the next pad id anyway, so a controller plugged in later works.
			devices.append(next_pad)
			next_pad += 1
	for i in range(1, wanted):
		bind_device(i, devices[i])
	# Playing alone, keeper one may use a pad as well as the keyboard and mouse.
	InputSetup.set_pad(wanted == 1)
	nodes.clear()

static func action(idx: int, name: String) -> String:
	if idx == 0:
		return name
	return "p%d_%s" % [idx, name]

func device_label(idx: int) -> String:
	var d := devices[idx] if idx < devices.size() else KEYBOARD_MOUSE
	if d == KEYBOARD_MOUSE:
		return "Keyboard + mouse"
	if d == KEYBOARD_ARROWS:
		return "Arrow keys (Ctrl swing, M use, / lamp, . beam, ; flare, [ ] weapons, Enter jump)"
	var pad_name := Input.get_joy_name(d)
	return "Gamepad %d%s" % [d + 1, (": " + pad_name) if pad_name != "" else " (not connected)"]

func bind_device(idx: int, device: int) -> void:
	for a in ACTIONS:
		var name := action(idx, a)
		if InputMap.has_action(name):
			InputMap.erase_action(name)
		InputMap.add_action(name, 0.25)
	if device == KEYBOARD_ARROWS:
		_key(idx, "move_left", KEY_LEFT)
		_key(idx, "move_right", KEY_RIGHT)
		_key(idx, "move_up", KEY_UP)
		_key(idx, "move_down", KEY_DOWN)
		_key(idx, "attack", KEY_CTRL)
		_key(idx, "interact", KEY_M)
		_key(idx, "operate", KEY_SLASH)
		_key(idx, "beam_mode", KEY_PERIOD)
		_key(idx, "sprint", KEY_COMMA)
		_key(idx, "jump", KEY_KP_ENTER)
		_key(idx, "flare", KEY_SEMICOLON)
		_key(idx, "use_dirty", KEY_APOSTROPHE)
		_key(idx, "weapon_next", KEY_BRACKETRIGHT)
		_key(idx, "weapon_prev", KEY_BRACKETLEFT)
		return
	_axis(idx, "move_left", device, JOY_AXIS_LEFT_X, -1.0)
	_axis(idx, "move_right", device, JOY_AXIS_LEFT_X, 1.0)
	_axis(idx, "move_up", device, JOY_AXIS_LEFT_Y, -1.0)
	_axis(idx, "move_down", device, JOY_AXIS_LEFT_Y, 1.0)
	_axis(idx, "aim_left", device, JOY_AXIS_RIGHT_X, -1.0)
	_axis(idx, "aim_right", device, JOY_AXIS_RIGHT_X, 1.0)
	_axis(idx, "aim_up", device, JOY_AXIS_RIGHT_Y, -1.0)
	_axis(idx, "aim_down", device, JOY_AXIS_RIGHT_Y, 1.0)
	_button(idx, "attack", device, JOY_BUTTON_X)
	_axis(idx, "attack", device, JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_button(idx, "interact", device, JOY_BUTTON_A)
	_button(idx, "jump", device, JOY_BUTTON_A)
	_button(idx, "operate", device, JOY_BUTTON_Y)
	_button(idx, "beam_mode", device, JOY_BUTTON_B)
	_button(idx, "sprint", device, JOY_BUTTON_RIGHT_SHOULDER)
	_axis(idx, "flare", device, JOY_AXIS_TRIGGER_LEFT, 1.0)
	_button(idx, "use_dirty", device, JOY_BUTTON_LEFT_SHOULDER)
	_button(idx, "weapon_next", device, JOY_BUTTON_DPAD_RIGHT)
	_button(idx, "weapon_prev", device, JOY_BUTTON_DPAD_LEFT)

func _key(idx: int, a: String, key: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = key
	InputMap.action_add_event(action(idx, a), ev)

func _button(idx: int, a: String, device: int, button: JoyButton) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = device
	ev.button_index = button
	InputMap.action_add_event(action(idx, a), ev)

func _axis(idx: int, a: String, device: int, axis: JoyAxis, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.device = device
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action(idx, a), ev)
