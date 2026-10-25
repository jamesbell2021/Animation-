extends Node
## Autoload: your Lookee Lookee workforce. Workers are hired per beach, have a role, a skill
## (1-3 stars), a daily wage and their own randomly generated look. On the beach you're
## playing they appear and work (see scripts/beach/worker.gd); on your other beaches they earn
## an estimated income at the end of each day.

signal staff_changed
signal candidates_changed

const ROLES := {
	"seller": {
		"name": "Blanket Seller", "wage": 22.0,
		"desc": "Runs a second blanket on the beach with your stock. Hello chicken nugget times two!",
	},
	"shouter": {
		"name": "Shouter", "wage": 14.0,
		"desc": "Walks the beach yelling \"Hello chicken nugget!\" and sends tourists your way.",
	},
	"lookout": {
		"name": "Lookout", "wage": 16.0,
		"desc": "Spots police early and asks them for directions. Very good very nice!",
	},
	"runner": {
		"name": "Runner", "wage": 18.0,
		"desc": "Restocks from the van when you run low. Very good very fast!",
	},
}

const NAMES := ["Big Dave", "Little Dave", "Kofi", "Raj", "Mo", "Gary", "Carmen", "Ibrahim", "Dmitri",
	"Lola", "Tito", "Sandra", "Yusuf", "Babacar", "Priya", "Sven", "Aisha", "Paco", "Moussa", "Nina",
	"Chen", "Olu", "Fernando", "Gloria", "Ahmed", "Tomasz", "Mariam", "Jorge", "Keisha", "Lars",
	"Amadou", "Rosa", "Viktor", "Fatou", "Diego", "Zara"]
const NICKNAMES := ["the Voice", "Flip-Flop", "Very Nice", "the Flamingo", "Two Bags", "Speedy",
	"the Legend", "Sunglasses", "Rolax", "Nugget", "the Whisper", "Big Deal"]

var staff: Array = []          # Array of Dictionaries
var candidates: Array = []
var _next_id := 1
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func new_game() -> void:
	staff = []
	_next_id = 1
	refresh_candidates()
	staff_changed.emit()


func refresh_candidates() -> void:
	candidates = []
	var roles := ROLES.keys()
	for i in 3:
		var role: String = roles[_rng.randi() % roles.size()]
		if i == 0 and staff.is_empty():
			role = "shouter"
		candidates.append(_make_worker(role))
	candidates_changed.emit()


func _make_worker(role: String) -> Dictionary:
	var skill := 1
	var r := _rng.randf()
	if r > 0.9:
		skill = 3
	elif r > 0.6:
		skill = 2
	var nm: String = NAMES[_rng.randi() % NAMES.size()]
	if _rng.randf() < 0.35:
		nm += " " + NICKNAMES[_rng.randi() % NICKNAMES.size()]
	var look := AppearanceOptions.random_appearance(_rng)
	look.name = nm
	return {
		"id": 0, "name": nm, "role": role, "skill": skill,
		"wage": roundf(float(ROLES[role].wage) * (0.7 + 0.35 * skill)),
		"beach": "", "appearance": look,
	}


func on_beach(beach_id: String) -> Array:
	return staff.filter(func(w): return w.beach == beach_id)


func count_on_beach(beach_id: String) -> int:
	return on_beach(beach_id).size()


func can_hire(beach_id: String) -> bool:
	return count_on_beach(beach_id) < Upgrades.staff_cap()


func hire_cost(candidate: Dictionary) -> float:
	return roundf(float(candidate.wage) * 2.0)  # signing-on bonus: two days' pay up front


func hire(index: int, beach_id: String) -> bool:
	if index < 0 or index >= candidates.size() or not can_hire(beach_id):
		return false
	var c: Dictionary = candidates[index]
	if not Economy.spend(hire_cost(c), "staff"):
		return false
	c.id = _next_id
	_next_id += 1
	c.beach = beach_id
	staff.append(c)
	candidates.remove_at(index)
	candidates.append(_make_worker(ROLES.keys()[_rng.randi() % ROLES.size()]))
	staff_changed.emit()
	candidates_changed.emit()
	GameManager.notify(Lines.fmt(Lines.pick(Lines.STAFF_HIRED), {"name": c.name}), "good")
	return true


func fire(worker_id: int) -> void:
	for i in staff.size():
		if int(staff[i].id) == worker_id:
			var w: Dictionary = staff[i]
			staff.remove_at(i)
			staff_changed.emit()
			GameManager.notify(Lines.fmt(Lines.pick(Lines.STAFF_FIRED), {"name": w.name}), "info")
			return


func move_to(worker_id: int, beach_id: String) -> bool:
	if not can_hire(beach_id):
		return false
	for w in staff:
		if int(w.id) == worker_id:
			w.beach = beach_id
			staff_changed.emit()
			return true
	return false


func daily_wages() -> float:
	var total := 0.0
	for w in staff:
		total += float(w.wage)
	return total


func skill_mult(w: Dictionary) -> float:
	return (0.75 + 0.25 * int(w.skill)) * (1.0 + Upgrades.staff_skill_bonus())


## Rough income from a beach you're not playing on today: sellers sell, shouters help.
func offsite_income(beach_id: String) -> float:
	var b := BeachDB.get_beach(beach_id)
	var sellers := 0.0
	var helpers := 0.0
	for w in on_beach(beach_id):
		if w.role == "seller":
			sellers += skill_mult(w)
		elif w.role == "shouter":
			helpers += 0.25 * skill_mult(w)
	var income := sellers * 55.0 * float(b.wealth) * float(b.crowd) * (1.0 + helpers)
	# Without a lookout, sometimes the police win.
	var has_lookout := on_beach(beach_id).any(func(w): return w.role == "lookout")
	if not has_lookout:
		income *= 0.8
	return roundf(income)


func to_dict() -> Dictionary:
	return {"staff": staff.duplicate(true), "next_id": _next_id}


func from_dict(d: Dictionary) -> void:
	staff = []
	for w in d.get("staff", []):
		if typeof(w) != TYPE_DICTIONARY or not ROLES.has(str(w.get("role", ""))):
			continue
		w.appearance = AppearanceOptions.sanitize(w.get("appearance", {}))
		w.skill = clampi(int(w.get("skill", 1)), 1, 3)
		w.id = int(w.get("id", 0))
		w.wage = float(w.get("wage", 15.0))
		w.name = str(w.get("name", "Worker"))
		w.beach = str(w.get("beach", "benidorm"))
		staff.append(w)
	_next_id = int(d.get("next_id", staff.size() + 1))
	refresh_candidates()
	staff_changed.emit()
