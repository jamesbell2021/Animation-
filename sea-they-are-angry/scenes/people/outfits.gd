class_name Outfits
extends RefCounted
## What the seven of Kirkhaven wear, so that from the camera nobody takes one of them for
## a keeper. Each of the seven borrows a keeper's model (Villagers.ROSTER, "model");
## dress() makes it a townsperson's in three ways:
## - it repaints a copy of the model's texture part by part (the coat, the trousers, the
##   hair), keeping the shading that was baked into it;
## - it takes away the parts that are the keeper's own (the hat, a beard, the tools);
## - it adds a few plain shapes on the bones (a cap, a skirt, a book).
## The keepers' own meshes, textures and materials are never touched.

## Side of a repainted texture, in texels (the keepers' own are 1024).
const RES := 512
## How far past a triangle's edge its paint runs, in texels, so the seams don't show.
const BLEED := 2.5

## The parts a keeper's model is told apart into. A look paints or hides them by name.
## "coat" is whatever they wear on top, "tails" a coat's skirt, "trim" what is sewn on
## its chest, "hem" what is sewn on at the hips (a rib, pockets), "kit" what hangs from
## the belt, "forearms" bare arms below a rolled sleeve.
const PARTS := ["", "skin", "forearms", "eyes", "brows", "hair", "bun", "braid", "beard", "hat",
	"collar", "trim", "hem", "buttons", "cuffs", "belt", "buckle", "kit", "tails", "boots", "soles",
	"coat", "trousers"]
## The colour of each keeper's hat in their texture (hair is known by the eyebrows).
const HATS := {
	"callum_keeper": Color(0.46, 0.09, 0.06),
	"hamish_keeper": Color(0.3, 0.25, 0.17),
	"ewan_keeper": Color(0.8, 0.6, 0.08),
}

const BLACK := Color(0.07, 0.07, 0.08)
const WHITE := Color(0.93, 0.93, 0.9)
const NAVY := Color(0.09, 0.12, 0.26)
const BRASS := Color(0.85, 0.66, 0.22)
const SEA_GREEN := Color(0.36, 0.78, 0.68)

