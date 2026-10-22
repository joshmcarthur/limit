// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Limit",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "LimitCore", targets: ["LimitCore"]),
    ],
    targets: [
        // Platform-independent logic. Foundation only, so it builds and tests on Linux.
        .target(name: "LimitCore"),
        .testTarget(name: "LimitCoreTests", dependencies: ["LimitCore"]),
    ]
)
