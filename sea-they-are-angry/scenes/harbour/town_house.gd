class_name TownHouse
extends StaticBody3D
## A building on Kirkhaven's harbour front: harled walls, a slate or pantile roof with
## the ridge along x, its FRONT facing +Z (the sea, and the camera). Set the vars below
## before it enters the tree; it builds itself in _ready(), dark, and set_lit() brings
## its windows up. One mesh per material (HarbourProps.Batch), no script running after.

const WINDOW_DARK := Color(0.06, 0.075, 0.1)
const WINDOW_LIT := Color(1.0, 0.72, 0.38)
const WINDOW_GLOW := 2.0
const LAMP_ENERGY := 1.3
const LAMP_RANGE := 5.0
## Wall height from which a building has an upstairs.
const TWO_STOREY := 4.5
const MAX_RISE := 3.4
const EAVES := 0.3
const VERGE := 0.18
const ROOF_T := 0.1
const PLINTH := 0.3
const STEP := 0.15
const WIN_W := 0.9
const WIN_H := 1.35
const SILL := 0.95
const DOOR_W := 0.95
const DOOR_H := 2.0
const FASCIA_H := 0.62
const FASCIA_TILT := 0.3
const LEAN_TO := Vector3(2.6, 1.9, 1.4)
const PITCH := {"slate": 42.0, "pantile": 38.0, "corrugated": 24.0}
const TRIMS := [Color(0.08, 0.08, 0.09), Color(0.3, 0.2, 0.14), Color(0.2, 0.28, 0.38), Color(0.62, 0.56, 0.42), Color(0.16, 0.26, 0.2), Color(0.45, 0.14, 0.11)]
const DOORS := [Color(0.1, 0.22, 0.16), Color(0.1, 0.14, 0.28), Color(0.4, 0.09, 0.08), Color(0.07, 0.07, 0.08), Color(0.3, 0.2, 0.13), Color(0.3, 0.42, 0.5)]
const SHOPFRONTS := [Color(0.1, 0.2, 0.15), Color(0.36, 0.08, 0.08), Color(0.09, 0.13, 0.26), Color(0.07, 0.07, 0.08), Color(0.2, 0.3, 0.36)]
const GILT := Color(0.9, 0.78, 0.45)
const SILL_STONE := Color(0.74, 0.71, 0.65)
const PLINTH_STONE := Color(0.62, 0.6, 0.56)
const BLACK := Color(0.07, 0.07, 0.08)

## Width along x, wall height to the eaves, depth along z. The origin is at ground
## level in the middle of the footprint.
var size := Vector3(7.0, 3.0, 6.0)
## "cottage" (one storey, a door and two windows, a chimney), "house" (two storeys:
## for size.y of 4.5 and over), "shop" (a big window, a door, a painted fascia), "pub"
## (as a shop, a hanging sign, two chimneys), "shed" (a fish shed or ice house: wide
## double doors, no chimney, no front windows), "office" (the harbour office: small, a
## noticeboard by the door). Any of them but the shed has an upstairs from 4.5 m.
var style := "cottage"
## Painted on the fascia of a shop or pub and the board of an office or shed.
var sign_text := ""
## The wall colour: harl or whitewash.
var harl := Color(0.82, 0.80, 0.74)
## "slate" or "pantile"; also "corrugated". A shed left at "slate" has a corrugated
## iron roof on odd seeds.
var roof := "slate"
## Varies the small things: which gable the chimney is on, crow steps or skews, the
## paint, which windows are lit, a drainpipe, a lean-to at the back.
var seed_value := 0
## A lean-to (on some seeds) stands 1.4 m out from the BACK wall, past the footprint.
var allow_lean_to := true
## Whether the windows are (or are coming) lit: use set_lit().
var lit := false

var _glass: StandardMaterial3D
var _lamp: OmniLight3D
var _glow := 0.0
var _tween: Tween
var _lit_col := WINDOW_LIT
var _trim := Color.WHITE
var _margins := true
var _frame := Color(0.86, 0.85, 0.8)
var _door_col := Color.WHITE
var _door_x := 0.0
var _storeys := 1
var _pitch := 0.0
var _ridge := 0.0
var _roof_tint := Color.WHITE

func _ready() -> void:
	collision_layer = HarbourProps.SOLID_LAYER
	collision_mask = 0
	_build()
	_show_glow(1.0 if lit else 0.0)

