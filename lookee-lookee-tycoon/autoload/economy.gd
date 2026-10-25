extends Node
## Autoload: money and stock. Buying from the Wholesaler, pricing, picking what a tourist
## wants, recording sales, fines and confiscations. Daily and lifetime stats feed the day
## summary and the save file.

signal cash_changed(cash: float, delta: float)
signal stock_changed(item_id: String, count: int)
signal sale_made(item_id: String, price: float, world_pos: Vector2)
signal markup_changed(index: int)

const START_CASH := 40.0
const START_STOCK := {"sunglasses": 15, "magnet": 15, "bracelet": 10}

## Price settings the player cycles through on the HUD. mult raises the price; tourists notice.
const MARKUPS := [
	{"name": "Bargain", "mult": 0.75, "desc": "Cheap cheap! Everybody buys."},
	{"name": "Fair", "mult": 1.0, "desc": "Very good very nice price."},
	{"name": "Cheeky", "mult": 1.4, "desc": "A little bit cheeky, chicken nugget."},
	{"name": "Daylight Robbery", "mult": 2.0, "desc": "Very good for you, very not nice for them."},
]

var cash := START_CASH
var inventory := {}
var markup_index := 1
var day_stats := {}
var lifetime := {}


func _ready() -> void:
	reset_day_stats()
	reset_lifetime()


func new_game() -> void:
	cash = START_CASH
	inventory = START_STOCK.duplicate()
	markup_index = 1
	reset_day_stats()
	reset_lifetime()
	cash_changed.emit(cash, 0.0)
	for id in inventory:
		stock_changed.emit(id, inventory[id])


func reset_day_stats() -> void:
	day_stats = {"revenue": 0.0, "sales": 0, "stock_spent": 0.0, "upgrades": 0.0, "fines": 0.0,
		"bribes": 0.0, "wages": 0.0, "confiscated": 0, "empire": 0.0, "best": {}, "events": 0, "other": 0.0}


func reset_lifetime() -> void:
	lifetime = {"revenue": 0.0, "sales": 0, "fines": 0.0, "escapes": 0, "busts": 0, "days": 0, "shouts": 0}


# --- Cash ------------------------------------------------------------------------------------

func can_afford(amount: float) -> bool:
	return cash + 0.001 >= amount


func add_cash(amount: float, reason := "") -> void:
	if amount == 0.0:
		return
	cash += amount
	if reason == "empire":
		day_stats.empire += amount
	elif reason != "sale" and amount > 0.0:
		day_stats.other += amount
	cash_changed.emit(cash, amount)


## Spends if affordable. Reason is one of: stock, upgrade, fine, bribe, wages, beach, other.
func spend(amount: float, reason := "other") -> bool:
	if not can_afford(amount):
		return false
	cash -= amount
	match reason:
		"stock": day_stats.stock_spent += amount
		"upgrade", "beach", "staff": day_stats.upgrades += amount
		"fine": day_stats.fines += amount
		"bribe": day_stats.bribes += amount
		"wages": day_stats.wages += amount
	cash_changed.emit(cash, -amount)
	return true


## Fines and wages can push you into the red; you just start tomorrow in debt.
func force_spend(amount: float, reason := "fine") -> void:
	if can_afford(amount):
		spend(amount, reason)
		return
	cash -= amount
	if reason == "fine":
		day_stats.fines += amount
	elif reason == "wages":
		day_stats.wages += amount
	cash_changed.emit(cash, -amount)


# --- Stock -----------------------------------------------------------------------------------

func count(id: String) -> int:
	return int(inventory.get(id, 0))


func total_stock() -> int:
	var n := 0
	for id in inventory:
		n += int(inventory[id])
	return n


func max_stock() -> int:
	return Upgrades.max_stock()


func space_left() -> int:
	return maxi(max_stock() - total_stock(), 0)


func wholesale_price(id: String) -> float:
	var item := ItemDB.get_item(id)
	return float(item.get("cost", 1.0)) * Upgrades.wholesale_mult() * RandomEvents.mult("wholesale")


func is_unlocked(id: String) -> bool:
	return ItemDB.tier(id) <= Upgrades.supplier_tier()


## Buys qty items (clamped to storage space). Returns how many were bought.
func buy_stock(id: String, qty: int, fee_mult := 1.0) -> int:
	if not ItemDB.has(id) or not is_unlocked(id):
		return 0
	qty = mini(qty, space_left())
	if qty <= 0:
		return 0
	var unit := wholesale_price(id) * fee_mult
	var affordable := int(floor((cash + 0.001) / maxf(unit, 0.01)))
	qty = mini(qty, affordable)
	if qty <= 0:
		return 0
	spend(unit * qty, "stock")
	inventory[id] = count(id) + qty
	stock_changed.emit(id, inventory[id])
	return qty


