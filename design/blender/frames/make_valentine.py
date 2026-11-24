"""Nocchi · 情人节相框（Blender 建模）。

给 `booth-heart` 模板渲染两层位图（四格条 52×160 mm、四宫格 102×152 mm，20 px/mm，和成片同一个分辨率）：

  valentine-<strip|grid>-base.jpg     照片下面：雾玫瑰色卡纸（细纤维、压印的小心形暗纹），四周一圈模切的奶油色纸蕾丝
                                      （真的镂空：扇贝边、小孔、镂空小心），四角各一枚蕾丝圆花；投影落在卡纸上。
  valentine-<strip|grid>-overlay.png  照片上面：每个心形窗口一圈纸蕾丝心环（内缘一道烫金线，压住照片边缘 0.55 mm），
                                      心口一只深红缎带蝴蝶结，窗口下角的烫金小心，题字上方一道烫金花线；
                                      阴影（落在照片和卡纸上）由当阴影捕捉器的卡纸带出来，其余透明。

心形窗口和 `RetroPrint.heart(in: rect.insetBy(dx: w * 0.03, dy: h * 0.05))` 是同一组贝塞尔控制点，几何和
`PaperLayout.boothStrip / .boothGrid` 一致（毫米，左上原点、y 向下；Blender 里 1 单位 = 1 mm，y 向上）。
光从屏幕左上方来（DESIGN.md §0），Standard 色彩变换：卡纸平面渲出来就是模板的纸色 #F2D7D0。

用法：
    /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P design/blender/frames/make_valentine.py -- [strip|grid] [--preview]

  --preview  只出一张合成预览（卡纸 + 蕾丝 + 心环 + 蝴蝶结 + 灰蓝色的「照片」），半分辨率，写到 out/。
结果写到 Packages/NocchiKit/Sources/NocchiKit/Resources/Frames/。
"""

import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "canisters"))
import studio as S  # noqa: E402

OUT = os.path.join(HERE, "out")
FRAMES = os.path.join(S.REPO, "Packages", "NocchiKit", "Sources", "NocchiKit", "Resources", "Frames")
PX_PER_MM = 20

LAYOUTS = {
    "strip": dict(size=(52.0, 160.0), windows=[(4, 4, 44, 33), (4, 40, 44, 33), (4, 76, 44, 33), (4, 112, 44, 33)],
                  caption=(4, 147, 44, 11)),
    "grid": dict(size=(102.0, 152.0), windows=[(4, 5, 45, 60), (53, 5, 45, 60), (4, 69, 45, 60), (53, 69, 45, 60)],
                 caption=(5, 133, 92, 15)),
}

CARD = "#F2D7D0"
LACE = "#FBF3E7"
SATIN = "#A3182B"
GOLD = "#E0B465"

Z_LACE_BORDER = 0.12
Z_MEDALLION = 0.2
Z_RING = 0.16


# --------------------------------------------------------------------------- 2-D geometry

def cubic(p0, c1, c2, p1, t):
    u = 1 - t
    return (u * u * u * p0[0] + 3 * u * u * t * c1[0] + 3 * u * t * t * c2[0] + t * t * t * p1[0],
            u * u * u * p0[1] + 3 * u * u * t * c1[1] + 3 * u * t * t * c2[1] + t * t * t * p1[1])


def heart_path(rect):
    """RetroPrint.heart(in: rect.insetBy(dx: w*0.03, dy: h*0.05))，毫米、y 向下；返回 4 段三次贝塞尔。"""
    x0, y0, w0, h0 = rect
    x, y, w, h = x0 + w0 * 0.03, y0 + h0 * 0.05, w0 * 0.94, h0 * 0.90

    def P(fx, fy):
        return (x + w * fx, y + h * fy)

    return [
        (P(0.5, 0.98), P(0.32, 0.80), P(0.02, 0.62), P(0.02, 0.36)),
        (P(0.02, 0.36), P(0.02, 0.06), P(0.40, -0.02), P(0.5, 0.16)),
        (P(0.5, 0.16), P(0.60, -0.02), P(0.98, 0.06), P(0.98, 0.36)),
        (P(0.98, 0.36), P(0.98, 0.62), P(0.68, 0.80), P(0.5, 0.98)),
    ], (x, y, w, h)


