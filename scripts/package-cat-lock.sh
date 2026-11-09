#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/extension/assets/CatLock.app"
STAGE_ROOT=""

cleanup() {
	if [[ -n "$STAGE_ROOT" ]]; then
		if [[ -e "$STAGE_ROOT/CatLock.app.previous" && ! -e "$APP" ]]; then
			mv "$STAGE_ROOT/CatLock.app.previous" "$APP"
		fi
		rm -rf "$STAGE_ROOT"
	fi
}
trap cleanup EXIT

cd "$ROOT"
swift build --configuration release --product CatLock

mkdir -p "$ROOT/work/icon"
STAGE_ROOT="$(mktemp -d "$ROOT/work/icon/package.XXXXXX")"
APP_STAGE="$STAGE_ROOT/CatLock.app"
APP_PREVIOUS="$STAGE_ROOT/CatLock.app.previous"

mkdir -p "$APP_STAGE/Contents/MacOS" "$APP_STAGE/Contents/Resources"
cp "$ROOT/.build/release/CatLock" "$APP_STAGE/Contents/MacOS/CatLock"
cp "$ROOT/resources/CatLock.icns" "$APP_STAGE/Contents/Resources/CatLock.icns"

cat > "$APP_STAGE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>CatLock</string>
	<key>CFBundleIconFile</key>
	<string>CatLock</string>
	<key>CFBundleIdentifier</key>
	<string>dev.sterling.cat-lock</string>
	<key>CFBundleName</key>
	<string>Cat Lock</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSUIElement</key>
	<true/>
</dict>
</plist>
PLIST

/usr/bin/codesign --force --deep --sign - "$APP_STAGE"
if [[ -e "$APP" ]]; then
	mv "$APP" "$APP_PREVIOUS"
fi
if ! mv "$APP_STAGE" "$APP"; then
	if [[ -e "$APP_PREVIOUS" ]]; then
		mv "$APP_PREVIOUS" "$APP"
	fi
	exit 1
fi
printf 'Packaged Cat Lock at %s\n' "$APP"