## Windows from dark glass to a warm glow (or back) over `fade` seconds, and the light
## they throw on the street outside.
func set_lit(on: bool, fade: float = 1.5) -> void:
	lit = on
	if _glass == null:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var to := 1.0 if on else 0.0
	if fade <= 0.0 or not is_inside_tree():
		_show_glow(to)
		return
	_tween = create_tween()
	_tween.tween_method(_show_glow, _glow, to, fade)

func _show_glow(k: float) -> void:
	_glow = k
	_glass.albedo_color = WINDOW_DARK.lerp(_lit_col, k * 0.7)
	_glass.emission_energy_multiplier = WINDOW_GLOW * k
	_lamp.light_energy = LAMP_ENERGY * k
	_lamp.visible = k > 0.001

## The top of the roof at `z` from the ridge line.
func _roof_y(z: float) -> float:
	return _ridge - absf(z) * tan(_pitch)

func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_value * 7919 + 31)
	var hw := size.x * 0.5
	var hd := size.z * 0.5
	var shed := style == "shed"
	_storeys = 2 if size.y >= TWO_STOREY and not shed else 1
	Geo.box_shape(self, size, Vector3(0.0, size.y * 0.5, 0.0))
	# The paint: window margins in a colour (or none), the door, the lit rooms' warmth.
	_margins = rng.randf() < 0.7
	_trim = TRIMS[rng.randi() % TRIMS.size()]
	_door_col = DOORS[rng.randi() % DOORS.size()]
	_lit_col = WINDOW_LIT.lerp(Color(1.0, 0.86, 0.6), rng.randf() * 0.6)
	var covering := roof
	if shed and roof == "slate" and seed_value % 2 != 0:
		covering = "corrugated"
	var degrees: float = PITCH.get(covering, 40.0)
	if shed and covering == "slate":
		degrees = 34.0
	var rise := minf(hd * tan(deg_to_rad(degrees)), MAX_RISE)
	_pitch = atan(rise / hd)
	_ridge = size.y + rise + ROOF_T / cos(_pitch)
	# The gables: a plain verge, stone skews, or crow steps.
	var gable := 0
	if not shed:
		var pick := rng.randf()
		gable = 2 if pick < 0.3 else (1 if pick < 0.75 else 0)
	var over := VERGE if gable == 0 else 0.0
	var b := HarbourProps.Batch.new()
	# Walls on a stone footing, the gables filled in to the roof.
	b.box("wall", size, Vector3(0.0, size.y * 0.5, 0.0))
	b.tri("wall", Vector3(hw, size.y, hd), Vector3(hw, size.y, -hd), Vector3(hw, size.y + rise, 0.0))
	b.tri("wall", Vector3(-hw, size.y, -hd), Vector3(-hw, size.y, hd), Vector3(-hw, size.y + rise, 0.0))
	b.box("stone", Vector3(size.x + 0.1, PLINTH, size.z + 0.1), Vector3(0.0, PLINTH * 0.5, 0.0), PLINTH_STONE)
	var roof_key := "roof_" + covering
	# Skews and crow steps sit on the roof's ends: it stops just short of the gable's face.
	var shade := rng.randf_range(0.8, 1.05)
	_roof_tint = Color(shade, shade * rng.randf_range(0.96, 1.02), shade * rng.randf_range(0.92, 1.04))
	HarbourProps.pitched_roof(b, roof_key, hw + (over if gable == 0 else -0.05), hd + EAVES, _ridge, _pitch, HarbourProps.roof_tile(covering), ROOF_T, _roof_tint)
	_ridge_and_gutters(b, covering, hw + over, hd, rng)
	if gable == 1:
		_skews(b, hw, hd)
	elif gable == 2:
		_crow_steps(b, hw, hd)
	# Chimneys on the gables.
	var stacks := 0 if shed else (2 if style == "pub" or (_storeys == 2 and rng.randf() < 0.5) else 1)
	var first := 1.0 if rng.randf() < 0.5 else -1.0
	for i in stacks:
		_chimney(b, (first if i == 0 else -first) * (hw - 0.36), rng)
	if not shed and rng.randf() < 0.3:
		_rooflight(b, rng.randf_range(-hw * 0.5, hw * 0.5), hd, rng.randf() < 0.6)
	# The front.
	b.xf = Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, hd))
	match style:
		"shop":
			_shop_front(b, rng)
		"pub":
			_pub_front(b, rng)
		"shed":
			_shed_front(b, rng)
		"office":
			_office_front(b, rng)
		_:
			_house_front(b, rng)
	# The back: a window or two a floor, and on some a lean-to.
	b.xf = Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, 0.0, -hd))
	var lean_side := 0.0
	if allow_lean_to and not shed and size.x >= 6.0 and rng.randf() < 0.35:
		lean_side = 1.0 if rng.randf() < 0.5 else -1.0
		_lean_to(b, lean_side * (hw - LEAN_TO.x * 0.5 - 0.3), roof_key, covering)
	for storey in _storeys:
		var sill := SILL + 0.1 if storey == 0 else _upper_sill()
		var spots := [-hw * 0.5, 0.0, hw * 0.5]
		spots.remove_at(rng.randi() % 3)
		if shed:
			spots = [0.0]
		for x: float in spots:
			if storey == 0 and lean_side != 0.0 and x * lean_side > -0.2:
				continue
			_sash(b, x, sill, 0.8, 1.1, rng.randf() < 0.6 and not shed)
	b.xf = Transform3D.IDENTITY
	_glass = Look.glow_mat(WINDOW_DARK, 0.0)
	_glass.emission = _lit_col
	_glass.roughness = 0.2
	b.build(self, {"wall": HarbourProps.harl_mat(harl), "glass": _glass})
	_lamp = OmniLight3D.new()
	_lamp.light_color = _lit_col
	_lamp.omni_range = LAMP_RANGE
	_lamp.shadow_enabled = false
	_lamp.position = Vector3(_door_x, 2.0, hd + 1.0)
	add_child(_lamp)