def sample_closed(segments, spacing=0.05):
    """按弧长等距采样闭合路径；返回点（y 向下）和总长。"""
    dense = []
    for seg in segments:
        for i in range(400):
            dense.append(cubic(*seg, i / 400.0))
    pts = np.array(dense)
    diffs = np.diff(np.vstack([pts, pts[:1]]), axis=0)
    lens = np.hypot(diffs[:, 0], diffs[:, 1])
    cum = np.concatenate([[0], np.cumsum(lens)])
    total = cum[-1]
    n = max(16, int(round(total / spacing)))
    targets = np.linspace(0, total, n, endpoint=False)
    closed = np.vstack([pts, pts[:1]])
    xs = np.interp(targets, cum, closed[:, 0])
    ys = np.interp(targets, cum, closed[:, 1])
    return np.stack([xs, ys], axis=1), total


def to_blender(pts, height):
    out = pts.copy()
    out[:, 1] = height - out[:, 1]
    return out


def outward_normals(pts):
    """闭合多边形每个点的外法线（中心差分切线，按方向判断哪边是外面）。"""
    prev = np.roll(pts, 1, axis=0)
    nxt = np.roll(pts, -1, axis=0)
    t = nxt - prev
    t /= np.linalg.norm(t, axis=1, keepdims=True) + 1e-12
    area = 0.5 * np.sum(pts[:, 0] * np.roll(pts[:, 1], -1) - np.roll(pts[:, 0], -1) * pts[:, 1])
    # 逆时针（面积为正）时外法线在切线右边。
    if area > 0:
        n = np.stack([t[:, 1], -t[:, 0]], axis=1)
    else:
        n = np.stack([-t[:, 1], t[:, 0]], axis=1)
    return n, t


# --------------------------------------------------------------------------- SDF textures

def smooth_alpha(f, px):
    """f < 0 是纸。按一个像素宽做抗锯齿。"""
    return np.clip(0.5 - f / px, 0.0, 1.0)


def heart_sdf(px, py):
    """Inigo Quilez 的心形 SDF：尖朝下在原点，宽约 1.2，高约 1.1（y 向上）。"""
    px = np.abs(px)
    a = np.sqrt((px - 0.25) ** 2 + (py - 0.75) ** 2) - math.sqrt(2.0) / 4.0
    m = 0.5 * np.maximum(px + py, 0.0)
    b = np.sqrt(np.minimum(px ** 2 + (py - 1.0) ** 2, (px - m) ** 2 + (py - m) ** 2)) * np.sign(px - py)
    return np.where(px + py > 1.0, a, b)


def ridge(f, inset=0.07, width=0.05):
    return np.exp(-((f + inset) / width) ** 2)


def to_image(name, rgba):
    """numpy (h, w, 4)，第 0 行在下面 → Blender 图像（浮点，非颜色数据）。"""
    h, w, _ = rgba.shape
    img = bpy.data.images.new(name, w, h, alpha=True, float_buffer=True)
    img.colorspace_settings.name = "Non-Color"
    img.pixels.foreach_set(rgba.astype(np.float32).ravel())
    img.update()
    return img


