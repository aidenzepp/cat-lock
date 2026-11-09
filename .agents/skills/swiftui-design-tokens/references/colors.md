# Colors: labeled examples

Read before you set AccentColor, add a color set or a color wrapper, or color anything from app code. C1 to C3, C6 and C7 use the app's own asset catalog, the default; C4, C5 and C8 use a shared target's catalog (SKILL.md, section 9). Each negative is made from a positive's files, and its evidence names every line it changes.

How the examples were checked. Each code block is the complete file that was checked, unchanged. Every Swift file follows swift-code-layout and passed the template's pinned SwiftFormat (`--lint --config .swiftformat`) and pinned SwiftLint (`lint --strict --config .swiftlint.yml`), run from the template root. Each was typechecked on Xcode 27 (Swift 6.4) with `xcrun swiftc -typecheck -swift-version 6 -strict-memory-safety -warnings-as-errors` and the four upcoming features (`NonisolatedNonsendingByDefault`, `InferIsolatedConformances`, `ExistentialAny`, `MemberImportVisibility`), for macOS and for the iOS Simulator. App files add `-default-isolation MainActor`; the shared target's files take no isolation flag, because the package is nonisolated. Each shared target's `Colors.swift` was also compiled with `xcrun swiftc -emit-module` and the same flags, which runs the later diagnostics that a plain typecheck skips, such as infinite recursion, and app files that import `DesignSystem` were checked against the module emitted from C4. No asset catalog was compiled for these examples, so each check put a stand-in for the build's generated symbol beside the files of the module that owns the color set: `static let emphasisText = ColorResource(name: "EmphasisText", bundle: .main)`, at internal access, in an extension of `ColorResource`. Omitted surroundings: that stand-in, and `PracticeSession`, a package model in an `AppModel` target, a `public` `@MainActor` `@Observable` `final class` with the method the button calls, as swiftui-views, section 6, describes. The JSON block was checked to parse. Claims about compiled catalogs and resolved colors come from earlier Xcode 27 builds of a package catalog and the probes SKILL.md, section 3, reports.

## C1 POSITIVE: AccentColor in the app's catalog, and the primary action in a stock style

Evidence: the app's AccentColor color set, named by the app target's `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME`, is the app's tint, so the stock `.borderedProminent` style fills the button with it and the view names no color. Here AccentColor is a fill under the button's white label, the role the HIG gives the accent color in prominent buttons. Its four values are the app's own, chosen by the check in SKILL.md, section 3: the white label against each value, at the HIG minimum, and each other use of the accent checked the same way (C3). Stock values are no pass: on the iOS 27 Simulator, stock `.borderedProminent` with the system accent, in Dark Mode with Increase Contrast, drew the white label on a light blue fill at visibly low contrast. Checks: format pass, lint pass, typecheck pass on macOS and the iOS Simulator; the JSON parses. That the accent fills a prominent button was seen with the system accent; no custom AccentColor was run.

The color set, `AccentColor.colorset/Contents.json` in the app's asset catalog. It shows the structure only: each `<red>`, `<green>` and `<blue>` stands for a component the app chooses and checks, so the file is not a usable color set until they are filled in. Every color set in C2 to C8 has the same shape. Omitted: the catalog's own `Contents.json`, which holds only the `info` block.

```json
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "<blue>",
          "green" : "<green>",
          "red" : "<red>"
        }
      },
      "idiom" : "universal"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "<blue>",
          "green" : "<green>",
          "red" : "<red>"
        }
      },
      "idiom" : "universal"
    },
    {
      "appearances" : [
        {
          "appearance" : "contrast",
          "value" : "high"
        }
      ],
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "<blue>",
          "green" : "<green>",
          "red" : "<red>"
        }
      },
      "idiom" : "universal"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        },
        {
          "appearance" : "contrast",
          "value" : "high"
        }
      ],
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "<blue>",
          "green" : "<green>",
          "red" : "<red>"
        }
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

App code:

```swift
import AppModel
import SwiftUI

/// The primary action that ends a practice session.
struct KeepPracticingButton: View {
    /// The finished session, which starts the next one.
    let session: PracticeSession

    /// The action in the bordered prominent style, which fills the button with the app's accent color.
    var body: some View {
        Button("Keep Practicing") {
            session.keepPracticing()
        }
        .buttonStyle(.borderedProminent)
    }
}
```

## C2 POSITIVE: a separate text role in the app's own catalog

Evidence: the streak figure is text that the app colors itself, on the app's backgrounds. Here the check in SKILL.md, section 3, run on AccentColor as this figure's text (C3), failed in at least one appearance: the accent's values were tuned as a fill under a white label, and Increase Contrast darkens a fill in Dark Mode, where text on a dark background needs to lighten. SwiftUI has no name for an emphasis color tuned as text, so the failing use gets a named token: an `EmphasisText` color set in the app's catalog, in C1's shape, whose values darken on light backgrounds and lighten on dark ones, more so with Increase Contrast, each checked against the backgrounds the figure is drawn on. The app module owns the catalog, so `Color(.emphasisText)` names its own generated symbol, with no wrapper. Checks: format pass, lint pass, typecheck pass on macOS and the iOS Simulator, against the stand-in symbol.

```swift
import SwiftUI

