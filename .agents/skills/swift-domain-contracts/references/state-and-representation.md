# State and representation: labeled examples

Read before modeling a model's loading state, choosing a collection's key, or replacing a sorted array. The examples continue the release-feed domain of parse-and-construct.md and swift-isolation's `references/failure-paths.md`.

How the examples were checked. Each code block is a complete file, checked unchanged. The declarations a block names under "Omitted surroundings" were checked beside it as further files of the same module. From the repository root, each file passed the pinned SwiftFormat (`--lint --config .swiftformat`) and the pinned SwiftLint (`lint --strict --config .swiftlint.yml`), and the module passed `xcrun swiftc -typecheck -swift-version 6 -strict-memory-safety -warnings-as-errors` with the `NonisolatedNonsendingByDefault`, `InferIsolatedConformances`, `ExistentialAny` and `MemberImportVisibility` upcoming features, once for macOS and once for iOS. All three are package code, so `-default-isolation MainActor` is off and the models carry `@MainActor` (swift-isolation, step 4). The examples follow swift-code-layout and pass the formatter. No code was run.

Contents: 1 NEGATIVE Booleans plus optionals · 2 POSITIVE one enum, one writer · 3 POSITIVE a dictionary keyed by the parsed type.

## 1. NEGATIVE: three properties hold one state

Placement: local package. Checks: format pass, lint pass, typecheck pass (macOS, iOS). The defect is a judgment rule that no tool sees.

Omitted surroundings: `Release` (parse-and-construct.md, Example 4) and what it names; `FeedError`, `ReleaseFeed` and what they name (swift-isolation's `references/failure-paths.md`, Examples 3 and 4, with this skill's `decodeRelease(from:)`); `ReleaseChannel` (swift-isolation's `references/unchecked-invariants.md`, Example 1).

Evidence: wrong only in the representation; Example 2 holds the same outcomes in one enum. Three properties allow combinations no screen should show: a release and a failure at once, or a failure while a read is in flight. `load()` produces them: a success leaves the last failure in place, a failure leaves the last release, and every view must decide which property wins. `FeedError?` can also hold `.cancelled`, an outcome this model never stores.

```swift
import Observation

/// The latest release on one channel, for the release screen.
@MainActor
@Observable
public final class ReleaseModel {
    /// Whether a read is in flight.
    public private(set) var isLoading = false
    /// The latest release on the channel, once a read succeeds.
    public private(set) var release: Release?
    /// Why the last read failed, if it did.
    public private(set) var failure: FeedError?

    /// The client that reads the feed.
    private let feed: ReleaseFeed
    /// The channel whose latest release the screen shows.
    private let channel: ReleaseChannel

    /// Creates a model that reads `channel` from `feed`.
    ///
    /// - Parameters:
    ///   - feed: The client that reads the feed.
    ///   - channel: The channel whose latest release the screen shows.
    public init(feed: ReleaseFeed, channel: ReleaseChannel) {
        self.feed = feed
        self.channel = channel
    }

    /// Reads the latest release, showing the read in flight and then its outcome.
    ///
    /// A cancelled read writes no outcome: a newer read, or no screen, owns the state now.
    public func load() async {
        isLoading = true

        switch await feed.latestRelease(on: channel) {
        case let .success(newRelease):
            release = newRelease
            isLoading = false

        case .failure(.cancelled):
            return

        case let .failure(error):
            failure = error
            isLoading = false
        }
    }
}
```

## 2. POSITIVE: one enum, changed by one method

Placement: local package. Checks: format pass, lint pass, typecheck pass (macOS, iOS).

Omitted surroundings: as in Example 1.

Evidence: `LoadState` has one case for each thing the screen can show, so a release and a failure cannot coexist and no view chooses between properties. The cases come from `FeedError` through an exhaustive `switch`, so cancellation is never a state, and a new feed failure cannot pass through unmapped. `state` is `public private(set)`: views read it, and only `load()` writes it. A cancelled read writes no outcome (swift-isolation, step 6). `LoadState` is `Equatable`, as swiftui-views asks of model properties.

```swift
import Observation

/// What the release screen shows while it reads the feed.
public enum LoadState: Equatable, Sendable {
    /// Nothing has been read yet.
    case idle
    /// A read is in flight.
    case loading
    /// The latest release on the channel.
    case loaded(Release)
    /// The feed could not be fetched; the screen offers to try again.
    case unavailable
    /// The feed sent something that is not a release; trying again will not help.
    case malformed
}

/// The latest release on one channel, for the release screen.
@MainActor
@Observable
public final class ReleaseModel {
    /// What the screen shows; only ``load()`` changes it.
    public private(set) var state = LoadState.idle

    /// The client that reads the feed.
    private let feed: ReleaseFeed
    /// The channel whose latest release the screen shows.
    private let channel: ReleaseChannel

    /// Creates a model that reads `channel` from `feed`.
    ///
    /// - Parameters:
    ///   - feed: The client that reads the feed.
    ///   - channel: The channel whose latest release the screen shows.
    public init(feed: ReleaseFeed, channel: ReleaseChannel) {
        self.feed = feed
        self.channel = channel
    }

    /// Reads the latest release, showing the read in flight and then its outcome.
    ///
    /// A cancelled read writes no outcome: a newer read, or no screen, owns the state now.
    public func load() async {
        state = .loading

        switch await feed.latestRelease(on: channel) {
        case let .success(release):
            state = .loaded(release)
        case .failure(.unavailable):
            state = .unavailable
        case .failure(.malformed):
            state = .malformed
        case .failure(.cancelled):
            return
        }
    }
}
```

## 3. POSITIVE: the parsed key owns validity, the dictionary owns association

Placement: local package. Checks: format pass, lint pass, typecheck pass (macOS, iOS).

Omitted surroundings: `ReleaseVersion` (parse-and-construct.md, Example 1) and `Release` (Example 4).

Replaces: a `[Release]` kept sorted by version string and searched by hand. That NEGATIVE is prose only, because the standard library has no binary search to misuse: it needs a hand-written search, a sort every writer must keep, and string order, which puts "2.10" before "2.9".

Evidence: the key is the parsed `ReleaseVersion`, so the key type owns validity and canonical form ("2.01" and "2.1" are one key), and `Dictionary` owns association and uniqueness. A lookup takes a parsed version and returns an optional, with no search code. The merge is stated, as in swift-isolation's `references/unchecked-invariants.md`, Example 3, because the feed can repeat a version. The input is `some Sequence<Release>`, the one pass it makes.

```swift
/// Keys the feed's releases by version.
///
/// The feed is outside the app's control and can list a version twice; the first listing wins.
///
/// - Parameter releases: The releases the feed listed, each with a parsed version.
/// - Returns: Each listed version and its first release.
func releasesByVersion(_ releases: some Sequence<Release>) -> [ReleaseVersion: Release] {
    Dictionary(releases.map {
        ($0.version, $0)
    }, uniquingKeysWith: { first, _ in
        first
    })
}
```
