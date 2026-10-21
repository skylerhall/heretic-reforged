"""Build a stand-in Disciple in Blender, following the design map.

The free AI steps (concept art, image-to-3D) need a GPU, so this script
models the Disciple directly from art/references/disciple/{front,side,back}.png:

  * red hooded robe over a dark tabard, gold-embroidered opening and hem
  * shoulder mantle, sleeves, studded bracers, belt with round buckle
  * spiked chain flail (right hand), spiked mace-staff (left hand)
  * 15-bone rig with idle / walk / attack / pain / death actions

Textures (color, roughness/metal, normal) are generated with numpy and packed
into the GLB. Output is a raw GLB; run blender_prepare.py on it afterwards.

  blender -b --python build_disciple.py -- --out disciple_raw.glb
"""

import argparse
import math
import os
import sys
import tempfile

import bpy
import addon_utils  # only importable once bpy is loaded
import numpy as np
from mathutils import Vector

TAU = math.tau


# --- textures -----------------------------------------------------------------

def noise2(h, w, scale, seed):
    """Tileable value noise with a few octaves, in 0..1."""
    rng = np.random.default_rng(seed)
    out = np.zeros((h, w))
    amp, total = 1.0, 0.0
    for octave in range(4):
        n = scale * (2 ** octave)
        grid = rng.random((n, n))
        ys = np.linspace(0, n, h, endpoint=False)
        xs = np.linspace(0, n, w, endpoint=False)
        y0 = np.floor(ys).astype(int) % n
        x0 = np.floor(xs).astype(int) % n
        fy = (ys - np.floor(ys))[:, None]
        fx = (xs - np.floor(xs))[None, :]
        fy = fy * fy * (3 - 2 * fy)
        fx = fx * fx * (3 - 2 * fx)
        a = grid[y0][:, x0]
        b = grid[y0][:, (x0 + 1) % n]
        c = grid[(y0 + 1) % n][:, x0]
        d = grid[(y0 + 1) % n][:, (x0 + 1) % n]
        out += amp * (a * (1 - fx) * (1 - fy) + b * fx * (1 - fy) + c * (1 - fx) * fy + d * fx * fy)
        total += amp
        amp *= 0.5
    return out / total


def weave(h, w, freq):
    y = np.arange(h)[:, None]
    x = np.arange(w)[None, :]
    return 0.5 + 0.25 * np.sin(x * TAU * freq / w) * np.sin(y * TAU * freq / h) + 0.25 * np.sin((x + y) * TAU * freq * 0.5 / w)


def swirls(h, w, count, seed):
    """Gold scroll ornament mask (0..1) for embroidery bands."""
    y = np.linspace(0, 1, h)[:, None]
    x = np.linspace(0, 1, w)[None, :]
    m = np.zeros((h, w))
    for k in range(count):
        cx = (k + 0.5) / count
        dx = (x - cx) * count
        r = np.sqrt(dx ** 2 + ((y - 0.5) * 2.2) ** 2)
        ang = np.arctan2(y - 0.5, dx + 1e-6)
        spiral = np.abs(np.sin(ang * 1.0 + r * 9.0 * (1 if k % 2 else -1)))
        m = np.maximum(m, (spiral < 0.22) * (r < 0.48))
    return m


