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

import json
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

def pmat(name, c1, c2, scale=30.0, detail=6.0, lo=0.3, hi=0.7, rough=0.85, pattern=None, pscale=60.0, pstrength=0.35,
         form=1.0, grade=True):
    """A painted-looking material: two colours broken up by noise, with an optional
    pattern (knit ribs, cables, stripes, weave) darkening it. `form` paints in the
    shape the way a hand-painted texture does: raised edges lighter, creases darker.
    `grade` lightens toward the head and darkens toward the feet."""
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
        wave.bands_direction = {'ribs': 'X', 'rings': 'Z', 'stripes': 'Z', 'weave': 'DIAGONAL', 'cables': 'X'}.get(pattern, 'X')
        if pattern == 'rings':
            wave.wave_profile = 'SAW'
        if pattern == 'cables':
            # Twisted cables: bands warped by a second, coarser wave up the body.
            wave.inputs["Distortion"].default_value = 6.0
            wave.inputs["Detail"].default_value = 3.0
        nt.links.new(coord.outputs["Object"], wave.inputs["Vector"])
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = 'RGBA'
        mix.blend_type = 'MULTIPLY'
        mix.inputs["Factor"].default_value = pstrength
        nt.links.new(col, mix.inputs["A"])
        nt.links.new(wave.outputs["Color"], mix.inputs["B"])
        col = mix.outputs["Result"]
    if form > 0:
        geo = nt.nodes.new("ShaderNodeNewGeometry")
        mr = nt.nodes.new("ShaderNodeMapRange")
        mr.inputs["From Min"].default_value = 0.44
        mr.inputs["From Max"].default_value = 0.56
        mr.inputs["To Min"].default_value = 1.0 - 0.32 * form
        mr.inputs["To Max"].default_value = 1.0 + 0.3 * form
        nt.links.new(geo.outputs["Pointiness"], mr.inputs["Value"])
        mul = nt.nodes.new("ShaderNodeMix")
        mul.data_type = 'RGBA'
        mul.blend_type = 'MULTIPLY'
        mul.inputs["Factor"].default_value = 1.0
        nt.links.new(col, mul.inputs["A"])
        nt.links.new(mr.outputs["Result"], mul.inputs["B"])
        col = mul.outputs["Result"]
    if grade:
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(coord.outputs["Object"], sep.inputs["Vector"])
        gr = nt.nodes.new("ShaderNodeMapRange")
        gr.inputs["From Min"].default_value = 0.0
        gr.inputs["From Max"].default_value = 1.8
        gr.inputs["To Min"].default_value = 0.72
        gr.inputs["To Max"].default_value = 1.08
        nt.links.new(sep.outputs["Z"], gr.inputs["Value"])
        g2 = nt.nodes.new("ShaderNodeMix")
        g2.data_type = 'RGBA'
        g2.blend_type = 'MULTIPLY'
        g2.inputs["Factor"].default_value = 1.0
        nt.links.new(col, g2.inputs["A"])
        nt.links.new(gr.outputs["Result"], g2.inputs["B"])
        col = g2.outputs["Result"]
    nt.links.new(col, bsdf.inputs["Base Color"])
    return m


def add_mat(ob, m):
    ob.data.materials.append(m)
    return len(ob.data.materials) - 1


def paint_regions(ob, rule, mats=None):
    """Give each face the material for the region rule(centre, normal) names: a key in
    `mats` when given, otherwise a material name."""
    slots = list(ob.data.materials)
    for p in ob.data.polygons:
        n = rule(Vector(p.center), Vector(p.normal))
        m = mats.get(n) if mats else bpy.data.materials.get(n)
        if m is not None and m in slots:
            p.material_index = slots.index(m)


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

def humanoid_joints(p, skip=()):
    """Joint graph for a humanoid from a proportions dict. Returns (joints, edges,
    named positions for the armature)."""
    H = p.get("height", 1.0)
    W = p.get("width", 1.0)
    G = p.get("girth", 1.0)
    hips_z = 0.84 * H * p.get("legs", 1.0)
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
        "hip": R("hip", 0.106), "knee": R("knee", 0.076), "ankle": R("ankle", 0.054), "toe": R("toe", (0.05, 0.038)),
    }
    names = [n for n in order if n not in skip]
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
    edges = [(idx[a], idx[b]) for a, b in E if a in idx and b in idx]
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


MARKERS = {}


def mark(key, p):
    """Remember a point (eyes, mouth) for the game, which puts glows and effects there.
    Written in the game's model space: +Y up, the character faces -Z, its left is -X."""
    MARKERS[key] = [-p[0], p[2], p[1]]


def export(name, rig, body):
    os.makedirs(OUT, exist_ok=True)
    if MARKERS:
        with open(os.path.join(OUT, name + ".json"), "w") as f:
            json.dump(MARKERS, f, indent=1)
        MARKERS.clear()
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
    # Frame the whole model: its bounds decide the distance.
    pts = [objs[0].matrix_world @ Vector(c) for c in objs[0].bound_box]
    size = max(max(p[i] for p in pts) - min(p[i] for p in pts) for i in range(3))
    mid = sum(pts, Vector()) / len(pts)
    d = max(height, size) * 1.9
    cam.location = mid + Vector((d * 0.55, -d, d * 0.35))
    direction = mid - cam.location
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
    # And a close-up of the head and shoulders.
    head = Vector((0, 0, height * 0.86))
    cam.data.lens = 85
    cam.location = head + Vector((0.45, -1.05, 0.08))
    cam.rotation_euler = (head - cam.location).to_track_quat('-Z', 'Y').to_euler()
    sc.render.resolution_x = 640
    sc.render.resolution_y = 640
    sc.render.filepath = os.path.join(OUT, "preview_" + name + "_head.png")
    bpy.ops.render.render(write_still=True)


# ---------------------------------------------------------------- keepers

KNIT_NAVY = ((0.10, 0.13, 0.22), (0.17, 0.21, 0.33))
SKIN = ((0.66, 0.45, 0.36), (0.80, 0.58, 0.47))


def gauss(d, r):
    return math.exp(-(d / r) ** 2)


