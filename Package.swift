// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "ConfigCatOpenFeatureProvider",
    platforms: [
        .iOS(.v14),
        .macOS(.v11),
    ],
    products: [
        .library(
            name: "ConfigCatOpenFeature", 
            targets: ["ConfigCatOpenFeature"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/open-feature/swift-sdk.git",
            from: "0.3.0"
        ),
        .package(
            url: "https://github.com/configcat/ios-sdk.git",
            .branch("master")
        ),
    ],
    targets: [
        .target(
            name: "ConfigCatOpenFeature",
            dependencies: [
                .product(name: "OpenFeature", package: "swift-sdk"),
                .product(name: "ConfigCat", package: "swift-sdk")
            ],
            resources: [.copy("Resources/PrivacyInfo.xcprivacy")]
        ),
        .testTarget(
            name: "ConfigCatOpenFeatureTests",
            dependencies: ["ConfigCatOpenFeature"],
            resources: [.process("Resources")]
        ),

    ],
    swiftLanguageVersions: [.v5]
)
