"""Nocchi studio: shared helpers for the Blender art scripts.

Used by design/blender/canisters, design/blender/icons and design/blender/props.
Everything is procedural; the only inputs are macOS system fonts (rasterised into
the textures) and, for a few props, the repo's own textures in Shared/Art.xcassets.

Run any script of the family with the Blender CLI, e.g.

    /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup \
        -P design/blender/canisters/make_canisters.py -- --stock cream-600

Conventions
- 1 Blender unit = 1 cm for 3-D scenes, 1 unit = 1 mm for flat (2-D) layouts.
- Final renders: Cycles on the Metal GPU, OpenImageDenoise, AgX, transparent film,
  a shadow-catcher floor, PNG RGBA 8 bit.
- Light comes from the top-left of the *screen* (defined in camera space), so every
  asset - 3/4 view or top-down - is lit the same way and drops its shadow to the
  right / bottom-right, as docs/DESIGN.md section 0 asks.
"""

import bpy
import bmesh
import json
import math
import os
import struct
import sys
import tempfile
import time

from mathutils import Matrix, Vector
from bpy_extras.object_utils import world_to_camera_view

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
ART = os.path.join(REPO, "Shared", "Art.xcassets")
BLENDER_DIR = os.path.abspath(os.path.join(HERE, ".."))


def log(*a):
    print("[nocchi]", *a, flush=True)


def script_args():
    argv = sys.argv
    return argv[argv.index("--") + 1:] if "--" in argv else []


# --------------------------------------------------------------------------- colour

def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def _s2l(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def lin(h, a=1.0):
    """sRGB hex -> linear RGBA tuple for node sockets."""
    r, g, b = hex_rgb(h) if isinstance(h, str) else h
    return (_s2l(r), _s2l(g), _s2l(b), a)


def mix_hex(a, b, t):
    ra, rb = hex_rgb(a), hex_rgb(b)
    c = [ra[i] * (1 - t) + rb[i] * t for i in range(3)]
    return "#%02X%02X%02X" % tuple(int(round(max(0, min(1, v)) * 255)) for v in c)


def luminance(h):
    r, g, b = (_s2l(v) for v in hex_rgb(h))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


# --------------------------------------------------------------------------- fonts

_SYS = "/System/Library/Fonts"
_SUP = "/System/Library/Fonts/Supplemental"
FONT_FILES = {
    # key: (file, face index inside a .ttc or None)
    "futura-cxb": (_SUP + "/Futura.ttc", 4),         # Futura Condensed ExtraBold
    "futura-cm": (_SUP + "/Futura.ttc", 3),          # Futura Condensed Medium
    "futura-bold": (_SUP + "/Futura.ttc", 2),
    "futura-medium": (_SUP + "/Futura.ttc", 0),
    "didot": (_SUP + "/Didot.ttc", 0),
    "didot-bold": (_SUP + "/Didot.ttc", 2),
    "typewriter": (_SUP + "/AmericanTypewriter.ttc", 0),
    "typewriter-semibold": (_SUP + "/AmericanTypewriter.ttc", 3),
    "typewriter-cond": (_SUP + "/AmericanTypewriter.ttc", 4),
    "typewriter-cond-bold": (_SUP + "/AmericanTypewriter.ttc", 5),
    "din-cond": (_SUP + "/DIN Condensed Bold.ttf", None),
    "courier": (_SUP + "/Courier New.ttf", None),
    "courier-bold": (_SUP + "/Courier New Bold.ttf", None),
    "gill-semibold": (_SUP + "/GillSans.ttc", 4),
    "copperplate": (_SUP + "/Copperplate.ttc", 0),
    "copperplate-bold": (_SUP + "/Copperplate.ttc", 2),
}
_font_cache = {}


def _extract_ttc_face(ttc, index, out):
    """Copy one face of a TrueType collection into a standalone .ttf (Blender loads face 0 only)."""
    data = open(ttc, "rb").read()
    if data[:4] != b"ttcf":
        raise ValueError("not a ttc: " + ttc)
    n = struct.unpack(">I", data[8:12])[0]
    offs = struct.unpack(">%dI" % n, data[12:12 + 4 * n])
    o = offs[index]
    sfnt, num, sr, es, rs = struct.unpack(">IHHHH", data[o:o + 12])
    recs = [struct.unpack(">4sIII", data[o + 12 + 16 * i:o + 28 + 16 * i]) for i in range(num)]
    head = struct.pack(">IHHHH", sfnt, num, sr, es, rs)
    pos = 12 + 16 * num
    dir_b, body = b"", b""
    for tag, cs, off, ln in recs:
        dir_b += struct.pack(">4sIII", tag, cs, pos, ln)
        pad = (4 - ln % 4) % 4
        body += data[off:off + ln] + b"\0" * pad
        pos += ln + pad
    with open(out, "wb") as f:
        f.write(head + dir_b + body)


def font(key):
    if key in _font_cache and _font_cache[key].name in bpy.data.fonts:
        return _font_cache[key]
    path, idx = FONT_FILES[key]
    if idx is not None:
        cache = os.path.join(tempfile.gettempdir(), "nocchi-blender-fonts")
        os.makedirs(cache, exist_ok=True)
        out = os.path.join(cache, "%s.ttf" % key)
        if not os.path.exists(out):
            _extract_ttc_face(path, idx, out)
        path = out
    f = bpy.data.fonts.load(path, check_existing=True)
    _font_cache[key] = f
    return f


# --------------------------------------------------------------------------- mesh helpers

def link(obj, scene=None):
    (scene or bpy.context.scene).collection.objects.link(obj)
    return obj


def mesh_object(name, bm, scene=None, smooth=True, sharp_angle=None, mats=()):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for m in mats:
        me.materials.append(m)
    if smooth:
        try:
            me.shade_smooth()
        except AttributeError:
            for p in me.polygons:
                p.use_smooth = True
        if sharp_angle is not None:
            try:
                me.set_sharp_from_angle(angle=math.radians(sharp_angle))
            except Exception:
                pass
    ob = bpy.data.objects.new(name, me)
    return link(ob, scene)


def lathe(name, profile, segments=128, mats=(), sharp_angle=35, scene=None, uv=False):
    """Revolve a list of (r, z) points around Z.  Points with r == 0 become poles."""
    bm = bmesh.new()
    rings = []
    for (r, z) in profile:
        if r < 1e-7:
            v = bm.verts.new((0.0, 0.0, z))
            rings.append([v] * segments)
        else:
            rings.append([bm.verts.new((r * math.cos(2 * math.pi * i / segments),
                                        r * math.sin(2 * math.pi * i / segments), z))
                          for i in range(segments)])
    for k in range(len(rings) - 1):
        A, B = rings[k], rings[k + 1]
        for i in range(segments):
            j = (i + 1) % segments
            quad = [A[i], A[j], B[j], B[i]]
            uniq = []
            for v in quad:
                if v not in uniq:
                    uniq.append(v)
            if len(uniq) >= 3:
                try:
                    bm.faces.new(uniq)
                except ValueError:
                    pass
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-7)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return mesh_object(name, bm, scene=scene, sharp_angle=sharp_angle, mats=mats)


