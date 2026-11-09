---
name: swift-code-layout
description: "Lay out the statements in Swift functions, initializers, computed properties, loops, switch cases, SwiftUI view content and scripts by logical step: one blank line between steps and none inside a step, lines ordered so each step reads as a unit, defer and explaining comments placed with their step, a closure reported in a condition bound first or split into guards, and a long step moved into a small function named for it. Use when writing, reorganizing or reviewing a Swift body; when blank lines fall by statement kind instead of by meaning; when a variable sits far from the code that uses it; when the project's check reports a closure in a guard, if or while condition; or when a function outgrows a screen. This is layout no formatting tool can infer. Hand off DocC content to swift-doc-comments, signatures and helper types to swift-domain-contracts, view structure to swiftui-views, and wrapping, spacing, chain splits, body lines and the blank line above an exit to the project's formatting command."
---

# Swift code layout

Blank lines inside a body mark its logical steps, so a reader can take in the steps before reading any line of them. Where a step begins depends on what the code means, so no tool can place it. The project's formatting command owns wrapping and mechanical spacing, including the line breaks and blank lines its layout rules add; this skill covers the judgment.

## 1. Confirm the project enforces

Check each item exists. If one is missing, report the gap and apply that rule by hand. This skill says nothing more about these rules.

- A formatting command with SwiftFormat as its only general-purpose formatter. It keeps the blank lines an author types inside a body; the blank lines it adds or removes are its own.
- Body wrapping in `.swiftformat`: the bodies of `if`, `guard`, loops, `do`, switch cases, functions, initializers, subscripts and computed properties go on their own lines, every closure included (`wrapClosureBodies` with `--wrap-closure-bodies always`).
- Chain wrapping, `wrapMultilineFunctionChains` in `.swiftformat`: it keeps a split chain one call per line.
- Switch-case spacing, `blankLineAfterSwitchCase` in `.swiftformat`.
- Layout rules the formatting command runs beside SwiftFormat, by rule id:
  - `layout_body_lines`: `defer`, accessor (`get`, `set`, `willSet`, `didSet`) and `deinit` bodies go on their own lines.
  - `layout_exit_blank_line`: a blank line goes above a `return`, `continue` or `break` that ends a block after other statements.
  - `layout_chain_lines`: a chain of two or more calls splits one call per line, its start alone on the first line; in SwiftUI view code, so does a view with any modifier. A type's static call and leading properties stay with the start, and a final argument-free `.get()` does not count.
  - `layout_condition_closure`: a closure inside a `guard`, `if` or `while` condition is reported, not moved, because moving it can change what runs (section 3).
- A function-length limit, where the project sets one, such as SwiftLint `function_body_length`.

In this template, the formatting command is `./scripts/dev.swift fix`: it runs SwiftFormat with `.swiftformat`, then the layout rules in `scripts/Sources/ToolingCore/Layout*.swift`, then SwiftFormat again. Run it after laying out a body, then `./scripts/dev.swift check`, which reports each layout finding with its rule id.

Apart from the blank line above an exit, a formatting command that adds blank lines by statement kind, such as around every `if`, `guard`, `for` or `defer`, or after every `let` line, splits steps. Keep its output, so the project's checks pass, and report the conflict. Do not reshape code to avoid it.

## 2. Find the steps

A step is one purpose you can name in a few words: "read the file", "count the notes", "log the import". Name each step before you arrange its lines.

- The statement kind never decides. `if`, `guard`, `for`, `while`, `switch`, `defer` and `let` or `var` lines start a step only when their purpose does.
- Cleaning a value and checking it is one step. Several guards in a row are one step.
- Creating an object and configuring it is one step.
- An early exit that checks a step's result belongs to that step.
- In a test, an `#expect` or `#require` that checks an action's result sits directly after that action, in the same step, as a guard sits after the read it checks. Setup is its own step, and a `#require` that gates setup stays with the setup it checks.
- A `defer` belongs to the step of the line it undoes.
- A blank line the formatting command adds, such as above an exit that ends a block (`layout_exit_blank_line`) or after a multiline switch case, is not a step boundary. Do not read the steps from these blank lines.

## 3. Lay out the body

