"""Nocchi · 卡片盒（2.5D 分层渲染）。

照参考图（浅色山毛榉索引卡盒、指接榫、前板椭圆拉手孔里一支黄色圆珠笔、塞满彩色索引卡和 A–Z 分隔卡、
最前面一张翘起折角的横线白卡）程序化建模；分隔卡标签留白，上面的字（首字母或年 / 月 / 日）由 App 按 hotspots.json 里标签面的四个角叠上去，Cycles 渲染两层：

- CardBoxBase：整盒 + 卡片 + 分隔卡 + 笔 + 地面柔和阴影（透明背景）
- CardBoxFront：只有前板和面向镜头的长侧板（同机位），App 里让照片从盒里升起时被它挡住

并把分隔卡标签、盒口、盒子外框投影成归一化坐标写进 hotspots.json。

用法：
    /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup \
        -P design/blender/cardbox/make_cardbox.py -- [--preview] [--samples 256]
"""

import json
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector
from bpy_extras.object_utils import world_to_camera_view

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "canisters"))
import studio as S  # noqa: E402

ARGS = S.script_args()
PREVIEW = "--preview" in ARGS
SAMPLES = int(ARGS[ARGS.index("--samples") + 1]) if "--samples" in ARGS else (64 if PREVIEW else 320)
OUT = os.path.join(HERE, "out")
# 画布比盒子大一圈：光从左上来、阴影落向右下，右边和下面要留够地方让阴影自然淡到透明（不能被画布边截成直角）。
W_PX, H_PX = (1000, 750) if PREVIEW else (2000, 1500)

# 尺寸（厘米）
BOX_W = 15.6      # 外宽（左右）
BOX_L = 26.0      # 外长（前后）
BOX_H = 8.4       # 前后板高度
SIDE_H = 8.4      # 侧板高度
WALL = 1.0
FLOOR = 0.7
ROWS = 7          # 指接榫的层数
LETTERS = [chr(c) for c in range(65, 91)] + ["#"]

rng = random.Random(20261124)


# --------------------------------------------------------------------------- materials

def wood(name, axis, tone=1.0):
    """山毛榉：沿 axis 的年轮（Rings），端面（法线平行于纹理方向）更深。"""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nodes, links = m.node_tree.nodes, m.node_tree.links
    for n in list(nodes):
        nodes.remove(n)
    out = nodes.new("ShaderNodeOutputMaterial")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Roughness"].default_value = 0.42
    try:
        bsdf.inputs["Coat Weight"].default_value = 0.18
        bsdf.inputs["Coat Roughness"].default_value = 0.25
    except KeyError:
        pass
    tc = nodes.new("ShaderNodeTexCoord")
    mapping = nodes.new("ShaderNodeMapping")
    # 年轮的方向：Wave Rings 的方向参数
    wave = nodes.new("ShaderNodeTexWave")
    wave.wave_type = "RINGS"
    wave.rings_direction = axis
    wave.inputs["Scale"].default_value = 1.35
    wave.inputs["Distortion"].default_value = 1.6
    wave.inputs["Detail"].default_value = 2.0
    wave.inputs["Detail Scale"].default_value = 0.7
    try:
        wave.inputs["Detail Roughness"].default_value = 0.62
    except KeyError:
        pass
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 26.0
    noise.inputs["Detail"].default_value = 8.0
    # 拉长的细纤维：在纹理方向上压扁噪声
    scale = {"X": (0.06, 1.0, 1.0), "Y": (1.0, 0.06, 1.0), "Z": (1.0, 1.0, 0.06)}[axis]
    fiber_map = nodes.new("ShaderNodeMapping")
    fiber_map.inputs["Scale"].default_value = scale
    links.new(tc.outputs["Object"], mapping.inputs["Vector"])
    links.new(mapping.outputs["Vector"], wave.inputs["Vector"])
    links.new(tc.outputs["Object"], fiber_map.inputs["Vector"])
    links.new(fiber_map.outputs["Vector"], noise.inputs["Vector"])
    ramp = nodes.new("ShaderNodeValToRGB")
    cr = ramp.color_ramp
    cr.elements[0].position = 0.0
    cr.elements[0].color = S.lin(S.mix_hex("#EBA862", "#000000", 1 - tone))
    cr.elements[1].position = 1.0
    cr.elements[1].color = S.lin(S.mix_hex("#C57835", "#000000", 1 - tone))
    e = cr.elements.new(0.55)
    e.color = S.lin(S.mix_hex("#DA9148", "#000000", 1 - tone))
    mix_val = nodes.new("ShaderNodeMath")
    mix_val.operation = "MULTIPLY_ADD"
    mix_val.inputs[1].default_value = 0.8
    links.new(wave.outputs["Fac"], mix_val.inputs[0])
    fib = nodes.new("ShaderNodeMath")
    fib.operation = "MULTIPLY"
    fib.inputs[1].default_value = 0.22
    links.new(noise.outputs["Fac"], fib.inputs[0])
    links.new(fib.outputs[0], mix_val.inputs[2])
    links.new(mix_val.outputs[0], ramp.inputs["Fac"])
    # 端面变深
    geo = nodes.new("ShaderNodeNewGeometry")
    sep = nodes.new("ShaderNodeSeparateXYZ")
    links.new(geo.outputs["Normal"], sep.inputs[0])
    comp = {"X": "X", "Y": "Y", "Z": "Z"}[axis]
    absn = nodes.new("ShaderNodeMath")
    absn.operation = "ABSOLUTE"
    links.new(sep.outputs[comp], absn.inputs[0])
    endmix = nodes.new("ShaderNodeMix")
    endmix.data_type = "RGBA"
    endmix.blend_type = "MULTIPLY"
    links.new(absn.outputs[0], endmix.inputs["Factor"])
    links.new(ramp.outputs["Color"], endmix.inputs["A"])
    endmix.inputs["B"].default_value = S.lin("#B88A62")
    links.new(endmix.outputs["Result"], bsdf.inputs["Base Color"])
    bump = nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.06
    bump.inputs["Distance"].default_value = 0.01
    links.new(noise.outputs["Fac"], bump.inputs["Height"])
    links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    links.new(bsdf.outputs[0], out.inputs["Surface"])
    return m


