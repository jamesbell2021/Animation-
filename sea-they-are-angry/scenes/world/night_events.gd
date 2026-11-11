class_name NightEvents
extends Node
## Small uncanny things in the night. Three slow knocks at the cottage door with nobody
## there. The wireless at dusk, stranger each night. The lights dipping as the fog comes
## ashore. A foghorn far out where no ship is due. None of it hurts anyone.
##
## The host stages them; on a LAN client this does nothing (the captions, and the sounds
## that have a place, reach it from the host). It finds the keepers, the cottage and the
## lights through the scene tree and groups, so it works where some are missing.

## The knock: from this night, after a keeper has been in the cottage this long, with
## nothing from the sea within KNOCK_CLEAR metres of it.
const KNOCK_FROM := 2
const KNOCK_INDOORS := 4.0
const KNOCK_CLEAR := 12.0
## The night's first knock comes no sooner than this (seconds into the night)...
const KNOCK_FIRST_MIN := 12.0
const KNOCK_FIRST_MAX := 45.0
## ...and another no sooner than this after it.
const KNOCK_GAP := 60.0
const KNOCK_GAP_MORE := 30.0
const KNOCK_CAPTION := "(Three slow knocks at the door.)"
const KNOCK_DB := 3.0
## While the knocks last, lights this near the door sink to this much of themselves.
const KNOCK_TIME := 2.4
const KNOCK_DIM := 0.45
const KNOCK_DIM_RADIUS := 6.0

## The wireless: from this night, this long into dusk (after the foghorn's two blasts),
## the static first and the voice this long after it.
const WIRELESS_FROM := 2
const WIRELESS_DELAY := 7.5
const WIRELESS_VOICE_AFTER := 1.3
const WIRELESS_PREFIX := "Wireless: "
const RADIO_DB := -12.0
const VOICE_DB := -9.0
## What comes over it at dusk, by night: one of these.
const WIRELESS := {
	2: ["Kirkhaven Coastguard, all stations. Fog bank reported east of the rock. Visibility elsewhere is good.",
		"Kirkhaven harbour office to the rock. Relief is on schedule. Nothing further. Out."],
	3: ["Coastguard. The forecast for your area is clear. Fog is reported on every side of the rock all the same.",
		"Fishing vessel Silver Darling, this is Kirkhaven harbour office. You are overdue. Report your position."],
	4: ["Silver Darling, Silver Darling, Kirkhaven Coastguard. Nothing heard. Calling again on the hour.",
		"Coastguard. The fog is reported moving against the wind. Vessels are advised to stand clear of it."],
	5: ["Coastguard. Silver Darling sighted two miles off, under way. She shows no lights and does not answer.",
		"Harbour office. The pier light failed at dusk. A man has gone out along the pier to see to it."],
	6: ["Harbour office to the rock. The quay lamps went out one after another, west to east. The fuses are sound.",
		"Coastguard. The man sent out to the pier light has not come back. Fog is in the harbour mouth."],
	7: ["Harbour office. Both wynds are dark, and the lamp at the kirk gate. We are on the generator. Is your lamp lit?",
		"Coastguard. Fog is at the foot of our stair. This station keeps watch for as long as it has light."],
	8: ["Harbour office. One lamp left, at the end of the quay. Somebody is knocking at the shutters. We are not",
		"(The harbour office's channel is open. Nobody speaks on it. A door bangs, a long way from the microphone.)"],
	9: ["(Static. A long way down in it a voice is counting, slowly. It stops at three.)",
		"(Static. Kirkhaven's channel is open, and nobody is speaking on it.)"],
	10: ["(Static. A voice under it says the rock, the rock, the rock, like a man reading from a list.)",
		"(Static. The counting again. It stops at three, and waits.)"],
	11: ["(Static. The voice says the rock, and then your names. It has two of them right.)",
		"(Only static. Then, quite clearly, and from very near: the rock.)"],
	12: ["(Static. The voice is counting the nights now. It has the number right.)",
		"(The rock. The rock. The rock. Then the sea, loud, from inside the set.)"],
}
## Nights past the table's end (a run kept on after the boat).
const WIRELESS_AFTER := [
	"(Static, and the sea in it.)",
	"(Static. Far down in it, somebody is still counting.)",
	"(The set warms up by itself. Static. Nothing else.)",
]
## The story's rock (Run.story): the town has fallen and nobody is coming, so the set
## has other things to say, by night.
const WIRELESS_STORY := {
	2: ["Coastguard, all stations. Kirkhaven harbour office is not answering. Any vessel near Kirkhaven, report.",
		"Coastguard. A fishing boat reports no lights at all in Kirkhaven tonight. None."],
	3: ["Coastguard. Fog lying off the coast north and south of Kirkhaven. It has not moved in three days.",
		"(Static. Somebody far off reading the shipping forecast, and stopping halfway through.)"],
	4: ["Coastguard. The Board's engineers report the rock light still showing. They ask who is tending it.",
		"(Static. A long way down in it a voice is counting, slowly. It stops at three.)"],
	5: ["(Static. A voice under it says the rock, the rock, the rock, like a man reading from a list.)",
		"(Static. Kirkhaven's channel is open, and nobody is speaking on it.)"],
	6: ["(Static. The voice is counting the nights. It has the number right.)",
		"(Static. The counting again. It stops at three, and waits.)"],
	7: ["(Static. The voice says the rock, and then your names. It has two of them right.)",
		"(Only static. Then, quite clearly, and from very near: the rock.)"],
}
## The story's last night, the kraken's.
const WIRELESS_STORY_LAST := "(The set comes on by itself. No static: only the sea in it, very loud, and very near.)"
## The last night before the boat (Rescue): she calls the rock herself.
const WIRELESS_BOAT := "Mary Ann to the rock. We have sailed, and will be off your landing at dawn. Keep the lamp burning."

