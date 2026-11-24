#!/usr/bin/env python3
"""Nocchi 胶卷色调离线预览（开发工具，不参与构建，CI 不跑它）。

把 `Packages/NocchiKit/Sources/NocchiKit/Resources/FilmStocks.json` 里的配方，
用与 `Film/ToneRecipe.swift`、`Film/ColorMath.swift` 逐行对应的 numpy 实现烘焙成
33³ LUT（和 App 一样做三线性查表），套到测试照片上；再粗略模拟 `FilmProcessor`
的光晕、柔焦、柔边、漏光、暗角与颗粒，拼成一张张联系表，用眼睛挑毛病。

只依赖 numpy 与 OpenImageIO —— Blender 自带的 Python 两样都有：

    PY=$(ls /Applications/Blender.app/Contents/Resources/*/python/bin/python3* | head -1)
    # 合成一张肤色 + 色卡测试图（确定性的，不依赖任何第三方图片）
    $PY scripts/film/preview_looks.py chart --out /tmp/nocchi-film/chart.png
    # 联系表：每一行一卷胶卷，每一列一张照片（第一行是原图）
    $PY scripts/film/preview_looks.py sheet --out /tmp/nocchi-film/contact.png \
        /tmp/nocchi-film/chart.png photo1.png photo2.png
    # 只看某几卷、放大看颗粒
    $PY scripts/film/preview_looks.py sheet --stocks cream-600,grit-400 --cell 480 --out ...

测试照片请放在仓库外（可以用 `sips -s format png` 把系统自带的桌面图片转出来），
不要把第三方图片提交进仓库。

改 Swift 里的色彩数学时，同步改这里（函数名一一对应）；FilmProcessor 的效果只是近似。
"""

import argparse
import json
import math
import os
import sys

import numpy as np

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
STOCKS_JSON = os.path.join(REPO, "Packages", "NocchiKit", "Sources", "NocchiKit", "Resources", "FilmStocks.json")

REC709 = np.array([0.2126, 0.7152, 0.0722])
HUE_BAND_CENTERS = np.array([0.0, 30.0, 60.0, 120.0, 180.0, 240.0, 270.0, 300.0])
HSL_BAND_NAMES = ["red", "orange", "yellow", "green", "cyan", "blue", "purple", "magenta"]


# ---------------------------------------------------------------------------
# ColorMath.swift
# ---------------------------------------------------------------------------

def clamp01(x):
    return np.clip(x, 0.0, 1.0)


def srgb_to_linear(c):
    c = np.asarray(c, dtype=np.float64)
    return np.where(c <= 0.04045, c / 12.92, np.power((np.maximum(c, 0.04045) + 0.055) / 1.055, 2.4))


def linear_to_srgb(c):
    v = np.maximum(np.asarray(c, dtype=np.float64), 0.0)
    return np.where(v <= 0.0031308, v * 12.92, 1.055 * np.power(np.maximum(v, 0.0031308), 1.0 / 2.4) - 0.055)


def luminance(c):
    return c @ REC709


def smoothstep(e0, e1, x):
    t = clamp01((x - e0) / (e1 - e0))
    return t * t * (3.0 - 2.0 * t)


def mix(a, b, t):
    return a + (b - a) * t


def soft_light(base, blend):
    return (1.0 - 2.0 * blend) * base * base + 2.0 * blend * base


def contrast_curve(x, k):
    x = clamp01(x)
    if k <= 0 or abs(k - 1) <= 0.0001:
        return x
    a = np.power(x, k)
    b = np.power(1.0 - x, k)
    s = a + b
    return np.where(s > 0, a / np.where(s > 0, s, 1.0), x)


def hsv(c):
    maxc = c.max(axis=-1)
    minc = c.min(axis=-1)
    d = maxc - minc
    s = np.where(maxc > 0, d / np.where(maxc > 0, maxc, 1.0), 0.0)
    r, g, b = c[..., 0], c[..., 1], c[..., 2]
    safe = np.where(d > 1e-7, d, 1.0)
    h = np.where(maxc == r, 60.0 * ((g - b) / safe),
                 np.where(maxc == g, 60.0 * ((b - r) / safe + 2.0), 60.0 * ((r - g) / safe + 4.0)))
    h = np.where(d > 1e-7, h, 0.0)
    h = np.where(h < 0, h + 360.0, h)
    h = np.where(h >= 360.0, h - 360.0, h)
    return h, s, maxc


def rgb_from_hsv(h, s, v):
    hh = np.mod(h, 360.0)
    chroma = v * s
    hp = hh / 60.0
    x = chroma * (1.0 - np.abs(np.mod(hp, 2.0) - 1.0))
    i = np.clip(np.floor(hp).astype(int), 0, 5)
    z = np.zeros_like(chroma)
    conds = [i == 0, i == 1, i == 2, i == 3, i == 4]
    r = np.select(conds, [chroma, x, z, z, x], chroma)
    g = np.select(conds, [x, chroma, chroma, x, z], z)
    b = np.select(conds, [z, z, x, chroma, chroma], x)
    m = v - chroma
    return np.stack([r + m, g + m, b + m], axis=-1)


