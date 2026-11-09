# Labeled examples

Read this before writing or changing an alert, an inline error or an error's display text. The examples share one small invoice importer: the typed errors and their text in the local package, the views in the app target.

How they were checked. Each code block is the complete file that was checked, unchanged. Every file went through the pinned SwiftFormat (`--lint --config .swiftformat`), the pinned SwiftLint (`lint --strict --config .swiftlint.yml`) and `xcrun swiftc -typecheck -swift-version 6 -strict-memory-safety -warnings-as-errors` with the template's four upcoming-feature flags. App-target files add `-default-isolation MainActor`, as Xcode sets for app targets; package files omit it, as a package's default isolation is nonisolated. App-target files import `InvoiceKit`, a module emitted from the package files shown with them. The examples follow swift-code-layout and pass the formatter. The checks cover tooling only; no code was run, so no example claims a string a running app would show.

Omitted surroundings, in every example that names them: `ImportModel`, a `@MainActor @Observable` class in `InvoiceKit` whose `failure` property holds the `ImportError` to present, and whose `chooseFile()` and `reviewRejectedRows()` start the file picker and the row editor. `failure` is settable by the screen. Examples 5 and 6 add `isShowingFailure`, a `Bool` on the model that reads `failure != nil` and clears `failure` when set to `false`. They are stubs in the checked scratch files and are not shown.

Contents: 1 POSITIVE text on the enum · 2 POSITIVE alert · 3 NEGATIVE `localizedDescription` · 4 NEGATIVE generic title · 5 NEGATIVE sentence as title · 6 POSITIVE title, reason and actions · 7 NEGATIVE cancelled shown · 8 POSITIVE cancelled ignored · 9 POSITIVE inline error · 10 NEGATIVE interpolated comment · 11 POSITIVE static comment · wording pairs.

## 1. POSITIVE: the text each case carries, as `LocalizedStringResource`

Placement: local package. Checks: format pass, lint pass, typecheck pass.

Evidence: the enum names a failure the caller can act on and carries no text. Its extension returns one `LocalizedStringResource` per case, so the string resolves when a view shows it. Each message says what happened to the file, and the second says what was kept. `bundle: #bundle` points lookup at the package's own String Catalog, and each `comment:` is a literal with no interpolation. The extension is a tool-visible contract (`missing_docs`); the wording is a judgment no tool sees.

```swift
import Foundation

/// Why an invoice file could not be imported.
public enum ImportError: Error, Equatable, Sendable {
    /// The file is not an invoice CSV; choosing another file may help.
    case unreadable
    /// Some rows lack an amount or a due date; the other rows were imported.
    case rowsRejected
}

/// The text the alert shows for each failure.
public extension ImportError {
    /// What happened to the file and what the person can do next.
    var message: LocalizedStringResource {
        switch self {
        case .unreadable:
            LocalizedStringResource(
                "This file isn't an invoice CSV. Choose a file exported from your billing system.",
                bundle: #bundle,
                comment: "Alert message when the chosen file cannot be read as invoices.",
            )

        case .rowsRejected:
            LocalizedStringResource(
                "Some rows are missing an amount or a due date. The other invoices were imported, and your file is unchanged.",
                bundle: #bundle,
                comment: "Alert message when some rows of an invoice CSV were rejected.",
            )
        }
    }
}
```

## 2. POSITIVE: an alert whose title says what happened and whose buttons are verbs

Placement: app target. Checks: format pass, lint pass, typecheck pass.

Omitted surroundings: `ImportModel`; `ImportError` from Example 1.

Evidence: the title "Couldn't Import Invoices" says what happened, and the message comes from the case, so each failure explains itself. `Review Rows` and `Choose Another File` name the next action. The cancelling button has `role: .cancel` and the title "Cancel". `alert(_:item:actions:message:)` presents from the optional `failure`, and `@Bindable` supplies `$model.failure`, so no `Binding(get:set:)` is needed. The title is a literal key in a view, so it is localized; the message is a resource, shown with `Text(_:)`.

