# Failure paths: labeled examples

Read before writing an API that can fail, wrapping one of Apple's throwing calls, or changing the async helper. The examples share one domain: a release-feed client in the local package.

Every example was extracted to its own Swift file, with any stubs it names, and run from the repository root through the pinned SwiftFormat (`--lint --config .swiftformat`), the pinned SwiftLint (`lint --strict --config .swiftlint.yml`) and `xcrun swiftc -typecheck -swift-version 6 -strict-memory-safety -warnings-as-errors`. Package examples omit `-default-isolation MainActor`.

Contents: 1 POSITIVE synchronous wrap · 2 NEGATIVE `try?` · 3 POSITIVE async helper · 4 POSITIVE async API · 5 NEGATIVE hand-rolled `catch`.

## 1. POSITIVE: a synchronous Apple call through `Result(catching:)`

Placement: local package. Checks: format pass, lint pass, typecheck pass.

Evidence: `decodeRelease(from:)` returns `Result<Release, ReleaseDecodingError>` and declares no `throws`. The throwing `JSONDecoder.decode` call is wrapped where it is made, and `mapError` turns every decoding error into `.malformed`, the one outcome a caller can act on ("trying again will not help"). The function is synchronous and cannot be cancelled, so its enum has no `.cancelled` case.

```swift
import Foundation

/// One published release of the app, as the release feed lists it.
public struct Release: Decodable, Equatable, Sendable {
    /// The marketing version, such as "2.1".
    public let version: String
    /// The page that describes what changed in this release.
    public let notesURL: URL
}

/// Why a release-feed body is not a release.
public enum ReleaseDecodingError: Error {
    /// The body is not release JSON; trying again will not help.
    case malformed
}

/// Decodes the release feed's response body.
///
/// - Parameter data: The response body.
/// - Returns: The release, or ``ReleaseDecodingError/malformed`` when the body is not a release.
func decodeRelease(from data: Data) -> Result<Release, ReleaseDecodingError> {
    Result(catching: {
        try JSONDecoder().decode(Release.self, from: data)
    }).mapError { _ in
        .malformed
    }
}
```

## 2. NEGATIVE: `try?` drops the failure

Placement: local package. Checks: format pass, lint pass, typecheck pass. The defect is a judgment rule that no tool sees.

Omitted surroundings: `Release`, declared in Example 1.

Evidence: `try?` turns every decoding error into `nil`, so the API returns `Release?` and the caller cannot tell a malformed feed from any other outcome, or tell the user. Wrap the call with `Result(catching:)` and `mapError` as in Example 1.

```swift
import Foundation

/// Decodes the release feed's response body.
///
/// - Parameter data: The response body.
/// - Returns: The release, or `nil` when the body is not a release.
func decodeRelease(from data: Data) -> Release? {
    try? JSONDecoder().decode(Release.self, from: data)
}
```

## 3. POSITIVE: the one async helper

Placement: local package, in a file of its own. Checks: format pass, typecheck pass. Lint passes once the project adds an exclusion for this file to `result_failure_paths`; without it, `result_failure_paths` flags the helper's `throws` and `catch`. The template ships no such exclusion. The closure parameter's `throws` and the helper's `catch` are the only ones the project keeps outside tests, so the exclusion names this file and no other.

Evidence: `Result(catching:)` takes only a synchronous closure, so async Apple calls go through this helper. It reports `Failure.cancelled` whenever the task is cancelled, whatever error the call threw on the way out, and maps every other error with the caller's transform. `nonisolated(nonsending)` keeps it on the caller's actor whether or not the target turns on `NonisolatedNonsendingByDefault`.

```swift
/// A failure type that can report that its operation was cancelled.
public protocol CancellableFailure: Error {
    /// The failure that reports cancellation.
    static var cancelled: Self { get }
}

/// The project's one wrapper for Apple's async throwing calls.
///
/// `Result(catching:)` accepts only a synchronous closure, so async calls come here.
public extension Result where Failure: CancellableFailure {
    /// Runs one of Apple's async throwing calls and returns its outcome as a value.
    ///
    /// The helper runs on the caller's actor. An error that arrives while the calling task is
    /// cancelled reports cancellation, whatever its type: the caller asked to stop.
    ///
    /// - Parameters:
    ///   - operation: The Apple call, such as `URLSession.data(from:delegate:)`.
    ///   - transform: Maps any other error to the failure a caller can act on.
    /// - Returns: The call's value, `Failure.cancelled`, or the mapped failure.
    nonisolated(nonsending) static func catching(
        _ operation: nonisolated(nonsending) () async throws -> Success,
        mapError transform: (any Error) -> Failure,
    ) async -> Self {
        do {
            return try await .success(operation())
        } catch {
            if error is CancellationError || Task.isCancelled {
                return .failure(.cancelled)
            }

            return .failure(transform(error))
        }
    }
}
```

