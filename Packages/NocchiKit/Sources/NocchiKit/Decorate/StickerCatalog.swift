import Foundation

/// 全部贴纸。ID 写进照片记录，发布后不能改。画法见 `StickerArt`。
///
/// 风格是复古印刷品（乙烯徽章、橡皮章、旧票据、纸胶带、凸字标签），不是线稿涂鸦。
public enum StickerCatalog {
    public static let all: [StickerKind] = badges + stamps + ephemera + tapes + labels + emoji

    // MARK: - 徽章（乙烯模切）

    static let badges: [StickerKind] = [
        StickerKind(id: "badge.sun", name: "太阳", category: .badge, aspect: 1, defaultSize: 0.2),
        StickerKind(id: "badge.rain", name: "下雨", category: .badge, aspect: 1, defaultSize: 0.2),
        StickerKind(id: "badge.bolt", name: "闪光", category: .badge, aspect: 0.8, defaultSize: 0.16),
        StickerKind(id: "badge.coffee", name: "咖啡", category: .badge, aspect: 1, defaultSize: 0.2),
        StickerKind(id: "badge.dog", name: "小狗", category: .badge, aspect: 1, defaultSize: 0.2),
        StickerKind(id: "badge.cat", name: "小猫", category: .badge, aspect: 1, defaultSize: 0.2),
        StickerKind(id: "badge.heart", name: "爱心", category: .badge, aspect: 1.08, defaultSize: 0.18),
        StickerKind(id: "badge.new", name: "NEW!", category: .badge, aspect: 1, defaultSize: 0.2, acceptsText: true, defaultText: "NEW!"),
        StickerKind(id: "badge.rainbow", name: "彩虹", category: .badge, aspect: 1.7, defaultSize: 0.26),
        StickerKind(id: "badge.cherry", name: "樱桃", category: .badge, aspect: 1, defaultSize: 0.18),
        StickerKind(id: "badge.lemon", name: "柠檬", category: .badge, aspect: 1, defaultSize: 0.18),
        StickerKind(id: "badge.daisy", name: "雏菊", category: .badge, aspect: 1, defaultSize: 0.18),
        StickerKind(id: "badge.camera", name: "相机", category: .badge, aspect: 1, defaultSize: 0.2),
        StickerKind(id: "badge.film", name: "胶卷", category: .badge, aspect: 1, defaultSize: 0.2),
        StickerKind(id: "badge.moon", name: "月亮", category: .badge, aspect: 1, defaultSize: 0.2),
        StickerKind(id: "badge.cake", name: "蛋糕", category: .badge, aspect: 1, defaultSize: 0.2),
        StickerKind(id: "badge.music", name: "音符", category: .badge, aspect: 1, defaultSize: 0.18),
        StickerKind(id: "badge.plane", name: "飞机", category: .badge, aspect: 1, defaultSize: 0.2)
    ]

    // MARK: - 印章（橡皮章，可以换色）

    static let stamps: [StickerKind] = [
        StickerKind(id: "stamp.postmark", name: "邮戳", category: .stamp, aspect: 1.55, defaultSize: 0.34, tintable: true, defaultTint: "#3A3A44", acceptsText: true),
        StickerKind(id: "stamp.ok", name: "OK!", category: .stamp, aspect: 1.6, defaultSize: 0.24, tintable: true, defaultTint: "#B23A2A"),
        StickerKind(id: "stamp.love", name: "LOVE", category: .stamp, aspect: 1.5, defaultSize: 0.26, tintable: true, defaultTint: "#C4593B"),
        StickerKind(id: "stamp.developed", name: "已显影", category: .stamp, aspect: 2.2, defaultSize: 0.3, tintable: true, defaultTint: "#2F4C8A"),
        StickerKind(id: "stamp.seal", name: "珍藏", category: .stamp, aspect: 1, defaultSize: 0.16, tintable: true, defaultTint: "#B23A2A"),
        StickerKind(id: "stamp.sunny", name: "好天气", category: .stamp, aspect: 1, defaultSize: 0.22, tintable: true, defaultTint: "#C4593B"),
        StickerKind(id: "stamp.best", name: "BEST", category: .stamp, aspect: 2.4, defaultSize: 0.32, tintable: true, defaultTint: "#2F5F5C"),
        StickerKind(id: "stamp.lab", name: "冲印店", category: .stamp, aspect: 1.9, defaultSize: 0.3, tintable: true, defaultTint: "#2E2924"),
        StickerKind(id: "stamp.date", name: "日期戳", category: .stamp, aspect: 2.6, defaultSize: 0.3, tintable: true, defaultTint: "#C2432F", acceptsText: true)
    ]

