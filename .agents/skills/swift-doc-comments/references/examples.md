# Doc comments: labeled examples

Read before writing or reviewing a doc comment. Every example passes the formatter, the linter and the typechecker, because `missing_docs` is satisfied by any comment. Each label therefore rests on whether the comment tells a reader something the declaration does not.

Every example was extracted to its own Swift file and run from the repository root through the pinned SwiftFormat (`--lint --config .swiftformat`), the pinned SwiftLint (`lint --strict --config .swiftlint.yml`) and `xcrun swiftc -typecheck -swift-version 6 -strict-memory-safety -warnings-as-errors` with the template's four upcoming features. All are package code, so `-default-isolation MainActor` is off; the one app-target probe, in Example 9, is the exception its checks line names. The examples follow swift-code-layout and pass the formatter.

## 1. NEGATIVE: polished restatement

Placement: local package. Checks: format pass, lint pass, typecheck pass. The defect is a judgment rule that no tool sees.

Evidence: every comment turns an identifier into a sentence, and the lint passes. Nothing states what the title may contain, what `rename` does to its input, or that it trims. A reader learns only what the signature already says.

```swift
import Foundation

/// A book on the reading list.
struct Book {
    /// The title.
    private(set) var title: String

    /// Renames the book.
    ///
    /// - Parameter newTitle: The new title.
    mutating func rename(to newTitle: String) {
        title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
```

## 2. POSITIVE: state what the type does not show

Placement: local package. Checks: format pass, lint pass, typecheck pass. A probe file in the same module that calls `Book(title: "")` fails the typecheck: "'Book' initializer is inaccessible due to 'private' protection level"; a control file that calls `Book.parse(title:)` passes.

Evidence: the invariant (trimmed, never empty) is written once, at the property that owns it, and the type keeps it. The `private init` in the type body removes the memberwise initializer, so every book comes from `parse(title:)`, whose documentation states its normalization and its failure for text that trims to nothing. `rename(to:)` goes through the same parse, so the two paths cannot drift. Without the body init, `Book(title: "")` compiles anywhere in the module, and the property's comment states an invariant the type does not keep (swift-domain-contracts, "Encode only invariants the design can keep").

```swift
import Foundation

/// Why the reader's text cannot be a book's title.
enum TitleError: Error {
    /// The text is empty or only whitespace; the caller asks the reader for a title.
    case empty
}

/// A book on the reading list.
struct Book {
    /// The title the reader entered, trimmed of surrounding whitespace and never empty.
    private(set) var title: String

    /// Creates a book from a title that is already trimmed and not empty.
    ///
    /// - Parameter title: A trimmed, non-empty title.
    private init(title: String) {
        self.title = title
    }

    /// Parses the title the reader entered into a book.
    ///
    /// Surrounding whitespace and newlines are trimmed before the title is checked.
    ///
    /// - Parameter title: The text the reader entered.
    /// - Returns: The book, or `.failure(.empty)` when the text is empty after trimming.
    static func parse(title: String) -> Result<Book, TitleError> {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure(.empty)
        }

        return .success(Book(title: trimmed))
    }

    /// Renames the book to the title the reader entered.
    ///
    /// The text is trimmed as ``parse(title:)`` trims it.
    ///
    /// - Parameter newTitle: The text the reader entered.
    /// - Returns: `.failure(.empty)` when the text is empty after trimming; the title is then unchanged.
    mutating func rename(to newTitle: String) -> Result<Void, TitleError> {
        Book.parse(title: newTitle).map {
            title = $0.title
        }
    }
}
```

## 3. NEGATIVE: Result failures live in Returns

Placement: local package. Checks: format pass, lint pass, typecheck pass. The defect is a judgment rule that no tool sees.

Evidence: wrong only in its documentation; the code is Example 4's. The function returns a `Result` and never throws, so `- Throws:` documents nothing. The failure cases and their triggers appear nowhere, so a caller cannot tell when `.notFound` or `.cancelled` comes back. The enum cases `.notFound` and `.cancelled` also say nothing a caller can act on.

```swift
/// Why a lookup produced no book.
enum LookupError: Error {
    /// The lookup was cancelled.
    case cancelled
    /// No book has the identity.
    case notFound
}

/// A book on the reading list.
struct Book: Identifiable {
    /// The identity assigned when the book was added.
    let id: Int
}

/// The books on the reading list.
struct Shelf {
    /// The books, in the order they were added.
    let books: [Book]

    /// Finds the book with the given identity.
    ///
    /// - Parameter id: The identity of the book to find.
    /// - Throws: The error.
    func book(id: Book.ID) async -> Result<Book, LookupError> {
        guard !Task.isCancelled else {
            return .failure(.cancelled)
        }
        let book = books.first {
            $0.id == id
        }
        guard let book else {
            return .failure(.notFound)
        }

        return .success(book)
    }
}
```

