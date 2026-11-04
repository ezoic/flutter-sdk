// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ezoic_flutter_sdk",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "ezoic-flutter-sdk", targets: ["ezoic_flutter_sdk"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        // Native Ezoic Ads SDK (pre-built XCFramework + Prebid / GMA / APS
        // transitive packages). Kept in lockstep with the plugin version.
        .package(url: "https://github.com/ezoic/ezoic-swift-sdk-dist.git", from: "1.21.0")
    ],
    targets: [
        .target(
            name: "ezoic_flutter_sdk",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "EzoicAdsSDK", package: "ezoic-swift-sdk-dist")
            ]
        )
    ]
)