def rounded_rect_points(x, y, w, h, r, seg=10):
    r = max(0.0, min(r, w / 2, h / 2))
    if r <= 1e-6:
        return [(x, y), (x + w, y), (x + w, y + h), (x, y + h)]
    pts = []
    corners = [(x + w - r, y + r, -90), (x + w - r, y + h - r, 0), (x + r, y + h - r, 90), (x + r, y + r, 180)]
    for cx, cy, a0 in corners:
        for i in range(seg + 1):
            a = math.radians(a0 + 90 * i / seg)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def polygon_object(name, pts, z=0.0, mat=None, scene=None):
    bm = bmesh.new()
    vs = [bm.verts.new((p[0], p[1], z)) for p in pts]
    bm.faces.new(vs)
    ob = mesh_object(name, bm, scene=scene, smooth=False, mats=(mat,) if mat else ())
    return ob


# --------------------------------------------------------------------------- materials

def _nodes(mat):
    try:
        mat.use_nodes = True
    except Exception:
        pass
    return mat.node_tree.nodes, mat.node_tree.links


def principled(name, color="#808080", rough=0.5, metal=0.0, **kw):
    """Principled BSDF material.  Extra keyword args map to socket names with '_' for ' '."""
    mat = bpy.data.materials.new(name)
    nodes, links = _nodes(mat)
    p = nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value = lin(color) if isinstance(color, str) else color
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metal
    for k, v in kw.items():
        sock = k.replace("_", " ")
        if isinstance(v, str):
            v = lin(v)
        p.inputs[sock].default_value = v
    return mat


def principled_node(mat):
    return mat.node_tree.nodes.get("Principled BSDF")


