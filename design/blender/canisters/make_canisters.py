"""Nocchi · 胶卷罐与相纸盒（胶卷柜、菜单、设置里的小图）。

- 彩色负片 / 黑白 / 夜景电影卷：35mm 胶卷罐（拉丝铝盖、黑色绒口与一截片头、印刷标签）
- 即显 / 大头贴相纸：扁平的相纸盒，最上面一张相纸露出来

标签全部原创（NOCCHI 字标、ISO 大字、英文名、色带取自胶卷色卡），不模仿任何真实品牌。

用法：
    /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup \
        -P design/blender/canisters/make_canisters.py -- [--stock cream-600] [--preview]
"""

import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import studio as S  # noqa: E402

STOCKS_JSON = os.path.join(S.REPO, "Packages", "NocchiKit", "Sources", "NocchiKit", "Resources", "FilmStocks.json")
OUT = os.path.join(HERE, "out")
SIZE = 384
INK = "#2E2924"


def family(stock):
    tags = set(stock.get("tags", []))
    if "custom" in tags:
        return "custom"
    if "booth" in tags:
        return "booth"
    if "instant" in tags:
        return "instant"
    if "bw" in tags or stock.get("tone", {}).get("monochrome"):
        return "bw"
    if "cine" in tags or "night" in tags:
        return "cine"
    return "color"


def short_name(stock):
    en = stock.get("englishName") or stock["id"]
    parts = en.split()
    if parts and parts[-1].isdigit():
        parts = parts[:-1]
    return " ".join(parts).upper()


# --------------------------------------------------------------------------- label artwork (2-D)

def label_png(stock, path):
    """35mm 罐子的标签展开图：宽 = 周长，高 = 罐身高度（毫米）。u = 0.5 是正面。"""
    fam = family(stock)
    sw = stock.get("swatch") or ["#D8CFC0", "#9A8C7A", "#3A3530"]
    w, h = 2 * math.pi * 12.5, 44.0
    if fam == "bw":
        bg, ink, bands = "#ECE8E0", "#141414", ["#141414", "#6E6A64"]
    elif fam == "cine":
        bg, ink, bands = "#24282E", "#F2E6CF", [sw[1], sw[0]]
    elif fam == "custom":
        bg, ink, bands = "#E4DDD0", INK, ["#9A8C7A", "#C9BFAE"]
    else:
        bg, ink, bands = "#EFE8DA", INK, [sw[0], sw[1]]
    fl = S.Flat(w, h, 900, bg=bg, samples=16, name="label")
    # 3/4 视角里右侧的片舌会挡住一截标签：正面的字整体往左挪一点，落在看得见的那一面正中。
    cx = w / 2 - 1.8
    # 色带绕一整圈
    fl.rect(0, 33.0, w, 4.2, bands[0])
    fl.rect(0, 30.6, w, 2.0, bands[1])
    if fam == "cine":
        fl.rect(0, 6.0, w, 1.0, "#E0553A")
    # 正面：ISO 大字、英文名、NOCCHI 字标、规格
    iso = str(stock.get("iso", 400))
    fl.text("NOCCHI", "futura-bold", 3.0, cx, 26.0, ink, align="CENTER", tracking=0.35)
    # 四位数（1600）收窄一点：罐身是圆的，太宽的字会绕到侧面、被片舌挡住。
    fl.text(iso, "futura-cxb", 13.5, cx, 11.2, ink if fam != "color" else sw[2] if S.luminance(sw[2]) < 0.25 else INK, align="CENTER", max_w=19)
    fl.text(short_name(stock), "typewriter-semibold", 3.3, cx, 6.2 if fam != "cine" else 8.3, ink, align="CENTER", max_w=40, tracking=0.08)
    count = "135-%d" % stock.get("exposures", 36) if fam != "custom" else "CUSTOM LUT"
    fl.text(count, "typewriter", 2.2, cx, 2.0, ink, align="CENTER", alpha=0.8)
    # 背面：竖排的小字（转到侧面时能看到一点）
    fl.text("NOCCHI FILM · " + iso, "typewriter", 2.2, w * 0.1, 16, ink, align="LEFT", rot=90, alpha=0.7)
    fl.text("PROCESS C-41" if fam not in ("bw",) else "B&W · D-76", "typewriter", 2.0, w * 0.9, 12, ink, align="LEFT", rot=90, alpha=0.6)
    fl.render(path)
    fl.dispose()
    return path


