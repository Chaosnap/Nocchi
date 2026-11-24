"""取卡片盒分隔卡标签的纸色（给 NocchiUI 的 `DividerPaper`）。

悬停时分隔卡抬起一截，露出来的纸面要和渲染图里的标签同一个颜色；重新渲染 `CardBoxBase` 后跑一遍，
把打印出来的 `mid` 值抄进 `Packages/NocchiKit/Sources/NocchiUI/CardBox/CardBoxLift.swift` 的 `DividerPaper.samples`。

用法：
    /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python design/blender/cardbox/sample_tab_paper.py
"""

import os
import re

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
SWIFT = os.path.join(REPO, "Packages", "NocchiKit", "Sources", "NocchiUI", "CardBox", "CardBoxHotspots.swift")
IMAGE = os.path.join(REPO, "Shared", "Art.xcassets", "CardBoxBase.imageset", "card-box-base.png")

src = open(SWIFT).read()
faces = []
for m in re.finditer(r"Tab\(slot: (\d+), center: CGPoint\(x: ([\d.]+), y: ([\d.]+)\), face: \[(.*?)\]\)", src):
    pts = [(float(a), float(b)) for a, b in re.findall(r"x: ([\d.]+), y: ([\d.]+)", m.group(4))]
    faces.append((int(m.group(1)), pts))

img = bpy.data.images.load(IMAGE)
w, h = img.size
px = img.pixels[:]


def sample(x, y):
    X, Y = int(x * w), int((1 - y) * h)
    i = (Y * w + X) * 4
    return tuple(round(v * 255) for v in px[i:i + 3])


def lerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


for slot, (tl, tr, br, bl) in faces:
    top = lerp(tl, tr, 0.5)
    bottom = lerp(bl, br, 0.5)
    print(slot, "mid", sample(*lerp(top, bottom, 0.55)))
