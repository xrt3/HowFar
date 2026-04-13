// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MileMateLiveActivityAttributes",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "MileMateLiveActivityAttributes", targets: ["MileMateLiveActivityAttributes"]),
    ],
    targets: [
        .target(
            name: "MileMateLiveActivityAttributes",
            dependencies: []
        ),
    ]
)