```swift
import InvoiceKit
import SwiftUI

/// The screen where a person imports invoices from a CSV file.
struct ImportScreen: View {
    /// The import's state; the screen that presents this view owns it.
    @Bindable var model: ImportModel

    /// The import button and the alert that reports why an import failed.
    var body: some View {
        Button("Choose File…") {
            model.chooseFile()
        }
        .alert("Couldn't Import Invoices", item: $model.failure) { failure in
            switch failure {
            case .rowsRejected:
                Button("Review Rows") {
                    model.reviewRejectedRows()
                }
                Button("Cancel", role: .cancel) {
                    // The alert dismisses itself; the file stays as it is.
                }

            case .unreadable:
                Button("Choose Another File") {
                    model.chooseFile()
                }
                Button("Cancel", role: .cancel) {
                    // The alert dismisses itself; the file stays as it is.
                }
            }
        } message: { failure in
            Text(failure.message)
        }
    }
}
```

## 3. NEGATIVE: `localizedDescription` on screen

Placement: app target. Checks: format pass, lint pass, typecheck pass. The defect is a judgment rule that no tool sees.

Omitted surroundings: `ImportModel`; `ImportError` from Example 1.

Evidence: identical to Example 2 except the message line. `ImportError` adopts neither `LocalizedError` nor any text of its own, so `localizedDescription` returns the system's generic wording for the error, not the sentence the package wrote, and the `message` property sits unused. This example was not run, so the exact string is not shown. Show `failure.message` as in Example 2.

```swift
import InvoiceKit
import SwiftUI

/// The screen where a person imports invoices from a CSV file.
struct ImportScreen: View {
    /// The import's state; the screen that presents this view owns it.
    @Bindable var model: ImportModel

    /// The import button and the alert that reports why an import failed.
    var body: some View {
        Button("Choose File…") {
            model.chooseFile()
        }
        .alert("Couldn't Import Invoices", item: $model.failure) { failure in
            switch failure {
            case .rowsRejected:
                Button("Review Rows") {
                    model.reviewRejectedRows()
                }
                Button("Cancel", role: .cancel) {
                    // The alert dismisses itself; the file stays as it is.
                }

            case .unreadable:
                Button("Choose Another File") {
                    model.chooseFile()
                }
                Button("Cancel", role: .cancel) {
                    // The alert dismisses itself; the file stays as it is.
                }
            }
        } message: { failure in
            Text(failure.localizedDescription)
        }
    }
}
```

## 4. NEGATIVE: a title that says nothing

Placement: app target. Checks: format pass, lint pass, typecheck pass. The defect is a judgment rule that no tool sees.

Omitted surroundings: `ImportModel`; `ImportError` from Example 1.

Evidence: identical to Example 2 except the title. "Error" does not say what happened, so the person must read the message to learn it. The buttons are Example 2's verbs, and the message is correct. Show a title that says what happened, as in Example 2.

```swift
import InvoiceKit
import SwiftUI

/// The screen where a person imports invoices from a CSV file.
struct ImportScreen: View {
    /// The import's state; the screen that presents this view owns it.
    @Bindable var model: ImportModel

    /// The import button and the alert that reports why an import failed.
    var body: some View {
        Button("Choose File…") {
            model.chooseFile()
        }
        .alert("Error", item: $model.failure) { failure in
            switch failure {
            case .rowsRejected:
                Button("Review Rows") {
                    model.reviewRejectedRows()
                }
                Button("Cancel", role: .cancel) {
                    // The alert dismisses itself; the file stays as it is.
                }

            case .unreadable:
                Button("Choose Another File") {
                    model.chooseFile()
                }
                Button("Cancel", role: .cancel) {
                    // The alert dismisses itself; the file stays as it is.
                }
            }
        } message: { failure in
            Text(failure.message)
        }
    }
}
```

## 5. NEGATIVE: a full sentence in `errorDescription`, shown with no message