def seg_dist(c, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (c - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (c - (a + ab * t)).length, t


def is_hand(c, P, margin=0.0):
    """True on the hand: near the wrist-to-fingers line, past the wrist."""
    for side in ("L", "R"):
        w, f = P["wrist." + side], P["fingers." + side]
        d, t = seg_dist(c, w, f + (f - w) * 0.3)
        if t > -0.12 + margin and d < 0.09:
            return True
    return False


# ---------------------------------------------------------------- heads

def sculpt_head(name, C, dims, mat, look):
    """A head from a dense sphere pushed into shape: a jaw that narrows to the chin, a
    heavy brow, sunken eye sockets, cheekbones, a full cranium. `look` tunes it:
    jaw (width), chin, brow, cheeks, gaunt (hollow cheeks, for the drowned)."""
    a, b, c = dims
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=36, v_segments=26, radius=1.0)
    jaw = look.get("jaw", 1.0)
    chin = look.get("chin", 1.0)
    brow = look.get("brow", 1.0)
    cheeks = look.get("cheeks", 1.0)
    gaunt = look.get("gaunt", 0.0)
    for v in bm.verts:
        u = v.co.copy()
        x, y, z = u.x * a, u.y * b, u.z * c
        front = max(0.0, -u.y)
        # The lower head narrows to the jaw, and to the neck at the back.
        if u.z < 0:
            x *= 1.0 - (0.22 / jaw) * (-u.z)
            if u.y > 0:
                y *= 1.0 - 0.38 * (-u.z)
        # Jaw corners and chin pushed forward and down.
        y -= 0.016 * chin * front * gauss(u.z + 0.75, 0.3) * gauss(u.x, 0.45)
        z -= 0.012 * chin * front * gauss(u.z + 0.85, 0.25) * gauss(u.x, 0.5)
        # Flatter face, fuller cranium behind.
        y += 0.012 * front * gauss(u.z - 0.1, 0.6)
        y += 0.012 * max(0.0, u.y) * max(0.0, u.z)
        # Heavy brow ridge, eye sockets under it.
        y -= 0.016 * brow * front * gauss(u.z - 0.28, 0.12) * gauss(abs(u.x) - 0.3, 0.32)
        for s in (-1, 1):
            d = math.hypot(u.x - s * 0.36, u.z - 0.12)
            y += 0.014 * front * gauss(d, 0.17)
            # Cheekbones out to the side and forward.
            d2 = math.hypot(u.x - s * 0.55, u.z + 0.12)
            x += s * 0.008 * cheeks * gauss(d2, 0.22) * (0.5 + front)
            y -= 0.006 * cheeks * front * gauss(d2, 0.2)
            if gaunt > 0:
                d3 = math.hypot(u.x - s * 0.5, u.z + 0.4)
                x -= s * 0.012 * gaunt * gauss(d3, 0.25)
        v.co = Vector((x, y, z)) + Vector(C)
    ob = mesh_from_bmesh(name, bm)
    smooth(ob)
    add_mat(ob, mat)
    return ob


def head_parts(C, dims, mats, look):
    """Nose, eyes with lids, ears and brows for a sculpted head (all bound to the head)."""
    a, b, c = dims
    C = Vector(C)
    parts = []
    nose = look.get("nose", 1.0)
    # Nose: bridge from between the brows to a fleshy tip, with nostril wings.
    nj = [(C + Vector((0, -b * 0.92, c * 0.12)), (0.011 * nose, 0.012 * nose)),
          (C + Vector((0, -b * 1.08, -c * 0.12)), (0.017 * nose, 0.018 * nose)),
          (C + Vector((0, -b * 1.12, -c * 0.24)), (0.021 * nose, 0.02 * nose))]
    n = skin_body("nose", nj, [(0, 1), (1, 2)], levels=2)
    add_mat(n, mats["skin"])
    parts.append(n)
    for s in (-1, 1):
        parts.append(blob("nostril", C + Vector((s * 0.016 * nose, -b * 1.03, -c * 0.27)), (0.012, 0.012, 0.01), 10, 6, mats["skin"]))
        # Small, deep-set eyes under heavy lids.
        e = C + Vector((s * a * 0.4, -b * 0.76, c * 0.1))
        mark("eye." + ("L" if s > 0 else "R"), e + Vector((0, -0.012, 0)))
        parts.append(blob("eye", e, (0.0135, 0.009, 0.0105), 12, 8, mats["eye_white"]))
        parts.append(blob("iris", e + Vector((0, -0.0072, 0)), (0.0072, 0.004, 0.0072), 10, 6, mats["iris"]))
        lid = dome("lid", e + Vector((0, -0.0015, 0.001)), (0.0165, 0.0125, 0.0135), cut=-0.05, mat=mats["skin"], segs=12, rings=8)
        parts.append(lid)
        if look.get("brows"):
            bw = look.get("brow_size", 1.0)
            inner = C + Vector((s * a * 0.16, -b * 0.95, c * 0.24))
            outer = C + Vector((s * a * 0.62, -b * 0.8, c * 0.27))
            brow = skin_body("brow", [(inner, (0.009 * bw, 0.007 * bw)), (outer, (0.006 * bw, 0.005 * bw))], [(0, 1)], levels=1)
            add_mat(brow, mats[look["brows"]])
            parts.append(roughen(brow, 0.002, 0.006))
        # Ears: a flattened shell with a rim.
        ear = blob("ear", C + Vector((s * a * 0.98, b * 0.05, c * 0.0)), (0.012, 0.03, 0.04), 12, 8, mats["skin"])
        parts.append(ear)
    for o in parts:
        bind_rigid(o, "head")
    return parts


def beard(C, dims, mat, kind="full", seed=1):
    """A chunky beard: a mass on the jaw with clumps hanging from it, and a moustache."""
    import random
    rnd = random.Random(seed)
    a, b, c = dims
    C = Vector(C)
    parts = []
    if kind in ("full", "long"):
        drop = 0.16 if kind == "long" else 0.1
        bj = [(C + Vector((0, -b * 0.5, -c * 0.45)), (a * 0.95, b * 0.55)),
              (C + Vector((0, -b * 0.82, -c * 0.85)), (a * 0.72, 0.05)),
              (C + Vector((0, -b * 0.85, -c * 0.85 - drop)), (a * 0.38, 0.032))]
        mass = skin_body("beard", bj, [(0, 1), (1, 2)], levels=2)
        parts.append(roughen(mass, 0.008, 0.025))
        for i in range(11):
            ang = -1.1 + 2.2 * i / 10.0
            top = C + Vector((math.sin(ang) * a * 0.66, -b * (0.6 + 0.3 * math.cos(ang)), -c * (0.72 + 0.1 * math.cos(ang))))
            bot = top + Vector((math.sin(ang) * 0.012, -0.012 * math.cos(ang), -(drop * 0.75 + rnd.uniform(0.0, 0.04))))
            parts.append(roughen(tube("clump", top, bot, 0.02, 0.004, 8), 0.003, 0.008))
    if kind == "short":
        bj = [(C + Vector((0, -b * 0.55, -c * 0.5)), (a * 0.98, b * 0.5)), (C + Vector((0, -b * 0.8, -c * 0.85)), (a * 0.6, 0.04))]
        parts.append(roughen(skin_body("beard", bj, [(0, 1)], levels=2), 0.006, 0.02))
    if kind != "none":
        for s in (-1, 1):
            m0 = C + Vector((s * 0.006, -b * 1.02, -c * 0.38))
            m1 = C + Vector((s * a * 0.55, -b * 0.85, -c * 0.52))
            parts.append(roughen(tube("tache", m0, m1, 0.017, 0.008, 8), 0.003, 0.01))
            # Sideburns down to the jaw.
            sb = skin_body("sideburn", [(C + Vector((s * a * 0.9, -b * 0.15, c * 0.12)), (0.012, 0.016)),
                                        (C + Vector((s * a * 0.78, -b * 0.42, -c * 0.42)), (0.018, 0.022))], [(0, 1)], levels=2)
            parts.append(roughen(sb, 0.003, 0.01))
    for o in parts:
        if not o.data.materials:
            add_mat(o, mat)
        bind_rigid(o, "head")
    return parts


def hair_back(C, dims, mat, low=-0.45, top=0.25):
    """Hair round the back and sides under a hat."""
    a, b, c = dims
    h = dome("hair", Vector(C) + Vector((0, 0.006, 0.0)), (a * 1.06, b * 1.05, c * 1.04), cut=low, mat=mat, segs=24, rings=14)
    # Only the back and sides, and only below the hat: drop the face and the crown.
    bm = bmesh.new()
    bm.from_mesh(h.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if (v.co - Vector(C)).y < -b * 0.25 or (v.co - Vector(C)).z > c * top], context='VERTS')
    bm.to_mesh(h.data)
    bm.free()
    h = roughen(h, 0.006, 0.02)
    bind_rigid(h, "head")
    return h


# ---------------------------------------------------------------- keepers

def keeper_body(name, p, mats, region):
    joints, edges, P = humanoid_joints(p, skip=("head_low", "head_mid", "head_top"))
    body = skin_body(name, joints, edges)
    for m in mats.values():
        add_mat(body, m)
    paint_regions(body, lambda c, n: region(c, n, P), mats)
    return body, P


def head_frame(P, hs):
    """Centre and half-sizes of the sculpted head on top of the neck."""
    C = P["head_low"] + Vector((0, 0.006, 0.075 * hs))
    return C, (0.083 * hs, 0.1 * hs, 0.118 * hs)


def boots(P, mats, side, top=0.26):
    a = P["ankle." + side]
    t = P["toe." + side]
    parts = []
    # A rubber sea boot: a shaft, a rolled top and a broad toe on a thick sole.
    parts.append(tube("boot", a + Vector((0, 0.008, -0.05)), a + Vector((0, 0.004, top)), 0.066, 0.072, 18, mats["boots"]))
    parts.append(ring("boot_top", a + Vector((0, 0.004, top)), 0.072, 0.014, mat=mats["boots"]))
    toe = skin_body("toe", [(a + Vector((0, 0.01, -0.04)), (0.062, 0.07)), (Vector((t.x, t.y - 0.02, 0.05)), (0.055, 0.045))], [(0, 1)], levels=2)
    add_mat(toe, mats["boots"])
    parts.append(toe)
    sole = box("sole", (a.x, (a.y + t.y) * 0.5 - 0.02, 0.016), (0.112, 0.3, 0.032), mats["sole"], 0.012)
    parts.append(sole)
    for o in parts[:2]:
        bind_rigid(o, "shin." + side)
    for o in parts[2:]:
        bind_rigid(o, "foot." + side)
    return parts


