# Conventional commit examples

These hypothetical scenarios teach commit boundaries and messages, not application code. Paths such as `Sources/Persistence/` stand in for the consuming package's real targets. File lists describe the complete contents of a proposed commit. Git commands are excerpts for the stated working-tree and index conditions; do not run them against an unrelated checkout.

No example contains Swift, so the formatter, linter and typecheck do not apply to them. Each pair differs on one judgment axis that no tool in this template checks (there is no commit-message hook), which each evidence line names.

## 1. Choose the most specific truthful prefix

Scenario: a documentation-only change clarifies local setup in `README.md`. It changes no behavior, tooling or configuration.

### POSITIVE: name the documentation change

Decisive evidence: `docs` identifies the change more specifically than the maintenance category; the subject states its purpose. Judgment rule, no tool sees it.

```text
docs: clarify local setup instructions
```

### NEGATIVE: use a broader category despite a specific fit

Decisive evidence: the subject is still accurate, but `chore` hides that the commit is documentation only. Fails only the prefix axis; no tool sees it.

```text
chore: clarify local setup instructions
```

## 2. Write a concrete, imperative subject

Scenario: a bug fix makes the persistence layer restore the saved sort order on launch. The commit holds the fix and its regression test.

### POSITIVE: state the behavior restored

Decisive evidence: the imperative verb and the named behavior tell a reviewer what was broken without opening the diff. Judgment rule, no tool sees it.

```text
fix(Persistence): restore the saved sort order
```

### NEGATIVE: hide the behavior behind a generic verb

Decisive evidence: prefix and scope are right and the verb is imperative, but "update" does not say what the fix restores. Fails only the subject axis; no tool sees it.

```text
fix(Persistence): update the sort
```

## 3. Split independent stories and keep their proof

Scenario: the working tree holds the sort-order fix, its regression test and an unrelated setup clarification. Each story passes its own checks. The lists show complete commit boundaries, not shell commands.

### POSITIVE: keep the fix and its test together

Decisive evidence: commit 1 holds the behavior and its proof; the unrelated documentation change is its own boundary. Judgment rule, no tool sees it.

```text
Commit 1: fix(Persistence): restore the saved sort order
  Sources/Persistence/SortStore.swift: restore the order
  Tests/PersistenceTests/SortStoreTests.swift: verify the restored order

Commit 2: docs: clarify local setup instructions
  README.md: clarify setup
```

### NEGATIVE: combine an unrelated story with the fix

Decisive evidence: the test is present and the message is accurate, but the setup clarification has nothing to do with the sort order. Fails only the story-split axis; no tool sees it.

```text
Commit 1: fix(Persistence): restore the saved sort order
  Sources/Persistence/SortStore.swift: restore the order
  Tests/PersistenceTests/SortStoreTests.swift: verify the restored order
  README.md: clarify setup
```

## 4. Stage only the intended boundary

Scenario: the index is empty. The three files from example 3 are modified, each holds only its stated change, and none is untracked. The full diff has been inspected. The next commit is the fix and its test. Commands run from the repository root and stop before committing.

### POSITIVE: stage the two files of the fix

Decisive evidence: explicit paths select exactly the fix and its proof, and the staged diff is read before committing. Judgment rule, no tool sees it.

```bash
git add -- Sources/Persistence/SortStore.swift Tests/PersistenceTests/SortStoreTests.swift
git diff --cached --stat
git diff --cached
```

### NEGATIVE: stage an inspected but unrelated change too

Decisive evidence: every file was inspected, yet the list includes `README.md`, which belongs to the documentation story; reading the staged diff does not make that boundary correct. Fails only the staging axis; no tool sees it.

```bash
git add -- Sources/Persistence/SortStore.swift Tests/PersistenceTests/SortStoreTests.swift README.md
git diff --cached --stat
git diff --cached
```

When one file holds several stories, stage hunks without interactive selection. In this template, run `mkdir -p work` first, because `work/` is git-ignored and absent from a fresh clone; then write its patch with `git diff -- <path> > work/<name>.patch`, delete the hunks of the other stories, apply the rest with `git apply --cached work/<name>.patch`, and read the staged diff.

## 5. Add a body when it explains a consequence

Scenario: a dependency bump in `Package.swift` pins `swift-collections` to an exact version because a newer release changes ordering that a persisted format depends on. The diff shows the pin; only the body can give the reason.

### POSITIVE: explain the reason behind the pin

Decisive evidence: the body supplies a cause the manifest line cannot express, without repeating the subject or claiming a check that did not run. Judgment rule, no tool sees it.

```text
build: pin swift-collections to an exact version

The next release changes OrderedDictionary iteration order, which the
saved sort order depends on. Revisit when the format stores its own keys.
```

### NEGATIVE: add a body that only repeats the subject

Decisive evidence: subject and prefix are right, but the body adds no cause, exclusion, trade-off or verification. Fails only the body axis; no tool sees it.

```text
build: pin swift-collections to an exact version

Pin swift-collections to an exact version.
```

For a self-explanatory change such as fixing a broken documentation link, use a subject alone.

## 6. Keep generated churn out of the change

Scenario: a one-line copy fix changes the German string for "Sort order". Building in Xcode also re-extracted `Localizable.xcstrings`: 400 lines of reordered keys and `extractionState` changes, none of them part of the fix. The working tree has no other changes.

### POSITIVE: commit only the hunk that is the fix

Decisive evidence: the patch keeps only the hunk that changes the one value; the re-extraction hunks stay unstaged to be committed on their own or discarded by the person who owns them. Judgment rule, no tool sees it.

```bash
mkdir -p work
git diff -- App/Localizable.xcstrings > work/sort-label.patch
# delete every hunk except the one that changes "Sort order"
git apply --cached work/sort-label.patch
git diff --cached --stat
```

```text
fix(app): correct the German label for Sort order
```

### NEGATIVE: commit the whole rewritten catalog with a one-line fix

Decisive evidence: the subject is accurate, but the commit also carries hundreds of lines of Xcode churn that hide the fix and make a later revert unsafe. Fails only the generated-churn axis; no tool sees it.

```bash
git add -- App/Localizable.xcstrings
git diff --cached --stat
```

```text
fix(app): correct the German label for Sort order
```