def hue_band_weights(h):
    hh = np.mod(h, 360.0)
    lower = np.clip(np.searchsorted(HUE_BAND_CENTERS, hh, side="right") - 1, 0, 7)
    upper = (lower + 1) % 8
    start = HUE_BAND_CENTERS[lower]
    end = np.where(upper == 0, 360.0, HUE_BAND_CENTERS[upper])
    t = clamp01((hh - start) / (end - start))
    s = np.sin(t * np.pi / 2.0)
    return lower, upper, s * s


def with_luminance(c, target):
    y = luminance(c)
    t = clamp01(target)
    up = (t > y) & (y < 0.99999)
    down = (t < y) & (y > 0.00001)
    k = np.where(up, (t - y) / np.where(up, 1.0 - y, 1.0), 0.0)
    out = np.where(up[..., None], c + (1.0 - c) * k[..., None], c)
    scale = np.where(down, t / np.where(down, y, 1.0), 1.0)
    return np.where(down[..., None], c * scale[..., None], out)


def scale_chroma(c, m):
    m = np.broadcast_to(np.asarray(m, dtype=np.float64), c.shape[:-1])
    y = luminance(c)
    gray = y[..., None]
    d = c - gray
    low = clamp01(gray + d * np.maximum(m, 0.0)[..., None])
    limit = np.full(c.shape[:-1], np.inf)
    for i in range(3):
        di = d[..., i]
        pos = di > 1e-6
        neg = di < -1e-6
        limit = np.where(pos, np.minimum(limit, (1.0 - y) / np.where(pos, di, 1.0)), limit)
        limit = np.where(neg, np.minimum(limit, -y / np.where(neg, di, 1.0)), limit)
    room = np.maximum(limit - 1.0, 0.0)
    valid = (limit < 1e6) & (room > 1e-6)
    safe_room = np.where(valid, room, 1.0)
    with np.errstate(over="ignore", invalid="ignore"):
        k = np.where(valid & (m > 1), 1.0 + room * (1.0 - np.exp(-(np.maximum(m, 1.0) - 1.0) / safe_room)), 1.0)
    high = np.where(valid[..., None], clamp01(gray + d * k[..., None]), c)
    return np.where((m <= 1)[..., None], low, high)


def skin_weight(c):
    h, s, v = hsv(c)
    hh = np.where(h > 180.0, h - 360.0, h)
    hue_gate = smoothstep(-5.0, 12.0, hh) * (1.0 - smoothstep(38.0, 55.0, hh))
    sat_gate = smoothstep(0.06, 0.16, s) * (1.0 - smoothstep(0.6, 0.85, s))
    value_gate = smoothstep(0.12, 0.3, v)
    return np.where((s > 0.02) & (v > 0.08), hue_gate * sat_gate * value_gate, 0.0)


def toning_color(rgb):
    return clamp01(rgb - luminance(rgb) + 0.5)


def hex_rgb(value):
    if value is None:
        return None
    s = value.strip().lstrip("#")
    if len(s) != 6:
        return None
    try:
        n = int(s, 16)
    except ValueError:
        return None
    return np.array([(n >> 16) & 0xFF, (n >> 8) & 0xFF, n & 0xFF], dtype=np.float64) / 255.0


class MonotoneCurve:
    """MonotoneCurve（Fritsch–Carlson），与 Swift 版逐行对应。"""

    def __init__(self, points):
        pts = sorted(((min(max(float(p[0]), 0.0), 1.0), min(max(float(p[1]), 0.0), 1.0)) for p in points),
                     key=lambda p: p[0])
        unique = []
        for p in pts:
            if unique and abs(unique[-1][0] - p[0]) < 1e-5:
                unique[-1] = p
            else:
                unique.append(p)
        if not unique or unique[0][0] > 1e-5:
            unique.insert(0, (0.0, 0.0))
        if unique[-1][0] < 1 - 1e-5:
            unique.append((1.0, 1.0))
        n = len(unique)
        x = [p[0] for p in unique]
        y = [p[1] for p in unique]
        secant = [(y[i + 1] - y[i]) / (x[i + 1] - x[i]) for i in range(n - 1)]
        m = [0.0] * n
        m[0] = secant[0]
        m[n - 1] = secant[n - 2]
        for i in range(1, n - 1):
            m[i] = 0.0 if secant[i - 1] * secant[i] <= 0 else (secant[i - 1] + secant[i]) / 2.0
        for i in range(n - 1):
            if abs(secant[i]) < 1e-9:
                m[i] = 0.0
                m[i + 1] = 0.0
                continue
            a = m[i] / secant[i]
            b = m[i + 1] / secant[i]
            s = a * a + b * b
            if s > 9:
                t = 3.0 / math.sqrt(s)
                m[i] = t * a * secant[i]
                m[i + 1] = t * b * secant[i]
        self.xs = np.array(x)
        self.ys = np.array(y)
        self.m = np.array(m)

    @property
    def is_identity(self):
        return bool(np.all(np.abs(self.xs - self.ys) < 1e-5))

    def __call__(self, value):
        xs, ys, m = self.xs, self.ys, self.m
        n = len(xs)
        v = np.asarray(value, dtype=np.float64)
        i = np.clip(np.searchsorted(xs, v, side="left") - 1, 0, n - 2)
        h = xs[i + 1] - xs[i]
        t = (v - xs[i]) / h
        t2 = t * t
        t3 = t2 * t
        h00 = 2 * t3 - 3 * t2 + 1
        h10 = t3 - 2 * t2 + t
        h01 = 3 * t2 - 2 * t3
        h11 = t3 - t2
        out = h00 * ys[i] + h10 * h * m[i] + h01 * ys[i + 1] + h11 * h * m[i + 1]
        out = np.where(v <= xs[0], ys[0], out)
        return np.where(v >= xs[n - 1], ys[n - 1], out)


