#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
APP="dist/WallWright.app"

echo "▸ 编译 ($CONFIG)"
swift build -c "$CONFIG" --disable-sandbox

echo "▸ 生成图标"
if [ ! -f Resources/AppIcon.icns ]; then
  rm -rf .build/AppIcon.iconset
  xcrun swift scripts/make_icon.swift .build/AppIcon.iconset
  iconutil -c icns .build/AppIcon.iconset -o Resources/AppIcon.icns
fi

echo "▸ 组装 app bundle"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/$CONFIG/WallWright" "$APP/Contents/MacOS/WallWright"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string WallWright" "$APP/Contents/Info.plist" >/dev/null 2>&1 || true

echo "▸ 签名"
codesign --force --sign - --timestamp=none "$APP" >/dev/null 2>&1 || echo "  (ad-hoc 签名跳过)"

echo "✓ 完成：$APP"
