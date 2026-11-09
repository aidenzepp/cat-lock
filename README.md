# Cat Lock

Cat Lock is a macOS menu bar app that temporarily blocks keyboard input.

The app targets macOS 13 or later. The build toolchain is Xcode 27.0 build
27A266a. Tinycast requires an Apple silicon Mac running macOS 26 or later. See
[Tinycast install requirements](https://tinycast.dev/docs/install/) and its
[Add from folder guide](https://tinycast.dev/docs/extensions/installing/).

Keyboard coverage is experimental and unverified across hardware. Cat Lock
refuses to lock while Secure Input is active and unlocks if Secure Input turns
on or macOS interrupts keyboard filtering. The mouse remains available. Cat
Lock does not block the physical power button.

## Install

Clone and package the app:

```bash
git clone https://github.com/aidenzepp/cat-lock.git
cd cat-lock
./scripts/package-cat-lock.sh
```

The script builds `extension/assets/CatLock.app`. To use Tinycast, enable
extensions, then choose `Settings → Extensions → Install → Add from folder`
and select `extension/`. Tinycast copies the extension, so add the folder again
after each rebuild.

## Start

To unlock, click the menu bar padlock and choose `Unlock` or `Quit`, or hold
`⌃⌥⌘U` for two seconds.

Run `Cat Lock` from Tinycast or open the app directly:

```console
$ open extension/assets/CatLock.app
```

On first launch, grant Accessibility access, then reopen Cat Lock. A padlock
appears in the menu bar when the keyboard lock starts. If Cat Lock is not listed
in Accessibility, click `+` in
`System Settings → Privacy & Security → Accessibility`, choose
`extension/assets/CatLock.app`, then reopen Cat Lock.

## Development

The formatter and linter tools are for development. They are not needed to
package the app. Run `./scripts/dev.swift bootstrap` once, then
`./scripts/dev.swift check`. To check the unlock gesture without starting
keyboard capture, run
`extension/assets/CatLock.app/Contents/MacOS/CatLock --self-test`.

See [Contributing](CONTRIBUTING.md) and [agent instructions](AGENTS.md) for
code changes.

Warm Key artwork is by Arrow 2. See the [source SVG](assets/cat-lock.svg) and
[Quiver conversation](https://app.quiver.ai/chat/d0e82878-ea8c-44dc-809b-44d2ccd11e4f).
