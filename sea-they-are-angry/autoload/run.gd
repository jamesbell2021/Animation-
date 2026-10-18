extends Node

var active := false
var night := 1
var lamp_fuel := 100.0

func start_new() -> void:
	night = 1
	lamp_fuel = 100.0
	Anger.reset()
	Stock.reset()
	active = true

func start_loaded(d: Dictionary) -> void:
	night = int(d.get("night", 1))
	lamp_fuel = float(d.get("fuel", 100.0))
	Anger.set_value(int(d.get("anger", 0)))
	Stock.set_all(d.get("stock", {}))
	active = true

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
