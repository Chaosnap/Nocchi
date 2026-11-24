"""Nocchi · 大头贴机整机正面（Blender 一体建模）。

装饰艺术（art deco）风格的胡桃木 + 黄铜大头贴机，正对镜头（正交），光从左上方来：
  拱顶：胡桃木拱框、一圈暖光灯泡、暗红搪瓷牌上立体金字「大头贴机」、金色放射纹；
  镀铬横带 + 黄铜扇形徽章；
  橱窗：镀铬包边的大橱窗（中间透明，界面在里面放样张 / 摄像头画面），两边胡桃木凹槽立柱 + 黄铜柱头，柱上黄铜箭头按钮的座；
  黄铜铭牌（界面写模板名）、黑色页码槽；
  奶油色搪瓷控制台（镀铬包边）：两块拉丝镀铬开关板（刻「四格条 / 四宫格」「黑白 / 彩色」）、拨杆的胶木垫圈和滚花螺母、「开始」按钮的镀铬座；
  底座：胡桃木、镀铬踢脚条、出片口、投币口、黄铜百叶。

输出（@2x，1 cm = 10 pt，画布 72 × 96 cm = 720 × 960 pt）：
  Shared/Art.xcassets/BoothMachine            整机（不含会动的零件；橱窗透明，橱窗里只有包边投下的阴影）
  BoothMachineArrowLeft[Down] / ArrowRight[Down]   黄铜箭头按钮帽（抬起 / 按下）
  BoothMachineFormatLeft / FormatRight / ColorLeft / ColorRight   两个拨杆的两个位置
  BoothMachineStart / StartLit / StartDown   「开始」按钮帽（暗 / 亮 / 按下）
零件和整机同一个镜头、同一套灯，用渲染边框裁成小图；零件的阴影落在机身上（机身当阴影捕捉器）。
热区写进 macOS/Nocchi/Booth/BoothMachineLayout.swift（生成的，不要手改）。

用法：
    /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P design/blender/booth/make_machine.py [-- --preview]
"""

import json
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from bpy_extras.object_utils import world_to_camera_view

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "canisters"))
import studio as S  # noqa: E402

OUT = os.path.join(HERE, "out")
SWIFT = os.path.join(S.REPO, "macOS", "Nocchi", "Booth", "BoothMachineLayout.swift")
CANVAS = (72.0, 96.0)
PX_PER_CM = 20
SONGTI = "/System/Library/Fonts/Supplemental/Songti.ttc"
# `--english`：英文界面用的整机图（招牌、刻字换成英文，零件和热区不变），写成 `BoothMachineEN`。
ENGLISH = "--english" in S.script_args()
ENGLISH_TEXT = {"大头贴机": "PHOTO BOOTH", "四格条": "STRIP", "四宫格": "GRID", "黑白": "B&W", "彩色": "COLOUR",
                "出片口": "PRINTS", "投币": "COIN"}


def say(body):
    """招牌和刻字：英文版换成英文。"""
    return ENGLISH_TEXT.get(body, body) if ENGLISH else body


def latin(key):
    """英文刻字用的字体（中文版返回 None，用宋体）。"""
    return S.font(key) if ENGLISH else None
DIDOT = "/System/Library/Fonts/Supplemental/Didot.ttc"


def P(x, y):
    """设计坐标（cm，左上原点、y 向下）→ Blender（中心原点、y 向上）。"""
    return (x - CANVAS[0] / 2, CANVAS[1] / 2 - y)


# --------------------------------------------------------------------------- materials

def chrome(name="chrome"):
    return S.principled(name, "#E9EAEE", rough=0.07, metal=1.0)


def brass(name="brass", rough=0.26):
    return S.principled(name, "#C9A35A", rough=rough, metal=1.0)


def gold_leaf(name="gold-leaf"):
    return S.principled(name, "#E6BE6C", rough=0.2, metal=1.0)


def enamel(name, color, coat=0.45, rough=0.38):
    return S.principled(name, color, rough=rough, Coat_Weight=coat, Coat_Roughness=0.1)


def bakelite(name="bakelite"):
    return S.principled(name, "#1A1716", rough=0.3, Coat_Weight=0.5, Coat_Roughness=0.15)


