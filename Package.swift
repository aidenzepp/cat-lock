// swift-tools-version: 6.0
import PackageDescription

/// The standalone macOS helper and its strict Swift compilation policy.
let package = Package(
    name: "CatLock",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "CatLock", targets: ["CatLock"])],
    targets: [.executableTarget(name: "CatLock", swiftSettings: [
        .enableUpcomingFeature("ExistentialAny"),
        .unsafeFlags(["-strict-memory-safety", "-warnings-as-errors"]),
    ])],
)