def emission_mat(name, color, strength=1.0):
    mat = bpy.data.materials.new(name)
    nodes, links = _nodes(mat)
    for n in list(nodes):
        nodes.remove(n)
    out = nodes.new("ShaderNodeOutputMaterial")
    em = nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = lin(color) if isinstance(color, str) else color
    em.inputs["Strength"].default_value = strength
    links.new(em.outputs[0], out.inputs["Surface"])
    return mat


def image_node(mat, path_or_img, colorspace="sRGB", interpolation="Cubic", extension="EXTEND"):
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    img = path_or_img
    if isinstance(path_or_img, str):
        img = bpy.data.images.load(path_or_img, check_existing=False)
    img.colorspace_settings.name = colorspace
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = interpolation
    tex.extension = extension
    return tex


def brushed_metal(name, color="#C9CCD0", rough=0.24, aniso=0.75, radial=True, ring_scale=900.0, bump=0.06):
    """Spun / brushed aluminium.  radial=True -> concentric brushing around the object's Z axis."""
    mat = principled(name, color, rough=rough, metal=1.0)
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    p = principled_node(mat)
    p.inputs["Anisotropic"].default_value = aniso
    tan = nodes.new("ShaderNodeTangent")
    tan.direction_type = "RADIAL"
    tan.axis = "Z"
    if radial:
        links.new(tan.outputs[0], p.inputs["Tangent"])
    tc = nodes.new("ShaderNodeTexCoord")
    wave = nodes.new("ShaderNodeTexWave")
    wave.wave_type = "RINGS"
    wave.rings_direction = "Z"
    wave.inputs["Scale"].default_value = ring_scale
    wave.inputs["Distortion"].default_value = 2.0
    wave.inputs["Detail"].default_value = 2.0
    links.new(tc.outputs["Object"], wave.inputs["Vector"])
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 60.0
    links.new(tc.outputs["Object"], noise.inputs["Vector"])
    mixc = nodes.new("ShaderNodeMix")
    mixc.data_type = "FLOAT"
    mixc.inputs[0].default_value = 0.35
    links.new(wave.outputs["Fac"], mixc.inputs[2])
    links.new(noise.outputs["Fac"], mixc.inputs[3])
    bmp = nodes.new("ShaderNodeBump")
    bmp.inputs["Strength"].default_value = bump
    bmp.inputs["Distance"].default_value = 0.002
    links.new(mixc.outputs[0], bmp.inputs["Height"])
    links.new(bmp.outputs[0], p.inputs["Normal"])
    # faint roughness variation
    rmap = nodes.new("ShaderNodeMapRange")
    rmap.inputs["To Min"].default_value = rough * 0.8
    rmap.inputs["To Max"].default_value = rough * 1.25
    links.new(noise.outputs["Fac"], rmap.inputs["Value"])
    links.new(rmap.outputs[0], p.inputs["Roughness"])
    return mat


def velvet(name, color="#0E0D0D"):
    mat = principled(name, color, rough=0.95)
    p = principled_node(mat)
    p.inputs["Sheen Weight"].default_value = 1.0
    p.inputs["Sheen Roughness"].default_value = 0.35
    p.inputs["Sheen Tint"].default_value = lin("#8A8580")
    p.inputs["Specular IOR Level"].default_value = 0.2
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 900.0
    bmp = nodes.new("ShaderNodeBump")
    bmp.inputs["Strength"].default_value = 0.35
    bmp.inputs["Distance"].default_value = 0.001
    links.new(noise.outputs["Fac"], bmp.inputs["Height"])
    links.new(bmp.outputs[0], p.inputs["Normal"])
    return mat


def add_fine_bump(mat, scale=300.0, strength=0.05, distance=0.002, kind="noise"):
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    p = principled_node(mat)
    tex = nodes.new("ShaderNodeTexNoise")
    tex.inputs["Scale"].default_value = scale
    tex.inputs["Detail"].default_value = 6.0
    bmp = nodes.new("ShaderNodeBump")
    bmp.inputs["Strength"].default_value = strength
    bmp.inputs["Distance"].default_value = distance
    links.new(tex.outputs["Fac"], bmp.inputs["Height"])
    links.new(bmp.outputs[0], p.inputs["Normal"])
    return bmp


# --------------------------------------------------------------------------- render setup

def fresh_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _font_cache.clear()
    scene = bpy.context.scene
    scene.name = "nocchi"
    return scene


def use_metal():
    prefs = bpy.context.preferences.addons["cycles"].preferences
    try:
        prefs.compute_device_type = "METAL"
        prefs.get_devices()
        ok = False
        for d in prefs.devices:
            d.use = d.type == "METAL"
            ok = ok or d.use
        return ok
    except Exception as e:  # pragma: no cover
        log("Metal unavailable:", e)
        return False


