# Parse and construct: labeled examples

Read before writing a parser, a type with an invariant, a `Decodable` conformance on a domain type, or a `-> Bool` validity check. The examples continue the release-feed domain of swift-isolation's `references/failure-paths.md`: the release's version text becomes a parsed `ReleaseVersion`.

How the examples were checked. Each code block is a complete file, checked unchanged. The declarations a block names under "Omitted surroundings" were checked beside it as further files of the same module. From the repository root, each file passed the pinned SwiftFormat (`--lint --config .swiftformat`) and the pinned SwiftLint (`lint --strict --config .swiftlint.yml`), and the module passed `xcrun swiftc -typecheck -swift-version 6 -strict-memory-safety -warnings-as-errors` with the `NonisolatedNonsendingByDefault`, `InferIsolatedConformances`, `ExistentialAny` and `MemberImportVisibility` upcoming features, once for macOS and once for iOS. All four are package code, so `-default-isolation MainActor` is off. The examples follow swift-code-layout and pass the formatter. No code was run: the behavior described below comes from reading the code against the documentation it cites.

Contents: 1 POSITIVE parser over a private init · 2 NEGATIVE validate and forget · 3 NEGATIVE open construction paths · 4 POSITIVE decode, then parse.

## 1. POSITIVE: `ReleaseVersion`, a parser over a private init

Placement: local package. Checks: format pass, lint pass, typecheck pass (macOS, iOS). A probe file in the same module that calls `ReleaseVersion(major: -1, minor: 0)` fails the typecheck: "'ReleaseVersion' initializer is inaccessible due to 'private' protection level".

Evidence: `parse(_:)` returns `Result<ReleaseVersion, ReleaseVersionError>`, so what the check learns is the result: a caller holds a version, or the reason it has none. The `private init` declared in the type body removes the memberwise initializer, and the type adopts neither `Decodable` nor a literal protocol, so `parse(_:)` is the only construction path, which the probe confirms. The documentation states the normalization policy: leading zeros compare by value, and a sign, a space or a third part is malformed. Comparing two versions has no failure case, because both sides are already versions.

```swift
/// Why text is not a release version.
public enum ReleaseVersionError: Error {
    /// The text is not two runs of the digits 0-9 joined by a period; trying again will not help.
    case malformed
}

/// A release's marketing version: a major and a minor number, such as "2.1".
///
/// ``parse(_:)`` is the only way to make one, so neither number is ever negative.
public struct ReleaseVersion: Comparable, Hashable, Sendable {
    /// The major number.
    public let major: Int
    /// The minor number within the major version.
    public let minor: Int

    /// Creates a version from numbers the parser has checked.
    ///
    /// - Parameters:
    ///   - major: The major number, never negative.
    ///   - minor: The minor number, never negative.
    private init(major: Int, minor: Int) {
        self.major = major
        self.minor = minor
    }

    /// Returns whether `lhs` is an earlier version than `rhs`, comparing major numbers first.
    ///
    /// - Parameters:
    ///   - lhs: A version.
    ///   - rhs: Another version.
    /// - Returns: `true` when `lhs` comes before `rhs`.
    public static func < (lhs: ReleaseVersion, rhs: ReleaseVersion) -> Bool {
        (lhs.major, lhs.minor) < (rhs.major, rhs.minor)
    }

    /// Parses a version that the feed or the app's bundle spells as text.
    ///
    /// The text is two runs of the digits 0-9 joined by a period. Numbers compare by value, so
    /// "2.01" and "2.1" parse to the same version.
    ///
    /// - Parameter text: The version text, such as "2.1".
    /// - Returns: The version, or ``ReleaseVersionError/malformed`` when `text` has any other shape.
    public static func parse(_ text: String) -> Result<ReleaseVersion, ReleaseVersionError> {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        let numbers = parts.compactMap {
            $0.allSatisfy(\.isWholeNumber) ? Int($0) : nil
        }
        guard parts.count == 2, numbers.count == 2, let major = numbers.first, let minor = numbers.last else {
            return .failure(.malformed)
        }

        return .success(ReleaseVersion(major: major, minor: minor))
    }
}
```

## 2. NEGATIVE: a `Bool` check, then the raw `String`

Placement: local package. Checks: format pass, lint pass, typecheck pass (macOS, iOS). The defect is a judgment rule that no tool sees.

Omitted surroundings: `ReleaseVersionError` (Example 1).

Evidence: `isValidVersion(_:)` learns that the text is a version and returns `Bool`, so the caller keeps a `String` that proves nothing. `isNewer(_:than:)` must check both texts again and returns `Result<Bool, ReleaseVersionError>`, whose failure no caller that checked first can reach, yet every caller has to handle it. Example 1 keeps what the check learns: `parse(_:)` returns a `ReleaseVersion`, and comparing two is a plain `<`.

