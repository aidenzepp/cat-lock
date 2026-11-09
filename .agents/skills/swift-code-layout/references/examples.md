# Code layout: labeled examples

Read before laying out or reviewing the statements in a body. The examples share one domain, a notes app. L12 is an app-target view and L15 a test in the package's test target. L16 and L17 each hold an app-target view and a test in the package's test target. Every other example is local package code.

How the examples were checked. Each block was extracted to its own Swift file and run from the repository root through the pinned SwiftFormat (`--lint --config .swiftformat`), the pinned SwiftLint (`lint --strict --config .swiftlint.yml`) and `xcrun swiftc -typecheck -swift-version 6 -strict-memory-safety -warnings-as-errors` with the template's four upcoming features. Package examples omit `-default-isolation MainActor`. L12 adds it and imports `NotesKit`, a module emitted from stubs of `Note` and `NoteTitle`. An excerpt was checked inside the complete type its line names. L15's test was linted with the test child profile added (`--config .swiftlint-tests.yml`) and typechecked in one module with L14's `Backup`, which was linted with the base configuration alone, and with `Testing` on the framework and plugin paths. L16's and L17's views were checked as L12 was, without `NotesKit`, and their tests as L15's was, in one module with L9's `restore(_:from:)`. No test was run. The template's layout rules (SKILL.md section 1) run in its formatting command, not in these three checks, so "format pass" below covers SwiftFormat alone; L17 and L19 name the layout findings they carry.

Omitted surroundings, which the blocks use as described here and never show:

- `Note`: an identity, a `NoteTitle`, text, the moment of the last edit, and whether the sync service holds the latest edit. `Note(id:title:)` leaves the rest at their defaults.
- `NoteTitle`: the title type whose parser L5 shows; `text` holds the title.
- `NoteStore`: a class that keeps notes in memory, created empty by `NoteStore()`, whose `insert(_:)` replaces any note with the same identity, plus `read(_:)`, `contains(_:)`, `allNotes()`, which returns the notes in no set order, and `remove(_:)`.
- `Summary`: a class with a `count`. `parse(_:)`: turns an export file's data into notes.
- `ImportError`, `BackupError`, `TitleError`, `SyncError` and `LinkError`: the failure enums, with the cases the blocks name. `BackupError` is `Equatable`, so L15 compares restore results with `==`. `SyncIndicator` and `MergeCount`: the value types L8 and L7 return.

Every NEGATIVE passes all three checks. L17 and L19 fail the template's layout rules on their labeled axis; every other NEGATIVE's defect is a judgment rule that no tool sees.

Contents: L1 POSITIVE steps by meaning · L2 NEGATIVE blank lines by statement kind · L3 NEGATIVE no blank lines between steps · L4 NEGATIVE a variable far from its use · L5 POSITIVE clean and check · L6 POSITIVE create and configure · L7 POSITIVE steps in a loop body · L8 POSITIVE a decision at the end · L9 POSITIVE an explaining comment · L10 POSITIVE `defer` after its line · L11 NEGATIVE `defer` set apart · L12 POSITIVE view content · L13 NEGATIVE a step with an honest name left nested inside its function · L14 POSITIVE small named functions · L15 POSITIVE a test's checks with their actions · L16 POSITIVE chained calls one per line · L17 NEGATIVE chained calls on one line · L18 POSITIVE closures bound before their guards · L19 NEGATIVE closures inside guard conditions.

## L1. POSITIVE: steps by meaning

Placement: local package. Checks: format pass, lint pass, typecheck pass.

Evidence: the body has three steps a reader can name, then the exit: read the file, insert and count its notes, log the import. `guard let data` checks the read, so it stays in the read step. `var count = 0` sits beside the loop that increments it, and `if count == 0` checks that loop's result, so both stay in the counting step. Creating `summary`, setting its `count` and logging it is one step. No blank line sits inside a step. The blank line above the final `return` is the formatting command's (`layout_exit_blank_line`): the `return` ends the body and starts no step.

