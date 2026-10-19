"""Builds the game's characters in Blender: rigged, textured GLBs in art/characters/.

    blender -b -P art/source/characters/build_characters.py -- <out_dir> [name ...] [--preview]

Every character is made the same way, so they can be rebuilt and tweaked from here:

1. A body from a joint graph through the skin modifier (radius per joint), smoothed
   with subdivision. The same joints place the armature's bones.
2. Clothing by region (faces coloured by where they sit on the body), plus extra
   geometry for the detail that sells it: hems, cuffs, collars, boots, belts, hats,
   beards, noses, ears, brows.
3. Automatic weights for the body; rigid parts are bound to a single bone.
4. Procedural materials (wool, oilskin, leather, skin, hair) baked with ambient
   occlusion into one texture, so the game draws each character with one material.
5. Exported as a GLB with its skeleton. The game animates the bones in code and
   swaps them to physics for ragdolls.

Blender coordinates: Z up, the character faces -Y, its left is +X (bone names .L).
"""

import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
PREVIEW = "--preview" in ARGV
ARGV = [a for a in ARGV if not a.startswith("--")]
OUT = ARGV[0] if ARGV else os.path.join(os.path.dirname(__file__), "..", "..", "characters")
ONLY = ARGV[1:]
TEX = 1024


def lin(c):
    """sRGB 0-1 tuple to linear, with alpha."""
    return tuple(pow(v, 2.2) for v in c[:3]) + (1.0,)


# ---------------------------------------------------------------- scene helpers

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def link(ob):
    bpy.context.scene.collection.objects.link(ob)
    return ob


def activate(ob, others=()):
    bpy.ops.object.select_all(action='DESELECT')
    for o in others:
        o.select_set(True)
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob


def bake_modifiers(ob):
    """Apply every modifier by taking the evaluated mesh (no operator context needed)."""
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    old = ob.data
    ob.modifiers.clear()
    ob.data = me
    bpy.data.meshes.remove(old)
    return ob


def mesh_from_bmesh(name, bm):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    return link(bpy.data.objects.new(name, me))


def smooth(ob):
    for p in ob.data.polygons:
        p.use_smooth = True


# ---------------------------------------------------------------- materials

