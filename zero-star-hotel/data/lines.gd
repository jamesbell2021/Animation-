class_name Lines
extends RefCounted
## Every piece of text the hotel says, in one place: guest shouts, staff lines, incidents,
## the reviews guests leave on "TrotAdvisor", the inspector's verdicts and the tips.
## Satire of package-holiday chaos, never of who anyone is.

const HOTEL_DEFAULT_NAME := "Hotel Paradiso"
const HOTEL_NAMES := ["Hotel Paradiso", "The Sunny Cockroach", "Costa Del Grim", "Hotel Splendido (ish)",
	"The Pint & Lounger", "Bella Vista (No View)", "Casa Calamari", "The Last Resort", "Hostal Fawlty-ish"]

# --- Guests ------------------------------------------------------------------------------------

const LADS := ["OI OI!", "Ere we go, ere we go!", "Two pints please, mate!", "Lads lads lads!",
	"Is it beer o'clock?", "Who's got the inflatable?", "Cheap pints! Get in!", "Taps aff!"]
const HENS := ["WOOOO!", "Prosecco o'clock!", "Where's the bride?!", "Sash on, girls!",
	"Shots! Shots! Shots!", "Is the barman single?"]
const FAMILY := ["Don't run by the pool!", "Has anyone seen Tyler?", "Suncream! NOW!",
	"Is there a kids' club?", "Mum, I need a wee!", "Are we nearly at the pool?"]
const MUMS := ["That's MY lounger!", "Towel down at 6am, love.", "Another wine, please!",
	"Kids are with their dad, thank God.", "Girls' holiday!", "Hold my sangria."]
const PENSIONERS := ["Is it always this loud?", "In my day hotels had doors.", "Lovely weather.",
	"Where's the full English?", "I'll be writing a letter.", "Is that a cockroach, Brian?"]
const BACKPACKERS := ["How many to a room?", "Does breakfast count as lunch?", "Got any free wifi?",
	"Mate, the towel is my bedsheet.", "I've stayed in worse. In a tent."]
const COUPLES := ["Is this the romantic suite?", "It looked bigger online.", "Let's get a cocktail.",
	"At least the sunset is free."]

const DRUNK := ["I love you, mate!", "Who moved the floor?", "*hic*", "Another one!",
	"I'm not drunk, you're drunk.", "Ere, where's my room?", "One more pint!"]
const HAPPY := ["Not bad for the price!", "Lovely!", "Cheap AND cheerful!", "Better than last year!"]
const UNHAPPY := ["This is grim.", "What's that smell?", "I want a refund!", "Never again."]

# --- Staff -------------------------------------------------------------------------------------

const CLEANER := ["Housekeeping!", "Who did THIS?!", "Not again...", "Mop's out!", "I've seen things."]
const HANDYMAN := ["That'll need a new one.", "Who throws a telly?!", "Gaffer tape fixes all.", "Sorted."]
const SECURITY := ["Oi! Pack it in!", "Lights out, lads.", "Not on my watch.", "Move along."]
const LIFEGUARD := ["NO DIVING!", "Got you!", "Walk, don't run!", "Arm bands, please!"]
const BARMAN := ["What can I get you?", "Pint of the usual?", "Happy hour all day!", "Last orders!"]
const MANAGER := ["I'm the manager!", "Everyone calm down!", "Not in my hotel!", "Sorted. Next!"]

# --- Incidents ---------------------------------------------------------------------------------

const INCIDENT_TEXT := {
	"music": ["Room %s is having a rave!", "Bass is shaking room %s!"],
	"fight": ["Fight at the bar!", "Two lads are scrapping!", "Punch-up at the bar!"],
	"vandal": ["Someone's trashing room %s!", "A telly just flew out of room %s!"],
	"theft": ["A thief is sneaking around!", "Someone's nicking towels!"],
	"pool": ["Someone's flailing in the pool!", "Drunk belly-flop! Help!"],
	"lounger": ["Sunlounger war by the pool!", "Mums battling over a lounger!"],
	"roach": ["Cockroaches in room %s!"],
}
const RESOLVED := {
	"music": ["Music turned down. For now.", "Rave over. Neighbours sleep."],
	"fight": ["Fight broken up!", "Everyone's friends again. Probably."],
	"vandal": ["Vandal stopped!", "The telly survives. Just."],
	"theft": ["Thief chased off!", "Towels saved!"],
	"pool": ["Rescued! Nobody drowns on my watch!", "Saved! Arm bands for everyone."],
	"lounger": ["Lounger war settled.", "Peace by the pool. Towels down."],
	"roach": ["Squashed!"],
}
const FAILED := {
	"music": "The rave went on till dawn. Neighbours furious.",
	"fight": "The fight wrecked the bar. Guests unhappy.",
	"vandal": "Room %s got trashed.",
	"theft": "Something got nicked. A guest is fuming.",
	"pool": "Paramedics fished them out. The pool is closed for an hour.",
	"lounger": "The lounger war ended in tears and sangria.",
}