def lace_tile(kind, ppm=100):
    """蕾丝花样（一个周期）：返回 (alpha 图, 高度图, 周期 mm, 带宽 mm)。坐标 a 沿边、b 横穿（b = 0 是内缘 / 纸边）。"""
    if kind == "ring":
        P, B = 1.3, 2.3
    else:
        P, B = 2.2, 3.0
    w, h = int(round(P * ppm)), int(round(B * ppm))
    a = (np.arange(w) + 0.5) / ppm
    b = (np.arange(h) + 0.5) / ppm
    A, Bm = np.meshgrid(a, b)
    px = 1.0 / ppm

    def periodic_dist(qa, qb):
        da = np.abs(A - qa)
        da = np.minimum(da, P - da)
        return np.sqrt(da ** 2 + (Bm - qb) ** 2)

    if kind == "ring":
        rs = P / 2
        f = np.minimum(periodic_dist(P / 2, B - rs) - rs, Bm - (B - rs))        # 扇贝外缘
        f = np.maximum(f, 0.2 - periodic_dist(P / 2, B - rs))                     # 扇贝里的孔
        f = np.maximum(f, 0.11 - periodic_dist(0.0, 0.98))                        # 扇贝之间的小点
        height = 0.35 + 0.65 * ridge(f) * (f < 0)
        height -= 0.45 * np.exp(-((Bm - 0.78) / 0.05) ** 2)                       # 压在照片边外面的一道线
        height -= 0.25 * np.exp(-((Bm - 0.42) / 0.06) ** 2)
    else:
        rs = P / 4
        f = Bm - (B - rs)
        f = np.minimum(f, periodic_dist(P / 4, B - rs) - rs)
        f = np.minimum(f, periodic_dist(3 * P / 4, B - rs) - rs)                 # 内缘两个扇贝
        f = np.maximum(f, 0.17 - periodic_dist(P / 4, 0.92))
        f = np.maximum(f, 0.17 - periodic_dist(3 * P / 4, 0.92))                  # 一排小孔
        f = np.maximum(f, 0.11 - periodic_dist(P / 4, B - rs + 0.05))
        f = np.maximum(f, 0.11 - periodic_dist(3 * P / 4, B - rs + 0.05))         # 扇贝里的小点
        s = 0.62
        hx = (A - P / 2) / s
        hy = (Bm - 1.52) / s
        f = np.maximum(f, -heart_sdf(hx, hy) * s)                                 # 镂空小心（尖朝纸边）
        f = np.maximum(f, 0.08 - periodic_dist(P / 2 - 0.62, 1.86))
        f = np.maximum(f, 0.08 - periodic_dist(P / 2 + 0.62, 1.86))
        height = 0.35 + 0.65 * ridge(f) * (f < 0)
        height -= 0.4 * np.exp(-((Bm - 0.48) / 0.05) ** 2)                        # 纸边内的一道压线
    alpha = smooth_alpha(f, px)
    height = np.clip(height, 0, 1) * alpha
    rgba_a = np.dstack([alpha, alpha, alpha, np.ones_like(alpha)])
    rgba_h = np.dstack([height, height, height, np.ones_like(height)])
    return to_image("lace-%s-alpha" % kind, rgba_a), to_image("lace-%s-height" % kind, rgba_h), P, B


def medallion_tile(R=2.5, ppm=100):
    """四角的蕾丝圆花：12 个扇贝、一圈小孔、中间镂空一颗心。"""
    n = int(round(2 * R * ppm))
    c = (np.arange(n) + 0.5) / ppm - R
    X, Y = np.meshgrid(c, c)
    r = np.sqrt(X ** 2 + Y ** 2)
    th = np.arctan2(Y, X)
    lobes = 12
    edge = R - 0.32 + 0.32 * np.abs(np.cos(th * lobes / 2))
    f = r - edge
    ring_r = 1.72
    k = np.round(th / (2 * math.pi / lobes))
    ang = k * 2 * math.pi / lobes
    f = np.maximum(f, 0.16 - np.sqrt((X - ring_r * np.cos(ang)) ** 2 + (Y - ring_r * np.sin(ang)) ** 2))
    s = 0.95
    f = np.maximum(f, -heart_sdf(X / s, (Y + 0.5) / s) * s)
    px = 1.0 / ppm
    alpha = smooth_alpha(f, px)
    height = 0.35 + 0.65 * ridge(f) * (f < 0) - 0.45 * np.exp(-((r - 1.25) / 0.05) ** 2)
    height = np.clip(height, 0, 1) * alpha
    return (to_image("medallion-alpha", np.dstack([alpha, alpha, alpha, np.ones_like(alpha)])),
            to_image("medallion-height", np.dstack([height, height, height, np.ones_like(height)])))


def damask_tile(ppm=60):
    """卡纸上压印的小心形暗纹（错开的格子），一格 5 mm。"""
    P = 5.0
    n = int(P * ppm)
    c = (np.arange(n) + 0.5) / ppm
    X, Y = np.meshgrid(c, c)
    h = np.zeros_like(X)
    for (cx, cy) in [(P / 4, P / 4), (3 * P / 4, 3 * P / 4)]:
        s = 0.55
        d = heart_sdf((X - cx) / s, (Y - cy + 0.3) / s) * s
        h += np.exp(-(np.maximum(d, 0) / 0.05) ** 2) * (d > -0.08) * 0.6
        h += 0.4 * (d < 0)
    for (cx, cy) in [(3 * P / 4, P / 4), (P / 4, 3 * P / 4)]:
        h += 0.8 * np.exp(-(((X - cx) ** 2 + (Y - cy) ** 2) / 0.06 ** 2))
    h = np.clip(h, 0, 1)
    return to_image("damask-height", np.dstack([h, h, h, np.ones_like(h)]))


