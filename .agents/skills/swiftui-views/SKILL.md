---
name: swiftui-views
description: "Use when writing, reviewing or refactoring SwiftUI code in this template's apps or its local package, including views, @Observable models and who owns them, ForEach and List rows, navigation, previews, toolbars, alerts (their error text is swift-error-surfaces), Liquid Glass, and accessibility labels or localized text in views. Covers the SwiftUI choices that compile clean when they are wrong, such as soft-deprecated APIs and their replacements, @State, @Bindable and @Environment ownership with models in the package, view structure and invalidation, and element identity. Hand off build settings to xcode-project-settings; async work, .task, isolation errors, failure paths and unchecked invariants to swift-isolation; error alert text and failure copy to swift-error-surfaces; and tests, accessibility audits and localization checks to app-verification."
---

# SwiftUI views

SwiftUI choices on the current SDK that compile clean when they are wrong: API currency, data flow, structure and identity. Tools own formatting and the mechanical rules. This skill covers what they cannot see.

## 1. Preflight

From the repository root, run the project's toolchain preflight and stop on a non-zero exit, reporting its output. Do not install or upgrade tools; name the project's setup step instead. In this template that is `./scripts/dev.swift doctor` after `./scripts/dev.swift bootstrap`.

## 2. Confirm the project enforces

Read the project's shared build settings (in this template, `config/Strict.xcconfig`) or the app targets' resolved settings, plus the local package's `Package.swift` and `.swiftlint.yml`, and confirm each mechanism below. If one is missing, report the gap and apply its rule by hand while you work. This skill says nothing more about these rules.

- Warnings are errors: `SWIFT_TREAT_WARNINGS_AS_ERRORS = YES` on every app and test target, and `.treatAllWarnings(as: .error)` in the package manifest.
- SwiftLint runs with `strict: true` and enables `force_unwrapping` (with `ignored_literal_argument_functions: []`), `force_try`, `force_cast`, `implicitly_unwrapped_optional` (with `mode: all`), `private_swiftui_state`, `no_empty_block`, `unowned_variable_capture`, `empty_count`, `contains_over_filter_is_empty`, `redundant_sendable`, `duplicate_imports`, `unused_closure_parameter`, `unused_optional_binding`, `unused_enumerated`, `blanket_disable_command`, `superfluous_disable_command`, `weak_delegate`, `discarded_notification_center_observer` and the `no_discardable_result` custom rule.
- SwiftFormat checks every source. In this template that is `./scripts/dev.swift check`.
- A soft-deprecated API scan, such as a SwiftLint custom rule limited by `match_kinds` to identifiers, seeded from Apple's list (section 4).

## 3. Read Apple's guide first

Xcode ships Apple's SwiftUI guidance, which states that it supersedes model training. Before writing code, read the file for the task. Link it; never copy it. APPLE below is `/Applications/Xcode.app/Contents/PlugIns/IDEIntelligenceChat.framework/Versions/A/Resources`; if Xcode is installed elsewhere, start from the app that `xcode-select -p` points into.

| Task | Read |
|---|---|
| Any SwiftUI code (the index of the files below) | `APPLE/swiftui-specialist.idechatprompttemplate` |
| Sections, view `init`, `Group` | `APPLE/swiftui-specialist-ref-structure.md.packaged` |
| `@State`, `@Observable`, bindings, `.onChange` | `APPLE/swiftui-specialist-ref-dataflow.md.packaged` |
| `@Environment`, `@Entry` | `APPLE/swiftui-specialist-ref-environment.md.packaged` |
| Conditional modifiers | `APPLE/swiftui-specialist-ref-modifiers.md.packaged` |
| `ForEach`, `List`, `Table`, `OutlineGroup` | `APPLE/swiftui-specialist-ref-foreach.md.packaged` |
| User-facing text | `APPLE/swiftui-specialist-ref-localization.md.packaged` |
| Custom `Animatable` types | `APPLE/swiftui-specialist-ref-animations.md.packaged` |
| API currency | `APPLE/swiftui-specialist-ref-soft-deprecation.md.packaged` and `-ref-soft-deprecated-apis.md.packaged` |
| APIs new or changed in the installed SDK, and `@State` errors after an SDK update | `APPLE/swiftui-whats-new-*.idechatprompttemplate` and its `-ref-*` files |
| Liquid Glass | `APPLE/AdditionalDocumentation/SwiftUI-Implementing-Liquid-Glass-Design.md`; the `AppKit-` and `UIKit-` guides for bridged views |
| Toolbars | `APPLE/AdditionalDocumentation/SwiftUI-New-Toolbar-Features.md` and the what's-new toolbar reference |

