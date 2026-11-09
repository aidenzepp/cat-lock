---
name: app-verification
description: "Prove SwiftUI app behavior headlessly with tests, accessibility audits and localization checks, then report only what actually ran. Use when writing or running Swift Testing or XCUITest tests, testing an @Observable model, running swift test or xcodebuild test, adding performAccessibilityAudit or VoiceOver checks, checking String Catalog translations, reading xcresult output, or reporting that something is verified."
---

# App verification

Format and lint prove no behavior. This skill covers what to run to prove behavior, and how to say what was and was not run.

## 1. Preflight

Run the project's toolchain preflight from the repository root (here `./scripts/dev.swift doctor`). Stop on a non-zero exit. Never install tools to get past it; name the project's setup step (here `./scripts/dev.swift bootstrap`) and let the operator run it.

## 2. Confirm the project enforces

Check each item exists before relying on it. If one is missing, report the gap and apply the rule by hand.

- Test targets use the strict build settings, so warnings fail test builds too (`config/Strict.xcconfig` here).
- Test sources are linted by the same configuration as production code. Only a child profile for test paths may differ: it exempts documentation, and the keyword rule's `excluded:` test paths (the rule on `throws`, `rethrows` and `catch`) let test functions throw.
- A CI step builds and tests every app scheme on pinned destinations, and builds and tests the local package's iOS slice. If none exists, state that nothing in CI proves app behavior.
- A String Catalog check reports untranslated entries. If none exists, run the checks in section 9 by hand.

Do not restate or weaken what those tools enforce. If a lint or format rule rejects a test, change the test.

## 3. What format and lint do not prove

- Behavior: only a run proves it.
- Accessibility and localization: only UI audits and catalog checks see them.
- Never report an unexecuted build, test or CI check as passing; AGENTS.md states the rule.

## 4. Framework choice

