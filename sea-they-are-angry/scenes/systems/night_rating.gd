class_name NightRating
extends RefCounted
## The dawn rating: one line at the foot of each dawn's log that says how the night went
## and gives it up to three stars, one for each of:
##   the light: it burned all night (never guttered, never dark: UPTIME of the night);
##   the souls: nobody was lost (none of the seven taken, no keeper downed);
##   the holding: nothing reached the light, nothing was wrecked, and the tower lost
##     less than HURT_MAX of its strength.
## Hard Light (Run.hard_light) adds a fourth for a night the light never went out.
## main.gd measures the night and keeps the run's total (Run.stars, Run.star_nights);
## the end cards and the game-over card show it.

const UPTIME := 0.99
const FALTERED := 0.8
const HURT_MAX := 0.2
const FULL := "★"
const EMPTY := "☆"

## The stars for a night's measures: {uptime 0..1, lost (names), downs, reached,
## wrecked, hurt (fraction of the tower's strength lost)}.
static func stars(m: Dictionary) -> int:
	var s := 0
	var lit := float(m.get("uptime", 1.0)) >= UPTIME
	if lit:
		s += 1
	if (m.get("lost", []) as Array).is_empty() and int(m.get("downs", 0)) == 0:
		s += 1
	if int(m.get("reached", 0)) == 0 and int(m.get("wrecked", 0)) == 0 and float(m.get("hurt", 0.0)) < HURT_MAX:
		s += 1
	if lit and bool(m.get("hard", false)):
		s += 1
	return s

## The most a night can earn.
static func most(hard: bool) -> int:
	return 4 if hard else 3

## The line for the dawn's log: "The light never went out. Not a soul lost. Nothing got
## through. ★★★".
static func line(m: Dictionary) -> String:
	var parts: Array[String] = []
	var up := float(m.get("uptime", 1.0))
	if up >= UPTIME:
		parts.append("The light never went out.")
	elif up >= FALTERED:
		parts.append("The light faltered.")
	else:
		parts.append("The light was out for much of the night.")
	var lost: Array = m.get("lost", [])
	var downs := int(m.get("downs", 0))
	if not lost.is_empty():
		parts.append("Lost: %s." % ", ".join(lost))
	elif downs > 0:
		parts.append("A keeper went down." if downs == 1 else "Keepers went down %d times." % downs)
	else:
		parts.append("Not a soul lost.")
	var wrecked := int(m.get("wrecked", 0))
	var reached := int(m.get("reached", 0))
	if wrecked > 0:
		parts.append("%d thing%s wrecked." % [wrecked, "" if wrecked == 1 else "s"])
	elif reached > 0:
		parts.append("%d reached the light." % reached)
	elif float(m.get("hurt", 0.0)) >= HURT_MAX:
		parts.append("The tower took a battering.")
	else:
		parts.append("Nothing got through.")
	var hard := bool(m.get("hard", false))
	return "%s  %s" % [" ".join(parts), marks(stars(m), most(hard))]

static func marks(n: int, of: int) -> String:
	return FULL.repeat(clampi(n, 0, of)) + EMPTY.repeat(maxi(0, of - n))

## The run's total for the end cards: "The nights rated: 14 of 21 stars." ("" if none).
static func total_line() -> String:
	if Run.star_nights <= 0:
		return ""
	var of := Run.star_nights * most(Run.hard_light)
	return "The nights rated: %d of %d stars%s." % [Run.stars, of, " (Hard Light)" if Run.hard_light else ""]