def walnut(name="walnut", along="Y"):
    """亮漆胡桃木：拉长的波纹做木纹，再叠一层细毛孔；清漆层很亮。"""
    mat = S.principled(name, "#4A2C1A", rough=0.34, Coat_Weight=0.9, Coat_Roughness=0.06)
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    p = S.principled_node(mat)
    tc = nodes.new("ShaderNodeTexCoord")
    mp = nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (1.0, 0.11, 1.0) if along == "Y" else (0.11, 1.0, 1.0)
    links.new(tc.outputs["Object"], mp.inputs["Vector"])
    wave = nodes.new("ShaderNodeTexWave")
    wave.wave_type = "BANDS"
    wave.bands_direction = "X" if along == "Y" else "Y"
    wave.inputs["Scale"].default_value = 1.9
    wave.inputs["Distortion"].default_value = 3.2
    wave.inputs["Detail"].default_value = 6.0
    wave.inputs["Detail Scale"].default_value = 1.2
    try:
        wave.inputs["Detail Roughness"].default_value = 0.55
    except KeyError:
        pass
    links.new(mp.outputs["Vector"], wave.inputs["Vector"])
    ramp = nodes.new("ShaderNodeValToRGB")
    cr = ramp.color_ramp
    cr.elements[0].position = 0.0
    cr.elements[0].color = S.lin("#301B0E")
    cr.elements[1].position = 1.0
    cr.elements[1].color = S.lin("#6C4428")
    e = cr.elements.new(0.55)
    e.color = S.lin("#4A2B18")
    links.new(wave.outputs["Fac"], ramp.inputs["Fac"])
    pores = nodes.new("ShaderNodeTexNoise")
    pores.inputs["Scale"].default_value = 35.0
    pores.inputs["Detail"].default_value = 6.0
    mp2 = nodes.new("ShaderNodeMapping")
    mp2.inputs["Scale"].default_value = (1.0, 0.08, 1.0) if along == "Y" else (0.08, 1.0, 1.0)
    links.new(tc.outputs["Object"], mp2.inputs["Vector"])
    links.new(mp2.outputs["Vector"], pores.inputs["Vector"])
    mix = nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs["Factor"].default_value = 0.18
    links.new(ramp.outputs["Color"], mix.inputs[6])
    links.new(pores.outputs["Color"], mix.inputs[7])
    links.new(mix.outputs[2], p.inputs["Base Color"])
    bump = nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.025
    bump.inputs["Distance"].default_value = 0.01
    links.new(pores.outputs["Fac"], bump.inputs["Height"])
    links.new(bump.outputs["Normal"], p.inputs["Normal"])
    return mat


def brushed(name, color="#D6D8DC", rough=0.22):
    """拉丝金属（横向细纹）。"""
    mat = S.principled(name, color, rough=rough, metal=1.0)
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    tc = nodes.new("ShaderNodeTexCoord")
    mp = nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (0.05, 18.0, 1.0)
    links.new(tc.outputs["Object"], mp.inputs["Vector"])
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 6.0
    noise.inputs["Detail"].default_value = 8.0
    links.new(mp.outputs["Vector"], noise.inputs["Vector"])
    bump = nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.08
    links.new(noise.outputs["Fac"], bump.inputs["Height"])
    links.new(bump.outputs["Normal"], S.principled_node(mat).inputs["Normal"])
    return mat


# --------------------------------------------------------------------------- geometry helpers

def prism(name, pts, z0, z1, mat, bevel=0.0, segments=4, angle=40):
    """XY 平面上的多边形挤出成柱体（z0 → z1）。"""
    bm = bmesh.new()
    bottom = [bm.verts.new((x, y, z0)) for x, y in pts]
    top = [bm.verts.new((x, y, z1)) for x, y in pts]
    fb = bm.faces.new(list(reversed(bottom)))
    ft = bm.faces.new(top)
    n = len(pts)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new([bottom[i], bottom[j], top[j], top[i]])
    bm.normal_update()
    if ft.normal.z < 0:
        for f in bm.faces:
            f.normal_flip()
    ob = S.mesh_object(name, bm, smooth=False, mats=(mat,))
    if bevel > 0:
        mod = ob.modifiers.new("bevel", "BEVEL")
        mod.width = bevel
        mod.segments = segments
        mod.limit_method = "ANGLE"
        mod.angle_limit = math.radians(angle)
        ob.modifiers.new("wn", "WEIGHTED_NORMAL")
    return ob


def rrect(x0, y0, x1, y1, r, seg=12):
    """Blender 坐标的圆角矩形（x0 < x1、y0 < y1）。"""
    return S.rounded_rect_points(x0, y0, x1 - x0, y1 - y0, r, seg=seg)


def design_rrect(dx0, dy0, dx1, dy1, r, seg=12):
    """设计坐标（左上原点、y 向下）的圆角矩形 → Blender 点。"""
    a = P(dx0, dy1)
    b = P(dx1, dy0)
    return rrect(a[0], a[1], b[0], b[1], r, seg)