func _upper_sill() -> float:
	return maxf(size.y - 0.4 - 1.2, SILL + WIN_H + 0.45)

# ---- roof ----

# The ridge, a gutter along each eaves, a downpipe at one front corner.
func _ridge_and_gutters(b: HarbourProps.Batch, covering: String, half_len: float, hd: float, rng: RandomNumberGenerator) -> void:
	match covering:
		"pantile":
			# Half-round clay ridge tiles.
			b.cyl("paint", 0.14, 0.14, half_len * 2.0 + 0.04, Vector3(0.0, _ridge - 0.05, 0.0), Color(0.46, 0.2, 0.13), 6, Basis(Vector3.BACK, -PI * 0.5), PI * 0.5, PI * 1.5, true)
		"corrugated":
			b.box("paint", Vector3(half_len * 2.0 + 0.04, 0.05, 0.3), Vector3(0.0, _ridge, 0.0), Color(0.3, 0.31, 0.3))
		_:
			b.box("paint", Vector3(half_len * 2.0 + 0.04, 0.1, 0.26), Vector3(0.0, _ridge - 0.01, 0.0), Color(0.2, 0.21, 0.24))
	var eaves_y := _roof_y(hd + EAVES)
	for sz: float in [1.0, -1.0]:
		b.box("paint", Vector3(half_len * 2.0, 0.07, 0.11), Vector3(0.0, eaves_y - 0.13, sz * (hd + EAVES + 0.045)), BLACK)
	var px := (1.0 if rng.randf() < 0.5 else -1.0) * (size.x * 0.5 - 0.18)
	var top := Vector3(px, eaves_y - 0.17, hd + EAVES + 0.045)
	var bend := Vector3(px, eaves_y - 0.55, hd + 0.07)
	b.rod("paint", top, bend, 0.04, BLACK, 5)
	b.rod("paint", bend, Vector3(px, 0.12, hd + 0.07), 0.04, BLACK, 5)

# Skews: a flat stone coping up each gable, standing a little proud of the slates.
func _skews(b: HarbourProps.Batch, hw: float, hd: float) -> void:
	var span := hd + 0.14
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			b.box("dressed", Vector3(0.3, 0.14, span / cos(_pitch) + 0.04), Vector3(sx * (hw - 0.15), _roof_y(span * 0.5) + 0.04, sz * span * 0.5), SILL_STONE, Basis(Vector3.RIGHT, sz * _pitch))
			b.box("dressed", Vector3(0.36, 0.24, 0.3), Vector3(sx * (hw - 0.15), _roof_y(span) + 0.02, sz * span), SILL_STONE)

# Crow steps (corbie steps) up each gable, a flat stone on every step.
func _crow_steps(b: HarbourProps.Batch, hw: float, hd: float) -> void:
	var span := hd + 0.12
	var n := clampi(roundi(span / 0.5), 3, 8)
	var run := span / float(n)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			for i in n:
				var z_out := span - float(i) * run
				var z_in := z_out - run
				var top := _roof_y(z_in) + 0.14
				var low := _roof_y(z_out) - 0.3
				var at := Vector3(sx * (hw - 0.16), (top + low) * 0.5, sz * (z_in + z_out) * 0.5)
				b.box("wall", Vector3(0.32, top - low, run), at)
				b.box("dressed", Vector3(0.38, 0.05, run + 0.03), Vector3(at.x, top + 0.025, at.z), SILL_STONE)