## 4. POSITIVE: Result failures live in Returns

Placement: local package. Checks: format pass, lint pass, typecheck pass.

Evidence: `- Returns:` names each failure and its trigger, and each error case says what the caller does with it. There is no `- Throws:`.

```swift
/// Why a lookup produced no book.
enum LookupError: Error {
    /// The lookup was cancelled; the caller has moved on and shows nothing.
    case cancelled
    /// No book has the identity; the caller removes any link to it.
    case notFound
}

/// A book on the reading list.
struct Book: Identifiable {
    /// The identity assigned when the book was added.
    let id: Int
}

/// The books on the reading list.
struct Shelf {
    /// The books, in the order they were added.
    let books: [Book]

    /// Finds the book with the given identity.
    ///
    /// - Parameter id: The identity assigned when the book was added.
    /// - Returns: The book, or `.failure(.notFound)` when it was removed. A cancelled call returns `.failure(.cancelled)`.
    func book(id: Book.ID) async -> Result<Book, LookupError> {
        guard !Task.isCancelled else {
            return .failure(.cancelled)
        }
        let book = books.first {
            $0.id == id
        }
        guard let book else {
            return .failure(.notFound)
        }

        return .success(book)
    }
}
```

## 5. NEGATIVE: a witness documents this type

Placement: local package. Checks: format pass, lint pass, typecheck pass. The defect is a judgment rule that no tool sees.

Evidence: wrong only in its documentation; the code is Example 6's. The comment on `<` copies the `Comparable` requirement. It is true of every conformer and says nothing about how books order: by which property, whether case matters, or whether the order agrees with `==`.

```swift
/// A book on the reading list.
struct Book: Comparable {
    /// The title the reader entered.
    let title: String

    /// Returns a Boolean value indicating whether the value of the first argument is less than that of the second argument.
    ///
    /// - Parameters:
    ///   - lhs: A value to compare.
    ///   - rhs: Another value to compare.
    /// - Returns: `true` if `lhs` is less than `rhs`; otherwise, `false`.
    static func < (lhs: Book, rhs: Book) -> Bool {
        lhs.title < rhs.title
    }
}
```

## 6. POSITIVE: a witness documents this type

Placement: local package. Checks: format pass, lint pass, typecheck pass.

Evidence: the comment states this type's ordering, so a caller can predict the sort: by exact title, with case significant, the same in every locale, and in agreement with `==`. The witness compares titles with `String`'s `<`, and `String`'s `==` and relational operators both compare the Unicode canonical representation (Apple, [`String`](https://developer.apple.com/documentation/swift/string), "Modifying and Comparing Strings"); the synthesized `==` compares nothing else. For any two books, exactly one of `==`, `<` and `>` therefore holds, as `Comparable` requires. A case-insensitive comparison would tie "Apple" with "apple" while `==` tells them apart, and a localized one reads the current locale, a hidden input in package code (swift-domain-contracts, "Honest signatures").

```swift
/// A book on the reading list.
struct Book: Comparable {
    /// The title the reader entered.
    let title: String

    /// Orders books by exact title, the same key equality compares, so the order is the same in every locale.
    ///
    /// Case is significant: "Apple" and "apple" are unequal books, and one of them always sorts first.
    ///
    /// - Parameters:
    ///   - lhs: The book that may come first.
    ///   - rhs: The book that may come after it.
    /// - Returns: `true` when `lhs.title` sorts before `rhs.title` as `String` values.
    static func < (lhs: Book, rhs: Book) -> Bool {
        lhs.title < rhs.title
    }
}
```

## 7. POSITIVE: a caller contract is a Precondition in the API doc

Placement: local package. Checks: format pass, lint pass, typecheck pass.

Evidence: callers cannot read the trap, so the contract `index` is a position on the shelf is a `- Precondition:` line in the method's doc, and the `precondition` message names the same contract. An internal invariant, such as `Dictionary(uniqueKeysWithValues:)` keys, takes an adjacent `//` comment instead: see `swift-isolation`, `references/unchecked-invariants.md`, Example 1.

```swift
/// The books on the reading list.
struct Shelf {
    /// The books, in reading order.
    private(set) var books: [String]

    /// Moves a book to the front of the reading order.
    ///
    /// - Parameter index: The position of the book to move.
    /// - Precondition: `index` is a valid position in ``books``.
    mutating func promote(at index: Int) {
        precondition(books.indices.contains(index), "promote(at:) needs a position on the shelf")

        books.insert(books.remove(at: index), at: 0)
    }
}
```

## 8. NEGATIVE: a caller contract is a Precondition in the API doc

