// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Vela",
    defaultLocalization: "pt",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Vela", targets: ["Vela"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Vela",
            path: "Sources/Vela",
            exclude: ["Resources/Info.plist"],
            resources: [
                .process("Resources/pt.lproj"),
                .process("Resources/en.lproj")
            ]
        )
    ]
)
