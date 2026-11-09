---
name: swift-isolation
description: "Isolation, task lifetime, cancellation, Result-based failure paths and unchecked invariants in Swift 6 code. Use when writing, reviewing or fixing async code, actors, Sendable types, Task or .task, background work or a concurrency diagnostic; a function that can fail or wraps one of Apple's throwing calls; or any fatalError, precondition, assert, assumeIsolated, integer index, Dictionary(uniqueKeysWithValues:), unsafe acknowledgment, @unchecked Sendable, nonisolated(unsafe), @preconcurrency or Unsafe pointer. Covers the choices the compiler accepts whether they are right or wrong."
---

# Swift isolation

Swift 6 checks data races, but it accepts wrong isolation, ignored cancellation, dropped failures and unchecked invariants without a warning. Tools own every mechanical rule. This skill covers what a correct use means and what a reviewer checks.

## 1. Preflight

From the repository root, run the project's toolchain preflight and stop on a non-zero exit. Do not install tools; name the project's setup step instead. In this template that is `./scripts/dev.swift doctor` after `./scripts/dev.swift bootstrap`.

## 2. Confirm the project enforces

Check each item exists. If one is missing, report the gap and apply the rule by hand.

- Swift 6 language mode on every target as resolved (`xcodebuild -showBuildSettings -json`) and in the package manifest; complete concurrency checking, `Sendable` checks and main-actor `View`, `App` and `Scene` come with it.
- Warnings as errors: `SWIFT_TREAT_WARNINGS_AS_ERRORS`, the manifest's `.treatAllWarnings(as: .error)`, SwiftLint `strict: true` and `swiftformat --lint`.
- Strict memory safety: `SWIFT_STRICT_MEMORY_SAFETY = YES` or `-strict-memory-safety` on app targets, `.strictMemorySafety()` in the manifest.
- SwiftLint `force_unwrapping` (with `ignored_literal_argument_functions: []`), `force_try`, `force_cast` and `implicitly_unwrapped_optional` (with `mode: all`).
- SwiftLint `unhandled_throwing_task`, `fatal_error_message` and `missing_docs` at every access level, conforming types and extensions included.
- SwiftLint `no_empty_block`, `unowned_variable_capture`, `empty_count`, `contains_over_filter_is_empty`, `redundant_sendable`, `duplicate_imports`, `unused_closure_parameter`, `unused_optional_binding`, `unused_enumerated`, `weak_delegate`, `discarded_notification_center_observer`, `blanket_disable_command` and `superfluous_disable_command`.
- SwiftLint custom rules: `no_discardable_result`, and the rule on the `throws`, `rethrows` and `catch` keywords (`result_failure_paths` in this template), which excludes test paths. A project that keeps the async helper (step 7) adds a precise exclusion for that one file; the template ships none.
- A repository check that every escape hatch and `unsafe` acknowledgment has an adjacent comment, and one that no disable comment names the force-unwrap, force-try, force-cast or IUO rules.

## 3. Read the target's settings first

Before fixing a concurrency diagnostic, find the target the file builds in and read its language mode and default isolation. For an Xcode target, read them from `xcodebuild -showBuildSettings -json`, resolved per scheme, destination and configuration as `xcode-project-settings` step 2 describes. For the package, read the manifest's `swiftSettings`. An unset default isolation is `nonisolated`.

Read the upcoming features (`NonisolatedNonsendingByDefault`, `InferIsolatedConformances`) and strict memory safety from the build log's `swiftc` invocation, not from `-showBuildSettings`. On Xcode 27 builds, `-showBuildSettings` omits defaults that Xcode's build-system spec files supply, and it reports `SWIFT_STRICT_MEMORY_SAFETY` as unset when the flag is set in `OTHER_SWIFT_FLAGS`. `xcode-project-settings` step 4 gives the procedure.

- The same source means different things under different defaults. Fix the isolation where the state's owner lives.
- Do not add `@MainActor` as a blanket fix. Add it where the code is UI-bound, and say why.
- Changing a setting belongs to `xcode-project-settings`.

## 4. Where isolation goes

- App target: `MainActor` default isolation, which the project sets, whether Xcode's template or `project.yml`. The `@main` App, views and any model kept in the app target need no annotation.
- Local package: `nonisolated`, stated in the manifest as `.defaultIsolation(nil)`, as `xcode-project-settings` requires. Its `@Observable` models carry `@MainActor`, because views read them on the main actor.
- Package services, clients and parsers are `nonisolated` value types. A type that owns mutable state shared across tasks is an `actor`.
- With `NonisolatedNonsendingByDefault`, a `nonisolated async` function runs on its caller's actor. Write `nonisolated(nonsending)` when that must hold whatever the setting.

## 5. Offloading work

CPU-heavy work goes in an `@concurrent` `async` method on a `nonisolated` type, and callers `await` it. CPU-heavy means long enough to drop frames, such as decoding a large file or processing an image; a small decode is not.

