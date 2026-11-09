---
name: conventional-commits
description: "Use when staging or committing changes in a git repo, writing a commit message or splitting a working tree into commits. Chooses a conventional-commit prefix and a scope that follows this template's targets, splits work into commits that each tell one story, stages explicit paths and hunks (including Xcode-generated files such as project.pbxproj, .xcstrings and Package.resolved), writes a body only when it explains a consequence, and reports only the checks that ran. Not for formatting rules, which SwiftFormat owns."
---

# Conventional commits

A commit history should read like a small design document. Each commit is one coherent reason for change, reviewable and meaningful alone. Size does not matter; atomic means one complete change, not few files.

## 1. Confirm what the project enforces

Nothing checks commit messages mechanically here: no `commit-msg` hook, no commitlint. Confirm before relying on that:

1. Read the project's agent and contributor instructions for commit, staging and verification rules; they win over this skill.
2. List the repository's hooks and read `git log --oneline` to see the prefixes and scopes already in use.
3. Formatting is tool policy. If a formatter run would obscure the semantic diff, see step 4; never describe style rules here.

## 2. Choose the prefix

Use the most specific truthful prefix from [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/):

- `feat`, `fix`: the only types the specification defines.
- `docs`, `refactor`, `test`, `build`, `ci`, `perf`, `chore`, `revert`: convention. Prefer the narrow one over `chore`.
- `style` here means a formatter-only change. A visual change to a view is `feat` or `fix`.
- A breaking change takes `!` after the type or scope, or a `BREAKING CHANGE:` footer.

Avoid vague subjects: `update`, `cleanup`, `misc`, `changes`. The subject is imperative and names the behavior.

## 3. Choose the scope

Scope is optional. Use the name of the unit the change lives in: a package target, `app`, `skills` or `tooling`. Take names from `git log` and the package manifest, not from this skill. Do not invent a scope for one commit.

## 4. Split by story

Inspect the whole change first (`git status --short`, `git diff --stat`, `git diff`), then split:

- separate unrelated concerns, even in neighboring files
- keep a fix with its regression test; keep a feature with the tests that prove it
- separate tooling, configuration and dependency changes from behavior
- `project.pbxproj` and `.xcstrings` hunks go with the change that caused them; `Package.resolved` goes with its dependency change
- an Xcode auto-extraction rewrite of `.xcstrings`, or a wholesale `project.pbxproj` reorder, is its own commit or is left out; see [references/examples.md](references/examples.md), example 6
- run the formatter as its own `style` commit only when its output would obscure the semantic diff
- with XcodeGen, commit `project.yml` changes and never commit the generated `.xcodeproj`. The template's `.gitignore` does not ignore `.xcodeproj`, so when XcodeGen creates the app project, add an ignore entry for `*.xcodeproj/` to the app's `.gitignore` first; until then the generated project shows as untracked, and no staging path should name it
- leave out scratch files, local research, `xcuserdata`, `DerivedData`, `.build` and other generated output

Each commit leaves the repository working. If a commit is knowingly not green alone, say so before committing.

## 5. Stage carefully

Stage explicit paths with `git add -- <path>`. For a file that holds several stories, stage hunks without interactive selection. In this template, `work/` is git-ignored and absent from a fresh clone, so run `mkdir -p work` first; then write the file's patch with `git diff -- <path> > work/<name>.patch`, delete the hunks that belong to other stories, and apply the rest with `git apply --cached work/<name>.patch`. A hunk that mixes two stories cannot be split this way; correct its `@@` counts by hand or leave it unstaged. Then read `git diff --cached`. Another writer may share the working tree: never stage, stash, reset or revert changes you did not make. Avoid `git add .` and `git add -A`.

## 6. Write the message

Subject: `type(scope): imperative, concrete summary`. Add a body only when the diff cannot say it:

- the cause or constraint behind the change
- what was deliberately excluded
- the trade-off chosen
- the verification that proves it

A body that repeats the subject is noise. A self-explanatory change takes a subject alone.

## 7. Verify the boundary

Run the narrowest useful checks for the staged story before committing. In this template, run `./scripts/dev.swift check`, plus `./scripts/dev.swift test` after changing rules, scripts or toolchain pins. Build and test of app code need the consuming project's scheme and destination (see `app-verification`, "Running tests"). State what ran. Never report an unrun build or test as passing.

## 8. Final pass

- `git status --short` shows only what you meant to leave
- the new log reads in story order
- report each hash and the checks that ran
- do not push, tag or release without the user confirming the remote target

## Examples

[references/examples.md](references/examples.md) holds six labeled POSITIVE and NEGATIVE pairs: prefix, subject, story split, staging, body and Xcode-generated churn.
