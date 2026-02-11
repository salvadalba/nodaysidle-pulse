// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Pulse",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "Pulse", targets: ["Pulse"])
    ],
    targets: [
        .executableTarget(
            name: "Pulse",
            path: "Sources/Pulse",
            exclude: ["Pulse.entitlements"],
            resources: [.process("Resources")],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "PulseTests",
            dependencies: ["Pulse"],
            path: "Tests/PulseTests",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        )
    ]
)
