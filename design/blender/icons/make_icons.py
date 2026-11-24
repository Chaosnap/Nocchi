"""Nocchi · 相册模式切换的四个小图标（同一机位、同一光照）。

ModeIconCork      小软木板（胡桃木框）+ 一张用图钉钉住的即显相片
ModeIconCardBox   卡片盒（直接复用 cardbox 的模型）
ModeIconFilm      胶卷罐 + 一截卷曲的胶片
ModeIconCalendar  复古翻页台历（黄铜环、红色日期）

用法：
    /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup \
        -P design/blender/icons/make_icons.py -- [--only cork,film] [--preview]
"""

import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "canisters"))
sys.path.insert(0, os.path.join(HERE, "..", "cardbox"))
import studio as S  # noqa: E402

OUT = os.path.join(HERE, "out")
SIZE = 192
# 画布四周留出地方给地面阴影（光从左上来、阴影落向右下）：物体只占中间约 56%，阴影在画布边之前淡到透明，
# 不会被画布截成直角。App 里按 `ModeIcon.overscan` 放大显示，物体看起来和以前一样大。
PAD = 0.22
ANCHOR = (0.45, 0.45)
FADE_MARGIN = 0.16


def scene_for_icon(samples):
    scene = S.fresh_scene()
    S.setup_cycles(scene, SIZE, SIZE, samples=samples, transparent=True, exposure=0.2)
    return scene


def finish(scene, target, name, preview, azimuth=-36.0, elevation=30.0, pad=PAD):
    cam = S.camera(scene, target, azimuth=azimuth, elevation=elevation, distance=60.0, lens=90.0)
    meshes = [o for o in scene.objects if o.type in ("MESH", "FONT") and not o.is_shadow_catcher and not o.hide_render]
    S.light_rig(scene, cam, target, scale=1.2, power_scale=1.0, world_strength=0.35)
    S.shadow_catcher(scene, size=300.0)
    S.fit_camera(scene, cam, meshes, pad=pad, anchor=ANCHOR)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".png")
    S.render_to(scene, path)
    S.fade_shadow_edges(path, margin=FADE_MARGIN)
    if not preview:
        S.write_imageset(name, path, filename=name.lower() + ".png")
    return path


