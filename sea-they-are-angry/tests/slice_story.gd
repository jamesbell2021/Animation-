extends SceneTree
## The keeper's log: StoryText's pages (words, and a drawing on disk for each one that
## names one), the crossing's wording for seven, five and none saved, and StoryPages
## turning through to `finished` by key, by its own turn(), and by a held Esc.
##   godot --headless --path . --script res://tests/slice_story.gd

const PAGES := "res://scenes/ui/story_pages.gd"
const TEXT := "res://scenes/ui/story_text.gd"

var fails := 0
var _done := 0

func check(c: bool, w: String) -> void:
	print(("PASS  " if c else "FAIL  ") + w)
	if not c:
		fails += 1

func _init() -> void:
	_go.call_deferred()

func _wait(frames: int) -> void:
	for i in frames:
		await process_frame

func _seconds(s: float) -> void:
	await create_timer(s).timeout

func _key(code: Key, down: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = down
	Input.parse_input_event(ev)

func _accept() -> void:
	var ev := InputEventAction.new()
	ev.action = "ui_accept"
	ev.pressed = true
	Input.parse_input_event(ev)

func _go() -> void:
	# The scripts are loaded here, not named: a --script file is compiled before the
	# autoloads they speak to exist.
	var text = load(TEXT)
	var pages = load(PAGES)
	check(text != null and pages != null, "the story's scripts load")
	if text == null or pages == null:
		print("\n%d FAILED" % fails)
		quit()
		return

	# The words, and the drawings they name.
	var sets := {"intro": text.intro(), "crossing": text.crossing(5, ["Isla Rennie", "Peter Main"]), "diary": text.diary(), "last_dusk": text.last_dusk(), "after": text.after()}
	var sizes := {"intro": 6, "crossing": 4, "diary": 2, "last_dusk": 1, "after": 4}
	for key in sets:
		var list: Array = sets[key]
		var worded := true
		var drawn := 0
		var missing: Array[String] = []
		for page in list:
			worded = worded and page is Dictionary and String(page.get("text", "")).strip_edges() != ""
			var img := String(page.get("image", ""))
			if img != "":
				drawn += 1
				if not FileAccess.file_exists(img):
					missing.append(img.get_file())
		check(list.size() == int(sizes[key]) and worded, "%s: %d page%s, all with words" % [key, list.size(), "" if list.size() == 1 else "s"])
		check(missing.is_empty(), "%s: every drawing it names (%d) is in art/story%s" % [key, drawn, "" if missing.is_empty() else " (missing: %s)" % ", ".join(missing)])
	check(String(text.intro()[0]["date"]) == "Kirkhaven, October 1987." and String(text.diary()[0]["date"]).contains("November 1944"), "the first entry and the diary's are dated")
	check(String(text.after()[3]["image"]) == "" and String(text.after()[3]["text"]) == "A light kept is a promise.", "the last page is the promise, with no drawing")

	# The crossing's second page.
	check(String(text.crossing(7, [])[1]["text"]) == "We got all seven of them down to the Mary Ann.", "seven saved: all seven of them")
	check(String(text.crossing(5, ["Isla Rennie", "Peter Main"])[1]["text"]) == "We got five of the seven down to the Mary Ann. We lost Isla Rennie and Peter Main.", "five saved: five of the seven, and the two lost by name")
	check(String(text.crossing(0, ["A", "B", "C", "D", "E", "F", "G"])[1]["text"]) == "We got none of them down to the Mary Ann. God forgive us.", "none saved: God forgive us")
	check(String(text.crossing(4, ["A", "B", "C"])[1]["text"]).ends_with("We lost A, B and C."), "three lost are listed with commas and an 'and'")

	# The book: two pages, turned by a key and then by its own turn().
	var two := [{"image": "res://art/story/intro_1.png", "text": "One.", "date": "A date."}, {"image": "res://art/story/no_such_drawing.png", "text": "Two, on a bare page."}]
	var was_paused := paused
	var book = pages.open(root, two, "")
	book.finished.connect(func() -> void: _done += 1)
	await _wait(3)
	check(book.layer == 40 and book.process_mode == Node.PROCESS_MODE_ALWAYS and book.index == 0, "it opens on its first page, over everything, and runs while the tree is paused")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and paused == was_paused, "the mouse shows; the tree is left as it was")
	_accept()
	await _seconds(0.5)
	check(book.index == 1 and _done == 0, "a key turns to the second page (its drawing is missing: the words stand alone)")
	book.turn()
	await _seconds(0.6)
	check(_done == 1, "turning the last page: finished")
	await _seconds(0.6)
	check(not is_instance_valid(book), "and the book puts itself away")

	# Two quick turns land both pages.
	_done = 0
	book = pages.open(root, two, "")
	book.finished.connect(func() -> void: _done += 1)
	await _wait(2)
	book.turn()
	book.turn()
	await _seconds(0.6)
	check(_done == 1, "two turns one on top of the other still end it once")
	await _seconds(0.6)

	# A tap of Esc is a page turn; held for half a second it skips to the end.
	_done = 0
	book = pages.open(root, text.intro(), "")
	book.finished.connect(func() -> void: _done += 1)
	await _wait(2)
	_key(KEY_ESCAPE, true)
	await _wait(2)
	_key(KEY_ESCAPE, false)
	await _seconds(0.4)
	check(book.index == 1 and _done == 0, "Esc tapped turns one page")
	_key(KEY_ESCAPE, true)
	await _seconds(1.1)
	check(_done == 1, "Esc held skips the rest: finished from page two of six")
	_key(KEY_ESCAPE, false)
	await _seconds(0.6)
	check(not is_instance_valid(book), "and it is gone")

	# Left alone, a page turns itself.
	_done = 0
	book = pages.open(root, [{"image": "", "text": "Alone."}], "")
	book.finished.connect(func() -> void: _done += 1)
	await _wait(2)
	book._page_t = book._turn_at - 0.2
	await _seconds(0.9)
	check(_done == 1, "a page left alone turns itself (after %d seconds)" % roundi(book.TURN_AFTER if is_instance_valid(book) else 9.0))

	print("\n%s" % ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
	quit()
