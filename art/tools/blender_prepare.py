"""Prepare an AI-generated (or hand-made) model for Heretic Reforged.

Imports a model plus any Mixamo animation files, cleans it up and exports one
.glb the game picks up automatically:

  * applies transforms, optionally decimates to a triangle budget
  * scales it to the in-game height with the feet at the origin, centred
  * merges animation files onto the model's skeleton and names the clips
    idle / walk / attack / pain / death (what the game looks for)
  * exports GLB (+Y up, facing +Z, which the game turns to face the player)

Run with Blender 4.2+ (or the `bpy` Python module):

  blender -b --python blender_prepare.py -- \\
      --in golem_trellis.glb --height 2.0 --max-tris 25000 \\
      --anim idle=Idle.fbx --anim walk=Walking.fbx --anim attack=Punching.fbx \\
      --anim pain=Hit_Reaction.fbx --anim death=Dying.fbx \\
      --out ../../assets/monsters/golem.glb

Heights the game uses (meters): see art/asset-manifest.json.
"""

import argparse
import math
import os
import sys

import bpy
import addon_utils  # only importable once bpy is loaded
from mathutils import Vector

STATE_KEYWORDS = {
    "idle": ["idle", "stand", "breath"],
    "walk": ["walk", "run", "move", "fly"],
    "attack": ["attack", "punch", "swing", "slash", "cast", "shoot", "throw", "bite"],
    "pain": ["hit", "pain", "react", "hurt"],
    "death": ["death", "die", "dying"],
    "fire": ["fire", "recoil"],
}


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--in", dest="src", required=True, help="model to prepare (.glb/.gltf/.fbx/.obj)")
    p.add_argument("--out", required=True, help="output .glb")
    p.add_argument("--height", type=float, default=0.0, help="target height in meters (0 = keep)")
    p.add_argument("--max-tris", type=int, default=0, help="decimate meshes above this many triangles")
    p.add_argument("--yaw", type=float, default=0.0, help="extra rotation in degrees if it faces the wrong way")
    p.add_argument("--anim", action="append", default=[], metavar="STATE=FILE",
                   help="animation file (e.g. a Mixamo FBX 'without skin') for a game state")
    return p.parse_args(argv)


def enable_addons():
    for mod in ("io_scene_gltf2", "io_scene_fbx"):
        try:
            addon_utils.enable(mod, default_set=True)
        except Exception:  # already built in on newer Blender versions
            pass


def import_file(path):
    before = set(bpy.data.objects)
    ext = os.path.splitext(path)[1].lower()
    if ext in (".glb", ".gltf"):
        bpy.ops.import_scene.gltf(filepath=path)
    elif ext == ".fbx":
        bpy.ops.import_scene.fbx(filepath=path, automatic_bone_orientation=True)
    elif ext == ".obj":
        bpy.ops.wm.obj_import(filepath=path)
    else:
        sys.exit(f"unsupported file type: {path}")
    return [o for o in bpy.data.objects if o not in before]


def triangles(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def decimate(meshes, budget):
    total = sum(triangles(m) for m in meshes)
    if budget <= 0 or total <= budget:
        return total
    ratio = budget / total
    for m in meshes:
        bpy.context.view_layer.objects.active = m
        mod = m.modifiers.new("Decimate", "DECIMATE")
        mod.ratio = ratio
        # Decimate before skinning so the armature keeps working.
        while m.modifiers.find("Decimate") > 0:
            bpy.ops.object.modifier_move_up(modifier="Decimate")
        bpy.ops.object.modifier_apply(modifier="Decimate")
    return sum(triangles(m) for m in meshes)


def world_bounds(meshes):
    lo = Vector((math.inf,) * 3)
    hi = Vector((-math.inf,) * 3)
    for m in meshes:
        for corner in m.bound_box:
            w = m.matrix_world @ Vector(corner)
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    return lo, hi


def state_for(name):
    low = name.lower()
    for state, words in STATE_KEYWORDS.items():
        if any(w in low for w in words):
            return state
    return None


def add_to_nla(armature, action, name):
    action.name = name
    action.use_fake_user = True
    ad = armature.animation_data or armature.animation_data_create()
    track = ad.nla_tracks.new()
    track.name = name
    strip = track.strips.new(name, int(action.frame_range[0]), action)
    if hasattr(strip, "action_slot") and len(getattr(action, "slots", [])) > 0:
        strip.action_slot = action.slots[0]  # Blender 4.4+ slotted actions
    track.mute = False


def main():
    args = parse_args()
    enable_addons()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    enable_addons()

    imported = import_file(os.path.abspath(args.src))
    meshes = [o for o in imported if o.type == "MESH"]
    armatures = [o for o in imported if o.type == "ARMATURE"]
    if not meshes:
        sys.exit("no meshes found in " + args.src)
    rig = armatures[0] if armatures else None

    # Actions that came with the model: give them game state names.
    named = {}
    for act in list(bpy.data.actions):
        state = state_for(act.name)
        if state and state not in named:
            named[state] = act

    # Animation files (Mixamo "without skin" FBX): keep their action, drop the rest.
    for spec in args.anim:
        state, _, path = spec.partition("=")
        before_actions = set(bpy.data.actions)
        objs = import_file(os.path.abspath(path))
        new_actions = [a for a in bpy.data.actions if a not in before_actions]
        if new_actions:
            named[state] = new_actions[0]
        for o in objs:
            bpy.data.objects.remove(o, do_unlink=True)
        if not new_actions:
            print(f"warning: no animation in {path}")

    if rig is not None:
        if rig.animation_data:
            rig.animation_data.action = None
        for state, act in named.items():
            add_to_nla(rig, act, state)
    elif named:
        print("warning: animations given but the model has no skeleton; rig it on Mixamo first")

    # Root empty: turn, scale and ground everything in one place.
    root = bpy.data.objects.new("root", None)
    bpy.context.scene.collection.objects.link(root)
    for o in imported:
        if o.parent is None and o.name in bpy.data.objects:
            o.parent = root
    root.rotation_euler[2] = math.radians(args.yaw)
    bpy.context.view_layer.update()

    tris = decimate(meshes, args.max_tris)
    lo, hi = world_bounds(meshes)
    size = hi - lo
    scale = args.height / size.z if args.height > 0 and size.z > 0 else 1.0
    root.scale = (scale, scale, scale)
    bpy.context.view_layer.update()
    lo, hi = world_bounds(meshes)
    root.location = (-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z)
    bpy.context.view_layer.update()
    lo, hi = world_bounds(meshes)

    out = os.path.abspath(args.out)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=out,
        export_format="GLB",
        export_yup=True,
        export_animations=True,
        export_animation_mode="NLA_TRACKS" if rig is not None and named else "ACTIONS",
    )
    print(f"wrote {out}")
    print(f"  height {hi.z - lo.z:.2f} m, footprint {hi.x - lo.x:.2f} x {hi.y - lo.y:.2f} m, {tris} triangles")
    print(f"  skeleton: {'yes' if rig else 'no'}, animations: {', '.join(sorted(named)) or 'none'}")
    missing = [s for s in ("idle", "walk", "attack", "pain", "death") if s not in named]
    if rig is not None and missing:
        print(f"  note: no clip for {', '.join(missing)} (the game falls back to idle)")


if __name__ == "__main__":
    main()