```swift
import Foundation

/// An importer for the notes that another app exported.
struct NoteImporter {
    /// The destination for the summary of each import that inserts at least one note.
    let log: (Summary) -> Void

    /// Reads an export file and inserts its notes into a store.
    ///
    /// - Parameters:
    ///   - url: The location of the export file.
    ///   - store: The store that receives the notes.
    /// - Returns: The number of notes inserted; `.failure(.unreadable)` when the file cannot be
    ///   read, or `.failure(.empty)` when it holds no notes.
    func importNotes(from url: URL, into store: NoteStore) -> Result<Int, ImportError> {
        let data = store.read(url)
        guard let data else {
            return .failure(.unreadable)
        }

        var count = 0
        let notes = parse(data)
        for note in notes {
            store.insert(note)
            count += 1
        }
        if count == 0 {
            return .failure(.empty)
        }

        let summary = Summary()
        summary.count = count
        log(summary)

        return .success(count)
    }
}
```

## L2. NEGATIVE: blank lines by statement kind

Placement: local package. Checks: format pass, lint pass, typecheck pass, on L1's file with this member. The defect is a judgment rule that no tool sees.

Excerpt: the `importNotes(from:into:)` member of L1's `NoteImporter`, without its doc comment, which is L1's. Only blank lines differ from L1.

Evidence: a blank line before every `guard`, `for` and `if` cuts three steps apart. Reading the file is split from the check that it was read, the parsed notes from the loop that inserts them, and `if count == 0`, which checks the loop's result, from that loop. A reader who skims the blank lines finds six steps where the code has three. A spacing tool that adds blank lines around every control statement produces exactly this layout. Where a project's formatting command does, keep its output and report the conflict (SKILL.md section 1): the label names what the layout costs a reader, not a change to undo.

```swift
    func importNotes(from url: URL, into store: NoteStore) -> Result<Int, ImportError> {
        let data = store.read(url)

        guard let data else {
            return .failure(.unreadable)
        }

        var count = 0
        let notes = parse(data)

        for note in notes {
            store.insert(note)
            count += 1
        }

        if count == 0 {
            return .failure(.empty)
        }

        let summary = Summary()
        summary.count = count
        log(summary)

        return .success(count)
    }
```

## L3. NEGATIVE: no blank lines between steps

Placement: local package. Checks: format pass, lint pass, typecheck pass, on L1's file with this member. The defect is a judgment rule that no tool sees.

Excerpt: the same member, without its doc comment. Only blank lines differ from L1.

Evidence: with no blank line between steps, the body reads as one block, so a reader must read every line to learn where reading the file ends and counting begins. The one blank line left, above the final `return`, is the one the formatting command places above an exit (`layout_exit_blank_line`). Removing it too would add a second defect, which that rule reports.

```swift
    func importNotes(from url: URL, into store: NoteStore) -> Result<Int, ImportError> {
        let data = store.read(url)
        guard let data else {
            return .failure(.unreadable)
        }
        var count = 0
        let notes = parse(data)
        for note in notes {
            store.insert(note)
            count += 1
        }
        if count == 0 {
            return .failure(.empty)
        }
        let summary = Summary()
        summary.count = count
        log(summary)

        return .success(count)
    }
```

## L4. NEGATIVE: a variable far from its use

Placement: local package. Checks: format pass, lint pass, typecheck pass, on L1's file with this member. The defect is a judgment rule that no tool sees.

Excerpt: the same member, without its doc comment. Only the position of `var count = 0` differs from L1.

Evidence: declared first, `var count = 0` joins the read step, which never uses it, and the counting step no longer holds everything it needs. A reader of the loop must look back past the guard to learn where `count` starts. Move it down to the loop, as in L1.

```swift
    func importNotes(from url: URL, into store: NoteStore) -> Result<Int, ImportError> {
        var count = 0
        let data = store.read(url)
        guard let data else {
            return .failure(.unreadable)
        }

        let notes = parse(data)
        for note in notes {
            store.insert(note)
            count += 1
        }
        if count == 0 {
            return .failure(.empty)
        }

        let summary = Summary()
        summary.count = count
        log(summary)

        return .success(count)
    }
```

## L5. POSITIVE: cleaning and checking a value is one step

Placement: local package. Checks: format pass, lint pass, typecheck pass, on the complete `NoteTitle`.