# --------------------------------------------------------------------------- materials

def paper_material(name, color, alpha_img=None, height_img=None, bump=0.5, distance=0.06, uv_node=True, rough=0.82):
    mat = S.principled(name, color, rough=rough)
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    p = S.principled_node(mat)
    try:
        p.inputs["Sheen Weight"].default_value = 0.12
    except KeyError:
        pass
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 3.0
    noise.inputs["Detail"].default_value = 8.0
    mix = nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.inputs["Factor"].default_value = 0.035
    mix.inputs[6].default_value = S.lin(color)
    mix.inputs[7].default_value = S.lin(S.mix_hex(color, "#8A5A52", 0.6))
    links.new(noise.outputs["Fac"], mix.inputs["Factor"])
    # 纤维感很淡：把噪声压到 ±3%。
    scale = nodes.new("ShaderNodeMath")
    scale.operation = "MULTIPLY"
    scale.inputs[1].default_value = 0.07
    links.new(noise.outputs["Fac"], scale.inputs[0])
    links.new(scale.outputs[0], mix.inputs["Factor"])
    links.new(mix.outputs[2], p.inputs["Base Color"])
    fiber = nodes.new("ShaderNodeTexNoise")
    fiber.inputs["Scale"].default_value = 90.0
    fiber.inputs["Detail"].default_value = 4.0
    bump_fiber = nodes.new("ShaderNodeBump")
    bump_fiber.inputs["Strength"].default_value = 0.08
    bump_fiber.inputs["Distance"].default_value = 0.01
    links.new(fiber.outputs["Fac"], bump_fiber.inputs["Height"])
    normal_out = bump_fiber.outputs["Normal"]
    if alpha_img is not None or height_img is not None:
        uv = nodes.new("ShaderNodeUVMap")
        if alpha_img is not None:
            ta = S.image_node(mat, alpha_img, colorspace="Non-Color", interpolation="Linear", extension="REPEAT")
            links.new(uv.outputs["UV"], ta.inputs["Vector"])
            links.new(ta.outputs["Color"], p.inputs["Alpha"])
        if height_img is not None:
            th = S.image_node(mat, height_img, colorspace="Non-Color", interpolation="Cubic", extension="REPEAT")
            links.new(uv.outputs["UV"], th.inputs["Vector"])
            bmp = nodes.new("ShaderNodeBump")
            bmp.inputs["Strength"].default_value = bump
            bmp.inputs["Distance"].default_value = distance
            links.new(th.outputs["Color"], bmp.inputs["Height"])
            links.new(bump_fiber.outputs["Normal"], bmp.inputs["Normal"])
            normal_out = bmp.outputs["Normal"]
    links.new(normal_out, p.inputs["Normal"])
    return mat


def gold_material():
    m = S.principled("gold-foil", GOLD, rough=0.24, metal=1.0)
    nodes, links = m.node_tree.nodes, m.node_tree.links
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 60.0
    bmp = nodes.new("ShaderNodeBump")
    bmp.inputs["Strength"].default_value = 0.12
    links.new(noise.outputs["Fac"], bmp.inputs["Height"])
    links.new(bmp.outputs["Normal"], S.principled_node(m).inputs["Normal"])
    return m


def satin_material():
    m = S.principled("satin", SATIN, rough=0.3)
    p = S.principled_node(m)
    for sock, v in (("Sheen Weight", 0.55), ("Sheen Roughness", 0.35), ("Specular IOR Level", 0.65), ("Coat Weight", 0.08)):
        try:
            p.inputs[sock].default_value = v
        except KeyError:
            pass
    return m


# --------------------------------------------------------------------------- meshes