# ---------------------------------------------------------------------------
# ToneRecipe.swift（ToneProgram）
# ---------------------------------------------------------------------------

TONE_DEFAULTS = {
    "exposure": 0.0, "temperature": 0.0, "tint": 0.0, "contrast": 1.0, "blackLift": 0.0, "whiteCap": 1.0,
    "saturation": 1.0, "crossTalk": 0.0, "shadowTint": None, "shadowTintAmount": 0.0, "highlightTint": None,
    "highlightTintAmount": 0.0, "monochrome": False, "monoMix": None, "monoTone": None, "monoToneAmount": 0.0,
    "curves": None, "hsl": None, "fade": 0.0, "highlightRolloff": 0.0, "skinProtect": 0.0,
}


class ToneProgram:
    def __init__(self, recipe):
        r = dict(TONE_DEFAULTS)
        r.update(recipe or {})
        unknown = set(recipe or {}) - set(TONE_DEFAULTS)
        if unknown:
            raise ValueError("unknown tone keys: %s" % sorted(unknown))
        self.is_identity = all(r[k] == TONE_DEFAULTS[k] for k in TONE_DEFAULTS)
        self.exposure_gain = 2.0 ** r["exposure"] if r["exposure"] != 0 else 1.0
        if r["temperature"] != 0 or r["tint"] != 0:
            t, n = r["temperature"], r["tint"]
            self.white_balance = np.array([1 + 0.10 * t + 0.02 * n, 1 - 0.07 * n, 1 - 0.13 * t + 0.02 * n])
        else:
            self.white_balance = None
        self.cross_talk = min(max(r["crossTalk"], 0.0), 0.5)
        rolloff = min(max(r["highlightRolloff"], 0.0), 1.0)
        if rolloff > 0:
            peak = self.exposure_gain * (self.white_balance.max() if self.white_balance is not None else 1.0)
            self.knee = 1 - 0.6 * rolloff
            self.white = max(peak, 1.0)
        else:
            self.knee = 1.0
            self.white = 1.0
        self.contrast = r["contrast"]
        curves = r["curves"] or {}
        self.master = self._curve(curves.get("master", []))
        self.curve_r = self._curve(curves.get("r", []))
        self.curve_g = self._curve(curves.get("g", []))
        self.curve_b = self._curve(curves.get("b", []))
        mixer = r["hsl"]
        if mixer:
            unknown = set(mixer) - set(HSL_BAND_NAMES)
            if unknown:
                raise ValueError("unknown hsl bands: %s" % sorted(unknown))
            bands = [dict({"hue": 0.0, "saturation": 1.0, "luminance": 0.0}, **mixer.get(name, {})) for name in HSL_BAND_NAMES]
            neutral = all(abs(b["hue"]) < 1e-4 and abs(b["saturation"] - 1) < 1e-4 and abs(b["luminance"]) < 1e-4 for b in bands)
        else:
            bands, neutral = None, True
        if not neutral:
            self.hsl_hue = np.array([b["hue"] for b in bands])
            self.hsl_saturation = np.array([max(b["saturation"], 0.0) for b in bands])
            self.hsl_luminance = np.array([b["luminance"] for b in bands])
        else:
            self.hsl_hue = None
        self.saturation = max(r["saturation"], 0.0)
        self.skin_protect = min(max(r["skinProtect"], 0.0), 1.0)
        self.shadow_tint = self._toning(r["shadowTint"])
        self.shadow_amount = max(r["shadowTintAmount"], 0.0)
        self.highlight_tint = self._toning(r["highlightTint"])
        self.highlight_amount = max(r["highlightTintAmount"], 0.0)
        self.monochrome = bool(r["monochrome"])
        mix_w = r["monoMix"]
        if mix_w and len(mix_w) == 3 and sum(mix_w) > 0.0001:
            self.mono_weights = np.array(mix_w, dtype=np.float64) / sum(mix_w)
        else:
            self.mono_weights = REC709.copy()
        self.mono_tone = self._toning(r["monoTone"])
        self.mono_tone_amount = max(r["monoToneAmount"], 0.0)
        self.fade = min(max(r["fade"], 0.0), 0.5)
        self.black_lift = r["blackLift"]
        self.white_cap = r["whiteCap"]

    @staticmethod
    def _curve(points):
        if not points:
            return None
        curve = MonotoneCurve(points)
        return None if curve.is_identity else curve

    @staticmethod
    def _toning(value):
        color = hex_rgb(value)
        return None if color is None else toning_color(color)

    def apply(self, rgb):
        source = clamp01(np.asarray(rgb, dtype=np.float64))
        if self.is_identity:
            return source
        lin = srgb_to_linear(source)
        if self.exposure_gain != 1:
            lin = lin * self.exposure_gain
        if self.white_balance is not None:
            lin = lin * self.white_balance
        if self.cross_talk > 0:
            k = self.cross_talk
            x, y, z = lin[..., 0], lin[..., 1], lin[..., 2]
            lin = np.stack([x * (1 - k) + (y + z) * k * 0.5,
                            y * (1 - k) + (x + z) * k * 0.5,
                            z * (1 - k) + (x + y) * k * 0.5], axis=-1)
        lin = self._shoulder(lin)
        if self.monochrome:
            return self._monochrome(lin)
        c = clamp01(linear_to_srgb(lin))
        c = self._tone_curves(c)
        if self.hsl_hue is not None:
            c = self._hsl(c)
        c = self._saturation(c)
        c = self._split_tone(c)
        return self._finish(c)

    def _shoulder(self, x):
        v = np.maximum(x, 0.0)
        knee, white = self.knee, self.white
        if white <= knee + 0.0001:
            return np.where(v > knee, np.minimum(v, 1.0), v)
        a = (white - knee) / (1 - knee)
        u = np.minimum((v - knee) / (white - knee), 1.0)
        rolled = knee + (1 - knee) * (a * u / (1 + (a - 1) * u))
        return np.where(v > knee, rolled, v)

    def _tone_curves(self, c):
        if abs(self.contrast - 1) > 0.0001:
            c = contrast_curve(c, self.contrast)
        if self.master is not None:
            c = self.master(c)
        c = c.copy()
        if self.curve_r is not None:
            c[..., 0] = self.curve_r(c[..., 0])
        if self.curve_g is not None:
            c[..., 1] = self.curve_g(c[..., 1])
        if self.curve_b is not None:
            c[..., 2] = self.curve_b(c[..., 2])
        return clamp01(c)

    def _hsl(self, c):
        chroma = c.max(axis=-1) - c.min(axis=-1)
        active = chroma > 1e-5
        h, s, v = hsv(c)
        lower, upper, wu = hue_band_weights(h)
        wl = 1.0 - wu
        dh = self.hsl_hue[lower] * wl + self.hsl_hue[upper] * wu
        ds = self.hsl_saturation[lower] * wl + self.hsl_saturation[upper] * wu
        dl = self.hsl_luminance[lower] * wl + self.hsl_luminance[upper] * wu
        y0 = luminance(c)
        out = c
        shifted = with_luminance(rgb_from_hsv(h + dh, s, v), y0)
        out = np.where((np.abs(dh) > 0.001)[..., None], shifted, out)
        out = np.where((np.abs(ds - 1) > 0.0001)[..., None], scale_chroma(out, ds), out)
        gate = smoothstep(0.0, 0.2, chroma)
        y = luminance(out)
        lum = with_luminance(out, y + dl * gate * 4 * y * (1 - y))
        out = np.where((np.abs(dl) > 0.00001)[..., None], lum, out)
        return np.where(active[..., None], clamp01(out), c)

    def _saturation(self, c):
        m = np.full(c.shape[:-1], self.saturation)
        if self.skin_protect > 0 and abs(self.saturation - 1) > 0.0001:
            m = m + (1 - m) * skin_weight(c) * self.skin_protect
        changed = np.abs(m - 1) > 0.0001
        if not np.any(changed):
            return c
        return np.where(changed[..., None], scale_chroma(c, m), c)

    def _split_tone(self, c):
        l = luminance(c)[..., None]
        if self.shadow_tint is not None and self.shadow_amount > 0:
            w = (1 - l) * (1 - l)
            c = mix(c, soft_light(c, self.shadow_tint), w * self.shadow_amount)
        if self.highlight_tint is not None and self.highlight_amount > 0:
            w = l * l
            c = mix(c, soft_light(c, self.highlight_tint), w * self.highlight_amount)
        return clamp01(c)

    def _finish(self, c):
        if self.fade > 0:
            inverse = 1.0 - c
            c = c + inverse * inverse * self.fade
        if self.black_lift != 0 or self.white_cap != 1:
            c = self.black_lift + c * (self.white_cap - self.black_lift)
        return clamp01(c)

    def _monochrome(self, lin):
        y = clamp01(lin @ self.mono_weights)
        g = linear_to_srgb(y)
        if abs(self.contrast - 1) > 0.0001:
            g = contrast_curve(g, self.contrast)
        if self.master is not None:
            g = self.master(g)
        c = np.repeat(clamp01(g)[..., None], 3, axis=-1)
        if self.mono_tone is not None and self.mono_tone_amount > 0:
            c = mix(c, soft_light(c, self.mono_tone), self.mono_tone_amount)
        c = self._split_tone(c)
        return self._finish(c)