Placement: package file, then app target. Checks for both files: format pass, lint pass, typecheck pass. The defect is a judgment rule that no tool sees.

Omitted surroundings: `ImportModel`, which here also has `isShowingFailure`.

Evidence: `errorDescription` holds the whole explanation, and the view uses `alert(isPresented:error:actions:)`, the overload with no `message:` closure. Apple's documentation names `errorDescription` as the alert's title for that overload, so the explanation becomes a sentence-long title, and Apple's page names nothing else the alert would show. The buttons are verbs; this overload's `actions` closure receives no error, so one next action serves both cases. Keep the title short and move the explanation to `failureReason`, as in Example 6.

```swift
import Foundation

/// Why an invoice file could not be imported.
public enum ImportError: LocalizedError, Equatable, Sendable {
    /// The file is not an invoice CSV; choosing another file may help.
    case unreadable
    /// Some rows lack an amount or a due date; the other rows were imported.
    case rowsRejected

    /// The text an alert shows as its title.
    public var errorDescription: String? {
        switch self {
        case .unreadable:
            String(
                localized: "This file isn't an invoice CSV. Choose a file exported from your billing system.",
                bundle: #bundle,
                comment: "Alert title when the chosen file cannot be read as invoices.",
            )

        case .rowsRejected:
            String(
                localized: "Some rows are missing an amount or a due date. The other invoices were imported, and your file is unchanged.",
                bundle: #bundle,
                comment: "Alert title when some rows of an invoice CSV were rejected.",
            )
        }
    }
}
```

```swift
import InvoiceKit
import SwiftUI

/// The screen where a person imports invoices from a CSV file.
struct ImportScreen: View {
    /// The import's state; the screen that presents this view owns it.
    @Bindable var model: ImportModel

    /// The import button and the alert that reports why an import failed.
    var body: some View {
        Button("Choose File…") {
            model.chooseFile()
        }
        .alert(isPresented: $model.isShowingFailure, error: model.failure) {
            Button("Choose Another File") {
                model.chooseFile()
            }
            Button("Cancel", role: .cancel) {
                // The alert dismisses itself; the file stays as it is.
            }
        }
    }
}
```

## 6. POSITIVE: `errorDescription` as the title, `failureReason` as the message

Placement: package file, then app target. Checks for both files: format pass, lint pass, typecheck pass.

Omitted surroundings: `ImportModel`, which here also has `isShowingFailure`.

Evidence: `errorDescription` is a short phrase that says what happened, and `failureReason` carries why and what was kept. Both are `String?`, so each is built with `String(localized:bundle:comment:)` and a static comment, because `LocalizedError` takes no `LocalizedStringResource`. The view presents with `alert(isPresented:error:actions:message:)`, whose closures receive the error. The actions name each case's next action, `Review Rows` or `Choose Another File`, beside a `Cancel` button with `role: .cancel`, and the message shows `failureReason` when it exists. Because the alert offers next actions, it has no "OK" button.

```swift
import Foundation

/// Why an invoice file could not be imported.
public enum ImportError: LocalizedError, Equatable, Sendable {
    /// The file is not an invoice CSV; choosing another file may help.
    case unreadable
    /// Some rows lack an amount or a due date; the other rows were imported.
    case rowsRejected

    /// The text an alert shows as its title: what happened, as a short phrase.
    public var errorDescription: String? {
        switch self {
        case .unreadable:
            String(
                localized: "Couldn't Read This File",
                bundle: #bundle,
                comment: "Alert title when the chosen file cannot be read as invoices.",
            )

        case .rowsRejected:
            String(
                localized: "Couldn't Import Some Invoices",
                bundle: #bundle,
                comment: "Alert title when some rows of an invoice CSV were rejected.",
            )
        }
    }

    /// The text an alert shows as its message: why it happened and what was kept.
    public var failureReason: String? {
        switch self {
        case .unreadable:
            String(
                localized: "This file isn't an invoice CSV. Choose a file exported from your billing system.",
                bundle: #bundle,
                comment: "Alert message when the chosen file cannot be read as invoices.",
            )

        case .rowsRejected:
            String(
                localized: "Some rows are missing an amount or a due date. The other invoices were imported, and your file is unchanged.",
                bundle: #bundle,
                comment: "Alert message when some rows of an invoice CSV were rejected.",
            )
        }
    }
}
```

