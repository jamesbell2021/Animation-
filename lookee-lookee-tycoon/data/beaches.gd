class_name BeachDB
extends RefCounted
## The Costa locations that make up the empire. Each beach has its own crowd, wealth, police
## strictness and colours. "kiosk" is the price of opening a shop there for passive income.

const ORDER := ["benidorm", "torremolinos", "salou", "lloret", "magaluf", "marbella"]

const BEACHES := {
	"benidorm": {
		"name": "Benidorm", "beach": "Playa Levante", "unlock": 0.0, "kiosk": 1500.0, "kiosk_income": 60.0,
		"wealth": 1.0, "police": 1.0, "crowd": 1.0, "needs_van": false,
		"mix": {"brits": 4.0, "family": 2.5, "pensioner": 3.0, "stag": 1.5, "backpacker": 0.8, "influencer": 0.6},
		"sky": Color("#7fd3f7"), "sea": Color("#1e9bd7"), "sand": Color("#f7d89b"), "prom": Color("#e9c8a0"),
		"hotels": Color("#f4eee4"),
		"blurb": "Where it all begins. Skyscrapers, sunburn and full English breakfasts. Hello chicken nugget!",
	},
	"torremolinos": {
		"name": "Torremolinos", "beach": "Playa La Carihuela", "unlock": 1200.0, "kiosk": 2500.0, "kiosk_income": 90.0,
		"wealth": 1.1, "police": 1.05, "crowd": 1.1, "needs_van": false,
		"mix": {"family": 3.5, "brits": 3.0, "pensioner": 2.0, "influencer": 1.0, "backpacker": 1.0, "stag": 1.0},
		"sky": Color("#86d8f5"), "sea": Color("#1890c8"), "sand": Color("#eccf94"), "prom": Color("#dcc0a0"),
		"hotels": Color("#fff3d6"),
		"blurb": "Fried fish, families and flamingos as far as the eye can see. Very good very nice!",
	},
	"salou": {
		"name": "Salou", "beach": "Platja de Llevant", "unlock": 4000.0, "kiosk": 5000.0, "kiosk_income": 150.0,
		"wealth": 1.2, "police": 1.15, "crowd": 1.2, "needs_van": true,
		"mix": {"family": 3.0, "stag": 2.0, "brits": 2.0, "backpacker": 1.5, "influencer": 1.2, "pensioner": 1.0},
		"sky": Color("#8ad4ff"), "sea": Color("#1386c9"), "sand": Color("#f3dca8"), "prom": Color("#e2c6a8"),
		"hotels": Color("#ffe9e0"),
		"blurb": "Rollercoasters next door, screaming tourists on the sand. Very good very loud!",
	},
	"lloret": {
		"name": "Lloret de Mar", "beach": "Platja de Lloret", "unlock": 9000.0, "kiosk": 9000.0, "kiosk_income": 240.0,
		"wealth": 1.3, "police": 1.3, "crowd": 1.25, "needs_van": true,
		"mix": {"stag": 3.5, "backpacker": 2.5, "brits": 2.0, "influencer": 1.5, "family": 1.0, "pensioner": 0.5},
		"sky": Color("#78c8f0"), "sea": Color("#0f7bbf"), "sand": Color("#e6c98f"), "prom": Color("#d7b896"),
		"hotels": Color("#f6efe6"),
		"blurb": "Party central. The bunny ears never stop flashing. Very good very nice!",
	},
	"magaluf": {
		"name": "Magaluf", "beach": "Playa de Magaluf", "unlock": 20000.0, "kiosk": 16000.0, "kiosk_income": 380.0,
		"wealth": 1.45, "police": 1.5, "crowd": 1.35, "needs_van": true,
		"mix": {"stag": 5.0, "brits": 3.0, "influencer": 2.0, "backpacker": 1.5, "family": 0.5},
		"sky": Color("#6ec1f0"), "sea": Color("#0aa2c0"), "sand": Color("#f0d6a0"), "prom": Color("#e0bf9a"),
		"hotels": Color("#fff0f5"),
		"blurb": "The legendary island of the stag party. The police are... very awake. Very good very nice?",
	},
	"marbella": {
		"name": "Marbella", "beach": "Puerto Banús", "unlock": 45000.0, "kiosk": 30000.0, "kiosk_income": 650.0,
		"wealth": 2.2, "police": 1.8, "crowd": 1.1, "needs_van": true,
		"mix": {"rich": 4.0, "influencer": 3.0, "family": 1.0, "pensioner": 1.0, "brits": 1.0},
		"sky": Color("#9ee0ff"), "sea": Color("#1aa7d9"), "sand": Color("#fbe7bd"), "prom": Color("#f1dcc4"),
		"hotels": Color("#ffffff"),
		"blurb": "Yachts, Lamborghinis and Louis Vuitpoint. The final boss of the Costa. Very good VERY nice!",
	},
}


static func get_beach(id: String) -> Dictionary:
	return BEACHES.get(id, BEACHES["benidorm"])


static func display_name(id: String) -> String:
	var b := get_beach(id)
	return "%s - %s" % [b.name, b.beach]
