class_name ReliefBoat
extends Node3D
## The relief boat that ends Chapter One (Rescue): the Mary Ann, a little Kirkhaven
## motor drifter in black and red lead, smoke from her funnel. She steams in from the
## south-east at dawn, lies off the east beach with a plank run out to the shingle, waits
## while the keepers come aboard ([E] at the plank; the helpers make their own way), then
## turns for the mainland and the next chapter.

signal arrived
signal departed

const NAME := "MARY ANN"
const LEN := 7.6
const BEAM := 2.5
const ARRIVE_TIME := 14.0
const DEPART_TIME := 14.0
## How far off the waterline she lies, and the plank's reach.
const STANDOFF := 3.6
const BOARD_RANGE := 1.8
const HULL := Color(0.09, 0.09, 0.1)
const RED_LEAD := Color(0.45, 0.13, 0.09)

## Where the keepers come aboard: the plank's end on the beach.
var shore := Vector3.ZERO
## Where she lies, off the beach.
var mooring := Vector3.ZERO
var waiting := false
var aboard: Array = []
var _t := 0.0
var _plank: Node3D
var _smoke: GPUParticles3D
var _wake_t := 0.0
var _moving := false
var _heading := 0.0

func _ready() -> void:
	_build()
	_plank.visible = false

## Where she'll lie for this beach (Terrain.BEACHES index): the waterline, and off it.
static func berth(beach: int) -> Array:
	var shore_at := Terrain.beach_point(beach, 0.0)
	for k in 60:
		var p := Terrain.beach_point(beach, float(k) / 60.0)
		if p.y > Terrain.SEA_LEVEL + 0.08:
			shore_at = p
			break
	var up := Terrain.beach_point(beach, 1.0) - Terrain.beach_point(beach, 0.0)
	up.y = 0.0
	up = up.normalized()
	var moor := shore_at - up * STANDOFF
	moor.y = Terrain.SEA_LEVEL
	return [shore_at, moor]