```swift
import InvoiceKit
import SwiftUI

/// The screen where a person imports invoices from a CSV file.
struct ImportScreen: View {
    /// The import's state; the screen that presents this view owns it.
    @Bindable var model: ImportModel

    /// The import button and the alert that reports why an import failed.
    var body: some View {
        Button("Choose File…") {
            model.chooseFile()
        }
        .alert(isPresented: $model.isShowingFailure, error: model.failure) { error in
            switch error {
            case .rowsRejected:
                Button("Review Rows") {
                    model.reviewRejectedRows()
                }
                Button("Cancel", role: .cancel) {
                    // The alert dismisses itself; the file stays as it is.
                }

            case .unreadable:
                Button("Choose Another File") {
                    model.chooseFile()
                }
                Button("Cancel", role: .cancel) {
                    // The alert dismisses itself; the file stays as it is.
                }
            }
        } message: { error in
            if let reason = error.failureReason {
                Text(reason)
            }
        }
    }
}
```

## 7. NEGATIVE: a cancelled save becomes an alert

Placement: local package. Checks: format pass, lint pass, typecheck pass. The defect is a judgment rule that no tool sees.

Evidence: `SaveState` is one enum with one writer, so a success replaces a failure, `isShowingFailure` is the settable `Bool` that `alert(isPresented:)` writes `false` to, and it reads from `state`, so no two properties disagree. The defect is `.cancelled`: `finish(_:)` stores every `SaveError` in `.failed`, so `.cancelled` reaches the alert. A cancelled task means its owner moved on and nobody is waiting for the result. Compare Example 8, which differs only in how cancellation reaches the state.

```swift
import Observation

/// A saved receipt.
public struct Receipt: Equatable, Sendable {
    /// The receipt's number.
    public let number: Int
}

/// Why saving a receipt failed.
public enum SaveError: Error, Equatable, Sendable {
    /// The task that saved the receipt was cancelled.
    case cancelled
    /// The device has no room for the receipt.
    case storageFull
}

/// What the receipt screen shows about the latest save.
public enum SaveState: Equatable, Sendable {
    /// No save has ended, or its failure was dismissed.
    case idle
    /// The latest save stored this receipt.
    case saved(Receipt)
    /// The latest save failed, and the screen presents the reason in an alert.
    case failed(SaveError)
}

/// The state of the receipt screen.
@MainActor @Observable
public final class ReceiptModel {
    /// The outcome of the latest save; this model is its only writer.
    public private(set) var state: SaveState

    /// Whether the screen presents the latest failure; writing `false` dismisses it, and any other state stays.
    public var isShowingFailure: Bool {
        get {
            if case .failed = state {
                true
            } else {
                false
            }
        }
        set {
            if !newValue, case .failed = state {
                state = .idle
            }
        }
    }

    /// Creates a model that has saved nothing.
    public init() {
        state = .idle
    }

    /// Records how a save ended so that the screen can show it.
    /// - Parameter result: The outcome of the save.
    public func finish(_ result: Result<Receipt, SaveError>) {
        switch result {
        case let .success(receipt):
            state = .saved(receipt)

        case let .failure(error):
            state = .failed(error)
        }
    }
}
```

## 8. POSITIVE: `.cancelled` ends quietly

Placement: local package. Checks: format pass, lint pass, typecheck pass.

Evidence: the same model and the same single-writer enum as Example 7, with cancellation kept out of the state. `SaveFailure` lists only the failures worth an alert, so `.failed` cannot hold `.cancelled`. `finish(_:)` matches `.failure(.cancelled)` first and leaves the state as it was, with a comment that says why. The `break` is a statement, so the case is not an empty block. A success clears an earlier failure, and writing `false` to `isShowingFailure` returns the state to `.idle`.