def pmat(name, c1, c2, scale=30.0, detail=6.0, lo=0.3, hi=0.7, rough=0.85, pattern=None, pscale=60.0, pstrength=0.35):
    """A painted-looking material: two colours broken up by noise, with an optional
    pattern (knit ribs, stripes, weave) darkening it."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = rough
    coord = nt.nodes.new("ShaderNodeTexCoord")
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = scale
    noise.inputs["Detail"].default_value = detail
    nt.links.new(coord.outputs["Object"], noise.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = lo
    ramp.color_ramp.elements[0].color = lin(c1)
    ramp.color_ramp.elements[1].position = hi
    ramp.color_ramp.elements[1].color = lin(c2)
    nt.links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    col = ramp.outputs["Color"]
    if pattern:
        wave = nt.nodes.new("ShaderNodeTexWave")
        wave.inputs["Scale"].default_value = pscale
        wave.inputs["Distortion"].default_value = 1.5
        wave.wave_type = 'BANDS'
        wave.bands_direction = {'ribs': 'X', 'rings': 'Z', 'stripes': 'Z', 'weave': 'DIAGONAL'}.get(pattern, 'X')
        if pattern == 'rings':
            wave.wave_profile = 'SAW'
        nt.links.new(coord.outputs["Object"], wave.inputs["Vector"])
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = 'RGBA'
        mix.blend_type = 'MULTIPLY'
        mix.inputs["Factor"].default_value = pstrength
        nt.links.new(col, mix.inputs["A"])
        nt.links.new(wave.outputs["Color"], mix.inputs["B"])
        col = mix.outputs["Result"]
    nt.links.new(col, bsdf.inputs["Base Color"])
    return m


def add_mat(ob, m):
    ob.data.materials.append(m)
    return len(ob.data.materials) - 1


def paint_regions(ob, rule):
    """Give each face the material slot named by rule(centre, normal)."""
    names = [m.name for m in ob.data.materials]
    for p in ob.data.polygons:
        n = rule(Vector(p.center), Vector(p.normal))
        if n in names:
            p.material_index = names.index(n)


# ---------------------------------------------------------------- shapes

def skin_body(name, joints, edges, root=0, levels=2):
    """A smooth organic mesh from joints [(pos, (rx, ry))] and edges between them."""
    me = bpy.data.meshes.new(name)
    me.from_pydata([j[0] for j in joints], edges, [])
    ob = link(bpy.data.objects.new(name, me))
    sk = ob.modifiers.new("skin", 'SKIN')
    sk.use_smooth_shade = True
    sk.branch_smoothing = 0.5
    for i, j in enumerate(joints):
        sv = me.skin_vertices[0].data[i]
        sv.radius = j[1]
        sv.use_root = i == root
    sub = ob.modifiers.new("sub", 'SUBSURF')
    sub.levels = levels
    sub.render_levels = levels
    return bake_modifiers(ob)


def blob(name, centre, size, segs=16, rings=10, mat=None):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector(centre), verts=bm.verts)
    ob = mesh_from_bmesh(name, bm)
    smooth(ob)
    if mat:
        add_mat(ob, mat)
    return ob


def ring(name, centre, r_major, r_minor, scale=(1, 1, 1), segs=24, mat=None, rot=None):
    bpy.ops.mesh.primitive_torus_add(major_radius=r_major, minor_radius=r_minor, major_segments=segs, minor_segments=8)
    ob = bpy.context.active_object
    ob.name = name
    ob.scale = scale
    if rot:
        ob.rotation_euler = rot
    ob.location = centre
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    smooth(ob)
    if mat:
        add_mat(ob, mat)
    return ob


def tube(name, a, b, r1, r2, segs=16, mat=None, caps=True):
    """A tapered cylinder from point a to point b."""
    a, b = Vector(a), Vector(b)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=caps, cap_tris=False, segments=segs, radius1=r1, radius2=r2, depth=(b - a).length)
    d = (b - a).normalized()
    rot = Vector((0, 0, 1)).rotation_difference(d).to_matrix().to_4x4()
    bmesh.ops.transform(bm, matrix=Matrix.Translation((a + b) / 2) @ rot, verts=bm.verts)
    ob = mesh_from_bmesh(name, bm)
    smooth(ob)
    if mat:
        add_mat(ob, mat)
    return ob


def box(name, centre, size, mat=None, bevel=0.01, rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=bm.edges[:], offset=bevel, segments=2, affect='EDGES')
    from mathutils import Euler
    bmesh.ops.rotate(bm, verts=bm.verts, cent=Vector((0, 0, 0)), matrix=Euler(rot).to_matrix())
    bmesh.ops.translate(bm, vec=Vector(centre), verts=bm.verts)
    ob = mesh_from_bmesh(name, bm)
    if mat:
        add_mat(ob, mat)
    return ob


def dome(name, centre, size, cut=0.0, mat=None, segs=20, rings=12):
    """The top part of an ellipsoid above `cut` (in unit-sphere z), e.g. a cap crown."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=1.0)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < cut - 1e-4], context='VERTS')
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector(centre), verts=bm.verts)
    ob = mesh_from_bmesh(name, bm)
    smooth(ob)
    if mat:
        add_mat(ob, mat)
    return ob


def roughen(ob, strength=0.01, scale=0.05, seed=0):
    """Lumpy, hand-made surfaces: a noise displacement along the normals."""
    tex = bpy.data.textures.new(ob.name + "_n", 'CLOUDS')
    tex.noise_scale = scale
    tex.noise_depth = 2
    d = ob.modifiers.new("disp", 'DISPLACE')
    d.texture = tex
    d.strength = strength
    d.mid_level = 0.5
    return bake_modifiers(ob)


def subdivide(ob, levels=1):
    s = ob.modifiers.new("sub", 'SUBSURF')
    s.levels = levels
    s.render_levels = levels
    return bake_modifiers(ob)


# ---------------------------------------------------------------- the humanoid rig

