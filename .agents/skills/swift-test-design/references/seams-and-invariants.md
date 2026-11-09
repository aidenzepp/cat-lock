# Seams and invariants

Read this when a test exposes a weak invariant, a hidden dependency, an awkward abstraction, or an unclear coverage boundary. Test difficulty is evidence, not authorization to redesign: a design change beyond the requested scope is reported as debt, with the best regression test written first.

## Build the obligation map

Start from promises, not files. One component may own several obligations, and one obligation may cross several components.

| Obligation | Owner | Enforcement | Test evidence | Status |
| --- | --- | --- | --- | --- |
| A percentage is within 0 through 100 | `Percentage` | `private` initializer, `Result` factory, decoding through the factory | Boundary and refusal cases, plus decoding cases that run through the factory | Covered |
| A session ends at its deadline | `Session` | A comparison against an explicit date | Cases one second before, at and after the deadline | Covered |
| A note title is saved once | `NoteStore` | Each implementation refuses a duplicate | The shared contract suite over the fake and the real store | Covered |
| A cancelled load writes no state | The model | Its `.cancelled` case, returned and not applied | A test that cancels the task and checks the state | Review-owned until written |
| Settings survive a restart | The settings store | A `Codable` round trip | Encode, decode, compare, with an explicit `Locale` and `TimeZone` | Covered |

Use the map when the work has several promises, state, external effects, or a failure mode that matters. Swift-specific rows to check: `Task` cancellation and its `.cancelled` case, `Sendable` crossing, main-actor isolation, `Codable` round trips, and `Locale`, `Calendar` and `TimeZone`.

## Move invariants into the design

If several functions take an `Int` that must be 0 through 100, a test in each of them is a distributed invariant. The type that should own it, and the construction paths it must close, belong to `swift-domain-contracts`, headings "Parse at boundaries and keep what you learn" and "Encode only invariants the design can keep". The tests are this skill's part: construction, refusal with the typed case, preservation, and each construction path the design closes, decoding and a restore from storage included. Positive 2 in [examples.md](examples.md) shows them.

## Pressure and response

| Pressure | Likely response |
| --- | --- |
| Invalid values flow through many functions | A trusted type or a boundary factory |
| Time, randomness or identifiers make results unstable | The smallest honest seam: `swift-domain-contracts`, heading "Dependencies and effects" |
| An effect is inseparable from a decision | Separate the pure decision; keep the effect at its owner |
| A mock needs many ordered expectations | Test a higher-level outcome |
| The fixture needs unrelated system state | Reconsider ownership or split the boundary |
| A fake keeps disagreeing with production | A shared contract suite, or a higher-fidelity dependency |

## Inject the value before the service

Which seam time, randomness and identifiers get is the ladder in `swift-domain-contracts`, heading "Dependencies and effects". From the test side: a decision that needs only the current time gets the time, and the test fixes it (Positive 1). A component that owns the act of reading time across several operations takes a generic `Clock`: `ContinuousClock` in production and a hand-written clock in tests. The SDK ships no test clock; Positive 6 is one.

## Consumer-owned capabilities

A seam names a capability in domain terms, makes failure explicit, has no method used only by tests, can be implemented by the real adapter and a faithful fake, and is wired to the real type where `swift-domain-contracts`, heading "Dependencies and effects", says. Do not reach for `.shared`, a global container, or an environment bag. Keep transactions, locks and ordering at the boundary that owns them; a repository fake proves nothing about database uniqueness or rollback.

## Time of check and time of use

Before separating a decision from its effect, check the split creates no gap between check and use and does not break atomicity. The right response may be a deterministic calculation called from inside the real transaction, not a decision moved outside it.

## Fidelity ladder

Take the highest rung that stays safe and deterministic.

| Rung | In Swift |
| --- | --- |
| Real local implementation | A temporary directory, `ModelConfiguration(isStoredInMemoryOnly: true)`, a per-test `UserDefaults(suiteName:)` |
| Maintained fake | Behind a consumer-owned `Sendable` protocol, held to the real behavior by a shared contract suite; its shape is in SKILL.md, "Choose the double by evidence" |
| Stub | A closure or value that returns data and asserts no interaction |
| Recording double | Only when the interaction is the promise, such as a charge that must not be issued twice; it has a fake's shape |

