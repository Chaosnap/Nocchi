#!/usr/bin/env python3
"""生成 FilmStocks.json（v0.2 调色）。只在本机调色时用；写出的 JSON 才是 App 的数据。"""
import json
import sys

OUT = sys.argv[1] if len(sys.argv) > 1 else "Packages/NocchiKit/Sources/NocchiKit/Resources/FilmStocks.json"

S = lambda *pts: [list(p) for p in pts]  # 曲线控制点
def band(hue=0, sat=1, lum=0):
    b = {}
    if hue: b["hue"] = hue
    if sat != 1: b["saturation"] = sat
    if lum: b["luminance"] = lum
    return b

stocks = []
def add(id, name, en, iso, exp, summary, swatch, tags, tone, effects, paper=None):
    s = {"id": id, "name": name, "englishName": en, "iso": iso, "exposures": exp,
         "summary": summary, "swatch": swatch, "tags": tags, "tone": tone, "effects": effects}
    if paper:
        s["paper"] = paper
    stocks.append(s)

# ───────── 即显相纸 ─────────
add("cream-600", "奶油 600", "Cream 600", 600, 10,
    "方形即显的经典味道：奶油高光、微青绿阴影、柔和反差",
    ["#F2D9A8", "#9FB49C", "#5A4B3C"], ["instant", "warm", "default"],
    {"exposure": 0.12, "temperature": 0.22, "tint": -0.06, "contrast": 1.0, "saturation": 0.86, "crossTalk": 0.05,
     "curves": {"master": S((0, 0.06), (0.25, 0.25), (0.5, 0.52), (0.75, 0.78), (1, 0.95)),
                "b": S((0, 0.06), (0.5, 0.5), (1, 0.93))},
     "hsl": {"red": band(4, 0.9), "orange": band(0, 0.92, 0.03), "yellow": band(-4, 0.85), "green": band(12, 0.72, -0.02),
             "cyan": band(0, 0.8), "blue": band(-12, 0.78)},
     "shadowTint": "#4E7A6E", "shadowTintAmount": 0.4, "highlightTint": "#F2D9A8", "highlightTintAmount": 0.35,
     "fade": 0.05, "highlightRolloff": 0.55, "skinProtect": 0.4},
    {"grain": 0.18, "grainSize": 1.2, "halation": 0.1, "bloom": 0.16, "vignette": 0.26, "edgeSoftness": 0.45},
    {"color": "#F6F2E8", "ink": "#2B2A28"})

add("crisp-800", "晶亮 800", "Crisp 800", 800, 10,
    "明亮通透的即显：干净的白、饱满而不艳俗、反差利落、阴影微青",
    ["#FFFFFF", "#7FC4E0", "#E26D8C"], ["instant", "mini", "bright"],
    {"exposure": 0.2, "temperature": -0.05, "tint": 0.02, "contrast": 1.08, "saturation": 1.04,
     "curves": {"master": S((0, 0.02), (0.25, 0.22), (0.5, 0.52), (0.75, 0.8), (1, 1)),
                "b": S((0, 0.05), (0.5, 0.51), (1, 0.99)), "g": S((0, 0.02), (0.5, 0.5), (1, 1))},
     "hsl": {"red": band(0, 1.05), "orange": band(0, 0.98, 0.04), "green": band(6, 1.04), "cyan": band(0, 1.08),
             "blue": band(-6, 1.1, -0.02), "magenta": band(0, 1.05)},
     "shadowTint": "#3E7C8C", "shadowTintAmount": 0.2,
     "highlightRolloff": 0.18, "skinProtect": 0.45},
    {"grain": 0.14, "grainSize": 1.1, "halation": 0.06, "bloom": 0.08, "vignette": 0.18, "edgeSoftness": 0.3},
    {"color": "#FAFAF7", "ink": "#2B2A28"})