def setup_cycles(scene, w, h, samples=256, transparent=True, view="AgX", look="None",
                 exposure=0.0, denoise=True, bounces=8, filter_width=1.2):
    scene.render.engine = "CYCLES"
    gpu = use_metal()
    scene.cycles.device = "GPU" if gpu else "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_adaptive_sampling = True
    scene.cycles.adaptive_threshold = 0.004
    scene.cycles.use_denoising = denoise
    if denoise:
        scene.cycles.denoiser = "OPENIMAGEDENOISE"
        try:
            scene.cycles.denoising_quality = "HIGH"
        except Exception:
            pass
    scene.cycles.max_bounces = bounces
    scene.cycles.diffuse_bounces = min(4, bounces)
    scene.cycles.glossy_bounces = min(4, bounces)
    scene.cycles.transmission_bounces = bounces
    scene.cycles.transparent_max_bounces = 16
    scene.cycles.caustics_reflective = False
    scene.cycles.caustics_refractive = False
    scene.cycles.blur_glossy = 0.5
    scene.cycles.filter_width = filter_width
    scene.render.resolution_x = w
    scene.render.resolution_y = h
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = transparent
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA" if transparent else "RGB"
    scene.render.image_settings.color_depth = "8"
    scene.render.image_settings.compression = 90
    scene.view_settings.view_transform = view
    scene.view_settings.look = look
    scene.view_settings.exposure = exposure
    scene.view_settings.gamma = 1.0
    return scene


def render_to(scene, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    scene.render.filepath = path
    t = time.time()
    bpy.ops.render.render(write_still=True, scene=scene.name)
    dt = time.time() - t
    log("rendered %s in %.1fs" % (os.path.relpath(path, REPO) if path.startswith(REPO) else path, dt))
    return dt


# --------------------------------------------------------------------------- camera & lights

def look_at(obj, target, up_axis="Y"):
    d = Vector(target) - obj.location
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = d.to_track_quat("-Z", up_axis)


def camera(scene, target, azimuth=0.0, elevation=20.0, distance=14.0, lens=85.0, ortho=None):
    """azimuth 0 = camera in front (on -Y) looking towards +Y; positive azimuth swings it to the right."""
    data = bpy.data.cameras.new("cam")
    data.sensor_fit = "HORIZONTAL"
    data.sensor_width = 36.0
    data.lens = lens
    data.clip_start = 0.05
    data.clip_end = 1000
    if ortho:
        data.type = "ORTHO"
        data.ortho_scale = ortho
    cam = bpy.data.objects.new("cam", data)
    link(cam, scene)
    az, el = math.radians(azimuth), math.radians(elevation)
    t = Vector(target)
    cam.location = t + distance * Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el)))
    look_at(cam, t)
    scene.camera = cam
    return cam


def cam_axes(cam):
    m = cam.matrix_world.to_3x3()
    right = (m @ Vector((1, 0, 0))).normalized()
    up = (m @ Vector((0, 1, 0))).normalized()
    back = (m @ Vector((0, 0, 1))).normalized()  # from target towards camera
    return right, up, back


def area_light(scene, name, pos, target, power, size, color="#FFFFFF", shape="DISK", spread=None):
    ld = bpy.data.lights.new(name, "AREA")
    ld.shape = shape
    ld.size = size
    if shape in ("RECTANGLE", "ELLIPSE"):
        ld.size_y = size
    ld.energy = power
    ld.color = lin(color)[:3]
    if spread is not None:
        ld.spread = math.radians(spread)
    ob = bpy.data.objects.new(name, ld)
    ob.location = pos
    link(ob, scene)
    look_at(ob, target)
    return ob


# Camera-space light directions (x = screen right, y = screen up, z = towards the camera).
RIG = {
    "key": dict(dir=(-0.62, 0.62, 0.48), dist=16.0, size=11.0, power=4200.0, color="#FFF4E6"),
    "fill": dict(dir=(0.92, -0.05, 0.40), dist=18.0, size=16.0, power=900.0, color="#FFE2C4"),
    "rim": dict(dir=(0.35, 0.55, -0.76), dist=14.0, size=7.0, power=1500.0, color="#EEF2FF"),
}