Excerpt: the `parse(_:)` member of `NoteTitle`, the title type of every `Note`. The rest of the file is omitted: `import Foundation`, `static let maximumLength = 100`, the stored `text` and a `private init(text:)`.

Evidence: trimming the input and the two guards that check the trimmed text form one step, "clean and check the title", so no blank line separates them. Consecutive guards stay together. The formatting command places a blank line above the final `return`, because the guards precede it (`layout_exit_blank_line`).

```swift
    /// Parses text into a note's title.
    ///
    /// Surrounding whitespace and newlines are trimmed before the title is checked.
    ///
    /// - Parameter input: The text a person entered or a file holds.
    /// - Returns: The title; `.failure(.empty)` when the text is empty after trimming, or
    ///   `.failure(.tooLong)` when it holds more than ``maximumLength`` characters.
    static func parse(_ input: String) -> Result<NoteTitle, TitleError> {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure(.empty)
        }
        guard trimmed.count <= maximumLength else {
            return .failure(.tooLong)
        }

        return .success(NoteTitle(text: trimmed))
    }
```

## L6. POSITIVE: creating and configuring an object is one step

Placement: local package. Checks: format pass, lint pass, typecheck pass.

Evidence: creating the formatter and setting its locale, time zone and format is one step, because the formatter is not ready until its last setting. The return that uses it follows the blank line the formatting command places above an exit (`layout_exit_blank_line`). A blank line between the initializer and its settings would split one object's setup in two.

```swift
import Foundation

/// Names an export file for the day it was made.
///
/// The name has the form `Notes 2026-11-04.json`. The fixed POSIX locale keeps the Gregorian
/// calendar and Western digits, so the name sorts by date and reads the same whatever the
/// person's language and region.
///
/// - Parameters:
///   - date: The moment of the export.
///   - timeZone: The time zone whose calendar day the name shows.
/// - Returns: The file name, with its extension.
func exportFileName(for date: Date, in timeZone: TimeZone) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = timeZone
    formatter.dateFormat = "yyyy-MM-dd"

    return "Notes \(formatter.string(from: date)).json"
}
```

## L7. POSITIVE: a loop body has its own steps

Placement: local package. Checks: format pass, lint pass, typecheck pass.

Evidence: `var count` sits directly above the loop that fills it, in the same step. Inside the loop, skipping a note the store already holds is one step and inserting and counting a new note is the next, so a blank line separates them. In the guard's `else` block, the formatting command places a blank line above `continue`, because `count.skipped += 1` precedes it (`layout_exit_blank_line`); the `continue` ends the block and starts no step.

```swift
/// Inserts the notes that a store does not hold yet, matching notes by identity.
///
/// - Parameters:
///   - notes: The notes received from another device.
///   - store: The store that receives the new notes.
/// - Returns: How many notes were inserted and how many the store already held.
func merge(_ notes: [Note], into store: NoteStore) -> MergeCount {
    var count = MergeCount()
    for note in notes {
        guard !store.contains(note.id) else {
            count.skipped += 1

            continue
        }

        store.insert(note)
        count.inserted += 1
    }

    return count
}
```

## L8. POSITIVE: a decision at the end

Placement: local package. Checks: format pass, lint pass, typecheck pass.

Evidence: counting the unsent notes and the guard that checks the count form one step. The decision between `.failed` and `.sending` is the next, and the `if` and the final `return` are its two branches. The step boundary is the blank line above the `if`. The formatting command places a blank line above the final `return` as an exit (`layout_exit_blank_line`), so it stays even though that `return` completes the decision.

```swift
/// Chooses what the sync indicator in the note list shows.
///
/// - Parameters:
///   - notes: Every note in the store.
///   - lastFailure: Why the most recent sync attempt failed, or `nil` when it succeeded.
/// - Returns: `.idle` when every note is sent, even after a failed attempt; otherwise
///   `.failed` when the last attempt failed, or `.sending` with the number of unsent notes.
func syncIndicator(for notes: [Note], lastFailure: SyncError?) -> SyncIndicator {
    let unsent = notes.count {
        !$0.isSent
    }
    guard unsent > 0 else {
        return .idle
    }

    if let lastFailure {
        return .failed(lastFailure)
    }

    return .sending(unsent)
}
```

