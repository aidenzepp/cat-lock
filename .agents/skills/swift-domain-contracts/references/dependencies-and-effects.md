# Dependencies and effects: labeled examples

Read before writing a function that reads the time or randomness, an actor method that awaits, or a protocol added so a test can substitute it. The examples continue the release-feed domain of parse-and-construct.md and the playlist domain of app-verification's `references/examples.md`.

How the examples were checked. Each code block is a complete file, checked unchanged. The declarations a block names under "Omitted surroundings" were checked beside it as further files of the same module. From the repository root, each file passed the pinned SwiftFormat (`--lint --config .swiftformat`) and the pinned SwiftLint (`lint --strict --config .swiftlint.yml`), and the module passed `xcrun swiftc -typecheck -swift-version 6 -strict-memory-safety -warnings-as-errors` with the `NonisolatedNonsendingByDefault`, `InferIsolatedConformances`, `ExistentialAny` and `MemberImportVisibility` upcoming features, once for macOS and once for iOS. All five are package code, so `-default-isolation MainActor` is off. The examples follow swift-code-layout and pass the formatter. No code was run: the reentrancy in Example 3 is SE-0306's documented semantics, not an observed failure.

Contents: 1 NEGATIVE a hidden clock · 2 POSITIVE the time and the generator as inputs · 3 NEGATIVE an `await` between check and write · 4 POSITIVE check and write in one actor turn · 5 NEGATIVE a protocol and a mock for deterministic code.

## 1. NEGATIVE: `isStale()` reads the clock

Placement: local package. Checks: format pass, lint pass, typecheck pass (macOS, iOS). The defect is a judgment rule that no tool sees.

Omitted surroundings: `Release` (parse-and-construct.md, Example 4) and what it names.

Evidence: `isStale()` reads `Date.now` in its body, so its answer depends on an input the signature hides. Two calls on the same snapshot can disagree, and a test of the one-hour boundary must wait for it or build snapshots relative to a clock it does not control.

```swift
import Foundation

/// The latest release the feed reported, and when the feed was read.
public struct FeedSnapshot: Equatable, Sendable {
    /// The release the feed listed.
    public let release: Release
    /// When the feed was read.
    public let fetchedAt: Date

    /// Returns whether the snapshot is an hour old or more, so the screen should read the feed again.
    ///
    /// - Returns: `true` when the feed was read an hour ago or earlier.
    public func isStale() -> Bool {
        Date.now.timeIntervalSince(fetchedAt) >= 60 * 60
    }
}
```

## 2. POSITIVE: the time and the generator arrive as inputs

Placement: local package. Checks: format pass, lint pass, typecheck pass (macOS, iOS).

