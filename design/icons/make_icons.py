#!/usr/bin/env python3
"""Nocchi 的网页 / README 图标（SVG，手写路径，原创）。

两种：
  website/public/icons/feature-<name>.svg   文档站首页的功能卡片：macOS 圆角瓷砖式的搪瓷小砖（DESIGN.md 的配色），
                                            上面一枚象牙白的线条图形，顶上一道柔光。
  website/public/icons/glyph-<name>.svg     README 的导航和标题：单色线条图形（浅陶土色，深浅背景都看得清）。

图形都画在 24 × 24 的格子里，线宽 1.6、圆头圆角，一套笔法。

用法：python3 design/icons/make_icons.py
"""

import os

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "website", "public", "icons")

GLYPHS = {
    # 相机：机身、取景器凸台、镜头、闪光灯。
    "camera": """
        <rect x="3" y="7.5" width="18" height="12.5" rx="2.6"/>
        <path d="M8.2 7.5 L9.6 4.8 H14.4 L15.8 7.5"/>
        <circle cx="12" cy="13.6" r="3.7"/>
        <circle cx="12" cy="13.6" r="1.4"/>
        <circle cx="17.6" cy="10.3" r="0.55" fill="currentColor"/>
    """,
    # 一张即显相片：白边、窗口里的太阳和山、底边一行题字。
    "develop": """
        <rect x="5" y="3" width="14" height="18" rx="1.6"/>
        <rect x="7.2" y="5.2" width="9.6" height="9.6" rx="0.6"/>
        <circle cx="14.1" cy="8" r="1.15"/>
        <path d="M7.6 13.9 L10.3 11 L12.3 12.8 L13.9 11.5 L16.4 13.9"/>
        <path d="M8.4 18 H12.8"/>
    """,
    # 胶卷罐：罐身、罐盖、片轴、伸出来的片头和齿孔。
    "film": """
        <rect x="4.5" y="6.5" width="10.5" height="13.5" rx="1.8"/>
        <rect x="6" y="4.2" width="7.5" height="2.3" rx="0.7"/>
        <path d="M8.7 4.2 V2.8 H10.8 V4.2"/>
        <path d="M15 9 H20 V16 H15"/>
        <path d="M16.6 11 H18.4 M16.6 13.9 H18.4"/>
        <path d="M7 10.5 H12.5 M7 13.2 H12.5"/>
    """,
    # 两张叠着的相纸（不同的模板）。
    "papers": """
        <g transform="rotate(-9 9 12.5)"><rect x="3.5" y="5" width="11" height="14.5" rx="1.2"/></g>
        <g transform="rotate(7 15 11.5)"><rect x="9.5" y="3.8" width="11" height="14.5" rx="1.2"/>
        <rect x="11.3" y="5.6" width="7.4" height="7.4" rx="0.5"/><path d="M12 15.8 H16"/></g>
    """,
    # 大头贴机：拱顶机身、橱窗、开始按钮。
    "booth": """
        <path d="M5.5 21 V9.5 A6.5 6.5 0 0 1 18.5 9.5 V21"/>
        <path d="M4 21 H20"/>
        <rect x="8.2" y="9.2" width="7.6" height="6.2" rx="1"/>
        <circle cx="12" cy="18.4" r="1.15"/>
        <path d="M9.4 4.9 L8.9 4.1 M14.6 4.9 L15.1 4.1 M12 3.2 V2.4"/>
    """,
    # 钢笔：笔身、笔尖、一道写出来的弧线。
    "pen": """
        <path d="M15.2 4.3 L19.7 8.8 L10.2 18.3 L5 19 L5.7 13.8 Z"/>
        <path d="M13.2 6.3 L17.7 10.8"/>
        <path d="M5.7 13.8 L10.2 18.3"/>
        <path d="M4 21.4 C7 20.6 9.4 21.6 12.6 20.8"/>
    """,
    # 卡片盒：盒身、把手孔、立着的分隔卡与卡片。
    "box": """
        <path d="M3 11.5 H21 V19.6 A1.4 1.4 0 0 1 19.6 21 H4.4 A1.4 1.4 0 0 1 3 19.6 Z"/>
        <path d="M5.4 11.5 V6.6 H9.4 L10.4 5 H12 V11.5"/>
        <path d="M13 11.5 V5.4 H18.6 V11.5"/>
        <path d="M10 16 H14"/>
    """,
    # 刘海暂存架：刘海、往里收的箭头、托盘。
    "shelf": """
        <path d="M7 3 H17 C17 4.6 16.1 5.5 14.6 5.5 H9.4 C7.9 5.5 7 4.6 7 3 Z"/>
        <path d="M12 8.3 V14.6 M9.2 11.9 L12 14.7 L14.8 11.9"/>
        <path d="M4 15 V19 A1.5 1.5 0 0 0 5.5 20.5 H18.5 A1.5 1.5 0 0 0 20 19 V15"/>
    """,
    # 锁：锁梁、锁身、钥匙孔。
    "lock": """
        <path d="M8 10.5 V8 A4 4 0 0 1 16 8 V10.5"/>
        <rect x="5.5" y="10.5" width="13" height="10" rx="2.4"/>
        <circle cx="12" cy="14.8" r="1.25"/>
        <path d="M12 16 V17.6"/>
    """,
    # 翻开的书。
    "book": """
        <path d="M12 6.6 C10 5.1 7 4.6 4 5.1 V18.6 C7 18.1 10 18.6 12 20.1 C14 18.6 17 18.1 20 18.6 V5.1 C17 4.6 14 5.1 12 6.6 Z"/>
        <path d="M12 6.6 V20.1"/>
    """,
    # 中文文档：翻开的书 + 一个「中」字。
    "zh": """
        <path d="M12 6.6 C10 5.1 7 4.6 4 5.1 V18.6 C7 18.1 10 18.6 12 20.1 C14 18.6 17 18.1 20 18.6 V5.1 C17 4.6 14 5.1 12 6.6 Z"/>
        <path d="M12 6.6 V20.1"/>
        <path d="M14 9.6 H18.2 V13.4 H14 Z M16.1 8.4 V15"/>
    """,
    # 四角星（亮点）。
    "sparkle": """
        <path d="M12 3 C12.6 8.6 15.4 11.4 21 12 C15.4 12.6 12.6 15.4 12 21 C11.4 15.4 8.6 12.6 3 12 C8.6 11.4 11.4 8.6 12 3 Z"/>
        <path d="M19 3.6 V6.4 M17.6 5 H20.4"/>
    """,
    # 相框里的风景：截图。
    "image": """
        <rect x="3" y="4.5" width="18" height="15" rx="2"/>
        <circle cx="8.6" cy="9.6" r="1.6"/>
        <path d="M3.4 17.6 L9 12.6 L12.6 15.8 L15.4 13.4 L20.6 17.8"/>
    """,
    # 下载：箭头落进托盘。
    "download": """
        <path d="M12 3.6 V14.6 M7.8 10.6 L12 14.8 L16.2 10.6"/>
        <path d="M4 15.4 V18.6 A1.8 1.8 0 0 0 5.8 20.4 H18.2 A1.8 1.8 0 0 0 20 18.6 V15.4"/>
    """,
    # 更新日志：一页纸上的几行字。
    "notes": """
        <path d="M6 3.5 H14.5 L18.5 7.5 V19.6 A1.4 1.4 0 0 1 17.1 21 H6.9 A1.4 1.4 0 0 1 5.5 19.6 V4 Z"/>
        <path d="M14.2 3.6 V7.8 H18.4"/>
        <path d="M8.6 11.4 H15.4 M8.6 14.4 H15.4 M8.6 17.4 H12.6"/>
    """,
    # 键帽：⌘ 键（玩法）。
    "key": """
        <rect x="3.5" y="3.5" width="17" height="17" rx="3.4"/>
        <path d="M10 10 H14 V14 H10 Z"/>
        <path d="M10 10 H8.8 A1.6 1.6 0 1 1 10 8.8 Z M14 10 V8.8 A1.6 1.6 0 1 1 15.2 10 Z M14 14 H15.2 A1.6 1.6 0 1 1 14 15.2 Z M10 14 V15.2 A1.6 1.6 0 1 1 8.8 14 Z"/>
    """,
    # 指南针：现在做到哪。
    "compass": """
        <circle cx="12" cy="12" r="8.6"/>
        <path d="M15.4 8.6 L13.4 13.4 L8.6 15.4 L10.6 10.6 Z"/>
        <circle cx="12" cy="12" r="0.7" fill="currentColor"/>
    """,
    # 扳手：怎么构建。
    "wrench": """
        <path d="M14.6 3.6 A5 5 0 0 0 10.4 10.2 L3.8 16.8 A1.9 1.9 0 0 0 6.5 19.5 L13.1 12.9 A5 5 0 0 0 19.7 8.7 L16.5 9.5 L14.1 9 L13.6 6.6 Z"/>
    """,
    # 心：参与。
    "heart": """
        <path d="M12 20 C7.2 16.6 3.6 13.4 3.6 9.3 A4.4 4.4 0 0 1 12 7.2 A4.4 4.4 0 0 1 20.4 9.3 C20.4 13.4 16.8 16.6 12 20 Z"/>
    """,
    # 卷轴：许可。
    "scroll": """
        <path d="M7 4 H17.4 A2.1 2.1 0 0 1 17.4 8.2 H16 V18 A2.5 2.5 0 0 1 13.5 20.5 H6.4"/>
        <path d="M7 4 A2.1 2.1 0 0 0 7 8.2 H8.4 V18 A2.5 2.5 0 0 1 6.4 20.5 A2.3 2.3 0 0 1 4.1 18.2 V17 H11 V18.2 A2.3 2.3 0 0 0 13.3 20.5"/>
        <path d="M10.6 11 H13.6 M10.6 13.8 H13.6"/>
    """,
    # 笔记本电脑（macOS）。
    "laptop": """
        <path d="M5 16.5 V6.4 A1.4 1.4 0 0 1 6.4 5 H17.6 A1.4 1.4 0 0 1 19 6.4 V16.5"/>
        <path d="M2.8 16.5 H21.2 L20.4 18.6 A1.5 1.5 0 0 1 19 19.5 H5 A1.5 1.5 0 0 1 3.6 18.6 Z"/>
        <path d="M10.4 5 H13.6 V5.9 A0.7 0.7 0 0 1 12.9 6.6 H11.1 A0.7 0.7 0 0 1 10.4 5.9 Z"/>
    """,
    # 手机（iPhone）。
    "phone": """
        <rect x="6.5" y="2.8" width="11" height="18.4" rx="2.6"/>
        <rect x="10" y="4.6" width="4" height="1.4" rx="0.7"/>
        <path d="M10.8 18.6 H13.2"/>
    """,
    # 刘海：屏幕顶上的黑岛和吐出来的一截相纸。
    "notch": """
        <path d="M3 4 H21"/>
        <path d="M8 4 H16 C16 6 15.1 7 13.6 7 H10.4 C8.9 7 8 6 8 4 Z"/>
        <path d="M9 9.2 H15 V19.4 A1 1 0 0 1 14 20.4 H10 A1 1 0 0 1 9 19.4 Z"/>
        <path d="M10.4 10.6 H13.6 V14.4 H10.4 Z"/>
    """,
}