def strip_mesh(name, centers, normals, inner, outer, period, z, mat, rows=4, cyclic=True, u_scale=None):
    """沿一条线（毫米，y 向上）的平带：横向从 inner 到 outer（沿法线），UV u = 弧长 / 周期，v 0…1。"""
    bm = bmesh.new()
    uv_layer = bm.loops.layers.uv.new("UVMap")
    n = len(centers)
    seg = np.linalg.norm(np.diff(np.vstack([centers, centers[:1]]) if cyclic else centers, axis=0), axis=1)
    s = np.concatenate([[0], np.cumsum(seg)])
    total = s[-1] if cyclic else s[-1]
    reps = max(1, int(round(total / period)))
    scale = u_scale if u_scale is not None else reps / total
    grid = []
    for i in range(n):
        row = []
        for j in range(rows + 1):
            off = inner + (outer - inner) * j / rows
            p = centers[i] + normals[i] * off
            row.append(bm.verts.new((p[0], p[1], z)))
        grid.append(row)
    count = n if cyclic else n - 1
    for i in range(count):
        i2 = (i + 1) % n
        u0 = s[i] * scale
        u1 = (s[i] + seg[i]) * scale if cyclic else s[i + 1] * scale
        for j in range(rows):
            quad = [grid[i][j], grid[i2][j], grid[i2][j + 1], grid[i][j + 1]]
            try:
                f = bm.faces.new(quad)
            except ValueError:
                continue
            uvs = [(u0, j / rows), (u1, j / rows), (u1, (j + 1) / rows), (u0, (j + 1) / rows)]
            for loop, uv in zip(f.loops, uvs):
                loop[uv_layer].uv = uv
    bm.normal_update()
    for f in bm.faces:
        if f.normal.z < 0:
            f.normal_flip()
    obj = S.mesh_object(name, bm, smooth=False, mats=(mat,))
    return obj


def rect_mesh(name, x0, y0, x1, y1, z, mat, uv_rect=None):
    bm = bmesh.new()
    uv_layer = bm.loops.layers.uv.new("UVMap")
    vs = [bm.verts.new((x0, y0, z)), bm.verts.new((x1, y0, z)), bm.verts.new((x1, y1, z)), bm.verts.new((x0, y1, z))]
    f = bm.faces.new(vs)
    u0, v0, u1, v1 = uv_rect or (0, 0, 1, 1)
    for loop, uv in zip(f.loops, [(u0, v0), (u1, v0), (u1, v1), (u0, v1)]):
        loop[uv_layer].uv = uv
    return S.mesh_object(name, bm, smooth=False, mats=(mat,))


def tube(name, pts, radius, mat, cyclic=True, z=0.0):
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = radius
    cu.bevel_resolution = 4
    cu.use_fill_caps = True
    sp = cu.splines.new("POLY")
    sp.points.add(len(pts) - 1)
    for p, q in zip(sp.points, pts):
        zz = q[2] if len(q) > 2 else z
        p.co = (q[0], q[1], zz, 1.0)
    sp.use_cyclic_u = cyclic
    ob = bpy.data.objects.new(name, cu)
    ob.data.materials.append(mat)
    S.link(ob)
    return ob


def ribbon(name, centers, widths, halfw, mat, cyclic=False, thickness=0.06, notch=0.0, subdiv=2):
    """缎带：每个采样点一个中心、一个宽度方向（单位向量）和半宽；横向 3 个顶点，末端可剪成燕尾（notch）。"""
    bm = bmesh.new()
    rows = []
    n = len(centers)
    for i in range(n):
        c, w, hw = Vector(centers[i]), Vector(widths[i]).normalized(), halfw[i]
        mid = c.copy()
        if notch and not cyclic and i == n - 1:
            t = (Vector(centers[i]) - Vector(centers[i - 1])).normalized()
            mid = c - t * notch
        rows.append([bm.verts.new(c - w * hw), bm.verts.new(mid), bm.verts.new(c + w * hw)])
    count = n if cyclic else n - 1
    for i in range(count):
        a, b = rows[i], rows[(i + 1) % n]
        for j in range(2):
            try:
                bm.faces.new([a[j], b[j], b[j + 1], a[j + 1]])
            except ValueError:
                pass
    obj = S.mesh_object(name, bm, smooth=True, mats=(mat,))
    sol = obj.modifiers.new("solidify", "SOLIDIFY")
    sol.thickness = thickness
    sol.offset = 0
    if subdiv:
        sub = obj.modifiers.new("subsurf", "SUBSURF")
        sub.levels = subdiv
        sub.render_levels = subdiv
    return obj