# --- Reviews (TrotAdvisor) ---------------------------------------------------------------------

const REVIEW_SITE := "TrotAdvisor"
const REVIEWS := {
	1: ["Found a cockroach doing the backstroke in the toilet.", "Zero stars is generous.",
		"Room smelled like a kebab's armpit.", "Got robbed. By the hotel AND a thief.",
		"Woken at 4am by a rave and a flying telly.", "The pool was green. GREEN."],
	2: ["Grim, but the pints were a euro.", "Bed was damp. Spirit was not.", "Would not recommend to my enemies.",
		"Bit loud. Bit dirty. Bit much.", "The cockroaches were friendly at least."],
	3: ["Does what it says. Mostly.", "Cheap and only slightly cheerful.", "Noisy but the staff tried.",
		"Pool was nice once they fished the inflatable out.", "Would maybe come again. Maybe."],
	4: ["Honestly? Really good for the money!", "Clean room, cold pints, warm pool.", "Staff were lovely!",
		"Surprisingly nice. Who knew?", "The lifeguard is a hero."],
	5: ["Best holiday ever!!! Five stars!!!", "Paradise. Actual paradise.", "Better than the brochure!",
		"Booked again for next year!", "Absolute gem of the Costa!"],
}
const PREVIOUS_OWNER_REVIEWS := [
	[1, "Previous guest", "Hotel Paradiso? Hotel Parasite more like."],
	[1, "Previous guest", "The 'sea view' was a puddle with a painting of the sea."],
	[2, "Previous guest", "Cheap. That's the only nice thing I can say."],
	[1, "Previous guest", "Something lives in the pool. Something big."],
]

# --- Stars and the inspector -------------------------------------------------------------------

const STAR_NAMES := ["Zero Stars", "One Star", "Two Stars", "Three Stars"]
const STAR_TITLES := ["Officially a Health Hazard", "Technically a Hotel", "Actually Quite Decent", "THREE STAR STATUS!"]
const INSPECTOR := ["*scribbles*", "Hmm.", "I see...", "Interesting.", "Is that... a cockroach?", "*sniffs*"]
const INSPECTION_PASS := "The inspector nods. The inspector smiles?! Another star for %s!"
const INSPECTION_FAIL := "The inspector saw %d problems. No star this time. Fix things up and ask again."

# --- Day summaries -------------------------------------------------------------------------------

const DAY_GOOD := ["A profitable day of chaos!", "The tills are ringing!", "Guests are (mostly) smiling!"]
const DAY_OK := ["Survived another day.", "Nobody drowned. Result!", "Could be worse. Has been worse."]
const DAY_BAD := ["A disaster, but a cheap one.", "The cockroaches had a better day than you.", "Tomorrow can only be better. Surely."]

# --- Tips ----------------------------------------------------------------------------------------

const TIPS := [
	"Tap a cockroach to squash it. Very satisfying.",
	"Cheap pints keep the lads happy... and drunk. Drunk lads break things.",
	"A lifeguard stops pool disasters before they happen.",
	"Dirty rooms attract cockroaches. Hire a cleaner!",
	"More sunloungers means fewer lounger wars.",
	"Meet every requirement on the Stars tab, then call the inspector.",
	"Soundproofing stops one rave keeping the whole floor awake.",
	"Room safes make theft impossible. Thieves hate this one trick.",
]

const TUTORIAL := {
	"start": "Welcome to %s, the worst hotel on the Costa! Guests arrive in the afternoon.",
	"incident": "Trouble! Tap the warning bubble to send your manager.",
	"roach": "Cockroaches! Tap them to squash them.",
	"shop": "Use the UPGRADES button to fix the place up.",
	"rooms": "Tip: tap a boarded-up room to open it. More rooms, more guests, more money!",
	"stars": "Your goal: THREE STARS. Check the Stars tab to see what the inspector wants.",
}

const MANAGER_NAMES := ["Big Steve", "Dolores", "Gary", "Concha", "Terry", "Pilar", "Kev", "Maribel"]


static func pick(list: Array, rng: RandomNumberGenerator = null) -> String:
	if list.is_empty():
		return ""
	return str(list[rng.randi() % list.size()]) if rng else str(list.pick_random())


static func money(amount: float) -> String:
	if absf(amount) >= 10000.0:
		return "€%sk" % String.num(amount / 1000.0, 1)
	if absf(amount - roundf(amount)) < 0.005 or absf(amount) >= 10.0:
		return "€%d" % int(roundf(amount))
	return "€%.2f" % amount


static func stars_text(n: float) -> String:
	var s := ""
	for i in 5:
		s += "★" if n >= i + 0.75 else ("½" if n >= i + 0.25 else "☆")
	return s
