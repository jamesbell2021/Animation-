class_name Lines
extends RefCounted
## Every piece of flavour text in the game, in one place so it's easy to tweak, extend or
## translate. The two signature catchphrases are the heart of the game: use them everywhere.
##
## Use Lines.pick(Lines.SALE) for a random line, and Lines.fmt() for lines with {item}, {price},
## {name} or {beach} placeholders.

const HELLO := "Hello chicken nugget!"
const VERY_GOOD := "Very good very nice!"

# --- The vendor ----------------------------------------------------------------------------

## Shouted when the player taps SHOUT.
const SHOUT := [
	"Hello chicken nugget!",
	"Hello chicken nugget! Lookee lookee!",
	"Hello chicken nugget! Very good very nice!",
	"Lookee lookee, chicken nugget!",
	"Hello my friend! Hello chicken nugget!",
	"Sunglasses! Watches! Very good very nice!",
	"Hello chicken nugget! Cheap cheap!",
	"Hello lovely chicken nugget family!",
	"Best price on the beach! Very good very nice!",
	"Hello chicken nugget! You want flamingo?",
]

## Said by whoever made a sale. {item} and {price} are filled in.
const SALE := [
	"Very good very nice!",
	"{item}! Very good very nice!",
	"Very good very nice! Enjoy, chicken nugget!",
	"Only {price}! Very good very nice!",
	"Very good very nice! Tell your friends!",
	"Ahh, very good choice. Very nice!",
	"Very good very nice! You look like film star!",
	"Thank you chicken nugget! Very good very nice!",
]

## Pitches when walking up to a tourist. {item} is filled in.
const PITCH := [
	"Hello chicken nugget! {item}? Very good very nice!",
	"Hello chicken nugget! Special price for you: {item}!",
	"Hello chicken nugget! {item}, original, very nice!",
	"Lookee lookee! {item}! Very good quality!",
	"Hello my friend! {item}, for you, very cheap!",
]

## When a tourist says no.
const SALE_FAIL := [
	"No problem, chicken nugget! Later!",
	"Okay okay! Very good very nice anyway!",
	"Next time, chicken nugget!",
	"Ahh! You break my heart, chicken nugget!",
]

## Packing up the stall.
const PACK := [
	"Pack pack pack! Very good very nice!",
	"Nothing to see, chicken nugget!",
	"I am just man with blanket!",
	"Whoosh! Very good very nice!",
]

## Setting up the stall.
const SETUP := [
	"Shop is open! Hello chicken nugget!",
	"Lookee lookee! Shop open!",
	"Hello chicken nugget! Come see, come see!",
]

## The bag is empty.
const NO_STOCK := [
	"No more stock, chicken nugget! Go to the shop!",
	"Bag is empty! Not very good, not very nice!",
	"Sold out! Buy more junk in the SHOP!",
]

# --- Tourists ------------------------------------------------------------------------------

const TOURIST_BUY := [
	"Go on then!",
	"Ooh, lovely!",
	"Bargain!",
	"I'll take it!",
	"Very good very nice!",
	"For the kids!",
	"Selfie time!",
	"Wahey!",
]

const TOURIST_NO := [
	"No thanks!",
	"No gracias!",
	"Too dear!",
	"Maybe later!",
	"Not today, pal!",
	"I've got one!",
]

const TOURIST_HAGGLE := [
	"{price} for it?",
	"Give you {price}!",
	"{price}, final offer!",
	"{price}? Very good very nice?",
]

const TOURIST_COMPLAIN := [
	"I'm telling the police!",
	"Too loud, mate!",
	"I'm on holiday!",
	"Ugh, not again!",
]

# --- Police --------------------------------------------------------------------------------

const POLICE_SPOT := ["¡Oye!", "Hmm...", "¿Qué es esto?", "¡Alto!"]
const POLICE_SHRUG := [
	"Just a man with a bag. Very good... very nice.",
	"Hmm. Nothing here.",
	"I am watching you, chicken nugget.",
]
const POLICE_BRIBE_OK := [
	"I saw nothing. Very good very nice.",
	"Hmm. Okay. Very good. Very nice.",
	"For my cousin's birthday. Adiós.",
]
const POLICE_BRIBE_FAIL := [
	"You insult me! Fine double!",
	"Nice try, chicken nugget!",
]

const BUSTED_TITLES := [
	"¡POLICÍA! Not very good, not very nice!",
	"Uh oh, chicken nugget!",
	"Busted! Very bad very not nice!",
]

const ESCAPED := [
	"You escaped! Very good very nice!",
	"Gone like the wind! Very good very nice!",
	"Lost the cop in the paddling pool! Very good very nice!",
]

const CAUGHT := [
	"Caught! Not very good, not very nice!",
	"The cop ran faster. Very good for them, very not nice for you.",
]

