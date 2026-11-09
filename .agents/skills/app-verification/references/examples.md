# Labeled examples

Read this before writing a model test or an async test. Every example was extracted to a `.swift` file and run through the pinned formatter, the pinned linter and a Swift 6 typecheck. The checks cover tooling only; no test was run.

Contract for all four: the package shape (models in a `nonisolated` package, `@MainActor @Observable` on the model), `Result` with a typed error for project APIs, no `@discardableResult`, strict memory safety, warnings as errors, and a Swift 6 language mode. Test files are checked with the base lint configuration plus the test child profile, which exempts documentation only.

Omitted surroundings: in a real package the `Track`, `RenameError`, `LoadError`, `TrackLoading`, `PlaylistModel` and `FakeLoader` declarations live in package source files, and the tests live in the package's test target. They are shown in the same block here so each example compiles as one file. The code under test is package code, so no default-isolation flag applies.

## POSITIVE 1: a model test that gets its optional with `#require` and matches `Result` cases

Evidence: `model.track(titled:)` returns an optional, and the test takes it with `try #require(...)`, so a missing track stops the test with a precise failure. `rename` returns `Result<Track, RenameError>` and the test compares whole results with `==`, so the failing case is asserted, not ignored. The suite is `@MainActor` because the model is. The fake data is a value, and there is no sleep and no view.

Checks: SwiftFormat lint pass; SwiftLint strict pass (base configuration plus the test child profile); `swiftc -typecheck -swift-version 6 -strict-memory-safety -warnings-as-errors` pass with `Testing` available; the layout follows swift-code-layout.

```swift
import Observation
import Testing

/// A song in a playlist.
public struct Track: Equatable, Identifiable, Sendable {
    /// The track's stable identity.
    public let id: Int
    /// The title shown in the list.
    public var title: String
}

/// Why renaming a track failed.
public enum RenameError: Error, Equatable {
    /// The new title was empty or only whitespace.
    case emptyTitle
    /// No track has the given identity.
    case unknownTrack
}

/// An ordered list of tracks that the playlist screen shows.
@MainActor @Observable
public final class PlaylistModel {
    /// The tracks in play order.
    public private(set) var tracks: [Track]

    /// Creates a playlist that starts with `tracks`.
    public init(tracks: [Track]) {
        self.tracks = tracks
    }

    /// Returns the first track titled `title`, or `nil` when none matches.
    public func track(titled title: String) -> Track? {
        tracks.first {
            $0.title == title
        }
    }

    /// Renames the track with `id`, keeping its position.
    public func rename(_ id: Track.ID, to title: String) -> Result<Track, RenameError> {
        guard !title.allSatisfy(\.isWhitespace) else {
            return .failure(.emptyTitle)
        }
        let index = tracks.firstIndex {
            $0.id == id
        }
        guard let index else {
            return .failure(.unknownTrack)
        }

        // `index` comes from `firstIndex(where:)` on `tracks` above; no element is added or removed before its uses.
        tracks[index].title = title

        return .success(tracks[index])
    }
}

@MainActor
struct PlaylistModelTests {
    let model = PlaylistModel(tracks: [Track(id: 1, title: "Intro"), Track(id: 2, title: "Outro")])

    @Test func `renaming keeps the position`() throws {
        let intro = try #require(model.track(titled: "Intro"))

        let result = model.rename(intro.id, to: "Opening")
        #expect(result == .success(Track(id: 1, title: "Opening")))
        #expect(model.tracks.map(\.title) == ["Opening", "Outro"])
    }

    @Test func `renaming to an empty title fails and changes nothing`() throws {
        let intro = try #require(model.track(titled: "Intro"))

        let result = model.rename(intro.id, to: "  ")
        #expect(result == .failure(.emptyTitle))
        #expect(model.tracks.map(\.title) == ["Intro", "Outro"])
    }
}
```

## POSITIVE 2: an async test that counts callback events with `confirmation`

Evidence: the loader reports each page through an `@Sendable` closure, which cannot mutate a local counter under Swift 6, so the event count goes through `confirmation(_:expectedCount:)`. The success test expects two pages; the failure test passes `expectedCount: 0` to prove no page is reported. The dependency sits behind a `Sendable` protocol, and the fake is a value type. The test awaits the work directly, so there is no sleep. `refresh` writes `tracks` only from a success, so a cancelled load, which `TrackLoading` reports as `.failure(.cancelled)`, writes nothing.

Checks: SwiftFormat lint pass; SwiftLint strict pass (base configuration plus the test child profile); typecheck pass with `Testing` available; the layout follows swift-code-layout.