def keeper_mats(jumper, trousers, extra=None):
    m = {
        "jumper": jumper,
        "trousers": trousers,
        "boots": pmat("boots", (0.05, 0.05, 0.05), (0.13, 0.12, 0.11), scale=18, rough=0.35, form=1.4),
        "sole": pmat("sole", (0.03, 0.03, 0.03), (0.07, 0.07, 0.07), scale=30, rough=0.6),
        "skin": pmat("skin", *SKIN, scale=22, lo=0.35, hi=0.75, form=1.3),
        "eye_white": pmat("eye_white", (0.8, 0.78, 0.72), (0.9, 0.88, 0.82), rough=0.2, form=0.0, grade=False),
        "iris": pmat("iris", (0.08, 0.12, 0.16), (0.16, 0.24, 0.3), rough=0.15, form=0.0, grade=False),
        "leather": pmat("leather", (0.22, 0.13, 0.07), (0.36, 0.22, 0.12), scale=25, rough=0.5, form=1.5),
        "brass": pmat("brass", (0.55, 0.42, 0.18), (0.8, 0.66, 0.3), scale=40, rough=0.3, form=1.5),
    }
    m.update(extra or {})
    return m


def is_forearm(c, P):
    for side in ("L", "R"):
        d, t = seg_dist(c, P["elbow." + side], P["wrist." + side])
        if t > 0.12 and d < 0.085:
            return True
    return False


def keeper_region(rolled=False, coat=False):
    def region(c, n, P):
        if is_hand(c, P):
            return "skin"
        if rolled and is_forearm(c, P):
            return "skin"
        if c.z > P["neck"].z - 0.02 and abs(c.x) < 0.1:
            return "skin"
        if c.z < 0.3 and abs(c.x) < 0.22:
            return "boots"
        if c.z < P["hips"].z - 0.02 and abs(c.x) < 0.25:
            return "trousers"
        return "jumper"
    return region


def finish(name, body, rig, parts):
    body = join_into(body, parts)
    smooth(body)
    bake_textures(body)
    export(name, rig, body)
    if PREVIEW:
        preview(name, [body])


def build_callum():
    """Callum MacLeod, principal keeper: navy cable-knit gansey, dark oilskin trousers,
    sea boots, a big grey-shot beard and a rolled red wool watch cap."""
    name = "callum_keeper"
    hs = 1.15
    p = {"height": 1.0, "width": 1.08, "girth": 1.08, "head": hs}
    mats = keeper_mats(
        pmat("jumper", *KNIT_NAVY, scale=60, pattern='cables', pscale=55, pstrength=0.5, form=1.6),
        pmat("trousers", (0.13, 0.12, 0.10), (0.22, 0.2, 0.17), scale=25, pattern='weave', pscale=90, pstrength=0.25, rough=0.5, form=1.4),
        {
            "beard": pmat("beard", (0.3, 0.28, 0.26), (0.66, 0.64, 0.6), scale=120, detail=8, lo=0.25, hi=0.8, pattern='stripes', pscale=220, pstrength=0.35, form=1.8),
            "hair": pmat("hair", (0.3, 0.28, 0.26), (0.55, 0.53, 0.5), scale=120, detail=8, pattern='stripes', pscale=200, pstrength=0.35, form=1.6),
            "cap": pmat("cap", (0.42, 0.09, 0.07), (0.62, 0.16, 0.12), scale=60, pattern='ribs', pscale=160, pstrength=0.45, form=1.6),
        })
    body, P = keeper_body(name, p, mats, keeper_region(None))
    rig = make_armature(name, P, HUMANOID_BONES)
    bind_auto(body, rig)
    C, dims = head_frame(P, hs)
    head = sculpt_head("head", C, dims, mats["skin"], {"jaw": 1.1, "brow": 1.2, "cheeks": 1.0, "chin": 1.0})
    bind_rigid(head, "head")
    parts = [head] + head_parts(C, dims, mats, {"nose": 1.15, "brows": "beard"})
    parts += beard(C, dims, mats["beard"], "full", seed=3)
    parts.append(hair_back(C, dims, mats["hair"], low=-0.35))
    a, b, c = dims
    crown = dome("cap", Vector(C) + Vector((0, 0.008, c * 0.28)), (a * 1.14, b * 1.1, c * 0.95), cut=0.0, mat=mats["cap"])
    crown = roughen(crown, 0.004, 0.02)
    brim = ring("brim", Vector(C) + Vector((0, 0.008, c * 0.36)), a * 1.1, 0.024, (1.0, b / a, 1.0), mat=mats["cap"])
    for o in (crown, brim):
        bind_rigid(o, "head")
    parts += [crown, brim]
    # Gansey: rib at the hem and cuffs, a turned-down roll collar, a yoke seam.
    hem = ring("hem", P["hips"] + Vector((0, 0.0, 0.025)), 0.172, 0.024, (1.02, 0.78, 1.0), mat=mats["jumper"])
    collar = ring("collar", P["neck"] + Vector((0, 0.004, 0.0)), 0.066, 0.026, mat=mats["jumper"])
    bind_rigid(hem, "hips")
    bind_rigid(collar, "neck")
    parts += [hem, collar]
    for s, side in ((1, "L"), (-1, "R")):
        w, e = P["wrist." + side], P["elbow." + side]
        d = (e - w).normalized()
        cuff = tube("cuff", w + d * 0.0, w + d * 0.055, 0.05, 0.054, 14, mats["jumper"])
        bind_rigid(cuff, "forearm." + side)
        parts.append(cuff)
        parts += boots(P, mats, side)
    belt = ring("belt", P["hips"] + Vector((0, 0.0, -0.03)), 0.168, 0.02, (1.02, 0.76, 0.7), mat=mats["leather"])
    buckle = box("buckle", P["hips"] + Vector((0, -0.132, -0.03)), (0.05, 0.012, 0.04), mats["brass"], 0.004)
    knife = box("sheath", P["hips"] + Vector((-0.15, -0.06, -0.09)), (0.03, 0.02, 0.15), mats["leather"], 0.008)
    for o in (belt, buckle, knife):
        bind_rigid(o, "hips")
    parts += [belt, buckle, knife]
    finish(name, body, rig, parts)


def skirt(name, P, top, bottom, r_top, r_bot, mat, depth=0.8):
    """A coat skirt from the waist down: each side follows its thigh more toward the hem."""
    a = Vector((0, 0.01, top))
    b = Vector((0, 0.02, bottom))
    ob = tube(name, a, b, r_top, r_bot, 24, mat, caps=False)
    for v in ob.data.vertices:
        v.co.y *= depth
    ob.data.update()
    hips = ob.vertex_groups.new(name="hips")
    tl = ob.vertex_groups.new(name="thigh.L")
    tr = ob.vertex_groups.new(name="thigh.R")
    for v in ob.data.vertices:
        k = max(0.0, min(1.0, (top - v.co.z) / max(top - bottom, 0.01))) * 0.75
        side = max(-1.0, min(1.0, v.co.x / 0.08))
        hips.add([v.index], 1.0 - k, 'REPLACE')
        if side > 0:
            tl.add([v.index], k * side, 'REPLACE')
            hips.add([v.index], 1.0 - k * side, 'REPLACE')
        elif side < 0:
            tr.add([v.index], k * -side, 'REPLACE')
            hips.add([v.index], 1.0 - k * -side, 'REPLACE')
    return ob


def cuffs(P, mats, key, r=0.05, at_elbow=False):
    parts = []
    for side in ("L", "R"):
        w, e = P["wrist." + side], P["elbow." + side]
        d = (e - w).normalized()
        if at_elbow:
            cuff = tube("cuff", e - d * 0.02, e + d * 0.04, r + 0.008, r + 0.01, 14, mats[key])
            bind_rigid(cuff, "upper_arm." + side)
        else:
            cuff = tube("cuff", w, w + d * 0.055, r, r + 0.004, 14, mats[key])
            bind_rigid(cuff, "forearm." + side)
        parts.append(cuff)
    return parts


