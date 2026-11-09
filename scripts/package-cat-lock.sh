#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/extension/assets/CatLock.app"

cd "$ROOT"
swift build --configuration release --product CatLock

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$ROOT/.build/release/CatLock" "$APP/Contents/MacOS/CatLock"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
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

/usr/bin/codesign --force --deep --sign - "$APP"
printf 'Packaged Cat Lock at %s\n' "$APP"
