// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "EstadoParques",
    platforms: [
        .macOS(.v12)
    ],
    dependencies: [
        .package(url: "https://github.com/TootSDK/TootSDK.git", from: "0.20.0"),
    ],
    targets: [
        .executableTarget(
            name: "EstadoParques",
            dependencies: [
                .product(name: "TootSDK", package: "TootSDK"),
            ],
            path: "Sources/EstadoParques"
        ),
    ]
)
