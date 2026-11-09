# `.task` cancellation: labeled examples

Read before writing or reviewing a `.task` or `.task(id:)` body. The view lives in the app target; the feed client comes from the local package (failure-paths.md).

Every example was extracted to its own Swift file, with stubs for the package declarations it names, and run from the repository root through the pinned SwiftFormat (`--lint --config .swiftformat`), the pinned SwiftLint (`lint --strict --config .swiftlint.yml`) and `xcrun swiftc -typecheck -swift-version 6 -strict-memory-safety -warnings-as-errors -default-isolation MainActor`. The stubs are marked `nonisolated` to stand in for the package's default isolation.

Contents: 1 POSITIVE cancellation as its own case · 2 NEGATIVE cancellation shown as a failure.

## 1. POSITIVE: cancellation is its own case and writes nothing

Placement: app target. Checks: format pass, lint pass, typecheck pass.

Omitted surroundings: the `import` of the local package and its `Release`, `FeedError` and `ReleaseFeed` (failure-paths.md, Examples 1 and 4) and `ReleaseChannel` (unchecked-invariants.md, Example 1).

Evidence: when `channel` changes, SwiftUI cancels the running task and starts a new one, which sets `.loading`. The old task's `.cancelled` result can arrive after that. Its own case returns without writing, so only the task for the current channel writes `phase`. `.unavailable` and `.malformed` keep separate messages because the user's next step differs.

```swift
import SwiftUI

/// Shows the latest release on one channel, reloading when the channel changes.
struct LatestReleaseView: View {
    /// What the view shows while and after the release loads.
    private enum Phase {
        /// The release is loading.
        case loading
        /// The release loaded.
        case loaded(Release)
        /// The release could not be loaded; the message says what the user can do.
        case failed(LocalizedStringResource)
    }

    /// The load's current phase; only the task for the current channel writes it.
    @State private var phase = Phase.loading

    /// The channel whose latest release is shown; a change restarts the load.
    let channel: ReleaseChannel
    /// The client that fetches the feed.
    let feed: ReleaseFeed

    /// The view for the current phase, loading while the view is on screen.
    var body: some View {
        Group {
            switch phase {
            case .loading:
                ProgressView("Loading the latest release")
            case let .loaded(release):
                Text("Version \(release.version)", comment: "Shows the version of the latest release, such as 2.1.")
            case let .failed(message):
                Text(message)
            }
        }
        .task(id: channel) {
            phase = .loading

            switch await feed.latestRelease(on: channel) {
            case let .success(release):
                phase = .loaded(release)
            case .failure(.cancelled):
                // A newer task owns `phase`, or the view is gone: end without writing.
                return
            case .failure(.unavailable):
                phase = .failed("The release feed is unavailable. Try again later.")
            case .failure(.malformed):
                phase = .failed("The release feed sent data this version can't read.")
            }
        }
    }
}
```

## 2. NEGATIVE: cancellation shown as a failure

Placement: app target. Checks: format pass, lint pass, typecheck pass, run on the whole view. The defect is a judgment rule that no tool sees.

Excerpt: the `body` property of `LatestReleaseView`. Every other line is as in Example 1, with the same omitted surroundings.

Evidence: `.cancelled` shares the `.unavailable` branch. After a channel change, the old task's cancellation can land after the new task set `.loading`, and the view shows "unavailable" for a load that did not fail. Give `.cancelled` a case of its own that ends without writing.

```swift
    /// The view for the current phase, loading while the view is on screen.
    var body: some View {
        Group {
            switch phase {
            case .loading:
                ProgressView("Loading the latest release")
            case let .loaded(release):
                Text("Version \(release.version)", comment: "Shows the version of the latest release, such as 2.1.")
            case let .failed(message):
                Text(message)
            }
        }
        .task(id: channel) {
            phase = .loading

            switch await feed.latestRelease(on: channel) {
            case let .success(release):
                phase = .loaded(release)
            case .failure(.unavailable), .failure(.cancelled):
                phase = .failed("The release feed is unavailable. Try again later.")
            case .failure(.malformed):
                phase = .failed("The release feed sent data this version can't read.")
            }
        }
    }
```
