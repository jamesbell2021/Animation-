class_name AppearanceOptions
extends RefCounted
## Everything a character can look like: option lists, colour palettes, and the random
## generators for guests, staff, the inspector and the manager.
##
## An appearance is a plain Dictionary (so it saves straight to JSON). Colours are stored as
## HTML hex strings. VendorAvatar reads it; CharacterData owns the player's copy.
## To add a new hair style (or hat, shirt...): append its name here and add a matching
## branch in VendorAvatar's painter (or drop a PNG in res://art/characters/<layer>/).

const HAIR_STYLES := ["Bald", "Buzz Cut", "Short", "Curly", "Long", "Afro", "Undercut", "Messy",
	"Ponytail", "Mohawk", "Top Bun", "Slick Back", "Braids"]
const EYES := ["Round", "Sleepy", "Wide", "Happy", "Narrow", "Sparkly"]
const BROWS := ["Normal", "Bushy", "Angry", "Raised", "Unibrow", "Thin"]
const NOSES := ["Button", "Big", "Pointy", "Round", "Wide"]
const MOUTHS := ["Grin", "Big Smile", "Smirk", "Shouting", "Gold Tooth", "Tiny"]
const FACIAL_HAIR := ["None", "Stubble", "Moustache", "Handlebar", "Goatee", "Full Beard", "Mutton Chops"]
const BODY_TYPES := ["Slim", "Average", "Large", "Muscular"]
const SHIRTS := ["Vest Top", "T-Shirt", "Hawaiian", "Football Shirt", "Open Shirt", "Polo", "No Shirt"]
const BOTTOMS := ["Shorts", "Board Shorts", "Trousers", "Cargo Shorts", "Trackies", "Swim Trunks"]
const SHOES := ["Flip-Flops", "Sandals", "Trainers", "Socks & Sandals", "Barefoot"]
const HATS := ["None", "Cap", "Backwards Cap", "Bucket Hat", "Straw Hat", "Sombrero", "Bandana", "Visor"]
const GLASSES := ["None", "Aviators", "Round Shades", "Star Shades", "Wraparounds", "Nerd Specs"]
const CHAINS := ["None", "Gold Chain", "Chunky Gold", "Shell Necklace"]
const WATCHES := ["None", "Gold Watch", "Watch Stack", "Smartwatch"]
const EARRINGS := ["None", "Gold Stud", "Hoops"]
const BAGS := ["None", "Bum Bag", "Cross-body Bag"]

## Index-valued keys and the option list each one indexes. Used for validation and the creator.
const OPTION_KEYS := {
	"hair_style": HAIR_STYLES, "eyes": EYES, "brows": BROWS, "nose": NOSES, "mouth": MOUTHS,
	"facial_hair": FACIAL_HAIR, "body": BODY_TYPES, "shirt": SHIRTS, "bottoms": BOTTOMS,
	"shoes": SHOES, "hat": HATS, "glasses": GLASSES, "chain": CHAINS, "watch": WATCHES,
	"earrings": EARRINGS, "bag": BAGS,
}
const COLOR_KEYS := ["skin", "hair_color", "eye_color", "shirt_color", "bottoms_color", "shoes_color", "hat_color"]

## Anchor colours for the continuous skin-tone gradient, from very light to very dark. The
## creator slider samples anywhere along it (no presets tied to ethnicity), and an undertone
## slider shifts the result pinker or more olive.
const SKIN_ANCHORS := [
	Color("#fff0e6"), Color("#fbe0cc"), Color("#f5cfb3"), Color("#eebd98"), Color("#e4aa80"),
	Color("#d8986c"), Color("#c9875b"), Color("#b8754b"), Color("#a3633d"), Color("#8d5231"),
	Color("#774327"), Color("#62361f"), Color("#4e2a18"), Color("#3b1f12"), Color("#2b160c"),
]
const SKIN_SWATCH_COUNT := 20

const HAIR_PALETTE := [
	Color("#0d0b0a"), Color("#2a1d17"), Color("#3b2618"), Color("#5a3a22"), Color("#7b4a2a"),
	Color("#8e3b1f"), Color("#b5502a"), Color("#d4733a"), Color("#e0a35e"), Color("#b08a5a"),
	Color("#e6c47c"), Color("#f4e3b0"), Color("#8c8c8c"), Color("#c9c9c9"), Color("#f2f2f2"),
	Color("#ff5fa2"), Color("#a05cff"), Color("#2f7bff"), Color("#18c3b5"), Color("#3fcf4f"),
	Color("#ff3b3b"), Color("#ff9d00"), Color("#ffe14d"), Color("#6b4cff"),
]
const EYE_PALETTE := [
	Color("#3b2314"), Color("#6b4423"), Color("#9a6b3a"), Color("#3d7a3a"), Color("#4a9a7a"),
	Color("#3a6fb0"), Color("#7aa8d8"), Color("#6f6f6f"), Color("#1a1a1a"), Color("#8a5ab8"),
]
const CLOTH_PALETTE := [
	Color("#ffffff"), Color("#1d1d1d"), Color("#e53935"), Color("#ff7043"), Color("#ffb300"),
	Color("#ffe14d"), Color("#7cb342"), Color("#00a86b"), Color("#00bcd4"), Color("#1e88e5"),
	Color("#3949ab"), Color("#8e24aa"), Color("#ec407a"), Color("#8d6e63"), Color("#90a4ae"),
	Color("#f5deb3"), Color("#ff80ab"), Color("#004d40"),
]

