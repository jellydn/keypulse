// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "KeyPulse",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "KeyPulse", targets: ["KeyPulse"])
    ],
    targets: [
        .executableTarget(
            name: "KeyPulse",
            linkerSettings: [
                .linkedFramework("Carbon")
            ]
        )
    ]
)