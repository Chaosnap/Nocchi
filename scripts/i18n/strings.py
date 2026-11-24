#!/usr/bin/env python3
"""Nocchi 界面翻译（简体中文是原文，英文是翻译）。只用 Python 标准库，本机或 CI 都能跑，不需要编译。

用法：
    python3 scripts/i18n/strings.py extract   # 扫源码，写 scripts/i18n/keys.json（键 → 出现的位置和用法）
    python3 scripts/i18n/strings.py build     # 用 scripts/i18n/en.json 生成 macOS/Nocchi/Resources/en.lproj/Localizable.strings（和 .stringsdict）
    python3 scripts/i18n/strings.py check     # 有键没翻译就失败（列出来）
    python3 scripts/i18n/strings.py todo      # 列出还是普通 String（SwiftUI 不会自动翻译）的中文字面量

键怎么来（和 SwiftUI / Foundation 运行时查表用的一样）：
- 没有插值的字面量：原文就是键（`\\n` 之类的转义按原样写进 .strings）。
- 有插值的：每个 `\\(…)` 换成格式符——字符串 `%@`、整数 `%lld`、小数 `%lf`；字面部分里的 `%` 写成 `%%`。
  类型靠表达式猜（数数的名字 → `%lld`）；猜不准的在 scripts/i18n/formats.json 里写「原文 → 键」覆盖。

哪些不算：注释、多行字符串（着色器等）、带 `// i18n-ok` 的行（故意不翻译，比如按语言分别生成的字）、
`say(` / `print(` / `log(` 里的字、测试代码。

英文有单复数（1 photo / 2 photos）：en.json 里这种键的值写成对象——
    "%lld 张": {"format": "%#@n@", "n": {"one": "%lld photo", "other": "%lld photos"}}
`format` 是整句，`%#@n@` 处按数字选 `n` 的一种写法（数字就是 `%#@n@` 在整句里那个位置的参数）。
build 把这些写进 Localizable.stringsdict（Apple 的复数规则，运行时优先用它），.strings 里留「other」那一种。
"""

import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
ROOTS = [
    "macOS/Nocchi",
    "Packages/NocchiKit/Sources/NocchiUI",
    "Packages/NocchiKit/Sources/NocchiKit",
]
KEYS = os.path.join(HERE, "keys.json")
EN = os.path.join(HERE, "en.json")
FORMATS = os.path.join(HERE, "formats.json")
OUT = os.path.join(REPO, "macOS", "Nocchi", "Resources", "en.lproj", "Localizable.strings")
PLURALS_OUT = os.path.join(REPO, "macOS", "Nocchi", "Resources", "en.lproj", "Localizable.stringsdict")
CJK = re.compile(r"[㐀-鿿　-〿＀-￯]")

# 这些调用的第一个参数是 LocalizedStringKey：SwiftUI 自己会查表。
SWIFTUI_CALLS = (
    "Text", "Button", "Label", "Toggle", "Section", "Picker", "LabeledContent", "Menu", "TextField",
    "Link", "Stepper", "GroupBox", "ProgressView", "ContentUnavailableView", "Slider", "DatePicker",
    "ColorPicker", "Tab", "SecureField", "Gauge", "ControlGroup", "DisclosureGroup",
)
SWIFTUI_MODIFIERS = (".help", ".navigationTitle", ".alert", ".confirmationDialog", ".accessibilityLabel", ".badge", ".keyboardShortcut")
SKIP_CALLS = ("say", "print", "log", "debugPrint", "fatalError", "precondition", "assert", "NSLog", "os_log", "Logger")
# 字符串：名字、标题、路径、说明……（先认这些，免得「counterText」被当成数）。
STRING_HINTS = re.compile(r"(name|Name|title|Title|path|Description|description|note|tagline|[tT]ext\b|trimmingCharacters|as\? String|String\(|label|Label|key\b|tag\b|query|trimmed|location|caption)\W*$|String\(|as\? String")
INT_HINTS = re.compile(r"(\bcount\b|\.count\b|Count\b|[nN]umber\b|\bindex\b|moved|\btotal|[tT]otal\w*|\bshots?\b|Int\(|\bn\b|\bi\b|\bfailed\b|\bline\b|\bexpected\b|\bactual\b|maxCount|bytes|\biso\b|exposures|month|day\b|year|min\()")
FLOAT_HINTS = re.compile(r"(Double\(|Float\(|CGFloat\(|\.rounded\(\))")