def build_hamish():
    """Hamish Fraser, engineer: stocky, in a blue-grey boiler suit with the sleeves rolled
    to the elbow, a tweed flat cap, a short dark beard and a big moustache."""
    name = "hamish_keeper"
    hs = 1.13
    p = {"height": 0.97, "width": 1.14, "girth": 1.2, "head": hs, "arms": 0.97}
    suit = pmat("suit", (0.22, 0.27, 0.32), (0.32, 0.38, 0.43), scale=35, pattern='weave', pscale=110, pstrength=0.2, rough=0.7, form=1.5)
    mats = keeper_mats(suit, suit, {
        "beard": pmat("beard", (0.08, 0.06, 0.05), (0.2, 0.15, 0.11), scale=120, detail=8, pattern='stripes', pscale=220, pstrength=0.35, form=1.8),
        "tweed": pmat("tweed", (0.28, 0.24, 0.17), (0.42, 0.36, 0.26), scale=90, detail=8, pattern='weave', pscale=140, pstrength=0.35, form=1.4),
        "oil": pmat("oil", (0.12, 0.12, 0.13), (0.3, 0.3, 0.32), scale=40, rough=0.3, form=1.6),
    })
    mats["skin"] = pmat("skin", (0.7, 0.47, 0.37), (0.84, 0.6, 0.48), scale=22, lo=0.35, hi=0.75, form=1.3)
    body, P = keeper_body(name, p, mats, keeper_region(rolled=True))
    rig = make_armature(name, P, HUMANOID_BONES)
    bind_auto(body, rig)
    C, dims = head_frame(P, hs)
    a, b, c = dims
    head = sculpt_head("head", C, dims, mats["skin"], {"jaw": 1.3, "brow": 1.0, "cheeks": 1.3, "chin": 0.8})
    bind_rigid(head, "head")
    parts = [head] + head_parts(C, dims, mats, {"nose": 1.3, "brows": "beard"})
    parts += beard(C, dims, mats["beard"], "short", seed=5)
    parts.append(hair_back(C, dims, mats["beard"], low=-0.3))
    # Flat cap: a squashed crown leaning forward over a stiff peak.
    crown = blob("cap", Vector(C) + Vector((0, -0.008, c * 0.6)), (a * 1.2, b * 1.22, c * 0.5), 24, 12, mats["tweed"])
    crown = roughen(crown, 0.003, 0.02)
    peak = box("peak", Vector(C) + Vector((0, -b * 1.05, c * 0.46)), (a * 1.6, 0.07, 0.012), mats["tweed"], 0.006, rot=(0.18, 0, 0))
    for o in (crown, peak):
        bind_rigid(o, "head")
    parts += [crown, peak]
    # Boiler suit: a collar, chest pockets, sleeves rolled to the elbow, a work belt.
    collar = ring("collar", P["neck"] + Vector((0, 0.006, -0.01)), 0.072, 0.02, mat=mats["jumper"])
    bind_rigid(collar, "neck")
    parts.append(collar)
    for s in (1, -1):
        pk = box("pocket", P["chest"] + Vector((s * 0.09, -0.142, 0.06)), (0.075, 0.012, 0.085), mats["jumper"], 0.003)
        flap = box("flap", P["chest"] + Vector((s * 0.09, -0.15, 0.1)), (0.08, 0.012, 0.025), mats["jumper"], 0.003)
        for o in (pk, flap):
            bind_rigid(o, "chest")
            parts.append(o)
    parts += cuffs(P, mats, "jumper", 0.058, at_elbow=True)
    for side in ("L", "R"):
        parts += boots(P, mats, side, top=0.2)
    belt = ring("belt", P["hips"] + Vector((0, 0.0, -0.02)), 0.18, 0.022, (1.02, 0.76, 0.7), mat=mats["leather"])
    buckle = box("buckle", P["hips"] + Vector((0, -0.142, -0.02)), (0.055, 0.012, 0.045), mats["brass"], 0.004)
    spanner = box("spanner", P["hips"] + Vector((0.17, -0.07, -0.1)), (0.02, 0.012, 0.2), mats["oil"], 0.004)
    rag = box("rag", P["hips"] + Vector((-0.16, 0.06, -0.1)), (0.05, 0.02, 0.14), mats["tweed"], 0.01)
    for o in (belt, buckle, spanner, rag):
        bind_rigid(o, "hips")
    parts += [belt, buckle, spanner, rag]
    finish(name, body, rig, parts)


def build_mairi():
    """Mairi Campbell, gardener and runner: lighter build, auburn hair in a bun and a
    long braid, a green waxed jacket over a cream jumper, cord trousers, green wellies."""
    name = "mairi_keeper"
    hs = 1.1
    p = {"height": 0.96, "width": 0.98, "girth": 0.95, "head": hs, "arms": 0.96}
    jacket = pmat("jacket", (0.14, 0.2, 0.13), (0.24, 0.3, 0.18), scale=28, rough=0.45, form=1.6)
    cords = pmat("cords", (0.3, 0.2, 0.12), (0.42, 0.3, 0.18), scale=30, pattern='ribs', pscale=260, pstrength=0.3, form=1.4)
    mats = keeper_mats(jacket, cords, {
        "hair": pmat("hair", (0.36, 0.13, 0.06), (0.62, 0.27, 0.12), scale=120, detail=8, pattern='stripes', pscale=220, pstrength=0.4, form=1.8),
        "cream": pmat("cream", (0.72, 0.68, 0.58), (0.86, 0.82, 0.72), scale=60, pattern='ribs', pscale=160, pstrength=0.3, form=1.4),
    })
    mats["boots"] = pmat("boots", (0.06, 0.16, 0.08), (0.12, 0.26, 0.14), scale=18, rough=0.35, form=1.4)
    mats["skin"] = pmat("skin", (0.74, 0.55, 0.45), (0.88, 0.68, 0.57), scale=22, lo=0.35, hi=0.75, form=1.2)
    body, P = keeper_body(name, p, mats, keeper_region())
    rig = make_armature(name, P, HUMANOID_BONES)
    bind_auto(body, rig)
    C, dims = head_frame(P, hs)
    a, b, c = dims
    head = sculpt_head("head", C, dims, mats["skin"], {"jaw": 0.85, "brow": 0.6, "cheeks": 1.1, "chin": 0.7})
    bind_rigid(head, "head")
    parts = [head] + head_parts(C, dims, mats, {"nose": 0.9, "brows": "hair", "brow_size": 0.7})
    # Hair: a full cap of hair with a side parting, a bun and a braid down the back.
    hair = dome("hair", Vector(C) + Vector((0, 0.006, -c * 0.02)), (a * 1.08, b * 1.07, c * 1.07), cut=-0.35, mat=mats["hair"], segs=28, rings=16)
    bm = bmesh.new()
    bm.from_mesh(hair.data)
    # Off the face: a hairline high on the forehead, swept back at the temples.
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if (v.co - Vector(C)).y < -b * 0.5 and (v.co - Vector(C)).z < c * 0.5], context='VERTS')
    bm.to_mesh(hair.data)
    bm.free()
    hair = roughen(hair, 0.005, 0.02)
    bun = roughen(blob("bun", Vector(C) + Vector((0, b * 0.95, c * 0.25)), (0.05, 0.045, 0.05), 14, 10, mats["hair"]), 0.004, 0.015)
    parts += [hair, bun]
    for k in range(7):
        seg = blob("braid", Vector(C) + Vector((0.006 * (-1) ** k, b * 1.02 + 0.012 * k, -c * 0.25 - 0.042 * k)), (0.03 - 0.002 * k, 0.026, 0.032), 10, 8, mats["hair"])
        parts.append(seg)
    for o in [hair, bun] + parts[-7:]:
        bind_rigid(o, "head")
    # Jumper roll neck under the jacket, the jacket's collar, pockets and cuffs.
    neck = ring("rollneck", P["neck"] + Vector((0, 0.004, 0.0)), 0.062, 0.028, mat=mats["cream"])
    bind_rigid(neck, "neck")
    jcollar = ring("jcollar", P["neck"] + Vector((0, 0.01, -0.035)), 0.088, 0.02, (1.0, 1.0, 1.0), mat=mats["jumper"])
    bind_rigid(jcollar, "chest")
    parts += [neck, jcollar]
    hem = skirt("jskirt", P, P["hips"].z + 0.02, P["hips"].z - 0.17, 0.175, 0.19, mats["jumper"], depth=0.78)
    parts.append(hem)
    for s in (1, -1):
        pk = box("pocket", P["hips"] + Vector((s * 0.12, -0.14, -0.07)), (0.09, 0.03, 0.08), mats["jumper"], 0.01)
        bind_rigid(pk, "hips")
        parts.append(pk)
    parts += cuffs(P, mats, "cream", 0.046)
    for side in ("L", "R"):
        parts += boots(P, mats, side, top=0.3)
    finish(name, body, rig, parts)


