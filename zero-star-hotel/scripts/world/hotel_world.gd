extends Node2D
## The hotel scene: builds the cut-away building and pool, runs the day (bookings, check-outs,
## the bar, the night), referees every incident (raves, fights, vandalism, theft, pool
## emergencies, sunlounger wars, cockroaches), keeps guests' happiness ticking, sends round
## the inspector, and turns taps into actions.

const HudScene := preload("res://scenes/ui/hud.tscn")
const DaySummary := preload("res://scripts/ui/day_summary.gd")
const RoomPanel := preload("res://scripts/ui/room_panel.gd")

var camera: CameraRig
var tint: CanvasModulate
var fx: FxLayer
var hud: CanvasLayer
var actors: Node2D
var incidents_layer: Node2D
var roach_layer: Node2D
var room_views: Array[RoomView] = []
var manager: Helper
var staff_nodes: Array[Helper] = []
var guests: Array[Guest] = []
var incidents: Array[Incident] = []
var roaches := {}               # room index -> Array[Cockroach]
var loungers := {}              # index -> Guest
var stools := {}                # index -> Guest
var inspector: Visitor
var reviews_today: Array = []
var _claims := {}               # "clean:3" -> Helper
var _booking_timer := 4.0
var _hour_mark := 0
var _thief_timer := 30.0
var _checkouts_done := false
var _inspector_sent := false
var _rave_player: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	name = "HotelWorld"
	_build()
	GameManager.day_ended.connect(_on_day_ended)
	GameManager.phase_changed.connect(_on_phase)
	RandomEvents.event_started.connect(_on_event)
	Hotel.rooms_changed.connect(_sync_roaches)
	Hotel.review_added.connect(func(r): reviews_today.append(r))
	Staff.staff_changed.connect(_sync_staff)
	Upgrades.upgrade_purchased.connect(_on_upgrade)
	GameManager.start_day()
	_hour_mark = int(GameManager.hour)
	_spawn_existing_guests()
	_sync_staff()
	_sync_roaches()
	AudioManager.play_music("day")
	if GameManager.first_day_hints:
		GameManager.notify(Lines.TUTORIAL.start % Hotel.name_of_hotel, "tutorial")
		get_tree().create_timer(6.0).timeout.connect(func(): GameManager.notify(Lines.TUTORIAL.stars, "tutorial"))
	else:
		GameManager.notify("Day %d at %s. %s" % [GameManager.day, Hotel.name_of_hotel, Lines.STAR_TITLES[Hotel.stars]], "info")
	if Hotel.inspector_visiting():
		GameManager.notify("The star inspector arrives at NOON. Clean every room and squash every cockroach!", "warning")


func _build() -> void:
	var back := BuildingView.new()
	add_child(back)
	for i in Hotel.ROOMS:
		var rv := RoomView.new()
		rv.index = i
		add_child(rv)
		room_views.append(rv)
	var pool := PoolView.new()
	add_child(pool)
	roach_layer = Node2D.new()
	add_child(roach_layer)
	actors = Node2D.new()
	actors.name = "Actors"
	add_child(actors)
	var front := BuildingView.new()
	front.front_layer = true
	add_child(front)
	var water := PoolView.new()
	water.front_layer = true
	add_child(water)
	incidents_layer = Node2D.new()
	add_child(incidents_layer)
	fx = FxLayer.new()
	add_child(fx)
	tint = CanvasModulate.new()
	add_child(tint)
	camera = CameraRig.new()
	camera.world_rect = Rect2(-200, -260, HotelLayout.WORLD_W + 260, HotelLayout.WORLD_H + 280)
	add_child(camera)
	camera.position = Vector2(820, 540)
	camera.zoom = Vector2(0.62, 0.62)
	camera._apply_limits()
	camera.tapped.connect(_on_tapped)
	manager = Helper.new()
	actors.add_child(manager)
	manager.setup(self, "manager", {}, {}, Vector2(HotelLayout.DESK_X + 90.0, HotelLayout.GROUND_Y))
	_rave_player = AudioStreamPlayer.new()
	_rave_player.bus = "SFX"
	_rave_player.volume_db = -14.0
	add_child(_rave_player)
	hud = HudScene.instantiate()
	hud.world = self
	add_child(hud)


func hour() -> float:
	return GameManager.hour


func is_on_screen(p: Vector2) -> bool:
	var half := get_viewport_rect().size / camera.zoom * 0.5
	return Rect2(camera.position - half, half * 2.0).grow(80.0).has_point(p)


# --- The day -----------------------------------------------------------------------------------