# ---------------------------------------------------------------------------
# ColorCube.swift（LUTBaker + 三线性查表）
# ---------------------------------------------------------------------------

def bake_cube(recipe, n=33):
    grid = np.linspace(0.0, 1.0, n)
    b, g, r = np.meshgrid(grid, grid, grid, indexing="ij")
    rgb = np.stack([r, g, b], axis=-1).reshape(-1, 3)
    out = ToneProgram(recipe).apply(rgb)
    return out.reshape(n, n, n, 3)  # [b, g, r]


def apply_cube(img, cube):
    n = cube.shape[0]
    p = clamp01(img) * (n - 1)
    i0 = np.minimum(np.floor(p).astype(int), n - 1)
    i1 = np.minimum(i0 + 1, n - 1)
    f = p - i0
    r0, g0, b0 = i0[..., 0], i0[..., 1], i0[..., 2]
    r1, g1, b1 = i1[..., 0], i1[..., 1], i1[..., 2]
    fr, fg, fb = f[..., 0:1], f[..., 1:2], f[..., 2:3]
    c00 = cube[b0, g0, r0] * (1 - fr) + cube[b0, g0, r1] * fr
    c10 = cube[b0, g1, r0] * (1 - fr) + cube[b0, g1, r1] * fr
    c01 = cube[b1, g0, r0] * (1 - fr) + cube[b1, g0, r1] * fr
    c11 = cube[b1, g1, r0] * (1 - fr) + cube[b1, g1, r1] * fr
    c0 = c00 * (1 - fg) + c10 * fg
    c1 = c01 * (1 - fg) + c11 * fg
    return c0 * (1 - fb) + c1 * fb


