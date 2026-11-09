# Labeled examples

Read this before writing a test for a model, a package API or an invariant type. For the checks, each block was cut at its first test-only declaration into two files of one module; the package source keeps every `import` but `Testing`, and the test code keeps them all. The package source above the cut was linted with the base configuration alone, as package source is; the test code below it was linted with the test child profile added. Both files ran through the pinned formatter and a Swift 6 typecheck. The checks cover tooling only; no test was run.

Contract for all: the package shape (logic in a `nonisolated` package), `Result` with a typed error for project APIs, no `@discardableResult`, strict memory safety, warnings as errors, Swift 6 language mode. `Testing` needs the platform's framework and the toolchain's `testing` macro plugin on the typecheck command line.

Omitted surroundings: in a real package the declarations above the cut live in package source files, and the rest in the package's test target, which imports the package's module with `@testable import`. Each example is shown in one block so it reads as one unit. `throws` appears only on tests that call `try`. `app-verification` holds the `#require`-an-optional, `Result`-case, `confirmation` and force-unwrap examples; this file does not repeat them.

## POSITIVE 1: pass the value, not a service

Evidence: `status(at:)` takes the `Date` it needs, so the test fixes the instant exactly and no clock, protocol or injected service exists. The one `Comment` is there because `status(at: deadline) == .expired` does not say that the deadline instant itself counts as expired; the other `#expect` needs none, because its captured expression already names the contract.

Checks: SwiftFormat lint pass; SwiftLint strict pass (package source with the base configuration alone, test code with the test child profile added); `swiftc -typecheck` under the strict flags pass, with `Testing` on the framework and plugin paths; the layout follows swift-code-layout.

```swift
import Foundation
import Testing

/// A signed-in session that ends at a fixed time.
public struct Session: Sendable {
    /// Whether the session still grants access.
    public enum Status: Equatable, Sendable {
        /// The deadline has not been reached.
        case active
        /// The deadline has been reached or passed.
        case expired
    }

    /// When the session ends.
    public let deadline: Date

    /// Creates a session that ends at the given deadline.
    public init(deadline: Date) {
        self.deadline = deadline
    }

    /// Returns the session's status at the given date; the deadline instant itself is expired.
    public func status(at date: Date) -> Status {
        date < deadline ? .active : .expired
    }
}

struct SessionTests {
    let deadline = Date(timeIntervalSince1970: 1000)

    @Test func `a session is active one second before its deadline`() {
        let session = Session(deadline: deadline)

        #expect(session.status(at: deadline.addingTimeInterval(-1)) == .active)
    }

    @Test func `a session is expired at its deadline`() {
        let session = Session(deadline: deadline)

        #expect(session.status(at: deadline) == .expired, "The deadline instant itself counts as expired.")
    }
}
```

## POSITIVE 2: an invariant type, and the path around its factory

Evidence: `Percentage` declares its `private init` in the type body and adopts no `Decodable`, so `make(_:)` is the only way to build one, and stored data reaches it only through `decodePercentage(from:)`, which decodes a plain `Int` and passes it to `make(_:)`. That design belongs to `swift-domain-contracts`, headings "Parse at boundaries and keep what you learn" and "Encode only invariants the design can keep". The tests are this skill's part: acceptance across the boundaries, refusal with the typed case that carries the value, and the decoding path. A stored `40` decodes unchanged, which proves the decoder reads a bare number, so the refusal of a stored `150` can come only from `make(_:)`.

Checks: SwiftFormat lint pass; SwiftLint strict pass (package source with the base configuration alone, test code with the test child profile added); `swiftc -typecheck` under the strict flags pass, with `Testing` on the framework and plugin paths; the layout follows swift-code-layout.

