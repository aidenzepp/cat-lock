---
name: swift-test-design
description: "Design what Swift tests should prove: the contract, the smallest stable boundary, seams, fakes versus real dependencies, test names and failure messages. Use when deciding what to test, writing or reviewing a Swift Testing test for a model, package API or invariant-carrying type, adding a fake, protocol, clock or injected value so code can be tested, finding a missing invariant type, diagnosing a brittle or flaky test, or judging whether coverage is complete. Does not run tests or report results (see app-verification)."
---

# Swift test design

A test is an executable contract for a reader who did not write it. Its failure should name the broken behavior without that reader reconstructing what the author meant. Tools own the mechanical rules; this skill covers what to test, where, and with what.

## 1. Preflight

Run the project's toolchain preflight from the repository root (here `./scripts/dev.swift doctor`). Stop on a non-zero exit. Install nothing; name the project's setup step (here `./scripts/dev.swift bootstrap`) and let the operator run it.

## 2. Confirm the project enforces

Check each item before relying on it. If one is missing, report the gap and apply the rule by hand.

- SwiftLint `force_unwrapping` and `force_try` cover test files, so a precondition is taken with `try #require`, never `!`.
- Test targets build under the strict settings, so a warning fails a test build.
- The full list of what tests are held to is `app-verification`, heading "Confirm the project enforces"; it is not repeated here. If a rule rejects a test, change the test.

## 3. Name the contract first

Write no test until you can state the behavior it protects and where that expectation comes from: a user decision, a public API contract, a schema, verified documentation, existing behavior or a reproduced bug. Do not encode a guess.

Before the first failing run, know:

- the behavior, and the smallest stable boundary that exposes it
- the inputs and the observable outputs, effects or errors
- the highest-fidelity deterministic dependency available (section 8)
- what the test deliberately does not protect
- the focused command that proves it fails and then passes (`app-verification`, heading "Running tests")

For a small test the name and arrangement may make this obvious. Write the packet down for a regression, an integration test, ambiguous behavior, or a double.

## 4. Map the obligations

Completeness is promises with an owner and credible evidence, not one test per function. For stateful or multi-promise work, list each obligation with its owner, its enforcement and its evidence; an obligation is covered, not applicable with a reason, or deferred with a named risk and approval. The worked table and the Swift rows to check (cancellation and `.cancelled`, `Sendable` crossing, main-actor isolation, `Codable` round trips, locale, calendar, time zone) are in [references/seams-and-invariants.md](references/seams-and-invariants.md).

## 5. Let tests pressure the design

A test proves an invariant is enforced; it should not be the only thing enforcing it. When tests keep re-establishing one assumption, name the invariant and the type that should own it. That type's design, and the construction paths it must close, belong to `swift-domain-contracts`, headings "Parse at boundaries and keep what you learn" and "Encode only invariants the design can keep". This skill's part is the tests: construction, refusal with the typed case, preservation, and every path around the factory, such as the memberwise `init`, decoding, a restore from storage and an `@Observable` setter ([Positive 2](references/examples.md)).

Repeated validation, large fixtures and unreachable behavior are design evidence. If the redesign is outside the requested scope, write the best regression test available and report the unenforced assumption as debt. Do not leave both the design and the behavior unprotected.

## 6. Choose the boundary

- Test observable behavior through the public API. `@testable import` is on by default in test targets; it is not permission to freeze private helpers, call order or data structures.
- Pick a boundary that survives a behavior-preserving refactor. A test that breaks when a helper is renamed is too coupled.
- Where the code lives decides the test target: package code in the package's `Tests/<Module>Tests` under `swift test`; app-target code in the app's test target under `xcodebuild test`; UI tests in their own target. In this template, models live in the package. Build wiring is `xcode-project-settings`.
- A `@MainActor @Observable` model needs a `@MainActor` suite. Default isolation differs between the app target and the package, so read the target's settings before moving a test between them (`swift-isolation`, heading "Read the target's settings first").
- For a bug, reproduce the symptom, trace it to the deepest violated promise, and protect that promise, not the first visible workaround.

## 7. Design honest seams