def build_ewan():
    """Ewan Reid, frontline: tall and young, a yellow oilskin coat to the knee buttoned
    up, a sou'wester, dark stubble."""
    name = "ewan_keeper"
    hs = 1.12
    p = {"height": 1.04, "width": 1.06, "girth": 1.02, "head": hs}
    oilskin = pmat("oilskin", (0.72, 0.52, 0.06), (0.9, 0.7, 0.14), scale=25, rough=0.3, form=1.8)
    mats = keeper_mats(oilskin, pmat("trousers", (0.1, 0.1, 0.1), (0.2, 0.19, 0.17), scale=25, pattern='weave', pscale=90, pstrength=0.25, form=1.4), {
        "beard": pmat("stubble", (0.2, 0.14, 0.1), (0.32, 0.22, 0.15), scale=200, detail=8, form=0.8),
        "hair": pmat("hair", (0.12, 0.08, 0.05), (0.26, 0.17, 0.1), scale=120, detail=8, pattern='stripes', pscale=220, pstrength=0.4, form=1.8),
        "toggle": pmat("toggle", (0.15, 0.1, 0.06), (0.3, 0.2, 0.12), scale=40, form=1.4),
    })
    body, P = keeper_body(name, p, mats, keeper_region())
    rig = make_armature(name, P, HUMANOID_BONES)
    bind_auto(body, rig)
    C, dims = head_frame(P, hs)
    a, b, c = dims
    head = sculpt_head("head", C, dims, mats["skin"], {"jaw": 1.15, "brow": 0.9, "cheeks": 0.9, "chin": 1.2})
    bind_rigid(head, "head")
    parts = [head] + head_parts(C, dims, mats, {"nose": 1.0, "brows": "hair"})
    parts += beard(C, dims, mats["beard"], "short", seed=7)
    parts.append(hair_back(C, dims, mats["hair"], low=-0.25))
    # Sou'wester: a rounded crown and a brim that sweeps down longer at the back.
    crown = dome("hat", Vector(C) + Vector((0, 0.01, c * 0.3)), (a * 1.16, b * 1.12, c * 0.9), cut=0.0, mat=mats["jumper"])
    brim = tube("brim", Vector(C) + Vector((0, 0.02, c * 0.33)), Vector(C) + Vector((0, 0.03, c * 0.26)), a * 1.12, a * 1.55, 28, mats["jumper"], caps=False)
    brim = subdivide(brim, 1)
    for v in brim.data.vertices:
        back = max(0.0, v.co.y - C[1])
        v.co.z -= back * 0.45
        v.co.y += back * 0.25
    brim.data.update()
    for o in (crown, brim):
        bind_rigid(o, "head")
    parts += [crown, brim]
    # The coat: a high collar, toggles down the front, a long skirt to the knee.
    collar = tube("collar", P["neck"] + Vector((0, 0.01, -0.04)), P["neck"] + Vector((0, 0.01, 0.06)), 0.09, 0.085, 20, mats["jumper"], caps=False)
    bind_rigid(collar, "neck")
    parts.append(collar)
    for k in range(4):
        tg = box("toggle", P["spine"] + Vector((0, -0.135 - 0.005 * k, 0.17 - 0.1 * k)), (0.035, 0.016, 0.014), mats["toggle"], 0.005)
        bind_rigid(tg, "spine" if k > 1 else "chest")
        parts.append(tg)
    coat = skirt("coat", P, P["hips"].z + 0.03, P["knee.L"].z - 0.02, 0.18, 0.22, mats["jumper"], depth=0.8)
    parts.append(coat)
    parts += cuffs(P, mats, "jumper", 0.058)
    for side in ("L", "R"):
        parts += boots(P, mats, side, top=0.28)
    finish(name, body, rig, parts)


# ---------------------------------------------------------------- the drowned

def creature_mats(skin1, skin2, extra=None, skin_scale=14):
    m = {
        "skin": pmat("skin", skin1, skin2, scale=skin_scale, detail=8, lo=0.25, hi=0.8, rough=0.3, form=1.8),
        "dark": pmat("dark", (0.04, 0.05, 0.05), (0.08, 0.09, 0.09), rough=0.6, form=0.4, grade=False),
        "kelp": pmat("kelp", (0.06, 0.12, 0.06), (0.14, 0.22, 0.1), scale=60, pattern='stripes', pscale=120, pstrength=0.3, rough=0.3, form=1.2),
        "barnacle": pmat("barnacle", (0.55, 0.53, 0.48), (0.8, 0.78, 0.7), scale=80, detail=8, rough=0.8, form=2.0),
        "rags": pmat("rags", (0.12, 0.1, 0.08), (0.24, 0.2, 0.15), scale=40, pattern='weave', pscale=120, pstrength=0.3, form=1.6),
    }
    m.update(extra or {})
    return m


def on_arm(c, P, r=0.13):
    for side in ("L", "R"):
        for a, b in (("shoulder", "elbow"), ("elbow", "wrist"), ("wrist", "fingers")):
            d, t = seg_dist(c, P[a + "." + side], P[b + "." + side])
            if d < r and (a != "shoulder" or t > 0.2):
                return True
    return False


def creature_region(rag_top, rag_bottom):
    def region(c, n, P):
        if rag_bottom < c.z < rag_top and abs(c.x) < 0.45 and not on_arm(c, P):
            return "rags"
        return "skin"
    return region


def kelp_strands(origin_pts, mat, bone, length=(0.3, 0.6), seed=2):
    import random
    rnd = random.Random(seed)
    parts = []
    for p0 in origin_pts:
        # A frond: flat, wavy and tapering, hanging and curling a little.
        p0 = Vector(p0)
        L = rnd.uniform(*length)
        sway = Vector((rnd.uniform(-0.05, 0.05), rnd.uniform(0.0, 0.05), 0))
        pts = [p0 + sway * (k / 3.0) ** 2 + Vector((0.015 * math.sin(k * 2.1 + rnd.random() * 3), 0, -L * k / 3.0)) for k in range(4)]
        widths = [(0.02, 0.007), (0.026, 0.007), (0.02, 0.006), (0.007, 0.003)]
        st = skin_body("kelp", list(zip(pts, widths)), [(0, 1), (1, 2), (2, 3)], levels=1)
        add_mat(st, mat)
        bind_rigid(st, bone)
        parts.append(st)
    return parts


def barnacles(points, mat, bone, seed=4):
    import random
    rnd = random.Random(seed)
    parts = []
    for p in points:
        n = Vector(p).normalized()
        cone = tube("barnacle", Vector(p), Vector(p) + Vector((n.x, n.y, 0.4)).normalized() * 0.03, 0.02 * rnd.uniform(0.7, 1.3), 0.008, 7, mat)
        bind_rigid(cone, bone)
        parts.append(cone)
    return parts


