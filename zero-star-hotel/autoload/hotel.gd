extends Node
## Autoload: the hotel itself. Twelve rooms over three floors (only some open at first), the
## guest groups staying in them, their happiness, the reviews they leave, the reputation those
## add up to, and the road from zero stars to three (requirements plus an inspector's visit).

signal rooms_changed
signal guests_changed
signal review_added(review: Dictionary)
signal stars_changed(stars: int)
signal inspection_changed

const FLOORS := 3
const PER_FLOOR := 4
const ROOMS := FLOORS * PER_FLOOR
const QUALITY_NAMES := ["Grim", "Basic", "Decent", "Nice"]
const QUALITY_DESC := [
	"Damp. Stained. A lock that mostly locks.",
	"A lock that locks! A mattress from this decade!",
	"Matching curtains, working shower, a kettle.",
	"Fresh paint, air-con, a telly from this century.",
]
const QUALITY_COST := [120.0, 300.0, 600.0]
const BASE_RATE := [12.0, 20.0, 32.0, 48.0]   # per guest, per night
const REVIEW_WINDOW := 12
const MAX_STRIKES := 2

var name_of_hotel := Lines.HOTEL_DEFAULT_NAME
var rooms: Array = []           # Array of room Dictionaries
var groups: Array = []          # guest groups currently staying
var reviews: Array = []         # newest last
var stars := 0
var inspection_day := -1        # day the inspector visits (-1 = none booked)
var strikes := 0                # problems the inspector saw today
var last_inspection_day := -10
var _next_group_id := 1
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	new_game()


func new_game() -> void:
	rooms = []
	for i in ROOMS:
		rooms.append({"open": false, "quality": 0, "dirt": 40.0, "damage": 0, "roaches": 0, "group": -1})
	for i in [0, 1]:
		rooms[i].open = true
	rooms[0].roaches = 2
	groups = []
	reviews = []
	for r in Lines.PREVIOUS_OWNER_REVIEWS:
		reviews.append({"stars": r[0], "name": r[1], "text": r[2], "type": "", "day": 0})
	stars = 0
	inspection_day = -1
	strikes = 0
	last_inspection_day = -10
	name_of_hotel = Lines.HOTEL_DEFAULT_NAME
	rooms_changed.emit()
	guests_changed.emit()


# --- Rooms ------------------------------------------------------------------------------------

static func floor_of(i: int) -> int:
	return i / PER_FLOOR


static func room_label(i: int) -> String:
	return "%d%02d" % [floor_of(i) + 1, i % PER_FLOOR + 1]


func floor_unlocked(f: int) -> bool:
	return f < Upgrades.floors_open()


func open_count() -> int:
	return rooms.filter(func(r): return r.open).size()


func open_cost() -> float:
	return roundf(150.0 * pow(1.16, open_count() - 2))


func can_open(i: int) -> String:
	var r: Dictionary = rooms[i]
	if r.open:
		return "Already open"
	if not floor_unlocked(floor_of(i)):
		return "Open this floor first (Building upgrades)"
	if not Economy.can_afford(open_cost()):
		return "Not enough cash"
	return ""


func open_room(i: int) -> bool:
	if can_open(i) != "":
		return false
	Economy.spend(open_cost(), "upgrade")
	rooms[i].open = true
	rooms[i].dirt = 10.0
	rooms_changed.emit()
	return true


func quality_cost(i: int) -> float:
	var q := int(rooms[i].quality)
	return QUALITY_COST[q] if q < QUALITY_COST.size() else INF


func upgrade_room(i: int) -> bool:
	var r: Dictionary = rooms[i]
	if not r.open or int(r.quality) >= 3 or not Economy.spend(quality_cost(i), "upgrade"):
		return false
	r.quality = int(r.quality) + 1
	r.damage = 0
	r.dirt = minf(float(r.dirt), 10.0)
	rooms_changed.emit()
	return true


func room_rate(i: int) -> float:
	return roundf(BASE_RATE[int(rooms[i].quality)] * Economy.room_mult() * (1.0 + 0.35 * stars))


func free_rooms() -> Array:
	var out := []
	for i in ROOMS:
		if rooms[i].open and int(rooms[i].group) < 0:
			out.append(i)
	return out


func clean(i: int, amount := 100.0) -> void:
	rooms[i].dirt = maxf(float(rooms[i].dirt) - amount, 0.0)
	rooms_changed.emit()


