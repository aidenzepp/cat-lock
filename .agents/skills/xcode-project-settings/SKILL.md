---
name: xcode-project-settings
description: "Choose and verify per-target build settings for an Xcode app project and its local Swift package. Use when creating the app project or the package, adding a target, extension or package product, editing build settings, `swiftSettings` or `platforms`, setting a deployment target, deferring a warning group, or upgrading Xcode. Covers asset-catalog symbol settings, scheme discovery, XcodeGen projects, target-level values that silently outrank the project's xcconfig, per-target default isolation, package manifest strictness and the app/package split."
---

# Xcode project settings

Decide what tools cannot choose, and catch overrides they miss. A setting that is wrong still compiles, so verify the resolved value, not the file you edited.

## 1. Preflight

From the repository root, run the project's toolchain preflight and stop on a non-zero exit. Do not install tools; name the project's setup step instead. In this template that is `./scripts/dev.swift doctor` after `./scripts/dev.swift bootstrap`.

## 2. Confirm the project enforces

Check each item exists. If one is missing, report the gap and apply the rule by hand.

- Swift 6 language mode, complete concurrency checking and warnings as errors on every app and test target (shared xcconfig or target settings).
- The same on the package: Swift 6 mode, all warnings as errors, strict memory safety and an explicit default isolation in the manifest.
- The String Catalog settings are present, written by Xcode's template or set in `project.yml` (`SWIFT_EMIT_LOC_STRINGS`, `LOCALIZATION_PREFERS_STRING_CATALOGS`, `STRING_CATALOG_GENERATE_SYMBOLS`).
- SwiftLint runs in strict mode and SwiftFormat in lint mode (`--lint`), so a violation fails the check.
- `ExistentialAny`, `NonisolatedNonsendingByDefault`, `InferIsolatedConformances` and `MemberImportVisibility` chosen and set individually in the app's build settings and in the manifest (`.enableUpcomingFeature`), and strict memory safety on every target.
- The preflight compares the Xcode build and the SwiftLint and SwiftFormat versions with the pins.
- A check that reads resolved build settings per target, configuration and destination platform (`xcodebuild -showBuildSettings -json`), and the build log for the flags the settings cannot show.
- A check that reads the manifest (`swift package dump-package`) and fails when a strictness item is missing.

## 3. App shape

Models and domain logic go in a local Swift package that builds for macOS and iOS and is tested with `swift test`. The app target holds the `@main` App, views by default, Info.plist, entitlements, signing, assets and extensions. A consuming app may override this shape; say so when you do.

- A new type goes in the package unless it must be an app type. Views stay in the app target unless the project moved them.
- The app target links a package product; it does not compile package sources itself.
- A new extension or helper target gets its own row in step 4 and step 5 before it builds.
- Bundle identifiers and signing teams belong to the consuming app. Do not set them here.

## 4. Settings that outrank the project's configuration

Xcode's new-app template writes values at target level, including `SWIFT_VERSION = 5.0`. A target-level value beats a target's base xcconfig, so the project can look strict and build in Swift 5 mode.

1. Open the target's build settings and delete any target-level `SWIFT_VERSION`. Delete other target-level values the project's xcconfig sets, except those in step 5.
2. Resolve each app and test target by hand, per configuration and per destination platform. `-target` resolves no platform for a multiplatform target (the SDK stays `auto`), and `-list` and `-target` write the default DerivedData when the project has a package dependency and refuse `-derivedDataPath`. Name a shared scheme (item 5 makes sure one exists), then resolve through it:

   ```sh
   xcodebuild -showBuildSettings -json -project App.xcodeproj -scheme <name> -configuration Debug -destination 'platform=macOS' -derivedDataPath <scratch>
   xcodebuild -showBuildSettings -json -project App.xcodeproj -scheme <name> -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath <scratch>
   ```

3. Read the resolved values: `SWIFT_VERSION` is `6.0`, `SWIFT_TREAT_WARNINGS_AS_ERRORS` is `YES`, strict memory safety is on, and the isolation and feature settings are the ones step 5 chose. Strict memory safety counts when it is set either as `SWIFT_STRICT_MEMORY_SAFETY = YES` or as `-strict-memory-safety` in `OTHER_SWIFT_FLAGS`; a project that sets only the flag shows `SWIFT_STRICT_MEMORY_SAFETY` unset, so confirm the flag on the build log's `swiftc` line (item 4). Do this for Debug and Release on each destination platform, and again after adding a target or upgrading Xcode.
4. `-showBuildSettings` omits defaults that Xcode's build-system spec files (`xcspec`) supply, so a value that does not appear is not proof it is off. The build log is the proof: build once and read the `swiftc` invocation for each flag you require (`-strict-memory-safety`, `-enable-upcoming-feature <Name>`).
5. Scheme discovery. Xcode creates a scheme for each target on the fly, and only `xcodebuild -list` shows those; they are not files. Look in `<App>.xcodeproj/xcshareddata/xcschemes/` for a `.xcscheme` file. If there is none, make one shared and take the name from the file: in an Xcode project, Product > Scheme > Manage Schemes, tick Shared; for XcodeGen, declare it in `project.yml` (see section 5b). With a shared scheme, `-showdestinations`, `-showBuildSettings`, `-showTestPlans` and `build` all accept `-scheme <name>` together with `-derivedDataPath <scratch>` and write nothing outside it. Observed on Xcode 27 builds. `-showTestPlans` on a scheme with no test plan prints that the scheme is not configured to use test plans, which is not a failure.