# A stack astride the gable with a stone cope and clay pots.
func _chimney(b: HarbourProps.Batch, x: float, rng: RandomNumberGenerator) -> void:
	var top := _ridge + 0.95
	var low := _ridge - 0.75
	var harled := rng.randf() < 0.5
	b.box("wall" if harled else "stone", Vector3(0.62, top - low, 1.05), Vector3(x, (top + low) * 0.5, 0.0), Color(0.72, 0.69, 0.63))
	b.box("dressed", Vector3(0.74, 0.1, 1.17), Vector3(x, top + 0.05, 0.0), SILL_STONE.darkened(0.1))
	var pots := 1 + rng.randi() % 2 if _storeys == 1 else 2
	var clay := Color(0.6, 0.34, 0.22) if rng.randf() < 0.6 else Color(0.7, 0.6, 0.44)
	for i in pots:
		var z := (float(i) - float(pots - 1) * 0.5) * 0.44
		b.cyl("paint", 0.13, 0.1, 0.4, Vector3(x, top + 0.3, z), clay, 8)
		b.cyl("paint", 0.075, 0.075, 0.01, Vector3(x, top + 0.503, z), BLACK, 8)

# A cast-iron rooflight on the front slope.
func _rooflight(b: HarbourProps.Batch, x: float, hd: float, on: bool) -> void:
	var z := hd * 0.5
	var keep := b.xf
	b.xf = Transform3D(Basis(Vector3.RIGHT, _pitch), Vector3(x, _roof_y(z), z))
	b.box("paint", Vector3(0.7, 0.07, 0.95), Vector3(0.0, 0.02, 0.0), BLACK)
	b.box("glass" if on else "glass_off", Vector3(0.56, 0.02, 0.8), Vector3(0.0, 0.06, 0.0))
	b.box("paint", Vector3(0.03, 0.03, 0.8), Vector3(0.0, 0.075, 0.0), BLACK)
	b.xf = keep

# ---- parts of a wall (drawn in the wall's frame: x along it, z out from its face) ----

# A two-over-two sash window with its sill, and a painted margin round it.
func _sash(b: HarbourProps.Batch, x: float, sill: float, w: float, h: float, on: bool) -> void:
	var mid := sill + h * 0.5
	if _margins:
		b.box("paint", Vector3(w + 0.3, h + 0.3, 0.03), Vector3(x, mid, 0.015), _trim)
	b.box("glass" if on else "glass_off", Vector3(w, h, 0.02), Vector3(x, mid, 0.04))
	for sy: float in [-1.0, 1.0]:
		b.box("paint", Vector3(w + 0.04, 0.07, 0.03), Vector3(x, mid + sy * h * 0.5, 0.06), _frame)
		b.box("paint", Vector3(0.07, h, 0.03), Vector3(x + sy * w * 0.5, mid, 0.06), _frame)
	b.box("paint", Vector3(w, 0.06, 0.035), Vector3(x, mid, 0.065), _frame)
	b.box("paint", Vector3(0.035, h, 0.025), Vector3(x, mid, 0.058), _frame)
	b.box("dressed", Vector3(w + 0.34, 0.09, 0.2), Vector3(x, sill - 0.045, 0.1), SILL_STONE)

# A panelled door on its step, a light over it.
func _door(b: HarbourProps.Batch, x: float, fanlight: bool = true) -> void:
	var top := STEP + DOOR_H
	var head := top + (0.32 if fanlight else 0.0)
	if _margins:
		b.box("paint", Vector3(DOOR_W + 0.3, head + 0.15, 0.03), Vector3(x, (head + 0.15) * 0.5, 0.015), _trim)
	b.box("paint", Vector3(DOOR_W, DOOR_H, 0.04), Vector3(x, STEP + DOOR_H * 0.5, 0.046), _door_col)
	for sx: float in [-1.0, 1.0]:
		for row in 2:
			b.box("paint", Vector3(DOOR_W * 0.33, DOOR_H * (0.3 if row == 0 else 0.42), 0.012), Vector3(x + sx * DOOR_W * 0.22, STEP + DOOR_H * (0.24 if row == 0 else 0.7), 0.07), _door_col.darkened(0.25))
	b.box("paint", Vector3(0.05, 0.05, 0.03), Vector3(x + DOOR_W * 0.38, STEP + 1.0, 0.08), Color(0.7, 0.58, 0.25))
	if fanlight:
		b.box("glass", Vector3(DOOR_W, 0.26, 0.02), Vector3(x, top + 0.17, 0.04))
		b.box("paint", Vector3(DOOR_W + 0.04, 0.05, 0.03), Vector3(x, top + 0.02, 0.06), _frame)
		b.box("paint", Vector3(DOOR_W + 0.04, 0.05, 0.03), Vector3(x, head, 0.06), _frame)
	b.box("dressed", Vector3(DOOR_W + 0.5, STEP, 0.5), Vector3(x, STEP * 0.5, 0.3), SILL_STONE.darkened(0.12))
	_door_x = x