func _process(delta: float) -> void:
	var h := hour()
	_apply_tint(h)
	if not GameManager.day_running:
		return
	# Check-outs from 10:00.
	if not _checkouts_done and h >= 10.0:
		_checkouts_done = true
		_start_checkouts()
	# Bookings arrive through the afternoon.
	if h >= 14.0 and h < 19.5:
		_booking_timer -= delta * RandomEvents.mult("arrivals")
		if _booking_timer <= 0.0:
			_booking_timer = _rng.randf_range(12.0, 20.0)
			for i in 2:
				var g := Hotel.try_booking()
				if not g.is_empty():
					_spawn_group(g, true)
	# The inspector arrives at noon on inspection day: the morning is for tidying up.
	if Hotel.inspector_visiting() and not _inspector_sent and h >= 12.0:
		_inspector_sent = true
		_send_inspector()
	# Thieves try their luck in the afternoon and the small hours.
	if (h >= 13.0 and h < 18.0) or h >= 23.0:
		_thief_timer -= delta
		if _thief_timer <= 0.0:
			_thief_timer = _rng.randf_range(40.0, 80.0) / Upgrades.theft_mult()
			_maybe_thief()
	# Every in-game hour: happiness drifts.
	if int(h) != _hour_mark:
		_hour_mark = int(h)
		_hourly_mood()
	# Rave noise.
	var raves := incidents.filter(func(i): return i.kind == "music").size()
	if raves > 0 and not _rave_player.playing and AudioManager.sfx.has("bass"):
		_rave_player.stream = AudioManager.sfx["bass"]
		_rave_player.play()
	elif raves == 0 and _rave_player.playing:
		_rave_player.stop()


func _on_phase(phase: String) -> void:
	match phase:
		"Happy hour":
			AudioManager.play_music("night")
			GameManager.notify("Happy hour! The bar is open. %s" % Economy.PINT_PRICES[Economy.pint_price_index].name, "info")
		"Night out":
			GameManager.notify("Night falls. Brace yourself.", "warning")
		"Check-in":
			if GameManager.first_day_hints:
				GameManager.notify("Guests arrive from 14:00. Tap rooms to see how they are.", "tutorial")
				GameManager.notify(Lines.TUTORIAL.rooms, "tutorial")


func _apply_tint(h: float) -> void:
	var c := Color.WHITE
	if h < 9.5:
		c = Color(1.0, 0.95, 0.88).lerp(Color.WHITE, (h - 8.0) / 1.5)
	elif h > 18.5:
		c = Color.WHITE.lerp(Color(1.0, 0.8, 0.65), clampf((h - 18.5) / 2.0, 0.0, 1.0))
		if h > 20.5:
			c = c.lerp(Color(0.62, 0.64, 0.86), clampf((h - 20.5) / 1.5, 0.0, 1.0))
	tint.color = c


func _start_checkouts() -> void:
	for g in Hotel.groups.duplicate():
		if int(g.nights) > 0 or not bool(g.get("arrived", false)):
			continue
		for guest in guests.filter(func(x): return x.group_id == int(g.id)):
			if guest.state == Guest.S.AWAY:
				guest.come_back()
			_end_involvement(guest)
			guest.check_out()


func _spawn_existing_guests() -> void:
	for g in Hotel.groups:
		_spawn_group(g, not bool(g.get("arrived", false)))


func _spawn_group(g: Dictionary, arriving: bool) -> void:
	for m in int(g.size):
		var guest := Guest.new()
		actors.add_child(guest)
		guest.setup(self, g, m)
		guests.append(guest)
		if arriving:
			guest.arrive(m * 0.7 + _rng.randf_range(0.0, 1.5))


func guest_checked_in(guest: Guest) -> void:
	if guest.leader:
		Hotel.on_check_in(guest.group_id)
		AudioManager.play_sfx("click")
		var room: Dictionary = Hotel.rooms[guest.room]
		if float(room.dirt) > 50.0:
			guest.say(Lines.pick(Lines.UNHAPPY, _rng), "bad", 1.8)


func guest_checked_out(guest: Guest) -> void:
	if not guest.leader:
		return
	var review := Hotel.check_out(guest.group_id)
	if review.is_empty():
		return
	var n := int(review.stars)
	guest.say("%d/5: %s" % [n, review.text], "sale" if n >= 4 else ("normal" if n == 3 else "bad"), 3.5)
	fx.float_text(guest.position + Vector2(0, -170), "%d/5 review" % n, Color("#ffd23f") if n >= 3 else Color("#ff8a80"), 24)


func guest_left(guest: Guest) -> void:
	guests.erase(guest)
	guest.queue_free()


func guest_went_out(_guest: Guest) -> void:
	pass


