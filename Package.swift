// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "UNCmorfi",
    platforms: [
       .macOS(.v12)
    ],
    dependencies: [
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "1.7.4"),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "Run",
            dependencies: [
                .target(name: "Server")
            ]
        ),

        .target(
            name: "Server",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                "SwiftSoup"
            ],
            swiftSettings: [
                // Enable better optimizations when building in Release configuration. Despite the use of
                // the `.unsafeFlags` construct required by SwiftPM, this flag is recommended for Release
                // builds. See <https://github.com/swift-server/guides/blob/main/docs/building.md#building-for-production> for details.
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
            ]
        ),
        .testTarget(
            name: "ServerTests",
            dependencies: [
                .target(name: "Server"),
                .product(name: "XCTVapor", package: "vapor"),
            ]
        )
    ]
)
