// swift-tools-version: 5.9

import PackageDescription

// Builds the Perch executable only; build.sh wraps it into Perch.app.
let package = Package(
    name: "Perch",
    platforms: [.macOS(.v14)],
    dependencies: [
        // Local while both are still moving; versioned GitHub URLs later.
        .package(path: "../NotchKit"),
        .package(path: "../perch-core"),
    ],
    targets: [
        .executableTarget(name: "Perch", dependencies: ["PerchApp"], path: "Sources/Perch"),
        // Everything but main.swift, so the tests can import it.
        .target(
            name: "PerchApp",
            dependencies: [
                "NotchKit",
                .product(name: "PerchCore", package: "perch-core"),
            ],
            path: "Sources/App"
        ),
        .testTarget(name: "PerchTests", dependencies: ["PerchApp"]),
    ]
)