def bow(name, at, scale, rot, satin):
    """缎带蝴蝶结：两只耳朵（扁的环，宽面朝镜头）、两条燕尾飘带、中间的结。at 是结的中心（毫米，y 向上）。"""
    objs = []
    cx, cy = at
    ca, sa = math.cos(rot), math.sin(rot)

    def place(p):
        x, y, z = p
        x, y = x * scale, y * scale
        return (cx + x * ca - y * sa, cy + x * sa + y * ca, 0.35 + z * scale)

    def place_dir(d):
        x, y, z = d
        return (x * ca - y * sa, x * sa + y * ca, z)

    for side in (1, -1):
        tilt = math.radians(24)
        L, A = 4.4, 0.55
        centers, widths, halfw = [], [], []
        for i in range(64):
            th = 2 * math.pi * i / 64
            x = L / 2 * (1 - math.cos(th))
            z = A * math.sin(th) + 0.25
            # 耳朵往斜上方翘：绕 z 转 tilt。
            ex, ey = x * math.cos(tilt), x * math.sin(tilt)
            centers.append(place((side * ex, ey, z)))
            # 宽度方向：耳朵平面里垂直于耳朵的方向（往上翘一点）。
            wx, wy = -math.sin(tilt), math.cos(tilt)
            widths.append(place_dir((side * wx, wy, 0.15 * math.cos(th))))
            halfw.append(scale * 1.3 * (0.42 + 0.58 * math.sin(th / 2) ** 0.7))
        objs.append(ribbon("%s-ear%d" % (name, side), centers, widths, halfw, satin, cyclic=True, thickness=0.05 * scale))
    for side in (1, -1):
        centers, widths, halfw = [], [], []
        n = 24
        for i in range(n):
            t = i / (n - 1)
            x = side * (0.25 + 2.3 * t + 0.35 * math.sin(math.pi * t))
            y = -(0.35 + 4.4 * t)
            z = 0.18 - 0.12 * t
            centers.append(place((x, y, z)))
            tx, ty = side * (2.3 + 0.35 * math.pi * math.cos(math.pi * t)), -4.4
            tl = math.hypot(tx, ty)
            nx, ny = -ty / tl, tx / tl
            twist = 0.55 * math.sin(math.pi * t)
            widths.append(place_dir((nx * math.cos(twist), ny * math.cos(twist), math.sin(twist))))
            halfw.append(scale * 0.62)
        objs.append(ribbon("%s-tail%d" % (name, side), centers, widths, halfw, satin, cyclic=False,
                           thickness=0.05 * scale, notch=0.55 * scale))
    centers, widths, halfw = [], [], []
    for i in range(40):
        th = 2 * math.pi * i / 40
        centers.append(place((0.0, 0.62 * math.cos(th), 0.5 + 0.5 * math.sin(th))))
        widths.append(place_dir((1.0, 0.0, 0.0)))
        halfw.append(scale * 0.72)
    objs.append(ribbon("%s-knot" % name, centers, widths, halfw, satin, cyclic=True, thickness=0.05 * scale))
    return objs


def gold_heart(name, center, size, rot, mat, z=0.22):
    """烫金小心：心形多边形挤出 0.22 mm，圆角。"""
    segs, _ = heart_path((0, 0, 1, 1))
    pts, _ = sample_closed(segs, spacing=0.02)
    pts = pts - np.array([0.5, 0.5])
    pts[:, 1] = -pts[:, 1]
    ca, sa = math.cos(rot), math.sin(rot)
    bm = bmesh.new()
    verts = []
    for x, y in pts[::2]:
        X = (x * ca - y * sa) * size + center[0]
        Y = (x * sa + y * ca) * size + center[1]
        verts.append(bm.verts.new((X, Y, z)))
    face = bm.faces.new(verts)
    if face.normal.z < 0:
        face.normal_flip()
    ext = bmesh.ops.extrude_face_region(bm, geom=[face])
    for v in ext["geom"]:
        if isinstance(v, bmesh.types.BMVert):
            v.co.z += 0.22
    obj = S.mesh_object(name, bm, smooth=True, sharp_angle=40, mats=(mat,))
    bev = obj.modifiers.new("bevel", "BEVEL")
    bev.width = 0.07 * max(size / 2.0, 0.6)
    bev.segments = 3
    bev.limit_method = "ANGLE"
    return obj