A dependency needs a seam when it brings I/O, nondeterminism, external state or a real ownership boundary. Which seam it gets is the ladder in `swift-domain-contracts`, heading "Dependencies and effects", which also says where the real type is wired; this skill restates neither. The examples show three of its rungs from the test side: a value the test fixes ([Positive 1](references/examples.md)), a consumer-owned protocol with a faithful fake ([Positive 3](references/examples.md)), and a generic `Clock` for a component that owns reading time ([Positive 6](references/seams-and-invariants.md)).

- A `.shared` singleton, global container or environment bag read inside the code under test leaves the test no control ([Negative 5](references/non-examples.md)).
- Injecting a dependency makes it visible, not deterministic or faithful. Do not split a decision from its effect if that breaks atomicity.

## 8. Choose the double by evidence

Take the highest rung that is safe and deterministic: real local implementation (a temporary directory, `ModelConfiguration(isStoredInMemoryOnly:)`), then a maintained fake behind the consumer's protocol, then a closure or value stub, then a recording double only when the interaction is the promise. Do not mock because it is easier; a mock that restates the call graph passes while production is broken ([Negative 3](references/non-examples.md)).

- A fake that owns behavior (uniqueness, ordering, retry) runs the same contract suite as the real type ([Positive 3](references/examples.md), [Negative 4](references/non-examples.md)).
- A fake's shape: one that keeps mutable state holds it in an `actor` ([Positive 3](references/examples.md)), or in a `Mutex` held by a `final class`, because a `Mutex` is noncopyable and the test and the code under test share one instance ([Positive 6](references/seams-and-invariants.md)). Which of the two is `swift-isolation`, heading "Sendable design". A fake with no mutable state is a value type. A recording double has the same shape.
- `@unchecked Sendable` on a test double is an escape hatch and follows `swift-isolation`, heading "Escape hatches" ([Negative 7](references/non-examples.md)).

## 9. Make failures self-explanatory

Treat a failure as a developer-facing error. It should show what was done, what was expected and why, and what was observed.

- Name each test for the behavior and condition, as a raw identifier: ``@Test func `renaming keeps the position`()``. One coherent reason to fail per test.
- `#expect` records the failure and continues; `try #require` stops. Take a precondition or an optional with `#require`, and gate any element read behind it ([Positive 4](references/examples.md), [Negative 1](references/non-examples.md)).
- `#expect` already prints the captured expression. Add a `Comment` only when the expression does not name the contract ([Positive 1](references/examples.md)); never an empty or bare "failed" ([Negative 6](references/non-examples.md)).
- Attach large or structured output with `Attachment.record(_:named:)` instead of interpolating it. Keep secrets and big payloads out of messages.
- Project APIs return `Result` with a typed error (the design is `swift-isolation`); assert the case. Compare with `==` when both payloads are `Equatable` ([Positive 2](references/examples.md)); otherwise `guard case` and `Issue.record` on the other arm. `#expect(throws:)` is only for an Apple throwing call the test itself makes, and returns the matched error.
- Assert the product's own error contract at its boundary, separately from the developer diagnostic.

## 10. Prove red, green, refactor

1. Run the focused test first and confirm it fails for the intended reason. A compile failure or a bad fixture is not red.
2. Make the smallest change that satisfies the contract, then confirm green.
3. Refactor, then rerun the focused and the wider tests.

When a test fails, classify it before editing: the test is wrong, the code is wrong, the design blocks honest testing, or the environment is broken. Do not turn a wrong test green by bending the code, and do not hide a bug by weakening the assertion. To detect flakiness, repeat: `swift test --repeat-until fail --maximum-repetitions <n>` (Swift Testing only). A test that sometimes passes is nondeterministic, not correct.

Commands, destinations, result bundles and reporting are `app-verification`, headings "Running tests", "Reading results" and "What CI must run".

## 11. Keep tests reliable

- Fix the inputs: a `Date`, an identifier, an ordering, and an explicit `Locale`, `Calendar` and `TimeZone`, because formatting follows the machine. (A recommendation; no primary source was read for it.)
- Use a temporary directory, an in-memory store or a per-test `UserDefaults` suite, never real user data.
- Tests run in parallel in one process. `.serialized` has no effect on a non-parameterized test and does not order a suite against its peers; use it only with a comment naming the shared state.
- Prefer DAMP setup that names the contract-bearing facts over a hidden shared fixture. A test must not depend on another test's order.
- No sleeps or polls. An event that arrives through a callback is `confirmation(_:expectedCount:)`, with `expectedCount: 0` for "must not happen". A change that arrives through observation is `Observations`.

