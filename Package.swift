// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "OpenEngine",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(name: "OpenEngine", targets: ["OpenEngineApp"]),
        .library(name: "WallpaperKit", targets: ["WallpaperKit"]),
    ],
    targets: [
        .target(
            name: "WallpaperKit",
            dependencies: [],
            path: "Sources/WallpaperKit",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .executableTarget(
            name: "OpenEngineApp",
            dependencies: ["WallpaperKit"],
            path: "Sources/OpenEngineApp",
            resources: [
                .process("Resources"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
    ]
)