const VOICE_MIN := 0.6
const VOICE_MAX := 1.7


## Colour along the skin gradient: tone 0 = lightest, 1 = darkest; undertone -1 pink .. +1 olive.
static func skin_color(tone: float, undertone := 0.0) -> Color:
	tone = clampf(tone, 0.0, 1.0)
	var f := tone * float(SKIN_ANCHORS.size() - 1)
	var i := mini(int(f), SKIN_ANCHORS.size() - 2)
	var c: Color = SKIN_ANCHORS[i].lerp(SKIN_ANCHORS[i + 1], f - float(i))
	var u := clampf(undertone, -1.0, 1.0)
	if u > 0.0:
		c = c.lerp(Color(c.r * 0.97, c.g * 1.02, c.b * 0.78), u * 0.6)
	elif u < 0.0:
		c = c.lerp(Color(minf(c.r * 1.04, 1.0), c.g * 0.9, c.b * 0.96), -u * 0.6)
	return c


static func skin_gradient() -> Gradient:
	var g := Gradient.new()
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for i in SKIN_ANCHORS.size():
		offsets.append(float(i) / float(SKIN_ANCHORS.size() - 1))
		colors.append(SKIN_ANCHORS[i])
	g.offsets = offsets
	g.colors = colors
	return g


static func skin_swatch_tones() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in SKIN_SWATCH_COUNT:
		out.append(float(i) / float(SKIN_SWATCH_COUNT - 1))
	return out


static func default_appearance() -> Dictionary:
	var a := {
		"name": "Chicken Nugget King",
		"skin_tone": 0.45, "undertone": 0.0,
		"hair_style": 3, "hair_color": HAIR_PALETTE[1].to_html(false),
		"eyes": 0, "eye_color": EYE_PALETTE[0].to_html(false),
		"brows": 0, "nose": 0, "mouth": 1, "facial_hair": 2,
		"body": 1,
		"shirt": 2, "shirt_color": CLOTH_PALETTE[8].to_html(false),
		"bottoms": 1, "bottoms_color": CLOTH_PALETTE[4].to_html(false),
		"shoes": 0, "shoes_color": CLOTH_PALETTE[2].to_html(false),
		"hat": 2, "hat_color": CLOTH_PALETTE[2].to_html(false),
		"glasses": 1, "chain": 1, "watch": 2, "earrings": 0, "bag": 1,
		"voice_pitch": 1.0,
	}
	a["skin"] = skin_color(a.skin_tone, a.undertone).to_html(false)
	return a


## A fully random character from the whole range of every option.
static func random_appearance(rng: RandomNumberGenerator = null) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var a := default_appearance()
	a.skin_tone = rng.randf()
	a.undertone = rng.randf_range(-0.6, 0.6)
	a.skin = skin_color(a.skin_tone, a.undertone).to_html(false)
	for key in OPTION_KEYS:
		a[key] = rng.randi() % OPTION_KEYS[key].size()
	# Keep accessories a bit rarer so randoms aren't all walking jewellery shops.
	for key: String in ["hat", "glasses", "chain", "watch", "earrings", "bag", "facial_hair"]:
		if rng.randf() < 0.35:
			a[key] = 0
	a.hair_color = _pick_color(HAIR_PALETTE, rng, 15 if rng.randf() < 0.85 else HAIR_PALETTE.size())
	a.eye_color = _pick_color(EYE_PALETTE, rng)
	a.shirt_color = _pick_color(CLOTH_PALETTE, rng)
	a.bottoms_color = _pick_color(CLOTH_PALETTE, rng)
	a.shoes_color = _pick_color(CLOTH_PALETTE, rng)
	a.hat_color = _pick_color(CLOTH_PALETTE, rng)
	a.voice_pitch = snappedf(rng.randf_range(0.75, 1.45), 0.05)
	a.name = Lines.MANAGER_NAMES[rng.randi() % Lines.MANAGER_NAMES.size()]
	return a