## 12. Swift traps

- Test types need no `XCTestCase` and no `test` prefix; each instance test gets a fresh instance, so setup is `init`.
- Never call XCTest assertions from a Swift Testing test, or the reverse. Whether such a failure counts depends on `SWIFT_TESTING_XCTEST_INTEROP_MODE`, whose default varies by toolchain and tools version, so a failing assertion can pass silently. `app-verification`'s examples hold the NEGATIVE.
- `@Test(arguments:)` with two collections runs their Cartesian product; use `zip` for pairs ([Positive 5](references/examples.md), [Negative 2](references/non-examples.md)).
- `.timeLimit` takes minutes only.
- Exit tests (`#expect(processExitsWith:)`) for a `precondition` or `fatalError` contract do not exist on iOS. Prove such a contract in the package's macOS host run, or leave it a documented review contract.
- Raw-identifier test names need Swift 6.2 or later.
- The construction paths an invariant type must close, the memberwise `init` among them, are `swift-domain-contracts`, heading "Encode only invariants the design can keep". Test each one (section 5).

## Hand-offs

- Invariant types, parsing, construction paths and the seam ladder: `swift-domain-contracts`.
- Framework choice, run commands, result reading, audits, CI: `app-verification`.
- `Result` and typed errors, `.cancelled`, escape hatches, the actor-or-`Mutex` choice, unchecked invariants, task lifetime: `swift-isolation`.
- Test target settings, manifests, default isolation: `xcode-project-settings`.
- Anything involving a view: `swiftui-views`.
- Formatting and lint policy are tool-owned; do not edit either to make a test pass.

## Examples

- [references/examples.md](references/examples.md): Positives 1 to 5, to read before writing a test.
- [references/non-examples.md](references/non-examples.md): Negatives 1 to 7 and the rationalizations table, to read when reviewing a test or considering a mock.
- [references/seams-and-invariants.md](references/seams-and-invariants.md): the obligation map, pressure table, fidelity ladder and Positive 6, to read when a test exposes a weak invariant or hidden dependency.

## Upstream documentation

- Swift Testing: https://developer.apple.com/documentation/testing
- Swift Testing, expectations: https://raw.githubusercontent.com/swiftlang/swift-testing/main/Sources/Testing/Testing.docc/Expectations.md
- Swift Testing, parameterized tests: https://raw.githubusercontent.com/swiftlang/swift-testing/main/Sources/Testing/Testing.docc/ParameterizedTesting.md
- Swift Testing, parallelization: https://raw.githubusercontent.com/swiftlang/swift-testing/main/Sources/Testing/Testing.docc/Parallelization.md
- Swift Testing, exit tests: https://raw.githubusercontent.com/swiftlang/swift-testing/main/Sources/Testing/Testing.docc/exit-testing.md
- Swift Testing, testing for errors: https://raw.githubusercontent.com/swiftlang/swift-testing/main/Sources/Testing/Testing.docc/testing-for-errors-in-swift-code.md
- Swift Testing, migrating from XCTest and the interoperability modes: https://raw.githubusercontent.com/swiftlang/swift-testing/main/Sources/Testing/Testing.docc/MigratingFromXCTest.md
- SE-0451, raw identifiers: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0451-escaped-identifiers.md
- SE-0329, `Clock`: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0329-clock-instant-duration.md
- The Swift Programming Language, Initialization: https://docs.swift.org/swift-book/documentation/the-swift-programming-language/initialization/
- The Swift Programming Language, Access Control: https://docs.swift.org/swift-book/documentation/the-swift-programming-language/accesscontrol/
- Google Testing Blog, test behavior not implementation: https://testing.googleblog.com/2013/08/testing-on-toilet-test-behavior-not.html ; don't overuse mocks: https://testing.googleblog.com/2013/05/testing-on-toilet-dont-overuse-mocks.html