def robe_textures(size=1024, front_u=0.75):
    """Albedo, ORM (R=occlusion, G=roughness, B=metal) and height for the robe.
    u wraps around the body (front at front_u), v runs hem (0) to neck (1)."""
    h = w = size
    v = np.linspace(0, 1, h)[:, None] * np.ones((1, w))
    u = np.ones((h, 1)) * np.linspace(0, 1, w)[None, :]
    n = noise2(h, w, 6, 1)
    wv = weave(h, w, 220)
    red = np.stack([0.34, 0.03, 0.024])
    col = red[None, None, :] * (0.72 + 0.35 * n[..., None] + 0.12 * (wv[..., None] - 0.5))
    # fold shading matching the geometry's folds
    a = u * TAU
    folds = 0.55 * np.sin(7 * a + 0.7) + 0.3 * np.sin(13 * a + 2.1)
    col *= (0.88 + 0.12 * folds * np.clip(1.1 - v * 1.4, 0, 1))[..., None]
    rough = np.full((h, w), 0.86)
    metal = np.zeros((h, w))
    height = 0.3 * wv + 0.2 * n
    gold = np.array([0.78, 0.57, 0.2])
    # the open front: dark patterned tabard with gold edging
    du = np.abs(u - front_u)
    tab = du < 0.055
    diamonds = (np.abs(((u - front_u) * 60) % 2 - 1) + np.abs((v * 34) % 2 - 1)) < 0.55
    tab_col = np.array([0.1, 0.095, 0.09]) * (0.8 + 0.4 * n[..., None])
    col = np.where(tab[..., None], tab_col, col)
    gold_pat = tab & diamonds & (v < 0.92)
    col = np.where(gold_pat[..., None], gold * 0.7, col)
    edge = (du >= 0.055) & (du < 0.068)
    hem = v < 0.045
    band = (v >= 0.06) & (v < 0.16)
    orn = np.zeros((h, w), bool)
    sw = swirls(int(h * 0.1), w, 22, 3) > 0
    orn[int(h * 0.06):int(h * 0.06) + sw.shape[0], :] = sw
    goldmask = edge | hem | (band & orn & ~tab)
    col = np.where(goldmask[..., None], gold * (0.85 + 0.3 * n[..., None]), col)
    rough = np.where(goldmask | gold_pat, 0.38, np.where(tab, 0.7, rough))
    metal = np.where(goldmask | gold_pat, 1.0, metal)
    height = np.where(goldmask | gold_pat, height + 0.6, height)
    occl = np.clip(0.75 + 0.25 * (folds * 0.5 + 0.5), 0, 1)
    orm = np.stack([occl, rough, metal], -1)
    return np.clip(col, 0, 1), orm, height


def cloth_textures(size=512):
    """Plain red cloth with gold bands at both ends (sleeves, hood, mantle)."""
    h = w = size
    v = np.linspace(0, 1, h)[:, None] * np.ones((1, w))
    n = noise2(h, w, 5, 7)
    wv = weave(h, w, 110)
    col = np.array([0.34, 0.03, 0.024])[None, None, :] * (0.72 + 0.35 * n[..., None] + 0.12 * (wv[..., None] - 0.5))
    goldmask = (v < 0.05) | (v > 0.95)
    col = np.where(goldmask[..., None], np.array([0.78, 0.57, 0.2]) * (0.85 + 0.3 * n[..., None]), col)
    rough = np.where(goldmask, 0.38, 0.86)
    metal = np.where(goldmask, 1.0, 0.0)
    orm = np.stack([np.ones((h, w)), rough, metal], -1)
    return np.clip(col, 0, 1), orm, 0.3 * wv + 0.2 * n + goldmask * 0.6


def normal_from_height(hgt, strength=3.0):
    gy, gx = np.gradient(hgt)
    nx, ny = -gx * strength * hgt.shape[1] / 256, -gy * strength * hgt.shape[0] / 256
    nz = np.ones_like(hgt)
    l = np.sqrt(nx ** 2 + ny ** 2 + nz ** 2)
    return np.stack([nx / l * 0.5 + 0.5, ny / l * 0.5 + 0.5, nz / l * 0.5 + 0.5], -1)


def make_image(name, rgb, folder, non_color=False):
    h, w = rgb.shape[:2]
    img = bpy.data.images.new(name, w, h, alpha=False)
    rgba = np.concatenate([rgb, np.ones((h, w, 1))], -1).astype(np.float32)
    img.pixels.foreach_set(rgba.ravel())
    img.filepath_raw = os.path.join(folder, name + ".png")
    img.file_format = "PNG"
    img.save()
    if non_color:
        img.colorspace_settings.name = "Non-Color"
    return img


# --- materials ------------------------------------------------------------------

def material(name, color=(0.5, 0.5, 0.5), rough=0.8, metal=0.0, emit=None, textures=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    p = nt.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*color, 1)
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metal
    if emit:
        p.inputs["Emission Color"].default_value = (*emit[0], 1)
        p.inputs["Emission Strength"].default_value = emit[1]
    if textures:
        albedo, orm, normal = textures
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = albedo
        nt.links.new(t.outputs["Color"], p.inputs["Base Color"])
        o = nt.nodes.new("ShaderNodeTexImage")
        o.image = orm
        sep = nt.nodes.new("ShaderNodeSeparateColor")
        nt.links.new(o.outputs["Color"], sep.inputs["Color"])
        nt.links.new(sep.outputs["Green"], p.inputs["Roughness"])
        nt.links.new(sep.outputs["Blue"], p.inputs["Metallic"])
        nm = nt.nodes.new("ShaderNodeTexImage")
        nm.image = normal
        nmap = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(nm.outputs["Color"], nmap.inputs["Color"])
        nt.links.new(nmap.outputs["Normal"], p.inputs["Normal"])
    m.use_backface_culling = False
    return m


