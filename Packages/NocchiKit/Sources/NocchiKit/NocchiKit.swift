import Foundation

/// NocchiKit 命名空间与版本信息。
public enum NocchiKit {
    public static let version = "0.1.0"

    /// 产品名（中文 / 英文）。
    public static let productName = "刘海冲印店"
    public static let productNameEnglish = "Nocchi"
}

extension KeyedDecodingContainer {
    /// 解码可选字段，缺省时回落到默认值。让 JSON 配方可以只写和默认值不同的字段。
    func decode<T: Decodable>(_ key: Key, default value: T) throws -> T {
        try decodeIfPresent(T.self, forKey: key) ?? value
    }
}