# ───────── 彩色负片 ─────────
add("portrait-400", "人像 400", "Portrait 400", 400, 36,
    "人像负片：暖中性、低反差，肤色奶油般柔和，绿色收敛，高光过渡细腻",
    ["#F3D7BE", "#C9A48A", "#5E6B5A"], ["color", "warm", "portrait", "print"],
    {"exposure": 0.15, "temperature": 0.12, "tint": 0.03, "contrast": 0.94, "saturation": 0.92, "crossTalk": 0.03,
     "curves": {"master": S((0, 0.035), (0.25, 0.24), (0.5, 0.51), (0.75, 0.77), (1, 0.97)),
                "r": S((0, 0.0), (0.5, 0.51), (1, 1)), "b": S((0, 0.04), (0.5, 0.49), (1, 0.95))},
     "hsl": {"red": band(0, 0.92), "orange": band(-2, 0.9, 0.04), "yellow": band(-6, 0.84), "green": band(-14, 0.7, 0.02),
             "cyan": band(0, 0.8), "blue": band(-5, 0.84), "magenta": band(0, 0.9)},
     "shadowTint": "#4C6670", "shadowTintAmount": 0.18, "highlightTint": "#F7DEC4", "highlightTintAmount": 0.2,
     "fade": 0.03, "highlightRolloff": 0.6, "skinProtect": 0.6},
    {"grain": 0.14, "grainSize": 1.05, "halation": 0.08, "bloom": 0.1, "vignette": 0.12, "edgeSoftness": 0.1})

add("gold-200", "金黄 200", "Golden 200", 200, 36,
    "金黄色的日常负片：暖洋洋、黄与红饱满、黑位微抬，一股旧夏天的味道",
    ["#FFD36E", "#E5893F", "#6B4A2E"], ["color", "warm", "print"],
    {"exposure": 0.1, "temperature": 0.32, "tint": 0.04, "contrast": 1.06, "saturation": 1.1, "crossTalk": 0.03,
     "curves": {"master": S((0, 0.04), (0.25, 0.23), (0.5, 0.51), (0.75, 0.79), (1, 0.98)),
                "b": S((0, 0.05), (0.5, 0.47), (1, 0.9)), "r": S((0, 0.01), (0.5, 0.52), (1, 1))},
     "hsl": {"red": band(0, 1.1), "orange": band(0, 1.06, 0.02), "yellow": band(-3, 1.2, 0.02), "green": band(-15, 0.86),
             "cyan": band(0, 0.85), "blue": band(4, 0.88)},
     "highlightTint": "#FFD48A", "highlightTintAmount": 0.25,
     "fade": 0.04, "highlightRolloff": 0.35, "skinProtect": 0.35},
    {"grain": 0.15, "grainSize": 1.05, "halation": 0.12, "bloom": 0.08, "vignette": 0.16, "lightLeak": 0.04})

add("vivid-100", "艳色 100", "Vivid 100", 100, 36,
    "风光负片：高饱和、深邃的蓝天、浓郁的红，颗粒极细、画面利落",
    ["#E8463A", "#2D6FB5", "#F2C14E"], ["color", "vivid", "print"],
    {"exposure": 0.0, "temperature": -0.02, "contrast": 1.14, "saturation": 1.18,
     "curves": {"master": S((0, 0.015), (0.25, 0.21), (0.5, 0.51), (0.75, 0.8), (1, 0.99))},
     "hsl": {"red": band(2, 1.22), "orange": band(0, 1.02), "yellow": band(0, 1.1), "green": band(4, 1.1, -0.02),
             "cyan": band(0, 1.15), "blue": band(0, 1.25, -0.05), "magenta": band(0, 1.1)},
     "highlightRolloff": 0.3, "skinProtect": 0.45},
    {"grain": 0.06, "grainSize": 0.9, "halation": 0.05, "bloom": 0.04, "vignette": 0.12})