## A guest of the given type: random person, holiday outfit picked from the type's hints.
static func guest_appearance(type_id: String, rng: RandomNumberGenerator, child := false) -> Dictionary:
	var a := random_appearance(rng)
	var t := GuestTypes.get_type(type_id)
	var o: Dictionary = t.get("outfit", {})
	if o.has("shirts"):
		a.shirt = o.shirts[rng.randi() % o.shirts.size()]
	if o.has("bottoms"):
		a.bottoms = o.bottoms[rng.randi() % o.bottoms.size()]
	if o.has("hats"):
		a.hat = o.hats[rng.randi() % o.hats.size()]
	var sb: Array = o.get("sunburn", [0.0, 0.3])
	a.sunburn = rng.randf_range(sb[0], sb[1])
	a.watch = 0 if rng.randf() < 0.8 else a.watch
	a.chain = 0 if rng.randf() < 0.75 else a.chain
	a.bag = 0 if rng.randf() < 0.7 else a.bag
	a.shoes = [0, 1, 4, 3][rng.randi() % 4]
	if type_id == "pensioners":
		a.hair_color = [HAIR_PALETTE[12], HAIR_PALETTE[13], HAIR_PALETTE[14]][rng.randi() % 3].to_html(false)
		if rng.randf() < 0.4:
			a.hair_style = 0
	if type_id == "hens" and rng.randf() < 0.5:
		a.hat = 6
		a.hat_color = "ff4fa3"
	if child:
		a.scale = 0.66
		a.facial_hair = 0
		a.body = rng.randi() % 2
		a.chain = 0
		a.watch = 0
	return a


## Staff uniforms: random person, role colours and a printed badge.
static func staff_appearance(role: String, rng: RandomNumberGenerator) -> Dictionary:
	var a := random_appearance(rng)
	a.chain = 0
	a.watch = 0
	a.bag = 0
	a.glasses = 0 if rng.randf() < 0.7 else a.glasses
	a.shoes = 2
	match role:
		"cleaner":
			a.shirt = 5
			a.shirt_color = "4fc3f7"
			a.bottoms = 2
			a.bottoms_color = "1565c0"
			a.hat = 6
			a.hat_color = "e1f5fe"
			a.badge = "CLEAN"
		"handyman":
			a.shirt = 1
			a.shirt_color = "ff9800"
			a.bottoms = 3
			a.bottoms_color = "5d4037"
			a.hat = 1
			a.hat_color = "ffd23f"
			a.badge = "FIX IT"
		"security":
			a.shirt = 1
			a.shirt_color = "1d1d1d"
			a.bottoms = 2
			a.bottoms_color = "263238"
			a.hat = 0
			a.glasses = 4
			a.body = 3
			a.badge = "SECURITY"
		"lifeguard":
			a.shirt = 0
			a.shirt_color = "e53935"
			a.bottoms = 1
			a.bottoms_color = "ffd23f"
			a.hat = 7
			a.hat_color = "fffaf0"
			a.badge = "LIFEGUARD"
		"barman":
			a.shirt = 5
			a.shirt_color = "fffaf0"
			a.bottoms = 2
			a.bottoms_color = "1d1d1d"
			a.hat = 0
			a.badge = "BAR"
		"inspector":
			a.shirt = 5
			a.shirt_color = "37474f"
			a.bottoms = 2
			a.bottoms_color = "263238"
			a.hat = 0
			a.glasses = 5
			a.mouth = 5
			a.brows = 2
			a.badge = "INSPECTOR"
		"thief":
			a.shirt = 1
			a.shirt_color = "212121"
			a.bottoms = 4
			a.bottoms_color = "212121"
			a.hat = 6
			a.hat_color = "212121"
			a.glasses = 0
			a.mouth = 2
	return a


## The manager everyone sees on day one (the player can re-roll it).
static func manager_appearance(rng: RandomNumberGenerator) -> Dictionary:
	var a := random_appearance(rng)
	a.shirt = 2
	a.shirt_color = "e2673f"
	a.bottoms = 2
	a.chain = 1
	a.bag = 0
	a.hat = 0
	a.badge = "MANAGER"
	return a


## Makes any dictionary safe to use: fills missing keys, clamps indices, repairs colours.
## Old saves and hand-edited files go through here.
static func sanitize(src: Dictionary) -> Dictionary:
	var a := default_appearance()
	for key in src:
		a[key] = src[key]
	for key in OPTION_KEYS:
		a[key] = clampi(int(a[key]), 0, OPTION_KEYS[key].size() - 1)
	a.skin_tone = clampf(float(a.skin_tone), 0.0, 1.0)
	a.undertone = clampf(float(a.undertone), -1.0, 1.0)
	a.voice_pitch = clampf(float(a.voice_pitch), VOICE_MIN, VOICE_MAX)
	for key in COLOR_KEYS:
		var s := str(a.get(key, ""))
		if not Color.html_is_valid(s):
			a[key] = default_appearance().get(key, "ffffff")
	a.name = str(a.get("name", "Chicken Nugget King")).strip_edges().left(24)
	if a.name == "":
		a.name = "Chicken Nugget King"
	return a


static func color_of(a: Dictionary, key: String, fallback := Color.WHITE) -> Color:
	var s := str(a.get(key, ""))
	return Color.html(s) if Color.html_is_valid(s) else fallback


static func _pick_color(palette: Array, rng: RandomNumberGenerator, limit := -1) -> String:
	var n := palette.size() if limit <= 0 else mini(limit, palette.size())
	return (palette[rng.randi() % n] as Color).to_html(false)