This proves settings, not a passing build. Keep the String Catalog settings, whether Xcode's template or `project.yml` provides them (`SWIFT_EMIT_LOC_STRINGS`, `LOCALIZATION_PREFERS_STRING_CATALOGS`, `STRING_CATALOG_GENERATE_SYMBOLS`) and `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY`.

## 5. Isolation per target

Default isolation is per module and never reaches an imported module ([SE-0466](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0466-control-default-actor-isolation.md)).

| Target | Default isolation |
| --- | --- |
| App target | `MainActor`: `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` |
| Extension target | decide per extension and record the choice; the setting is per module |
| Package library | `nonisolated`, stated in the manifest: `.defaultIsolation(nil)`; do not add `.defaultIsolation(MainActor.self)` |
| Package executable | `MainActor` is allowed via `.defaultIsolation(MainActor.self)` |
| Test target | decide per test target and set it; the setting is per module, so it does not follow the module under test |

- Set `ExistentialAny`, `NonisolatedNonsendingByDefault`, `InferIsolatedConformances` and `MemberImportVisibility` individually in both places: `SWIFT_UPCOMING_FEATURE_EXISTENTIAL_ANY`, `SWIFT_UPCOMING_FEATURE_NONISOLATED_NONSENDING_BY_DEFAULT`, `SWIFT_UPCOMING_FEATURE_INFER_ISOLATED_CONFORMANCES` and `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY` for the app, `.enableUpcomingFeature("ExistentialAny")`, `.enableUpcomingFeature("NonisolatedNonsendingByDefault")`, `.enableUpcomingFeature("InferIsolatedConformances")` and `.enableUpcomingFeature("MemberImportVisibility")` in the manifest, so app and package are equally strict and run a `nonisolated async` function in the same place. Do not rely on `SWIFT_APPROACHABLE_CONCURRENCY` instead. On Xcode 27 `SWIFT_UPCOMING_FEATURE_NONISOLATED_NONSENDING_BY_DEFAULT` and `SWIFT_UPCOMING_FEATURE_INFER_ISOLATED_CONFORMANCES` default to its value with no condition (`Swift.xcspec` lines 906 and 925), so it turns both on in Swift 6 mode, and a probe build with it set to `NO` passed neither flag. The default is Xcode's, not the project's, and `-showBuildSettings` does not show it (step 4, item 4). Setting each feature explicitly keeps the result independent of that default across Xcode upgrades.
- A package type that the app calls from the main actor stays `nonisolated` and `Sendable`; isolate it in the app, not by loosening the library. The exception is a package `@Observable` model that views read: declare it `@MainActor` in the package.
- Concurrency design inside either target belongs to a different skill (`swift-isolation`).

## 5a. Asset-catalog symbol settings

The asset-catalog compiler writes `GeneratedAssetSymbols.swift` with a symbol per color and image. An app names its own catalog's symbols directly (`Color(.name)`), and a shared target's public wrappers build on them (`swiftui-design-tokens`, sections 3 and 9). The settings and their defaults, from `AssetCatalogCompiler.xcspec` on Xcode 27:

| Setting | Default | Keep |
| --- | --- | --- |
| `ASSETCATALOG_COMPILER_GENERATE_ASSET_SYMBOLS` | `YES` | `YES` |
| `ASSETCATALOG_COMPILER_GENERATE_ASSET_SYMBOL_ERRORS` | `YES` | `YES` |
| `ASSETCATALOG_COMPILER_GENERATE_ASSET_SYMBOL_WARNINGS` | `YES` | `YES` |
| `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS` | `NO` | `NO` |

- The defaults are already right, so a project sets none of these. Confirm no target-level or xcconfig value overrides them. `-showBuildSettings` omits xcspec defaults (step 4, item 4), so absence from its output is expected; a value you set does appear.
- `GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES` adds the symbols as extensions on Apple's `Color` and `Image` types. Leave it off in an app's own catalog as well as in a shared target. Then each color set has one spelling, `Color(.name)` in the app or `ColorResource.name` inside a wrapper, and a set's name could shadow a member Apple already defines. The skill has not built with this setting on, so this is the reason to keep it off, not a measured failure.
- No setting controls access level: the generated symbols are internal to the module that builds the catalog. SwiftPM generates the same symbols for a package catalog.
- To prove generation, build and find `GeneratedAssetSymbols.swift` under the `DerivedSources` folder of the module that owns the catalog.
- `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME` has no default in `AssetCatalogCompiler.xcspec` on Xcode 27 (its entry has no `DefaultValue`), and Xcode's app template writes it as `AccentColor`; an app not made from that template must set it.

## 5b. If XcodeGen creates the project