# 功能卡片：图形 → 搪瓷小砖的上下两色（DESIGN.md §1.1 的配色往亮 / 暗各推一点）。
FEATURES = {
    "shoot": ("camera", "#DE7A55", "#A8442B"),
    "develop": ("develop", "#E6BD63", "#B4852C"),
    "film": ("film", "#93664A", "#4A3021"),
    "papers": ("papers", "#4A8580", "#244A47"),
    "booth": ("booth", "#C44A37", "#7A2418"),
    "decorate": ("pen", "#4D71B8", "#26407A"),
    "album": ("box", "#8F8A4F", "#585430"),
    "shelf": ("shelf", "#5C5751", "#2A2725"),
    "privacy": ("lock", "#D5B676", "#9C7A3E"),
}

GLYPH_COLOR = "#D9744F"
IVORY = "#FBF3E7"


def glyph_svg(body, color):
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="{color}" color="{color}" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">{body.strip()}</svg>
'''


def tile_svg(body, top, bottom, name):
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="56" height="56" viewBox="0 0 56 56">
  <defs>
    <linearGradient id="{name}-g" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="{top}"/>
      <stop offset="1" stop-color="{bottom}"/>
    </linearGradient>
    <linearGradient id="{name}-h" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.42"/>
      <stop offset="0.45" stop-color="#FFFFFF" stop-opacity="0"/>
    </linearGradient>
    <radialGradient id="{name}-s" cx="0.32" cy="0.12" r="0.75">
      <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.22"/>
      <stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <rect x="3" y="4.5" width="50" height="50" rx="12.5" fill="#000000" fill-opacity="0.18"/>
  <rect x="3" y="2.5" width="50" height="50" rx="12.5" fill="url(#{name}-g)"/>
  <rect x="3" y="2.5" width="50" height="50" rx="12.5" fill="url(#{name}-s)"/>
  <rect x="3.5" y="3" width="49" height="49" rx="12" fill="none" stroke="url(#{name}-h)" stroke-width="1"/>
  <g transform="translate(12 11.5) scale(1.333)" fill="none" stroke="{IVORY}" color="{IVORY}" stroke-width="1.55" stroke-linecap="round" stroke-linejoin="round">{body.strip()}</g>
</svg>
'''


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, body in GLYPHS.items():
        with open(os.path.join(OUT, f"glyph-{name}.svg"), "w", encoding="utf-8") as f:
            f.write(glyph_svg(body, GLYPH_COLOR))
    for name, (glyph, top, bottom) in FEATURES.items():
        with open(os.path.join(OUT, f"feature-{name}.svg"), "w", encoding="utf-8") as f:
            f.write(tile_svg(GLYPHS[glyph], top, bottom, name))
    print(f"wrote {len(GLYPHS)} glyphs and {len(FEATURES)} feature tiles to {os.path.normpath(OUT)}")


main()
