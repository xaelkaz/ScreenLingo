// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ScreenLingo",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "ScreenLingo", targets: ["ScreenLingo"]),
        .executable(name: "ScreenLingoChecks", targets: ["ScreenLingoChecks"])
    ],
    targets: [
        .target(
            name: "ScreenLingoCore",
            path: "Sources/ScreenLingoCore"
        ),
        .executableTarget(
            name: "ScreenLingo",
            dependencies: ["ScreenLingoCore"],
            path: "Sources/ScreenLingo"
        ),
        .executableTarget(
            name: "ScreenLingoChecks",
            dependencies: ["ScreenLingoCore"],
            path: "Tests/ScreenLingoChecks"
        )
    ],
    swiftLanguageModes: [.v5]
)
