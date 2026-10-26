extends Node
## Autoload: money. Room takings each night, the bar's cheap pints, wages, repairs, paramedics
## and everything else the day costs. Daily stats feed the end-of-day summary.

signal cash_changed(cash: float, delta: float)
signal prices_changed

const START_CASH := 600.0

## Room price settings (multiplier on each room's base rate).
const ROOM_PRICES := [
	{"name": "Bargain", "mult": 0.7}, {"name": "Normal", "mult": 1.0},
	{"name": "Pricey", "mult": 1.35}, {"name": "Cheeky", "mult": 1.8},
]
## Pint prices: cheap pints sell more and get guests drunker.
const PINT_PRICES := [
	{"name": "€1 Pints!", "price": 1.0, "thirst": 1.6},
	{"name": "€2 Pints", "price": 2.0, "thirst": 1.0},
	{"name": "€3.50 Pints", "price": 3.5, "thirst": 0.6},
]

var cash := START_CASH
var room_price_index := 1
var pint_price_index := 0
var day_stats := {}


func _ready() -> void:
	reset_day_stats()


func new_game() -> void:
	cash = START_CASH
	room_price_index = 1
	pint_price_index = 0
	reset_day_stats()
	cash_changed.emit(cash, 0.0)


func reset_day_stats() -> void:
	day_stats = {"rooms": 0.0, "bar": 0.0, "deposits": 0.0, "wages": 0.0, "repairs": 0.0, "upgrades": 0.0,
		"fines": 0.0, "theft": 0.0, "other": 0.0, "pints": 0, "nights": 0}


func can_afford(amount: float) -> bool:
	return cash + 0.001 >= amount


func earn(amount: float, reason := "other") -> void:
	if amount <= 0.0:
		return
	cash += amount
	day_stats[reason] = float(day_stats.get(reason, 0.0)) + amount
	cash_changed.emit(cash, amount)


func spend(amount: float, reason := "other") -> bool:
	if not can_afford(amount):
		return false
	_pay(amount, reason)
	return true


## Wages, paramedics and repairs can push you into the red.
func force_spend(amount: float, reason := "other") -> void:
	_pay(amount, reason)


func _pay(amount: float, reason: String) -> void:
	if amount <= 0.0:
		return
	cash -= amount
	day_stats[reason] = float(day_stats.get(reason, 0.0)) + amount
	cash_changed.emit(cash, -amount)


func room_mult() -> float:
	return float(ROOM_PRICES[room_price_index].mult)


func pint_price() -> float:
	return float(PINT_PRICES[pint_price_index].price) * Upgrades.bar_price_mult()


func thirst() -> float:
	return float(PINT_PRICES[pint_price_index].thirst)


func cycle_room_price() -> void:
	room_price_index = (room_price_index + 1) % ROOM_PRICES.size()
	prices_changed.emit()


func cycle_pint_price() -> void:
	pint_price_index = (pint_price_index + 1) % PINT_PRICES.size()
	prices_changed.emit()


func sell_pint() -> float:
	var p := pint_price()
	day_stats.pints += 1
	earn(p, "bar")
	return p


func profit_today() -> float:
	var s := day_stats
	return s.rooms + s.bar + s.deposits + s.other - s.wages - s.repairs - s.fines - s.theft


func to_dict() -> Dictionary:
	return {"cash": cash, "room_price": room_price_index, "pint_price": pint_price_index}


func from_dict(d: Dictionary) -> void:
	cash = float(d.get("cash", START_CASH))
	room_price_index = clampi(int(d.get("room_price", 1)), 0, ROOM_PRICES.size() - 1)
	pint_price_index = clampi(int(d.get("pint_price", 0)), 0, PINT_PRICES.size() - 1)
	reset_day_stats()
	cash_changed.emit(cash, 0.0)
	prices_changed.emit()