Omitted surroundings: `Release` (parse-and-construct.md, Example 4) and what it names; `Track` (app-verification's `references/examples.md`, POSITIVE 1).

Evidence: `isStale(at:)` takes the time as a value, so the same snapshot and `now` always give the same answer, and a test passes any `Date`. The caller reads `Date.now` where it meets the system clock, such as in the model that owns the snapshot. `TimeInterval` appears only in the Foundation call. `shuffledQueue(_:after:using:)` takes the generator `inout` and hands it to the standard library's `shuffled(using:)`, so randomness is an input too: the app passes a `SystemRandomNumberGenerator`, and a test passes a seeded generator of its own. Its documentation says a seeded order is not stable across Swift versions, as the standard library's own documentation warns. It asks for `some Sequence<Track>`, because it makes one pass.

```swift
import Foundation

/// The latest release the feed reported, and when the feed was read.
public struct FeedSnapshot: Equatable, Sendable {
    /// The release the feed listed.
    public let release: Release
    /// When the feed was read.
    public let fetchedAt: Date

    /// Returns whether the snapshot is an hour old or more, so the screen should read the feed again.
    ///
    /// - Parameter now: The current time, which the caller reads where it meets the system clock.
    /// - Returns: `true` when the feed was read an hour or more before `now`.
    public func isStale(at now: Date) -> Bool {
        now.timeIntervalSince(fetchedAt) >= 60 * 60
    }
}

/// Returns the tracks that play after `current` once shuffle is on: every other track, once each, in random order.
///
/// The order depends only on `generator`. A seeded generator repeats an order within one Swift
/// version, but the standard library may change its shuffling algorithm in a later one, so a test
/// checks the order's properties and never stores a seeded order as its expected value.
///
/// - Parameters:
///   - tracks: The playlist's tracks.
///   - current: The track playing now, which stays out of the queue.
///   - generator: The source of randomness; the app passes a `SystemRandomNumberGenerator`.
/// - Returns: The other tracks, shuffled.
func shuffledQueue(
    _ tracks: some Sequence<Track>,
    after current: Track.ID,
    using generator: inout some RandomNumberGenerator,
) -> [Track] {
    tracks
        .filter {
            $0.id != current
        }
        .shuffled(using: &generator)
}
```

## 3. NEGATIVE: the slot check and the increment straddle an `await`

Placement: local package. Checks: format pass, lint pass, typecheck pass (macOS, iOS). The defect is a judgment rule that no tool sees.

Evidence: wrong only in the order of the guards; Example 4 checks the slots after the `await`. Here `guard active < limit` passes, then `await allowsDownload()` suspends, and the actor runs other calls meanwhile: SE-0306 states that actor state can change across an `await`. Two calls that arrive with one slot free can both pass the guard, both resume and both increment, so `active` exceeds `limit`, which its documentation says never happens. The compiler accepts it, because every access is isolated to the actor.

```swift
/// Why a download did not run.
public enum SlotError: Error {
    /// Every slot is in use; the caller may try again when a download finishes.
    case full
    /// The device does not allow downloads now, such as on a constrained network.
    case notAllowed
    /// The calling task was cancelled before the download started; the caller writes nothing and ends.
    case cancelled
}

/// Runs at most a fixed number of release downloads at once.
public actor DownloadSlots {
    /// The most downloads that may run at once.
    private let limit: Int
    /// Reports whether the device allows a download now.
    private let allowsDownload: @Sendable () async -> Bool
    /// The downloads running now; never more than `limit`.
    private var active = 0

    /// Creates slots for at most `limit` downloads at once.
    ///
    /// - Parameters:
    ///   - limit: The most downloads that may run at once.
    ///   - allowsDownload: Reports whether the device allows a download now.
    public init(limit: Int, allowsDownload: @escaping @Sendable () async -> Bool) {
        self.limit = limit
        self.allowsDownload = allowsDownload
    }

    /// Runs `download` in a free slot, and frees the slot when it returns.
    ///
    /// - Parameter download: The download, which reports its own failures, cancellation included, in its value.
    /// - Returns: The download's value; ``SlotError/notAllowed`` when the device does not allow downloads
    ///   now; ``SlotError/cancelled`` when the calling task is cancelled before the download starts;
    ///   ``SlotError/full`` when every slot is in use.
    public func withSlot<Success: Sendable>(_ download: @Sendable () async -> Success) async -> Result<Success, SlotError> {
        guard active < limit else {
            return .failure(.full)
        }
        guard await allowsDownload() else {
            return .failure(.notAllowed)
        }
        guard !Task.isCancelled else {
            return .failure(.cancelled)
        }

        active += 1
        defer {
            active -= 1
        }

        return await .success(download())
    }
}
```

## 4. POSITIVE: the check and the write share one actor turn

Placement: local package. Checks: format pass, lint pass, typecheck pass (macOS, iOS).

Evidence: the method awaits `allowsDownload()` first. The check `active < limit` and the increment that depends on it then run with no `await` between them, so they share one actor turn and no other call can interleave. The download's own `await` comes after the increment, and `defer` frees the slot on every exit, so the count stays true with no release call a caller could forget. `withSlot(_:)` is async, so `SlotError` has a `.cancelled` case, and the method checks cancellation after its `await` and before it writes (swift-isolation, steps 6 and 7). Callers `await` the actor.

```swift
/// Why a download did not run.
public enum SlotError: Error {
    /// Every slot is in use; the caller may try again when a download finishes.
    case full
    /// The device does not allow downloads now, such as on a constrained network.
    case notAllowed
    /// The calling task was cancelled before the download started; the caller writes nothing and ends.
    case cancelled
}

/// Runs at most a fixed number of release downloads at once.
public actor DownloadSlots {
    /// The most downloads that may run at once.
    private let limit: Int
    /// Reports whether the device allows a download now.
    private let allowsDownload: @Sendable () async -> Bool
    /// The downloads running now; never more than `limit`.
    private var active = 0

    /// Creates slots for at most `limit` downloads at once.
    ///
    /// - Parameters:
    ///   - limit: The most downloads that may run at once.
    ///   - allowsDownload: Reports whether the device allows a download now.
    public init(limit: Int, allowsDownload: @escaping @Sendable () async -> Bool) {
        self.limit = limit
        self.allowsDownload = allowsDownload
    }

    /// Runs `download` in a free slot, and frees the slot when it returns.
    ///
    /// - Parameter download: The download, which reports its own failures, cancellation included, in its value.
    /// - Returns: The download's value; ``SlotError/notAllowed`` when the device does not allow downloads
    ///   now; ``SlotError/cancelled`` when the calling task is cancelled before the download starts;
    ///   ``SlotError/full`` when every slot is in use.
    public func withSlot<Success: Sendable>(_ download: @Sendable () async -> Success) async -> Result<Success, SlotError> {
        guard await allowsDownload() else {
            return .failure(.notAllowed)
        }
        guard !Task.isCancelled else {
            return .failure(.cancelled)
        }
        guard active < limit else {
            return .failure(.full)
        }

        active += 1
        defer {
            active -= 1
        }

        return await .success(download())
    }
}
```

## 5. NEGATIVE: a protocol and a mock in front of a comparison

Placement: local package. Checks: format pass, lint pass, typecheck pass (macOS, iOS). The defect is a judgment rule that no tool sees.

Omitted surroundings: `ReleaseVersion` (parse-and-construct.md, Example 1) and `Release` (Example 4). In a real package `MockVersionComparer` lives in the test target; it is shown here so the example typechecks as one module.

Evidence: `ReleaseVersion` is `Comparable` and comparing two is deterministic, so the protocol, its one real conformer, the init that exists only for tests and the mock buy nothing. A test that passes the mock proves that the model copies the mock's answer, not that 2.10 is newer than 2.9. Write `showsUpdate = release.version > installed`, drop the second init, and test the model with real versions. A protocol fronts external authority, as `TrackLoading` does in app-verification's `references/examples.md`, POSITIVE 2, which is this example's positive counterpart.

```swift
import Observation

/// Decides whether one release version is newer than another.
protocol VersionComparing: Sendable {
    /// Returns whether `candidate` is newer than `installed`.
    ///
    /// - Parameters:
    ///   - candidate: The version the feed lists.
    ///   - installed: The version of the running app.
    /// - Returns: `true` when `candidate` is newer.
    func isNewer(_ candidate: ReleaseVersion, than installed: ReleaseVersion) -> Bool
}

/// The comparer the app uses: version order.
struct VersionComparer: VersionComparing {
    /// Returns whether `candidate` comes after `installed` in version order.
    ///
    /// - Parameters:
    ///   - candidate: The version the feed lists.
    ///   - installed: The version of the running app.
    /// - Returns: `true` when `candidate` is newer.
    func isNewer(_ candidate: ReleaseVersion, than installed: ReleaseVersion) -> Bool {
        candidate > installed
    }
}

/// The model behind the app's update banner.
@MainActor
@Observable
public final class UpdateModel {
    /// Whether the feed lists a version newer than the running app's.
    public private(set) var showsUpdate = false

    /// The version of the running app.
    private let installed: ReleaseVersion
    /// Decides whether a listed version is newer.
    private let comparer: any VersionComparing

    /// Creates a model for an app running `installed`.
    ///
    /// - Parameter installed: The version of the running app.
    public convenience init(installed: ReleaseVersion) {
        self.init(installed: installed, comparer: VersionComparer())
    }

    /// Creates a model that compares versions with `comparer`, so a test can pass a mock.
    ///
    /// - Parameters:
    ///   - installed: The version of the running app.
    ///   - comparer: Decides whether a listed version is newer.
    init(installed: ReleaseVersion, comparer: any VersionComparing) {
        self.installed = installed
        self.comparer = comparer
    }

    /// Shows the banner when `release` is newer than the running app.
    ///
    /// - Parameter release: The release the feed listed.
    public func receive(_ release: Release) {
        showsUpdate = comparer.isNewer(release.version, than: installed)
    }
}

/// A comparer that gives a fixed answer, so a test chooses what the model sees.
struct MockVersionComparer: VersionComparing {
    /// The answer to every comparison.
    let answer: Bool

    /// Returns the fixed answer, whatever the versions.
    ///
    /// - Returns: ``answer``.
    func isNewer(_: ReleaseVersion, than _: ReleaseVersion) -> Bool {
        answer
    }
}
```