# --------------------------------------------------------------------------- Swift 字面量解析

def scan_literals(src):
    """找出所有单行字符串字面量：返回 (起点, 终点, 片段)；片段是 [('text', s) | ('expr', s)]。"""
    out = []
    i = 0
    n = len(src)
    while i < n:
        c = src[i]
        if src.startswith("//", i):
            j = src.find("\n", i)
            i = n if j < 0 else j
            continue
        if src.startswith("/*", i):
            j = src.find("*/", i + 2)
            i = n if j < 0 else j + 2
            continue
        if src.startswith('"""', i):
            j = src.find('"""', i + 3)
            i = n if j < 0 else j + 3
            continue
        if c == "#" and i + 1 < n and src[i + 1] == '"':
            # 原始字符串：跳过
            j = src.find('"#', i + 2)
            i = n if j < 0 else j + 2
            continue
        if c == '"':
            end, parts = parse_string(src, i + 1)
            out.append((i, end, parts))
            i = end
            continue
        i += 1
    return out


def parse_string(src, i):
    """从开引号后面开始解析，返回 (闭引号之后的位置, 片段)。"""
    parts = []
    buf = []
    n = len(src)
    while i < n:
        c = src[i]
        if c == "\\" and i + 1 < n:
            if src[i + 1] == "(":
                if buf:
                    parts.append(("text", "".join(buf)))
                    buf = []
                expr, i = parse_interpolation(src, i + 2)
                parts.append(("expr", expr))
                continue
            buf.append(src[i:i + 2])
            i += 2
            continue
        if c == '"':
            if buf:
                parts.append(("text", "".join(buf)))
            return i + 1, parts
        if c == "\n":
            break
        buf.append(c)
        i += 1
    if buf:
        parts.append(("text", "".join(buf)))
    return i, parts


def parse_interpolation(src, i):
    depth = 1
    start = i
    n = len(src)
    while i < n and depth > 0:
        c = src[i]
        if c == '"':
            i, _ = parse_string(src, i + 1)
            continue
        if c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                return src[start:i], i + 1
        i += 1
    return src[start:i], i


def guess_format(expr):
    e = expr.strip()
    if FLOAT_HINTS.search(e):
        return "%lf"
    if STRING_HINTS.search(e):
        return "%@"
    if INT_HINTS.search(e):
        return "%lld"
    return "%@"


def literal_text(parts):
    """源码里的样子（含 \\(…)），用来在 formats.json 里认人。"""
    return "".join(s if kind == "text" else "\\(" + s + ")" for kind, s in parts)


def make_key(parts, overrides):
    raw = literal_text(parts)
    if raw in overrides:
        return overrides[raw]
    if not any(kind == "expr" for kind, _ in parts):
        return raw
    out = []
    for kind, s in parts:
        out.append(s.replace("%", "%%") if kind == "text" else guess_format(s))
    return "".join(out)


def context(src, start):
    """字面量前面是什么调用：swiftui（会自动查表）/ localized（已经 String(localized:)）/ skip / string。"""
    line_start = src.rfind("\n", 0, start) + 1
    before = src[line_start:start]
    line_end = src.find("\n", start)
    line = src[line_start: line_end if line_end >= 0 else len(src)]
    if "i18n-ok" in line:
        return "skip"
    stripped = before.rstrip()
    m = re.search(r"([A-Za-z_.][A-Za-z0-9_.]*)\(\s*(?:[A-Za-z]+:\s*)?$", stripped)
    if m:
        name = m.group(1)
        base = name.split(".")[-1]
        if name.endswith("String") or stripped.endswith("String(localized:") or "localized:" in stripped[-20:]:
            return "localized"
        if base in SKIP_CALLS:
            return "skip"
        if name in SWIFTUI_CALLS or any(name.endswith(mod) for mod in SWIFTUI_MODIFIERS):
            return "swiftui"
    if re.search(r"String\(localized:\s*$", stripped) or re.search(r"Localized\.string\(\s*$", stripped):
        return "localized"
    if re.search(r"LocalizedStringKey\(\s*$", stripped):
        return "swiftui"
    return "string"


def files():
    for root in ROOTS:
        for dp, _, names in os.walk(os.path.join(REPO, root)):
            for name in sorted(names):
                if name.endswith(".swift"):
                    yield os.path.join(dp, name)