# --- mesh helpers -----------------------------------------------------------------

def mesh_object(name, verts, faces, uvs, mat):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    uv = me.uv_layers.new(name="UVMap")
    for poly in me.polygons:
        for li in poly.loop_indices:
            uv.data[li].uv = uvs[me.loops[li].vertex_index]
    for poly in me.polygons:
        poly.use_smooth = True
    me.materials.append(mat)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def lathe(name, profile, mat, segs=48, fold=None, jag=0.0, v_range=None):
    """Surface of revolution around Z. profile: [(z, rx, ry)] bottom to top."""
    verts, uvs, faces = [], [], []
    z0, z1 = profile[0][0], profile[-1][0]
    for i, (z, rx, ry) in enumerate(profile):
        for j in range(segs + 1):
            a = TAU * j / segs
            f = 1.0 + (fold(z, a) if fold else 0.0)
            zz = z - (jag * max(0.0, math.sin(5 * a)) if i == 0 else 0.0)
            verts.append((math.cos(a) * rx * f, math.sin(a) * ry * f, zz))
            vv = (z - z0) / (z1 - z0) if v_range is None else v_range[0] + (v_range[1] - v_range[0]) * (z - z0) / (z1 - z0)
            uvs.append((j / segs, vv))
    for i in range(len(profile) - 1):
        for j in range(segs):
            a = i * (segs + 1) + j
            faces.append((a, a + 1, a + segs + 2, a + segs + 1))
    return mesh_object(name, verts, faces, uvs, mat)


def tube(name, points, radii, mat, segs=16, caps=True):
    """Tube along a polyline; rings perpendicular to the path."""
    pts = [Vector(p) for p in points]
    verts, uvs, faces = [], [], []
    length = sum((pts[i + 1] - pts[i]).length for i in range(len(pts) - 1))
    acc = 0.0
    ref = Vector((0, 0, 1))
    for i, p in enumerate(pts):
        if i > 0:
            acc += (pts[i] - pts[i - 1]).length
        t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        if abs(t.dot(ref)) > 0.95:
            ref = Vector((1, 0, 0))
        n1 = t.cross(ref).normalized()
        n2 = t.cross(n1)
        for j in range(segs + 1):
            a = TAU * j / segs
            verts.append(tuple(p + radii[i] * (math.cos(a) * n1 + math.sin(a) * n2)))
            uvs.append((j / segs, acc / length))
    for i in range(len(pts) - 1):
        for j in range(segs):
            a = i * (segs + 1) + j
            faces.append((a, a + 1, a + segs + 2, a + segs + 1))
    if caps:
        for end, step in ((0, -1), (len(pts) - 1, 1)):
            c = len(verts)
            verts.append(tuple(pts[end]))
            uvs.append((0.5, 0.5))
            base = end * (segs + 1)
            for j in range(segs):
                f = (c, base + j + 1, base + j) if step < 0 else (c, base + j, base + j + 1)
                faces.append(f)
    return mesh_object(name, verts, faces, uvs, mat)


def primitive(kind, mat, loc, scale=(1, 1, 1), rot=(0, 0, 0), **kw):
    getattr(bpy.ops.mesh, f"primitive_{kind}_add")(location=loc, rotation=rot, **kw)
    ob = bpy.context.active_object
    ob.scale = scale
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for poly in ob.data.polygons:
        poly.use_smooth = True
    ob.data.materials.append(mat)
    return ob