func repair(i: int) -> void:
	rooms[i].damage = 0
	rooms_changed.emit()


func squash_roach(i: int) -> void:
	rooms[i].roaches = maxi(int(rooms[i].roaches) - 1, 0)
	rooms_changed.emit()


func add_roaches(i: int, n: int) -> void:
	rooms[i].roaches = clampi(int(rooms[i].roaches) + n, 0, 8)
	rooms_changed.emit()


func damage_room(i: int, amount := 1) -> void:
	rooms[i].damage = clampi(int(rooms[i].damage) + amount, 0, 3)
	rooms_changed.emit()


func repair_cost(i: int) -> float:
	return [0.0, 25.0, 60.0, 120.0][int(rooms[i].damage)]


# --- Guests ------------------------------------------------------------------------------------

func group(id: int) -> Dictionary:
	for g in groups:
		if int(g.id) == id:
			return g
	return {}


## How likely a free room gets booked today: reputation, stars and price all matter.
func booking_chance() -> float:
	var rep := reputation()
	var price_penalty := (Economy.room_mult() - 1.0) * 0.45
	return clampf(0.32 + 0.1 * rep + 0.08 * stars - price_penalty, 0.1, 0.95)


## Books a new group into a free room (or returns {} when nobody turns up).
func try_booking() -> Dictionary:
	var free := free_rooms()
	if free.is_empty() or _rng.randf() > booking_chance():
		return {}
	var type_id := GuestTypes.weighted_pick(GuestTypes.booking_mix(stars), _rng)
	var t := GuestTypes.get_type(type_id)
	var room: int = free[_rng.randi() % free.size()]
	var g := {
		"id": _next_group_id, "type": type_id, "room": room,
		"size": _rng.randi_range(int(t.group[0]), int(t.group[1])),
		"nights": _rng.randi_range(1, 3), "happiness": 60.0, "seed": _rng.randi(),
		"reasons": {}, "arrived": false,
	}
	_next_group_id += 1
	rooms[room].group = g.id
	groups.append(g)
	guests_changed.emit()
	rooms_changed.emit()
	return g


## Positive or negative; reason is remembered so the review can mention it.
func adjust(group_id: int, delta: float, reason := "") -> void:
	var g := group(group_id)
	if g.is_empty():
		return
	var fussy := float(GuestTypes.get_type(g.type).fussy)
	if delta < 0.0:
		delta *= 0.5 + fussy
	g.happiness = clampf(float(g.happiness) + delta, 0.0, 100.0)
	if reason != "":
		g.reasons[reason] = float(g.reasons.get(reason, 0.0)) + delta


## The first impression when a group walks into their room.
func on_check_in(group_id: int) -> void:
	var g := group(group_id)
	if g.is_empty():
		return
	g.arrived = true
	var r: Dictionary = rooms[int(g.room)]
	adjust(group_id, [-8.0, 2.0, 8.0, 14.0][int(r.quality)], "room")
	adjust(group_id, [-3.0, 4.0, 8.0][Upgrades.level("reception")], "reception")
	if float(r.dirt) > 50.0:
		adjust(group_id, -15.0, "dirty")
	if int(r.damage) > 0:
		adjust(group_id, -8.0 * int(r.damage), "damage")
	if int(r.roaches) > 0:
		adjust(group_id, -4.0 * int(r.roaches), "roaches")
	# Over-paying guests expect more.
	adjust(group_id, (1.0 - Economy.room_mult()) * 20.0, "price")


## Checks a group out and writes their review. Returns the review.
func check_out(group_id: int) -> Dictionary:
	var g := group(group_id)
	if g.is_empty():
		return {}
	var h := float(g.happiness)
	var n := clampi(int(roundf(1.0 + h / 25.0)), 1, 5)
	var review := {
		"stars": n, "type": g.type, "day": GameManager.day,
		"name": "%s, room %s" % [GuestTypes.get_type(g.type).name, room_label(int(g.room))],
		"text": _review_text(n, g),
	}
	reviews.append(review)
	while reviews.size() > 40:
		reviews.pop_front()
	var room: Dictionary = rooms[int(g.room)]
	if int(room.group) == group_id:
		room.group = -1
	groups.erase(g)
	review_added.emit(review)
	guests_changed.emit()
	rooms_changed.emit()
	return review


