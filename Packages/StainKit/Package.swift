// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "StainKit",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "StainKit", targets: ["StainKit"])
    ],
    targets: [
        .target(
            name: "StainKit",
            swiftSettings: [.treatAllWarnings(as: .error)]
        ),
        .testTarget(
            name: "StainKitTests",
            dependencies: ["StainKit"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
