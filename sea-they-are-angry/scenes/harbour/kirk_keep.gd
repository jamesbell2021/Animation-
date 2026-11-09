class_name KirkKeep
extends Kirk
## The kirk as the game plays it: Kirkhaven's people are shut inside. Knock, and
## somebody answers through the door. If the doors go, the run is over. Its bell, once
## the rope is spliced, can be rung once a night: every lamp burning in the town flares
## white for a few seconds and burns what stands in it.

signal spoke(text: String)
signal bell_rung

const ROPE_COST := {"scrap": 2}
const DOOR_MEND := 60
## What they say through the door, by night (the last is kept for the last night).
const VOICES := [
	"A voice behind the door: \"Keepers? Off the rock? Then you know what light does to them. The lamps went out on Tuesday. We have been in here since.\"",
	"\"There are forty of us, and the bairns. They don't like the bell. Its rope is cut through; splice it and ring it when they're in among the lamps.\"",
	"\"The generator is at the west end of the quay. There's diesel at the fuel berth by the pier. Keep it fed and the front stays lit.\"",
	"\"They took the harbour master off the pier the first night. He'd gone out to see why the light had stopped. Keep out of the fog.\"",
	"\"We can hear them at the lamps. Every one you keep burning is a street they can't have.\"",
]
const LAST_VOICE := "\"If the lamps hold tonight we will open these doors at first light. All of us. God keep you till then.\""

## Whether raiders make for the doors (the last night, or when no lamp is left burning).
var besieged := false

func display_name() -> String:
	return "the kirk doors"

func repair_cost() -> Dictionary:
	return {"driftwood": 1}

func repair_amount() -> int:
	return DOOR_MEND

func draws_raiders() -> bool:
	if besieged:
		return true
	for l in get_tree().get_nodes_in_group("street_lamps"):
		if l.is_lit():
			return false
	return true

func _night() -> bool:
	return Cycle.phase == Cycle.Phase.DUSK or Cycle.phase == Cycle.Phase.NIGHT

func can_ring() -> bool:
	return Run.bell_mended and _night() and Run.bell_rung_night != Run.night

func interact_prompt() -> String:
	var parts: Array[String] = []
	if is_damaged():
		parts.append("[E] Mend %s (%s)" % [display_name(), Stock.cost_str(repair_cost())])
	else:
		parts.append("[E] Knock")
	if not Run.bell_mended:
		parts.append("[F] Splice the bell rope (%s)" % Stock.cost_str(ROPE_COST))
	elif can_ring():
		parts.append("[F] Ring the bell")
	elif _night():
		parts.append("The bell has been rung tonight")
	else:
		parts.append("The bell is ready for the dark")
	return "   ".join(parts)

func interact(player: Node) -> bool:
	if is_damaged():
		return super.interact(player)
	Audio.sfx("knock", door_point() + Vector3(0.0, 1.2, 0.0), -2.0, 0.0)
	var line: String = LAST_VOICE if Rescue.is_last_night() else VOICES[(Run.night - 1) % VOICES.size()]
	spoke.emit(line)
	Events.did.emit("kirk", player)
	return true

## [F]: the bell. Splice its rope first; then ring it, once a night.
func alt_use(player: Node) -> void:
	if not Run.bell_mended:
		if not Stock.spend(ROPE_COST):
			Events.message.emit("The bell rope is cut through. Splicing it needs " + Stock.cost_str(ROPE_COST) + ".")
			return
		Run.bell_mended = true
		Audio.sfx("repair", global_position, -2.0)
		Events.message.emit("The bell rope is spliced. Ring it in the dark [F], once a night, when they are in among the lamps.")
		Events.did.emit("bell", player)
		return
	if not _night():
		Events.message.emit("Keep the bell for the dark.")
		return
	if Run.bell_rung_night == Run.night:
		Events.message.emit("The bell has been rung tonight. They won't heed it twice.")
		return
	Run.bell_rung_night = Run.night
	toll(3)
	bell_rung.emit()
	Events.did.emit("bell", player)

## Ring it `times` times (the tolls a couple of seconds apart).
func toll(times: int) -> void:
	for i in times:
		if not is_inside_tree():
			return
		ring()
		Audio.ambient_sfx("kirk_bell", global_position + Vector3(0.0, 8.0, 0.0), 4.0, 0.0)
		await get_tree().create_timer(2.2).timeout