func guest_at_pool(guest: Guest, swimming: bool) -> void:
	if not swimming:
		return
	if Upgrades.level("pool") == 0 and _rng.randf() < 0.4:
		guest.say("Something touched my leg!", "bad", 1.6)
	# Sunlounger war: a mum without a lounger eyes up one already taken.
	if guest.type_id == "mums" and Upgrades.lounger_count() <= loungers.size():
		for other: Guest in loungers.values():
			if other.type_id == "mums" and other.group_id != guest.group_id and not other.is_busy():
				_start_lounger_war(guest, other)
				return


# --- Seats --------------------------------------------------------------------------------------

func claim_lounger(guest: Guest) -> int:
	for i in Upgrades.lounger_count():
		if not loungers.has(i):
			loungers[i] = guest
			return i
	return -1


func release_lounger(i: int) -> void:
	loungers.erase(i)


func claim_stool(guest: Guest) -> int:
	for i in 7:
		if not stools.has(i):
			stools[i] = guest
			return i
	return -1


func release_stool(i: int) -> void:
	stools.erase(i)


func barman_on() -> bool:
	return staff_nodes.any(func(s): return s.role == "barman")


func serve_pint(guest: Guest) -> void:
	if Upgrades.level("bar") >= 1 and not barman_on() and _rng.randf() < 0.5:
		if _rng.randf() < 0.3:
			guest.say("Is anyone behind this bar?!", "normal", 1.4)
		return
	var price := Economy.sell_pint()
	guest.drunk += 1.0
	guest.avatar.hold_item("cocktail" if Upgrades.level("bar") >= 2 and guest.type_id in ["hens", "couples", "mums"] else ("wine" if guest.type_id == "mums" else "pint"))
	if is_on_screen(guest.position):
		fx.float_text(guest.position + Vector2(0, -130), "+" + Lines.money(price), Color("#ffe14d"), 18)
		if _rng.randf() < 0.25:
			guest.say(Lines.pick(Lines.DRUNK if guest.drunk >= 3.0 else guest.lines(), _rng), "shout", 1.4)
			if guest.type_id == "lads" and _rng.randf() < 0.5:
				AudioManager.say("oi_oi" if _rng.randf() < 0.6 else "ere_we_go", float(guest.avatar.appearance.get("voice_pitch", 1.0)), "guest%d" % guest.group_id, -6.0)
			elif guest.type_id == "hens":
				AudioManager.say("woo", float(guest.avatar.appearance.get("voice_pitch", 1.2)) + 0.3, "guest%d" % guest.group_id, -6.0)


# --- Incident triggers (called by guests) --------------------------------------------------------

func bar_trouble_tick(guest: Guest, delta: float) -> void:
	if guest.drunk < 3.0 or guest.is_busy():
		return
	var p := 0.012 * float(guest.type_def().trouble) * Upgrades.fight_mult() * RandomEvents.mult("fights") * RandomEvents.mult("trouble")
	if _rng.randf() > p * delta * 10.0:
		return
	# Pick a fight with someone else at the bar.
	for other: Guest in stools.values():
		if other != guest and not other.is_busy() and other.drunk >= 1.0:
			_start_incident("fight", guest.position, [guest, other])
			return


func pool_risk_tick(guest: Guest, delta: float) -> void:
	if guest.is_busy():
		return
	var risk := 0.0
	if guest.child:
		risk = 0.004
	if guest.drunk >= 2.0:
		risk = 0.012 + 0.004 * guest.drunk
	if risk <= 0.0:
		return
	risk *= Upgrades.pool_risk_mult() * RandomEvents.mult("pool_risk")
	if _rng.randf() > risk * delta * 10.0:
		return
	# A lifeguard on duty stops most of it before it starts.
	if staff_nodes.any(func(s): return s.role == "lifeguard") and _rng.randf() < 0.75:
		guest.say("Lifeguard: \"Oi! Walk, don't belly-flop!\"", "normal", 1.6)
		return
	_start_incident("pool", guest.position, [guest])


func maybe_rave(guest: Guest) -> bool:
	if incidents.any(func(i): return i.kind == "music" and i.room == guest.room):
		return false
	var p := 0.45 * float(guest.type_def().trouble) * Upgrades.rave_mult() * RandomEvents.mult("raves") * minf(guest.drunk / 3.0, 1.5)
	if _rng.randf() > p:
		return false
	_start_incident("music", HotelLayout.room_door(guest.room), [], guest.room)
	return true


func _maybe_thief() -> void:
	var targets := []
	for i in Hotel.ROOMS:
		var r: Dictionary = Hotel.rooms[i]
		if r.open and int(r.group) >= 0 and not guests.any(func(g): return g.room == i and g.in_room()):
			targets.append(i)
	if targets.is_empty() or _rng.randf() > 0.6:
		return
	var thief := Visitor.new()
	actors.add_child(thief)
	thief.setup_thief(self, targets[_rng.randi() % targets.size()])
	var inc := _start_incident("theft", thief.position, [])
	inc.thief = thief
	thief.incident = inc