def spiked_ball(name, center, r, spikes, mat_ball, mat_spike):
    parts = [primitive("ico_sphere", mat_ball, center, (r, r, r), subdivisions=2)]
    golden = math.pi * (3 - math.sqrt(5))
    for k in range(spikes):
        y = 1 - 2 * (k + 0.5) / spikes
        rad = math.sqrt(1 - y * y)
        d = Vector((math.cos(golden * k) * rad, math.sin(golden * k) * rad, y))
        tip = Vector(center) + d * (r * 2.0)
        parts.append(tube(f"{name}_spike{k}", [Vector(center) + d * r * 0.8, tip], [r * 0.28, 0.002], mat_spike, segs=6, caps=False))
    return parts


# --- rig ------------------------------------------------------------------------

BONES = {
    # name: (head, tail, parent)
    "hips": ((0, 0, 0.95), (0, 0, 1.1), None),
    "spine": ((0, 0, 1.1), (0, 0, 1.28), "hips"),
    "chest": ((0, 0, 1.28), (0, 0, 1.45), "spine"),
    "neck": ((0, 0, 1.45), (0, 0, 1.55), "chest"),
    "head": ((0, 0, 1.55), (0, 0, 1.82), "neck"),
}
ARM = [(0.2, 0.0, 1.42), (0.31, -0.03, 1.13), (0.36, -0.08, 0.88), (0.38, -0.1, 0.78)]
LEG = [(0.1, 0.0, 0.95), (0.1, -0.02, 0.5), (0.1, 0.0, 0.08)]
for side, sx in (("L", 1), ("R", -1)):
    a = [(sx * p[0], p[1], p[2]) for p in ARM]
    BONES[f"upper_arm.{side}"] = (a[0], a[1], "chest")
    BONES[f"forearm.{side}"] = (a[1], a[2], f"upper_arm.{side}")
    BONES[f"hand.{side}"] = (a[2], a[3], f"forearm.{side}")
    l = [(sx * p[0], p[1], p[2]) for p in LEG]
    BONES[f"thigh.{side}"] = (l[0], l[1], "hips")
    BONES[f"shin.{side}"] = (l[1], l[2], f"thigh.{side}")


def build_rig():
    data = bpy.data.armatures.new("DiscipleRig")
    rig = bpy.data.objects.new("Disciple", data)
    bpy.context.scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    for name, (h, t, parent) in BONES.items():
        b = data.edit_bones.new(name)
        b.head, b.tail = h, t
        if parent:
            b.parent = data.edit_bones[parent]
            b.use_connect = Vector(data.edit_bones[parent].tail) == Vector(h)
    bpy.ops.object.mode_set(mode="OBJECT")
    return rig