```swift
import Observation

/// A saved receipt.
public struct Receipt: Equatable, Sendable {
    /// The receipt's number.
    public let number: Int
}

/// Why saving a receipt failed.
public enum SaveError: Error, Equatable, Sendable {
    /// The task that saved the receipt was cancelled.
    case cancelled
    /// The device has no room for the receipt.
    case storageFull
}

/// A failure worth telling the person about; cancellation is not one.
public enum SaveFailure: Equatable, Sendable {
    /// The device has no room for the receipt.
    case storageFull
}

/// What the receipt screen shows about the latest save.
public enum SaveState: Equatable, Sendable {
    /// No save has ended, or its failure was dismissed.
    case idle
    /// The latest save stored this receipt.
    case saved(Receipt)
    /// The latest save failed, and the screen presents the reason in an alert.
    case failed(SaveFailure)
}

/// The state of the receipt screen.
@MainActor @Observable
public final class ReceiptModel {
    /// The outcome of the latest save; this model is its only writer.
    public private(set) var state: SaveState

    /// Whether the screen presents the latest failure; writing `false` dismisses it, and any other state stays.
    public var isShowingFailure: Bool {
        get {
            if case .failed = state {
                true
            } else {
                false
            }
        }
        set {
            if !newValue, case .failed = state {
                state = .idle
            }
        }
    }

    /// Creates a model that has saved nothing.
    public init() {
        state = .idle
    }

    /// Records how a save ended so that the screen can show it.
    /// - Parameter result: The outcome of the save.
    public func finish(_ result: Result<Receipt, SaveError>) {
        switch result {
        case let .success(receipt):
            state = .saved(receipt)

        case .failure(.cancelled):
            // The task's owner moved on, so no one is waiting for this result.
            break

        case .failure(.storageFull):
            state = .failed(.storageFull)
        }
    }
}
```

## 9. POSITIVE: an inline error that names the value, the constraint and the announcement

Placement: package file, then app target. Checks for both files: format pass, lint pass, typecheck pass.

Evidence (the app-target file imports `ZipKit`, a module emitted from the package file above it): `ZipCode` declares a `private init(digits:)` in its body, which removes the internal memberwise initializer, so `parse(_:)` is the only way to make one and the documentation's "only way" is true. `parse(_:)` returns `Result<ZipCode, ZipCodeError>`, and its documentation states that it ignores surrounding spaces, so `digits` holds the trimmed text; the failing case keeps the text exactly as typed, so the message can say "Enter a 5-digit ZIP code. You entered “…”" (value and constraint). The view checks on submit, not while typing, leaves `text` as typed, shows the message beside the field with an icon and text, and announces it to VoiceOver. `String(localized:)` converts the resource only because the announcement needs a `String`. The red foreground is extra: the icon and the words carry the meaning.

```swift
import Foundation

/// Why text is not a ZIP code.
public enum ZipCodeError: Error, Equatable, Sendable {
    /// The text is not five digits; the case keeps what was typed.
    case notFiveDigits(entered: String)
}

/// The text the field shows for each failure.
public extension ZipCodeError {
    /// What to enter, and the text that was entered.
    var message: LocalizedStringResource {
        switch self {
        case let .notFiveDigits(entered):
            LocalizedStringResource(
                "Enter a 5-digit ZIP code. You entered “\(entered)”.",
                bundle: #bundle,
                comment: "Inline error under the ZIP code field; the value is what the person typed.",
            )
        }
    }
}

/// A five-digit US ZIP code.
///
/// ``parse(_:)`` is the only way to make one, so ``digits`` is always five ASCII digits.
public struct ZipCode: Equatable, Sendable {
    /// The five digits.
    public let digits: String

    /// Creates a ZIP code from digits that have already been checked.
    /// - Parameter digits: Five ASCII digits.
    private init(digits: String) {
        self.digits = digits
    }

    /// Reads a ZIP code from typed text.
    ///
    /// Spaces before and after the text are ignored, so ``digits`` never holds them; a failure keeps the
    /// text exactly as typed.
    ///
    /// - Parameter text: The text in the field.
    /// - Returns: The ZIP code, or ``ZipCodeError/notFiveDigits(entered:)`` with `text` as typed.
    public static func parse(_ text: String) -> Result<ZipCode, ZipCodeError> {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let allDigits = trimmed.allSatisfy {
            $0.isASCII && $0.isWholeNumber
        }
        guard trimmed.count == 5, allDigits else {
            return .failure(.notFiveDigits(entered: text))
        }

        return .success(ZipCode(digits: trimmed))
    }
}
```