# A bulkhead lamp on the wall (lit with the windows).
func _wall_lamp(b: HarbourProps.Batch, x: float, y: float) -> void:
	b.box("paint", Vector3(0.3, 0.2, 0.06), Vector3(x, y, 0.03), BLACK)
	b.box("glass", Vector3(0.22, 0.13, 0.08), Vector3(x, y, 0.08))

# A painted board canted back to face the high camera, with the sign on it. Close under
# the eaves it would be hidden from above, so there it stands out past them, boxed in.
func _fascia(b: HarbourProps.Batch, x: float, y: float, width: float, height: float, board: Color, letters: Color) -> void:
	var cant := Basis(Vector3.RIGHT, -FASCIA_TILT)
	var top_y := y + height * 0.5 * cos(FASCIA_TILT)
	var low_y := y - height * 0.5 * cos(FASCIA_TILT)
	var out := 0.06 if top_y < size.y - 0.9 else EAVES + 0.17
	var low_z := out + height * sin(FASCIA_TILT)
	var at := Vector3(x, y, (out + low_z) * 0.5)
	var pale := board.lightened(0.12)
	b.box("paint", Vector3(width, height, 0.05), at, board, cant)
	b.box("paint", Vector3(width + 0.14, 0.06, 0.12), at + cant * Vector3(0.0, height * 0.5 + 0.03, 0.0), pale, cant)
	b.box("paint", Vector3(width + 0.08, 0.05, 0.08), at + cant * Vector3(0.0, -height * 0.5 - 0.02, 0.0), pale, cant)
	if out > 0.1:
		b.box("paint", Vector3(width, 0.04, low_z), Vector3(x, low_y, low_z * 0.5), board.darkened(0.3))
		for sx: float in [-1.0, 1.0]:
			var ex := x + sx * width * 0.5
			b.poly("paint", PackedVector3Array([Vector3(ex, top_y, 0.0), Vector3(ex, top_y, out), Vector3(ex, low_y, low_z), Vector3(ex, low_y, 0.0)]), pale, Vector3(sx, 0.0, 0.0))
	if sign_text.strip_edges() == "":
		return
	var label := HarbourProps.lettering(sign_text, width * 0.9, height * 0.66, letters)
	label.transform = b.xf * Transform3D(cant, at + cant * Vector3(0.0, 0.0, 0.032))
	add_child(label)

# ---- fronts ----

# Cottage or house: a door and sash windows, bay by bay, the same again upstairs.
func _house_front(b: HarbourProps.Batch, rng: RandomNumberGenerator) -> void:
	var bays := clampi(roundi(size.x / 2.4), 2, 5)
	var side := 0.45
	var bay := (size.x - side * 2.0) / float(bays)
	var door_bay := bays / 2
	if bays % 2 == 0:
		door_bay -= rng.randi() % 2
	var w := minf(WIN_W, bay - 0.55)
	var h := minf(WIN_H, size.y - SILL - 0.4)
	for i in bays:
		var x := -size.x * 0.5 + side + bay * (float(i) + 0.5)
		if i == door_bay:
			_door(b, x, size.y >= STEP + DOOR_H + 0.6)
		else:
			_sash(b, x + rng.randf_range(-0.1, 0.1), SILL, w, h, rng.randf() < 0.8)
		if _storeys == 2:
			_sash(b, x, _upper_sill(), w, 1.2, rng.randf() < 0.65)