add("warm-sun-400", "暖阳 400", "Warm Sun 400", 400, 24,
    "阳光下的万能负片：暖黄、肤色健康、反差适中，带一点点漏光",
    ["#FFD28A", "#E8A86A", "#7A6040"], ["warm"],
    {"exposure": 0.22, "temperature": 0.42, "tint": 0.05, "contrast": 0.95, "saturation": 0.98, "crossTalk": 0.03,
     "curves": {"master": S((0, 0.05), (0.25, 0.25), (0.5, 0.52), (0.75, 0.78), (1, 0.97)),
                "b": S((0, 0.04), (0.5, 0.48), (1, 0.92))},
     "hsl": {"orange": band(0, 1.0, 0.03), "yellow": band(-2, 1.12), "green": band(-10, 0.85), "blue": band(0, 0.92)},
     "shadowTint": "#7A6040", "shadowTintAmount": 0.2, "highlightTint": "#FFD28A", "highlightTintAmount": 0.35,
     "fade": 0.07, "highlightRolloff": 0.45, "skinProtect": 0.4},
    {"grain": 0.16, "grainSize": 1.0, "halation": 0.14, "bloom": 0.14, "vignette": 0.15, "lightLeak": 0.1, "edgeSoftness": 0.2},
    {"color": "#F8F3E6"})

add("mint-400", "薄荷 400", "Mint 400", 400, 36,
    "通透淡彩：薄荷绿、青蓝天空、粉嫩肤色，像微微过曝的胶片",
    ["#DDEFE4", "#9CCBC0", "#4E7F86"], ["color", "pastel", "airy"],
    {"exposure": 0.3, "temperature": -0.1, "tint": -0.04, "contrast": 0.86, "saturation": 0.86,
     "curves": {"master": S((0, 0.06), (0.25, 0.28), (0.5, 0.55), (0.75, 0.8), (1, 0.97)),
                "g": S((0, 0.03), (0.5, 0.51), (1, 1)), "b": S((0, 0.06), (0.5, 0.51), (1, 0.98))},
     "hsl": {"red": band(-6, 0.82), "orange": band(0, 0.86, 0.05), "yellow": band(6, 0.82), "green": band(16, 0.76, 0.05),
             "cyan": band(0, 0.92, 0.03), "blue": band(-10, 0.82), "magenta": band(0, 0.86)},
     "shadowTint": "#5E9C96", "shadowTintAmount": 0.25,
     "fade": 0.06, "highlightRolloff": 0.6, "skinProtect": 0.5},
    {"grain": 0.14, "grainSize": 1.05, "halation": 0.06, "bloom": 0.2, "vignette": 0.06, "edgeSoftness": 0.15},
    {"color": "#F7F8F5"})

add("evergreen-400", "常青 400", "Evergreen 400", 400, 36,
    "偏冷的日常负片：浓郁的绿、清脆的反差，阴影里一点青绿",
    ["#BFD9A0", "#4E8C6A", "#2A3F4F"], ["color", "green", "print"],
    {"exposure": 0.05, "temperature": -0.08, "tint": -0.05, "contrast": 1.08, "saturation": 1.0,
     "curves": {"master": S((0, 0.02), (0.25, 0.22), (0.5, 0.51), (0.75, 0.79), (1, 0.99)),
                "g": S((0, 0.03), (0.5, 0.51), (1, 1)), "r": S((0, 0.0), (0.5, 0.49), (1, 0.98))},
     "hsl": {"red": band(-3, 1.05), "orange": band(0, 0.96, 0.02), "yellow": band(4, 0.95), "green": band(6, 1.16, -0.03),
             "cyan": band(0, 1.08), "blue": band(-4, 1.04)},
     "shadowTint": "#2F5F5C", "shadowTintAmount": 0.25,
     "highlightRolloff": 0.3, "skinProtect": 0.4},
    {"grain": 0.18, "grainSize": 1.1, "halation": 0.06, "bloom": 0.05, "vignette": 0.14})