def cut(ob, cutter):
    """布尔挖洞（挖洞在倒角之前）。"""
    mod = ob.modifiers.new("cut-" + cutter.name, "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.object = cutter
    try:
        mod.solver = "EXACT"
    except Exception:
        pass
    cutter.hide_render = True
    cutter.display_type = "WIRE"
    # 布尔要在倒角前面：挪到第一个。
    while ob.modifiers.find(mod.name) > 0:
        bpy.ops.object.modifier_move_up({"object": ob}, modifier=mod.name) if False else None
        break
    order = [m.name for m in ob.modifiers]
    if order and order[0] != mod.name:
        ob.modifiers.move(order.index(mod.name), 0)
    return mod


def tube(name, pts, radius, mat, cyclic=True, z=0.0):
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = radius
    cu.bevel_resolution = 5
    cu.use_fill_caps = True
    sp = cu.splines.new("POLY")
    sp.points.add(len(pts) - 1)
    for p, q in zip(sp.points, pts):
        p.co = (q[0], q[1], q[2] if len(q) > 2 else z, 1.0)
    sp.use_cyclic_u = cyclic
    ob = bpy.data.objects.new(name, cu)
    ob.data.materials.append(mat)
    S.link(ob)
    return ob


_fonts = {}


def cjk_font(face):
    if face in _fonts:
        return _fonts[face]
    out = os.path.join(OUT, "songti-%d.ttf" % face)
    os.makedirs(OUT, exist_ok=True)
    if not os.path.exists(out):
        S._extract_ttc_face(SONGTI, face, out)
    f = bpy.data.fonts.load(out, check_existing=True)
    _fonts[face] = f
    return f


def didot_bold():
    """Didot Bold（Didot.ttc 的第 3 个字面）：和相册字标 NOCCHI 同一家族，粗体的发丝线挤出、倒角后不会断。"""
    if "didot-bold" in _fonts:
        return _fonts["didot-bold"]
    out = os.path.join(OUT, "didot-bold.ttf")
    os.makedirs(OUT, exist_ok=True)
    if not os.path.exists(out):
        S._extract_ttc_face(DIDOT, 2, out)
    f = bpy.data.fonts.load(out, check_existing=True)
    _fonts["didot-bold"] = f
    return f


def text(name, body, size, at, z, mat, face=1, extrude=0.03, bevel=0.0, spacing=1.0, font=None):
    cu = bpy.data.curves.new(name, type="FONT")
    cu.body = body
    cu.font = font or cjk_font(face)
    cu.size = size
    cu.extrude = extrude
    cu.bevel_depth = bevel
    cu.bevel_resolution = 3
    cu.align_x = "CENTER"
    cu.align_y = "CENTER"
    cu.space_character = spacing
    ob = bpy.data.objects.new(name, cu)
    ob.data.materials.append(mat)
    ob.location = (at[0], at[1], z + extrude)
    S.link(ob)
    return ob


def lathe_at(name, profile, at, mats, segments=96):
    ob = S.lathe(name, profile, segments=segments, mats=mats)
    ob.location = (at[0], at[1], 0)
    return ob


def ellipse_arc(cx, cy, a, b, t0, t1, n):
    return [(cx + a * math.cos(t), cy + b * math.sin(t)) for t in np.linspace(t0, t1, n)]


def resample(path, count, closed=False):
    pts = np.array(path, dtype=float)
    if closed:
        pts = np.vstack([pts, pts[:1]])
    seg = np.linalg.norm(np.diff(pts, axis=0), axis=1)
    cum = np.concatenate([[0], np.cumsum(seg)])
    targets = np.linspace(0, cum[-1], count, endpoint=not closed)
    xs = np.interp(targets, cum, pts[:, 0])
    ys = np.interp(targets, cum, pts[:, 1])
    return list(zip(xs, ys))


# --------------------------------------------------------------------------- the machine

def crown_outline(inset=0.0):
    """拱顶外形（Blender 坐标）：两边竖直，上面一段椭圆拱。"""
    left, right = -32.0 + inset, 32.0 - inset
    y0 = 28.0 + (0.9 if inset > 0 else 0.0)
    ys = 34.0
    b = 12.0 - inset
    a = 32.0 - inset
    arc = ellipse_arc(0, ys, a, b, math.pi, 0, 72)
    return [(left, y0)] + arc + [(right, y0)]


def build_machine(scene):
    base, parts = [], {}
    wal = walnut("walnut")
    wal_h = walnut("walnut-h", along="X")
    chr_ = chrome()
    brs = brass()
    gld = gold_leaf()
    red = enamel("red-enamel", "#6A1220", coat=0.65, rough=0.3)
    red_ray = enamel("red-ray", "#86202D", coat=0.65, rough=0.26)
    cream = enamel("cream-enamel", "#EFE5D0", coat=0.5, rough=0.36)
    black = enamel("black-enamel", "#141212", coat=0.5, rough=0.3)
    ink = S.principled("engraving", "#1B1513", rough=0.5)

    # ---- 拱顶
    crown = prism("crown", crown_outline(), 0.0, 3.0, wal_h, bevel=0.35)
    field = crown_outline(inset=2.6)
    cut(crown, prism("crown-cutter", field, 1.0, 9.0, wal_h))
    base.append(crown)
    base.append(prism("crown-field", field, 0.0, 2.55, red, bevel=0.12))
    base.append(tube("crown-bead-in", [(x, y, 2.62) for x, y in resample(field, 260)], 0.16, brs, cyclic=True))
    base.append(tube("crown-bead-out", [(x, y, 2.95) for x, y in resample(crown_outline(inset=0.25), 300)], 0.2, brs, cyclic=True))
    # 放射纹：从招牌下沿中间往上散开，留在搪瓷牌里面。
    for k in range(17):
        ang = math.radians(12 + (156.0 / 16) * k)
        width = math.radians(2.6 if k % 2 == 0 else 1.4)
        r0, r1 = 4.0, 15.6 if k % 2 == 0 else 13.2
        cx, cy = 0.0, 29.2
        pts = [(cx + r0 * math.cos(ang - width / 3), cy + r0 * math.sin(ang - width / 3)),
               (cx + r1 * math.cos(ang - width / 2), cy + r1 * math.sin(ang - width / 2)),
               (cx + r1 * math.cos(ang + width / 2), cy + r1 * math.sin(ang + width / 2)),
               (cx + r0 * math.cos(ang + width / 3), cy + r0 * math.sin(ang + width / 3))]
        # 截在搪瓷牌的椭圆里面（留 0.8 cm）。
        clipped = []
        for x, y in pts:
            if y > 34.0:
                a, b = 29.4 - 0.8, 9.4 - 0.8
                t = ((x / a) ** 2 + ((y - 34.0) / b) ** 2) ** 0.5
                if t > 1:
                    x, y = x / t, 34.0 + (y - 34.0) / t
            clipped.append((x, y))
        base.append(prism("ray%d" % k, clipped, 2.55, 2.66, red_ray, bevel=0.03))
    # 立体金字招牌
    sign = text("sign", say("大头贴机"), 5.4 if ENGLISH else 6.0, (0.0, 36.3), 2.55, gld, face=0, extrude=0.42, bevel=0.07,
                spacing=1.12 if ENGLISH else 1.08, font=latin("futura-cxb"))
    base.append(sign)
    # 灯泡：沿着胡桃木拱框一圈
    glass = S.principled("bulb-glass", "#FFFFFF", rough=0.04, Transmission_Weight=1.0, IOR=1.45)
    glow = S.emission_mat("bulb-glow", "#FFC97A", strength=24.0)
    socket = chrome("bulb-socket")
    mid = [(-30.7, 29.2)] + ellipse_arc(0, 34.0, 30.7, 10.7, math.pi, 0, 200) + [(30.7, 29.2)]
    bulbs = resample(mid, 19)
    for i, (x, y) in enumerate(bulbs):
        base.append(lathe_at("bulb-socket%d" % i, [(0, 2.9), (0.78, 2.9), (0.78, 3.35), (0, 3.35)], (x, y), (socket,), 32))
        base.append(lathe_at("bulb-fil%d" % i, [(0, 3.35), (0.42, 3.5), (0.42, 3.85), (0, 4.0)], (x, y), (glow,), 24))
        base.append(lathe_at("bulb%d" % i, [(0, 3.3), (0.6, 3.42), (0.74, 3.8), (0.6, 4.25), (0, 4.38)], (x, y), (glass,), 32))
        light = bpy.data.lights.new("bulb-light%d" % i, "POINT")
        light.energy = 30.0
        light.color = S.hex_rgb("#FFCF8C")
        light.shadow_soft_size = 0.4
        lob = bpy.data.objects.new("bulb-light%d" % i, light)
        lob.location = (x, y, 3.9)
        S.link(lob, scene)
        base.append(lob)

    # ---- 横带 + 扇形徽章
    base.append(prism("band", rrect(-32.4, 26.0, 32.4, 28.2, 0.4), 0.0, 3.45, chr_, bevel=0.18))
    base.append(lathe_at("medallion", [(0, 3.9), (1.2, 3.85), (1.9, 3.65), (2.1, 3.45), (2.1, 3.3), (0, 3.3)], (0, 27.1), (brs,), 96))
    base.append(lathe_at("medallion-ring", [(1.35, 3.88), (1.55, 3.95), (1.75, 3.8), (1.55, 3.74)], (0, 27.1), (gld,), 96))

    # ---- 机身（胡桃木，挖出橱窗）
    body = prism("body", rrect(-32.0, -38.2, 32.0, 26.2, 0.6), 0.0, 3.0, wal, bevel=0.3)
    win = rrect(-23.0, -13.0, 23.0, 24.0, 2.6, seg=16)
    cutter = prism("window-cutter", win, -5.0, 8.0, wal)
    cut(body, cutter)
    base.append(body)
    # 橱窗里的「后墙」：阴影捕捉器，只留包边投进去的阴影（界面在下面放样张 / 摄像头）。
    back = prism("window-back", rrect(-24.0, -14.0, 24.0, 25.0, 2.6), -0.8, -0.7, black)
    back.is_shadow_catcher = True
    base.append(back)
    # 镀铬包边：外圈 1.5 cm、圆润的截面；里面一圈黑色胶条。
    bezel = prism("bezel", rrect(-24.5, -14.5, 24.5, 25.5, 4.0, seg=16), 0.6, 3.95, chr_, bevel=0.55, segments=8)
    bezel_cut = prism("bezel-cutter", rrect(-23.0, -13.0, 23.0, 24.0, 2.6, seg=16), -5.0, 9.0, chr_)
    cut(bezel, bezel_cut)
    base.append(bezel)
    gasket = prism("gasket", rrect(-23.25, -13.25, 23.25, 24.25, 2.8, seg=16), 0.4, 3.1, black, bevel=0.1)
    gasket_cut = prism("gasket-cutter", rrect(-22.9, -12.9, 22.9, 23.9, 2.5, seg=16), -5.0, 9.0, black)
    cut(gasket, gasket_cut)
    base.append(gasket)

    # 橱窗外一圈黄铜嵌线
    base.append(tube("window-inlay", [(x, y, 3.02) for x, y in resample(rrect(-25.6, -15.6, 25.6, 26.6 - 1.0, 4.8, seg=16), 360, closed=True)], 0.11, brs, cyclic=True))

    # ---- 凹槽立柱 + 黄铜柱头 + 箭头按钮座
    for side in (-1, 1):
        x0 = 25.2 if side > 0 else -31.2
        base.append(prism("pilaster%d" % side, rrect(x0, -15.0, x0 + 6.0, 25.0, 0.3), 0.0, 3.25, wal, bevel=0.15))
        for i in range(5):
            cx = x0 + 0.6 + 1.2 * i
            reed = bpy.data.meshes.new("reed")
            bm = bmesh.new()
            bmesh.ops.create_cone(bm, cap_ends=True, segments=24, radius1=0.6, radius2=0.6, depth=38.6)
            bm.to_mesh(reed)
            bm.free()
            ob = bpy.data.objects.new("reed%d_%d" % (side, i), reed)
            ob.data.materials.append(wal)
            ob.rotation_euler = (math.radians(90), 0, 0)
            ob.location = (cx, 5.0, 3.2)
            for poly in reed.polygons:
                poly.use_smooth = True
            S.link(ob)
            base.append(ob)
        for (y0, y1) in ((24.6, 26.0), (-15.8, -14.4)):
            base.append(prism("capital%d_%d" % (side, int(y0)), rrect(x0 - 0.3, y0, x0 + 6.3, y1, 0.25), 0.0, 3.95, brs, bevel=0.15))
        cx = x0 + 3.0
        base.append(lathe_at("arrow-socket%d" % side, [(2.35, 3.75), (2.95, 3.75), (3.1, 3.95), (3.05, 4.35), (2.8, 4.5), (2.4, 4.42), (2.3, 4.1)], (cx, 5.5), (brs,), 128))
        base.append(lathe_at("arrow-well%d" % side, [(0, 3.85), (2.36, 3.85), (2.36, 4.0), (0, 4.0)], (cx, 5.5), (black,), 96))

    # ---- 铭牌、页码槽
    base.append(prism("nameplate", rrect(-14.0, -20.0, 14.0, -14.0, 0.6), 2.8, 3.3, brushed("plate-brass", "#C8A25E", rough=0.3), bevel=0.12))
    for sx in (-12.7, 12.7):
        base.append(lathe_at("plate-screw%d" % int(sx), [(0, 3.55), (0.35, 3.5), (0.45, 3.38), (0.45, 3.3), (0, 3.3)], (sx, -17.0), (brs,), 48))
    # 制造商铭牌：黄铜里嵌一块黑漆底，上面是阳刻（凸起）的鎏金字「Nocchi」——一眼认得出是谁家的机器。
    base.append(prism("nameplate-field", rrect(-11.8, -19.3, 11.8, -14.7, 0.5), 3.3, 3.34,
                      enamel("plate-field", "#22160D", coat=0.7, rough=0.32), bevel=0.04))
    base.append(text("brand", "Nocchi", 4.1, (0.0, -17.15), 3.34, gold_leaf("brand-gold"),
                     extrude=0.17, bevel=0.035, spacing=1.04, font=didot_bold()))
    base.append(prism("dots-frame", rrect(-12.4, -22.6, 12.4, -20.4, 1.1), 2.8, 3.15, chr_, bevel=0.1))
    base.append(prism("dots-slot", rrect(-12.0, -22.2, 12.0, -20.8, 0.7), 2.8, 3.17, black, bevel=0.05))

    # ---- 控制台
    deck = rrect(-30.0, -37.4, 30.0, -23.0, 1.8, seg=14)
    base.append(prism("deck", deck, 2.8, 3.35, cream, bevel=0.15))
    base.append(tube("deck-rim", [(x, y, 3.35) for x, y in resample(deck, 320, closed=True)], 0.22, chr_, cyclic=True))
    for side in (-1, 1):
        x0, x1 = (-28.6, -7.4) if side < 0 else (7.4, 28.6)
        base.append(prism("switch-plate%d" % side, rrect(x0, -32.4, x1, -25.6, 1.1), 3.3, 3.5, brushed("switch-plate%d" % side, "#C8A25E", rough=0.3), bevel=0.08))
        sx = (x0 + x1) / 2
        base.append(lathe_at("switch-washer%d" % side, [(0, 3.5), (1.3, 3.5), (1.38, 3.6), (1.38, 3.82), (1.25, 3.92), (0, 3.92)], (sx, -29.0), (bakelite(),), 96))
        base.append(lathe_at("switch-nut%d" % side, [(0, 3.92), (0.85, 3.92), (0.92, 4.0), (0.92, 4.4), (0.82, 4.5), (0.35, 4.5), (0.32, 4.65), (0, 4.65)], (sx, -29.0), (chr_,), 96))
    labels = {"四格条": (-25.0, -29.0), "四宫格": (-11.0, -29.0), "黑白": (12.2, -29.0), "彩色": (23.8, -29.0)}
    for name, (lx, ly) in labels.items():
        base.append(text("label-" + name, say(name), 1.5 if ENGLISH else 1.6, (lx, ly), 3.5, ink, face=0, extrude=0.02,
                         spacing=1.1 if ENGLISH else 1.05, font=latin("futura-cxb")))
    base.append(lathe_at("start-seat", [(3.6, 3.35), (4.85, 3.35), (5.05, 3.6), (5.0, 4.15), (4.7, 4.42), (4.05, 4.36), (3.85, 4.0)], (0.0, -29.6), (chr_,), 192))
    base.append(lathe_at("start-collar", [(0, 3.3), (3.86, 3.3), (3.86, 3.95), (0, 3.95)], (0.0, -29.6), (bakelite("collar"),), 128))

    # ---- 底座
    base.append(prism("plinth", rrect(-33.0, -45.2, 33.0, -38.0, 0.7), 0.0, 3.6, wal_h, bevel=0.3))
    base.append(prism("kick", rrect(-33.1, -45.3, 33.1, -44.3, 0.3), 0.0, 3.95, chr_, bevel=0.15))
    base.append(prism("slot-frame", rrect(-10.0, -42.4, 10.0, -39.8, 1.0), 3.0, 3.95, chr_, bevel=0.2))
    base.append(prism("slot", rrect(-9.2, -41.8, 9.2, -40.4, 0.45), 3.0, 3.97, black))
    base.append(text("slot-label", say("出片口"), 0.95, (0.0, -43.35), 3.6, gld, face=1, extrude=0.02, spacing=1.2,
                     font=latin("futura-cxb")))
    base.append(prism("coin-plate", rrect(19.0, -44.0, 27.0, -38.8, 0.8), 3.0, 3.85, chr_, bevel=0.18))
    base.append(prism("coin-slot", rrect(22.65, -41.9, 23.35, -39.5, 0.3), 3.0, 3.87, black))
    base.append(text("coin-label", say("投币"), 0.9, (23.0, -43.0), 3.85, ink, face=1, extrude=0.015, spacing=1.2,
                     font=latin("futura-cxb")))
    base.append(prism("grille-well", rrect(-27.0, -44.0, -19.0, -38.8, 0.8), 3.0, 3.62, black, bevel=0.1))
    base.append(tube("grille-frame", [(x, y, 3.7) for x, y in resample(rrect(-27.0, -44.0, -19.0, -38.8, 0.8), 120, closed=True)], 0.2, brs, cyclic=True))
    for i in range(5):
        y = -39.7 - 0.95 * i
        base.append(tube("louver%d" % i, [(-26.4, y, 3.75), (-19.6, y, 3.75)], 0.26, brs, cyclic=False))

    # ---- 会动的零件（单独渲染）
    # 箭头按钮帽
    for side, name in ((-1, "ArrowLeft"), (1, "ArrowRight")):
        cx = (28.2 if side > 0 else -28.2)
        for pressed in (False, True):
            dz = -0.32 if pressed else 0.0
            objs = [lathe_at("dome-%s-%d" % (name, pressed), [(0, 5.55 + dz), (1.0, 5.48 + dz), (1.75, 5.25 + dz), (2.2, 4.85 + dz), (2.25, 4.1), (0, 4.1)], (cx, 5.5), (brass("dome%d%d" % (side, pressed), rough=0.22),), 128)]
            bm = bmesh.new()
            tri = [(-0.5, -0.7), (0.7, 0.0), (-0.5, 0.7), (-0.22, 0.0)]
            tri = [(side * x, y) for x, y in tri]
            bottom = [bm.verts.new((cx + x, 5.5 + y, 5.2 + dz)) for x, y in tri]
            top = [bm.verts.new((cx + x, 5.5 + y, 5.62 + dz)) for x, y in tri]
            bm.faces.new(list(reversed(bottom)) if side > 0 else bottom)
            bm.faces.new(top if side > 0 else list(reversed(top)))
            for i in range(len(tri)):
                j = (i + 1) % len(tri)
                bm.faces.new([bottom[i], bottom[j], top[j], top[i]] if side > 0 else [bottom[j], bottom[i], top[i], top[j]])
            bm.normal_update()
            chevron = S.mesh_object("chevron-%s-%d" % (name, pressed), bm, smooth=False, mats=(S.principled("chevron", "#F0D9A0", rough=0.14, metal=1.0),))
            bev = chevron.modifiers.new("bevel", "BEVEL")
            bev.width = 0.06
            bev.segments = 3
            objs.append(chevron)
            parts["%s%s" % (name, "Down" if pressed else "")] = objs
    # 拨杆（蝙蝠柄，绕 Y 轴往左 / 右倒 30°）
    for group, sx in (("Format", -18.0), ("Color", 18.0)):
        for side, suffix in ((-1, "Left"), (1, "Right")):
            handle = S.lathe("bat-%s-%s" % (group, suffix), [(0, 0), (0.4, 0), (0.37, 1.2), (0.45, 3.2), (0.7, 4.3), (0.68, 4.85), (0.42, 5.15), (0, 5.2)], segments=64, mats=(chrome("bat"),))
            handle.location = (sx, -29.0, 4.5)
            handle.rotation_euler = (0, math.radians(40 * side), 0)
            parts[group + suffix] = [handle]
    # 「开始」按钮帽：深红玻璃、里面一盏灯
    for state, name in (("idle", "Start"), ("lit", "StartLit"), ("pressed", "StartDown")):
        dz = -0.34 if state == "pressed" else 0.0
        lit = state == "lit"
        cap_mat = S.principled("cap-" + state, "#B0202C", rough=0.12, Coat_Weight=1.0, Coat_Roughness=0.03, Subsurface_Weight=0.35,
                               Emission_Color="#FF3B2A", Emission_Strength=0.7 if lit else 0.0)
        objs = [lathe_at("cap-" + state, [(0, 5.95 + dz), (1.5, 5.88 + dz), (2.7, 5.55 + dz), (3.5, 4.95 + dz), (3.62, 4.4), (3.62, 3.9), (0, 3.9)], (0.0, -29.6), (cap_mat,), 192)]
        if lit:
            glow = bpy.data.lights.new("cap-glow", "POINT")
            glow.energy = 60.0
            glow.color = S.hex_rgb("#FF5A3A")
            gob = bpy.data.objects.new("cap-glow", glow)
            gob.location = (0.0, -29.6, 4.6)
            S.link(gob, scene)
            objs.append(gob)
        parts[name] = objs

    # 墙：阴影捕捉器（机身后面），边缘再淡出。
    wall = prism("wall", rrect(-40, -52, 40, 52, 0.1), -2.6, -2.5, black)
    wall.is_shadow_catcher = True
    hotspots = dict(bulbs=[(x, y) for x, y in bulbs], labels=labels)
    return base, parts, wall, hotspots


# --------------------------------------------------------------------------- render

def to_points(x, y):
    """Blender 坐标 → 画布上的点（720 × 960，左上原点）。"""
    return ((x + CANVAS[0] / 2) * 10.0, (CANVAS[1] / 2 - y) * 10.0)


def pixel_box(scene, cam, objs, margin_px=(18, 18, 40, 40)):
    """一组物体投影到画面上的像素框（左上原点），再按阴影方向（右下）多留一点边。"""
    W, H = scene.render.resolution_x, scene.render.resolution_y
    deps = bpy.context.evaluated_depsgraph_get()
    xs, ys = [], []
    for ob in objs:
        if ob.type == "LIGHT":
            continue
        ev = ob.evaluated_get(deps)
        mesh = ev.to_mesh()
        for v in mesh.vertices:
            co = world_to_camera_view(scene, cam, ev.matrix_world @ v.co)
            xs.append(co.x)
            ys.append(co.y)
        ev.to_mesh_clear()
    left, right = min(xs) * W, max(xs) * W
    top, bottom = (1 - max(ys)) * H, (1 - min(ys)) * H
    ml, mt, mr, mb = margin_px
    x0 = max(0, int(math.floor(left - ml)))
    y0 = max(0, int(math.floor(top - mt)))
    x1 = min(W, int(math.ceil(right + mr)))
    y1 = min(H, int(math.ceil(bottom + mb)))
    return x0, y0, x1, y1


def set_border(scene, box):
    W, H = scene.render.resolution_x, scene.render.resolution_y
    x0, y0, x1, y1 = box
    scene.render.use_border = True
    scene.render.use_crop_to_border = True
    # Blender 把边框的两头都往下取整：都往上多给一点点，取整后正好落在这几个整数像素上。
    eps = 0.01
    scene.render.border_min_x = (x0 + eps) / W
    scene.render.border_max_x = (x1 + eps) / W
    scene.render.border_min_y = (H - y1 + eps) / H
    scene.render.border_max_y = (H - y0 + eps) / H


def write_imageset_2x(name, png):
    import shutil
    d = os.path.join(S.ART, name + ".imageset")
    os.makedirs(d, exist_ok=True)
    fname = name.lower() + ".png"
    shutil.copyfile(png, os.path.join(d, fname))
    with open(os.path.join(d, "Contents.json"), "w") as f:
        f.write('{\n  "images" : [\n    { "filename" : "%s", "idiom" : "universal", "scale" : "2x" }\n  ],\n'
                '  "info" : { "author" : "xcode", "version" : 1 }\n}\n' % fname)


def swift_rect(box):
    x0, y0, x1, y1 = box
    return "CGRect(x: %.1f, y: %.1f, width: %.1f, height: %.1f)" % (x0 / 2, y0 / 2, (x1 - x0) / 2, (y1 - y0) / 2)


def design_rect(x0, y0, x1, y1):
    """Blender 坐标的矩形 → 画布上的点（CGRect 字符串）。"""
    a = to_points(x0, y1)
    b = to_points(x1, y0)
    return "CGRect(x: %.1f, y: %.1f, width: %.1f, height: %.1f)" % (a[0], a[1], b[0] - a[0], b[1] - a[1])


def write_swift(boxes, hotspots):
    lines = [
        "// 由 design/blender/booth/make_machine.py 生成，不要手改。",
        "import CoreGraphics",
        "",
        "/// 大头贴机整机正面（`BoothMachine`，720 × 960 点）上各处的位置：橱窗、铭牌、页码槽、拨杆刻字、灯泡，",
        "/// 以及会动的零件图（箭头、拨杆、开始按钮）在整机上的框。",
        "enum BoothMachineLayout {",
        "    static let size = CGSize(width: 720, height: 960)",
        "    /// 橱窗（透明，界面在里面放样张 / 摄像头画面）。",
        "    static let window = %s" % design_rect(-23.0, -13.0, 23.0, 24.0),
        "    static let windowCornerRadius: CGFloat = 26",
        "    /// 黄铜铭牌（写模板名和一句说明）。",
        "    static let nameplate = %s" % design_rect(-11.6, -19.6, 11.6, -14.4),
        "    /// 黑色页码槽。",
        "    static let dots = %s" % design_rect(-11.6, -22.0, 11.6, -21.0),
        "    /// 控制台底下写胶卷名的地方。",
        "    static let filmInfo = %s" % design_rect(-12.0, -37.0, 12.0, -35.2),
        "    /// 招牌（立体金字所在的搪瓷牌）。",
        "    static let sign = %s" % design_rect(-29.4, 29.0, 29.4, 43.4),
        "    static let startCenter = CGPoint(x: %.1f, y: %.1f)" % to_points(0.0, -29.6),
    ]
    for key, box in boxes.items():
        lines.append("    static let %s = %s" % (key[0].lower() + key[1:], swift_rect(box)))
    lines.append("    /// 拨杆两边的刻字（中心点）：点刻字拨到那一边。")
    lines.append("    static let labels: [String: CGPoint] = [")
    for name, (x, y) in hotspots["labels"].items():
        px, py = to_points(x, y)
        lines.append('        "%s": CGPoint(x: %.1f, y: %.1f),' % (name, px, py))
    lines.append("    ]")
    lines.append("    /// 拱框上一圈灯泡的中心。")
    lines.append("    static let bulbs: [CGPoint] = [")
    for x, y in hotspots["bulbs"]:
        px, py = to_points(x, y)
        lines.append("        CGPoint(x: %.1f, y: %.1f)," % (px, py))
    lines.append("    ]")
    lines.append("}")
    with open(SWIFT, "w") as f:
        f.write("\n".join(lines) + "\n")
    S.log("wrote", os.path.relpath(SWIFT, S.REPO))


def set_visible(objs, on):
    for ob in objs:
        ob.hide_render = not on


def composite(base_png, crops, out_png):
    """预览：把零件图按位置叠到整机图上。"""
    img = bpy.data.images.load(base_png, check_existing=False)
    W, H = img.size
    canvas = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, 4)
    for png, (x0, y0, x1, y1) in crops:
        part = bpy.data.images.load(png, check_existing=False)
        w, h = part.size
        px = np.array(part.pixels[:], dtype=np.float32).reshape(h, w, 4)
        # Blender 图像第 0 行在下面。
        r0, r1 = H - y1, H - y0
        region = canvas[r0:r1, x0:x1]
        a = px[..., 3:4]
        region[..., :3] = px[..., :3] * a + region[..., :3] * (1 - a)
        region[..., 3:4] = a + region[..., 3:4] * (1 - a)
        canvas[r0:r1, x0:x1] = region
    out = bpy.data.images.new("preview", W, H, alpha=True)
    out.pixels[:] = canvas.ravel()
    out.filepath_raw = out_png
    out.file_format = "PNG"
    out.save()


