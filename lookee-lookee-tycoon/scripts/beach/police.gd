class_name Police
extends Walker
## A Policía Local officer. Strolls the promenade, keeps an eye on the sand, and gets
## suspicious when they spot an open stall. Heat decides how hard they look: at WANTED one
## comes straight for you; at RAID they all do. Pack up before they arrive and they shrug.

signal reached_stall(cop: Police, stall: Stall)
signal caught_vendor(cop: Police)

enum State { PATROL, INVESTIGATE, CHASE_STALL, CHASE_VENDOR, DISTRACTED, BUSY, RETURN, LEAVE }

const PATROL_SPEED := 62.0
const CHASE_SPEED := 135.0
const SIGHT := 220.0
const WATCH_TIME := 3.2         # seconds a cop stares at a stall before coming over

var state: State = State.PATROL
var target_stall: Stall
var suspicion := 0.0
var cooldown := 0.0
var warned := false            # has a lookout already warned about this chase?
var _timer := 0.0
var _scan := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	setup_avatar(AppearanceOptions.police_appearance(_rng), true)
	speed = PATROL_SPEED
	_new_patrol_target()


func sight() -> float:
	var s := SIGHT * (1.25 if HeatSystem.level >= HeatSystem.Level.SUSPICIOUS else 1.0)
	return s * clampf(float(BeachDB.get_beach(GameManager.current_beach).police), 0.8, 1.4)


func chase_speed() -> float:
	return CHASE_SPEED * pow(float(BeachDB.get_beach(GameManager.current_beach).police), 0.35)


func is_chasing() -> bool:
	return state in [State.CHASE_STALL, State.CHASE_VENDOR, State.INVESTIGATE]


func _process(delta: float) -> void:
	cooldown = maxf(cooldown - delta, 0.0)
	_timer -= delta
	match state:
		State.PATROL:
			if step_move(delta, PATROL_SPEED):
				if _timer <= 0.0:
					_new_patrol_target()
			_scan -= delta
			if _scan <= 0.0:
				_scan = 0.25
				_look_around()
		State.INVESTIGATE:
			# Stop and stare: this is the player's window to pack up.
			if target_stall == null or not target_stall.is_open():
				if target_stall and target_stall.owner_kind == "player":
					say(Lines.pick(Lines.POLICE_SHRUG, _rng), "police", 2.0)
				_lose_interest()
			else:
				face(target_stall.position)
				suspicion += delta
				if target_stall.owner_kind == "player":
					HeatSystem.add(4.0 * delta, "spotted")
				var patience := WATCH_TIME * (0.5 if HeatSystem.level >= HeatSystem.Level.WANTED else 1.0)
				if suspicion > patience:
					chase_stall(target_stall)
		State.CHASE_STALL:
			if target_stall == null or not target_stall.visible or target_stall.state == Stall.State.CLOSED:
				_arrive_empty()
			else:
				target = target_stall.position + Vector2(0, 36)
				moving = true
				if step_move(delta, chase_speed()) or position.distance_to(target) < 20.0:
					stop()
					state = State.BUSY
					reached_stall.emit(self, target_stall)
		State.CHASE_VENDOR:
			var v: Node2D = beach.vendor
			target = v.position
			moving = true
			running = true
			step_move(delta, chase_speed() * 1.08)
			if position.distance_to(v.position) < 30.0:
				stop()
				state = State.BUSY
				caught_vendor.emit(self)
		State.DISTRACTED:
			if _timer <= 0.0:
				state = State.CHASE_STALL if target_stall else State.RETURN
		State.RETURN:
			if step_move(delta, PATROL_SPEED):
				state = State.PATROL
				_new_patrol_target()
		State.LEAVE:
			if step_move(delta, PATROL_SPEED):
				beach.remove_cop(self)


func _look_around() -> void:
	if cooldown > 0.0:
		return
	var s: Stall = beach.nearest_open_stall(position, sight())
	if s:
		if s.owner_kind == "player":
			HeatSystem.add(3.0, "spotted")
		suspicion = 0.0
		target_stall = s
		state = State.INVESTIGATE
		warned = false
		stop()
		say(Lines.pick(Lines.POLICE_SPOT, _rng), "police", 1.6)
		AudioManager.play_sfx("whistle", 0.05, -10.0)
		if s.owner_kind == "player":
			beach.on_police_coming(self)


func _new_patrol_target() -> void:
	running = false
	var x := clampf(position.x + _rng.randf_range(-600.0, 600.0), 60.0, BeachBackdrop.WORLD_W - 60.0)
	var y: float = _rng.randf_range(BeachBackdrop.PROM_Y + 25.0, BeachBackdrop.PROM_Y + 85.0)
	# Suspicious cops step onto the sand for a better look.
	if HeatSystem.level >= HeatSystem.Level.SUSPICIOUS and _rng.randf() < 0.5:
		y = _rng.randf_range(BeachBackdrop.PROM_Y - 220.0, BeachBackdrop.PROM_Y - 40.0)
	walk_to(Vector2(x, y))
	_timer = _rng.randf_range(1.0, 4.0)


## Go straight for a stall (heat WANTED, a dispatch from the beach, or after investigating).
func chase_stall(s: Stall) -> void:
	if s == null:
		return
	target_stall = s
	state = State.CHASE_STALL
	running = true
	if not warned:
		say("¡ALTO! ¡POLICÍA!", "police", 1.6)
		AudioManager.play_sfx("whistle")
	if s.owner_kind == "player":
		beach.on_police_coming(self)


func chase_vendor() -> void:
	state = State.CHASE_VENDOR
	running = true
	say("¡VUELVE AQUÍ!", "police", 1.6)


func distract(seconds: float) -> void:
	if state == State.BUSY or state == State.CHASE_VENDOR:
		return
	state = State.DISTRACTED
	stop()
	_timer = seconds
	say("The beach? Er... it's here?", "police", seconds)


func _lose_interest() -> void:
	target_stall = null
	running = false
	state = State.RETURN
	cooldown = 4.0
	walk_to(Vector2(position.x, _rng.randf_range(BeachBackdrop.PROM_Y + 25.0, BeachBackdrop.PROM_Y + 85.0)))


func _arrive_empty() -> void:
	# The stall vanished before we got there. Very suspicious... but nothing to see.
	if target_stall and target_stall.owner_kind == "player":
		say(Lines.pick(Lines.POLICE_SHRUG, _rng), "police", 2.4)
		HeatSystem.reduce(10.0)
	finish(6.0)


## Done with this incident: back to the promenade, ignore stalls for a while.
func finish(cool := 12.0) -> void:
	target_stall = null
	suspicion = 0.0
	running = false
	cooldown = cool
	state = State.RETURN
	walk_to(Vector2(position.x + _rng.randf_range(-200, 200), _rng.randf_range(BeachBackdrop.PROM_Y + 25.0, BeachBackdrop.PROM_Y + 85.0)))


func leave_beach() -> void:
	state = State.LEAVE
	running = false
	walk_to(Vector2(-80.0 if position.x < BeachBackdrop.WORLD_W * 0.5 else BeachBackdrop.WORLD_W + 80.0, BeachBackdrop.PROM_Y + 50.0))
