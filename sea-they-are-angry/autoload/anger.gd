extends Node

signal changed(value: int)

const MAX := 10

var value := 0
var _delta_this_night := 0

func reset() -> void:
	set_value(0)

func set_value(v: int) -> void:
	value = clampi(v, 0, MAX)
	_delta_this_night = 0
	changed.emit(value)

func add(amount: int) -> void:
	var new_delta := clampi(_delta_this_night + amount, -1, 2)
	var applied := new_delta - _delta_this_night
	_delta_this_night = new_delta
	value = clampi(value + applied, 0, MAX)
	changed.emit(value)

func on_dawn(structures_damaged: int) -> void:
	var calm := 1 if structures_damaged < 3 else 2
	value = clampi(value - calm, 0, MAX)
	_delta_this_night = 0
	changed.emit(value)