def light_rig(scene, cam, target, scale=1.0, power_scale=1.0, world_strength=0.28, rig=None, extra=None):
    """Soft top-left key, warm fill from the right, cool rim from behind; plus a dim studio world."""
    rig = dict(RIG if rig is None else rig)
    if extra:
        rig.update(extra)
    right, up, back = cam_axes(cam)
    t = Vector(target)
    objs = []
    for name, L in rig.items():
        dx, dy, dz = L["dir"]
        d = (right * dx + up * dy + back * dz).normalized()
        pos = t + d * L["dist"] * scale
        p = L["power"] * power_scale * scale * scale
        objs.append(area_light(scene, name, pos, t, p, L["size"] * scale, L["color"]))
    world_gradient(scene, world_strength)
    return objs


def world_gradient(scene, strength=0.28, top="#F3EEE6", horizon="#B9B1A6", bottom="#4A4540"):
    w = bpy.data.worlds.new("studio")
    scene.world = w
    nodes, links = _nodes(w)
    for n in list(nodes):
        nodes.remove(n)
    out = nodes.new("ShaderNodeOutputWorld")
    bg = nodes.new("ShaderNodeBackground")
    bg.inputs["Strength"].default_value = strength
    tc = nodes.new("ShaderNodeTexCoord")
    sep = nodes.new("ShaderNodeSeparateXYZ")
    links.new(tc.outputs["Generated"], sep.inputs[0])
    ramp = nodes.new("ShaderNodeValToRGB")
    cr = ramp.color_ramp
    cr.elements[0].position = 0.0
    cr.elements[0].color = lin(bottom)
    cr.elements[1].position = 1.0
    cr.elements[1].color = lin(top)
    e = cr.elements.new(0.52)
    e.color = lin(horizon)
    # Generated coords for the world are the view direction; z in [-1,1] -> [0,1]
    mapr = nodes.new("ShaderNodeMapRange")
    mapr.inputs["From Min"].default_value = -1.0
    mapr.inputs["From Max"].default_value = 1.0
    links.new(sep.outputs["Z"], mapr.inputs["Value"])
    links.new(mapr.outputs[0], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], bg.inputs["Color"])
    links.new(bg.outputs[0], out.inputs["Surface"])
    return w


def shadow_catcher(scene, size=400.0, z=0.0, loc=(0, 0)):
    bpy.ops.mesh.primitive_plane_add(size=size, location=(loc[0], loc[1], z))
    pl = bpy.context.active_object
    pl.name = "floor"
    pl.is_shadow_catcher = True
    pl.data.materials.append(principled("floor", "#BDB6AA", rough=0.9))
    return pl


# --------------------------------------------------------------------------- framing

def projected_bbox(scene, cam, objs):
    deps = bpy.context.evaluated_depsgraph_get()
    deps.update()
    xs, ys = [], []
    for o in objs:
        if o.type not in ("MESH", "CURVE", "FONT", "SURFACE"):
            continue
        ev = o.evaluated_get(deps)
        try:
            me = ev.to_mesh()
        except RuntimeError:
            continue
        mw = ev.matrix_world
        for v in me.vertices:
            p = world_to_camera_view(scene, cam, mw @ v.co)
            xs.append(p.x)
            ys.append(p.y)
        ev.to_mesh_clear()
    return min(xs), max(xs), min(ys), max(ys)


def fit_camera(scene, cam, objs, pad=0.10, iterations=4, anchor=None):
    """Zoom (focal length) and lens-shift a fixed camera so objs fill the frame with `pad` margins.

    anchor: optional (ax, ay) in [0,1] to place the bbox centre somewhere other than the middle."""
    w, h = scene.render.resolution_x, scene.render.resolution_y
    aspect = w / h
    ax, ay = anchor or (0.5, 0.5)
    for _ in range(iterations):
        x0, x1, y0, y1 = projected_bbox(scene, cam, objs)
        bw, bh = x1 - x0, y1 - y0
        k = min((1 - 2 * pad) / bw, (1 - 2 * pad) / bh)
        cam.data.lens *= k
        x0, x1, y0, y1 = projected_bbox(scene, cam, objs)
        cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
        # shift is measured in units of the larger frame dimension
        if aspect >= 1:
            cam.data.shift_x += (cx - ax)
            cam.data.shift_y += (cy - ay) / aspect
        else:
            cam.data.shift_x += (cx - ax) * aspect
            cam.data.shift_y += (cy - ay)
    return projected_bbox(scene, cam, objs)