def humanoid_joints(p):
    """Joint graph for a humanoid from a proportions dict. Returns (joints, edges,
    named positions for the armature)."""
    H = p.get("height", 1.0)
    W = p.get("width", 1.0)
    G = p.get("girth", 1.0)
    hips_z = 0.88 * H * p.get("legs", 1.0)
    chest_up = H * p.get("torso", 1.0)
    P = {}
    P["hips"] = Vector((0, 0.0, hips_z))
    P["spine"] = Vector((0, 0.005, hips_z + 0.17 * chest_up))
    P["chest"] = Vector((0, 0.0, hips_z + 0.35 * chest_up))
    P["upper"] = Vector((0, 0.01, hips_z + 0.47 * chest_up))
    P["neck"] = Vector((0, 0.005 + p.get("hunch", 0.0), hips_z + 0.55 * chest_up))
    hb = P["neck"] + Vector((0, -0.012 - p.get("hunch", 0.0) * 0.5, 0.07))
    P["head_low"] = hb
    hs = p.get("head", 1.0)
    P["head_mid"] = hb + Vector((0, 0.008, 0.09 * hs))
    P["head_top"] = hb + Vector((0, 0.012, 0.19 * hs))
    sh = 0.19 * W
    arm = p.get("arms", 1.0)
    for s, side in ((1, "L"), (-1, "R")):
        P["shoulder." + side] = Vector((s * sh, 0.01, P["upper"].z))
        # Arms hang a little out from the body: the rest pose the game animates from.
        P["elbow." + side] = Vector((s * (sh + 0.07 * arm), 0.025, P["upper"].z - 0.27 * arm))
        P["wrist." + side] = Vector((s * (sh + 0.11 * arm), -0.01, P["upper"].z - 0.5 * arm))
        P["hand." + side] = Vector((s * (sh + 0.12 * arm), -0.02, P["upper"].z - 0.585 * arm))
        P["fingers." + side] = Vector((s * (sh + 0.125 * arm), -0.025, P["upper"].z - 0.645 * arm * p.get("fingers", 1.0)))
        P["thumb." + side] = Vector((s * (sh + 0.095 * arm), -0.06, P["upper"].z - 0.545 * arm))
        lx = 0.095 * W * p.get("stance", 1.0)
        P["hip." + side] = Vector((s * lx, 0.0, hips_z - 0.04))
        P["knee." + side] = Vector((s * (lx + 0.01), -0.015, hips_z * 0.53))
        P["ankle." + side] = Vector((s * (lx + 0.01), 0.025, 0.1))
        P["toe." + side] = Vector((s * (lx + 0.015), -0.12 * p.get("feet", 1.0), 0.045))
    r = p.get("r", {})

    def R(name, default):
        v = r.get(name, default)
        if isinstance(v, (int, float)):
            v = (v, v)
        return (v[0] * G if name in ("hips", "spine", "chest", "upper") else v[0], v[1] * G if name in ("hips", "spine", "chest", "upper") else v[1])

    order = ["hips", "spine", "chest", "upper", "neck", "head_low", "head_mid", "head_top"]
    radii = {
        "hips": R("hips", (0.165, 0.125)), "spine": R("spine", (0.165, 0.118)), "chest": R("chest", (0.2, 0.135)),
        "upper": R("upper", (0.19, 0.118)), "neck": R("neck", 0.06), "head_low": R("head_low", (0.078 * hs, 0.086 * hs)),
        "head_mid": R("head_mid", (0.092 * hs, 0.104 * hs)), "head_top": R("head_top", (0.068 * hs, 0.075 * hs)),
    }
    limb = {
        "shoulder": R("shoulder", 0.074), "elbow": R("elbow", 0.055), "wrist": R("wrist", 0.042),
        "hand": R("hand", (0.052, 0.03)), "fingers": R("fingers", (0.045, 0.024)), "thumb": R("thumb", 0.021),
        "hip": R("hip", 0.098), "knee": R("knee", 0.07), "ankle": R("ankle", 0.05), "toe": R("toe", (0.05, 0.038)),
    }
    names = list(order)
    for side in ("L", "R"):
        for k in ("shoulder", "elbow", "wrist", "hand", "fingers", "thumb", "hip", "knee", "ankle", "toe"):
            names.append(k + "." + side)
    idx = {n: i for i, n in enumerate(names)}
    joints = []
    for n in names:
        base = n.split(".")[0]
        joints.append((P[n], radii[n] if n in radii else limb[base]))
    E = [("hips", "spine"), ("spine", "chest"), ("chest", "upper"), ("upper", "neck"), ("neck", "head_low"),
         ("head_low", "head_mid"), ("head_mid", "head_top")]
    for side in ("L", "R"):
        s = "." + side
        E += [("upper", "shoulder" + s), ("shoulder" + s, "elbow" + s), ("elbow" + s, "wrist" + s),
              ("wrist" + s, "hand" + s), ("hand" + s, "fingers" + s), ("wrist" + s, "thumb" + s),
              ("hips", "hip" + s), ("hip" + s, "knee" + s), ("knee" + s, "ankle" + s), ("ankle" + s, "toe" + s)]
    edges = [(idx[a], idx[b]) for a, b in E]
    return joints, edges, P


