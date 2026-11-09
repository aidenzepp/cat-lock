---
name: swift-doc-comments
description: "What a Swift doc comment must say, in DocC terms: summaries, Parameters, Returns and Precondition sections, failure cases of a Result-returning API, symbol links, and comments on @Observable model properties. Use when writing or reviewing Swift types, functions, properties, protocol conformances, enum cases or @Observable models; when a unit's contract is non-obvious; when an invariant, precondition or escape hatch needs its comment; or when debugging, upstream documentation or an experiment reveals a constraint the code must preserve. SwiftLint enforces that a comment exists, so this skill covers content only."
---

# Swift doc comments

Make each declaration's contract and role clear before a reader studies its implementation. A tool forces a comment on every declaration, so the risk is a comment that satisfies the tool and teaches nothing.

## 1. Preflight

From the repository root, run the project's toolchain preflight and stop on a non-zero exit. Do not install tools; name the project's setup step instead. In this template that is `./scripts/dev.swift doctor` after `./scripts/dev.swift bootstrap`.

## 2. Confirm the project enforces

Check each item exists. If one is missing, report the gap and apply the rule by hand.

- SwiftLint `missing_docs` at every access level, conforming types and extensions included, and `orphaned_doc_comment`.
- SwiftFormat as the only formatter, and the SwiftLint custom rule on the `throws`, `rethrows` and `catch` keywords.

Presence, placement and layout belong to those tools. A local value inside a function is not a declaration to document; a named local function with its own contract is.

## 3. The content bar

A comment fails when a reader learns nothing beyond the name or the signature.

- Do not restate the name, the type or the access level. `/// The title.` on `title` satisfies the linter and adds nothing.
- State what the declaration does not show: units, ranges, normalization, who may write it, what an empty or absent value means, cost, side effects, and when it is safe to call.
- Use the domain's own vocabulary, and the framework's for framework behavior.
- Describe the contract a caller relies on, not the sequence of steps inside.
- Do not document `async`, an actor annotation or a `Void` result the signature already shows. Document cancellation behavior, side effects and cost it does not show.

Read [references/examples.md](references/examples.md) before writing or reviewing a comment. Each POSITIVE and NEGATIVE label is acceptance data: reproduce the contract quality, not the comment shape.

## 4. Summary and discussion

- The summary is one sentence fragment ending in a period. A function's starts with a verb ("Inserts ..."); a type's or property's is a noun phrase ("A book on the reading list."); an initializer's starts with "Creates".
- It is plain text of about 150 characters or fewer, with no symbol names and no links, because it renders alone in lists.
- Add discussion only for a mental model, an invariant, a rationale, an ownership boundary or a cost. Each fact appears once, at the declaration that owns it.

## 5. Sections by declaration

Name each parameter by its internal name, not its argument label. DocC reads one `Returns` and one `Throws` section per symbol; more is undefined behavior.

| Declaration | Say | Leave out |
| --- | --- | --- |
| Function or method | Verb summary; each parameter's purpose and accepted range; `- Returns:` for the meaning of the result, including when an optional is `nil`; `- Precondition:` for a caller contract a trap enforces; cost or side effects the signature hides | A restated type; `- Throws:` on the project's own API; a `Void` result |
| Initializer | What it creates; each parameter's meaning and any default | A memberwise initializer the compiler synthesizes |
| Stored property | What it is, plus what the type does not show: unit, range, owner, writer, meaning of the default | The name as a sentence |
| `@Observable` model property | Domain meaning, who may write it (`private(set)`), what a change means to a reader, and why an `@ObservationIgnored` property is untracked | How observation works; the generated `_name` property |
| Computed property | What it computes; `- Complexity:` when it is not O(1) | |
| Enum case, error case | What it represents; for an error, what the caller can do about it | |
| Protocol requirement | The contract every conformer must meet | |
| Protocol witness | What this type's implementation does or guarantees | A copy of the requirement's text |
| SwiftUI view | The rendered responsibility and the model it reads; a stored property's meaning when its name does not give it | "View" or `body` boilerplate |
| Module-scope constant | The invariant, policy, consumers or role it establishes | |

