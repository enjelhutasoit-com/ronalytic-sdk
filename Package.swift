// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Ronalytic",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "Ronalytic", targets: ["Ronalytic"]),
        .library(name: "RonalyticCore", targets: ["RonalyticCore"]),
        .library(name: "RonalyticLifecycle", targets: ["RonalyticLifecycle"]),
        .library(name: "RonalyticFileStorage", targets: ["RonalyticFileStorage"]),
        .library(name: "RonalyticHTTP", targets: ["RonalyticHTTP"]),
        .library(name: "RonalyticTestSupport", targets: ["RonalyticTestSupport"])
    ],
    targets: [
        .target(name: "RonalyticCore"),
        .target(name: "RonalyticLifecycle", dependencies: ["RonalyticCore"]),
        .target(name: "RonalyticFileStorage", dependencies: ["RonalyticCore"]),
        .target(name: "RonalyticHTTP", dependencies: ["RonalyticCore"]),
        .target(name: "RonalyticTestSupport", dependencies: ["RonalyticCore"]),
        .target(name: "Ronalytic", dependencies: ["RonalyticCore", "RonalyticLifecycle"]),
        .testTarget(
            name: "RonalyticCoreTests",
            dependencies: ["RonalyticCore", "RonalyticTestSupport"]
        )
    ]
)