func _review_text(n: int, g: Dictionary) -> String:
	# Mention the worst (or best) thing that happened to them.
	var worst := ""
	var worst_v := 0.0
	for k in g.reasons:
		if float(g.reasons[k]) < worst_v:
			worst_v = float(g.reasons[k])
			worst = k
	if n <= 2 and worst != "":
		var specific := {
			"roaches": "Cockroaches. Everywhere. EVERYWHERE.",
			"noise": "Couldn't sleep for the raves next door.",
			"theft": "Someone nicked my stuff from the room!",
			"dirty": "The room was filthy when we arrived.",
			"damage": "The telly was smashed and the bed was broken.",
			"fight": "Woke up to a brawl at the bar. Twice.",
			"pool": "The pool was a swamp. Something touched my leg.",
			"lounger": "Lost a sunlounger war on day one. Never recovered.",
			"price": "Paid a fortune for THIS?",
		}
		if specific.has(worst):
			return specific[worst]
	return Lines.pick(Lines.REVIEWS[n], _rng)


## What each staying group pays for tonight, and how their rooms suffer. Called at day end.
func process_night() -> Dictionary:
	var income := 0.0
	var leaving := []
	for g in groups:
		if not bool(g.get("arrived", false)):
			continue
		var i := int(g.room)
		var pays := float(GuestTypes.get_type(g.type).pays)
		income += room_rate(i) * pays * int(g.size)
		var r: Dictionary = rooms[i]
		r.dirt = minf(float(r.dirt) + 30.0 + 15.0 * float(GuestTypes.get_type(g.type).trouble), 100.0)
		g.nights = int(g.nights) - 1
		if int(g.nights) <= 0:
			leaving.append(int(g.id))
	# Dirty rooms breed cockroaches (pest control helps a lot).
	for i in ROOMS:
		var r: Dictionary = rooms[i]
		if not r.open:
			continue
		var breed := (float(r.dirt) / 100.0) * 1.6 * Upgrades.roach_mult() * RandomEvents.mult("roaches")
		if int(r.roaches) > 0:
			breed += 0.6 * Upgrades.roach_mult()
		var n := int(floor(breed + _rng.randf() * 0.8 - 0.3))
		if n > 0:
			add_roaches(i, n)
	if income > 0.0:
		Economy.earn(roundf(income), "rooms")
	Economy.day_stats.nights = groups.size()
	guests_changed.emit()
	rooms_changed.emit()
	return {"income": income, "leaving": leaving}


func occupancy() -> int:
	return groups.size()


func guest_count() -> int:
	var n := 0
	for g in groups:
		n += int(g.size)
	return n


# --- Reputation and stars ------------------------------------------------------------------------

func reputation() -> float:
	if reviews.is_empty():
		return 1.0
	var recent := reviews.slice(maxi(reviews.size() - REVIEW_WINDOW, 0))
	var total := 0.0
	for r in recent:
		total += float(r.stars)
	return total / recent.size()


func _all_open_rooms_at(q: int) -> bool:
	for r in rooms:
		if r.open and int(r.quality) < q:
			return false
	return true


## The inspector's checklist for the next star: [label, met?] pairs.
func requirements(for_star := -1) -> Array:
	var s := stars + 1 if for_star < 0 else for_star
	var rep := reputation()
	match s:
		1:
			return [
				["Average review 2.0+ (now %.1f)" % rep, rep >= 2.0],
				["Every open room at least Basic", _all_open_rooms_at(1)],
				["Pool: Clean Pool (no swamp)", Upgrades.level("pool") >= 1],
				["Pool fence & gate", Upgrades.level("fence") >= 1],
				["\"NO DIVING\" signs", Upgrades.level("signs") >= 1],
				["At least one cleaner", Staff.count_role("cleaner") >= 1],
			]
		2:
			return [
				["Average review 3.0+ (now %.1f)" % rep, rep >= 3.0],
				["6 rooms open (now %d)" % open_count(), open_count() >= 6],
				["Every open room at least Decent", _all_open_rooms_at(2)],
				["Reception: Proper Desk", Upgrades.level("reception") >= 1],
				["Bar: The Drunken Duck", Upgrades.level("bar") >= 1],
				["A lifeguard", Staff.count_role("lifeguard") >= 1],
				["Security on the door", Staff.count_role("security") >= 1],
				["Pest Control", Upgrades.level("pest_control") >= 1],
			]
		3:
			return [
				["Average review 4.0+ (now %.1f)" % rep, rep >= 4.0],
				["10 rooms open (now %d)" % open_count(), open_count() >= 10],
				["Every open room Nice", _all_open_rooms_at(3)],
				["Reception: Air-con Lobby", Upgrades.level("reception") >= 2],
				["Bar: Cocktail Bar", Upgrades.level("bar") >= 2],
				["Pool with Slide", Upgrades.level("pool") >= 2],
				["Soundproofing", Upgrades.level("soundproofing") >= 1],
				["Room safes or CCTV", Upgrades.level("safes") + Upgrades.level("cctv") >= 1],
				["A handyman", Staff.count_role("handyman") >= 1],
			]
	return []