## The fog coming ashore: lights of this group, this near the landing, stutter this long,
## sinking to between DIP_MIN and DIP_MAX of themselves in steps of STEP_MIN to STEP_MAX
## seconds, catching back up now and then.
const FLICKER_GROUP := "flicker_lights"
const ASHORE_RADIUS := 14.0
const FLICKER_TIME := 1.2
const DIP_MIN := 0.3
const DIP_MAX := 0.6
const STEP_MIN := 0.06
const STEP_MAX := 0.24
const CATCH_CHANCE := 0.3
const FOG_ROLL_DB := 4.0

## The other foghorn: from this night, once, somewhere in the middle third of the night;
## this far from the camera, and answered this long after from another quarter.
const HORN_FROM := 3
const HORN_RANGE := 50.0
const HORN_DB := 3.0
const HORN_ANSWER_AFTER := 5.0
const HORN_CAPTION := "(A foghorn, far out. There is no ship due.)"

## Seconds of night before the next knock may come, and how many are left tonight.
var knock_in := 0.0
var knocks_left := 0
## How long a keeper has been in the cottage.
var indoors_t := 0.0
## Seconds until this dusk's wireless (below zero: none waiting).
var wireless_in := -1.0
## How far through the night the far foghorn sounds, 0 to 1 (below zero: not tonight).
var horn_at := -1.0
## The far foghorn's caption is shown once in a run.
var horn_told := false

var _cottage: Cottage
## Things to do in a moment: [seconds left, Callable] each.
var _later: Array = []
## Lights held down now, by instance id.
var _dips := {}

## One light being dipped: what it was, what was last written to it, and the levels to
## hold it at ([until this many seconds in, this much of itself] each).
class Dip:
	extends RefCounted
	var light: Light3D
	var base := 0.0
	var wrote := 0.0
	var t := 0.0
	var time := 0.0
	var steps: Array = []

	func level() -> float:
		for s in steps:
			if t < float(s[0]):
				return float(s[1])
		return 1.0

func _init() -> void:
	name = "NightEvents"
	# After whatever owns a light has set it for the frame (the cottage's fire flickers).
	process_priority = 100

func _ready() -> void:
	Cycle.phase_changed.connect(_on_phase_changed)

func _exit_tree() -> void:
	for d: Dip in _dips.values():
		if is_instance_valid(d.light):
			d.light.light_energy = d.base
	_dips.clear()

## Whether there's anything to stage: a run going, on the machine that runs the game.
func _staging() -> bool:
	return Run.active and not Net.is_client()

