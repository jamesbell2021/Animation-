class_name Guest
extends Walker
## A holidaymaker, one member of a guest group. Follows the hotel day: arrive and check in,
## lie by the pool or head to the beach, prop up the bar in the evening, and (depending on
## type and how many pints) go to bed... or start a rave, a fight or a 3am swim.
## The HotelWorld referees anything involving other people.

enum S { AWAY, ARRIVE, CHECKIN, TO_ROOM, ROOM, SLEEP, TO_POOL, LOUNGE, SWIM, TO_BAR, DRINK,
	OUT, PARTY, BRAWL, FLAIL, BATTLE, CHECKOUT, LEAVE }

var group_id := -1
var type_id := "lads"
var member := 0
var room := -1
var state: S = S.AWAY
var drunk := 0.0
var child := false
var lounger := -1
var stool := -1
var leader := false
var incident: Incident
var _timer := 0.0
var _think := 0.0
var _pint_timer := 0.0
var _is_out := false
var _rng := RandomNumberGenerator.new()


func setup(w: Node, g: Dictionary, index: int) -> void:
	world = w
	group_id = int(g.id)
	type_id = str(g.type)
	member = index
	room = int(g.room)
	leader = index == 0
	child = type_id == "family" and index >= 2
	_rng.seed = int(g.seed) + index * 7919
	setup_avatar(AppearanceOptions.guest_appearance(type_id, _rng, child), true)
	_rng.randomize()
	speed = (45.0 if type_id == "pensioners" else 70.0) * _rng.randf_range(0.85, 1.15)
	if child:
		speed *= 1.1
	if bool(g.get("arrived", false)):
		position = HotelLayout.room_spot(room, _rng)
		state = S.ROOM
		_think = _rng.randf_range(1.0, 8.0)
	else:
		visible = false
		state = S.AWAY


func type_def() -> Dictionary:
	return GuestTypes.get_type(type_id)


func lines() -> Array:
	return GuestTypes.lines_for(type_id)


func is_busy() -> bool:
	return state in [S.BRAWL, S.FLAIL, S.BATTLE, S.CHECKOUT, S.LEAVE, S.CHECKIN, S.ARRIVE]


func is_present() -> bool:
	return visible and state != S.AWAY


func in_room() -> bool:
	return state in [S.ROOM, S.SLEEP, S.PARTY]


# --- Commands from the world -------------------------------------------------------------------

func arrive(delay: float) -> void:
	visible = true
	position = Vector2(HotelLayout.STREET_X - member * 30.0, HotelLayout.GROUND_Y)
	state = S.ARRIVE
	_timer = delay
	avatar.hold_item("suitcase" if member % 2 == 0 else "")


func check_out() -> void:
	_leave_spots()
	state = S.CHECKOUT
	avatar.set_pose(VendorAvatar.Pose.IDLE)
	avatar.hold_item("suitcase" if member % 2 == 0 else "")
	go_to(Vector2(HotelLayout.DESK_X - 20.0 - member * 26.0, HotelLayout.GROUND_Y))


func send_to_room() -> void:
	_leave_spots()
	avatar.set_pose(VendorAvatar.Pose.IDLE)
	state = S.TO_ROOM
	go_to(HotelLayout.room_spot(room, _rng))


func calm_down() -> void:
	# After a fight, rave or rescue: sulk back to the room (drunk ones sober up a bit).
	incident = null
	drunk = maxf(drunk - 1.5, 0.0)
	send_to_room()


# --- Brain -------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_timer -= delta
	_think -= delta
	match state:
		S.AWAY:
			if _is_out and _timer <= 0.0:
				_is_out = false
				come_back()
		S.ARRIVE:
			if _timer > 0.0:
				return
			if not moving and path.is_empty():
				go_to(Vector2(HotelLayout.DESK_X - 20.0 - member * 26.0, HotelLayout.GROUND_Y))
			elif step_path(delta):
				state = S.CHECKIN
				_timer = 1.4
				face(Vector2(HotelLayout.DESK_X + 60, 0))
				if leader:
					say(Lines.pick(lines(), _rng), "normal", 1.6)
		S.CHECKIN:
			if _timer <= 0.0:
				world.guest_checked_in(self)
				avatar.hold_item("")
				send_to_room()
		S.TO_ROOM:
			if step_path(delta):
				state = S.ROOM
				_think = _rng.randf_range(2.0, 6.0)
		S.ROOM:
			if _think <= 0.0:
				_decide()
		S.SLEEP:
			if _think <= 0.0 and world.hour() >= 8.5 and world.hour() < 22.0:
				avatar.set_pose(VendorAvatar.Pose.IDLE)
				position = HotelLayout.room_spot(room, _rng)
				state = S.ROOM
				_think = _rng.randf_range(1.0, 5.0)
		S.TO_POOL:
			if step_path(delta):
				_arrive_pool()
		S.LOUNGE, S.SWIM:
			if state == S.SWIM and not moving and _rng.randf() < delta * 0.4:
				walk_to(HotelLayout.swim_spot(_rng))
			if state == S.SWIM:
				step_move(delta, 30.0)
				avatar.set_pose(VendorAvatar.Pose.SWIM)
				world.pool_risk_tick(self, delta)
			if _think <= 0.0:
				if state == S.LOUNGE and _rng.randf() < 0.35:
					# Off for a dip. The towel stays on the lounger, obviously.
					state = S.SWIM
					position = HotelLayout.swim_spot(_rng)
					avatar.set_pose(VendorAvatar.Pose.SWIM)
					_think = _rng.randf_range(6.0, 14.0)
					world.guest_at_pool(self, true)
				else:
					_decide()
		S.TO_BAR:
			if step_path(delta):
				state = S.DRINK
				face(Vector2(HotelLayout.BAR_COUNTER_X, 0))
				_pint_timer = _rng.randf_range(1.0, 4.0)
				_think = _rng.randf_range(12.0, 30.0)
		S.DRINK:
			_pint_timer -= delta
			if _pint_timer <= 0.0:
				_pint_timer = _rng.randf_range(6.0, 12.0) / maxf(Economy.thirst() * RandomEvents.mult("bar"), 0.3)
				world.serve_pint(self)
			world.bar_trouble_tick(self, delta)
			if _think <= 0.0:
				_decide()
		S.OUT:
			if step_path(delta):
				visible = false
				state = S.AWAY
				_is_out = true
				_timer = _rng.randf_range(15.0, 40.0)
				world.guest_went_out(self)
		S.PARTY:
			if _rng.randf() < delta * 0.25:
				say(Lines.pick(Lines.DRUNK, _rng), "shout", 1.4)
		S.BRAWL, S.FLAIL, S.BATTLE:
			pass
		S.CHECKOUT:
			if step_path(delta):
				world.guest_checked_out(self)
				state = S.LEAVE
				go_to(Vector2(HotelLayout.STREET_X - 40.0, HotelLayout.GROUND_Y))
		S.LEAVE:
			if step_path(delta):
				world.guest_left(self)


