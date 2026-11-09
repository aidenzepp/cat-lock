# ForEach identity: labeled examples

Read before you write or review a `ForEach`, or a `List`, `Table` or `OutlineGroup` built from a collection. The three examples are one minimal pair and its variant: they differ only in the `id:` key path.

How the examples were checked. Each code block is the complete file that was checked, unchanged. Every file passed the project's pinned SwiftFormat (`--lint --config .swiftformat`) and pinned SwiftLint (`lint --strict --config .swiftlint.yml`), and `xcrun swiftc -typecheck -swift-version 6 -strict-memory-safety -warnings-as-errors -default-isolation MainActor` (app-target flags) for a macOS target and again for an iOS target. The files import `ReadingListKit`, a module emitted unchanged from the package example in [observable-ownership.md](observable-ownership.md), where `Book` is `Identifiable` with an immutable `id`.

## POSITIVE: the element's id, with the offset as row data

Evidence: `id: \.element.id` identifies each row by `Book.id`, a `let` assigned once when the model creates the book, so a row keeps its identity, state and animation when books are inserted, removed or reordered. The offset is used only as displayed data, which Apple's guide calls fine (`swiftui-specialist-ref-foreach.md.packaged`, "`.enumerated()` is fine - the index just shouldn't be the id"). `enumerated()` of a random-access collection is itself random-access (SE-0459), so no `Array(...)` copy is needed. Checks: format pass, lint pass, typecheck pass (macOS and iOS).

```swift
import ReadingListKit
import SwiftUI

/// The reading list, numbered in reading order.
struct NumberedBookList: View {
    /// The books in reading order.
    let books: [Book]

    /// One row per book, in reading order.
    var body: some View {
        List(books.enumerated(), id: \.element.id) { offset, book in
            BookRow(position: offset + 1, title: book.title)
        }
    }
}

/// A row that shows a book's position and title.
struct BookRow: View {
    /// The book's one-based position in reading order.
    let position: Int
    /// The title the reader entered.
    let title: String

    /// The position, then the title.
    var body: some View {
        HStack {
            Text(position, format: .number)
                .foregroundStyle(.secondary)
            Text(title)
        }
    }
}
```

## NEGATIVE: the offset as the id

Evidence: `id: \.offset` makes the position the identity. After a book is inserted at the top, every id from that point on names a different book, so "SwiftUI sees 'the element at id 3 changed' rather than 'element B moved from 3 to 4', so row state resets and moves animate as replacements" (Apple, `swiftui-specialist-ref-foreach.md.packaged`, "Avoid collection indices as identity"). Checks: format pass, lint pass, typecheck pass. The defect is a judgment rule that no tool sees. Only the `id:` key path differs from the positive.

```swift
import ReadingListKit
import SwiftUI

/// The reading list, numbered in reading order.
struct NumberedBookList: View {
    /// The books in reading order.
    let books: [Book]

    /// One row per book, in reading order.
    var body: some View {
        List(books.enumerated(), id: \.offset) { offset, book in
            BookRow(position: offset + 1, title: book.title)
        }
    }
}

/// A row that shows a book's position and title.
struct BookRow: View {
    /// The book's one-based position in reading order.
    let position: Int
    /// The title the reader entered.
    let title: String

    /// The position, then the title.
    var body: some View {
        HStack {
            Text(position, format: .number)
                .foregroundStyle(.secondary)
            Text(title)
        }
    }
}
```

## NEGATIVE: editable content as the id

Evidence: `id: \.element.title` derives identity from content the reader can edit. Two books with the same title share an id, which breaks the rule that ids are unique within a `ForEach`, and editing a title changes the id, so SwiftUI "interprets it as 'the old element was removed and a new one inserted', which drops the row's state" (Apple, `swiftui-specialist-ref-foreach.md.packaged`, "Identity must outlive the view that renders the `ForEach`"). Checks: format pass, lint pass, typecheck pass. The defect is a judgment rule that no tool sees. Only the `id:` key path differs from the positive.

```swift
import ReadingListKit
import SwiftUI

/// The reading list, numbered in reading order.
struct NumberedBookList: View {
    /// The books in reading order.
    let books: [Book]

    /// One row per book, in reading order.
    var body: some View {
        List(books.enumerated(), id: \.element.title) { offset, book in
            BookRow(position: offset + 1, title: book.title)
        }
    }
}

/// A row that shows a book's position and title.
struct BookRow: View {
    /// The book's one-based position in reading order.
    let position: Int
    /// The title the reader entered.
    let title: String

    /// The position, then the title.
    var body: some View {
        HStack {
            Text(position, format: .number)
                .foregroundStyle(.secondary)
            Text(title)
        }
    }
}
```

Source: Apple's bundled `swiftui-specialist-ref-foreach.md.packaged` (path in SKILL.md, section 3).
