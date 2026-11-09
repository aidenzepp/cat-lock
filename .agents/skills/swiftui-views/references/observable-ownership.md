# Observable model ownership: labeled examples

Read before you create an `@Observable` model, change which view owns one, or pass one to a view. The examples follow one small reading list: the model in the local package, the views in the app target.

How the examples were checked. Each code block is the complete file that was checked, unchanged; nothing is omitted unless a block says so. Every file passed the project's pinned SwiftFormat (`--lint --config .swiftformat`) and pinned SwiftLint (`lint --strict --config .swiftlint.yml`), and `xcrun swiftc -typecheck -swift-version 6 -strict-memory-safety -warnings-as-errors` for a macOS target and again for an iOS target. App-target files were also typechecked with `-default-isolation MainActor`, as Xcode sets for app targets; the package file was typechecked without it, as a package's default isolation is nonisolated. App-target files import `ReadingListKit`, a module emitted from the package file below without changes.

## POSITIVE: the model, in the package target `ReadingListKit`

Evidence: the model lives in the package, so the app target imports it, and its type, members and `init` are `public`. It carries `@MainActor` because the package's default isolation is nonisolated while views read the model on the main actor. It is `@Observable`, not `ObservableObject`. `Book` is `Equatable`, so `[Book]` is too, and the macro's setter skips writes of an equal array. `Book.id` is a `let` assigned once in `init`, so a book keeps its identity when its title is edited. `addDraft()` documents what it does with an empty draft instead of failing. Checks: format pass, lint pass, typecheck pass (package flags, macOS and iOS).

```swift
import Foundation
import Observation

/// A book on the reading list.
public struct Book: Identifiable, Equatable, Sendable {
    /// The identity that stays fixed while the book's data changes.
    public let id: UUID
    /// The title the reader entered.
    public var title: String

    /// Creates a book with a new identity.
    /// - Parameter title: The title the reader entered.
    public init(title: String) {
        id = UUID()
        self.title = title
    }
}

/// The reading list that the app's views observe.
@MainActor
@Observable
public final class ReadingListModel {
    /// The books in reading order.
    public private(set) var books: [Book]
    /// The title the reader is typing for the next book.
    public var draftTitle: String

    /// Creates a reading list.
    /// - Parameter books: The books in reading order.
    public init(books: [Book] = []) {
        self.books = books
        draftTitle = ""
    }

    /// Adds the draft title as a new book and clears the draft.
    ///
    /// A draft that is empty or only whitespace adds nothing.
    public func addDraft() {
        let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            return
        }

        books.append(Book(title: title))
        draftTitle = ""
    }
}
```

## POSITIVE: the views, in the app target

Evidence: the `App` creates the model and holds it in `@State private var`, so SwiftUI keeps one instance for the app's lifetime (Apple, "Managing model data in your app": create the source of truth with `@State`, including in the top-level `App`). It injects the model with `.environment(model)`. `ReadingListScreen` reads it with `@Environment(ReadingListModel.self)`; its body reads no model property, so it does not re-run when the books change. `BookList` only reads, so it takes a plain `let`. `AddBookField` needs a binding to `draftTitle`, so it declares `@Bindable var model` and binds `$model.draftTitle`. Checks: format pass, lint pass, typecheck pass (app-target flags plus `-parse-as-library` for `@main`, macOS and iOS).

```swift
import ReadingListKit
import SwiftUI

/// The app, which owns the reading list that its window shows.
@main
struct ReadingListApp: App {
    /// The one reading list; `@State` keeps this instance for the app's lifetime.
    @State private var model = ReadingListModel()

    /// The main window, with the reading list in its environment.
    var body: some Scene {
        WindowGroup {
            ReadingListScreen()
                .environment(model)
        }
    }
}

/// The root screen: the list of books above the field that adds one.
struct ReadingListScreen: View {
    /// The reading list that an ancestor placed in the environment.
    @Environment(ReadingListModel.self) private var model

    /// The book list above the add field, in a navigation stack.
    var body: some View {
        NavigationStack {
            VStack {
                BookList(model: model)
                AddBookField(model: model)
            }
            .navigationTitle("Reading List")
        }
    }
}

/// The list of books, which reads the model but never edits it.
struct BookList: View {
    /// The reading list this view displays.
    let model: ReadingListModel

    /// One row per book, in reading order.
    var body: some View {
        List(model.books) { book in
            Text(book.title)
        }
    }
}

/// The text field that adds a book to the reading list.
struct AddBookField: View {
    /// The reading list that owns the draft title this field edits.
    @Bindable var model: ReadingListModel

    /// A field bound to the draft title that adds the book on submit.
    var body: some View {
        TextField("Book title", text: $model.draftTitle)
            .onSubmit {
                model.addDraft()
            }
            .padding()
    }
}
```

## NEGATIVE: a view holds a model it was given in `@State`

Evidence: this `AddBookField` receives a model it did not create and stores it in `@State`. SwiftUI "initializes the state's storage only once for each container instance" (Apple, `State.init(wrappedValue:)`), so if its parent ever passes a different reading list, the field keeps editing the first one. Apple's `State` page shares an observable object stored in state by passing "the object reference to the subview". The fix is the positive's `@Bindable var model`. Checks: format pass, lint pass, typecheck pass. The defect is a judgment rule that no tool sees. This block replaces `AddBookField` in the app-target positive above; the rest of that file is unchanged and omitted, and this file was checked on its own.

```swift
import ReadingListKit
import SwiftUI

/// The text field that adds a book to the reading list.
struct AddBookField: View {
    /// The reading list that owns the draft title this field edits.
    @State private var model: ReadingListModel

    /// Creates the field for a reading list.
    /// - Parameter model: The reading list that owns the draft title.
    init(model: ReadingListModel) {
        self.model = model
    }

    /// A field bound to the draft title that adds the book on submit.
    var body: some View {
        TextField("Book title", text: $model.draftTitle)
            .onSubmit {
                model.addDraft()
            }
            .padding()
    }
}
```

## NEGATIVE: a closure binding instead of `@Bindable`

Evidence: `Binding(get:set:)` creates new closures on every body evaluation, which "means a new heap allocation each time `body` is run and can result in issues with comparison, triggering unnecessary invalidations" (Apple, `swiftui-specialist-ref-dataflow.md.packaged`, "Use KeyPath bindings, not closure bindings"). `@Bindable` and `$model.draftTitle` derive the same binding from a key path. Checks: format pass, lint pass, typecheck pass. The defect is a judgment rule that no tool sees. This block replaces `AddBookField` in the app-target positive above; the rest of that file is unchanged and omitted, and this file was checked on its own.

```swift
import ReadingListKit
import SwiftUI

/// The text field that adds a book to the reading list.
struct AddBookField: View {
    /// The reading list that owns the draft title this field edits.
    let model: ReadingListModel

    /// A field bound to the draft title that adds the book on submit.
    var body: some View {
        TextField(
            "Book title",
            text: Binding(
                get: {
                    model.draftTitle
                },
                set: {
                    model.draftTitle = $0
                },
            ),
        )
        .onSubmit {
            model.addDraft()
        }
        .padding()
    }
}
```

Sources: Apple, "Managing model data in your app" (https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app); Apple, `State` and `State.init(wrappedValue:)` (https://developer.apple.com/documentation/swiftui/state); Apple's bundled `swiftui-specialist-ref-dataflow.md.packaged` (path in SKILL.md, section 3).
