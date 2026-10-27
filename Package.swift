// swift-tools-version: 6.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "Notion",
    products: [
        .library(name: "Notion", targets: ["Notion"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "604.0.0-latest"),
    ],
    targets: [
        .macro(
            name: "NotionMacrosImplementation",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "Notion",
            dependencies: ["NotionMacrosImplementation"],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ],
        ),
        .executableTarget(
            name: "NotionMacrosClient",
            dependencies: ["Notion"],
        ),
        .testTarget(
            name: "NotionMacrosTests",
            dependencies: ["Notion"],
        ),
    ]
)
