// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "xdiary",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "XDiaryCore", targets: ["XDiaryCore"]),
        .executable(name: "xdiary", targets: ["xdiary"]),
    ],
    targets: [
        .target(
            name: "XDiaryCore",
            path: "Sources/XDiaryCore"
        ),
        .executableTarget(
            name: "xdiary",
            dependencies: ["XDiaryCore"],
            path: "Sources/xdiary"
        ),
        .testTarget(
            name: "XDiaryCoreTests",
            dependencies: ["XDiaryCore"],
            path: "Tests/XDiaryCoreTests"
        ),
        .testTarget(
            name: "XDiaryAppTests",
            dependencies: ["xdiary", "XDiaryCore"],
            path: "Tests/XDiaryAppTests"
        ),
    ]
)
