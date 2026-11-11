class_name StoryRock
extends Node
## Act Two as the story tells it (docs/STORY.md): Kirkhaven's survivors living in the
## old camp, what they bring each dawn, the diary's last pages, and the last night, when
## the kraken comes and the survivors stand with the keepers on the crag. main.gd makes
## one of these when Run.story is set; without it the rock is the old game, with the
## relief boat at the end.

## How far through the last night it rises.
const KRAKEN_AT := 0.18
## The diary's last pages are read at the dawn with this many nights still to come.
const DIARY_NIGHTS_LEFT := 3
## From the dawn the kraken dies to the last pages.
const END_AFTER := 12.0
const CLEAR_DAY := {"bg": Color(0.36, 0.60, 0.93), "amb": Color(0.66, 0.74, 0.86), "amb_e": 0.62, "sun": Color(1.0, 0.96, 0.86), "sun_e": 1.5, "fog": 0.0004, "vfog": 0.001, "tint": Color(0.72, 0.80, 0.90)}

## The scene (main.gd).
var main: Node
var people: Array[Villager] = []
var kraken: Kraken
## The kraken is dead: the story is over.
var done := false
var _lost_tonight: Array = []
var _end_t := -1.0
## The last view: low over the sea, the lighthouse against the clearing sky.
var _cine: Camera3D
var _cine_t := 0.0
const CINE_FROM := Vector3(-24.0, 5.0, 27.0)
const CINE_TO := Vector3(-19.0, 12.0, 30.0)
const CINE_LOOK := Vector3(3.0, 11.0, -4.0)
const CINE_AFTER := 4.5

func _ready() -> void:
	name = "StoryRock"
	for id in Run.villagers:
		var v := Villager.new(String(id))
		main.add_child(v)
		v.place(_camp_spot(v), "about")
		v.taken.connect(_on_taken)
		people.append(v)
	Cycle.phase_changed.connect(_on_phase)
	Events.structure_destroyed.connect(_on_wrecked)

func _camp_spot(v: Villager) -> Vector3:
	var o: Vector2 = Villagers.who(v.id).get("camp", Vector2.ZERO)
	var p := Terrain.CAMP_C + o
	return Vector3(p.x, Terrain.height_at(p.x, p.y), p.y)

func _living() -> Array:
	var out := []
	for v in people:
		if v.state != "lost":
			out.append(v)
	return out

func _on_taken(v: Villager) -> void:
	_lost_tonight.append(v.display_name())
	_lost_ids.append(v.id)

## The ids of those lost since dusk (for the grief lines at dawn).
var _lost_ids: Array = []

func _on_phase(p: int) -> void:
	if done or not Run.active:
		return
	match p:
		Cycle.Phase.DUSK:
			_lost_tonight = []
			_lost_ids = []
			if Rescue.is_last_night():
				_stand_to()
				main.hud.warn("Tonight. Everything you have, to hand. It comes tonight.")
			else:
				for v in _living():
					v.go_inside()
				if main.camp != null and Villagers.dusk_engineer(main.camp.generator):
					Events.message.emit("Sandy Coull has seen to the camp's generator  (%d%%)" % roundi(main.camp.generator.fuel))
				# With her dressings made up (her request done), the nurse sees to them at dusk too.
				Villagers.dusk_dressings(main.players)
		Cycle.Phase.DAWN:
			for v in _living():
				v.fighting = false
				v.place(_camp_spot(v), "about")
			if not Run.diary_read and Rescue.nights_left() <= DIARY_NIGHTS_LEFT and Rescue.nights_left() > 0:
				_read_diary()

# The last dusk: the survivors come over to the crag and stand with the keepers, on the
# side of the tower away from the east beach.
func _stand_to() -> void:
	var folk := _living()
	for i in folk.size():
		var v: Villager = folk[i]
		var a := deg_to_rad(lerpf(205.0, 335.0, float(i) / float(maxi(folk.size() - 1, 1))))
		var at := Vector3(sin(a) * 3.1, 0.0, cos(a) * 3.1)
		v.fighting = true
		v.place(at, "about")