# --------------------------------------------------------------------------- scene

def build(fmt, preview=False):
    L = LAYOUTS[fmt]
    W, H = L["size"]
    scene = S.fresh_scene()
    w_px, h_px = int(W * PX_PER_MM), int(H * PX_PER_MM)
    if preview:
        w_px, h_px = w_px // 2, h_px // 2
    S.setup_cycles(scene, w_px, h_px, samples=96 if preview else 384, transparent=True, view="Standard")
    scene.cycles.max_bounces = 6

    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = max(W, H)
    cam_data.sensor_fit = "AUTO"
    cam_data.clip_start = 1
    cam_data.clip_end = 400
    cam = bpy.data.objects.new("cam", cam_data)
    S.link(cam)
    cam.location = (W / 2, H / 2, 200)
    cam.rotation_euler = (0, 0, 0)
    scene.camera = cam

    # 左上方的太阳（仰角约 39°）+ 均匀的天光；E·cosθ + s ≈ 0.97，平的卡纸渲出来就是纸色。
    sun_data = bpy.data.lights.new("sun", "SUN")
    sun_data.energy = 0.94
    sun_data.angle = math.radians(4)
    sun_data.color = S.lin("#FFF6EC")[:3]
    sun = bpy.data.objects.new("sun", sun_data)
    S.link(sun)
    d = Vector((0.55, -0.55, -0.63)).normalized()
    sun.rotation_mode = "QUATERNION"
    sun.rotation_quaternion = d.to_track_quat("-Z", "Y")
    world = bpy.data.worlds.new("sky")
    scene.world = world
    nodes, links = world.node_tree.nodes, world.node_tree.links
    bg = nodes.get("Background")
    bg.inputs["Color"].default_value = S.lin("#FFF9F2")
    bg.inputs["Strength"].default_value = 0.38

    # ---- 卡纸
    damask = damask_tile()
    card = paper_material("card", CARD, height_img=damask, bump=0.12, distance=0.03, rough=0.86)
    card_obj = rect_mesh("card", 0, 0, W, H, 0.0, card, uv_rect=(0, 0, W / 5.0, H / 5.0))

    # ---- 四周的纸蕾丝
    ba, bh, P, B = lace_tile("border")
    lace_mat = paper_material("lace-border", LACE, alpha_img=ba, height_img=bh, bump=0.7, distance=0.05)
    border = []
    edges = [
        # 中心线（纸边）、内法线方向、长度方向
        (np.array([[x, H] for x in np.linspace(0, W, 400)]), np.array([0.0, -1.0])),
        (np.array([[x, 0.0] for x in np.linspace(W, 0, 400)]), np.array([0.0, 1.0])),
        (np.array([[0.0, y] for y in np.linspace(0, H, 900)]), np.array([1.0, 0.0])),
        (np.array([[W, y] for y in np.linspace(H, 0, 900)]), np.array([-1.0, 0.0])),
    ]
    for k, (line, inward) in enumerate(edges):
        normals = np.tile(inward, (len(line), 1))
        length = np.linalg.norm(line[-1] - line[0])
        reps = max(1, int(round(length / P)))
        border.append(strip_mesh("lace-edge%d" % k, line, normals, 0.0, B, P, Z_LACE_BORDER + 0.004 * k, lace_mat,
                                 rows=2, cyclic=False, u_scale=reps / length))
    ma, mh = medallion_tile()
    med_mat = paper_material("lace-medallion", LACE, alpha_img=ma, height_img=mh, bump=0.7, distance=0.05)
    R = 2.5
    for k, (mx, my) in enumerate([(B * 0.82, H - B * 0.82), (W - B * 0.82, H - B * 0.82), (B * 0.82, B * 0.82), (W - B * 0.82, B * 0.82)]):
        border.append(rect_mesh("medallion%d" % k, mx - R, my - R, mx + R, my + R, Z_MEDALLION, med_mat))

    # ---- 心形窗口：纸蕾丝心环 + 烫金内缘线
    ra, rh, RP, RB = lace_tile("ring")
    ring_mat = paper_material("lace-ring", LACE, alpha_img=ra, height_img=rh, bump=0.7, distance=0.05)
    gold = gold_material()
    satin = satin_material()
    overlay = []
    hearts = []
    for i, rect in enumerate(L["windows"]):
        segs, inner_rect = heart_path(rect)
        pts, total = sample_closed(segs, spacing=0.04)
        pts_b = to_blender(pts, H)
        normals, _ = outward_normals(pts_b)
        hearts.append((pts_b, inner_rect))
        overlay.append(strip_mesh("ring%d" % i, pts_b, normals, -0.55, -0.55 + RB, RP, Z_RING, ring_mat, rows=4))
        line = pts_b + normals * -0.38
        overlay.append(tube("gold-line%d" % i, [(p[0], p[1], Z_RING + 0.03) for p in line[::2]], 0.13, gold))
        x, y, w, h = inner_rect
        # 心口的蝴蝶结（心形上缘中间那个凹口），尺寸跟着心的宽度。
        cleft = (x + w * 0.5, H - (y + h * 0.16) + 0.55)
        overlay += bow("bow%d" % i, cleft, scale=w / 44.0 * 1.05, rot=math.radians(-4 if i % 2 else 4), satin=satin)
        # 窗口下角的烫金小心（心形尖两边空出来的三角）。
        rx, ry, rw, rh_ = rect
        overlay.append(gold_heart("gold-heart%da" % i, (rx + rw * 0.11, H - (ry + rh_ * 0.86)), rw * 0.085, math.radians(-14), gold))
        overlay.append(gold_heart("gold-heart%db" % i, (rx + rw * 0.9, H - (ry + rh_ * 0.9)), rw * 0.055, math.radians(12), gold))

    # ---- 题字上方的烫金花线
    cx0, cy0, cw, ch = L["caption"]
    yline = H - (cy0 - 0.9)
    half = cw * 0.32
    mid = W / 2
    for side in (-1, 1):
        pts = [(mid + side * (1.6 + t * half), yline + 0.25 * math.sin(t * math.pi * 2) * (1 - t), Z_RING) for t in np.linspace(0, 1, 60)]
        overlay.append(tube("flourish%d" % side, pts, 0.11, gold, cyclic=False))
    overlay.append(gold_heart("flourish-heart", (mid, yline), 2.2, 0.0, gold))

    photos = []
    if preview:
        photo_mat = S.principled("photo", "#7C93A6", rough=0.4)
        for i, (pts_b, _) in enumerate(hearts):
            bm = bmesh.new()
            vs = [bm.verts.new((p[0], p[1], 0.02)) for p in pts_b[::3]]
            f = bm.faces.new(vs)
            if f.normal.z < 0:
                f.normal_flip()
            photos.append(S.mesh_object("photo%d" % i, bm, smooth=False, mats=(photo_mat,)))
    return scene, card_obj, border, overlay, photos


