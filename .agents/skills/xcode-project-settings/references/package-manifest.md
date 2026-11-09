# Package manifest strictness

Required when you write or change a `Package.swift`. Both examples pass `swiftformat --lint` and `swiftlint lint --strict` with the project's configuration, and `swift package dump-package` resolves both. The typecheck is replaced by the manifest dump because a manifest is compiled by SwiftPM, not by the app's compiler flags. Each example sits beside two stub source files (`public struct Marker: Sendable {}` and an `import Testing` test file) that are omitted surroundings.

The checks verify these items: tools version 6.4, `.macOS(.v27)` and `.iOS(.v27)`, `swiftLanguageModes: [.v6]`, `.treatAllWarnings(as: .error)` and `.strictMemorySafety()` on every target, the four upcoming features (`ExistentialAny`, `NonisolatedNonsendingByDefault`, `InferIsolatedConformances` and `MemberImportVisibility`), and an explicit `.defaultIsolation(nil)` so the library is `nonisolated` by declaration.

## POSITIVE: every strictness item is present

Evidence: `swift package dump-package` lists `platformName` `macos` and `ios` at `27.0`, `swiftLanguageVersions` `["6"]`, tools `6.4.0`, and for both `AppCore` and `AppCoreTests` the settings `treatAllWarnings: error`, `strictMemorySafety`, `enableUpcomingFeature` for `ExistentialAny`, `NonisolatedNonsendingByDefault`, `InferIsolatedConformances` and `MemberImportVisibility`, and `defaultIsolation: nonisolated`. Formatter and linter report zero findings. `.defaultIsolation(nil)` sets the library's isolation in the manifest instead of leaving it to the tools default. One shared `strictSettings` array holds the settings, so a target that takes the array gets all of them; a `.target(name:)` that omits `swiftSettings:` is still valid, which is why the dump is the check.

```swift
// swift-tools-version: 6.4
import PackageDescription

/// Strictness that every target of this package shares; Xcode build settings do not reach SwiftPM targets.
let strictSettings: [SwiftSetting] = [
    .treatAllWarnings(as: .error),
    .strictMemorySafety(),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .defaultIsolation(nil),
]

/// The local package that holds the models and domain logic; the app target links its product.
let package = Package(
    name: "AppCore",
    platforms: [.macOS(.v27), .iOS(.v27)],
    products: [.library(name: "AppCore", targets: ["AppCore"])],
    targets: [
        .target(name: "AppCore", swiftSettings: strictSettings),
        .testTarget(name: "AppCoreTests", dependencies: ["AppCore"], swiftSettings: strictSettings),
    ],
    swiftLanguageModes: [.v6],
)
```

## NEGATIVE: warnings are not errors in the package

Evidence: identical to the positive example except that `.treatAllWarnings(as: .error)` is absent. `swift package dump-package` lists no `treatAllWarnings` under the settings of `AppCore` and `AppCoreTests`, only `strictMemorySafety`, the four upcoming features and `defaultIsolation: nonisolated`, so a warning in the package builds. Formatter and linter report zero findings, because the defect is a missing setting that no tool reads; only the dump or a reviewer sees it. The doc comment above `strictSettings` is unchanged and now overstates the array, which is the trap.

```swift
// swift-tools-version: 6.4
import PackageDescription

/// Strictness that every target of this package shares; Xcode build settings do not reach SwiftPM targets.
let strictSettings: [SwiftSetting] = [
    .strictMemorySafety(),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .defaultIsolation(nil),
]

/// The local package that holds the models and domain logic; the app target links its product.
let package = Package(
    name: "AppCore",
    platforms: [.macOS(.v27), .iOS(.v27)],
    products: [.library(name: "AppCore", targets: ["AppCore"])],
    targets: [
        .target(name: "AppCore", swiftSettings: strictSettings),
        .testTarget(name: "AppCoreTests", dependencies: ["AppCore"], swiftSettings: strictSettings),
    ],
    swiftLanguageModes: [.v6],
)
```