## Coming back from the beach / town.
func come_back() -> void:
	visible = true
	position = Vector2(HotelLayout.SEA_X if _rng.randf() < 0.5 else HotelLayout.STREET_X, HotelLayout.GROUND_Y)
	send_to_room()


func _decide() -> void:
	var h: float = world.hour()
	var t := type_def()
	if h >= 23.5 or (h >= 22.0 and drunk < 1.0):
		# Bedtime... or party time.
		if in_room() and drunk >= 2.0 and not child and world.maybe_rave(self):
			return
		if state == S.ROOM:
			_go_sleep()
		elif not in_room():
			send_to_room()
		else:
			_go_sleep()
		return
	if h < 9.5:
		_think = _rng.randf_range(3.0, 8.0)
		return
	var weights := {"room": 0.35}
	if h < 19.0:
		weights["pool"] = float(t.pool) * Upgrades.pool_appeal() * RandomEvents.mult("pool") * 1.4
		weights["out"] = 0.6
	else:
		if not child:
			weights["bar"] = float(t.drinks) * Upgrades.bar_appeal() * Economy.thirst() * RandomEvents.mult("bar") * 1.6
		weights["out"] = 0.25
		if drunk >= 2.0 and Upgrades.level("fence") == 0:
			weights["pool"] = 0.4  # a drunken night swim. What could go wrong?
	match GuestTypes.weighted_pick(weights, _rng):
		"pool":
			go_pool()
		"bar":
			_leave_spots()
			stool = world.claim_stool(self)
			if stool < 0:
				_think = _rng.randf_range(4.0, 8.0)
				return
			state = S.TO_BAR
			avatar.set_pose(VendorAvatar.Pose.IDLE)
			go_to(HotelLayout.stool(stool))
		"out":
			_leave_spots()
			state = S.OUT
			avatar.set_pose(VendorAvatar.Pose.IDLE)
			go_to(Vector2(HotelLayout.SEA_X + 20.0, HotelLayout.GROUND_Y) if h < 19.0 else Vector2(HotelLayout.STREET_X - 40.0, HotelLayout.GROUND_Y))
		_:
			if state != S.ROOM:
				send_to_room()
			else:
				walk_to(HotelLayout.room_spot(room, _rng))
				_think = _rng.randf_range(6.0, 14.0)


## Head for the pool, bagging a sunlounger if there's one left.
func go_pool() -> void:
	_leave_spots()
	state = S.TO_POOL
	avatar.set_pose(VendorAvatar.Pose.IDLE)
	lounger = world.claim_lounger(self)
	if lounger >= 0:
		go_to(HotelLayout.lounger(lounger))
	else:
		go_to(HotelLayout.swim_spot(_rng))


func _arrive_pool() -> void:
	if lounger >= 0:
		state = S.LOUNGE
		position = HotelLayout.lounger(lounger) + Vector2(-50, -12)
		avatar.set_pose(VendorAvatar.Pose.LIE)
		_think = _rng.randf_range(12.0, 30.0)
		world.guest_at_pool(self, false)
	else:
		state = S.SWIM
		avatar.set_pose(VendorAvatar.Pose.SWIM)
		_think = _rng.randf_range(8.0, 20.0)
		world.guest_at_pool(self, true)


func _go_sleep() -> void:
	_leave_spots()
	state = S.SLEEP
	position = HotelLayout.bed_spot(room) + Vector2(-50, 0)
	avatar.set_pose(VendorAvatar.Pose.LIE)
	avatar.hold_item("")
	_think = _rng.randf_range(4.0, 10.0)


func _leave_spots() -> void:
	if lounger >= 0:
		world.release_lounger(lounger)
		lounger = -1
	if stool >= 0:
		world.release_stool(stool)
		stool = -1
	if avatar and avatar.pose == VendorAvatar.Pose.LIE:
		avatar.set_pose(VendorAvatar.Pose.IDLE)
		if state == S.LOUNGE:
			position += Vector2(50, 12)  # undo the lounging offset
	if state == S.SWIM:
		avatar.set_pose(VendorAvatar.Pose.IDLE)