add("everyday-200", "日常 200", "Everyday 200", 200, 36,
    "平和的日常负片：中性略偏青绿、柔和不抢戏，什么都能拍",
    ["#F1E7D2", "#9DB7A8", "#3F5866"], ["color", "print"],
    {"exposure": 0.05, "temperature": -0.06, "tint": -0.06, "contrast": 1.02, "saturation": 0.96,
     "curves": {"master": S((0, 0.03), (0.25, 0.24), (0.5, 0.51), (0.75, 0.78), (1, 0.98)),
                "b": S((0, 0.04), (0.5, 0.5), (1, 0.98))},
     "hsl": {"orange": band(0, 0.95, 0.02), "green": band(6, 0.96), "blue": band(-3, 0.9)},
     "fade": 0.03, "highlightRolloff": 0.35, "skinProtect": 0.3},
    {"grain": 0.12, "grainSize": 1.0, "halation": 0.04, "bloom": 0.05, "vignette": 0.12})

add("sea-salt-160", "海盐 160", "Sea Salt 160", 160, 36,
    "日系淡彩：通透、微青、抬起的阴影，人像干净",
    ["#F4F8F4", "#A8CCD0", "#5F8FA0"], ["pastel", "cool", "airy"],
    {"exposure": 0.32, "temperature": -0.16, "tint": -0.04, "contrast": 0.86, "saturation": 0.76,
     "curves": {"master": S((0, 0.08), (0.25, 0.3), (0.5, 0.56), (0.75, 0.8), (1, 0.98)),
                "b": S((0, 0.06), (0.5, 0.51), (1, 1))},
     "hsl": {"orange": band(0, 0.85, 0.05), "yellow": band(4, 0.8), "green": band(8, 0.78, 0.04), "blue": band(-6, 0.82)},
     "shadowTint": "#5F8FA0", "shadowTintAmount": 0.3,
     "fade": 0.06, "highlightRolloff": 0.55, "skinProtect": 0.5},
    {"grain": 0.08, "grainSize": 0.95, "bloom": 0.2, "vignette": 0.05},
    {"color": "#F7F8F5"})

add("sakura-rain-200", "樱雨 200", "Sakura Rain 200", 200, 12,
    "粉紫淡彩：低饱和、柔光，像下过雨的春天",
    ["#FFD0DC", "#C9A6C8", "#7A5A8A"], ["pastel", "soft"],
    {"exposure": 0.22, "temperature": 0.04, "tint": 0.24, "contrast": 0.86, "saturation": 0.78,
     "curves": {"master": S((0, 0.07), (0.25, 0.28), (0.5, 0.54), (0.75, 0.79), (1, 0.96)),
                "r": S((0, 0.02), (0.5, 0.52), (1, 1))},
     "hsl": {"red": band(-6, 0.86), "orange": band(-4, 0.85, 0.04), "green": band(10, 0.7), "blue": band(8, 0.85),
             "magenta": band(0, 1.08)},
     "shadowTint": "#7A5A8A", "shadowTintAmount": 0.32, "highlightTint": "#FFD6E0", "highlightTintAmount": 0.35,
     "fade": 0.06, "highlightRolloff": 0.5, "skinProtect": 0.4},
    {"grain": 0.12, "grainSize": 1.0, "halation": 0.1, "bloom": 0.42, "vignette": 0.12, "edgeSoftness": 0.35},
    {"color": "#FBF1F2", "ink": "#5A3A4A"})

add("moss-400", "青苔 400", "Moss 400", 400, 24,
    "褪色的青绿：低反差、橄榄色的绿，一点漏光",
    ["#E8EDC8", "#7FA07A", "#3F6B4A"], ["faded", "green"],
    {"exposure": 0.05, "temperature": -0.03, "tint": -0.24, "contrast": 0.88, "saturation": 0.8,
     "curves": {"master": S((0, 0.08), (0.25, 0.27), (0.5, 0.52), (0.75, 0.77), (1, 0.95)),
                "g": S((0, 0.03), (0.5, 0.51), (1, 0.99))},
     "hsl": {"red": band(0, 0.85), "yellow": band(-6, 0.85), "green": band(-14, 0.74, -0.03), "blue": band(-10, 0.7)},
     "shadowTint": "#3F6B4A", "shadowTintAmount": 0.42, "highlightTint": "#E8EDC8", "highlightTintAmount": 0.28,
     "fade": 0.08, "highlightRolloff": 0.45},
    {"grain": 0.2, "grainSize": 1.1, "bloom": 0.1, "vignette": 0.22, "lightLeak": 0.22, "edgeSoftness": 0.25},
    {"color": "#F3F3EA"})

