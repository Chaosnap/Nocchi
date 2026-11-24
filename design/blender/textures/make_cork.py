"""Nocchi · 柔和的软木纹理（无缝平铺）。

细颗粒、低反差、暖色：Voronoi 颗粒（每粒一个随机深浅）+ 颗粒之间浅浅的缝 + 细噪声 + 稀疏的小深点。
无缝：把 UV 映射到四维环面（cos/sin 2πu, cos/sin 2πv）上取 4D 噪声，左右、上下边缘严丝合缝。
输出 1024×1024，作为 @2x 资源（铺在界面上颗粒更细）：Shared/Art.xcassets/CorkSoft.imageset。

用法：
    /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P design/blender/textures/make_cork.py
"""

import math
import os

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(HERE, "out")
SIZE = 1024
RADIUS = 2.4  # 环面半径：越大颗粒越密


def srgb(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple((v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4) for v in c) + (1.0,)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 24
    scene.cycles.use_denoising = False
    scene.render.resolution_x = SIZE
    scene.render.resolution_y = SIZE
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    try:
        scene.cycles.device = "GPU"
        prefs = bpy.context.preferences.addons["cycles"].preferences
        prefs.compute_device_type = "METAL"
        prefs.get_devices()
        for d in prefs.devices:
            d.use = True
    except Exception:
        pass

    bpy.ops.mesh.primitive_plane_add(size=2)
    plane = bpy.context.active_object
    mat = bpy.data.materials.new("cork")
    mat.use_nodes = True
    nt = mat.node_tree
    nodes, links = nt.nodes, nt.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    emit = nodes.new("ShaderNodeEmission")
    links.new(emit.outputs[0], out.inputs["Surface"])

    tex = nodes.new("ShaderNodeTexCoord")
    sep = nodes.new("ShaderNodeSeparateXYZ")
    links.new(tex.outputs["UV"], sep.inputs[0])

    def math_node(op, a, b=None, value=None):
        n = nodes.new("ShaderNodeMath")
        n.operation = op
        if isinstance(a, float):
            n.inputs[0].default_value = a
        else:
            links.new(a, n.inputs[0])
        if b is not None:
            if isinstance(b, float):
                n.inputs[1].default_value = b
            else:
                links.new(b, n.inputs[1])
        return n.outputs[0]

    tau = 2 * math.pi
    u = math_node("MULTIPLY", sep.outputs["X"], tau)
    v = math_node("MULTIPLY", sep.outputs["Y"], tau)
    x = math_node("MULTIPLY", math_node("COSINE", u), RADIUS)
    y = math_node("MULTIPLY", math_node("SINE", u), RADIUS)
    z = math_node("MULTIPLY", math_node("COSINE", v), RADIUS)
    w = math_node("MULTIPLY", math_node("SINE", v), RADIUS)
    comb = nodes.new("ShaderNodeCombineXYZ")
    links.new(x, comb.inputs[0])
    links.new(y, comb.inputs[1])
    links.new(z, comb.inputs[2])

    def voronoi(scale, feature="F1", randomness=1.0):
        n = nodes.new("ShaderNodeTexVoronoi")
        n.voronoi_dimensions = "4D"
        n.feature = feature
        n.inputs["Scale"].default_value = scale
        n.inputs["Randomness"].default_value = randomness
        links.new(comb.outputs[0], n.inputs["Vector"])
        links.new(w, n.inputs["W"])
        return n

    def noise(scale, detail, roughness=0.5):
        n = nodes.new("ShaderNodeTexNoise")
        n.noise_dimensions = "4D"
        n.inputs["Scale"].default_value = scale
        n.inputs["Detail"].default_value = detail
        n.inputs["Roughness"].default_value = roughness
        links.new(comb.outputs[0], n.inputs["Vector"])
        links.new(w, n.inputs["W"])
        return n

    # 颗粒：每粒一个随机深浅
    grains = voronoi(9.0)
    grain_value = nodes.new("ShaderNodeRGBToBW")
    links.new(grains.outputs["Color"], grain_value.inputs[0])
    # 颗粒之间的缝
    edges = voronoi(9.0, feature="DISTANCE_TO_EDGE")
    gap = nodes.new("ShaderNodeMapRange")
    gap.inputs["From Min"].default_value = 0.0
    gap.inputs["From Max"].default_value = 0.09
    gap.inputs["To Min"].default_value = 0.0
    gap.inputs["To Max"].default_value = 1.0
    links.new(edges.outputs["Distance"], gap.inputs["Value"])
    # 细噪声与第二层更小的颗粒
    fine = noise(70.0, 8.0, 0.55)
    small = voronoi(22.0)
    small_value = nodes.new("ShaderNodeRGBToBW")
    links.new(small.outputs["Color"], small_value.inputs[0])
    # 稀疏的小深点
    specks = voronoi(46.0)
    speck_mask = nodes.new("ShaderNodeMapRange")
    speck_mask.inputs["From Min"].default_value = 0.0
    speck_mask.inputs["From Max"].default_value = 0.06
    speck_mask.inputs["To Min"].default_value = 0.78
    speck_mask.inputs["To Max"].default_value = 1.0
    links.new(specks.outputs["Distance"], speck_mask.inputs["Value"])
    speck_rand = nodes.new("ShaderNodeRGBToBW")
    links.new(specks.outputs["Color"], speck_rand.inputs[0])
    speck_on = math_node("GREATER_THAN", speck_rand.outputs[0], 0.93)
    speck = nodes.new("ShaderNodeMix")
    speck.data_type = "FLOAT"
    links.new(speck_on, speck.inputs["Factor"])
    speck.inputs["A"].default_value = 1.0
    links.new(speck_mask.outputs[0], speck.inputs["B"])

    # 明暗：颗粒 55% + 小颗粒 25% + 细噪声 20%
    tone = math_node("ADD", math_node("MULTIPLY", grain_value.outputs[0], 0.55), math_node("MULTIPLY", small_value.outputs[0], 0.25))
    tone = math_node("ADD", tone, math_node("MULTIPLY", fine.outputs["Fac"], 0.2))
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.16
    ramp.color_ramp.elements[0].color = srgb("#B28A62")
    ramp.color_ramp.elements[1].position = 0.88
    ramp.color_ramp.elements[1].color = srgb("#DCBE99")
    mid = ramp.color_ramp.elements.new(0.52)
    mid.color = srgb("#C9A57E")
    # 很淡的大块斑驳（±3%），免得看起来像一块平平的毛毡
    mottle = noise(1.6, 3.0, 0.4)
    mottle_shift = math_node("MULTIPLY", math_node("SUBTRACT", mottle.outputs["Fac"], 0.5), 0.16)
    tone = math_node("ADD", tone, mottle_shift)
    links.new(tone, ramp.inputs[0])
    # 缝：最多压暗 12%
    gap_shade = nodes.new("ShaderNodeMapRange")
    gap_shade.inputs["To Min"].default_value = 0.88
    gap_shade.inputs["To Max"].default_value = 1.0
    links.new(gap.outputs[0], gap_shade.inputs["Value"])
    shade = math_node("MULTIPLY", gap_shade.outputs[0], speck.outputs[0])
    final = nodes.new("ShaderNodeMix")
    final.data_type = "RGBA"
    final.blend_type = "MULTIPLY"
    final.inputs["Factor"].default_value = 1.0
    links.new(ramp.outputs[0], final.inputs["A"])
    shade_rgb = nodes.new("ShaderNodeCombineColor")
    links.new(shade, shade_rgb.inputs[0])
    links.new(shade, shade_rgb.inputs[1])
    links.new(shade, shade_rgb.inputs[2])
    links.new(shade_rgb.outputs[0], final.inputs["B"])
    links.new(final.outputs["Result"], emit.inputs["Color"])
    plane.data.materials.append(mat)

    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = 2.0
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = (0, 0, 5)
    scene.camera = cam

    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "cork-soft.png")
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("[nocchi] rendered", path, flush=True)

    d = os.path.join(REPO, "Shared", "Art.xcassets", "CorkSoft.imageset")
    os.makedirs(d, exist_ok=True)
    import shutil
    shutil.copyfile(path, os.path.join(d, "cork-soft.png"))
    with open(os.path.join(d, "Contents.json"), "w") as f:
        f.write('{\n  "images" : [\n    { "filename" : "cork-soft.png", "idiom" : "universal", "scale" : "2x" }\n  ],\n'
                '  "info" : { "author" : "xcode", "version" : 1 }\n}\n')
    print("[nocchi] wrote CorkSoft.imageset", flush=True)


if __name__ == "__main__":
    main()