def extract():
    overrides = load(FORMATS, {})
    keys = {}
    for path in files():
        src = open(path, encoding="utf-8").read()
        rel = os.path.relpath(path, REPO)
        for start, _, parts in scan_literals(src):
            raw = literal_text(parts)
            if not CJK.search(raw):
                continue
            ctx = context(src, start)
            if ctx == "skip":
                continue
            line = src.count("\n", 0, start) + 1
            key = make_key(parts, overrides)
            entry = keys.setdefault(key, {"source": raw, "uses": []})
            entry["uses"].append({"at": "%s:%d" % (rel, line), "context": ctx})
    for key, entry in load(EXTRA, {}).items():
        keys.setdefault(key, {"source": key, "uses": [{"at": entry, "context": "data"}]})
    with open(KEYS, "w", encoding="utf-8") as f:
        json.dump(dict(sorted(keys.items())), f, ensure_ascii=False, indent=1)
    by_ctx = {}
    for entry in keys.values():
        for use in entry["uses"]:
            by_ctx[use["context"]] = by_ctx.get(use["context"], 0) + 1
    print("keys: %d  uses by context: %s" % (len(keys), by_ctx))
    return keys


# 不在 Swift 字面量里、但界面上会显示的中文（胶卷名、简介……）：键 → 出处。
EXTRA = os.path.join(HERE, "extra.json")


def load(path, default):
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    return default


def escape(s):
    # 键和值按 .strings 的写法：只需要转义引号；源码里的 \n 之类已经是转义过的写法。
    return s.replace('"', '\\"') if '\\"' not in s else s


def plural_vars(value):
    """复数写法里的变量：{名字: {"one": …, "other": …}}（普通字符串返回空）。"""
    if isinstance(value, str):
        return {}
    return {name: rules for name, rules in value.items() if name != "format"}


def flat(value, form="other"):
    """en.json 的值展开成一句：普通字符串原样；复数写法把每个 %#@变量@ 换成那个变量的 form 写法。"""
    if isinstance(value, str):
        return value
    out = value["format"]
    for name, rules in plural_vars(value).items():
        out = out.replace("%#@" + name + "@", rules[form])
    return out


def plural_problems(key, value):
    """复数写法写得对不对：每个变量都要有 one 和 other，都要在 format 里出现，键里不能有反斜杠（plist 里是原样的字）。"""
    if isinstance(value, str):
        return []
    problems = []
    if "format" not in value:
        problems.append("no format")
    if "\\" in key:
        problems.append("plural keys cannot contain escapes")
    for name, rules in plural_vars(value).items():
        if not isinstance(rules, dict) or "one" not in rules or "other" not in rules:
            problems.append("%s needs one and other" % name)
        elif "%#@" + name + "@" not in value.get("format", ""):
            problems.append("%s is not used in format" % name)
    if not plural_vars(value):
        problems.append("no plural variables")
    return problems


def write_stringsdict(plurals):
    """Localizable.stringsdict：每个复数键一个 NSStringLocalizedFormatKey + 复数规则。"""
    import plistlib
    root = {}
    spec = re.compile(r"%(?:\d+\$)?(lld|ld|d)")
    for key, value in plurals.items():
        entry = {"NSStringLocalizedFormatKey": value["format"]}
        for name, rules in plural_vars(value).items():
            kind = spec.search(rules["other"])
            entry[name] = dict(rules, NSStringFormatSpecTypeKey="NSStringPluralRuleType",
                               NSStringFormatValueTypeKey=kind.group(1) if kind else "lld")
        root[key] = entry
    with open(PLURALS_OUT, "wb") as f:
        plistlib.dump(root, f, sort_keys=True)


