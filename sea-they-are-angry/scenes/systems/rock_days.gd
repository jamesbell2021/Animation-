class_name RockDays
extends Node
## The rock's days and nights made to differ (the story's Act Two; main.gd makes one when
## StoryRock is made, so never on a LAN, where Run.story is always false).
##
## Each day one event from EVENTS, drawn by the run's seed (never the same two days
## running), announced in one short line and kept in a small note at the top of the
## screen, with a marker over its place if it has one: a wreck ashore, the old camp's
## kit, fish in close, a long clear day, the gulls' nests left full, a lifejacket with a
## page in it, something on the wireless, a cave on the holm dry at low tide.
##
## Some nights are special (NIGHTS: a storm, squid, smotherers, a quiet fog from every
## beach, the eel; a big night every BIG_EVERY): the morning gives a sign of it, dusk
## says it in one line, and the spawner shapes its table (Spawner.special_rows).
##
## And one at a time, for a day, one of the seven asks something (Villagers.REQUESTS),
## for a reward that holds (Run.favours).

const SpawnerScript := preload("res://scenes/systems/spawner.gd")
const EVENTS := ["wreck", "camp_kit", "fish", "long_day", "gulls", "lifejacket", "wireless", "low_tide"]
## The first day's draw: something gentle while the jobs list is up.
const FIRST_DAY := ["fish", "lifejacket", "camp_kit"]
const NIGHTS := ["storm", "squid", "fog", "smotherer", "eel"]
## The first night each special night can be.
const NIGHT_FROM := {"storm": 2, "squid": 2, "fog": 2, "smotherer": 3, "eel": 3}
## Every this many nights a big night (never the last, which is the kraken's).
const BIG_EVERY := 3
## The chance a night that could be special is plain, by sea.
const PLAIN_CHANCE := [0.4, 0.25, 0.0]
## The long clear day: this many seconds more of it.
const LONG_DAY := 30.0
## The seven's requests begin on this day; another opens this long after one is done.
const REQUEST_FROM := 2
const REQUEST_NEXT := 15.0
## Not opened with less of the day left than this.
const REQUEST_MIN_LEFT := 30.0
## When the lines come up after the day starts: the event, the night's sign, the request.
const SAY_EVENT := 0.6
const SAY_SIGN := 5.5
const SAY_REQUEST := 10.0
const SAY_FIRST := 7.0

## The morning's sign of a special night.
const SIGNS := {
	"storm": "The glass is falling: a storm tonight.",
	"squid": "The rock pools are black with ink this morning: squid tonight, and plenty of them.",
	"smotherer": "Pale handprints on the tower's stones at first light, going up: the smotherers will go for the lamp tonight.",
	"fog": "The fog has not lifted off the sea all day: a quiet night, but they will come from every beach.",
	"eel": "Something long went under the rope bridge at first light: the eel tonight.",
	"big": "The sea has gone flat and quiet, holding its breath: a big night tonight.",
}
## Dusk's line for it.
const DUSK := {
	"storm": "A storm night: keep warm, and keep the light.",
	"squid": "A squid night: they climb straight up the crag. Watch its faces.",
	"smotherer": "A smotherer night: several will make for the lamp. Keep a boathook to throw.",
	"fog": "A fog night: fewer of them, but from every beach at once.",
	"eel": "An eel night: it coils round the rock. Go for its head.",
	"big": "A big night. Everything to hand.",
}
## What the wireless picks up by day (the wireless event): a hint of the night.
const WIRELESS_DAY := {
	"": "Coastguard. Nothing heard from Kirkhaven since Wednesday. The harbour office does not answer.",
	"storm": "Coastguard. Gale warning, all sea areas north of Kirkhaven: severe gale nine, imminent.",
	"squid": "(Static. Under it, a wet clicking, like a great many small beaks.)",
	"smotherer": "(Static. Somebody breathing close to the set, slow and heavy, as if climbing.)",
	"fog": "Coastguard. Fog on every quarter of the rock tonight, and no wind to move it.",
	"eel": "(Static. A long low sound under it, like a cable dragged over stones.)",
	"big": "(The counting again. Tonight it does not stop at three.)",
}

