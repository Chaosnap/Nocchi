"""Nocchi · 软木板与光台上的小道具。

PinBrass / PinTerracotta / PinMustard / PinTeal   图钉（俯视略斜，针尖朝下）
Clothespin                                       木夹（竖直）
Loupe                                            放大镜外圈（正俯视，镜片区域透明）

用法：
    /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P design/blender/props/make_props.py
"""

import math
import os
import sys

import bmesh
import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "canisters"))
import studio as S  # noqa: E402

OUT = os.path.join(HERE, "out")


def setup(w, h, samples=160):
    scene = S.fresh_scene()
    S.setup_cycles(scene, w, h, samples=samples, transparent=True, exposure=0.2)
    return scene


def finish(scene, cam, target, name, pad=0.1, floor=False, rig_scale=0.5):
    S.light_rig(scene, cam, target, scale=rig_scale, power_scale=1.0, world_strength=0.4)
    if floor:
        S.shadow_catcher(scene, size=100.0)
    meshes = [o for o in scene.objects if o.type == "MESH" and not o.is_shadow_catcher]
    S.fit_camera(scene, cam, meshes, pad=pad)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".png")
    S.render_to(scene, path)
    S.write_imageset(name, path, filename=name.lower() + ".png")
    return path


def brass_tack():
    scene = setup(128, 128)
    brass = S.principled("brass", "#C9A35A", rough=0.22, metal=1.0)
    steel = S.principled("steel", "#BDBDBD", rough=0.25, metal=1.0)
    head = S.lathe("head", [(0, 0.0), (0.92, 0.0), (1.0, 0.05), (1.0, 0.12), (0.92, 0.18), (0.3, 0.24), (0, 0.3)], segments=96, mats=(brass,))
    needle = S.lathe("needle", [(0, -0.9), (0.06, -0.75), (0.07, 0), (0, 0)], segments=32, mats=(steel,))
    head.location.z = 0.9
    needle.location.z = 0.9
    cam = S.camera(scene, (0, 0, 0.9), azimuth=-20.0, elevation=58.0, distance=20.0, lens=85.0)
    return finish(scene, cam, (0, 0, 0.9), "PinBrass", pad=0.14)


def map_pin(name, color):
    scene = setup(128, 128)
    plastic = S.principled("head", color, rough=0.16)
    steel = S.principled("steel", "#C8C8C8", rough=0.22, metal=1.0)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=64, ring_count=32, radius=0.55, location=(0, 0, 1.45))
    ball = bpy.context.active_object
    ball.data.materials.append(plastic)
    for p in ball.data.polygons:
        p.use_smooth = True
    collar = S.lathe("collar", [(0, 0.0), (0.22, 0.0), (0.26, 0.08), (0.18, 0.22), (0, 0.24)], segments=48, mats=(plastic,))
    collar.location.z = 0.82
    needle = S.lathe("needle", [(0, -0.2), (0.05, -0.1), (0.06, 0.9), (0, 0.9)], segments=32, mats=(steel,))
    needle.location.z = 0.0
    cam = S.camera(scene, (0, 0, 1.2), azimuth=-24.0, elevation=48.0, distance=20.0, lens=85.0)
    return finish(scene, cam, (0, 0, 1.2), name, pad=0.14)


def clothespin():
    scene = setup(96, 192)
    wood = S.principled("pine", "#D8B07A", rough=0.55)
    S.add_fine_bump(wood, scale=80.0, strength=0.06, distance=0.01)
    steel = S.principled("spring", "#B8B8B8", rough=0.2, metal=1.0)
    root = bpy.data.objects.new("root", None)
    S.link(root)
    for side in (-1, 1):
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts:
            v.co.x *= 0.36
            v.co.y *= 0.5
            v.co.z *= 7.2
            # 下端（夹口）收窄
            if v.co.z < 0:
                v.co.x *= 0.65
        half = S.mesh_object("half", bm, smooth=False, mats=(wood,))
        half.location = (side * 0.19, 0, 3.6)
        bev = half.modifiers.new("bevel", "BEVEL")
        bev.width = 0.08
        bev.segments = 3
        half.parent = root
    coil = S.lathe("coil", [(0.36, -0.42), (0.46, -0.42), (0.46, 0.42), (0.36, 0.42)], segments=48, mats=(steel,))
    coil.rotation_euler = (0, math.radians(90), 0)
    coil.location = (0, 0, 4.4)
    coil.scale = (1.0, 1.0, 1.0)
    coil.parent = root
    root.rotation_euler = (math.radians(90), 0, 0)
    root.location = (0, 0, 0.3)
    cam = S.camera(scene, (0, 0, 0.3), azimuth=-14.0, elevation=70.0, distance=40.0, lens=85.0)
    return finish(scene, cam, (0, 0, 0.3), "Clothespin", pad=0.1)


def loupe():
    scene = setup(512, 512, samples=192)
    black = S.principled("loupe-body", "#151515", rough=0.42)
    S.add_fine_bump(black, scale=200.0, strength=0.05, distance=0.004)
    chrome = S.principled("chrome", "#E6E6E6", rough=0.08, metal=1.0)
    # 带滚花的黑色外圈 + 一道细铬边，中间是空的（镜片区域透明）
    profile = [(3.2, 0.0), (4.4, 0.0), (4.6, 0.25), (4.6, 1.5), (4.45, 1.75), (3.45, 1.75), (3.3, 1.6), (3.2, 1.6)]
    body = S.lathe("body", profile, segments=180, mats=(black,))
    ridges = body.modifiers.new("ridges", "DISPLACE")
    tex = bpy.data.textures.new("ridge", type="WOOD")
    tex.wood_type = "RINGS"
    tex.noise_basis_2 = "SAW"
    ridges.texture = tex
    ridges.strength = 0.0
    bezel = S.lathe("bezel", [(3.05, 1.55), (3.35, 1.55), (3.35, 1.78), (3.05, 1.78)], segments=180, mats=(chrome,))
    glass_rim = S.lathe("rim", [(3.0, 1.5), (3.08, 1.5), (3.08, 1.62), (3.0, 1.62)], segments=180, mats=(chrome,))
    cam = S.camera(scene, (0, 0, 0.9), azimuth=0.0, elevation=89.9, distance=60.0, lens=85.0)
    return finish(scene, cam, (0, 0, 0.9), "Loupe", pad=0.06, rig_scale=1.0)


def main():
    outputs = [(brass_tack(), "PinBrass")]
    for name, color in (("PinTerracotta", "#C4593B"), ("PinMustard", "#D9A441"), ("PinTeal", "#2F5F5C")):
        outputs.append((map_pin(name, color), name))
    outputs.append((clothespin(), "Clothespin"))
    outputs.append((loupe(), "Loupe"))
    S.contact_sheet(outputs, os.path.join(HERE, "contact.png"), cols=6, cell=(220, 260), bgs=("#B98A5E", "#F2EEE6"))


if __name__ == "__main__":
    main()
