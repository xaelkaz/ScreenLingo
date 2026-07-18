// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "GameLingo",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "GameLingo", targets: ["GameLingo"]),
        .executable(name: "GameLingoChecks", targets: ["GameLingoChecks"])
    ],
    targets: [
        .target(
            name: "GameLingoCore",
            path: "Sources/GameLingoCore"
        ),
        .executableTarget(
            name: "GameLingo",
            dependencies: ["GameLingoCore"],
            path: "Sources/GameLingo"
        ),
        .executableTarget(
            name: "GameLingoChecks",
            dependencies: ["GameLingoCore"],
            path: "Tests/GameLingoChecks"
        )
    ],
    swiftLanguageModes: [.v5]
)