add("old-album-100", "旧相册 100", "Old Album 100", 100, 12,
    "70 年代褪色的冲印：暖红偏色、黑位发灰、颜色像晒过太阳",
    ["#F0D8A0", "#C49A8A", "#7A5050"], ["faded", "vintage"],
    {"exposure": 0.05, "temperature": 0.32, "tint": 0.18, "contrast": 0.86, "saturation": 0.7, "crossTalk": 0.08,
     "curves": {"master": S((0, 0.1), (0.25, 0.3), (0.5, 0.53), (0.75, 0.75), (1, 0.9)),
                "b": S((0, 0.08), (0.5, 0.46), (1, 0.84))},
     "hsl": {"red": band(0, 0.9), "green": band(-20, 0.58), "cyan": band(0, 0.6), "blue": band(14, 0.55)},
     "shadowTint": "#7A5050", "shadowTintAmount": 0.35, "highlightTint": "#F0D8A0", "highlightTintAmount": 0.45,
     "fade": 0.06},
    {"grain": 0.24, "grainSize": 1.1, "bloom": 0.1, "vignette": 0.36, "lightLeak": 0.1, "edgeSoftness": 0.35},
    {"color": "#EFE6D2", "ink": "#4A3A2A"})

add("sunset-200", "晚霞 200", "Sunset 200", 200, 24,
    "橙粉色的高光、青绿色的阴影，傍晚出门就带它",
    ["#FF9A6A", "#E070A0", "#2F6A70"], ["warm", "vivid"],
    {"exposure": 0.05, "temperature": 0.26, "tint": 0.12, "contrast": 1.08, "saturation": 1.12,
     "curves": {"master": S((0, 0.03), (0.25, 0.23), (0.5, 0.51), (0.75, 0.79), (1, 0.98))},
     "hsl": {"red": band(-4, 1.14), "orange": band(0, 1.12, 0.02), "yellow": band(-6, 1.05), "green": band(10, 0.85),
             "blue": band(-10, 1.1), "magenta": band(0, 1.1)},
     "shadowTint": "#2F6A70", "shadowTintAmount": 0.45, "highlightTint": "#FF9A6A", "highlightTintAmount": 0.42,
     "highlightRolloff": 0.35, "skinProtect": 0.35},
    {"grain": 0.18, "grainSize": 1.05, "halation": 0.25, "bloom": 0.08, "vignette": 0.25, "lightLeak": 0.12},
    {"color": "#FAF2EA"})

add("lemon-soda-100", "柠檬汽水 100", "Lemon Soda 100", 100, 24,
    "明亮高调：黄绿清爽、饱和但干净，适合晴天",
    ["#FFF2A0", "#B8E07A", "#4A8A6A"], ["bright", "vivid"],
    {"exposure": 0.25, "temperature": 0.08, "tint": -0.12, "contrast": 1.05, "saturation": 1.18,
     "curves": {"master": S((0, 0.03), (0.25, 0.25), (0.5, 0.54), (0.75, 0.81), (1, 1))},
     "hsl": {"orange": band(0, 1.0, 0.04), "yellow": band(3, 1.25, 0.03), "green": band(5, 1.15, 0.04), "cyan": band(0, 1.05),
             "blue": band(-4, 1.0)},
     "shadowTint": "#4A8A6A", "shadowTintAmount": 0.18, "highlightTint": "#FFF2A0", "highlightTintAmount": 0.3,
     "highlightRolloff": 0.3, "skinProtect": 0.5},
    {"grain": 0.07, "grainSize": 0.9, "bloom": 0.1, "vignette": 0.08},
    {"color": "#FFFDF4"})

