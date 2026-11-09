class_name Kirk
extends Structure
## Kirkhaven's parish kirk: a plain rubble nave under a steep slate roof, its long axis
## along z and its doors in the gable facing +Z; a square tower at the front-left corner
## with a bronze bell in the open belfry and a slated cap. The town shelters inside by
## candlelight, and it is the DOORS that take the damage: they splinter, plank by plank.

const NAVE_W := 5.5
const NAVE_L := 9.0
const WALL_H := 4.0
const PITCH := 50.0
const EAVES := 0.28
const ROOF_T := 0.1
const TOWER := 3.0
const TOWER_H := 9.0
## The tower's centre: against the nave's west wall, a little proud of the gable.
const TOWER_AT := Vector3(-NAVE_W * 0.5 - TOWER * 0.5 + 0.4, 0.0, NAVE_L * 0.5 - TOWER * 0.5 + 0.3)
const BELFRY_Y := 6.4
const BELFRY_TOP := 8.4
const PIER := 0.62
const SPIRE_H := 2.6
const FLOOR_Y := 0.3
const DOOR_W := 1.8
const DOOR_H := 2.5
const PLANKS := 6
const BELL_SWING := 0.5
const RING_TIME := 1.6
const WINDOW_DARK := Color(0.05, 0.06, 0.08)
const CANDLE := Color(1.0, 0.66, 0.32)
const WINDOW_GLOW := 2.2
const LAMP_ENERGY := 1.5
const WALL := Color(0.72, 0.69, 0.64)
const DRESSED := Color(0.76, 0.72, 0.64)
const BLACK := Color(0.07, 0.07, 0.08)

## How bright the windows are, 0..1: use set_glow().
var glow := 0.25

var _glass: StandardMaterial3D
var _lamp: OmniLight3D
var _bell: Node3D
var _planks: Array[MeshInstance3D] = []
var _rest: Array[Transform3D] = []
var _glow_tween: Tween
var _ring_tween: Tween
var _ridge := 0.0

func _init() -> void:
	id = "kirk"
	max_hp = 300

