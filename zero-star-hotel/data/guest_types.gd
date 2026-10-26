class_name GuestTypes
extends RefCounted
## Who checks in. "trouble" is how likely they are to cause chaos after a few pints,
## "fussy" how much they mind the hotel's flaws, "drinks" how fond they are of the bar,
## "pool" how much of the day they spend by the pool. min_stars: they won't book a
## hotel below this rating, so the clientele improves as the stars do.

const TYPES := {
	"lads": {
		"name": "Lads on Tour", "group": [3, 4], "trouble": 1.0, "fussy": 0.3, "drinks": 1.0, "pool": 0.6,
		"min_stars": 0, "pays": 0.9, "lines": "LADS",
		"outfit": {"shirts": [3, 1, 6], "bottoms": [1, 5], "sunburn": [0.3, 0.9], "hats": [0, 2, 0]},
	},
	"hens": {
		"name": "Hen Party", "group": [3, 4], "trouble": 0.7, "fussy": 0.4, "drinks": 0.9, "pool": 0.7,
		"min_stars": 0, "pays": 1.0, "lines": "HENS",
		"outfit": {"shirts": [0, 1, 4], "bottoms": [0, 5], "sunburn": [0.1, 0.6], "hats": [6, 0, 3]},
	},
	"backpackers": {
		"name": "Backpackers", "group": [1, 2], "trouble": 0.3, "fussy": 0.2, "drinks": 0.6, "pool": 0.4,
		"min_stars": 0, "pays": 0.7, "lines": "BACKPACKERS",
		"outfit": {"shirts": [0, 1, 6], "bottoms": [3, 1], "sunburn": [0.1, 0.5], "hats": [6, 0]},
	},
	"mums": {
		"name": "Mums' Getaway", "group": [2, 3], "trouble": 0.35, "fussy": 0.6, "drinks": 0.7, "pool": 1.0,
		"min_stars": 0, "pays": 1.0, "lines": "MUMS",
		"outfit": {"shirts": [0, 4, 2], "bottoms": [5, 0], "sunburn": [0.0, 0.5], "hats": [4, 3, 7]},
	},
	"family": {
		"name": "Family", "group": [3, 4], "trouble": 0.2, "fussy": 0.8, "drinks": 0.3, "pool": 0.9,
		"min_stars": 1, "pays": 1.2, "lines": "FAMILY",
		"outfit": {"shirts": [1, 5, 2], "bottoms": [0, 3], "sunburn": [0.0, 0.4], "hats": [1, 3, 0]},
	},
	"couples": {
		"name": "Couple", "group": [2, 2], "trouble": 0.1, "fussy": 0.9, "drinks": 0.5, "pool": 0.6,
		"min_stars": 1, "pays": 1.3, "lines": "COUPLES",
		"outfit": {"shirts": [5, 4, 2], "bottoms": [2, 0], "sunburn": [0.0, 0.3], "hats": [0, 4]},
	},
	"pensioners": {
		"name": "Pensioners", "group": [2, 2], "trouble": 0.0, "fussy": 1.2, "drinks": 0.4, "pool": 0.5,
		"min_stars": 2, "pays": 1.4, "lines": "PENSIONERS",
		"outfit": {"shirts": [5, 2, 1], "bottoms": [2, 3], "sunburn": [0.0, 0.4], "hats": [4, 3, 7]},
	},
}


static func get_type(id: String) -> Dictionary:
	return TYPES.get(id, TYPES["lads"])


static func lines_for(id: String) -> Array:
	match str(get_type(id).lines):
		"HENS": return Lines.HENS
		"FAMILY": return Lines.FAMILY
		"MUMS": return Lines.MUMS
		"PENSIONERS": return Lines.PENSIONERS
		"BACKPACKERS": return Lines.BACKPACKERS
		"COUPLES": return Lines.COUPLES
	return Lines.LADS


## Which types might book, weighted, given the hotel's current stars.
static func booking_mix(stars: int) -> Dictionary:
	var mix := {}
	for id in TYPES:
		var t: Dictionary = TYPES[id]
		if stars < int(t.min_stars):
			continue
		var w := 1.0
		match id:
			"lads": w = 4.0 - stars * 1.0
			"hens": w = 2.5 - stars * 0.5
			"backpackers": w = 2.0 - stars * 0.4
			"mums": w = 2.0
			"family": w = 1.0 + stars * 1.0
			"couples": w = 0.8 + stars * 0.8
			"pensioners": w = 1.5 + stars * 0.5
		mix[id] = maxf(w, 0.3)
	return mix


static func weighted_pick(weights: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var r := rng.randf() * total
	for k in weights:
		r -= float(weights[k])
		if r <= 0.0:
			return k
	return weights.keys().back()