def set_visible(objs, on):
    for o in objs:
        o.hide_render = not on


def render_format(fmt, preview=False):
    scene, card, border, overlay, photos = build(fmt, preview)
    os.makedirs(OUT, exist_ok=True)
    if preview:
        scene.render.film_transparent = False
        path = os.path.join(OUT, "valentine-%s-preview.png" % fmt)
        scene.render.image_settings.color_mode = "RGB"
        S.render_to(scene, path)
        return

    os.makedirs(FRAMES, exist_ok=True)
    # 照片下面：卡纸 + 四周蕾丝（不透明 JPEG）。
    set_visible(overlay, False)
    scene.render.film_transparent = False
    scene.render.image_settings.file_format = "JPEG"
    scene.render.image_settings.color_mode = "RGB"
    scene.render.image_settings.quality = 90
    S.render_to(scene, os.path.join(FRAMES, "valentine-%s-base.jpg" % fmt))

    # 照片上面：心环、金线、蝴蝶结、金心；卡纸当阴影捕捉器，四周蕾丝藏起来。
    set_visible(overlay, True)
    set_visible(border, False)
    card.is_shadow_catcher = True
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.compression = 100
    S.render_to(scene, os.path.join(FRAMES, "valentine-%s-overlay.png" % fmt))


def main():
    args = S.script_args()
    preview = "--preview" in args
    fmts = [a for a in args if a in LAYOUTS] or list(LAYOUTS)
    for fmt in fmts:
        render_format(fmt, preview)


main()
