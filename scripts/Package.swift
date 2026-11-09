// swift-tools-version: 6.4
import PackageDescription

/// Compiler diagnostics for our tooling targets; third-party targets keep their own settings.
let safetySettings: [SwiftSetting] = [
    .treatAllWarnings(as: .error),
    .unsafeFlags(["-strict-memory-safety"]),
    .enableUpcomingFeature("ExistentialAny"),
]

/// The developer-tool package, independent of the consuming application's architecture.
let package = Package(
    name: "TemplateTools",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "template", targets: ["TemplateCLI"])],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", exact: "1.8.2"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", exact: "604.0.0"),
    ],
    targets: [
        .target(
            name: "ToolingCore",
            dependencies: [
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ],
            swiftSettings: safetySettings,
        ),
        .executableTarget(
            name: "TemplateCLI",
            dependencies: [
                "ToolingCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            swiftSettings: safetySettings,
        ),
        .testTarget(name: "ToolingCoreTests", dependencies: ["ToolingCore"], swiftSettings: safetySettings),
    ],
    swiftLanguageModes: [.v6],
)
