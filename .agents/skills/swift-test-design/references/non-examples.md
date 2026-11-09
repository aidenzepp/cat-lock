# Labeled non-examples

Read this when reviewing a test, diagnosing a brittle suite, or about to add a mock. Each negative is wrong on exactly one axis, named in its heading. Most are wrong in a way no tool sees, because the formatter, linter and typechecker accept them; the checks line says so, and the defect is a reviewer's to find. The examples were extracted and run through the same checks as `examples.md`, and no test was run.

Omitted surroundings are as in [examples.md](examples.md).

## NEGATIVE 1: `#expect` then an index

Evidence: Wrong axis: no gate. `#expect(count == 2)` records a failure and the test keeps running, so `tracks[0]` still executes against whatever the array holds, and an empty array traps and ends the whole test process, not just the test. Use `try #require` as in Positive 4.

Checks: passes SwiftFormat lint, SwiftLint strict (package source with the base configuration alone, test code with the test child profile added) and the strict typecheck, and the layout follows swift-code-layout. Review-only: no tool sees the defect; the trap is Swift array semantics, not run here.

```swift
import Testing

/// A song in a playlist.
public struct Track: Equatable, Identifiable, Sendable {
    /// The track's stable identity.
    public let id: Int
    /// The title shown in the list.
    public var title: String
}

/// An ordered list of tracks.
public struct Playlist: Sendable {
    /// The tracks in play order.
    public private(set) var tracks: [Track]

    /// Creates a playlist that starts with the given tracks.
    public init(tracks: [Track]) {
        self.tracks = tracks
    }

    /// Moves the last track to the front and does nothing for fewer than two tracks.
    public mutating func rotate() {
        guard tracks.count > 1, let last = tracks.popLast() else {
            return
        }

        tracks.insert(last, at: 0)
    }
}

struct PlaylistTests {
    @Test func `rotating moves the last track to the front`() {
        var playlist = Playlist(tracks: [Track(id: 1, title: "Intro"), Track(id: 2, title: "Outro")])

        playlist.rotate()
        #expect(playlist.tracks.count == 2)
        #expect(playlist.tracks[0].title == "Outro")
    }
}
```

## NEGATIVE 2: two collections where pairs were meant

Evidence: Wrong axis: no `zip`. Two argument collections produce their Cartesian product, so this declares 16 cases, 12 of which pair a minute count with the wrong label and fail. Positive 5 is the same test with `zip`.

Checks: passes SwiftFormat lint, SwiftLint strict (package source with the base configuration alone, test code with the test child profile added) and the strict typecheck, and the layout follows swift-code-layout. Review-only: the typecheck accepts it; the product is documented Swift Testing behavior, not run here.

```swift
import Testing

/// Formats a length of time for a list row.
public enum DurationLabel {
    /// Returns "45 min" below an hour and "1 h 30 min" from an hour up; whole hours omit the minutes.
    public static func text(forMinutes minutes: Int) -> String {
        guard minutes >= 60 else {
            return "\(minutes) min"
        }

        let remainder = minutes % 60

        return remainder == 0 ? "\(minutes / 60) h" : "\(minutes / 60) h \(remainder) min"
    }
}

struct DurationLabelTests {
    @Test(arguments: [0, 45, 60, 90], ["0 min", "45 min", "1 h", "1 h 30 min"])
    func `a length of time reads as minutes, then hours and minutes`(minutes: Int, expected: String) {
        #expect(DurationLabel.text(forMinutes: minutes) == expected)
    }
}
```

## NEGATIVE 3: asserting the call graph

Evidence: Wrong axis: observable behavior. The mock's call count is the assertion, so the test still passes if `listTitles` returns the wrong titles, and fails after a harmless cache. The seam itself is sound: one storage capability in domain terms, which the real store (omitted) implements. Assert the titles returned for a fixed store.

Checks: passes SwiftFormat lint, SwiftLint strict (package source with the base configuration alone, test code with the test child profile added) and the strict typecheck, and the layout follows swift-code-layout. Review-only: no tool sees an assertion on the wrong thing.

