class_name Helper
extends Walker
## Someone who fixes things: the manager (you) or a member of staff. Works through jobs:
## walk to a spot, work for a few seconds, then the job's callback runs. The manager takes
## jobs from your taps (queued); staff ask the HotelWorld for the next job their role covers.

const SPEEDS := {"manager": 160.0, "cleaner": 95.0, "handyman": 95.0, "security": 140.0, "lifeguard": 170.0, "barman": 90.0}
const TOOLS := {"cleaner": "mop", "handyman": "wrench", "lifeguard": "lifebuoy", "barman": "pint", "manager": "clipboard", "security": ""}

var role := "manager"
var data: Dictionary = {}
var job: Dictionary = {}
var queue: Array = []
var home := Vector2.ZERO
var working := false
var _work := 0.0
var _poll := 0.0
var _chase := 0.0
var _chat := 0.0
var _rng := RandomNumberGenerator.new()


func setup(w: Node, r: String, d: Dictionary, look: Dictionary, home_pos: Vector2) -> void:
	world = w
	role = r
	data = d
	home = home_pos
	position = home_pos
	_rng.randomize()
	_chat = _rng.randf_range(10.0, 30.0)
	if role == "manager":
		setup_avatar({}, false, true)
	else:
		setup_avatar(look, true)
	speed = float(SPEEDS.get(role, 100.0))


func is_idle() -> bool:
	return job.is_empty() and queue.is_empty()


## Manager only: add a job to the queue (max 4). Returns false if it was already queued.
func enqueue(j: Dictionary) -> bool:
	for q in queue + ([job] if not job.is_empty() else []):
		if q.get("key", "") != "" and q.get("key", "") == j.get("key", "?"):
			return false
	if queue.size() >= 4:
		return false
	queue.append(j)
	return true


func walk_somewhere(p: Vector2) -> void:
	if job.is_empty():
		go_to(p, true)


func assign(j: Dictionary) -> void:
	job = j
	working = false
	go_to(j.spot, role in ["manager", "security", "lifeguard"])


func cancel_job() -> void:
	if job.has("incident") and job.incident and is_instance_valid(job.incident):
		var inc: Incident = job.incident
		if inc.claimed_by == self:
			inc.claimed_by = null
			inc.working = false
	if job.has("release"):
		(job.release as Callable).call()
	job = {}
	working = false
	avatar.hold_item("")


func _process(delta: float) -> void:
	_chat -= delta
	if job.is_empty():
		if not queue.is_empty():
			assign(queue.pop_front())
			return
		if role != "manager":
			_poll -= delta
			if _poll <= 0.0:
				_poll = 0.5
				var j: Dictionary = world.find_job(self)
				if not j.is_empty():
					assign(j)
					return
			if not moving and path.is_empty() and position.distance_to(home) > 12.0:
				go_to(home)
		step_path(delta)
		if not moving and role == "barman":
			face(Vector2(HotelLayout.BAR_X0, 0))
		if _chat <= 0.0 and world.is_on_screen(position):
			_chat = _rng.randf_range(25.0, 50.0)
			say(_idle_line(), "normal", 1.8)
		return
	# Abandon jobs whose incident got sorted (or went wrong) without us.
	if job.has("incident"):
		var inc = job.incident
		if inc == null or not is_instance_valid(inc) or inc.done:
			cancel_job()
			return
	if not working:
		if job.has("follow"):
			_chase -= delta
			if _chase <= 0.0:
				_chase = 0.4
				var target: Node2D = job.follow
				if target and is_instance_valid(target):
					go_to(target.position, true)
					job.spot = target.position
		if step_path(delta) or position.distance_to(job.spot) < 14.0:
			stop()
			path.clear()
			working = true
			_work = float(job.get("time", 1.0))
			avatar.present(_work)
			avatar.hold_item(str(TOOLS.get(role, "")))
			if job.has("incident"):
				job.incident.working = true
			if job.has("line"):
				say(str(job.line), "shout" if role in ["manager", "security", "lifeguard"] else "normal", 1.6)
	else:
		_work -= delta
		if _work <= 0.0:
			var done_cb: Callable = job.on_done
			job = {}
			working = false
			avatar.hold_item("")
			done_cb.call()


func _idle_line() -> String:
	match role:
		"cleaner": return Lines.pick(Lines.CLEANER, _rng)
		"handyman": return Lines.pick(Lines.HANDYMAN, _rng)
		"security": return Lines.pick(Lines.SECURITY, _rng)
		"lifeguard": return Lines.pick(Lines.LIFEGUARD, _rng)
		"barman": return Lines.pick(Lines.BARMAN, _rng)
	return Lines.pick(Lines.MANAGER, _rng)
