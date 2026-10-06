// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SanguoshaJi",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SanguoshaCore", targets: ["SanguoshaCore"]),
        .executable(name: "SanguoshaJi", targets: ["SanguoshaApp"])
    ],
    targets: [
        .target(name: "SanguoshaCore"),
        .executableTarget(name: "SanguoshaApp", dependencies: ["SanguoshaCore"], resources: [.copy("Resources/CardArt.png")]),
        .testTarget(name: "SanguoshaCoreTests", dependencies: ["SanguoshaCore"])
    ]
)
