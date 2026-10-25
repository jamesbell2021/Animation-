class_name ItemDB
extends RefCounted
## The junk catalogue. Every item: wholesale cost, base street price, which supplier tier
## unlocks it, how much each tourist type wants it (appeal 0..1.5) and its description.
## Add an item here and it appears in the Wholesaler, on stalls and in tourists' wish lists.
## Icons are drawn by ItemArt from the "art" key (or res://art/items/<id>.png if present).

const ITEMS := {
	"magnet": {
		"name": "Fridge Magnet", "tier": 0, "cost": 0.2, "price": 2.0, "art": "magnet",
		"color": Color("#ff5d73"),
		"desc": "\"I LOVE COSTA\". Made in a factory far, far away. Very good very nice!",
		"appeal": {"brits": 0.9, "stag": 0.5, "family": 0.8, "pensioner": 1.2, "influencer": 0.3, "backpacker": 0.7, "rich": 0.1},
	},
	"sunglasses": {
		"name": "Ray-Bams", "tier": 0, "cost": 0.5, "price": 5.0, "art": "sunglasses",
		"color": Color("#222222"),
		"desc": "Hello chicken nugget! Original Ray-Bams! (The 'm' is for 'magnífico'.)",
		"appeal": {"brits": 1.2, "stag": 1.3, "family": 0.8, "pensioner": 0.6, "influencer": 1.0, "backpacker": 0.9, "rich": 0.3},
	},
	"bracelet": {
		"name": "Friendship Bracelet", "tier": 0, "cost": 0.1, "price": 2.0, "art": "bracelet",
		"color": Color("#ffb627"),
		"desc": "Friendship guaranteed for up to three days. Very good very nice!",
		"appeal": {"brits": 0.6, "stag": 0.6, "family": 1.0, "pensioner": 0.4, "influencer": 0.8, "backpacker": 1.3, "rich": 0.1},
	},
	"umbrella": {
		"name": "Pocket Umbrella", "tier": 0, "cost": 0.6, "price": 4.0, "art": "umbrella",
		"color": Color("#3d5afe"),
		"desc": "Nobody needs it... until the rain. Then: very good very nice!",
		"appeal": {"brits": 0.3, "stag": 0.2, "family": 0.3, "pensioner": 0.5, "influencer": 0.2, "backpacker": 0.2, "rich": 0.1},
	},
	"bunny_ears": {
		"name": "Light-up Bunny Ears", "tier": 1, "cost": 0.4, "price": 4.0, "art": "bunny_ears",
		"color": Color("#ff4fd8"),
		"desc": "Flashes in seven colours, four of them legal. Stag parties go wild!",
		"appeal": {"brits": 0.9, "stag": 1.5, "family": 1.0, "pensioner": 0.2, "influencer": 1.1, "backpacker": 0.6, "rich": 0.1},
	},
	"selfie_stick": {
		"name": "Selfie Stick", "tier": 1, "cost": 1.0, "price": 8.0, "art": "selfie_stick",
		"color": Color("#7c4dff"),
		"desc": "Hello chicken nugget! Take photo of yourself, very good very nice!",
		"appeal": {"brits": 0.8, "stag": 0.9, "family": 0.9, "pensioner": 0.5, "influencer": 1.5, "backpacker": 0.8, "rich": 0.3},
	},
	"sun_hat": {
		"name": "Big Straw Hat", "tier": 1, "cost": 0.8, "price": 6.0, "art": "sun_hat",
		"color": Color("#e8c170"),
		"desc": "Bigger than your head. Bigger than your problems. Very nice!",
		"appeal": {"brits": 1.1, "stag": 0.7, "family": 0.9, "pensioner": 1.4, "influencer": 0.9, "backpacker": 0.6, "rich": 0.5},
	},
	"flamingo": {
		"name": "Inflatable Flamingo", "tier": 1, "cost": 2.0, "price": 12.0, "art": "flamingo",
		"color": Color("#ff7aa8"),
		"desc": "Every family needs one. Every pool has seven. Very good very nice!",
		"appeal": {"brits": 1.0, "stag": 1.2, "family": 1.5, "pensioner": 0.3, "influencer": 1.3, "backpacker": 0.5, "rich": 0.4},
	},
	"fan": {
		"name": "Folding Fan", "tier": 1, "cost": 0.3, "price": 4.0, "art": "fan",
		"color": Color("#e53935"),
		"desc": "Olé! A breeze for your face. Very good, very nice, very cool!",
		"appeal": {"brits": 0.9, "stag": 0.4, "family": 0.7, "pensioner": 1.3, "influencer": 0.7, "backpacker": 0.5, "rich": 0.3},
	},
	"watch": {
		"name": "Rolax Watch", "tier": 2, "cost": 3.0, "price": 20.0, "art": "watch",
		"color": Color("#ffd23f"),
		"desc": "Swiss quality! (Swiss is a small town near the motorway.) Very good very nice!",
		"appeal": {"brits": 0.8, "stag": 1.1, "family": 0.3, "pensioner": 0.5, "influencer": 0.8, "backpacker": 0.3, "rich": 0.6},
	},
	"speaker": {
		"name": "Buetooth Speaker", "tier": 2, "cost": 4.0, "price": 25.0, "art": "speaker",
		"color": Color("#00bfa5"),
		"desc": "Plays one song very loudly. Which song? Surprise! Very good very nice!",
		"appeal": {"brits": 1.0, "stag": 1.4, "family": 0.4, "pensioner": 0.1, "influencer": 0.9, "backpacker": 0.8, "rich": 0.3},
	},
	"henna": {
		"name": "Temporary Tattoo", "tier": 2, "cost": 0.5, "price": 7.0, "art": "henna",
		"color": Color("#8d5524"),
		"desc": "A dragon. Or a dolphin. Depends how you look. Very good very nice!",
		"appeal": {"brits": 1.1, "stag": 1.3, "family": 0.5, "pensioner": 0.2, "influencer": 1.0, "backpacker": 1.2, "rich": 0.2},
	},
	"unicorn": {
		"name": "Giant Inflatable Unicorn", "tier": 3, "cost": 8.0, "price": 45.0, "art": "unicorn",
		"color": Color("#b388ff"),
		"desc": "Visible from space. Hello chicken nugget, hello unicorn! Very good very nice!",
		"appeal": {"brits": 0.9, "stag": 1.3, "family": 1.4, "pensioner": 0.1, "influencer": 1.5, "backpacker": 0.2, "rich": 0.7},
	},
	"gold_chain": {
		"name": "Solid Gold* Chain", "tier": 3, "cost": 5.0, "price": 35.0, "art": "gold_chain",
		"color": Color("#ffc400"),
		"desc": "*Solid. Gold colour. Very good very nice, very shiny!",
		"appeal": {"brits": 0.8, "stag": 1.2, "family": 0.2, "pensioner": 0.3, "influencer": 1.0, "backpacker": 0.2, "rich": 0.5},
	},
	"drone": {
		"name": "Mini Drone", "tier": 3, "cost": 15.0, "price": 70.0, "art": "drone",
		"color": Color("#455a64"),
		"desc": "Flies! Sometimes up! Hello chicken nugget, hello sky! Very good very nice!",
		"appeal": {"brits": 0.6, "stag": 1.0, "family": 0.8, "pensioner": 0.1, "influencer": 1.3, "backpacker": 0.3, "rich": 0.8},
	},
	"handbag": {
		"name": "Louis Vuitpoint Bag", "tier": 4, "cost": 20.0, "price": 110.0, "art": "handbag",
		"color": Color("#795548"),
		"desc": "Designer! The designer is my cousin Pepe. Very good very nice!",
		"appeal": {"brits": 0.5, "stag": 0.7, "family": 0.3, "pensioner": 0.4, "influencer": 1.4, "backpacker": 0.1, "rich": 1.3},
	},
	"light_shoes": {
		"name": "Light-up Trainers", "tier": 4, "cost": 10.0, "price": 55.0, "art": "light_shoes",
		"color": Color("#00e5ff"),
		"desc": "Every step is a disco. Very good very nice, very bright!",
		"appeal": {"brits": 0.7, "stag": 1.3, "family": 1.0, "pensioner": 0.2, "influencer": 1.2, "backpacker": 0.3, "rich": 0.6},
	},
	"yacht_model": {
		"name": "Inflatable Yacht", "tier": 4, "cost": 30.0, "price": 160.0, "art": "yacht",
		"color": Color("#ffffff"),
		"desc": "For people who can't afford a yacht. Or people who can. Very good very nice!",
		"appeal": {"brits": 0.4, "stag": 0.9, "family": 0.6, "pensioner": 0.1, "influencer": 1.1, "backpacker": 0.0, "rich": 1.5},
	},
}

const TIER_NAMES := ["Bargain Bin", "Market Wholesaler", "Shipping Container", "Cousin Pepe's Warehouse", "Mega Import Empire"]


static func ids() -> Array:
	return ITEMS.keys()


static func has(id: String) -> bool:
	return ITEMS.has(id)


static func get_item(id: String) -> Dictionary:
	return ITEMS.get(id, {})


static func item_name(id: String) -> String:
	return ITEMS.get(id, {}).get("name", id)


static func appeal(id: String, tourist_type: String) -> float:
	return float(ITEMS.get(id, {}).get("appeal", {}).get(tourist_type, 0.4))


static func tier(id: String) -> int:
	return int(ITEMS.get(id, {}).get("tier", 0))


static func unlocked_ids(supplier_tier: int) -> Array:
	var out := []
	for id in ITEMS:
		if int(ITEMS[id].tier) <= supplier_tier:
			out.append(id)
	return out