An app may be created in Xcode or from a `project.yml` that [XcodeGen](https://github.com/yonaskolb/XcodeGen) turns into the `.xcodeproj`. Everything above applies to both; only who writes the settings differs. Observed on Xcode 27 builds with a generated project.

- XcodeGen writes none of the String Catalog settings or `SWIFT_DEFAULT_ACTOR_ISOLATION`. Set them in the target's `settings: base:` yourself, with the deployment targets, `GENERATE_INFOPLIST_FILE` and signing values the app needs.
- XcodeGen also writes no `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME`: the generated trial project had none, so set it to `AccentColor` in the app target's `settings: base:` in `project.yml`, or the AccentColor set changes nothing.
- Attach `config/Strict.xcconfig` as the target's base configuration through `configFiles`, for each configuration:

  ```yaml
  targets:
    TrialApp:
      configFiles:
        Debug: config/Strict.xcconfig
        Release: config/Strict.xcconfig
      settings:
        base:
          SWIFT_DEFAULT_ACTOR_ISOLATION: MainActor
          SWIFT_UPCOMING_FEATURE_NONISOLATED_NONSENDING_BY_DEFAULT: YES
          SWIFT_UPCOMING_FEATURE_INFER_ISOLATED_CONFORMANCES: YES
          SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY: YES
          SWIFT_EMIT_LOC_STRINGS: YES
          LOCALIZATION_PREFERS_STRING_CATALOGS: YES
          STRING_CATALOG_GENERATE_SYMBOLS: YES
  ```

  The xcconfig supplies `SWIFT_VERSION`, warnings as errors, strict memory safety and `ExistentialAny`; the YAML supplies what it leaves to the app. Do not repeat the xcconfig's keys in `settings:`: a target-level value outranks the xcconfig (step 4).
- XcodeGen sets a project-level `SWIFT_VERSION = 5.0`. The target's xcconfig outranks the project level, so a generated project resolved `6.0`. That is not the target-level trap in step 4; still resolve the value per step 4, and do not set `SWIFT_VERSION` under the target's `settings:`.
- Declare the scheme in `project.yml` so XcodeGen writes it as a shared scheme. A top-level `schemes:` entry generates `<App>.xcodeproj/xcshareddata/xcschemes/<name>.xcscheme`; without one the project has no scheme file (step 4, item 5):

  ```yaml
  schemes:
    TrialApp:
      build:
        targets:
          TrialApp: all
      run:
        config: Debug
      archive:
        config: Release
  ```

- Commit `project.yml`. Ignore the generated `.xcodeproj` and never commit it; regenerate with `xcodegen generate` after changing `project.yml`, then resolve settings again.

## 6. The package manifest

Xcode build settings do not reach SwiftPM targets, so a package built without its own strictness has none. Read [references/package-manifest.md](references/package-manifest.md) before writing or changing a manifest. Then verify what SwiftPM resolved:

```sh
swift package dump-package --package-path <package>
```

Confirm the tools version, both `platforms`, `swiftLanguageVersions` and, for every target including test targets, the `treatAllWarnings`, `strictMemorySafety` and `defaultIsolation` settings and the `enableUpcomingFeature` entries for `ExistentialAny`, `NonisolatedNonsendingByDefault`, `InferIsolatedConformances` and `MemberImportVisibility`. A target that is missing from the dump's `settings` has none.

## 7. Deployment floor and `#available`

The deployment target is the current OS on both platforms. Set `MACOSX_DEPLOYMENT_TARGET` and `IPHONEOS_DEPLOYMENT_TARGET` for each app target, and `platforms:` in the manifest to the same release.

If a project deliberately keeps an older macOS floor, every API added by the newer SDK needs an `#available` check or an `@available` declaration. The compiler enforces this; the decision to lower the floor is yours to state, not to assume.

## 8. Deferring one warning group through an Xcode upgrade

A new Xcode can add warnings that break a zero-warning build. Keep warnings as errors and defer one group only.

1. Name the group the compiler prints. Set it as a warning after the all-errors flag, because the last flag wins ([SE-0443](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0443-warning-control-flags.md)): `SWIFT_WARNINGS_AS_WARNINGS_GROUPS = <Group>` in Xcode, `.treatWarning("<Group>", as: .warning)` after `.treatAllWarnings(as: .error)` in a manifest ([SE-0480](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0480-swiftpm-warning-control.md)).
2. Put a dated comment beside it: the date, the Xcode build that raised it, the group and the issue or task that ends the deferral.
3. Defer one group per target at a time. The deferral ends when the group's warnings are fixed or at the next Xcode upgrade, whichever is first; then remove the setting and the comment.
4. Never defer by dropping `SWIFT_TREAT_WARNINGS_AS_ERRORS` or `.treatAllWarnings`.

Apple's current concurrency guidance is bundled with Xcode: `/Applications/Xcode.app/Contents/PlugIns/IDEIntelligenceChat.framework/Versions/A/Resources/AdditionalDocumentation/Swift-Concurrency-Updates.md`.

## 9. Finish

Run the project's formatter, linter and the resolved-settings and manifest checks. Report which you ran and any gap from step 2.