## The seven looks, by Villagers id. Each is made for the model that person has in the
## roster; a part the model hasn't got is passed over.
## "paint": part -> its new colour, or [colour, shade]: how much of the part's painted
## light and dark to keep (1 all of it; less for pale cloth, or to rub out the shadow a
## hat or a beard left on the skin). "hide": parts taken off. "label": the name's tint.
## "props": shapes on bones, each [bone, shape, where, size, turn, colour] and, if wanted,
## a stretch along each axis: `where` is from the bone, in metres, with -Z forward and +X
## the person's right; `turn` in degrees.
##   "box": size is its width, height and depth. "ball": its three diameters.
##   "cyl": its bottom radius, height and top radius. "ring": its radius, thickness
##   and how deep it is against how wide (1 = round).
## "skirt": a skirt or coat tails that move with the legs: from and to (heights from the
## hips), wide (radius at the waist and at the hem), deep (front to back against side to
## side), colour, and "apron" for a white front.
const LOOKS := {
	# The minister: a long black coat, a white band at the throat, a bare grey head.
	"baird": {
		"label": Color(0.86, 0.86, 0.9),
		"paint": {"coat": BLACK, "tails": BLACK, "cuffs": BLACK, "buttons": Color(0.16, 0.16, 0.17),
			"trousers": Color(0.09, 0.09, 0.1), "hair": Color(0.45, 0.45, 0.46), "brows": Color(0.45, 0.45, 0.46),
			"skin": [Color(0.8, 0.6, 0.5), 0.3]},
		"hide": ["hat", "beard", "collar"],
		"props": [
			["neck", "cyl", Vector3(0.0, 0.085, 0.012), Vector3(0.074, 0.045, 0.07), Vector3.ZERO, WHITE],
			["hand.L", "box", Vector3(0.0, -0.1, -0.02), Vector3(0.034, 0.2, 0.15), Vector3.ZERO, Color(0.78, 0.64, 0.3)],
			["hand.L", "box", Vector3(0.022, -0.1, -0.017), Vector3(0.01, 0.215, 0.165), Vector3.ZERO, Color(0.05, 0.05, 0.06)],
			["hand.L", "box", Vector3(-0.022, -0.1, -0.017), Vector3(0.01, 0.215, 0.165), Vector3.ZERO, Color(0.05, 0.05, 0.06)],
			["hand.L", "box", Vector3(0.0, -0.1, 0.06), Vector3(0.05, 0.215, 0.012), Vector3.ZERO, Color(0.05, 0.05, 0.06)],
		],
	},
	# The chandler: a brown shop coat to the knee, a sea-green headscarf
	# (not the rust red it might have been: the head keeper's cap is red).
	"rennie": {
		"label": Color(0.9, 0.8, 0.62),
		"paint": {"coat": [Color(0.46, 0.3, 0.16), 0.6], "tails": Color(0.46, 0.3, 0.16), "trim": Color(0.4, 0.26, 0.14), "hem": Color(0.36, 0.23, 0.12),
			"trousers": Color(0.2, 0.2, 0.23), "boots": Color(0.1, 0.09, 0.08), "hair": Color(0.3, 0.2, 0.12), "brows": Color(0.3, 0.2, 0.12)},
		"hide": ["bun", "braid"],
		"skirt": {"from": 0.02, "to": -0.4, "wide": Vector2(0.19, 0.235), "deep": 0.82, "colour": Color(0.46, 0.3, 0.16)},
		"props": [
			["head", "ball", Vector3(0.0, 0.118, 0.035), Vector3(0.23, 0.26, 0.235), Vector3.ZERO, SEA_GREEN],
			["head", "ball", Vector3(0.0, 0.02, 0.105), Vector3(0.16, 0.14, 0.07), Vector3(25.0, 0.0, 0.0), SEA_GREEN],
		],
	},
	# The engineer: a bright blue boiler suit, white ice-plant boots, a sandy beard.
	"coull": {
		"label": Color(0.62, 0.76, 1.0),
		"paint": {"coat": Color(0.16, 0.3, 0.62), "trousers": Color(0.16, 0.3, 0.62), "trim": Color(0.14, 0.27, 0.56),
			"cuffs": Color(0.14, 0.27, 0.56), "collar": Color(0.14, 0.27, 0.56), "hat": Color(0.1, 0.1, 0.11),
			"boots": Color(0.86, 0.86, 0.8), "beard": Color(0.74, 0.4, 0.14), "hair": Color(0.58, 0.31, 0.12), "brows": Color(0.6, 0.33, 0.12)},
		"hide": ["kit"],
		"props": [
			["hips", "box", Vector3(0.17, -0.13, 0.07), Vector3(0.08, 0.2, 0.035), Vector3(0.0, 0.0, 6.0), Color(0.8, 0.16, 0.1)],
			["hips", "box", Vector3(-0.185, -0.12, -0.05), Vector3(0.022, 0.24, 0.035), Vector3.ZERO, Color(0.62, 0.64, 0.68)],
			["hips", "box", Vector3(-0.185, -0.25, -0.05), Vector3(0.024, 0.05, 0.07), Vector3.ZERO, Color(0.62, 0.64, 0.68)],
		],
	},
	# The publican: a wine-red jumper and skirt, a broad white apron, dark hair up.
	"duthie": {
		"label": Color(0.98, 0.78, 0.8),
		"paint": {"coat": Color(0.45, 0.1, 0.16), "tails": Color(0.45, 0.1, 0.16), "trim": Color(0.45, 0.1, 0.16), "collar": WHITE, "cuffs": WHITE,
			"trousers": Color(0.14, 0.13, 0.14), "boots": Color(0.08, 0.08, 0.08),
			"hair": Color(0.13, 0.1, 0.09), "bun": Color(0.13, 0.1, 0.09), "brows": Color(0.13, 0.1, 0.09)},
		"hide": ["braid", "hem"],
		"skirt": {"from": 0.02, "to": -0.46, "wide": Vector2(0.19, 0.29), "deep": 0.85, "colour": Color(0.36, 0.08, 0.13), "apron": WHITE},
		"props": [
			["chest", "box", Vector3(0.0, -0.02, -0.125), Vector3(0.2, 0.24, 0.03), Vector3(4.0, 0.0, 0.0), WHITE],
			["hips", "box", Vector3(0.0, 0.01, 0.16), Vector3(0.18, 0.06, 0.03), Vector3.ZERO, WHITE],
			["hips", "box", Vector3(0.0, -0.08, 0.175), Vector3(0.07, 0.15, 0.02), Vector3(-8.0, 0.0, 0.0), WHITE],
		],
	},
	# The district nurse: a navy cape over a pale blue dress, a small white cap.
	"buchan": {
		"label": Color(0.75, 0.88, 1.0),
		"paint": {"coat": [Color(0.56, 0.72, 0.88), 0.5], "tails": Color(0.56, 0.72, 0.88), "trim": Color(0.56, 0.72, 0.88), "collar": WHITE, "cuffs": WHITE,
			"trousers": Color(0.13, 0.13, 0.16), "boots": Color(0.08, 0.08, 0.08),
			"hair": Color(0.68, 0.66, 0.62), "bun": Color(0.68, 0.66, 0.62), "brows": Color(0.5, 0.48, 0.45)},
		"hide": ["braid", "hem"],
		"skirt": {"from": 0.02, "to": -0.44, "wide": Vector2(0.19, 0.27), "deep": 0.85, "colour": Color(0.56, 0.72, 0.88)},
		"props": [
			["chest", "cyl", Vector3(0.0, 0.03, 0.005), Vector3(0.29, 0.3, 0.085), Vector3.ZERO, NAVY, Vector3(1.0, 1.0, 0.68)],
			["head", "cyl", Vector3(0.0, 0.238, 0.01), Vector3(0.092, 0.055, 0.082), Vector3(-8.0, 0.0, 0.0), WHITE],
		],
	},
	# The harbour master: a navy uniform coat with brass buttons, a white-topped cap.
	"geddes": {
		"label": Color(0.7, 0.76, 1.0),
		"paint": {"coat": NAVY, "tails": NAVY, "collar": NAVY, "cuffs": NAVY, "buttons": BRASS,
			"trousers": Color(0.07, 0.08, 0.13), "hair": Color(0.5, 0.5, 0.5), "beard": Color(0.6, 0.6, 0.58), "brows": Color(0.4, 0.4, 0.4)},
		"hide": ["hat"],
		"props": [
			["head", "cyl", Vector3(0.0, 0.19, 0.0), Vector3(0.108, 0.05, 0.11), Vector3(-5.0, 0.0, 0.0), Color(0.06, 0.07, 0.12)],
			["head", "cyl", Vector3(0.0, 0.235, 0.004), Vector3(0.112, 0.045, 0.15), Vector3(-5.0, 0.0, 0.0), WHITE],
			["head", "box", Vector3(0.0, 0.168, -0.135), Vector3(0.17, 0.012, 0.09), Vector3(-14.0, 0.0, 0.0), Color(0.04, 0.04, 0.05)],
			["head", "box", Vector3(0.0, 0.195, -0.112), Vector3(0.04, 0.035, 0.012), Vector3.ZERO, BRASS],
		],
	},
	# The net-mender: a cream Aran jumper, a dark flat cap, a white beard, twine in a coil.
	"main": {
		"label": Color(1.0, 0.95, 0.8),
		"paint": {"coat": [Color(0.87, 0.82, 0.68), 0.7], "hem": Color(0.82, 0.77, 0.63), "cuffs": Color(0.82, 0.77, 0.63), "collar": Color(0.82, 0.77, 0.63),
			"trousers": Color(0.24, 0.2, 0.17), "beard": Color(0.84, 0.84, 0.82), "hair": Color(0.66, 0.66, 0.65), "brows": Color(0.7, 0.7, 0.68)},
		"hide": ["hat", "kit"],
		"props": [
			["head", "ball", Vector3(0.0, 0.2, 0.005), Vector3(0.255, 0.1, 0.3), Vector3(-7.0, 0.0, 0.0), Color(0.14, 0.14, 0.16)],
			["head", "box", Vector3(0.0, 0.17, -0.14), Vector3(0.16, 0.014, 0.09), Vector3(-12.0, 0.0, 0.0), Color(0.12, 0.12, 0.14)],
			["chest", "ring", Vector3(0.02, -0.02, 0.0), Vector3(0.22, 0.04, 0.74), Vector3(0.0, 0.0, -52.0), Color(0.62, 0.48, 0.27)],
			["chest", "ring", Vector3(0.04, -0.04, 0.0), Vector3(0.235, 0.03, 0.74), Vector3(0.0, 0.0, -45.0), Color(0.45, 0.33, 0.17)],
		],
	},
}

