# Type, shapes, glass and variant styles: labeled examples

Read before you add a custom font, a surface that nests rounded shapes, a material or glass surface, or a variant style. Each pair is a minimal pair; its evidence names the lines that differ. Every file here belongs to the app target, the default home for appearance (SKILL.md, section 9); a file under `Appearance/` is one of the appearance files.

How the examples were checked. Each code block is the complete file that was checked, unchanged. Every file follows swift-code-layout and passed the template's pinned SwiftFormat (`--lint --config .swiftformat`) and pinned SwiftLint (`lint --strict --config .swiftlint.yml`), run from the template root. Each was typechecked on Xcode 27 (Swift 6.4) with `xcrun swiftc -typecheck -swift-version 6 -strict-memory-safety -warnings-as-errors -default-isolation MainActor` and the four upcoming features (`NonisolatedNonsendingByDefault`, `InferIsolatedConformances`, `ExistentialAny`, `MemberImportVisibility`), for macOS and for the iOS Simulator, together with the appearance file it uses. Omitted surroundings in V1: `PracticeSession`, a package model in an `AppModel` target, a `public` `@MainActor` `@Observable` `final class` with the two methods the buttons call, as swiftui-views, section 6, describes; the check imported a module emitted from a stand-in with those members. The appearance files carry no `#Preview`, to keep each pair minimal; SKILL.md, section 9, says what a style's preview covers.

## T1 POSITIVE: a custom font built on a text style

Evidence: `Font.system(.title2, design:weight:)` takes the title 2 text style's size, so on iOS the section heading scales with Dynamic Type as title 2 does, and on macOS it gets the platform's title 2 size. Every screen heads its sections in this type, so it is one named static in the appearance files, and app code writes `.font(.sectionHeading)`. Checks: format pass, lint pass, typecheck pass on macOS and the iOS Simulator.

`Appearance/Fonts.swift`:

```swift
import SwiftUI

/// Custom type that app code applies with `.font(.sectionHeading)`.
extension Font {
    /// The type for a section's heading: the title 2 text style, rounded and semibold.
    static let sectionHeading = Font.system(.title2, design: .rounded, weight: .semibold)
}
```

## T1 NEGATIVE: a custom font at a fixed size

Evidence: `Font.system(size: 22, weight:design:)` is fixed at 22 points, so on iOS the section heading does not scale with Dynamic Type, and on macOS it is larger than the platform's title 2. A fixed-size lint that excludes the appearance files, as SKILL.md, section 1, describes, does not see it. Checks: format pass, lint pass, typecheck pass on macOS and the iOS Simulator; the defect is a judgment rule no tool sees. It differs from the positive in the property and its comment.

```swift
import SwiftUI

/// Custom type that app code applies with `.font(.sectionHeading)`.
extension Font {
    /// The type for a section's heading: 22 points, rounded and semibold.
    static let sectionHeading = Font.system(size: 22, weight: .semibold, design: .rounded)
}
```

## S1 POSITIVE: a card surface that sets its container shape, and a nested row that follows it

Evidence: `CardSurface` makes its own `.rect(cornerRadius: 20)` the container shape, so the row's `ConcentricRectangle()` computes bottom corners that share the card's corner centers at the padding's inset, whatever the platform's default padding is. Corners far from the card's draw square, as Apple documents. The card's one fixed radius is a named constant in the appearance files, and the view file holds no radius at all. `CardSurface.swift` follows the order in Apple's `containerShape(_:)` example: padding, container shape, then the background. Checks: format pass, lint pass, typecheck pass on macOS and the iOS Simulator for both files.

`Appearance/CardSurface.swift`:

```swift
import SwiftUI

/// The card surface: padded content on the secondary background, in the app's card corners.
///
/// The card's shape is also the container shape, so a `ConcentricRectangle` inside the card draws corners that
/// share the card's corner centers at whatever inset it sits.
struct CardSurface: ViewModifier {
    /// The card's corner radius, the one fixed radius the app names.
    static let cornerRadius: CGFloat = 20

    /// Pads the content, makes the card shape its container shape and fills that shape behind it.
    func body(content: Content) -> some View {
        content
            .padding()
            .containerShape(.rect(cornerRadius: Self.cornerRadius))
            .background(.background.secondary, in: .rect(cornerRadius: Self.cornerRadius))
    }
}

/// The card surface as a view method.
extension View {
    /// Draws this view as a card whose nested concentric shapes follow its corners.
    func cardSurface() -> some View {
        modifier(CardSurface())
    }
}
```

App code:

```swift
import SwiftUI

/// The now-playing card: the track's title and artist above a full-width now-playing row.
struct NowPlayingCard: View {
    /// The track's title.
    let title: String
    /// The track's artist.
    let artist: String

    /// The track details on the card surface, with the row's bottom corners concentric with the card's.
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.headline)
            Text(artist)
                .foregroundStyle(.secondary)

            Label("Now Playing", systemImage: "speaker.wave.2")
                .frame(maxWidth: .infinity)
                .padding()
                .background(.quaternary, in: ConcentricRectangle())
        }
        .cardSurface()
    }
}
```

## S1 NEGATIVE: a nested row with its own radius

Evidence: the row's `.rect(cornerRadius: 12)` ignores the card's container shape. Its corners do not share the card's corner centers, and the number repeats a design value outside the appearance files. Checks: format pass, lint pass, typecheck pass on macOS and the iOS Simulator; only the radius lint that SKILL.md, section 1, describes would flag it, and the checked configuration has none. It differs from the positive app file in the row's shape and the body's comment; `CardSurface.swift` is unchanged.