```swift
import Testing

/// A reminder on the to-do list.
public struct Reminder: Equatable, Sendable {
    /// The reminder's title.
    public let title: String
}

/// The storage the reminder list reads from.
public protocol ReminderStore: Sendable {
    /// Returns every saved reminder.
    func list() async -> [Reminder]
}

/// Returns the titles of the saved reminders in order.
public func listTitles(from store: some ReminderStore) async -> [String] {
    await store
        .list()
        .map(\.title)
}

actor MockReminderStore: ReminderStore {
    private(set) var listCallCount = 0

    func list() -> [Reminder] {
        listCallCount += 1

        return [Reminder(title: "Pay rent")]
    }
}

struct ReminderListTests {
    @Test func `listing calls the store once`() async {
        let store = MockReminderStore()

        _ = await listTitles(from: store)
        #expect(await store.listCallCount == 1)
    }
}
```

## NEGATIVE 4: a fake that is a different system

Evidence: Wrong axis: fidelity. `SavedNoteStore` refuses a second note under a taken title; `FakeNoteStore` accepts it, and the test then asserts that convenient behavior. A suite that ran the same tests against both stores (Positive 3) would have failed here.

Checks: passes SwiftFormat lint, SwiftLint strict (package source with the base configuration alone, test code with the test child profile added) and the strict typecheck, and the layout follows swift-code-layout. Review-only: both stores satisfy the protocol; only a shared contract suite exposes the difference.

```swift
import Foundation
import Testing

/// A note the user saved.
public struct Note: Equatable, Sendable {
    /// The unique name the note is saved under.
    public let title: String
    /// The note's text.
    public let body: String
}

/// Why a note store refused a request.
public enum NoteStoreError: Error, Equatable {
    /// A note with this title is already saved.
    case duplicateTitle
}

/// The storage the note list needs.
public protocol NoteStore: Sendable {
    /// Saves a note and returns it, or fails when its title is taken.
    ///
    /// - Returns: The saved note, or `.duplicateTitle` when its title is taken.
    func save(_ note: Note) async -> Result<Note, NoteStoreError>
}

/// The production store; it refuses a second note under the same title.
public actor SavedNoteStore: NoteStore {
    /// The titles saved so far; a title in this set is taken.
    private var titles: Set<String> = []

    /// Saves a note unless its title is taken.
    public func save(_ note: Note) -> Result<Note, NoteStoreError> {
        guard titles.insert(note.title).inserted else {
            return .failure(.duplicateTitle)
        }

        return .success(note)
    }
}

actor FakeNoteStore: NoteStore {
    private var notes: [Note] = []

    func save(_ note: Note) -> Result<Note, NoteStoreError> {
        notes.append(note)

        return .success(note)
    }
}

struct NoteListTests {
    @Test func `saving two notes with the same title succeeds`() async {
        let store = FakeNoteStore()
        let first = Note(title: "Groceries", body: "Milk")
        let second = Note(title: "Groceries", body: "Eggs")

        #expect(await store.save(first) == .success(first))
        #expect(await store.save(second) == .success(second))
    }
}
```

## NEGATIVE 5: a hidden dependency

Evidence: Wrong axis: a visible composition boundary. `greeting()` reads `CurrentUser.shared`, so the test cannot choose the name; it passes only while the global holds "Sam". Pass the name in, or the user, from the caller.

Checks: passes SwiftFormat lint, SwiftLint strict (package source with the base configuration alone, test code with the test child profile added) and the strict typecheck, and the layout follows swift-code-layout. Review-only: no tool flags a singleton read.

```swift
import Foundation
import Testing

/// The signed-in user's name, shared by the whole app.
public final class CurrentUser: Sendable {
    /// The one instance every caller reads.
    public static let shared = CurrentUser(name: "Sam")

    /// The user's display name.
    public let name: String

    /// Creates the signed-in user; the shared instance is the only one.
    ///
    /// - Parameter name: The name the home screen greets.
    private init(name: String) {
        self.name = name
    }
}

/// Returns the greeting shown on the home screen.
public func greeting() -> String {
    "Welcome back, \(CurrentUser.shared.name)"
}

struct GreetingTests {
    @Test func `the greeting names the user`() {
        #expect(greeting() == "Welcome back, Sam")
    }
}
```