```swift
import Observation
import Testing

/// A song in a playlist.
public struct Track: Equatable, Identifiable, Sendable {
    /// The track's stable identity.
    public let id: Int
    /// The title shown in the list.
    public var title: String
}

/// Why loading tracks failed.
public enum LoadError: Error, Equatable {
    /// The source could not be reached.
    case offline
    /// The surrounding task was cancelled before loading finished.
    case cancelled
}

/// A source of tracks that delivers them page by page.
public protocol TrackLoading: Sendable {
    /// Loads every track, calling `onPage` with the page's size as each page arrives.
    /// Returns `.failure(.cancelled)` with no tracks when the surrounding task is cancelled.
    func loadTracks(onPage: @Sendable (Int) -> Void) async -> Result<[Track], LoadError>
}

/// An ordered list of tracks that the playlist screen shows.
@MainActor @Observable
public final class PlaylistModel {
    /// The tracks in play order.
    public private(set) var tracks: [Track] = []

    /// Where tracks come from.
    private let loader: any TrackLoading

    /// Creates an empty playlist that refreshes from `loader`.
    public init(loader: any TrackLoading) {
        self.loader = loader
    }

    /// Replaces the tracks with the loader's, reporting each page, and returns how many arrived.
    public func refresh(onPage: @Sendable (Int) -> Void) async -> Result<Int, LoadError> {
        let loaded = await loader.loadTracks(onPage: onPage)

        return loaded.map { newTracks in
            tracks = newTracks

            return newTracks.count
        }
    }
}

/// A loader that serves fixed pages, or fails with a fixed error.
struct FakeLoader: TrackLoading {
    /// What the loader serves, or why it fails.
    let outcome: Result<[[Track]], LoadError>

    /// Serves each page in order, then returns every track, or `.failure(.cancelled)` when the task was cancelled by then.
    func loadTracks(onPage: @Sendable (Int) -> Void) async -> Result<[Track], LoadError> {
        let served = outcome.map { pages in
            for page in pages {
                onPage(page.count)
            }

            return pages.flatMap(\.self)
        }

        guard !Task.isCancelled else {
            return .failure(.cancelled)
        }

        return served
    }
}

@MainActor
struct PlaylistRefreshTests {
    let intro = Track(id: 1, title: "Intro")
    let middle = Track(id: 2, title: "Middle")
    let outro = Track(id: 3, title: "Outro")

    @Test func `refresh reports each page as it arrives`() async {
        let model = PlaylistModel(loader: FakeLoader(outcome: .success([[intro], [middle, outro]])))

        await confirmation("page reported", expectedCount: 2) { pageReported in
            let result = await model.refresh { _ in
                pageReported()
            }
            #expect(result == .success(3))
        }
        #expect(model.tracks.map(\.title) == ["Intro", "Middle", "Outro"])
    }

    @Test func `refresh that fails leaves the tracks alone and reports no page`() async {
        let model = PlaylistModel(loader: FakeLoader(outcome: .failure(.offline)))

        await confirmation("page reported", expectedCount: 0) { pageReported in
            let result = await model.refresh { _ in
                pageReported()
            }
            #expect(result == .failure(.offline))
        }
        #expect(model.tracks.isEmpty)
    }
}
```

## NEGATIVE 1: a force unwrap in a test

Evidence: wrong only in `let intro = model.track(titled: "Intro")!`. A missing track would crash the test run instead of failing one test with a message; POSITIVE 1 uses `try #require`. Everything else matches POSITIVE 1, and the declarations above the test are the same as in POSITIVE 1.

Checks: expected-fail on the labeled axis only. SwiftFormat lint fails with `noForceUnwrapInTests` (running the formatter would rewrite this to `try #require`); SwiftLint strict fails with `force_unwrapping`; typecheck pass.

```swift
@MainActor
struct PlaylistModelTests {
    let model = PlaylistModel(tracks: [Track(id: 1, title: "Intro"), Track(id: 2, title: "Outro")])

    @Test func `renaming keeps the position`() {
        let intro = model.track(titled: "Intro")!

        let result = model.rename(intro.id, to: "Opening")
        #expect(result == .success(Track(id: 1, title: "Opening")))
        #expect(model.tracks.map(\.title) == ["Opening", "Outro"])
    }
}
```

## NEGATIVE 2: an XCTest assertion inside a Swift Testing test

Evidence: wrong only in `XCTAssertEqual(...)` inside an `@Test`. The [migration guide](https://raw.githubusercontent.com/swiftlang/swift-testing/main/Sources/Testing/Testing.docc/MigratingFromXCTest.md) says a cross-library failure is ignored when `SWIFT_TESTING_XCTEST_INTEROP_MODE` is `none` and only a warning when it is `limited`; the default depends on toolchain and tools version, so a failing assertion can pass silently. The comparison belongs in `#expect`, as in POSITIVE 1. The declarations above the test are the same as in POSITIVE 1, with `import XCTest` added after `import Testing`.

Checks: passes all three, because the defect is a judgment rule no tool sees. SwiftFormat lint pass; SwiftLint strict pass; typecheck pass (with `XCTest`'s module directory added). The checks never ran the test, so they cannot show how it behaves at run time; only review catches the defect.

```swift
@MainActor
struct PlaylistModelTests {
    let model = PlaylistModel(tracks: [Track(id: 1, title: "Intro"), Track(id: 2, title: "Outro")])

    @Test func `renaming keeps the position`() throws {
        let intro = try #require(model.track(titled: "Intro"))

        let result = model.rename(intro.id, to: "Opening")
        XCTAssertEqual(result, .success(Track(id: 1, title: "Opening")))
        #expect(model.tracks.map(\.title) == ["Opening", "Outro"])
    }
}
```