def paper_mat(name, hex_color, rough=0.86):
    m = S.principled(name, hex_color, rough=rough)
    S.add_fine_bump(m, scale=180.0, strength=0.02, distance=0.002)
    return m


def ruled_mat():
    """白色横线卡：浅蓝横线 + 一条红色页眉线。"""
    m = bpy.data.materials.new("ruled")
    m.use_nodes = True
    nodes, links = m.node_tree.nodes, m.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 0.8
    tc = nodes.new("ShaderNodeTexCoord")
    sep = nodes.new("ShaderNodeSeparateXYZ")
    links.new(tc.outputs["UV"], sep.inputs[0])
    lines = nodes.new("ShaderNodeMath")
    lines.operation = "MULTIPLY"
    lines.inputs[1].default_value = 11.0
    links.new(sep.outputs["Y"], lines.inputs[0])
    frac = nodes.new("ShaderNodeMath")
    frac.operation = "FRACT"
    links.new(lines.outputs[0], frac.inputs[0])
    thin = nodes.new("ShaderNodeMath")
    thin.operation = "LESS_THAN"
    thin.inputs[1].default_value = 0.07
    links.new(frac.outputs[0], thin.inputs[0])
    # 顶上一段不画横线（页眉），换成一条红线
    top = nodes.new("ShaderNodeMath")
    top.operation = "LESS_THAN"
    top.inputs[1].default_value = 0.8
    links.new(sep.outputs["Y"], top.inputs[0])
    both = nodes.new("ShaderNodeMath")
    both.operation = "MULTIPLY"
    links.new(thin.outputs[0], both.inputs[0])
    links.new(top.outputs[0], both.inputs[1])
    mix = nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    links.new(both.outputs[0], mix.inputs["Factor"])
    mix.inputs["A"].default_value = S.lin("#FBFAF6")
    mix.inputs["B"].default_value = S.lin("#8EB4D6")
    red_band = nodes.new("ShaderNodeMath")
    red_band.operation = "COMPARE"
    red_band.inputs[1].default_value = 0.83
    red_band.inputs[2].default_value = 0.006
    links.new(sep.outputs["Y"], red_band.inputs[0])
    mix2 = nodes.new("ShaderNodeMix")
    mix2.data_type = "RGBA"
    links.new(red_band.outputs[0], mix2.inputs["Factor"])
    links.new(mix.outputs["Result"], mix2.inputs["A"])
    mix2.inputs["B"].default_value = S.lin("#E59A9A")
    links.new(mix2.outputs["Result"], bsdf.inputs["Base Color"])
    return m