A view's comment owns its role. A property comment adds only meaning the view comment does not, and a closure property states its completion guarantee, because callers pass it at the call site.

Deprecation is `@available(*, deprecated, renamed:)`, which the compiler enforces, never prose.

## 6. Failure paths

The project's APIs return `Result` and do not throw. DocC has no field for a failure, so:

- `- Returns:` names each `.failure` case and what triggers it.
- Each error-enum case says what a caller can do about it.
- `- Throws:` appears only on a protocol witness that must throw, such as `Decodable.init(from:)`.
- A cancellable API's `.cancelled` case states that cancellation surfaces there only. The rule itself, and when a case exists, belong to `swift-isolation` ("Failure paths").

## 7. Invariants and review contracts

This skill owns placement and form only.

- A caller contract that a `precondition` enforces is `- Precondition:` in the API's doc.
- An internal invariant or escape hatch gets a `//` comment beside the construct, naming the invariant.
- What the comment must name, and what a reviewer checks, is `swift-isolation` ("Escape hatches" and "Unchecked invariants"). Do not copy it here.

## 8. Preserve consequential knowledge

After debugging, reading documentation or upstream source, or running an experiment reveals new knowledge, re-review the comment on the affected code, even when it already looks complete. Embed the knowledge when all three hold:

1. It changes which implementation is correct, safe or interoperable.
2. It is not apparent from the code, the types or ordinary ecosystem knowledge.
3. A reasonable maintainer could remove the constraint, or repeat a costly discovery, without it.

Write it for a first-time reader:

1. State the declaration's current contract or role.
2. Give the causal chain as present facts: the invariant, why it requires the current design, and the guarantee that design provides.
3. Add sources: the Apple, swift.org or Swift Evolution page for public behavior, and a pinned permalink when exact upstream behavior matters.

Never write "previously", "this fixes", "after this failed" or any chronology. Put the knowledge on the smallest declaration that owns it; use a `//` comment only when it belongs to one statement or to execution order. Add none when the code or types already show it, when a tool or another skill owns the policy, or when it is temporary debugging evidence.

## 9. Links and sources

- Link a project symbol with double backticks, written relative to the enclosing context: ``Book/rename(to:)``. Single backticks are code voice and do not navigate.
- Links go in the discussion, never in the summary.
- An external source is a Markdown link `[title](url)` or a `- SeeAlso:` aside, placed on the smallest declaration that owns the sourced behavior. No generic homepages.
- An example in a comment is a fenced `swift` code block.

## 10. Review

- Every comment adds something the name and signature do not.
- Each summary is one fragment; each parameter, result and failure case is described by its meaning.
- `Result` failures are in `- Returns:`, not `- Throws:`; preconditions are `- Precondition:`.
- Each internal invariant has an adjacent comment a reviewer can check.
- `@Observable` property comments state meaning only.
- Symbol links use double backticks, outside summaries; sources sit beside the sourced behavior.
- No comment narrates history, repeats a rule a tool or another skill owns, or is user-facing error copy.

## Hand-offs

- Invariant and escape-hatch content, cancellation and `Result` semantics: `swift-isolation`.
- Who owns an `@Observable` model: `swiftui-views`.
- Test design, fakes and matching `Result` cases: `swift-test-design`; running and reporting tests: `app-verification`.
- User-facing error text, including `LocalizedError`, is user copy and belongs to `swift-error-surfaces`, not here.

## Upstream documentation

- DocC, writing symbol documentation: https://www.swift.org/documentation/docc/writing-symbol-documentation-in-your-source-files
- DocC, linking to symbols and other content: https://www.swift.org/documentation/docc/linking-to-symbols-and-other-content
- DocC, formatting documentation content: https://www.swift.org/documentation/docc/formatting-your-documentation-content
- Swift API Design Guidelines, documentation comments: https://www.swift.org/documentation/api-design-guidelines/#write-doc-comment
