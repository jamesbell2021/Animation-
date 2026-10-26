extends Node

var active := false
var night := 1
var lamp_fuel := 100.0
## Diesel in the camp's generator (Generator.fuel), 0 to 100.
var camp_fuel := 60.0
## The camp's three outdoor beds and the greenhouse: 0 bare, 1 planted, 2 ready (CampPlot).
var camp_crops := [0, 0, 0, 0]
## Each keeper's hunger and warmth, 0 to 100 (100 fed and warm), by keeper index.
var hunger := [100.0, 100.0, 100.0]
var warmth := [100.0, 100.0, 100.0]
## Research done (Research.PROJECTS ids), and the one being worked out tonight.
var research: Array = []
var researching := ""
## How many of the internees' pages have been found (which one turns up next).
var notes_found := 0
## Upgrade levels bought at the cottage, 1 to 3 (see Upgrades).
var upgrades := {"lighthouse": 1, "defences": 1, "garden": 1}
## Extra max health each keeper has eaten their way to, by keeper index.
var max_hp_bonus := [0, 0, 0]
## Each garden plot: 0 bare, 1 planted (ripens at dawn), 2 ready to lift.
var crops := [0, 0, 0, 0, 0]
## Flares in each keeper's gun.
var flares := [2, 2, 2]
## What each keeper carries besides the boathook ("bow", "shotgun", "flamer"; see Arsenal).
## There's one shotgun and one weed burner: whoever isn't carrying them, they're in the shed.
var arms := [[], [], []]
## The weed burner rigged as a flamer yet, and what's in its tank (0 to 100).
var flamer_rigged := false
var flamer_fuel := 0.0
## Cartridges in the shotgun's two barrels.
var barrels := 2
## Seeds each night's weather roll (see Weather.tonight), so a reload keeps it.
var weather_seed := 0
var weather_for := 0
var weather_kind := 0
# Set before reloading the scene to skip the title screen (New Run from game over).
var quick_start := false

func start_new() -> void:
	night = 1
	lamp_fuel = 100.0
	camp_fuel = 60.0
	camp_crops = [0, 0, 0, 0]
	hunger = [100.0, 100.0, 100.0]
	warmth = [100.0, 100.0, 100.0]
	research = []
	researching = ""
	notes_found = 0
	upgrades = {"lighthouse": 1, "defences": 1, "garden": 1}
	max_hp_bonus = [0, 0, 0]
	crops = [0, 0, 0, 0, 0]
	flares = [2, 2, 2]
	arms = [[], [], []]
	flamer_rigged = false
	flamer_fuel = 0.0
	barrels = 2
	weather_seed = randi()
	weather_for = 0
	Anger.reset()
	Stock.reset()
	active = true

func start_loaded(d: Dictionary) -> void:
	night = int(d.get("night", 1))
	lamp_fuel = float(d.get("fuel", 100.0))
	camp_fuel = float(d.get("camp_fuel", 60.0))
	camp_crops = [0, 0, 0, 0]
	var cc: Array = d.get("camp_crops", [])
	for i in mini(cc.size(), 4):
		camp_crops[i] = clampi(int(cc[i]), 0, 2)
	hunger = _three(d.get("hunger", []))
	warmth = _three(d.get("warmth", []))
	research = []
	for r in d.get("research", []):
		research.append(String(r))
	researching = String(d.get("researching", ""))
	notes_found = int(d.get("notes_found", 0))
	var up: Dictionary = d.get("upgrades", {})
	upgrades = {"lighthouse": int(up.get("lighthouse", 1)), "defences": int(up.get("defences", 1)), "garden": int(up.get("garden", 1))}
	var bonus: Array = d.get("max_hp_bonus", [0, 0, 0])
	max_hp_bonus = [int(bonus[0]) if bonus.size() > 0 else 0, int(bonus[1]) if bonus.size() > 1 else 0, int(bonus[2]) if bonus.size() > 2 else 0]
	var c: Array = d.get("crops", [])
	crops = [0, 0, 0, 0, 0]
	for i in mini(c.size(), crops.size()):
		crops[i] = clampi(int(c[i]), 0, 2)
	var fl: Array = d.get("flares", [2, 2, 2])
	flares = [2, 2, 2]
	for i in mini(fl.size(), 3):
		flares[i] = clampi(int(fl[i]), 0, 2)
	arms = [[], [], []]
	var ar: Array = d.get("arms", [])
	for i in mini(ar.size(), 3):
		for w in ar[i]:
			arms[i].append(String(w))
	flamer_rigged = bool(d.get("flamer_rigged", false))
	flamer_fuel = clampf(float(d.get("flamer_fuel", 0.0)), 0.0, 100.0)
	barrels = clampi(int(d.get("barrels", 2)), 0, 2)
	weather_seed = int(d.get("weather_seed", randi()))
	weather_for = 0
	Anger.set_value(int(d.get("anger", 0)))
	Stock.set_all(d.get("stock", {}))
	active = true

static func _three(a: Array) -> Array:
	var out := [100.0, 100.0, 100.0]
	for i in mini(a.size(), 3):
		out[i] = clampf(float(a[i]), 0.0, 100.0)
	return out

func advance_night(structures_damaged: int) -> void:
	Anger.on_dawn(structures_damaged)
	night += 1
	SaveSys.save_run()

func end_run(reason: String) -> void:
	if not active:
		return
	active = false
	SaveSys.save_best(night)
	SaveSys.clear_run()
	Events.run_ended.emit(reason, night)