```swift
import Foundation
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

/// Why stored data is not a percentage.
public enum PercentageDecodingError: Error {
    /// The data is not a single JSON number, or the number is outside 0 through 100; reading it again will not help.
    case malformed
}

/// Decodes a percentage stored as a single JSON number.
///
/// The number goes through ``Percentage/make(_:)``, so stored data cannot hold a value outside 0 through 100.
///
/// - Parameter data: The stored JSON, such as `40`.
/// - Returns: The percentage, or ``PercentageDecodingError/malformed`` when the data is not a number or the number is
///   out of range.
public func decodePercentage(from data: Data) -> Result<Percentage, PercentageDecodingError> {
    Result(catching: {
        try JSONDecoder().decode(Int.self, from: data)
    })
    .mapError { _ in
        .malformed
    }
    .flatMap { number in
        Percentage.make(number).mapError { _ in
            .malformed
        }
    }
}

struct PercentageTests {
    @Test(arguments: [0, 1, 50, 100])
    func `a number within range is accepted unchanged`(number: Int) {
        guard case let .success(percentage) = Percentage.make(number) else {
            Issue.record("Percentage.make(\(number)) refused a number within 0 through 100.")

            return
        }
        #expect(percentage.value == number)
    }

    @Test(arguments: [-1, 101])
    func `a number outside the range is refused with its own value`(number: Int) {
        #expect(Percentage.make(number) == .failure(.outOfRange(number)))
    }

    @Test func `a stored number within range decodes unchanged`() {
        #expect(decodePercentage(from: Data("40".utf8)).map(\.value) == .success(40))
    }

    @Test func `decoding refuses a stored number that the factory refuses`() {
        #expect(decodePercentage(from: Data("150".utf8)) == .failure(.malformed))
    }
}
```

## POSITIVE 3: a consumer-owned seam, a faithful fake and a shared contract suite

Evidence: `NoteStore` is the one capability the note list needs, in domain terms, with typed failures. The fake is an `actor` (no `@unchecked Sendable`), and the same three contract tests run against the fake and against `DirectoryNoteStore` over a fresh temporary directory, so the fake cannot become a different system: it must refuse a duplicate title and report `.notFound` as the real store does. Setup is one helper that names its scratch directory, and the one dropped `Result` carries its reason.

Checks: SwiftFormat lint pass; SwiftLint strict pass (package source, `Note` through `DirectoryNoteStore`, with the base configuration alone, test code with the test child profile added); `swiftc -typecheck` under the strict flags pass, with `Testing` on the framework and plugin paths; the layout follows swift-code-layout.

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
    /// No note has this title.
    case notFound
    /// The storage could not be reached.
    case unavailable
}

/// The storage the note list needs: save a note once per title, and read it back.
public protocol NoteStore: Sendable {
    /// Saves a note and returns it, or fails when its title is taken.
    ///
    /// - Returns: The saved note, or `.duplicateTitle` when its title is taken, or `.unavailable` when the storage cannot be reached.
    func save(_ note: Note) async -> Result<Note, NoteStoreError>

    /// Returns the note saved under a title, or fails when there is none.
    ///
    /// - Returns: The note, or `.notFound` when no note has the title, or `.unavailable` when the storage cannot be reached.
    func note(titled title: String) async -> Result<Note, NoteStoreError>
}

/// Saves each note as a text file named after its title, in a directory the caller owns.
public struct DirectoryNoteStore: NoteStore {
    /// The directory that holds the files.
    public let directory: URL

    /// Creates a store over an existing directory; titles are plain names without slashes.
    public init(directory: URL) {
        self.directory = directory
    }

    /// Writes the note's file without replacing an existing one.
    public func save(_ note: Note) -> Result<Note, NoteStoreError> {
        Result {
            try Data(note.body.utf8).write(to: file(for: note.title), options: .withoutOverwriting)
        }
        .map {
            Note(title: note.title, body: note.body)
        }
        .mapError { error in
            (error as? CocoaError)?.code == .fileWriteFileExists ? .duplicateTitle : .unavailable
        }
    }

    /// Reads the note's file.
    public func note(titled title: String) -> Result<Note, NoteStoreError> {
        Result {
            try String(contentsOf: file(for: title), encoding: .utf8)
        }
        .map {
            Note(title: title, body: $0)
        }
        .mapError { error in
            (error as? CocoaError)?.code == .fileReadNoSuchFile ? .notFound : .unavailable
        }
    }

    /// Returns the location of a note's file inside the directory.
    ///
    /// - Parameter title: The note's title, a plain name without `/`.
    /// - Returns: The file named after `title`, with the `txt` extension.
    private func file(for title: String) -> URL {
        directory.appending(path: "\(title).txt")
    }
}

