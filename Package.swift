// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "KakuyomuDL",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(path: "../EpubBuilder"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.0.0"),
        .package(url: "https://github.com/mojzesh/swift-colorful.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "CoverCreator",
            dependencies: [
                .product(name: "Colorful", package: "swift-colorful")
            ],
            resources: [
                .process("cover.jpg")
            ]
        ),
        .executableTarget(
            name: "KakuyomuDL",
            dependencies: [
                "EpubBuilder",
                "CoverCreator",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
    ]
)