## The bell swings once out and back (no sound: that is the caller's).
func ring() -> void:
	if _bell == null:
		return
	if _ring_tween != null and _ring_tween.is_valid():
		_ring_tween.kill()
	_ring_tween = create_tween()
	_ring_tween.tween_property(_bell, "rotation:x", -BELL_SWING, RING_TIME * 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_ring_tween.tween_property(_bell, "rotation:x", BELL_SWING * 0.8, RING_TIME * 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_ring_tween.tween_property(_bell, "rotation:x", 0.0, RING_TIME * 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## The candlelight in the windows, 0 (dark) to 1, over `fade` seconds.
func set_glow(k: float, fade: float = 1.5) -> void:
	var from := glow
	glow = clampf(k, 0.0, 1.0)
	if _glass == null:
		return
	if _glow_tween != null and _glow_tween.is_valid():
		_glow_tween.kill()
	if fade <= 0.0 or not is_inside_tree():
		_show_glow(glow)
		return
	_glow_tween = create_tween()
	_glow_tween.tween_method(_show_glow, from, glow, fade)

func _show_glow(k: float) -> void:
	_glass.albedo_color = WINDOW_DARK.lerp(CANDLE, k)
	_glass.emission_energy_multiplier = WINDOW_GLOW * k
	_lamp.light_energy = LAMP_ENERGY * k
	_lamp.visible = k > 0.001

## On the ground 1.2 m in front of the doors (global).
func door_point() -> Vector3:
	return to_global(Vector3(0.0, 0.0, NAVE_L * 0.5 + 1.2))

func display_name() -> String:
	return "the kirk doors"

func smoke_point() -> Vector3:
	return Vector3(0.0, FLOOR_Y + DOOR_H + 0.4, NAVE_L * 0.5 + 0.3)

func surface_distance(p: Vector3) -> float:
	var local := to_local(p)
	var dx := maxf(0.0, absf(local.x) - NAVE_W * 0.5)
	var dz := maxf(0.0, absf(local.z) - NAVE_L * 0.5)
	return Vector2(dx, dz).length()

# Splinters fly from the doors, not from the middle of the nave.
func _on_damaged() -> void:
	if is_inside_tree():
		FX.splinters(get_parent(), to_global(Vector3(0.0, FLOOR_Y + 1.2, NAVE_L * 0.5 + 0.3)))
		Audio.sfx("hit", door_point(), -6.0, 0.15)

# The doors as they stand: whole; a plank gone and one hanging; half of them gone;
# nothing but the dark of the doorway.
func _refresh() -> void:
	if _planks.is_empty():
		return
	var r := health_ratio()
	var stage := 0 if r >= 0.66 else (1 if r >= 0.33 else (2 if r > 0.0 else 3))
	for i in _planks.size():
		_planks[i].transform = _rest[i]
		_planks[i].visible = stage < 3
	if stage >= 1:
		_planks[4].visible = false
		_askew(1, 0.16, -0.1)
	if stage >= 2:
		_planks[0].visible = false
		_planks[3].visible = false
		_askew(2, -0.3, -0.3)
		_askew(5, 0.42, -0.45)

func _askew(i: int, roll: float, drop: float) -> void:
	_planks[i].rotation = Vector3(-0.08, 0.0, roll)
	_planks[i].position += Vector3(roll * 0.4, drop, 0.07)

func _roof_y(x: float) -> float:
	return _ridge - absf(x) * tan(deg_to_rad(PITCH))

func _build() -> void:
	var hw := NAVE_W * 0.5
	var hl := NAVE_L * 0.5
	var pitch := deg_to_rad(PITCH)
	var rise := hw * tan(pitch)
	_ridge = WALL_H + rise + ROOF_T / cos(pitch)
	Geo.box_shape(self, Vector3(NAVE_W, WALL_H, NAVE_L), Vector3(0.0, WALL_H * 0.5, 0.0))
	Geo.box_shape(self, Vector3(TOWER, WALL_H, TOWER), TOWER_AT + Vector3(0.0, WALL_H * 0.5, 0.0))
	var b := HarbourProps.Batch.new()
	# The nave: rubble walls on a footing, the gables up to the roof.
	b.box("stone", Vector3(NAVE_W, WALL_H, NAVE_L), Vector3(0.0, WALL_H * 0.5, 0.0), WALL)
	b.tri("stone", Vector3(-hw, WALL_H, hl), Vector3(hw, WALL_H, hl), Vector3(0.0, WALL_H + rise, hl), WALL)
	b.tri("stone", Vector3(hw, WALL_H, -hl), Vector3(-hw, WALL_H, -hl), Vector3(0.0, WALL_H + rise, -hl), WALL)
	b.box("stone", Vector3(NAVE_W + 0.16, 0.4, NAVE_L + 0.16), Vector3(0.0, 0.2, 0.0), WALL.darkened(0.2))
	# The roof, its ridge along z: drawn in a frame turned a quarter round.
	b.xf = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO)
	var span := hw + EAVES
	HarbourProps.pitched_roof(b, "roof_slate", hl, span, _roof_y(span), pitch, HarbourProps.roof_tile("slate"), ROOF_T)
	b.box("paint", Vector3(NAVE_L, 0.1, 0.26), Vector3(0.0, _ridge - 0.01, 0.0), Color(0.2, 0.21, 0.24))
	# Skews up each gable.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			b.box("dressed", Vector3(0.32, 0.16, (hw + 0.14) / cos(pitch) + 0.04), Vector3(sx * (hl - 0.16), _roof_y((hw + 0.14) * 0.5) + 0.05, sz * (hw + 0.14) * 0.5), DRESSED, Basis(Vector3.RIGHT, sz * pitch))
			b.box("dressed", Vector3(0.38, 0.26, 0.32), Vector3(sx * (hl - 0.16), _roof_y(hw + 0.14) + 0.02, sz * (hw + 0.14)), DRESSED)
	b.xf = Transform3D.IDENTITY
	# A stone cross on the front gable.
	var apex := Vector3(0.0, _ridge, hl - 0.16)
	b.box("dressed", Vector3(0.34, 0.3, 0.34), apex + Vector3(0.0, 0.12, 0.0), DRESSED)
	b.box("dressed", Vector3(0.12, 0.75, 0.12), apex + Vector3(0.0, 0.62, 0.0), DRESSED)
	b.box("dressed", Vector3(0.46, 0.12, 0.12), apex + Vector3(0.0, 0.72, 0.0), DRESSED)
	# Pointed windows down both sides (two on the tower's side), one in the gable.
	for wz: float in [-3.0, -0.6, 1.8]:
		b.xf = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(hw, 0.0, wz))
		_lancet(b, 0.0, 1.35, 0.8, 1.5, 0.75)
		if wz < 1.0:
			b.xf = Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-hw, 0.0, wz))
			_lancet(b, 0.0, 1.35, 0.8, 1.5, 0.75)
	b.xf = Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, hl))
	_lancet(b, 0.0, 4.75, 0.75, 0.85, 0.7)
	_doorway(b)
	b.xf = Transform3D.IDENTITY
	_tower(b)
	_glass = Look.glow_mat(WINDOW_DARK, 0.0)
	_glass.emission = CANDLE
	_glass.roughness = 0.25
	b.build(self, {"glass": _glass})
	_hang_doors(hl)
	_hang_bell()
	_lamp = OmniLight3D.new()
	_lamp.light_color = CANDLE
	_lamp.omni_range = 6.5
	_lamp.shadow_enabled = false
	_lamp.position = Vector3(0.0, 2.4, hl + 1.0)
	add_child(_lamp)
	_show_glow(glow)

