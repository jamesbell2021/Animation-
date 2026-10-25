class_name TouristTypes
extends RefCounted
## Tourist archetypes. Budget is how many euros they'll happily spend per item, "ears" is how
## strongly they react to "Hello chicken nugget!", and "outfit" steers their random look.
## Everyone is lovingly mocked equally.

const TYPES := {
	"brits": {
		"name": "Sunburnt Brits", "budget": 16.0, "speed": 55.0, "ears": 1.1, "patience": 7.0,
		"swim": 0.25, "sunbathe": 0.55, "complain": 0.04, "group": [1, 3],
		"outfit": {"shirts": [3, 6, 0], "bottoms": [0, 5, 1], "sunburn": [0.35, 0.9], "hats": [0, 0, 1, 4]},
		"lines": ["Ooh, lovely!", "Is it Wednesday?", "Where's the full English?", "Me back's burnin'!"],
	},
	"stag": {
		"name": "Stag & Hen Party", "budget": 26.0, "speed": 70.0, "ears": 1.4, "patience": 5.0,
		"swim": 0.2, "sunbathe": 0.2, "complain": 0.08, "group": [3, 5],
		"outfit": {"shirts": [1, 3, 2], "bottoms": [1, 5], "sunburn": [0.1, 0.6], "hats": [0, 2, 5, 6]},
		"lines": ["WAHEYYY!", "Lads lads lads!", "Shots! Shots!", "Best holiday EVER!"],
	},
	"family": {
		"name": "Family Holiday", "budget": 18.0, "speed": 45.0, "ears": 1.0, "patience": 8.0,
		"swim": 0.35, "sunbathe": 0.5, "complain": 0.03, "group": [2, 4],
		"outfit": {"shirts": [1, 5, 0], "bottoms": [0, 3, 5], "sunburn": [0.0, 0.4], "hats": [0, 1, 3, 4]},
		"lines": ["Dad, can we get one?", "Don't touch that!", "Where's the suncream?", "Are we there yet?"],
	},
	"pensioner": {
		"name": "Pensioners", "budget": 9.0, "speed": 32.0, "ears": 0.7, "patience": 12.0,
		"swim": 0.15, "sunbathe": 0.7, "complain": 0.07, "group": [1, 2],
		"outfit": {"shirts": [5, 2, 1], "bottoms": [2, 3], "sunburn": [0.0, 0.5], "hats": [4, 3, 7, 0]},
		"lines": ["In my day...", "How much?!", "Lovely weather.", "Is there a toilet?"],
	},
	"influencer": {
		"name": "Influencers", "budget": 30.0, "speed": 50.0, "ears": 1.2, "patience": 6.0,
		"swim": 0.1, "sunbathe": 0.4, "complain": 0.05, "group": [1, 2],
		"outfit": {"shirts": [4, 0, 2], "bottoms": [5, 0], "sunburn": [0.0, 0.1], "hats": [3, 7, 0]},
		"lines": ["Like and subscribe!", "Is the lighting okay?", "So aesthetic!", "Content!"],
	},
	"backpacker": {
		"name": "Backpackers", "budget": 6.0, "speed": 60.0, "ears": 0.9, "patience": 9.0,
		"swim": 0.4, "sunbathe": 0.35, "complain": 0.02, "group": [1, 2],
		"outfit": {"shirts": [0, 1, 6], "bottoms": [3, 1], "sunburn": [0.1, 0.5], "hats": [6, 0, 3]},
		"lines": ["Can I pay in bracelets?", "Hostel's that way.", "Is it cheaper in Thailand?", "Free walking tour?"],
	},
	"rich": {
		"name": "Yacht Folk", "budget": 70.0, "speed": 40.0, "ears": 0.6, "patience": 6.0,
		"swim": 0.1, "sunbathe": 0.6, "complain": 0.12, "group": [1, 2],
		"outfit": {"shirts": [5, 4], "bottoms": [2, 0], "sunburn": [0.0, 0.2], "hats": [4, 7, 0]},
		"lines": ["Is this... plastic?", "Daddy's yacht is bigger.", "How quaint!", "Charge it to the boat."],
	},
}

## Moods change how likely a tourist is to buy and how they react to shouting.
const MOODS := {
	"happy": {"name": "Happy", "buy": 1.15, "ears": 1.1, "complain": 0.5, "color": Color("#4caf50")},
	"chill": {"name": "Chilled", "buy": 1.0, "ears": 0.9, "complain": 0.6, "color": Color("#29b6f6")},
	"grumpy": {"name": "Grumpy", "buy": 0.6, "ears": 0.6, "complain": 2.5, "color": Color("#ef5350")},
	"tipsy": {"name": "Tipsy", "buy": 1.4, "ears": 1.5, "complain": 1.2, "color": Color("#ab47bc")},
	"sunburnt": {"name": "Sunburnt", "buy": 0.9, "ears": 0.8, "complain": 1.4, "color": Color("#ff7043")},
}


static func get_type(id: String) -> Dictionary:
	return TYPES.get(id, TYPES["brits"])


static func roll_mood(type_id: String, rng: RandomNumberGenerator) -> String:
	var weights := {"happy": 3.0, "chill": 3.0, "grumpy": 1.0, "tipsy": 0.5, "sunburnt": 1.0}
	match type_id:
		"stag": weights["tipsy"] = 4.0
		"pensioner": weights["grumpy"] = 2.0
		"brits": weights["sunburnt"] = 3.0
		"rich": weights["grumpy"] = 1.5
	return weighted_pick(weights, rng)


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
