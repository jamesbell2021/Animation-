class_name StoryText
extends RefCounted
## The words of the keeper's log (docs/STORY.md, "The keeper's log"), as pages for
## StoryPages: each a drawing from art/story (tools/make_story_stills.gd makes them) and
## a line or two in the head keeper's hand. A page is
## {"image": path or "", "text": String, "date": String}; the date is a small heading,
## and is left out where the entry has none.

const ART := "res://art/story/%s.png"
const SEVEN := 7
const COUNTS := ["none", "one", "two", "three", "four", "five", "six", "seven"]

static func _page(id: String, text: String, date: String = "") -> Dictionary:
	return {"image": (ART % id) if id != "" else "", "text": text, "date": date}

## Before Act One: how Kirkhaven's light went out.
static func intro() -> Array:
	return [
		_page("intro_1", "The Board has put the harbour light on a clock. Thirty years I have kept a lamp, and a tin box with a dial is to do it for nothing.", "Kirkhaven, October 1987."),
		_page("intro_2", "They paid the three of us off on the Monday. We took rooms over The Creel and waited on the Mary Ann to carry our kit out to the rock one last time."),
		_page("intro_3", "Tuesday night the clock stuck. The harbour light never lit. Nobody noticed until the fog came in, and it came in against the wind."),
		_page("intro_4", "There was something in it."),
		_page("intro_5", "The street lamps went one after another, west to east. Mr Baird got who he could into the kirk and barred the doors."),
		_page("intro_6", "We know what a light is for. Wednesday, first light. We are going to put Kirkhaven's back."),
	]

## Between the acts: `saved` of the seven reached the boat; `lost` is the names of the rest.
static func crossing(saved: int, lost: Array) -> Array:
	return [
		_page("crossing_1", "We could not hold it. The third night it came over the quay and up the wynds."),
		_page("crossing_2", brought_down(saved, lost)),
		_page("crossing_3", "Dod Wiseman put her head to the north-east. There is one light on this coast the Board's engineers have not reached."),
		_page("crossing_4", "The rock. The old camp on the holm will shelter them. The lamp wants oil and a hand to light it, and it has both."),
	]

## The crossing's second entry: how many were brought to the boat, and who was not.
static func brought_down(saved: int, lost: Array) -> String:
	var n := clampi(saved, 0, SEVEN)
	if n >= SEVEN:
		return "We got all seven of them down to the Mary Ann."
	if n <= 0:
		return "We got none of them down to the Mary Ann. God forgive us."
	var text := "We got %s of the seven down to the Mary Ann." % COUNTS[n]
	if not lost.is_empty():
		text += " We lost %s." % _names(lost)
	return text

# "A", "A and B", "A, B and C".
static func _names(names: Array) -> String:
	var list: Array[String] = []
	for nm in names:
		list.append(String(nm))
	if list.size() == 1:
		return list[0]
	var last: String = list.pop_back()
	return "%s and %s" % [", ".join(list), last]

## On the rock, when the last pages of the internees' diary are found.
static func diary() -> Array:
	return [
		_page("diary_1", "It came up on the ninth night, the size of the holm. It took the wire and the huts.", "From the internees' diary, November 1944."),
		_page("diary_2", "The lamp was all that stopped it. It cannot abide the light in its eyes."),
	]

## The last dusk, before the kraken.
static func last_dusk() -> Array:
	return [
		_page("dusk_1", "Tonight. Everything we have is on the shingle or in our hands."),
	]

## After. The last page is the words alone.
static func after() -> Array:
	return [
		_page("after_1", "It went down at first light, and the fog went with it."),
		_page("after_2", "The sky cleared from the west. I had forgotten the colour."),
		_page("after_3", "The Board's man came out in the spring with his tin box. We showed him this log. He took the box back with him."),
		_page("", "A light kept is a promise."),
	]