# ---------------------------------------------------------------------------
# FilmProcessor.swift（近似：Core Image 的工作空间是线性光）
# ---------------------------------------------------------------------------

class SeededRandom:
    """SeededRandom.swift（SplitMix64）。"""
    MASK = (1 << 64) - 1

    def __init__(self, seed):
        self.state = (seed + 0x9E3779B97F4A7C15) & self.MASK

    def next(self):
        self.state = (self.state + 0x9E3779B97F4A7C15) & self.MASK
        z = self.state
        z = ((z ^ (z >> 30)) * 0xBF58476D1CE4E5B9) & self.MASK
        z = ((z ^ (z >> 27)) * 0x94D049BB133111EB) & self.MASK
        return z ^ (z >> 31)

    def unit(self):
        return (self.next() >> 11) * (1.0 / 9007199254740992.0)

    def range(self, lo, hi):
        return lo + (hi - lo) * self.unit()

    def index(self, count):
        return self.next() % count if count > 0 else 0


def _box_sizes(sigma, n=3):
    ideal = math.sqrt(12.0 * sigma * sigma / n + 1.0)
    wl = int(math.floor(ideal))
    if wl % 2 == 0:
        wl -= 1
    wu = wl + 2
    m = round((12.0 * sigma * sigma - n * wl * wl - 4.0 * n * wl - 3.0 * n) / (-4.0 * wl - 4.0))
    return [wl if i < m else wu for i in range(n)]


def _box_axis(a, r, axis):
    if r < 1:
        return a
    pad = [(0, 0)] * a.ndim
    pad[axis] = (r + 1, r)
    p = np.pad(a, pad, mode="edge")
    cs = np.cumsum(p, axis=axis)
    n = a.shape[axis]
    upper = np.take(cs, np.arange(2 * r + 1, 2 * r + 1 + n), axis=axis)
    lower = np.take(cs, np.arange(0, n), axis=axis)
    return (upper - lower) / (2 * r + 1)


def gaussian_blur(img, sigma):
    if sigma < 0.5:
        return img
    out = img
    for w in _box_sizes(sigma):
        r = (w - 1) // 2
        out = _box_axis(_box_axis(out, r, 0), r, 1)
    return out


def _radial(shape, inner, outer):
    """CIRadialGradient：半径 inner 以内为 1，到 outer 线性降到 0（以对角线一半为单位）。"""
    h, w = shape
    yy, xx = np.mgrid[0:h, 0:w]
    cx, cy = (w - 1) / 2.0, (h - 1) / 2.0
    radius = math.hypot(w, h) / 2.0
    r = np.hypot(xx - cx, yy - cy) / radius
    return clamp01((outer - r) / (outer - inner))


def _ci_tone_curve(x, points):
    return MonotoneCurve(points)(clamp01(x))


def fx_halation(lin, amount):
    if amount <= 0.001:
        return lin
    md = min(lin.shape[:2])
    mask = _ci_tone_curve(lin @ REC709, [(0, 0), (0.55, 0), (0.75, 0.1), (0.9, 0.6), (1, 1)])
    glow = gaussian_blur(mask[..., None], md * 0.018)[..., 0]
    halo = glow * (1.0 - mask)
    tint = np.array([1.25, 0.36, 0.12]) * amount
    return lin + halo[..., None] * tint


def fx_bloom(lin, amount):
    if amount <= 0.001:
        return lin
    md = min(lin.shape[:2])
    blur = gaussian_blur(lin, md * 0.018)
    k = amount * 0.8 * 0.55
    return 1.0 - (1.0 - clamp01(lin)) * (1.0 - clamp01(blur) * k)


def fx_edge_softness(lin, amount):
    if amount <= 0.001:
        return lin
    md = min(lin.shape[:2])
    blur = gaussian_blur(lin, md * 0.012 * amount)
    mask = 1.0 - _radial(lin.shape[:2], 0.55, 1.0)
    return mix(lin, blur, mask[..., None])


def fx_light_leak(lin, amount, seed):
    if amount <= 0.001:
        return lin
    rng = SeededRandom(seed ^ 0x1EA4C0DE)
    h, w = lin.shape[:2]
    t = rng.range(0.15, 0.85)
    edge = rng.index(4)
    # Core Image 原点在左下；这里换算成左上原点的像素坐标。
    if edge == 0:
        cx, cy = 0.0, h - h * t
    elif edge == 1:
        cx, cy = float(w), h - h * t
    elif edge == 2:
        cx, cy = w * t, 0.0
    else:
        cx, cy = w * t, float(h)
    palette = [(1.0, 0.42, 0.12), (1.0, 0.24, 0.18), (1.0, 0.72, 0.28)]
    color = srgb_to_linear(np.array(palette[rng.index(len(palette))]))
    radius = max(w, h) * rng.range(0.35, 0.6)
    alpha = min(1.0, amount * 0.9)
    yy, xx = np.mgrid[0:h, 0:w]
    d = np.hypot(xx - cx, yy - cy)
    a = alpha * clamp01((radius - d) / (radius - radius * 0.08))
    src = color * a[..., None]
    return 1.0 - (1.0 - clamp01(lin)) * (1.0 - src)


