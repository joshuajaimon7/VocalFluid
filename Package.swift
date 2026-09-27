// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VocalFluid",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0")
    ],
    targets: [
        .executableTarget(
            name: "VocalFluid",
            dependencies: [
                .product(name: "WhisperKit", package: "WhisperKit")
            ],
            path: "Sources/VocalFluid",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
