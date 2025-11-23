// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "PhotoboothApp",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "PhotoboothApp",
            targets: ["PhotoboothApp"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "PhotoboothApp",
            dependencies: [],
            path: "Sources"),
    ]
)