func _start_lounger_war(a: Guest, b: Guest) -> void:
	_start_incident("lounger", b.position, [a, b])


func _start_incident(kind: String, at: Vector2, involved: Array, room := -1) -> Incident:
	var inc := Incident.new()
	inc.setup(self, kind, at)
	inc.room = room
	inc.guests = involved
	incidents_layer.add_child(inc)
	incidents.append(inc)
	for g: Guest in involved:
		g.incident = inc
		match kind:
			"fight":
				g.state = Guest.S.BRAWL
				g.avatar.set_pose(VendorAvatar.Pose.CHEER)
				g.say(Lines.pick(["Wanna go?!", "Come on then!", "You spilt my pint!", "Say that again!"], _rng), "bad", 1.6)
			"pool":
				g.state = Guest.S.FLAIL
				g.avatar.shout(9.0)
				g.say("HELP! *glub glub*", "bad", 2.0)
			"lounger":
				g.state = Guest.S.BATTLE
				g.stop()
				g.avatar.set_pose(VendorAvatar.Pose.IDLE)
				g.avatar.hold_item("towel")
				g.avatar.shout(9.0)
				g.say("That's MY lounger!", "bad", 1.6)
	if kind == "music":
		room_views[room].set_party(true)
		for g in guests:
			if g.room == room and g.in_room():
				g.state = Guest.S.PARTY
				g.avatar.set_pose(VendorAvatar.Pose.CHEER)
				g.avatar.hold_item("speaker" if g.member == 0 else "pint")
	var label: String = Lines.pick(Lines.INCIDENT_TEXT[kind], _rng)
	if label.contains("%s"):
		label = label % Hotel.room_label(maxi(room, 0))
	GameManager.notify(label, "warning")
	AudioManager.play_sfx("punch" if kind == "fight" else ("splash" if kind == "pool" else "click"), 0.1, -4.0)
	if GameManager.first_day_hints and incidents.size() == 1:
		GameManager.notify(Lines.TUTORIAL.incident, "tutorial")
	if kind == "fight":
		_brawl_fx(inc.get_instance_id())
	if kind == "music":
		_maybe_escalate(inc.get_instance_id())
	return inc


## Timers carry the incident's id, not the node: it may be gone by the time they fire.
func _live_incident(id: int) -> Incident:
	var inc := instance_from_id(id) as Incident
	if inc == null or not is_instance_valid(inc) or inc.done or inc.is_queued_for_deletion():
		return null
	return inc


func _release_claim(key: String) -> void:
	_claims.erase(key)


func _brawl_fx(id: int) -> void:
	# Cartoon dust cloud and punches while the fight lasts.
	var inc := _live_incident(id)
	if inc == null:
		return
	fx.puff(inc.anchor + Vector2(0, -40), 5, Color(0.9, 0.85, 0.7, 0.8))
	if is_on_screen(inc.anchor) and _rng.randf() < 0.6:
		AudioManager.play_sfx("punch", 0.2, -8.0)
	get_tree().create_timer(0.6).timeout.connect(_brawl_fx.bind(id))


func _maybe_escalate(id: int) -> void:
	# A long rave with very drunk lads can turn into a smashed-up room.
	var rave := _live_incident(id)
	if rave == null:
		return
	if rave.fuse < rave.max_fuse - 8.0:
		var partiers := guests.filter(func(g): return g.room == rave.room and g.state == Guest.S.PARTY)
		var worst := 0.0
		var trouble := 0.0
		for g: Guest in partiers:
			worst = maxf(worst, g.drunk)
			trouble = maxf(trouble, float(g.type_def().trouble))
		if worst >= 3.5 and trouble >= 0.6 and _rng.randf() < 0.35 and not incidents.any(func(i): return i.kind == "vandal" and i.room == rave.room):
			var inc := _start_incident("vandal", HotelLayout.room_door(rave.room), [], rave.room)
			AudioManager.play_sfx("smash", 0.1, -6.0)
			inc.guests = partiers
			return
	get_tree().create_timer(3.0).timeout.connect(_maybe_escalate.bind(id))


# --- Resolving incidents -------------------------------------------------------------------------

## Tap on an incident: the manager heads over.
func dispatch_manager(inc: Incident) -> void:
	if inc.done:
		return
	if inc.claimed_by and inc.claimed_by != manager:
		GameManager.notify("%s is already on it." % _helper_name(inc.claimed_by), "info")
		return
	var job := _incident_job(inc, manager)
	if manager.enqueue(job):
		inc.claimed_by = manager
		AudioManager.play_sfx("tap")


