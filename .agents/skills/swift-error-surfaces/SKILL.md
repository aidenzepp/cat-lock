---
name: swift-error-surfaces
description: "Write or review the text a person sees when something fails in a SwiftUI app: alert titles and messages, inline validation, empty and error states, and the user-facing text an error type carries. Use when adding or changing an alert, a LocalizedError, errorDescription, failureReason, recoverySuggestion, an error enum's display text, alert(isPresented:error:) or alert(error:), or when localizedDescription appears on screen. Covers what the compiler accepts but shows the person wrongly. Hand off failure-path types and cancellation to swift-isolation, view code and localization keys to swiftui-views, tests of failure paths to swift-test-design, and running tests and accessibility audits to app-verification."
---

# Swift error surfaces

The words a person reads when an operation fails. The compiler accepts any `String` here, so a wrong title, a system placeholder or an alert for a cancelled task builds clean. Tools own the mechanical rules. This skill covers what the text must say and where it comes from.

## 1. Confirm the project enforces

Check each item exists. If one is missing, report the gap and apply the rule by hand. This skill says nothing more about these rules.

- Warnings are errors, so a warning the compiler gives on this code stops the build. A non-static `comment:` and an overload above the deployment target are compile errors whatever the setting.
- SwiftLint `missing_docs` at every access level, so the types that carry display text are documented.
- The `throws`, `rethrows` and `catch` custom rule and `no_discardable_result`, so failures reach this skill as `Result` values (see `swift-isolation`, "Failure paths").
- No tool in this template stops `localizedDescription` from reaching a view or a log line shown to a person. Search for it in review.

## 2. Start from the failure's cases

Write one message per case of the typed error. Each case is already one thing a caller can act on, so each message names that action. Error design, `Result` and cancellation belong to `swift-isolation`; do not restate them.

- `.cancelled` has no message. The task's owner moved on, so nobody is waiting for a result. Never present it.
- A case with no action for the person ("trying again will not help") says so and names the way out: another file, a setting, support.
- Ask five questions of every message: what happened, why (when known and safe to say), what to do next, what was kept or lost, where to go if that fails.

## 3. Message shape

Use this order and drop what the surface cannot hold: what happened, why or which constraint, what to do next, fallback.

- A blocking alert carries a title and, when it adds something, a message.
- An inline error is one sentence beside the field.
- Preserve the person's input and say what was kept: "Your file is unchanged."

## 4. Tone

Be direct and neutral, as Apple's [alerts guidance](https://developer.apple.com/design/human-interface-guidelines/alerts) asks.

- Instructions, not accusations: "Enter a name", not "You didn't enter a name".
- No jokes, no exclamation marks, no apology padding, no blame of the user, a server or a provider.
- Keep one word for one thing across the app.

## 5. Invalid input

Show the value and the constraint, unless the value is a secret.

- "Enter a 5-digit ZIP code. You entered “4872953”." names both.
- For a secret, name the field and the rule, never the value.
- Format numbers and dates with format styles in the interpolation, as `swiftui-views` says, never `String(format:)`.

## 6. Alerts in SwiftUI

- The title says what happened, as a short phrase. Never "Error", an error code or "Something went wrong".
- Buttons are verbs that name the action. "OK" only when the alert is purely informational. The cancelling button has `role: .cancel` and the title "Cancel".
- Add a message only when it says something the title does not. Do not explain what the buttons do.
- Present with the `alert` modifiers (`swiftui-views`, the Navigation heading). To show a case-specific message, use `alert(_:item:actions:message:)` with a title literal and the message from the model.
- `LocalizedError` is for the overloads that read it. `errorDescription` becomes the alert's title and nothing else. Apple's page names only the title for the overload without a `message:` closure, so assume it shows nothing else. Put the explanation in `failureReason` and show it through `alert(isPresented:error:actions:message:)`.
- `alert(error:)` for any `Error` is `@available(anyAppleOS 27.0)`; where the deployment target is lower, the error must be `LocalizedError`. Read the project's deployment target before choosing.

## 7. Where the text lives

- A model or an error enum carries display text as `LocalizedStringResource`, in an extension next to the enum. Convert with `String(localized:)` only where an API needs a `String`, such as an accessibility announcement. Keys, `#bundle` and format styles follow `swiftui-views`.
- `LocalizedError` members return `String?`, not a resource, so they build their strings with `String(localized:bundle:comment:)`. Adopt `LocalizedError` only when an overload needs it.
- `comment:` is a `StaticString`: write the translator's note as a literal with no interpolation.
- An error that supplies no text still has a `localizedDescription`: the system's generic wording. Never show it, and never show `String(describing: error)`. Map an Apple error to a case where the call is made, then write that case's text.

## 8. Inline errors and accessibility

- Put the message next to the field, with an icon and text, not color alone.
- Show it after the person submits or leaves the field, never before they interact. Keep what they typed.
- Announce it, because a change in color or position is silent to VoiceOver. Audits of the result belong to `app-verification`.

## 9. Anti-patterns

- `Text(error.localizedDescription)`, or any message built from an unmapped error.
- A `try?` that hides the failure the message should explain (see `swift-isolation`).
- A title of "Error", "Something went wrong" or "Invalid input"; an "OK" button when a next action exists.
- One message for cases that need different fixes.
- Presenting `.cancelled`.
- A sentence in `errorDescription` with no `message:` overload.

## 10. Review checklist

- Every case of the error has its own text, and `.cancelled` has none.
- The title says what happened; the message adds why or what next.
- Each button names its action; "OK" appears only on an informational alert.
- The invalid value and the constraint are named, and secrets are not echoed.
- The person's input and saved state are preserved and said so.
- No `localizedDescription` or `String(describing:)` reaches a person.
- Inline errors are beside the field, not color alone, and announced.

## 11. Examples

Read [references/examples.md](references/examples.md) before writing or changing an alert, inline error text or an error's display text. It holds labeled examples and a table of wording rewrites.

## 12. Hand-offs

- Error enums, `Result`, cancellation and wrapping Apple's throwing calls: `swift-isolation`.
- Alert modifiers, localization keys, `#bundle`, format styles and view structure: `swiftui-views`.
- Tests of failure paths: `swift-test-design`.
- Running and reporting tests, accessibility audits and untranslated-entry checks: `app-verification`.
- String Catalog and build settings: `xcode-project-settings`.