## L9. POSITIVE: an explaining comment directly above its step

Placement: local package. Checks: format pass, lint pass, typecheck pass.

Evidence: the comment sits after the blank line, directly above `let kept`, the first line of the removal step it explains. It says why the removal step matches notes by identity, a constraint no line of code shows: two notes can share a title. `kept` sits next to the loop that reads it. A comment such as `// Remove stale notes` would only name the step, which the code beside it already says.

```swift
/// Replaces the notes in a store with the notes from a backup.
///
/// - Parameters:
///   - store: The store whose notes are replaced.
///   - backup: The notes to restore.
func restore(_ store: NoteStore, from backup: [Note]) {
    for note in backup {
        store.insert(note)
    }

    // Two notes can share a title, so only an identity tells whether the backup holds a note.
    let kept = Set(backup.map(\.id))
    for note in store.allNotes() where !kept.contains(note.id) {
        store.remove(note)
    }
}
```

## L10. POSITIVE: `defer` directly after the line it undoes

Placement: local package. Checks: format pass, lint pass, typecheck pass, on the complete `NoteImporter`.

Excerpt: the `importPickedFile(at:into:)` member of `NoteImporter`. The rest of the type is as in L1, which supplies `importNotes(from:into:)`.

Evidence: the guard starts access to the file and the `defer` ends it, so the two statements form one step, "gain access to the file", with the `defer` on the line after the guard. A reader sees the release beside the acquisition and does not search for it. The `defer` body sits on its own lines like every other body; the formatting command puts it there (`layout_body_lines`).

```swift
    /// Imports a file the person picked outside the app's sandbox.
    ///
    /// Access to the file lasts until this returns.
    ///
    /// - Parameters:
    ///   - url: The security-scoped URL from the file picker.
    ///   - store: The store that receives the notes.
    /// - Returns: The number of notes inserted; `.failure(.unreadable)` when the system refuses
    ///   access to the file or the file cannot be read, or `.failure(.empty)` when it holds no notes.
    func importPickedFile(at url: URL, into store: NoteStore) -> Result<Int, ImportError> {
        guard url.startAccessingSecurityScopedResource() else {
            return .failure(.unreadable)
        }
        defer {
            url.stopAccessingSecurityScopedResource()
        }

        return importNotes(from: url, into: store)
    }
```

## L11. NEGATIVE: `defer` set apart from the line it undoes

Placement: local package. Checks: format pass, lint pass, typecheck pass, on the complete `NoteImporter`. The defect is a judgment rule that no tool sees.

Excerpt: the same member as L10, without its doc comment, which is L10's. Only one blank line differs from L10.

Evidence: the blank line between the guard and the `defer` makes the `defer` read as a step of its own, so the step that starts access no longer shows that access ends. The gap also invites a later edit to put a statement there, and a statement that returns early from that spot leaves access open. A spacing tool that adds blank lines around every `guard` and `defer` produces this layout (SKILL.md section 1).

```swift
    func importPickedFile(at url: URL, into store: NoteStore) -> Result<Int, ImportError> {
        guard url.startAccessingSecurityScopedResource() else {
            return .failure(.unreadable)
        }

        defer {
            url.stopAccessingSecurityScopedResource()
        }

        return importNotes(from: url, into: store)
    }
```

## L12. POSITIVE: view content grouped by meaning

Placement: app target. Checks: format pass, lint pass, typecheck pass (with `-default-isolation MainActor`, macOS). `Note` comes from the package module `NotesKit`.

Evidence: the title and the edit day form the row's header, so they sit together. The start of the note's text is a second group, after a blank line. The groups follow what a person sees in the row, not the view types. The formatting command wraps the view-builder closures but places no blank line in them, so these blank lines are judgment only. The edit day's format is one initializer, `Date.FormatStyle(date: .abbreviated, time: .omitted)`, so the `Text` and its arguments stay on one line, and only its modifiers go below it.

```swift
import NotesKit
import SwiftUI

/// A row in the note list: the title and the day of the last edit, then the start of the note's text.
struct NoteRow: View {
    /// The note the row shows.
    let note: Note

    /// The title and edit day as one header, then up to two lines of text, read as one element.
    var body: some View {
        VStack(alignment: .leading) {
            Text(note.title.text)
                .font(.headline)
            Text(note.editedAt, format: Date.FormatStyle(date: .abbreviated, time: .omitted))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(note.text)
                .lineLimit(2)
        }
        .accessibilityElement(children: .combine)
    }
}
```