func _incident_job(inc: Incident, helper: Helper) -> Dictionary:
	var job := {"key": "inc%d" % inc.get_instance_id(), "spot": inc.work_spot(), "time": inc.work_time(),
		"incident": inc, "on_done": resolve_incident.bind(inc, helper)}
	match inc.kind:
		"theft":
			job.follow = inc.thief
			job.line = "Oi! Stop, thief!"
		"music", "vandal":
			job.line = "*knock knock* Turn it DOWN!"
		"fight":
			job.line = "Break it up!"
		"pool":
			job.line = "Grab the ring!"
		"lounger":
			job.line = "Ladies, ladies!"
	return job


func resolve_incident(inc: Incident, helper: Helper) -> void:
	if inc.done:
		return
	inc.done = true
	incidents.erase(inc)
	var line: String = Lines.pick(Lines.RESOLVED[inc.kind], _rng)
	match inc.kind:
		"music":
			AudioManager.play_sfx("knock")
			_end_rave(inc.room)
			for g: Guest in guests.filter(func(x): return x.room == inc.room):
				Hotel.adjust(g.group_id, -2.0, "")
		"vandal":
			for g: Guest in inc.guests:
				if is_instance_valid(g):
					g.calm_down()
		"fight":
			for g: Guest in inc.guests:
				if is_instance_valid(g):
					Hotel.adjust(g.group_id, -4.0, "fight")
					g.calm_down()
		"pool":
			AudioManager.play_sfx("splash")
			for g: Guest in inc.guests:
				if is_instance_valid(g):
					g.say("Thanks! *cough*", "normal", 1.6)
					g.calm_down()
			fx.hearts(inc.anchor)
		"lounger":
			for g: Guest in inc.guests:
				if is_instance_valid(g):
					g.incident = null
					g.avatar.hold_item("")
					g.calm_down()
		"theft":
			if inc.thief and is_instance_valid(inc.thief):
				inc.thief.flee(true)
	fx.float_text(inc.anchor + Vector2(0, -170), "Sorted!", Color("#b9f6a0"), 24)
	helper.say(line, "sale", 1.6)
	AudioManager.play_sfx("upgrade", 0.05, -8.0)
	inc.queue_free()


func incident_failed(inc: Incident) -> void:
	incidents.erase(inc)
	var text: String = Lines.FAILED.get(inc.kind, "That went badly.")
	if text.contains("%s"):
		text = text % Hotel.room_label(maxi(inc.room, 0))
	match inc.kind:
		"music":
			for i in _noise_rooms(inc.room):
				for g in Hotel.groups.filter(func(x): return int(x.room) == i):
					Hotel.adjust(int(g.id), -12.0, "noise")
			Hotel.rooms[inc.room].dirt = minf(float(Hotel.rooms[inc.room].dirt) + 25.0, 100.0)
			_end_rave(inc.room)
			Hotel.add_strike("a rave in room %s" % Hotel.room_label(inc.room))
		"vandal":
			Hotel.damage_room(inc.room, 1 + _rng.randi() % 2)
			AudioManager.play_sfx("smash")
			if Upgrades.level("deposit") > 0:
				Economy.earn(Hotel.repair_cost(inc.room), "deposits")
				text += " (Deposit kept: %s)" % Lines.money(Hotel.repair_cost(inc.room))
			for g: Guest in inc.guests:
				if is_instance_valid(g):
					g.calm_down()
			Hotel.add_strike("room %s getting smashed up" % Hotel.room_label(inc.room))
		"fight":
			Economy.force_spend(40.0, "repairs")
			for g: Guest in stools.values():
				Hotel.adjust(g.group_id, -6.0, "fight")
			for g: Guest in inc.guests:
				if is_instance_valid(g):
					Hotel.adjust(g.group_id, -8.0, "fight")
					g.calm_down()
			Hotel.add_strike("a brawl")
		"pool":
			Economy.force_spend(80.0, "fines")
			for g: Guest in inc.guests:
				if is_instance_valid(g):
					Hotel.adjust(g.group_id, -30.0, "pool")
					g.say("Never. Again. *cough*", "bad", 2.0)
					g.calm_down()
			AudioManager.play_sfx("siren" if AudioManager.sfx.has("siren") else "bad_event")
			Hotel.add_strike("paramedics at the pool")
		"lounger":
			for g: Guest in inc.guests:
				if is_instance_valid(g):
					Hotel.adjust(g.group_id, -14.0, "lounger")
					g.avatar.hold_item("")
					g.calm_down()
			Hotel.add_strike("a sunlounger war")
		"theft":
			if inc.thief and is_instance_valid(inc.thief) and inc.thief.state != Visitor.S.FLEE:
				thief_steals(inc.thief)
	GameManager.notify(text, "bad")
	AudioManager.play_sfx("bad_event", 0.0, -6.0)
	inc.queue_free()


