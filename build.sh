#!/bin/bash
# BranchBar を .app バンドルとしてビルドする。
#   ./build.sh            → build/BranchBar.app を作る
#   ./build.sh --install  → ビルドして /Applications にコピーし、起動する
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="BranchBar"
BUNDLE_ID="io.github.tropicbird.branchbar"
VERSION="1.0"
BUILD_DIR="build"
APP="$BUILD_DIR/$APP_NAME.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc \
  -parse-as-library \
  -swift-version 5 \
  -O \
  -target "$(uname -m)-apple-macos13.0" \
  -framework AppKit -framework SwiftUI -framework ServiceManagement \
  -o "$APP/Contents/MacOS/$APP_NAME" \
  Sources/*.swift

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>              <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>       <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>        <string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key>        <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>       <string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key>           <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>    <string>13.0</string>
    <key>NSHighResolutionCapable</key>   <true/>
    <!-- メニューバーだけのアプリなので Dock には出さない -->
    <key>LSUIElement</key>               <true/>
</dict>
</plist>
PLIST

# 署名しておくと再ビルドしても設定（選んだリポジトリ）が引き継がれる
codesign --force --sign - "$APP" >/dev/null 2>&1

echo "ビルド完了: $(pwd)/$APP"

if [ "${1:-}" = "--install" ]; then
    pkill -x "$APP_NAME" 2>/dev/null || true
    rm -rf "/Applications/$APP_NAME.app"
    cp -R "$APP" "/Applications/"
    open "/Applications/$APP_NAME.app"
    echo "インストールして起動しました: /Applications/$APP_NAME.app"
fi