HUMANOID_BONES = [
    # name, head joint, tail joint, parent
    ("hips", "hips", "spine", None),
    ("spine", "spine", "chest", "hips"),
    ("chest", "chest", "upper", "spine"),
    ("neck", "upper", "head_low", "chest"),
    ("head", "head_low", "head_top", "neck"),
]
for _s in ("L", "R"):
    HUMANOID_BONES += [
        ("upper_arm." + _s, "shoulder." + _s, "elbow." + _s, "chest"),
        ("forearm." + _s, "elbow." + _s, "wrist." + _s, "upper_arm." + _s),
        ("hand." + _s, "wrist." + _s, "fingers." + _s, "forearm." + _s),
        ("thigh." + _s, "hip." + _s, "knee." + _s, "hips"),
        ("shin." + _s, "knee." + _s, "ankle." + _s, "thigh." + _s),
        ("foot." + _s, "ankle." + _s, "toe." + _s, "shin." + _s),
    ]


def make_armature(name, P, bones):
    arm = bpy.data.armatures.new(name + "_rig")
    rig = link(bpy.data.objects.new(name + "_rig", arm))
    activate(rig)
    bpy.ops.object.mode_set(mode='EDIT')
    eb = arm.edit_bones
    for bname, h, t, parent in bones:
        b = eb.new(bname)
        b.head = P[h] if isinstance(h, str) else Vector(h)
        b.tail = P[t] if isinstance(t, str) else Vector(t)
        b.roll = 0.0
        if parent:
            b.parent = eb[parent]
            b.use_connect = False
    bpy.ops.object.mode_set(mode='OBJECT')
    return rig


def bind_auto(body, rig):
    activate(rig, [body])
    bpy.ops.object.parent_set(type='ARMATURE_AUTO')


def bind_rigid(ob, bone):
    vg = ob.vertex_groups.new(name=bone)
    vg.add(list(range(len(ob.data.vertices))), 1.0, 'REPLACE')


def join_into(body, parts):
    activate(body, parts)
    bpy.ops.object.join()
    return body


# ---------------------------------------------------------------- baking and export

def bake_textures(ob, size=TEX):
    """Unwrap, bake the procedural colours and ambient occlusion into one image, and
    swap every material for one textured material."""
    activate(ob)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.006)
    bpy.ops.object.mode_set(mode='OBJECT')
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = 24
    sc.render.bake.margin = 6
    col = bpy.data.images.new(ob.name + "_col", size, size)
    ao = bpy.data.images.new(ob.name + "_ao", size, size)
    # The armature would pose the mesh during the bake; it is at rest, so that's fine.
    for img, kind in ((col, 'DIFFUSE'), (ao, 'AO')):
        for m in ob.data.materials:
            nt = m.node_tree
            node = nt.nodes.get("_bake") or nt.nodes.new("ShaderNodeTexImage")
            node.name = "_bake"
            node.image = img
            nt.nodes.active = node
        if kind == 'DIFFUSE':
            bpy.ops.object.bake(type='DIFFUSE', pass_filter={'COLOR'}, use_clear=True)
        else:
            sc.world = sc.world or bpy.data.worlds.new("w")
            bpy.ops.object.bake(type='AO', use_clear=True)
    c = np.array(col.pixels[:]).reshape(-1, 4)
    a = np.array(ao.pixels[:]).reshape(-1, 4)
    occl = 0.45 + 0.55 * np.clip(a[:, :1], 0.0, 1.0)
    c[:, :3] *= occl
    final = bpy.data.images.new(ob.name, size, size)
    final.pixels = c.flatten().tolist()
    final.file_format = 'PNG'
    m = bpy.data.materials.new(ob.name + "_mat")
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.88
    bsdf.inputs["Specular IOR Level"].default_value = 0.25
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = final
    nt.links.new(t.outputs["Color"], bsdf.inputs["Base Color"])
    ob.data.materials.clear()
    ob.data.materials.append(m)
    final.pack()
    return final


def export(name, rig, body):
    os.makedirs(OUT, exist_ok=True)
    activate(rig, [body])
    path = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, export_apply=False,
                              export_animations=False, export_skins=True, export_yup=True,
                              export_image_format='AUTO', export_texcoords=True, export_normals=True)
    print("EXPORTED", path, len(body.data.polygons), "faces")
    return path


