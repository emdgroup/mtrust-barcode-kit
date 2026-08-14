// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "mtrust_barcode_kit",
    platforms: [
        .iOS("13.0"),
    ],
    products: [
        .library(name: "mtrust-barcode-kit", targets: ["mtrust_barcode_kit"]),
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
    ],
    targets: [
        .target(
            name: "mtrust_barcode_kit",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
            ],
        ),
    ],
)
