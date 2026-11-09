# Cat Lock agent guide

Cat Lock is a local macOS keyboard lock helper with a Tinycast extension.

## Scope and safety

- `hand-native` owns `Sources/**` and `Package.swift`.
- `hand-launcher` owns template tooling/config/skills, `README.md`, this file,
  `.gitignore`, `extension/**`, and `scripts/package-cat-lock.sh`.
- The Mind integrates and commits; a Head reviews only when assigned.
- Preserve `.vivi/`, `work/`, and other writers' changes. Do not install tools
  globally, grant Accessibility, or launch Cat Lock/key capture during checks.
- Keep live key coverage labeled unverified until checked by a person on-device.

## Vivi delivery

- Use `vivi --project .`; boot first, then load only the assigned handle.
- Speedboat uses small Hand scopes; the Mind integrates, commits, and accepts;
  Heads review only when assigned. Load the `speedboat` skill for delivery.

## Commands

- `./scripts/dev.swift bootstrap` prepares the pinned template tooling once.
- `./scripts/dev.swift check` runs the template formatter and linter.
- `./scripts/dev.swift test` checks tooling rules and scripts after those change.
- `swift build --product CatLock` builds the native product.
- `./scripts/package-cat-lock.sh` builds the release app and copies it into
  `extension/assets/CatLock.app`.
- `bash -n scripts/package-cat-lock.sh` checks the packaging script syntax.

Use the template's pinned Swift tooling and `.swiftformat`/`.swiftlint.yml`.
Build success and static checks do not prove live key coverage or Accessibility
setup.

## Tinycast

The extension lives in `extension/`; install it with Tinycast's **Settings →
Extensions → Install → Add from folder** and select that directory. Re-add the
folder after rebuilding; folder installs do not auto-update.
