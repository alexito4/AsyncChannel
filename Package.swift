// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "AsyncChannel",
    platforms: [.macOS(.v12)],
    products: [
        .library(
            name: "AsyncChannel",
            targets: ["AsyncChannel"]
        ),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "AsyncChannel",
            dependencies: []
        ),
        .testTarget(
            name: "AsyncChannelTests",
            dependencies: ["AsyncChannel"]
        ),
    ]
)