# --------------------------------------------------------------------------- geometry

def cuboid(name, x0, x1, y0, y1, z0, z1, mat, bevel=0.06, parent=None):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x = x0 + (v.co.x + 0.5) * (x1 - x0)
        v.co.y = y0 + (v.co.y + 0.5) * (y1 - y0)
        v.co.z = z0 + (v.co.z + 0.5) * (z1 - z0)
    ob = S.mesh_object(name, bm, smooth=False, mats=(mat,))
    if bevel > 0:
        mod = ob.modifiers.new("bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 3
        mod.limit_method = "ANGLE"
        mod.harden_normals = False
    if parent:
        ob.parent = parent
    return ob


def build_box(root):
    """前板在 -Y，后板在 +Y，左侧板在 -X。指接榫：偶数层归前后板，奇数层归侧板。"""
    wx = wood("wood-x", "X")            # 前后板：纹理沿 X
    wy = wood("wood-y", "Y", tone=0.97)  # 侧板：纹理沿 Y
    floor = wood("wood-floor", "Y", tone=0.9)
    hw, hl = BOX_W / 2, BOX_L / 2
    parts = {"front": [], "back": [], "left": [], "right": [], "floor": []}
    # 中段（不含四角）
    parts["front"].append(cuboid("front", -hw + WALL, hw - WALL, -hl, -hl + WALL, 0, BOX_H, wx, parent=root))
    parts["back"].append(cuboid("back", -hw + WALL, hw - WALL, hl - WALL, hl, 0, BOX_H, wx, parent=root))
    parts["left"].append(cuboid("left", -hw, -hw + WALL, -hl + WALL, hl - WALL, 0, SIDE_H, wy, parent=root))
    parts["right"].append(cuboid("right", hw - WALL, hw, -hl + WALL, hl - WALL, 0, SIDE_H, wy, parent=root))
    parts["floor"].append(cuboid("box-floor", -hw + WALL, hw - WALL, -hl + WALL, hl - WALL, 0, FLOOR, floor, bevel=0.02, parent=root))
    # 四角的指接榫
    row_h = BOX_H / ROWS
    for sx in (-1, 1):
        for sy in (-1, 1):
            x0, x1 = (-hw, -hw + WALL) if sx < 0 else (hw - WALL, hw)
            y0, y1 = (-hl, -hl + WALL) if sy < 0 else (hl - WALL, hl)
            for k in range(ROWS):
                end_panel = k % 2 == 0
                mat = wx if end_panel else wy
                ob = cuboid("finger", x0, x1, y0, y1, k * row_h, (k + 1) * row_h, mat, bevel=0.035, parent=root)
                key = ("front" if sy < 0 else "back") if end_panel else ("left" if sx < 0 else "right")
                parts[key].append(ob)
    # 前板的椭圆拉手孔
    cutter_me = bpy.data.meshes.new("cutter")
    bm = bmesh.new()
    seg = 48
    w, h = 6.2, 1.9
    r = h / 2
    pts = []
    for i in range(seg + 1):
        a = -math.pi / 2 + math.pi * i / seg
        pts.append((w / 2 - r + r * math.cos(a), r * math.sin(a)))
    for i in range(seg + 1):
        a = math.pi / 2 + math.pi * i / seg
        pts.append((-w / 2 + r + r * math.cos(a), r * math.sin(a)))
    top = [bm.verts.new((x, -hl - 1, BOX_H * 0.5 + z)) for x, z in pts]
    bot = [bm.verts.new((x, -hl + WALL + 1, BOX_H * 0.5 + z)) for x, z in pts]
    bm.faces.new(top)
    bm.faces.new(list(reversed(bot)))
    n = len(pts)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new([top[i], top[j], bot[j], bot[i]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(cutter_me)
    bm.free()
    cutter = bpy.data.objects.new("cutter", cutter_me)
    S.link(cutter)
    cutter.hide_render = True
    cutter.hide_viewport = True
    front = parts["front"][0]
    boolean = front.modifiers.new("hole", "BOOLEAN")
    boolean.operation = "DIFFERENCE"
    boolean.object = cutter
    try:
        boolean.solver = "EXACT"
    except Exception:
        pass
    return parts


def build_pen(root):
    """一支黄色圆珠笔，横躺在前板后面，从拉手孔里露出来。"""
    yellow = S.principled("pen-yellow", "#F1C232", rough=0.32)
    metal = S.brushed_metal("pen-metal", "#D8D8D4", rough=0.18, aniso=0.6, radial=False)
    black = S.principled("pen-black", "#1C1C1C", rough=0.5)
    hl = BOX_L / 2
    pen = bpy.data.objects.new("pen", None)
    S.link(pen)
    pen.parent = root
    # 笔比盒子宽度短：两端藏在木头里，拉手孔里看得见黄色笔杆和银色笔帽。
    pen.location = (-1.0, -hl + WALL * 0.45, BOX_H * 0.5 - 0.12)
    pen.rotation_euler = (0, 0, math.radians(-1.2))
    pen.scale = (0.8, 0.8, 0.8)
    objs = []
    barrel = S.lathe("pen-barrel", [(0, -5.6), (0.48, -5.6), (0.5, -5.4), (0.5, 4.2), (0.47, 4.4), (0, 4.4)], segments=6, mats=(yellow,), sharp_angle=40)
    cap = S.lathe("pen-cap", [(0, 4.3), (0.52, 4.3), (0.52, 6.6), (0.44, 6.9), (0, 6.95)], segments=64, mats=(metal,))
    tip = S.lathe("pen-tip", [(0, -7.1), (0.08, -7.05), (0.42, -5.75), (0.48, -5.6), (0, -5.6)], segments=48, mats=(metal,))
    for ob in (barrel, cap, tip):
        ob.rotation_euler = (0, math.radians(90), 0)
        ob.parent = pen
        objs.append(ob)
    objs.append(cuboid("pen-clip", 4.5, 6.6, -0.07, 0.07, 0.5, 0.6, metal, bevel=0.03, parent=pen))
    ring = S.lathe("pen-ring", [(0, -0.1), (0.53, -0.1), (0.53, 0.1), (0, 0.1)], segments=48, mats=(black,))
    ring.rotation_euler = (0, math.radians(90), 0)
    ring.location = (4.25, 0, 0)
    ring.parent = pen
    objs.append(ring)
    return objs


CARD_COLORS = ["#F4EFE3", "#FBF8F0", "#CFE3D4", "#D8E6F0", "#F2D7CF", "#F2E3B3", "#E8D2B8", "#DCE7C8", "#F7E6D4", "#E3DDF0"]


def build_cards(root):
    """一叠彩色索引卡 + 27 张 A–Z 分隔卡 + 最前面一张折角的横线白卡。"""
    hl = BOX_L / 2
    inner_w = BOX_W - 2 * WALL - 0.25
    card_h = 9.4
    lean = math.radians(-9)
    mats = {c: paper_mat("card-" + c, c) for c in CARD_COLORS}
    divider_mat = paper_mat("divider", "#F6F2E8", rough=0.75)
    tab_mat = paper_mat("tab", "#FCFAF5", rough=0.7)
    sheets = []
    y = hl - WALL - 0.6
    y_front_limit = -hl + WALL + 2.6
    letter_index = 0
    color = rng.choice(CARD_COLORS)
    run = 0
    total = 0
    # 从后往前排；每隔 3 张左右插一张分隔卡
    while y > y_front_limit:
        if run <= 0:
            color = rng.choice(CARD_COLORS)
            run = rng.randint(2, 6)
        is_divider = letter_index < len(LETTERS) and total % 3 == 2 and y < hl - WALL - 1.0
        jitter = rng.uniform(-0.12, 0.22)
        tilt = lean + math.radians(rng.uniform(-1.6, 1.6))
        if is_divider:
            letter = LETTERS[len(LETTERS) - 1 - letter_index]
            sheets.append(("divider", y, tilt, jitter, letter))
            letter_index += 1
        else:
            sheets.append(("card", y, tilt, jitter, color))
            run -= 1
        total += 1
        y -= rng.uniform(0.17, 0.24)
    objs = {"cards": [], "dividers": [], "tabs": {}}
    # 标签是空白的：上面印的字（A–Z，或者按年 / 月 / 日归档时的「2026」「11月」「11/24」）由 App 按透视叠上去，
    # 所以标签做得比只印一个字母时宽一点，放得下五个字符（高度不变：再高，后一张的标签下沿就会被前一张挡住）。
    tab_w = 2.8
    tab_h = 1.25
    positions = 5
    for kind, y, tilt, jitter, info in sheets:
        h = card_h + jitter
        thickness = 0.025
        if kind == "card":
            ob = cuboid("card", -inner_w / 2, inner_w / 2, -thickness / 2, thickness / 2, 0, h, mats[info], bevel=0.0, parent=None)
            objs["cards"].append(ob)
        else:
            ob = cuboid("divider", -inner_w / 2, inner_w / 2, -thickness / 2, thickness / 2, 0, h, divider_mat, bevel=0.0)
            index = LETTERS.index(info)
            slot = index % positions
            tx = -inner_w / 2 + 0.5 + slot * (inner_w - 1.0 - tab_w) / (positions - 1)
            tab = cuboid("tab", tx, tx + tab_w, -0.016, 0.016, h - 0.05, h + tab_h, tab_mat, bevel=0.0)
            tab.parent = ob
            objs["dividers"].append(ob)
            # 标签正面（-Y 一侧）露在分隔卡上沿以上的部分：左上、右上、右下、左下（分隔卡自己的坐标）
            face = [(tx, -0.017, h + tab_h), (tx + tab_w, -0.017, h + tab_h), (tx + tab_w, -0.017, h), (tx, -0.017, h)]
            objs["tabs"][info] = (tab, face)
        ob.location = (0, y, FLOOR - 0.02)
        ob.rotation_euler = (tilt, 0, 0)
        ob.parent = root
    # 最前面一张横线白卡：更高、斜得更厉害、右上角折了一角
    ruled = ruled_mat()
    fw, fh = inner_w - 0.2, 12.2
    fold = 1.35
    bm = bmesh.new()
    corners = [(-fw / 2, 0), (fw / 2, 0), (fw / 2, fh - fold), (fw / 2 - fold, fh), (-fw / 2, fh)]
    verts = [bm.verts.new((x, 0, z)) for x, z in corners]
    face = bm.faces.new(verts)
    uv = bm.loops.layers.uv.new("UVMap")
    for loop in face.loops:
        loop[uv].uv = ((loop.vert.co.x + fw / 2) / fw, loop.vert.co.z / fh)
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.03)
    front_card = S.mesh_object("front-card", bm, smooth=False, mats=(ruled,))
    # 折角：把切掉的三角形沿折线翻到正面
    p1 = Vector((fw / 2, 0, fh - fold))
    p2 = Vector((fw / 2 - fold, 0, fh))
    corner = Vector((fw / 2, 0, fh))
    mid = (p1 + p2) / 2
    reflected = mid + (mid - corner) * 1.0
    bm = bmesh.new()
    flap_pts = [p1 + Vector((0, -0.05, 0)), p2 + Vector((0, -0.05, 0)), reflected + Vector((0, -0.12, 0))]
    fv = [bm.verts.new(p) for p in flap_pts]
    bm.faces.new(fv)
    flap = S.mesh_object("flap", bm, smooth=False, mats=(paper_mat("flap", "#F1EFE8", rough=0.8),))
    flap.parent = front_card
    front_card.location = (0.1, -hl + WALL + 1.9, FLOOR - 0.02)
    front_card.rotation_euler = (math.radians(-13), 0, math.radians(2.0))
    front_card.parent = root
    objs["front_card"] = front_card
    return objs


# --------------------------------------------------------------------------- scene

def main():
    scene = S.fresh_scene()
    S.setup_cycles(scene, W_PX, H_PX, samples=SAMPLES, transparent=True, view="AgX", look="None", exposure=0.2)
    root = bpy.data.objects.new("root", None)
    S.link(root)
    parts = build_box(root)
    pen = build_pen(root)
    cards = build_cards(root)
    root.rotation_euler = (0, 0, math.radians(0))
    bpy.context.view_layer.update()

    target = (0, 0, BOX_H * 0.45)
    cam = S.camera(scene, target, azimuth=-52.0, elevation=34.0, distance=95.0, lens=105.0)
    S.light_rig(scene, cam, target, scale=2.2, power_scale=1.0, world_strength=0.32)
    floor = S.shadow_catcher(scene, size=600.0)

    every = [o for o in scene.objects if o.type in ("MESH", "FONT") and not o.is_shadow_catcher and o.name != "cutter"]
    S.fit_camera(scene, cam, every, pad=0.14, anchor=(0.42, 0.44))
    bpy.context.view_layer.update()

    os.makedirs(OUT, exist_ok=True)
    base_png = os.path.join(OUT, "card-box-base.png")
    S.render_to(scene, base_png)
    S.fade_shadow_edges(base_png, margin=0.13)

    # 前板层：只留下前板（含拉手孔）和左侧板（面向镜头的长侧板）以及它们的指接榫
    keep = set()
    for key in ("front", "left"):
        for ob in parts[key]:
            keep.add(ob.name)
    hidden = []
    for ob in scene.objects:
        if ob.type in ("MESH", "FONT") and ob.name not in keep:
            if not ob.hide_render:
                ob.hide_render = True
                hidden.append(ob)
    front_png = os.path.join(OUT, "card-box-front.png")
    S.render_to(scene, front_png)
    for ob in hidden:
        ob.hide_render = False

    # 热区：分隔卡标签中心（归一化，左上原点）与是否被挡住
    deps = bpy.context.evaluated_depsgraph_get()
    tabs = []
    for letter, (tab, face_local) in cards["tabs"].items():
        mw = tab.matrix_world
        bb = [mw @ Vector(c) for c in tab.bound_box]
        center = sum(bb, Vector()) / 8
        p = world_to_camera_view(scene, cam, center)
        # 标签正面在画面里的四个角（左上、右上、右下、左下）：App 按它把标签上的字斜切到标签面上
        face = []
        for corner in face_local:
            q = world_to_camera_view(scene, cam, mw @ Vector(corner))
            face.append([round(q.x, 5), round(1 - q.y, 5)])
        direction = (center - cam.location).normalized()
        hit, loc, normal, index, obj, matrix = scene.ray_cast(deps, cam.location, direction)
        occluded = bool(hit and obj is not None and obj.name != tab.name and (loc - cam.location).length < (center - cam.location).length - 0.05)
        tabs.append({"letter": letter, "slot": LETTERS.index(letter), "center": [round(p.x, 5), round(1 - p.y, 5)], "face": face, "occluded": occluded})
    tabs.sort(key=lambda t: t["slot"])

    hw, hl = BOX_W / 2, BOX_L / 2
    mouth3d = [Vector((-hw + WALL, -hl + WALL, BOX_H)), Vector((hw - WALL, -hl + WALL, BOX_H)),
               Vector((hw - WALL, hl - WALL, BOX_H)), Vector((-hw + WALL, hl - WALL, BOX_H))]
    mouth = []
    for v in mouth3d:
        p = world_to_camera_view(scene, cam, root.matrix_world @ v)
        mouth.append([round(p.x, 5), round(1 - p.y, 5)])
    box_objs = [o for key in parts for o in parts[key]]
    x0, x1, y0, y1 = S.projected_bbox(scene, cam, box_objs)
    data = {
        "canvas": [W_PX, H_PX],
        "tabs": tabs,
        "mouth": mouth,
        "boxBounds": [round(x0, 5), round(1 - y1, 5), round(x1 - x0, 5), round(y1 - y0, 5)],
    }
    with open(os.path.join(HERE, "hotspots.json"), "w") as f:
        json.dump(data, f, indent=2)
    S.log("hotspots:", len(tabs), "tabs,", sum(1 for t in tabs if not t["occluded"]), "visible")

    if not PREVIEW:
        S.write_imageset("CardBoxBase", base_png)
        S.write_imageset("CardBoxFront", front_png)


if __name__ == "__main__":
    main()