- Swift Testing for every test that does not drive the UI.
- XCTest only for `XCUIApplication` UI tests and `XCTMetric` performance tests, which Swift Testing does not support.
- Mixing XCTest assertions into a Swift Testing test: the `swift-test-design` skill, heading "Swift traps", states the rule. See the NEGATIVE example in [references/examples.md](references/examples.md).
- Docs: [Swift Testing](https://developer.apple.com/documentation/testing), [migrating from XCTest](https://raw.githubusercontent.com/swiftlang/swift-testing/main/Sources/Testing/Testing.docc/MigratingFromXCTest.md).

## 5. Writing tests

Test design belongs to other skills:

- What to test, boundaries, doubles and fakes, optionals with `#require`, matching `Result` cases, callback and observation events, `#expect(throws:)`, `.serialized`, `@MainActor` suites and where a test lives: `swift-test-design`.
- The seam ladder that decides what a test substitutes: `swift-domain-contracts`, heading "Dependencies and effects".

Read [references/examples.md](references/examples.md) before writing a model test. It holds the labeled examples the rules below describe.

- A model test involves no view; views get UI tests (heading "Framework choice" and heading "Accessibility audits").
- A table of inputs uses `@Test(arguments:)`, so each case fails alone.
- A known failure uses `withKnownIssue` or `.bug`, never a commented-out test.

## 6. Running tests

Package (macOS host, headless):

```sh
swift test --parallel --package-path <package>
```

`swift test` builds for the host only. Build and test the package's iOS slice through `xcodebuild` with an iOS Simulator destination, using the package's scheme.

App targets:

1. Discover, do not guess: read the scheme name from a shared scheme file under `<project>.xcodeproj/xcshareddata/xcschemes/`, then run `xcodebuild -showdestinations -scheme <scheme> -derivedDataPath <dir>` and `xcodebuild -showTestPlans -scheme <scheme> -derivedDataPath <dir>`. Pass `-scheme` and `-derivedDataPath` together on `-showdestinations`, `-showTestPlans`, `-showBuildSettings`, build and test: `-derivedDataPath` without `-scheme` is refused, and a bare `xcodebuild -list` writes the default DerivedData when the project has a package dependency, so `-list` is not used for discovery.
   - An Xcode-created project keeps its shared schemes in that folder.
   - An XcodeGen project has no scheme file until `project.yml` declares one under the top-level `schemes:` key; XcodeGen then generates a shared scheme there. Without that key Xcode creates the schemes implicitly, and only `-list` shows them. Add the key rather than using `-list`.
   - Observed on Xcode 27 builds: with a declared scheme, `-showdestinations`, `-showTestPlans`, `-showBuildSettings` and a build all accepted `-scheme` with `-derivedDataPath` and wrote only under that path. `-showTestPlans` prints "The scheme <scheme> is not configured to use test plans." when none exist; that is not a failure.
2. Pin the destination: `-destination 'platform=macOS'` or `-destination 'platform=iOS Simulator,name=<device>,OS=<version>'`. Confirm the `OS=` key against `-showdestinations` output first.
3. Pass `-resultBundlePath` with a new path every run; `xcodebuild` refuses an existing path.
4. Build once, test many with `build-for-testing` then `test-without-building` when running more than once.

## 7. Reading results

Read the result bundle as data, not the console tail:

```sh
xcrun xcresulttool get test-results summary --path <bundle>
xcrun xcresulttool get test-results tests --path <bundle>
xcrun xcresulttool export attachments --path <bundle> --output-path <dir> --only-failures
```

Two Xcode log lines are benign and are not problems in the project's code. Exclude them by text when you claim zero warnings; every other `warning:` line counts:

- `IDERunDestination: Supported platforms for the buildables in the current scheme is empty.` (xcodebuild's own stderr, on `-showdestinations`, `-showBuildSettings` and builds).
- `appintentsmetadataprocessor ... warning: Metadata extraction skipped, no AppIntents.framework dependency found` (the App Intents step, for a target that has no App Intents dependency).

Report counts, failures by test name and the destination run. Include coverage only when the run enabled it (`-enableCodeCoverage YES`, then `xcrun xccov view --report --json <bundle>`).

## 8. Accessibility audits

The audit is the only runnable accessibility check. It needs a simulator (iOS) or a logged-in macOS GUI session, driven by `xcodebuild`.

- One XCUITest per top-level screen state calls `try app.performAccessibilityAudit(for: .all)` with `continueAfterFailure = true`. The audit records its own failures; add no assertions.
- A handler that returns `true` hides that issue. Each one carries a comment giving the reason.
- The audit sees one state per call, so run each state separately.
  - iOS states: default, largest accessibility size, dark, Increase Contrast, and dark with Increase Contrast together. The combined state is its own run: a color that passes in each setting alone can fail when both apply, because a dark high-contrast variant can be darker than the plain dark one. Set the states between runs with `xcrun simctl ui <device> content_size accessibility-extra-extra-extra-large`, `appearance dark` and `increase_contrast enabled`, and restore them after.
  - macOS: default state only; `simctl ui` has no macOS counterpart.
- Audit types differ by platform. `.dynamicType`, `.textClipped` and `.trait` exist on iOS only; `.action` and `.parentChild` on macOS only.
- Each custom control and each image-only button gets one test asserting the VoiceOver speech: `XCUIDevice.shared.voiceOverService`, then `currentSpeech().utterance`. The audit proves a label exists, not that it is right. This API's behavior is unverified here; run it before depending on it.
- No tool audits color-only cues, motion, captions or reading order. List them as "needs human review" in the report.
- Docs: [performAccessibilityAudit](https://developer.apple.com/documentation/xcuiautomation/xcuiapplication/performaccessibilityaudit(for:_:)), [WWDC23 Perform accessibility audits](https://developer.apple.com/videos/play/wwdc2023/10035/).
- Accessibility rules for the view code itself live in `swiftui-views`.

## 9. Localization checks

- Missing translations show only in Xcode's editor unless the project's catalog check reports them. Inspect a catalog headlessly with `xcrun xcstringstool print <catalog>`. Read the `.xcstrings` JSON from a real catalog before writing any tool that decodes it.
- A stale entry (translated, no longer in code) is deleted only after confirming the string is gone from the source. `xcstringstool sync` marks staleness; `--skip-marking-strings-stale` suppresses it.
- Layout under other languages: run the UI tests with a test-plan configuration that sets Application Language and Region, or with `-testLanguage` and `-testRegion`. Check the pseudolanguage identifier in Apple's documentation before using one.
- Docs: [String Catalogs](https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog), [test plans](https://developer.apple.com/documentation/xcode/organizing-tests-to-improve-feedback).
- Localization rules for the view code itself live in `swiftui-views`.

## 10. What CI must run

- The project's format and lint check.
- `swift test` for the local package, and its iOS slice through `xcodebuild`.
- Every app scheme's build and tests on pinned macOS and iOS Simulator destinations, UI audits included.
- The catalog check.

A green format-and-lint run alone is not a green build. When CI lacks a step, say which one.

## Hand-offs

- Build settings, isolation defaults, deployment floor: `xcode-project-settings`.
- View code, accessibility and localization in code: `swiftui-views`.
- Result and error design, task lifetime, unchecked invariants: `swift-isolation`.
- Test design, doubles, fakes and test placement: `swift-test-design`.
- The seam ladder: `swift-domain-contracts`.