    // MARK: - 旧物（纸质）

    static let ephemera: [StickerKind] = [
        StickerKind(id: "ephemera.ticket", name: "电影票", category: .ephemera, aspect: 2.1, defaultSize: 0.34),
        StickerKind(id: "ephemera.stamp", name: "邮票", category: .ephemera, aspect: 0.82, defaultSize: 0.2),
        StickerKind(id: "ephemera.pricetag", name: "价签", category: .ephemera, aspect: 0.62, defaultSize: 0.16, acceptsText: true, defaultText: "¥ 9.9"),
        StickerKind(id: "ephemera.luggage", name: "行李牌", category: .ephemera, aspect: 0.56, defaultSize: 0.17, acceptsText: true, defaultText: "TRAVEL"),
        StickerKind(id: "ephemera.filmstrip", name: "胶片", category: .ephemera, aspect: 2.6, defaultSize: 0.42),
        StickerKind(id: "ephemera.corner", name: "照片角", category: .ephemera, aspect: 1, defaultSize: 0.1),
        StickerKind(id: "ephemera.receipt", name: "小票", category: .ephemera, aspect: 0.58, defaultSize: 0.2),
        StickerKind(id: "ephemera.matchbox", name: "火柴盒", category: .ephemera, aspect: 1.5, defaultSize: 0.24),
        StickerKind(id: "ephemera.label", name: "编号标签", category: .ephemera, aspect: 1.5, defaultSize: 0.2, acceptsText: true, defaultText: "No. 7")
    ]

    // MARK: - 胶带

    static let tapes: [StickerKind] = [
        StickerKind(id: "tape.kraft", name: "牛皮纸胶带", category: .tape, aspect: 3.6, defaultSize: 0.36),
        StickerKind(id: "tape.washi", name: "和纸胶带", category: .tape, aspect: 3.6, defaultSize: 0.36),
        StickerKind(id: "tape.stripe", name: "条纹胶带", category: .tape, aspect: 3.6, defaultSize: 0.36),
        StickerKind(id: "tape.check", name: "格纹胶带", category: .tape, aspect: 3.6, defaultSize: 0.36),
        StickerKind(id: "tape.dots", name: "波点胶带", category: .tape, aspect: 3.6, defaultSize: 0.36),
        StickerKind(id: "tape.grid", name: "方格胶带", category: .tape, aspect: 3.6, defaultSize: 0.36)
    ]

    // MARK: - 标签（可以打字）

    static let labels: [StickerKind] = [
        StickerKind(id: "label.embossed", name: "凸字标签（黑）", category: .label, aspect: 4.2, defaultSize: 0.42, tintable: true, defaultTint: "#1E1E1E", acceptsText: true, defaultText: "NOCCHI"),
        StickerKind(id: "label.embossed.red", name: "凸字标签（红）", category: .label, aspect: 4.2, defaultSize: 0.42, tintable: true, defaultTint: "#B23A2A", acceptsText: true, defaultText: "SAY CHEESE"),
        StickerKind(id: "label.typed", name: "打字机纸条", category: .label, aspect: 4.6, defaultSize: 0.5, acceptsText: true, defaultText: "今天也很好")
    ]

    // MARK: - 表情（乙烯模切）