func take_item(id: String) -> bool:
	if count(id) <= 0:
		return false
	inventory[id] = count(id) - 1
	if inventory[id] <= 0:
		inventory.erase(id)
	stock_changed.emit(id, count(id))
	return true


func remove_random(n: int, rng: RandomNumberGenerator = null) -> int:
	var removed := 0
	for i in n:
		var ids := inventory.keys()
		if ids.is_empty():
			break
		var id: String = ids[rng.randi() % ids.size()] if rng else ids.pick_random()
		if take_item(id):
			removed += 1
	return removed


## Police take a fraction of every stack. Returns how many items were lost.
func confiscate(fraction: float) -> int:
	var lost := 0
	for id in inventory.keys():
		var n := int(ceil(count(id) * clampf(fraction, 0.0, 1.0)))
		if n <= 0:
			continue
		inventory[id] = count(id) - n
		lost += n
		if inventory[id] <= 0:
			inventory.erase(id)
		stock_changed.emit(id, count(id))
	day_stats.confiscated += lost
	return lost


## Item ids in stock, best sellers first (for stall displays).
func stocked_ids() -> Array:
	var ids := inventory.keys()
	ids.sort_custom(func(a, b): return count(a) > count(b))
	return ids


# --- Selling ---------------------------------------------------------------------------------

func markup() -> float:
	return float(MARKUPS[markup_index].mult)


func cycle_markup() -> void:
	markup_index = (markup_index + 1) % MARKUPS.size()
	markup_changed.emit(markup_index)


func set_markup(i: int) -> void:
	markup_index = clampi(i, 0, MARKUPS.size() - 1)
	markup_changed.emit(markup_index)


func sale_price(id: String) -> float:
	var base := float(ItemDB.get_item(id).get("price", 1.0))
	var beach := BeachDB.get_beach(GameManager.current_beach)
	var p := base * markup() * (0.85 + 0.15 * float(beach.wealth)) * RandomEvents.item_price_mult(id)
	return snappedf(p, 0.5) if p >= 3.0 else snappedf(p, 0.1)


## Which item a tourist of this type would like most from what's in stock ("" if nothing).
func pick_item_for(tourist_type: String, rng: RandomNumberGenerator) -> String:
	var weights := {}
	for id in inventory:
		if count(id) <= 0:
			continue
		var a := ItemDB.appeal(id, tourist_type) * RandomEvents.item_demand(id)
		if a > 0.0:
			weights[id] = a * a
	if weights.is_empty():
		return ""
	return TouristTypes.weighted_pick(weights, rng)


## Chance that a tourist with this budget/mood buys the item at the current price.
func sale_chance(id: String, tourist_type: String, budget: float, mood_mult: float, bonus := 0.0) -> float:
	var price := sale_price(id)
	var appeal := ItemDB.appeal(id, tourist_type) * RandomEvents.item_demand(id)
	var willingness := budget * appeal * 0.4
	var r := willingness / maxf(price, 0.1)
	var chance := r / (r + 1.0) * mood_mult + bonus + RandomEvents.add("sale_chance")
	return clampf(chance, 0.03, 0.94)


## Takes the item and pays. world_pos is where the coins should pop.
func complete_sale(id: String, price: float, world_pos: Vector2) -> bool:
	if not take_item(id):
		return false
	cash += price
	day_stats.revenue += price
	day_stats.sales += 1
	day_stats.best[id] = int(day_stats.best.get(id, 0)) + 1
	lifetime.revenue += price
	lifetime.sales += 1
	cash_changed.emit(cash, price)
	sale_made.emit(id, price, world_pos)
	return true


func best_seller_today() -> String:
	var best := ""
	var n := 0
	for id in day_stats.best:
		if int(day_stats.best[id]) > n:
			n = int(day_stats.best[id])
			best = id
	return best


# --- Save ------------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"cash": cash, "inventory": inventory.duplicate(), "markup": markup_index, "lifetime": lifetime.duplicate()}


func from_dict(d: Dictionary) -> void:
	cash = float(d.get("cash", START_CASH))
	inventory = {}
	var inv: Dictionary = d.get("inventory", {})
	for id in inv:
		if ItemDB.has(id) and int(inv[id]) > 0:
			inventory[id] = int(inv[id])
	markup_index = clampi(int(d.get("markup", 1)), 0, MARKUPS.size() - 1)
	reset_lifetime()
	var lt: Dictionary = d.get("lifetime", {})
	for k in lt:
		lifetime[k] = lt[k]
	reset_day_stats()
	cash_changed.emit(cash, 0.0)