## What the dawn's log says of them (main's dawn report adds these lines).
func dawn_lines() -> Array[String]:
	var lines: Array[String] = []
	if not _lost_tonight.is_empty():
		lines.append("Lost in the night: %s." % ", ".join(_lost_tonight))
		# And one of those left says something for each.
		for id in _lost_ids:
			var g := Villagers.grief_line(String(id))
			if g != "":
				lines.append(g)
	var gifts := Villagers.dawn_gifts()
	if gifts != "":
		lines.append(gifts)
	if Villagers.dawn_nursing(main.players):
		lines.append("Nurse Buchan has seen to the keepers.")
	if Rescue.nights_left() > 0 and Rescue.nights_left() <= DIARY_NIGHTS_LEFT:
		lines.append("For the last night: %s." % _arms_line())
	return lines

# What there is to throw at it.
func _arms_line() -> String:
	var parts: Array[String] = []
	parts.append("%d petrol bomb%s" % [Stock.get_amount("bombs"), "" if Stock.get_amount("bombs") == 1 else "s"])
	parts.append("%d cartridges" % Stock.get_amount("shells"))
	parts.append("%d arrows" % Stock.get_amount("arrows"))
	parts.append("the flamer rigged" if Run.flamer_rigged else "no flamer yet")
	parts.append("lamp fuel %d%%" % roundi(main.lighthouse.lamp.fuel))
	return ", ".join(parts)

func _read_diary() -> void:
	Run.diary_read = true
	main.hud.report("The internees' diary: the last pages", [
		"\"November 1944. It came up on the ninth night, the size of the holm. It took the wire and the huts.\"",
		"\"The lamp was all that stopped it. It cannot abide the light in its eyes.\"",
		"It will come again, on the last of these nights. Arm for it: bombs, cartridges, arrows, the flamer, and the lamp full.",
	], 16.0)
	# The world waits while the pages are read.
	var book: StoryPages = _pages("diary")
	if book != null:
		get_tree().paused = true
		book.finished.connect(func() -> void: get_tree().paused = false)

# One of the huts down in the night, with people in it.
func _on_wrecked(s: Node) -> void:
	if done or not Run.active or not (s is CampBuilding):
		return
	if Cycle.phase != Cycle.Phase.NIGHT and Cycle.phase != Cycle.Phase.DUSK:
		return
	var inside := []
	for v in people:
		if v.state == "inside":
			inside.append(v)
	if inside.is_empty():
		return
	var v: Villager = inside[randi() % inside.size()]
	var nm: String = (s as Structure).display_name()
	v.take()
	main.hud.warn("%s is wrecked. %s did not get out." % [nm.left(1).to_upper() + nm.substr(1), v.display_name()])

func _process(delta: float) -> void:
	if done:
		_cine_t += delta
		if _cine == null and _cine_t >= CINE_AFTER:
			_look_up()
		if _cine != null:
			var k := smoothstep(0.0, 26.0, _cine_t - CINE_AFTER)
			_cine.global_position = CINE_FROM.lerp(CINE_TO, k)
			_cine.look_at(CINE_LOOK, Vector3.UP)
	if _end_t >= 0.0:
		_end_t -= delta
		if _end_t < 0.0:
			_last_pages()
		return
	if done or not Run.active or kraken != null:
		return
	if Rescue.is_last_night() and Cycle.phase == Cycle.Phase.NIGHT and Cycle.progress() >= KRAKEN_AT:
		raise_kraken()

## It rises. The night holds until it is dead, or the light is.
func raise_kraken() -> void:
	if kraken != null:
		return
	Cycle.running = false
	kraken = Kraken.new()
	kraken.lighthouse = main.lighthouse
	kraken.camp = main.camp
	kraken.players = main.players
	kraken.fighters = _living()
	main.add_child(kraken)
	kraken.died.connect(_on_kraken_dead)
	kraken.phase_changed.connect(_on_kraken_phase)
	Audio.music("finale", 2.0)
	main.hud.report("It has come.", [
		"Off the east of the holm, the size of the holm. It will have the camp first, and then the light.",
		"At the camp: fire and the searchlights drive its arms back over the wire.",
		"On its way round: cut the arms it lays on the rock, at the pale wound.",
		"At the light: the focused beam held in its eyes blinds it [Q at the lamp]. Blind, everything that hits it counts for more.",
	], 14.0)