/// An in-memory store that holds the same promises as the directory store.
actor FakeNoteStore: NoteStore {
    private var notes: [String: Note] = [:]

    func save(_ note: Note) -> Result<Note, NoteStoreError> {
        guard notes[note.title] == nil else {
            return .failure(.duplicateTitle)
        }

        notes[note.title] = note

        return .success(note)
    }

    func note(titled title: String) -> Result<Note, NoteStoreError> {
        notes[title].map {
            .success($0)
        } ?? .failure(.notFound)
    }
}

enum StoreKind: CaseIterable, CustomTestStringConvertible {
    case fake
    case directory

    var testDescription: String {
        switch self {
        case .fake:
            "fake"
        case .directory:
            "directory"
        }
    }
}

/// Runs a body against a fresh store of the given kind; a directory store gets a new temporary folder.
func withStore(_ kind: StoreKind, run body: (any NoteStore) async -> Void) async {
    switch kind {
    case .fake:
        await body(FakeNoteStore())
    case .directory:
        let directory = FileManager.default.temporaryDirectory.appending(path: "NoteStoreTests-\(UUID().uuidString)")
        let creation = Result {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        }
        guard case .success = creation else {
            Issue.record("The test could not create its temporary directory \(directory.path).")

            return
        }

        await body(DirectoryNoteStore(directory: directory))

        // The folder is scratch that no assertion reads again, so a failed delete leaves only an empty temporary folder.
        _ = Result {
            try FileManager.default.removeItem(at: directory)
        }
    }
}

struct NoteStoreContractTests {
    @Test(arguments: StoreKind.allCases)
    func `a saved note is read back by its title`(kind: StoreKind) async {
        await withStore(kind) { store in
            let note = Note(title: "Groceries", body: "Milk")

            #expect(await store.save(note) == .success(note))
            #expect(await store.note(titled: "Groceries") == .success(note))
        }
    }

    @Test(arguments: StoreKind.allCases)
    func `saving a second note under a taken title is refused and keeps the first`(kind: StoreKind) async {
        await withStore(kind) { store in
            let first = Note(title: "Groceries", body: "Milk")

            #expect(await store.save(first) == .success(first))
            #expect(await store.save(Note(title: "Groceries", body: "Eggs")) == .failure(.duplicateTitle))
            #expect(await store.note(titled: "Groceries") == .success(first))
        }
    }

    @Test(arguments: StoreKind.allCases)
    func `reading a title that was never saved reports not found`(kind: StoreKind) async {
        await withStore(kind) { store in
            #expect(await store.note(titled: "Missing") == .failure(.notFound))
        }
    }
}
```

## POSITIVE 4: gate before reading an element

Evidence: `try #require(playlist.tracks.first)` stops the test when the list is empty, so the reads that follow never run against nothing. The `Comment` names the promise the bare expression does not: the count survives the rotation. A failed `#expect` continues, so it could not guard these reads.

Checks: SwiftFormat lint pass; SwiftLint strict pass (package source with the base configuration alone, test code with the test child profile added); `swiftc -typecheck` under the strict flags pass, with `Testing` on the framework and plugin paths; the layout follows swift-code-layout.

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
    @Test func `rotating moves the last track to the front`() throws {
        var playlist = Playlist(tracks: [Track(id: 1, title: "Intro"), Track(id: 2, title: "Outro")])

        playlist.rotate()
        let first = try #require(playlist.tracks.first, "A two-track playlist is still two tracks after rotating.")
        let last = try #require(playlist.tracks.last)
        #expect(first.title == "Outro")
        #expect(last.title == "Intro")
    }
}
```

## POSITIVE 5: paired cases with `zip`

Evidence: `zip` yields four pairs, and each pair fails alone under its own arguments. Two separate collections would run every minute count against every label (Negative 2).

Checks: SwiftFormat lint pass; SwiftLint strict pass (package source with the base configuration alone, test code with the test child profile added); `swiftc -typecheck` under the strict flags pass, with `Testing` on the framework and plugin paths; the layout follows swift-code-layout.

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
    @Test(arguments: zip([0, 45, 60, 90], ["0 min", "45 min", "1 h", "1 h 30 min"]))
    func `a length of time reads as minutes, then hours and minutes`(minutes: Int, expected: String) {
        #expect(DurationLabel.text(forMinutes: minutes) == expected)
    }
}
```