1. Order the lines so each step's lines sit together. Declare a variable next to the code that first uses it, not at the top of the function.
2. Put one blank line between steps and none inside a step.
3. Put `defer` directly after the line it undoes, in the same step.
4. Put a comment that explains a step directly above the step's first line, after the blank line. The comment says why: a constraint, an ordering, a consequence the code cannot show. A label that only names the step, such as `// Parse the notes`, restates the code beside it. Delete it, or extract the step (section 4) so that a function name says it.
5. Group nested blocks, loop bodies, switch-case bodies and top-level scripts the same way. Script declarations are grouped by step, not separated one `let` at a time.
6. Group SwiftUI view content the same way: views that read as one unit, such as a title and its date, sit together, and a blank line comes before the next group. The formatting command wraps closure bodies but places no blank line in them, so this is judgment only.
7. Run the formatting command (section 1) and keep its output. Do not hand-place the line breaks and blank lines its rules add.
8. Move each closure the check reports in a condition (`layout_condition_closure`). Bind the closure's result with `let` first, in the same step as the condition that checks it: `let note = notes.first { ... }`, then `guard let note`. When an earlier condition must run first, because the closure uses a value that condition binds or because the closure is costly or has effects, split the condition into consecutive guards with the `let` between them; they stay together as one step.

## 4. Keep functions small

The Linux kernel coding style sets the bar: "Functions should be short and sweet, and do just one thing", and "They should fit on one or two screenfuls of text". It allows a longer function that is conceptually simple, such as one long switch of small cases, and holds a complex function well inside the limit. Its second measure is local variables: past 5 to 10, rethink the function and split it into smaller pieces.

- Move a step into its own function when it has an honest name and either grows long or nests its own checks and locals, such as a loop body that parses one line. Move steps out, too, once the function no longer fits a screen. Name the function for the step, so the caller reads as a list of steps.
- Split a long step into smaller steps with blank lines instead when the helper would need most of the caller's state, or when no honest name fits.
- A lint length limit is a ceiling, not the test. A function under it can still hold a step to extract.
- An extracted function's signature, and whether a function mixes conceptual levels, follow swift-domain-contracts. The extracted function's failure path follows swift-isolation, and its doc comment swift-doc-comments.

## 5. Review

- Each blank line separates two steps you can name, and no blank line sits inside a step.
- No variable sits away from the code that first uses it.
- Every check of a step's result sits in that step, and consecutive guards stay together.
- In each test, setup is its own step, and each `#expect` or `#require` sits directly after the action or setup line whose result it checks.
- Each `defer` sits directly after the line it undoes.
- Each closure moved out of a condition has its result bound with `let` in the step of the condition that checks it, and a condition that must run first is a guard of its own.
- Each comment above a step explains why; none only names its step.
- No function holds a step with an honest name that has grown long or nests its own checks and locals, and the length limit passes.
- The formatting command ran, its output is kept, and the check reports no layout finding. Any blank line it added by statement kind, other than above an exit, is reported as a conflict.

## Examples

Read [references/examples.md](references/examples.md) before laying out or reviewing a body. Each POSITIVE and NEGATIVE label is acceptance data: reproduce the grouping decision, not the domain.

## Hand-offs

- What a doc comment says: swift-doc-comments.
- Signatures, parameters, helper types and parsing boundaries, including those of an extracted function: swift-domain-contracts.
- Result failure paths, cancellation and isolation: swift-isolation.
- View structure, state ownership and when to extract a view: swiftui-views.
- Wrapping, indentation and mechanical spacing, multiline switch-case spacing, chain splits, body lines and the blank line above an exit included: the project's formatting command and its layout rules (section 1). Run it; do not hand-format what it covers.

## Upstream documentation

- Google Swift Style Guide, "Vertical whitespace": a single blank line appears "Only as needed between statements to organize code into logical subsections." https://google.github.io/swift/#vertical-whitespace
- Linux kernel coding style, "6) Functions": https://www.kernel.org/doc/html/latest/process/coding-style.html#functions
- SwiftFormat rules, at the pinned version: https://github.com/nicklockwood/SwiftFormat/blob/0.64.5/Rules.md
- SwiftLint `function_body_length`: https://realm.github.io/SwiftLint/function_body_length.html