## In from the south-east to her berth.
func arrive(p_shore: Vector3, p_mooring: Vector3) -> void:
	shore = p_shore
	mooring = p_mooring
	var from := mooring + Vector3(26.0, 0.0, 46.0)
	global_position = from
	_face(mooring - from)
	_moving = true
	var tw := create_tween()
	tw.tween_property(self, "global_position", mooring, ARRIVE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Round she comes at the end, broadside to the beach, the plank run out.
	var side := shore - mooring
	tw.parallel().tween_method(_turn_to.bind(_heading, atan2(-side.x, -side.z)), 0.0, 1.0, ARRIVE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(_on_arrived)
	Audio.sfx("foghorn", global_position, 2.0, 0.0)

func _on_arrived() -> void:
	_moving = false
	waiting = true
	_plank.visible = true
	_lay_plank()
	add_to_group("interactable")
	arrived.emit()
	Audio.sfx("foghorn_short", global_position, 0.0, 0.0)

func _turn_to(k: float, a: float, b: float) -> void:
	_heading = lerp_angle(a, b, k)
	rotation.y = _heading

# Bow (her local +X) along d.
func _face(d: Vector3) -> void:
	_heading = atan2(-d.z, d.x)
	rotation.y = _heading

## A keeper steps aboard.
func take_aboard(k: Node) -> void:
	if aboard.has(k):
		return
	aboard.append(k)
	k.board(self)
	Audio.sfx("creak", shore, -2.0, 0.1)
	Events.message.emit("%s is aboard the %s." % [k.keeper_name(), NAME.capitalize()])

## Away to the mainland, everyone aboard.
func depart() -> void:
	waiting = false
	remove_from_group("interactable")
	_plank.visible = false
	_moving = true
	var to := mooring + Vector3(10.0, 0.0, 70.0)
	var tw := create_tween()
	tw.tween_method(_turn_to.bind(_heading, atan2(-(to - mooring).z, (to - mooring).x)), 0.0, 1.0, 3.0)
	tw.tween_property(self, "global_position", to, DEPART_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: departed.emit())
	Audio.sfx("foghorn", global_position, 2.0, 0.0)

# ---- a keeper at the plank ----

func surface_distance(p: Vector3) -> float:
	return Geo.flat_dist(p, shore) if waiting else INF

func interact_prompt() -> String:
	return "[E] Go aboard the %s" % NAME.capitalize() if waiting else ""

func interact(player: Node) -> bool:
	if not waiting or not player.has_method("board"):
		return false
	take_aboard(player)
	return true

func _process(delta: float) -> void:
	_t += delta
	# Riding the swell: a slow roll and pitch, more in a sea.
	var sea := 1.0 + Weather.wind_now.length() * 0.15
	rotation.x = sin(_t * 0.9) * 0.025 * sea
	rotation.z = sin(_t * 0.7 + 1.3) * 0.045 * sea
	position.y = Terrain.SEA_LEVEL + sin(_t * 1.1) * 0.06 * sea - 0.25
	if _moving:
		_wake_t -= delta
		if _wake_t <= 0.0:
			_wake_t = 0.25
			var stern := global_transform * Vector3(-LEN * 0.5, 0.0, 0.0)
			FX.splash(get_parent(), Vector3(stern.x, Terrain.SEA_LEVEL, stern.z), 0.35)
	if _plank.visible:
		_lay_plank()

# The plank from her rail to the shingle.
func _lay_plank() -> void:
	var a := global_transform * Vector3(0.0, 1.0, -BEAM * 0.5)
	var b := shore + Vector3(0.0, 0.1, 0.0)
	_plank.global_position = (a + b) * 0.5
	_plank.look_at(b, Vector3.UP)
	_plank.scale = Vector3(1.0, 1.0, a.distance_to(b))

# ---- her looks: along local +X bow to stern -X, port -Z ----

func _build() -> void:
	var hull := Look.flat_mat(HULL, 0.6)
	var red := Look.flat_mat(RED_LEAD, 0.7)
	var deck := Look.wood(Color(0.45, 0.4, 0.32), 0.6)
	var white := Look.flat_mat(Color(0.82, 0.8, 0.74), 0.6)
	# Hull: a long box, a raked bow and a rounded stern; red lead below the waterline.
	var body := Geo.box(self, Vector3(LEN * 0.72, 1.1, BEAM), Color.WHITE, Vector3(-LEN * 0.06, 0.45, 0.0))
	body.material_override = hull
	var under := Geo.box(self, Vector3(LEN * 0.7, 0.5, BEAM * 0.86), Color.WHITE, Vector3(-LEN * 0.06, -0.2, 0.0))
	under.material_override = red
	var bow := Geo.cyl(self, BEAM * 0.5, 1.1, Color.WHITE, Vector3(LEN * 0.3, 0.45, 0.0))
	(bow.mesh as CylinderMesh).radial_segments = 3
	bow.scale = Vector3(1.9, 1.0, 1.0)
	bow.material_override = hull
	var stern := Geo.cyl(self, BEAM * 0.5, 1.1, Color.WHITE, Vector3(-LEN * 0.42, 0.45, 0.0))
	stern.material_override = hull
	var planking := Geo.box(self, Vector3(LEN * 0.9, 0.06, BEAM - 0.12), Color.WHITE, Vector3(-0.1, 0.98, 0.0))
	planking.material_override = deck
	# Bulwarks along both sides, a white capping rail on them, a white strake below, and
	# old tyres hung over as fenders.
	for sz in [-1.0, 1.0]:
		var bulwark := Geo.box(self, Vector3(LEN * 0.88, 0.42, 0.08), Color.WHITE, Vector3(-0.1, 1.2, sz * (BEAM * 0.5 - 0.04)))
		bulwark.material_override = hull
		var cap := Geo.box(self, Vector3(LEN * 0.88, 0.05, 0.14), Color.WHITE, Vector3(-0.1, 1.43, sz * (BEAM * 0.5 - 0.04)))
		cap.material_override = white
		var strake := Geo.box(self, Vector3(LEN * 0.9, 0.08, 0.04), Color.WHITE, Vector3(-0.1, 0.8, sz * (BEAM * 0.5 + 0.01)))
		strake.material_override = white
		for k in 3:
			var tyre := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.12
			tm.outer_radius = 0.24
			tyre.mesh = tm
			tyre.material_override = Look.flat_mat(Color(0.05, 0.05, 0.05), 0.9)
			tyre.position = Vector3(-1.8 + 1.6 * float(k), 0.95, sz * (BEAM * 0.5 + 0.08))
			tyre.rotation.x = PI * 0.5
			add_child(tyre)
	# Fish boxes stacked forward, a coil of rope, a hatch.
	for k in 3:
		var box := Geo.box(self, Vector3(0.6, 0.25, 0.4), Color.WHITE, Vector3(1.1 + 0.05 * float(k % 2), 1.14 + 0.25 * float(k), 0.4 - 0.1 * float(k)))
		box.material_override = Look.wood(Color(0.55, 0.42, 0.3), 0.5)
	var coil := MeshInstance3D.new()
	var cm := TorusMesh.new()
	cm.inner_radius = 0.12
	cm.outer_radius = 0.3
	coil.mesh = cm
	coil.material_override = Look.flat_mat(Color(0.55, 0.46, 0.3), 1.0)
	coil.position = Vector3(2.1, 1.06, -0.5)
	add_child(coil)
	var hatch := Geo.box(self, Vector3(0.9, 0.18, 0.9), Color.WHITE, Vector3(0.3, 1.08, 0.0))
	hatch.material_override = hull
	# Wheelhouse aft of midships, windows lit.
	var house := Geo.box(self, Vector3(1.8, 1.4, 1.7), Color.WHITE, Vector3(-0.9, 1.7, 0.0))
	house.material_override = Look.wood(Color(0.62, 0.6, 0.52), 0.8)
	var roof := Geo.box(self, Vector3(2.0, 0.08, 1.9), Color.WHITE, Vector3(-0.9, 2.44, 0.0))
	roof.material_override = hull
	var glass := Look.glow_mat(Color(1.0, 0.85, 0.55), 1.2)
	for sz in [-0.86, 0.86]:
		for k in 2:
			var w := Geo.box(self, Vector3(0.45, 0.4, 0.03), Color.WHITE, Vector3(-0.55 - 0.65 * float(k), 1.95, sz))
			w.material_override = glass
	var fwin := Geo.box(self, Vector3(0.03, 0.4, 1.2), Color.WHITE, Vector3(0.01, 1.95, 0.0))
	fwin.material_override = glass
	# Funnel, black with a red band, and the mast forward with her lights.
	var funnel := Geo.cyl(self, 0.28, 1.4, Color.WHITE, Vector3(-2.1, 2.2, 0.0))
	funnel.material_override = hull
	var band := Geo.cyl(self, 0.29, 0.25, Color.WHITE, Vector3(-2.1, 2.6, 0.0))
	band.material_override = red
	var mast := Geo.cyl(self, 0.06, 4.2, Color.WHITE, Vector3(1.8, 3.1, 0.0))
	mast.material_override = deck
	var masthead := OmniLight3D.new()
	masthead.light_color = Color(1.0, 0.95, 0.8)
	masthead.light_energy = 1.4
	masthead.omni_range = 6.0
	masthead.position = Vector3(1.8, 5.1, 0.0)
	add_child(masthead)
	Look.glint(self, Vector3(1.8, 5.1, 0.0), Color(1.0, 0.95, 0.8), 0.35)
	Look.glint(self, Vector3(0.2, 1.4, -BEAM * 0.52), Color(1.0, 0.15, 0.1), 0.25)
	Look.glint(self, Vector3(0.2, 1.4, BEAM * 0.52), Color(0.15, 1.0, 0.3), 0.25)
	# Lifebelts on the wheelhouse, and her name on the stern.
	for sz in [-0.88, 0.88]:
		var belt := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.16
		tm.outer_radius = 0.25
		belt.mesh = tm
		belt.material_override = Look.flat_mat(Color(0.85, 0.35, 0.15), 0.6)
		belt.position = Vector3(-1.5, 1.7, sz)
		belt.rotation.x = PI * 0.5
		add_child(belt)
	var label := Label3D.new()
	label.text = NAME + "\nKIRKHAVEN"
	label.font_size = 40
	label.pixel_size = 0.005
	label.modulate = Color(0.85, 0.8, 0.6)
	label.outline_size = 0
	label.position = Vector3(-LEN * 0.5 - 0.06, 0.7, 0.0)
	label.rotation.y = -PI * 0.5
	add_child(label)
	_smoke = FX.smoke(self, to_global(Vector3(-2.1, 3.0, 0.0)), Color(0.25, 0.25, 0.26, 0.5), 18, 3.0, Vector3(-0.3, 1.0, 0.0).normalized(), 15.0, 0.6, 1.2, 0.15, 0.4, 1.0)
	# The plank (laid when she's in).
	_plank = Node3D.new()
	add_child(_plank)
	var board := Geo.box(_plank, Vector3(0.5, 0.06, 1.0), Color.WHITE, Vector3.ZERO)
	board.material_override = deck