# A shop: one big window over a stall riser, the door beside it, pilasters, and the
# fascia over all with the name on it.
func _shop_front(b: HarbourProps.Batch, rng: RandomNumberGenerator) -> void:
	var paint: Color = SHOPFRONTS[rng.randi() % SHOPFRONTS.size()]
	var head := minf(2.45, size.y - 0.72)
	var span := size.x - 0.8
	var way := 1.0 if rng.randf() < 0.5 else -1.0
	var post := 0.16
	var door_zone := DOOR_W + 0.1
	var win_w := span - post * 3.0 - door_zone
	var win_x := way * (-span * 0.5 + post + win_w * 0.5)
	var door_x := way * (span * 0.5 - post - door_zone * 0.5)
	b.box("paint", Vector3(span, head, 0.06), Vector3(0.0, head * 0.5, 0.03), paint)
	for s: float in [0.0, post + win_w, span - post]:
		b.box("paint", Vector3(post, head, 0.05), Vector3(way * (-span * 0.5 + s + post * 0.5), head * 0.5, 0.08), paint.lightened(0.14))
	# The window: a sill board, mullions, a transom with toplights over it.
	var riser := 0.62
	b.box("glass", Vector3(win_w, head - riser - 0.1, 0.02), Vector3(win_x, (riser + head - 0.1) * 0.5, 0.07))
	b.box("paint", Vector3(win_w + 0.06, 0.07, 0.16), Vector3(win_x, riser - 0.03, 0.11), paint.lightened(0.14))
	b.box("paint", Vector3(win_w - 0.3, riser - 0.3, 0.02), Vector3(win_x, riser * 0.5 + 0.02, 0.068), paint.darkened(0.25))
	b.box("paint", Vector3(win_w, 0.05, 0.03), Vector3(win_x, head - 0.5, 0.09), paint.lightened(0.14))
	var lights := maxi(2, roundi(win_w / 1.2))
	for i in range(1, lights):
		b.box("paint", Vector3(0.05, head - riser - 0.1, 0.03), Vector3(win_x - win_w * 0.5 + win_w * float(i) / float(lights), (riser + head - 0.1) * 0.5, 0.09), paint.lightened(0.14))
	# The door: half glazed, a light over it.
	b.box("paint", Vector3(DOOR_W, DOOR_H, 0.04), Vector3(door_x, STEP + DOOR_H * 0.5, 0.075), paint.lightened(0.05))
	b.box("glass", Vector3(DOOR_W - 0.26, 0.9, 0.02), Vector3(door_x, STEP + 1.4, 0.09))
	b.box("paint", Vector3(DOOR_W - 0.26, 0.6, 0.012), Vector3(door_x, STEP + 0.45, 0.098), paint.darkened(0.25))
	b.box("paint", Vector3(0.04, 0.16, 0.04), Vector3(door_x - way * (DOOR_W * 0.5 - 0.1), STEP + 1.0, 0.11), Color(0.7, 0.58, 0.25))
	if head > STEP + DOOR_H + 0.2:
		b.box("glass", Vector3(DOOR_W, head - STEP - DOOR_H - 0.12, 0.02), Vector3(door_x, (head + STEP + DOOR_H) * 0.5 - 0.02, 0.07))
	b.box("dressed", Vector3(DOOR_W + 0.4, STEP, 0.5), Vector3(door_x, STEP * 0.5, 0.3), SILL_STONE.darkened(0.12))
	_door_x = door_x
	_fascia(b, 0.0, head + FASCIA_H * 0.5 * cos(FASCIA_TILT) + 0.04, span + 0.1, FASCIA_H, paint.darkened(0.15), GILT)
	_upstairs(b, rng)

# A pub: two broad windows and the door between, the name across the front, and a
# painted board hung out on an iron bracket.
func _pub_front(b: HarbourProps.Batch, rng: RandomNumberGenerator) -> void:
	var paint: Color = SHOPFRONTS[rng.randi() % SHOPFRONTS.size()]
	_trim = paint
	_margins = true
	_door_col = paint.lightened(0.05)
	var head := minf(2.45, size.y - 0.72)
	var bays := 3 if size.x < 10.0 else 5
	var side := 0.5
	var bay := (size.x - side * 2.0) / float(bays)
	var h := head - 0.85 - 0.2
	for i in bays:
		var x := -size.x * 0.5 + side + bay * (float(i) + 0.5)
		if i == bays / 2:
			_door(b, x, head > STEP + DOOR_H + 0.4)
		else:
			_sash(b, x, 0.85, minf(1.6, bay - 0.7), h, rng.randf() < 0.9)
	_fascia(b, 0.0, head + FASCIA_H * 0.5 * cos(FASCIA_TILT) + 0.04, size.x - 0.8, FASCIA_H, BLACK.lerp(paint, 0.25), GILT)
	_upstairs(b, rng)
	# The hanging sign, square to the wall.
	var way := 1.0 if rng.randf() < 0.5 else -1.0
	var x := way * (size.x * 0.5 - 0.55)
	var y := minf(size.y - 0.14, head + 1.75)
	b.rod("paint", Vector3(x, y, 0.0), Vector3(x, y, 1.1), 0.028, BLACK, 5)
	if _storeys == 2:
		b.rod("paint", Vector3(x, y + 0.5, 0.0), Vector3(x, y, 0.75), 0.02, BLACK, 4)
	for z: float in [0.48, 0.92]:
		b.rod("paint", Vector3(x, y, z), Vector3(x, y - 0.12, z), 0.012, BLACK, 3)
	b.box("paint", Vector3(0.05, 0.74, 0.6), Vector3(x, y - 0.49, 0.7), BLACK)
	b.box("paint", Vector3(0.07, 0.62, 0.48), Vector3(x, y - 0.49, 0.7), paint.lightened(0.1))
	b.box("paint", Vector3(0.08, 0.2, 0.26), Vector3(x, y - 0.44, 0.7), GILT)