# What is known of each keeper's model, by model name (found once).
static var _bases := {}
# The repainted textures and the meshes with parts taken off, by villager id.
static var _textures := {}
static var _meshes := {}
static var _prop_meshes := {}
static var _cloth: StandardMaterial3D
static var _cloth_open: StandardMaterial3D

## Give a villager's rig the look that goes with their id. The rig must be in the tree.
static func dress(rig: CharacterRig, id: String) -> void:
	if rig == null or rig.mesh == null or rig.skeleton == null or not LOOKS.has(id):
		return
	var look: Dictionary = LOOKS[id]
	var model: String = Players.MODELS[int(Villagers.who(id).get("model", 0)) % Players.MODELS.size()]
	var key := id + "/" + model
	var base := _base(model, rig)
	if not base.is_empty():
		if not _textures.has(key):
			_textures[key] = _repaint(base, look.get("paint", {}))
			_meshes[key] = _cut(base, look.get("hide", []))
		var tex: Texture2D = _textures[key]
		if tex != null and rig.material != null:
			# A material of this villager's own: the keepers' is left as it was.
			var mat := rig.material.duplicate() as StandardMaterial3D
			mat.albedo_texture = tex
			rig.material = mat
			rig.mesh.material_override = mat
		var cut: ArrayMesh = _meshes[key]
		if cut != null:
			rig.mesh.mesh = cut
	_add_skirt(rig, key, look.get("skirt", {}))
	_add_props(rig, key, look.get("props", []))

