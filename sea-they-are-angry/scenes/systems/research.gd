class_name Research
extends RefCounted
## What the keepers can work out at the desk in the camp's mess, from what they find in
## the internees' notes and what they have in the store. One project at a time: begun
## by day, worked at overnight, done by dawn. Done projects are kept in `Run.research`.

const PROJECTS := {
	"tracking": {"name": "Clockwork tracking", "cost": {"scrap": 3, "notes": 1},
		"blurb": "a searchlight nobody is on follows whatever comes into its reach, and narrows onto it"},
	"reflectors": {"name": "Silvered reflectors", "cost": {"scrap": 2, "bio": 2, "notes": 1},
		"blurb": "the searchlights reach 5 m further and burn 60% harder"},
	"governor": {"name": "Generator governor", "cost": {"scrap": 3, "notes": 1},
		"blurb": "the generator burns a third less diesel"},
	"wire": {"name": "Barbed-wire coils", "cost": {"scrap": 2, "notes": 1},
		"blurb": "coils of wire at the cairns and defence posts: slow and cut whatever pushes through"},
	"tripwire": {"name": "Tripwire flares", "cost": {"scrap": 2, "bio": 1, "notes": 1},
		"blurb": "a wire across the path that fires a flare into whatever trips it"},
	"sandbags": {"name": "Sandbag walls", "cost": {"driftwood": 3, "notes": 1},
		"blurb": "a wall of sandbags across a path, that creatures have to batter down"},
	"cloches": {"name": "Cold frames", "cost": {"driftwood": 2, "seeds": 1, "notes": 1},
		"blurb": "the camp's beds come through storms, and the greenhouse gives 2 more"},
	"rations": {"name": "Tinning", "cost": {"scrap": 2, "food": 1, "notes": 1},
		"blurb": "every harvest, at the camp and the cottage, gives a food more"},
	"bell": {"name": "Alarm bell", "cost": {"scrap": 1, "notes": 1},
		"blurb": "the camp's bell rings when anything comes ashore on the holm, and says where"},
}

static func has(id: String) -> bool:
	return Run.research.has(id)

static func busy() -> bool:
	return Run.researching != ""

static func can_start(id: String) -> bool:
	return not busy() and not has(id) and Stock.can_afford(PROJECTS[id]["cost"])

## Begin a project, paying for it. Returns false (so a menu closes after).
static func start(id: String) -> bool:
	if not can_start(id) or not Stock.spend(PROJECTS[id]["cost"]):
		return false
	Run.researching = id
	Events.message.emit("Working out %s: done by dawn." % PROJECTS[id]["name"])
	return false

## At dawn: tonight's project is done.
static func finish() -> String:
	var id := Run.researching
	if id == "":
		return ""
	Run.researching = ""
	if not Run.research.has(id):
		Run.research.append(id)
	return id

static func title(id: String) -> String:
	return PROJECTS[id]["name"]