# A fish shed or ice house: wide boarded double doors on strap hinges, a concrete
# apron, a lamp on the wall, a board over the doors if it has a name.
func _shed_front(b: HarbourProps.Batch, rng: RandomNumberGenerator) -> void:
	var door_w := minf(3.4, size.x - 1.5)
	var door_h := clampf(size.y - 1.0, 2.2, 2.8)
	var boards: Color = [Color(0.2, 0.34, 0.3), Color(0.42, 0.16, 0.12), Color(0.24, 0.32, 0.42), Color(0.5, 0.46, 0.4)][rng.randi() % 4]
	b.box("paint", Vector3(door_w + 0.3, door_h + 0.2, 0.05), Vector3(0.0, (door_h + 0.2) * 0.5, 0.025), BLACK.lightened(0.1))
	for sx: float in [-1.0, 1.0]:
		var leaf_x := sx * door_w * 0.25
		b.box("wood", Vector3(door_w * 0.5 - 0.03, door_h - 0.06, 0.05), Vector3(leaf_x, door_h * 0.5 + 0.02, 0.075), boards)
		for ledge: float in [0.3, door_h * 0.5, door_h - 0.3]:
			b.box("wood", Vector3(door_w * 0.5 - 0.1, 0.14, 0.03), Vector3(leaf_x, ledge, 0.115), boards.darkened(0.2))
			b.box("paint", Vector3(door_w * 0.3, 0.05, 0.012), Vector3(sx * (door_w * 0.5 - door_w * 0.15), ledge, 0.136), BLACK)
	b.box("paint", Vector3(0.12, 0.3, 0.04), Vector3(0.0, door_h * 0.45, 0.13), BLACK)
	b.box("dressed", Vector3(door_w + 0.8, 0.07, 1.0), Vector3(0.0, 0.035, 0.52), Color(0.6, 0.6, 0.58))
	_wall_lamp(b, door_w * 0.5 + 0.5, minf(2.5, size.y - 0.35))
	_door_x = 0.0
	if sign_text.strip_edges() != "" and size.y - door_h > 0.75:
		_fascia(b, 0.0, door_h + 0.2 + (size.y - door_h - 0.2) * 0.45, minf(door_w, 3.0), minf(0.55, size.y - door_h - 0.45), Color(0.8, 0.78, 0.7), Color(0.1, 0.12, 0.2))
	# Louvred vents on the ridge.
	b.xf = Transform3D.IDENTITY
	for vx: float in [-size.x * 0.22, size.x * 0.22]:
		b.box("paint", Vector3(0.5, 0.3, 0.4), Vector3(vx, _ridge + 0.1, 0.0), Color(0.24, 0.25, 0.25))
		b.box("paint", Vector3(0.64, 0.04, 0.54), Vector3(vx, _ridge + 0.27, 0.0), Color(0.3, 0.31, 0.3))

