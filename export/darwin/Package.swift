// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DianyaAPI",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "DianyaAPI",
            targets: ["DianyaAPI"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "DianyaAPI",
            dependencies: ["DianyaAPIFFI"],
            path: "Sources/DianyaAPI",
            cSettings: [
                .headerSearchPath("../include"),
            ]
        ),
        .binaryTarget(
            name: "DianyaAPIFFI",
            path: "DianyaAPIFFI.xcframework"
        ),
    ]
)