func _on_phase_changed(p: int) -> void:
	if p != Cycle.Phase.NIGHT:
		knocks_left = 0
		horn_at = -1.0
		indoors_t = 0.0
	if p != Cycle.Phase.DUSK and p != Cycle.Phase.NIGHT:
		wireless_in = -1.0
		_later.clear()
	if not _staging():
		return
	# Kirkhaven (Chapter Two) has its own transmissions: harbour.gd sends those.
	if p == Cycle.Phase.DUSK and Run.night >= WIRELESS_FROM and Run.chapter != 2:
		wireless_in = WIRELESS_DELAY
	elif p == Cycle.Phase.NIGHT:
		if Run.night >= KNOCK_FROM:
			knocks_left = randi_range(1, 2)
			knock_in = randf_range(KNOCK_FIRST_MIN, KNOCK_FIRST_MAX)
		if Run.night >= HORN_FROM:
			horn_at = randf_range(1.0 / 3.0, 2.0 / 3.0)

func _process(delta: float) -> void:
	_step_dips(delta)
	if not _staging():
		return
	_step_later(delta)
	var night := Cycle.phase == Cycle.Phase.NIGHT
	if wireless_in >= 0.0 and (night or Cycle.phase == Cycle.Phase.DUSK):
		wireless_in -= delta
		if wireless_in < 0.0:
			wireless(line_for(Run.night))
	if night:
		_knock_step(delta)
		_horn_step()

# ---- the knock ----

func _knock_step(delta: float) -> void:
	if knocks_left <= 0:
		return
	knock_in = maxf(0.0, knock_in - delta)
	var cot := _find_cottage()
	if cot == null or cot.is_destroyed() or not _keeper_in(cot):
		indoors_t = 0.0
		return
	indoors_t += delta
	if knock_in > 0.0 or indoors_t < KNOCK_INDOORS or _creature_near(cot.global_position, KNOCK_CLEAR):
		return
	knocks_left -= 1
	knock_in = KNOCK_GAP + randf() * KNOCK_GAP_MORE
	indoors_t = 0.0
	knock_at(cot.to_global(Vector3(Cottage.DOOR_X, 1.1, -Cottage.DEPTH * 0.5)), KNOCK_CAPTION)

## Three knocks on a door at `at`, the lights near it sinking while they last, and a
## caption if one's given. Nothing is there.
func knock_at(at: Vector3, caption: String = "") -> void:
	if Net.is_client():
		return
	Audio.sfx("knock", at, KNOCK_DB, 0.03)
	_dip(_lights_near(at, KNOCK_DIM_RADIUS), KNOCK_TIME, [[KNOCK_TIME, KNOCK_DIM]])
	if caption != "":
		Events.message.emit(caption)

func _find_cottage() -> Cottage:
	if not is_instance_valid(_cottage):
		_cottage = null
		for s in get_tree().get_nodes_in_group("structures"):
			if s is Cottage:
				_cottage = s
				break
	return _cottage

func _keepers() -> Array:
	var scene := get_tree().current_scene
	if scene == null:
		return []
	var list: Variant = scene.get("players")
	return list if list is Array else []

# Whether a keeper somebody is playing stands in the cottage's room.
func _keeper_in(cot: Cottage) -> bool:
	for k: Variant in _keepers():
		if is_instance_valid(k) and k is Player and not k.ai and cot.interior.contains(k.global_position):
			return true
	return false

func _creature_near(at: Vector3, within: float) -> bool:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Node3D and Geo.flat_dist(e.global_position, at) < within:
			return true
	return false

# ---- the wireless ----

## What the wireless says at dusk on a night.
func line_for(night: int) -> String:
	if Run.story and Run.chapter == 1:
		if night >= Rescue.night():
			return WIRELESS_STORY_LAST
		var said: Array = WIRELESS_STORY.get(night, WIRELESS_AFTER)
		return said[randi() % said.size()]
	if not Run.endless and night == Rescue.night():
		return WIRELESS_BOAT
	var lines: Array = WIRELESS.get(night, WIRELESS_AFTER)
	return lines[randi() % lines.size()]

## The wireless coming alive: static, then a voice under it and what it says.
func wireless(line: String) -> void:
	if Net.is_client():
		return
	Audio.sfx("radio", Vector3.INF, RADIO_DB, 0.03)
	_after(WIRELESS_VOICE_AFTER, _wireless_speaks.bind(line))