def build_bloated():
    """The Bloated Dead: a drowned hulk, swollen with seawater. A distended belly and
    chest, a small head sunk forward between the shoulders, long swollen arms, short legs,
    mottled grey-green skin, rotten rags, barnacles and trailing kelp."""
    name = "bloated"
    hs = 0.95
    p = {"height": 1.06, "legs": 0.82, "width": 1.35, "girth": 1.0, "head": hs, "arms": 1.18, "hunch": 0.07, "stance": 1.3,
         "r": {"hips": (0.27, 0.23), "spine": (0.34, 0.31), "chest": (0.33, 0.27), "upper": (0.27, 0.2), "neck": 0.12,
               "shoulder": 0.105, "elbow": 0.085, "wrist": 0.068, "hand": (0.075, 0.045), "fingers": (0.06, 0.036), "thumb": 0.03,
               "hip": 0.14, "knee": 0.105, "ankle": 0.08, "toe": (0.075, 0.05)}}
    mats = creature_mats((0.26, 0.31, 0.25), (0.46, 0.5, 0.4), {
        "mouth": pmat("mouth", (0.08, 0.04, 0.04), (0.16, 0.06, 0.06), rough=0.2, form=0.4, grade=False),
        "eye_white": pmat("eye_white", (0.85, 0.85, 0.6), (0.95, 0.95, 0.7), rough=0.2, form=0.0, grade=False),
        "iris": pmat("iris", (0.5, 0.6, 0.2), (0.7, 0.8, 0.3), rough=0.2, form=0.0, grade=False),
    })
    joints, edges, P = humanoid_joints(p, skip=("head_low", "head_mid", "head_top"))
    body = skin_body(name, joints, edges)
    body = roughen(body, 0.02, 0.18)
    for m in mats.values():
        add_mat(body, m)
    paint_regions(body, lambda c, n: creature_region(P["hips"].z + 0.02, P["knee.L"].z + 0.05)(c, n, P), mats)
    rig = make_armature(name, P, HUMANOID_BONES)
    bind_auto(body, rig)
    C, dims = head_frame(P, hs)
    C = C + Vector((0, -0.06, -0.06))
    a, b, c = dims
    head = sculpt_head("head", C, dims, mats["skin"], {"jaw": 1.5, "chin": 0.4, "brow": 0.5, "cheeks": 1.8})
    head = roughen(head, 0.006, 0.05)
    bind_rigid(head, "head")
    parts = [head] + head_parts(C, dims, mats, {"nose": 0.6})
    mouth = blob("mouth", C + Vector((0, -b * 0.82, -c * 0.45)), (0.035, 0.02, 0.028), 12, 8, mats["mouth"])
    bind_rigid(mouth, "head")
    parts.append(mouth)
    mark("mouth", C + Vector((0, -b * 0.9, -c * 0.45)))
    parts += barnacles([P["upper"] + Vector((0.12, 0.15, 0.06)), P["upper"] + Vector((-0.15, 0.13, 0.02)), P["chest"] + Vector((0.2, 0.18, 0.0)),
                        P["chest"] + Vector((0.05, 0.25, -0.05)), P["spine"] + Vector((-0.2, 0.22, 0.02))], mats["barnacle"], "chest")
    parts += barnacles([P["shoulder.L"] + Vector((0.04, 0.0, 0.06)), P["elbow.L"] + Vector((0.05, 0.04, 0.0))], mats["barnacle"], "upper_arm.L", seed=6)
    parts += kelp_strands([P["upper"] + Vector((x, 0.12, 0.06)) for x in (-0.18, -0.06, 0.1, 0.2)], mats["kelp"], "chest", (0.3, 0.55))
    parts += kelp_strands([C + Vector((x, 0.03, c * 0.6)) for x in (-0.05, 0.02, 0.06)], mats["kelp"], "head", (0.15, 0.3), seed=9)
    rag = skirt("rags", P, P["hips"].z + 0.05, P["knee.L"].z + 0.08, 0.3, 0.33, mats["rags"], depth=0.85)
    rag = roughen(rag, 0.03, 0.06)
    parts.append(rag)
    finish(name, body, rig, parts)


def build_smotherer():
    """The Smotherer: tall, gaunt and pale, with arms that reach past its knees and long
    webbed fingers, a long hollow-cheeked face with black sockets, a hood of kelp and a
    tattered shroud about its hips."""
    name = "smotherer"
    hs = 1.0
    p = {"height": 1.1, "legs": 1.05, "width": 0.92, "girth": 0.62, "head": hs, "arms": 1.4, "fingers": 1.25, "hunch": 0.06,
         "r": {"neck": 0.04, "shoulder": 0.05, "elbow": 0.036, "wrist": 0.028, "hand": (0.048, 0.016), "fingers": (0.044, 0.012),
               "thumb": 0.014, "hip": 0.07, "knee": 0.048, "ankle": 0.035, "toe": (0.04, 0.026), "chest": (0.17, 0.11), "upper": (0.16, 0.1)}}
    mats = creature_mats((0.5, 0.56, 0.55), (0.7, 0.75, 0.72), {
        "socket": pmat("socket", (0.01, 0.01, 0.02), (0.03, 0.03, 0.04), rough=0.9, form=0.0, grade=False),
        "ribs": pmat("ribs", (0.47, 0.53, 0.52), (0.68, 0.72, 0.7), scale=12, pattern='rings', pscale=16, pstrength=0.28, rough=0.35, form=1.8),
    }, skin_scale=12)
    joints, edges, P = humanoid_joints(p, skip=("head_low", "head_mid", "head_top"))
    body = skin_body(name, joints, edges)
    for m in mats.values():
        add_mat(body, m)

    def region(c, n, P):
        if on_arm(c, P, 0.08):
            return "skin"
        if P["hips"].z - 0.18 < c.z < P["hips"].z + 0.06 and abs(c.x) < 0.3:
            return "rags"
        if P["spine"].z < c.z < P["upper"].z and abs(c.x) < 0.17:
            return "ribs"
        return "skin"
    paint_regions(body, lambda c, n: region(c, n, P), mats)
    rig = make_armature(name, P, HUMANOID_BONES)
    bind_auto(body, rig)
    C, dims = head_frame(P, hs)
    dims = (dims[0] * 0.85, dims[1], dims[2] * 1.25)
    C = C + Vector((0, -0.03, 0.02))
    a, b, c = dims
    head = sculpt_head("head", C, dims, mats["skin"], {"jaw": 0.8, "chin": 1.3, "brow": 1.6, "cheeks": 1.5, "gaunt": 1.6})
    bind_rigid(head, "head")
    parts = [head]
    for s in (-1, 1):
        sock = blob("socket", C + Vector((s * a * 0.4, -b * 0.8, c * 0.08)), (0.022, 0.012, 0.02), 12, 8, mats["socket"])
        bind_rigid(sock, "head")
        parts.append(sock)
        mark("eye." + ("L" if s > 0 else "R"), C + Vector((s * a * 0.4, -b * 0.9, c * 0.08)))
    nose = skin_body("nose", [(C + Vector((0, -b * 0.92, c * 0.05)), (0.008, 0.01)), (C + Vector((0, -b * 1.02, -c * 0.15)), (0.012, 0.012))], [(0, 1)], levels=2)
    add_mat(nose, mats["skin"])
    bind_rigid(nose, "head")
    mouth = box("mouth", C + Vector((0, -b * 0.86, -c * 0.45)), (0.05, 0.012, 0.008), mats["socket"], 0.003)
    bind_rigid(mouth, "head")
    parts += [nose, mouth]
    # A hood of kelp hanging from the crown down the back and over the shoulders.
    hood = dome("hood", C + Vector((0, 0.01, 0.0)), (a * 1.12, b * 1.1, c * 1.06), cut=-0.2, mat=mats["kelp"], segs=24, rings=12)
    bm = bmesh.new()
    bm.from_mesh(hood.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if (v.co - C).y < -b * 0.62 and (v.co - C).z < c * 0.55], context='VERTS')
    bm.to_mesh(hood.data)
    bm.free()
    hood = roughen(hood, 0.008, 0.03)
    bind_rigid(hood, "head")
    parts.append(hood)
    parts += kelp_strands([C + Vector((x, b * 0.5, -c * 0.1)) for x in (-0.07, -0.03, 0.01, 0.05, 0.08)], mats["kelp"], "head", (0.3, 0.6), seed=12)
    parts += kelp_strands([C + Vector((x * 1.4, -b * 0.3, -c * 0.2)) for x in (-0.07, 0.07)], mats["kelp"], "head", (0.25, 0.4), seed=13)
    shroud = skirt("shroud", P, P["hips"].z + 0.06, P["knee.L"].z - 0.05, 0.16, 0.2, mats["rags"], depth=0.8)
    parts.append(roughen(shroud, 0.03, 0.05))
    finish(name, body, rig, parts)


# ---------------------------------------------------------------- crab and squid

def bind_parts(parts, bone):
    for o in parts:
        bind_rigid(o, bone)
    return parts


def finish_rigid(name, rig, parts, preview_h=1.2):
    """Join rigidly-bound parts (no automatic weights) into one mesh with an armature."""
    body = parts[0]
    body = join_into(body, parts[1:])
    mod = body.modifiers.new("rig", 'ARMATURE')
    mod.object = rig
    body.parent = rig
    smooth(body)
    bake_textures(body)
    export(name, rig, body)
    if PREVIEW:
        preview(name, [body], preview_h)