## L13. NEGATIVE: a step with an honest name left nested inside its function

Placement: local package. Checks: format pass, lint pass, typecheck pass. The defect is a judgment rule that no tool sees.

Evidence: each step is laid out correctly, and the 25-line body fits on a screen. This template's lint limit, `function_body_length` at 40 lines, does not flag it either: the limit is a ceiling, not the test. The defect is that the loop body is a step with an honest name, "parse one line into a note", with its own split, checks and three locals, nested inside the loop. A reader must read all of it to learn what `restore` does. L14 moves it into a function named for the step.

```swift
import Foundation

/// The backup file format, which holds one note per line: an identity, a tab, then a title.
enum Backup {
    /// Restores the notes in a backup file into a store.
    ///
    /// Empty lines are skipped. Surrounding whitespace is trimmed from each title, which
    /// ``NoteTitle/parse(_:)`` then checks. Each restored note replaces any note in the store
    /// with the same identity. A backup line holds only an identity and a title, so a replaced
    /// note loses its text, edit moment and sync state.
    ///
    /// - Parameters:
    ///   - data: The contents of the backup file.
    ///   - store: The store that receives the notes.
    /// - Returns: The number of notes restored; `.failure(.notText)` when the file is not UTF-8
    ///   text, `.failure(.malformedLine(_:))` with the first line that is not a note, or
    ///   `.failure(.empty)` when the file holds no notes. A failure restores nothing.
    static func restore(from data: Data, into store: NoteStore) -> Result<Int, BackupError> {
        guard let text = String(data: data, encoding: .utf8) else {
            return .failure(.notText)
        }

        var notes: [Note] = []
        for line in text.split(whereSeparator: \.isNewline) {
            let fields = line.split(separator: "\t", maxSplits: 1)
            guard fields.count == 2,
                  let id = UUID(uuidString: String(fields[0])),
                  case let .success(title) = NoteTitle.parse(String(fields[1]))
            else {
                return .failure(.malformedLine(String(line)))
            }

            notes.append(Note(id: id, title: title))
        }
        if notes.isEmpty {
            return .failure(.empty)
        }

        for note in notes {
            store.insert(note)
        }

        return .success(notes.count)
    }
}
```

## L14. POSITIVE: a short caller that reads as a list of small named functions

Placement: local package. Checks: format pass, lint pass, typecheck pass.

Evidence: parsing one line is the nested step L13 left inline, with an honest name and its own split, checks and locals, so it moves into `parseNote(fromLine:)` (SKILL.md section 4). The steps around it become functions too, so `restore` only orchestrates while each helper carries out one operation: decoding bytes, splitting the text into lines, or writing to the store (swift-domain-contracts, one conceptual level per function). L1 keeps its short steps inline because each already calls a domain operation. `restore` reads as its steps: decode the text, parse the notes, insert them. Each helper is laid out by the same rules: `parseNotes(in:)` keeps the empty check with the loop it checks, and `parseNote(fromLine:)` checks its line in one guard. Each helper takes only the values its step needs, and each one that can fail returns a `Result` with the typed error, so `parseNotes(in:)` forwards the failure `parseNote(fromLine:)` reports.