- Not `Task.detached`. `@concurrent` states the offload in the signature, the work stays in the caller's task so cancellation reaches it, and the caller's actor stays free.
- Not `Task {}` to get off the main actor: it inherits the enclosing actor.

## 6. Task lifetime and cancellation

- Views start async work with `.task` or `.task(id:)`, not `Task {}` in `onAppear`. SwiftUI cancels the task when the view goes away or the id changes.
- After each `await`, a cancelled task body writes no state. It handles `.cancelled` as a case of its own and returns, because a newer task, or no view, owns that state now.
- Never `try?` a call that can throw `CancellationError`. It turns cancellation into "no value".
- A read that a caller may cancel checks `Task.isCancelled` before it returns and reports `.cancelled`, so a value that arrives after cancellation never reaches a caller that moved on.
- An unstructured `Task` has one owner that keeps its handle and cancels it when the work's purpose ends.
- `deinit` is nonisolated. Never start a `Task` there that captures `self`.

Read [references/task-cancellation.md](references/task-cancellation.md) before writing or reviewing a `.task` body.

## 7. Failure paths

The project's APIs return `Result<Success, Failure>` with a typed error enum. The judgment is in the cases and the wrapping:

- Each case is something a caller can act on: try again later, report, or end quietly. Do not mirror Apple's error types; map them where the call is made.
- An API that can be cancelled (async, or running inside a task) has an explicit `.cancelled` case and reports cancellation only through it. A synchronous API carries no `.cancelled` case, because it can never produce one. When a cancellable API calls a synchronous one, it maps that API's failure into its own enum.
- Synchronous Apple calls: wrap with `Result(catching:)` where the call is made, then `mapError` to the enum.
- Async Apple calls: `Result(catching:)` takes only a synchronous closure, so they go through `Result.catching(_:mapError:)`, the one async helper. The template ships neither the helper nor a lint exclusion for it. If the helper is absent, the project adds it once from failure-paths.md, Example 3, in a file of its own, and adds an exclusion for that one path to the keyword rule. Do not write a second helper or hand-roll `do`/`catch` around an async call.
- A hand-written witness of an Apple protocol that must call throwing APIs, such as `Decodable.init(from:)`, keeps `throws` with a trailing `// swiftlint:disable:this <rule>` comment on the declaration line, for the keyword rule, naming the requirement. Only the trailing form works: above the doc comment it suppresses nothing, and between the doc comment and the declaration it orphans the doc. A witness that throws nothing drops `throws`; a nonthrowing method satisfies a throwing requirement. Prefer synthesized conformances on wire types, which write no keyword. Never synthesize `Decodable` for a type that carries an invariant: decode a wire type, then parse it (see swift-domain-contracts).
- `try?` on an Apple call and `_ =` on a `Result` both drop a failure. Each needs a comment saying why no caller can act on it. A reviewer searches for both.

Read [references/failure-paths.md](references/failure-paths.md) before writing an API that can fail, wrapping an Apple throwing call, or touching the async helper.

## 8. Escape hatches

`@unchecked Sendable`, `nonisolated(unsafe)`, `@preconcurrency` and `MainActor.assumeIsolated` each compile clean and switch a check off. Reach for one only when immutability, isolation, an actor or `sending` cannot express the guarantee. Each carries a comment beside it naming the invariant that makes it safe.

| Construct | The comment names | Also |
| --- | --- | --- |
| `@unchecked Sendable` | What guards every mutable member, such as a lock or immutability after `init` | A lock-guarded type can stay this way for good |
| `nonisolated(unsafe)` | Why no two tasks touch the value at once | Its `unsafe` acknowledgments follow the `unsafe` row in step 9 |
| `@preconcurrency` | The upstream module and the change that removes the attribute | An `@unsafe` on the import follows the `unsafe` row in step 9 |
| `MainActor.assumeIsolated` | Why the call is on the main actor | Follows the `precondition` contract in step 9 |

The reviewer checks that the named invariant is true and holds for every caller. A comment that exists but is false is the defect no tool catches.

## 9. Unchecked invariants

Each construct below compiles clean and fails only at run time. Use it only where its condition holds, write the invariant beside it, and review it against the last column. Recoverable failures are `Result` failures (step 7), never traps.