Placement: local package. Checks: format pass, lint pass, typecheck pass. The defect is a judgment rule that no tool sees.

Evidence: the method traps on a bad index and its doc never says so, so a caller learns the contract from a crash. The adjacent `// Check.` names no invariant a reviewer could verify.

```swift
/// The books on the reading list.
struct Shelf {
    /// The books, in reading order.
    private(set) var books: [String]

    /// Moves a book to the front of the reading order.
    ///
    /// - Parameter index: The position of the book to move.
    mutating func promote(at index: Int) {
        // Check.
        precondition(books.indices.contains(index), "promote(at:) needs a position on the shelf")

        books.insert(books.remove(at: index), at: 0)
    }
}
```

## 9. POSITIVE: an @Observable property documents meaning, not tracking

Placement: local package. Checks: format pass, lint pass, typecheck pass. A probe view in an app-target file, typechecked with `-default-isolation MainActor` against a module emitted from this file, holds the list in `@State`, reads `isSaved` and calls `append(_:)`; it passes.

Evidence: each property comment states the domain meaning and who writes it, and `isSaved` says what a change means to a view: when it turns false, the list holds edits its stored copy lacks. Both properties are tracked, so a view that reads either one re-renders when it changes, and neither comment explains observation. `@ObservationIgnored` disables that tracking (SE-0395), so a property any view reads never carries it. The model is a `public` class with a `public init`, as swiftui-views' "Model ownership" requires, so views in the app target can create and read it.

```swift
import Observation

/// The reading list a view shows.
@MainActor
@Observable
public final class ReadingList {
    /// The titles in reading order; only the list's own methods change them.
    public private(set) var titles: [String]
    /// Whether the stored copy holds the current titles, so a view can warn about edits that are not stored yet; only the list's own methods change it.
    public private(set) var isSaved: Bool

    /// Creates a reading list that matches its stored copy.
    ///
    /// - Parameter titles: The stored titles, in reading order.
    public init(titles: [String]) {
        self.titles = titles
        isSaved = true
    }

    /// Appends a title to the end of the reading order and marks the list unsaved.
    ///
    /// - Parameter title: The title to append.
    public func append(_ title: String) {
        titles.append(title)
        isSaved = false
    }
}
```

## 10. NEGATIVE: an @Observable property documents meaning, not tracking

Placement: local package. Checks: format pass, lint pass, typecheck pass. The defect is a judgment rule that no tool sees.

Evidence: the macro generates the tracking, and "tracked by the Observation framework" is true of every tracked property in the class. The property's comment never says who may write `titles` or what order they hold.

```swift
import Observation

/// The reading list a view shows.
@MainActor
@Observable
public final class ReadingList {
    /// The titles; tracked by the Observation framework, so changes cause views to update.
    public private(set) var titles: [String]

    /// Creates a reading list with the given titles.
    ///
    /// - Parameter titles: The titles the list starts with.
    public init(titles: [String]) {
        self.titles = titles
    }

    /// Appends a title to the end of the reading order.
    ///
    /// - Parameter title: The title to append.
    public func append(_ title: String) {
        titles.append(title)
    }
}
```

## 11. POSITIVE: a constraint as a present-tense causal chain, with its source

Placement: local package. Checks: format pass, lint pass, typecheck pass.

Evidence: the comment on `url` states the invariant (the file holds the previous list or the new one), why the atomic write provides it, and links the Apple documentation beside the code that depends on it. Nothing needs the history of the code to be understood.

```swift
import Foundation

/// A reading list stored in its own file inside the app's support directory.
struct ListStore {
    /// The file that holds the list.
    ///
    /// The list is rewritten whole on every save, and a reader that finds a partly written file cannot tell it from a corrupt one. The write therefore goes through an atomic replace: the file holds either the previous list or the new one, never a mix. See [Data.WritingOptions.atomic](https://developer.apple.com/documentation/foundation/nsdata/writingoptions/atomic).
    let url: URL

    /// Replaces the stored list with the given data.
    ///
    /// - Parameter data: The encoded list.
    /// - Returns: `.failure(.writeFailed)` when the file could not be replaced; the previous list is still stored.
    func save(_ data: Data) -> Result<Void, SaveError> {
        Result {
            try data.write(to: url, options: .atomic)
        }.mapError { _ in
            .writeFailed
        }
    }
}

/// Why a save did not complete.
enum SaveError: Error {
    /// The file could not be replaced, and the previous list is unchanged.
    case writeFailed
}
```

## 12. NEGATIVE: a constraint as a present-tense causal chain, with its source

Placement: local package. Checks: format pass, lint pass, typecheck pass. The defect is a judgment rule that no tool sees.

