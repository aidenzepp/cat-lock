---
name: swift-domain-contracts
description: "Design and review Swift functions, initializers, domain types and their dependencies so signatures tell the truth. Use when writing or reviewing a function or method in the local package or app; a struct, enum or @Observable model that carries an invariant; parsing raw input (String, numbers, JSON or Codable, URLs, UserDefaults, framework values) into domain values; a validation helper that returns Bool; a function that reads Date.now, UUID(), shuffled() or random(), Locale.current, a .shared singleton or a task-local; a protocol, fake or mock added for testing; Bool or primitive-heavy parameters, parameter objects, or Sequence, Collection or Array parameters; an actor method that checks state, awaits and then writes; or a lifecycle or locking rule kept in a comment. Hand off isolation, error enums and unchecked invariants to swift-isolation, views to swiftui-views and tests to swift-test-design."
---

# Swift domain contracts

A trustworthy design makes functions and data tell the same truth. A signature shows what an operation needs, changes, returns and may fail to do. A value keeps the facts the program has already established, so later code neither checks them again nor carries failure cases that cannot happen. The compiler accepts these choices whether they are right or wrong. Tools own the mechanical rules; this skill covers the judgment.

> Parse raw input into the smallest representation that keeps what was learned, then make every function ask for exactly the data, authority and guarantees it needs.

## 1. Preflight

From the repository root, run the project's toolchain preflight and stop on a non-zero exit. Do not install tools; name the project's setup step instead. In this template that is `./scripts/dev.swift doctor` after `./scripts/dev.swift bootstrap`.

## 2. Confirm the project enforces

Check each item exists. If one is missing, report the gap and apply the rule by hand. This skill says nothing more about these rules.

- `ExistentialAny` on every target: `SWIFT_UPCOMING_FEATURE_EXISTENTIAL_ANY` in the app's build settings, `.enableUpcomingFeature("ExistentialAny")` in the package manifest.
- The SwiftLint custom rule on the `throws`, `rethrows` and `catch` keywords, which excludes test paths. A project that keeps the async helper (`swift-isolation`, step 7) adds a precise exclusion for that one file.
- The `no_discardable_result` custom rule, with warnings as errors.
- SwiftLint `missing_docs` at every access level, and `swiftformat --lint`.
- SwiftLint `function_parameter_count` and `large_tuple`, where the project enables them. Meet either ceiling with a concept (step 6), never with a bag of fields.

## 3. Honest signatures

An honest function shows every operationally meaningful input, output, mutation and external capability in its signature. A dishonest one reaches past its signature for state or authority: the clock, a random source, user settings, a singleton, a task-local. "Honest" is this skill's working term, not Swift vocabulary, and it is not purity:

| Question | Asks |
| --- | --- |
| Pure or impure? | Does evaluation have observable effects? |
| Honest or dishonest? | Does the signature show the real inputs, outputs, effects and authority? |

- `func total(_ values: [Int]) -> Int` is pure and honest.
- `mutating func sort()` is impure and honest: the mutation is in the signature.
- `print(_:to:)`, which takes its output `inout`, is impure and honest about where it writes.
- A function that reads `Date.now` in its body is dishonest: the clock is a hidden input.
- `tracks.shuffled()` hides the system's random generator. `tracks.shuffled(using: &generator)` is honest, though not pure.

Swift's channels are parameters, `inout`, `mutating`, the return value, `Result`'s failure, `async` and closures.

- A class instance passed as a parameter is mutation authority with no marker, because a reference is not copied. Pass values, or name the mutation in the function's name.
- A closure parameter is non-escaping unless marked. `@escaping` says the callee keeps it and `@Sendable` that it may run concurrently; each is authority the signature must earn. A callback makes authority explicit, not pure: state its ordering, reentrancy, failure and cancellation when they matter, and return a sequence instead when the caller should control consumption.

Hidden inputs and their honest forms:

| Hidden | Honest |
| --- | --- |
| `Date.now`, `ContinuousClock.now` | a `now: Date` parameter for wall-clock time, a `ContinuousClock.Instant` for elapsed time |
| `Task.sleep(for:)`, whose clock defaults to `.continuous` | a `some Clock<Duration>` parameter passed as its `clock:` |
| `shuffled()`, `randomElement()`, `Int.random(in:)`, `Bool.random()` | `inout some RandomNumberGenerator`, passed to the `using:` overloads |
| `UUID()` where a result depends on the id | an id parameter; minting is fine where nothing depends on the value |
| `Locale.current`, `Calendar.current`, `TimeZone.current` | a `Locale`, `Calendar` or `TimeZone` parameter |
| `URLSession.shared`, `UserDefaults.standard`, `FileManager.default`, a project `static let shared` | an init parameter wired at the composition root (step 5) |
| `@TaskLocal` | never a domain input; SE-0311 calls it a hidden argument |

- Dishonesty spreads: a function that calls a dishonest one inherits its hidden input. Move the input into the signature, or keep the call inside a deliberately effectful boundary.
- Contain necessary dishonesty in small adapters at the edge that read the clock or the singleton and pass values inward, unless an actor turn, a lock or a transaction needs the effect and the decision together (step 5).
- Draw the line at operationally meaningful inputs. Allocation, scheduling the contract does not depend on and CPU temperature stay out of signatures.
- Seeded generators are test fixtures the project writes. The standard library ships none and documents that its random algorithms may change in a later Swift version, so a test never stores a seeded result as its expected value.

Read [references/dependencies-and-effects.md](references/dependencies-and-effects.md) before writing a function that reads the time, randomness or a singleton, an actor method that awaits, or a protocol added for testing.

## 4. Design the contract before the body

Start from the call site that should exist. State the operation in one sentence, then list:

- the values it needs and the guarantees they carry;
- what it mutates and what it returns;
- how it fails, and which absence is a value rather than a failure;
- the preconditions, postconditions and invariants it keeps;
- time, randomness, user settings, files, network, framework or global state;
- isolation, `Sendable`, escaping closures, cancellation, ordering and cost.

Make the signature describe the durable contract, not today's implementation. Isolation, `Sendable` and cancellation belong to swift-isolation's "Where isolation goes", "Task lifetime and cancellation" and "Sendable design" sections, and error enums and wrapping Apple's throwing calls to its "Failure paths" section.

## 5. Dependencies and effects

Keep deterministic decisions apart from environmental work where the separation keeps the real semantics. Ask for the smallest honest input. This is the seam ladder; other skills point here and do not restate it:

1. A value, when the function needs a snapshot: `now`, an id, a setting.
2. A closure, for one narrow operation that really varies.
3. A standard capability whose semantics fit: `some Sequence<T>`, `inout some RandomNumberGenerator`, `some Clock<Duration>`, `inout some TextOutputStream`.
4. A concrete type, when substitution buys no control.
5. A protocol the consumer owns, for external authority or real alternative implementations.

- The composition root is the `@main` App and model initializers. Singletons and real implementations are wired there and passed inward. A context object, service locator or bag of dependencies hides what each function needs, even when it is passed as a parameter.
- A framework callback (`body`, a button action, `.task`, a delegate method) translates its input and calls one package operation.
- Place effects at the narrowest boundary that keeps consistency, not mechanically at the root. A read, the decision and the write stay together when an actor turn, a lock or a transaction needs them together.
- Actor reentrancy: an actor runs other calls whenever it suspends, so its state can change across any `await`. Never `await` between a check of actor state and the write that depends on it. Await first, or check again after the `await`. The compiler accepts every order.
- A rule that a lock must be held becomes state reachable only inside `Mutex.withLock`, or an actor's isolation; never a comment. The actor-or-`Mutex` choice belongs to swift-isolation, under "Sendable design".

## 6. Ask for the right power

Ask for the least powerful input that still states the real semantic and performance contract:

| Need | Ask for |
| --- | --- |
| one pass | `some Sequence<T>`; iterating a sequence may consume it |
| several passes | `some Collection<T>` |
| indexing, or ownership and growth | `some RandomAccessCollection<T>` or `[T]` |
| contiguous borrowed storage | `Span<T>`, which is bounds-checked and cannot escape |
| a domain object's behavior or invariants | the domain type |
| a few fields of a large value | those fields, not the whole value |

- Write `some P` in parameters. `any P` is for storage that must hold different conforming types.
- Code generic over collections uses `startIndex`, `first` and `indices`, never `0`: an `ArraySlice` keeps its base's indices. Index review is in swift-isolation's "Unchecked invariants" section.
- Do not weaken a parameter only because today's loop compiles against a weaker protocol. Several passes, stable indices and cost are real requirements.
- Return a complete value when the result is bounded. A large or incremental result is a lazy `some Sequence<T>` or an `AsyncSequence`, and text output goes to `inout some TextOutputStream`, so the caller controls consumption.
- Argument labels name roles. Replace each Boolean choice with an enum, and pass time spans as `Duration`. `TimeInterval` is `Double`; use it only at the Foundation call that takes it. A `typealias` is another name for the same type and adds no checking; a domain type is a struct.
- A parameter object is earned when its fields form one concept or one coherent option set. It never fixes a function that owns unrelated jobs, and it is never a way past a parameter-count ceiling.

## 7. Parse at boundaries and keep what you learn

Parsing turns less structured input into more structured data, or fails. Prefer:

```text
raw input -> parser returning Result -> invariant-bearing value -> operations that cannot fail on it
```

over:

```text
raw input -> check returning Bool -> keep using the raw input -> check again, or carry an impossible failure
```

- A `-> Bool` validity check, or an `isValid` property, is a smell when the caller keeps the weak type: the check learned a fact and the program threw it away. Return a type that keeps the fact, or parse straight into the aggregate that owns it.
- Swift's raw boundaries are `Codable` input, `URL` components, `UserDefaults`, bundle resources, framework input and C interop. C interop also follows the `unsafe` rows in swift-isolation's "Unchecked invariants" section.
- Choose the proof owner:
  - A value type, when the fact is intrinsic and travels through returns, properties and collections.
  - An aggregate, such as an `@Observable` model whose state is `private(set)` and changes only through methods that keep the rule, when the fact means something only inside it. A settable `public var` is writable from any view through `@Bindable`.
  - Live state, when the fact can go stale (a name is still free, a slot is still open): keep the check and the action inside one actor turn or one transaction. Never wrap a passing observation in a lasting type.
- Parser shape: `static func parse(_:) -> Result<Self, ParseError>` over a `private init`. An initializer returns no value, the project's APIs do not throw, and a hand-written `init?` drops the reason.
- A closed set is a raw-value enum. Its synthesized `init?(rawValue:)`, and the standard library's raw-value decoding, reject unknown values with no code of yours.
- Decoding: a type with an invariant gets no synthesized `Decodable`. Decode a private wire type of primitives, then parse it.
- Normalization is a stated policy, never a silent repair. `String` equality and hashing already use canonical equivalence, and `lowercased()` folds non-ASCII letters too, so an ASCII-only key checks `isASCII`. Trimming, case folding and unit conversion each get a line in the parser's documentation.
- Once parsing succeeds, downstream operations take the parsed type and drop the parse's failure, unless they accept weaker input again.
- A wrapper is earned only when it removes checks, prevents misuse or makes later operations total. A generic `Validated<T>` names no fact.

Read [references/parse-and-construct.md](references/parse-and-construct.md) before writing a parser, a type with an invariant, a `Decodable` conformance on a domain type, or a `-> Bool` validity check.

## 8. Encode only invariants the design can keep

A dedicated type is earned when its invariant matters, is stable, is needed repeatedly, and holds through every construction and mutation path. For such a type:

- Store it in `let` properties and declare an explicit `private init` in the type body. A body init removes the memberwise initializer, which is otherwise internal even when every property is `public`; an init in an extension keeps it.
- Close Swift's other construction paths. Synthesized `Decodable` assigns stored properties without your parser. A literal conformance (`ExpressibleByStringLiteral` and the rest) requires an initializer that cannot fail, so a validated type never adopts one.
- Expose only operations that keep the invariant, or return a weaker type. An operation returns the strongest type it can prove: filtering a non-empty collection returns `[T]`, not the non-empty type.
- Make legitimate access to the underlying value easy, so callers do not look for a bypass.
- Test construction, rejection, preservation and every bypass path (swift-test-design).

Never strengthen a type because a claim sounds plausible. Check that the implementation can prove it and keep it; otherwise return a weaker type or a `Result`.

Typestate, for a rule that A must happen before B:

- Default to separate types: the operation that finishes A returns the type that offers B.
- Use `~Copyable` with a `consuming` method only where using the old state again is a bug. `consuming` on a copyable type proves nothing, because the caller can copy the value and keep using it.

The line between a parse and a `precondition` is input versus programmer error. Input, I/O and stored data are parsed; a contract only a programmer can break is a precondition (swift-isolation's "Unchecked invariants" section).

## 9. One conceptual level per function

A function either orchestrates sibling operations or carries out one detailed operation. It does not alternate between domain intent and bytes, indices, string handling or a hand-written algorithm.

- Extract a block when the new function names a real operation or policy, owns an invariant or representation rule, isolates an effect, hides lower-level machinery, forms a contract worth testing, or replaces logic whose copies could drift.
- Keep the code inline when a helper would only rename a property access, forward its arguments or shorten the function. In Swift, helper sprawl grows in computed properties and extensions; the same test applies there.
- Use standard-library algorithms (`min(by:)`, `sorted(by:)`, `firstIndex(where:)`, `partition(by:)`) before writing your own. The standard library has no binary search: a sorted search needs an owner type (step 10) or a package, which is a dependency decision.
- Lint metrics such as parameter counts are ceilings, never a reason to extract.

## 10. Let the representation own the contract

Before improving helpers around the current representation, separate what the domain needs from constraints that exist only because of today's container, and per-value invariants (validity, canonical form, units) from relationships (uniqueness, association, order). Give each real invariant its smallest natural owner, and compose the owners:

- A parsed key type owns validity; `Dictionary` and `Set` own association and uniqueness. A `[String: Release]` accepts any string as a key; a `[ReleaseVersion: Release]` does not.
- State with exclusive phases is an enum with associated values, not Booleans plus optionals.
- The standard library has no sorted or ordered container. An ordering invariant needs a type that owns it, or swift-collections' `OrderedSet` and `OrderedDictionary`, which is a dependency decision.
- Add an outer collection type only when it owns behavior or policy beyond what its key and value types already guarantee.

Judge simplicity by the policy left in the system, not by the number of types.

Read [references/state-and-representation.md](references/state-and-representation.md) before modeling a model's loading state, choosing a collection's key, or replacing a sorted array.

## 11. Make every abstraction earn its cost

Before keeping a new function, wrapper, protocol, generic, parameter object, closure, fake or plan type, name what it buys: a truthful contract, an important invalid state ruled out, controlled nondeterminism or external authority, ownership or consistency kept, reusable policy, or clearly better local reasoning or testing. If it buys none, remove it.

Complete the sentence "This exists because it ___, and a direct implementation would ___." "It makes mocking possible", "it is cleaner", "it might be reused" and "it makes the function shorter" do not complete it.

| Rationalization | Reality |
| --- | --- |
| "A protocol makes it testable." | Deterministic code is already testable through its inputs and outputs. A protocol fronts external authority. |
| "Everything should be injectable." | Inject caller-owned policy, nondeterminism and external authority; keep ordinary implementation local. |
| "`consuming` makes it single-use." | Only on a `~Copyable` type. |
| "A `typealias` makes it a type." | It is another name for the same type. |
| "Synthesized `Codable` is free." | On a type with an invariant, it is a constructor that skips the parser. |
| "Effects belong at the top." | Effects belong at the narrowest boundary that keeps consistency, actor turns included. |
| "The weakest protocol is the most reusable." | The truthful input includes multipass, indexing and cost guarantees. |
| "Small functions are easier to read." | Functions that name concepts are; wrapper ladders are not. |

Test deterministic code by value. Test files, network and framework wiring at the highest fidelity that is safe; a protocol does not reproduce external semantics. Test and fake design, including the mock rationalizations, belongs to swift-test-design.

## 12. Before you finish

1. Read the call site without opening the body. The intent and the guarantees it needs are visible.
2. Every meaningful input and effect is in the signature. Search for `Date.now`, `Date()`, `UUID()`, `.shared`, `.standard`, `.default`, `.current`, `@TaskLocal`, `Task.sleep` without `clock:`, and `shuffled()`, `randomElement()` and `random(in:)` without `using:`.
3. No function receives unrelated authority: no context object, and no whole model where a value serves.
4. Every strong type states a true invariant, and every construction path keeps it. Search for `Decodable` and `ExpressibleBy` on types with invariants, and for types with invariants but no init in the type body.
5. Search for `isValid`, `-> Bool` checks and repeated checks. Each learned fact is kept in a type, or confined on purpose to an aggregate or a live boundary.
6. Failures occur where weak input becomes strong data, not in functions that already receive proven values.
7. Every remaining invariant has an owner. None is owned only by a comment, a duplicated helper or caller discipline.
8. The representation keeps no accidental requirement, such as sorting or indexing where the domain needs lookup. Search for `typealias` and `TimeInterval` standing in for domain types.
9. Ordering, cancellation, actor turns and cost survived decomposition. Search actors for an `await` between a check and a write.
10. Mechanical helpers, speculative protocols, wrapper ladders and test-only seams are gone.
11. Tests prove the contract, the invariant boundaries, the deterministic core and the effectful adapters; design them with swift-test-design and run them through app-verification.
12. Run the project's formatter and checks; never hand-format. In this template, run `./scripts/dev.swift fix`, then `./scripts/dev.swift check`.

## Hand-offs

- swift-isolation: error enum cases and wrapping Apple's throwing calls ("Failure paths"); preconditions, `fatalError`, indices and unique keys ("Unchecked invariants"); `Sendable` and the actor-or-`Mutex` choice ("Sendable design"); cancellation ("Task lifetime and cancellation").
- swiftui-views: view inputs, model ownership, `Equatable` model properties, and the locale and formatting in views.
- swift-test-design: tests of rejection, preservation and bypass paths; fakes and the double to choose; seam checks.
- app-verification: running and reporting tests only.
- xcode-project-settings: whether a type goes in the package or the app target, and the upcoming-feature flags.

## Upstream documentation

- Swift API Design Guidelines: https://www.swift.org/documentation/api-design-guidelines/
- The Swift Programming Language, Initialization: https://docs.swift.org/swift-book/documentation/the-swift-programming-language/initialization/
- The Swift Programming Language, Access Control: https://docs.swift.org/swift-book/documentation/the-swift-programming-language/accesscontrol/
- SE-0306, actors and reentrancy: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0306-actors.md
- SE-0311, task-local values: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0311-task-locals.md
- SE-0390, noncopyable types: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0390-noncopyable-structs-and-enums.md
- SE-0433, `Mutex`: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0433-mutex.md
- SE-0447, `Span`: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0447-span-access-shared-contiguous-storage.md
- Xcode's `Span` guide: `/Applications/Xcode.app/Contents/PlugIns/IDEIntelligenceChat.framework/Versions/A/Resources/AdditionalDocumentation/Swift-InlineArray-Span.md`
- Alexis King, "Parse, don't validate": https://lexi-lambda.github.io/blog/2019/11/05/parse-don-t-validate/