# The outline of a pointed arch standing on a rectangle, anticlockwise from its foot.
func _arch(x: float, sill: float, w: float, straight: float, rise: float, z: float) -> PackedVector3Array:
	var spring := sill + straight
	var pts := PackedVector3Array([Vector3(x - w * 0.5, sill, z), Vector3(x + w * 0.5, sill, z)])
	var side: Array[Vector2] = []
	for k in 4:
		# Each side bows out from the springing and meets the other at a point.
		var t := float(k) / 4.0
		var p0 := Vector2(w * 0.5, spring)
		var p1 := Vector2(w * 0.5, spring + rise * 0.75)
		var p2 := Vector2(0.0, spring + rise)
		side.append(p0.lerp(p1, t).lerp(p1.lerp(p2, t), t))
	for p in side:
		pts.append(Vector3(x + p.x, p.y, z))
	pts.append(Vector3(x, spring + rise, z))
	for k in range(3, -1, -1):
		pts.append(Vector3(x - side[k].x, side[k].y, z))
	return pts

# A pointed window on the wall the batch faces: dressed margin, glass, a mullion, a sill.
func _lancet(b: HarbourProps.Batch, x: float, sill: float, w: float, straight: float, rise: float) -> void:
	b.poly("dressed", _arch(x, sill - 0.14, w + 0.34, straight + 0.14, rise + 0.2, 0.03), DRESSED, Vector3.BACK)
	b.poly("glass", _arch(x, sill, w, straight, rise, 0.055), Color.WHITE, Vector3.BACK)
	b.box("dressed", Vector3(0.07, straight + rise - 0.06, 0.03), Vector3(x, sill + (straight + rise - 0.06) * 0.5, 0.07), DRESSED)
	b.box("dressed", Vector3(w + 0.44, 0.1, 0.22), Vector3(x, sill - 0.14, 0.11), DRESSED)

