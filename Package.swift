// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "OpenRow",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "OpenRow", targets: ["OpenRow"]),
        .executable(name: "OpenRowFixture", targets: ["OpenRowFixture"]),
    ],
    targets: [
        .executableTarget(
            name: "OpenRow",
            linkerSettings: [
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
        .executableTarget(name: "OpenRowFixture"),
        .testTarget(name: "OpenRowTests", dependencies: ["OpenRow"]),
    ],
    swiftLanguageModes: [.v6]
)