The temporary-directory, in-memory `ModelConfiguration` and `UserDefaults(suiteName:)` forms are named from Apple's API; the first is in Positive 3, the other two are not shown or checked here.

## POSITIVE 6: a hand-written clock for a component that owns time

Evidence: `Lease` reads `now` from a generic `Clock`, so production passes `ContinuousClock` and the test passes `ManualClock` and moves time by hand: no sleep, no real wait. The clock keeps its state in a `Mutex` inside a `final class`, a fake's shape from SKILL.md, "Choose the double by evidence", so it needs no `@unchecked Sendable`. Its `sleep` keeps the real clocks' contract instead of waiting: it returns with `now` at or past the deadline, and a cancelled task gets `CancellationError`, as from the standard clocks (SE-0329). So a component that sleeps on it sees the time it asked for. `sleep` keeps `throws` to report cancellation; it is test code, where the template lets functions throw (`app-verification`, heading "Confirm the project enforces").

Checks: SwiftFormat lint pass; SwiftLint strict pass (package source, `Lease`, with the base configuration alone; test code with the test child profile added); `swiftc -typecheck` under the strict flags pass, with `Testing` on the framework and plugin paths; the layout follows swift-code-layout.

```swift
import Synchronization
import Testing

/// A grant that ends a fixed time after it was issued.
struct Lease<TimeSource: Clock> where TimeSource.Duration == Duration {
    /// The time source the lease reads on every check.
    ///
    /// Production passes `ContinuousClock`; a test passes a clock it controls.
    let clock: TimeSource
    /// The instant at which the lease ends; it counts as expired from that instant on.
    let expiry: TimeSource.Instant

    /// Whether the clock has reached the lease's end.
    var isExpired: Bool {
        clock.now >= expiry
    }

    /// Creates a lease that ends a fixed time after the clock's current instant.
    ///
    /// - Parameters:
    ///   - duration: How long the lease lasts, from now.
    ///   - clock: The time source to read now and on every later check.
    init(lasting duration: Duration, on clock: TimeSource) {
        self.clock = clock
        expiry = clock.now.advanced(by: duration)
    }
}

/// A time source that moves only when a test advances it or a caller sleeps.
final class ManualClock: Clock {
    /// A point on the manual clock, measured from its start.
    struct Instant: InstantProtocol {
        /// How far the clock has been advanced.
        var offset: Duration

        static func < (lhs: Instant, rhs: Instant) -> Bool {
            lhs.offset < rhs.offset
        }

        func advanced(by duration: Duration) -> Instant {
            Instant(offset: offset + duration)
        }

        func duration(to other: Instant) -> Duration {
            other.offset - offset
        }
    }

    private let elapsed = Mutex(Duration.zero)

    var now: Instant {
        Instant(offset: elapsed.withLock {
            $0
        })
    }

    var minimumResolution: Duration {
        .zero
    }

    /// Moves the clock forward by a given duration.
    func advance(by duration: Duration) {
        elapsed.withLock {
            $0 += duration
        }
    }

    /// Jumps the clock to the deadline when that is later than now, then returns, so a caller wakes at the time it asked for.
    ///
    /// Like the standard clocks, it throws `CancellationError` when the task is already cancelled.
    func sleep(until deadline: Instant, tolerance _: Duration?) async throws {
        try Task.checkCancellation()

        elapsed.withLock {
            $0 = max($0, deadline.offset)
        }
    }
}

struct LeaseTests {
    @Test func `a lease lasts until its duration has passed`() {
        let clock = ManualClock()
        let lease = Lease(lasting: .seconds(30), on: clock)

        clock.advance(by: .seconds(29))
        #expect(!lease.isExpired)

        clock.advance(by: .seconds(1))
        #expect(lease.isExpired)
    }
}
```