/// The practice streak that the progress screen leads with.
struct StreakFigure: View {
    /// Consecutive days with at least one practice session.
    let days: Int

    /// The day count in the large title text style and the emphasis text color.
    var body: some View {
        Text(days, format: .number)
            .font(.largeTitle)
            .foregroundStyle(Color(.emphasisText))
    }
}
```

## C3 POSITIVE: the accent color as text, after the check

Evidence: `.foregroundStyle(.tint)` draws the figure in AccentColor, the same color set that fills C1's button, and the app names no second color. That is sound only because the use was checked: the accent's four values were measured as text against each background the figure is drawn on, at the HIG minimum (SKILL.md, section 3), and each passed, the Dark Mode increased-contrast value included, where a fill-tuned accent is likeliest to fail. The values are the app's own and none is shown here. Had one failed, the figure would take C2's separate color; a pass needs none, so a separate color is added only for a use that fails. The check's result is the evidence; the line itself looks the same either way. Checks: format pass, lint pass, typecheck pass on macOS and the iOS Simulator; the contrast check is a judgment rule no tool sees, and only a rendered check in the dark, increased-contrast state confirms it (app-verification). It differs from C2 in the color line and the body's comment.

```swift
import SwiftUI

/// The practice streak that the progress screen leads with.
struct StreakFigure: View {
    /// Consecutive days with at least one practice session.
    let days: Int

    /// The day count in the large title text style and the app's tint, which the app checked as text.
    var body: some View {
        Text(days, format: .number)
            .font(.largeTitle)
            .foregroundStyle(.tint)
    }
}
```

## C4 POSITIVE: a shared target's public wrapper that names `ColorResource`, and app code that uses it

Evidence: once several targets share the emphasis color, its color set moves to the `DesignSystem` target's catalog (SKILL.md, section 9). The build generates `ColorResource.emphasisText` at internal access in that target, so the public `ShapeStyle` member is the only thing the app can name: the app writes `.foregroundStyle(.emphasisText)`, and an app file that writes `Color(ColorResource.emphasisText)` fails with `error: 'emphasisText' is inaccessible due to 'internal' protection level`. The getter spells `ColorResource`, so with the stand-in symbol removed, as renaming the color set removes the generated one, the file fails at `Colors.swift:14:29: error: type 'ColorResource' has no member 'emphasisText'` instead of compiling into something else. Checks: format pass and lint pass for both files; on macOS and the iOS Simulator, `-emit-module` pass for `Colors.swift` with the stand-in, and typecheck pass for the app file against the emitted module; the rename failure above is the intended one.

`Sources/DesignSystem/Colors.swift`:

```swift
import SwiftUI

/// The shared colors that app code may use, each read from a color set in this target's asset catalog.
///
/// The build generates a `ColorResource` for each color set at internal access, so the app cannot name it.
/// These public members are the app's only way to reach the catalog.
public extension ShapeStyle where Self == Color {
    /// Text and icons that carry emphasis on the app's backgrounds, such as the figure a screen leads with.
    ///
    /// Its color set darkens on light backgrounds and lightens on dark ones, more so with Increase Contrast.
    static var emphasisText: Color {
        // Name the generated type: a bare `.emphasisText` also matches this property through `Color`'s generic
        // `ShapeStyle` initializer.
        Color(ColorResource.emphasisText)
    }
}
```

App code:

```swift
import DesignSystem
import SwiftUI

/// The practice streak that the progress screen leads with.
struct StreakFigure: View {
    /// Consecutive days with at least one practice session.
    let days: Int

    /// The day count in the large title text style and the emphasis text color.
    var body: some View {
        Text(days, format: .number)
            .font(.largeTitle)
            .foregroundStyle(.emphasisText)
    }
}
```

## C5 NEGATIVE: a wrapper whose getter can resolve to itself

Evidence: the getter writes `Color(.emphasisText)`. While the generated symbol exists, overload ranking picks `Color(_: ColorResource)`, so it compiles. Remove the symbol, as renaming the color set does, and the only `.emphasisText` left is this property, reached through `Color`'s generic `ShapeStyle` initializer: `-emit-module` fails at `Colors.swift:12:16: error: function call causes an infinite recursion` on both platforms. Without `-warnings-as-errors` the same compile succeeds with that diagnostic as a warning, leaving a getter that calls itself (not run), and a plain `-typecheck` reports nothing either way. Earlier Xcode 27 builds of a package catalog failed the same way after a real rename. Checks: format pass, lint pass, typecheck and `-emit-module` pass on macOS and the iOS Simulator as written; the defect is a judgment rule no tool sees until the rename. It differs from C4's `Colors.swift` only in that getter, which also loses C4's comment.

```swift
import SwiftUI