def fit_objects(scene, cam, objs, root, box, iterations=6):
    """Scale/translate `root` (parent of objs, sitting on the floor) so objs' projection fills `box`.

    box = (x0, x1, y0, y1) in normalised frame coordinates.  Camera stays untouched."""
    right, up, back = cam_axes(cam)
    flat_right = Vector((right.x, right.y, 0)).normalized()
    flat_back = Vector((back.x, back.y, 0)).normalized()
    tx0, tx1, ty0, ty1 = box
    for _ in range(iterations):
        x0, x1, y0, y1 = projected_bbox(scene, cam, objs)
        k = min((tx1 - tx0) / (x1 - x0), (ty1 - ty0) / (y1 - y0))
        root.scale = root.scale * k
        bpy.context.view_layer.update()
        x0, x1, y0, y1 = projected_bbox(scene, cam, objs)
        cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
        tcx, tcy = (tx0 + tx1) / 2, (ty0 + ty1) / 2
        # crude Jacobian: frame width at the object's distance
        dist = (root.location - cam.location).length
        fw = dist * cam.data.sensor_width / cam.data.lens
        root.location += flat_right * (tcx - cx) * fw
        # moving along flat_back shifts the object vertically on screen through perspective/elevation
        el = math.asin(max(-1, min(1, back.z)))
        root.location -= flat_back * (tcy - cy) * fw / max(0.2, math.sin(el))
        bpy.context.view_layer.update()
    return projected_bbox(scene, cam, objs)


# --------------------------------------------------------------------------- flat (2-D) layouts

