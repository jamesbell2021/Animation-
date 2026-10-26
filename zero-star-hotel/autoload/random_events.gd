extends Node
## Autoload: random chaos. Every minute or so something happens: a coach of lads, a heatwave,
## football on the telly, a foam party, a cockroach plague... Timed events apply modifiers that
## gameplay reads through mult(); instant ones fire once. The hotel scene listens to
## event_started for anything it needs to show or spawn.

signal event_started(id: String, def: Dictionary)
signal event_ended(id: String)

const EVENTS := {
	"coach": {"title": "Coach of Lads!", "duration": 0.0, "weight": 1.5, "good": true,
		"text": "A coach pulls up and twenty lads in matching T-shirts pile out. OI OI!"},
	"hens": {"title": "Hen Party Bus!", "duration": 0.0, "weight": 1.0, "good": true,
		"text": "A pink minibus. Sashes. Inflatables. Prosecco. Brace yourself."},
	"heatwave": {"title": "Heatwave!", "duration": 60.0, "weight": 1.5, "good": true,
		"text": "40 degrees! Everybody's at the pool. Keep an eye on the deep end!",
		"mods": {"pool": 1.8, "pool_risk": 1.3}},
	"football": {"title": "Football on the Telly!", "duration": 60.0, "weight": 1.3, "good": false,
		"text": "Big match at the bar. Pints are flying. So are fists, probably.",
		"mods": {"bar": 1.5, "fights": 2.0}},
	"foam": {"title": "Foam Party!", "duration": 55.0, "weight": 1.0, "good": true,
		"text": "Someone ordered a foam machine. The bar is packed. The floor is soap.",
		"mods": {"bar": 2.0, "trouble": 1.4}},
	"roach_plague": {"title": "Cockroach Plague!", "duration": 45.0, "weight": 1.0, "good": false,
		"text": "The bins weren't collected. The cockroaches are holding a conference.",
		"mods": {"roaches": 2.5}},
	"power_cut": {"title": "Power Cut!", "duration": 35.0, "weight": 0.8, "good": false,
		"text": "No air-con, no music, no lights. Guests grumble. At least the raves stop.",
		"mods": {"raves": 0.0, "mood": -1.0}},
	"vlogger": {"title": "Travel Vlogger!", "duration": 0.0, "weight": 0.7, "good": true,
		"text": "A vlogger loved the chaos: \"So bad it's brilliant!\" A five-star review!"},
	"burst_pipe": {"title": "Burst Pipe!", "duration": 0.0, "weight": 0.9, "good": false,
		"text": "Water pours through a ceiling. A room needs fixing."},
	"tour_rep": {"title": "Tour Rep Visit!", "duration": 50.0, "weight": 1.0, "good": true,
		"text": "The tour rep is sending extra guests your way today.",
		"mods": {"arrivals": 1.6}},
	"lost_property": {"title": "Lost Property!", "duration": 0.0, "weight": 0.8, "good": true,
		"text": "Cleaning out lost property: you found cash in a flip-flop."},
}

var active := {}
var enabled := false
var _timer := 40.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func _process(delta: float) -> void:
	if not enabled or get_tree().paused:
		return
	for id in active.keys():
		active[id] -= delta
		if active[id] <= 0.0:
			active.erase(id)
			event_ended.emit(id)
	_timer -= delta
	if _timer <= 0.0:
		_timer = _rng.randf_range(45.0, 85.0)
		trigger_random()


func new_day() -> void:
	for id in active.keys():
		event_ended.emit(id)
	active.clear()
	_timer = _rng.randf_range(35.0, 60.0)


func trigger_random() -> void:
	var weights := {}
	for id in EVENTS:
		if not active.has(id):
			weights[id] = float(EVENTS[id].weight)
	trigger(GuestTypes.weighted_pick(weights, _rng))


func trigger(id: String) -> void:
	if not EVENTS.has(id):
		return
	var def: Dictionary = EVENTS[id].duplicate()
	if float(def.duration) > 0.0:
		active[id] = float(def.duration)
	match id:
		"vlogger":
			Hotel.reviews.append({"stars": 5, "name": "Travel vlogger", "text": "So bad it's brilliant! Subscribe!", "type": "", "day": GameManager.day})
			Hotel.review_added.emit(Hotel.reviews.back())
		"lost_property":
			var cash := roundf(_rng.randf_range(20.0, 60.0))
			Economy.earn(cash, "other")
			def.text += " (+%s)" % Lines.money(cash)
	event_started.emit(id, def)


func is_active(id: String) -> bool:
	return active.has(id)


func mult(key: String) -> float:
	var m := 1.0
	for id in active:
		m *= float(EVENTS[id].get("mods", {}).get(key, 1.0))
	return m


## Sum of additive modifiers ("mood": happiness change per in-game hour).
func add(key: String) -> float:
	var a := 0.0
	for id in active:
		a += float(EVENTS[id].get("mods", {}).get(key, 0.0))
	return a