# The harbour office: a door, a window, the noticeboard beside the door, a lamp over
# it and a painted board with its name.
func _office_front(b: HarbourProps.Batch, rng: RandomNumberGenerator) -> void:
	var way := 1.0 if rng.randf() < 0.5 else -1.0
	_door_col = Color(0.1, 0.16, 0.3)
	var door_x := -way * size.x * 0.14
	var has_light := size.y >= STEP + DOOR_H + 1.2
	_door(b, door_x, has_light)
	_sash(b, way * size.x * 0.27, SILL, minf(1.1, size.x * 0.22), minf(WIN_H, size.y - SILL - 0.4), true)
	if _storeys == 2:
		_sash(b, way * size.x * 0.27, _upper_sill(), WIN_W, 1.2, rng.randf() < 0.5)
		_sash(b, door_x, _upper_sill(), WIN_W, 1.2, rng.randf() < 0.5)
	# The noticeboard: tide tables and notices to mariners under a little pent.
	var board_w := minf(0.85, size.x * 0.17)
	var board_x := -way * (size.x * 0.5 - 0.3 - board_w * 0.5)
	b.box("paint", Vector3(board_w, 0.75, 0.05), Vector3(board_x, 1.5, 0.025), Color(0.1, 0.2, 0.15))
	b.box("paint", Vector3(board_w + 0.12, 0.04, 0.14), Vector3(board_x, 1.9, 0.06), BLACK)
	for i in 3:
		var paper := Vector3(board_w * 0.36, rng.randf_range(0.2, 0.3), 0.01)
		b.box("paint", paper, Vector3(board_x + (float(i % 2) - 0.5) * board_w * 0.46, 1.66 - 0.31 * float(i / 2) - paper.y * 0.5 + 0.14, 0.055), Color(0.86, 0.84, 0.74).darkened(0.1 * float(i)))
	var over_door := STEP + DOOR_H + (0.32 if has_light else 0.0) + 0.15
	var room := size.y - over_door - 0.25
	if sign_text.strip_edges() != "" and room > 0.25:
		var board_h := minf(0.5, room)
		_fascia(b, way * size.x * 0.06, over_door + 0.08 + board_h * 0.5, minf(size.x - 1.6, 3.4), board_h, Color(0.84, 0.83, 0.77), Color(0.08, 0.12, 0.26))
		_wall_lamp(b, door_x - way * (DOOR_W * 0.5 + 0.4), STEP + DOOR_H - 0.2)
	else:
		_wall_lamp(b, door_x, over_door + 0.15)

# The windows of a floor over a shop or pub.
func _upstairs(b: HarbourProps.Batch, rng: RandomNumberGenerator) -> void:
	if _storeys < 2:
		return
	var bays := clampi(roundi(size.x / 2.6), 2, 5)
	var sill := maxf(_upper_sill(), minf(2.45, size.y - 0.72) + FASCIA_H + 0.3)
	var h := minf(1.2, size.y - 0.35 - sill)
	if h < 0.6:
		return
	for i in bays:
		_sash(b, -size.x * 0.5 + 0.5 + (size.x - 1.0) * (float(i) + 0.5) / float(bays), sill, WIN_W, h, rng.randf() < 0.6)

# A low lean-to against the back wall (drawn in the back wall's frame), solid.
func _lean_to(b: HarbourProps.Batch, x: float, roof_key: String, covering: String) -> void:
	var half := LEAN_TO.x * 0.5
	b.box("wall", LEAN_TO, Vector3(x, LEAN_TO.y * 0.5, LEAN_TO.z * 0.5))
	var high := LEAN_TO.y + 0.5
	for sx: float in [-1.0, 1.0]:
		b.poly("wall", PackedVector3Array([Vector3(x + sx * half, LEAN_TO.y, 0.0), Vector3(x + sx * half, LEAN_TO.y, LEAN_TO.z), Vector3(x + sx * half, high - 0.05, 0.0)]), Color.WHITE, Vector3(sx, 0.0, 0.0))
	var out := LEAN_TO.z + 0.18
	var low := high - (high - LEAN_TO.y) * out / LEAN_TO.z
	var tile := HarbourProps.roof_tile(covering)
	var u := (half + 0.12) / tile
	var v := Vector2(out, high - low).length() / tile
	var e_l := Vector3(x - half - 0.12, low, out)
	var e_r := Vector3(x + half + 0.12, low, out)
	var w_r := Vector3(x + half + 0.12, high, 0.0)
	var w_l := Vector3(x - half - 0.12, high, 0.0)
	b.quad(roof_key, e_l, e_r, w_r, w_l, _roof_tint, PackedVector2Array([Vector2(-u, v), Vector2(u, v), Vector2(u, 0.0), Vector2(-u, 0.0)]))
	var lip := Vector3(0.0, 0.08, 0.0)
	b.quad(roof_key, e_l - lip, e_r - lip, e_r, e_l, _roof_tint, PackedVector2Array([Vector2(-u, v + 0.05), Vector2(u, v + 0.05), Vector2(u, v), Vector2(-u, v)]))
	b.quad(roof_key, e_r - lip, e_l - lip, w_l - lip, w_r - lip, _roof_tint)
	b.box("paint", Vector3(0.8, 1.75, 0.04), Vector3(x, 0.9, LEAN_TO.z + 0.02), _door_col.darkened(0.2))
	# The back wall's frame is turned half round from the building's own.
	Geo.box_shape(self, LEAN_TO, Vector3(-x, LEAN_TO.y * 0.5, -size.z * 0.5 - LEAN_TO.z * 0.5))
