class_name Rescue
extends RefCounted
## Chapter One ends when the relief boat comes for the keepers: at the dawn after the
## last night (8 on a calm sea, 10 as the game's balanced, 12 on a raging one; two nights
## sooner once the camp's wireless is mended and has called it). Hold the light that long.
## The last night the sea throws everything it has. At that dawn the boat steams in to
## the east beach, everyone goes aboard, and it takes them off: the end of the chapter.
## A run kept on past it (Run.endless) has no boat.

const NIGHTS := [8, 10, 12]
const WIRELESS_SOONER := 2
## The last night's landings are this much bigger.
const LAST_NIGHT_SURGE := 1.3

## The night after whose dawn the boat comes.
static func night() -> int:
	var n: int = NIGHTS[Difficulty.level()]
	if Research.has("wireless"):
		n -= WIRELESS_SOONER
	return n

## Nights still to hold, counting tonight (0 once the boat has come).
static func nights_left() -> int:
	if Run.endless:
		return 0
	return maxi(0, night() - Run.night + 1)

static func is_last_night() -> bool:
	return not Run.endless and Run.night == night()

## The words for the HUD: how long until the boat.
static func countdown() -> String:
	if Run.endless:
		return ""
	var n := nights_left()
	if n <= 0:
		return "the boat is here"
	if n == 1:
		return "the boat comes at dawn"
	return "boat in %d nights" % n