# --------------------------------------------------------------------------- 3-D canister

def label_cylinder(name, r, h, z0, mat, front_angle, segments=128):
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    bottom, top = [], []
    for i in range(segments + 1):
        u = i / segments
        a = front_angle + 2 * math.pi * (u - 0.5)
        bottom.append((bm.verts.new((r * math.cos(a), r * math.sin(a), z0)), u))
        top.append((bm.verts.new((r * math.cos(a), r * math.sin(a), z0 + h)), u))
    for i in range(segments):
        (b0, u0), (b1, u1) = bottom[i], bottom[i + 1]
        (t0, _), (t1, _) = top[i], top[i + 1]
        f = bm.faces.new([b0, b1, t1, t0])
        for loop, coord in zip(f.loops, ((u0, 0), (u1, 0), (u1, 1), (u0, 1))):
            loop[uv].uv = coord
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return S.mesh_object(name, bm, smooth=True, mats=(mat,))


def textured(name, path, rough=0.38):
    m = S.principled(name, "#FFFFFF", rough=rough)
    try:
        S.principled_node(m).inputs["Coat Weight"].default_value = 0.12
    except Exception:
        pass
    tex = S.image_node(m, path)
    m.node_tree.links.new(tex.outputs["Color"], S.principled_node(m).inputs["Base Color"])
    return m


def build_canister(stock, front_angle, label_path):
    objs = []
    r, h = 1.25, 4.4
    alu = S.brushed_metal("alu", "#CFD1D3", rough=0.22, aniso=0.7, radial=True)
    black = S.principled("plastic", "#151515", rough=0.45)
    felt = S.velvet("felt", "#0F0E0E") if hasattr(S, "velvet") else black
    leader = S.principled("leader", "#5A3A26", rough=0.3)
    label = textured("label-" + stock["id"], label_path)
    objs.append(label_cylinder("label", r, h, 0.0, label, front_angle))
    cap_profile = [(0, -0.34), (1.18, -0.34), (1.30, -0.3), (1.34, -0.22), (1.34, -0.02), (1.29, 0.02), (1.24, 0.06), (0, 0.06)]
    bottom = S.lathe("cap-bottom", cap_profile, segments=128, mats=(alu,))
    objs.append(bottom)
    top = S.lathe("cap-top", [(0, -0.06), (1.24, -0.06), (1.29, -0.02), (1.34, 0.02), (1.34, 0.22), (1.30, 0.3), (1.18, 0.34), (0, 0.34)], segments=128, mats=(alu,))
    top.location.z = h
    objs.append(top)
    knob = S.lathe("knob", [(0, 0), (0.46, 0), (0.46, 0.42), (0.40, 0.5), (0, 0.5)], segments=64, mats=(black,))
    knob.location.z = h + 0.32
    objs.append(knob)
    # 绒口与片头：在罐身右后侧
    lip_angle = front_angle + math.radians(62)
    lip = S.lathe("lip", [(0, 0), (0.16, 0), (0.16, h * 0.92), (0, h * 0.92)], segments=24, mats=(felt,))
    lip.location = (r * 0.98 * math.cos(lip_angle), r * 0.98 * math.sin(lip_angle), h * 0.04)
    lip.scale = (1.0, 2.2, 1.0)
    lip.rotation_euler = (0, 0, lip_angle)
    objs.append(lip)
    bm = bmesh.new()
    tangent = Vector((-math.sin(lip_angle), math.cos(lip_angle), 0))
    radial = Vector((math.cos(lip_angle), math.sin(lip_angle), 0))
    base = radial * (r + 0.05)
    pts = []
    for i in range(9):
        t = i / 8
        p = base + tangent * (t * 1.3) + radial * (0.35 * t * t)
        pts.append(p)
    lo = [bm.verts.new((p.x, p.y, h * 0.12)) for p in pts]
    hi = [bm.verts.new((p.x, p.y, h * 0.88)) for p in pts]
    for i in range(len(pts) - 1):
        bm.faces.new([lo[i], lo[i + 1], hi[i + 1], hi[i]])
    film = S.mesh_object("leader", bm, smooth=True, mats=(leader,))
    mod = film.modifiers.new("solid", "SOLIDIFY")
    mod.thickness = 0.02
    objs.append(film)
    return objs