func thief_steals(thief: Visitor) -> void:
	if thief.state == Visitor.S.FLEE:
		return
	var room: Dictionary = Hotel.rooms[thief.target_room]
	if Upgrades.level("safes") > 0:
		thief.say("A safe?! Curses!", "bad", 1.6)
		thief.flee(true)
	else:
		if int(room.group) >= 0:
			Hotel.adjust(int(room.group), -30.0, "theft")
		Economy.force_spend(20.0, "theft")
		GameManager.notify("Room %s got robbed! You compensate the guests (%s)." % [Hotel.room_label(thief.target_room), Lines.money(20)], "bad")
		thief.flee(false)
		Hotel.add_strike("a burglary")
	if thief.incident and is_instance_valid(thief.incident) and not thief.incident.done:
		thief.incident.done = true
		incidents.erase(thief.incident)
		thief.incident.queue_free()


func _end_rave(room: int) -> void:
	room_views[room].set_party(false)
	for g in guests:
		if g.room == room and g.state == Guest.S.PARTY:
			g.calm_down()


func _noise_rooms(room: int) -> Array:
	var out := []
	var spread := Upgrades.noise_spread()
	for i in Hotel.ROOMS:
		if i != room and Hotel.floor_of(i) == Hotel.floor_of(room) and absi(i - room) <= spread:
			out.append(i)
	# Rooms directly above and below hear it too without soundproofing.
	if spread >= 2:
		for d in [-4, 4]:
			if room + d >= 0 and room + d < Hotel.ROOMS:
				out.append(room + d)
	return out


func _end_involvement(guest: Guest) -> void:
	if guest.incident and is_instance_valid(guest.incident):
		guest.incident.guests.erase(guest)
	guest.incident = null


func _helper_name(h: Node) -> String:
	if h == manager:
		return "You"
	return str((h as Helper).data.get("name", "Staff"))


# --- Staff jobs ---------------------------------------------------------------------------------

func _sync_staff() -> void:
	var have := {}
	for n in staff_nodes:
		have[int(n.data.id)] = n
	for s in Staff.staff:
		if not have.has(int(s.id)):
			var h := Helper.new()
			actors.add_child(h)
			h.setup(self, str(s.role), s, Staff.appearance(s), _staff_home(str(s.role), staff_nodes.size()))
			h.position = Vector2(HotelLayout.STREET_X + 40.0, HotelLayout.GROUND_Y) if GameManager.hour > 8.2 else h.home
			staff_nodes.append(h)
		have.erase(int(s.id))
	for id in have:
		var n: Helper = have[id]
		n.cancel_job()
		staff_nodes.erase(n)
		n.queue_free()


func _staff_home(role: String, k: int) -> Vector2:
	match role:
		"security": return Vector2(HotelLayout.STAIR_X0 + 90.0, HotelLayout.GROUND_Y)
		"lifeguard": return Vector2(HotelLayout.LIFEGUARD_X + 30.0, HotelLayout.GROUND_Y)
		"barman": return Vector2(HotelLayout.BAR_COUNTER_X + 30.0, HotelLayout.GROUND_Y)
	return Vector2(HotelLayout.DESK_X + 130.0 + k * 18.0, HotelLayout.GROUND_Y)


func find_job(h: Helper) -> Dictionary:
	match h.role:
		"cleaner":
			var best := -1
			var best_score := 0.0
			for i in Hotel.ROOMS:
				var r: Dictionary = Hotel.rooms[i]
				if not r.open or _claims.has("room:%d" % i):
					continue
				var score := float(r.dirt) + 25.0 * int(r.roaches)
				if guests.any(func(g): return g.room == i and g.state in [Guest.S.SLEEP, Guest.S.PARTY]):
					continue
				if score > 40.0 and score > best_score:
					best_score = score
					best = i
			if best >= 0:
				_claims["room:%d" % best] = h
				return {"spot": HotelLayout.room_spot(best, _rng), "time": 3.5, "line": Lines.pick(Lines.CLEANER, _rng),
					"on_done": _cleaned.bind(best, h), "release": _release_claim.bind("room:%d" % best)}
		"handyman":
			for i in Hotel.ROOMS:
				var r: Dictionary = Hotel.rooms[i]
				if r.open and int(r.damage) > 0 and not _claims.has("fix:%d" % i):
					_claims["fix:%d" % i] = h
					return {"spot": HotelLayout.room_spot(i, _rng), "time": 5.0, "line": Lines.pick(Lines.HANDYMAN, _rng),
						"on_done": _repaired.bind(i, h, true), "release": _release_claim.bind("fix:%d" % i)}
		"security":
			for inc in incidents:
				if inc.claimed_by == null and inc.kind in ["fight", "music", "vandal", "theft", "lounger"]:
					inc.claimed_by = h
					var j := _incident_job(inc, h)
					j.line = Lines.pick(Lines.SECURITY, _rng)
					return j
		"lifeguard":
			for inc in incidents:
				if inc.claimed_by == null and inc.kind == "pool":
					inc.claimed_by = h
					var j := _incident_job(inc, h)
					j.line = "NOBODY drowns on my watch!"
					return j
	return {}