| Construct | Acceptable when | Documents | Reviewer checks |
| --- | --- | --- | --- |
| `fatalError` | A path the code proves unreachable, with no failable form | The message names the invariant | It holds for every caller; no `Result`, optional or failable initializer serves (`required init?(coder:)` returns `nil`); no input, I/O or user data reaches the line |
| `precondition`, `preconditionFailure` | A caller contract that only a programmer error can break | `- Precondition:` in the API's docs (placement: `swift-doc-comments`, "Sections by declaration") | Input, I/O, persisted or network data cannot fail it; every caller can satisfy it; the check is cheap. It stops Release builds too |
| `assert`, `assertionFailure` | Cheap internal consistency | What must already be true | It stops only Debug builds and tests, so Release relies on the condition holding |
| `MainActor.assumeIsolated` | An isolated conformance cannot state the guarantee | Why the call is on the actor | It crashes off the main actor's executor; every path to it is on the main actor |
| Integer subscript | The index comes from the same collection, unchanged since: `indices`, `firstIndex(where:)`, `enumerated()` offsets, a checked `indices.contains(i)` | Where the index came from, if not on the same line | The collection cannot change between check and use, across an `await` included; no literal index such as `items[0]` on a collection that can be empty. Otherwise use `first`, `last`, `for`-`in` or `zip` |
| `Dictionary(uniqueKeysWithValues:)` | Keys are unique by construction | A comment naming that source | Input data, case folding or normalization cannot repeat a key. Otherwise use `Dictionary(_:uniquingKeysWith:)` and say which duplicate wins. `dict[key]` is an Optional; its only trap is a force unwrap |
| `unsafe`, `@unsafe`, `nonisolated(unsafe)`, `unowned(unsafe)`, `@exclusivity(unchecked)` | A boundary with no safe API, in the smallest scope | The invariant relied on: lifetime, bounds, initialization, exclusivity or thread safety. An own `@unsafe` declaration documents what callers must uphold | No safe API serves, and the named invariant holds. Strict memory safety makes each use visible, not safe |
| `Unsafe(Mutable)(Raw)(Buffer)Pointer`, `OpaquePointer`, `Unmanaged`, `unsafeBitCast`, `unsafeDowncast`, `unsafelyUnwrapped` | As `unsafe`, when `Span`, `RawSpan`, `Data` or `[UInt8]` cannot serve | As `unsafe` | The pointer never leaves the `withUnsafe…` closure that vends it; bounds and initialization hold |

Arithmetic overflow also traps, and no tool flags it. Review arithmetic on values that input can size.

Read [references/unchecked-invariants.md](references/unchecked-invariants.md) before writing or reviewing `Dictionary(uniqueKeysWithValues:)`; its examples show the comment-and-check shape every row shares.

## 10. Sendable design

- Prefer value types whose stored members are `Sendable`.
- For shared mutable state, use an `actor`, `@MainActor`, `Mutex` or `sending` to hand over ownership, before `@unchecked Sendable`.
- Choosing between an `actor` and a `Mutex`: an `actor` when callers can `await` and the state's operations may suspend; a `Mutex` when callers must stay synchronous and every access is short and never suspends inside the lock. `Mutex` comes from the `Synchronization` module (`import Synchronization`) and guards its value through `withLock`. It does not replace an actor where an access needs an `await`. Its availability follows the deployment target, so check it before adopting it.
- Public types in the package state `Sendable` explicitly, because Swift does not infer it for them.

## 11. Legacy patterns

- No `Thread.sleep` in async code. `Task.sleep(for:)` suspends and ends on cancellation. `Task.sleep(nanoseconds:)` is not deprecated; do not churn it.
- No `DispatchQueue.main.async` or `MainActor.run` where the function or type can declare its isolation instead.
- GCD stays at C or callback boundaries, with a comment naming the boundary.

## 12. Writing the code

Run the project's formatter (`./scripts/dev.swift fix` in this template). Do not hand-format.

## Hand-offs

- Build settings, default isolation and upcoming features: `xcode-project-settings`.
- SwiftUI data flow, view structure and identity: `swiftui-views`.
- Case display text and user-facing failure messages: `swift-error-surfaces`.
- Comment form, including `- Precondition:` and failure cases: `swift-doc-comments`.
- Test design, fakes and matching `Result` cases: `swift-test-design`; running and reporting tests: `app-verification`.

## Upstream documentation

- Xcode's concurrency guide: `/Applications/Xcode.app/Contents/PlugIns/IDEIntelligenceChat.framework/Versions/A/Resources/AdditionalDocumentation/Swift-Concurrency-Updates.md`
- Xcode's `Span` guide: `/Applications/Xcode.app/Contents/PlugIns/IDEIntelligenceChat.framework/Versions/A/Resources/AdditionalDocumentation/Swift-InlineArray-Span.md`
- The toolchain's diagnostic explanations: `/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/share/doc/swift/diagnostics/`
- The Swift 6 migration guide: https://www.swift.org/migration/documentation/migrationguide/ (common problems: https://github.com/swiftlang/swift-migration-guide/blob/main/Guide.docc/CommonProblems.md)
- SE-0458, strict memory safety: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0458-strict-memory-safety.md
- SE-0461, `@concurrent` and `nonisolated(nonsending)`: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0461-async-function-isolation.md
- SE-0433, `Mutex` and the `Synchronization` module: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0433-mutex.md
- SE-0413, typed throws and `Result(catching:)`: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0413-typed-throws.md