def build_pack(stock, front_angle):
    """相纸盒：深色盒子 + 露出来的一张相纸（画面是这卷的色卡渐变）。"""
    objs = []
    fam = family(stock)
    tags = set(stock.get("tags", []))
    sw = stock.get("swatch") or ["#D8CFC0", "#9A8C7A", "#3A3530"]
    if fam == "booth":
        pw, ph, window = 2.6, 8.0, None
    elif "mini" in tags:
        pw, ph = 5.4, 8.6
    else:
        pw, ph = 8.8, 10.7
    depth = 0.9
    case = S.principled("case", "#1F1E1D", rough=0.55)
    stripe = S.principled("stripe", sw[1] if fam != "booth" else "#C4593B", rough=0.5)
    paper = S.principled("print", "#F4F0E6", rough=0.6)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= pw + 0.5
        v.co.y *= depth
        v.co.z = (v.co.z + 0.5) * (ph * 0.72)
    box = S.mesh_object("pack", bm, smooth=False, mats=(case,))
    bev = box.modifiers.new("bevel", "BEVEL")
    bev.width = 0.12
    bev.segments = 4
    objs.append(box)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= pw + 0.52
        v.co.y *= depth * 1.02
        v.co.z = ph * 0.72 * 0.18 + v.co.z * 0.5
    band = S.mesh_object("band", bm, smooth=False, mats=(stripe,))
    objs.append(band)
    # 露出来的一张：白边 + 画面
    sheet_h = ph
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= pw
        v.co.y *= 0.04
        v.co.z = (v.co.z + 0.5) * sheet_h
    sheet = S.mesh_object("sheet", bm, smooth=False, mats=(paper,))
    sheet.location = (0, -0.12, ph * 0.33)
    objs.append(sheet)
    image_mat = bpy.data.materials.new("image")
    image_mat.use_nodes = True
    nodes, links = image_mat.node_tree.nodes, image_mat.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 0.25
    tc = nodes.new("ShaderNodeTexCoord")
    grad = nodes.new("ShaderNodeTexGradient")
    mapping = nodes.new("ShaderNodeMapping")
    mapping.inputs["Rotation"].default_value = (0, math.radians(-60), 0)
    links.new(tc.outputs["Generated"], mapping.inputs["Vector"])
    links.new(mapping.outputs["Vector"], grad.inputs["Vector"])
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = S.lin(sw[0])
    ramp.color_ramp.elements[1].color = S.lin(sw[2])
    mid = ramp.color_ramp.elements.new(0.5)
    mid.color = S.lin(sw[1])
    links.new(grad.outputs["Fac"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    frames = 4 if fam == "booth" else 1
    for k in range(frames):
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        if fam == "booth":
            fw, fh = pw * 0.84, (sheet_h * 0.9) / 4 * 0.86
            z0 = sheet_h - (k + 1) * (sheet_h * 0.9) / 4
        else:
            fw = pw * 0.88
            fh = fw * (62 / 46 if "mini" in tags else 1.0)
            z0 = sheet_h - fh - pw * 0.06
        for v in bm.verts:
            v.co.x *= fw
            v.co.y *= 0.01
            v.co.z = z0 + (v.co.z + 0.5) * fh
        img = S.mesh_object("frame", bm, smooth=False, mats=(image_mat,))
        img.location = (0, -0.145, ph * 0.33)
        objs.append(img)
    # 盒子正面的印刷标签（贴一张平面）
    face_w, face_h = pw + 0.5 - 0.2, ph * 0.72 - 0.2
    label_path = pack_label_png(stock, face_w, face_h, os.path.join(OUT, "pack-label-%s.png" % stock["id"]))
    lm = textured("pack-label-" + stock["id"], label_path, rough=0.5)
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    y = -depth / 2 - 0.006
    vs = [bm.verts.new(c) for c in ((-face_w / 2, y, 0.1), (face_w / 2, y, 0.1), (face_w / 2, y, 0.1 + face_h), (-face_w / 2, y, 0.1 + face_h))]
    f = bm.faces.new(vs)
    for loop, coord in zip(f.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
        loop[uvl].uv = coord
    objs.append(S.mesh_object("pack-label", bm, smooth=False, mats=(lm,)))
    root = bpy.data.objects.new("pack-root", None)
    S.link(root)
    for o in objs:
        o.parent = root
    # 正面朝镜头再转 28°，看得见侧面
    root.rotation_euler = (0, 0, front_angle + math.pi / 2 + math.radians(28))
    return objs


def pack_label_png(stock, w_cm, h_cm, path):
    """相纸盒正面：炭黑底、一道色带、NOCCHI 字标、ISO 与名字（象牙白）。"""
    fam = family(stock)
    sw = stock.get("swatch") or ["#D8CFC0", "#9A8C7A", "#3A3530"]
    w, h = w_cm * 10, h_cm * 10
    fl = S.Flat(w, h, 700, bg="#1F1E1D", samples=16, name="pack")
    ivory = "#EDE6D8"
    band = sw[1] if fam != "booth" else "#C4593B"
    fl.rect(0, h * 0.30, w, h * 0.09, band)
    fl.rect(0, h * 0.26, w, h * 0.025, sw[0] if fam != "booth" else "#D9A441")
    fl.text("NOCCHI", "futura-bold", min(w * 0.11, 7.0), w / 2, h * 0.78, ivory, align="CENTER", tracking=0.3, max_w=w * 0.8)
    kind = "PHOTO BOOTH" if fam == "booth" else "INSTANT FILM"
    fl.text(kind, "typewriter", min(w * 0.07, 3.6), w / 2, h * 0.66, ivory, align="CENTER", tracking=0.12, max_w=w * 0.86, alpha=0.85)
    fl.text(str(stock.get("iso", 400)), "futura-cxb", min(w * 0.3, 18.0), w / 2, h * 0.43, ivory, align="CENTER", max_w=w * 0.7)
    fl.text(short_name(stock), "typewriter-semibold", min(w * 0.08, 4.2), w / 2, h * 0.1, ivory, align="CENTER", max_w=w * 0.86)
    fl.render(path)
    fl.dispose()
    return path


def render_stock(stock, preview=False):
    scene = S.fresh_scene()
    S.setup_cycles(scene, SIZE, SIZE, samples=48 if preview else 128, transparent=True, exposure=0.15)
    target = (0, 0, 2.4)
    cam = S.camera(scene, target, azimuth=-22.0, elevation=16.0, distance=40.0, lens=85.0)
    cam_dir = Vector((cam.location.x, cam.location.y, 0)).normalized()
    front_angle = math.atan2(cam_dir.y, cam_dir.x)
    fam = family(stock)
    os.makedirs(OUT, exist_ok=True)
    if fam in ("instant", "booth"):
        objs = build_pack(stock, front_angle)
    else:
        label = label_png(stock, os.path.join(OUT, "label-%s.png" % stock["id"]))
        objs = build_canister(stock, front_angle, label)
    S.light_rig(scene, cam, target, scale=0.42, power_scale=0.9, world_strength=0.35)
    S.shadow_catcher(scene, size=200.0)
    meshes = [o for o in scene.objects if o.type == "MESH" and not o.is_shadow_catcher]
    S.fit_camera(scene, cam, meshes, pad=0.1)
    name = "FilmCanister-" + stock["id"]
    path = os.path.join(OUT, name + ".png")
    S.render_to(scene, path)
    if not preview:
        S.write_imageset(name, path, filename=name.lower() + ".png")
    return path


def main():
    args = S.script_args()
    preview = "--preview" in args
    stocks = json.load(open(STOCKS_JSON))["stocks"]
    stocks.append({"id": "custom", "englishName": "Custom LUT", "iso": 200, "exposures": 24,
                   "swatch": ["#D8CFC0", "#9A8C7A", "#3A3530"], "tags": ["custom"]})
    every = list(stocks)
    if "--stock" in args:
        wanted = set(args[args.index("--stock") + 1].split(","))
        stocks = [s for s in stocks if s["id"] in wanted]
    for stock in stocks:
        render_stock(stock, preview)
    # 联系表总是排全部胶卷：只重渲几卷时，其余的用 out/ 里上次的渲染图。
    sheet = [(os.path.join(OUT, "FilmCanister-%s.png" % s["id"]), s["id"]) for s in every]
    S.contact_sheet(sheet, os.path.join(HERE, "contact.png"), cols=7, cell=(260, 300), bgs=("#1E1E1E",))


if __name__ == "__main__":
    main()