# The doorway in the front gable: a pointed stone surround, the dark inside, a boarded
# head over the doors, and two steps up.
func _doorway(b: HarbourProps.Batch) -> void:
	b.poly("dressed", _arch(0.0, 0.0, DOOR_W + 0.5, FLOOR_Y + DOOR_H, 1.1, 0.03), DRESSED, Vector3.BACK)
	b.box("void", Vector3(DOOR_W, DOOR_H, 0.02), Vector3(0.0, FLOOR_Y + DOOR_H * 0.5, 0.05))
	b.poly("wood", _arch(0.0, FLOOR_Y + DOOR_H, DOOR_W, 0.0, 0.8, 0.055), Color(0.2, 0.15, 0.11), Vector3.BACK)
	b.box("dressed", Vector3(DOOR_W + 0.1, 0.1, 0.1), Vector3(0.0, FLOOR_Y + DOOR_H, 0.08), DRESSED.darkened(0.1))
	b.box("dressed", Vector3(3.0, FLOOR_Y * 0.5, 1.0), Vector3(0.0, FLOOR_Y * 0.25, 0.5), DRESSED.darkened(0.15))
	b.box("dressed", Vector3(2.5, FLOOR_Y * 0.5, 0.55), Vector3(0.0, FLOOR_Y * 0.75, 0.275), DRESSED.darkened(0.08))

# The double doors: planks, each its own mesh so that _refresh() can break them.
func _hang_doors(hl: float) -> void:
	var board := BoxMesh.new()
	board.size = Vector3(DOOR_W / float(PLANKS) - 0.015, DOOR_H - 0.03, 0.07)
	var dark := Look.wood(Color(0.17, 0.125, 0.095))
	for i in PLANKS:
		var plank := MeshInstance3D.new()
		plank.name = "Plank%d" % i
		plank.mesh = board
		plank.material_override = dark
		plank.position = Vector3(-DOOR_W * 0.5 + DOOR_W * (float(i) + 0.5) / float(PLANKS), FLOOR_Y + DOOR_H * 0.5, hl + 0.1)
		add_child(plank)
		_planks.append(plank)
		_rest.append(plank.transform)

