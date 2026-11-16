// swift-tools-version: 6.2
import PackageDescription

/// Ejemplo de uso de StainKit: pinta una imagen de referencia trazo a trazo con las herramientas de StaiN.
let package = Package(
    name: "Replica",
    platforms: [.macOS(.v26)],
    dependencies: [.package(path: "../../Packages/StainKit")],
    targets: [
        .executableTarget(
            name: "Replica",
            dependencies: [.product(name: "StainKit", package: "StainKit")]
        )
    ],
    swiftLanguageModes: [.v6]
)
