# Unchecked invariants: labeled examples

Read before writing or reviewing `Dictionary(uniqueKeysWithValues:)`. The shape is the one every row of the skill's unchecked-invariants table shares: the invariant is written beside the code, and a reviewer checks that it holds. The compiler and the linter accept every call below, so each label rests on whether the invariant is true.

Every example was extracted to its own Swift file, with any stubs it names, and run from the repository root through the pinned SwiftFormat (`--lint --config .swiftformat`), the pinned SwiftLint (`lint --strict --config .swiftlint.yml`) and `xcrun swiftc -typecheck -swift-version 6 -strict-memory-safety -warnings-as-errors`. All three are package code, so `-default-isolation MainActor` is off.

## 1. POSITIVE: keys unique by construction, with the source named

Placement: local package. Checks: format pass, lint pass, typecheck pass.

Evidence: the keys come from `ReleaseChannel.allCases`, which lists each case exactly once, so the initializer's precondition (no duplicate keys) holds on every call. The comment names that source, so a reviewer can check it, and adding a case cannot break it.

```swift
/// A release track that the feed publishes separately.
public enum ReleaseChannel: String, CaseIterable, Sendable {
    /// Releases for everyone.
    case stable
    /// Releases for testers, ahead of stable.
    case beta
}

/// Whether each channel is followed when the app first runs: only the stable channel is.
///
/// - Returns: One entry for every channel.
func initialFollowedChannels() -> [ReleaseChannel: Bool] {
    // Keys are unique by construction: `allCases` lists each channel exactly once.
    Dictionary(uniqueKeysWithValues: ReleaseChannel.allCases.map {
        ($0, $0 == .stable)
    })
}
```

## 2. NEGATIVE: keys from outside data

Placement: local package. Checks: format pass, lint pass, typecheck pass. The defect is a judgment rule that no tool sees.

Omitted surroundings: `Release` (failure-paths.md, Example 1).

Evidence: `releases` comes from the network feed, and nothing makes its versions unique. A feed that lists one version twice traps at run time, because `Dictionary(uniqueKeysWithValues:)` requires a sequence with no duplicate keys. No comment could name a source of uniqueness, which is the sign that this initializer is wrong here.

```swift
import Foundation

/// The feed's releases, keyed by version.
///
/// - Parameter releases: The releases the feed listed.
/// - Returns: Each listed version and its release.
func releasesByVersion(_ releases: [Release]) -> [String: Release] {
    Dictionary(uniqueKeysWithValues: releases.map {
        ($0.version, $0)
    })
}
```

## 3. POSITIVE: outside data with a stated merge

Placement: local package. Checks: format pass, lint pass, typecheck pass.

Omitted surroundings: `Release` (failure-paths.md, Example 1).

Evidence: `Dictionary(_:uniquingKeysWith:)` accepts repeated keys, and the doc comment says which listing wins, so a repeated version neither traps nor leaves the choice unstated.

```swift
import Foundation

/// The feed's releases, keyed by version.
///
/// The feed is outside the app's control and can list a version twice; the first listing wins.
///
/// - Parameter releases: The releases the feed listed.
/// - Returns: Each listed version and its first release.
func releasesByVersion(_ releases: [Release]) -> [String: Release] {
    Dictionary(
        releases.map {
            ($0.version, $0)
        },
        uniquingKeysWith: { first, _ in
            first
        },
    )
}
```