def fx_vignette(lin, amount):
    if amount <= 0.001:
        return lin
    ramp = _radial(lin.shape[:2], 0.3, 1.25)
    s = _ci_tone_curve(ramp, [(0, 0), (0.25, 0.156), (0.5, 0.5), (0.75, 0.844), (1, 1)])
    depth = min(amount, 1.0) * 0.62
    return lin * ((1.0 - depth) + depth * s)[..., None]


def _noise(shape, rng, scale, blur):
    h, w = shape
    sh, sw = int(math.ceil(h / scale)) + 2, int(math.ceil(w / scale)) + 2
    base = rng.random((sh, sw))
    yy = np.arange(h) / scale
    xx = np.arange(w) / scale
    y0 = np.floor(yy).astype(int)
    x0 = np.floor(xx).astype(int)
    fy = (yy - y0)[:, None]
    fx = (xx - x0)[None, :]
    a = base[y0][:, x0]
    b = base[y0][:, x0 + 1]
    c = base[y0 + 1][:, x0]
    d = base[y0 + 1][:, x0 + 1]
    n = (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy
    if blur > 0.05:
        n = gaussian_blur(n[..., None], blur)[..., 0]
    return n


def fx_grain(lin, amount, size, iso, seed):
    if amount <= 0.001:
        return lin
    h, w = lin.shape[:2]
    rng = np.random.default_rng(seed)
    iso_scale = (max(iso, 25) / 400.0) ** 0.13
    s = max(1.0, max(size, 0.5) * iso_scale)
    resolution = min(1.0, max(0.5, math.sqrt(max(h, w) / 1600.0)))
    k = amount * 0.30 * resolution
    fine = _noise((h, w), rng, s, (s - 1) * 0.45 if s > 1.2 else 0.0)
    clumps = _noise((h, w), rng, s * 2.4, s * 0.8)
    out = clamp01(lin)
    for layer, gain in ((fine, k * 0.85), (clumps, k * 1.1)):
        blend = (gain * layer + (0.5 - gain / 2.0))[..., None]
        out = soft_light(out, blend)
    return out


def develop(img_srgb, stock, seed=7, cube=None):
    """App 的管线：LUT → 光晕 → 柔焦 → 柔边 → 漏光 → 暗角 → 颗粒。"""
    if cube is None:
        cube = bake_cube(stock.get("tone", {}))
    graded = apply_cube(img_srgb, cube)
    fx = dict({"grain": 0, "grainSize": 1, "halation": 0, "bloom": 0, "vignette": 0, "lightLeak": 0,
               "edgeSoftness": 0}, **stock.get("effects", {}))
    lin = srgb_to_linear(graded)
    lin = fx_halation(lin, fx["halation"])
    lin = fx_bloom(lin, fx["bloom"])
    lin = fx_edge_softness(lin, fx["edgeSoftness"])
    lin = fx_light_leak(lin, fx["lightLeak"], seed)
    lin = fx_vignette(lin, fx["vignette"])
    lin = fx_grain(lin, fx["grain"], fx["grainSize"], stock.get("iso", 400), seed)
    return clamp01(linear_to_srgb(clamp01(lin)))


# ---------------------------------------------------------------------------
# 图片读写
# ---------------------------------------------------------------------------

def read_image(path):
    try:
        import OpenImageIO as oiio
        buf = oiio.ImageBuf(path)
        px = buf.get_pixels(oiio.FLOAT)
        if px is None or px.size == 0:
            raise IOError(buf.geterror())
        px = np.asarray(px, dtype=np.float64)
        if px.ndim == 2:
            px = px[..., None]
        if px.shape[2] == 1:
            px = np.repeat(px, 3, axis=2)
        return clamp01(px[..., :3])
    except ImportError:
        from PIL import Image  # 没有 OpenImageIO 时的退路
        return np.asarray(Image.open(path).convert("RGB"), dtype=np.float64) / 255.0


def write_image(path, img):
    img = np.ascontiguousarray(clamp01(img), dtype=np.float32)
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    try:
        import OpenImageIO as oiio
        out = oiio.ImageOutput.create(path)
        out.open(path, oiio.ImageSpec(img.shape[1], img.shape[0], 3, oiio.UINT8))
        out.write_image(img)
        out.close()
    except ImportError:
        from PIL import Image
        Image.fromarray((img * 255 + 0.5).astype(np.uint8)).save(path)


def resize(img, width=None, height=None):
    h, w = img.shape[:2]
    if width is None:
        width = max(1, int(round(w * height / h)))
    if height is None:
        height = max(1, int(round(h * width / w)))
    factor = max(w / width, h / height)
    if factor > 1.5:
        img = gaussian_blur(img, factor * 0.42)
    ys = (np.arange(height) + 0.5) * h / height - 0.5
    xs = (np.arange(width) + 0.5) * w / width - 0.5
    y0 = np.clip(np.floor(ys).astype(int), 0, h - 1)
    x0 = np.clip(np.floor(xs).astype(int), 0, w - 1)
    y1 = np.clip(y0 + 1, 0, h - 1)
    x1 = np.clip(x0 + 1, 0, w - 1)
    fy = np.clip(ys - y0, 0, 1)[:, None, None]
    fx = np.clip(xs - x0, 0, 1)[None, :, None]
    a = img[y0][:, x0]
    b = img[y0][:, x1]
    c = img[y1][:, x0]
    d = img[y1][:, x1]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def fit_crop(img, aspect):
    """按宽 / 高比例居中裁切（App 冲印时的裁切）。"""
    h, w = img.shape[:2]
    if w / h > aspect:
        nw = int(round(h * aspect))
        x0 = (w - nw) // 2
        return img[:, x0:x0 + nw]
    nh = int(round(w / aspect))
    y0 = (h - nh) // 2
    return img[y0:y0 + nh]


# ---------------------------------------------------------------------------
# 5×7 点阵字（联系表的标签只用 ASCII，免得依赖字体库）
# ---------------------------------------------------------------------------

_GLYPHS = {
    "A": ".###.#...##...######...##...##...#", "B": "####.#...##...#####.#...##...#####.",
    "C": ".###.#...##....#....#....#...#.###.", "D": "####.#...##...##...##...##...#####.",
    "E": "######....#....####.#....#....#####", "F": "######....#....####.#....#....#....",
    "G": ".###.#...##....#.####...##...#.###.", "H": "#...##...##...#######...##...##...#",
    "I": ".###...#....#....#....#....#...###.", "J": "..###...#....#....#....#.#..#..##..",
    "K": "#...##..#.#.#..##...#.#..#..#.#...#", "L": "#....#....#....#....#....#....#####",
    "M": "#...###.###.#.##.#.##...##...##...#", "N": "#...##...###..##.#.##..###...##...#",
    "O": ".###.#...##...##...##...##...#.###.", "P": "####.#...##...#####.#....#....#....",
    "Q": ".###.#...##...##...##.#.##..#..##.#", "R": "####.#...##...#####.#.#..#..#.#...#",
    "S": ".#####....#.....###.....#....#####.", "T": "#####..#....#....#....#....#....#..",
    "U": "#...##...##...##...##...##...#.###.", "V": "#...##...##...##...##...#.#.#...#..",
    "W": "#...##...##...##.#.##.#.##.#..#.#.", "X": "#...##...#.#.#...#...#.#.#...##...#",
    "Y": "#...##...#.#.#...#....#....#....#..", "Z": "#####....#...#...#...#...#....#####",
    "0": ".###.#...##..###.#.###..##...#.###.", "1": "..#...##....#....#....#....#...###.",
    "2": ".###.#...#....#...#...#...#...#####", "3": "#####...#...#.....#....##...#.###.",
    "4": "...#...##..#.#.#..#.#####...#....#.", "5": "######....####.....#....##...#.###.",
    "6": "..##..#...#....####.#...##...#.###.", "7": "#####....#...#...#...#....#....#...",
    "8": ".###.#...##...#.###.#...##...#.###.", "9": ".###.#...##...#.####....#...#..##..",
    "-": "...............#####...............", ".": ".........................##...##...",
    " ": "...................................", "/": "....#....#...#...#...#...#....#....",
    "+": "......#....#..#####..#....#........", ":": ".....##...##.........##...##.......",
}


def draw_text(canvas, x, y, text, scale=2, color=(0.92, 0.9, 0.86)):
    for ch in text.upper():
        glyph = _GLYPHS.get(ch, _GLYPHS[" "]).ljust(35, ".")
        for row in range(7):
            for col in range(5):
                if glyph[row * 5 + col] == "#":
                    y0, x0 = y + row * scale, x + col * scale
                    if 0 <= y0 < canvas.shape[0] - scale and 0 <= x0 < canvas.shape[1] - scale:
                        canvas[y0:y0 + scale, x0:x0 + scale] = color
        x += 6 * scale


# ---------------------------------------------------------------------------
# 合成测试图：六种肤色的球 + 24 色卡 + 灰阶
# ---------------------------------------------------------------------------

_SKINS = ["#F6DCC8", "#EDC3A4", "#D9A27C", "#BC8160", "#8E5A3E", "#5C3A28"]
_CHECKER = [
    "#735244", "#C29682", "#627A9D", "#576C43", "#8580B1", "#67BDAA",
    "#D67E2C", "#505BA6", "#C15A63", "#5E3C6C", "#9DBC40", "#E0A32E",
    "#383D96", "#469449", "#AF363C", "#E7C71F", "#BB5695", "#0885A1",
    "#F3F3F2", "#C8C8C8", "#A0A0A0", "#7A7A79", "#555555", "#343434",
]


def make_chart(width=900, height=600):
    img = np.zeros((height, width, 3))
    yy, xx = np.mgrid[0:height, 0:width]
    # 背景：上面暖灰到下面中灰的柔和渐变（看偏色）
    bg = 0.47 + 0.08 * (1 - yy / height)
    img[:] = bg[..., None]
    light = np.array([-0.45, -0.55, 0.70])
    light /= np.linalg.norm(light)
    half = np.array([-0.2, -0.3, 1.0])
    half /= np.linalg.norm(half)
    radius = int(width / 15)
    for i, hex_value in enumerate(_SKINS):
        cx = int(width * (i + 0.5) / len(_SKINS))
        cy = int(height * 0.24)
        dx = (xx - cx) / radius
        dy = (yy - cy) / radius
        rr = dx * dx + dy * dy
        inside = rr <= 1.0
        nz = np.sqrt(np.clip(1.0 - rr, 0.0, 1.0))
        diffuse = np.clip(dx * light[0] + dy * light[1] + nz * light[2], 0.0, 1.0)
        spec = np.clip(dx * half[0] + dy * half[1] + nz * half[2], 0.0, 1.0) ** 40
        albedo = srgb_to_linear(hex_rgb(hex_value))
        shade = albedo * (0.08 + 1.0 * diffuse)[..., None] + 0.05 * spec[..., None]
        edge = smoothstep(1.0, 0.96, rr)[..., None]
        img = np.where(inside[..., None], mix(img, linear_to_srgb(shade), edge), img)
    # 色卡
    top = int(height * 0.48)
    cell_w = width / 6.0
    cell_h = (height * 0.43) / 4.0
    for k, hex_value in enumerate(_CHECKER):
        row, col = divmod(k, 6)
        x0 = int(col * cell_w + 6)
        x1 = int((col + 1) * cell_w - 6)
        y0 = int(top + row * cell_h + 4)
        y1 = int(top + (row + 1) * cell_h - 4)
        img[y0:y1, x0:x1] = hex_rgb(hex_value)
    # 底部灰阶
    ramp = np.linspace(0.0, 1.0, width)
    img[int(height * 0.93):, :] = ramp[None, :, None]
    return clamp01(img)


# ---------------------------------------------------------------------------
# 联系表
# ---------------------------------------------------------------------------

def load_stocks(path=STOCKS_JSON, only=None):
    with open(path, encoding="utf-8") as f:
        stocks = json.load(f)["stocks"]
    if only:
        wanted = [s.strip() for s in only.split(",") if s.strip()]
        by_id = {s["id"]: s for s in stocks}
        missing = [w for w in wanted if w not in by_id]
        if missing:
            raise SystemExit("unknown stock ids: %s" % ", ".join(missing))
        stocks = [by_id[w] for w in wanted]
    return stocks


def build_sheet(stocks, photos, cell, label_width, aspect, seed, include_original=True):
    prepared = [resize(fit_crop(p, aspect), width=int(cell * 1.9)) for p in photos]
    rows = ([("ORIGINAL", None)] if include_original else []) + [(s["id"], s) for s in stocks]
    cell_h = int(round(cell / aspect))
    gap = 6
    width = label_width + len(photos) * (cell + gap) + gap
    height = len(rows) * (cell_h + gap) + gap
    canvas = np.full((height, width, 3), 0.12)
    for r, (label, stock) in enumerate(rows):
        y = gap + r * (cell_h + gap)
        draw_text(canvas, 10, y + cell_h // 2 - 7, label, scale=2)
        if stock is not None:
            iso = "ISO %d" % stock.get("iso", 0)
            draw_text(canvas, 10, y + cell_h // 2 + 12, iso, scale=1, color=(0.6, 0.58, 0.55))
        cube = bake_cube(stock.get("tone", {})) if stock is not None else None
        for c, photo in enumerate(prepared):
            out = photo if stock is None else develop(photo, stock, seed=seed + c, cube=cube)
            tile = resize(out, width=cell, height=cell_h)
            x = label_width + gap + c * (cell + gap)
            canvas[y:y + cell_h, x:x + cell] = tile
    return canvas


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    chart = sub.add_parser("chart", help="合成肤色 + 色卡测试图")
    chart.add_argument("--out", required=True)
    sheet = sub.add_parser("sheet", help="联系表")
    sheet.add_argument("photos", nargs="+")
    sheet.add_argument("--out", required=True)
    sheet.add_argument("--stocks", help="逗号分隔的胶卷 id（缺省：全部）")
    sheet.add_argument("--json", default=STOCKS_JSON)
    sheet.add_argument("--cell", type=int, default=220)
    sheet.add_argument("--aspect", type=float, default=1.0, help="画面宽 / 高（方形即显 = 1）")
    sheet.add_argument("--rows-per-page", type=int, default=0, help="再按页拆成 -p1、-p2 … 方便逐页看")
    sheet.add_argument("--seed", type=int, default=7)
    args = parser.parse_args(argv)

    if args.command == "chart":
        write_image(args.out, make_chart())
        print(args.out)
        return 0

    stocks = load_stocks(args.json, args.stocks)
    photos = [read_image(p) for p in args.photos]
    label_width = 190
    full = build_sheet(stocks, photos, args.cell, label_width, args.aspect, args.seed)
    write_image(args.out, full)
    print(args.out)
    if args.rows_per_page > 0:
        root, ext = os.path.splitext(args.out)
        for page, start in enumerate(range(0, len(stocks), args.rows_per_page), start=1):
            chunk = stocks[start:start + args.rows_per_page]
            part = build_sheet(chunk, photos, args.cell, label_width, args.aspect, args.seed)
            path = "%s-p%d%s" % (root, page, ext)
            write_image(path, part)
            print(path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