func requirements_met() -> bool:
	if stars >= 3:
		return false
	for r in requirements():
		if not r[1]:
			return false
	return true


func inspection_booked() -> bool:
	return inspection_day >= 0


func can_request_inspection() -> String:
	if stars >= 3:
		return "You've made it to three stars!"
	if inspection_booked():
		return "Inspector booked for day %d" % inspection_day
	if not requirements_met():
		return "Meet every requirement first"
	if GameManager.day - last_inspection_day < 2:
		return "The inspector won't come back so soon"
	return ""


func request_inspection() -> bool:
	if can_request_inspection() != "":
		return false
	inspection_day = GameManager.day + 1
	inspection_changed.emit()
	return true


func inspector_visiting() -> bool:
	return inspection_day == GameManager.day


## True only while the inspector is actually walking round (set by the hotel scene).
var inspector_on_site := false


## Problems the inspector would spot right now, for the morning heads-up.
func inspection_problems() -> Array:
	var out := []
	for i in ROOMS:
		var r: Dictionary = rooms[i]
		if not r.open:
			continue
		if int(r.roaches) > 0:
			out.append("cockroaches in %s" % room_label(i))
		elif float(r.dirt) > 65.0:
			out.append("%s is filthy" % room_label(i))
		elif int(r.damage) > 0:
			out.append("%s is smashed up" % room_label(i))
	return out


func add_strike(why: String) -> void:
	if not inspector_visiting() or not inspector_on_site:
		return
	strikes += 1
	GameManager.notify("Inspector saw: %s (%d/%d strikes)" % [why, strikes, MAX_STRIKES + 1], "bad")
	inspection_changed.emit()


## End of an inspection day: did we earn the star?
func finish_inspection() -> Dictionary:
	if not inspector_visiting():
		return {}
	var passed := strikes <= MAX_STRIKES and requirements_met()
	var result := {"passed": passed, "strikes": strikes, "star": stars + (1 if passed else 0)}
	if passed:
		stars += 1
		stars_changed.emit(stars)
	last_inspection_day = GameManager.day
	inspection_day = -1
	strikes = 0
	inspection_changed.emit()
	return result


func to_dict() -> Dictionary:
	return {"name": name_of_hotel, "rooms": rooms.duplicate(true), "groups": groups.duplicate(true),
		"reviews": reviews.duplicate(true), "stars": stars, "inspection_day": inspection_day,
		"last_inspection_day": last_inspection_day, "next_group_id": _next_group_id}


func from_dict(d: Dictionary) -> void:
	new_game()
	name_of_hotel = str(d.get("name", Lines.HOTEL_DEFAULT_NAME)).left(24)
	var saved: Array = d.get("rooms", [])
	for i in mini(saved.size(), ROOMS):
		var r: Dictionary = saved[i]
		rooms[i] = {"open": bool(r.get("open", false)), "quality": clampi(int(r.get("quality", 0)), 0, 3),
			"dirt": clampf(float(r.get("dirt", 0.0)), 0.0, 100.0), "damage": clampi(int(r.get("damage", 0)), 0, 3),
			"roaches": clampi(int(r.get("roaches", 0)), 0, 8), "group": int(r.get("group", -1))}
	groups = []
	for g in d.get("groups", []):
		if typeof(g) == TYPE_DICTIONARY and GuestTypes.TYPES.has(str(g.get("type", ""))):
			groups.append(g)
	for r in rooms:
		if int(r.group) >= 0 and group(int(r.group)).is_empty():
			r.group = -1
	reviews = d.get("reviews", reviews)
	stars = clampi(int(d.get("stars", 0)), 0, 3)
	inspection_day = int(d.get("inspection_day", -1))
	last_inspection_day = int(d.get("last_inspection_day", -10))
	_next_group_id = int(d.get("next_group_id", 1))
	rooms_changed.emit()
	guests_changed.emit()
	stars_changed.emit(stars)
