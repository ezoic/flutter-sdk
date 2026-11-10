// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ezoic_flutter_cmp_sdk",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "ezoic-flutter-cmp-sdk", targets: ["ezoic_flutter_cmp_sdk"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        // Native Ezoic CMP (pre-built XCFramework, no other dependencies).
        // Kept in lockstep with the plugin version.
        .package(url: "https://github.com/ezoic/ezoic-swift-sdk-dist.git", from: "1.22.0")
    ],
    targets: [
        .target(
            name: "ezoic_flutter_cmp_sdk",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "EzoicCmpSDK", package: "ezoic-swift-sdk-dist")
            ]
        )
    ]
)
