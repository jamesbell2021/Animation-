extends Node
## Autoload: random beach events. Every 40-80 seconds of play something happens: a cruise ship,
## a rain shower, a police crackdown, a seagull with a criminal record... Timed events apply
## modifiers that gameplay reads through mult()/add()/item_demand(); instant events fire once.
## The beach listens to event_started for anything it needs to show (rain, the ship, a rival).

signal event_started(id: String, def: Dictionary)
signal event_ended(id: String)

## duration 0 = instant. mods: multipliers/additions read by gameplay. weight: how often.
const EVENTS := {
	"cruise": {
		"title": "Cruise Ship!", "duration": 55.0, "weight": 3.0, "good": true,
		"text": "A cruise ship docks! 3,000 tourists with money! Hello chicken nugget, hello chicken nuggets!",
		"mods": {"spawn": 2.2, "budget": 1.15},
	},
	"rain": {
		"title": "Rain Shower!", "duration": 35.0, "weight": 1.6, "good": false,
		"text": "It's raining! Tourists run for cover... but umbrellas sell like hot nuggets. Very good very wet!",
		"mods": {"spawn": 0.35, "heat_decay": 1.6}, "demand": {"umbrella": 6.0}, "price": {"umbrella": 2.5},
	},
	"crackdown": {
		"title": "Police Crackdown!", "duration": 45.0, "weight": 1.6, "good": false,
		"text": "The mayor wants a tidy beach. Extra police! Not very good, not very nice!",
		"mods": {"heat_gain": 1.8, "police": 1.0},
	},
	"heatwave": {
		"title": "Heatwave!", "duration": 50.0, "weight": 2.0, "good": true,
		"text": "40 degrees! Everybody needs hats, fans and sunglasses. Very good very HOT!",
		"mods": {"spawn": 1.2}, "demand": {"sun_hat": 2.2, "fan": 2.5, "sunglasses": 1.7, "umbrella": 1.5},
	},
	"football": {
		"title": "Football Final!", "duration": 50.0, "weight": 1.6, "good": true,
		"text": "Big match tonight! Stag parties flood the beach. Very good very loud!",
		"mods": {"spawn": 1.5, "type_stag": 4.0, "type_brits": 2.0},
	},
	"fiesta": {
		"title": "Fiesta!", "duration": 50.0, "weight": 1.6, "good": true,
		"text": "It's a local fiesta! Even the police are dancing. Heat cools down fast. Very good very nice!",
		"mods": {"heat_decay": 2.5, "budget": 1.2},
	},
	"influencer": {
		"title": "You Went Viral!", "duration": 45.0, "weight": 1.4, "good": true,
		"text": "An influencer filmed your stall! \"Hello chicken nugget\" has 2 million views! Very good very nice!",
		"mods": {"attraction": 1.6, "ears": 1.5, "sale_chance": 0.08},
	},
	"supplier_sale": {
		"title": "Supplier Sale!", "duration": 9999.0, "weight": 1.2, "good": true,
		"text": "Cousin Pepe has too many boxes. Wholesale prices HALF for the rest of the day! Very good very cheap!",
		"mods": {"wholesale": 0.5},
	},
	"rival": {
		"title": "Rival Vendor!", "duration": 45.0, "weight": 1.4, "good": false,
		"text": "A rival is stealing your chicken nuggets! SHOUT near him to scare him off!",
		"mods": {},
	},
	"seagull": {
		"title": "Seagull Thief!", "duration": 0.0, "weight": 1.4, "good": false,
		"text": "A seagull stole some stock! Not very good, not very nice, very feathery!",
	},
	"wallet": {
		"title": "Lost Wallet!", "duration": 0.0, "weight": 1.0, "good": true,
		"text": "You found a wallet and returned it. The grateful owner tips you! Very good very nice, very honest!",
	},
	"complaint": {
		"title": "Hotel Complaint!", "duration": 0.0, "weight": 1.0, "good": false,
		"text": "A hotel manager complained about \"the shouting man\". Who could that be? Heat goes up!",
	},
	"coach": {
		"title": "Coach Party!", "duration": 0.0, "weight": 1.6, "good": true,
		"text": "A coach full of tourists just arrived! Hello chicken nugget, hello coach!",
	},
}

var active := {}               # id -> seconds remaining
var enabled := false
var _timer := 30.0
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
		_timer = _rng.randf_range(40.0, 80.0)
		trigger_random()


func new_day() -> void:
	for id in active.keys():
		event_ended.emit(id)
	active.clear()
	_timer = _rng.randf_range(25.0, 45.0)


func trigger_random() -> void:
	var weights := {}
	for id in EVENTS:
		if not active.has(id):
			weights[id] = float(EVENTS[id].weight)
	if weights.is_empty():
		return
	trigger(TouristTypes.weighted_pick(weights, _rng))


func trigger(id: String) -> void:
	if not EVENTS.has(id):
		return
	var def: Dictionary = EVENTS[id]
	if float(def.duration) > 0.0:
		active[id] = float(def.duration)
	Economy.day_stats.events += 1
	# Instant effects that don't need the beach.
	match id:
		"seagull":
			var n := Economy.remove_random(_rng.randi_range(1, 3), _rng)
			def = def.duplicate()
			def.text += " (-%d items)" % n
		"wallet":
			var tip := roundf(_rng.randf_range(10.0, 30.0) * float(BeachDB.get_beach(GameManager.current_beach).wealth))
			Economy.add_cash(tip, "event")
			def = def.duplicate()
			def.text += " (+%s)" % Lines.money(tip)
		"complaint":
			HeatSystem.add(20.0, "complaint")
	event_started.emit(id, def)


func is_active(id: String) -> bool:
	return active.has(id)


## Product of every active event's multiplier for key (1.0 when none).
func mult(key: String) -> float:
	var m := 1.0
	for id in active:
		m *= float(EVENTS[id].get("mods", {}).get(key, 1.0))
	return m


## Sum of every active event's additive bonus for key (0.0 when none). Used for "sale_chance"
## (added to the buy chance) and "police" (extra cops on the beach).
func add(key: String) -> float:
	var a := 0.0
	for id in active:
		a += float(EVENTS[id].get("mods", {}).get(key, 0.0))
	return a


func item_demand(item_id: String) -> float:
	var m := 1.0
	for id in active:
		m *= float(EVENTS[id].get("demand", {}).get(item_id, 1.0))
	return m


func item_price_mult(item_id: String) -> float:
	var m := 1.0
	for id in active:
		m *= float(EVENTS[id].get("price", {}).get(item_id, 1.0))
	return m
