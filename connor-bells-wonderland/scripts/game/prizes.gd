class_name Prizes
extends RefCounted
## The ridiculous prizes the winner takes home. pick() is seeded from the race
## results, so every screen in a Wi-Fi race shows the same prize.

const LIST: Array[String] = [
	"a brand new toaster",
	"a wheelie bin cover",
	"a lifetime supply of soggy chips",
	"a goldfish called Kevin",
	"a slightly used hovercraft",
	"a tin of tartan paint",
	"a jet-powered shopping trolley",
	"a pet rock with a moustache",
	"a golden toilet seat",
	"a year's supply of turnips",
	"a llama called Gary",
	"a 40-foot inflatable sausage",
	"a haunted lawnmower",
	"a bag of very angry bees",
	"a left-handed screwdriver",
	"a pogo stick with no spring",
	"a box of 1,000 rubber ducks",
	"a games console made of cardboard",
	"a rocket-powered skateboard",
	"a pair of glow-in-the-dark Y-fronts",
	"a fridge full of jelly",
	"an extremely loud kazoo",
	"a portable hole",
	"a monster truck (toy size)",
	"a lifetime supply of beans",
	"a trophy for 'Most Average Driver'",
	"a sandwich toaster shaped like a shark",
	"a garden gnome with a mohawk",
	"a second-hand trampoline",
	"a hamster-powered night light",
	"a signed photo of a traffic cone",
	"a bucket of pure custard",
	"a hot tub full of baked beans",
	"a pet crab called Steve",
	"a jumbo pack of whoopee cushions",
	"a wig made of spaghetti",
	"a cardboard cut-out of Connor",
	"a ride-on lawnmower with flames painted on",
	"a bin lorry for one day",
	"an inflatable dinosaur costume",
]


## The Paintball Battle prize (always the same, it's that good).
const BATTLE_PRIZE := "a year's Fruit of the Month subscription"
const BATTLE_PRIZE_DETAIL := "Free fruit delivered to your home every month!"


## Prize for a race, from text that is the same on every screen (e.g. the winner and time).
static func pick(seed_text: String) -> String:
	return LIST[absi(seed_text.hash()) % LIST.size()]
