extends Node
## Autoload: picks a quality tier for the device and keeps the game smooth.
##   - Auto-detects phones/tablets/browsers and chooses LOW, MEDIUM or HIGH.
##   - Targets 60 FPS. If a device can't hold it, it drops to 30 FPS and a lower tier
##     (fewer tourists, fewer coin particles) instead of stuttering.
##   - Keeps the screen awake on phones while playing.
## Gameplay reads max_tourists, particles and fx_scale; the Settings menu can force a tier.

signal tier_changed(tier: int)

enum Tier { LOW, MEDIUM, HIGH }

const TIER_NAMES := ["Low", "Medium", "High"]
const MAX_TOURISTS := [16, 24, 30]
const PARTICLES := [6, 10, 16]
const CHECK_SECONDS := 6.0

var tier: Tier = Tier.HIGH
var forced := -1               # -1 = auto, else a Tier
var max_tourists := 30
var particles := 16
var show_fps := false
var is_mobile := false
var is_web := false

var _samples: Array[float] = []
var _sample_timer := 0.0
var _downgraded := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	is_web = OS.has_feature("web")
	is_mobile = OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios") \
		or OS.has_feature("web_android") or OS.has_feature("web_ios")
	if is_mobile:
		DisplayServer.screen_set_keep_on(true)
	apply(detect())


func detect() -> Tier:
	if forced >= 0:
		return forced as Tier
	if is_mobile:
		return Tier.LOW if OS.get_processor_count() <= 4 else Tier.MEDIUM
	if is_web:
		return Tier.MEDIUM
	return Tier.HIGH


func apply(t: Tier) -> void:
	tier = t
	max_tourists = MAX_TOURISTS[t]
	particles = PARTICLES[t]
	Engine.max_fps = 60
	_samples.clear()
	_downgraded = false
	tier_changed.emit(tier)


func force(t: int) -> void:
	forced = t
	apply(detect())


func tier_name() -> String:
	return ("Auto (%s)" % TIER_NAMES[tier]) if forced < 0 else TIER_NAMES[tier]


# Watches the frame rate during play and steps down once if the device is struggling.
func _process(delta: float) -> void:
	if forced >= 0 or _downgraded or DisplayServer.get_name() == "headless":
		return
	_sample_timer += delta
	if _sample_timer < 1.0:
		return
	_sample_timer = 0.0
	_samples.append(Engine.get_frames_per_second())
	if _samples.size() < CHECK_SECONDS:
		return
	var avg := 0.0
	for s in _samples:
		avg += s
	avg /= _samples.size()
	_samples.pop_front()
	if avg < 48.0 and get_tree().current_scene and get_tree().current_scene.name == "Beach":
		_downgraded = true
		if tier > Tier.LOW:
			tier = (tier - 1) as Tier
			max_tourists = MAX_TOURISTS[tier]
			particles = PARTICLES[tier]
		# Graceful fallback: a steady 30 beats a jittery 45.
		if avg < 40.0:
			Engine.max_fps = 30
		print("Quality: average %.0f FPS, now %s at %d FPS cap" % [avg, TIER_NAMES[tier], Engine.max_fps])
		tier_changed.emit(tier)
