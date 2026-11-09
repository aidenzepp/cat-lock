# Cat Lock

Cat Lock pauses keyboard input while a cat is near your Mac. The native helper
fails open if macOS Secure Input is active. Live key coverage is unverified.

## Build and install

From the project root:

```sh
./scripts/dev.swift bootstrap   # once, for the pinned formatter and linter
./scripts/package-cat-lock.sh
```

In Tinycast, open **Settings → Extensions → Install → Add from folder** and
select this project's `extension/` directory. Enable extensions in Tinycast if
needed. Re-add the folder after rebuilding because folder installs do not
auto-update.

If macOS asks for Accessibility access, grant it to Cat Lock yourself. If it
does not prompt, add `extension/assets/CatLock.app` under **System Settings →
Privacy & Security → Accessibility**. Cat Lock does not change this setting.

## Use and unlock

Run **Cat Lock** from Tinycast to open the helper. Its menu bar status is the
native `lock.fill` padlock icon, without a “Locked” label. Click it to choose
**Unlock** or **Quit**, or hold **⌃⌥⌘U** for two seconds to unlock.

Secure Input sessions, such as password entry, make Cat Lock exit fail-open;
run the Tinycast command again after that session. The physical power button
is outside Cat Lock's coverage. Keep your Mac supervised if pressing it could
cause a problem.

Warm Key artwork by Arrow 2, from [Quiver](https://app.quiver.ai/chat/d0e82878-ea8c-44dc-809b-44d2ccd11e4f); source SVG: `assets/cat-lock.svg`.