# ───────── 夜景与电影 ─────────
add("tungsten-800", "钨丝 800", "Tungsten 800", 800, 36,
    "电影卷改的夜景卷：钨丝灯下偏冷、青色阴影，灯光周围一圈红色光晕",
    ["#2B5B7A", "#E0553A", "#10202C"], ["cine", "night"],
    {"exposure": 0.05, "temperature": -0.5, "tint": 0.06, "contrast": 1.08, "saturation": 1.05,
     "curves": {"master": S((0, 0.03), (0.25, 0.22), (0.5, 0.5), (0.75, 0.79), (1, 0.98)),
                "b": S((0, 0.05), (0.5, 0.52), (1, 0.98))},
     "hsl": {"red": band(0, 1.15), "orange": band(0, 0.95, 0.03), "yellow": band(-6, 0.92), "green": band(12, 0.85),
             "cyan": band(0, 1.1), "blue": band(-8, 1.1)},
     "shadowTint": "#2F6F7A", "shadowTintAmount": 0.45, "highlightTint": "#FFB27A", "highlightTintAmount": 0.18,
     "highlightRolloff": 0.45, "skinProtect": 0.5},
    {"grain": 0.24, "grainSize": 1.3, "halation": 0.7, "bloom": 0.2, "vignette": 0.25},
    {"color": "#1E1E22", "ink": "#F2F2F2"})

add("night-flight-800", "夜航 800", "Night Flight 800", 800, 24,
    "蓝调时刻：深蓝阴影、暖橙灯光，中颗粒",
    ["#2E4A7A", "#FFB070", "#141A2A"], ["cool", "night"],
    {"exposure": -0.02, "temperature": -0.38, "tint": 0.06, "contrast": 1.14, "saturation": 1.06,
     "curves": {"master": S((0, 0.02), (0.25, 0.2), (0.5, 0.49), (0.75, 0.79), (1, 0.98)),
                "b": S((0, 0.07), (0.5, 0.53), (1, 0.97))},
     "hsl": {"orange": band(0, 1.15, 0.03), "yellow": band(-4, 1.05), "blue": band(0, 1.12, -0.03), "cyan": band(0, 0.95)},
     "shadowTint": "#1F3B6E", "shadowTintAmount": 0.55, "highlightTint": "#FFB070", "highlightTintAmount": 0.25,
     "highlightRolloff": 0.4},
    {"grain": 0.32, "grainSize": 1.35, "halation": 0.35, "bloom": 0.15, "vignette": 0.4},
    {"color": "#1E1E22", "ink": "#F2F2F2"})

add("neon-800", "霓虹 800", "Neon 800", 800, 24,
    "霓虹夜：品红与红色饱满、紫色阴影，灯光有光晕",
    ["#FF6A4A", "#C04AA0", "#3A2A6A"], ["night", "vivid"],
    {"exposure": 0.05, "temperature": 0.1, "tint": 0.18, "contrast": 1.18, "saturation": 1.26, "crossTalk": 0.02,
     "curves": {"master": S((0, 0.02), (0.25, 0.2), (0.5, 0.5), (0.75, 0.8), (1, 0.99))},
     "hsl": {"red": band(0, 1.2), "orange": band(0, 1.0, 0.02), "blue": band(10, 1.2), "purple": band(0, 1.2),
             "magenta": band(0, 1.25)},
     "shadowTint": "#3A2A6A", "shadowTintAmount": 0.4, "highlightTint": "#FF6A4A", "highlightTintAmount": 0.3,
     "highlightRolloff": 0.35, "skinProtect": 0.3},
    {"grain": 0.3, "grainSize": 1.3, "halation": 0.6, "bloom": 0.25, "vignette": 0.3},
    {"color": "#141418", "ink": "#FFE8F0"})