```swift
import SwiftUI

/// The now-playing card: the track's title and artist above a full-width now-playing row.
struct NowPlayingCard: View {
    /// The track's title.
    let title: String
    /// The track's artist.
    let artist: String

    /// The track details on the card surface, with the row on a rounded fill.
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.headline)
            Text(artist)
                .foregroundStyle(.secondary)

            Label("Now Playing", systemImage: "speaker.wave.2")
                .frame(maxWidth: .infinity)
                .padding()
                .background(.quaternary, in: .rect(cornerRadius: 12))
        }
        .cardSurface()
    }
}
```

## G1 POSITIVE: content over artwork on a standard material

Evidence: a lyric line is content, so it sits on `.regularMaterial`, the content layer's material in the HIG, and leaves Liquid Glass to the controls and navigation layer. Checks: format pass, lint pass, typecheck pass on macOS and the iOS Simulator.

```swift
import SwiftUI

/// The lyric line being sung, shown over the album artwork.
struct LyricLine: View {
    /// The line being sung now.
    let line: String

    /// The line on a regular material capsule.
    var body: some View {
        Text(line)
            .padding()
            .background(.regularMaterial, in: .capsule)
    }
}
```

## G1 NEGATIVE: content on Liquid Glass

Evidence: `.glassEffect(in: .capsule)` puts content on the controls and navigation layer, which the HIG reserves for glass. The API accepts any view, so it compiles clean. Checks: format pass, lint pass, typecheck pass on macOS and the iOS Simulator; the defect is a judgment rule no tool sees. It differs from the positive in the background line and the body's comment.

```swift
import SwiftUI

/// The lyric line being sung, shown over the album artwork.
struct LyricLine: View {
    /// The line being sung now.
    let line: String

    /// The line on a glass capsule.
    var body: some View {
        Text(line)
            .padding()
            .glassEffect(in: .capsule)
    }
}
```

## V1 POSITIVE: one label style type for a variant no built-in style draws, applied to the container

Evidence: SwiftUI's label styles are `automatic`, `iconOnly`, `titleOnly` and `titleAndIcon` (SwiftUI interface, iOS 27 SDK), and none stacks the icon above the title, so the stacked look is a `LabelStyle` type in the appearance files with a static member, and call sites read `.labelStyle(.stacked)`. Every button in the row is a practice-mode choice, so the row applies the style once, beside the stock `.bordered` button style, and each button keeps a plain `Button(_:systemImage:action:)` label. Checks: format pass, lint pass, typecheck pass on macOS and the iOS Simulator for both files.

`Appearance/StackedLabelStyle.swift`:

```swift
import SwiftUI

/// A label drawn as its icon above its title, for a row of choices of equal weight.
struct StackedLabelStyle: LabelStyle {
    /// Stacks the icon, at the large image scale, above the title in the caption text style.
    func makeBody(configuration: Configuration) -> some View {
        VStack {
            configuration.icon
                .imageScale(.large)
            configuration.title
                .font(.caption)
        }
    }
}

/// The stacked label style as a static member, so a view applies it with `.labelStyle(.stacked)`.
extension LabelStyle where Self == StackedLabelStyle {
    /// The style for a row of choices of equal weight.
    static var stacked: StackedLabelStyle {
        StackedLabelStyle()
    }
}
```

App code:

```swift
import AppModel
import SwiftUI

/// The practice modes that a session can start in.
struct PracticeModeChoices: View {
    /// The session that the chosen mode starts.
    let session: PracticeSession

    /// One bordered button per mode, each with its icon stacked above its title.
    var body: some View {
        HStack {
            Button("Listen", systemImage: "ear") {
                session.startListening()
            }
            Button("Speak", systemImage: "mic") {
                session.startSpeaking()
            }
        }
        .buttonStyle(.bordered)
        .labelStyle(.stacked)
    }
}
```

## V1 NEGATIVE: the stacked look written at each call site

Evidence: each button builds the stack itself from an image and a text, so the stack and its modifiers live in every label instead of one style type. Every screen with this look has to copy them, and the copies drift. Checks: format pass, lint pass, typecheck pass on macOS and the iOS Simulator; the defect is a judgment rule no tool sees. It differs from the positive app file in both buttons and does not use `StackedLabelStyle.swift`.

```swift
import AppModel
import SwiftUI

/// The practice modes that a session can start in.
struct PracticeModeChoices: View {
    /// The session that the chosen mode starts.
    let session: PracticeSession

    /// One bordered button per mode, each with its icon stacked above its title.
    var body: some View {
        HStack {
            Button {
                session.startListening()
            } label: {
                VStack {
                    Image(systemName: "ear")
                        .imageScale(.large)
                        .accessibilityHidden(true)
                    Text("Listen")
                        .font(.caption)
                }
            }
            Button {
                session.startSpeaking()
            } label: {
                VStack {
                    Image(systemName: "mic")
                        .imageScale(.large)
                        .accessibilityHidden(true)
                    Text("Speak")
                        .font(.caption)
                }
            }
        }
        .buttonStyle(.bordered)
    }
}
```

Sources: Apple, [ConcentricRectangle](https://developer.apple.com/documentation/swiftui/concentricrectangle), [containerShape(_:)](https://developer.apple.com/documentation/swiftui/view/containershape(_:)), [LabelStyle](https://developer.apple.com/documentation/swiftui/labelstyle) and the `Font.custom` pages linked from SKILL.md, section 4; HIG, [Materials](https://developer.apple.com/design/human-interface-guidelines/materials) and [Typography](https://developer.apple.com/design/human-interface-guidelines/typography); the SwiftUI SDK interface for iOS 27.