# The fight's stages, each with its line (docs/DESIGN.md, "The kraken").
func _on_kraken_phase(p: String) -> void:
	match p:
		"camp_east":
			main.hud.warn("It is through the wire. Fire and the searchlights: drive its arms back!")
		"camp_north":
			main.hud.warn("It is working round the north of the holm.")
		"cross":
			var stood: int = kraken.camp_left if kraken != null else 0
			main.hud.warn("It's coming round for the light! %s" % ("The camp is gone." if stood <= 0 else "%d of the camp's buildings still stand." % stood))
		"light":
			main.hud.warn("It can't abide the light! The focused beam in its eyes, and hit it with everything!")
		"dying":
			# Its strength is gone: the night is won, even if the lamp gutters out while
			# it goes down.
			Run.active = false

# It is dead: the fog goes out, the weather clears, the sky is blue.
func _on_kraken_dead() -> void:
	done = true
	Run.active = false
	SaveSys.finish_chapter(1)
	SaveSys.clear_run()
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.has_method("on_dawn"):
			e.on_dawn()
	Run.weather_kind = Weather.Kind.CLEAR
	main._lighting[Cycle.Phase.DAY] = CLEAR_DAY
	main._apply_lighting(Cycle.Phase.DAY, 9.0)
	main.atmosphere.apply(Cycle.Phase.DAY, 9.0)
	main.lighthouse.lamp._set_state(Lamp.State.OFF)
	Audio.music("ending", 3.0)
	var lines: Array = ["It went down at first light, and the fog went with it."]
	if kraken != null and kraken.camp_had > 0:
		lines.append("The camp: %s." % ("nothing left standing" if kraken.camp_left <= 0 else "%d of %d still standing" % [kraken.camp_left, kraken.camp_had]))
	main.hud.report("It is over.", lines, 9.0)
	_end_t = END_AFTER

# The keepers' camera only ever looks down. For the end it lets go of them and looks up:
# the lighthouse, the sea going calm, the sky clearing behind it.
func _look_up() -> void:
	if main.director != null:
		main.director.process_mode = Node.PROCESS_MODE_DISABLED
		main.director._overlay.visible = false
	_cine = Camera3D.new()
	_cine.fov = 48.0
	main.add_child(_cine)
	_cine.global_position = CINE_FROM
	_cine.look_at(CINE_LOOK, Vector3.UP)
	_cine.current = true
	# Nothing on the screen now but the rock and the sky.
	main.hud.visible = false

func _pages(which: String) -> StoryPages:
	if DisplayServer.get_name() == "headless":
		return null
	var list: Array = StoryText.diary() if which == "diary" else StoryText.after()
	return StoryPages.open(main, list, "")

func _last_pages() -> void:
	main.hud.visible = false
	var book: StoryPages = _pages("after")
	if book != null:
		book.finished.connect(_end_card)
	else:
		_end_card()

func _end_card() -> void:
	var card := preload("res://scenes/ui/story_end.gd").new()
	card.name = "StoryEnd"
	card.nights = Run.night
	card.kills = main._total_kills
	card.sea = Difficulty.name()
	card.saved = Villagers.count()
	card.rating = NightRating.total_line()
	card.unlocked = unlock_line()
	card.back_to_title.connect(main._after_chapter.bind(false))
	main.add_child(card)

## What finishing on this sea has unlocked (SaveSys.UNLOCKS), for the end card ("" if
## nothing: a calm sea unlocks nothing).
static func unlock_line() -> String:
	var got: Array[String] = []
	for id in SaveSys.UNLOCKS:
		if Run.difficulty >= int(SaveSys.UNLOCKS[id]["sea"]) and SaveSys.unlocked(id):
			got.append(String(SaveSys.UNLOCKS[id]["name"]))
	if got.is_empty():
		return ""
	return "Finished on %s: %s yours, in Settings." % [["a calm sea", "an angry sea", "a raging sea"][Difficulty.level()], " and ".join(got) + (" are" if got.size() > 1 else " is")]