## The scene (main.gd).
var main: Node
## Today's event and tonight's kind ("" for a plain night).
var today := ""
var tonight := ""
## The note's lines: what today holds, and who has asked what ("" for none).
var today_line := ""
var request := ""
## Whether today's event has been had (its stores all fetched).
var today_done := false
## Mr Baird's bible, while it lies on the shingle or is being carried.
var keepsake: Keepsake
var carrying := false
var _spawned: Array = []
## The marker over today's event's place, and the one for the open request.
var _marker: Node3D
var _req_marker: Node3D
var _lines: Array = []
var _request_in := -1.0
var _note: CanvasLayer

func _ready() -> void:
	name = "RockDays"
	add_to_group("rock_days")
	Cycle.phase_changed.connect(_on_phase)
	_note = preload("res://scenes/ui/day_note.gd").new()
	_note.days = self
	add_child(_note)

# ---- what each day and night is (from the run's seed: a reload gets the same) ----

## The event on day `n` (never the same as the day before's).
static func event_for(n: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([Run.weather_seed, n, "day"])
	if n <= 1:
		return FIRST_DAY[rng.randi() % FIRST_DAY.size()]
	var prev := event_for(n - 1)
	var night := night_kind(n)
	var pool: Array = []
	for e in EVENTS:
		# A long clear day doesn't come before a fog night.
		if e != prev and not (e == "long_day" and night == "fog"):
			pool.append(e)
	return pool[rng.randi() % pool.size()]

## What night `n` is: "" plain, or one of NIGHTS, or "big". Night 1 and the last (the
## kraken's) are always plain; never the same special two nights running.
static func night_kind(n: int) -> String:
	if n <= 1 or n >= Rescue.night():
		return ""
	if n % BIG_EVERY == 0:
		return "big"
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([Run.weather_seed, n, "night"])
	var sea := Difficulty.level()
	if rng.randf() < float(PLAIN_CHANCE[sea]):
		return ""
	var prev := night_kind(n - 1)
	var pool: Array = []
	for k in NIGHTS:
		var from := int(NIGHT_FROM[k]) + (1 if k == "eel" and sea == 0 else 0)
		if n < from or k == prev:
			continue
		# The eel on its own night anyway needs no special night.
		if k == "eel" and SpawnerScript.eel_night(n, Players.humans(), 0):
			continue
		pool.append(k)
	if pool.is_empty():
		return ""
	return pool[rng.randi() % pool.size()]

# ---- the day ----

func _on_phase(p: int) -> void:
	if not Run.active or Net.is_client() or (main.story != null and main.story.done):
		return
	match p:
		Cycle.Phase.DAY:
			_begin_day()
		Cycle.Phase.DUSK:
			_end_day()
			if tonight != "":
				_say(1.5, String(DUSK[tonight]))

func _begin_day() -> void:
	_clear()
	tonight = night_kind(Run.night)
	_set_weather()
	today = event_for(Run.night)
	today_done = false
	var said := start_event(today)
	today_line = said
	if said != "":
		# The first day's welcome line has the first few seconds to itself.
		_say(SAY_FIRST if Run.night <= 1 else SAY_EVENT, said)
	if tonight != "":
		_say(SAY_SIGN, String(SIGNS[tonight]))
	if Run.night >= REQUEST_FROM and request == "":
		_request_in = SAY_REQUEST

# A storm night is a storm whatever the glass would have rolled; a fog night is still.
func _set_weather() -> void:
	if tonight == "storm" or tonight == "fog":
		Run.weather_for = Run.night
		Run.weather_kind = Weather.Kind.STORM if tonight == "storm" else Weather.Kind.CLEAR

func _end_day() -> void:
	_lines.clear()
	_request_in = -1.0
	# The sea takes back what nobody fetched, and a request not done waits for another day.
	_clear()
	if request != "":
		_lapse()
	today_line = ""

func _clear() -> void:
	for n in _spawned:
		if is_instance_valid(n) and not n.is_queued_for_deletion():
			n.queue_free()
	_spawned.clear()
	_drop_marker()

## Start the day's event: put out what it brings and return its line ("" for none).
func start_event(id: String) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([Run.weather_seed, Run.night, id])
	var b := rng.randi() % Terrain.BEACHES.size()
	var where: String = main.compass(Terrain.beach_point(b, 0.5))
	match id:
		"wreck":
			var at := Terrain.beach_point(b, 0.3)
			_wreck_prop(Terrain.beach_point(b, 0.16), at)
			_stores([["scrap", 2], ["diesel", 1], ["shells", 3]], b, 0.34, false)
			_mark(at, "wreck")
			return "A wreck has come ashore on the %s beach: scrap, diesel and cartridges to fetch before dusk, when the sea takes her back." % where
		"camp_kit":
			# By a tower's foot, where the papers turn up too (main.NOTE_SPOTS).
			var spot: Vector2 = Terrain.CAMP_C + Vector2(-8.4, 6.1)
			var at := Salvage.ashore(Vector3(spot.x, 0.0, spot.y))
			_put("poison", 2, at)
			_put("oil", 1, at + Vector3(0.9, 0.0, 0.3))
			_put("shells", 2, at + Vector3(-0.4, 0.0, 0.9))
			_mark(at, "the old camp's kit")
			return "A crate of the old camp's kit in the long grass by the wire: rat poison, a drum of lamp oil, a few of the guards' cartridges."
		"fish":
			_stores([["food", 3]], b, 0.32, false)
			_mark(Terrain.beach_point(b, 0.32), "fish")
			return "Seals are working off the %s beach: the fish are in close. A creel's worth at the tideline." % where
		"long_day":
			Cycle.time_left += LONG_DAY
			Cycle._duration += LONG_DAY
			today_done = true
			return "The fog has lifted right off the rock: a long clear day."
		"gulls":
			for n in get_tree().get_nodes_in_group("gull_nests"):
				n.set_eggs(GullNest.MAX_EGGS)
			_mark(Terrain.islet_slip_point(0.9), "eggs")
			return "The gulls went up off Gull Rock screaming at first light, and have not settled. Their nests are full, and nobody minding them."
		"lifejacket":
			_stores([["notes", 1]], b, 0.36, false)
			_mark(Terrain.beach_point(b, 0.36), "lifejacket")
			return "A lifejacket on the %s beach, with something buttoned into it: a page wrapped in oilcloth." % where
		"wireless":
			today_done = true
			if main.events != null:
				main.events.wireless(String(WIRELESS_DAY.get(tonight, WIRELESS_DAY[""])))
			return ""
		"low_tide":
			var hb := rng.randi() % Terrain.HOLM_BEACHES.size()
			var at := Terrain.holm_beach_point(hb, 0.32)
			_cave_prop(Terrain.holm_beach_point(hb, 0.2))
			_stores([["scrap", 2], ["bio", 2], ["driftwood", 2]], hb, 0.36, true)
			_mark(at, "the cave")
			return "A tide so low the cave under the holm's %s beach is dry, with wreckage at the back of it. Search it before the tide turns at dusk." % main.compass(at - Vector3(Terrain.CAMP_C.x, 0.0, Terrain.CAMP_C.y))
	return ""

# Stores along a beach, across it.
func _stores(list: Array, beach: int, t: float, holm: bool) -> void:
	for i in list.size():
		var lateral := (float(i) - float(list.size() - 1) * 0.5) * 1.5
		var p := Terrain.holm_beach_point(beach, t, lateral) if holm else Terrain.beach_point(beach, t, lateral)
		_put(String(list[i][0]), int(list[i][1]), p)

func _put(kind: String, amount: int, at: Vector3) -> ScavengePoint:
	var sp := ScavengePoint.new(kind, amount)
	sp.once = true
	sp.position = Salvage.ashore(at)
	main.add_child(sp)
	_spawned.append(sp)
	return sp

# A wreck's bones built in code: the keel and a few ribs, half in the water.
func _wreck_prop(sea_end: Vector3, shore_end: Vector3) -> void:
	var w := Node3D.new()
	w.name = "Wreck"
	main.add_child(w)
	w.global_position = sea_end.lerp(shore_end, 0.4)
	var dir := shore_end - sea_end
	w.rotation.y = atan2(dir.x, dir.z)
	var wood := Look.flat_mat(Look.WOOD.darkened(0.25), 0.95)
	var keel := Geo.box(w, Vector3(0.35, 0.3, 4.2), Color.WHITE, Vector3(0.0, 0.1, 0.0))
	keel.material_override = wood
	keel.rotation.x = 0.06
	for i in 5:
		for side in [-1.0, 1.0]:
			var rib := Geo.box(w, Vector3(0.14, 1.3 - 0.12 * i, 0.16), Color.WHITE, Vector3(side * 0.55, 0.5, -1.6 + 0.8 * i))
			rib.material_override = wood
			rib.rotation.z = side * -0.5
	var plank := Geo.box(w, Vector3(1.0, 0.06, 1.6), Color.WHITE, Vector3(0.35, 0.25, 0.9))
	plank.material_override = wood
	plank.rotation = Vector3(0.1, 0.4, 0.2)
	_spawned.append(w)

# The cave's mouth: a few dark slabs leaning together.
func _cave_prop(at: Vector3) -> void:
	var c := Node3D.new()
	c.name = "Cave"
	main.add_child(c)
	c.global_position = at
	var rock := Look.flat_mat(Color(0.16, 0.16, 0.17), 1.0)
	for i in 3:
		var s := Geo.box(c, Vector3(1.6, 2.2, 0.6), Color.WHITE, Vector3(-1.4 + 1.4 * i, 0.9, 0.0))
		s.material_override = rock
		s.rotation = Vector3(0.2, 0.3 * (i - 1), 0.35 * (1 - i))
	_spawned.append(c)

# ---- the markers over a place ----

func _mark(at: Vector3, label: String) -> void:
	_drop_marker()
	_marker = _new_marker(at, label)

func _drop_marker() -> void:
	if is_instance_valid(_marker):
		_marker.queue_free()
	_marker = null

func _mark_request(at: Vector3, label: String) -> void:
	_drop_request_marker()
	_req_marker = _new_marker(at, label)

func _drop_request_marker() -> void:
	if is_instance_valid(_req_marker):
		_req_marker.queue_free()
	_req_marker = null

func _new_marker(at: Vector3, label: String) -> Node3D:
	var m := Marker.new(label)
	main.add_child(m)
	m.global_position = at
	return m

## Whether the marker is up, and where.
func marker_at() -> Vector3:
	return _marker.global_position if is_instance_valid(_marker) else Vector3.INF

func _process(delta: float) -> void:
	if not Run.active:
		return
	_step_lines(delta)
	if Cycle.phase != Cycle.Phase.DAY:
		return
	# The event's stores all fetched: it's done, and its marker goes (unless the bible's).
	if not today_done and _stores_left() == 0 and today != "gulls":
		today_done = true
		_drop_marker()
	if today == "gulls" and not today_done and _eggs_left() == 0:
		today_done = true
		_drop_marker()
	if _request_in >= 0.0:
		_request_in -= delta
		if _request_in < 0.0:
			open_request()
	if request == "geddes" and _stove_lit():
		complete_request(null)
	if request != "" and not Villagers.alive(request):
		_lapse()

func _stores_left() -> int:
	var n := 0
	for s in _spawned:
		if is_instance_valid(s) and s is ScavengePoint and not s.is_queued_for_deletion() and s.available:
			n += 1
	return n

func _eggs_left() -> int:
	var n := 0
	for g in get_tree().get_nodes_in_group("gull_nests"):
		n += int(g.eggs)
	return n

func _say(after: float, text: String) -> void:
	_lines.append([after, text])

func _step_lines(delta: float) -> void:
	# Each line when its own time comes (they are not queued in time order).
	var due: Array = []
	for l in _lines:
		l[0] = float(l[0]) - delta
		if float(l[0]) <= 0.0:
			due.append(l)
	for l in due:
		_lines.erase(l)
		Events.message.emit(String(l[1]))

# ---- the seven's requests ----

## Who asks next: the living not yet favoured, those never asked first, in an order fixed
## by the run's seed. "" if nobody is left to ask.
func next_asker() -> String:
	var order: Array = Villagers.all_ids()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([Run.weather_seed, "asks"])
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp = order[i]
		order[i] = order[j]
		order[j] = tmp
	var later := ""
	for id in order:
		if not Villagers.alive(id) or Villagers.favoured(id):
			continue
		if not Run.asked.has(id):
			return id
		if later == "":
			later = id
	return later

## Open the next request, if there is anyone to ask and day enough left.
func open_request(who: String = "") -> bool:
	if request != "" or Cycle.phase != Cycle.Phase.DAY:
		return false
	if who == "":
		if Cycle.time_left < REQUEST_MIN_LEFT:
			return false
		who = next_asker()
	if who == "" or not Villagers.REQUESTS.has(who):
		return false
	request = who
	if not Run.asked.has(who):
		Run.asked.append(who)
	var r: Dictionary = Villagers.REQUESTS[who]
	var ask := String(r["ask"])
	if r["kind"] == "fetch":
		var b := (Run.night + 1) % Terrain.BEACHES.size()
		var at := Terrain.beach_point(b, 0.4, -2.4)
		keepsake = Keepsake.new()
		keepsake.days = self
		keepsake.label = String(r["item"])
		main.add_child(keepsake)
		keepsake.global_position = Salvage.ashore(at)
		carrying = false
		_mark_request(keepsake.global_position, "the bible")
		ask = ask % main.compass(at)
	Events.message.emit(ask)
	return true

## The note's line for the open request.
func request_line() -> String:
	if request == "":
		return ""
	var r: Dictionary = Villagers.REQUESTS[request]
	var s := String(r["short"])
	if r["kind"] == "fetch":
		if carrying:
			return "%s: you have it. Take it to him in the camp." % String(r["item"])
		if is_instance_valid(keepsake):
			return s % main.compass(keepsake.global_position)
	if r["kind"] == "give":
		var cost: Dictionary = r["cost"]
		if not Stock.can_afford(cost):
			var have: Array[String] = []
			for k in cost:
				have.append("%d %s" % [Stock.get_amount(k), Stock.word(k)])
			return "%s  (in the store: %s)" % [s, ", ".join(have)]
		return s + "  (in the store: take it to them)"
	return s

## What a villager offers a keeper at their side ("" when they have nothing to ask).
func villager_prompt(id: String) -> String:
	if request != id:
		return ""
	var r: Dictionary = Villagers.REQUESTS[id]
	var nm := Villagers.name_of(id)
	match String(r["kind"]):
		"give":
			var cost: Dictionary = r["cost"]
			if Stock.can_afford(cost):
				return "[E] Give %s %s" % [nm, Stock.cost_str(cost)]
			return "%s wants %s" % [nm, Stock.cost_str(cost)]
		"fetch":
			if carrying:
				return "[E] Give %s %s" % [nm, "his bible" if id == "baird" else String(r["item"])]
			return String(r["short"]) % main.compass(keepsake.global_position) if is_instance_valid(keepsake) else ""
		"stove":
			return "%s: light the quarters' stove for him" % nm
	return ""

func villager_interact(id: String, keeper: Node) -> bool:
	if request != id:
		return false
	var r: Dictionary = Villagers.REQUESTS[id]
	match String(r["kind"]):
		"give":
			if not Stock.spend(r["cost"]):
				return false
		"fetch":
			if not carrying:
				return false
		_:
			return false
	complete_request(keeper)
	return true

## The bible picked up off the shingle.
func picked_up(_k: Keepsake) -> void:
	carrying = true
	keepsake = null
	Events.message.emit("Mr Baird's bible, sodden but whole. Take it to him in the camp.")
	var v := _villager(request)
	if v != null:
		_mark_request(v.global_position, Villagers.name_of(request))
	else:
		_drop_request_marker()

func _villager(id: String) -> Villager:
	if main.story == null:
		return null
	for v in main.story.people:
		if v.id == id and v.state != "lost":
			return v
	return null

## The open request done: its reward, and the next asks a little later.
func complete_request(_keeper: Node) -> void:
	var id := request
	if id == "":
		return
	request = ""
	carrying = false
	if is_instance_valid(keepsake):
		keepsake.queue_free()
	keepsake = null
	if not Run.favours.has(id):
		Run.favours.append(id)
	var said := String(Villagers.REQUESTS[id]["thanks"])
	match id:
		"baird":
			Anger.set_value(maxi(0, Anger.value - 2))
		"coull":
			if Research.has("governor"):
				said = "Sandy Coull has been over the generator again, and filled her to the brim."
				if main.camp != null and main.camp.generator != null:
					main.camp.generator.fuel = Generator.FUEL_MAX
					Run.camp_fuel = Generator.FUEL_MAX
			else:
				Run.research.append("governor")
				if Run.researching == "governor":
					Run.researching = ""
		"geddes":
			Stock.add("shells", Villagers.GEDDES_BOX)
	Audio.sfx("gather", Vector3.INF, -2.0, 0.0)
	Events.message.emit(said)
	_drop_request_marker()
	_request_in = REQUEST_NEXT

func _lapse() -> void:
	request = ""
	_drop_request_marker()
	carrying = false
	if is_instance_valid(keepsake):
		keepsake.queue_free()
	keepsake = null

func _stove_lit() -> bool:
	for n in get_tree().get_nodes_in_group("heat"):
		if n is HutStove and n.is_lit():
			return true
	return false

## A marker over a place: a gold point bobbing over it, and its name. Built in code.
class Marker:
	extends Node3D
	var label := ""
	var _t := 0.0
	var _cone: MeshInstance3D

	func _init(p_label: String = "") -> void:
		label = p_label
		name = "DayMarker"

	func _ready() -> void:
		_cone = MeshInstance3D.new()
		var m := CylinderMesh.new()
		m.top_radius = 0.32
		m.bottom_radius = 0.0
		m.height = 0.6
		m.radial_segments = 8
		m.rings = 1
		_cone.mesh = m
		_cone.material_override = Look.glow_mat(Color(1.0, 0.78, 0.36), 2.2)
		_cone.position = Vector3(0.0, 2.6, 0.0)
		add_child(_cone)
		var l := Label3D.new()
		l.text = label
		l.font_size = 34
		l.pixel_size = 0.008
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.modulate = Color(1.0, 0.84, 0.5)
		l.outline_modulate = Color(0.0, 0.0, 0.0, 0.75)
		l.position = Vector3(0.0, 3.3, 0.0)
		add_child(l)

	func _process(delta: float) -> void:
		_t += delta
		_cone.position.y = 2.6 + sin(_t * 2.4) * 0.18
		_cone.rotation.y = _t * 1.5

## Something of one of the seven's, lying on the shingle: [E] picks it up.
class Keepsake:
	extends Node3D
	var days: RockDays
	var label := ""

	func _ready() -> void:
		add_to_group("interactable")
		var book := Geo.box(self, Vector3(0.32, 0.09, 0.42), Color(0.12, 0.09, 0.07), Vector3(0.0, 0.05, 0.0))
		book.rotation.y = 0.5
		Geo.box(self, Vector3(0.3, 0.07, 0.4), Color(0.86, 0.82, 0.7), Vector3(0.0, 0.05, 0.0)).rotation.y = 0.5

	func interact_prompt() -> String:
		return "[E] Pick up %s" % label

	func interact(_p: Node) -> bool:
		Audio.sfx("gather", global_position, -2.0, 0.05)
		days.picked_up(self)
		queue_free()
		return true