func _cleaned(i: int, h: Helper) -> void:
	_claims.erase("room:%d" % i)
	Hotel.clean(i)
	var n := int(Hotel.rooms[i].roaches)
	if n > 0:
		for k in n:
			Hotel.squash_roach(i)
		fx.puff(HotelLayout.room_spot(i, _rng) + Vector2(0, -10), 6, Color(0.5, 0.35, 0.2, 0.7))
		AudioManager.play_sfx("splat", 0.2, -6.0)
	if is_instance_valid(h):
		h.say("Spotless. For now.", "sale", 1.4)


func _repaired(i: int, h: Helper, staff_rate: bool) -> void:
	_claims.erase("fix:%d" % i)
	var cost := Hotel.repair_cost(i) * (0.5 if staff_rate else 1.0)
	Economy.force_spend(cost, "repairs")
	Hotel.repair(i)
	if is_instance_valid(h):
		h.say("Sorted. %s in parts." % Lines.money(cost), "sale", 1.6)


## Room panel buttons: the manager does it personally.
func manager_clean(i: int) -> void:
	if manager.enqueue({"key": "clean%d" % i, "spot": HotelLayout.room_spot(i, _rng), "time": 5.0, "line": "Fine, I'll do it myself.",
			"on_done": _cleaned.bind(i, manager)}):
		AudioManager.play_sfx("tap")


func manager_repair(i: int) -> void:
	if manager.enqueue({"key": "fix%d" % i, "spot": HotelLayout.room_spot(i, _rng), "time": 6.0, "line": "Where's the gaffer tape?",
			"on_done": _repaired.bind(i, manager, false)}):
		AudioManager.play_sfx("tap")


# --- Cockroaches --------------------------------------------------------------------------------

func _sync_roaches() -> void:
	for i in Hotel.ROOMS:
		var want := int(Hotel.rooms[i].roaches) if Hotel.rooms[i].open else 0
		var have: Array = roaches.get(i, [])
		while have.size() < want:
			var c := Cockroach.new()
			roach_layer.add_child(c)
			c.setup(i)
			have.append(c)
		while have.size() > want:
			var c: Cockroach = have.pop_back()
			c.queue_free()
		roaches[i] = have


func squash(c: Cockroach) -> void:
	fx.puff(c.position, 4, Color(0.45, 0.3, 0.15, 0.85))
	fx.float_text(c.position + Vector2(0, -30), "SPLAT!", Color("#ffd23f"), 20)
	AudioManager.play_sfx("splat", 0.15)
	var list: Array = roaches.get(c.room, [])
	list.erase(c)
	c.queue_free()
	Hotel.squash_roach(c.room)


# --- Mood ---------------------------------------------------------------------------------------

func _hourly_mood() -> void:
	var raving := incidents.filter(func(i): return i.kind == "music")
	var noisy := {}
	for r in raving:
		for i in _noise_rooms(r.room):
			noisy[i] = true
	var mood_event := RandomEvents.add("mood")
	for g in Hotel.groups:
		if not bool(g.get("arrived", false)):
			continue
		var id := int(g.id)
		var members := guests.filter(func(x): return x.group_id == id)
		if members.is_empty():
			continue
		var room: Dictionary = Hotel.rooms[int(g.room)]
		var in_room := members.any(func(x): return x.in_room())
		if in_room and noisy.has(int(g.room)):
			Hotel.adjust(id, -5.0, "noise")
		if in_room and int(room.roaches) > 0:
			Hotel.adjust(id, -1.5 * int(room.roaches), "roaches")
			if GameManager.first_day_hints:
				GameManager.notify(Lines.TUTORIAL.roach, "tutorial")
		if members.any(func(x): return x.state == Guest.S.LOUNGE):
			Hotel.adjust(id, 2.0, "pool")
		if members.any(func(x): return x.state == Guest.S.SWIM):
			Hotel.adjust(id, 4.0 * Upgrades.pool_appeal() - 2.0, "pool")
		if members.any(func(x): return x.state == Guest.S.DRINK):
			var cheap := 1.5 if Economy.pint_price_index == 0 and g.type in ["lads", "hens"] else 0.0
			Hotel.adjust(id, 2.0 + cheap, "bar")
		if mood_event != 0.0:
			Hotel.adjust(id, mood_event * 3.0, "")
		if members.any(func(x): return x.state == Guest.S.SLEEP) and not noisy.has(int(g.room)):
			Hotel.adjust(id, 1.0, "")