## The tint for a villager's name: a pale shade of what they wear.
static func label_colour(id: String) -> Color:
	var c: Color = (LOOKS.get(id, {}) as Dictionary).get("label", Color(0.95, 0.9, 0.75))
	return Color(c.r, c.g, c.b, 0.85)

# ---- telling a keeper's model apart ----

# Everything dress() needs to know about a model: its mesh arrays, which part each
# triangle and each texel belongs to, and how bright each part is painted.
static func _base(model: String, rig: CharacterRig) -> Dictionary:
	if _bases.has(model):
		return _bases[model]
	var out := {}
	_bases[model] = out
	var mesh := rig.mesh.mesh as ArrayMesh
	if mesh == null or mesh.get_surface_count() != 1 or rig.material == null or rig.material.albedo_texture == null:
		return out
	var img := rig.material.albedo_texture.get_image()
	if img == null or img.is_empty():
		return out
	if img.is_compressed() and img.decompress() != OK:
		return out
	img.clear_mipmaps()
	img.convert(Image.FORMAT_RGB8)
	while img.get_width() >= RES * 2 and img.get_height() >= RES * 2:
		img.shrink_x2()
	if img.get_width() != RES or img.get_height() != RES:
		img.resize(RES, RES, Image.INTERPOLATE_BILINEAR)
	var arrays := mesh.surface_get_arrays(0)
	if arrays.size() <= Mesh.ARRAY_INDEX:
		return out
	for need: int in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS, Mesh.ARRAY_INDEX]:
		if arrays[need] == null:
			return out
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var tri_part := _tell_parts(model, rig, verts, uvs, idx, arrays[Mesh.ARRAY_BONES], arrays[Mesh.ARRAY_WEIGHTS], img)
	# How bright each part is painted, to keep its shading under a new colour.
	var total := PackedFloat32Array()
	var count := PackedInt32Array()
	total.resize(PARTS.size())
	count.resize(PARTS.size())
	for t in tri_part.size():
		var c := _sample(img, (uvs[idx[t * 3]] + uvs[idx[t * 3 + 1]] + uvs[idx[t * 3 + 2]]) / 3.0)
		total[tri_part[t]] += c.v * 255.0
		count[tri_part[t]] += 1
	var bright := PackedFloat32Array()
	bright.resize(PARTS.size())
	for p in PARTS.size():
		bright[p] = maxf(4.0, total[p] / float(count[p])) if count[p] > 0 else 0.0
	out["arrays"] = arrays
	out["tri_part"] = tri_part
	out["bright"] = bright
	out["pixels"] = img.get_data()
	out["map"] = _raster(uvs, idx, tri_part)
	return out

static func _sample(img: Image, uv: Vector2) -> Color:
	return img.get_pixel(clampi(int(uv.x * RES), 0, RES - 1), clampi(int(uv.y * RES), 0, RES - 1))

static func _is_skin(c: Color) -> bool:
	return c.h > 0.01 and c.h < 0.09 and c.s > 0.28 and c.s < 0.5 and c.v > 0.35