## NEGATIVE 6: a failure message that says nothing

Evidence: Wrong axis: diagnostic content. `Issue.record("failed")` names no operation and no observed value, so a reader of the report cannot tell what broke. Say what was called and what came back, as the `Comment` in Positive 2 does.

Checks: passes SwiftFormat lint, SwiftLint strict (package source with the base configuration alone, test code with the test child profile added) and the strict typecheck, and the layout follows swift-code-layout. Review-only: no tool reads the words.

```swift
import Testing

/// A whole percentage from 0 through 100.
public struct Percentage: Equatable, Sendable {
    /// Why a number is not a percentage.
    public enum Failure: Error, Equatable {
        /// The number is below 0 or above 100.
        case outOfRange(Int)
    }

    /// The validated number.
    public let value: Int

    /// Creates a percentage from a number already known to be within 0 through 100.
    ///
    /// - Parameter value: A number from 0 through 100.
    private init(value: Int) {
        self.value = value
    }

    /// Returns the percentage for a number, or a failure when it is out of range.
    ///
    /// - Parameter value: The number to check.
    /// - Returns: The percentage, or `.outOfRange` carrying `value` when it is below 0 or above 100.
    public static func make(_ value: Int) -> Result<Percentage, Failure> {
        guard (0 ... 100).contains(value) else {
            return .failure(.outOfRange(value))
        }

        return .success(Percentage(value: value))
    }
}

struct PercentageTests {
    @Test func `a number outside the range is refused`() {
        guard case let .failure(failure) = Percentage.make(101) else {
            Issue.record("failed")

            return
        }
        #expect(failure == .outOfRange(101))
    }
}
```

## NEGATIVE 7: an escape hatch with a false comment

Evidence: Wrong axis: the `@unchecked Sendable` justification. Swift Testing runs tests in parallel, so the claim that tests run one at a time is false, and nothing guards `saved` if a second test shares the store. Make the recorder an `actor` or hold a `Mutex` (`swift-isolation`, heading "Sendable design").

Checks: passes SwiftFormat lint, SwiftLint strict (package source with the base configuration alone, test code with the test child profile added) and the strict typecheck, and the layout follows swift-code-layout. Review-only: the comment exists and the compiler accepts the escape hatch; only a reviewer can find that the stated invariant is false.

```swift
import Testing

/// A note the user saved.
public struct Note: Equatable, Sendable {
    /// The note's title.
    public let title: String
}

/// The storage the note list needs.
public protocol NoteStore: Sendable {
    /// Saves a note.
    func save(_ note: Note) -> Note
}

/// Tests run one at a time, so the array is never touched from two tasks.
final class RecordingNoteStore: NoteStore, @unchecked Sendable {
    private(set) var saved: [Note] = []

    func save(_ note: Note) -> Note {
        saved.append(note)

        return note
    }
}

struct NoteListTests {
    @Test func `saving records the note`() {
        let store = RecordingNoteStore()
        let note = Note(title: "Groceries")

        #expect(store.save(note) == note)
        #expect(store.saved == [note])
    }
}
```

## Common rationalizations

| Rationalization | Reality |
| --- | --- |
| "The test passes." | A passing test can protect the wrong behavior, or prove only that the code agrees with its mock, not with the system the mock stands for. |
| "Mocking is easier." | Easier setup is not better evidence; try a real local dependency, a fake, then a stub first. |
| "Dependency injection means a protocol for every type." | Each dependency gets the smallest honest seam on the ladder in `swift-domain-contracts`, heading "Dependencies and effects", and most of its rungs are not protocols. |
| "The test checks the invariant." | A test detects a violation after the fact; the design should refuse invalid states at their owner. |
| "It is only a private helper." | Private structure is replaceable unless it is the stable contract. |
| "`#expect` already fails the test." | It records a failure and continues; the next line still runs, and a trapping index ends the whole process. |
| "The error is already printed." | The reader still needs the operation and the assumption that made it matter. |
| "The test is obvious to me." | It must stay self-explanatory to a reader who did not write it. |
| "I can rerun until it passes." | Intermittent success is nondeterminism, not correctness. |