def build_crab():
    """The Armoured Crab: a broad domed carapace, spiked at the rim and grown over with
    rusted scrap and barnacles, eyes on stalks, six jointed legs, one huge pincer on its
    right and a small one on its left."""
    name = "crab"
    mats = {
        "shell": pmat("shell", (0.2, 0.06, 0.04), (0.42, 0.17, 0.1), scale=10, detail=8, lo=0.25, hi=0.8, rough=0.4, form=2.0),
        "under": pmat("under", (0.6, 0.5, 0.4), (0.78, 0.68, 0.55), scale=20, rough=0.6, form=1.5),
        "tips": pmat("tips", (0.03, 0.03, 0.03), (0.1, 0.08, 0.07), rough=0.3, form=1.2),
        "rust": pmat("rust", (0.3, 0.15, 0.07), (0.55, 0.3, 0.15), scale=30, detail=8, rough=0.7, form=1.8),
        "barnacle": pmat("barnacle", (0.55, 0.53, 0.48), (0.8, 0.78, 0.7), scale=80, detail=8, rough=0.8, form=2.0),
        "eye": pmat("eye", (0.02, 0.02, 0.02), (0.06, 0.05, 0.05), rough=0.1, form=0.0, grade=False),
    }
    P = {"body_h": Vector((0, 0.35, 0.58)), "body_t": Vector((0, -0.35, 0.58))}
    bones = [("body", "body_h", "body_t", None)]
    for s, side in ((1, "L"), (-1, "R")):
        for i in range(3):
            hip = Vector((s * 0.6, -0.28 + 0.3 * i, 0.5))
            knee = Vector((s * 1.0, -0.34 + 0.34 * i, 0.78))
            tip = Vector((s * 1.38, -0.42 + 0.4 * i, 0.02))
            P[f"hip{i}{side}"], P[f"knee{i}{side}"], P[f"tip{i}{side}"] = hip, knee, tip
            bones += [(f"leg{i}.{side}", f"hip{i}{side}", f"knee{i}{side}", "body"),
                      (f"leg{i}.{side}.tip", f"knee{i}{side}", f"tip{i}{side}", f"leg{i}.{side}")]
    big = -1
    P["arm0R"], P["arm1R"], P["clawR"] = Vector((-0.5, -0.45, 0.55)), Vector((-0.78, -0.92, 0.62)), Vector((-0.74, -1.5, 0.6))
    P["arm0L"], P["arm1L"], P["clawL"] = Vector((0.5, -0.45, 0.55)), Vector((0.66, -0.82, 0.55)), Vector((0.62, -1.08, 0.5))
    for side in ("L", "R"):
        bones += [(f"claw_arm.{side}", f"arm0{side}", f"arm1{side}", "body"), (f"claw.{side}", f"arm1{side}", f"claw{side}", f"claw_arm.{side}")]
    rig = make_armature(name, P, bones)
    parts = []
    # Carapace: a wide dome flattened underneath, with a lip and spikes round the rim.
    cara = blob("carapace", (0, 0.02, 0.62), (0.86, 0.66, 0.3), 32, 16, mats["shell"])
    cara = roughen(cara, 0.02, 0.15)
    under = blob("under", (0, 0.0, 0.48), (0.74, 0.56, 0.17), 24, 10, mats["under"])
    parts += [cara, under]
    for k in range(14):
        a = 2 * math.pi * k / 14
        rim = Vector((math.sin(a) * 0.84, math.cos(a) * 0.64 + 0.02, 0.6))
        spike = tube("spike", rim, rim + Vector((math.sin(a) * 0.12, math.cos(a) * 0.1, 0.03)), 0.05, 0.005, 7, mats["shell"])
        parts.append(spike)
    # Scrap grown into the shell, and barnacles.
    for c, sz, r in (((-0.3, 0.1, 0.88), (0.3, 0.2, 0.12), 0.4), ((0.28, -0.1, 0.87), (0.24, 0.18, 0.1), -0.6), ((0.05, 0.32, 0.86), (0.2, 0.14, 0.1), 1.0)):
        parts.append(box("scrap", c, sz, mats["rust"], 0.015, rot=(0.1, 0.15, r)))
    parts += barnacles([Vector((x, y, 0.85)) for x, y in ((0.45, 0.25), (-0.5, -0.2), (0.15, -0.35), (-0.15, 0.4), (0.55, -0.05))], mats["barnacle"], "body", seed=3)
    # Eyes on stalks, and mouthparts.
    for s in (1, -1):
        st0 = Vector((s * 0.17, -0.52, 0.72))
        st1 = Vector((s * 0.21, -0.6, 0.98))
        parts.append(tube("stalk", st0, st1, 0.04, 0.03, 8, mats["shell"]))
        parts.append(blob("eye", st1 + Vector((0, -0.01, 0.03)), (0.055, 0.055, 0.055), 12, 8, mats["eye"]))
        mark("eye." + ("L" if s > 0 else "R"), st1 + Vector((0, -0.06, 0.03)))
    parts.append(box("mouth", (0, -0.62, 0.5), (0.26, 0.06, 0.12), mats["under"], 0.02))
    bind_parts(parts, "body")
    # Legs: two tapering segments with knobbly joints and black tips.
    for s, side in ((1, "L"), (-1, "R")):
        for i in range(3):
            hip, knee, tip = P[f"hip{i}{side}"], P[f"knee{i}{side}"], P[f"tip{i}{side}"]
            up = tube("leg", hip, knee, 0.075, 0.062, 10, mats["shell"])
            joint = blob("joint", knee, (0.075, 0.075, 0.075), 10, 8, mats["shell"])
            lo = tube("leg", knee, tip + (knee - tip) * 0.2, 0.062, 0.04, 10, mats["shell"])
            point = tube("tip", tip + (knee - tip) * 0.2, tip, 0.04, 0.004, 8, mats["tips"])
            parts += bind_parts([up, joint], f"leg{i}.{side}") + bind_parts([lo, point], f"leg{i}.{side}.tip")
    # The big claw: a thick arm, a swollen palm and a pair of crushing fingers.
    for side, k in (("R", 1.0), ("L", 0.55)):
        a0, a1, c = P[f"arm0{side}"], P[f"arm1{side}"], P[f"claw{side}"]
        arm = tube("arm", a0, a1, 0.11 * k, 0.1 * k, 12, mats["shell"])
        elbow = blob("elbow", a1, (0.11 * k, 0.11 * k, 0.11 * k), 12, 8, mats["shell"])
        d = (c - a1)
        palm = blob("palm", a1 + d * 0.38, (0.17 * k, 0.24 * k, 0.15 * k), 16, 10, mats["shell"])
        palm = roughen(palm, 0.01, 0.1)
        top = tube("finger", a1 + d * 0.62 + Vector((0, 0, 0.05 * k)), c + Vector((0, 0, 0.06 * k)), 0.08 * k, 0.012, 10, mats["shell"])
        bot = tube("finger", a1 + d * 0.62 + Vector((0, 0, -0.05 * k)), c + Vector((0, -0.02, -0.05 * k)), 0.065 * k, 0.012, 10, mats["shell"])
        tipt = blob("tip", c + Vector((0, 0, 0.06 * k)), (0.03, 0.04, 0.03), 8, 6, mats["tips"])
        tipb = blob("tip", c + Vector((0, -0.02, -0.05 * k)), (0.025, 0.035, 0.025), 8, 6, mats["tips"])
        parts += bind_parts([arm, elbow], f"claw_arm.{side}") + bind_parts([palm, top, bot, tipt, tipb], f"claw.{side}")
    finish_rigid(name, rig, parts, 1.2)