```swift
import Accessibility
import Foundation
import SwiftUI
import ZipKit

/// The field where a person enters a ZIP code.
struct ZipCodeField: View {
    /// The text in the field; a failed check leaves it as typed.
    @State private var text = ""
    /// What is wrong with the text, shown after the person submits.
    @State private var problem: ZipCodeError?

    /// The field, and under it the reason the last submit failed.
    var body: some View {
        VStack(alignment: .leading) {
            TextField("ZIP Code", text: $text)
                .onSubmit {
                    check()
                }

            if let problem {
                Label(problem.message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }
        }
    }

    /// Checks the text, and announces the reason to VoiceOver when it fails.
    private func check() {
        switch ZipCode.parse(text) {
        case .success:
            problem = nil

        case let .failure(error):
            problem = error
            AccessibilityNotification.Announcement(String(localized: error.message)).post()
        }
    }
}
```

## 10. NEGATIVE: an interpolated `comment:`

Placement: app target or package. Checks: format pass, lint pass, typecheck fail. The defect is the type error: `comment:` is a `StaticString`.

Evidence: the compiler refuses the interpolation, with `error: cannot convert value of type 'String' to expected argument type 'StaticString'` at the `comment:` line. Translators need a stable comment, so the value goes in the localized string and the comment stays a literal, as in Example 11.

```swift
import Foundation

/// Names the file that failed to save, for the person who sees the alert.
/// - Parameter name: The file's name.
/// - Returns: The localized failure text.
func saveFailureTitle(for name: String) -> String {
    String(
        localized: "Couldn't save “\(name)”",
        bundle: #bundle,
        comment: "Failed to save \(name)",
    )
}
```

## 11. POSITIVE: a static comment

Placement: app target or package. Checks: format pass, lint pass, typecheck pass.

Evidence: the same function with a literal comment that names what the interpolated value is. The value `name` is interpolated into the localized string, where it belongs.

```swift
import Foundation

/// Names the file that failed to save, for the person who sees the alert.
/// - Parameter name: The file's name.
/// - Returns: The localized failure text.
func saveFailureTitle(for name: String) -> String {
    String(
        localized: "Couldn't save “\(name)”",
        bundle: #bundle,
        comment: "Alert title when a file cannot be saved; the value is the file name.",
    )
}
```

## Wording pairs

Wording only: no tool checks it, and none of these is code.

| Surface | NEGATIVE | POSITIVE | Why |
| --- | --- | --- | --- |
| Alert title | Whoops! Something went wrong. | Couldn't Connect Your Account | Says what happened, no joke |
| Alert message | The provider isn't responding. Try again later. | Your changes were saved, but the account wasn't connected because the provider is unavailable. Try again later, or contact support if this keeps happening. | Names what was kept, why and a fallback |
| Inline | Invalid postal code. | Enter a 5-digit ZIP code. You entered “4872953”. | Names the constraint and the value |
| Password | Bad password. | Password must have at least 12 characters. | Names the rule, not the secret |
| Permission | Permission denied. | Allow access to Photos in Settings to add this picture. | Names the permission and the way to grant it |
| Import | Upload failed. Invalid file. | Couldn't import 12 invoices. Your file is saved as a draft. | Says what failed and what was kept |
| Button | OK | Review Rows | Names the action |