```swift
/// Returns whether `text` is a release version: two runs of the digits 0-9 joined by a period, such as "2.1".
///
/// - Parameter text: The version text.
/// - Returns: `true` when `text` is a release version.
func isValidVersion(_ text: String) -> Bool {
    let parts = text.split(separator: ".", omittingEmptySubsequences: false)

    return parts.count == 2 && parts.allSatisfy {
        $0.allSatisfy(\.isWholeNumber) && Int($0) != nil
    }
}

/// Returns whether `candidate` is a newer release version than `installed`.
///
/// - Parameters:
///   - candidate: The version the feed lists, which the caller checked with ``isValidVersion(_:)``.
///   - installed: The app's own version, which the caller checked with ``isValidVersion(_:)``.
/// - Returns: Whether `candidate` is newer, or ``ReleaseVersionError/malformed`` when either text is
///   not a release version.
func isNewer(_ candidate: String, than installed: String) -> Result<Bool, ReleaseVersionError> {
    guard isValidVersion(candidate), isValidVersion(installed) else {
        return .failure(.malformed)
    }

    let candidateNumbers = candidate
        .split(separator: ".")
        .compactMap {
            Int($0)
        }
    let installedNumbers = installed
        .split(separator: ".")
        .compactMap {
            Int($0)
        }

    return .success(installedNumbers.lexicographicallyPrecedes(candidateNumbers))
}
```

## 3. NEGATIVE: the memberwise initializer and synthesized `Decodable` skip the parser

Placement: local package. Checks: format pass, lint pass, typecheck pass (macOS, iOS). The defect is a judgment rule that no tool sees. A probe file in the same module that calls `ReleaseVersion(major: -1, minor: 0)` and `JSONDecoder().decode(ReleaseVersion.self, from:)` passes the typecheck.

Omitted surroundings: `ReleaseVersionError` (Example 1).

Evidence: wrong only in its construction paths: the type body declares no init, and the type adopts synthesized `Decodable`; every other line of the type is Example 1's, documentation included. The memberwise initializer is internal although both properties are `public` (TSPL, Access Control), and synthesized `init(from:)` assigns the stored properties from the input (SE-0166), so neither path runs `parse(_:)`. The probe shows both compile, so the documentation's "the only way to make one" and "neither number is ever negative" are false.

```swift
/// A release's marketing version: a major and a minor number, such as "2.1".
///
/// ``parse(_:)`` is the only way to make one, so neither number is ever negative.
public struct ReleaseVersion: Comparable, Decodable, Hashable, Sendable {
    /// The major number.
    public let major: Int
    /// The minor number within the major version.
    public let minor: Int

    /// Returns whether `lhs` is an earlier version than `rhs`, comparing major numbers first.
    ///
    /// - Parameters:
    ///   - lhs: A version.
    ///   - rhs: Another version.
    /// - Returns: `true` when `lhs` comes before `rhs`.
    public static func < (lhs: ReleaseVersion, rhs: ReleaseVersion) -> Bool {
        (lhs.major, lhs.minor) < (rhs.major, rhs.minor)
    }

    /// Parses a version that the feed or the app's bundle spells as text.
    ///
    /// The text is two runs of the digits 0-9 joined by a period. Numbers compare by value, so
    /// "2.01" and "2.1" parse to the same version.
    ///
    /// - Parameter text: The version text, such as "2.1".
    /// - Returns: The version, or ``ReleaseVersionError/malformed`` when `text` has any other shape.
    public static func parse(_ text: String) -> Result<ReleaseVersion, ReleaseVersionError> {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        let numbers = parts.compactMap {
            $0.allSatisfy(\.isWholeNumber) ? Int($0) : nil
        }
        guard parts.count == 2, numbers.count == 2, let major = numbers.first, let minor = numbers.last else {
            return .failure(.malformed)
        }

        return .success(ReleaseVersion(major: major, minor: minor))
    }
}
```

## 4. POSITIVE: decode a wire record, then parse it

Placement: local package. Checks: format pass, lint pass, typecheck pass (macOS, iOS).

Omitted surroundings: `ReleaseVersion` and `ReleaseVersionError` (Example 1). This `Release` and `decodeRelease(from:)` replace failure-paths.md Example 1's once the version is parsed; that example's `ReleaseFeed` (Example 4) calls this one unchanged.

Evidence: decoding is a construction path, so the JSON lands in `ReleaseRecord`, a private wire type of primitives whose synthesized `Decodable` needs no hand-written `init(from:)` and no `throws`. `decodeRelease(from:)` wraps the decode with `Result(catching:)` as in failure-paths.md Example 1, then parses the record's version, so the only road from JSON to a `Release` runs through `ReleaseVersion.parse(_:)`. Both failures map to `.malformed`, the one outcome a caller can act on. `Release` keeps its memberwise initializer and earns no private init: each stored property is already proven by its type, so every combination is a valid release.

```swift
import Foundation

/// One published release of the app, with its version parsed.
public struct Release: Equatable, Sendable {
    /// The release's version.
    public let version: ReleaseVersion
    /// The page that describes what changed in this release.
    public let notesURL: URL
}

/// A release as the feed's JSON spells it, before its version is parsed.
private struct ReleaseRecord: Decodable {
    /// The version text, such as "2.1".
    let version: String
    /// The page that describes what changed in this release.
    let notesURL: URL
}

/// Why a release-feed body is not a release.
public enum ReleaseDecodingError: Error {
    /// The body is not release JSON, or its version is not a version; trying again will not help.
    case malformed
}

/// Decodes the release feed's response body.
///
/// - Parameter data: The response body.
/// - Returns: The release, or ``ReleaseDecodingError/malformed`` when the body is not a release.
func decodeRelease(from data: Data) -> Result<Release, ReleaseDecodingError> {
    Result(catching: {
        try JSONDecoder().decode(ReleaseRecord.self, from: data)
    })
    .mapError { _ in
        .malformed
    }
    .flatMap { record in
        ReleaseVersion.parse(record.version)
            .map {
                Release(version: $0, notesURL: record.notesURL)
            }
            .mapError { _ in
                .malformed
            }
    }
}
```
