// swift-tools-version: 5.9
//
// NocchiKit：macOS 与 iOS 两个 App 共享的「暗房」核心。
// 只放与平台无关、可单元测试的逻辑：胶卷配方、LUT、Core Image 管线、
// 显影模型、甩动检测、相纸排版、照片库与程序化音效。
import PackageDescription

let package = Package(
    name: "NocchiKit",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "NocchiKit", targets: ["NocchiKit"])
    ],
    targets: [
        .target(
            name: "NocchiKit",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "NocchiKitTests",
            dependencies: ["NocchiKit"]
        )
    ]
)