class Flat:
    """A tiny 2-D compositor in millimetres: rectangles, polygons, text and images, rendered flat.

    Uses a throw-away scene, an orthographic camera and emission shaders with the Standard view
    transform, so hex colours come out exactly.  Origin is bottom-left, y up."""

    def __init__(self, w_mm, h_mm, px_w, bg=None, transparent=False, samples=24, name="flat"):
        self.w, self.h = float(w_mm), float(h_mm)
        self.px_w = int(px_w)
        self.px_h = int(round(px_w * h_mm / w_mm))
        self.scene = bpy.data.scenes.new(name)
        sc = self.scene
        setup_cycles(sc, self.px_w, self.px_h, samples=samples, transparent=transparent,
                     view="Standard", denoise=False, bounces=0, filter_width=1.0)
        sc.cycles.use_adaptive_sampling = False
        sc.render.dither_intensity = 0.0
        sc.world = bpy.data.worlds.new(name + "-world")
        nodes, links = _nodes(sc.world)
        bgn = nodes.get("Background")
        if bgn is not None:
            bgn.inputs["Strength"].default_value = 0.0
        cd = bpy.data.cameras.new(name + "-cam")
        cd.type = "ORTHO"
        cd.ortho_scale = max(self.w, self.h)
        cd.clip_start = 0.01
        cd.clip_end = 1000
        cam = bpy.data.objects.new(name + "-cam", cd)
        cam.location = (self.w / 2, self.h / 2, 500)
        sc.collection.objects.link(cam)
        sc.camera = cam
        self._mats = {}
        self.z = 0.0
        if bg:
            self.rect(0, 0, self.w, self.h, bg)

    def _z(self):
        self.z += 0.01
        return self.z

    def mat(self, color, alpha=1.0):
        key = (color, round(alpha, 3))
        if key in self._mats:
            return self._mats[key]
        m = emission_mat("flat-%s-%.2f" % (color, alpha), color)
        if alpha < 1.0:
            nodes, links = m.node_tree.nodes, m.node_tree.links
            out = nodes.get("Material Output")
            em = nodes.get("Emission")
            tr = nodes.new("ShaderNodeBsdfTransparent")
            mix = nodes.new("ShaderNodeMixShader")
            mix.inputs[0].default_value = alpha
            links.new(tr.outputs[0], mix.inputs[1])
            links.new(em.outputs[0], mix.inputs[2])
            links.new(mix.outputs[0], out.inputs["Surface"])
        self._mats[key] = m
        return m

    def poly(self, pts, color, alpha=1.0):
        ob = polygon_object("poly", pts, z=self._z(), mat=self.mat(color, alpha), scene=self.scene)
        return ob

    def rect(self, x, y, w, h, color, radius=0.0, alpha=1.0):
        return self.poly(rounded_rect_points(x, y, w, h, radius), color, alpha)

    def circle(self, cx, cy, r, color, seg=64, alpha=1.0):
        pts = [(cx + r * math.cos(2 * math.pi * i / seg), cy + r * math.sin(2 * math.pi * i / seg)) for i in range(seg)]
        return self.poly(pts, color, alpha)

    def ring(self, cx, cy, r0, r1, color, seg=96, alpha=1.0):
        bm = bmesh.new()
        z = self._z()
        outer = [bm.verts.new((cx + r1 * math.cos(2 * math.pi * i / seg), cy + r1 * math.sin(2 * math.pi * i / seg), z)) for i in range(seg)]
        inner = [bm.verts.new((cx + r0 * math.cos(2 * math.pi * i / seg), cy + r0 * math.sin(2 * math.pi * i / seg), z)) for i in range(seg)]
        for i in range(seg):
            j = (i + 1) % seg
            bm.faces.new([outer[i], outer[j], inner[j], inner[i]])
        return mesh_object("ring", bm, scene=self.scene, smooth=False, mats=(self.mat(color, alpha),))

    def text(self, s, font_key, size, x, y, color, align="LEFT", tracking=0.0, rot=0.0,
             max_w=None, max_h=None, height=None, valign="BASELINE", alpha=1.0, scale_x=1.0):
        """Place text with its baseline at y (valign BASELINE) or its ink box centred on y (CENTER).

        size: em size in mm (ignored when `height` is given: then the ink height of the string is set
        exactly to `height` mm).  tracking: extra letter spacing in em.  max_w / max_h shrink to fit.
        Returns (obj, width, height) of the ink box."""
        cu = bpy.data.curves.new("txt", "FONT")
        cu.body = s
        cu.font = font(font_key)
        cu.size = size if height is None else 10.0
        cu.space_character = 1.0 + tracking
        cu.align_x = align
        cu.align_y = "BOTTOM_BASELINE"
        cu.resolution_u = 10
        ob = bpy.data.objects.new("txt", cu)
        self.scene.collection.objects.link(ob)
        ob.data.materials.append(self.mat(color, alpha))
        ob.location = (x, y, self._z())
        ob.scale = (scale_x, 1, 1)
        w, h, ymin, ymax = self.measure(ob)
        if height is not None and h > 0:
            cu.size = 10.0 * height / h
            w, h, ymin, ymax = self.measure(ob)
        k = 1.0
        if max_w and w > max_w:
            k = min(k, max_w / w)
        if max_h and h > max_h:
            k = min(k, max_h / h)
        if k < 1.0:
            ob.scale = (scale_x * k, k, 1)
            w, h, ymin, ymax = self.measure(ob)
        if valign == "CENTER":
            ob.location.y += y - (ymin + ymax) / 2
        if rot:
            ob.rotation_euler = (0, 0, math.radians(rot))
        return ob, w, h

    def measure(self, ob):
        self.scene.view_layers[0].update()
        deps = self.scene.view_layers[0].depsgraph
        ev = ob.evaluated_get(deps)
        me = ev.to_mesh()
        if len(me.vertices) == 0:
            ev.to_mesh_clear()
            return 0.0, 0.0, ob.location.y, ob.location.y
        mw = ob.matrix_world
        xs = [(mw @ v.co).x for v in me.vertices]
        ys = [(mw @ v.co).y for v in me.vertices]
        ev.to_mesh_clear()
        return max(xs) - min(xs), max(ys) - min(ys), min(ys), max(ys)

    def image(self, path, x, y, w, h=None, alpha=1.0):
        img = bpy.data.images.load(path, check_existing=True)
        if h is None:
            h = w * img.size[1] / img.size[0]
        m = bpy.data.materials.new("img")
        nodes, links = _nodes(m)
        for n in list(nodes):
            nodes.remove(n)
        out = nodes.new("ShaderNodeOutputMaterial")
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = img
        tex.interpolation = "Cubic"
        tex.extension = "CLIP"
        em = nodes.new("ShaderNodeEmission")
        tr = nodes.new("ShaderNodeBsdfTransparent")
        mix = nodes.new("ShaderNodeMixShader")
        mul = nodes.new("ShaderNodeMath")
        mul.operation = "MULTIPLY"
        mul.inputs[1].default_value = alpha
        links.new(tex.outputs["Color"], em.inputs["Color"])
        links.new(tex.outputs["Alpha"], mul.inputs[0])
        links.new(mul.outputs[0], mix.inputs[0])
        links.new(tr.outputs[0], mix.inputs[1])
        links.new(em.outputs[0], mix.inputs[2])
        links.new(mix.outputs[0], out.inputs["Surface"])
        bm = bmesh.new()
        z = self._z()
        vs = [bm.verts.new(c) for c in ((x, y, z), (x + w, y, z), (x + w, y + h, z), (x, y + h, z))]
        f = bm.faces.new(vs)
        uvl = bm.loops.layers.uv.new()
        for loop, uv in zip(f.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
            loop[uvl].uv = uv
        return mesh_object("img", bm, scene=self.scene, smooth=False, mats=(m,))

    def render(self, path):
        return render_to(self.scene, path)

    def dispose(self):
        sc = self.scene
        for ob in list(sc.collection.objects):
            bpy.data.objects.remove(ob, do_unlink=True)
        bpy.data.scenes.remove(sc)


# --------------------------------------------------------------------------- asset catalog

def fade_shadow_edges(path, margin=0.12):
    """Fade the shadow-catcher pixels to fully transparent near the canvas edges.

    Shadow pixels are black and partly transparent; object pixels are coloured or opaque and stay untouched.
    Guarantees the floor shadow never ends in a hard edge at the image border (smoothstep over `margin`)."""
    import numpy as np
    img = bpy.data.images.load(path, check_existing=False)
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    rgb_max = px[..., :3].max(axis=2)
    alpha = px[..., 3]
    shadow = (rgb_max < 0.035) & (alpha < 0.97)
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    dx = np.minimum(xs, w - 1 - xs) / max(1.0, w * margin)
    dy = np.minimum(ys, h - 1 - ys) / max(1.0, h * margin)
    t = np.clip(np.minimum(dx, dy), 0.0, 1.0)
    fade = t * t * (3.0 - 2.0 * t)
    px[..., 3] = np.where(shadow, alpha * fade, alpha)
    img.pixels[:] = px.ravel()
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    edge = np.concatenate([px[0, :, 3], px[-1, :, 3], px[:, 0, 3], px[:, -1, 3]])
    log("faded shadow edges of %s (edge alpha max %.3f)" % (os.path.basename(path), float(edge.max())))


def write_imageset(name, png_src, filename=None):
    """Copy a rendered PNG into Shared/Art.xcassets/<name>.imageset with a Contents.json."""
    import shutil
    d = os.path.join(ART, name + ".imageset")
    os.makedirs(d, exist_ok=True)
    filename = filename or os.path.basename(png_src)
    dst = os.path.join(d, filename)
    if os.path.abspath(png_src) != os.path.abspath(dst):
        shutil.copyfile(png_src, dst)
    contents = ('{\n  "images" : [\n    { "filename" : "%s", "idiom" : "universal" }\n  ],\n'
                '  "info" : { "author" : "xcode", "version" : 1 }\n}\n') % filename
    with open(os.path.join(d, "Contents.json"), "w") as f:
        f.write(contents)
    return dst


def imageset_png(name, filename):
    return os.path.join(ART, name + ".imageset", filename)


# --------------------------------------------------------------------------- contact sheets

def contact_sheet(items, out, cols, cell=(420, 470), sizes=(None,), bgs=("#1E1E1E",),
                  title=None, caption_color=None, px_per_mm=1.0):
    """Render a labelled contact sheet.

    items: list of (png_path, caption).  For each item and each background a cell is drawn; inside it
    the image is shown at every size in `sizes` (None = native pixels)."""
    cw, ch = cell
    rows = (len(items) + cols - 1) // cols
    bands = len(bgs)
    title_h = 60 if title else 0
    W = cols * cw
    H = rows * ch * bands + title_h
    fl = Flat(W, H, W, bg="#F4EEE1", samples=16, name="contact")
    if title:
        fl.text(title, "futura-bold", 26, 20, H - 42, "#2E2924", tracking=0.08)
    for b, bgc in enumerate(bgs):
        ink = caption_color or ("#ECE6DA" if luminance(bgc) < 0.3 else "#2E2924")
        for i, (path, cap) in enumerate(items):
            r, c = divmod(i, cols)
            x0 = c * cw
            y0 = H - title_h - (b * rows + r + 1) * ch
            fl.rect(x0 + 4, y0 + 4, cw - 8, ch - 8, bgc, radius=6)
            if not os.path.exists(path):
                fl.text("missing", "typewriter", 16, x0 + 20, y0 + ch / 2, "#B23A2A")
                continue
            img = bpy.data.images.load(path, check_existing=True)
            iw, ih = img.size
            xcur = x0 + 14
            for s in sizes:
                if s is None:
                    dw, dh = iw, ih
                    k = min(1.0, (cw - 28) / dw, (ch - 64) / dh)
                    dw, dh = dw * k, dh * k
                else:
                    k = s / max(iw, ih)
                    dw, dh = iw * k, ih * k
                fl.image(path, xcur, y0 + 40 + (ch - 64 - dh), dw, dh)
                xcur += dw + 12
            fl.text(cap, "typewriter", 13, x0 + 14, y0 + 16, ink, max_w=cw - 28)
    fl.render(out)
    fl.dispose()
    return out