```swift
import Foundation

/// The backup file format, which holds one note per line: an identity, a tab, then a title.
enum Backup {
    /// Restores the notes in a backup file into a store.
    ///
    /// Empty lines are skipped. Each restored note replaces any note in the store with the same
    /// identity. A backup line holds only an identity and a title, so a replaced note loses its
    /// text, edit moment and sync state.
    ///
    /// - Parameters:
    ///   - data: The contents of the backup file.
    ///   - store: The store that receives the notes.
    /// - Returns: The number of notes restored; `.failure(.notText)` when the file is not UTF-8
    ///   text, `.failure(.malformedLine(_:))` with the first line that is not a note, or
    ///   `.failure(.empty)` when the file holds no notes. A failure restores nothing.
    static func restore(from data: Data, into store: NoteStore) -> Result<Int, BackupError> {
        decodeText(of: data)
            .flatMap(parseNotes(in:))
            .map {
                insert($0, into: store)
            }
    }

    /// Decodes the contents of a backup file as UTF-8 text.
    ///
    /// - Parameter data: The contents of the backup file.
    /// - Returns: The text, or `.failure(.notText)` when the contents are not UTF-8.
    private static func decodeText(of data: Data) -> Result<String, BackupError> {
        guard let text = String(data: data, encoding: .utf8) else {
            return .failure(.notText)
        }

        return .success(text)
    }

    /// Parses every line of a backup into a note.
    ///
    /// Empty lines are skipped.
    ///
    /// - Parameter text: The text of the backup file.
    /// - Returns: The notes in file order; `.failure(.malformedLine(_:))` with the first line that
    ///   is not a note, or `.failure(.empty)` when the text holds no notes.
    private static func parseNotes(in text: String) -> Result<[Note], BackupError> {
        var notes: [Note] = []
        for line in text.split(whereSeparator: \.isNewline) {
            switch parseNote(fromLine: line) {
            case let .success(note):
                notes.append(note)
            case let .failure(error):
                return .failure(error)
            }
        }
        if notes.isEmpty {
            return .failure(.empty)
        }

        return .success(notes)
    }

    /// Parses one line of a backup into a note.
    ///
    /// Surrounding whitespace is trimmed from the title, which ``NoteTitle/parse(_:)`` then checks.
    ///
    /// - Parameter line: A line of the backup file that is not empty.
    /// - Returns: The note, or `.failure(.malformedLine(_:))` with the line when it is not a UUID,
    ///   a tab, then a title that ``NoteTitle/parse(_:)`` accepts.
    private static func parseNote(fromLine line: Substring) -> Result<Note, BackupError> {
        let fields = line.split(separator: "\t", maxSplits: 1)
        guard fields.count == 2,
              let id = UUID(uuidString: String(fields[0])),
              case let .success(title) = NoteTitle.parse(String(fields[1]))
        else {
            return .failure(.malformedLine(String(line)))
        }

        return .success(Note(id: id, title: title))
    }

    /// Inserts notes into a store in file order.
    ///
    /// - Parameters:
    ///   - notes: The parsed notes.
    ///   - store: The store that receives them.
    /// - Returns: The number of notes inserted.
    private static func insert(_ notes: [Note], into store: NoteStore) -> Int {
        for note in notes {
            store.insert(note)
        }

        return notes.count
    }
}
```

## L15. POSITIVE: each check sits with the action it checks

Placement: the package's test target. Checks: format pass, lint pass with the test child profile added, typecheck pass, in one module with L14's `Backup`.

Evidence: setup creates an empty store and a fixed identity in one step. The `#require` checks the identity that setup creates, so it stays in the setup step. Each restore is an action, and the two `#expect` checks of it, first its result and then the store, sit directly after it, in the same step, as `guard let data` sits after the read it checks in L1. The blank line before the second restore starts the next action's step. A blank line between `let first` and its checks would set them apart as a step of their own, though they only confirm the line above them. A formatting command that adds a blank line between a `let` line and the line after it splits each action from its checks; keep its output and report the conflict (SKILL.md section 1).

```swift
import Foundation
import Testing

struct BackupTests {
    @Test func `restoring a backup replaces the stored note that has the same identity`() throws {
        let store = NoteStore()
        let id = try #require(UUID(uuidString: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F"))

        let first = Backup.restore(from: Data("\(id.uuidString)\tGroceries".utf8), into: store)
        #expect(first == .success(1))
        #expect(
            store
                .allNotes()
                .map(\.title.text) == ["Groceries"],
        )

        let second = Backup.restore(from: Data("\(id.uuidString)\tShopping".utf8), into: store)
        #expect(second == .success(1))
        #expect(
            store
                .allNotes()
                .map(\.title.text) == ["Shopping"],
        )
    }
}
```

## L16. POSITIVE: chained calls one per line

Placement: an app-target view, then a test in the package's test target. Checks: format pass, lint pass, typecheck pass for each block: the view with `-default-isolation MainActor`, macOS, and the test with the test child profile added, in one module with L9's `restore(_:from:)`.

