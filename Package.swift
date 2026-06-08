// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ParallelMeIOS",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "ParallelMeCore", targets: ["ParallelMeCore"]),
        .library(name: "ParallelMeDesign", targets: ["ParallelMeDesign"]),
        .library(name: "ParallelMeUI", targets: ["ParallelMeUI"]),
        .executable(name: "ParallelMeCoreSmokeTests", targets: ["ParallelMeCoreSmokeTests"])
    ],
    targets: [
        .target(name: "ParallelMeCore"),
        .target(name: "ParallelMeDesign"),
        .target(
            name: "ParallelMeUI",
            dependencies: ["ParallelMeCore", "ParallelMeDesign"]
        ),
        .executableTarget(
            name: "ParallelMeCoreSmokeTests",
            dependencies: ["ParallelMeCore", "ParallelMeUI"]
        )
    ]
)