const COPS_COMING := [
	"¡POLICÍA! Pack up, chicken nugget!",
	"Cops incoming! Pack it up!",
	"Police! Not very good, not very nice!",
]

# --- Staff ---------------------------------------------------------------------------------

const STAFF_HIRED := [
	"{name} joins the empire! Very good very nice!",
	"{name}: \"Hello boss chicken nugget!\"",
	"Welcome, {name}! Very good very nice!",
]
const STAFF_FIRED := [
	"{name} rolls up the blanket. Very sad, very not nice.",
	"{name} leaves to start a rival empire. Hmm.",
]
const LOOKOUT_WARN := [
	"¡POLICÍA! ¡POLICÍA!",
	"{name}: \"Boss! Cops!\"",
	"{name} asks the policeman for directions. Very good very nice!",
]
const RUNNER_RESTOCK := "{name} brought {qty} more {item} from the van. Very good very nice!"

# --- Day summaries -------------------------------------------------------------------------

const DAY_GREAT := [
	"Very good very nice! You are the King of the Costa!",
	"What a day, chicken nugget! Very good very nice!",
	"The tourists love you! Very good very nice!",
]
const DAY_OK := [
	"Not bad, chicken nugget! Very good, quite nice.",
	"A day's work is a day's work. Very good very nice!",
]
const DAY_BAD := [
	"Ouch. Not very good, not very nice. Tomorrow is new day!",
	"The police had a good day. You had a bad day.",
	"Chin up, chicken nugget! Tomorrow, very good very nice!",
]

# --- Tips (main menu, loading, first day) ---------------------------------------------------

const TIPS := [
	"Tap SHOUT to yell \"Hello chicken nugget!\" and draw a crowd.",
	"Bigger stalls sell more but take longer to pack. Very good very nice?",
	"When the Heat meter turns red, PACK UP or run!",
	"Tap a tourist to walk over and pitch to them directly.",
	"Drag to look around the beach. Pinch or scroll to zoom.",
	"Hire a Lookout: they ask the police for directions. Very good very nice!",
	"Cheeky prices make more money... and fewer friends.",
	"Families love flamingos. Stag parties love everything.",
]

const TUTORIAL := {
	"setup": "Hello chicken nugget! Tap SET UP to lay out your blanket.",
	"shout": "Now tap SHOUT! \"Hello chicken nugget!\" brings the tourists.",
	"sell": "Tourists buy from your stall. Very good very nice!",
	"heat": "Selling makes the Heat meter rise. Too hot = POLICÍA!",
	"pack": "Police nearby? Tap PACK UP fast!",
	"shop": "Low on stock? Tap SHOP to buy more junk.",
	"done": "You're a natural, chicken nugget! Very good very nice!",
}

# --- Character creator ---------------------------------------------------------------------

const CREATOR_TITLE := "Hello chicken nugget! Who are you today?"
const CREATOR_REACTIONS := [
	"Very good very nice!",
	"Ooh! Very good very nice!",
	"Hello handsome chicken nugget!",
	"Hello gorgeous chicken nugget!",
	"Very nice! The tourists will love it!",
	"Very good! Very very nice!",
	"Now THAT is a vendor!",
	"Hello chicken nugget! Lookin' good!",
	"Very good very stylish!",
	"Magnífico! Very good very nice!",
]
const CREATOR_RANDOM := [
	"Surprise, chicken nugget!",
	"Random! Very good very nice!",
	"Who is this?! Very nice!",
	"New day, new you!",
]
const CREATOR_CONFIRM := "Very good very nice! Let's go!"
const VENDOR_NAMES := [
	"Chicken Nugget King", "Señor Bargain", "Big Deal", "Lookee Larry", "Very Nice Vince",
	"Flamingo Fran", "Sunny Sam", "Captain Cheap", "Nugget Nora", "Paco Plastico",
	"Rolax Rob", "Bumbag Bea", "Sandy Sal", "Selfie Sid", "Dolores Deals",
]

# --- Helpers -------------------------------------------------------------------------------

static func pick(list: Array, rng: RandomNumberGenerator = null) -> String:
	if list.is_empty():
		return ""
	if rng:
		return str(list[rng.randi() % list.size()])
	return str(list.pick_random())


## Replaces {key} placeholders. Example: Lines.fmt(Lines.pick(Lines.SALE), {"item": "Ray-Bams"}).
static func fmt(text: String, values: Dictionary) -> String:
	var out := text
	for key in values:
		out = out.replace("{%s}" % key, str(values[key]))
	return out


static func money(amount: float) -> String:
	if absf(amount) >= 10000.0:
		return "€%sk" % String.num(amount / 1000.0, 1)
	if absf(amount - roundf(amount)) < 0.005:
		return "€%d" % int(roundf(amount))
	return "€%.2f" % amount
