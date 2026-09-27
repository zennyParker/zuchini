// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Zuchini",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "ZuchiniCore", targets: ["ZuchiniCore"]),
        .library(name: "ZuchiniMenu", targets: ["ZuchiniMenu"])
    ],
    targets: [
        .target(name: "ZuchiniCore"),
        .target(name: "ZuchiniMenu", dependencies: ["ZuchiniCore"]),
        .testTarget(name: "ZuchiniCoreTests", dependencies: ["ZuchiniCore", "ZuchiniMenu"])
    ]
)