def preview(name, objs, height=1.8):
    """A Cycles render of the character, front three-quarter, for checking by eye."""
    sc = bpy.context.scene
    cam = link(bpy.data.objects.new("cam", bpy.data.cameras.new("cam")))
    cam.data.lens = 60
    d = height * 1.9
    cam.location = (d * 0.55, -d, height * 0.62)
    direction = Vector((0, 0, height * 0.5)) - cam.location
    cam.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()
    sc.camera = cam
    sun = link(bpy.data.objects.new("sun", bpy.data.lights.new("sun", 'SUN')))
    sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(50), 0, math.radians(30))
    fill = link(bpy.data.objects.new("fill", bpy.data.lights.new("fill", 'SUN')))
    fill.data.energy = 0.8
    fill.rotation_euler = (math.radians(70), 0, math.radians(-140))
    w = sc.world or bpy.data.worlds.new("w")
    sc.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Color"].default_value = (0.35, 0.4, 0.45, 1)
    w.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.6
    sc.render.engine = 'CYCLES'
    sc.cycles.samples = 32
    sc.render.resolution_x = 640
    sc.render.resolution_y = 800
    sc.render.film_transparent = False
    sc.render.filepath = os.path.join(OUT, "preview_" + name + ".png")
    bpy.ops.render.render(write_still=True)
    print("PREVIEW", sc.render.filepath)


# ---------------------------------------------------------------- keepers

KNIT_NAVY = ((0.10, 0.13, 0.22), (0.17, 0.21, 0.33))
SKIN = ((0.66, 0.45, 0.36), (0.80, 0.58, 0.47))


def is_hand(c, P, margin=0.0):
    """True past the wrist, along the forearm."""
    for side in ("L", "R"):
        w, e = P["wrist." + side], P["elbow." + side]
        d = (w - e).normalized()
        if (c - w).dot(d) > margin and (c - w).length < 0.2:
            return True
    return False


def keeper_body(name, p, mats, region):
    joints, edges, P = humanoid_joints(p)
    body = skin_body(name, joints, edges)
    for m in mats.values():
        add_mat(body, m)
    paint_regions(body, lambda c, n: region(c, n, P))
    return body, P


def face(P, hs, mats, beard=None, brows=None, nose=1.0):
    """Eyes, brows, nose and ears on the head: all bound to the head bone."""
    parts = []
    hm = P["head_mid"]
    fr = 0.104 * hs
    for s in (1, -1):
        e = blob("eye", hm + Vector((s * 0.034 * hs, -fr * 0.86, 0.012)), (0.013, 0.008, 0.012), 10, 6, mats["eye"])
        parts.append(e)
        if brows:
            b = box("brow", hm + Vector((s * 0.036 * hs, -fr * 0.9, 0.032)), (0.04, 0.02, 0.014), mats[brows], 0.005, rot=(0.25, s * 0.2, 0))
            parts.append(b)
        ear = blob("ear", hm + Vector((s * 0.09 * hs, 0.01, 0.0)), (0.014, 0.026, 0.034), 10, 6, mats["skin"])
        parts.append(ear)
    n = blob("nose", hm + Vector((0, -fr * 1.0, -0.01)), (0.02 * nose, 0.03 * nose, 0.034 * nose), 10, 8, mats["skin"])
    parts.append(n)
    if beard:
        bj = [(hm + Vector((0, -0.045, -0.025)), (0.085 * hs, 0.06)), (hm + Vector((0, -0.07, -0.085)), (0.07 * hs, 0.05)),
              (hm + Vector((0, -0.07, -0.15)), (0.04 * hs, 0.03))]
        bd = skin_body("beard", bj, [(0, 1), (1, 2)], levels=2)
        bd = roughen(bd, 0.012, 0.03)
        add_mat(bd, mats[beard])
        parts.append(bd)
        # Moustache.
        m = tube("tache", hm + Vector((-0.045, -fr * 0.93, -0.035)), hm + Vector((0.045, -fr * 0.93, -0.035)), 0.016, 0.016, 10, mats[beard])
        parts.append(m)
    for o in parts:
        o.data.update()
        bind_rigid(o, "head")
    return parts


