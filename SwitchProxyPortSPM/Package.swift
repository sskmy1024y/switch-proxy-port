// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "SwitchProxyPort",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "SwitchProxyPort",
            targets: ["SwitchProxyPort"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "SwitchProxyPort",
            dependencies: [],
            resources: [
                .process("Resources")
            ]
        )
    ]
)