add("midnight-1600", "午夜 1600", "Midnight 1600", 1600, 24,
    "高感夜拍：粗颗粒、压暗、阴影微绿，像深夜的便利店",
    ["#E8F0D0", "#4A6A5A", "#0E1410"], ["night", "grainy"],
    {"exposure": -0.12, "temperature": -0.08, "tint": -0.18, "contrast": 1.2, "saturation": 0.86,
     "curves": {"master": S((0, 0.04), (0.25, 0.2), (0.5, 0.48), (0.75, 0.76), (1, 0.93)),
                "g": S((0, 0.03), (0.5, 0.51), (1, 1))},
     "hsl": {"orange": band(0, 0.9, 0.02), "green": band(-6, 0.9), "blue": band(-6, 0.8)},
     "shadowTint": "#2A4A3A", "shadowTintAmount": 0.5, "highlightTint": "#E8F0D0", "highlightTintAmount": 0.2,
     "fade": 0.03, "highlightRolloff": 0.4},
    {"grain": 0.68, "grainSize": 2.0, "halation": 0.28, "bloom": 0.1, "vignette": 0.48},
    {"color": "#1A1A1A", "ink": "#EDEDED"})

# ───────── 黑白 ─────────
add("grit-400", "粗粒 400", "Grit 400", 400, 36,
    "经典高反差黑白：深黑、亮白、颗粒粗犷，街头和人像都有劲",
    ["#F2F2F2", "#7A7A7A", "#0E0E0E"], ["bw", "contrast"],
    {"monochrome": True, "monoMix": [0.33, 0.55, 0.12], "exposure": 0.05, "contrast": 1.28,
     "curves": {"master": S((0, 0.0), (0.18, 0.11), (0.5, 0.52), (0.82, 0.9), (1, 1))},
     "blackLift": 0.015, "whiteCap": 0.985},
    {"grain": 0.5, "grainSize": 1.5, "halation": 0.05, "vignette": 0.26, "edgeSoftness": 0.1},
    {"color": "#F4F1EA", "ink": "#151515"})

add("fine-100", "细腻 100", "Fine 100", 100, 36,
    "细腻黑白：灰阶丰富、颗粒极细，中间调像丝绒",
    ["#F5F3EE", "#A3A09A", "#232220"], ["bw", "soft"],
    {"monochrome": True, "monoMix": [0.24, 0.6, 0.16], "contrast": 1.06,
     "curves": {"master": S((0, 0.025), (0.25, 0.22), (0.5, 0.5), (0.75, 0.79), (1, 0.98))},
     "highlightRolloff": 0.45},
    {"grain": 0.08, "grainSize": 0.9, "vignette": 0.14},
    {"color": "#F5F3EE", "ink": "#232220"})

add("silver-400", "银盐 400", "Silver 400", 400, 36,
    "柔和黑白：低反差、略带暖调的银盐纸",
    ["#EFE7DA", "#A89C8A", "#2A2622"], ["bw", "soft"],
    {"monochrome": True, "monoMix": [0.3, 0.59, 0.11], "contrast": 0.96,
     "curves": {"master": S((0, 0.05), (0.25, 0.25), (0.5, 0.51), (0.75, 0.77), (1, 0.96))},
     "monoTone": "#C8A880", "monoToneAmount": 0.32, "fade": 0.03, "highlightRolloff": 0.4},
    {"grain": 0.34, "grainSize": 1.25, "bloom": 0.1, "vignette": 0.24, "edgeSoftness": 0.2},
    {"color": "#F3EEE4", "ink": "#2A2622"})

add("old-news-100", "旧报纸 100", "Old News 100", 100, 36,
    "旧报纸一样的黑白：极高反差、发黄的纸、粗颗粒",
    ["#F4F1EA", "#8A8A8A", "#121212"], ["bw", "contrast"],
    {"monochrome": True, "monoMix": [0.35, 0.5, 0.15], "contrast": 1.5,
     "curves": {"master": S((0, 0.0), (0.22, 0.1), (0.5, 0.52), (0.78, 0.93), (1, 1))},
     "monoTone": "#E6DCC4", "monoToneAmount": 0.14, "blackLift": 0.03, "whiteCap": 0.96},
    {"grain": 0.55, "grainSize": 1.6, "vignette": 0.32},
    {"color": "#F4F1EA", "ink": "#151515"})