def build_callum():
    """Callum MacLeod, principal keeper: navy gansey, oilskin trousers, sea boots,
    a grey-shot beard and a rolled wool watch cap."""
    name = "callum_keeper"
    p = {"height": 1.0, "width": 1.05, "girth": 1.05, "head": 1.15}
    mats = {
        "jumper": pmat("jumper", *KNIT_NAVY, scale=60, pattern='ribs', pscale=140, pstrength=0.45),
        "trousers": pmat("trousers", (0.16, 0.15, 0.13), (0.24, 0.22, 0.19), scale=25, pattern='weave', pscale=90, pstrength=0.25),
        "boots": pmat("boots", (0.06, 0.06, 0.06), (0.14, 0.13, 0.12), scale=18, rough=0.4),
        "skin": pmat("skin", *SKIN, scale=22, lo=0.35, hi=0.75),
        "beard": pmat("beard", (0.32, 0.30, 0.28), (0.62, 0.6, 0.57), scale=90, detail=8, lo=0.25, hi=0.8),
        "cap": pmat("cap", (0.45, 0.10, 0.08), (0.6, 0.16, 0.12), scale=60, pattern='ribs', pscale=160, pstrength=0.4),
        "eye": pmat("eye", (0.05, 0.05, 0.06), (0.1, 0.1, 0.12), rough=0.2),
        "leather": pmat("leather", (0.25, 0.15, 0.08), (0.38, 0.24, 0.13), scale=25, rough=0.5),
    }

    def region(c, n, P):
        if c.z > P["neck"].z - 0.01:
            return "skin"
        if is_hand(c, P):
            return "skin"
        if c.z < 0.3 and abs(c.x) < 0.2:
            return "boots"
        if c.z < P["hips"].z - 0.02 and abs(c.x) < 0.25:
            return "trousers"
        return "jumper"

    body, P = keeper_body(name, p, mats, region)
    rig = make_armature(name, P, HUMANOID_BONES)
    bind_auto(body, rig)
    parts = face(P, 1.0, mats, beard="beard", brows="beard", nose=1.05)
    # Watch cap: crown and a rolled brim.
    hm = P["head_mid"]
    crown = dome("cap", hm + Vector((0, 0.008, 0.035)), (0.106, 0.114, 0.12), cut=0.0, mat=mats["cap"])
    brim = ring("brim", hm + Vector((0, 0.008, 0.045)), 0.103, 0.022, (1.0, 1.08, 1.0), mat=mats["cap"])
    for o in (crown, brim):
        bind_rigid(o, "head")
    parts += [crown, brim]
    # Gansey rib at the hem, cuffs and a roll collar.
    hem = ring("hem", P["hips"] + Vector((0, 0.0, 0.02)), 0.15, 0.022, (1.03, 0.78, 1.0), mat=mats["jumper"])
    collar = ring("collar", P["neck"] + Vector((0, 0.0, -0.01)), 0.058, 0.022, (1.0, 1.0, 1.0), mat=mats["jumper"])
    bind_rigid(hem, "hips")
    bind_rigid(collar, "neck")
    parts += [hem, collar]
    for s, side in ((1, "L"), (-1, "R")):
        w = P["wrist." + side]
        e = P["elbow." + side]
        cuff = tube("cuff", w + (e - w).normalized() * 0.01, w + (e - w).normalized() * 0.06, 0.045, 0.048, 14, mats["jumper"])
        bind_rigid(cuff, "forearm." + side)
        # Sea boots: a stiff upper and a thick sole.
        a = P["ankle." + side]
        upper = tube("boot", a + Vector((0, 0.01, -0.06)), a + Vector((0, 0.005, 0.24)), 0.062, 0.068, 16, mats["boots"])
        bind_rigid(upper, "shin." + side)
        sole = box("sole", (a.x, -0.045, 0.018), (0.1, 0.27, 0.036), mats["boots"], 0.012)
        bind_rigid(sole, "foot." + side)
        parts += [cuff, upper, sole]
    belt = ring("belt", P["hips"] + Vector((0, 0.0, -0.03)), 0.155, 0.018, (1.02, 0.76, 0.7), mat=mats["leather"])
    bind_rigid(belt, "hips")
    parts.append(belt)
    body = join_into(body, parts)
    smooth(body)
    bake_textures(body)
    export(name, rig, body)
    if PREVIEW:
        preview(name, [body])


BUILDERS = {
    "callum_keeper": build_callum,
}

if __name__ == "__main__":
    for n, fn in BUILDERS.items():
        if ONLY and n not in ONLY:
            continue
        reset()
        fn()