Apple's guides win over training. The project's own decisions below (the package shape, and the isolation and error policy in swift-isolation) win where they are stricter. Apple's sample code is not policy: follow the guides' rules, not every snippet.

## 4. Never emit soft-deprecated APIs

A soft-deprecated API carries `deprecated: 100000.0`, which raises no warning, so a clean build proves nothing about API currency. Never write one in new code. The common ones:

| Never write | Write |
|---|---|
| `NavigationView` | `NavigationStack`, or `NavigationSplitView` for columns |
| `NavigationLink(destination:)` with a view value | `NavigationLink(value:label:)` with `navigationDestination(for:)` |
| `.tabItem` | `Tab` |
| `.foregroundColor` | `.foregroundStyle` |
| `.cornerRadius` | `.clipShape(.rect(cornerRadius:))`, or `fill` on a shape |
| `.accentColor` | `.tint`, or the asset catalog's accent color |
| `.edgesIgnoringSafeArea` | `.ignoresSafeArea` |
| `.colorScheme(_:)` | `.preferredColorScheme(_:)` |
| `Alert`, `ActionSheet` | the `alert` and `confirmationDialog` modifiers |
| `.navigationBarTitle` | `.navigationTitle`, plus `.navigationBarTitleDisplayMode` on iOS |
| `.navigationBarHidden` | `.toolbarVisibility(.hidden, for: .navigationBar)` on iOS. The SDK's message names `toolbar(.hidden)`, which is itself soft-deprecated |
| `.toolbar(_:for:)` or `.toolbarBackground(_:for:)` with a `Visibility` | `.toolbarVisibility(_:for:)`, `.toolbarBackgroundVisibility(_:for:)` |
| `.autocapitalization` | `.textInputAutocapitalization`, iOS only; macOS has no equivalent |
| `.disableAutocorrection` | `.autocorrectionDisabled`, on both platforms |
| `.overlay(_:alignment:)` or `.background(_:alignment:)` with a view | `.overlay(alignment:content:)`, `.background(alignment:content:)` |

- The full list is `APPLE/swiftui-specialist-ref-soft-deprecated-apis.md.packaged`. Search it before you use an API you have not checked, because any API can become soft-deprecated in a new release.
- When the installed SDK is newer than the SDKs in the list's header, check the declaration's `@available` attribute in the SDK interface, `"$(xcrun --sdk macosx --show-sdk-path)/System/Library/Frameworks/SwiftUI.framework/Modules/SwiftUI.swiftmodule/arm64e-apple-macos.swiftinterface"`, and its `SwiftUICore` sibling (`--sdk iphoneos` and `arm64e-apple-ios` for iOS).
- Examples: [references/soft-deprecated-apis.md](references/soft-deprecated-apis.md).

## 5. Scope of migration

Apple's soft-deprecation guide sets the scope:

- Writing new code: never emit one.
- Asked to review, refactor, modernize or clean up: point out each one in the code under review and name its replacement, as information, not as an urgent defect.
- Asked for a feature or a fix in a view that uses one: keep the existing API in your change, then offer the migration as a separate step.
- A view you were not asked to change: say nothing about it.

An existing conditional `.if` modifier follows the same scope: leave it in place, and in a review say what it breaks (section 7).

## 6. Model ownership

Models and domain logic live in the local Swift package, and views stay in the app target, unless the consuming app has chosen another shape.

- A package model is a `public` `@MainActor` `@Observable` `final class` with a `public init`. The package's default isolation is nonisolated and views read models on the main actor, so the annotation is required there. A model kept in an app target whose default isolation is `MainActor` needs none.
- Give its stored properties `Equatable` types, and collections `Equatable` elements, so the macro's setter skips writes of an equal value.
- Never use `ObservableObject`, `@Published`, `@StateObject`, `@ObservedObject` or `@EnvironmentObject` in new code. They carry no deprecation, so nothing warns.

| The view | Declares |
|---|---|
| creates and owns the model: the `App`, a `Scene`, or the highest view that needs it | `@State private var model = Model()` |
| reads the model or calls its methods | a plain `let model: Model` |
| needs a binding to one of its properties | `@Bindable var model: Model` and `$model.property`; inside a `body`, `@Bindable var model = model` |
| is one of many descendants | the owner applies `.environment(model)`; the reader declares `@Environment(Model.self) private var model`, optional only where absence is a legitimate state |