Evidence: in SwiftUI view code the formatting command counts a view with any modifier as a chain (`layout_chain_lines`), so the second `Text` puts even its one modifier, `.foregroundStyle(.secondary)`, on its own line, and the `VStack`'s `.font(.footnote)` sits on its own line after the closing brace. The first `Text` has no modifier, so it stays on one line. In the test, the check calls `.allNotes()`, `.map(_:)` and `.sorted()` on the variable `store`, so `store` sits alone on the first line and each call gets its own line; `sorted()` makes the check independent of the order `allNotes()` returns, and the trailing comma after the comparison is the formatting command's. Each `try NoteTitle.parse(...).get()` stays on one line: `NoteTitle.parse(_:)` is a type's static call, which stays with the start, and a final argument-free `.get()` does not count. These splits are the formatting command's, and it reports each of L17's chains. The test's steps follow L15: setup is one step, and the `#expect` sits directly after the restore it checks.

```swift
import SwiftUI

/// The footer under the note list: how many notes wait to sync, then when the last sync ended.
struct SyncFooter: View {
    /// The number of notes the sync service does not hold yet.
    let unsent: Int

    /// The moment the last sync ended.
    let lastSync: Date

    /// The count, then the time of the last sync in the secondary style, both in the footnote style.
    var body: some View {
        VStack {
            Text("\(unsent) waiting to sync", comment: "%lld: the number of unsent notes.")
            Text("Last synced \(lastSync, format: .dateTime)", comment: "%@: the date and time of the last sync.")
                .foregroundStyle(.secondary)
        }
        .font(.footnote)
    }
}
```

```swift
import Foundation
import Testing

struct RestoreTests {
    @Test func `restoring a backup removes the stored notes that the backup does not hold`() throws {
        let store = NoteStore()
        let stale = try NoteTitle.parse("Old list").get()
        store.insert(Note(id: UUID(), title: stale))
        let groceries = try NoteTitle.parse("Groceries").get()
        let errands = try NoteTitle.parse("Errands").get()

        restore(store, from: [Note(id: UUID(), title: groceries), Note(id: UUID(), title: errands)])
        #expect(
            store
                .allNotes()
                .map(\.title.text)
                .sorted() == ["Errands", "Groceries"],
        )
    }
}
```

## L17. NEGATIVE: chained calls on one line

Placement: the same two blocks as L16. Checks: format pass, lint pass, typecheck pass, as for L16. Layout rules: expected failure on the labeled axis, `layout_chain_lines` at each of the three chains.

Evidence: only the chains differ from L16. The second `Text` and its modifier share one line, `.font(.footnote)` follows the `VStack`'s closing brace, and the check runs `.allNotes()`, `.map(_:)` and `.sorted()` on one line. A reader must scan each line to its end to find the modifiers and transforms, and a modifier added later lands at the end of a line that is already long. The formatting command reports all three (`layout_chain_lines`); SwiftFormat alone accepts them. The `.get()` lines are the same as in L16 and draw no finding, because `NoteTitle.parse(_:)` stays with its start and a final argument-free `.get()` does not count.

```swift
import SwiftUI

/// The footer under the note list: how many notes wait to sync, then when the last sync ended.
struct SyncFooter: View {
    /// The number of notes the sync service does not hold yet.
    let unsent: Int

    /// The moment the last sync ended.
    let lastSync: Date

    /// The count, then the time of the last sync in the secondary style, both in the footnote style.
    var body: some View {
        VStack {
            Text("\(unsent) waiting to sync", comment: "%lld: the number of unsent notes.")
            Text("Last synced \(lastSync, format: .dateTime)", comment: "%@: the date and time of the last sync.").foregroundStyle(.secondary)
        }.font(.footnote)
    }
}
```

```swift
import Foundation
import Testing

struct RestoreTests {
    @Test func `restoring a backup removes the stored notes that the backup does not hold`() throws {
        let store = NoteStore()
        let stale = try NoteTitle.parse("Old list").get()
        store.insert(Note(id: UUID(), title: stale))
        let groceries = try NoteTitle.parse("Groceries").get()
        let errands = try NoteTitle.parse("Errands").get()

        restore(store, from: [Note(id: UUID(), title: groceries), Note(id: UUID(), title: errands)])
        #expect(store.allNotes().map(\.title.text).sorted() == ["Errands", "Groceries"])
    }
}
```