## 4. POSITIVE: an async API built on the helper

Placement: local package. Checks: format pass, lint pass, typecheck pass.

Omitted surroundings: `CancellableFailure` and `Result.catching(_:mapError:)` (Example 3); `Release`, `ReleaseDecodingError` and `decodeRelease(from:)` (Example 1); `ReleaseChannel` (unchecked-invariants.md, Example 1).

Evidence: `latestRelease(on:)` is async and can be cancelled, so its `FeedError` has a `.cancelled` case, while the synchronous decode keeps its own enum without one. `FeedError.init(_:)` maps the decode's failure through an exhaustive `switch`, so a new decoding case cannot pass through unmapped. The async Apple call goes through `Result.catching(_:mapError:)`; the status check and the decode are `flatMap` steps that return `FeedError`; nothing throws. The last line makes the documented contract true: a cancelled caller gets `.cancelled` even when the response arrived first, so a late value never reaches a view that moved on.

```swift
import Foundation

/// The release-feed failures a caller can act on.
public enum FeedError: CancellableFailure {
    /// The feed could not be fetched; the caller may try again later.
    case unavailable
    /// The feed sent data that is not a release; trying again will not help.
    case malformed
    /// The calling task was cancelled; the caller writes nothing and ends.
    case cancelled

    /// The feed failure for a body that did not decode.
    ///
    /// - Parameter error: Why the body is not a release.
    init(_ error: ReleaseDecodingError) {
        switch error {
        case .malformed:
            self = .malformed
        }
    }
}

/// The client for the app's release feed.
public struct ReleaseFeed: Sendable {
    /// The session that performs the feed's requests.
    private let session: URLSession
    /// The feed's base address; each channel's feed is a JSON file beneath it.
    private let baseURL: URL

    /// Creates a client for the feed at `baseURL`.
    ///
    /// - Parameters:
    ///   - session: The session that performs the requests.
    ///   - baseURL: The address that holds one JSON file per channel.
    public init(session: URLSession, baseURL: URL) {
        self.session = session
        self.baseURL = baseURL
    }

    /// Returns the body of a successful response.
    ///
    /// - Parameter response: The body and response metadata from the session.
    /// - Returns: The body, or ``FeedError/unavailable`` for any status outside 200-299.
    private static func body(of response: (Data, URLResponse)) -> Result<Data, FeedError> {
        guard let status = (response.1 as? HTTPURLResponse)?.statusCode, (200 ..< 300).contains(status) else {
            return .failure(.unavailable)
        }

        return .success(response.0)
    }

    /// Downloads and decodes the latest release on `channel`.
    ///
    /// - Parameter channel: The channel whose feed is read.
    /// - Returns: The release; ``FeedError/cancelled`` whenever the calling task is cancelled
    ///   before this returns, even if the response already arrived; otherwise the failure
    ///   the caller can act on.
    public func latestRelease(on channel: ReleaseChannel) async -> Result<Release, FeedError> {
        let url = baseURL.appending(path: "\(channel.rawValue).json")
        let release = await Result.catching {
            try await session.data(from: url)
        } mapError: { _ in
            FeedError.unavailable
        }
        .flatMap(Self.body(of:))
        .flatMap {
            decodeRelease(from: $0).mapError(FeedError.init)
        }

        return Task.isCancelled ? .failure(.cancelled) : release
    }
}
```

## 5. NEGATIVE: a hand-rolled `catch` folds cancellation into a failure

Placement: local package. Checks: format pass, typecheck pass, run on the whole type; lint expected-fail on the labeled axis only: `result_failure_paths` flags the `catch` keyword. The cancellation that the `catch` folds away is a judgment rule that no tool sees.

Excerpt: the `latestRelease(on:)` member of `ReleaseFeed`. Every other line of the type is as in Example 4, with the same omitted surroundings.

Evidence: the `catch` reports cancellation as `.unavailable`, so a view whose task was cancelled shows "unavailable" for a load that never failed, and with no final `Task.isCancelled` check a late response still reaches it. Both break the documented `.cancelled` contract. Use the helper and the final check as in Example 4.

```swift
    /// Downloads and decodes the latest release on `channel`.
    ///
    /// - Parameter channel: The channel whose feed is read.
    /// - Returns: The release; ``FeedError/cancelled`` whenever the calling task is cancelled
    ///   before this returns, even if the response already arrived; otherwise the failure
    ///   the caller can act on.
    public func latestRelease(on channel: ReleaseChannel) async -> Result<Release, FeedError> {
        let url = baseURL.appending(path: "\(channel.rawValue).json")
        let response: (Data, URLResponse)
        do {
            response = try await session.data(from: url)
        } catch {
            return .failure(.unavailable)
        }

        return Self.body(of: response).flatMap {
            decodeRelease(from: $0).mapError(FeedError.init)
        }
    }
```
