# Soft-deprecated APIs: labeled examples

Read before you write view modifiers or containers whose current form you have not checked against Apple's list. The two examples are a minimal pair: they differ on three lines.

How the examples were checked. Each code block is the complete file that was checked, unchanged. Both files passed the project's pinned SwiftFormat (`--lint --config .swiftformat`) and pinned SwiftLint (`lint --strict --config .swiftlint.yml`), and `xcrun swiftc -typecheck -swift-version 6 -strict-memory-safety -warnings-as-errors -default-isolation MainActor` (app-target flags) for a macOS target and again for an iOS target.

## POSITIVE: current APIs

Evidence: `NavigationStack`, `.foregroundStyle` and `.clipShape(.rect(cornerRadius:))` are the replacements that the SDK's own messages name for `NavigationView` ("use NavigationStack or NavigationSplitView instead"), `foregroundColor` (`renamed: "foregroundStyle(_:)"`) and `cornerRadius` ("Use `clipShape` or `fill` instead"), and none of the APIs used here is on Apple's soft-deprecated list. `Text(name)` shows the shelf name the reader chose as is, without localizing it. Checks: format pass, lint pass, typecheck pass (macOS and iOS).

```swift
import SwiftUI

/// The root screen of a shelf window.
struct ShelfScreen: View {
    /// The shelf name the reader chose.
    let name: String

    /// The shelf's badge in a navigation stack titled with the shelf name.
    var body: some View {
        NavigationStack {
            ShelfBadge(name: name)
                .navigationTitle(name)
        }
    }
}

/// A rounded badge that shows a shelf name.
struct ShelfBadge: View {
    /// The shelf name the reader chose.
    let name: String

    /// The name in secondary style on a rounded fill.
    var body: some View {
        Text(name)
            .foregroundStyle(.secondary)
            .padding(8)
            .background(.quaternary)
            .clipShape(.rect(cornerRadius: 8))
    }
}
```

## NEGATIVE: soft-deprecated APIs

Evidence: `NavigationView`, `.foregroundColor` and `.cornerRadius` are soft-deprecated: the SDK marks each `deprecated: 100000.0`, which raises no warning. This file passes all three checks, including the typecheck with `-warnings-as-errors`, so a clean build says nothing about API currency. Only a soft-deprecated API scan or a reviewer catches it. Checks: format pass, lint pass, typecheck pass; the defect is a judgment rule that the compiler and the project's built-in lint rules do not see. It differs from the positive only on those three lines.

```swift
import SwiftUI

/// The root screen of a shelf window.
struct ShelfScreen: View {
    /// The shelf name the reader chose.
    let name: String

    /// The shelf's badge in a navigation stack titled with the shelf name.
    var body: some View {
        NavigationView {
            ShelfBadge(name: name)
                .navigationTitle(name)
        }
    }
}

/// A rounded badge that shows a shelf name.
struct ShelfBadge: View {
    /// The shelf name the reader chose.
    let name: String

    /// The name in secondary style on a rounded fill.
    var body: some View {
        Text(name)
            .foregroundColor(.secondary)
            .padding(8)
            .background(.quaternary)
            .cornerRadius(8)
    }
}
```

Sources: Apple's bundled `swiftui-specialist-ref-soft-deprecation.md.packaged` and `swiftui-specialist-ref-soft-deprecated-apis.md.packaged` (path in SKILL.md, section 3); the SwiftUI and SwiftUICore SDK interfaces.