## L18. POSITIVE: a closure's result bound with `let` before its guard

Placement: local package. Checks: format pass, lint pass, typecheck pass.

Evidence: no `guard` condition holds a closure. In `noteForLink(to:in:)`, the lookup `notes.first { ... }` is bound to `note` directly above the `guard let note` that checks it, so the lookup and its check form one step, "find the note". In the loop of `notesToAdd(from:comparedWith:)`, the cheap check `!note.text.isEmpty` is a guard of its own and runs first, so the scan through `stored` runs only for a note with text. Binding the scan with `let` above both guards would run it for every note; folding both checks into one guard would put the closure in its condition, as in L19. The two guards and the `let` between them stay together as one step, "skip a note that adds nothing", and the blank line before `added.append(note)` starts the next step.

```swift
import Foundation

/// Finds the note that a link to a note opens.
///
/// - Parameters:
///   - id: The identity the link names.
///   - notes: Every note in the store.
/// - Returns: The note, or `.failure(.unknownNote)` when no note has the identity, such as after
///   the note was deleted.
func noteForLink(to id: UUID, in notes: [Note]) -> Result<Note, LinkError> {
    let note = notes.first {
        $0.id == id
    }
    guard let note else {
        return .failure(.unknownNote)
    }

    return .success(note)
}

/// Picks the imported notes that add something to a store.
///
/// An imported note is skipped when it has no text, or when a stored note already holds the same
/// text. Imported notes are not compared with each other.
///
/// - Parameters:
///   - imported: The notes another app exported.
///   - stored: The notes the store holds before the import.
/// - Returns: The imported notes to insert, in import order.
func notesToAdd(from imported: [Note], comparedWith stored: [Note]) -> [Note] {
    var added: [Note] = []
    for note in imported {
        guard !note.text.isEmpty else {
            continue
        }
        let duplicate = stored.contains {
            $0.text == note.text
        }
        guard !duplicate else {
            continue
        }

        added.append(note)
    }

    return added
}
```

## L19. NEGATIVE: closures inside guard conditions

Placement: local package. Checks: format pass, lint pass, typecheck pass. Layout rules: expected failure on the labeled axis, `layout_condition_closure` at the closure in each guard.

Evidence: only the guards differ from L18. Each closure sits inside a guard condition, and a condition cannot hold a trailing closure, so both calls take a `where:` label. The formatting command wraps each closure body, which ends the condition with `}) else {`: a reader must read through the closure to find where the condition stops and the `else` begins, and in the loop the cheap check and the scan share one line. The combined guard still runs `!note.text.isEmpty` first, because a condition's clauses run in order, so the defect is how the code reads, not what it does. The formatting command reports each closure (`layout_condition_closure`) but does not move it, because moving it can change what runs; SwiftFormat, SwiftLint and the typecheck all pass.

```swift
import Foundation

/// Finds the note that a link to a note opens.
///
/// - Parameters:
///   - id: The identity the link names.
///   - notes: Every note in the store.
/// - Returns: The note, or `.failure(.unknownNote)` when no note has the identity, such as after
///   the note was deleted.
func noteForLink(to id: UUID, in notes: [Note]) -> Result<Note, LinkError> {
    guard let note = notes.first(where: {
        $0.id == id
    }) else {
        return .failure(.unknownNote)
    }

    return .success(note)
}

/// Picks the imported notes that add something to a store.
///
/// An imported note is skipped when it has no text, or when a stored note already holds the same
/// text. Imported notes are not compared with each other.
///
/// - Parameters:
///   - imported: The notes another app exported.
///   - stored: The notes the store holds before the import.
/// - Returns: The imported notes to insert, in import order.
func notesToAdd(from imported: [Note], comparedWith stored: [Note]) -> [Note] {
    var added: [Note] = []
    for note in imported {
        guard !note.text.isEmpty, !stored.contains(where: {
            $0.text == note.text
        }) else {
            continue
        }

        added.append(note)
    }

    return added
}
```