def build_squid():
    """The Wall-Crawling Squid: a long mottled mantle with fins, big eyes on the sides of
    its head, and six arms splayed out on the ground to crawl with."""
    name = "squid"
    mats = {
        "skin": pmat("skin", (0.12, 0.16, 0.24), (0.3, 0.36, 0.48), scale=12, detail=8, lo=0.3, hi=0.8, rough=0.25, form=1.8),
        "belly": pmat("belly", (0.45, 0.48, 0.55), (0.62, 0.66, 0.72), scale=20, rough=0.3, form=1.4),
        "eye": pmat("eye", (0.02, 0.03, 0.04), (0.05, 0.06, 0.08), rough=0.05, form=0.0, grade=False),
        "suckers": pmat("suckers", (0.6, 0.55, 0.6), (0.8, 0.75, 0.78), scale=40, rough=0.4, form=1.6),
    }
    P = {"m_h": Vector((0, 0.75, 0.55)), "m_t": Vector((0, -0.12, 0.34))}
    bones = [("mantle", "m_h", "m_t", None)]
    arms = []
    for i in range(6):
        a = 2 * math.pi * i / 6 + 0.5
        d = Vector((math.sin(a), -math.cos(a), 0))
        root = Vector((0, -0.12, 0.3)) + d * 0.18
        pts = [root, root + d * 0.35 + Vector((0, 0, -0.12)), root + d * 0.68 + Vector((0, 0, -0.17)), root + d * 0.98 + Vector((0, 0, -0.2))]
        for k in range(3):
            P[f"t{i}_{k}"] = pts[k]
            P[f"t{i}_{k + 1}"] = pts[k + 1]
        arms.append(pts)
        bones += [(f"arm{i}.a", f"t{i}_0", f"t{i}_1", "mantle"), (f"arm{i}.b", f"t{i}_1", f"t{i}_2", f"arm{i}.a"),
                  (f"arm{i}.c", f"t{i}_2", f"t{i}_3", f"arm{i}.b")]
    rig = make_armature(name, P, bones)
    # Mantle: a long tapering body lifted behind the head, fins at the tail.
    mj = [(Vector((0, -0.12, 0.32)), (0.24, 0.22)), (Vector((0, 0.25, 0.44)), (0.26, 0.24)), (Vector((0, 0.6, 0.55)), (0.15, 0.13)), (Vector((0, 0.82, 0.6)), (0.04, 0.04))]
    mantle = skin_body("mantle", mj, [(0, 1), (1, 2), (2, 3)], levels=2)
    add_mat(mantle, mats["skin"])
    mantle = roughen(mantle, 0.008, 0.08)
    # Arms: one smooth tapering limb each, weighted along its three bones.
    limbs = []
    for i, pts in enumerate(arms):
        aj = [(pts[0], (0.075, 0.06)), (pts[1], (0.06, 0.045)), (pts[2], (0.042, 0.03)), (pts[3], (0.01, 0.008))]
        arm = skin_body("arm", aj, [(0, 1), (1, 2), (2, 3)], levels=2)
        add_mat(arm, mats["skin"])
        limbs.append(arm)
    mantle = join_into(mantle, limbs)
    bind_auto(mantle, rig)
    parts = [mantle]
    for s in (1, -1):
        fin = blob("fin", (s * 0.15, 0.62, 0.56), (0.16, 0.14, 0.02), 12, 6, mats["skin"])
        parts.append(fin)
        eye = blob("eye", (s * 0.2, -0.14, 0.38), (0.07, 0.08, 0.075), 14, 10, mats["eye"])
        parts.append(eye)
        mark("eye." + ("L" if s > 0 else "R"), Vector((s * 0.25, -0.2, 0.4)))
    head = blob("head", (0, -0.15, 0.3), (0.22, 0.2, 0.17), 18, 10, mats["belly"])
    parts.append(head)
    bind_parts(parts, "mantle")
    for i, pts in enumerate(arms):
        for k, bone in enumerate(("a", "b", "c")):
            for j in range(2):
                q = pts[k].lerp(pts[k + 1], 0.3 + 0.4 * j) + Vector((0, 0, -0.035 + 0.01 * k))
                sk = blob("sucker", q, (0.022 - 0.005 * k, 0.022 - 0.005 * k, 0.012), 8, 4, mats["suckers"])
                parts.append(sk)
                bind_rigid(sk, f"arm{i}.{bone}")
    body = join_into(parts[0], parts[1:])
    smooth(body)
    bake_textures(body)
    export(name, rig, body)
    if PREVIEW:
        preview(name, [body], 1.0)


def export_static(name, ob):
    os.makedirs(OUT, exist_ok=True)
    if MARKERS:
        with open(os.path.join(OUT, name + ".json"), "w") as f:
            json.dump(MARKERS, f, indent=1)
        MARKERS.clear()
    activate(ob)
    path = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, export_apply=True,
                              export_animations=False, export_yup=True, export_image_format='AUTO')
    print("EXPORTED", path, len(ob.data.polygons), "faces")


def build_eel_head():
    """The Constrictor Eel's head: a long moray skull over a gaping lower jaw ringed with
    needle teeth, a dark maw, gill slits, a heavy brow and trailing barbels. The body is
    drawn in the game as a tube through its coils."""
    name = "eel_head"
    mats = {
        "skin": pmat("skin", (0.08, 0.12, 0.1), (0.2, 0.28, 0.2), scale=8, detail=8, lo=0.3, hi=0.8, rough=0.25, form=2.0, grade=False),
        "belly": pmat("belly", (0.42, 0.42, 0.26), (0.6, 0.58, 0.36), scale=16, rough=0.3, form=1.6, grade=False),
        "maw": pmat("maw", (0.12, 0.02, 0.03), (0.25, 0.05, 0.06), scale=20, rough=0.2, form=1.0, grade=False),
        "teeth": pmat("teeth", (0.75, 0.72, 0.62), (0.9, 0.88, 0.8), rough=0.3, form=1.2, grade=False),
        "eye": pmat("eye", (0.02, 0.02, 0.02), (0.05, 0.05, 0.04), rough=0.05, form=0.0, grade=False),
        "gill": pmat("gill", (0.03, 0.03, 0.03), (0.08, 0.06, 0.06), rough=0.5, form=0.4, grade=False),
    }
    skull = skin_body("skull", [(Vector((0, 0.7, 0.05)), (0.55, 0.5)), (Vector((0, 0.1, 0.12)), (0.46, 0.38)),
                                (Vector((0, -0.5, 0.08)), (0.27, 0.22)), (Vector((0, -0.95, 0.05)), (0.12, 0.1))], [(0, 1), (1, 2), (2, 3)])
    skull = roughen(skull, 0.015, 0.2)
    for m in ("skin", "belly"):
        add_mat(skull, mats[m])
    paint_regions(skull, lambda c, n: "belly" if n.z < -0.35 else "skin", mats)
    jaw = skin_body("jaw", [(Vector((0, 0.45, -0.22)), (0.42, 0.16)), (Vector((0, -0.3, -0.36)), (0.25, 0.1)),
                            (Vector((0, -0.85, -0.4)), (0.1, 0.06))], [(0, 1), (1, 2)])
    for m in ("skin", "belly"):
        add_mat(jaw, mats[m])
    paint_regions(jaw, lambda c, n: "belly" if n.z < 0.2 else "skin", mats)
    maw = blob("maw", (0, -0.25, -0.15), (0.3, 0.6, 0.16), 16, 10, mats["maw"])
    parts = [jaw, maw]
    # Needle teeth along both jaws, raked back.
    for k in range(9):
        t = k / 8.0
        for s in (1, -1):
            up = Vector((s * (0.08 + 0.2 * t), -0.85 + 0.85 * t, -0.04))
            parts.append(tube("tooth", up, up + Vector((0, 0.03, -0.11 + 0.03 * t)), 0.022, 0.002, 6, mats["teeth"]))
            lo = Vector((s * (0.06 + 0.16 * t), -0.8 + 0.8 * t, -0.3))
            parts.append(tube("tooth", lo, lo + Vector((0, 0.03, 0.1 - 0.03 * t)), 0.02, 0.002, 6, mats["teeth"]))
    for s in (1, -1):
        e = Vector((s * 0.29, -0.32, 0.24))
        parts.append(blob("eye", e, (0.08, 0.09, 0.08), 14, 10, mats["eye"]))
        mark("eye." + ("L" if s > 0 else "R"), e + Vector((s * 0.05, -0.05, 0)))
        brow = skin_body("brow", [(e + Vector((-s * 0.06, 0.12, 0.08)), (0.05, 0.04)), (e + Vector((s * 0.02, -0.12, 0.07)), (0.03, 0.025))], [(0, 1)], levels=1)
        add_mat(brow, mats["skin"])
        parts.append(brow)
        for g in range(3):
            parts.append(box("gill", (s * 0.415, 0.28 + 0.1 * g, 0.04), (0.03, 0.025, 0.22), mats["gill"], 0.008, rot=(0, 0, s * 0.2)))
        bar = skin_body("barbel", [(Vector((s * 0.1, -0.88, -0.05)), (0.025, 0.02)), (Vector((s * 0.2, -1.0, -0.25)), (0.016, 0.014)),
                                   (Vector((s * 0.24, -0.95, -0.5)), (0.005, 0.005))], [(0, 1), (1, 2)], levels=1)
        add_mat(bar, mats["skin"])
        parts.append(bar)
    head = join_into(skull, parts)
    smooth(head)
    bake_textures(head, 512)
    export_static(name, head)
    if PREVIEW:
        preview(name, [head], 1.5)


BUILDERS = {
    "eel_head": build_eel_head,
    "crab": build_crab,
    "squid": build_squid,
    "bloated": build_bloated,
    "smotherer": build_smotherer,
    "callum_keeper": build_callum,
    "hamish_keeper": build_hamish,
    "mairi_keeper": build_mairi,
    "ewan_keeper": build_ewan,
}

if __name__ == "__main__":
    for n, fn in BUILDERS.items():
        if ONLY and n not in ONLY:
            continue
        reset()
        fn()