def build(check_only=False):
    keys = extract()
    # 只有运行时真的会查表的键才需要翻译（全部用法都是没包起来的普通 String 的，比如字典键、截图样片，不查表）。
    keys = {k: e for k, e in keys.items() if any(u["context"] != "string" for u in e["uses"])}
    en = load(EN, {})
    missing = [k for k in keys if k not in en]
    unused = [k for k in en if k not in keys]
    if not check_only:
        os.makedirs(os.path.dirname(OUT), exist_ok=True)
        lines = ["/* 由 scripts/i18n/strings.py build 从 scripts/i18n/en.json 生成，不要手改。 */", ""]
        for key in sorted(keys):
            if key in en:
                lines.append('"%s" = "%s";' % (escape(key), escape(flat(en[key]))))
        with open(OUT, "w", encoding="utf-8") as f:
            f.write("\n".join(lines) + "\n")
        plurals = {k: en[k] for k in sorted(keys) if k in en and not isinstance(en[k], str)}
        write_stringsdict(plurals)
        print("wrote %s (%d translations, %d with plurals)" % (os.path.relpath(OUT, REPO), len(keys) - len(missing), len(plurals)))
    # 英文里的格式符要和键一样（个数、类型、顺序；%1$@ 这种带位置的也算），不然运行时会拿错参数。
    spec = re.compile(r"%(\d+\$)?(lld|ld|d|@|lf|f)")
    mismatched = []
    for key in keys:
        if key in en:
            problems = plural_problems(key, en[key])
            if problems:
                mismatched.append((key, "; ".join(problems)))
                continue
            want = [m.group(2) for m in spec.finditer(key.replace("%%", ""))]
            for form in ("other", "one"):
                have = [m.group(2) for m in spec.finditer(flat(en[key], form).replace("%%", ""))]
                if want != have:
                    mismatched.append((key, form))
                    break
    if mismatched:
        print("format specifiers differ: %d" % len(mismatched))
        for k, why in mismatched:
            print("  %s => %s (%s)" % (json.dumps(k, ensure_ascii=False), json.dumps(en[k], ensure_ascii=False), why))
        return 1
    if unused:
        print("unused translations: %d" % len(unused))
    if missing:
        print("missing translations: %d" % len(missing))
        for k in missing[:400]:
            print("  " + json.dumps(k, ensure_ascii=False))
        return 1
    return 0


# 这些文件夹 / 文件不自动包 String(localized:)：截图工作室的样片内容、生成的热点文件、搜索用的日期写法。
WRAP_SKIP = ("macOS/Nocchi/Screenshots/", "BoothMachineLayout.swift", "CardBoxHotspots.swift", "PhotoSearch.swift")


def wrap(paths=None):
    """把「普通 String」里的中文字面量包成 String(localized: …)（跳过字典键、比较、case 模式、生成的文件）。"""
    changed = 0
    for path in files():
        rel = os.path.relpath(path, REPO)
        if paths and not any(rel.startswith(p) for p in paths):
            continue
        if any(skip in rel for skip in WRAP_SKIP):
            continue
        src = open(path, encoding="utf-8").read()
        edits = []
        for start, end, parts in scan_literals(src):
            raw = literal_text(parts)
            if not CJK.search(raw) or context(src, start) != "string":
                continue
            line_start = src.rfind("\n", 0, start) + 1
            before = src[line_start:start].rstrip()
            after = src[end:end + 3].lstrip()
            # 字典键：前面是 [ 或 , 或行首，后面跟着冒号（三元运算的第一支前面是 ?，不算）。
            if after.startswith(":") and (before == "" or before.endswith("[") or before.endswith(",")):
                continue
            if re.search(r"(==|!=|case|hasPrefix\(|hasSuffix\(|contains\(|replacingOccurrences\(of:|firstIndex\(of:|range\(of:|components\(separatedBy:)\s*$", before):
                continue
            if re.search(r"\bcase\s+\w+\s*=\s*$", before):
                continue
            edits.append((start, end))
        if not edits:
            continue
        out = src
        for start, end in reversed(edits):
            out = out[:start] + "String(localized: " + out[start:end] + ")" + out[end:]
        with open(path, "w", encoding="utf-8") as f:
            f.write(out)
        changed += len(edits)
        print("%3d  %s" % (len(edits), rel))
    print("wrapped %d literals" % changed)


def todo():
    keys = extract()
    rows = []
    for key, entry in keys.items():
        for use in entry["uses"]:
            if use["context"] == "string":
                rows.append((use["at"], entry["source"]))
    for at, src in sorted(rows):
        print("%s\t%s" % (at, src))
    print("%d plain-String uses" % len(rows))


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "extract"
    if cmd == "extract":
        extract()
    elif cmd == "build":
        sys.exit(build())
    elif cmd == "check":
        sys.exit(build(check_only=True))
    elif cmd == "todo":
        todo()
    elif cmd == "wrap":
        wrap(sys.argv[2:] or None)
    else:
        print(__doc__)
        sys.exit(2)
