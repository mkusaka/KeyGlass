// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "KeyGlassSparkle",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "KeyGlassSparkle",
            targets: ["KeyGlassSparkle"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/sparkle-project/Sparkle",
            from: "2.9.0"
        ),
    ],
    targets: [
        .target(
            name: "KeyGlassSparkle",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
            ]
        ),
    ]
)