- Never hold a model the view did not create in `@State`. SwiftUI creates state storage once per view instance, so a different instance passed later is ignored.
- Never give a `@State` an initial value and also assign it in `init`: the body keeps the initial value. To seed view-local state from a parameter, declare it without an initial value and assign it only in `init`; later values of that parameter are ignored. Reordering the assignments is not a fix (what's-new `-ref-state-macro`).
- Derive bindings with `@Bindable` and `$model.property`, or a labeled subscript for a projection that takes an argument, never with `Binding(get:set:)`. A closure binding allocates on every body evaluation and defeats comparison.
- Observation tracks each stored property as a whole. A view that reads one element of a stored array depends on the whole array, and so does a computed property that reads it. Cache a derived value as its own stored property, updated in `didSet`.
- An `@Entry` default returns the same value on every read: a literal, an enum case, `nil` or a `static let`. `Date()`, `UUID()` and other fresh values are not stable defaults.
- Storage is chosen per app. If an app adopts SwiftData, follow Apple's SwiftData documentation and `APPLE/AdditionalDocumentation/SwiftData-Class-Inheritance.md`; this skill sets no SwiftData rules.
- Examples, required reading before you create a model or change who owns one: [references/observable-ownership.md](references/observable-ownership.md).

## 7. Structure and invalidation

A view is SwiftUI's unit of invalidation: when an input changes, its whole `body` runs again.

- Give each section (a header, list, footer, sidebar or detail pane) its own `View` struct, not a computed property or a `@ViewBuilder` helper on the parent. A computed property shares the parent's invalidation boundary.
- Pass value-type inputs as the fields the view reads, not a whole struct, because SwiftUI compares value inputs field by field. Forwarding a field to a child counts as reading it. An `@Observable` model is compared by reference, so passing the model is fine.
- Pass a row its element or the fields it shows, never an index into the model.
- Keep `init` a constant-time copy of its inputs: no decoding, formatting, file access or large allocation. Format in `body` with `Text(_:format:)`, and do expensive work in the model or in `.task`.
- Drop a `Group` that wraps one concrete view. A `Group` around siblings, a `ForEach` or an `if`/`else` does real work.
- Never write a conditional `.if` modifier. Flipping its condition swaps the view for a different one, which resets state and breaks animation. Put the condition in the modifier's argument as a ternary, and erase to `AnyShapeStyle` only when the two styles do not unify.
- Delete an `@Environment(\.key)` declaration whose value the body never reads; every write to that key still invalidates the view.
- When a value is read only to drive `.onChange` and the host's body is expensive, move the read and the `.onChange` into a small `ViewModifier`. Skip this when the value is also rendered or the body is trivial.
- Async side effects belong to `.task`; see swift-isolation.

## 8. Identity

`ForEach`, and `List`, `Table`, `OutlineGroup` and the other data-driven views that work like it, match rows across updates by id. An id must be stable, so an element keeps it through edits and moves, and unique within the collection.

- Take the id from the element: its `Identifiable` id, or a key path to a key that never changes. Never a position (`indices`, `\.offset`, `id: \.self` on an index) and never editable content such as a title.
- `.enumerated()` is fine with `id: \.element.id`; the offset is then row data.
- Indices are acceptable only over a collection that never changes, such as a constant array of options.
- Never mint ids in `body`, for example by mapping to new values whose `id` defaults to `UUID()`. Create them once, in storage that outlives `body`.
- Never sort or filter in the `ForEach` argument. Cache the derived collection in the model and recompute it when an input changes. A cheap read such as `prefix(_:)` is fine.
- Keep each row one top-level view, with any `switch` or `if` inside a container, and never use `AnyView` as a row. To find rows that defeat `List`'s fast path, launch with the argument `-LogForEachSlowPath YES`.
- Examples, required reading before you write or review a `ForEach` or a data-driven list: [references/foreach-identity.md](references/foreach-identity.md).

## 9. Navigation

- Use `NavigationStack` with `NavigationLink(value:label:)` and `navigationDestination(for:)`, or `NavigationSplitView` when the layout has two or three columns; it collapses to a stack in compact width.
- Bind a `path:` (a typed array or a `NavigationPath`) when the app needs deep links, state restoration or programmatic navigation.
- Which screens exist and how routes are modeled belong to each app. The template prescribes neither.
- Present alerts and dialogs with the `alert` and `confirmationDialog` modifiers, and use the `item:` overloads to present from an optional value (what's-new `-ref-item-binding`). The title, message and buttons of an error alert are user-facing failure text: see swift-error-surfaces.
- A customizable toolbar gives every item an id through `toolbar(id:)`. Placement, overflow and visibility APIs are in the toolbar guides (section 3).

## 10. Previews

- Write `#Preview` blocks, and set their layout with `traits:`, such as `.sizeThatFitsLayout`.
- State that a preview needs is `@Previewable @State` inside the `#Preview` body, not a wrapper view.
- Setup that several previews share, such as a model with sample data or an environment value, goes in a `PreviewModifier`, whose shared context is created once per configuration.

## 11. Liquid Glass

- Standard controls adopt Liquid Glass when built with the current SDK. Prefer them to custom glass.
- For buttons, use `.buttonStyle(.glass)` or `.buttonStyle(.glassProminent)`.
- Apply `glassEffect` only to custom views, sparingly, after the modifiers that set the view's appearance. Group several glass views in one `GlassEffectContainer`, morph between them with `glassEffectID(_:in:)` and a `@Namespace`, and make glass `.interactive()` only when it responds to input.

## 12. Accessibility and text in code

- An icon-only control still has a text label: `Button("Add Book", systemImage: "plus", action: add)` with `.labelStyle(.iconOnly)`, or `accessibilityLabel` on a view that shows no text.
- Use `Button` for an action, not `onTapGesture`, so assistive technologies see a button.
- A literal passed to a `LocalizedStringKey` API (`Text`, `Button`, `navigationTitle`) is a localization key; never wrap it in `String(localized:)`. Use `Text(verbatim:)` for a literal that must not be localized. A `String` variable, such as a title the user typed, is shown as is.
- A user-facing string that a non-view type or a model property carries is a `LocalizedStringResource`, so it resolves at display time.
- In the package, pass `bundle: #bundle` to `Text`, `String(localized:)` and `LocalizedStringResource`. Without it, lookup uses the app's bundle and fails silently.
- Add `comment:` to an ambiguous string and to an interpolated one, naming placeholders by position.
- Read the locale from `@Environment(\.locale)`, not `Locale.current`. Format with `Text(_:format:)` and format styles, not `String(format:)`. Align with `.leading` and `.trailing`, not `.left` and `.right`.
- iOS: set text with text styles (`.font(.body)`, `.font(.headline)`), not fixed sizes, so Dynamic Type scales it. macOS: text styles still apply, as the HIG asks for dynamic system fonts, but macOS does not support Dynamic Type, so they do not scale with the user's text size there.
- Observed on Xcode 27 builds: on macOS 27, Dynamic Type sizes do not change text styles or `@ScaledMetric` values in a headless probe. Whether a macOS system setting enlarges a running window's text is unverified. For text styles, see `swiftui-design-tokens`.
- Accessibility audits and localization checks belong to app-verification.

## 13. Platform bridging

- Bridge to AppKit or UIKit (`NSViewRepresentable`, `UIViewRepresentable`, `NSHostingView`, `UIHostingController`) only for a capability SwiftUI lacks, and name that capability in the type's documentation comment.
- On macOS, panels and status items are routine reasons to bridge.
- For the `init(coder:)` a bridged subclass must declare, and any other path the code treats as unreachable, see swift-isolation.

## 14. Before you finish

1. Run the project's format and check entry points; never hand-format. In this template, run `./scripts/dev.swift fix`, then `./scripts/dev.swift check`.
2. Review what no tool checks, in the code you changed: soft-deprecated APIs (section 4), who owns each model (6), section factoring and inputs (7), element identity (8), and labels and text (12).
3. A clean build and lint do not show that a view works. Running it belongs to app-verification.

Hand-offs:

- xcode-project-settings: build settings, targets, the package manifest and deployment floors.
- swift-isolation: async code, `.task`, actors and `Sendable` errors, failure paths and `Result`, `fatalError`, integer indices and `unsafe`.
- swift-error-surfaces: the text a person sees when something fails, including alert titles, messages and buttons, inline validation and error states.
- app-verification: tests, accessibility audits, localization checks and CI.