add("sepia-80", "旧时光 80", "Old Days 80", 80, 10,
    "棕褐色调的老照片：低反差、柔边、暗角、明显颗粒",
    ["#E8D5B0", "#A07850", "#3A2818"], ["bw", "vintage", "sepia"],
    {"monochrome": True, "monoMix": [0.4, 0.45, 0.15], "contrast": 0.9,
     "curves": {"master": S((0, 0.06), (0.25, 0.27), (0.5, 0.52), (0.75, 0.76), (1, 0.92))},
     "monoTone": "#B08850", "monoToneAmount": 0.78, "fade": 0.04, "blackLift": 0.02, "whiteCap": 0.96},
    {"grain": 0.4, "grainSize": 1.4, "bloom": 0.15, "vignette": 0.45, "edgeSoftness": 0.5},
    {"color": "#F1EADB", "ink": "#3A2A1A"})

# ───────── 大头贴 ─────────
add("booth-flash-400", "闪光 400", "Booth Flash 400", 400, 16,
    "照相亭的白光闪灯：明亮的肤色、清脆的反差、高光微微过曝",
    ["#FFF6F0", "#F4B8B0", "#5A4A50"], ["booth", "bright"],
    {"exposure": 0.3, "temperature": -0.04, "tint": 0.06, "contrast": 1.18, "saturation": 1.02,
     "curves": {"master": S((0, 0.02), (0.25, 0.23), (0.5, 0.54), (0.75, 0.82), (1, 1))},
     "hsl": {"red": band(0, 1.04), "orange": band(0, 0.96, 0.05), "magenta": band(0, 1.05)},
     "highlightTint": "#FFF6F0", "highlightTintAmount": 0.25,
     "highlightRolloff": 0.25, "skinProtect": 0.4},
    {"grain": 0.15, "grainSize": 1.1, "bloom": 0.3, "vignette": 0.2, "edgeSoftness": 0.15},
    {"color": "#FFFFFF"})

add("booth-silver-400", "照相亭黑白 400", "Booth Silver 400", 400, 16,
    "老式照相亭的黑白：闪光直打、高反差，印在略暖的银盐纸上",
    ["#F4F1EA", "#9A948A", "#1C1A18"], ["booth", "bw"],
    {"monochrome": True, "monoMix": [0.38, 0.5, 0.12], "exposure": 0.25, "contrast": 1.3,
     "curves": {"master": S((0, 0.0), (0.2, 0.12), (0.5, 0.53), (0.8, 0.9), (1, 1))},
     "monoTone": "#C9B496", "monoToneAmount": 0.3, "blackLift": 0.02, "whiteCap": 0.965},
    {"grain": 0.26, "grainSize": 1.2, "bloom": 0.2, "vignette": 0.22, "edgeSoftness": 0.12},
    {"color": "#F4F1EA", "ink": "#1C1A18"})


def dump(obj):
    return json.dumps(obj, ensure_ascii=False, separators=(", ", ": "))

lines = ["{", '  "version": 2,', '  "stocks": [']
for i, s in enumerate(stocks):
    block = ["    {"]
    keys = ["id", "name", "englishName", "iso", "exposures", "summary", "swatch", "tags"]
    for k in keys:
        block.append(f'      "{k}": {dump(s[k])},')
    block.append(f'      "tone": {dump(s["tone"])},')
    tail = "," if "paper" in s else ""
    block.append(f'      "effects": {dump(s["effects"])}{tail}')
    if "paper" in s:
        block.append(f'      "paper": {dump(s["paper"])}')
    block.append("    }" + ("," if i < len(stocks) - 1 else ""))
    lines.extend(block)
lines += ["  ]", "}"]
open(OUT, "w").write("\n".join(lines) + "\n")
ids = [s["id"] for s in stocks]
assert len(ids) == len(set(ids)), "duplicate ids"
print(len(stocks), "stocks →", OUT)