# --- Inspector ----------------------------------------------------------------------------------

func _send_inspector() -> void:
	var tour := []
	tour.append({"pos": Vector2(HotelLayout.DESK_X - 30.0, HotelLayout.GROUND_Y), "check": func(): pass})
	for i in Hotel.ROOMS:
		if Hotel.rooms[i].open:
			tour.append({"pos": HotelLayout.room_spot(i, _rng), "check": _inspect_room.bind(i)})
	tour.append({"pos": Vector2(HotelLayout.BAR_X0 + 120.0, HotelLayout.GROUND_Y), "check": _inspect_area.bind(["fight"], "the bar")})
	tour.append({"pos": Vector2(HotelLayout.POOL_X0 - 40.0, HotelLayout.GROUND_Y), "check": _inspect_area.bind(["pool", "lounger"], "the pool")})
	inspector = Visitor.new()
	actors.add_child(inspector)
	inspector.setup_inspector(self, tour)
	GameManager.notify("The star inspector has arrived! Clipboard at the ready.", "warning")
	AudioManager.play_sfx("event")


func _inspect_room(i: int) -> void:
	var r: Dictionary = Hotel.rooms[i]
	if int(r.roaches) > 0:
		Hotel.add_strike("cockroaches in room %s" % Hotel.room_label(i))
	elif float(r.dirt) > 65.0:
		Hotel.add_strike("a filthy room %s" % Hotel.room_label(i))
	elif int(r.damage) > 0:
		Hotel.add_strike("a smashed-up room %s" % Hotel.room_label(i))


func _inspect_area(kinds: Array, where: String) -> void:
	if incidents.any(func(inc): return inc.kind in kinds):
		Hotel.add_strike("chaos at %s" % where)


# --- Taps ---------------------------------------------------------------------------------------

func _on_tapped(p: Vector2) -> void:
	if get_tree().paused:
		return
	for inc in incidents:
		if inc.hit_test(p):
			dispatch_manager(inc)
			return
	for i in roaches:
		for c: Cockroach in roaches[i]:
			if c.hit_test(p):
				squash(c)
				return
	for i in Hotel.ROOMS:
		if HotelLayout.room_rect(i).has_point(p):
			var panel := RoomPanel.new()
			panel.world = self
			panel.room = i
			hud.add_child(panel)
			return
	if p.y > 0 and p.y < HotelLayout.WORLD_H:
		manager.walk_somewhere(Vector2(clampf(p.x, HotelLayout.STREET_X + 60.0, HotelLayout.WORLD_W - 40.0), HotelLayout.level_y(HotelLayout.level_of(p.y)) if not HotelLayout.in_pool(p) else HotelLayout.GROUND_Y))


# --- Events -------------------------------------------------------------------------------------

func _on_event(id: String, _def: Dictionary) -> void:
	match id:
		"coach", "hens":
			var forced := 0
			for k in 2:
				var g := Hotel.try_booking()
				if not g.is_empty():
					g.type = "lads" if id == "coach" else "hens"
					_spawn_group(g, true)
					forced += 1
			if forced == 0:
				GameManager.notify("...but you've got no free rooms! They go to the hotel next door.", "info")
		"roach_plague":
			for k in 3:
				var i := _rng.randi() % Hotel.ROOMS
				if Hotel.rooms[i].open:
					Hotel.add_roaches(i, 2)
		"burst_pipe":
			var open := []
			for i in Hotel.ROOMS:
				if Hotel.rooms[i].open:
					open.append(i)
			if not open.is_empty():
				Hotel.damage_room(open[_rng.randi() % open.size()], 1)
	AudioManager.play_sfx("event" if bool(_def.get("good", true)) else "bad_event")


func _on_upgrade(_id: String, _level: int) -> void:
	AudioManager.play_sfx("upgrade")


func _on_day_ended(summary: Dictionary) -> void:
	_rave_player.stop()
	for inc in incidents.duplicate():
		inc.done = true
		inc.queue_free()
	incidents.clear()
	summary.reviews_today = reviews_today.duplicate()
	AudioManager.play_sfx("day_end")
	var dlg := DaySummary.new()
	dlg.summary = summary
	hud.add_child(dlg)