static func _apart(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()

static func _find(parent: PackedInt32Array, i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i

# The part (an index into PARTS) of every triangle. The models are built of separate
# pieces (a hat, a boot, each lock of a beard) joined into one mesh: find the pieces,
# then name each by the bone it hangs on, its colour and where it sits.
static func _tell_parts(model: String, rig: CharacterRig, verts: PackedVector3Array, uvs: PackedVector2Array, idx: PackedInt32Array, bones: PackedInt32Array, weights: PackedFloat32Array, img: Image) -> PackedByteArray:
	var skel := rig.skeleton
	var skin := rig.mesh.skin
	var per := bones.size() / maxi(1, verts.size())
	# Pieces: vertices at the same place are one, and so is all that a triangle joins.
	var parent := PackedInt32Array()
	parent.resize(verts.size())
	var seen := {}
	for i in verts.size():
		var at := Vector3i((verts[i] * 20000.0).round())
		if seen.has(at):
			parent[i] = seen[at]
		else:
			seen[at] = i
			parent[i] = i
	for t in range(0, idx.size(), 3):
		var ra := _find(parent, idx[t])
		for j in [1, 2]:
			var rb := _find(parent, idx[t + j])
			if rb != ra:
				parent[rb] = ra
	var pieces := {}
	for i in verts.size():
		var r := _find(parent, i)
		if not pieces.has(r):
			pieces[r] = {"n": 0, "lo": verts[i], "hi": verts[i], "sum": Vector3.ZERO, "bones": {}, "part": 0}
		var pc: Dictionary = pieces[r]
		pc["n"] += 1
		pc["lo"] = (pc["lo"] as Vector3).min(verts[i])
		pc["hi"] = (pc["hi"] as Vector3).max(verts[i])
		var c := _sample(img, uvs[i])
		pc["sum"] += Vector3(c.r, c.g, c.b)
		var b := _bone_of(i, per, bones, weights, skin, skel)
		pc["bones"][b] = int(pc["bones"].get(b, 0)) + 1
	# Model space: the model faces +Z and its left is +X (the rig turns it round).
	var eyes: Array[Vector3] = []
	for k: String in ["eye.L", "eye.R"]:
		if rig.markers.has(k):
			var m: Vector3 = rig.markers[k]
			eyes.append(Vector3(-m.x, m.y, -m.z))
	var hb := skel.find_bone("head")
	var eye_y: float = eyes[0].y if not eyes.is_empty() else (skel.get_bone_global_rest(hb).origin.y + 0.1 if hb >= 0 else 1.55)
	var hips := skel.find_bone("hips")
	var hips_y: float = skel.get_bone_global_rest(hips).origin.y if hips >= 0 else 0.84
	# First the body (the one big piece that bends), triangle by triangle.
	var tri_part := PackedByteArray()
	tri_part.resize(idx.size() / 3)
	var coat_sum := Vector3.ZERO
	var coat_n := 0
	for pc: Dictionary in pieces.values():
		var top := 0
		var top_bone := ""
		for b: String in pc["bones"]:
			if int(pc["bones"][b]) > top:
				top = int(pc["bones"][b])
				top_bone = b
		pc["bone"] = top_bone if top >= int(pc["n"] * 0.98) else ""
		var sum: Vector3 = pc["sum"] / float(pc["n"])
		pc["colour"] = Color(sum.x, sum.y, sum.z)
		if pc["bone"] == "":
			pc["part"] = -1 if int(pc["n"]) >= 1000 else PARTS.find("tails")
	for t in tri_part.size():
		var i0 := idx[t * 3]
		if int(pieces[_find(parent, i0)]["part"]) != -1:
			continue
		var i1 := idx[t * 3 + 1]
		var i2 := idx[t * 3 + 2]
		var mid := (verts[i0] + verts[i1] + verts[i2]) / 3.0
		var c := _sample(img, (uvs[i0] + uvs[i1] + uvs[i2]) / 3.0)
		var part := "coat"
		if _is_skin(c):
			var b := _bone_of(i0, per, bones, weights, skin, skel)
			part = "forearms" if b.begins_with("forearm") or b.begins_with("upper_arm") else "skin"
		elif mid.y < 0.3 and absf(mid.x) < 0.22:
			part = "boots"
		elif mid.y < hips_y - 0.02 and absf(mid.x) < 0.25:
			part = "trousers"
		else:
			coat_sum += Vector3(c.r, c.g, c.b)
			coat_n += 1
		tri_part[t] = PARTS.find(part)
	var coat := Color(coat_sum.x, coat_sum.y, coat_sum.z) / float(maxi(1, coat_n))
	# The eyebrows next: they are the colour of the hair, which tells hair from hat.
	var brow_sum := Vector3.ZERO
	var brow_n := 0
	for pc: Dictionary in pieces.values():
		if pc["bone"] != "head":
			continue
		var ctr: Vector3 = (pc["lo"] + pc["hi"]) * 0.5
		var size: Vector3 = pc["hi"] - pc["lo"]
		for e in eyes:
			if size.x < 0.06 and size.y < 0.04 and ctr.distance_to(e) < 0.035:
				var brow := ctr.y > e.y + 0.014 and not _is_skin(pc["colour"])
				pc["part"] = PARTS.find("brows" if brow else "eyes")
				if brow:
					brow_sum += pc["sum"] / float(pc["n"])
					brow_n += 1
	var hair := Color(brow_sum.x, brow_sum.y, brow_sum.z) / float(maxi(1, brow_n))
	# Then every other piece.
	for pc: Dictionary in pieces.values():
		if int(pc["part"]) != 0:
			continue
		var called := "trim"
		var bone: String = pc["bone"]
		var c: Color = pc["colour"]
		var ctr: Vector3 = (pc["lo"] + pc["hi"]) * 0.5
		var size: Vector3 = pc["hi"] - pc["lo"]
		var like_coat := _apart(c, coat) < 0.1
		if bone == "head":
			if _is_skin(c):
				called = "skin"
			elif HATS.has(model) and (brow_n == 0 or _apart(c, HATS[model]) < _apart(c, hair)):
				called = "hat"
			elif ctr.z > 0.0 and ctr.y < eye_y - 0.01:
				called = "beard"
			elif ctr.z < -0.08:
				called = "braid" if ctr.y < eye_y - 0.02 else "bun"
			else:
				called = "hair"
		elif bone == "neck":
			called = "collar"
		elif bone.begins_with("forearm") or bone.begins_with("upper_arm") or bone.begins_with("hand"):
			called = "cuffs"
		elif bone.begins_with("shin") or bone.begins_with("foot") or bone.begins_with("thigh"):
			called = "soles" if (pc["hi"] as Vector3).y < 0.06 else "boots"
		elif bone == "hips" and like_coat:
			called = "hem"
		elif bone == "hips":
			if size.x > 0.3:
				called = "belt"
			elif ctr.z > 0.1 and absf(ctr.x) < 0.05:
				called = "buckle"
			else:
				called = "kit"
		elif not like_coat:
			called = "buttons"
		pc["part"] = PARTS.find(called)
	for t in tri_part.size():
		var part := int(pieces[_find(parent, idx[t * 3])]["part"])
		if part > 0:
			tri_part[t] = part
	return tri_part

# The bone a vertex mostly follows.
static func _bone_of(i: int, per: int, bones: PackedInt32Array, weights: PackedFloat32Array, skin: Skin, skel: Skeleton3D) -> String:
	var best := 0
	for j in range(1, per):
		if weights[i * per + j] > weights[i * per + best]:
			best = j
	var b := bones[i * per + best]
	if skin == null:
		return skel.get_bone_name(b)
	if b >= skin.get_bind_count():
		return ""
	var n := String(skin.get_bind_name(b))
	return n if n != "" else skel.get_bone_name(skin.get_bind_bone(b))

# Which part each texel of the texture belongs to: every triangle drawn into a map by
# its texture coordinates, a little past its edges.
static func _raster(uvs: PackedVector2Array, idx: PackedInt32Array, tri_part: PackedByteArray) -> PackedByteArray:
	var map := PackedByteArray()
	map.resize(RES * RES)
	var sure := PackedByteArray()
	sure.resize(RES * RES)
	for t in tri_part.size():
		var part := tri_part[t]
		if part == 0:
			continue
		var a := uvs[idx[t * 3]] * RES
		var b := uvs[idx[t * 3 + 1]] * RES
		var c := uvs[idx[t * 3 + 2]] * RES
		var area := (b - a).cross(c - a)
		if absf(area) < 0.0001:
			continue
		if area < 0.0:
			var swap := b
			b = c
			c = swap
		var ab := (b - a) / maxf((b - a).length(), 0.0001)
		var bc := (c - b) / maxf((c - b).length(), 0.0001)
		var ca := (a - c) / maxf((a - c).length(), 0.0001)
		var x0 := maxi(0, floori(minf(a.x, minf(b.x, c.x)) - BLEED))
		var x1 := mini(RES - 1, ceili(maxf(a.x, maxf(b.x, c.x)) + BLEED))
		var y0 := maxi(0, floori(minf(a.y, minf(b.y, c.y)) - BLEED))
		var y1 := mini(RES - 1, ceili(maxf(a.y, maxf(b.y, c.y)) + BLEED))
		for y in range(y0, y1 + 1):
			var py := y + 0.5
			for x in range(x0, x1 + 1):
				var px := x + 0.5
				# Distances inside each edge, in texels.
				var d0 := ab.x * (py - a.y) - ab.y * (px - a.x)
				if d0 < -BLEED:
					continue
				var d1 := bc.x * (py - b.y) - bc.y * (px - b.x)
				if d1 < -BLEED:
					continue
				var d2 := ca.x * (py - c.y) - ca.y * (px - c.x)
				if d2 < -BLEED:
					continue
				var k := y * RES + x
				if d0 >= 0.0 and d1 >= 0.0 and d2 >= 0.0:
					map[k] = part
					sure[k] = 1
				elif sure[k] == 0:
					map[k] = part
	return map

# ---- the three ways of dressing ----

# A copy of the model's texture with the named parts in new colours. Each texel keeps
# its shade: how bright it was against the rest of its part.
static func _repaint(base: Dictionary, paint: Dictionary) -> ImageTexture:
	var map: PackedByteArray = base["map"]
	var bright: PackedFloat32Array = base["bright"]
	var pixels: PackedByteArray = (base["pixels"] as PackedByteArray).duplicate()
	# For each part: whether it is painted, and its new colour as so much for each step
	# of the old brightness (r, g, b) on top of so much flat.
	var on := PackedByteArray()
	var gain := PackedVector3Array()
	var flat := PackedVector3Array()
	on.resize(PARTS.size())
	gain.resize(PARTS.size())
	flat.resize(PARTS.size())
	for part: String in paint:
		var p := PARTS.find(part)
		if p < 1 or bright[p] <= 0.0:
			continue
		var spec: Variant = paint[part]
		var c: Color = spec[0] if spec is Array else spec
		var shade: float = spec[1] if spec is Array else 1.0
		var full := Vector3(c.r, c.g, c.b) * 255.0
		on[p] = 1
		gain[p] = full * shade / bright[p]
		flat[p] = full * (1.0 - shade)
	for k in map.size():
		var p := map[k]
		if on[p] == 0:
			continue
		var o := k * 3
		var c := gain[p] * float(maxi(pixels[o], maxi(pixels[o + 1], pixels[o + 2]))) + flat[p]
		pixels[o] = mini(255, int(c.x))
		pixels[o + 1] = mini(255, int(c.y))
		pixels[o + 2] = mini(255, int(c.z))
	var img := Image.create_from_data(RES, RES, false, Image.FORMAT_RGB8, pixels)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# The model's mesh without the named parts (the same vertices, fewer triangles).
static func _cut(base: Dictionary, hide: Array) -> ArrayMesh:
	var gone := PackedByteArray()
	gone.resize(PARTS.size())
	var any := false
	for part: String in hide:
		var p := PARTS.find(part)
		if p > 0:
			gone[p] = 1
			any = true
	if not any:
		return null
	var arrays: Array = (base["arrays"] as Array).duplicate()
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var tri_part: PackedByteArray = base["tri_part"]
	var kept := PackedInt32Array()
	for t in tri_part.size():
		if gone[tri_part[t]] == 0:
			kept.append(idx[t * 3])
			kept.append(idx[t * 3 + 1])
			kept.append(idx[t * 3 + 2])
	arrays[Mesh.ARRAY_INDEX] = kept
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

static func _material(open: bool) -> StandardMaterial3D:
	if _cloth == null:
		_cloth = StandardMaterial3D.new()
		_cloth.vertex_color_use_as_albedo = true
		_cloth.vertex_color_is_srgb = true
		_cloth.roughness = 0.9
		_cloth_open = _cloth.duplicate()
		_cloth_open.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _cloth_open if open else _cloth

# The shapes of a look, one mesh for each bone they hang on.
static func _add_props(rig: CharacterRig, key: String, props: Array) -> void:
	var by_bone := {}
	for p: Array in props:
		if not rig.has_bone(p[0]):
			continue
		if not by_bone.has(p[0]):
			by_bone[p[0]] = []
		by_bone[p[0]].append(p)
	for bone: String in by_bone:
		var k := key + "/" + bone
		if not _prop_meshes.has(k):
			_prop_meshes[k] = _shapes(by_bone[bone])
		var mi := MeshInstance3D.new()
		mi.name = "Outfit_" + bone.replace(".", "_")
		mi.mesh = _prop_meshes[k]
		mi.material_override = _material(false)
		rig.attach_aligned(bone, mi)

# One mesh out of a few plain shapes, coloured by vertex.
static func _shapes(list: Array) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	var idx := PackedInt32Array()
	for s: Array in list:
		var size: Vector3 = s[3]
		var turn: Vector3 = s[4]
		var turned := Basis.from_euler(Vector3(deg_to_rad(turn.x), deg_to_rad(turn.y), deg_to_rad(turn.z)))
		var prim: PrimitiveMesh
		match String(s[1]):
			"box":
				var box := BoxMesh.new()
				box.size = size
				prim = box
			"cyl":
				var cyl := CylinderMesh.new()
				cyl.bottom_radius = size.x
				cyl.height = size.y
				cyl.top_radius = size.z
				cyl.radial_segments = 14
				cyl.rings = 1
				prim = cyl
			"ring":
				var ring := TorusMesh.new()
				ring.inner_radius = size.x - size.y
				ring.outer_radius = size.x + size.y
				ring.rings = 18
				ring.ring_segments = 6
				prim = ring
				turned = turned * Basis.from_scale(Vector3(1.0, 1.0, size.z))
			_:
				var ball := SphereMesh.new()
				ball.radius = 0.5
				ball.height = 1.0
				ball.radial_segments = 14
				ball.rings = 7
				prim = ball
				turned = turned * Basis.from_scale(size)
		if s.size() > 6:
			turned = turned * Basis.from_scale(s[6])
		var a := prim.get_mesh_arrays()
		var from := verts.size()
		var turn_normals := turned.inverse().transposed()
		for v: Vector3 in a[Mesh.ARRAY_VERTEX]:
			verts.append(turned * v + (s[2] as Vector3))
			colours.append(s[5])
		for n: Vector3 in a[Mesh.ARRAY_NORMAL]:
			normals.append((turn_normals * n).normalized())
		for i: int in a[Mesh.ARRAY_INDEX]:
			idx.append(from + i)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

# A skirt (or the tails of a long coat) hung from the hips. It is skinned like the
# models' own coats: each side follows its thigh more toward the hem.
static func _add_skirt(rig: CharacterRig, key: String, spec: Dictionary) -> void:
	if spec.is_empty() or rig.mesh.skin == null or not rig.has_bone("hips"):
		return
	if not _prop_meshes.has(key + "/skirt"):
		_prop_meshes[key + "/skirt"] = _skirt_mesh(rig, spec)
	var mi := MeshInstance3D.new()
	mi.name = "Outfit_skirt"
	mi.mesh = _prop_meshes[key + "/skirt"]
	mi.skin = rig.mesh.skin
	mi.material_override = _material(true)
	mi.extra_cull_margin = 2.0
	rig.mesh.add_sibling(mi)

static func _skirt_mesh(rig: CharacterRig, spec: Dictionary) -> ArrayMesh:
	var skel := rig.skeleton
	var skin := rig.mesh.skin
	var bind := {}
	for i in skin.get_bind_count():
		var n := String(skin.get_bind_name(i))
		bind[n if n != "" else skel.get_bone_name(skin.get_bind_bone(i))] = i
	var hips: int = bind.get("hips", 0)
	var left: int = bind.get("thigh.L", hips)
	var right: int = bind.get("thigh.R", hips)
	var hips_y := skel.get_bone_global_rest(skel.find_bone("hips")).origin.y
	var wide: Vector2 = spec.get("wide", Vector2(0.19, 0.27))
	var data := {"verts": PackedVector3Array(), "normals": PackedVector3Array(), "colours": PackedColorArray(),
		"bones": PackedInt32Array(), "weights": PackedFloat32Array(), "idx": PackedInt32Array(),
		"y0": hips_y + float(spec.get("from", 0.02)), "y1": hips_y + float(spec.get("to", -0.45)),
		"r0": wide.x, "r1": wide.y, "deep": float(spec.get("deep", 0.85)), "bind": [hips, left, right]}
	_skirt_band(data, 0.0, TAU, 18, 0.0, 1.0, 0.0, spec.get("colour", Color.GRAY))
	if spec.has("apron"):
		# The apron: the front of the skirt again, a finger's width proud of it.
		_skirt_band(data, deg_to_rad(28.0), deg_to_rad(152.0), 7, 0.12, 0.88, 0.014, spec["apron"])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = data["verts"]
	arrays[Mesh.ARRAY_NORMAL] = data["normals"]
	arrays[Mesh.ARRAY_COLOR] = data["colours"]
	arrays[Mesh.ARRAY_BONES] = data["bones"]
	arrays[Mesh.ARRAY_WEIGHTS] = data["weights"]
	arrays[Mesh.ARRAY_INDEX] = data["idx"]
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

# Part of a skirt: round from angle a0 to a1 (the front is a quarter turn), down from
# t0 to t1 of its length, `proud` metres outside it.
static func _skirt_band(data: Dictionary, a0: float, a1: float, segs: int, t0: float, t1: float, proud: float, colour: Color) -> void:
	var verts: PackedVector3Array = data["verts"]
	var normals: PackedVector3Array = data["normals"]
	var colours: PackedColorArray = data["colours"]
	var bones: PackedInt32Array = data["bones"]
	var weights: PackedFloat32Array = data["weights"]
	var idx: PackedInt32Array = data["idx"]
	var bind: Array = data["bind"]
	var rows := 5
	var from := verts.size()
	for r in rows:
		var t := lerpf(t0, t1, float(r) / float(rows - 1))
		# Gathered in at the waist, then widening to the hem.
		var radius: float = lerpf(data["r0"], data["r1"], t) * (0.8 if t <= 0.0 else 1.0) + proud
		for s in segs + 1:
			var ang := lerpf(a0, a1, float(s) / float(segs))
			var v := Vector3(cos(ang) * radius, lerpf(data["y0"], data["y1"], t), sin(ang) * radius * float(data["deep"]) - 0.01)
			verts.append(v)
			normals.append(Vector3(cos(ang), 0.25, sin(ang)).normalized())
			colours.append(colour)
			var follow := t * 0.8 * clampf(absf(v.x) / 0.08, 0.0, 1.0)
			bones.append_array(PackedInt32Array([bind[0], bind[1] if v.x > 0.0 else bind[2], 0, 0]))
			weights.append_array(PackedFloat32Array([1.0 - follow, follow, 0.0, 0.0]))
	for r in rows - 1:
		for s in segs:
			var a := from + r * (segs + 1) + s
			var b := a + segs + 1
			idx.append_array(PackedInt32Array([a, b, a + 1, a + 1, b, b + 1]))
	data["verts"] = verts
	data["normals"] = normals
	data["colours"] = colours
	data["bones"] = bones
	data["weights"] = weights
	data["idx"] = idx
