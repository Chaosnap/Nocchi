"""Nocchi · 大头贴机的零件（Blender 建模）。

BoothPanel                         象牙白搪瓷面板：镀铬包边、四角黄铜螺丝，正俯视（九宫格拉伸用，cap 140）
BoothMarquee                       顶上的招牌：镀铬圆角框、一圈暖色灯泡、中间留白的搪瓷牌（标题由界面写）
BoothLeverLeft / BoothLeverRight   镀铬蝙蝠柄拨杆（滚花螺母 + 胶木垫圈），拨向左 / 右
BoothArrow / BoothArrowPressed     黄铜圆顶按钮（浮雕箭头朝右，向左的由界面水平翻转），抬起 / 按下
BoothStart / BoothStartLit / BoothStartPressed   街机式大按钮：镀铬圈 + 半透明陶土红顶盖；暗 / 亮 / 按下

全部透明背景、不带地面阴影（阴影由界面按轮廓画），光从左上来。

用法：
    /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P design/blender/booth/make_booth.py
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


def finish(scene, cam, target, name, pad=0.08, rig_scale=0.6, fit=True, world=0.42):
    S.light_rig(scene, cam, target, scale=rig_scale, power_scale=1.0, world_strength=world)
    if fit:
        meshes = [o for o in scene.objects if o.type in ("MESH", "FONT")]
        S.fit_camera(scene, cam, meshes, pad=pad)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".png")
    S.render_to(scene, path)
    S.write_imageset(name, path, filename=name.lower() + ".png")
    return path


def chrome(name="chrome"):
    return S.principled(name, "#E8E9EC", rough=0.09, metal=1.0)


def brass(name="brass"):
    return S.principled(name, "#C9A35A", rough=0.24, metal=1.0)


def enamel(name="enamel", color="#EEE6D5", coat=0.2):
    return S.principled(name, color, rough=0.5, Coat_Weight=coat, Coat_Roughness=0.25)


def slab(name, w, h, r, depth, mat, z0=0.0, bevel=0.0):
    """圆角矩形厚板（XY 平面，向 +Z 长出 depth）。"""
    bm = bmesh.new()
    pts = S.rounded_rect_points(-w / 2, -h / 2, w, h, r, seg=16)
    bottom = [bm.verts.new((x, y, z0)) for x, y in pts]
    top = [bm.verts.new((x, y, z0 + depth)) for x, y in pts]
    bm.faces.new(list(reversed(bottom)))
    bm.faces.new(top)
    n = len(pts)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new([bottom[i], bottom[j], top[j], top[i]])
    ob = S.mesh_object(name, bm, smooth=False, mats=(mat,))
    if bevel > 0:
        mod = ob.modifiers.new("bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 4
        mod.limit_method = "ANGLE"
    return ob


def screw(name, x, y, z, radius, mat):
    head = S.lathe(name, [(0, z + radius * 0.42), (radius * 0.75, z + radius * 0.36), (radius, z + radius * 0.12), (radius, z), (0, z)], segments=64, mats=(mat,))
    head.location = (x, y, 0)
    slot = slab(name + "-slot", radius * 1.5, radius * 0.18, radius * 0.05, radius * 0.3, S.principled(name + "-dark", "#4A3A22", rough=0.6), z0=z + radius * 0.2)
    slot.location = (x, y, 0)
    slot.rotation_euler = (0, 0, math.radians(-35))
    return head


# --------------------------------------------------------------------------- panel (9-slice)

def panel():
    scene = S.fresh_scene()
    S.setup_cycles(scene, 600, 600, samples=192, transparent=True, exposure=0.15)
    size, radius = 60.0, 8.0
    trim = slab("trim", size, size, radius, 1.4, chrome("trim-chrome"), bevel=0.35)
    face = slab("face", size - 2.4, size - 2.4, radius - 1.2, 1.7, enamel(), bevel=0.5)
    inner = slab("groove", size - 7.0, size - 7.0, radius - 3.5, 1.74, S.principled("groove", "#E2D8C4", rough=0.42), bevel=0.25)
    for sx in (-1, 1):
        for sy in (-1, 1):
            screw("screw", sx * (size / 2 - 4.6), sy * (size / 2 - 4.6), 1.74, 1.25, brass("screw-brass"))
    cam = S.camera(scene, (0, 0, 0), azimuth=0.0, elevation=89.9, distance=120.0, lens=85.0, ortho=size * 1.0)
    # 九宫格要拉伸：中间要匀，光放得很大、很柔，世界光多一点。
    path = finish(scene, cam, (0, 0, 0), "BoothPanel", fit=False, rig_scale=4.0, world=1.1)
    # @2x：600 像素 = 300 点，圆角约 40 点；界面用 56 点的九宫格边。
    with open(os.path.join(S.ART, "BoothPanel.imageset", "Contents.json"), "w") as f:
        f.write('{\n  "images" : [\n    { "filename" : "boothpanel.png", "idiom" : "universal", "scale" : "2x" }\n  ],\n'
                '  "info" : { "author" : "xcode", "version" : 1 }\n}\n')
    return path


# --------------------------------------------------------------------------- marquee

def marquee():
    scene = S.fresh_scene()
    S.setup_cycles(scene, 960, 300, samples=224, transparent=True, exposure=0.1)
    w, h = 64.0, 18.0
    frame = slab("frame", w, h, 8.0, 1.6, chrome("frame-chrome"), bevel=0.4)
    plate = slab("plate", w - 3.2, h - 3.2, 6.6, 1.9, enamel("plate-enamel", "#F4EDDF", coat=0.3), bevel=0.5)
    band = slab("band", w - 8.0, h - 8.6, 4.0, 1.95, S.principled("band", "#B8452F", rough=0.38, Coat_Weight=0.5), bevel=0.2)
    center = slab("center", w - 14.0, h - 11.0, 2.6, 1.98, enamel("center-enamel", "#FBF6EC", coat=0.1), bevel=0.25)
    glass = S.principled("bulb-glass", "#FFFFFF", rough=0.05, Transmission_Weight=1.0, IOR=1.45)
    glow = S.emission_mat("bulb-glow", "#FFC872", strength=22.0)
    socket = chrome("socket")
    # 沿着边框一圈灯泡
    pts = S.rounded_rect_points(-(w - 5.2) / 2, -(h - 5.2) / 2, w - 5.2, h - 5.2, 5.4, seg=4)
    perimeter = 0.0
    seglen = []
    for i in range(len(pts)):
        a, b = pts[i], pts[(i + 1) % len(pts)]
        d = math.dist(a, b)
        seglen.append(d)
        perimeter += d
    count = 24
    for k in range(count):
        t = perimeter * k / count
        i = 0
        while t > seglen[i]:
            t -= seglen[i]
            i += 1
        a, b = pts[i], pts[(i + 1) % len(pts)]
        f = t / max(seglen[i], 1e-6)
        x, y = a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f
        base = S.lathe("socket", [(0, 1.6), (0.95, 1.6), (0.95, 2.1), (0, 2.1)], segments=32, mats=(socket,))
        base.location = (x, y, 0)
        filament = S.lathe("filament", [(0, 2.1), (0.55, 2.3), (0.55, 2.75), (0, 3.0)], segments=24, mats=(glow,))
        filament.location = (x, y, 0)
        bulb = S.lathe("bulb", [(0, 2.05), (0.75, 2.2), (0.92, 2.7), (0.75, 3.3), (0, 3.45)], segments=32, mats=(glass,))
        bulb.location = (x, y, 0)
        light = bpy.data.lights.new("bulb-light", "POINT")
        light.energy = 1.4
        light.color = S.hex_rgb("#FFD08A")
        lob = bpy.data.objects.new("bulb-light", light)
        lob.location = (x, y, 2.6)
        S.link(lob, scene)
    cam = S.camera(scene, (0, 0, 0), azimuth=0.0, elevation=89.9, distance=160.0, lens=85.0, ortho=w * 1.04)
    return finish(scene, cam, (0, 0, 0), "BoothMarquee", fit=False, rig_scale=1.8, world=0.3)


# --------------------------------------------------------------------------- lever

def lever(direction, name):
    scene = S.fresh_scene()
    S.setup_cycles(scene, 220, 220, samples=192, transparent=True, exposure=0.15)
    washer = S.lathe("washer", [(0, 0.0), (2.3, 0.0), (2.4, 0.15), (2.4, 0.45), (2.25, 0.6), (0, 0.6)], segments=96, mats=(S.principled("bakelite", "#1C1A18", rough=0.35, Coat_Weight=0.4),))
    nut = S.lathe("nut", [(0, 0.6), (1.45, 0.6), (1.55, 0.7), (1.55, 1.5), (1.4, 1.65), (0.6, 1.65), (0.55, 1.9), (0, 1.9)], segments=96, mats=(chrome("nut-chrome"),))
    knurl = nut.modifiers.new("knurl", "DISPLACE")
    tex = bpy.data.textures.new("knurl", type="WOOD")
    tex.wood_type = "RINGS"
    tex.noise_basis_2 = "SAW"
    knurl.texture = tex
    knurl.strength = 0.0
    handle = S.lathe("bat", [(0, 0), (0.32, 0), (0.3, 1.2), (0.36, 3.2), (0.52, 4.3), (0.5, 4.75), (0.3, 5.0), (0, 5.05)], segments=64, mats=(chrome("bat-chrome"),))
    handle.location = (0, 0, 1.75)
    handle.rotation_euler = (0, math.radians(30 * direction), 0)
    cam = S.camera(scene, (0, 0, 2.0), azimuth=0.0, elevation=38.0, distance=60.0, lens=85.0)
    return finish(scene, cam, (0, 0, 2.0), name, pad=0.08)


# --------------------------------------------------------------------------- arrow button

def arrow_button(pressed, name):
    scene = S.fresh_scene()
    S.setup_cycles(scene, 200, 200, samples=192, transparent=True, exposure=0.12)
    S.lathe("bezel", [(1.9, 0.0), (2.3, 0.0), (2.4, 0.2), (2.4, 0.55), (2.2, 0.75), (1.85, 0.7), (1.8, 0.4)], segments=128, mats=(chrome("bezel-chrome"),))
    dz = -0.28 if pressed else 0.0
    dome = S.lathe("dome", [(0, 1.15 + dz), (0.9, 1.1 + dz), (1.55, 0.95 + dz), (1.8, 0.7 + dz), (1.8, 0.3), (0, 0.3)], segments=128, mats=(brass("dome-brass"),))
    # 浮雕箭头（朝 +X）
    bm = bmesh.new()
    tri = [(-0.45, -0.62), (0.62, 0.0), (-0.45, 0.62), (-0.2, 0.0)]
    bottom = [bm.verts.new((x, y, 1.0 + dz)) for x, y in tri]
    top = [bm.verts.new((x, y, 1.28 + dz)) for x, y in tri]
    bm.faces.new(list(reversed(bottom)))
    bm.faces.new(top)
    for i in range(len(tri)):
        j = (i + 1) % len(tri)
        bm.faces.new([bottom[i], bottom[j], top[j], top[i]])
    arrow = S.mesh_object("arrow", bm, smooth=False, mats=(S.principled("arrow-brass", "#E4C98C", rough=0.18, metal=1.0),))
    bev = arrow.modifiers.new("bevel", "BEVEL")
    bev.width = 0.05
    bev.segments = 3
    cam = S.camera(scene, (0, 0, 0.6), azimuth=0.0, elevation=58.0, distance=60.0, lens=85.0)
    return finish(scene, cam, (0, 0, 0.6), name, pad=0.06)


# --------------------------------------------------------------------------- start button

def start_button(state, name):
    scene = S.fresh_scene()
    S.setup_cycles(scene, 320, 320, samples=256, transparent=True, exposure=0.1)
    S.lathe("ring", [(2.55, 0.0), (3.2, 0.0), (3.32, 0.25), (3.3, 0.8), (3.05, 1.05), (2.6, 1.0), (2.5, 0.7)], segments=160, mats=(chrome("ring-chrome"),))
    S.lathe("collar", [(2.45, 0.2), (2.6, 0.2), (2.6, 0.9), (2.45, 0.95)], segments=160, mats=(S.principled("collar", "#1E1A17", rough=0.4),))
    dz = -0.32 if state == "pressed" else 0.0
    lit = state == "lit"
    cap = S.principled("cap", "#C4402F", rough=0.18, Coat_Weight=1.0, Coat_Roughness=0.04, Subsurface_Weight=0.4,
                       Emission_Color="#FF3A14", Emission_Strength=0.55 if lit else 0.0)
    S.lathe("cap", [(0, 1.75 + dz), (1.2, 1.7 + dz), (2.05, 1.5 + dz), (2.42, 1.15 + dz), (2.42, 0.4), (0, 0.4)], segments=160, mats=(cap,))
    if lit:
        glow = bpy.data.lights.new("glow", "POINT")
        glow.energy = 9
        glow.color = S.hex_rgb("#FF5A2A")
        gob = bpy.data.objects.new("glow", glow)
        gob.location = (0, 0, 0.6)
        S.link(gob, scene)
    cam = S.camera(scene, (0, 0, 0.8), azimuth=0.0, elevation=60.0, distance=60.0, lens=85.0)
    return finish(scene, cam, (0, 0, 0.8), name, pad=0.06)


def main():
    outputs = [(panel(), "BoothPanel"), (marquee(), "BoothMarquee")]
    outputs.append((lever(-1, "BoothLeverLeft"), "BoothLeverLeft"))
    outputs.append((lever(1, "BoothLeverRight"), "BoothLeverRight"))
    outputs.append((arrow_button(False, "BoothArrow"), "BoothArrow"))
    outputs.append((arrow_button(True, "BoothArrowPressed"), "BoothArrowPressed"))
    for state, name in (("idle", "BoothStart"), ("lit", "BoothStartLit"), ("pressed", "BoothStartPressed")):
        outputs.append((start_button(state, name), name))
    S.contact_sheet(outputs, os.path.join(HERE, "contact.png"), cols=5, cell=(300, 300), bgs=("#E9E2D4", "#2A211B"))


if __name__ == "__main__":
    main()
