#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
swift build -c release --product LogX
BIN="$ROOT/.build/release/LogX"
DIST="$ROOT/dist/LogX.app"
rm -rf "$DIST"
mkdir -p "$DIST/Contents/MacOS" "$DIST/Contents/Resources"
cp "$BIN" "$DIST/Contents/MacOS/LogX"
if [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then
  cp "$ROOT/Resources/AppIcon.icns" "$DIST/Contents/Resources/AppIcon.icns"
fi
if [[ -d "$ROOT/Resources/Fonts" ]]; then
  mkdir -p "$DIST/Contents/Resources/Fonts"
  cp "$ROOT/Resources/Fonts/"*.ttf "$ROOT/Resources/Fonts/"*.txt "$DIST/Contents/Resources/Fonts/"
fi
cat > "$DIST/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>LogX</string>
  <key>CFBundleDisplayName</key><string>LogX</string>
  <key>CFBundleIdentifier</key><string>uz.realsoft.logx</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleExecutable</key><string>LogX</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>LSUIElement</key><false/>
  <key>LSBackgroundOnly</key><false/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>ATSApplicationFontsPath</key><string>Fonts</string>
  <key>NSAppTransportSecurity</key>
  <dict>
    <key>NSAllowsLocalNetworking</key><true/>
    <key>NSAllowsArbitraryLoads</key><true/>
  </dict>
</dict>
</plist>
PLIST
echo "$DIST"