def main():
    preview = "--preview" in S.script_args()
    scene = S.fresh_scene()
    W, H = int(CANVAS[0] * PX_PER_CM), int(CANVAS[1] * PX_PER_CM)
    if preview:
        W, H = W // 2, H // 2
    S.setup_cycles(scene, W, H, samples=64 if preview else 320, transparent=True, exposure=0.05)
    try:
        scene.view_settings.look = "AgX - Medium High Contrast"
    except Exception:
        pass
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = CANVAS[1]
    cam_data.sensor_fit = "AUTO"
    cam_data.clip_start = 1
    cam_data.clip_end = 500
    cam = bpy.data.objects.new("cam", cam_data)
    S.link(cam, scene)
    cam.location = (0, 0, 200)
    scene.camera = cam
    S.light_rig(scene, cam, (0, 0, 0), scale=6.5, power_scale=1.0, world_strength=0.5)
    # 给镀铬和黄铜照的柔光箱：镜头看不见，只出现在反射里（上方一长条、右边一竖条、左下一小块）。
    for name, loc, size, strength in (("softbox-top", (-8.0, 75.0, 70.0), (90.0, 18.0), 6.0),
                                      ("softbox-right", (80.0, 4.0, 55.0), (16.0, 80.0), 3.5),
                                      ("softbox-left", (-80.0, -20.0, 45.0), (12.0, 40.0), 2.0)):
        bpy.ops.mesh.primitive_plane_add(size=1.0, location=loc)
        box = bpy.context.active_object
        box.name = name
        box.scale = (size[0], size[1], 1.0)
        S.look_at(box, (0.0, 0.0, 0.0))
        box.data.materials.append(S.emission_mat(name, "#FFF5E8", strength))
        box.visible_camera = False
        box.visible_shadow = False

    base, parts, wall, hotspots = build_machine(scene)
    all_parts = [o for objs in parts.values() for o in objs]
    os.makedirs(OUT, exist_ok=True)

    # 整机：零件都藏起来。
    set_visible(all_parts, False)
    base_png = os.path.join(OUT, "BoothMachineEN.png" if ENGLISH else "BoothMachine.png")
    S.render_to(scene, base_png)
    S.fade_shadow_edges(base_png, margin=0.06)
    if ENGLISH:
        # 英文版只换整机图：零件没有字，热区一样。
        if not preview:
            write_imageset_2x("BoothMachineEN", base_png)
        return

    # 零件：机身当阴影捕捉器，裁出零件那一块。
    catchers = [o for o in base if o.type in ("MESH", "FONT", "CURVE")]
    saved = {o.name: o.is_shadow_catcher for o in catchers}
    for o in catchers:
        o.is_shadow_catcher = True
    boxes, crops = {}, []
    for key, objs in parts.items():
        set_visible(all_parts, False)
        set_visible(objs, True)
        box = pixel_box(scene, cam, objs, margin_px=(12, 12, 30, 30) if preview else (24, 24, 60, 60))
        set_border(scene, box)
        png = os.path.join(OUT, "BoothMachine%s.png" % key)
        S.render_to(scene, png)
        img = bpy.data.images.load(png, check_existing=False)
        w, h = img.size
        bpy.data.images.remove(img)
        if (w, h) != (box[2] - box[0], box[3] - box[1]):
            S.log("crop size of %s is %dx%d, expected %dx%d" % (key, w, h, box[2] - box[0], box[3] - box[1]))
            box = (box[0], box[1], box[0] + w, box[1] + h)
        boxes[key] = box if not preview else tuple(v * 2 for v in box)
        crops.append((png, box))
    scene.render.use_border = False
    for o in catchers:
        o.is_shadow_catcher = saved[o.name]

    if preview:
        idle = [(p, b) for (p, b), k in zip(crops, parts.keys()) if k in ("ArrowLeft", "ArrowRight", "FormatLeft", "ColorRight", "StartLit")]
        composite(base_png, idle, os.path.join(OUT, "machine-preview.png"))
        S.log("preview at", os.path.join(OUT, "machine-preview.png"))
        return

    write_imageset_2x("BoothMachine", base_png)
    for key in parts:
        write_imageset_2x("BoothMachine" + key, os.path.join(OUT, "BoothMachine%s.png" % key))
    write_swift(boxes, hotspots)
    with open(os.path.join(OUT, "machine-hotspots.json"), "w") as f:
        json.dump(dict(boxes={k: list(v) for k, v in boxes.items()}, **{k: v for k, v in hotspots.items()}), f, indent=1, default=list)


main()
