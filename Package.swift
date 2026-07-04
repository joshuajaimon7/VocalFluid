// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FlowLocal",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0")
    ],
    targets: [
        .executableTarget(
            name: "FlowLocal",
            dependencies: [
                .product(name: "WhisperKit", package: "WhisperKit")
            ],
            path: "Sources/FlowLocal",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