func _wireless_speaks(line: String) -> void:
	Audio.sfx("radio_voice", Vector3.INF, VOICE_DB, 0.04)
	Events.message.emit(WIRELESS_PREFIX + line)

# ---- the fog ashore ----

## A tongue of fog coming up the shore at `at`: its breath, and the lights of the group
## within `within` metres of it stutter.
func fog_ashore(at: Vector3, within: float = ASHORE_RADIUS) -> void:
	if Net.is_client():
		return
	Audio.sfx("fog_roll", at, FOG_ROLL_DB, 0.06)
	flicker(_lights_near(at, within))

## Make these lights stutter for `time` seconds and then give them back exactly as they
## were. Safe to call again while they're still at it, and if one is freed meanwhile.
func flicker(lights: Array, time: float = FLICKER_TIME) -> void:
	var steps := []
	var t := 0.0
	while t < time:
		t += randf_range(STEP_MIN, STEP_MAX)
		var catching := not steps.is_empty() and randf() < CATCH_CHANCE
		steps.append([minf(t, time), randf_range(0.85, 1.0) if catching else randf_range(DIP_MIN, DIP_MAX)])
	_dip(lights, time, steps)

func _lights_near(at: Vector3, within: float) -> Array:
	var out := []
	for l in get_tree().get_nodes_in_group(FLICKER_GROUP):
		if (l is OmniLight3D or l is SpotLight3D) and Geo.flat_dist((l as Light3D).global_position, at) <= within:
			out.append(l)
	return out

func _dip(lights: Array, time: float, steps: Array) -> void:
	for l: Variant in lights:
		if not is_instance_valid(l) or not (l is Light3D):
			continue
		var light: Light3D = l
		var d: Dip = _dips.get(light.get_instance_id())
		if d == null:
			d = Dip.new()
			d.light = light
			d.base = light.light_energy
			d.wrote = d.base
			_dips[light.get_instance_id()] = d
		d.t = 0.0
		d.time = time
		d.steps = steps

func _step_dips(delta: float) -> void:
	for id: int in _dips.keys():
		var d: Dip = _dips[id]
		if not is_instance_valid(d.light):
			_dips.erase(id)
			continue
		# Whoever owns the light may have set it since (a fire flickers, dawn puts a
		# lamp out): that's what it dips from, and what it gets back.
		if d.light.light_energy != d.wrote:
			d.base = d.light.light_energy
		d.t += delta
		if d.t >= d.time:
			d.light.light_energy = d.base
			_dips.erase(id)
			continue
		d.light.light_energy = d.base * d.level()
		# Read back, not kept: the light stores it less finely than a script does.
		d.wrote = d.light.light_energy

# ---- the other foghorn ----

func _horn_step() -> void:
	if horn_at < 0.0 or Cycle.progress() < horn_at:
		return
	horn_at = -1.0
	var bearing := randf() * TAU
	Audio.sfx("foghorn", _out_to_sea(bearing), HORN_DB, 0.0)
	_after(HORN_ANSWER_AFTER, _horn_answers.bind(bearing + randf_range(PI * 0.4, PI * 1.6)))
	if not horn_told:
		horn_told = true
		Events.message.emit(HORN_CAPTION)

func _horn_answers(bearing: float) -> void:
	Audio.sfx("foghorn_short", _out_to_sea(bearing), HORN_DB, 0.0)

# A point far out on a bearing: a set distance from whoever's listening (the camera),
# so it's as faint from any quarter.
func _out_to_sea(bearing: float) -> Vector3:
	var from := Vector3.ZERO
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		from = cam.global_position
	return from + Vector3(sin(bearing), 0.0, cos(bearing)) * HORN_RANGE

# ---- doing things in a moment ----

func _after(seconds: float, what: Callable) -> void:
	_later.append([seconds, what])

func _step_later(delta: float) -> void:
	if _later.is_empty():
		return
	var due: Array[Callable] = []
	for item in _later:
		item[0] = float(item[0]) - delta
		if float(item[0]) <= 0.0:
			due.append(item[1])
	_later = _later.filter(func(item: Array) -> bool: return float(item[0]) > 0.0)
	for what in due:
		what.call()
