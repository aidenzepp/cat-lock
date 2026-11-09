# Contributing

Run `./scripts/dev.swift bootstrap` after cloning, then `./scripts/dev.swift check` before committing.
Use `./scripts/dev.swift fix` for formatting; remaining lint findings need intentional edits.
Run `./scripts/dev.swift test` when changing rules, scripts, or tool pins. Application
changes additionally require the consuming project's build and relevant tests.

Tooling is implemented in `scripts/` using Swift ArgumentParser and Swift Testing.
Keep the `scripts/dev.swift` launcher small; it only builds and runs the CLI.
Preserve its executable shebang when formatting.

Keep changes focused and commit with conventional prefixes. Do not stage local
research, coordination records, downloaded tools, signing materials, or build output.

## Rule ownership

Formatting belongs to `.swiftformat`. Additional code checks belong to
`.swiftlint.yml`. Compiler settings belong to `config/Strict.xcconfig`. Agent skills
should cover judgment that these checks cannot reliably enforce. Declaration
organization can reorder members as well as add whitespace; review those changes
when changing organization settings.

Prefer an upstream syntax-aware rule to a custom regex. New custom rules need
passing and failing examples, a clear scope, and an explanation of false positives.
Do not enable an entire opt-in rule set, silently add suppression baselines, or
add a second general-purpose formatter. When SwiftFormat has no rule for a
mechanical layout, add a SwiftSyntax layout rule beside the existing ones: it only
inserts line breaks, and it has passing, failing and idempotence tests. Layout
that depends on meaning, such as where a step begins, stays a skill's judgment.
Prefer actionable diagnostics to growing prose checklists.

The test profile exempts only documentation presence for conventional test paths.
It inherits all production safety and performance checks. The Result keyword
rule separately excludes conventional test paths, allowing native throwing tests;
production tooling has no exemption. Keep new test suites
inside `Tests` / `*Tests` directories or name files `*Tests.swift`.

A local suppression names one rule and explains a concrete API constraint or
invariant. A suppression is not a general exception for tests or generated code.
The linter checks its supported syntactic cases; passing does not prove all errors,
task lifetimes, concurrency, resource use, or privacy behavior are correct.

## Authoritative documentation

- Swift ArgumentParser: https://github.com/apple/swift-argument-parser
- Swift API design: https://www.swift.org/documentation/api-design-guidelines/
- Swift concurrency: https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html
- SwiftFormat rules: https://github.com/nicklockwood/SwiftFormat/blob/0.64.5/Rules.md
- SwiftLint rules: https://realm.github.io/SwiftLint/rule-directory.html
- Swift Testing: https://developer.apple.com/documentation/testing
- DocC: https://www.swift.org/documentation/docc/

Follow Swift conventions rather than mechanically translating TypeScript, Effect,
or Rust patterns. The repository does not require an architecture framework.