def box(name, size, loc, mat, bevel=0.02, parent=None):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= size[0]
        v.co.y *= size[1]
        v.co.z *= size[2]
    ob = S.mesh_object(name, bm, smooth=False, mats=(mat,))
    ob.location = loc
    if bevel:
        mod = ob.modifiers.new("bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 3
    if parent:
        ob.parent = parent
    return ob


def cork_material():
    m = bpy.data.materials.new("cork")
    m.use_nodes = True
    nodes, links = m.node_tree.nodes, m.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 0.92
    vor = nodes.new("ShaderNodeTexVoronoi")
    vor.inputs["Scale"].default_value = 60.0
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 140.0
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = S.lin("#8A5E36")
    ramp.color_ramp.elements[1].color = S.lin("#D3A675")
    mid = ramp.color_ramp.elements.new(0.5)
    mid.color = S.lin("#B9895B")
    add = nodes.new("ShaderNodeMath")
    add.operation = "ADD"
    links.new(vor.outputs["Distance"], add.inputs[0])
    links.new(noise.outputs["Fac"], add.inputs[1])
    half = nodes.new("ShaderNodeMath")
    half.operation = "MULTIPLY"
    half.inputs[1].default_value = 0.6
    links.new(add.outputs[0], half.inputs[0])
    links.new(half.outputs[0], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    bump = nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.4
    links.new(half.outputs[0], bump.inputs["Height"])
    links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    return m


def photo(parent, w, loc, rot, colors):
    """一张即显相片：象牙白相纸 + 渐变画面。"""
    paper = S.principled("photo-paper", "#F4F0E6", rough=0.55)
    h = w * 107 / 88
    card = box("photo", (w, 0.03, h), loc, paper, bevel=0.01, parent=parent)
    card.rotation_euler = rot
    img = bpy.data.materials.new("photo-img")
    img.use_nodes = True
    nodes, links = img.node_tree.nodes, img.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 0.3
    tc = nodes.new("ShaderNodeTexCoord")
    grad = nodes.new("ShaderNodeTexGradient")
    links.new(tc.outputs["Generated"], grad.inputs["Vector"])
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = S.lin(colors[0])
    ramp.color_ramp.elements[1].color = S.lin(colors[1])
    links.new(grad.outputs["Fac"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    window = box("photo-window", (w * 0.88, 0.01, w * 0.88), (0, -0.02, h * 0.5 - w * 0.06 - w * 0.44), img, bevel=0, parent=card)
    return card


def map_pin(parent, loc, color):
    head = S.principled("pin-head", color, rough=0.18)
    metal = S.brushed_metal("pin-metal", "#D0D0D0", rough=0.2, aniso=0.4, radial=False)
    pin = S.lathe("pin", [(0, 0), (0.05, 0), (0.05, 0.5), (0, 0.5)], segments=32, mats=(metal,))
    pin.rotation_euler = (math.radians(90), 0, 0)
    pin.location = loc
    pin.parent = parent
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.42, location=(loc[0], loc[1] - 0.55, loc[2]))
    ball = bpy.context.active_object
    ball.data.materials.append(head)
    for p in ball.data.polygons:
        p.use_smooth = True
    ball.parent = parent
    return ball


def icon_cork(preview):
    scene = scene_for_icon(48 if preview else 160)
    root = bpy.data.objects.new("root", None)
    S.link(root)
    walnut = S.principled("walnut", "#5A3A28", rough=0.45)
    S.add_fine_bump(walnut, scale=60.0, strength=0.05, distance=0.01)
    cork = cork_material()
    W, H, T = 12.0, 9.0, 0.5
    # 软木板立着，像挂在墙上：正面朝 -Y
    board = box("board", (W, T, H), (0, 0, H / 2 + 0.6), cork, bevel=0.02, parent=root)
    f = 0.8
    box("frame-top", (W + 2 * f, T + 0.4, f), (0, 0, H + 0.6 + f / 2), walnut, bevel=0.12, parent=root)
    box("frame-bottom", (W + 2 * f, T + 0.4, f), (0, 0, 0.6 - f / 2), walnut, bevel=0.12, parent=root)
    box("frame-left", (f, T + 0.4, H), (-W / 2 - f / 2, 0, H / 2 + 0.6), walnut, bevel=0.12, parent=root)
    box("frame-right", (f, T + 0.4, H), (W / 2 + f / 2, 0, H / 2 + 0.6), walnut, bevel=0.12, parent=root)
    card = photo(root, 4.6, (-1.2, -0.3, H / 2 + 0.9), (0, math.radians(-6), 0), ("#E9C08A", "#5F8FA0"))
    photo(root, 3.6, (3.2, -0.28, H / 2 + 1.6), (0, math.radians(8), 0), ("#C4593B", "#F2D9A8"))
    map_pin(root, (-1.2, -0.35, H / 2 + 3.3), "#C4593B")
    map_pin(root, (3.2, -0.33, H / 2 + 3.3), "#D9A441")
    root.rotation_euler = (math.radians(-8), 0, 0)
    return finish(scene, (0, 0, H / 2), "ModeIconCork", preview, azimuth=-24.0, elevation=12.0)


def icon_cardbox(preview):
    import make_cardbox as C
    scene = scene_for_icon(48 if preview else 160)
    root = bpy.data.objects.new("root", None)
    S.link(root)
    C.build_box(root)
    C.build_cards(root)
    C.build_pen(root)
    for ob in scene.objects:
        if ob.name.startswith("cutter"):
            ob.hide_render = True
    return finish(scene, (0, 0, 4.0), "ModeIconCardBox", preview, azimuth=-50.0, elevation=32.0, pad=PAD - 0.02)


def icon_film(preview):
    import json
    import make_canisters as K
    scene = scene_for_icon(48 if preview else 160)
    stocks = json.load(open(K.STOCKS_JSON))["stocks"]
    stock = next(s for s in stocks if s["id"] == "gold-200")
    target = (0, 0, 2.2)
    cam = S.camera(scene, target, azimuth=-36.0, elevation=30.0, distance=60.0, lens=90.0)
    cam_dir = Vector((cam.location.x, cam.location.y, 0)).normalized()
    front = math.atan2(cam_dir.y, cam_dir.x)
    label = K.label_png(stock, os.path.join(OUT, "label-gold.png"))
    objs = K.build_canister(stock, front, label)
    # 一截卷曲的胶片：从绒口抽出来，绕个弯落到桌面
    film = S.principled("film-base", "#2A1A10", rough=0.22)
    amber = S.principled("film-frame", "#C98B4A", rough=0.25)
    lip_angle = front + math.radians(62)
    tangent = Vector((-math.sin(lip_angle), math.cos(lip_angle), 0))
    radial = Vector((math.cos(lip_angle), math.sin(lip_angle), 0))
    bm = bmesh.new()
    pts = []
    n = 40
    for i in range(n + 1):
        t = i / n
        a = t * math.pi * 1.25
        p = radial * (1.35 + 2.6 * t) + tangent * (1.2 + 2.4 * math.sin(a))
        z = 2.2 * (1 - t) ** 1.6
        pts.append((p, z))
    width = 3.5
    lo = [bm.verts.new((p.x, p.y, z + 0.4)) for p, z in pts]
    hi = [bm.verts.new((p.x, p.y, z + 0.4 + width * (1 - 0.0))) for p, z in pts]
    faces = []
    for i in range(n):
        f = bm.faces.new([lo[i], lo[i + 1], hi[i + 1], hi[i]])
        f.material_index = 1 if (i // 5) % 2 == 0 and 0 < i < n - 1 else 0
        faces.append(f)
    strip = S.mesh_object("strip", bm, smooth=True, mats=(film, amber))
    mod = strip.modifiers.new("solid", "SOLIDIFY")
    mod.thickness = 0.03
    S.light_rig(scene, cam, target, scale=1.2, power_scale=1.0, world_strength=0.35)
    S.shadow_catcher(scene, size=300.0)
    meshes = [o for o in scene.objects if o.type == "MESH" and not o.is_shadow_catcher]
    S.fit_camera(scene, cam, meshes, pad=PAD, anchor=ANCHOR)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "ModeIconFilm.png")
    S.render_to(scene, path)
    S.fade_shadow_edges(path, margin=FADE_MARGIN)
    if not preview:
        S.write_imageset("ModeIconFilm", path, filename="modeiconfilm.png")
    return path


def icon_calendar(preview):
    scene = scene_for_icon(48 if preview else 160)
    root = bpy.data.objects.new("root", None)
    S.link(root)
    walnut = S.principled("cal-wood", "#6A4530", rough=0.45)
    paper = S.principled("cal-paper", "#F3EBDD", rough=0.8)
    brass = S.principled("brass", "#C9A35A", rough=0.25, metal=1.0)
    # 页面图案：大号红色日期
    page_png = os.path.join(OUT, "calendar-page.png")
    os.makedirs(OUT, exist_ok=True)
    fl = S.Flat(60, 52, 512, bg="#F3EBDD", samples=16, name="page")
    fl.rect(0, 44, 60, 8, "#B23A2A")
    fl.text("NOV", "futura-bold", 6.0, 30, 46.2, "#F3EBDD", align="CENTER", tracking=0.3)
    fl.text("24", "didot-bold", 30, 30, 12, "#B23A2A", align="CENTER")
    fl.text("2026  ·  MON", "typewriter", 3.6, 30, 5, "#2E2924", align="CENTER", tracking=0.1)
    fl.render(page_png)
    fl.dispose()
    page_mat = S.principled("page", "#FFFFFF", rough=0.75)
    tex = S.image_node(page_mat, page_png)
    page_mat.node_tree.links.new(tex.outputs["Color"], S.principled_node(page_mat).inputs["Base Color"])
    # A 字形支架
    tilt = math.radians(14)
    stand = box("stand", (6.6, 0.4, 6.0), (0, 0.7, 3.0), walnut, bevel=0.15, parent=root)
    stand.rotation_euler = (-tilt, 0, 0)
    base = box("base", (7.2, 3.6, 0.5), (0, 0.6, 0.25), walnut, bevel=0.15, parent=root)
    # 一叠页
    for k in range(6):
        pg = box("page-back", (6.0, 0.04, 5.2), (0, 0.2 - k * 0.05, 3.1), paper, bevel=0, parent=root)
        pg.rotation_euler = (-tilt, 0, 0)
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    vs = [bm.verts.new(c) for c in ((-3, 0, -2.6), (3, 0, -2.6), (3, 0, 2.6), (-3, 0, 2.6))]
    f = bm.faces.new(vs)
    for loop, coord in zip(f.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
        loop[uvl].uv = coord
    front = S.mesh_object("page-front", bm, smooth=False, mats=(page_mat,))
    front.location = (0, -0.12, 3.1)
    front.rotation_euler = (-tilt, 0, 0)
    front.parent = root
    for x in (-1.8, 0, 1.8):
        ring = S.lathe("ring", [(0.32, -0.06), (0.4, -0.06), (0.4, 0.06), (0.32, 0.06)], segments=48, mats=(brass,))
        ring.rotation_euler = (0, math.radians(90), 0)
        ring.location = (x, 0.05, 5.65)
        ring.parent = root
    return finish(scene, (0, 0, 3.0), "ModeIconCalendar", preview, azimuth=-30.0, elevation=16.0)


def main():
    args = S.script_args()
    preview = "--preview" in args
    only = set(args[args.index("--only") + 1].split(",")) if "--only" in args else {"cork", "cardbox", "film", "calendar"}
    outputs = []
    if "cork" in only:
        outputs.append((icon_cork(preview), "cork"))
    if "cardbox" in only:
        outputs.append((icon_cardbox(preview), "cardbox"))
    if "film" in only:
        outputs.append((icon_film(preview), "film"))
    if "calendar" in only:
        outputs.append((icon_calendar(preview), "calendar"))
    S.contact_sheet(outputs, os.path.join(HERE, "contact.png"), cols=4, cell=(220, 230), sizes=(None, 30), bgs=("#F2EEE6", "#1E1E1E"))


if __name__ == "__main__":
    main()
