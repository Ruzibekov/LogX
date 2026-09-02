// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LogX",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "LogXCore", targets: ["LogXCore"]),
        .executable(name: "LogX", targets: ["LogX"]),
    ],
    targets: [
        .target(name: "LogXCore", path: "Sources/LogXCore"),
        .executableTarget(name: "LogX", dependencies: ["LogXCore"], path: "Sources/LogX"),
        .testTarget(name: "LogXTests", dependencies: ["LogXCore", "LogX"], path: "Tests/LogXTests"),
    ]
)