Evidence: the comment on `url` is understood only by someone who knows the old write and the reports it caused ("old", "this fixes"). It names no invariant, so a maintainer cannot tell whether removing `.atomic` is safe.

```swift
import Foundation

/// A reading list stored in its own file inside the app's support directory.
struct ListStore {
    /// The file that holds the list.
    ///
    /// Replaces the old plain write that left half-written files after crashes; this fixes the corrupt-list reports by writing atomically.
    let url: URL

    /// Replaces the stored list with the given data.
    ///
    /// - Parameter data: The encoded list.
    /// - Returns: `.failure(.writeFailed)` when the file could not be replaced; the previous list is still stored.
    func save(_ data: Data) -> Result<Void, SaveError> {
        Result {
            try data.write(to: url, options: .atomic)
        }.mapError { _ in
            .writeFailed
        }
    }
}

/// Why a save did not complete.
enum SaveError: Error {
    /// The file could not be replaced, and the previous list is unchanged.
    case writeFailed
}
```

## 13. NEGATIVE: links stay out of summaries

Placement: local package. Checks: format pass, lint pass, typecheck pass. The defect is a judgment rule that no tool sees.

Evidence: the summary names symbols in single backticks. Single backticks are code voice and do not navigate, and the summary shows alone in lists, where a symbol name tells the reader nothing about the unit. It also opens with `Uses`, not with what the method does.

```swift
/// A book on the reading list.
struct Book {
    /// The title the reader entered.
    private(set) var title: String

    /// Uses `Book` and `rename(to:)` to change the title.
    ///
    /// - Parameter newTitle: The title to apply.
    mutating func rename(to newTitle: String) {
        title = newTitle
    }
}
```

## 14. POSITIVE: links stay out of summaries

Placement: local package. Checks: format pass, lint pass, typecheck pass.

Evidence: the summary is plain text. The discussion uses double-backtick links, written relative to the enclosing context, to the symbols that change.

```swift
/// A book on the reading list.
struct Book {
    /// The title the reader entered.
    private(set) var title: String

    /// Changes the title of this book.
    ///
    /// ``Book/title`` holds the new value after the call, and ``Shelf/sorted()`` reflects it on its next call.
    ///
    /// - Parameter newTitle: The title to apply.
    mutating func rename(to newTitle: String) {
        title = newTitle
    }
}

/// The books on the reading list.
struct Shelf {
    /// The books, in the order they were added.
    let books: [Book]

    /// Returns the books ordered by title.
    func sorted() -> [Book] {
        books.sorted {
            $0.title < $1.title
        }
    }
}
```

## 15. POSITIVE: a valid reason for @ObservationIgnored

Placement: local package. Checks: format pass, lint pass, typecheck pass. Omitted surroundings: a stub `writeTitles(_:)` async function that returns `Result<Void, SaveError>`, declared only in the typechecked scratch file.

Evidence: `saveTask` is implementation state, not model state: it is the handle that lets a newer save cancel an older one, and no view body reads it, so tracking it would only register a dependency no view needs (a view re-runs only when a property its body reads changes: Apple, "Migrating from the Observable Object protocol to the Observable macro"). Its comment says that and what the handle is for. It is the only property here that carries `@ObservationIgnored` (SE-0395: it excludes a property from tracking); `titles` is what views read, so it stays tracked and its comment states meaning only. `save()` reports failure through `Result`, with each case and its trigger in `- Returns:` (rule 96ab9a8b).

```swift
import Observation

/// Why a save did not store the titles.
public enum SaveError: Error {
    /// A newer save replaced this one; the caller shows nothing.
    case cancelled
    /// The store refused the titles; the caller can offer a retry.
    case unwritable
}

/// The reading list a view shows.
@MainActor
@Observable
public final class ReadingList {
    /// The titles in reading order; only the list's own methods change them.
    public private(set) var titles: [String]

    /// The save in flight, kept so a newer save can cancel it.
    ///
    /// Implementation state, not model state: no view reads it, so tracking it would only register a dependency nothing needs.
    @ObservationIgnored private var saveTask: Task<Result<Void, SaveError>, Never>?

    /// Creates a reading list with the given titles.
    ///
    /// - Parameter titles: The stored titles, in reading order.
    public init(titles: [String]) {
        self.titles = titles
    }

    /// Stores the current titles and cancels any save still running.
    ///
    /// - Returns: `.success` once the titles are stored. `.failure(.unwritable)` when the store refused them; the list keeps its titles, so the caller can offer a retry. `.failure(.cancelled)` when a newer save replaced this one; the caller shows nothing.
    public func save() async -> Result<Void, SaveError> {
        saveTask?.cancel()

        let task = Task { [titles] in
            await writeTitles(titles)
        }
        saveTask = task

        return await task.value
    }
}
```
