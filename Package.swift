// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SecFilings",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "SecEdgarKit",
            targets: ["SecEdgarKit"]
        ),
        .executable(
            name: "SecFilingsDemo",
            targets: ["SecFilingsDemo"]
        ),
    ],
    targets: [
        .target(
            name: "SecEdgarKit"
        ),
        .executableTarget(
            name: "SecFilingsDemo",
            dependencies: ["SecEdgarKit"]
        ),
    ]
)