def smooth(e0, e1, x):
    t = min(max((x - e0) / (e1 - e0), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def weights_robe(co):
    x, y, z = co
    w = {}
    if z > 1.3:
        w["chest"] = 1.0
    elif z > 1.1:
        k = smooth(1.1, 1.3, z)
        w["chest"], w["spine"] = k, 1 - k
    elif z > 0.95:
        k = smooth(0.95, 1.1, z)
        w["spine"], w["hips"] = k, 1 - k
    else:
        side = "L" if x > 0 else "R"
        leg = smooth(0.95, 0.6, z) * min(abs(x) / 0.09, 1.0) * 0.85
        lower = smooth(0.55, 0.3, z)
        w["hips"] = 1 - leg
        w[f"thigh.{side}"] = leg * (1 - lower)
        w[f"shin.{side}"] = leg * lower
    return w


def weights_arm(co, side):
    p = Vector(co)
    a = [Vector(((1 if side == "L" else -1) * q[0], q[1], q[2])) for q in ARM]
    def seg_t(p0, p1):
        d = p1 - p0
        return max(0.0, min(1.0, (p - p0).dot(d) / d.length_squared))
    t1 = seg_t(a[0], a[1])
    d1 = (a[0] + (a[1] - a[0]) * t1 - p).length
    t2 = seg_t(a[1], a[2])
    d2 = (a[1] + (a[2] - a[1]) * t2 - p).length
    if d1 < d2:
        k = smooth(0.75, 1.0, t1) * 0.5
        return {f"upper_arm.{side}": 1 - k, f"forearm.{side}": k}
    k = smooth(0.0, 0.25, t2) * 0.5 + 0.5
    return {f"forearm.{side}": k, f"upper_arm.{side}": 1 - k}


def assign(ob, rig, fn):
    for name in BONES:
        ob.vertex_groups.new(name=name)
    mw = ob.matrix_world
    for v in ob.data.vertices:
        for bone, wt in fn(tuple(mw @ v.co)).items():
            if wt > 0.001:
                ob.vertex_groups[bone].add([v.index], wt, "REPLACE")
    ob.parent = rig
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = rig


# --- animation --------------------------------------------------------------------

def forward_sign(rig, bone, axis=0):
    """+1 if rotating this bone positively about `axis` moves its tail forward (-Y)/up."""
    pb = rig.pose.bones[bone]
    pb.rotation_mode = "XYZ"
    bpy.context.view_layer.update()
    before = rig.matrix_world @ pb.tail
    rot = [0.0, 0.0, 0.0]
    rot[axis] = 0.3
    pb.rotation_euler = rot
    bpy.context.view_layer.update()
    after = rig.matrix_world @ pb.tail
    pb.rotation_euler = (0, 0, 0)
    bpy.context.view_layer.update()
    d = after - before
    return 1.0 if (-d.y + d.z * 0.3) > 0 else -1.0


def action(rig, name, frames, keys):
    """keys: {bone: [(frame, (rx, ry, rz) degrees, optional (lx, ly, lz))]}"""
    act = bpy.data.actions.new(name)
    rig.animation_data_create()
    rig.animation_data.action = act
    for bone, seq in keys.items():
        pb = rig.pose.bones[bone]
        pb.rotation_mode = "XYZ"
        for item in seq:
            f, rot = item[0], item[1]
            pb.rotation_euler = [math.radians(r) for r in rot]
            pb.keyframe_insert("rotation_euler", frame=f)
            if len(item) > 2:
                pb.location = item[2]
                pb.keyframe_insert("location", frame=f)
    for pb in rig.pose.bones:
        pb.rotation_euler = (0, 0, 0)
        pb.location = (0, 0, 0)
    act.frame_range = (1, frames)
    act.use_fake_user = True
    track = rig.animation_data.nla_tracks.new()
    track.name = name
    strip = track.strips.new(name, 1, act)
    if hasattr(strip, "action_slot") and len(getattr(act, "slots", [])) > 0:
        strip.action_slot = act.slots[0]
    rig.animation_data.action = None
    return act


def animate(rig):
    s = {b: forward_sign(rig, b) for b in ("upper_arm.L", "upper_arm.R", "forearm.L", "forearm.R",
                                            "thigh.L", "thigh.R", "shin.L", "shin.R", "chest", "spine", "head", "hips")}
    def fw(b, deg):  # rotate a bone "forward" by deg
        return (s[b] * deg, 0, 0)

    action(rig, "Idle", 61, {
        "chest": [(1, fw("chest", 0)), (31, fw("chest", 2.5)), (61, fw("chest", 0))],
        "head": [(1, fw("head", 0)), (31, fw("head", -2)), (61, fw("head", 0))],
        "upper_arm.R": [(1, fw("upper_arm.R", 0)), (31, fw("upper_arm.R", 4)), (61, fw("upper_arm.R", 0))],
        "upper_arm.L": [(1, fw("upper_arm.L", 0)), (31, fw("upper_arm.L", -2)), (61, fw("upper_arm.L", 0))],
    })
    action(rig, "Walk", 33, {
        "thigh.L": [(1, fw("thigh.L", 25)), (17, fw("thigh.L", -20)), (33, fw("thigh.L", 25))],
        "thigh.R": [(1, fw("thigh.R", -20)), (17, fw("thigh.R", 25)), (33, fw("thigh.R", -20))],
        "shin.L": [(1, fw("shin.L", 0)), (9, fw("shin.L", 0)), (21, fw("shin.L", -35)), (33, fw("shin.L", 0))],
        "shin.R": [(1, fw("shin.R", -20)), (5, fw("shin.R", -35)), (17, fw("shin.R", 0)), (33, fw("shin.R", -20))],
        "hips": [(1, (0, 0, 0), (0, 0, 0)), (9, (0, 0, 0), (0, -0.025, 0)), (17, (0, 0, 0), (0, 0, 0)),
                 (25, (0, 0, 0), (0, -0.025, 0)), (33, (0, 0, 0), (0, 0, 0))],
        "upper_arm.L": [(1, fw("upper_arm.L", -10)), (17, fw("upper_arm.L", 10)), (33, fw("upper_arm.L", -10))],
        "upper_arm.R": [(1, fw("upper_arm.R", 14)), (17, fw("upper_arm.R", -14)), (33, fw("upper_arm.R", 14))],
        "chest": [(1, (0, 0, 0)), (9, fw("chest", 3)), (17, (0, 0, 0)), (25, fw("chest", 3)), (33, (0, 0, 0))],
    })
    action(rig, "Attack", 25, {
        "upper_arm.R": [(1, fw("upper_arm.R", 0)), (9, fw("upper_arm.R", 165)), (14, fw("upper_arm.R", 55)),
                        (19, fw("upper_arm.R", 40)), (25, fw("upper_arm.R", 0))],
        "forearm.R": [(1, fw("forearm.R", 0)), (9, fw("forearm.R", 20)), (14, fw("forearm.R", 0)), (25, fw("forearm.R", 0))],
        "chest": [(1, fw("chest", 0)), (9, fw("chest", -10)), (14, fw("chest", 16)), (25, fw("chest", 0))],
        "spine": [(1, (0, 0, 0)), (9, (0, 8, 0)), (14, (0, -10, 0)), (25, (0, 0, 0))],
    })
    action(rig, "Pain", 13, {
        "chest": [(1, fw("chest", 0)), (4, fw("chest", -16)), (13, fw("chest", 0))],
        "head": [(1, fw("head", 0)), (4, fw("head", -22)), (13, fw("head", 0))],
        "upper_arm.L": [(1, fw("upper_arm.L", 0)), (4, fw("upper_arm.L", 25)), (13, fw("upper_arm.L", 0))],
        "upper_arm.R": [(1, fw("upper_arm.R", 0)), (4, fw("upper_arm.R", 25)), (13, fw("upper_arm.R", 0))],
    })
    action(rig, "Death", 41, {
        "hips": [(1, (0, 0, 0), (0, 0, 0)), (16, (0, 0, 0), (0, -0.42, 0)), (41, fw("hips", 75), (0, -0.92, 0.0))],
        "thigh.L": [(1, fw("thigh.L", 0)), (16, fw("thigh.L", 75)), (41, fw("thigh.L", 20))],
        "thigh.R": [(1, fw("thigh.R", 0)), (16, fw("thigh.R", 70)), (41, fw("thigh.R", 15))],
        "shin.L": [(1, fw("shin.L", 0)), (16, fw("shin.L", -80)), (41, fw("shin.L", -30))],
        "shin.R": [(1, fw("shin.R", 0)), (16, fw("shin.R", -85)), (41, fw("shin.R", -30))],
        "chest": [(1, fw("chest", 0)), (16, fw("chest", 10)), (41, fw("chest", 25))],
        "head": [(1, fw("head", 0)), (16, fw("head", 15)), (41, fw("head", 30))],
        "upper_arm.L": [(1, fw("upper_arm.L", 0)), (41, fw("upper_arm.L", 40))],
        "upper_arm.R": [(1, fw("upper_arm.R", 0)), (41, fw("upper_arm.R", 50))],
    })


# --- build ----------------------------------------------------------------------

def build(out):
    for mod in ("io_scene_gltf2",):
        try:
            addon_utils.enable(mod, default_set=True)
        except Exception:
            pass
    bpy.ops.wm.read_factory_settings(use_empty=True)
    try:
        addon_utils.enable("io_scene_gltf2", default_set=True)
    except Exception:
        pass
    tex_dir = tempfile.mkdtemp(prefix="disciple_tex_")

    ra, ro, rh = robe_textures()
    robe_tex = (make_image("disciple_robe_basecolor", ra, tex_dir),
                make_image("disciple_robe_orm", ro, tex_dir, True),
                make_image("disciple_robe_normal", normal_from_height(rh), tex_dir, True))
    ca, co, ch = cloth_textures()
    cloth_tex = (make_image("disciple_cloth_basecolor", ca, tex_dir),
                 make_image("disciple_cloth_orm", co, tex_dir, True),
                 make_image("disciple_cloth_normal", normal_from_height(ch), tex_dir, True))
    m_robe = material("Robe", textures=robe_tex)
    m_cloth = material("Cloth", textures=cloth_tex)
    # material colors are linear (Blender's convention), not sRGB screen values
    m_leather = material("Leather", (0.032, 0.018, 0.011), 0.65)
    m_gold = material("Gold", (0.72, 0.48, 0.15), 0.35, 1.0)
    m_iron = material("Iron", (0.11, 0.105, 0.1), 0.45, 0.9)
    m_skin = material("Skin", (0.16, 0.09, 0.065), 0.6)
    m_shadow = material("FaceShadow", (0.008, 0.005, 0.004), 0.95)
    m_wood = material("Wood", (0.05, 0.028, 0.014), 0.75)
    m_eyes = material("Eyes", (0.2, 0.08, 0.02), 0.5, 0.0, ((1.0, 0.45, 0.12), 4.0))

    rig = build_rig()
    groups = []   # (object, weight function)

    def fold(z, a):
        amp = 0.07 * min(max((1.0 - z) / 1.0, 0.0), 1.0) + 0.012
        return amp * (0.55 * math.sin(7 * a + 0.7) + 0.3 * math.sin(13 * a + 2.1) + 0.15 * math.sin(23 * a))

    robe = lathe("Robe", [(0.0, 0.36, 0.3), (0.2, 0.33, 0.27), (0.45, 0.28, 0.23), (0.7, 0.23, 0.19),
                          (0.92, 0.19, 0.155), (1.0, 0.175, 0.145), (1.12, 0.19, 0.15), (1.25, 0.205, 0.155),
                          (1.36, 0.21, 0.15), (1.45, 0.16, 0.12), (1.52, 0.09, 0.08)],
                 m_robe, segs=64, fold=fold, jag=0.02, v_range=(0.0, 1.0))
    # the lathe's u=0.75 points at -Y (the front), where the tabard is painted
    groups.append((robe, weights_robe))

    mantle = lathe("Mantle", [(1.2, 0.3, 0.235), (1.3, 0.285, 0.22), (1.42, 0.22, 0.17), (1.5, 0.12, 0.1),
                              (1.55, 0.085, 0.075)],
                   m_cloth, segs=48, fold=lambda z, a: 0.03 * math.sin(9 * a) * (1.45 - z) * 3, jag=0.03)
    groups.append((mantle, lambda c: {"chest": 1.0} if c[2] < 1.47 else {"chest": 0.5, "neck": 0.5}))

    belt = lathe("Belt", [(0.94, 0.188, 0.156), (1.06, 0.188, 0.156)], m_leather, segs=48)
    buckle = primitive("cylinder", m_gold, (0, -0.158, 1.0), (0.045, 0.045, 0.012), (math.pi / 2, 0, 0), vertices=20)
    pouch = primitive("cube", m_leather, (0.15, -0.09, 0.92), (0.045, 0.03, 0.055))
    for ob in (belt, buckle, pouch):
        groups.append((ob, lambda c: {"hips": 0.6, "spine": 0.4}))

    # hood: a pointed sphere with the face opening cut out
    hood = primitive("uv_sphere", m_cloth, (0, 0.015, 1.63), (0.15, 0.17, 0.2), segments=32, ring_count=16)
    me = hood.data
    for v in me.vertices:
        p = v.co - Vector((0, 0.015, 1.63))
        back_top = max(0.0, p.y / 0.17 + 0.3) * max(0.0, p.z / 0.2)
        v.co += Vector((0, 0.05, 0.11)) * back_top ** 1.5
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(me)
    cut = [f for f in bm.faces if f.calc_center_median().y < -0.07
           and abs(f.calc_center_median().x) < 0.095 and 1.49 < f.calc_center_median().z < 1.72]
    bmesh.ops.delete(bm, geom=cut, context="FACES")
    bm.to_mesh(me)
    bm.free()
    sol = hood.modifiers.new("Solidify", "SOLIDIFY")
    sol.thickness = 0.014
    bpy.context.view_layer.objects.active = hood
    bpy.ops.object.modifier_apply(modifier="Solidify")
    face = primitive("uv_sphere", m_shadow, (0, -0.01, 1.6), (0.095, 0.1, 0.13), segments=20, ring_count=10)
    jaw = primitive("uv_sphere", m_skin, (0, -0.07, 1.56), (0.045, 0.04, 0.05), segments=12, ring_count=8)
    eyes = [primitive("uv_sphere", m_eyes, (sx * 0.032, -0.098, 1.625), (0.012, 0.008, 0.008), segments=8, ring_count=6)
            for sx in (1, -1)]
    for ob in [hood, face, jaw] + eyes:
        groups.append((ob, lambda c: {"head": 1.0}))

    for side, sx in (("L", 1), ("R", -1)):
        a = [Vector((sx * p[0], p[1], p[2])) for p in ARM]
        cuff = a[1] + (a[2] - a[1]) * 0.25
        sleeve = tube(f"Sleeve.{side}", [a[0] + Vector((0, 0, 0.02)), a[1], cuff], [0.085, 0.08, 0.1], m_cloth, segs=20, caps=False)
        bracer = tube(f"Bracer.{side}", [a[1] + (a[2] - a[1]) * 0.2, a[2]], [0.058, 0.05], m_iron, segs=16)
        studs = [primitive("uv_sphere", m_gold, tuple(a[1] + (a[2] - a[1]) * t + Vector((sx * 0.05, -0.02, 0))),
                           (0.009, 0.009, 0.009), segments=8, ring_count=4) for t in (0.35, 0.55, 0.75)]
        hand = primitive("uv_sphere", m_skin, tuple(a[2] + (a[3] - a[2]) * 0.6), (0.04, 0.032, 0.065), segments=12, ring_count=8)
        for ob in [sleeve, bracer] + studs:
            groups.append((ob, (lambda s: (lambda c: weights_arm(c, s)))(side)))
        groups.append((hand, (lambda s: (lambda c: {f"hand.{s}": 1.0}))(side)))
        boot = primitive("uv_sphere", m_leather, (sx * 0.09, -0.07, 0.05), (0.06, 0.1, 0.05), segments=12, ring_count=8)
        groups.append((boot, (lambda s: (lambda c: {f"shin.{s}": 1.0}))(side)))

    # flail in the right hand: short grip, chain, spiked iron ball
    hr = Vector((-0.37, -0.095, 0.82))
    flail = [tube("FlailGrip", [hr + Vector((0, 0, 0.05)), hr - Vector((0, 0.005, 0.1))], [0.016, 0.016], m_wood, segs=10)]
    chain_top, chain_end = hr - Vector((0, 0.01, 0.1)), Vector((-0.38, -0.13, 0.46))
    for k in range(9):
        t = (k + 0.5) / 9
        rot = (0, 0, 0) if k % 2 else (0, 0, math.pi / 2)
        flail.append(primitive("torus", m_iron, tuple(chain_top.lerp(chain_end, t)), (1, 1, 1),
                               (math.pi / 2, 0, rot[2]), major_radius=0.016, minor_radius=0.0045,
                               major_segments=10, minor_segments=5))
    flail += spiked_ball("Flail", (-0.38, -0.13, 0.4), 0.06, 12, m_iron, m_iron)
    for ob in flail:
        groups.append((ob, lambda c: {"hand.R": 1.0}))

    # mace-staff in the left hand
    hl = Vector((0.37, -0.095, 0.82))
    staff = [tube("Staff", [hl + Vector((0, 0.02, -0.6)), hl + Vector((0.01, -0.03, 1.08))], [0.018, 0.017], m_wood, segs=10)]
    head = hl + Vector((0.01, -0.03, 1.12))
    staff.append(primitive("cylinder", m_iron, tuple(head - Vector((0, 0, 0.06))), (0.025, 0.025, 0.03), vertices=12))
    staff += spiked_ball("StaffHead", tuple(head), 0.045, 10, m_iron, m_iron)
    for ob in staff:
        groups.append((ob, lambda c: {"hand.L": 1.0}))

    for ob, fn in groups:
        assign(ob, rig, fn)

    # one mesh, one draw call per material
    bpy.ops.object.select_all(action="DESELECT")
    for ob, _ in groups:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = robe
    bpy.ops.object.join()
    robe.name = "DiscipleBody"
    tris = sum(len(p.vertices) - 2 for p in robe.data.polygons)

    animate(rig)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_yup=True, export_animations=True,
                              export_animation_mode="NLA_TRACKS")
    print(f"built {out}: {tris} triangles, {len(BONES)} bones, actions: Idle Walk Attack Pain Death")


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    build(os.path.abspath(ap.parse_args(argv).out))
