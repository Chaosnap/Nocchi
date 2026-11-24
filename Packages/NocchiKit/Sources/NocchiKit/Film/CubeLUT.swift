import Foundation

/// `.cube` LUT 文件（Adobe / Resolve 格式）的解析器。
///
/// 支持 `LUT_3D_SIZE`、`LUT_1D_SIZE`、`DOMAIN_MIN/MAX`、`LUT_*_INPUT_RANGE`、`TITLE`
/// 与注释；对用户导入的文件做大小、格点数、数值合法性检查。
public struct CubeLUT: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case threeD
        case oneD
    }

    public enum ParseError: Error, Equatable, LocalizedError {
        case fileTooLarge(bytes: Int)
        case unreadableText
        case missingSize
        case invalidSize(Int)
        case malformedLine(Int)
        case nonFiniteValue(line: Int)
        case entryCountMismatch(expected: Int, actual: Int)
        case invalidDomain

        public var errorDescription: String? {
            switch self {
            case .fileTooLarge(let bytes):
                return String(localized: "LUT 文件太大（\(bytes / 1024) KB），上限 \(CubeLUT.maxFileBytes / 1024 / 1024) MB。")
            case .unreadableText:
                return String(localized: "无法以文本方式读取这个 LUT 文件。")
            case .missingSize:
                return String(localized: "缺少 LUT_3D_SIZE 或 LUT_1D_SIZE。")
            case .invalidSize(let n):
                return String(localized: "不支持的 LUT 尺寸：\(n)。")
            case .malformedLine(let line):
                return String(localized: "第 \(line) 行格式不正确。")
            case .nonFiniteValue(let line):
                return String(localized: "第 \(line) 行包含无效数值。")
            case .entryCountMismatch(let expected, let actual):
                return String(localized: "数据行数量不符：需要 \(expected) 行，实际 \(actual) 行。")
            case .invalidDomain:
                return String(localized: "DOMAIN_MIN 必须小于 DOMAIN_MAX。")
            }
        }
    }

    public static let maxFileBytes = 32 * 1024 * 1024
    public static let max3DSize = 129
    public static let max1DSize = 65_536
    /// Core Image 立方体维度上限。
    public static let maxCubeDimension = 64

    public var title: String?
    public var kind: Kind
    public var size: Int
    public var domainMin: RGB
    public var domainMax: RGB
    public var entries: [RGB]

    public init(contentsOf url: URL) throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let bytes = (attributes[.size] as? NSNumber)?.intValue ?? 0
        if bytes > Self.maxFileBytes {
            throw ParseError.fileTooLarge(bytes: bytes)
        }
        let data = try Data(contentsOf: url)
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw ParseError.unreadableText
        }
        try self.init(parsing: text)
    }

    public init(parsing text: String) throws {
        var title: String?
        var size3D: Int?
        var size1D: Int?
        var domainMin = RGB(0, 0, 0)
        var domainMax = RGB(1, 1, 1)
        var entries: [RGB] = []
        var lineNumber = 0

        for rawLine in text.split(omittingEmptySubsequences: false, whereSeparator: { $0.isNewline }) {
            lineNumber += 1
            var line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            if let hash = line.firstIndex(of: "#") {
                line = String(line[..<hash]).trimmingCharacters(in: .whitespaces)
                if line.isEmpty { continue }
            }
            let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
            guard let head = parts.first else { continue }

            switch head.uppercased() {
            case "TITLE":
                let rest = line.dropFirst(head.count).trimmingCharacters(in: .whitespaces)
                title = rest.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            case "LUT_3D_SIZE":
                guard parts.count >= 2, let n = Int(parts[1]) else { throw ParseError.malformedLine(lineNumber) }
                guard n >= 2, n <= Self.max3DSize else { throw ParseError.invalidSize(n) }
                size3D = n
            case "LUT_1D_SIZE":
                guard parts.count >= 2, let n = Int(parts[1]) else { throw ParseError.malformedLine(lineNumber) }
                guard n >= 2, n <= Self.max1DSize else { throw ParseError.invalidSize(n) }
                size1D = n
            case "DOMAIN_MIN":
                domainMin = try Self.parseTriple(parts, line: lineNumber)
            case "DOMAIN_MAX":
                domainMax = try Self.parseTriple(parts, line: lineNumber)
            case "LUT_3D_INPUT_RANGE", "LUT_1D_INPUT_RANGE":
                guard parts.count >= 3, let lo = Float(parts[1]), let hi = Float(parts[2]) else {
                    throw ParseError.malformedLine(lineNumber)
                }
                domainMin = RGB(repeating: lo)
                domainMax = RGB(repeating: hi)
            default:
                if parts.count >= 3, let r = Float(parts[0]), let g = Float(parts[1]), let b = Float(parts[2]) {
                    guard r.isFinite, g.isFinite, b.isFinite else { throw ParseError.nonFiniteValue(line: lineNumber) }
                    entries.append(RGB(r, g, b))
                } else if head.first?.isLetter == true {
                    continue // 未知关键字：忽略
                } else {
                    throw ParseError.malformedLine(lineNumber)
                }
            }
        }

        let kind: Kind
        let size: Int
        let expected: Int
        if let n = size3D {
            kind = .threeD
            size = n
            expected = n * n * n
        } else if let n = size1D {
            kind = .oneD
            size = n
            expected = n
        } else {
            throw ParseError.missingSize
        }
        guard entries.count == expected else {
            throw ParseError.entryCountMismatch(expected: expected, actual: entries.count)
        }
        guard domainMax.x > domainMin.x, domainMax.y > domainMin.y, domainMax.z > domainMin.z else {
            throw ParseError.invalidDomain
        }

        self.title = title
        self.kind = kind
        self.size = size
        self.domainMin = domainMin
        self.domainMax = domainMax
        self.entries = entries
    }

    private static func parseTriple(_ parts: [String], line: Int) throws -> RGB {
        guard parts.count >= 4, let a = Float(parts[1]), let b = Float(parts[2]), let c = Float(parts[3]),
              a.isFinite, b.isFinite, c.isFinite else {
            throw ParseError.malformedLine(line)
        }
        return RGB(a, b, c)
    }

    private var hasStandardDomain: Bool {
        domainMin == RGB(0, 0, 0) && domainMax == RGB(1, 1, 1)
    }

    /// 在 LUT 自己的定义域里取样（u 已归一化到 0…1）。
    public func sample(normalized u: RGB) -> RGB {
        let u = ColorMath.clamp01(u)
        switch kind {
        case .oneD:
            func channel(_ value: Float, _ pick: (RGB) -> Float) -> Float {
                let p = value * Float(size - 1)
                let i0 = min(Int(p), size - 1)
                let i1 = min(i0 + 1, size - 1)
                let f = p - Float(i0)
                return pick(entries[i0]) * (1 - f) + pick(entries[i1]) * f
            }
            return RGB(channel(u.x) { $0.x }, channel(u.y) { $0.y }, channel(u.z) { $0.z })
        case .threeD:
            let n = size
            let p = u * Float(n - 1)
            let r0 = min(Int(p.x), n - 1), g0 = min(Int(p.y), n - 1), b0 = min(Int(p.z), n - 1)
            let r1 = min(r0 + 1, n - 1), g1 = min(g0 + 1, n - 1), b1 = min(b0 + 1, n - 1)
            let fr = p.x - Float(r0), fg = p.y - Float(g0), fb = p.z - Float(b0)
            func e(_ r: Int, _ g: Int, _ b: Int) -> RGB { entries[(b * n + g) * n + r] }
            let c00 = e(r0, g0, b0) * (1 - fr) + e(r1, g0, b0) * fr
            let c10 = e(r0, g1, b0) * (1 - fr) + e(r1, g1, b0) * fr
            let c01 = e(r0, g0, b1) * (1 - fr) + e(r1, g0, b1) * fr
            let c11 = e(r0, g1, b1) * (1 - fr) + e(r1, g1, b1) * fr
            let c0 = c00 * (1 - fg) + c10 * fg
            let c1 = c01 * (1 - fg) + c11 * fg
            return c0 * (1 - fb) + c1 * fb
        }
    }

    /// 输入颜色（0…1 sRGB）→ 输出颜色，处理非标准定义域。
    public func map(_ color: RGB) -> RGB {
        let u = (color - domainMin) / (domainMax - domainMin)
        return sample(normalized: u)
    }

    /// 转成 Core Image 可用的立方体；必要时重新采样到 0…1 定义域、≤64 格点。
    public func colorCube(intensity: Float = 1) -> ColorCube {
        let cube: ColorCube
        if kind == .threeD, hasStandardDomain, size <= Self.maxCubeDimension {
            var values = [Float]()
            values.reserveCapacity(entries.count * 4)
            for e in entries {
                values.append(e.x)
                values.append(e.y)
                values.append(e.z)
                values.append(1)
            }
            cube = ColorCube(dimension: size, values: values)
        } else {
            let dimension = kind == .threeD ? min(size, Self.maxCubeDimension) : LUTBaker.defaultDimension
            cube = ColorCube.make(dimension: dimension) { self.map($0) }
        }
        return cube.withIntensity(intensity)
    }
}