# The tower: plain to the belfry, four piers round the bell, a slated cap and a vane.
func _tower(b: HarbourProps.Batch) -> void:
	var c := TOWER_AT
	var half := TOWER * 0.5
	b.box("stone", Vector3(TOWER, BELFRY_Y, TOWER), c + Vector3(0.0, BELFRY_Y * 0.5, 0.0), WALL.darkened(0.04))
	b.box("stone", Vector3(TOWER + 0.16, 0.4, TOWER + 0.16), c + Vector3(0.0, 0.2, 0.0), WALL.darkened(0.2))
	b.box("dressed", Vector3(TOWER + 0.14, 0.14, TOWER + 0.14), c + Vector3(0.0, BELFRY_Y, 0.0), DRESSED)
	b.box("paint", Vector3(TOWER - 0.1, 0.03, TOWER - 0.1), c + Vector3(0.0, BELFRY_Y + 0.085, 0.0), Color(0.16, 0.17, 0.19))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			b.box("stone", Vector3(PIER, BELFRY_TOP - BELFRY_Y, PIER), c + Vector3(sx * (half - PIER * 0.5), (BELFRY_TOP + BELFRY_Y) * 0.5, sz * (half - PIER * 0.5)), WALL.darkened(0.04))
	b.box("stone", Vector3(TOWER, TOWER_H - BELFRY_TOP, TOWER), c + Vector3(0.0, (TOWER_H + BELFRY_TOP) * 0.5, 0.0), WALL.darkened(0.04))
	b.box("dressed", Vector3(TOWER + 0.2, 0.14, TOWER + 0.2), c + Vector3(0.0, TOWER_H + 0.07, 0.0), DRESSED)
	# The cap: four slated faces to a point.
	var foot := half + 0.2
	var base_y := TOWER_H + 0.14
	var top := c + Vector3(0.0, base_y + SPIRE_H, 0.0)
	var tile := HarbourProps.roof_tile("slate")
	var slant := Vector2(foot, SPIRE_H).length() / tile
	for k in 4:
		var turn := Basis(Vector3.UP, PI * 0.5 * float(k))
		b.tri("roof_slate", c + turn * Vector3(-foot, base_y, foot), c + turn * Vector3(foot, base_y, foot), top, Color.WHITE,
			PackedVector2Array([Vector2(-foot / tile, slant), Vector2(foot / tile, slant), Vector2(0.0, 0.0)]))
	b.box("paint", Vector3(foot * 2.0, 0.05, foot * 2.0), c + Vector3(0.0, base_y - 0.02, 0.0), Color(0.16, 0.17, 0.19))
	b.rod("paint", top - Vector3(0.0, 0.1, 0.0), top + Vector3(0.0, 1.0, 0.0), 0.025, BLACK, 4)
	b.ball("paint", Vector3(0.1, 0.1, 0.1), top + Vector3(0.0, 0.35, 0.0), Color(0.75, 0.6, 0.25), 6, 4)
	b.box("paint", Vector3(0.62, 0.04, 0.02), top + Vector3(0.05, 0.85, 0.0), BLACK)
	b.box("paint", Vector3(0.2, 0.22, 0.02), top + Vector3(-0.3, 0.85, 0.0), BLACK)
	# The front of the tower: two slit windows, and the clock, stopped.
	b.xf = Transform3D(Basis.IDENTITY, c + Vector3(0.0, 0.0, half))
	_lancet(b, 0.0, 1.9, 0.36, 0.7, 0.4)
	_lancet(b, 0.0, 3.5, 0.36, 0.7, 0.4)
	var face := Vector3(0.0, 5.35, 0.0)
	var flat_on := Basis(Vector3.RIGHT, PI * 0.5)
	b.cyl("dressed", 0.7, 0.7, 0.05, face + Vector3(0.0, 0.0, 0.025), DRESSED.darkened(0.3), 16, flat_on)
	b.cyl("paint", 0.6, 0.6, 0.03, face + Vector3(0.0, 0.0, 0.055), Color(0.84, 0.82, 0.72), 16, flat_on)
	b.box("paint", Vector3(0.05, 0.34, 0.012), face + Basis(Vector3.BACK, -0.1) * Vector3(0.0, 0.15, 0.0) + Vector3(0.0, 0.0, 0.078), BLACK, Basis(Vector3.BACK, -0.1))
	b.box("paint", Vector3(0.035, 0.5, 0.012), face + Basis(Vector3.BACK, 0.5) * Vector3(0.0, 0.23, 0.0) + Vector3(0.0, 0.0, 0.084), BLACK, Basis(Vector3.BACK, 0.5))
	b.xf = Transform3D.IDENTITY

# The bell on its headstock, hung just inside the belfry's front opening so that it
# shows from above under the cap; ring() swings it out through the opening and back.
func _hang_bell() -> void:
	_bell = Node3D.new()
	_bell.name = "Bell"
	_bell.position = TOWER_AT + Vector3(0.0, 7.95, TOWER * 0.5 - 0.5)
	add_child(_bell)
	var b := HarbourProps.Batch.new()
	b.box("wood", Vector3(TOWER - PIER * 2.0 + 0.2, 0.2, 0.22), Vector3(0.0, 0.06, 0.0), Color(0.3, 0.24, 0.18))
	var profile := [[0.13, 0.0], [0.2, -0.12], [0.27, -0.42], [0.33, -0.68], [0.45, -0.84]]
	for i in profile.size() - 1:
		var r_top: float = profile[i][0]
		var y_top: float = profile[i][1]
		var r_low: float = profile[i + 1][0]
		var y_low: float = profile[i + 1][1]
		b.cyl("bronze", r_low, r_top, y_top - y_low, Vector3(0.0, (y_top + y_low) * 0.5 - 0.04, 0.0), Color.WHITE, 10, Basis.IDENTITY, 0.0, TAU, i == 0)
	b.cyl("paint", 0.42, 0.42, 0.01, Vector3(0.0, -0.875, 0.0), BLACK, 10)
	b.ball("paint", Vector3(0.075, 0.075, 0.075), Vector3(0.0, -0.9, 0.0), BLACK, 6, 4)
	var bronze := Look.flat_mat(Color(0.55, 0.38, 0.16), 0.35)
	bronze.metallic = 0.7
	b.build(_bell, {"bronze": bronze})