    /// 做成贴纸的系统表情。
    public static let emojiCharacters: [String] = [
        "😀", "🥰", "😎", "🤩", "🌈", "🌸", "🍓", "🍰", "☕️", "🐶", "🐱", "⭐️",
        "✨", "❤️", "📷", "🎞️", "🎂", "🎉", "🍀", "🌙", "☀️", "🌧️", "💌", "🎀", "👑"
    ]

    static let emoji: [StickerKind] = emojiCharacters.map {
        StickerKind(id: "emoji." + $0, name: $0, category: .emoji, aspect: 1, defaultSize: 0.16)
    }

    // MARK: - 查询

    private static let byID: [String: StickerKind] = {
        var map: [String: StickerKind] = [:]
        for kind in all where map[kind.id] == nil {
            map[kind.id] = kind
        }
        return map
    }()

    public static func kinds(in category: StickerCategory) -> [StickerKind] {
        all.filter { $0.category == category }
    }

    public static func kind(id: String) -> StickerKind? {
        byID[id]
    }

    /// 装饰台里的建议标签（按这个顺序显示）。
    public static let suggestedTags: [String] = ["阳光", "雨天", "闪光", "咖啡", "小狗", "猫咪", "旅行", "朋友", "生日", "夜晚"]

    private static let tagMap: [String: String] = [
        "阳光": "badge.sun", "晴天": "badge.sun", "sun": "badge.sun", "sunny": "badge.sun",
        "雨天": "badge.rain", "下雨": "badge.rain", "rain": "badge.rain", "rainy": "badge.rain",
        "闪光": "badge.bolt", "flash": "badge.bolt",
        "咖啡": "badge.coffee", "coffee": "badge.coffee",
        "小狗": "badge.dog", "狗": "badge.dog", "dog": "badge.dog", "puppy": "badge.dog",
        "猫咪": "badge.cat", "猫": "badge.cat", "cat": "badge.cat", "kitty": "badge.cat",
        "旅行": "ephemera.luggage", "travel": "ephemera.luggage", "trip": "ephemera.luggage",
        "朋友": "badge.heart", "friend": "badge.heart", "friends": "badge.heart", "love": "badge.heart",
        "生日": "badge.cake", "birthday": "badge.cake",
        "夜晚": "badge.moon", "晚上": "badge.moon", "night": "badge.moon"
    ]

    /// 标签（有没有 # 都行）→ 自动贴纸的 kind ID；不认识的标签返回 nil。
    public static func kindID(forTag tag: String) -> String? {
        let key = PhotoRecord.normalizedTag(tag).lowercased()
        guard !key.isEmpty else { return nil }
        return tagMap[key]
    }

    /// 贴上一枚能写字的贴纸时预先填的文字（邮戳、日期戳带上照片的日期）。
    public static func initialText(for kind: StickerKind, date: Date) -> String? {
        guard kind.acceptsText else { return nil }
        switch kind.id {
        case "stamp.postmark":
            return "NOCCHI · " + Self.dotted.string(from: date)
        case "stamp.date":
            return Self.dateStamp.string(from: date).uppercased()
        default:
            return kind.defaultText
        }
    }

    private static let dotted: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy.MM.dd"
        return f
    }()

    private static let dateStamp: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy MMM dd"
        return f
    }()
}

public extension StickerPlacement {
    /// 由 UUID 字节推出的稳定随机种子（不用 hashValue，每次启动都一样）。
    var stableSeed: UInt64 {
        var raw = id.uuid
        var a: UInt64 = 0
        var b: UInt64 = 0
        withUnsafeBytes(of: &raw) { bytes in
            for i in 0..<8 {
                a |= UInt64(bytes[i]) << UInt64(8 * i)
            }
            for i in 8..<16 {
                b |= UInt64(bytes[i]) << UInt64(8 * (i - 8))
            }
        }
        return a ^ (b &* 0x9E37_79B9_7F4A_7C15)
    }
}
