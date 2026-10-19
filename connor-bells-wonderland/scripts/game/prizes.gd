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


## Dodgem Derby prizes for the last driver left out of the Irish Sea.
const DERBY_LIST: Array[String] = [
	"a pedalo to cross the Irish Sea",
	"a rubber ring and a pair of armbands",
	"a slightly soggy dodgem car",
	"a pet seagull that steals your chips",
	"a jellyfish called Jeff",
	"a snorkel with a hole in it",
	"a lifetime supply of seaweed",
	"swimming lessons (beginners)",
	"a one-way ferry ticket to nowhere",
	"a giant inflatable crab",
	"a lilo shaped like a sausage roll",
	"a waterproof onesie",
	"a bucket of slightly used sand",
	"a message in a bottle (it says 'help')",
	"a submarine made of cardboard",
	"a seal who thinks you're his mum",
	"a fish supper that's mostly batter",
	"a jet ski with a pedal engine",
	"a year's supply of wet socks",
	"a lighthouse (some assembly required)",
	"a sea shanty sung by a goat",
	"a dodgem licence (provisional)",
]


## Tower Climb: big, crazy prizes for the first to the top.
const TOWER_LIST: Array[String] = [
	"a solid gold toilet (it's actually chocolate)",
	"a helicopter made of lollipop sticks",
	"a lifetime supply of ladders",
	"a pet giraffe called Tower",
	"a rocket to the moon (one way)",
	"a castle made entirely of jelly",
	"a stretch limo with a hot tub in the back",
	"a trophy taller than your house",
	"a lift installed in your bedroom",
	"a robot butler called Kevin",
	"a private jet (toy size)",
	"a slightly used moon",
	"a mountain of chips with its own ski lift",
	"a crown made of doughnuts",
	"a theme park named after you (it's a bouncy castle)",
	"a zip line from your bed to the fridge",
	"a hot air balloon shaped like your face",
	"a swimming pool full of custard",
	"a trampoline the size of a football pitch",
	"a lifetime pass to sit on top of this tower",
]


## Prize for a race, from text that is the same on every screen (e.g. the winner and time).
static func pick(seed_text: String) -> String:
	return LIST[absi(seed_text.hash()) % LIST.size()]


## Tower Climb prize, seeded the same way.
static func pick_tower(seed_text: String) -> String:
	return TOWER_LIST[absi(seed_text.hash()) % TOWER_LIST.size()]


## Dodgem Derby prize, seeded the same way.
static func pick_derby(seed_text: String) -> String:
	return DERBY_LIST[absi(seed_text.hash()) % DERBY_LIST.size()]