/// The shared colors that app code may use, each read from a color set in this target's asset catalog.
///
/// The build generates a `ColorResource` for each color set at internal access, so the app cannot name it.
/// These public members are the app's only way to reach the catalog.
public extension ShapeStyle where Self == Color {
    /// Text and icons that carry emphasis on the app's backgrounds, such as the figure a screen leads with.
    ///
    /// Its color set darkens on light backgrounds and lightens on dark ones, more so with Increase Contrast.
    static var emphasisText: Color {
        Color(.emphasisText)
    }
}
```

## C6 NEGATIVE: a string color name in app code

Evidence: `Color("EmphasisText")` compiles whatever the name says. It searches the app's main bundle at run time ([init(_:bundle:)](https://developer.apple.com/documentation/swiftui/color/init(_:bundle:))), so it finds the color set only while the name matches and the set stays in the app's catalog; a typo, a rename or a move to a shared target draws the figure clear, with no build or test-output diagnostic (a run-time console message is likely and was not looked for). On Xcode 27 builds, `Color("NoSuchColor", bundle: .main)` resolved to red 0, green 0, blue 0, opacity 0, and so did the name of a color set in a package's catalog looked up from outside the package. This line was typechecked, not run. Checks: format pass, lint pass, typecheck pass on macOS and the iOS Simulator; only the string-name lint that SKILL.md, section 1, describes would flag it, and the checked configuration has none. It differs from C2 in the color line.

```swift
import SwiftUI

/// The practice streak that the progress screen leads with.
struct StreakFigure: View {
    /// Consecutive days with at least one practice session.
    let days: Int

    /// The day count in the large title text style and the emphasis text color.
    var body: some View {
        Text(days, format: .number)
            .font(.largeTitle)
            .foregroundStyle(Color("EmphasisText"))
    }
}
```

## C7 NEGATIVE: a raw color in app code

Evidence: `Color(white: 0.5)` is one value for every appearance. It has no dark or increased-contrast value, so its contrast cannot rise with Increase Contrast, and the check in SKILL.md, section 3, fails by construction. It also defines a color outside the asset catalog, where no review of the color sets sees it. Checks: format pass, lint pass, typecheck pass on macOS and the iOS Simulator; only the raw-color lint that SKILL.md, section 1, describes would flag it, and the checked configuration has none. It differs from C2 in the color line and the body's comment.

```swift
import SwiftUI

/// The practice streak that the progress screen leads with.
struct StreakFigure: View {
    /// Consecutive days with at least one practice session.
    let days: Int

    /// The day count in the large title text style and a fixed gray.
    var body: some View {
        Text(days, format: .number)
            .font(.largeTitle)
            .foregroundStyle(Color(white: 0.5))
    }
}
```

## C8 NEGATIVE: `Color(.emphasisText)` in app code beside a shared target

Evidence: in C2 this spelling named the app's own generated symbol. Here that symbol is internal to `DesignSystem`, so the line compiles through `Color.init<T: Hashable & ShapeStyle>(_:)` (SwiftUICore interface, macOS 27 SDK, line 17223), which takes C4's public wrapper and wraps one `Color` in another. With the wrapper made internal, the same line fails at `StreakFigure.swift:13:37: error: 'emphasisText' is inaccessible due to 'internal' protection level`, with the note pointing at `DesignSystem.ColorResource.emphasisText`. So the line compiles only because of the wrapper, proves nothing about whether the generated symbol is visible, and teaches a reader the wrong mechanism. The visibility test is `Color(ColorResource.emphasisText)` in app code, which fails with the same error while the public wrapper exists (C4). Checks: format pass, lint pass, typecheck pass on macOS and the iOS Simulator against the module emitted from C4; the defect is a judgment rule no tool sees. It differs from C4's app file in the color line.

```swift
import DesignSystem
import SwiftUI

/// The practice streak that the progress screen leads with.
struct StreakFigure: View {
    /// Consecutive days with at least one practice session.
    let days: Int

    /// The day count in the large title text style and the emphasis text color.
    var body: some View {
        Text(days, format: .number)
            .font(.largeTitle)
            .foregroundStyle(Color(.emphasisText))
    }
}
```

Sources: Apple, [Specifying your app's color scheme](https://developer.apple.com/documentation/xcode/specifying-your-apps-color-scheme), [init(_:bundle:)](https://developer.apple.com/documentation/swiftui/color/init(_:bundle:)) and [Bundling resources with a Swift package](https://developer.apple.com/documentation/xcode/bundling-resources-with-a-swift-package); HIG, [Color](https://developer.apple.com/design/human-interface-guidelines/color) and [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility), whose contrast table sets 4.5:1 for text up to 17 points and 3:1 at 18 points and for bold text; WCAG 2.2, [contrast ratio](https://www.w3.org/TR/WCAG22/#dfn-contrast-ratio); `AssetCatalogCompiler.xcspec` in Xcode 27, for `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME`; the SwiftUICore SDK interface; a trial app's stock styles on the iOS 27 Simulator in Dark Mode with Increase Contrast; earlier Xcode 27 builds of a package catalog.
