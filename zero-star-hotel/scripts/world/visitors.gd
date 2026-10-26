class_name Visitor
extends Walker
## Uninvited (or very invited) visitors: a thief who sneaks into an empty room, or the star
## inspector touring the hotel with a clipboard. HotelWorld creates and referees them.

enum Kind { THIEF, INSPECTOR }
enum S { ENTER, TOUR, RUMMAGE, FLEE, GONE }

var kind: Kind = Kind.THIEF
var state: S = S.ENTER
var target_room := -1
var incident: Incident
var stops: Array = []           # inspector: [position, label, check Callable]
var _timer := 0.0
var _rng := RandomNumberGenerator.new()


func setup_thief(w: Node, room_index: int) -> void:
	world = w
	kind = Kind.THIEF
	target_room = room_index
	_rng.randomize()
	setup_avatar(AppearanceOptions.staff_appearance("thief", _rng), true)
	speed = 85.0
	position = Vector2(HotelLayout.STREET_X, HotelLayout.GROUND_Y)
	go_to(HotelLayout.room_spot(room_index, _rng))
	state = S.ENTER


func setup_inspector(w: Node, tour: Array) -> void:
	world = w
	kind = Kind.INSPECTOR
	stops = tour
	_rng.randomize()
	setup_avatar(AppearanceOptions.staff_appearance("inspector", _rng), true)
	avatar.hold_item("clipboard")
	speed = 55.0
	position = Vector2(HotelLayout.STREET_X, HotelLayout.GROUND_Y)
	state = S.TOUR
	_next_stop()


## Thief: spotted and chased off.
func flee(empty_handed: bool) -> void:
	state = S.FLEE
	speed = 190.0
	avatar.hold_item("" if empty_handed else "swag")
	say("Leg it!" if empty_handed else "Ha! Mine now!", "bad", 1.4)
	go_to(Vector2(HotelLayout.STREET_X - 40.0, HotelLayout.GROUND_Y), true)


func _process(delta: float) -> void:
	_timer -= delta
	match state:
		S.ENTER:
			if step_path(delta):
				state = S.RUMMAGE
				_timer = 4.5
				avatar.present(4.5)
		S.RUMMAGE:
			if _timer <= 0.0:
				world.thief_steals(self)
		S.TOUR:
			if moving or not path.is_empty():
				step_path(delta)
			elif _timer <= 0.0:
				if not stops.is_empty() and stops[0].has("arrived"):
					var stop_def: Dictionary = stops.pop_front()
					(stop_def.check as Callable).call()
					_next_stop()
				elif not stops.is_empty():
					stops[0]["arrived"] = true
					_timer = 3.0
					avatar.present(2.0)
					say(Lines.pick(Lines.INSPECTOR, _rng), "think", 2.2)
		S.FLEE:
			if step_path(delta, speed):
				state = S.GONE
				queue_free()


func _next_stop() -> void:
	if stops.is_empty():
		go_to(Vector2(HotelLayout.STREET_X - 40.0, HotelLayout.GROUND_Y))
		state = S.FLEE
		speed = 60.0
		return
	go_to(stops[0].pos)
