---
name: swiftui-design-tokens
description: "Use when adding or changing shared appearance in a SwiftUI app or its local package: stock styles and AccentColor, asset-catalog color sets and their contrast check, text styles and custom fonts, spacing, concentric corner shapes, materials and where Liquid Glass belongs, ButtonStyle, LabelStyle and ViewModifier variants, theme @Entry values, and a shared target's public color wrappers. Covers choices that compile clean when wrong: an unchecked AccentColor in Dark Mode with Increase Contrast, an accent-colored use that skipped its contrast check, internal generated color symbols, Color(.name) compiling through the wrong initializer, a wrapper that calls itself, string color names that resolve to clear, and macOS text that does not scale. Hand off build settings and the package manifest to xcode-project-settings; soft-deprecated APIs, view structure, glass mechanics and the text-style rule for views to swiftui-views; running the app, accessibility audits and rendered contrast checks to app-verification."
---

# SwiftUI design tokens

Shared appearance for an app built from this template: which value a view uses, where it is defined, and when a named token is worth adding at all. Apple ships the token system already: stock control styles, semantic colors, text styles, materials and the app's accent color. This skill covers the few values an app adds on top, the check each one needs, and the traps that compile clean. It ships no palette and no implementation; every value is the app's own choice.

Behavior this skill reports as observed was seen on Xcode 27 (Swift 6.4): builds of a package target holding an asset catalog, alone and linked into an app target, and a trial app's stock styles on the iOS 27 Simulator. Each labeled example states the checks it passed.

## 1. Confirm the project enforces

Run the project's toolchain preflight from the repository root and stop on a non-zero exit; do not install tools. In this template that is `./scripts/dev.swift doctor` after `./scripts/dev.swift bootstrap`. Then check each mechanism below. If one is missing, report the gap and apply its rule by hand while you work. This skill says nothing more about these rules.

- Asset-symbol generation at Xcode's defaults. The settings, their defaults and how to confirm them are in xcode-project-settings, section 5a, "Asset-catalog symbol settings". SwiftPM generates the same symbols for a package catalog.
- The app target's accent color setting, `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor`. The asset-catalog compiler's spec gives it no default. Xcode's app templates set it; the trial's XcodeGen-generated project had no value, so a `project.yml` sets it in the app target's `settings: base:`. Without it the AccentColor color set changes nothing.
- Warnings as errors in the package manifest, `.treatAllWarnings(as: .error)`, and on app targets. The self-call trap in section 3 fails the build only because of it.
- The soft-deprecated API scan, which flags `.cornerRadius`, `.foregroundColor` and `.accentColor`. In this template, `./scripts/dev.swift check` runs it; replacements are in swiftui-views, section 4.
- Lint rules for tokens, each a SwiftLint custom rule limited by `match_kinds` or a SwiftSyntax pass, each excluding the appearance files (section 9) except the first:
  - a string color name, `Color("…")` or `Color(_:bundle:)`, everywhere;
  - a raw color outside them: `Color(red:`, `Color(white:`, `Color(hue:`, `Color(.sRGB` or `.displayP3`, `UIColor`, `NSColor`, `#colorLiteral`;
  - a fixed font size outside them: `.system(size:` and `custom(_:fixedSize:)`;
  - a corner-radius literal outside them: `cornerRadius:` followed by a number;
  - optionally, an advisory warning for numeric `.padding(` and `spacing:` arguments.

## 2. Decide where a value comes from

Take the first rung that fits, and never put a literal at a call site:

1. A stock style or system value: the semantic styles, text styles, materials, built-in control styles and adaptive spacing in the table below.
2. The app's AccentColor color set, the first customization. It is the app's tint, so `.tint`, `Color.accentColor`, `.borderedProminent`, `.glassProminent` and every other standard control that uses a tint color take it app-wide, with no color named in code. Apple: "By default, your accent color applies to all views and controls in your app that use a tint color" ([Specifying your app's color scheme](https://developer.apple.com/documentation/xcode/specifying-your-apps-color-scheme)).
3. A named token, only for a value SwiftUI has no name for, such as a separate text role (section 3).

| Need | Stock first | Named token, only when stock has no name for it |
|---|---|---|
| Text and icon color | `.primary`, `.secondary`, `.tertiary` | a color set for a separate text role, such as `emphasisText` |
| Accent, primary action | AccentColor, through `.tint`, `.borderedProminent` and `.glassProminent` | none; change AccentColor's values instead |
| Surfaces | `.background`, `.background.secondary`, a `Material` | a color set such as `surface` |
| Status | the system colors, which adapt per appearance | a color set such as `danger` |
| Type | text styles: `.body`, `.headline`, `.title2` | a `Font` static built on a text style |
| Spacing | `.padding()`, a stack's default spacing, `.scenePadding()`, `.contentMargins(_:for:)` | a small named constant, or `@ScaledMetric` |
| Corners | `ConcentricRectangle`, `.capsule`, system container shapes | one named fixed radius |
| Control variants | `.bordered`, `.borderedProminent`, `.glass`, `.glassProminent`, `.controlSize`, the built-in label styles | a `ButtonStyle` or `LabelStyle` type |

Apple's HIG for [color](https://developer.apple.com/design/human-interface-guidelines/color), [typography](https://developer.apple.com/design/human-interface-guidelines/typography), [materials](https://developer.apple.com/design/human-interface-guidelines/materials) and [layout](https://developer.apple.com/design/human-interface-guidelines/layout) is the source for the system values. Never give a system color a new meaning.

## 3. Colors

AccentColor:

- AccentColor is a color set in the app target's asset catalog, named by the setting in section 1. Xcode's app templates create it.
- Its contrast role is the fill under a prominent button's label. The HIG says the system "applies the app accent color to the background in prominent buttons", and asks for color on a primary action's background rather than its text.
- Check it as the next bullets check every color set. A stock accent is no pass: observed on the iOS 27 Simulator, stock `.borderedProminent` with the system accent, in Dark Mode with Increase Contrast, drew its white label on a light blue fill at visibly low contrast. A custom AccentColor needs the check in all four appearances.
- AccentColor and `.tint` may color text and icons as well as fills: borderless buttons, links, and `.foregroundStyle(.tint)` do. Each use gets the contrast check in all four appearances: a fill against the label on it, text and icons against each background they are drawn on. Add a separate color only for a use that fails, a text-role color set (`.tint(_:)` for stock controls, `.foregroundStyle(_:)` for a view's own text); a use that passes needs none.
- On macOS, the system applies the app's accent color only while the person's accent color setting is multicolor; any other choice replaces it (HIG color, macOS). Check macOS screens with that setting at multicolor.

Every color set, AccentColor included:

- A custom color is a color set named for its role (`emphasisText`, `danger`, `surface`), never for its hue, and never a name SwiftUI already gives a style, such as `primary`, `secondary`, `tint` or `accentColor`.
- A custom text color is rarely needed: the semantic styles in the section 2 table adapt to appearance and vibrancy, which a fixed color does not. Add a text-role color set only where the contrast check fails for them.
- Give every color set four values: any, dark, high contrast, and dark with high contrast. The HIG asks for light, dark and increased-contrast variants even in a one-appearance app. A package catalog compiled all four on both platforms: `assetutil --info` listed default, `DarkAqua`, `AccessibilitySystem` and `AccessibilityDarkAqua` on macOS, and default, `Dark`, `HighContrastAny` and `HighContrastDark` on iOS.
- Give each color set the contrast roles it is checked in: a fill under content, such as a button's capsule under its white label, or content, such as text and icons on the app's backgrounds. Increase Contrast moves the two roles apart in Dark Mode: a white label gains contrast as its fill darkens, and text on a dark background gains as it lightens. A color set the app adds has one role. AccentColor is the one set that stock controls draw both ways, so it is checked in every role the app draws it in, each against the minimum in all four appearances.
- Check each color set in each role it is drawn in, in all four appearances. Compute the WCAG [contrast ratio](https://www.w3.org/TR/WCAG22/#dfn-contrast-ratio) from the relative luminance of the set's value and of what it meets: for a fill, the content drawn on it; for text or an icon, each background it is drawn on, measured against the backgrounds the app's screens use. Meet the [HIG minimum](https://developer.apple.com/design/human-interface-guidelines/accessibility) (4.5:1 for text up to 17 points, 3:1 at 18 points and for bold text), and give each increased-contrast value of a one-role set a higher ratio than its plain value. An AccentColor drawn in both roles cannot rise in both in Dark Mode, so it meets the minimum in each role and the use that misses gets its own color. The rendered check is the audit in app-verification.
- A string name finds nothing, and the build and test output say nothing about it. On Xcode 27 builds, `Color("NoSuchColor", bundle: .main)` resolved to red 0, green 0, blue 0, opacity 0, and so did the name of a color set in a package's catalog looked up from outside the package, because a package's catalog compiles into its own resource bundle (`<Package>_<Target>.bundle` inside the app), not the main bundle. The simulator's frameworks hold a "No color named" string, so a run-time console message is likely; none was looked for. That is why the string-name lint in section 1 has no exclusion.
- In the app's own catalog, name the generated symbol: `Color(.emphasisText)`. The build writes each color set's `ColorResource` at internal access into the module that owns the catalog, so app code sees its own. That follows from the access level observed in package builds; no app-target catalog was built.
- Leave `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS` at its default, `NO`; xcode-project-settings, section 5a, says why. Nothing was tested with it on.
- Image sets get `ImageResource` symbols in the same generated file, so the same rules should apply. That is inferred from the file's shape; no image set was built.

A shared target's catalog (section 9). The generated symbols are internal to that target, so it exposes public wrappers:

- Xcode and SwiftPM both write `static let <name> = DeveloperToolsSupport.ColorResource(name:bundle:)` with no access modifier into `GeneratedAssetSymbols.swift`, with `Bundle.module` as the bundle, and the asset-catalog compiler's spec has no access-level setting (observed on Xcode 27 builds). App code that names `ColorResource.emphasisText` fails: `'emphasisText' is inaccessible due to 'internal' protection level`.
- So the target declares one public member per color set, `public extension ShapeStyle where Self == Color { static var emphasisText: Color }`, and app code names the member in its role: `.foregroundStyle(.emphasisText)`.
- Inside the wrapper, spell the generated type: `Color(ColorResource.emphasisText)`. A bare `Color(.emphasisText)` picks the generated symbol by overload ranking alone. Rename the color set and it resolves to the wrapper itself through `Color`'s generic `ShapeStyle` initializer: the getter calls itself, and the build fails only because warnings are errors (`function call causes an infinite recursion`; with warnings as warnings the build succeeds). The explicit spelling fails instead with `type 'ColorResource' has no member 'emphasisText'`.
- In app code, `Color(.emphasisText)` then compiles, but through `Color.init<T: Hashable & ShapeStyle>(_:)` (SwiftUICore interface, macOS 27 SDK, line 17223), which reaches the wrapper, not the generated symbol. A passing `Color(.name)` beside a shared target is no evidence that the generated symbol is visible, and the spelling misleads a reader into thinking it is. To test visibility, write `Color(ColorResource.name)` in the app.

Examples, required reading before you set AccentColor, add a color set or a wrapper, or color anything from app code: [references/colors.md](references/colors.md).

## 4. Type

- Text styles are the type scale. The rule for views (text styles, not fixed sizes, on iOS) is in swiftui-views, section 12.
- A custom font earns a `Font` static only when several views share it; one view composes the text style inline. The static is built on a text style: `Font.system(.title2, design: .rounded, weight: .semibold)`, or `Font.custom(_:size:relativeTo:)` for a bundled face, with the text style of the role it fills. `Font.custom(_:size:)` scales with the body style whatever its role, and `custom(_:fixedSize:)` and `system(size:)` do not scale (Apple: [custom(_:size:)](https://developer.apple.com/documentation/swiftui/font/custom(_:size:)), [custom(_:size:relativeTo:)](https://developer.apple.com/documentation/swiftui/font/custom(_:size:relativeto:)), [custom(_:fixedSize:)](https://developer.apple.com/documentation/swiftui/font/custom(_:fixedsize:))).
- The fixed-size lint excludes the appearance files, so review them yourself.
- A custom number that should grow with text, such as an icon size, is `@ScaledMetric(relativeTo:)`.
- On macOS 27, SwiftUI maps `dynamicTypeSize` to neither text-style sizes nor `@ScaledMetric`. A headless probe on Xcode 27 builds resolved body at 13 points and title 2 at 17 at every size from `.xSmall` to `.accessibility5`, rendered body text 16 points high at four sizes across that range, and kept a `@ScaledMetric(relativeTo: .body)` of 100 at 100. A `.system(size: 26)` control resolved to 26, so the probe measures size. AppKit has no content-size API. On macOS, use text styles for the platform's sizes and do not promise or build scaling.
- Open: whether a macOS system text-size setting changes a running window's fonts or its `dynamicTypeSize`. That needs a GUI session and has not been checked. Say so when a macOS change depends on it.

## 5. Spacing and layout

- Start from the adaptive defaults in the section 2 table; they adapt per platform.
- A spacing number lives in the appearance files, as a named constant when several views share it. Use `@ScaledMetric` for spacing that should grow with text on iOS.
- Keep the spacing tokens few. SwiftUI has no system spacing scale to mirror, so a token enum adds little over the defaults; the consistency comes from keeping numbers out of call sites.

## 6. Corner shapes

- A surface that holds other rounded shapes sets `.containerShape(_:)` with a `RoundedRectangularShape`, such as `.rect(cornerRadius:)`. Shapes inside it are `ConcentricRectangle()`, which computes each corner from the container's (iOS and macOS 26).
- A corner far from the container's corner can compute to zero radius and draw square. Use `.concentric(minimum:)` where it must stay rounded ([ConcentricRectangle](https://developer.apple.com/documentation/swiftui/concentricrectangle)).
- A fixed radius is a named constant in the appearance files, used through `.rect(cornerRadius:)`.

## 7. Materials and Liquid Glass

How to apply glass is in swiftui-views, section 11. This section covers which layer gets it.

- Liquid Glass is the controls and navigation layer. Content gets a standard `Material` (`.regularMaterial` and its siblings), never glass (HIG materials).
- Put color on glass sparingly: tint only the primary action's background (HIG color). The prominent button styles already do that with AccentColor.
- Use the clear glass variant only over rich media, with a dimming layer where the content behind it is bright.
- Glass and materials both change with Reduce Transparency and Increase Contrast. Choose them by meaning, never for their apparent color.

## 8. Variants and theming

- Prefer a built-in style (section 2) before writing one.
- A variant that no built-in style draws is a `ButtonStyle`, `LabelStyle` or `ToggleStyle` type in the appearance files, with a static member so call sites read `.labelStyle(.stacked)`. Use a `ViewModifier` for a surface that is not a control. A `ButtonStyle` keeps the system's interaction and reads `configuration.isPressed`. `ButtonStyleConfiguration` carries only `role`, `label` and `isPressed`, so a style draws its disabled look from `@Environment(\.isEnabled)` in a view the style returns; write a `PrimitiveButtonStyle` only to change the interaction.
- Apply a style to the control, or to a container whose controls all share its role. A style for one role, such as the primary action, never goes on a container that also holds controls with other roles.
- A theme value that differs by subtree is an `@Entry` environment value declared in the appearance files. Its default follows swiftui-views, section 6.

Examples for type, shapes, glass and variant styles: [references/type-shapes-and-variants.md](references/type-shapes-and-variants.md).

## 9. Where it lives

- By default, the app target, which holds views and assets in this template's app shape (xcode-project-settings, section 3). Color sets, AccentColor included, go in the app's asset catalog. The Swift appearance definitions (`Font` statics, named constants, styles, surface modifiers and `@Entry` values) go in one folder of the app target, `Appearance/` by default; those are the appearance files that the section 1 lints exclude. All of it stays internal.
- A shared target only when several targets share tokens, such as an app and its extensions: a `DesignSystem` library target and product in the local package holds the shared color sets in its own catalog, one public wrapper per color set (section 3), and the shared statics, styles and modifiers as `public` members. Each target links the product (in an XcodeGen project, a `project.yml` dependency), and the section 1 lints exclude its sources too. AccentColor stays in each app target's catalog, because the setting in section 1 names a color in the catalog of the target it is set on.
  - SwiftPM finds a catalog in the target's sources without a `resources:` entry; `swift package dump-package` shows `resources []` for such a target.
  - The target takes the package's strictness and its nonisolated default. Both are xcode-project-settings, sections 5 and 6.
- When you preview a style or surface, cover light and dark (`.preferredColorScheme`) and the largest type size (`.dynamicTypeSize(.accessibility5)`); preview mechanics are in swiftui-views, section 10. Increased contrast has no public setter: `colorSchemeContrast` is read-only. A probe may set the underscored `_colorSchemeContrast`; product code never does. Check contrast variants in the iOS audit states (app-verification, section 8).
- What a token's documentation comment says is swift-doc-comments.

## 10. Figma, if the app uses it

Figma variables have collections and modes, such as light and dark. The variables REST API needs an Enterprise plan, and Figma documents no exporter to asset catalogs, so any sync is custom code that writes color-set `Contents.json` files. Start from [Figma's variables guide](https://help.figma.com/hc/en-us/articles/15339657135383-Guide-to-variables-in-Figma) and the [REST variables reference](https://developers.figma.com/docs/rest-api/variables/).

## 11. Before you finish

1. Run the project's format and check entry points; never hand-format. In this template, run `./scripts/dev.swift fix`, then `./scripts/dev.swift check`.
2. Review what no tool checks, in what you changed: a stock style and AccentColor considered before any named token, and a token only where SwiftUI has no name (section 2); role names that SwiftUI does not already use, one contrast role per color set, and AccentColor and every color set checked in each role it is drawn in, in four appearances, with each increased-contrast value higher for a one-role set (3); wrappers that spell `ColorResource` in a shared target (3); custom type on text styles (4); nested corners (6); the glass layer (7); variants as style types (8); and placement in the app target unless several targets share the token (9).
3. A new, renamed or deleted color set is proven only by building the app, and the shared target when there is one; in a shared target, renaming the set should break the explicit wrapper at compile time. What AccentColor recolors is proven only by running the app. Running it, audits and rendered contrast checks belong to app-verification.

Hand-offs:

- xcode-project-settings: build settings, including the asset-symbol settings (section 5a), targets, the package manifest and deployment floors.
- swiftui-views: soft-deprecated APIs, view structure, `@Entry` defaults, glass mechanics, and text styles and accessibility in views.
- app-verification: builds and tests of the app, accessibility audits including contrast and Dynamic Type states.
- swift-doc-comments: what a documentation comment on a token says.
