extends Node
## Autoload: the hotel's staff. Each role handles one kind of trouble on its own:
##   cleaner   - cleans dirty rooms and sweeps up cockroaches
##   handyman  - repairs smashed tellies and trashed rooms
##   security  - breaks up fights, shuts down raves, chases thieves
##   lifeguard - watches the pool; nobody drowns on their shift
##   barman    - runs the bar, so it sells far more pints

signal staff_changed

const ROLES := {
	"cleaner": {"name": "Cleaner", "wage": 25.0, "max": 3,
		"desc": "Cleans dirty rooms and squashes cockroaches. Has seen things."},
	"handyman": {"name": "Handyman", "wage": 35.0, "max": 2,
		"desc": "Fixes smashed tellies, broken beds and anything that's been 'done in'."},
	"security": {"name": "Security", "wage": 40.0, "max": 2,
		"desc": "Breaks up fights, shuts down 4am raves and sees off thieves."},
	"lifeguard": {"name": "Lifeguard", "wage": 30.0, "max": 1,
		"desc": "Watches the pool. Rescues belly-floppers before it gets serious."},
	"barman": {"name": "Barman", "wage": 30.0, "max": 1,
		"desc": "Pulls pints all evening: the bar sells far more with someone behind it."},
}
const NAMES := ["Paco", "Lola", "Big Dave", "Mo", "Carmen", "Kofi", "Ana", "Tomás", "Sandra", "Raj",
	"Pepe", "Nuria", "Gaz", "Fatima", "Jorge", "Bev", "Iker", "Priya", "Manolo", "Shaz"]

var staff: Array = []
var _next_id := 1
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func new_game() -> void:
	staff = []
	_next_id = 1
	staff_changed.emit()


func count_role(role: String) -> int:
	return staff.filter(func(s): return s.role == role).size()


func can_hire(role: String) -> String:
	if not ROLES.has(role):
		return "Unknown"
	if count_role(role) >= int(ROLES[role].max):
		return "Fully staffed"
	if not Economy.can_afford(hire_cost(role)):
		return "Not enough cash"
	return ""


func hire_cost(role: String) -> float:
	return float(ROLES[role].wage) * 2.0


func hire(role: String) -> Dictionary:
	if can_hire(role) != "":
		return {}
	Economy.spend(hire_cost(role), "upgrade")
	var s := {"id": _next_id, "role": role, "name": NAMES[_rng.randi() % NAMES.size()], "seed": _rng.randi()}
	_next_id += 1
	staff.append(s)
	staff_changed.emit()
	return s


func fire(id: int) -> void:
	for i in staff.size():
		if int(staff[i].id) == id:
			staff.remove_at(i)
			staff_changed.emit()
			return


func appearance(s: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(s.seed)
	var a := AppearanceOptions.staff_appearance(str(s.role), rng)
	a.name = str(s.name)
	return a


func daily_wages() -> float:
	var t := 0.0
	for s in staff:
		t += float(ROLES[s.role].wage)
	return t


func to_dict() -> Dictionary:
	return {"staff": staff.duplicate(true), "next_id": _next_id}


func from_dict(d: Dictionary) -> void:
	staff = []
	for s in d.get("staff", []):
		if typeof(s) == TYPE_DICTIONARY and ROLES.has(str(s.get("role", ""))):
			staff.append({"id": int(s.get("id", 0)), "role": str(s.role), "name": str(s.get("name", "Staff")), "seed": int(s.get("seed", 0))})
	_next_id = int(d.get("next_id", staff.size() + 1))
	staff_changed.emit()
